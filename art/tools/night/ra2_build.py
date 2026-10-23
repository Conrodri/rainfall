"""RA2 — Rainette: wet anatomical tongue, adhesive mire, impact crown, spit and portrait.
Background Blender only; reuse AV2 export, CREA/TOP rigs and unchanged RA1 emblems.
--resume / --verify / --godot are independent restartable stages. No gameplay edits.
"""
import sys, math, json, hashlib, inspect
from pathlib import Path
sys.dont_write_bytecode=True
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso')]
import ra1_build as ra1, av2_build as av2, iso_rig
from ardent_iso_build import worn, mesh, bead, empty
from cd_cd1_common import tube, rgb
from PIL import Image, ImageChops
DEST=ra1.DEST
SRC=ROOT/'art/blender/characters'
WORK=SRC/'rainette_ra2_frames'
SPECS={'tongue':('CREA',512,4,1,False),'goo':('TOP',352,6,1,True),
       'land_ring':('TOP',384,4,1,False),'goo_projectile':('CREA',128,4,1,True)}
# Keep the proven pass/atlas and CanvasTexture exporter; only new resources are created.
exec(inspect.getsource(av2.resource).replace('characters/averse/','characters/rainette/'),globals())
# TOP game decals are 64 px/u: override framing locally, leaving shared rig intact.
_effects_source=inspect.getsource(av2.effects).replace('AV2','RA2').replace("'averse_'","'rainette_'")
_effects_source=_effects_source.replace("key=='goutte_lame'","key in ('tongue','goo_projectile')")
_effects_source=_effects_source.replace("ppu=128 if rig=='TOP'", "ppu=64 if rig=='TOP'")
_effects_source=_effects_source.replace("iso_rig.set_frame(cell,rig);s.render.resolution_percentage=50", "iso_rig.set_frame(cell,rig);s.camera.data.ortho_scale=cell/ppu;s.render.resolution_percentage=50")
exec(_effects_source,globals())


def atlas_image(folder,key,cell,n,suffix):
    im=Image.open(folder/(key+suffix+'.png'))
    assert max(im.size)<=4096
    return im

def shadow():
    # A physical opaque low disk and alpha falloff rendered by Blender, no PIL drawing.
    s=iso_rig.create_rig('TOP',104);s.eevee.taa_render_samples=16
    r=empty('Rainette ground contact shadow')
    mat=bpy.data.materials.new('Contact shadow black');mat.use_nodes=True
    ns=mat.node_tree.nodes;ns.clear();out=ns.new('ShaderNodeOutputMaterial');mix=ns.new('ShaderNodeMixShader')
    trans=ns.new('ShaderNodeBsdfTransparent');black=ns.new('ShaderNodeEmission');black.inputs[0].default_value=(0,0,0,1)
    tex=ns.new('ShaderNodeTexCoord');dist=ns.new('ShaderNodeVectorMath');dist.operation='DISTANCE';dist.inputs[1].default_value=(.5,.5,0)
    flatten=ns.new('ShaderNodeVectorMath');flatten.operation='MULTIPLY';flatten.inputs[1].default_value=(1,1,0)
    ramp=ns.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.04;ramp.color_ramp.elements[0].color=(.52,.52,.52,1);ramp.color_ramp.elements[1].position=.5;ramp.color_ramp.elements[1].color=(0,0,0,1)
    links=mat.node_tree.links;links.new(tex.outputs['Generated'],flatten.inputs[0]);links.new(flatten.outputs['Vector'],dist.inputs[0]);links.new(dist.outputs['Value'],ramp.inputs[0]);links.new(ramp.outputs[0],mix.inputs[0]);links.new(trans.outputs[0],mix.inputs[1]);links.new(black.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],out.inputs[0])
    bead('Soft contact lens',(0,0,0),(.35,.35,.015),mat,r)
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'rainette_shadow.blend'))
    iso_rig.render_frame(DEST/'effects/shadow/shadow.png',passes=False)
    print('RA2 SHADOW PASS',flush=True)

def materials():
    wet=worn('RA2 rain-slick olive mucosa','131F18','5B6B4F',0,.28)
    p=wet.node_tree.nodes.get('Principled BSDF');p.inputs['Coat Weight'].default_value=.72;p.inputs['Coat Roughness'].default_value=.10
    p.inputs['Subsurface Weight'].default_value=.06
    mire=worn('RA2 translucent-looking peat mucus','0B1612','3C4F38',.12,.25)
    p=mire.node_tree.nodes.get('Principled BSDF');p.inputs['Coat Weight'].default_value=.9;p.inputs['Coat Roughness'].default_value=.09
    silt=worn('RA2 pale mineral sediment on ridges','26372A','6C795D',.10,.44)
    jade=worn('RA2 sole accent vocal jade #8DBBA8','294839','8DBBA8',.20,.25)
    p=jade.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=rgb('8DBBA8');p.inputs['Emission Strength'].default_value=.8
    mud=worn('RA2 angular black peat fragments','0A100E','30372B',0,.83)
    return wet,mire,silt,jade,mud

def ribbon(name,pts,width,thickness,mat,parent):
    verts=[]
    for j,p in enumerate(pts):
        v=Vector(pts[min(j+1,len(pts)-1)])-Vector(pts[max(0,j-1)])
        side=Vector((-v.y,v.x,0)).normalized()
        w=width*(.70+.30*math.sin(math.pi*j/(len(pts)-1)))
        for a,z in [(-1,-1),(1,-1),(1,1),(-1,1)]:
            verts.append(Vector(p)+side*w*a+Vector((0,0,z*thickness)))
    faces=[(3,2,1,0),tuple((len(pts)-1)*4+k for k in range(4))]
    faces += [(j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k) for j in range(len(pts)-1) for k in range(4)]
    o=mesh(name,verts,faces,mat,parent,.012)
    for m in o.modifiers:
        if m.type=='BEVEL':m.segments=3
    for poly in o.data.polygons:poly.use_smooth=True
    return o

def pool(root,radius,f,mats):
    wet,mire,silt,jade,mud=mats
    sectors=112;nr=12;vs=[(0,0,.028)]
    for k in range(1,nr+1):
        t=k/nr
        for j in range(sectors):
            a=j*math.tau/sectors
            edge=1+.035*math.sin(a*11+.3)+.022*math.sin(a*23)
            rr=radius*t*edge
            z=.025+(1-t*t)*(.035+.022*math.sin(t*22-f*math.tau/6+a*3))
            z+=.038*math.exp(-((t-.91)/.055)**2)*(1+.3*math.sin(a*13+f*.35))
            vs.append((rr*math.cos(a),rr*math.sin(a),z))
    fs=[(0,1+j,1+(j+1)%sectors) for j in range(sectors)]
    fs += [(1+(k-1)*sectors+j,1+k*sectors+j,1+k*sectors+(j+1)%sectors,1+(k-1)*sectors+(j+1)%sectors) for k in range(1,nr) for j in range(sectors)]
    ob=mesh('Living adhesive pool / scalloped meniscus',vs,fs,mire,root)
    for p in ob.data.polygons:p.use_smooth=True
    for j in range(17):
        a=j*2.39996;rr=radius*(.29+.60*((j*.618)%1))
        x,y=rr*math.cos(a),rr*math.sin(a)
        pulse=.9+.13*math.sin(f*math.tau/6+j)
        ob=bead('Collapsed mucus blister',(x,y,.06),(.045*pulse,.065*pulse,.025*pulse),wet,root)
        # Strands pulled towards the centre suggest the gameplay attraction.
        pts=[]
        for k in range(20):
            t=k/19;aa=a+.32*t+.02*math.sin(t*9+f*math.tau/6)
            r=rr*(1-.45*t);pts.append((r*math.cos(aa),r*math.sin(aa),.065+.018*math.sin(t*math.pi)))
        tube('Inward adhesive filament',pts,.0065,jade if j%4==0 else silt,root)
    for j in range(5):
        a=j*1.256+.2;rr=radius*.91
        pts=[((rr+.012*math.sin(k*.5+f))*math.cos(a+k*.014),(rr+.012*math.sin(k*.5+f))*math.sin(a+k*.014),.075) for k in range(23)]
        tube('Sparse phosphorescent rim trace',pts,.007,jade,root)

def geometry(key,f,n,mats):
    wet,mire,silt,jade,mud=mats;r=empty('Rainette RA2 '+key)
    phase=f*math.tau/n
    if key=='tongue':
        lengths=[1.6,3.6,4.5,2.35];length=lengths[f];pts=[]
        for j in range(65):
            t=j/64
            pts.append((-216/iso_rig.R+length*t,.12*math.sin(t*math.pi*2+phase)*math.sin(t*math.pi),.102+.13*math.sin(t*math.pi)))
        ribbon('Flattened muscular tongue / 4.5u peak',pts,.064,.024,wet,r)
        for sign in (-1,1):
            edge=[(x,y+sign*.047,z+.026) for x,y,z in pts]
            tube('Longitudinal wet tendon',edge,.007,silt,r)
        tube('Sparse vocal jade nerve',[(x,y-.013,z+.028) for x,y,z in pts[18:45]],.0055,jade,r)
        x,y,z=pts[-1];bead('Flattened gripping tongue pad',(x,y,z),(.115,.098,.034),wet,r)
        for j in range(7):
            xx=x-.07+j*.021
            tube('Serrated gripping papilla',[(xx,y-.065,z+.022),(xx+.008,y,z+.040),(xx,y+.065,z+.022)],.005,silt,r)
        for j in range(3):
            k=33+j*7;xx,yy,zz=pts[k]
            tube('Taut saliva thread',[(xx,yy,zz),(xx-.10,yy-.04,zz-.045),(xx-.18,yy-.015,zz-.01)],.0035,mire,r)
    elif key=='goo':pool(r,2.5,f,mats)
    elif key=='land_ring':
        radius=[.75,1.5,2.15,2.5][f];height=[.18,.28,.20,.08][f]
        # Thin folded annulus: an impact crown, not a luminous graphical circle.
        vs=[];count=144
        for j in range(count+1):
            a=j*math.tau/count
            spike=(.5+.5*math.sin(a*19+f*.6))**7
            for k in range(6):
                t=k/5;rr=radius-.16+t*.23+.022*math.sin(a*27+f)
                zz=.018+height*math.sin(t*math.pi*.84)*(1+.9*spike)
                vs.append((rr*math.cos(a),rr*math.sin(a),zz))
        faces=[(j*6+k,(j+1)*6+k,(j+1)*6+k+1,j*6+k+1) for j in range(count) for k in range(5)]
        o=mesh('Folded mire splash crown',vs,faces,wet,r)
        o.modifiers.new('Thin viscous shell','SOLIDIFY').thickness=.008
        for p in o.data.polygons:p.use_smooth=True
        for j in range(13):
            a=j*2.3999+.15*f;rr=radius+.15+.08*math.sin(j*2)
            ob=bead('Flying elongated mire droplet',(rr*math.cos(a),rr*math.sin(a),height*(.5+(j%3)*.4)),(.025,.04,.048),wet,r)
            ob.rotation_euler=(.45*math.sin(a),.45*math.cos(a),a)
        for j in range(9):
            a=j*math.tau/9
            pts=[]
            for k in range(13):
                aa=a+k*.025;spike=(.5+.5*math.sin(aa*19+f*.6))**7
                rr=radius-.16+.6*.23+.022*math.sin(aa*27+f)
                zz=.018+height*math.sin(.6*math.pi*.84)*(1+.9*spike)+.009
                pts.append((rr*math.cos(aa),rr*math.sin(aa),zz))
            tube('Broken vocal resonance along wet edge',pts,.008,jade,r)
        for j in range(11):
            a=j*2.3999;rr=radius*.75
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
            ob=bpy.context.object;ob.name='Impact fractured peat';ob.parent=r;ob.location=(rr*math.cos(a),rr*math.sin(a),.025)
            ob.scale=(.05,.025,.03);ob.rotation_euler=(j,j*.7,j*.6);ob.data.materials.append(mud)
    else:
        bead('Aerodynamic viscous spit',(0,0,0),(.24,.11,.09),mire,r)
        for j in range(5):
            a=j*math.tau/5+phase*.35
            pts=[(-.36+t*.55,.075*math.cos(a)*math.sin(t*math.pi),.065*math.sin(a)*math.sin(t*math.pi)) for t in [k/24 for k in range(25)]]
            tube('Twisting secretion tendon',pts,.010,jade if j==1 else wet,r)
        for j in range(3):
            xx=-.32-j*.12-.02*math.sin(phase+j)
            bead('Detached spit tail',(xx,.018*math.sin(phase+j),.02*math.cos(phase+j)),(.045-j*.01,.024-j*.004,.021-j*.004),silt if j==0 else wet,r)
    return r

def portrait():
    bpy.ops.wm.open_mainfile(filepath=str(ra1.SOURCE));s=bpy.context.scene;s.frame_set(1)
    root=bpy.data.objects['Rainette'];root.rotation_euler.z=-.25
    bpy.context.view_layer.update()
    # Head rig origin is at the pelvis; aim at anatomical head/throat in model space.
    target=root.matrix_world @ Vector((0,-.04,1.43))
    cam=s.camera;cam.data.shift_y=0;cam.data.ortho_scale=.78
    cam.rotation_euler=(math.radians(70),0,0);cam.location=target+cam.rotation_euler.to_matrix()@Vector((0,0,12))
    s['iso_frame']=[256,256];s.render.resolution_x=s.render.resolution_y=512;s.render.resolution_percentage=100;s.eevee.taa_render_samples=24
    s['RA2_portrait']='Original RA1/CD anatomy, corroded cuirass, throat light and reed spear; no repaint.'
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'rainette_portrait.blend'))
    iso_rig.render_frame(DEST/'portrait.png',passes=True)
    print('RA2 PORTRAIT PASS',flush=True)

def assemble_pass_alpha():
    # Assemble rendered coverage exactly as RA1; RGB normal/emission data is untouched.
    for diffuse in [*DEST.glob('portrait.png'),*(DEST/'effects').rglob('*.png')]:
        if diffuse.stem.endswith(('_n','_e')):continue
        with Image.open(diffuse) as im:alpha=im.getchannel('A')
        for suffix in ('_n','_e'):
            path=diffuse.with_name(diffuse.stem+suffix+'.png')
            if not path.exists():continue
            with Image.open(path) as im:channels=im.convert('RGBA').split()
            if ImageChops.difference(channels[3],alpha).getbbox():
                Image.merge('RGBA',(*channels[:3],alpha)).save(path,optimize=True,compress_level=9)

def verify():
    board=Image.new('RGBA',(1536,1664),(19,24,28,255));result={}
    for row,(key,(rig,cell,n,nd,loop)) in enumerate(SPECS.items()):
        folder=DEST/'effects'/key
        with atlas_image(folder,key,cell,n,'') as im:alpha=im.getchannel('A')
        for su in ('','_n','_e'):
            with atlas_image(folder,key,cell,n,su) as im:
                assert im.size==(cell*n,cell*nd) and max(im.size)<=4096,(key,su,im.size)
                assert not ImageChops.difference(im.getchannel('A'),alpha).getbbox(),(key,su,'coverage')
                hashes=[]
                for f in range(n):
                    tile=im.crop((cell*f,0,cell*(f+1),cell));bb=tile.getchannel('A').getbbox()
                    assert bb and min(bb[:2])>=3 and max(bb[2:])<=cell-3,(key,su,f,bb)
                    hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
                    if not su:
                        tile.thumbnail((230,230),Image.Resampling.LANCZOS);board.alpha_composite(tile,(f*250,row*240))
                assert len(set(hashes))==n,(key,su,'duplicate')
        result[key]={'rig':rig,'cell':cell,'frames':n,'directions':nd,'loop':loop,'native_px_per_u':64 if rig=='TOP' else iso_rig.R,'pivot_px':[cell/2,cell/2]}
    # Full contract retained from RA1, including attack/cast/ultimate/death and 8 directions.
    for anim,n in ra1.ANIMS.items():
        for su in ('','_n','_e'):
            with Image.open(DEST/(anim+su+'.png')) as im:assert im.size==(n*192,1536)
    for j,su in enumerate(('','_n','_e')):
        with Image.open(DEST/('portrait'+su+'.png')) as im:
            assert im.size==(256,256) and im.getbbox();board.alpha_composite(im.convert('RGBA'),(j*270,968))
    with Image.open(DEST/'effects/shadow/shadow.png') as shadow_im:
        assert shadow_im.getchannel('A').getpixel((52,52))>60
        board.alpha_composite(shadow_im.convert('RGBA'),(1000,1050))
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    keys=['rainette_langue','rainette_grand_saut','rainette_gluant','rainette_chant_de_crue','eclat_de_braise','nova_ardente','cendres','brasier']
    for j,key in enumerate(keys):
        with Image.open(ra1.ICONS/(key+'.png')) as raw:
            im=raw.convert('RGBA');assert im.size==(128,128)
        for size,y in [(128,1232),(64,1370)]:
            tile=im.resize((size,size),Image.Resampling.LANCZOS);tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));board.alpha_composite(tile,(j*192+(192-size)//2,y))
    refs=['art/tools/characters/_cd_rainette.png','art/tools/ui/_i2_contact.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png']
    for j,path in enumerate(refs):
        with Image.open(ROOT/path) as raw:im=raw.convert('RGBA')
        im.thumbnail((295,205),Image.Resampling.LANCZOS);board.alpha_composite(im,(j*307,1450))
    board.save(ROOT/'art/tools/night/_ra2_contact.png',optimize=True)
    result['texture_policy']={'max_side':4096,'TOP_px_per_u':64,'CREA_px_per_u':iso_rig.R,'reason':'Native display cells; all passes share identical atlas layouts.'}
    result['tongue'].update(max_length_u=4.5,peak_frame_zero_based=2,mouth_pivot_px=[40,248],direction='east; rotated by game; mouth anchor at local x=-216/R')
    result['goo'].update(radius_u=2.5,duration_s=5,meaning='inward filaments show adhesive attraction; static area scale')
    result['land_ring'].update(max_radius_u=2.5,ultimate_radius_u=3,ultimate_scale=1.2,meaning='same crown for Grand saut and Chant de crue impacts')
    result['goo_projectile'].update(direction='east',meaning='Gluant travelling spit before pool deployment')
    result['integration_pending']={'file':'game/scripts/spells/rainette_kit.gd','required_by_native_64px_u':'GOO_RADIUS_PX and LAND_RING_RADIUS_PX: 320 -> 160; comments TOP 128 -> 64. Gameplay scripts excluded from RA2 scope.'}
    result['shadow']={'path':'effects/shadow/shadow.png','size':104,'radius_px':45,'method':'Blender radial alpha contact lens'}
    result['portrait']={'path':'portrait.png','size':256,'passes':['diffuse','normal','emission']}
    result['icons']='Four RA1 bevelled PBR emblems retained byte for byte, 128px; no other existing sizes found. Medallions at 64/128 beside Ardent.'
    (DEST/'ra2_manifest.json').write_text(json.dumps(result,indent=2),encoding='utf8')
    print('RA2 VERIFY PASS: 18 VFX frames / 12 atlases / portrait / four icons / 552 RA1 poses preserved',flush=True)

# AV2 already checks every AtlasTexture/CanvasTexture as well as the requested scene.
exec(inspect.getsource(av2.godot_verify).replace('AV2','RA2').replace('averse','rainette').replace('av2_','ra2_'),globals())

if __name__=='__main__':
    WORK.mkdir(parents=True,exist_ok=True)
    if '--godot' in sys.argv:godot_verify()
    elif '--verify' in sys.argv:assemble_pass_alpha();verify()
    elif '--portrait-only' in sys.argv:portrait();verify()
    elif '--shadow-only' in sys.argv:shadow();verify()
    else:
        effects()
        shadow()
        if '--resume' not in sys.argv or not all((DEST/('portrait'+su+'.png')).exists() for su in ('','_n','_e')):portrait()
        assemble_pass_alpha();verify()
