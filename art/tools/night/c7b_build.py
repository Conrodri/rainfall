"""C7b: new haunted blackwood stag; background Blender, legacy grid/pivot, CREA 30deg.
Reuses C7a timeline/atlas pipeline, official worn shaders, Blender passes and legacy mist shader.
Run Blender --background --python this.py. Temporary frames are removed on success.
"""
import sys, math, json, re, tempfile, hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
sys.path[:0]=[str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools/bosses'),str(ROOT/'art/tools/iso')]
sys.path[:0]=[str(ROOT/'art/tools/iso/_deps'),str(Path.home()/'AppData/Local/RainfallIsoDeps')]
import bpy
from mathutils import Vector
from PIL import Image
import boss_common as c
import cerf as legacy
import iso_rig
from ash_lord_build import worn, plate, mesh, rod as branch

DST=ROOT/'game/assets/sprites/bosses/etage/cerf'
INV=json.loads((HERE/'_c7b_inventory.json').read_text())
COUNTS={k:v[0] for k,v in legacy.SPECS.items()}
EXTRAS={'antlers','wisp','wisp_explode','ground_mist','ground_wisp_trail'}


# C7a source/timeline and SpriteFrames append machinery, adapted for Cerf.
def save_source(root,pose):
    s=bpy.context.scene;f=1
    for anim in [a for a in COUNTS if a not in EXTRAS]:
        n=COUNTS[anim];s.timeline_markers.new(anim,frame=f)
        for i in range(n):
            pose(anim,i,n)
            for o in [root,*root.children_recursive]:
                for k in ('location','rotation_euler','scale','hide_render'):o.keyframe_insert(k,frame=f+i)
            for mat in bpy.data.materials:
                if not mat.use_nodes:continue
                for node in mat.node_tree.nodes:
                    if node.type=='VALUE':node.outputs[0].keyframe_insert('default_value',frame=f+i)
                    if node.type=='BSDF_PRINCIPLED':node.inputs['Emission Strength'].keyframe_insert('default_value',frame=f+i)
        f+=n+2
    s.frame_end=f;s.render.fps=12
    path=ROOT/'art/blender/monsters/cerf_iso.blend';path.parent.mkdir(parents=True,exist_ok=True)
    s.frame_set(1);bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path))
    for o in [root,*root.children_recursive]:o.animation_data_clear()
    for mat in bpy.data.materials:
        if mat.use_nodes:mat.node_tree.animation_data_clear()

def append_tres():
    t=INV['original_tres'];ext=[];subs=[];anims=[]
    for anim in ('auto','spell_a','spell_b'):
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/bosses/etage/cerf/{anim}_dirs.png" id="c7b_{anim}"]')
        ref=next(a for a in INV['animations'] if a['name']==anim+'_s')
        for row,d in enumerate(('e','w','n')):
            frames=[]
            for i in range(COUNTS[anim]):
                sid=f'C7b_{anim}_{d}_{i}'
                subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("c7b_{anim}")\nregion = Rect2({i*256}, {row*256}, 256, 256)')
                frames.append('{"duration": 1.0, "texture": SubResource("'+sid+'")}')
            anims.append('{"frames": ['+', '.join(frames)+'], "loop": '+str(ref['loop']).lower()+', "name": &"'+anim+'_'+d+'", "speed": '+str(ref['fps'])+'}')
    t=t.replace('[sub_resource', '\n\n'.join(ext)+'\n\n[sub_resource',1)
    t=t.replace('[resource]', '\n\n'.join(subs)+'\n\n[resource]',1)
    at=t.rfind(']');t=t[:at]+',\n'+',\n'.join(anims)+t[at:]
    t=re.sub(r'load_steps=(\d+)',lambda m:'load_steps='+str(int(m[1])+3+66),t,count=1)
    (DST/'cerf.tres').write_text(t,encoding='utf-8')


def setup(scale=5.1,cell=256,pivot=.20):
    s=iso_rig.create_rig('CREA',cell)
    s.eevee.taa_render_samples=16;s.camera.data.ortho_scale=scale
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,scale*pivot,0))
    s.render.image_settings.compression=100
    s['c7b_height_u']=3.2;s['c7b_pixels_per_u']=256/5.1;s['c7b_pivot']=[128,179.2]
    return s

def loft(name,sections,mat,parent):
    # Elliptical, offset anatomical rings; real mesh volumes, no stacked balls.
    verts=[];N=10
    for x,y,z,rx,rz in sections:
        verts.extend((x+rx*math.cos(j*math.tau/N),y,z+rz*math.sin(j*math.tau/N)) for j in range(N))
    faces=[tuple(range(N-1,-1,-1)),tuple(range((len(sections)-1)*N,len(sections)*N))]
    faces.extend((i*N+j,i*N+(j+1)%N,(i+1)*N+(j+1)%N,(i+1)*N+j) for i in range(len(sections)-1) for j in range(N))
    o=mesh(name,verts,faces,mat,parent)
    for p in o.data.polygons:p.use_smooth=True
    return o

def twig(name,points,r,mat,parent):
    # Tapered antler/blackwood ribs, seven-sided cross sections.
    o=branch(name,points,r,mat,parent)
    N=6
    for i in range(len(points)):
        fac=1-.91*(i/(len(points)-1))**1.5
        center=Vector(points[i])
        for v in o.data.vertices[i*N:(i+1)*N]:v.co=center+(v.co-center)*fac
    return o

def build():
    setup();root=c.empty('CERF_C7B_BLACKWOOD_RELIQUARY');body=c.empty('Thorax',(0,.10,1.42),root)
    bark=worn('Black drowned oak','111914','3E4435',.05,.83)
    ridge=worn('Split wet bark edges','263027','69705A',.03,.69)
    moss=worn('Forest moss #foret_brume','202A20','566044',0,.94)
    bone=worn('Old ash antler','42483D','9C9E86',.08,.66)
    iron=worn('Lantern forged iron','101A19','4B5C51',.72,.47)
    bronze=worn('Verdigris cage fittings','253D32','697B60',.65,.49)
    hoof=worn('Hoof black horn','0D1211','384139',.2,.43)
    mint=c.material('Wisp only accent #9CF0C8',(*legacy.linear('9CF0C8'),),.05,.4,1.5)
    mint.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.008,.018,.012,1)
    allm=[bark,ridge,moss,bone,iron,bronze,hoof,mint]
    for mat in allm:
        legacy.fade_material(mat,True)
        mat.surface_render_method='DITHERED'
    # Deep barrel chest pinched at the flanks; the back breaks into angular scapulae.
    loft('Ancient cervid thorax',[(0,-.69,.06,.19,.33),(0,-.47,.04,.40,.53),(0,-.10,.01,.38,.47),(0,.38,.03,.27,.32),(0,.72,.02,.29,.36),(0,.91,0,.14,.23)],bark,body)
    for side in (-1,1):
        for j in range(6):
            y=-.54+j*.20;z=.08+(.1 if j<2 else 0)
            twig('Exposed curved wooden rib',[(side*.15,y,z+.34),(side*.36,y-.04,z+.21),(side*.39,y-.02,z-.12),(side*.19,y+.04,z-.35)],.065,ridge,body)
        for j in range(3):
            plate('Riven scapular plate',[(side*.18,-.04),(side*.43,-.19),(side*.47,.20),(side*.31,.53),(side*.12,.35)],-.58+j*.15,.13,bark,body,.018)
        for j in range(4):
            twig('Moss hanging from shoulder',[(side*.35,-.42+j*.15,.23),(side*.42,-.37+j*.15,-.03),(side*.38,-.35+j*.15,-.24-j*.03)],.035,moss,body)
    for j in range(7):
        y=-.47+j*.20
        twig('Splintered dorsal crest',[(0,y,.35),(.035,y+.04,.55),(-.025,y+.15,.65-(j*.025))],.056,ridge,body)
    tail=c.empty('Shattered tail',(0,.88,.13),body)
    twig('Tail branch',[(0,0,0),(.09,.19,-.04),(.03,.37,-.21)],.08,bark,tail)
    neck=c.empty('Neck pivot',(0,-.52,.17),body)
    loft('Long withered neck',[(0,.06,.05,.27,.31),(0,-.05,.30,.23,.39),(0,-.26,.53,.19,.32),(0,-.40,.65,.13,.19)],bark,neck)
    for side in (-1,1):
        for j in range(3):
            twig('Tendon of split wood',[(side*.18,-.03,.15),(side*.18,-.16,.52),(side*.11,-.38,.74+j*.018)],.025,ridge,neck)
    head=c.empty('Narrow death mask',(0,-.43,.67),neck)
    loft('Carved cervid skull',[(0,.20,.02,.10,.15),(0,.08,.03,.20,.18),(0,-.12,-.01,.17,.16),(0,-.39,-.08,.09,.085),(0,-.57,-.09,.075,.07)],bone,head)
    loft('Recessed black nasal cleft',[(0,-.30,-.02,.028,.075),(0,-.50,-.045,.040,.047),(0,-.59,-.075,.049,.035)],hoof,head)
    lanterns=[];flames=[];phasebranches=[];ghost=[]
    for side in (-1,1):
        c.sphere('Hollow eye socket',(side*.164,-.12,.025),(.044,.097,.055),hoof,head)
        o=c.sphere('Narrow mint eye slit',(side*.192,-.15,.032),(.013,.050,.012),mint,head);flames.append(o)
        twig('Chiselled brow',[(side*.12,-.25,.10),(side*.21,-.11,.11),(side*.14,.04,.14)],.036,bark,head)
        ear=loft('Torn blade ear',[(side*.15,.12,.08,.035,.04),(side*.34,.16,.19,.09,.09),(side*.48,.22,.25,.005,.015)],bark,head)
        for j in range(4):
            twig('Lichen beard',[(side*(.04+j*.03),-.10,-.14),(side*(.08+j*.02),-.02,-.31),(side*(.03+j*.03),.04,-.50+j*.04)],.020,moss,head)
    crown=c.empty('Ramure',(0,.10,.14),head)
    for side in (-1,1):
        twig('Ancient main beam',[(side*.13,0,0),(side*.32,.13,.14),(side*.67,.20,.38),(side*1.00,.26,.57),(side*1.31,.33,.71)],.105,bone,crown)
        for j in range(4):
            x=.38+j*.23;y=.14+j*.045;z=.19+j*.15
            twig('Knife tine',[(side*x,y,z),(side*(x-.08),y+.06,z+.29),(side*(x+.03),y+.14,z+.295-(j*.045))],.049,bone,crown)
            twig('Black antler scar',[(side*x,y-.045,z),(side*(x+.08),y-.045,z+.12)],.023,bark,crown)
        # Asymmetric old growth appears in phase two.
        o=twig('New bifurcated spirit branch',[(side*.63,.22,.35),(side*.94,.43,.62),(side*1.19,.38,.65)],.058,bone,crown);phasebranches.append(o)
        for j in range(3):
            x=side*(.44+j*.33);y=.17+j*.07;z=.28+j*.15
            cage=c.empty('Hanging votive lantern',(x,y,z-.29-(j%2)*.10),crown);lanterns.append(cage)
            twig('Iron suspension',[(0,0,.29),(side*.03,0,.13),(0,0,.08)],.014,iron,cage)
            c.ring('Hammered upper cage rim',(0,0,.055),.093,.016,bronze,cage,rotation=(0,0,0))
            c.ring('Lower cage rim',(0,0,-.18),.072,.016,iron,cage,rotation=(0,0,0))
            for k in range(5):
                a=k*math.tau/5
                twig('Angular lantern bars',[(.065*math.cos(a),.065*math.sin(a),-.21),(.105*math.cos(a),.105*math.sin(a),-.04),(.07*math.cos(a),.07*math.sin(a),.09)],.014,iron,cage)
            f=loft('Captive wisp flame',[(0,0,-.17,.028,.012),(0,-.012,-.10,.046,.063),(.025,-.018,.003,.018,.057),(-.005,-.025,.07,.003,.004)],mint,cage);flames.append(f)
            twig('Lantern iron thorn',[(0,0,-.19),(0,0,-.31)],.025,iron,cage)
    legs=[]
    for front,y in ((True,-.46),(False,.70)):
        for side in (-1,1):
            leg=c.empty('Foreleg' if front else 'Hindleg',(side*(.27 if front else .25),y,-.10),body)
            # Four slender, correctly jointed load-bearing limbs and split hooves.
            knee=(side*.055,.03 if front else -.18,-.58)
            twig('Upper limb root',[(0,0,.09),(side*.035,0,-.25),knee],.085,bark,leg)
            c.sphere('Knotted knee',knee,(.078,.093,.095),ridge,leg)
            shin=c.empty('Shin pivot',knee,leg)
            twig('Long bare cannon bone',[(0,0,0),(side*.025,.08,-.36),(0,-.015,-.63)],.050,bone,shin)
            twig('Black shin tendon',[(side*.036,0,-.02),(side*.049,.06,-.41),(side*.028,-.07,-.63)],.023,bark,shin)
            for k in (-1,1):
                plate('Split black hoof',[(k*.012,-.69),(k*.012,-.55),(k*.075,-.58),(k*.093,-.69)],-.12,.20,hoof,shin,.01)
            legs.append((leg,shin,front,side))
    # Ghost phase exposes empty wicker ribs instead of just tinting the coat.
    for side in (-1,1):
        for j in range(4):
            o=twig('Phantom open rib',[(side*.16,-.35+j*.23,.30),(side*.48,-.32+j*.23,.08),(side*.38,-.27+j*.23,-.39)],.033,bone,body);ghost.append(o)
    mistmat=c.material('Brume #B8C8C0',legacy.linear('B8C8C0'),0,.95,.04)
    mistvis=legacy.fade_material(mistmat,False,.1);legacy.soften_mist(mistmat)
    mist=[]
    for j in range(9):
        a=j*2.39996;r=.25+(j%3)*.21
        mist.append(c.sphere('Low forest mist',(math.cos(a)*r,math.sin(a)*r,.045),(.40,.26,.045),mistmat,root))
    iso_rig.bake_ao_shadows(root)
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def pose(anim,i,n):
        for o,(l,r,sc) in rest.items():o.location=l;o.rotation_euler=r;o.scale=sc;o.hide_render=False
        root.location=(0,0,0);root.scale=(1,1,1)
        t=i/n;u=i/max(1,n-1);w=math.sin(math.tau*t)
        ph=1+u if anim=='trans_p2' else 2+u if anim=='trans_p3' else int(anim[-1]) if anim.startswith(('idle_p','walk_p')) else 3 if anim in ('death','vanish','reappear') else 1
        q=min(1,max(0,ph-1));spect=min(1,max(0,ph-2))
        visibility=1-u if anim in ('death','vanish') else u if anim=='reappear' else 1
        for mat in allm:
            mat.node_tree.nodes['Visibility'].outputs[0].default_value=visibility
            mat.node_tree.nodes['Spectral'].outputs[0].default_value=spect
        # Coat keeps its worn PBR texture in all phases.
        bone.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.66+.2*spect
        mint.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value=(1.5+.65*q)*(1-.985*spect)
        for o in phasebranches:o.scale=tuple(v*max(.001,q) for v in rest[o][2]);o.hide_render=q<.001
        for o in ghost:o.scale=tuple(v*max(.001,spect) for v in rest[o][2]);o.hide_render=spect<.001
        for o in lanterns:o.scale*=1+.32*q-.08*spect
        for j,f in enumerate(flames):f.scale*=max(.025,1-.94*spect);f.scale.z*=1+.15*math.sin(t*math.tau+j)
        for o in mist:o.hide_render=q<.001 or anim=='antlers'
        mistvis.default_value=.095*q*visibility
        body.location.z+=.026*w;neck.rotation_euler.x=.026*w;head.rotation_euler.z=.035*w
        tail.rotation_euler.z=.13*w
        for j,o in enumerate(lanterns):o.rotation_euler.y=.09*math.sin(math.tau*t+j*.8)
        if anim.startswith('walk'):
            body.location.z+=.055*math.cos(2*math.tau*t)
            for leg,shin,front,side in legs:
                a=math.tau*t+(0 if front==(side==1) else math.pi)
                leg.rotation_euler.x=.49*math.sin(a);shin.rotation_euler.x=-.53*max(0,math.cos(a));leg.location.z+=.06*max(0,math.cos(a))
            neck.rotation_euler.x=-.045*w
        if anim=='auto':
            body.location.z-=[0,.035,.16,.04,0,0][i]
            neck.rotation_euler.x=[0,-.40,-.73,.63,.24,0][i]
            head.rotation_euler.z=[0,.14,.30,-.44,-.12,0][i]
            crown.rotation_euler.z=[0,.14,.31,-.38,-.12,0][i]
            body.rotation_euler.x=[0,-.035,-.10,.14,.05,0][i]
        if anim=='spell_a':
            v=math.sin(math.pi*u);body.location.z-=.13*v;neck.rotation_euler.x=-.27*v;crown.rotation_euler.y=.19*math.sin(math.tau*u)
            for o in lanterns:o.rotation_euler.x=.45*v
            for f in flames:f.scale.z*=1+1.1*v
        if anim=='spell_b':
            v=math.sin(math.pi*u);body.location.z-=.05*v;body.rotation_euler.x=-.06*v
            for leg,shin,front,side in legs:
                if front:leg.rotation_euler.x=-.90*v;shin.rotation_euler.x=-.35*v
            neck.rotation_euler.x=-.12*v
        if anim=='death':
            body.location.z-=.78*u;body.rotation_euler.y=.64*u;neck.rotation_euler.x=.55*u
            for leg,shin,front,side in legs:leg.rotation_euler.x=(-.8 if front else .8)*u;shin.rotation_euler.x=-.8*u
        if anim in ('vanish','reappear'):
            body.location.z+=.12*(1-visibility);root.scale=(1-.12*(1-visibility),)*3
        if visibility<.0001:
            for o in root.children_recursive:o.hide_render=True
        if anim=='antlers':
            keep=set(flames)
            for o in root.children_recursive:
                if o.type in ('MESH','CURVE'):o.hide_render=o not in keep
            # Flame layer is exactly aligned to the idle_p1 timeline.
            for f in flames[:2]:f.hide_render=True
    return root,pose,None

def prop(anim):
    setup(3.8 if anim=='ground_mist' else 1.45,256 if anim=='ground_mist' else 64)
    if anim=='ground_mist':return legacy.prop(anim)
    root=c.empty('Unbound wisp')
    mat=c.material('Wisp #9CF0C8',legacy.linear('9CF0C8'),0,.65,1.8)
    mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.006,.014,.009,1)
    vis=legacy.fade_material(mat,True,.85);mat.node_tree.nodes['Spectral'].outputs[0].default_value=.7
    objects=[]
    for j in range(5):
        a=j*math.tau/5
        pts=[]
        for k in range(6):
            z=.07+k*.095;r=.105*(1-k/6);ang=a+k*.6
            pts.append((r*math.cos(ang),r*math.sin(ang),z))
        objects.append(twig('Torn spiral of soul',pts,.035 if j<3 else .020,mat,root))
    objects.append(loft('Hollow wisp core',[(0,.035,.14,.042,.07),(.02,-.015,.24,.068,.11),(-.02,-.035,.37,.019,.06),(0,-.04,.50,.002,.003)],mat,root))
    if anim=='ground_wisp_trail':
        for j in range(3):objects.append(c.sphere('Dying ember',((j-1)*.14,.05*j,.05),(.055,.025,.022),mat,root))
    rest=[(o,o.location.copy(),o.scale.copy()) for o in objects]
    def pose(t):
        u=t*8/7;w=math.sin(math.tau*t)
        vis.default_value=.85
        for j,(o,l,sc) in enumerate(rest):
            o.location=l;o.scale=sc;o.hide_render=False
            if anim=='wisp_explode':
                a=j*2.39996;o.location.x+=math.cos(a)*u*.32;o.location.y+=math.sin(a)*u*.32
                o.scale*=max(.001,1-u)*(1+.8*math.sin(math.pi*min(1,u)));vis.default_value=max(0,1-u)
                o.hide_render=u>=.999
            else:o.location.z+=.025*math.sin(math.tau*t+j*.7);o.rotation_euler.z=.20*w;o.scale.z*=1+.10*w
    return root,pose

def make_contact(frames):
    # Assembly only. Columns: idle / windup / impact / phase2 / phase3.
    board=Image.new('RGBA',(1728,1920),(31,38,36,255))
    for row,d in enumerate(('e','s','w','n')):
        for col,key in enumerate((f'idle_p1_{d}_0',f'auto_{d}_2',f'auto_{d}_3')):
            board.alpha_composite(frames[key],(col*256,row*256))
    for col,a in enumerate(('idle_p2','idle_p3')):
        for row,d in enumerate(('e','s','w','n')):
            board.alpha_composite(frames[f'{a}_{d}_0'],((col+3)*256,row*256))
    # Approved reference plates are sampled here; no separate image viewing.
    for row,name in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png')):
        im=Image.open(ROOT/name).convert('RGBA');im.thumbnail((416,320),Image.Resampling.LANCZOS)
        board.alpha_composite(im,(1300,row*336))
    for row,a in enumerate(('spell_a','spell_b','trans_p2','trans_p3','death','vanish','reappear')):
        n=COUNTS[a];sheet=Image.open(DST/f'{a}.png').convert('RGBA')
        for col,i in enumerate(sorted({0,n//2,n-1})):
            im=sheet.crop((i*256,0,(i+1)*256,256)).resize((128,128),Image.Resampling.LANCZOS)
            board.alpha_composite(im,(col*128,1024+row*128))
    for j,a in enumerate(('antlers','ground_mist','wisp','wisp_explode','ground_wisp_trail')):
        size=64 if a in ('wisp','wisp_explode','ground_wisp_trail') else 256
        sheet=Image.open(DST/f'{a}.png').convert('RGBA');im=sheet.crop((0,0,size,size))
        board.alpha_composite(im,(448+j*256,1100))
    # Worn materials and normal/emission passes at native pixel size.
    for col,(a,sf) in enumerate((('idle_p1',''),('idle_p1','_n'),('idle_p1','_e'),('idle_p2',''),('idle_p3',''))):
        im=Image.open(DST/f'{a}{sf}.png').convert('RGBA').crop((0,0,256,256))
        board.alpha_composite(im,(448+col*256,1400))
    ard=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA').crop((0,384,192,576))
    ard=ard.resize((106,106),Image.Resampling.LANCZOS)
    ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/idle.png').convert('RGBA').crop((0,0,170,170)).resize((195,195),Image.Resampling.LANCZOS)
    board.alpha_composite(frames['idle_p1_s_0'],(512,1664));board.alpha_composite(ard,(800,1769));board.alpha_composite(ash,(960,1706))
    board.convert('RGB').save(HERE/'_c7b_contact.png',compress_level=9)
    (HERE/'_c7b_contact.json').write_text(json.dumps({'rows':'e,s,w,n','columns':'idle p1, auto windup2, impact3, idle p2, idle p3; approved references right; spells/death below; passes below','px_per_u':256/5.1,'pivot':[128,179.2]},indent=2))

def main():
    import argparse
    ap=argparse.ArgumentParser();ap.add_argument('--anims',nargs='*');ap.add_argument('--smoke',action='store_true');ap.add_argument('--verify',action='store_true');ap.add_argument('--bounds-only',action='store_true')
    args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.verify:return verify()
    contact={};report={};root,pose,_=build()
    if args.bounds_only:return check_bounds(root,pose)
    if not args.smoke:save_source(root,pose)
    tasks=[a for a in COUNTS if a not in EXTRAS]+['auto_dirs','spell_a_dirs','spell_b_dirs','idle_contact']+list(a for a in COUNTS if a in EXTRAS)
    if args.anims:tasks=args.anims
    if args.smoke:tasks=['smoke']
    with tempfile.TemporaryDirectory(prefix='rainfall_c7b_') as tmp:
        tmp=Path(tmp)
        for task in tasks:
            if task=='idle_contact':
                root,pose,_=build()
                for ph in (1,2,3):
                    for d in ('e','s','w','n'):
                        path=tmp/f'idle{ph}_{d}.png';c.render_still(root,lambda t:pose(f'idle_p{ph}',0,6),path,0,d)
                        contact[f'idle_p{ph}_{d}_0']=Image.open(path).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
                continue
            if task in EXTRAS and task!='antlers':root,p=prop(task)
            elif task=='antlers':root,pose,_=build()
            base=task.replace('_dirs','')
            if task=='smoke':base='auto'
            n=COUNTS[base];dirs=['e','w','n'] if task.endswith('_dirs') else ['e','s','w','n'] if task.startswith('walk') else ['s']
            size=64 if base in ('wisp','wisp_explode','ground_wisp_trail') else 256
            s=bpy.context.scene;s.render.resolution_x=s.render.resolution_y=size*2
            boards=[Image.new('RGBA',(size*n,size*len(dirs)),(128,128,255,0) if j==1 else (0,0,0,0)) for j in range(3)]
            bounds=[];hashes=[]
            for row,d in enumerate(dirs):
                for i in range(n):
                    path=tmp/f'{task}_{d}_{i}.png'
                    fn=p if task in EXTRAS and task!='antlers' else lambda t,b=base,i=i,n=n:pose(b,i,n)
                    renderer=legacy.render_frame if task in EXTRAS and task!='antlers' else c.render_still
                    renderer(root,fn,path,i/n,d)
                    ims=[Image.open(path.with_name(path.stem+suffix+'.png')).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS) for suffix in ('','_n','_e')]
                    if task=='antlers':ims[0]=ims[2].copy()
                    alpha=ims[0].getchannel('A');bbox=alpha.getbbox();bounds.append(bbox);hashes.append(hashlib.sha256(ims[0].tobytes()).hexdigest())
                    if bbox and min(bbox[0],bbox[1],size-bbox[2],size-bbox[3])<4:print('MARGIN',task,d,i,bbox,flush=True)
                    for j,im in enumerate(ims):
                        if j:im.putalpha(alpha)
                        if j==1:im.putdata([(128,128,255,0) if v[3]==0 else v for v in im.getdata()])
                        boards[j].paste(im,(i*size,row*size))
                    if base=='auto' and i in (2,3):contact[f'auto_{d}_{i}']=ims[0].copy()
            if args.smoke:
                print('SMOKE PASS',bounds,flush=True);return
            for board,suffix in zip(boards,('','_n','_e')):board.save(DST/f'{task}{suffix}.png',compress_level=9)
            report[task]={'size':boards[0].size,'frames':n,'directions':dirs,'bounds':bounds,'unique_frames':len(set(hashes))}
            print('C7B DONE',task,flush=True)
        rp=HERE/'_c7b_render_report.json'
        if args.anims and rp.exists():report={**json.loads(rp.read_text()),**report}
        rp.write_text(json.dumps(report,indent=2))
        append_tres()
        if 'idle_contact' in tasks:
            for anim in ('auto',):
                for d in ('s','e','w','n'):
                    sh=Image.open(DST/f'{anim if d=="s" else anim+"_dirs"}.png').convert('RGBA')
                    row=0 if d=='s' else ('e','w','n').index(d)
                    for i in (2,3):contact[f'{anim}_{d}_{i}']=sh.crop((i*256,row*256,(i+1)*256,(row+1)*256))
            make_contact(contact)
    (DST/'lighting.md').write_text('C7b: CREA 30 deg, ortho 5.1, 50.196078 px/u, legacy ground pivot (128,179.2). Eevee16, Standard, 2x Lanczos. PBR worn blackwood/bone/moss/iron; AO and direct self-shadows baked. One mint accent #9CF0C8, forest mist #B8C8C0. _n: Blender world Normal projected to screen, R right G up B camera, Raw encoding; transparent=(128,128,255,0). _e: Blender Emission, matching beauty alpha. walk rows e,s,w,n; *_dirs rows e,w,n. Auto windup2, impact3/6, non-loop. Antlers is emission-only, aligned to idle_p1; no eyes or opaque cage. Phase2: new tines, enlarged lanterns, low mist. Phase3: open ribs, dying lanterns, grazing transparency. Death/vanish/wisp_explode end empty; reappear begins empty.\n',encoding='utf-8')
    (DST/'manifest.md').write_text('# Cerf C7b\n\nAncient blackwood cervid, narrow death mask, split hooves, ruined iron votive lanterns. New built mesh anatomy, tapered antlers, moss and exposed ribs. Three structural phases.\n\nContract: original 57 PNG replaced at identical dimensions and frame counts; original 28 SpriteFrames definitions retained verbatim, nine attack directions appended. FPS and looping preserved.\n\nSource: art/blender/monsters/cerf_iso.blend. Script: art/tools/night/c7b_build.py. Inventory and per-frame report: art/tools/night/_c7b_inventory.json, _c7b_render_report.json. Contact: art/tools/night/_c7b_contact.png.\n',encoding='utf-8')
    verify()

def verify():
    from PIL import ImageChops
    errors=[];changed=0
    for name,info in INV['files'].items():
        p=DST/name
        if not p.exists():errors.append('missing '+name);continue
        if p.suffix!='.png':continue
        if hashlib.sha256(p.read_bytes()).hexdigest()!=info['sha256']:changed+=1
        else:errors.append('unchanged '+name)
        im=Image.open(p).convert('RGBA')
        if list(im.size)!=info['size']:errors.append('size '+name)
        if name.endswith(('_n.png','_e.png')):
            base=Image.open(DST/(name[:-6]+'.png')).convert('RGBA')
            if ImageChops.difference(im.getchannel('A'),base.getchannel('A')).getbbox():errors.append('alpha '+name)
    t=(DST/'cerf.tres').read_text()
    for a in INV['animations']:
        b=next((b for b in re.findall(r'\{\s*"frames":.*?"speed":\s*[\d.]+\s*\}',t,re.S) if f'&"{a["name"]}"' in b),None)
        if b is None or len(re.findall('"duration"',b))!=a['frames'] or float(re.search(r'"speed": ([\d.]+)',b)[1])!=a['fps'] or ('"loop": true' in b)!=a['loop']:errors.append('animation '+a['name'])
    for a in ('auto','spell_a','spell_b'):
        base=Image.open(DST/f'{a}_dirs.png').convert('RGBA')
        if base.size!=(COUNTS[a]*256,768):errors.append('direction grid '+a)
        for sf in ('_n','_e'):
            im=Image.open(DST/f'{a}_dirs{sf}.png').convert('RGBA')
            if im.size!=base.size or ImageChops.difference(im.getchannel('A'),base.getchannel('A')).getbbox():errors.append('direction pass '+a+sf)
    original_blocks=re.findall(r'\{\s*"frames":.*?"speed":\s*[\d.]+\s*\}',INV['original_tres'],re.S)
    if not all(b in t for b in original_blocks):errors.append('original animation block modified')
    rp=HERE/'_c7b_render_report.json'
    frame_count=0;minimum=999
    if rp.exists():
        for a,v in json.loads(rp.read_text()).items():
            size=64 if a in ('wisp','wisp_explode','ground_wisp_trail') else 256
            for i,b in enumerate(v['bounds']):
                frame_count+=1
                if b:
                    margin=min(b[0],b[1],size-b[2],size-b[3]);minimum=min(minimum,margin)
                    if margin<4:errors.append('margin '+a+' '+str(i))
                elif not ((a in ('death','vanish','wisp_explode') and i==COUNTS[a]-1) or (a=='reappear' and i==0)):errors.append('empty '+a+' '+str(i))
            if v['unique_frames']<min(4,COUNTS[a.replace('_dirs','')]):errors.append('motion '+a)
    assert not errors,errors
    print('PIXELS PASS',frame_count,'frames; minimum margin',minimum,'px; matching alphas and expected empty endpoints',flush=True)
    print('VERIFY PASS',changed,'legacy PNG replaced; original 28 animations preserved; total',len(re.findall('"name": &',t)),flush=True)

def check_bounds(root,pose):
    from bpy_extras.object_utils import world_to_camera_view
    s=bpy.context.scene;bad=[];minimum=999
    for a in COUNTS:
        if a in EXTRAS:continue
        for d in ('e','s','w','n'):
            root.rotation_euler.z=c.DIRECTIONS[d]
            for i in range(COUNTS[a]):
                pose(a,i,COUNTS[a]);bpy.context.view_layer.update();margin=999
                for o in root.children_recursive:
                    if o.hide_render or o.type not in ('MESH','CURVE'):continue
                    if o.name.startswith('Low forest mist'):continue
                    for pt in o.bound_box:
                        v=world_to_camera_view(s,s.camera,o.matrix_world@Vector(pt))
                        margin=min(margin,v.x*256,(1-v.x)*256,v.y*256,(1-v.y)*256)
                minimum=min(minimum,margin)
                if margin<5:bad.append((a,d,i,round(margin,2)))
    print('BOUNDS',round(minimum,2),'MIN; BAD',bad,flush=True)

if __name__=='__main__':main()
