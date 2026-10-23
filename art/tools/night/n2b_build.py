"""N2b moss_mantis. Background Blender sculpt/render; system Python --pack/--verify.
Reuses R8/R9 materials, normal/emission passes, camera, and SpriteFrames contract.
"""
import sys, math, json, random, re
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT/'game/assets/sprites/bosses/mini/moss_mantis'
SOURCE = ROOT/'art/blender/monsters/n2b_moss_mantis.blend'
FRAMES = ROOT/'art/blender/monsters/n2b_frames'
ANIMS = {'idle':(1,6),'run':(21,8),'attack':(41,6),'cast_a':(61,8),'cast_b':(81,8),'phase2':(101,8),'death':(121,10)}
DIRS = {a: ['e','s','w','n'] if a in ('run','attack','cast_a','cast_b') else ['s'] for a in ANIMS}

def pack():
    from PIL import Image
    OUT.mkdir(parents=True,exist_ok=True)
    stats={}; preview=[]
    for a,(_,n) in ANIMS.items():
        groups = [(a,['e','s','w','n'])] if a=='run' else [(a,['s'])]
        if a in ('attack','cast_a','cast_b'): groups.append((a+'_dirs',['e','w','n']))
        for name,ds in groups:
            for suffix in ('','_n','_e'):
                sheet=Image.new('RGBA',(170*n,170*len(ds)),(128,128,255,0) if suffix=='_n' else (0,0,0,0))
                for row,d in enumerate(ds):
                    for i in range(n):
                        with Image.open(FRAMES/a/f'{d}_{i:02}{suffix}.png') as raw:
                            im=raw.convert('RGBA').resize((170,170),Image.Resampling.LANCZOS)
                        sheet.paste(im,(i*170,row*170))
                sheet.save(OUT/f'{name}{suffix}.png',compress_level=9)
                stats[name+suffix]=list(sheet.size)
    tres=(ROOT/'game/assets/sprites/bosses/mini/frost_bear/frost_bear.tres').read_text(encoding='utf-8').replace('frost_bear','moss_mantis')
    # R9 kept the old cast looping flag. The N2 contract explicitly requires one shot casts.
    tres=re.sub(r'"loop": true,(\s*"name": &"cast_[ab]_[eswn]")',r'"loop": false,\1',tres)
    (OUT/'moss_mantis.tres').write_text(tres,encoding='utf-8')
    # One final contact, including approved references; no painting or drawing in Pillow.
    rows=[]
    for a in ANIMS:
        ds=DIRS[a]
        for d in ds:
            ids=[0, len(range(ANIMS[a][1]))//2, ANIMS[a][1]-1]
            row=Image.new('RGBA',(170*6,170),(28,32,32,255))
            for col,i in enumerate(ids):
                for offset,suf in ((0,''),(3,'_n')):
                    with Image.open(FRAMES/a/f'{d}_{i:02}{suf}.png') as raw:
                        im=raw.convert('RGBA').resize((170,170),Image.Resampling.LANCZOS)
                    row.alpha_composite(im,((col+offset)*170,0))
            rows.append(row)
    refs=Image.new('RGBA',(1020,170),(28,32,32,255))
    for col,p in enumerate(['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png']):
        with Image.open(ROOT/p) as src:
            # Reference excerpt rather than unreadable downscaled full production sheets.
            im=src.convert('RGBA').crop((0,0,min(src.width,510),min(src.height,340)))
            im.thumbnail((340,170),Image.Resampling.LANCZOS)
            refs.alpha_composite(im,(col*340,0))
    rows.append(refs)
    contact=Image.new('RGBA',(1020,170*len(rows)),(28,32,32,255))
    for j,row in enumerate(rows):contact.paste(row,(0,j*170))
    contact.save(HERE/'_n2b_contact.png',compress_level=9)
    (HERE/'_n2b_atlases.json').write_text(json.dumps(stats,indent=2))
    print('PASS pack: 30 atlases, 19 animations; contact rows idle/run ESWN/attack ESWN/cast_a ESWN/cast_b ESWN/phase2/death/references')

def verify():
    from PIL import Image, ImageChops
    text=(OUT/'moss_mantis.tres').read_text(encoding='utf-8')
    expected={f'{a}_{d}' for a in ANIMS for d in DIRS[a]}
    assert set(re.findall(r'"name": &"([^"]+)"',text))==expected
    assert len(re.findall(r'\[sub_resource type="AtlasTexture"',text))==144
    for loop,name in re.findall(r'"loop": (true|false),\s*"name": &"([^"]+)"',text):
        assert (loop=='true')==name.startswith(('idle_','run_')),name
    animations=0; clipped=[]; empty=[]; mismatches=[]
    for a,(_,n) in ANIMS.items():
        for d in DIRS[a]:
            animations+=1
            for i in range(n):
                ims=[]
                for suf in ('','_n','_e'):
                    with Image.open(FRAMES/a/f'{d}_{i:02}{suf}.png') as raw:ims.append(raw.convert('RGBA'))
                alpha=ims[0].getchannel('A'); box=alpha.getbbox()
                if box is None:empty.append([a,d,i])
                elif min(box[0],box[1],340-box[2],340-box[3])<8:clipped.append([a,d,i,box])
                if any(ImageChops.difference(alpha,im.getchannel('A')).getbbox() for im in ims[1:]):mismatches.append([a,d,i])
    sizes={}
    for p in OUT.glob('*.png'):
        with Image.open(p) as im:
            assert max(im.size)<=4096
            sizes[p.name]=im.size
    assert animations==19 and not empty and not mismatches,(empty,mismatches)
    result={'animations':animations,'frames':sum(n*len(DIRS[a]) for a,(_,n) in ANIMS.items()),'clipped_frames':clipped,'empty':empty,'alpha_mismatches':mismatches,'atlases':sizes,'pivot':[85,119],'camera_scale':4.051028251647949,'impact':{'attack':3,'cast_a':4,'cast_b':4}}
    (HERE/'_n2b_verification.json').write_text(json.dumps(result,indent=2))
    assert not clipped,clipped[:4]
    print('PASS verify: 19 animations, 144 frames, matching alpha, >=4px margins, textures <=4096')

def build_render():
    import bpy
    sys.path.insert(0,str(ROOT/'art/tools/monsters'))
    from ash_lord_build import worn, rod, mesh, plate, shard
    from boss_pipeline import empty, material, key, pose, passes
    from mathutils import Vector
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/monsters/frost_bear.blend'))
    s=bpy.context.scene
    # Keep the exact R9 camera, world and studio lighting, remove the previous creature.
    for o in list(s.objects):
        if o.type not in ('CAMERA','LIGHT'):bpy.data.objects.remove(o,do_unlink=True)
    s.render.resolution_x=s.render.resolution_y=340
    s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=12
    s.render.threads_mode='FIXED';s.render.threads=8
    s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
    s.render.film_transparent=True;s.use_nodes=False
    if hasattr(s,'compositing_node_group'):s.compositing_node_group=None
    s.camera.data.ortho_scale=4.051028251647949;s.camera.data.shift_y=.2
    bark=worn('N2B rain split hardwood','211F1A','686250',0,.83)
    edge=worn('N2B polished deadwood cutting edge','4C4839','A29A78',0,.55)
    shell=worn('N2B black olive chitin','1C2520','586153',.18,.64)
    moss=worn('N2B damp lichen mats','26352B','66715A',0,.96)
    pale=worn('N2B grey parasitic lichen','424A40','949582',0,.92)
    sinew=worn('N2B exposed dry ligaments','302C21','81785B',0,.73)
    recess=worn('N2B deep sutures','0C100E','222A24',0,.9)
    eye=material('N2B slit eyes - single sulphur accent','C6AD57',2.1,True)
    root=empty('N2B_MossMantis');body=empty('N2B_Thorax',parent=root)
    # Narrow rising thorax and overlapping keel plates, never spherical primitive anatomy.
    rod('Serrated wood sternum',[(0,.13,.65),(0,.1,1.0),(0,.015,1.4),(0,-.04,1.83)],.14,bark,body)
    for j in range(8):
        z=.84+j*.123;w=.12+.055*math.sin(j*.38)
        plate('Thoracic overlapping shield',[(-w,z-.06),(w,z-.06),(w*.87,z+.06),(0,z+.1),(-w*.87,z+.06)],-.105,.24,shell,body)
        rod('Median raised ridge',[(0,-.12,z-.05),(0,-.16,z+.045)],.018,edge,body)
    abdomen=empty('N2B_Abdomen',(0,.16,1.02),body)
    # Long pointed folded elytra, with split edges, asymmetric fungal shingles.
    for j in range(9):
        y=j*.108;w=.32*(1-j/11);z=.12-j*.022
        verts=[(-w,y,z),(0,y-.055,z+.13),(w,y,z),(w*.8,y+.16,z-.04),(0,y+.22,z+.06),(-w*.8,y+.16,z-.04),(0,y+.08,z-.18)]
        mesh('Imbricated elytron',verts,[(0,1,4,5),(1,2,3,4),(0,5,6),(5,4,3,6),(3,2,6),(2,1,0,6)],shell,abdomen,.008)
        rod('Wing longitudinal vein',[(-w*.65,y,z+.055),(0,y+.1,z+.115),(w*.65,y,z+.055)],.012,bark,abdomen)
    head=empty('N2B_Head',(0,-.07,1.89),body)
    verts=[(-.29,-.10,.13),(.29,-.10,.13),(0,-.18,-.19),(-.22,.10,.09),(.22,.10,.09),(0,.06,-.12)]
    mesh('Inverted triangular predatory mask',verts,[(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)],shell,head,.012)
    for sign in (-1,1):
        rod('Recessed orbital brow',[(sign*.075,-.15,.09),(sign*.25,-.12,.12)],.037,bark,head)
        rod('Narrow sulphur eye slit',[(sign*.11,-.163,.079),(sign*.23,-.145,.105)],.015,eye,head)
        rod('Closed serrated mandible',[(sign*.055,-.14,-.1),(sign*.085,-.22,-.18),(sign*.013,-.24,-.215)],.025,edge,head)
        rod('Broken feeler',[(sign*.17,0,.15),(sign*.25,.03,.39),(sign*.34,.07,.48 if sign==1 else .36)],.012,bark,head)
    arms=[];forearms=[]
    for sign in (-1,1):
        arm=empty('N2B_RaptorialShoulder',(.18*sign,-.015,1.62),body);arms.append((arm,sign))
        rod('Fibrous upper raptor arm',[(0,0,0),(sign*.35,-.06,-.22),(sign*.52,-.20,-.43)],.065,bark,arm)
        rod('Tensioned flexor tendon',[(sign*.07,-.055,-.02),(sign*.46,-.24,-.35)],.023,sinew,arm)
        fore=empty('N2B_FoldingScythe',(sign*.52,-.20,-.43),arm);forearms.append((fore,sign))
        # Blade curves forward then inward: broad root, knife edge and hooked fine tip.
        pts=[(0,0,0),(sign*.15,-.11,-.20),(sign*.25,-.26,-.47),(sign*.20,-.43,-.68),(sign*.045,-.61,-.81),(-sign*.10,-.64,-.81)]
        rod('Recurved deadwood scythe',pts,.105,bark,fore)
        rod('Honed ivory wood edge',[(x-sign*.045,y-.04,z+.015) for x,y,z in pts[1:]],.028,edge,fore)
        for j in range(5):
            x,y,z=pts[min(1+j//2,4)]
            rod('Blade inner saw tooth',[(x-sign*.065,y-.035,z),(x-sign*(.16 if j%2 else .13),y-.07,z+.065)],.022,edge,fore)
    legs=[]
    for k in range(2):
        for sign in (-1,1):
            leg=empty('N2B_WalkingLeg',(sign*.14,.18+k*.29,.84-k*.11),body)
            legs.append((leg,sign,k))
            pts=[(0,0,0),(sign*.48,.05,-.10),(sign*.77,.16 if k else -.27,-.45),(sign*.86,.22 if k else -.43,-.78+k*.11)]
            rod('Angular femur',pts[:2],.064,shell,leg)
            rod('Dry tibia',pts[1:],.035,bark,leg)
            rod('Hooked claw tarsus',[pts[-1],(sign*.98,pts[-1][1]-.08,-.83+k*.11)],.022,edge,leg)
            for j in range(3):
                p=Vector(pts[1]).lerp(Vector(pts[2]),(j+1)/4)
                rod('Tibial thorn',[p,p+Vector((sign*.07,-.035,.02))],.014,edge,leg)
    rng=random.Random(247)
    # Small jagged leaf blades and peeling lichen plates cling to the back, not fluffy balls.
    for j in range(68):
        y=rng.uniform(.13,.93);x=rng.uniform(-.19,.19)*(1.1-y*.45);z=1.20-y*.16
        w=rng.uniform(.035,.085);h=rng.uniform(.06,.15)
        ob=plate('Ragged rain lichen',[(-w,0),(0,h),(w*.45,h*.48),(w,0),(0,-.025)],0,.016,pale if j%9==0 else moss,abdomen)
        ob.location=(x,y-.16,z-1.02);ob.rotation_euler=(rng.uniform(-.5,.5),rng.uniform(-.5,.5),rng.uniform(-math.pi,math.pi))
    for j in range(18):
        sign=-1 if j%2 else 1;z=.98+j*.047
        rod('Splintered dorsal moss spur',[(sign*.12,.15,z),(sign*(.2+rng.random()*.1),.20,z+.1)],.022,moss,body)
    def animate(a,i,n,f):
        t=i*math.tau/n;p=i/(n-1);impact=i==n//2
        strike = [0,-.35,-.65,1.0,.35,0][i] if a=='attack' else ([0,-.2,-.45,-.65,1,.55,.2,0][i] if a=='cast_a' else 0)
        crouch = [0,.2,.45,.58,-.2,-.08,.12,0][i] if a=='cast_b' else 0
        dead=p if a=='death' else 0
        body.location=(-.15*dead,-.22 if a=='cast_b' and impact else .10*max(0,-strike),(.025*math.sin(2*t) if a=='run' else .012*math.sin(t))-.28*crouch-.35*dead)
        if a=='cast_b' and i in (4,5):
            body.location.y=-.18 if i==4 else -.10
            body.location.z=.40 if i==4 else .18
        body.rotation_euler=(.12*strike-.28*crouch,.5*dead,(-.17*strike if a=='attack' else .015*math.sin(t)))
        body.scale=(1,1,1);key(body,f)
        abdomen.rotation_euler=(.08*math.sin(t)+(.27*p if a=='phase2' else 0),0,-.12*strike);key(abdomen,f)
        head.rotation_euler=(.1*strike-.18*crouch,0,.05*math.sin(t));key(head,f)
        for arm,sign in arms:
            arm.rotation_euler=(-.65*strike-.55*crouch+.8*dead,sign*(.25*strike+.4*dead),sign*(.4*strike if a=='cast_a' else -.15*max(0,-strike)))
            if a=='cast_b' and impact:arm.rotation_euler.x=-.8
            if a=='phase2':arm.rotation_euler.z=sign*(-.28*p)
            key(arm,f)
        for fore,sign in forearms:
            fore.rotation_euler=(.9*strike+.65*crouch,0,sign*(-.7*strike if a=='cast_a' else .12*strike))
            key(fore,f)
        for leg,sign,k in legs:
            swing=math.sin(t+(math.pi if (sign>0) != bool(k) else 0)) if a=='run' else 0
            leg.rotation_euler=(.36*swing+.2*crouch+.4*dead,sign*(.1*max(0,swing)-.65*dead),sign*.12*swing)
            if a=='cast_b' and impact:leg.rotation_euler.x=-.5 if k==0 else .5
            key(leg,f)
    for a,(start,n) in ANIMS.items():
        for i in range(n):animate(a,i,n,start+i)
        s.timeline_markers.new(a,frame=start)
    s['N2B_contract']=json.dumps({'pivot':[85,119],'frame':170,'impact_indices':[3,4,4],'design':'deadwood raptorial mantis; damp black chitin; ragged grey olive lichen; sulphur eye slits'})
    s.frame_start=1;s.frame_end=130
    pose(root,1,'s');bpy.context.preferences.filepaths.save_version=0
    SOURCE.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    if '--build-only' in sys.argv:return
    for a,(start,n) in ANIMS.items():
        if '--death-only' in sys.argv and a!='death':continue
        if '--cast-b-only' in sys.argv and a!='cast_b':continue
        folder=FRAMES/a;folder.mkdir(parents=True,exist_ok=True)
        for d in DIRS[a]:
            for i in range(n):
                pose(root,start+i,d);p=folder/f'{d}_{i:02}.png'
                if '--resume' in sys.argv and all(p.with_stem(p.stem+x).exists() for x in ('','_n','_e')):continue
                s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
                passes.render_normal_pass(p.with_stem(p.stem+'_n'),p,s)
                passes.render_emission_pass(p.with_stem(p.stem+'_e'),p,s)
            print('N2B_DONE',a,d,flush=True)
    print('N2B_RENDER_PASS',flush=True)

if __name__=='__main__':
    if '--pack' in sys.argv:pack()
    elif '--verify' in sys.argv:verify()
    else:build_render()
