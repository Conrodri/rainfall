"""N1D: ceremonial walking toro, C7a rig/pass pipeline and shared boss cel.
Blender --background --python art/tools/night/n1d_build.py [--preview]
System Python: this.py --verify / --contact (assembly/inspection only).
"""
import sys, math, json, tempfile, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/bosses'),str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
try:
    from PIL import Image
except ImportError:
    sys.path[:0]=[str(ROOT/'art/tools/iso/_deps'),str(Path.home()/'AppData/Local/RainfallIsoDeps')]
    from PIL import Image
DST=ROOT/'game/assets/sprites/bosses/etage/jar_bearer'
WORK=Path(tempfile.gettempdir())/'rainfall_n1d_cel_nonormals_v3'
SPECS={**{f'{a}_p{p}':(6 if a=='idle' else 8,256,4) for p in (1,2,3) for a in ('idle','walk')},'auto':(6,256,4),'spell_a':(8,256,4),'spell_b':(8,256,4),'trans_p2':(8,256,1),'trans_p3':(8,256,1),'death':(10,256,1),'jar':(8,64,1),'jar_shatter':(6,128,1),'mother_jar':(6,128,1),'puddle':(4,128,1)}
EXTRAS={'jar','jar_shatter','mother_jar','puddle'}

def tres():
    ext=[];subs=[];anims=[]
    for a,(n,z,rows) in SPECS.items():
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/jar_bearer/{a}.png" id="{a}"]')
        for row,d in enumerate(('e','s','w','n') if rows==4 else ('s',)):
            frames=[]
            for i in range(n):
                sid=f'{a}_{d}_{i}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{a}")\nregion = Rect2({i*z}, {row*z}, {z}, {z})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            loop=a.startswith(('idle','walk')) or a in ('jar','mother_jar','puddle')
            name=a if a in EXTRAS else a+'_'+d
            anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(loop).lower()+', "name": &"'+name+'", "speed": '+('14.0' if a.startswith('walk') else '12.0')+'}')
    (DST/'jar_bearer.tres').write_text('[gd_resource type="SpriteFrames" load_steps='+str(1+len(ext)+len(subs))+' format=3]\n\n'+'\n\n'.join(ext+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(anims)+']\n',encoding='utf8')

def contact():
    # One contact only; all artwork comes from Blender. Pillow crops/assembles.
    # Text is omitted: this is strictly an image assembly, no Pillow drawing.
    cells=[]
    samples=[('idle_p1',0,1),('idle_p1',1,1),('idle_p1',3,1),('idle_p2',1,1),('idle_p3',1,1),('walk_p3',0,3),('auto',1,3),('spell_a',1,4),('spell_b',1,4),('trans_p2',0,5),('trans_p3',0,6),('death',0,9)]
    for a,row,f in samples:
        im=Image.open(DST/(a+'.png')).convert('RGBA');cells.append(im.crop((f*256,row*256,(f+1)*256,(row+1)*256)))
    for name in ('eclusier','ox_herder'):
        p=ROOT/f'game/assets/sprites/bosses/etage/{name}/idle_p1.png'
        if p.exists():
            im=Image.open(p).convert('RGBA');cell=im.height//4 if im.height>=1024 else im.height
            row=1 if im.height>=1024 else 0
            # Preserve game display pixels: no resizing of comparison bosses.
            im=im.crop((0,row*cell,cell,(row+1)*cell));tile=Image.new('RGBA',(256,256))
            bottom=210 if name=='ox_herder' else 186
            tile.alpha_composite(im,((256-cell)//2,215-bottom));cells.append(tile)
        else:
            cells.append(Image.new('RGBA',(256,256)))
    for a in ('jar','jar_shatter','mother_jar','puddle'):
        n,z,_=SPECS[a];im=Image.open(DST/(a+'.png')).convert('RGBA').crop((z*min(3,n-1),0,z*(min(3,n-1)+1),z))
        tile=Image.new('RGBA',(256,256));tile.alpha_composite(im,((256-z)//2,(256-z)//2));cells.append(tile)
    # Quality references, as requested, assembled at original pixel scale.
    for rel in ('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png'):
        p=ROOT/rel
        if p.exists():
            im=Image.open(p).convert('RGBA');x=im.width//2 if '_cs1' in rel else 0
            cells.append(im.crop((x,0,min(x+256,im.width),min(256,im.height))))
    board=Image.new('RGBA',(1536,1024),(58,64,56,255))
    for i,im in enumerate(cells):board.alpha_composite(im,((i%6)*256,(i//6)*256))
    board.convert('RGB').save(ROOT/'art/tools/night/_n1d_contact.png',compress_level=9)

def verify():
    import numpy as np
    report={};errors=[]
    for a,(n,z,rows) in SPECS.items():
        ims=[Image.open(DST/(a+'.png')).convert('RGBA')]
        arr=[np.array(im) for im in ims];alpha=arr[0][:,:,3]
        assert ims[0].size==(n*z,rows*z),a+' grid'
        assert max(ims[0].size)<=4096,a+' budget'
        ep=DST/(a+'_e.png')
        if ep.exists():
            em=np.array(Image.open(ep).convert('RGBA'))
            assert (em.shape[1],em.shape[0])==((n*z+1)//2,(rows*z+1)//2),a+' emission size'
            assert (em[:,:,:3].max(axis=2)*em[:,:,3].astype(float)/255).max()>2,a+' empty emission'
        hashes=[];boxes=[]
        for row in range(rows):
            for f in range(n):
                im=ims[0].crop((f*z,row*z,(f+1)*z,(row+1)*z));assert im.getbbox(),a+' empty'
                boxes.append(im.getbbox());hashes.append(__import__('hashlib').sha1(im.tobytes()).hexdigest())
            assert len(set(hashes[-n:]))==n,(a,'duplicate frames',row)
        body=arr[0][:,:,:3][alpha>200];mean=float(body.mean())
        if a not in EXTRAS and a!='death':assert mean>=90,(a,'dark',mean)
        report[a]={'size':ims[0].size,'mean_rgb':round(mean,2),'emission':ep.exists(),'unique_frames':len(set(hashes)),'frames':len(hashes),'bbox_first':boxes[0]}
    assert not list(DST.glob('*_n.png')),'normal maps forbidden'
    (WORK/'verification.json').write_text(json.dumps(report,indent=2))
    print('N1D VERIFY PASS:',len(report),'sheets; grids/unique frames/emission/luminance/budget; no normals')

def prepare_imports():
    for png in DST.glob('*.png'):
        ip=png.with_name(png.name+'.import')
        if not ip.exists():
            ip.write_text('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\ncompress/high_quality=true\nmipmaps/generate=false\nprocess/size_limit=0\n',encoding='utf8')

if '--contact' in sys.argv:contact();sys.exit()
if '--verify' in sys.argv:verify();sys.exit()
if '--imports' in sys.argv:prepare_imports();sys.exit()
import bpy
from mathutils import Vector
import boss_common as c
import iso_rig
import cel_style as cel
from ash_lord_build import worn,mesh,plate

def lin(h):
    rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in rgb)

def mat(name,h,em=0):return c.material(name,lin(h),roughness=.8,emission=em)

def box(n,loc,size,m,p,b=.025):
    o=c.box(n,loc,size,m,p,b)
    for mod in o.modifiers:
        if mod.type=='BEVEL':mod.segments=1
    return o

def lathe(n,profile,m,parent,seg=20):
    v=[(r*math.cos(j*math.tau/seg),r*math.sin(j*math.tau/seg),z) for z,r in profile for j in range(seg)]
    faces=[tuple(range(seg-1,-1,-1))]
    for k in range(len(profile)-1):
        for j in range(seg):faces.append((k*seg+j,k*seg+(j+1)%seg,(k+1)*seg+(j+1)%seg,(k+1)*seg+j))
    o=mesh(n,v,faces,m,parent)
    for poly in o.data.polygons:poly.use_smooth=True
    return o

def jar(n,parent,loc,scale=1):
    p=c.empty(n,loc,parent);p.scale=(scale,)*3
    lathe('Hand-thrown faceted terracotta',[(0,.19),(.05,.24),(.16,.33),(.38,.35),(.55,.28),(.63,.18),(.71,.17),(.74,.20)],CLAY,p)
    lathe('Verdigris neck glaze',[(.56,.275),(.62,.188),(.70,.181),(.745,.205),(.77,.20),(.77,.13),(.70,.125)],GLAZE,p)
    lathe('Sealed dark mouth',[(.727,.13),(.735,.13)],DARK,p)
    for side in (-1,1):c.tube('Kiln handle',[(side*.22,0,.58),(side*.39,0,.56),(side*.40,0,.40),(side*.31,0,.35)],.027,CLAY,p)
    # Folded talisman with torn lower corners, no texture painting.
    plate('Faded paper seal',[(-.078,.74),(.065,.73),(.068,.28),(.02,.30),(-.025,.25),(-.079,.28)],-.343,.008,PAPER,p)
    for z,w in ((.62,.034),(.55,.023),(.47,.038),(.40,.019)):
        box('Illegible ink prayer',(0,-.355,z),(w,.009,.023),INK,p,.001)
    for z in (.12,.2):lathe('Wheel-thrown incision',[(z,.31 if z==.12 else .342),(z+.009,.314 if z==.12 else .345)],CLAYD,p)
    cracks=c.empty('Phase cracks',parent=p)
    c.tube('Split kiln wall',[(-.24,-.22,.55),(-.16,-.31,.43),(-.19,-.32,.32),(-.09,-.33,.20)],.012,DARK,cracks)
    seep=c.empty('Olive seep',parent=p)
    for x,z in ((-.19,.29),(.14,.43)):
        c.tube('Sludge trail',[(x,-.32,z),(x+.025,-.335,z-.13),(x-.01,-.29,.06)],.022,SLUDGE,seep)
    return p,cracks,seep

def roof(parent):
    # Square hip roof with sagging eaves and upturned corners, not a cone.
    seg=16;v=[]
    for radius,z in ((.99,2.46),(1.01,2.52),(.80,2.55),(.44,2.82),(.16,2.90)):
        for j in range(seg):
            t=math.tau*j/seg;x=math.cos(t);y=math.sin(t);d=max(abs(x),abs(y));x/=d;y/=d
            corner=(abs(x*y))**5
            v.append((radius*x,radius*y*.81,z+corner*.15))
    faces=[]
    for k in range(4):
        for j in range(seg):faces.append((k*seg+j,k*seg+(j+1)%seg,(k+1)*seg+(j+1)%seg,(k+1)*seg+j))
    mesh('Sweeping pagoda hip roof',v,faces,STONE,parent,.012)
    for s in (-1,1):
        for t in (-1,1):
            c.tube('Worn hip ridge',[(s*.12,t*.1,2.93),(s*.44,t*.36,2.84),(s*.79,t*.64,2.63),(s*1.01,t*.82,2.69)],.036,EDGE,parent)
    for side in (-1,1):
        c.tube('Uneven moss eave',[(side*.93,-.81,2.62),(side*.62,-.82,2.55),(side*.26,-.82,2.55)],.033,MOSS,parent)
    lathe('Lotus roof finial',[(2.90,.14),(2.97,.10),(3.04,.11),(3.14,0)],EDGE,parent,12)

def build():
    global STONE,EDGE,CLAY,CLAYD,GLAZE,DARK,PAPER,INK,SLUDGE,MOSS,CYAN,ROPE,BAMBOO
    s=iso_rig.create_rig('CREA',256);s.camera.data.ortho_scale=4.65
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,1.35,0))
    s.eevee.taa_render_samples=8;s.render.image_settings.compression=55
    STONE=worn('Rain-worn grey granite','666D67','A0AAA2');EDGE=mat('Chipped silver stone','A8B3AC')
    CLAY=worn('Terracotta A88060 C49A74','A88060','C49A74');CLAYD=mat('Kiln rings','85684E')
    GLAZE=mat('Verdigris glaze','6D9181');DARK=mat('Deep joints','424A43');PAPER=mat('Washed prayer paper','C0B695');INK=mat('Faded prayer ink','655D4C')
    SLUDGE=mat('Olive slime 4C5A3C','4C5A3C');MOSS=mat('Mossy roof','627051');ROPE=mat('Hemp bindings','9B916E');BAMBOO=mat('Old bamboo','858268');CYAN=mat('Water fire 5EC8FF','5EC8FF',1.5)
    bpy.ops.object.light_add(type='AREA',location=(-3,1,4));rim=bpy.context.object;rim.name='Cold upper-left silhouette rim';rim.data.energy=650;rim.data.color=(.55,.76,1);rim.data.size=3;rim.rotation_euler=(-rim.location).to_track_quat('-Z','Y').to_euler()
    root=c.empty('JAR_BEARER_N1D');body=c.empty('Walking shrine',parent=root)
    legs=[]
    for side in (-1,1):
        leg=c.empty('Short articulated stone leg',(side*.34,0,.42),root);legs.append(leg)
        c.rod('Bent granite ankle',(0,0,0),(side*.05,-.08,-.23),.13,STONE,leg)
        box('Wide eroded stone foot',(side*.05,-.13,-.29),(.43,.58,.22),STONE,leg,.05)
        box('Toe bevel',(side*.05,-.39,-.26),(.39,.07,.11),EDGE,leg)
    lathe('Octagonal walking plinth',[(.42,.54),(.50,.65),(.63,.65),(.71,.43)],STONE,body,8)
    lathe('Shaft collars',[(.71,.31),(.80,.35),(.89,.27),(1.25,.24),(1.35,.33),(1.45,.40)],STONE,body,8)
    for x in (-.15,0,.15):box('Chiselled shaft flute',(x,-.245,1.06),(.025,.018,.25),DARK,body,.003)
    box('Fire-chamber lower lintel',(0,0,1.46),(1.04,.88,.18),STONE,body)
    for x in (-.40,.40):
        for y in (-.32,.32):
            box('Stone chamber corner',(x,y,1.94),(.15,.15,.83),STONE,body)
            box('Carved pillar cap',(x,y,2.29),(.22,.22,.12),EDGE,body)
    box('Fire-chamber upper lintel',(0,0,2.34),(1.01,.87,.18),STONE,body)
    lathe('Water brazier',[(1.57,.23),(1.62,.32),(1.70,.32)],GLAZE,body,16)
    flame=c.empty('Living water flame',(0,0,1.65),body)
    for j in range(3):
        f=lathe('Water tongues',[(0,.13),(.16,.16),(.33,.10),(.54,.035),(.69,0)],CYAN,flame,12);f.location=(.11*(j-1),0,.01*j);f.rotation_euler=(0,(j-1)*.29,0);f.scale=(.65,.65,.65+.16*j)
    roof(body)
    ruin=c.empty('Dying shrine fissures',parent=body)
    c.tube('Split chamber lintel',[(-.47,-.451,1.52),(-.21,-.455,1.46),(-.08,-.455,1.39)],.017,DARK,ruin)
    c.tube('Broken pagoda slab',[(.17,-.17,2.90),(.28,-.37,2.82),(.20,-.58,2.66),(.29,-.82,2.55)],.020,DARK,ruin)
    arms=[]
    for side in (-1,1):
        arm=c.empty('Ceremonial shoulder',(side*.59,-.04,1.73),body);arms.append(arm)
        c.rod('Jointed upper arm',(0,0,0),(side*.18,-.09,-.33),.065,STONE,arm)
        c.sphere('Elbow pin',(side*.18,-.09,-.33),(.11,.10,.10),GLAZE,arm)
        c.rod('Thin stone forearm',(side*.18,-.09,-.33),(side*.23,-.38,-.53),.06,EDGE,arm)
        box('Offering palm',(side*.23,-.43,-.52),(.20,.25,.075),STONE,arm)
        for dx in (-.065,0,.065):c.rod('Stone fingers',(side*.23+dx,-.47,-.49),(side*.23+dx,-.59,-.46),.022,STONE,arm)
    racks=[];jars=[];cracks=[];seeps=[]
    for side in (-1,1):
        rack=c.empty('Opening bamboo pannier',(side*.43,.42,.70),body);racks.append(rack)
        for x in (0,side*.55):
            c.rod('Bamboo upright',(x,0,-.12),(x,.10,1.72),.045,BAMBOO,rack)
            for z in (.0,.50,1.0,1.5):lat=box('Bamboo node',(x,.055,z),(.12,.12,.045),ROPE,rack)
        for z in (0,.60,1.20,1.7):c.rod('Cross lashing',(0,0,z),(side*.57,0,z),.039,BAMBOO,rack)
        for k in range(3):
            p,cr,seep=jar(f'Backpack jar {side}:{k}',rack,(side*.32,.13,k*.57),.87 if k else 1.05)
            jars.append(p);cracks.append(cr);seeps.append(seep)
            c.tube('Hemp cradle',[(side*.04,-.10,k*.57+.14),(side*.32,-.22,k*.57+.11),(side*.59,-.08,k*.57+.14)],.022,ROPE,rack)
    held,hcr,hseep=jar('Offered jar',body,(0,-.7,1.2),.85)
    # Join fixed mesh pieces within each articulated group, retaining material slots.
    for parent in [o for o in root.children_recursive if o.type=='EMPTY']+[root]:
        obs=[o for o in parent.children if o.type=='MESH']
        if len(obs)>1:
            bpy.ops.object.select_all(action='DESELECT')
            for o in obs:o.select_set(True)
            bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join()
    movable=[body,*legs,*arms,*racks,*jars,*cracks,*seeps,flame,held,hcr,hseep,ruin]
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in movable}
    def pose(a,i,n):
        for o,(loc,rot,scale) in rest.items():o.location=loc;o.rotation_euler=rot;o.scale=scale
        t=i/n;v=i/max(1,n-1);wave=math.sin(math.tau*t)
        phase=3 if a.endswith('p3') else 2 if a.endswith('p2') else 1
        if a=='trans_p2':phase=2
        lift=.5 if phase==3 else .5*v if a=='trans_p3' else 0
        body.location.z=lift+(.025*wave if phase==3 else .008*wave)
        body.rotation_euler.y=.018*wave
        ruin.scale=(v,)*3 if a=='death' else (0,)*3
        hcr.scale=hseep.scale=(0,)*3
        for j,leg in enumerate(legs):
            leg.location.z+=lift;leg.rotation_euler.x=(.22*math.sin(math.tau*t+j*math.pi) if a.startswith('walk') and phase!=3 else .015*wave)
        for j,p in enumerate(jars):
            p.rotation_euler.y=.035*math.sin(math.tau*t+j*1.3);p.rotation_euler.x=.02*wave
            damaged=(phase>=2 and j in (1,4)) or a=='death'
            cracks[j].scale=(min(1,v*2),)*3 if damaged and a=='trans_p2' else (1,)*3 if damaged else (0,)*3
            seeps[j].scale=(v if a=='trans_p2' else 1,)*3 if damaged else (0,)*3
            if phase==3 and j%3!=0:p.scale=(0,)*3
        for j,r in enumerate(racks):r.rotation_euler.y=(-1 if j==0 else 1)*(.40 if phase==3 else .40*v if a=='trans_p3' else 0)
        flame.scale=(1+.09*wave,1+.08*wave,(1.38 if phase==3 else .85)+.13*wave);flame.rotation_euler.y=.13*wave
        held.scale=(0,)*3
        if a=='auto':
            # Index 3/6: release at the apex, projectile belongs to game code.
            q=math.sin(math.pi*min(i,3)/6)
            arms[1].rotation_euler.x=-1.9*q if i<=3 else -1.9*(1-(i-3)/3)
            arms[1].rotation_euler.y=-.38*q
            if i<3:
                held.scale=(.85,)*3
                bpy.context.view_layer.update()
                held.location=arms[1].matrix_basis@Vector((.24,-.45,-.49))
                held.rotation_euler=arms[1].rotation_euler
                jars[5].scale=(0,)*3
        if a=='spell_a':
            q=math.sin(math.pi*min(i,4)/8) if i<=4 else (1-(i-4)/4)
            for j,arm in enumerate(arms):arm.rotation_euler.y=(1 if j==0 else -1)*1.95*q;arm.rotation_euler.x=-.3*q
            if i>=4:
                for j,p in enumerate(jars):
                    if j%3!=0:p.location.z+=(i-3)*.48;p.scale=rest[p][2]*(max(.0,1-(i-4)/3))
        if a=='spell_b':
            # At index 4 the mother jar is grounded in front, palms fully extended.
            q=i/4 if i<=4 else (8-i)/4;arms[1].rotation_euler.x=.65*q
            held.scale=(1.2,)*3 if i<=4 else (0,)*3
            held.location=(.25,-.65-q*.50,1.3*(1-q))
            jars[3].scale=(0,)*3
        if a=='trans_p3':
            for j,p in enumerate(jars):
                if j%3!=0:
                    p.location.z+=v*1.4;p.location.x+=(-1 if j<3 else 1)*v*.38
                    if v>.72:p.scale=rest[p][2]*max(0,(1-v)/.28)
        if a=='death':
            body.location.z=-.42*v;body.rotation_euler.x=.34*v;body.rotation_euler.y=-.48*v
            flame.scale=(max(0,1-v*2.4),)*3
            for j,p in enumerate(jars):
                # Pannier releases its jars onto the ground; asymmetrical rolling.
                p.location.z-=v*(.65+(j%3)*.56);p.location.x+=(-1 if j<3 else 1)*v*.45;p.rotation_euler.y+=v*(j+2)*.39
        bpy.context.view_layer.update()
    return root,pose

def save_source(root,pose):
    s=bpy.context.scene;f=1
    # Body actions are editable keyframed clips, with markers for each strip.
    for a,(n,z,rows) in SPECS.items():
        if a in EXTRAS:continue
        s.timeline_markers.new(a,frame=f)
        for i in range(n):
            pose(a,i,n)
            for o in root.children_recursive:
                for prop in ('location','rotation_euler','scale'):o.keyframe_insert(prop,frame=f+i)
        f+=n+2
    s.frame_end=f;s.render.fps=12;s['N1D_contract']='256px; feet y215; dim170; e,s,w,n; cel boss; cyan only'
    s['N1D_extra_specs']=json.dumps({k:v for k,v in SPECS.items() if k in EXTRAS})
    for o in root.children_recursive:
        if o.animation_data and o.animation_data.action:
            try:
                for fc in o.animation_data.action.fcurves:
                    for kp in fc.keyframe_points:kp.interpolation='LINEAR'
            except AttributeError:pass
    s.frame_set(1);pose('idle_p1',0,6)
    p=ROOT/'art/blender/bosses/jar_bearer_iso.blend';p.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(p))
    for o in root.children_recursive:o.animation_data_clear()

def extra(a):
    # Preserve existing studio, hide body; every particle is rendered geometry.
    s=bpy.context.scene;s.camera.rotation_euler=(math.pi/3,0,0);s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
    s['iso_frame']=[SPECS[a][1]]*2;s.render.resolution_x=s.render.resolution_y=SPECS[a][1]*2
    root=c.empty('Extra '+a)
    if a in ('jar','mother_jar'):
        p,cr,seep=jar('Ceremonial thrown vessel',root,(0,0,0),1);cr.scale=seep.scale=(0,)*3
        s.camera.data.ortho_scale=SPECS[a][1]/iso_rig.R
        if a=='jar':
            p.scale=(.65,)*3
            for child in p.children:child.location.z-=.37
            def pose(i,n):p.rotation_euler=(.15*math.sin(i*math.tau/n),i*math.tau/n,i*.17)
        else:
            # Calibrated 72px silhouette, 90.5097px/u billboard, base y112.
            s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,.427,0))
            for x in (-.14,.14):
                box('Cyan mother seal',(x,-.359,.51),(.032,.014,.26),CYAN,p,.003)
            def pose(i,n):
                p.scale=(.815*(1+.012*math.sin(i*math.tau/n)),)*3
                for o in p.children:
                    if o.name.startswith('Cyan mother'):o.scale.z=.5+.5*abs(math.sin((i/n)**2*math.pi*5))
    elif a=='puddle':
        s.camera.rotation_euler=(0,0,0);s.camera.location=(0,0,12);s.camera.data.ortho_scale=2
        rng=random.Random(19);verts=[(0,0,0)];N=48
        for j in range(N):
            t=j*math.tau/N;r=.80+rng.uniform(-.12,.09);verts.append((r*math.cos(t),r*.72*math.sin(t),0))
        mesh('Sharp-edged olive puddle',verts,[(0,j+1,(j+1)%N+1) for j in range(N)],SLUDGE,root)
        ripples=[]
        for x,y,r in ((-.27,.09,.17),(.31,-.16,.11),(.07,.18,.25)):
            pts=[(x+r*math.cos(t),y+r*.6*math.sin(t),.008) for t in [j*math.pi/10 for j in range(6)]]
            ripples.append(c.tube('Water reflection',pts,.009,GLAZE,root))
        def pose(i,n):
            for j,o in enumerate(ripples):o.scale=(1+.13*math.sin(i*math.tau/n+j),)*2+(1,)
    else:
        # Origin projects to y82, width approximately96px.
        s.camera.data.ortho_scale=128/iso_rig.R;root.scale=(s.camera.data.ortho_scale/1.95,)*3
        s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,18/iso_rig.R,0))
        shards=[];drops=[];rng=random.Random(7)
        for j in range(16):
            t=j*math.tau/16
            ob=mesh('Broken ceramic shard',[(-.08,0,0),(.07,.02,0),(.04,.04,.14),(-.06,.015,.10)],[(0,1,2,3),(3,2,1,0)],CLAY if j%3 else GLAZE,root);shards.append((ob,t,rng.uniform(.4,.72)))
        for j in range(18):
            t=j*math.tau/18;o=c.sphere('Water splash',(0,0,0),(.018,.018,.07),CYAN,root);drops.append((o,t,.25+.22*rng.random()))
        def pose(i,n):
            q=(i+.25)/n
            for j,(o,t,r) in enumerate(shards):
                o.location=(math.cos(t)*r*q*1.45,math.sin(t)*r*q,abs(math.sin(math.pi*q))*.36);o.rotation_euler=(q*j,q*3,q*4);o.scale=(max(.12,1-q*.65),)*3
            for j,(o,t,r) in enumerate(drops):
                o.location=(math.cos(t)*q*.67,math.sin(t)*q*.5,math.sin(math.pi*q)*r*1.8);o.scale=Vector((.018,.018,.07))*max(.01,1-q)
    return root,pose

def main():
    DST.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    root,pose=build()
    body_camera=bpy.context.scene.camera.location.copy()
    cel.install('boss', normals=False)
    cel.toon_materials('boss');cel.setup_scene(samples=8)
    save_source(root,pose)
    # Required shared cel installation immediately precedes rendering.
    cel.install('boss', normals=False)
    preview='--preview' in sys.argv
    tasks=['idle_p1','idle_p2','idle_p3','auto','spell_a','spell_b','trans_p2','trans_p3','death'] if preview else list(SPECS)
    if '--extras-only' in sys.argv:
        tasks=[a for a in SPECS if a in EXTRAS]
        for a in tasks:
            for p in WORK.glob(a+'_*.png'):p.unlink()
    if '--only' in sys.argv:tasks=sys.argv[sys.argv.index('--only')+1].split(',')
    for a in tasks:
        n,z,rows=SPECS[a]
        if a in EXTRAS:
            for o in root.children_recursive:o.hide_render=True
            eroot,epose=extra(a)
        boards=[Image.new('RGBA',(z*n,z*rows),(0,0,0,0)) for j in range(2)]
        for row,d in enumerate(('e','s','w','n') if rows==4 else ('s',)):
            if a not in EXTRAS:
                # Align planted soles to y215 in every direction; one ground pivot.
                camera=bpy.context.scene.camera
                correction={'e':-6,'s':0,'w':-6,'n':7}[d]*camera.data.ortho_scale/256
                camera.location=body_camera+camera.rotation_euler.to_matrix()@Vector((0,correction,0))
            for i in range(n):
                path=WORK/f'{a}_{d}_{i}.png'
                if not path.exists():
                    render_root=eroot if a in EXTRAS else root
                    fn=(lambda t:epose(i,n)) if a in EXTRAS else (lambda t:pose(a,i,n))
                    c.render_still(render_root,fn,path,i/n,d)
                for j,suf in enumerate(('','_e')):
                    im=Image.open(path.with_name(path.stem+suf+'.png')).convert('RGBA').resize((z,z),Image.Resampling.LANCZOS)
                    if j==0:alpha=im.getchannel('A')
                    else:im.putalpha(alpha)
                    boards[j].paste(im,(i*z,row*z))
        for board,suf in zip(boards,('','_e')):
            if suf:
                import numpy as np
                data=np.array(board)
                if (data[:,:,:3].max(axis=2)*data[:,:,3].astype(float)/255).max()<=2:
                    (DST/(a+suf+'.png')).unlink(missing_ok=True)
                    continue
                board=board.resize(((board.width+1)//2,(board.height+1)//2),Image.Resampling.LANCZOS)
            board.save(DST/(a+suf+'.png'),compress_level=9)
        if a in EXTRAS:
            for o in eroot.children_recursive:o.hide_render=True
        print('N1D DONE '+a,flush=True)
    if not preview:
        if not (DST/'jar_bearer.tres').exists():tres()
        prepare_imports()
        contact();verify()
    print('N1D COMPLETE',flush=True)

if __name__=='__main__':main()
