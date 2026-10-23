"""VG1 / Vigie. Blender geometry + timelines; Pillow only assembly/crop/verification.
Blender: --background --python art/tools/night/vg1_build.py -- --render
Python: vg1_build.py --finish | --verify. Resume automatically from complete raw pairs.
"""
import sys, math, json, os, tempfile, shutil, hashlib
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
DEST = ROOT/'game/assets/sprites/characters'
SOURCE = ROOT/'art/blender/characters/vigie.blend'
RAW = Path(tempfile.gettempdir())/'Rainfall_VG1_frames'
DIRS = ['e','se','s','sw','w','nw','n','ne']
ANIMS = {'idle':8,'run':8,'brace':4,'attack':4,'draw':6,'flare':5,'net':5,'volley':7,'death':6}
IMPACTS = {'attack':2,'draw':4,'flare':3,'net':2,'volley':4}
PIVOT = [96,136.32]
CELL=192
sys.path[:0] = [str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]

def manifest():
    return {'character':'vigie','lot':'VG1','cell':CELL,'pivot':PIVOT,'directions':DIRS,
        'rig':{'name':'CREA','elevation':30,'px_per_unit':64*math.sqrt(2),'height_u':1.35},
        'animations':{a:{'frames':n,'fps':10 if a in ('idle','run','brace') else 12,
            'loop':a in ('idle','run','brace'),'impact':IMPACTS.get(a),
            'source_start':1+20*list(ANIMS).index(a)} for a,n in ANIMS.items()},
        'aliases':{'cast':'flare','cast_ult':'volley'},'unique_renders':424,
        'normal_maps':False,'emission_scale':0.5,'accent':'#FF3A4F',
        'emission_parts':['bowstring','quiver flare heads','smouldering hip fuse'],
        'design':['gaunt stooped watcher, realistic proportions','asymmetric woven reed roof with frayed tips',
                  'blackened longbow with verdigris bindings','dented brass hip tube and telescope',
                  'mud layered fisher gaiters, scarf covering nose'],
        'contact':{'rows':list(ANIMS),'columns':['Vigie se','Vigie s','Vigie nw','Ardent cel s','Rictus s'],
                   'scale':'native 192px cells, no rescaling','ground':'terrain/terraces/iso/ground_a.png'}}

def resources(folder):
    ex=[]; subs=[]; anims=[]; ids={}; k=0
    for i,(a,n) in enumerate(ANIMS.items()):
        eid=str(i+1)
        ex.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/{folder.name}/{a}.png" id="{eid}"]')
        for row,d in enumerate(DIRS):
            frames=[]
            for f in range(n):
                k+=1; aid='a'+str(k)
                subs.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = ExtResource("{eid}")\nregion = Rect2({f*CELL}, {row*CELL}, {CELL}, {CELL})')
                frames.append('{"duration": 1.0, "texture": SubResource("'+aid+'")}')
            ids[(a,d)] = frames
    for a in [*ANIMS,'cast','cast_ult']:
        original={'cast':'flare','cast_ult':'volley'}.get(a,a)
        info=manifest()['animations'][original]
        for d in DIRS:
            anims.append('{"frames": ['+', '.join(ids[(original,d)])+'], "loop": '+str(info['loop']).lower()+', "name": &"'+a+'_'+d+'", "speed": '+str(info['fps'])+'.0}')
    (folder/'vigie.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={len(ex)+len(subs)+1} format=3]\n\n'+'\n\n'.join(ex+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(anims)+']\n',encoding='utf8')

def finish():
    from PIL import Image
    for a,n in ANIMS.items():
        for suffix in ('','_e'):
            sheet=Image.new('RGBA',(CELL*n,CELL*8))
            for row,d in enumerate(DIRS):
                for f in range(n):
                    p=RAW/f'{a}_{d}_{f:02d}{suffix}.png'
                    with Image.open(p) as im:
                        assert im.size==(CELL,CELL), str(p)
                        sheet.paste(im,(f*CELL,row*CELL))
            if suffix:
                sheet=sheet.resize((sheet.width//2,sheet.height//2),Image.Resampling.LANCZOS)
                assert max(c.getextrema()[1] for c in sheet.split()[:3])>32
            for name in ('vigie','vigie_cel'):
                folder=DEST/name; folder.mkdir(parents=True,exist_ok=True)
                sheet.save(folder/(a+suffix+'.png'),optimize=True,compress_level=9)
    for name in ('vigie','vigie_cel'):
        folder=DEST/name
        resources(folder)
        (folder/'vigie_manifest.json').write_text(json.dumps(manifest(),ensure_ascii=False,indent=2),encoding='utf8')
    contact()
    verify()

def contact():
    from PIL import Image
    # Assemble actual game floor and sprite crops only. No Pillow drawing.
    floor=ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'
    with Image.open(floor) as im: tile=im.convert('RGBA')
    canvas=Image.new('RGBA',(CELL*5,CELL*len(ANIMS)),(20,26,29,255))
    for y in range(0,canvas.height,max(1,tile.height//2)):
        for x in range(0,canvas.width,max(1,tile.width)):
            canvas.alpha_composite(tile,(x-(tile.width//2 if (y//max(1,tile.height//2))%2 else 0),y))
    canvas.alpha_composite(Image.new('RGBA',canvas.size,(5,10,14,170)))
    for row,(a,n) in enumerate(ANIMS.items()):
        f=IMPACTS.get(a,n-1 if a=='death' else n//3)
        with Image.open(DEST/'vigie'/(a+'.png')) as sheet:
            for col,d in enumerate(('se','s','nw')):
                j=DIRS.index(d); frame=sheet.crop((f*CELL,j*CELL,(f+1)*CELL,(j+1)*CELL))
                canvas.alpha_composite(frame,(col*CELL,row*CELL))
        for col,name in ((3,'ardent_cel'),(4,'rictus')):
            p=DEST/name/'idle.png'
            with Image.open(p) as ref:
                frame=ref.crop((0,2*CELL,CELL,3*CELL))
                canvas.alpha_composite(frame,(col*CELL,row*CELL))
    canvas.convert('RGB').save(HERE/'_vg1_contact.png',optimize=True)

def verify():
    import cel_style as cel
    from PIL import Image
    report=[]
    for name in ('vigie','vigie_cel'):
        folder=DEST/name
        assert not list(folder.glob('*_n.png'))
        tres=(folder/'vigie.tres').read_text()
        assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
        assert tres.count('[sub_resource type="AtlasTexture"')==424
        assert tres.count('"name": &"')==88
        for a,n in ANIMS.items():
            report.append(cel.check_sheet(f'characters/{name}/{a}.png',cell=CELL,frames=n,rows=8,normals=False))
            p=folder/(a+'.png'); e=folder/(a+'_e.png')
            with Image.open(p) as im, Image.open(e) as em:
                assert em.size==((im.width+1)//2,(im.height+1)//2)
                for f in range(n):
                    signatures={hashlib.sha256(im.crop((f*CELL,row*CELL,(f+1)*CELL,(row+1)*CELL)).tobytes()).digest() for row in range(8)}
                    assert len(signatures)==8,(a,f,'DUPLICATE DIRECTIONS')
                for row in range(8):
                    for f in range(n):
                        fr=im.crop((f*CELL,row*CELL,(f+1)*CELL,(row+1)*CELL))
                        box=fr.getchannel('A').getbbox()
                        assert box and min(box[:2])>=2 and max(box[2:])<=190,(a,row,f,'CLIPPED',box)
                        er=em.crop((f*96,row*96,(f+1)*96,(row+1)*96))
                        assert max(c.getextrema()[1] for c in er.split()[:3])>20,(a,row,f,'NO ACCENT')
            assert hashlib.sha256(p.read_bytes()).digest()==hashlib.sha256((DEST/('vigie_cel' if name=='vigie' else 'vigie')/p.name).read_bytes()).digest()
    print('VG1 VERIFY PASS: 424 frames, 88 animations/style, 18 sheets/style, no normals, half emission',flush=True)

# All below is executed only inside Blender.
def build():
    import bpy, random
    import iso_rig, cel_style as cel
    from mathutils import Vector
    common=iso_rig.common
    random.seed(7321)
    RAW.mkdir(parents=True,exist_ok=True)
    s=iso_rig.create_rig('CREA',CELL,target=(0,0,0))
    s.camera.data.shift_y=.21
    s.render.threads_mode='FIXED';s.render.threads=6
    s.render.image_settings.compression=35
    s.render.fps=12
    facing=common.empty('Vigie_facing_8_directions')
    root=common.empty('Vigie_ROOT',parent=facing)
    torso=common.empty('Stooped_spine',(0,0,.65),root)
    head=common.empty('Watchers_neck',(0,-.065,.48),torso)
    mats={}
    def color(h):
        v=[int(h[i:i+2],16)/255 for i in (1,3,5)]
        return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v)
    def mat(name,h,metal=0,glow=0):
        m=common.material('Vigie_'+name,color(h),metal,.84,glow,grain=not glow)
        m['palette_srgb']=h
        if glow:m['rainfall_emissive']=True
        mats[name]=m;return m
    reed=mat('waterlogged_reed','#5A5540');reedlight=mat('reed_splits','#77705A');reeddark=mat('reed_knots','#484739')
    slate=mat('oilskin','#3A4048');seam=mat('worn_oilskin_edges','#626771')
    wood=mat('black_dike_wood','#2A2522');copper=mat('verdigris_bindings','#4F6B5E',.55)
    brass=mat('dented_brass','#8B7957',.65);gold=mat('brass_scratches','#B4A07A',.6)
    skin=mat('rain_pale_skin','#C9B8A8');shadow=mat('tired_eyelids','#776D66')
    dark=mat('wet_leather','#302D2B');mud=mat('silt','#565245');lightmud=mat('dried_silt','#777263')
    eye=mat('small_dull_eyes','#B8B4A6');fuse=mat('DISTRESS_RED','#FF3A4F',glow=1)
    smoke=mat('fuse_ash','#646469'); rope=mat('soaked_hemp','#8B8167')
    objs=[]
    def mesh(name,verts,faces,m,parent):
        data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
        ob=bpy.data.objects.new(name,data);s.collection.objects.link(ob);ob.parent=parent;ob.data.materials.append(m);objs.append(ob);return ob
    def loft(name,rings,m,parent,N=12):
        verts=[]
        for z,cx,cy,rx,ry in rings:
            verts.extend((cx+rx*math.cos(2*math.pi*j/N),cy+ry*math.sin(2*math.pi*j/N),z) for j in range(N))
        faces=[tuple(range(N-1,-1,-1))]
        for k in range(len(rings)-1):
            for j in range(N):faces.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
        faces.append(tuple((len(rings)-1)*N+j for j in range(N)))
        ob=mesh(name,verts,faces,m,parent)
        for p in ob.data.polygons:p.use_smooth=True
        return ob
    def ell(name,loc,scale,m,parent):
        ob=common.sphere(name,loc,scale,m,parent);objs.append(ob);return ob
    def box(name,loc,size,m,parent):
        ob=common.box(name,loc,size,m,parent,bevel=.008);objs.append(ob);return ob
    def line(name,pts,r,m,parent):
        ob=common.tube(name,pts,r,m,parent);ob.data.bevel_resolution=1;ob.data.resolution_u=3;objs.append(ob);return ob
    def rod(name,a,b,r,m,parent):
        a,b=Vector(a),Vector(b)
        # Shared simple cylinder avoids hundreds of bevel modifiers below sprite resolution.
        bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=r,radius2=r*.88,depth=1)
        ob=bpy.context.object;ob.name=name;ob.parent=parent;ob.data.materials.append(m);objs.append(ob)
        segment(ob,a,b,r)
        return ob
    def segment(ob,a,b,r=None):
        a,b=Vector(a),Vector(b);ob.location=(a+b)/2
        ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();ob.scale.z=(b-a).length
    # Long narrow oilskin coat, sewn gussets and asymmetric storm flap.
    loft('Patched_oilskin_coat',[(0,0,0,.14,.095),(.10,0,0,.115,.09),(.25,0,-.03,.13,.085),(.39,0,-.065,.18,.095),(.45,0,-.075,.10,.07)],slate,torso)
    for j in range(7):
        x=-.126+j*.042
        line('Coat_creased_seam',[(x,-.09,.02),(x*.86,-.105,.16),(x*.8,-.13,.32)],.004,seam,torso)
    box('Storm_flap',(.025,-.115,.19),(.115,.022,.29),slate,torso)
    line('Chest_diagonal_leather_sling',[(-.14,-.145,.39),(-.045,-.14,.23),(.10,-.106,.04)],.015,dark,torso)
    loft('Waist_belt',[(-.005,0,0,.146,.102),(.036,0,0,.14,.10)],dark,torso)
    box('Belt_buckle',(.065,-.108,.015),(.046,.014,.032),brass,torso)
    # Hood shell: open at the face. Pointed peak, drooping rear, no large round head.
    N=16;vs=[]
    for z,rx,ry,cy in [(-.075,.095,.092,.014),(.035,.122,.108,.014),(.145,.099,.095,.018),(.215,.025,.042,.031)]:
        for j in range(N):
            t=2*math.pi*j/N;vs.append((rx*math.cos(t),cy+ry*math.sin(t),z))
    fs=[]
    for k in range(3):
        for j in range(N):
            # Open lower two front rows, retain overhanging brow.
            if k<2 and 9<=j<=14:continue
            fs.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
    fs.append(tuple(3*N+j for j in range(N)))
    mesh('Slate_hood_open_face',vs,fs,slate,head)
    line('Hood_front_worn_hem',[(-.095,-.065,-.04),(-.103,-.081,.07),(-.074,-.078,.145),(0,-.073,.17),(.074,-.078,.145),(.103,-.081,.07),(.095,-.065,-.04)],.006,seam,head)
    ell('Narrow_gaunt_face',(0,-.077,.038),(.075,.046,.106),skin,head)
    # Angular cheek planes, pinched nose and slit eyes under heavy sleepless lids.
    for x in (-.041,.041):
        ell('Hollow_cheek',(x,-.114,.006),(.026,.013,.036),shadow,head)
        line('Upper_heavy_eyelid',[(x-.022,-.120,.078),(x,-.127,.082),(x+.021,-.120,.076)],.005,shadow,head)
        ell('Slit_of_eye',(x,-.125,.069),(.017,.006,.0045),eye,head)
        ell('Pupil',(x,-.131,.069),(.004,.003,.004),dark,head)
        line('Sleepless_lower_lid',[(x-.019,-.118,.060),(x,-.123,.055),(x+.017,-.118,.06)],.0035,shadow,head)
    mesh('Pinched_nose',[(-.016,-.118,.083),(.016,-.118,.083),(0,-.151,.035),(-.021,-.125,.028),(.021,-.125,.028)],[(0,1,2),(0,2,3),(1,4,2),(2,4,3)],skin,head)
    for z in (-.025,-.003,.018):
        line('Scarf_over_nose',[(-.085,-.075,z+.009),(-.060,-.125,z),(0,-.145,z-.008),(.060,-.125,z),(.085,-.075,z+.01)],.018,reed if z==-.003 else dark,head)
    # Pelerine: asymmetric triangular woven roof, frayed tips, ropes binding the reeds.
    N=40;vs=[]
    for layer in range(3):
        for j in range(N):
            t=j*2*math.pi/N
            front=max(0,-math.sin(t)); back=max(0,math.sin(t))
            if layer==0:rx,ry,z=.10,.09,.51
            elif layer==1:rx,ry,z=.29,.185,.365
            else:rx,ry,z=.265,.185,.235-.11*back+.065*front
            vs.append((rx*math.cos(t),-.062+ry*math.sin(t),z))
    fs=[(k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j) for k in range(2) for j in range(N)]
    cape=mesh('Woven_reed_roof',vs,fs,reed,torso)
    for j in range(64):
        t=2*math.pi*j/64;ct,st=math.cos(t),math.sin(t);back=max(0,st);front=max(0,-st)
        end=.22-.11*back+.065*front+random.uniform(-.035,.025)
        off=random.uniform(-.008,.008);width=random.uniform(.009,.018)
        verts=[(.105*ct,-.063+.093*st,.508),(.29*ct,-.063+.191*st,.365),(.27*ct,-.063+.192*st,end),(.27*ct-width*st,-.063+.192*st+width*ct,end+.018),(.29*ct-width*st,-.063+.191*st+width*ct,.365),(.105*ct-width*.3*st,-.063+.093*st+width*.3*ct,.508)]
        mesh('Split_reed_%02d'%j,verts,[(0,1,4,5),(1,2,3,4)],random.choice([reed,reed,reedlight,reeddark]),torso)
        if j%3==0:
            line('Broken_reed_tip',[(.27*ct,-.063+.19*st,end),(.28*ct,-.063+.20*st,end-.045-random.random()*.035)],.0035,reedlight,torso)
    for z,rx,ry in [(.402,.245,.158),(.34,.285,.19)]:
        pts=[(rx*math.cos(j*2*math.pi/32),-.065+ry*math.sin(j*2*math.pi/32),z+.012*math.cos(j)) for j in range(33)]
        line('Cross_woven_hemp_binding',pts,.004,reeddark,torso)
    # Tube quiver hollow mouth, dented cylinder, rolled lips and scarred bands.
    quiver=common.empty('Hip_brass_tube',(.185,.065,.12),torso);quiver.rotation_euler=(.13,-.21,-.08)
    loft('Dented_tube',[(-.25,0,0,.043,.045),(-.22,.005,0,.052,.045),(-.06,-.003,0,.046,.052),(.12,0,0,.055,.05)],brass,quiver,12)
    ell('Quiver_dark_opening',(0,0,.123),(.045,.041,.012),dark,quiver)
    for z in (-.235,-.16,.12):
        line('Rolled_brass_lip',[(.054*math.cos(j*2*math.pi/20),.050*math.sin(j*2*math.pi/20),z) for j in range(21)],.006,gold,quiver)
    for j in range(4):
        x=(j-1.5)*.018;y=.015 if j%2 else -.012;h=.23+.025*(j%3)
        rod('Fusée_hemp_shaft',(x,y,.08),(x,y,h),.008,wood,quiver)
        rod('Red_magnesium_head',(x,y,h-.045),(x,y,h),.013,fuse,quiver)
        for zz in (h-.043,h-.01):rod('Flare_paper_band',(x,y,zz),(x,y,zz+.005),.014,rope,quiver)
    wick=line('Smouldering_hip_fuse',[(.03,-.055,.11),(.064,-.063,.14),(.08,-.06,.15)],.006,fuse,quiver)
    ash=[]
    for j in range(3):ash.append(ell('Fuse_smoke_ash',(.08+j*.01,-.06,.18+j*.035),(.013+j*.005,.012+j*.004,.018),smoke,quiver))
    # Telescope at opposite hip: irregular brass tubes with dark glass and leather grip.
    scope=common.empty('Battered_telescope',(-.17,-.01,.035),torso);scope.rotation_euler=(0,.9,.3)
    rod('Telescope_main',(0,0,-.17),(0,0,.055),.031,brass,scope)
    rod('Telescope_drawtube',(0,0,.04),(0,0,.115),.024,gold,scope)
    rod('Telescope_leather_grip',(0,0,-.12),(0,0,-.04),.034,dark,scope)
    for z in (-.17,-.13,-.04,.06,.115):rod('Telescope_rim',(0,0,z),(0,0,z+.009),.036,copper,scope)
    ell('Telescope_clouded_glass',(0,0,.123),(.022,.022,.005),slate,scope)
    # Limb pivots: local Z is the long bone axis. Hands follow explicit archery constraints.
    limbs={}
    for side,x in [('L',-.085),('R',.085)]:
        thigh=common.empty(side+'_thigh',(x,0,.65),root)
        shin=common.empty(side+'_shin',(0,0,-.30),thigh)
        foot=common.empty(side+'_boot',(0,0,-.29),shin)
        loft(side+'_oilskin_trouser',[(-.30,0,0,.049,.055),(-.15,0,0,.057,.063),(0,0,0,.063,.067)],slate,thigh)
        loft(side+'_fisher_gaiter',[(-.30,0,0,.047,.06),(-.22,0,0,.059,.065),(-.04,0,0,.056,.057),(0,0,0,.06,.061)],dark,shin)
        loft(side+'_silt_waterline',[(-.29,0,-.004,.049,.065),(-.23,0,-.004,.061,.067),(-.11,0,-.003,.057,.06),(-.08,0,0,.05,.054)],mud,shin)
        ell(side+'_long_worn_boot',(0,-.037,.005),(.054,.10,.047),mud,foot)
        box(side+'_boot_sole',(0,-.043,-.025),(.105,.182,.024),dark,foot)
        for z in (-.055,-.13):line('Gaiter_tied_cord',[(-.052,-.025,z),(0,-.063,z-.005),(.052,-.025,z)],.006,rope,shin)
        for k in range(5):
            x0=random.uniform(-.039,.039);z=random.uniform(-.27,-.10)
            line('Vertical_silt_scar',[(x0,-.06,z),(x0+.005,-.065,z+.035)],.004,lightmud,shin)
        shoulder=common.empty(side+'_shoulder',(x*1.8,-.055,.36),torso)
        upper=loft(side+'_thin_sleeve',[(0,0,0,.054,.055),(.11,0,0,.047,.046),(.23,0,0,.039,.04)],slate,shoulder)
        elbow=common.empty(side+'_elbow',(0,0,.23),shoulder)
        loft(side+'_forearm_oilskin',[(0,0,0,.04,.04),(.13,0,0,.035,.033),(.22,0,0,.031,.03)],slate,elbow)
        for z in (.13,.175):loft('Leather_wrist_guard',[(z,0,0,.037,.034),(z+.018,0,0,.038,.035)],dark,elbow)
        hand=common.empty(side+'_hand',(0,0,.225),elbow)
        ell(side+'_gaunt_hand',(0,0,.01),(.033,.025,.055),skin,hand)
        for finger in range(3):
            line('Gloved_finger_seam',[(-.02+finger*.015,-.023,-.015),(-.019+finger*.015,-.023,.039)],.003,dark,hand)
        limbs[side]=(thigh,shin,foot,shoulder,elbow,hand)
    bow=common.empty('Longbow_hand_socket',(0,0,0),root)
    # Bow local -Y is shot direction. Physical stave curves forward; string runs behind.
    bowrods=[];bindings=[]
    for j in range(18):bowrods.append(rod('Blackened_longbow_limb_%02d'%j,(0,0,0),(0,0,.1),.016 if 6<=j<=11 else .011,wood,bow))
    for j in (1,4,7,10,13,16):bindings.append((j,rod('Verdigris_bow_binding',(0,0,0),(0,0,.02),.019,copper,bow)))
    grip=rod('Hemp_bound_grip',(0,0,-.08),(0,0,.08),.025,dark,bow)
    for z in (-.07,-.035,0,.035,.07):line('Grip_copper_wire',[(-.021,-.007,z),(.02,-.007,z+.013)],.003,copper,bow)
    strings=[rod('Emissive_hemp_bowstring_upper',(0,0,0),(0,0,.1),.006,fuse,bow),rod('Emissive_hemp_bowstring_lower',(0,0,0),(0,0,.1),.006,fuse,bow)]
    arrow=common.empty('Nocked_arrow',(0,0,0),bow)
    rod('Arrow_shaft',(0,.21,0),(0,-.48,0),.005,reedlight,arrow)
    mesh('Arrow_iron_point',[(0,-.58,0),(-.025,-.47,0),(.025,-.47,0),(0,-.47,.013)],[(0,1,3),(0,3,2),(0,2,1)],dark,arrow)
    for x in (-.018,.018):mesh('Arrow_fletching',[(0,.20,0),(x,.18,.028),(x,.09,.025),(0,.065,0)],[(0,1,2,3)],rope,arrow)
    flarehead=rod('Loaded_flare_head',(0,-.48,0),(0,-.55,0),.018,fuse,arrow)
    weight=ell('Net_lead_weight',(0,-.51,0),(.025,.042,.026),dark,arrow)
    netroot=common.empty('Unrolling_fishing_net',parent=limbs['R'][5]);nets=[]
    for j in range(6):
        pts=[((j-2.5)*.028,-.01+.016*math.sin(k+j),-.02-k*.043) for k in range(7)]
        nets.append(line('Knotted_net_warp',pts,.003,rope,netroot))
    for k in range(7):
        pts=[((j-2.5)*.028,-.01+.016*math.sin(k+j),-.02-k*.043) for j in range(6)]
        nets.append(line('Knotted_net_weft',pts,.003,rope,netroot))
    for x in (-.07,.07):ell('Net_lead_sinkers',(x,-.01,-.29),(.011,.01,.018),dark,netroot)
    drops=[]
    for j in range(5):drops.append(ell('Reed_rain_drop',(0,0,0),(.004,.004,.014),seam,root))

    def aim(ob,vector):ob.rotation_euler=Vector(vector).to_track_quat('Z','Y').to_euler()
    def local_world(ob):
        bpy.context.view_layer.update();return ob.matrix_world.translation.copy()
    def visibility(ob,on):
        ob.hide_render=not on;ob.keyframe_insert('hide_render')
        for child in ob.children_recursive:child.hide_render=not on;child.keyframe_insert('hide_render')
    def pose(a,f,n):
        t=f/n;tau=t*math.tau;breath=math.sin(tau)
        root.location=(0,0,0);root.rotation_euler=(0,0,0)
        torso.location=(0,-.012,.65+.005*breath);torso.rotation_euler=(.075,0,.012*breath)
        head.rotation_euler=(-.035,.025*breath,-.035)
        for side,(thigh,shin,foot,sh,el,hand) in limbs.items():
            thigh.rotation_euler=(0,0,0);shin.rotation_euler=(0,0,0);foot.rotation_euler=(0,0,0)
        bow.location=(-.24,-.14,.78);bow.rotation_euler=(0,.06,-.15)
        pull=.08;shoot=a in ('brace','attack','draw','flare','net','volley')
        if a=='run':
            step=math.sin(tau);torso.location.z+=.015*math.cos(2*tau)
            torso.rotation_euler.x=.15;torso.rotation_euler.z=.045*step
            for side,sign in [('L',1),('R',-1)]:
                thigh,shin,foot,*_=limbs[side]
                thigh.rotation_euler.x=.63*step*sign
                shin.rotation_euler.x=-max(0,-step*sign)*.85
                foot.rotation_euler.x=-.12*step*sign
            bow.location=(-.25,-.13,.72+.025*math.cos(2*tau));bow.rotation_euler=(.18,.26,-.22+.04*step)
        if shoot:
            impact=IMPACTS.get(a,99)
            if a=='brace':pull=.23+.004*breath
            elif f<impact:pull=.12+.31*(f/max(1,impact-1))
            else:pull=.025+(.04 if f==impact else .015)*(-1 if f%2 else 1)
            if a=='attack' and f<impact:pull=.16+.10*f
            if a=='net' and f<impact:pull=.30+.07*f
            bow.location=(-.16,-.37,.89)
            bow.rotation_euler=(0,.98,0)
            torso.rotation_euler.z=-.11-(.06 if f<impact else -.035)
            limbs['L'][0].rotation_euler.x=.16;limbs['R'][0].rotation_euler.x=-.18
            torso.location.y=-.018
            if a=='volley':
                bow.location=(-.16,-.23,.92)
                bow.rotation_euler=(-1.10,0,0)
                torso.rotation_euler.x=-.09
                head.rotation_euler.x=-.25
            if a=='draw':torso.rotation_euler.y=-.045*(f<impact)
            if a=='flare':head.rotation_euler.z=.05
        if a=='death':
            t=f/(n-1);fall=t*t*(3-2*t)
            torso.location.z=.65-.45*fall;torso.location.y=.03+.12*fall
            torso.rotation_euler=(.08-1.53*fall,.12*fall,.25*fall)
            head.rotation_euler=(.15*fall,-.22*fall,.25*fall)
            for side,sgn in [('L',-1),('R',1)]:
                limbs[side][0].rotation_euler=(.25*fall,sgn*.34*fall,sgn*.15*fall)
                limbs[side][1].rotation_euler=(-1.22*fall,0,0)
            bow.location=(-.24+.14*fall,-.17-.09*fall,.78-.71*fall)
            bow.rotation_euler=(.08*fall,1.56*fall,-.4*fall)
        bpy.context.view_layer.update()
        # Match left gripping hand to stave, right draw hand to the middle of the string.
        targetL=bow.matrix_world@Vector((0,0,0))
        targetR=bow.matrix_world@Vector((0,pull,0))
        for side,target in [('L',targetL),('R',targetR)]:
            thigh,shin,foot,sh,el,hand=limbs[side]
            shoulder=sh.matrix_world.translation.copy()
            if a=='death' and f>=3:
                target=shoulder+Vector((-.12 if side=='L' else .16,-.13,-.23))
            vec=target-shoulder
            # Two-bone solution with outward elbow (real length, no stretching).
            l1=.23;l2=.225;dist=min(.45,max(.075,vec.length));direction=vec.normalized()
            middle=shoulder+direction*(dist/2)
            pole=Vector((-.05 if side=='L' else .20,.11,.05 if side=='L' else .035))
            pole-=direction*pole.dot(direction);pole.normalize()
            elbowpos=middle+pole*math.sqrt(max(.0001,l1*l1-(dist/2)**2))
            parent=sh.parent.matrix_world
            aim(sh,parent.inverted().to_3x3()@(elbowpos-shoulder))
            bpy.context.view_layer.update()
            aim(el,sh.matrix_world.inverted().to_3x3()@(target-el.matrix_world.translation))
        bpy.context.view_layer.update()
        # Bow flex and reactive string: red core remains in the emission AOV at every pose.
        points=[]
        for j in range(19):
            z=-.76+j*1.52/18
            y=.15*(abs(z)/.76)**1.6+.12*(pull/.43)*(abs(z)/.76)**2
            points.append(Vector((0,y,z)))
        for j,ob in enumerate(bowrods):segment(ob,points[j],points[j+1])
        for j,ob in bindings:
            d=(points[j+1]-points[j]).normalized()*.018;segment(ob,points[j]-d,points[j]+d)
        segment(strings[0],points[-1],(0,pull,0));segment(strings[1],(0,pull,0),points[0])
        arrow.location=(0,pull,0)
        visibility(arrow,shoot and (a=='brace' or f<IMPACTS[a]))
        visibility(flarehead,a=='flare' and f<IMPACTS['flare'])
        visibility(weight,a=='net' and f<IMPACTS['net'])
        visibility(netroot,a=='net')
        netroot.scale=(1,1,.35+1.05*f/max(1,n-1))
        for j,ob in enumerate(ash):
            ob.location=(.08+j*.01+.01*math.sin(tau+j),-.06,.18+j*.035+.02*t)
            ob.scale=(.013+j*.005,.012+j*.004,.018)
        for j,ob in enumerate(drops):
            phase=(t+j*.21)%1;angle=j*2.3
            ob.location=(math.cos(angle)*.27,.02+math.sin(angle)*.16,.86-phase*.38)
            ob.scale=(.004,.004,.014*(.75+phase*.7))
        for ob in [root,torso,head,bow,arrow,netroot,*ash,*drops,*bowrods,*strings,*[o for _,o in bindings],*[o for ls in limbs.values() for o in ls]]:
            ob.keyframe_insert('location');ob.keyframe_insert('rotation_euler');ob.keyframe_insert('scale')
    for ai,(a,n) in enumerate(ANIMS.items()):
        start=ai*20+1;s.timeline_markers.new(a,frame=start)
        for f in range(n):s.frame_set(start+f);pose(a,f,n)
    s.frame_start=1;s.frame_end=167
    s['VG1_manifest']=json.dumps(manifest());s['VG1_rig']='Articulated object rig; camera CREA; all nine actions baked at 20-frame intervals'
    # CEL material conversion, no normal output nodes or screen-normal conversion.
    cel.install('creature',normals=False)
    cel.setup_scene(s);cel.toon_materials('creature')
    def accent_base(path):
        tree=getattr(s,'node_tree',None)
        if tree is None:
            tree=bpy.data.node_groups.new('Vigie_CEL','CompositorNodeTree');s.compositing_node_group=tree
        tree.nodes.clear();nodes=tree.nodes;links=tree.links
        if not any(x.name=='Image' and x.in_out=='OUTPUT' for x in tree.interface.items_tree):tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
        rl=nodes.new('CompositorNodeRLayers');out=nodes.new('NodeGroupOutput');links.new(rl.outputs['Image'],out.inputs['Image'])
        file=nodes.new('CompositorNodeOutputFile')
        file.directory=str(path.parent);file.file_name=path.stem+'_e__';file.file_output_items.new('RGBA','Image')
        file.format.media_type='IMAGE';file.format.file_format='PNG';file.format.color_mode='RGBA';file.format.color_depth='8'
        links.new(rl.outputs[cel.AOV],file.inputs[0])
    output=RAW/'current.png'
    cel.cel_passes(output,'creature',base_configure=accent_base,normals=False)
    SOURCE.parent.mkdir(parents=True,exist_ok=True)
    s.frame_set(1);bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    # Validate projected geometry before spending time on renders. Same exact camera/pivot.
    invcam=s.camera.matrix_world.inverted(); worst=(999,None)
    for ai,(a,n) in enumerate(ANIMS.items()):
        for d in DIRS:
            for f in range(n):
                s.frame_set(ai*20+1+f);facing.rotation_euler.z=common.DIRECTIONS[d]
                bpy.context.view_layer.update()
                for ob in s.objects:
                    if ob.type not in ('MESH','CURVE') or ob.hide_render:continue
                    transform=invcam@ob.matrix_world
                    for corner in ob.bound_box:
                        co=transform@Vector(corner)
                        x=96+iso_rig.R*co.x;y=136.32-iso_rig.R*co.y
                        margin=min(x,y,192-x,192-y)
                        if margin<worst[0]:worst=(margin,(a,d,f,ob.name))
    print('VG1 GEOMETRY MARGIN',round(worst[0],2),worst[1],flush=True)
    assert worst[0]>=3,worst
    from PIL import Image
    for ai,(a,n) in enumerate(ANIMS.items()):
        completed=0
        for row,d in enumerate(DIRS):
            for f in range(n):
                p=RAW/f'{a}_{d}_{f:02d}.png';e=p.with_name(p.stem+'_e.png')
                if p.exists() and e.exists():completed+=1;continue
                s.frame_set(ai*20+1+f)
                facing.rotation_euler.z=common.DIRECTIONS[d]
                bpy.context.view_layer.update()
                s.render.filepath=str(output)
                bpy.ops.render.render(write_still=True)
                accents=list(RAW.glob('current_e__*.png'));assert len(accents)==1
                for src,target in ((output,p),(accents[0],e)):
                    with Image.open(src) as im:final=im.convert('RGBA').resize((CELL,CELL),Image.Resampling.LANCZOS)
                    final.save(target,compress_level=3)
                    src.unlink()
                completed+=1
        print('VG1 RENDER '+a+' '+str(completed)+'/'+str(n*8),flush=True)
    finish()

if __name__=='__main__':
    if '--render' in sys.argv:build()
    elif '--finish' in sys.argv:finish()
    elif '--verify' in sys.argv:verify()
    elif '--audit' in sys.argv:
        import bpy
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
        for fr in (1,21,41,61,81,101,121,141,166):
            bpy.context.scene.frame_set(fr)
            print('AUDIT',fr,[(n,tuple(round(v,3) for v in bpy.data.objects[n].location)) for n in ('Longbow_hand_socket','Stooped_spine')],flush=True)
        from bpy_extras.object_utils import world_to_camera_view
        from mathutils import Vector
        bpy.context.scene.frame_set(61)
        bpy.data.objects['Vigie_facing_8_directions'].rotation_euler.z=3*math.pi/4
        bpy.context.view_layer.update()
        vals=[]
        for ob in bpy.context.scene.objects:
            if ob.type=='MESH' and not ob.hide_render:
                top=min(192*(1-world_to_camera_view(bpy.context.scene,bpy.context.scene.camera,ob.matrix_world@Vector(c)).y) for c in ob.bound_box)
                vals.append((round(top,2),ob.name))
        print('TOP OFFENDERS',sorted(vals)[:8],flush=True)
        print('BOW ROT',list(bpy.data.objects['Longbow_hand_socket'].rotation_euler),flush=True)
    else:print(__doc__)
