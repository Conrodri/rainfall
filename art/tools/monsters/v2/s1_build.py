"""MOB_V2_S1: new ossuary hand and salt mourner, articulated CREA assets."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters

def deliver(name,size,bottom,counts,root,pose):
    if '--bounds' not in sys.argv:
        return produce(name,size,bottom,counts,root,pose)
    from mathutils import Vector
    for a,n in counts.items():
        for d in (('e','s','w','n') if a=='death' else DIRS):
            root.rotation_euler.z=math.radians(90-45*DIRS.index(d))
            rot=root.rotation_euler.to_matrix()
            lowest=min((rot@Vector(p)).y*.5+p[2]*math.cos(math.pi/6) for p in root['foot_reference'])
            for f in range(n):
                pose(a,f,n); bpy.context.view_layer.update(); worst=(-1,''); xmin=size[0]; xmax=0
                for o in root.children_recursive:
                    if o.type!='MESH': continue
                    for v in o.data.vertices:
                        p=o.matrix_world@v.co; y=bottom+lowest*64-(p.y*.5+p.z*math.cos(math.pi/6))*64
                        xmin=min(xmin,size[0]/2+p.x*64); xmax=max(xmax,size[0]/2+p.x*64)
                        if y>worst[0]: worst=(y,o.name)
                if worst[0]>size[1]-4: print('BOUNDS',a,d,f,round(worst[0],1),worst[1],flush=True)
                if xmin<4 or xmax>size[0]-4: print('BOUNDS_X',a,d,f,round(xmin,1),round(xmax,1),flush=True)

def crystal(name,loc,r,h,mat,parent):
    verts=[(0,0,h)]+[(r*math.cos(j*math.tau/5),r*math.sin(j*math.tau/5),h*.25) for j in range(5)]+[(0,0,-h*.22)]
    o=mesh(name,verts,[(0,1+j,1+(j+1)%5) for j in range(5)]+[(6,1+(j+1)%5,1+j) for j in range(5)],mat,parent)
    o.location=loc; return o

def swarm():
    rig((64,56),48)
    bone=material('Ivory ossuary bone','D8D5BD'); salt=material('White salt crust','EEE8D8')
    shade=material('Mineral blue fissures','697E88'); glow=material('Crystal BFF4FF','BFF4FF',1.4)
    root=empty('Main ossuaire direction'); palm=empty('Carpal arch breathing',(0,.035,.26),root)
    # Broad knuckled palm with distinct metacarpals, never a radial insect body.
    ellipsoid('Flattened carpal bridge',(0,.005,0),(.17,.145,.065),bone,palm,2)
    wrist=empty('Broken wrist secondary',(0,.16,.015),palm)
    taper('Broken radius',(-.065,0,0),(-.065,.105,.015),(.043,.028),bone,wrist)
    taper('Broken ulna',(.055,0,-.008),(.055,.085,.015),(.036,.022),bone,wrist)
    wristgem=empty('Wrist crystal pulse',(0,.035,.055),wrist)
    crystal('Wrist crystal',(0,0,0),.055,.09,glow,wristgem)
    fingers=[]; refs=[]
    for i,(x,y,fan,length) in enumerate(((-.14,-.055,-.7,.16),(-.10,-.10,-.19,.205),(0,-.13,0,.23),(.095,-.11,.13,.21),(.155,-.055,.42,.17))):
        taper('Metacarpal %d'%i,(x*.53,.065,.014),(x,y,.015),(.036,.027),bone,palm)
        hip=empty('Knuckle %d'%i,(x,y,0),palm); hip.rotation_euler.z=fan
        knee=empty('Middle joint %d'%i,(0,-length*.58,-.04),hip)
        tip=empty('Distal joint %d'%i,(0,-length*.44,-.065),knee)
        ellipsoid('Salt knuckle %d'%i,(0,0,.006),(.042,.045,.037),salt,hip)
        taper('Proximal phalanx %d'%i,(0,0,0),tuple(knee.location),(.034,.024),bone,hip)
        taper('Middle phalanx %d'%i,(0,0,0),tuple(tip.location),(.027,.018),salt,knee)
        taper('Curved fingertip %d'%i,(0,0,0),(0,-.04,-.144),(.022,.005),bone,tip)
        crystal('Salt spur %d'%i,(.012,-.03,.018),.027,.055,salt,knee)
        fingers.append((hip,knee,tip,i,fan))
        refs.append((x+math.sin(fan)*(length+.04),y-math.cos(fan)*(length+.04)+.035,.011))
    # A forward socket supplies a directional eye even when the wrist faces away.
    ellipsoid('Crystal in finger socket',(0,-.13,.052),(.032,.027,.022),glow,palm)
    flash=empty('Claw impact',(0,-.205,-.035),palm)
    crystal('Claw impact splinter',(0,0,0),.048,.10,glow,flash)
    root['foot_reference']=refs; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; flash.scale=(.01,)*3
        palm.scale.z=1+.035*math.sin(t+.3); wrist.rotation_euler.x=.10*math.sin(t-.8)
        if a=='idle':
            fingers[0][1].rotation_euler.x=.12*math.sin(t+.6)
            palm.rotation_euler.y=.025*math.sin(t)
        if a=='run':
            palm.location.z+=.006*math.sin(2*t)
            for hip,knee,tip,i,fan in fingers:
                p=t+i*math.tau/5; swing=max(0,-math.cos(p))
                hip.rotation_euler.x=.50*math.cos(p)
                # Two-link IK: fixed sole height through contact; lifted return stroke.
                q=hip.rotation_euler.x; upper=knee.location.z*math.cos(q)+knee.location.y*math.sin(q)
                desired=(.011+.035*swing-palm.location.z)/palm.scale.z+.144-upper
                length=-tip.location.y; radius=math.hypot(.065,length)
                theta=math.atan2(length,.065)-math.acos(max(-1,min(1,-desired/radius)))
                knee.rotation_euler.x=theta-q; tip.rotation_euler.x=-theta
            wrist.rotation_euler.y=.17*math.sin(t-math.pi/4)
        if a=='attack':
            reach=(0,-.035,-.065,.05,.025,.008)[f]
            palm.location.y-=reach
            palm.rotation_euler.x=(0,-.12,-.23,.20,.09,.015)[f]
            wrist.location.z+=(0,.025,.055,0,0,0)[f]
            if f==3: wrist.location.y+=.07
            wristgem.scale.z=(1,.75,.45,1,1,1)[f]
            for hip,knee,tip,i,fan in fingers:
                hip.rotation_euler.x=(-.60,-.80,-1.05,-.12,-.35,-.50)[f]
                hip.rotation_euler.z=fan*(.72,.65,.60,1.12,.9,.8)[f]
                hip.scale.y=(1,1,1,1.12,1.05,1)[f]
                knee.rotation_euler.x=(-.25,-.30,-.40,.02,.10,.0)[f]
                tip.rotation_euler.x=(0,-.1,-.18,.65,.25,.06)[f]
                if f!=3: tip.rotation_euler.x=-hip.rotation_euler.x-knee.rotation_euler.x-palm.rotation_euler.x
            if f==3: flash.scale=(1,1,1)
        if a=='death':
            palm.location.y-=f*.003; palm.location.z-=f*.013
            palm.rotation_euler.x=(.12,.42,.57,.60)[f]; palm.scale.z=1-f*.13
            for hip,knee,tip,i,fan in fingers:
                hip.rotation_euler.z=fan*(1+f*.12)
                hip.rotation_euler.x=-palm.rotation_euler.x-.12*f
                knee.rotation_euler.x=.1*f; tip.rotation_euler.x=.02*f
    deliver('swarm_tier1_salt',(64,56),48,dict(idle=4,run=8,attack=6,death=4),root,pose)

def shooter():
    rig((88,104),96)
    salt=material('Pale salt linen','DCDACA'); edge=material('Cold mineral folds','8DADB5')
    dark=material('Empty hood cavity','424F5B'); bone=material('Exposed ivory fingers','CBCBB9')
    metal=material('Oxidized censer chain','7D929A'); glow=material('Crystal BFF4FF','BFF4FF',1.4)
    root=empty('Pleureuse sel direction'); pelvis=empty('Walking pelvis',(0,0,.43),root)
    torso=empty('Breathing salt shroud',(0,0,.20),pelvis)
    # Individually articulated solid, folded linen gores; irregular broken hem.
    cloth=[]
    for j in range(12):
        a=j*math.tau/12; panel=empty('Linen gore %02d'%j,(0,0,.25),torso); cloth.append(panel)
        verts=[]
        for thickness in (0,.012):
            for radius,z in ((.12,0),(.19,-.21),(.23,-.64-(j%3)*.018)):
                for da,extra in ((-.27,0),(0,.022),(.27,0)):
                    r=radius+extra-thickness
                    verts.append((r*math.cos(a+da),r*math.sin(a+da),z))
        faces=[]
        for k in (0,9):
            faces.extend((k+r*3+c,k+r*3+c+1,k+(r+1)*3+c+1,k+(r+1)*3+c) for r in range(2) for c in range(2))
        faces.extend((c,c+1,10+c,9+c) for c in (0,1,6,7))
        faces.extend((r*3,(r+1)*3,(r+1)*3+9,r*3+9) for r in range(2))
        faces.extend((r*3+2,r*3+11,(r+1)*3+11,(r+1)*3+2) for r in range(2))
        o=mesh('Thick folded salt linen %02d'%j,verts,faces,salt,panel)
        o.data.materials.append(edge)
        for poly in o.data.polygons:
            if poly.index in (1,3): poly.material_index=1
    head=empty('Hood and eye',(0,-.015,.29),torso)
    ellipsoid('Deep empty face',(0,-.035,.025),(.102,.075,.125),dark,head,2)
    # Open front hood: broad rim, five angular depth bands, closed pointed back.
    v=[]; seg=10
    for y,rx,rz,zc in ((-.105,.135,.165,.04),(.035,.14,.17,.05),(.12,.08,.12,.08)):
        for j in range(seg):
            a=math.tau*j/seg; v.append((rx*math.sin(a),y,zc+rz*math.cos(a)))
    v.append((0,.14,.13))
    faces=[(r*seg+j,r*seg+(j+1)%seg,(r+1)*seg+(j+1)%seg,(r+1)*seg+j) for r in range(2) for j in range(seg)]
    faces += [(30,20+j,20+(j+1)%seg) for j in range(seg)]
    mesh('Open peaked salt hood',v,faces,salt,head)
    ellipsoid('Single crystal eye',(.012,-.115,.04),(.033,.022,.029),glow,head)
    crystal('Asymmetric hood crystal shard',(-.12,.015,.10),.034,.14,glow,head)
    legs=[]; feet=[]
    for sign in (-1,1):
        hip=empty('Hip %d'%sign,(sign*.075,0,0),pelvis)
        knee=empty('Knee %d'%sign,(0,0,-.20),hip)
        taper('Tapered thigh',(0,0,0),tuple(knee.location),(.040,.027),edge,hip)
        taper('Tapered shin',(0,0,0),(0,0,-.20),(.028,.016),bone,knee)
        taper('Bare planted toe',(0,0,-.20),(0,-.085,-.215),(.028,.012),bone,knee)
        legs.append((hip,knee,sign)); feet.extend(((sign*.075,-.085,.015),(sign*.075,.035,.015)))
    shoulder=empty('Censer shoulder',(.16,-.015,.19),torso)
    elbow=empty('Censer elbow',(.045,-.08,-.14),shoulder)
    taper('Shroud sleeve',(0,0,0),tuple(elbow.location),(.085,.046),salt,shoulder)
    taper('Ivory wrist',(0,0,0),(-.025,-.11,-.01),(.033,.019),bone,elbow)
    grip=empty('Chain grip',(-.025,-.11,-.01),elbow)
    ellipsoid('Clasped hand',(0,0,0),(.035,.032,.042),bone,grip)
    pendulum=empty('Articulated censer chain',(0,0,0),grip)
    pendulum.scale=(.82,)*3  # fixed cell ceiling, preserve the articulated arm's reach
    # Open oval chain links with useful silhouette instead of a constant-radius rod.
    for j in range(6):
        verts=[]
        for r in (.025,.014):
            for k in range(8):
                a=k*math.tau/8; verts.append((r*math.cos(a),0,-j*.043+r*1.35*math.sin(a)))
        o=mesh('Open chain link %d'%j,verts,[(k,(k+1)%8,(k+1)%8+8,k+8) for k in range(8)],metal,pendulum)
        if j%2: o.rotation_euler.z=math.pi/2
    censer=empty('Crystal censer',(0,0,-.285),pendulum)
    ellipsoid('Censer iron crown',(0,0,.02),(.074,.065,.035),metal,censer)
    crystal('Censer crystal',(0,0,-.065),.066,.12,glow,censer)
    for sign in (-1,1): taper('Censer cage',(sign*.065,0,.025),(sign*.025,0,-.12),(.015,.008),metal,censer)
    burst=empty('Impact crystal flare',(0,0,-.045),censer)
    for j in range(3):
        o=crystal('Impact ray %d'%j,((j-1)*.057,0,-.015),.027,.15,glow,burst); o.rotation_euler.y=(j-1)*.55
    root['foot_reference']=feet; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; burst.scale=(.01,)*3
        torso.scale.x=1+.025*math.sin(t); torso.scale.z=1+.012*math.sin(t+.3)
        head.rotation_euler.z=.045*math.sin(t+.5)
        pendulum.rotation_euler.x=.12*math.sin(t-math.pi/4)
        for j,p in enumerate(cloth): p.rotation_euler.x=.025*math.sin(t+j*.35-.8)
        if a=='idle': head.rotation_euler.x=.045*math.sin(t+.2)
        if a=='run':
            pelvis.location.z+=.012*math.cos(2*t)+.008
            for hip,knee,sign in legs:
                p=t+(math.pi if sign<0 else 0)
                hip.rotation_euler.x=.50*math.sin(p); knee.rotation_euler.x=-.55*max(0,math.cos(p))
            torso.rotation_euler.z=.07*math.sin(t); shoulder.rotation_euler.x=.18*math.sin(t)
            pendulum.rotation_euler.x=.32*math.sin(t-math.pi/4)
            for j,p in enumerate(cloth): p.rotation_euler.x=.11*math.sin(t+j*.45-math.pi/4)
        if a=='attack':
            torso.location.y+=(0,.018,.03,.008,-.025,-.025,-.01,0)[f]
            shoulder.rotation_euler.x=(0,-.35,-.60,-.20,-.85,-.65,-.24,-.04)[f]
            elbow.rotation_euler.x=(0,.32,.50,.25,0,-.15,.10,.03)[f]
            pendulum.rotation_euler.x=(.1,2.2,3.2,.5,-.55,-.45,-.15,.06)[f]
            pendulum.rotation_euler.y=(0,.20,-.20,.15,0,-.12,-.06,0)[f]
            head.rotation_euler.x=(0,-.05,-.08,-.03,.12,.06,.02,0)[f]
            if f==4: burst.scale=(1.35,1,1)
        if a=='death':
            pelvis.location.z-=(0,.07,.18,.20)[f]; pelvis.location.y-=(0,.025,.07,.10)[f]
            torso.rotation_euler.x=(.14,.48,.85,1.14)[f]; torso.scale.z=1-f*.12
            head.rotation_euler.x=f*.13; shoulder.rotation_euler.x=-f*.22
            pendulum.rotation_euler.x=.4+f*.4
            for hip,knee,sign in legs:
                hip.rotation_euler.x=(.15,.55,.95,1.2)[f]
                knee.rotation_euler.x=-2*hip.rotation_euler.x
            for j,p in enumerate(cloth): p.rotation_euler.x=-.12*f*math.cos(j*math.tau/12)
    deliver('shooter_tier2_salt',(88,104),96,dict(idle=4,run=8,attack=8,death=4),root,pose)

def contact_s1():
    # Pilot assembly, with current Ash Lord run AtlasTexture cells (114 x 116).
    ground=Image.open(ROOT/'game/assets/sprites/terrain/crypts/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(720,480))
    for y in range(-ground.height,board.height,ground.height//2):
        for x in range(-ground.width,board.width,ground.width):
            board.alpha_composite(ground,(x+(ground.width//2 if (y//(ground.height//2))%2 else 0),y))
    ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/run.png').convert('RGBA')
    factor=2.4*1.1*64/100
    for panel,(a,d) in enumerate((('run','s'),('run','e'),('attack','s'),('attack','e'))):
        ox=(panel%2)*360; baseline=(panel//2)*240+218
        for x,name,size,bottom,n in ((62,'swarm_tier1_salt',(64,56),48,6),(157,'shooter_tier2_salt',(88,104),96,8)):
            f=0 if a=='run' else n//2; row=DIRS.index(d)
            source=Image.open(ROOT/'game/assets/sprites/monsters'/name/(a+'.png')).convert('RGBA')
            tile=source.crop((f*size[0],row*size[1],(f+1)*size[0],(row+1)*size[1]))
            board.alpha_composite(tile,(ox+x-size[0]//2,baseline-bottom))
        row=0 if d=='e' else 1
        ref=ash.crop((0,row*116,114,(row+1)*116)).resize((round(114*factor),round(116*factor)),Image.Resampling.LANCZOS)
        board.alpha_composite(ref,(ox+280-ref.width//2,baseline-round(117*factor)))
    board.save(ROOT/'art/tools/night/_mob_v2_s1_contact.png',optimize=True)

if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'swarm'
    {'swarm':swarm,'shooter':shooter,'contact':contact_s1}[role]()
