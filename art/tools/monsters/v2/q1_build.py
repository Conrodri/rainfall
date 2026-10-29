"""MOB_V2_Q1: new storm bronze / flowing water creatures. No normal outputs."""
import sys, math, os, subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters

def deliver(name,size,bottom,counts,root,pose):
    if '--bounds' not in sys.argv:
        result=produce(name,size,bottom,counts,root,pose)
        compact(name)
        return result
    failures=[]
    for a,n in counts.items():
        for d in (('e','s','w','n') if a=='death' else DIRS):
            root.rotation_euler.z=math.radians(90-45*DIRS.index(d))
            rot=root.rotation_euler.to_matrix()
            low=min((rot@Vector(p)).y*.5+p[2]*math.cos(math.pi/6) for p in root['foot_reference'])
            for f in range(n):
                pose(a,f,n); bpy.context.view_layer.update()
                for o in root.children_recursive:
                    if o.type!='MESH': continue
                    for v in o.data.vertices:
                        p=o.matrix_world@v.co
                        x=size[0]/2+p.x*64; y=bottom+low*64-(p.y*.5+p.z*math.cos(math.pi/6))*64
                        if not (4<=x<=size[0]-4 and 4<=y<=size[1]-4):
                            failures.append((a,d,f,o.name,round(x,1),round(y,1))); break
    print('BOUNDS',name,'PASS' if not failures else failures[:12],flush=True)

def compact(name):
    # Original per-atlas byte ceilings; pngquant is only needed above the ceiling.
    limits = {'swarm_tier1_source': (122846,21317,36505,6342,78589,13761,161307,27254),
              'shooter_tier2_source': (326232,46234,75989,10765,158901,21925,353270,48764)}
    for filename,limit in zip(('attack.png','attack_e.png','death.png','death_e.png','idle.png','idle_e.png','run.png','run_e.png'),limits[name]):
        path=ROOT/'game/assets/sprites/monsters'/name/filename
        if path.stat().st_size>limit:
            subprocess.run([os.environ.get('RAINFALL_PNGQUANT','pngquant'),'--force','--ext','.png','--speed','1','--quality','85-100',str(path)],check=True)
        assert path.stat().st_size<=limit,(filename,path.stat().st_size,limit)

def palette():
    return (material('Rain blackened bronze','887354'),material('Worn bronze bevels','B49A6C'),
            material('Opaque silver water reflections','A49C85'),material('Water deep folds','687C73'),
            material('Cold white DDF6FF','DDF6FF',1.8))

_taper = taper
def taper(name, a, b, radii, mat, parent, sides=5):
    return _taper(name,a,b,tuple(r*1.4 for r in radii),mat,parent,sides)

def spike(name,loc,width,length,height,mat,parent):
    # Chiselled lightning fin: solid wedge, broken diamond cross section.
    o=mesh(name,[(-width,0,0),(0,-length,height*.3),(width,0,0),(0,length*.36,0),(0,0,height),(0,0,-height*.25)],
           [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)],mat,parent)
    o.location=loc; return o

def solve(hip,knee,y,z,l1,l2):
    bend=-math.acos(max(-.999,min(.999,(y*y+z*z-l1*l1-l2*l2)/(2*l1*l2))))
    hip.rotation_euler.x=math.atan2(y,-z)-math.atan2(l2*math.sin(bend),l1+l2*math.cos(bend))
    knee.rotation_euler.x=bend

def swarm():
    rig((64,56),48); bronze,edge,water,fold,glow=palette()
    root=empty('Goutte rampante direction'); body=empty('Crawling lightning keel',(0,0,.22),root)
    spike('Forged central lightning point',(0,-.015,0),.15,.28,.17,bronze,body)
    spike('Pale rain flowing on upper bevel',(0,.005,.10),.145,.24,.09,water,body)
    tail=empty('Lagged runoff fin',(0,.14,.045),body)
    spike('Broad broken rear barb',(0,0,0),.17,.10,.07,water,tail)
    head=empty('Thrust pivot',(0,-.14,.04),body)
    ellipsoid('White water bead',(0,-.025,.025),(.090,.090,.084),glow,head,2)
    for sign in (-1,1):
        taper('Bronze head fork',(sign*.082,.055,-.025),(sign*.053,-.12,-.015),(.032,.005),edge,head)
    tip=empty('Impact lightning point',(0,-.08,-.005),head)
    spike('Puncturing tip',(0,0,0),.047,.06,.025,edge,tip)
    flash=empty('Impact white water pivot',(0,-.025,.025),tip)
    ellipsoid('Impact white water',(0,0,0),(.04,.045,.035),glow,flash)
    runoff=[]
    for sign in (-1,1):
        p=empty('Flowing pendant',(sign*.095,.06,.09),body); runoff.append(p)
        taper('Continuous pale runoff',(0,0,0),(sign*.02,.015,-.15),(.027,.005),water,p)
    legs=[]; refs=[]
    for i,y in enumerate((-.115,.14)):
        for sign in (-1,1):
            hip=empty('Filament hip %d %d'%(i,sign),(sign*.105,y,0),body)
            knee=empty('Filament joint %d %d'%(i,sign),(sign*.09,0,-.105),hip)
            taper('Flattened bronze filament thigh',(0,0,0),tuple(knee.location),(.037,.022),edge,hip)
            taper('Curved tapered walking filament',(0,0,0),(sign*.085,0,-.105),(.023,.007),bronze,knee)
            ellipsoid('Foot knuckle',(sign*.085,0,-.105),(.018,.028,.01),edge,knee)
            legs.append((hip,knee,i,sign)); refs.append((sign*.28,y,.01))
    root['foot_reference']=refs; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; flash.scale=(.01,)*3
        body.scale.z=1+.025*math.sin(t+.2)
        for j,p in enumerate(runoff): p.rotation_euler.x=.13*math.sin(t-.8+j)
        tail.rotation_euler.x=.10*math.sin(t-.8)
        head.rotation_euler.x=.055*math.sin(t+.4)
        if a=='idle': head.rotation_euler.z=.12 if f==2 else -.025*f
        if a=='run':
            body.location.z+=.006*math.sin(2*t)
            for hip,knee,i,sign in legs:
                p=t+math.pi*(i+(sign<0)); y=.073*math.sin(p)
                lift=.055*max(0,math.cos(p))
                solve(hip,knee,y,.01+lift-body.location.z,.105,.105)
            tail.rotation_euler.z=.17*math.sin(t-.8)
        if a=='attack':
            extension=(0,-.045,-.075,.080,.045,.012)[f]
            head.location.y-=extension
            head.rotation_euler.x=(0,-.15,-.23,.28,.12,.02)[f]
            body.location.y+=(0,.018,.025,-.018,-.008,0)[f]
            if f==3: flash.scale=(1,1,1); head.scale=(1.32,1.20,1.18)
        if a=='death':
            body.rotation_euler.x=(.18,.55,.95,1.12)[f]
            body.location.z=(.23,.25,.26,.24)[f]; body.location.y=.008*f
            body.scale.z=1-.14*f
            for hip,knee,i,sign in legs: hip.rotation_euler.y=sign*(.18+.22*f); knee.rotation_euler.x=-.22*f
    deliver('swarm_tier1_source',(64,56),48,dict(idle=4,run=8,attack=6,death=4),root,pose)

def shooter():
    rig((88,104),96); bronze,edge,water,fold,glow=palette()
    root=empty('Paratonnerre errant direction'); pelvis=empty('Articulated bronze pelvis',(0,0,.50),root)
    torso=empty('Forged rain conductor',(0,0,.10),pelvis)
    taper('Angular breast',(0,0,-.12),(0,0,.33),(.12,.156),bronze,torso,6)
    spike('Silver sternum',(0,-.09,.13),.072,.045,.14,water,torso)
    head=empty('Split lightning sphere',(0,0,.42),torso)
    # Two asymmetrical sphere lobes leave a true open fissure around the luminous bead.
    for sign in (-1,1):
        ellipsoid('Split bronze lightning ball',(sign*.073,0,0),(.096,.13,.145),edge,head,2)
        spike('Lightning crown prong',(sign*.087,.015,.085),.026,.045,.13,bronze,head)
    ellipsoid('Cold water in split head',(0,-.035,.005),(.045,.105,.106),glow,head,2)
    cape=[]
    for j in range(7):
        angle=math.pi*j/6
        x=math.cos(angle); y=math.sin(angle)
        p=empty('Waterfall cape hinge %d'%j,(x*.13,y*.09,.29),torso); cape.append(p)
        verts=[]
        for r,z in ((.035,0),(.10,-.23),(.15,-.52),(.13,-.66+(j%2)*.055)):
            for da in (-.24,.24): verts.append((r*math.cos(angle+da),r*math.sin(angle+da),z))
        mesh('Faceted flowing water cape %d'%j,verts,[(0,1,3,2),(2,3,5,4),(4,5,7,6)],water if j%3!=1 else fold,p)
        taper('Pale runoff edge',verts[1],verts[7],(.018,.006),water,p)
    legs=[]; refs=[]
    for sign in (-1,1):
        hip=empty('Hip %d'%sign,(sign*.085,0,0),pelvis)
        knee=empty('Knee %d'%sign,(0,0,-.24),hip)
        taper('Forged tapered thigh',(0,0,0),tuple(knee.location),(.049,.028),bronze,hip)
        taper('Bevelled shin',(0,0,0),(0,0,-.24),(.032,.016),edge,knee)
        taper('Bronze planted foot',(0,.035,-.24),(0,-.095,-.24),(.027,.017),bronze,knee)
        legs.append((hip,knee,sign)); refs.extend(((sign*.085,-.095,-.007),(sign*.085,.035,-.007)))
    arms=[]
    for sign in (-1,1):
        arm=empty('Shoulder %d'%sign,(sign*.16,0,.24),torso)
        elbow=empty('Elbow %d'%sign,(sign*.035,0,-.18),arm)
        taper('Tapered upper conductor arm',(0,0,0),tuple(elbow.location),(.045,.026),bronze,arm)
        taper('Long conductor forearm',(0,0,0),(0,-.035,-.20),(.031,.019),edge,elbow)
        hand=empty('Conductor palm',(0,-.035,-.20),elbow)
        ellipsoid('Wide split bronze palm',(0,0,0),(.062,.052,.070),bronze,hand)
        for dx in (-.027,.027): taper('Conducting finger',(dx,0,-.01),(dx,-.035,-.11),(.012,.004),edge,hand)
        arms.append((arm,elbow,hand,sign))
    shot=empty('Detached impact droplet',(0,-.04,-.07),arms[1][2])
    ellipsoid('White torn free rain drop',(0,0,0),(.042,.045,.06),glow,shot,2)
    root['foot_reference']=refs; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; shot.scale=(.01,)*3
        torso.scale.z=1+.018*math.sin(t+.1); head.rotation_euler.z=.06*math.sin(t+.3)
        for j,p in enumerate(cape): p.rotation_euler.x=.045*math.sin(t-.8+j*.4)
        if a=='idle': head.rotation_euler.x=.09 if f==2 else -.02*f
        if a=='run':
            pelvis.location.z+=.012*math.sin(2*t)
            for hip,knee,sign in legs:
                p=t+(math.pi if sign<0 else 0)
                solve(hip,knee,.125*math.sin(p),.025+.075*max(0,math.cos(p))-pelvis.location.z,.24,.24)
            for arm,elbow,hand,sign in arms: arm.rotation_euler.x=-sign*.40*math.sin(t); elbow.rotation_euler.x=-.20
            for j,p in enumerate(cape): p.rotation_euler.x=.16*math.sin(t-.8+j*.4)
        if a=='attack':
            arm,elbow,hand,sign=arms[1]
            arm.rotation_euler.x=(.05,-.35,-.52,.45,1.80,1.17,.55,.12)[f]
            elbow.rotation_euler.x=(-.15,-.4,-.7,-.45,0,-.15,-.25,-.18)[f]
            arm.rotation_euler.z=(0,.12,.20,.10,-.18,-.10,0,0)[f]
            torso.rotation_euler.x=(0,-.07,-.10,-.03,.09,.06,.02,0)[f]
            head.rotation_euler.x=.10 if f==4 else -.03*f/8
            if f==4: shot.scale=(1.35,1.35,1.35); hand.scale=(1.45,1.40,1.25); arm.location.y-=.08
        if a=='death':
            pelvis.rotation_euler.x=(.18,.60,1.0,1.26)[f]
            pelvis.location.z=(.50,.45,.34,.29)[f]; pelvis.location.y=.025*f
            torso.scale.z=1-f*.14; torso.rotation_euler.x=-.23*f
            for hip,knee,sign in legs:
                hip.rotation_euler.x=-pelvis.rotation_euler.x-.3*f; knee.rotation_euler.x=.55*f
                hip.scale=(1,1,1-.16*f)
            for arm,elbow,hand,sign in arms: arm.rotation_euler.x=.3+f*.2
    deliver('shooter_tier2_source',(88,104),96,dict(idle=4,run=8,attack=8,death=4),root,pose)

def contact_q1():
    # Reuse the validated pilot assembly; correct biome, names and current reference atlas.
    from s1_build import contact_s1
    import inspect
    source=inspect.getsource(contact_s1).replace('contact_s1','contact_q1_impl').replace('terrain/crypts/','terrain/source/').replace('_salt','_source').replace('_mob_v2_s1_contact','_mob_v2_q1_contact')
    ns=globals().copy(); exec(source,ns); ns['contact_q1_impl']()

if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'swarm'
    {'swarm':swarm,'shooter':shooter,'contact':contact_q1}[role]()






