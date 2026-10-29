"""MOB_V2_C2: new articulated rust-city creatures. leaper|brute|contact; --audit."""
import sys, math, inspect
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters
from t2_build import plate, fin, ring, plant, finish
from c1_build import audit

def spring(name,parent,mat):
    verts=[]; faces=[]; steps=72; sides=4
    for i in range(steps+1):
        a=i/steps*math.tau*6
        center=Vector((.115*math.cos(a),-.18+i/steps*.43,.115*math.sin(a)))
        for j in range(sides):
            b=j*math.tau/sides
            verts.append(center+Vector((math.cos(a)*math.cos(b),math.sin(b),math.sin(a)*math.cos(b)))*.026)
    for i in range(steps):
        for j in range(sides): faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
    return mesh(name,verts,faces,mat,parent)

def setup(size,bottom):
    s=rig(size,bottom); s.eevee.taa_render_samples=8
    return (material('Zinc pale metal','C6C9BB'), material('Industrial rust','6B3A22'),material('Black iron','2B2A29'),material('Lamp orange FF9A3C','FF9A3C',1))

def deliver(*args):
    if '--audit' in sys.argv:
        audit(*args)
    else:
        # Shared pipeline, restricted to the three frontal impact cells.
        import common_v2 as cv
        name,size,bottom,counts,root,pose=args
        out=ROOT/'game/assets/sprites/monsters'/name
        limits={p.name:p.stat().st_size for p in out.glob('*.png')}
        original_tres=(out/(name+'.tres')).read_bytes()
        source=inspect.getsource(cv.produce).replace('def produce(', 'def impact_produce(')
        source=source.replace("sheets={k:Image.new('RGBA',(size[0]*n,size[1]*len(dirs))) for k in ('','_e')}",
            "sheets={k:Image.open(out/(a+k+'.png')).convert('RGBA') for k in ('','_e')}")
        source=source.replace("for row,d in enumerate(dirs):", "for row,d in enumerate(dirs):\n            if d not in ('s','se','sw'): continue")
        source=source.replace("for f in range(n):\n                pose", "for f in range(n):\n                if f != n//2: continue\n                pose")
        source=source.replace("sheets[suffix].paste(im,(f*size[0],row*size[1]))", "sheets[suffix].paste(im.resize((size[0]//2,size[1]//2),Image.Resampling.LANCZOS) if suffix else im,(f*size[0]//2,row*size[1]//2) if suffix else (f*size[0],row*size[1]))")
        source=source.replace("if suffix: im=im.resize(((im.width+1)//2,(im.height+1)//2),Image.Resampling.LANCZOS)", "# Emission atlas already at half resolution.")
        source=source.replace('    tres(name,size,counts,out)', '    # Preserve existing SpriteFrames bytes.')
        ns=dict(vars(cv)); exec(source,ns); ns['impact_produce'](*args)
        assert (out/(name+'.tres')).read_bytes()==original_tres
        for filename,limit in limits.items():
            p=out/filename
            if p.stat().st_size>limit:
                # Lossless recompression preserves every untouched atlas pixel.
                import subprocess
                subprocess.run(['python','-c',
                    'import sys,zopfli.png; p=sys.argv[1]; data=open(p,"rb").read(); result=zopfli.png.optimize(data,num_iterations=5); open(p,"wb").write(result)',str(p)],check=True)
            assert p.stat().st_size<=limit,(filename,p.stat().st_size,limit)

def leaper():
    pale,rust,dark,glow=setup((96,96),82)
    root=empty('Chien ressort direction'); body=empty('Articulated spring chassis',(0,0,.43),root)
    coil=empty('Compressible helical spine',(0,.015,.065),body); spring('Six turn exposed zinc spring',coil,pale)
    rear=empty('Oversized piston haunch',(0,.235,0),body)
    front=empty('Front chest carriage',(0,-.22,0),body)
    for p,sz in ((rear,(.40,.24,.28)),(front,(.30,.20,.24))):
        plate('Zinc folded chassis', (0,0,.015),sz,pale,p)
        plate('Rust chassis inset',(0,-.02,.11),(sz[0]*.68,.12,.055),rust,p)
    for side in (-1,1):
        fin('Raised chipped dorsal shield',[(side*.03,-.08,.17),(side*.22,-.04,.18),(side*.19,.12,.09),(side*.04,.16,.12)],.035,pale,rear)
    head=empty('Neck steering hinge',(0,-.115,.025),front)
    plate('Dog clamp skull',(0,-.095,0),(.24,.25,.16),pale,head)
    plate('Black clamp recess',(0,-.227,-.025),(.18,.025,.09),dark,head,.005)
    jaw=empty('True lower clamp hinge',(0,-.005,-.075),head)
    fin('Lower hooked clamp',[(-.115,0,0),(-.09,-.26,0),(-.04,-.29,.07),(.04,-.29,.07),(.09,-.26,0),(.115,0,0)],.042,rust,jaw)
    flash=empty('Impact furnace mouth',(0,-.20,-.04),head)
    plate('Orange mouth',(0,0,0),(.14,.09,.035),glow,flash,.005)
    for side in (-1,1):
        plate('Furnace eye housing',(side*.125,-.12,.045),(.04,.09,.075),dark,head,.008)
        ellipsoid('Orange eye',(side*.15,-.14,.05),(.022,.032,.025),glow,head)
        fin('Pointed dog ear',[(side*.07,0,.06),(side*.15,.06,.23),(side*.16,-.03,.06)],.045,pale,head)
    tail=empty('Delayed hooked metal tail',(0,.12,.075),rear)
    fin('Tapered riveted tail',[(-.055,0,0),(-.04,.12,.07),(-.02,.23,.04),(.025,.27,.08),(.055,.10,.10),(.055,0,0)],.055,rust,tail)
    legs=[]; refs=[]
    for i,parent in enumerate((front,rear)):
        for sign in (-1,1):
            hip=empty('Hip %d %d'%(i,sign),(sign*(.15 if i==0 else .20),0,-.045),parent)
            knee=empty('Knee',(0,0,-.19),hip)
            taper('Tapered piston thigh',(0,0,0),(0,0,-.19),(.085 if i else .055,.043),pale,hip,6)
            taper('Rust hydraulic shin',(0,0,0),(0,0,-.17),(.043,.022),rust,knee,6)
            plate('Piston knee cap',(0,-.025,0),(.10,.09,.075),dark,knee,.012)
            ankle=empty('Planted claw ankle',(0,0,-.17),knee)
            plate('Split metal paw',(0,-.035,-.025),(.12,.17,.07),pale,ankle,.012)
            legs.append((hip,knee,ankle,i,sign)); refs.append((sign*(.15 if i==0 else .20),(-.22 if i==0 else .235)-.07,.0))
    root.scale=(.90,)*3; root['foot_reference']=[tuple(v*.90 for v in p) for p in refs]; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; flash.scale=(.02,)*3
        body.scale.z=1+.024*math.sin(t+.3); head.rotation_euler.z=.04*math.sin(t+.4)
        tail.rotation_euler.z=.14*math.sin(t-.8)
        if a=='idle': jaw.rotation_euler.x=.06+.035*math.sin(t+.8)
        if a=='run':
            bob=.012*math.cos(t*2); body.location.z+=bob
            for hip,knee,ankle,i,sign in legs:
                p=t+i*math.pi+(math.pi if sign<0 else 0)
                plant(hip,knee,ankle,(0,-.19),(0,-.17),.10*math.cos(p),-.32-bob+.09*max(0,math.sin(p)))
            head.rotation_euler.x=.09*math.sin(t); tail.rotation_euler.z=.25*math.sin(t-.8)
        if a=='charge':
            p=f/(n-1); coil.scale.y=1-.52*p; rear.location.y-=.15*p; front.location.y+=.06*p
            body.location.z-=.07*p; head.rotation_euler.x=-.2*p
            for hip,knee,ankle,i,sign in legs:
                plant(hip,knee,ankle,(0,-.19),(0,-.17),.015,-.32+.07*p)
        if a=='leap':
            coil.scale.y=1.15+.035*math.sin(t); rear.location.y+=.035; front.location.y-=.035
            body.location.z+=.07+.012*math.sin(t); jaw.rotation_euler.x=.20+.04*math.cos(t)
            for hip,knee,ankle,i,sign in legs:
                hip.rotation_euler.x=(-.55 if i else .50)+.08*math.sin(t+i); knee.rotation_euler.x=-.35+.07*math.cos(t)
        if a=='attack':
            ext=(0,-.035,-.065,.085,.035,.006)[f]; front.location.y-=ext; coil.scale.y=1+ext*2
            jaw.rotation_euler.x=(.12,.30,.60,.025,.16,.07)[f]; head.rotation_euler.x=(0,-.08,-.16,.15,.05,.01)[f]
            body.location.y-=ext*.3
            if f==3:
                flash.scale=(1,)*3
                if abs(root.rotation_euler.z)<=math.pi/4+.001:
                    head.location.y-=.19
                    head.location.z+=.035
                    head.rotation_euler.x=.38
                    head.rotation_euler.z=0
                    jaw.rotation_euler.x=.52
        if a=='death':
            p=f/(n-1); body.location.z-=.12*p; body.location.y-=.04*p
            body.rotation_euler.x=.32*p; body.scale.z=1-.24*p; coil.scale.y=1-.2*p
            head.rotation_euler.x=.3*p; jaw.rotation_euler.x=.4*p
            for hip,knee,ankle,i,sign in legs: hip.rotation_euler.y=-sign*.8*p; knee.rotation_euler.x=-.4*p
    deliver('leaper_tier2_rust',(96,96),82,dict(idle=4,run=8,charge=6,leap=4,attack=6,death=4),root,pose)


def brute():
    pale,rust,dark,glow=setup((128,136),124)
    root=empty('Chauffeur de cuve direction'); hips=empty('Weight bearing pelvis',(0,0,.64),root)
    torso=empty('Boiler torso joint',(0,0,.24),hips)
    plate('Riveted pelvis',(0,0,0),(.51,.32,.22),rust,hips)
    ellipsoid('Faceted pressure boiler',(0,0,.22),(.40,.28,.43),rust,torso,2)
    plate('Pale boiler back shield',(0,.22,.25),(.61,.11,.52),pale,torso)
    plate('Pale crown plate',(0,0,.54),(.58,.40,.12),pale,torso)
    for z in (.02,.41):
        o=ring('Black pressure vessel band',(0,0,z),.35,.025,dark,torso); o.scale.y=.79
    plate('Furnace black door',(0,-.275,.16),(.38,.08,.33),dark,torso)
    plate('Orange coal furnace',(0,-.321,.16),(.28,.021,.23),glow,torso,.009)
    for x in (-.10,0,.10): plate('Iron fire grate',(x,-.34,.16),(.032,.025,.27),dark,torso,.004)
    shoulders=[]; elbows=[]
    for sign in (-1,1):
        shoulder=empty('Shoulder '+str(sign),(sign*.47,0,.43),torso)
        o=plate('Chipped pale concrete pauldron',(sign*.025,0,.01),(.35,.38,.24),pale,shoulder,.045)
        o.rotation_euler.y=sign*.18
        fin('Broken pauldron notch',[(sign*.10,-.20,.10),(sign*.17,-.20,.02),(sign*.12,-.20,-.06)],.025,rust,shoulder)
        elbow=empty('Elbow '+str(sign),(sign*.035,0,-.29),shoulder)
        taper('Heavy variable section upper arm',(0,0,0),tuple(elbow.location),(.135,.085),rust,shoulder,6)
        taper('Forged tapered forearm',(0,0,0),(0,-.065,-.23),(.10,.065),pale,elbow,6)
        plate('Iron glove',(0,-.065,-.23),(.16,.18,.16),dark,elbow)
        shoulders.append(shoulder); elbows.append(elbow)
    head=empty('Recessed stoker helmet',(0,-.025,.60),torso)
    plate('Small iron mask',(0,-.02,.035),(.22,.20,.18),dark,head)
    plate('Pale helmet brim',(0,-.025,.14),(.30,.27,.055),pale,head,.014)
    for sign in (-1,1): ellipsoid('Lamp eye',(sign*.055,-.125,.062),(.027,.018,.023),glow,head)
    # Asymmetric tools: articulated crane chain and broad coal shovel.
    chain=empty('Delayed chain wrist',(0,-.065,-.29),elbows[1])
    for j in range(3):
        o=ring('Interlocking crane chain',(0,0,-j*.062),.041,.016,pale,chain)
        o.rotation_euler.x=math.pi/2
        if j%2: o.rotation_euler.z=math.pi/2
    hook=empty('Crane hook hinge',(0,0,-.17),chain)
    points=[(-.035,0,.04),(.045,0,.04),(.045,0,-.065),(.13,0,-.11),(.16,0,-.045),(.17,0,.02),(.22,0,-.03),(.21,0,-.13),(.14,0,-.20),(.05,0,-.20),(-.04,0,-.13)]
    # Extrusion across Y preserves a clearly open C-shaped forged hook.
    fin('Large open forged crane hook',[(x,z,y) for x,y,z in points],.085,pale,hook).rotation_euler.x=math.pi/2
    flash=empty('Impact hot hook edge',(.14,-.048,-.14),hook)
    plate('Orange striking edge',(0,0,0),(.11,.027,.06),glow,flash,.008)
    shovel=empty('Coal shovel grip',(0,-.065,-.27),elbows[0])
    taper('Tapered shovel handle',(0,0,.10),(0,0,-.20),(.037,.025),rust,shovel,5)
    fin('Broad coal shovel blade',[(-.12,-.16,-.14),(-.15,-.19,-.35),(.15,-.19,-.35),(.12,-.16,-.14)],.07,dark,shovel)
    plate('Pale shovel cutting edge',(0,-.19,-.33),(.28,.08,.055),pale,shovel,.012)
    steam=[]
    for sign in (-1,1):
        vent=empty('Joint steam articulated',(sign*.32,.18,.45),torso)
        for j in range(2): ellipsoid('Angular pale steam puff',(sign*j*.035,.02*j,.06+j*.08),(.046-j*.01,.039,.055-j*.012),pale,vent)
        steam.append(vent)
    legs=[]; refs=[]
    for sign in (-1,1):
        hip=empty('Hip '+str(sign),(sign*.19,0,-.045),hips)
        knee=empty('Knee '+str(sign),(0,0,-.28),hip)
        taper('Broad work trouser thigh',(0,0,0),(0,0,-.28),(.15,.10),rust,hip,6)
        plate('Pale thigh armour',(0,-.09,-.12),(.23,.12,.24),pale,hip)
        taper('Tapered heavy boot shin',(0,0,0),(0,0,-.26),(.105,.065),dark,knee,6)
        plate('Pale knee guard',(0,-.065,0),(.20,.10,.13),pale,knee)
        ankle=empty('Boot ankle',(0,0,-.26),knee)
        plate('Steel work boot',(0,-.07,-.025),(.25,.33,.11),pale,ankle)
        legs.append((hip,knee,ankle,sign)); refs.append((sign*.19,-.16,0))
    wave=empty('Ground impact pressure wave',(0,-.12,.035),root)
    ring('Orange pressure front',(0,0,0),.42,.025,glow,wave)
    root['foot_reference']=[(sign*.19+dx,y,-.025) for sign in (-1,1) for dx in (-.125,.125) for y in (-.235,.095)]; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; flash.scale=(.02,)*3; wave.scale=(.001,)*3
        torso.scale.z=1+.022*math.sin(t+.2); head.rotation_euler.z=.035*math.sin(t+.8)
        chain.rotation_euler.x=.09*math.sin(t-.9)
        for j,o in enumerate(steam): o.scale=(1,1,1+.12*math.sin(t-j*.6))
        if a=='idle': elbows[0].rotation_euler.x=.06*math.sin(t+.5)
        if a=='run':
            bob=.016*math.cos(t*2); hips.location.z+=bob; torso.rotation_euler.z=.055*math.sin(t)
            for hip,knee,ankle,sign in legs:
                p=t+(math.pi if sign<0 else 0)
                plant(hip,knee,ankle,(0,-.28),(0,-.26),.17*math.cos(p),-.51-bob+.13*max(0,math.sin(p)))
            for j,o in enumerate(shoulders): o.rotation_euler.x=.30*math.sin(t+j*math.pi)
            chain.rotation_euler.x=.27*math.sin(t-.9); shovel.rotation_euler.x=.10*math.sin(t-.6)
        if a in ('attack','cast'):
            extension=(0,-.08,-.16,-.22,1,.50,.19,.025)[f]
            if a=='attack':
                shoulders[1].rotation_euler.x=-.65*extension
                shoulders[1].rotation_euler.z=-.35*extension
                elbows[1].rotation_euler.x=-.15*extension
                torso.rotation_euler.z=-.19*extension
                chain.rotation_euler.x=.12*extension
            else:
                lift=(0,-.35,-.80,-1.20,.12,-.10,-.06,0)[f]
                shoulders[1].rotation_euler.x=lift
                shoulders[1].rotation_euler.z=-.45*min(1,abs(lift))
                elbows[1].rotation_euler.x=-.12
                torso.rotation_euler.x=(0,-.05,-.10,-.16,.30,.17,.06,.01)[f]
                hips.location.z-=(0,0,0,0,.045,.025,.01,0)[f]
                chain.rotation_euler.x=-.12 if f==4 else .10*math.sin(t)
                if f==4: chain.scale.z=1.6; chain.location.z-=.06
                if f>=4: wave.scale=(.45+.17*(f-4),)*2+(1,)
            if f==4:
                flash.scale=(1,)*3
                if abs(root.rotation_euler.z)<=math.pi/4+.001:
                    shoulders[1].location.x-=.16
                    shoulders[1].rotation_euler.x=-.90 if a=='attack' else -.62
                    shoulders[1].rotation_euler.z=-.08
                    elbows[1].rotation_euler.x=-.30
                    chain.rotation_euler.x=.35 if a=='attack' else -.18
                    chain.scale.z=1.0 if a=='attack' else 1.30
                    hook.rotation_euler.z=.35
                    hook.location.y-=.025
            head.rotation_euler.x=.08*extension; shoulders[0].rotation_euler.x=.12*extension
        if a=='death':
            p=f/(n-1); hips.location.z-=.16*p; hips.location.y-=.04*p
            torso.rotation_euler.x=.65*p; torso.scale.z=1-.25*p
            head.rotation_euler.x=.35*p
            for hip,knee,ankle,sign in legs: plant(hip,knee,ankle,(0,-.28),(0,-.26),.05*p,-.51+.16*p)
            for j,o in enumerate(shoulders): o.rotation_euler.x=-.65*p; o.rotation_euler.z=(1 if j else -1)*.25*p
            elbows[1].rotation_euler.x=-.65*p; elbows[0].rotation_euler.x=-.5*p; chain.rotation_euler.x=.15*p
    deliver('brute_tier3_rust',(128,136),124,dict(idle=4,run=8,attack=8,cast=8,death=6),root,pose)

def contact():
    import common_v2
    source=inspect.getsource(common_v2.contact).replace('def contact():','def assemble():')
    source=source.replace('terrain/terraces/','terrain/rust_city/').replace('_mob_v2_t1_contact.png','_mob_v2_c2_contact.png')
    source=source.replace("(62,'swarm_tier1',(64,56),48,6),(157,'shooter_tier2',(88,104),96,8)","(66,'leaper_tier2_rust',(96,96),82,6),(172,'brute_tier3_rust',(128,136),124,8)")
    ns=dict(globals()); exec(source,ns); ns['assemble']()

if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'leaper'
    globals()[role]()

