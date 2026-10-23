"""BO3: native-size TOP mire effects, CD3 portrait, common-studio PBR seals.
Blender --background --python art/tools/night/bo3_build.py -- [--resume|--contact|--icons]
Pillow only crops, assembles, resizes and verifies rendered images.
"""
import sys, math, json, random, inspect
from pathlib import Path
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/ui')]
import bpy
from mathutils import Vector
import iso_rig, bo2_build
from cd_cd3_common import tube, ell, empty, rgb
from ash_lord_build import worn, mesh
from PIL import Image, ImageChops
OUT=ROOT/'game/assets/sprites/characters/bourbe'
SRC=ROOT/'art/blender/characters'
WORK=SRC/'bourbe_bo3_frames'
SPECS={'bog_zone':(720,8,8,True,5.0),'ally_ring':(64,1,1,True,.42),'mud_slap':(288,4,12,False,2.0),'mud_splash':(288,6,14,False,2.0)}
TAU=math.tau

def studio(size):
    s=iso_rig.create_rig('TOP',size)
    # TOP renders at the game's 64 px/u, without hidden supersized margins.
    s.camera.data.ortho_scale=size/64
    s.eevee.taa_render_samples=12
    s.render.threads_mode='FIXED';s.render.threads=6
    for o in list(s.objects):
        if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
    for name,loc,energy,color,diam in [('Warm key',(-3,-4,7),850,(1,.76,.53),4),('Cold rim',(3,4,5),700,(.5,.66,.85),3),('Soft fill',(4,-2,5),180,(.6,.72,.85),5)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=energy;d.color=color;d.shape='DISK';d.size=diam
        o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
    s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.3
    return s

def materials():
    clay=worn('BO3 stratified wet slate clay','151D26','39434A',0,.37)
    clay.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.55
    water=worn('BO3 black tannin water','090F13','27352F',0,.24)
    water.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.85
    root=worn('BO3 drowned root fibres','171C18','434A38',0,.63)
    bronze=worn('BO3 worn verdigris bronze','263E36','8A9475',1,.42)
    fire=bpy.data.materials.new('BO3 cold follet 8DDBA8');fire.use_nodes=True
    p=fire.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=rgb('42644C');p.inputs['Emission Color'].default_value=rgb('8DDBA8');p.inputs['Emission Strength'].default_value=1.4
    return clay,water,root,bronze,fire

def radial(name,radius,ma,parent,seed,z=.0):
    rng=random.Random(seed);N=112;bands=15;vs=[(0,0,z)];fs=[]
    edges=[1+.025*math.sin(j*TAU/N*9)+.017*math.sin(j*TAU/N*17+.7) for j in range(N)]
    for k in range(1,bands+1):
        for j in range(N):
            a=j*TAU/N;r=radius*k/bands*edges[j]
            zz=z+.018*math.sin(a*7+r*8)+.013*rng.uniform(-1,1)
            vs.append((r*math.cos(a),r*math.sin(a),zz))
    for j in range(N):fs.append((0,1+j,1+(j+1)%N))
    for k in range(bands-1):
        for j in range(N):
            a=1+k*N+j;b=1+k*N+(j+1)%N;fs.append((a,b,b+N,a+N))
    ob=mesh(name,vs,fs,ma,parent)
    for p in ob.data.polygons:p.use_smooth=True
    return ob

def build_effect(key):
    size,n,_,_,radius=SPECS[key];studio(size);clay,water,rootmat,bronze,fire=materials();root=empty('BO3 '+key)
    rng=random.Random(365)
    if key=='bog_zone':
        radial('Irregular silt shore',4.96,clay,root,7,.015)
        radial('Viscous black water',4.68,water,root,13,.045)
        for j in range(17):
            a=j*TAU/17;rr=4.65+rng.uniform(-.12,.12)
            pts=[]
            for k in range(10):
                t=a+(k-4.5)*.026;r=rr+.055*math.sin(k*1.4+j)
                pts.append((r*math.cos(t),r*math.sin(t),.07+.02*math.sin(k)))
            tube('Torn shore root',pts,.035+rng.random()*.035,rootmat,root)
        for j in range(7):
            a=j*TAU/7+.3;pts=[]
            for k in range(22):
                r=.6+k*.17;t=a+.13*k
                pts.append((r*math.cos(t),r*math.sin(t),.09+.014*math.sin(k*.9)))
            tube('Drowned root spiral',pts,.035,clay,root)
            # Broken, narrow light leaks; no neon outline around the whole area.
            tube('Follet through mire',[(x,y,z+.055) for x,y,z in pts[5:15]],.014,fire,root)
            p=pts[17];ell('Oxidised buried clasp',p,(.16,.08,.035),bronze,root).rotation_euler.z=a
        for j in range(25):
            a=rng.random()*TAU;r=math.sqrt(rng.random())*4.3;x=r*math.cos(a);y=r*math.sin(a);rad=rng.uniform(.065,.17)
            tube('Ruptured gas crater',[(x+rad*math.cos(t*TAU/19),y+rad*math.sin(t*TAU/19),.092) for t in range(20)],.012,clay,root)
    elif key=='ally_ring':
        # One broken bronze ally seal; no opaque centre underneath the familiar.
        for j in range(3):
            a=j*TAU/3
            pts=[(.405*math.cos(a+k*.047),.405*math.sin(a+k*.047),.015) for k in range(39)]
            tube('Ally bronze arc',pts,.018,bronze,root)
            tube('Ally cold inlay',[(x,y,z+.018) for x,y,z in pts[3:33]],.010,fire,root)
    elif key=='mud_slap':
        N=64;vs=[]
        for k in range(3):
            for j in range(N+1):
                a=math.radians(-105+210*j/N);r=(.72,1.66,1.95)[k]+.03*math.sin(j*2.7)
                vs.append((r*math.cos(a),r*math.sin(a),.06+(k==1)*.16*math.sin(j*math.pi/N)))
        fs=[(k*(N+1)+j,k*(N+1)+j+1,(k+1)*(N+1)+j+1,(k+1)*(N+1)+j) for k in range(2) for j in range(N)]
        ob=mesh('Ragged 210 degree mud impact',vs,fs,clay,root,.006)
        ob.modifiers.new('Mud sheet thickness','SOLIDIFY').thickness=.035
        for j in range(9):
            a=math.radians(-96+j*24)
            tube('Clay root spray',[(r*math.cos(a+.04*math.sin(k)),r*math.sin(a+.04*math.sin(k)),.12+.12*math.sin(k)) for k,r in enumerate((.85,1.3,1.8))],.025,rootmat,root)
        tube('Follet leading fault',[(1.83*math.cos(a),1.83*math.sin(a),.27) for a in [math.radians(-72+j*3) for j in range(49)]],.016,fire,root)
    else:
        radial('Plouf impact basin',1.4,water,root,19,.035)
        for j in range(13):
            a=j*TAU/13;pts=[]
            for k in range(8):
                r=.35+k*.2;t=a+.035*k;pts.append((r*math.cos(t),r*math.sin(t),.05+.32*math.sin(k*math.pi/8)))
            tube('Torn clay splash',pts,.040+(j%3)*.012,clay,root)
            if j%3==0:tube('Cold seam in splash',[(x,y,z+.075) for x,y,z in pts[1:6]],.016,fire,root)
            ell('Airborne angular wet clod',(1.84*math.cos(a),1.84*math.sin(a),.2),(.055,.095,.09),clay,root).rotation_euler.z=a
    iso_rig.bake_ao_shadows(root)
    s=bpy.context.scene;s['BO3']='TOP; 64 px/u; broken root-tendon geometry, tannin water, cold green seams; mobile atlases <=4096'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('bourbe_'+key+'.blend')))
    return root

def resources(key):
    cell,n,fps,loop,_=SPECS[key];folder=OUT/key;cols=min(n,4096//cell);atlases=math.ceil(n/cols)
    for emission in (False,True):
        ext=[];subs=[];frames=[]
        for a in range(atlases):
            stem=key+(f'_{a:02}' if a else '')
            if emission:ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/bourbe/{key}/{stem}_e.png" id="d{a}"]')
            else:
                for tag,suf in [('d',''),('n','_n')]:ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/bourbe/{key}/{stem}{suf}.png" id="{tag}{a}"]')
                subs.append(f'[sub_resource type="CanvasTexture" id="c{a}"]\ndiffuse_texture = ExtResource("d{a}")\nnormal_texture = ExtResource("n{a}")')
        for f in range(n):
            a=f//cols;ref=f'ExtResource("d{a}")' if emission else f'SubResource("c{a}")'
            subs.append(f'[sub_resource type="AtlasTexture" id="f{f}"]\natlas = {ref}\nregion = Rect2({(f%cols)*cell}, 0, {cell}, {cell})')
            frames.append('{"duration": 1.0, "texture": SubResource("f'+str(f)+'")}')
        text=f'[gd_resource type="SpriteFrames" load_steps={1+len(ext)+len(subs)} format=3]\n\n'+'\n\n'.join(ext+subs)+'\n\n[resource]\nanimations = [{"frames": ['+', '.join(frames)+f'], "loop": {str(loop).lower()}, "name": &"default", "speed": {fps}.0'+'}]\n'
        (folder/(key+('_emission' if emission else '')+'.tres')).write_text(text)

def effects():
    for key,(cell,n,fps,loop,radius) in SPECS.items():
        folder=OUT/key;folder.mkdir(parents=True,exist_ok=True);raw=WORK/key;raw.mkdir(parents=True,exist_ok=True)
        complete=all((raw/f'{f:02}{s}.png').exists() for f in range(n) for s in ('','_n','_e'))
        if not ('--resume' in sys.argv and complete):
            root=build_effect(key)
            surfaces=[(o,tuple(v.co.copy() for v in o.data.vertices)) for o in root.children_recursive if o.type=='MESH' and 'water' in o.name.lower()]
            for f in range(n):
                phase=f/n*TAU
                if key=='bog_zone':
                    for ob,base in surfaces:
                        for v,co in zip(ob.data.vertices,base):v.co.z=co.z+.018*math.sin(co.x*3+co.y*2+phase)
                    root.rotation_euler.z=.007*math.sin(phase)
                    for mat in bpy.data.materials:
                        if mat.name.startswith('BO3 cold follet'):mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=1.25+.25*math.sin(phase)
                elif key=='mud_slap':
                    root.rotation_euler.z=math.radians(-18+12*f);root.scale=(.76+.08*f,)*3
                elif key=='mud_splash':
                    sc=(.58,.78,.94,1,.86,.64)[f];root.scale=(sc,sc,1+.12*f);root.rotation_euler.z=f*.035
                iso_rig.render_frame(raw/f'{f:02}.png')
        cols=min(n,4096//cell)
        for a in range(math.ceil(n/cols)):
            count=min(cols,n-a*cols);stem=key+(f'_{a:02}' if a else '')
            for suffix in ('','_n','_e'):
                atlas=Image.new('RGBA',(count*cell,cell))
                for j in range(count):
                    f=a*cols+j
                    with Image.open(raw/f'{f:02}{suffix}.png') as im:im=im.convert('RGBA')
                    if suffix:
                        with Image.open(raw/f'{f:02}.png') as d:im.putalpha(d.getchannel('A'))
                    atlas.paste(im,(j*cell,0))
                atlas.save(folder/(stem+suffix+'.png'),optimize=True,compress_level=9)
        resources(key);print('BO3 PASS '+key,flush=True)

def icons():
    # Reuse BO2's bevelled sculptural emblems, with an explicit shared studio.
    code=inspect.getsource(bo2_build.icons).replace('def icons():','def build_icons():').replace("s=iso_rig.create_rig('CREA',128);s.eevee.taa_render_samples=20","s=studio(128);s.eevee.taa_render_samples=20").replace('ortho_scale=1.45','ortho_scale=1.18')
    ns=dict(bo2_build.__dict__);ns['studio']=studio
    exec(code,ns);ns['build_icons']()

def portrait():
    bpy.ops.wm.open_mainfile(filepath=str(SRC/'bourbe.blend'))
    s=bpy.context.scene
    s=iso_rig.create_rig('CREA',256,reset=False);s.eevee.taa_render_samples=20
    s.camera.location=(2.1,-6,3.2);target=Vector((0,-.015,.90));s.camera.rotation_euler=(target-s.camera.location).to_track_quat('-Z','Y').to_euler();s.camera.data.ortho_scale=1.12;s.camera.data.shift_y=0
    s['portrait']='CD3 upper-body, wet clay, bronze ligatures and cold follet; three-quarter view'
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(SRC/'bourbe_portrait.blend'))
    iso_rig.render_frame(OUT/'portrait.png');print('BO3 PASS portrait',flush=True)

def verify_contact():
    report={'status':'PASS','effects':{},'portrait':256,'accent':'#8DDBA8','px_per_u':64,'notes':'BO1 actor and BO2 familiar retained. Mire broken shore, drowned roots, bronze splinters; narrow cold green fissures. Common studio seals. CD3 portrait.'}
    rows=[]
    for key,(cell,n,fps,loop,radius) in SPECS.items():
        row=Image.new('RGBA',(1536,224));hashes=[];bounds=[]
        cols=min(n,4096//cell)
        for f in range(n):
            a=f//cols;stem=key+(f'_{a:02}' if a else '');box=((f%cols)*cell,0,(f%cols+1)*cell,cell)
            ims=[]
            for suffix in ('','_n','_e'):
                with Image.open(OUT/key/(stem+suffix+'.png')) as im:
                    assert max(im.size)<=4096
                    ims.append(im.convert('RGBA').crop(box))
            for im in ims[1:]:assert not ImageChops.difference(ims[0].getchannel('A'),im.getchannel('A')).getbbox(),key+' alpha'
            b=ims[0].getchannel('A').getbbox();assert b and b[0]>=2 and b[1]>=2 and b[2]<=cell-2 and b[3]<=cell-2,(key,b)
            bounds.append(b);hashes.append(__import__('hashlib').sha256(ims[0].tobytes()).hexdigest())
            thumb=ims[0];thumb.thumbnail((184,216),Image.Resampling.LANCZOS);row.alpha_composite(thumb,(f*192+(192-thumb.width)//2,(224-thumb.height)//2))
        assert len(set(hashes))==n,key+' duplicate frames'
        report['effects'][key]={'cell':cell,'frames':n,'atlases':math.ceil(n/cols),'bounds':bounds,'loop':loop,'fps':fps,'radius_u':radius}
        rows.append(row)
    # A native crop of the mire makes the surface and material detail assessable.
    with Image.open(OUT/'bog_zone/bog_zone.png') as im:detail=im.crop((0,0,720,720)).resize((420,420),Image.Resampling.LANCZOS)
    row=Image.new('RGBA',(1536,420));row.alpha_composite(detail,(0,0))
    for j,suf in enumerate(('','_n','_e')):
        with Image.open(OUT/('portrait'+suf+'.png')) as im:row.alpha_composite(im.convert('RGBA'),(450+j*270,65))
    rows.append(row)
    frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
    keys=['bourbe_gifle_de_vase','bourbe_detacher','bourbe_rappel','bourbe_bourbier','eclat_de_braise','nova_ardente','cendres','brasier']
    for size in (128,64):
        row=Image.new('RGBA',(1536,144))
        for j,key in enumerate(keys):
            with Image.open(ROOT/('game/assets/sprites/icons/spells/'+key+'.png')) as im:tile=im.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
            tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));row.alpha_composite(tile,(j*192+(192-size)//2,8))
        rows.append(row)
    # Reference crops are assembled into this single final contact sheet.
    row=Image.new('RGBA',(1536,320))
    for j,name in enumerate(('art/tools/characters/_cd_bourbe.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/ui/_i2_contact.png')):
        with Image.open(ROOT/name) as im:im=im.convert('RGBA');im.thumbnail((300,320),Image.Resampling.LANCZOS);row.alpha_composite(im,(j*307,0))
    rows.append(row)
    board=Image.new('RGBA',(1536,sum(r.height for r in rows)),(19,24,29,255));y=0
    for row in rows:board.alpha_composite(row,(0,y));y+=row.height
    board.convert('RGB').save(ROOT/'art/tools/night/_bo3_contact.png',optimize=True)
    (OUT/'bo3_manifest.json').write_text(json.dumps(report,indent=2));print('BO3 VERIFY PASS: matched passes, unique frames, margins, atlases <=4096',flush=True)

if __name__=='__main__':
    if '--contact' in sys.argv:verify_contact()
    elif '--icons' in sys.argv:icons()
    else:
        effects();icons();portrait();verify_contact()
