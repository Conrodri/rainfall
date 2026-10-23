"""SA1 / Taliant. Blender geometry only; Pillow crops, assembles and verifies.
Run Blender --background --python this.py [-- --stage model|base|dual|vfx|portrait|all].
Resume with --reuse. No normals, no spell icons. Editable articulated .blend source.
"""
import sys, math, json, random
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
for rel in ('art/tools/iso', 'art/tools/cel', 'art/tools/bosses', 'art/tools/monsters'):
    sys.path.insert(0, str(ROOT / rel))
import bpy
from mathutils import Vector, Matrix, Euler
import iso_rig as iso
import cel_style as cel
from ash_lord_build import mesh
from boss_common import empty, material
from PIL import Image

OUT = ROOT / 'art/tools/night/_sa1_out'
DEST = ROOT / 'game/assets/sprites/characters/morfil'
SOURCE = ROOT / 'art/blender/characters/morfil.blend'
DIRS = list(iso.DIRECTIONS)
BASE = dict(idle=8, run=8, cut_circle=6, thrust=6, crescent=8, sharpen=8, twin_draw=8, dodge=5, hurt=3, death=8)
ANIMS = dict(BASE, **{a+'_dual': BASE[a] for a in ('idle','run','cut_circle','thrust','crescent')})
IMPACTS = dict(cut_circle=2, thrust=2, crescent=4, sharpen=5, twin_draw=4)
RNG = random.Random(4617)
P = {}

def mat(name, color, emit=0):
    c = [int(color[i:i+2],16)/255 for i in (0,2,4)]
    c = [v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
    m = material(name,c,roughness=.9,emission=emit)
    if emit: m['rainfall_emissive']=True
    return m

def tube(name, pts, radius, m, parent, sides=7):
    pts=[Vector(p) for p in pts]; vs=[]
    for i,p in enumerate(pts):
        tangent=pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]
        q=tangent.to_track_quat('Z','Y')
        r=radius[i] if isinstance(radius,(tuple,list)) else radius
        vs.extend(tuple(p+q@Vector((r*math.cos(j*math.tau/sides),r*math.sin(j*math.tau/sides),0))) for j in range(sides))
    fs=[(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j) for k in range(len(pts)-1) for j in range(sides)]
    fs.extend([tuple(range(sides-1,-1,-1)),tuple(range((len(pts)-1)*sides,len(pts)*sides))])
    return mesh(name,vs,fs,m,parent)

def shell(name, levels, m, parent, sides=24, pleat=0):
    vs=[]
    for k,(z,rx,ry,cy) in enumerate(levels):
        for j in range(sides):
            a=j*math.tau/sides; r=1+(pleat if j%2 else -pleat)
            vs.append((rx*r*math.cos(a),cy+ry*r*math.sin(a),z+(.012*math.sin(j*3.7) if k==0 else 0)))
    fs=[(k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j) for k in range(len(levels)-1) for j in range(sides)]
    return mesh(name,vs,fs,m,parent)

def plaque(name, loc, size, m, parent, seed=0):
    x,y,z=loc; w,d,h=size
    vs=[(x+sx*w*.5,y+sy*d*.5,z+sz*h*.5) for sx,sy,sz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    vs[0]=(vs[0][0]+w*.16,vs[0][1],vs[0][2]+h*.12)
    vs[5]=(vs[5][0]-w*.1,vs[5][1],vs[5][2]-h*.09)
    return mesh(name,vs,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],m,parent,.0025)

def aim(ob, vector):
    ob.rotation_mode='QUATERNION';ob.rotation_quaternion=Vector(vector).to_track_quat('Z','Y')

def merge_parts():
    # One mesh per articulated node: retain detailed geometry without hundreds of draw objects.
    parents={o.parent for o in list(bpy.context.scene.objects) if o.type=='MESH'}
    for parent in parents:
        obs=[o for o in list(bpy.context.scene.objects) if o.type=='MESH' and o.parent==parent]
        if not obs:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in obs:o.select_set(True)
        bpy.context.view_layer.objects.active=obs[0]
        bpy.ops.object.convert(target='MESH');bpy.ops.object.join()
        bpy.context.object.name=parent.name+'_sculpt'

def blade(parent, prefix):
    # Black heartwood, tapered curved shinogi; luminous edge is its own geometric strand.
    vs=[]; length=.93
    for i in range(17):
        t=i/16; z=.07+length*t; bend=.17*t*t; w=.040*(1-t)**.45+.002
        vs.extend([(bend-w,-.014*(1-t),z),(bend+w,-.009,z),(bend+w,.009,z),(bend-w,.014*(1-t),z)])
    fs=[(i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j) for i in range(16) for j in range(4)]
    hinge=Vector((.17*.5**2,0,.07+length*.5))
    tip=empty(prefix+' blade fracture',hinge,parent)
    mesh(prefix+' black cedar blade root',vs[:36],fs[:32],P['blade'],parent)
    mesh(prefix+' black cedar blade tip',[tuple(Vector(v)-hinge) for v in vs[32:]],
         [tuple(j-32 for j in face) for face in fs[32:]],P['blade'],tip)
    edge=[(.17*(i/24)**2+.040*(1-i/24)**.45+.002,-.010,.07+length*i/24) for i in range(25)]
    tube(prefix+' isolated sap edge root',edge[:13],.0042,P['edge'],parent,5)
    tube(prefix+' isolated sap edge tip',[tuple(Vector(v)-hinge) for v in edge[12:]],.0042,P['edge'],tip,5)
    for j in range(3):
        points=[(.17*t*t-.020+j*.012,-.015,.08+length*t) for t in [i/12 for i in range(12)]]
        tube(prefix+' wood vein root',points[:7],.0025,P['wood'],parent,4)
        tube(prefix+' wood vein tip',[tuple(Vector(v)-hinge) for v in points[6:]],.0025,P['wood'],tip,4)
    shell(prefix+' rusted tsuba',[(.025,.093,.055,0),(.049,.093,.055,0)],P['rust'],parent,16)
    tube(prefix+' wrist root',[(0,0,-.09),(-.015,.008,.025),(.015,0,.12)],[.047,.039,.014],P['bark'],parent)

def build():
    s=iso.create_rig('CREA',192);s.camera.data.shift_y=.21
    s.render.threads_mode='FIXED';s.render.threads=6
    P.update({k:mat(k,c) for k,c in dict(bark='3A3129',wood='5E5246',cloth='343C4A',fold='242C38',lacquer='5A2420',chip='794138',rope='8A7A5C',moss='4F5A3A',rust='6B3A22',blade='252A25',stone='646B67',dark='21241F',reed='71674D',reedlight='958665',water='738586').items()})
    P['sap']=mat('Unique sap CEL Accent CDEB6E','CDEB6E',1.3)
    P['edge']=mat('Isolated sharpenable sap edge CDEB6E','CDEB6E',1.3)
    root=empty('Taliant');body=empty('Hollow cedar', (0,0,.73),root)
    # The torso is open down the middle, bound by a rotten diagonal kimono lapel.
    for side in (-1,1):
        tube('Split cedar ribs',[(side*.065,0,-.1),(side*.10,.01,.12),(side*.17,.025,.35),(side*.10,0,.47)],[.048,.035,.067,.038],P['bark'],body,9)
        for j in range(3):
            tube('Raised bark fissure',[(side*(.05+j*.025),-.038,-.04),(side*(.085+j*.02),-.045,.14),(side*(.12+j*.018),-.035,.33)],.006,P['wood'],body,5)
    shell('Rotten crossed kimono',[(.04,.145,.088,0),(.24,.184,.095,0),(.39,.177,.08,.015)],P['cloth'],body,20,.055)
    for side in (-1,1):
        tube('Crossed lapel',[(side*.13,-.09,.39),(-side*.055,-.105,.18),(-side*.11,-.092,.07)],.018,P['rope'],body,5)
    # Several staggered lamellae, chipped edges and physically laced shoulders.
    for back in (-1,1):
        for row in range(4):
            for col in range(5):
                x=(col-2)*.065;z=.125+row*.058;y=back*(.11-.012*abs(col-2))
                plaque('Lacquer bark lamella',(x,y,z),(.063,.022,.051),P['lacquer'] if (row+col)%4 else P['chip'],body)
                if (row+col)%3==0:plaque('Exposed chipped cedar',(x+.018,y+back*.013,z-.019),(.021,.005,.009),P['wood'],body)
                if col in (0,4):tube('Do hemp lacing',[(x,y+back*.016,z-.018),(x+.012,y+back*.018,z+.02)],.0045,P['rope'],body,4)
    for j in range(3):
        tube('Obi rope',[(.15*math.cos(a),.104*math.sin(a),.045+j*.015) for a in [i*math.tau/36 for i in range(37)]],.009,P['rope'],body,5)
    tube('Stone suspension',[(.12,-.11,.04),(.15,-.135,-.15)],.007,P['rope'],body)
    stone=empty('Whetstone',(.15,-.14,-.18),body)
    plaque('Concave waterstone',(0,0,0),(.092,.035,.13),P['stone'],stone)
    head=empty('Bark face',(0,-.035,.44),body)
    shell('Narrow cedar head',[(0,.075,.058,0),(.085,.088,.064,0),(.145,.06,.048,.012)],P['bark'],head,14,.09)
    for x in (-.039,.039):
        plaque('Eye fissure',(x,-.063,.074),(.043,.008,.014),P['dark'],head)
        tube('Sap eye point',[(x,-.071,.073),(x+.004,-.072,.077)],.006,P['sap'],head,5)
    tube('Chin cord',[(-.16,.0,.59),(-.065,-.095,.40),(0,-.102,.38),(.065,-.095,.40),(.16,0,.59)],.006,P['rope'],body,5)
    hat=empty('Oversized inverted basket bowl',(0,-.005,.58),body)
    shell('Broad drooping bowl',[(0,.535,.52,0),(.035,.49,.48,0),(.075,.40,.39,0),(.135,.29,.28,0),(.175,.14,.135,0),(.185,.005,.005,0)],P['reed'],hat,64)
    # Basket weave is actual interlaced geometry; readable in cel and at portrait scale.
    for k in range(1,12):
        r=.535*k/12;z=.185*(1-(r/.535)**1.9)
        tube('Concentric woven reed',[(r*math.cos(a),r*.97*math.sin(a),z+.003*math.sin(48*a)) for a in [i*math.tau/128 for i in range(129)]],.0058,P['reedlight'] if k%3 else P['wood'],hat,4)
    for j in range(48):
        a=j*math.tau/48
        tube('Radial bark ribbon',[(r*math.cos(a),r*.97*math.sin(a),.185*(1-(r/.535)**1.9)+.004*math.cos(k*math.pi)) for k,r in enumerate([.05,.1,.15,.2,.25,.3,.35,.4,.45,.49,.535])],.0058,P['wood'] if j%3 else P['reedlight'],hat,4)
    for j in range(31):
        a=j*2.399;r=.51+RNG.uniform(-.01,.02)
        tube('Frayed hat rim',[(r*math.cos(a),r*math.sin(a),.012),((r+.024)*math.cos(a+.01),(r+.024)*math.sin(a+.01),-.025-RNG.random()*.035)],[.004,.0015],P['rope'],hat,4)
    for j in range(12):
        a=RNG.random()*math.tau;r=RNG.uniform(.25,.47);z=.185*(1-(r/.535)**1.9)+.006
        plaque('Moss in basket weave',(r*math.cos(a),r*.97*math.sin(a),z),(.045,.025,.009),P['moss'],hat)
    legs=[]
    for side in (-1,1):
        leg=empty('Root leg '+str(side),(side*.105,0,.71),root);legs.append(leg)
        tube('Knotted shin',[(0,0,0),(side*.025,.025,-.31),(side*.04,-.01,-.57),(side*.065,-.10,-.68)],[.067,.058,.038,.029],P['bark'],leg,9)
        shell('Tattered pleated hakama',[(-.55,.105,.095,0),(-.42,.13,.105,.012),(-.19,.112,.10,0),(0,.09,.085,0)],P['cloth'],leg,24,.12)
        for j in range(7):
            a=j*math.tau/7
            tube('Torn indigo hem',[(.1*math.cos(a),.09*math.sin(a),-.45),(.09*math.cos(a+.1),.09*math.sin(a+.1),-.58-RNG.random()*.035)],[.012,.001],P['fold'],leg,4)
        for j in range(4):
            x=(j-1.5)*.025
            tube('Grasping root toe',[(side*.04+x,-.01,-.57),(side*.055+x,-.08,-.65),(side*.07+x*1.3,-.17-RNG.random()*.04,-.685)],[.019,.014,.003],P['wood'] if j%2 else P['bark'],leg,6)
        tube('Hakama hemp seam',[(side*.09,.02,-.1),(side*.12,.035,-.36),(side*.09,0,-.52)],.005,P['rope'],leg,4)
    arms=[];blades=[];leftfore=None
    for side in (-1,1):
        arm=empty('Right cedar arm' if side==-1 else 'Left branch arm',(side*.205,0,.35),body);arms.append(arm)
        tube('Knotted upper arm',[(0,0,0),(.018*side,.015,.10),(0,0,.24)],[.05,.036,.028],P['bark'],arm,8)
        for row in range(3):
            plaque('Sode lacquer scales',(0,-.015,.04+row*.055),(.16,.075,.048),P['lacquer'] if row%2 else P['chip'],arm)
            for x in (-.052,.052):tube('Sode laces',[(x,-.056,row*.055+.02),(x,-.056,row*.055+.08)],.005,P['rope'],arm,4)
        fore=empty('Living katana' if side==-1 else 'Left twig forearm',(0,0,.24),arm)
        if side==-1:
            blade(fore,'Right');blades.append(fore)
        else:
            leftfore=fore
            tube('Twig forearm',[(0,0,0),(.012,0,.12),(0,0,.25)],[.028,.023,.017],P['bark'],fore,7)
            for j in range(4):tube('Twig finger',[(0,0,.23),((j-1.5)*.016,-.025,.28),((j-1.5)*.022,-.015,.31)],[.008,.006,.002],P['wood'],fore,5)
            second=empty('Growing second katana',(0,0,.10),fore);blade(second,'Left');blades.append(second)
    sheath=empty('Hollow branch scabbard',(.16,.04,-.10),body)
    tube('Branch scabbard',[(0,0,0),(.02,.15,-.06),(.055,.43,-.14),(.09,.68,-.2)],[.037,.035,.028,.018],P['bark'],sheath,10)
    shell('Open scabbard mouth',[(0,.044,.044,0),(.025,.044,.044,0)],P['rust'],sheath,12)
    tube('Hollow scabbard interior',[(0,0,-.002),(0,0,.01)],.03,P['dark'],sheath,12)
    # Sparse lichen patches at seams, never luminous.
    for j in range(10):
        side=(-1,1)[j%2]
        plaque('Lichen in rotten seams',(side*RNG.uniform(.10,.16),-.115,RNG.uniform(.09,.34)),(.024,.008,.015),P['moss'],body)
    drops=empty('Hat rain drops',(0,0,0),hat)
    for a in (.1,1.7,3.2,4.9):tube('Dripping rain',[(.52*math.cos(a),.51*math.sin(a),-.04),(.52*math.cos(a),.51*math.sin(a),-.065)],[.003,.001],P['water'],drops,5)
    merge_parts()
    rig=dict(root=root,body=body,head=head,hat=hat,legs=legs,arms=arms,blades=blades,leftfore=leftfore,stone=stone,sheath=sheath,drops=drops)
    s['SA1_contract']='CREA 30deg R=90.50966799; 192px; pivot=(96,136.32); no normal maps; sap edge and eyes only'
    s['SA1_design']='Narrow hollow cedar; wide low woven bowl; frayed indigo; chipped oxblood lamellae; fused curved heartwood arm-blade'
    return rig

def pose(rig, anim, f, n):
    a=anim.replace('_dual','');dual=anim.endswith('_dual');t=f/n*math.tau;p=f/max(1,n-1)
    root,body,hat=rig['root'],rig['body'],rig['hat']
    body.location=(0,0,.73);body.rotation_euler=(.12,0,0)
    hat.location=(0,-.005,.58);hat.rotation_euler=(.025,0,0)
    rig['stone'].location=(.15,-.14,-.18)
    rig['sheath'].scale=(1,1,1)
    for tip in (bpy.data.objects.get('Right blade fracture'),bpy.data.objects.get('Left blade fracture')):
        if tip:tip.rotation_euler=(0,0,0)
    for i,leg in enumerate(rig['legs']):leg.rotation_euler=(.04 if i==0 else -.08,0,0)
    for arm in rig['arms']:arm.location.z=.35
    # Quaternions aim the anatomical upper arm and the fused forearm blade independently.
    r_upper=(-.07,-.04,-.23);r_blade=(-.32,-.28,-.83)
    l_upper=(.05,-.07,-.22);l_fore=(-.07,-.16,-.12)
    growth=1 if dual else .001
    body.location.z+=.006*math.sin(t)
    if a=='idle':
        hat.rotation_euler.y=.012*math.sin(t);hat.rotation_euler.x=.025+.015*math.cos(t)
        r_blade=(-.32+.06*math.cos(t),-.27+.035*math.sin(t),-.83)
    if a=='run':
        body.rotation_euler.x=.33;body.location.z=.70+.025*math.cos(2*t)
        for i,leg in enumerate(rig['legs']):leg.rotation_euler.x=.65*math.sin(t+.2+i*math.pi)
        r_upper=(-.08,.03,-.22);r_blade=(-.20,.90,-.28)
        l_upper=(.1,-.1-.13*math.sin(t),-.20);l_fore=(.05,-.08,-.20)
        hat.rotation_euler.y=.035*math.sin(t)
    if a in ('cut_circle','crescent'):
        # Peak passage in front at the gameplay impact; recovery keeps the full sweep.
        theta=(-math.pi/2+(f-2)*math.tau/6) if a=='cut_circle' else (-math.pi+(f/7)*math.pi)
        v=(math.cos(theta),math.sin(theta),-.13)
        r_upper=(.205,-.015,-.10);r_blade=v
        body.rotation_euler.z=.24*math.sin(theta);body.rotation_euler.x=.05
        for arm in rig['arms']:arm.location.z=.29
        l_upper=(-.205,.015,-.10);l_fore=(-v[0],-v[1],-.17)
    if a=='thrust':
        reach=[0,.35,1,.85,.35,0][f]
        body.rotation_euler.x=.12+.25*reach;body.location.y=-.08*reach
        r_upper=(-.09+.295*reach,-.02+.15*reach,-.16+.06*reach);r_blade=(-.06,-.3-.7*reach,-.8+.8*reach)
        l_upper=(.08-.285*reach,.13*reach,-.18+.08*reach);l_fore=(.06,-.6,-.12)
    if a=='sharpen':
        r_upper=(-.12,-.10,-.10);r_blade=(.88,-.22,.08)
        l_upper=(-.06,-.18,-.07);l_fore=(-.40+.45*p,-.10,.1)
        rig['stone'].location=(-.30+.72*p,-.28,.16)
    if a=='twin_draw':
        growth=max(.001,min(1,(f-1)/3));l_upper=(-.205,.02,-.10);l_fore=(.55,-.40,-.35)
        body.rotation_euler.z=-.12+.24*p
    if a=='dodge':
        body.rotation_euler.x=.5+.25*math.sin(math.pi*p);body.location.z=.62-.08*math.sin(math.pi*p)
        r_upper=(-.07,-.15,-.1);r_blade=(.90,-.25+.4*p,.04)
        rig['legs'][0].rotation_euler.x=-.6+.3*p;rig['legs'][1].rotation_euler.x=.8-.4*p
    if a=='hurt':
        body.rotation_euler.x=-.18*math.sin(math.pi*p);body.rotation_euler.y=.17*math.sin(math.pi*p)
        r_blade=(-.4,-.1,-.6)
    if a=='death':
        body.location.z=.73-.43*p;body.rotation_euler.x=.12+.52*p
        rig['legs'][0].rotation_euler.x=-1.2*p;rig['legs'][1].rotation_euler.x=.7*p
        fall=max(0,(p-.14)/.86)
        position=(.38*fall,.1*fall,1.31-1.19*fall-.10*math.sin(math.pi*fall))
        hat.matrix_basis=body.matrix_basis.inverted()@Matrix.Translation(position)@Euler((1.4*math.sin(math.pi*fall),.1*math.sin(math.pi*fall),4*fall)).to_matrix().to_4x4()
        r_upper=(.205,0,-.10);r_blade=(-.5,-.3,-.7)
        fracture=bpy.data.objects.get('Right blade fracture')
        if fracture:fracture.rotation_euler.y=.95*max(0,(p-.4)/.6)
    if dual and a in ('idle','run'):
        l_upper=(-.18,-.08,-.12);l_fore=(.55,.72,-.34) if a=='run' else (.4,-.18,-.78)
    aim(rig['arms'][0],r_upper);aim(rig['arms'][1],l_upper)
    # Convert desired body-space blade orientation through the upper arm inverse.
    for arm,fore,vec in [(rig['arms'][0],rig['blades'][0],r_blade),(rig['arms'][1],rig['leftfore'],l_fore)]:
        aim(fore,arm.rotation_quaternion.inverted()@Vector(vec))
    rig['blades'][1].scale=(growth*.90,growth*.90,growth*.90)
    rig['drops'].location.z=-.06*((f%4)/4)
    # The edge mask is independent of the eyes; stone contact restores it at impact 5.
    strength=(.12 if f<5 else 1.3) if a=='sharpen' else 1.3
    if 'edge' in P:
        m=P['edge'];nodes=m.node_tree.nodes
        for node in nodes:
            if node.type=='BSDF_PRINCIPLED':node.inputs['Emission Strength'].default_value=strength
            if node.type=='EMISSION':node.inputs['Strength'].default_value=strength
            if node.type=='OUTPUT_AOV':
                color=next((v.inputs['Color'].default_value for v in nodes if v.type=='EMISSION'),(1,1,1,1))
                node.inputs['Color'].default_value=tuple(c*strength for c in color[:3])+(1,)

def key_source(rig):
    s=bpy.context.scene;manifest={};nodes=[o for o in rig['root'].children_recursive if o.type=='EMPTY']
    start=1
    for anim,n in ANIMS.items():
        manifest[anim]=dict(start=start,frames=n,impact=IMPACTS.get(anim.replace('_dual','')))
        s.timeline_markers.new(anim,frame=start)
        for f in range(n):
            pose(rig,anim,f,n)
            for o in nodes:
                for prop in ('location','rotation_quaternion' if o.rotation_mode=='QUATERNION' else 'rotation_euler','scale'):o.keyframe_insert(prop,frame=start+f)
        start+=n+3
    s.frame_end=start;s['SA1_animations']=json.dumps(manifest)
    SOURCE.parent.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0
    pose(rig,'idle',0,8);bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
    for o in nodes:o.animation_data_clear()

def render(path, size, profile='creature'):
    # Reuse shared compositor. iso.render_frame expects a normal file, so use its diffuse pipeline directly.
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    s=bpy.context.scene;bpy.context.view_layer.update()
    iso.common.configure_passes(path)
    s.eevee.taa_render_samples=8;s.render.filepath=str(path)
    bpy.ops.render.render(write_still=True)
    for suffix in ('','_e'):
        dest=path.with_name(path.stem+suffix+'.png')
        if suffix:
            candidates=list(path.parent.glob(path.stem+suffix+'__*.png'))
            assert len(candidates)==1,(path,candidates)
            candidates[0].replace(dest)
        with Image.open(dest) as src:im=src.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
        im.save(dest,optimize=True,compress_level=9)

def resources():
    ext=[];subs=[];anims=[];sid=0
    for anim,n in ANIMS.items():
        if not (DEST/(anim+'.png')).exists():continue
        ext.append(f'[ext_resource type="Texture2D" path="res://assets/sprites/characters/morfil/{anim}.png" id="{anim}"]')
        for row,d in enumerate(DIRS):
            frames=[]
            for f in range(n):
                sid+=1;aid='a'+str(sid)
                subs.append(f'[sub_resource type="AtlasTexture" id="{aid}"]\natlas = ExtResource("{anim}")\nregion = Rect2({f*192}, {row*192}, 192, 192)')
                frames.append('{"duration": 1.0, "texture": SubResource("'+aid+'")}')
            loop=anim.replace('_dual','') in ('idle','run')
            speed=8 if anim.startswith('idle') else 12 if anim.startswith('run') else 10 if anim=='death' else 16
            anims.append('{"frames": ['+', '.join(frames)+f'], "loop": {str(loop).lower()}, "name": &"{anim}_{d}", "speed": {speed}.0'+'}')
    DEST.mkdir(parents=True,exist_ok=True)
    (DEST/'morfil.tres').write_text(f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(subs)+1} format=3]\n\n'+'\n\n'.join(ext+subs)+'\n\n[resource]\nanimations = ['+',\n'.join(anims)+']\n')

def sheet(anim,n):
    for suffix in ('','_e'):
        atlas=Image.new('RGBA',(n*192,8*192))
        for row,d in enumerate(DIRS):
            for f in range(n):
                with Image.open(OUT/anim/f'{d}_{f:02}{suffix}.png') as im:atlas.paste(im,(f*192,row*192))
        if suffix:atlas=atlas.resize((n*96,8*96),Image.Resampling.LANCZOS)
        atlas.save(DEST/(anim+suffix+'.png'),optimize=True,compress_level=9)

def character(stage,reuse):
    rig=build();key_source(rig);cel.install('creature',normals=False)
    selected=list(BASE) if stage=='base' else [a for a in ANIMS if a.endswith('_dual')] if stage=='dual' else ['idle'] if stage=='model' else list(ANIMS)
    if '--anims' in sys.argv:selected=sys.argv[sys.argv.index('--anims')+1].split(',')
    DEST.mkdir(parents=True,exist_ok=True)
    for anim in selected:
        n=ANIMS[anim]
        for d,angle in iso.DIRECTIONS.items():
            for f in range(n):
                path=OUT/anim/f'{d}_{f:02}.png'
                if reuse and path.exists() and path.with_name(path.stem+'_e.png').exists():continue
                pose(rig,anim,f,n);rig['root'].rotation_euler.z=angle
                render(path,192)
        sheet(anim,n);resources();print('PASS SA1',anim,flush=True)
    cel.uninstall()
    return rig

def portrait(rig=None):
    if rig is None:rig=build()
    pose(rig,'idle_dual',0,8);rig['root'].rotation_euler.z=-.28
    aim(rig['arms'][0],(.1,-.15,-.15))
    aim(rig['blades'][0],rig['arms'][0].rotation_quaternion.inverted()@Vector((-.25,-.12,.94)))
    s=bpy.context.scene;iso.set_frame(256,'CREA');s.camera.data.ortho_scale=1.27;s.camera.data.shift_y=0
    target=Vector((0,-.03,1.03));s.camera.location=target+s.camera.rotation_euler.to_matrix()@Vector((0,0,12))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_name('morfil_portrait.blend')))
    if '--source-only' in sys.argv:return
    cel.install('creature',normals=False);render(OUT/'portrait.png',256);cel.uninstall()
    dest=ROOT/'game/assets/sprites/ui/portraits/morfil.png';dest.parent.mkdir(parents=True,exist_ok=True)
    with Image.open(OUT/'portrait.png') as im:im.save(dest,optimize=True)
    print('PASS SA1 portrait',flush=True)

def vfx():
    specs=dict(cut_circle=(6,320,'TOP'),cut_thrust=(5,448,'TOP'),cut_crescent=(6,480,'TOP'),twin_draw=(8,352,'TOP'),iai_trail=(4,400,'TOP'),sharpen_sparks=(6,192,'CREA'))
    if '--effects' in sys.argv:
        names=sys.argv[sys.argv.index('--effects')+1].split(',');specs={k:v for k,v in specs.items() if k in names}
    for name,(n,size,rigtype) in specs.items():
        iso.create_rig(rigtype,size);s=bpy.context.scene
        s.render.threads_mode='FIXED';s.render.threads=6
        dark=mat('Ink heartwood trail','303930');sap=mat('Sap edge CDEB6E','CDEB6E',1.4)
        r=size*.45/(128 if rigtype=='TOP' else iso.R)
        root=empty('VFX '+name);objects=[]
        for f in range(n):
            group=empty('Frame '+str(f),parent=root);objects.append(group);p=f/max(1,n-1)
            if name in ('cut_circle','cut_crescent','twin_draw'):
                loops=2 if name=='twin_draw' else 1
                for ring in range(loops):
                    arc=math.tau if name!='cut_crescent' else math.pi
                    start=(-math.pi/2 if name=='cut_crescent' else -.4+f*.44)+ring*.5
                    radius=r*(.63+.37*math.sin((p*.75+.2)*math.pi))
                    for band in range(4):
                        rr=radius-band*r*.035;pts=[]
                        for j in range(97):
                            a=start+arc*j/96
                            x=rr*math.cos(a);y=rr*math.sin(a)
                            if name=='twin_draw':
                                y*=.65;angle=(-.55,.55)[ring]
                                x,y=x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle)
                            pts.append((x,y,.015+ring*.006))
                        tube('Swept ink ribbon' if band else 'Thin luminous cutting edge',pts,r*(.004 if band==0 else .014)*(1-.4*p),sap if band==0 else dark,group,4)
            elif name in ('cut_thrust','iai_trail'):
                tip=r*(.55+.45*math.sin((p*.7+.2)*math.pi));width=r*(.30 if name=='cut_thrust' else .055)*(1-.4*p)
                mesh('Black pointed stroke',[(-r*.15,-width,.01),(tip,0,.01),(-r*.15,width,.01),(-r*.27,0,.01)],[(0,1,2,3)],dark,group)
                for side in (-1,1):tube('Sap pointed edge',[(-r*.13,side*width,.018),(tip,0,.018)],r*.004,sap,group,4)
                tube('Residual splinter',[(-r*.7,0,.012),(-r*.3,0,.012)],[r*.008,r*.002],dark,group,4)
            else:
                for j in range(11):
                    a=j*2.399;length=.15+.48*p;u=Vector((math.cos(a)*.55,-.1,math.sin(a)*.4+.5))
                    center=Vector((.05,0,.0));begin=center+u*length;end=begin+u*.11*(1-.7*p)
                    tube('Sap whetstone sparks',[begin,end],[.016,.003],sap,group,5)
            # Frame groups are independently selectable in the source file.
        merge_parts();cel.install('vfx',normals=False)
        frames=[];emissions=[]
        for f,group in enumerate(objects):
            for g in objects:
                for o in g.children_recursive:o.hide_render=g!=group
            path=OUT/'vfx'/name/f'{f:02}.png';render(path,size)
            frames.append(path);emissions.append(path.with_name(path.stem+'_e.png'))
        cel.uninstall();dest=DEST/name;dest.mkdir(parents=True,exist_ok=True)
        # At most 3840 px wide: exact same cuts for diffuse and half-size emission.
        atlas=Image.new('RGBA',(n*size,size));accent=Image.new('RGBA',(n*size,size))
        for f,(path,e) in enumerate(zip(frames,emissions)):
            with Image.open(path) as im:atlas.paste(im,(f*size,0))
            with Image.open(e) as im:accent.paste(im,(f*size,0))
        atlas.save(dest/(name+'.png'),optimize=True)
        accent.resize((n*size//2,size//2),Image.Resampling.LANCZOS).save(dest/(name+'_e.png'),optimize=True)
        subs=[];entries=[]
        for f in range(n):
            subs.append(f'[sub_resource type="AtlasTexture" id="a{f}"]\natlas = ExtResource("1")\nregion = Rect2({f*size}, 0, {size}, {size})')
            entries.append('{"duration": 1.0, "texture": SubResource("a'+str(f)+'")}')
        (dest/(name+'.tres')).write_text(f'[gd_resource type="SpriteFrames" load_steps={n+2} format=3]\n\n[ext_resource type="Texture2D" path="res://assets/sprites/characters/morfil/{name}/{name}.png" id="1"]\n\n'+'\n\n'.join(subs)+'\n\n[resource]\nanimations = [{"frames": ['+', '.join(entries)+'], "loop": false, "name": &"default", "speed": 18.0}]\n')
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE.with_name('morfil_'+name+'.blend')))
        print('PASS SA1 VFX',name,flush=True)

def main():
    stage=sys.argv[sys.argv.index('--stage')+1] if '--stage' in sys.argv else 'all'
    reuse='--reuse' in sys.argv
    if stage=='bounds':
        import numpy as np
        rig=build();cache=[];failures=[]
        for ob in rig['root'].children_recursive:
            if ob.type!='MESH':continue
            coords=np.empty(len(ob.data.vertices)*3);ob.data.vertices.foreach_get('co',coords)
            cache.append((ob,np.column_stack((coords.reshape(-1,3),np.ones(len(ob.data.vertices))))))
        for anim,n in ANIMS.items():
            for d,angle in iso.DIRECTIONS.items():
                for f in range(n):
                    pose(rig,anim,f,n);rig['root'].rotation_euler.z=angle;bpy.context.view_layer.update()
                    limits=[192.,192.,0.,0.];culprits=[]
                    for ob,coords in cache:
                        v=coords@np.array(ob.matrix_world).T
                        x=96+v[:,0]*iso.R;y=136.32-(v[:,1]*.5+v[:,2]*math.sqrt(.75))*iso.R
                        b=[float(x.min()),float(y.min()),float(x.max()),float(y.max())]
                        limits=[min(limits[0],b[0]),min(limits[1],b[1]),max(limits[2],b[2]),max(limits[3],b[3])]
                        if min(b[:2])<4 or max(b[2:])>188:culprits.append(ob.name)
                    if culprits:failures.append(dict(anim=anim,d=d,f=f,bounds=[round(v,2) for v in limits],objects=culprits))
        (OUT/'bounds.json').write_text(json.dumps(failures,indent=1))
        print('SA1 bounds',len(failures),json.dumps(failures[:8]),flush=True);return
    if stage in ('model','base','dual','all'):rig=character(stage,reuse)
    if stage in ('vfx','all') or '--finish' in sys.argv:vfx()
    if stage in ('portrait','all') or '--finish' in sys.argv:portrait()
    print('PASS SA1 stage',stage,flush=True)

if __name__=='__main__':main()
