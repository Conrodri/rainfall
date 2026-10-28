"""MOB_V2_Q2. New rain feline and broken lightning pylon; articulated CREA assets."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters
from q1_build import palette, spike, solve, deliver

def feline():
    rig((96,96),82); bronze,edge,water,fold,glow=palette()
    root=empty('Fauve de pluie direction')
    body=empty('Feline breathing spine',(0,0,.45),root)
    ellipsoid('Long smooth bronze ribcage',(0,-.025,0),(.165,.32,.155),bronze,body,2)
    for y,sz in ((-.12,.15),(.08,.18),(.25,.205)):
        ellipsoid('Broad polished dorsal scute',(0,y,.105),(.17,sz,.09),edge,body,2)
    ellipsoid('Powerful raised haunch',(0,.25,-.015),(.205,.19,.19),bronze,body,2)
    neck=empty('Low hunting neck',(0,-.29,.025),body)
    ellipsoid('Arched neck',(0,0,0),(.13,.14,.13),edge,neck,2)
    head=empty('Forward projecting skull',(0,-.12,-.005),neck)
    ellipsoid('Broad feline skull',(0,-.025,0),(.135,.145,.105),bronze,head,2)
    ellipsoid('Pale brow',(0,-.055,.06),(.14,.11,.065),edge,head,2)
    jaw=empty('Opening jaw',(0,-.06,-.055),head)
    ellipsoid('Muzzle',(0,-.06,0),(.105,.085,.045),edge,jaw,2)
    mouth=empty('Impact white mouth',(0,-.115,.025),jaw)
    ellipsoid('Cold mouth slit',(0,0,0),(.08,.022,.018),glow,mouth)
    for sign in (-1,1):
        spike('Swept feline ear',(sign*.11,.035,.08),.047,.035,.09,edge,head)
        ellipsoid('White searching eye',(sign*.097,-.11,.035),(.032,.025,.022),glow,head,2)
        taper('Long canine',(sign*.073,-.11,-.015),(sign*.073,-.13,-.073),(.018,.003),water,head)
    tails=[]; par=body
    for j,(loc,length,r) in enumerate((((0,.29,.02),.13,.055),((0,.13,.025),.12,.044),((0,.12,.015),.10,.03))):
        p=empty('Articulated rain tail %d'%j,loc,par); tails.append(p)
        taper('Curved tapering tail',(0,0,0),(0,length,.02),(r,r*.57),edge if j==2 else bronze,p,6)
        par=p
    runoff=[]
    for sign in (-1,1):
        for y in (-.04,.18):
            p=empty('Runoff pendant',(sign*.16,y,.1),body); runoff.append(p)
            taper('Wide water rivulet',(0,0,0),(sign*.015,.035,-.17),(.026,.006),water,p)
    legs=[]; refs=[]
    for i,y in enumerate((-.22,.23)):
        for sign in (-1,1):
            hip=empty('Feline hip %d %d'%(i,sign),(sign*.145,y,-.025),body)
            l1,l2=(.205,.21)
            knee=empty('Flexing feline knee',(0,0,-l1),hip)
            taper('Sculpted thigh',(0,0,.015),(0,0,-l1),(.075 if i==0 else .11,.044),bronze,hip,7)
            ellipsoid('Polished thigh shield',(sign*.025,0,-.055),(.065,.075,.095),edge,hip,2)
            taper('Narrow shin',(0,0,0),(0,0,-l2),(.044,.025),bronze,knee,6)
            foot=empty('Feline paw',(0,0,-l2),knee)
            ellipsoid('Broad planted paw',(0,-.03,.012),(.066,.085,.036),edge,foot,2)
            for x in (-.037,0,.037):
                taper('White paw fissure',(x,-.015,.039),(x,-.08,.027),(.008,.006),glow,foot,4)
                taper('Hooked claw',(x,-.077,.015),(x,-.124,.007),(.013,.002),water,foot)
            legs.append((hip,knee,foot,i,sign,l1,l2)); refs.append((sign*.145,y-.04,.015))
    root.scale=(.90,)*3; root['foot_reference']=[tuple(.90*c for c in p) for p in refs]; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; mouth.scale=(.025,)*3
        body.scale.z=1+.022*math.sin(t+.25)
        head.rotation_euler.z=.045*math.sin(t+.4)
        for j,p in enumerate(tails): p.rotation_euler.z=.19*math.sin(t-.8-j*.45); p.rotation_euler.x=.08*math.sin(t-.6-j*.4)
        for j,p in enumerate(runoff): p.rotation_euler.x=.12*math.sin(t-.8+j*.3)
        if a=='idle': head.rotation_euler.x=.09 if f==2 else -.012*f
        if a=='run': body.location.z+=.014*math.sin(2*t)
        if a=='charge':
            u=f/(n-1); body.location.z-=.105*u; body.location.y+=.055*u
            neck.rotation_euler.x=-.21*u; head.location.y+=.025*u
        if a=='leap':
            body.location.z+=.06+.012*math.sin(t); body.scale.y=1.08
            neck.location.y-=.045; head.rotation_euler.x=.1
        if a=='attack':
            v=(0,-.055,-.09,.105,.05,.015)[f]
            body.location.y-=v*.35; neck.location.y-=v*.55; head.location.y-=v*.65
            body.location.z+=(0,-.02,-.045,.025,.01,0)[f]
            neck.rotation_euler.x=(0,-.12,-.22,.20,.1,.02)[f]
            jaw.rotation_euler.x=(0,.1,.16,.52,.28,.03)[f]
            if f==3: mouth.scale=(1,1,1); head.scale=(1.12,1.12,1.08)
        for hip,knee,foot,i,sign,l1,l2 in legs:
            dy=0; z=.022-body.location.z+.025
            if a=='run':
                p=t+math.pi*(i+(sign<0)); dy=.135*math.sin(p); z+=.085*max(0,math.cos(p))
            if a=='charge': dy=.025*f/(n-1)
            if a=='leap': dy=(-.17 if i==0 else .17)+.016*math.sin(t+(i*math.pi)); z=-.25
            if a=='attack' and i==0:
                dy=(0,.055,.1,-.24,-.12,-.02)[f]; z+=(0,.025,.065,.14,.065,.01)[f]
            solve(hip,knee,dy,z,l1,l2)
            foot.rotation_euler.x=-hip.rotation_euler.x-knee.rotation_euler.x
            if a=='attack' and i==0:
                spread=(0,.06,.12,.65,.28,.04)[f]
                hip.rotation_euler.y=-sign*spread
                foot.rotation_euler.y=sign*spread*.5
                if f==3: foot.scale=(1.25,)*3
        if a=='death':
            body.rotation_euler.x=(.15,.4,.65,.72)[f]
            body.location.z=(.43,.43,.43,.42)[f]; body.location.y=-.012*f; body.scale.z=1-.14*f
            head.rotation_euler.x=.2+.09*f
            for hip,knee,foot,i,sign,l1,l2 in legs:
                hip.rotation_euler.y=sign*(.12+.18*f); knee.rotation_euler.x=-.25*f
    deliver('leaper_tier2_source',(96,96),82,dict(idle=4,run=8,charge=6,leap=4,attack=6,death=4),root,pose)

def chainlink(name,loc,r,width,mat,parent,turn=0):
    # A real open forged link, with alternating planes, rather than a solid rod.
    verts=[]
    for radius in (r,r-width):
        for z in (-width*.5,width*.5):
            for k in range(8):
                t=math.tau*k/8; verts.append((radius*math.cos(t),z,1.35*radius*math.sin(t)))
    faces=[]
    for k in range(8):
        j=(k+1)%8
        faces += [(k,j,8+j,8+k),(16+k,24+k,24+j,16+j),(k,16+k,16+j,j),(8+k,8+j,24+j,24+k)]
    o=mesh(name,verts,faces,mat,parent); o.location=loc; o.rotation_euler.z=turn; return o

def pylon():
    rig((128,136),124); bronze,edge,water,fold,glow=palette()
    root=empty('Pylone errant direction'); pelvis=empty('Walking bronze pelvis',(0,0,.66),root)
    taper('Heavy broken pedestal',(0,0,-.08),(0,0,.16),(.24,.21),bronze,pelvis,8)
    torso=empty('Open bright cage',(0,0,.2),pelvis)
    for z,r in ((-.05,.25),(.4,.31)):
        for j in range(6):
            a=math.tau*j/6; b=math.tau*(j+1)/6
            taper('Hexagonal cage rim',(r*math.cos(a),r*.68*math.sin(a),z),(r*math.cos(b),r*.68*math.sin(b),z),(.045,.04),edge,torso)
    for j in range(6):
        a=math.tau*j/6
        taper('Pale load bearing cage rib',(.25*math.cos(a),.17*math.sin(a),-.05),(.31*math.cos(a),.21*math.sin(a),.4),(.052,.038),edge,torso,6)
    drop=empty('Beating white water heart',(0,0,.19),torso)
    ellipsoid('Captive white drop',(0,0,0),(.09,.085,.135),glow,drop,2)
    spike('Drop apex',(0,0,.09),.055,.04,.095,glow,drop)
    # Offset fracture makes the lightning pylon recognisable above its small recessed face.
    taper('Broken sloping conductor',(.10,.04,.37),(.16,.065,.66),(.12,.065),bronze,torso,7)
    spike('Fractured pale conductor crest',(.15,.065,.62),.11,.075,.18,edge,torso)
    head=empty('Small recessed storm face',(0,-.12,.43),torso)
    ellipsoid('Bronze brow block',(0,0,0),(.12,.09,.095),bronze,head,2)
    for sign in (-1,1): ellipsoid('White eye',(sign*.057,-.08,.008),(.024,.018,.019),glow,head,2)
    arms=[]; flashes=[]
    for sign in (-1,1):
        heavy=sign==1; r=.083 if heavy else .062
        shoulder=empty('Chain shoulder %d'%sign,(sign*.31,0,.29),torso)
        ellipsoid('Broad polished shoulder',(sign*.035,0,0),(.14,.14,.13),edge,shoulder,2)
        chainlink('Upper forged link',(sign*.025,0,-.12),r,.025,bronze,shoulder)
        elbow=empty('Chain elbow',(sign*.035,0,-.25),shoulder)
        chainlink('Crosswise middle link',(0,0,0),r,.026,edge,elbow,math.pi/2)
        chainlink('Additional swinging link',(0,0,-.20),r,.024,bronze,elbow)
        wrist=empty('Chain wrist',(0,0,-.38),elbow)
        chainlink('Hanging lower link',(0,0,0),r,.026,bronze,wrist)
        taper('Asymmetric striking weight',(0,0,-.08),(sign*.025,-.015,-.22),(.11 if heavy else .07,.075 if heavy else .04),edge,wrist,7)
        spike('Broken hook tooth',(sign*.06,-.02,-.18),.05,.09,.08,bronze,wrist)
        flash=empty('Impact chain arc',(0,-.07,-.17),wrist); flashes.append(flash)
        ellipsoid('White impact edge',(0,0,0),(.085 if heavy else .05,.027,.06),glow,flash,2)
        arms.append((shoulder,elbow,wrist,sign))
    legs=[]; refs=[]
    for sign in (-1,1):
        hip=empty('Golem hip %d'%sign,(sign*.155,0,-.04),pelvis)
        knee=empty('Golem knee',(0,0,-.28),hip)
        taper('Swelling bronze thigh',(0,0,0),(0,0,-.28),(.11,.073),bronze,hip,7)
        ellipsoid('Pale knee cap',(0,-.055,-.015),(.1,.065,.09),edge,knee,2)
        taper('Tapered bronze shin',(0,0,-.02),(0,0,-.30),(.075,.048),bronze,knee,7)
        foot=empty('Planted bronze foot',(0,0,-.30),knee)
        ellipsoid('Wide pale bronze foot',(0,-.05,.015),(.11,.17,.065),edge,foot,2)
        legs.append((hip,knee,foot,sign)); refs.extend(((sign*.155,-.20,.02),(sign*.155,.20,.02)))
    root.scale=(.90,)*3; root['foot_reference']=[tuple(.90*c for c in p) for p in refs]; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n
        torso.scale.z=1+.018*math.sin(t+.2); drop.scale=(1+.05*math.sin(t),)*3
        for p in flashes: p.scale=(.02,)*3
        if a=='idle': head.rotation_euler.z=.12 if f==2 else -.02*f
        if a=='run': pelvis.location.z+=.019*math.sin(2*t)
        if a=='cast': pelvis.location.z-=(0,.02,.04,.045,.25,.15,.06,0)[f]
        for hip,knee,foot,sign in legs:
            dy=0; z=.07-pelvis.location.z+.04
            if a=='run':
                p=t+(math.pi if sign<0 else 0); dy=.16*math.sin(p); z+=.10*max(0,math.cos(p))
            solve(hip,knee,dy,z,.28,.30); foot.rotation_euler.x=-hip.rotation_euler.x-knee.rotation_euler.x
        for shoulder,elbow,wrist,sign in arms:
            shoulder.rotation_euler.y=-sign*.13
            shoulder.rotation_euler.x=.065*math.sin(t-.8+(math.pi if sign<0 else 0))
            elbow.rotation_euler.x=.12*math.sin(t-1.2)
            wrist.rotation_euler.x=.13*math.sin(t-1.6)
            if a=='run': shoulder.rotation_euler.x=.30*math.sin(t-.8+(math.pi if sign<0 else 0))
            if a=='attack':
                if sign==1:
                    shoulder.rotation_euler.x=(0,.35,.7,.85,-1.05,-.72,-.25,-.04)[f]
                    shoulder.rotation_euler.y=(-.13,-.25,-.35,-.42,-.55,-.30,-.18,-.13)[f]
                    shoulder.rotation_euler.z=(0,-.1,-.2,-.25,.32,.2,.08,0)[f]
                    elbow.rotation_euler.x=(0,.12,.26,.38,-.16,-.06,0,.02)[f]
                    wrist.rotation_euler.x=-.12 if f==4 else .08*math.sin(t-.8)
                else: shoulder.rotation_euler.x=.14*math.sin(t)
            if a=='cast':
                shoulder.rotation_euler.x=(0,.35,.7,.85,-.50,-.31,-.1,-.02)[f]
                shoulder.rotation_euler.y=-sign*(.13,.19,.25,.32,.30,.22,.16,.13)[f]
                elbow.rotation_euler.x=(0,.12,.25,.32,.05,-.08,-.03,0)[f]
                wrist.rotation_euler.x=.05 if f==4 else 0
        if a in ('attack','cast'):
            v=(0,-.025,-.05,-.075,.10,.05,.02,0)[f]
            torso.rotation_euler.x=v; head.location.y-=max(0,v)*.6
            if f==4:
                for j,p in enumerate(flashes):
                    if a=='cast' or j==1: p.scale=(1,1,1)
                drop.scale=(1.25,)*3
        if a=='death':
            u=f/(n-1); pelvis.rotation_euler.x=.12+1.02*u
            pelvis.location.z=.66-.36*u; pelvis.location.y=-.12*u
            torso.scale.z=1-.33*u; head.rotation_euler.x=.32*u
            for hip,knee,foot,sign in legs: hip.rotation_euler.x=.4+.7*u; hip.rotation_euler.y=sign*(.1+.28*u); knee.rotation_euler.x=-1.4*u
            for shoulder,elbow,wrist,sign in arms:
                shoulder.rotation_euler.y=-sign*(.18+.45*u); shoulder.rotation_euler.x=-.25*u
                elbow.rotation_euler.x=.55*u
    deliver('brute_tier3_source',(128,136),124,dict(idle=4,run=8,attack=8,cast=8,death=6),root,pose)

def contact_q2():
    # Reuse the pilot's AtlasTexture-aware assembly and actual in-game boss scale.
    import inspect
    from t2_build import contact_t2
    source=inspect.getsource(contact_t2).replace('contact_t2','contact_q2_impl').replace('terrain/terraces/','terrain/source/').replace("'leaper_tier2'","'leaper_tier2_source'").replace("'brute_tier3'","'brute_tier3_source'").replace('_mob_v2_t2_contact','_mob_v2_q2_contact')
    ns=globals().copy(); exec(source,ns); ns['contact_q2_impl']()
    # Same single contact sheet: final row compares frontal idle/impact/cast.
    path=ROOT/'art/tools/night/_mob_v2_q2_contact.png'
    top=Image.open(path).convert('RGBA'); board=Image.new('RGBA',(720,720))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/source/iso/ground_a.png').convert('RGBA')
    for y in range(480-ground.height,720,ground.height//2):
        for x in range(-ground.width,720,ground.width):
            board.alpha_composite(ground,(x+(ground.width//2 if (y//(ground.height//2))%2 else 0),y))
    board.alpha_composite(top,(0,0))
    for x,name,size,bottom,a,f in ((60,'leaper_tier2_source',(96,96),82,'idle',0),(180,'leaper_tier2_source',(96,96),82,'attack',3),(330,'brute_tier3_source',(128,136),124,'idle',0),(475,'brute_tier3_source',(128,136),124,'attack',4),(625,'brute_tier3_source',(128,136),124,'cast',4)):
        im=Image.open(ROOT/'game/assets/sprites/monsters'/name/(a+'.png')).convert('RGBA')
        row=DIRS.index('s'); cell=im.crop((f*size[0],row*size[1],(f+1)*size[0],(row+1)*size[1]))
        board.alpha_composite(cell,(x-size[0]//2,700-bottom))
    board.save(path,optimize=True)

if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'leaper'
    {'leaper':feline,'brute':pylon,'contact':contact_q2}[role]()









