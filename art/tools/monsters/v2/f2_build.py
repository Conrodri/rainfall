"""MOB_V2_F2: new root marten, then shrine guardian. No source blend reuse.
blender --background --python art/tools/monsters/v2/f2_build.py -- leaper|brute|contact
Append --check for geometry-only preflight, --only idle,run for a targeted rerender.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters
from t2_build import plate, fin, ring, plant, finish


def trunk(name, sections, mat, parent, pale=None):
    """Hand-shaped elliptical cross sections, longitudinal grain and dorsal colour."""
    sides=10; vs=[]
    for y,z,rx,rz in sections:
        vs.extend((rx*math.cos(j*math.tau/sides),y,z+rz*math.sin(j*math.tau/sides)) for j in range(sides))
    fs=[tuple(range(sides-1,-1,-1))]
    fs.extend((k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j)
              for k in range(len(sections)-1) for j in range(sides))
    fs.append(tuple(range((len(sections)-1)*sides,len(sections)*sides)))
    o=mesh(name,vs,fs,mat,parent)
    if pale:
        o.data.materials.append(pale)
        for p in o.data.polygons:
            # Rings run anticlockwise: top half is indices 0..4.
            if len(p.vertices)==4 and ((p.index-1)%sides)<5: p.material_index=1
    return o


def deliver(name,size,bottom,counts,root,pose):
    # Mesh projections before expensive rendering; the cell is never expanded.
    s=bpy.context.scene; failures=[]
    for a,n in counts.items():
        for row,d in enumerate(('e','s','w','n') if a=='death' else DIRS):
            root.rotation_euler.z=math.radians(90-45*DIRS.index(d))
            rot=root.rotation_euler.to_matrix()
            lowest=min((rot@Vector(p)).y*.5+p[2]*math.cos(math.pi/6) for p in root['foot_reference'])
            s.camera.data.shift_y=(bottom-size[1]/2+lowest*64)/size[0]
            for f in range(n):
                pose(a,f,n); bpy.context.view_layer.update()
                world=[o.matrix_world@v.co for o in root.children_recursive if o.type=='MESH' for v in o.data.vertices]
                coords=[(size[0]/2+p.x*64,bottom+lowest*64-(p.y*.5+p.z*math.cos(math.pi/6))*64) for p in world]
                bounds=(min(p[0] for p in coords),min(p[1] for p in coords),max(p[0] for p in coords),max(p[1] for p in coords))
                if min(bounds[:2])<3.8 or bounds[2]>size[0]-3.8 or bounds[3]>size[1]-3.8:
                    failures.append((a,d,f,tuple(round(v,1) for v in bounds)))
    root.rotation_euler.z=0
    assert not failures, (len(failures), failures[:20])
    print('F2 PREFLIGHT PASS',name,flush=True)
    if '--check' not in sys.argv: finish(name,size,bottom,counts,root,pose)


def leaper():
    rig((96,96),82)
    bark=material('Cedar dark heartwood','505349'); pale=material('Pale dorsal lichen','C4CBB0')
    moss=material('Grey green moss','687C61'); black=material('Thorn mouth recess','30392F')
    tooth=material('Bleached thorn tips','B9BBA0'); glow=material('Forest accent 9CF0C8','9CF0C8',1)
    root=empty('Martre des racines direction')
    body=empty('Lumbar breathing and flexion',(0,-.02,.43),root)
    trunk('Powerful lichen hindquarters',[(.30,-.03,.09,.10),(.20,.015,.22,.22),(.02,.025,.18,.19),(-.08,0,.14,.14)],bark,body,pale)
    chest=empty('Thoracic spine',(0,-.10,.01),body)
    trunk('Long flexible cedar ribcage',[(.06,0,.155,.15),(-.08,0,.16,.16),(-.23,-.025,.12,.12)],bark,chest,pale)
    head=empty('Neck turn for reversing bite',(0,-.24,-.025),chest)
    trunk('Narrow mustelid skull',[(.04,0,.09,.085),(-.035,.005,.105,.10),(-.15,-.015,.065,.052),(-.21,-.025,.04,.038)],bark,head,pale)
    ellipsoid('Black wet cedar nose',(0,-.211,-.01),(.047,.026,.034),black,head)
    jaw=empty('Bramble jaw hinge',(0,-.015,-.048),head)
    trunk('Lower bramble mandible',[(.01,0,.08,.035),(-.11,0,.065,.028),(-.20,.015,.026,.018)],bark,jaw)
    mouth=empty('Impact green throat',(0,-.11,-.045),head)
    ellipsoid('Luminous throat',(0,0,0),(.062,.09,.035),glow,mouth)
    for sign in (-1,1):
        ellipsoid('Dark eye socket',(sign*.083,-.066,.055),(.038,.045,.03),black,head)
        ellipsoid('Green watchful eye',(sign*.095,-.087,.06),(.023,.026,.022),glow,head)
        ear=fin('Pointed torn cedar ear',[(sign*.055,.015,.05),(sign*.10,.04,.19),(sign*.14,.02,.08)],.045,bark,head)
        fin('Pale ear lichen',[(sign*.068,.006,.075),(sign*.10,.025,.16),(sign*.12,.008,.08)],.022,pale,head)
        for j in range(3):
            y=-.07-j*.045
            taper('Upper thorn fang',(sign*.066,y,-.018),(sign*.06,y-.01,-.075),(.018,.002),tooth,head,4)
            taper('Lower hooked thorn',(sign*.06,y,.01),(sign*.05,y-.018,.052),(.014,.002),tooth,jaw,4)
    # Broad lichen ridges break the smooth dorsal contour without surface noise.
    for j in range(4):
        fin('Raised lichen comb %d'%j,[(-.10,.19-j*.09,.16),(0,.23-j*.09,.24),(.10,.19-j*.09,.16)],.035,pale,body)
    tail=empty('Root tail proximal lag',(0,.29,.015),body)
    trunk('Tapered cedar root tail',[(0,0,.08,.07),(.12,-.01,.065,.055),(.23,-.055,.04,.035)],bark,tail,pale)
    tip=empty('Root tail distal lag',(0,.22,-.05),tail)
    for j in range(3):
        taper('Frayed root tail prong',(0,0,0),((j-1)*.09,.16-.015*abs(j-1),-.03+j*.015),(.037,.004),pale if j==1 else bark,tip,5)
    legs=[]; refs=[]
    for i,y in enumerate((-.25,.19)):
        for sign in (-1,1):
            hip=empty('Marten hip %d %d'%(i,sign),(sign*.125,y,-.065),body)
            knee=empty('Marten knee',(sign*.025,.035,-.16),hip)
            taper('Bulging haunch' if i else 'Tapered forelimb',(0,0,0),tuple(knee.location),(.10 if i else .064,.046),bark,hip,7)
            taper('Lichen shin',(0,0,0),(0,-.065,-.17),(.046,.024),pale,knee,6)
            foot=empty('Marten wrist',(0,-.065,-.17),knee)
            ellipsoid('Broad root paw',(0,-.035,-.005),(.055,.075,.026),bark,foot)
            for j in (-1,0,1): taper('Root claw',(j*.028,-.067,0),(j*.03,-.10,-.005),(.012,.003),tooth,foot,4)
            legs.append((hip,knee,foot,i,sign)); refs.append((sign*.15,y-.02-.065-.10,.01))
    root['foot_reference']=refs; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; mouth.scale=(.015,)*3
        body.scale.z=1+.025*math.sin(t+.2); head.rotation_euler.z=.045*math.sin(t+.4)
        tail.rotation_euler.z=.12*math.sin(t-math.pi/4); tip.rotation_euler.z=.19*math.sin(t-math.pi/2)
        if a=='idle': head.rotation_euler.x=.06*math.sin(t+.7); jaw.rotation_euler.x=.025*math.sin(t+.6)
        if a=='run':
            body.location.z+=.012*math.cos(2*t); chest.rotation_euler.x=.065*math.sin(2*t-.5)
            for hip,knee,foot,i,sign in legs:
                p=t+i*math.pi+(math.pi if sign<0 else 0)
                plant(hip,knee,foot,(.035,-.16),(-.065,-.17),-.03+.105*math.cos(p),-.33-.012*math.cos(2*t)+.095*max(0,math.sin(p)))
            tail.rotation_euler.z=.27*math.sin(t-math.pi/4)
        if a=='charge':
            p=f/(n-1); body.location.z-=.08*p; body.scale.z=1+.12*p
            chest.rotation_euler.x=-.22*p; head.rotation_euler.x=.20*p
            tail.rotation_euler.x=-.15*p
            for hip,knee,foot,i,sign in legs:
                plant(hip,knee,foot,(.035,-.16),(-.065,-.17),-.03+.04*p,-.33+.08*p)
        if a=='leap':
            body.location.z+=.065+.012*math.sin(t); body.rotation_euler.x=-.11
            chest.rotation_euler.x=.22+.06*math.sin(t); head.rotation_euler.x=-.18
            for hip,knee,foot,i,sign in legs:
                hip.rotation_euler.x=(-.75 if i else .60)+.10*math.sin(t+i); knee.rotation_euler.x=-.6+.07*math.cos(t)
        if a=='attack':
            ext=(0,-.035,-.07,.10,.04,.008)[f]
            chest.rotation_euler.z=(0,.17,.30,-.35,-.13,-.02)[f]
            head.rotation_euler.z=(.1,.26,.40,-.48,-.16,.02)[f]
            head.location.y-=ext; body.location.y-=ext*.30
            jaw.rotation_euler.x=(.04,.18,.32,.85,.34,.07)[f]
            if f==3: mouth.scale=(1,1,1)
        if a=='death':
            p=f/(n-1); body.location.y-=.065*p; body.location.z-=.195*p
            body.rotation_euler.x=.20*p; body.scale.z=1-.30*p
            head.rotation_euler.x=.35*p; jaw.rotation_euler.x=.18*p
            tail.rotation_euler.z=.28*p
            for hip,knee,foot,i,sign in legs:
                hip.rotation_euler.y=-sign*.65*p; knee.rotation_euler.x=-.30*p
    deliver('leaper_tier2_moss',(96,96),82,dict(idle=4,run=8,charge=6,leap=4,attack=6,death=4),root,pose)


def brute():
    rig((128,136),124)
    stone=material('Pale shrine limestone','C5C7B8'); shade=material('Weathered stone fractures','7A8277')
    rootwood=material('Cedar root heartwood','625949'); moss=material('Quiet grey moss','63785F')
    dark=material('Empty lantern niche','343C36'); bronze=material('Votive old bronze','94896B')
    glow=material('Forest accent 9CF0C8','9CF0C8',1)
    root=empty('Gardien de sanctuaire direction'); hips=empty('Articulated masonry pelvis',(0,0,.60),root)
    torso=empty('Toppled shrine chest',(0,0,.18),hips)
    plate('Chipped shrine plinth',(0,.015,0),(.59,.39,.25),stone,hips,.055)
    # Separate jambs and lintel leave a deep, genuinely hollow chest niche.
    plate('Rear wall of hollow shrine',(0,.12,.29),(.64,.19,.61),shade,torso,.045)
    for sign in (-1,1):
        o=plate('Pale eroded chest jamb',(sign*.235,-.04,.30),(.18,.33,.62),stone,torso,.035)
        o.rotation_euler.y=sign*.08
        o=plate('Broken broad shoulder',(sign*.43,.01,.51),(.31,.39,.24),stone,torso,.045)
        o.rotation_euler.y=sign*.13
    plate('Cracked niche lintel',(0,-.035,.59),(.59,.34,.16),stone,torso,.035)
    plate('Niche stone sill',(0,-.06,.08),(.48,.32,.11),stone,torso,.025)
    plate('Dark recessed niche',(0,.007,.32),(.28,.06,.37),dark,torso,.018)
    lantern=empty('Hanging chest lantern',(0,-.055,.30),torso)
    plate('Bronze lantern cap',(0,0,.105),(.19,.15,.05),bronze,lantern,.015)
    plate('Pale green lantern paper',(0,0,0),(.105,.10,.16),glow,lantern,.012)
    for x in (-.07,.07): taper('Lantern frame',(x,-.06,-.09),(x,-.06,.09),(.012,.009),bronze,lantern,4)
    head=empty('Erased stone face',(0,-.015,.75),torso)
    o=plate('Small effaced statue head',(0,0,0),(.27,.26,.29),stone,head,.065); o.rotation_euler.y=-.12
    plate('Obscured facial plane',(0,-.126,-.015),(.18,.025,.13),shade,head,.018)
    for sign in (-1,1): ellipsoid('Faint green eye',(sign*.048,-.148,.013),(.021,.014,.014),glow,head)
    plate('Broken shrine crest',(-.065,.035,.18),(.30,.23,.075),stone,head,.022)
    # Thick root veins grip the stone, leaving its pale upper planes visible.
    for sign in (-1,1):
        for j in range(2):
            a=(sign*(.27+j*.04),-.21,.54-j*.06); b=(sign*(.15+j*.05),-.22,.18-j*.08)
            taper('Root gripping shrine',a,b,(.037,.016),rootwood,torso,5)
        ellipsoid('Moss shoulder cushion',(sign*.40,.02,.64),(.135,.15,.035),moss,torso)
    arms=[]
    for sign in (-1,1):
        shoulder=empty('Guardian shoulder '+str(sign),(sign*.45,0,.44),torso)
        elbow=empty('Guardian elbow',(sign*.035,0,-.25),shoulder)
        taper('Thick stone upper arm',(0,0,0),tuple(elbow.location),(.14,.10),stone,shoulder,7)
        taper('Root bound forearm',(0,0,0),(0,-.055,-.22),(.11,.075),rootwood if sign>0 else stone,elbow,7)
        arms.append((shoulder,elbow,sign))
        if sign<0: plate('Eroded left fist',(0,-.055,-.23),(.18,.20,.17),stone,elbow,.035)
        else: right=elbow
    weapon=empty('Uprooted cedar root mace',(0,-.055,-.22),right)
    taper('Crooked root handle',(0,.05,.035),(.015,-.22,-.39),(.08,.06),rootwood,weapon,6)
    ellipsoid('Heavy earth root ball',(.015,-.29,-.40),(.20,.23,.18),rootwood,weapon,2)
    ellipsoid('Pale stone caught in root ball',(.045,-.32,-.32),(.15,.17,.105),stone,weapon)
    for j in range(4):
        a=j*math.tau/4
        taper('Torn clod root',(.015,-.29,-.40),(.015+.24*math.cos(a),-.34,-.40+.20*math.sin(a)),(.045,.009),rootwood,weapon,5)
    flash=empty('Impact root sap',(0,-.47,-.35),weapon)
    for j in (-1,0,1): ellipsoid('Green sap split',(j*.07,0,j*.025),(.025,.025,.065),glow,flash)
    chain=empty('Lagged votive chain',(-.34,-.18,.40),torso)
    for j in range(5):
        bpy.ops.mesh.primitive_torus_add(major_segments=8,minor_segments=4,major_radius=.038,minor_radius=.009)
        o=bpy.context.object; o.name='Interlocking votive chain link'; o.parent=chain; o.location=(0,0,-j*.06)
        o.rotation_euler=(math.pi/2,0,(j%2)*math.pi/2); o.data.materials.append(bronze)
    fin('Hanging votive tablet',[(-.055,0,-.27),(.055,0,-.27),(.045,0,-.37),(0,0,-.41),(-.045,0,-.37)],.035,stone,chain)
    legs=[]; refs=[]
    for sign in (-1,1):
        hip=empty('Guardian hip '+str(sign),(sign*.19,0,-.05),hips)
        knee=empty('Guardian knee',(0,0,-.24),hip)
        taper('Bulky stone thigh',(0,0,0),(0,0,-.24),(.155,.105),stone,hip,7)
        taper('Chipped stone shin',(0,0,0),(0,0,-.23),(.11,.085),shade,knee,6)
        plate('Pale shin plane',(0,-.065,-.10),(.15,.09,.19),stone,knee,.025)
        foot=empty('Guardian ankle',(0,0,-.23),knee)
        plate('Broken plinth foot',(sign*.015,-.055,-.025),(.26,.31,.10),stone,foot,.03)
        legs.append((hip,knee,foot,sign)); refs.extend((sign*.32,y,.0) for y in (-.21,.10))
    root.scale=(.97,)*3
    root['foot_reference']=[tuple(.97*v for v in p) for p in refs]; reset=resetters(root)
    solid=[o for o in root.children_recursive if o.type=='MESH']
    def pose(a,f,n):
        reset(); t=math.tau*f/n; flash.scale=(.015,)*3
        torso.scale.z=1+.018*math.sin(t+.2); head.rotation_euler.z=.035*math.sin(t+.6)
        chain.rotation_euler.x=.10*math.sin(t-math.pi/4); lantern.rotation_euler.y=.07*math.sin(t-math.pi/2)
        if a=='idle': arms[0][1].rotation_euler.x=.06*math.sin(t+.4)
        if a=='run':
            hips.location.z+=.018*math.cos(2*t); torso.rotation_euler.z=.055*math.sin(t)
            for hip,knee,foot,sign in legs:
                p=t+(math.pi if sign<0 else 0)
                plant(hip,knee,foot,(0,-.24),(0,-.23),.14*math.cos(p),-.475-.018*math.cos(2*t)+.13*max(0,math.sin(p)))
            for shoulder,elbow,sign in arms: shoulder.rotation_euler.x=-sign*.25*math.cos(t-.3)
            chain.rotation_euler.x=.26*math.sin(t-math.pi/4)
        if a in ('attack','cast'):
            ext=(0,-.14,-.30,-.40,1,.27,.10,.025)[f]
            torso.rotation_euler.z=-.27*ext if a=='attack' else .015*math.sin(t)
            torso.rotation_euler.x=.13*max(0,ext) if a=='cast' else .04*ext
            for shoulder,elbow,sign in arms:
                if sign>0:
                    shoulder.rotation_euler.x=-.95*ext if a=='attack' else (-1.5*ext if ext<0 else -.12*ext)
                    shoulder.rotation_euler.z=-.62*ext if a=='attack' else .08*ext
                    shoulder.rotation_euler.y=-.12*ext if a=='attack' else .12*max(0,ext)
                    elbow.rotation_euler.x=-.25*abs(ext)
                else: shoulder.rotation_euler.x=-.18*ext
            if a=='cast':
                crouch=.12*max(0,ext); hips.location.z-=crouch; weapon.rotation_euler.x=.55*max(0,ext)
                for hip,knee,foot,sign in legs:
                    plant(hip,knee,foot,(0,-.24),(0,-.23),0,-.475+crouch)
            chain.rotation_euler.x=.30*math.sin(t-math.pi/4)
            if f==n//2: flash.scale=(1,1,1); lantern.scale=(1.25,1.25,1.25)
        if a=='death':
            p=f/(n-1); hips.location.z-=.29*p; hips.location.y+=.08*p
            torso.rotation_euler.x=.75*p; torso.scale.z=1-.28*p; head.rotation_euler.x=.25*p
            for hip,knee,foot,sign in legs:
                hip.rotation_euler.x=-.55*p; knee.rotation_euler.x=-.85*p; foot.rotation_euler.x=1.4*p
            for shoulder,elbow,sign in arms: shoulder.rotation_euler.x=.45*p; elbow.rotation_euler.x=-.25*p
            bpy.context.view_layer.update()
            floor=min((o.matrix_world@Vector(v)).z for o in solid for v in o.bound_box)
            hips.location.z+=max(0,.015-floor)
    deliver('brute_tier3_moss',(128,136),124,dict(idle=4,run=8,attack=8,cast=8,death=6),root,pose)


def contact_f2():
    # Reuse the pilot's AtlasTexture-aware Ash Lord reference and game scale.
    import inspect, t2_build
    source=inspect.getsource(t2_build.contact_t2)
    source=source.replace('contact_t2','contact_f2_impl').replace('terrain/terraces/','terrain/fog_forest/')
    source=source.replace("'leaper_tier2'","'leaper_tier2_moss'").replace("'brute_tier3'","'brute_tier3_moss'")
    source=source.replace('_mob_v2_t2_contact.png','_mob_v2_f2_contact.png')
    scope=dict(globals()); exec(source,scope); scope['contact_f2_impl']()
    print('F2 CONTACT PASS',flush=True)


if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'leaper'
    {'leaper':leaper,'brute':brute,'contact':contact_f2}[role]()
