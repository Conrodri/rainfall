"""MOB_V2_F1: fresh cedar/lichen creatures, articulated at 64 px/u.
Run in Blender background: -- swarm | shooter | contact. No legacy blend input.
"""
import sys, math
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters


def plate(name, width, depth, height, mat, parent):
    # Closed bevelled transverse wood plate, six crown facets and chipped rim.
    profile=[(-1,0),(-.92,.48),(-.60,.88),(0,1),(.60,.88),(.92,.48),(1,0)]
    verts=[(x*width,y,z*height) for y in (-depth/2,depth/2) for x,z in profile]
    faces=[tuple(range(6,-1,-1)),tuple(range(7,14))]
    faces += [(j,j+1,j+8,j+7) for j in range(6)] + [(0,7,13,6)]
    return mesh(name,verts,faces,mat,parent)


def fine_leg(name,a,b,radii,mat,parent):
    a,b=Vector(a),Vector(b); q=(b-a).to_track_quat('Z','Y')
    v=[p+q@Vector((r*math.cos(j*math.pi/2),r*math.sin(j*math.pi/2),0))
       for p,r in ((a,radii[0]),(b,radii[1])) for j in range(4)]
    return mesh(name,v,[(3,2,1,0),(4,5,6,7)]+[(j,(j+1)%4,(j+1)%4+4,j+4) for j in range(4)],mat,parent)


def swarm():
    rig((64,56),48)
    pale=material('Grey green sunbleached lichen','D0D5BE')
    rim=material('Bleached upper plate ridge','E2E5D2')
    wood=material('Dead cedar exposed edges','92927B')
    moss=material('Deep damp moss','4E6B54')
    joint=material('Root joints','44473A')
    glow=material('Pale green 9CF0C8','9CF0C8',1.25)
    root=empty('Cloporte des racines - direction')
    body=empty('Segmented breathing trunk',(0,0,.145),root)
    plates=[]
    for i in range(7):
        y=-.225+i*.073; w=.16*(.78+.22*math.sin((i+1)*math.pi/8))
        p=empty('Dorsal plate pivot %d'%i,(0,y,0),body); plates.append(p)
        plate('Bevelled deadwood plate %d'%i,w,.084,.145,wood,p)
        top=empty('Pale lichen crown %d'%i,(0,-.003,.025),p)
        crown=plate('Broad pale dorsal lichen %d'%i,w*.94,.067,.135,pale,top)
        crown.data.materials.append(rim)
        for face in crown.data.polygons:
            if face.index in (4,5): face.material_index=1
        for sign in (-1,1):
            taper('Trailing moss fringe',(sign*w*.8,.021,.065),(sign*w*1.05,.06,.025),(.022,.004),moss,p,4)
    head=empty('Head and front closing plates',(0,-.27,.035),body)
    ellipsoid('Cedar head',(0,0,0),(.12,.077,.067),wood,head,2)
    jaws=[]; antennae=[]
    for sign in (-1,1):
        ellipsoid('Green eye',(sign*.077,-.064,.035),(.031,.020,.024),glow,head)
        jaw=empty('Front plate hinge',(sign*.078,-.042,-.008),head); jaws.append(jaw)
        plate('Snapping front lichen plate',.052,.09,.059,pale,jaw)
        ant=empty('Antenna root',(sign*.062,-.048,.045),head); antennae.append(ant)
        taper('Antenna first joint',(0,0,0),(sign*.038,-.07,.04),(.014,.009),wood,ant,4)
        taper('Antenna tapered tip',(sign*.038,-.07,.04),(sign*.060,-.12,.035),(.009,.002),pale,ant,4)
    mouth=empty('Impact lit mouth',(0,-.083,-.01),head)
    ellipsoid('Mouth accent',(0,0,0),(.042,.026,.025),glow,mouth)
    legs=[]; feet=[]
    for i in range(7):
        y=-.218+i*.071
        for sign in (-1,1):
            hip=empty('Root hip %d %d'%(i,sign),(sign*.125,y,.018),body)
            knee=empty('Root knee %d %d'%(i,sign),(sign*.093,.018,-.035),hip)
            ankle=empty('Root ankle %d %d'%(i,sign),(sign*.055,-.015,-.092),knee)
            fine_leg('Tapered root thigh',(0,0,0),tuple(knee.location),(.022,.014),wood,hip)
            fine_leg('Tapered root tibia',(0,0,0),tuple(ankle.location),(.014,.007),joint,knee)
            fine_leg('Fine hooked foot',(0,0,0),(sign*.023,-.031,-.019),(.008,.002),pale,ankle)
            legs.append((hip,knee,ankle,i,sign)); feet.append((sign*.296,y-.028,.017))
    root.scale.x=.92; root.scale.y=.92
    root['foot_reference']=[(x*.92,y*.92,z) for x,y,z in feet]
    reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; mouth.scale=(.02,)*3
        body.scale.z=1+.028*math.sin(t+.2)
        head.rotation_euler.z=.045*math.sin(t+.4)
        for i,p in enumerate(plates): p.rotation_euler.x=.025*math.sin(t-i*.35)
        for j,ant in enumerate(antennae): ant.rotation_euler.z=.13*math.sin(t-.9+j)
        if a=='idle':
            jaws[0].rotation_euler.z=.12*math.sin(t+.3)
        if a=='run':
            body.location.z+=.004*math.sin(2*t)
            for hip,knee,ankle,i,sign in legs:
                p=t-i*math.tau/7+(math.pi if sign<0 else 0)
                # Stance sweeps backward at ground level; return lifts the knee.
                hip.rotation_euler.z=.52*math.sin(p)
                lift=max(0,math.cos(p))
                hip.rotation_euler.y=-sign*.28*lift
                knee.rotation_euler.y=sign*.37*lift
                ankle.rotation_euler.x=.24*lift
            for i,p in enumerate(plates): p.rotation_euler.z=.045*math.sin(t-i*.5-math.pi/4)
        if a=='attack':
            pull=(0,.025,.043,-.012,-.006,0)[f]
            body.location.y+=pull; body.rotation_euler.x=(0,-.12,-.22,.22,.10,.02)[f]
            head.location.y+=(0,.008,.018,-.025,-.006,0)[f]
            if f==3:
                head.location.z+=.035
                head.scale=(1,1,1.12)
                body.scale.y=.90
            for ant in antennae: ant.rotation_euler.x=.55 if f==3 else 0
            for j,sign in zip(jaws,(-1,1)):
                j.rotation_euler.z=sign*(.12,.45,.68,-.36,-.12,0)[f]
                j.location.y-=.035 if f==3 else 0
            if f==3: mouth.scale=(1.35,1.3,1.2)
        if a=='death':
            body.rotation_euler.x=(.06,.25,.22,.18)[f]
            body.location.y-=(.0,.006,.010,.012)[f]
            body.location.z-=(0,.008,.016,.024)[f]
            body.scale.z=1-f*.16
            for hip,knee,ankle,i,sign in legs:
                hip.rotation_euler.y=-sign*(.08+f*.10); knee.rotation_euler.x=f*.13
            for i,p in enumerate(plates): p.rotation_euler.x=f*.035*math.sin(i)
    # Common pipeline's default suffixed-swarm cap is 3000; enforce 1500 here.
    tris=sum(len(p.vertices)-2 for o in root.children_recursive if o.type=='MESH' for p in o.data.polygons)
    assert tris<=1500,tris
    produce('swarm_tier1_moss',(64,56),48,dict(idle=4,run=8,attack=6,death=4),root,pose)


def shooter():
    rig((88,104),96)
    pale=material('Pale sage lichen mantle','BFC6A5')
    bark=material('Split cedar warm heartwood','806C54')
    lightwood=material('Bleached cedar ribs','B9B59A')
    dark=material('Hollow cedar shadows','393F36')
    moss=material('Hanging moss','5E7760')
    paper=material('Unlit grey paper lantern','9C9E7C')
    green=material('Pale green 9CF0C8','9CF0C8',1.15)
    root=empty('Archer ecorce - direction'); pelvis=empty('Root pelvis',(0,0,.47),root)
    torso=empty('Split hollow rib cage',(0,0,.19),pelvis)
    # Open, uneven cedar staves surrounding a visible hollow thorax.
    for j in range(7):
        t=math.tau*j/7; x=.105*math.cos(t); y=.082*math.sin(t)
        if y<-.05: continue
        taper('Split cedar stave',(x*1.13,y*1.13,-.16),(x*.86,y*.86,.28),(.043,.028),lightwood if j%2 else bark,torso,5)
    for sign in (-1,1):
        for z in (-.1,.02,.14):
            taper('Broken cage rib',(sign*.115,.01,z),(sign*.038,-.085,z-.04),(.023,.012),lightwood,torso,4)
    lantern=empty('Suspended lantern',(0,-.01,.025),torso)
    taper('Lantern cord',(0,0,.19),(0,0,.075),(.008,.004),dark,lantern,4)
    ellipsoid('Unlit paper lantern',(0,0,0),(.065,.057,.083),paper,lantern,2)
    for sign in (-1,1): taper('Lantern cedar cage',(sign*.045,-.045,-.065),(sign*.045,-.045,.06),(.009,.006),bark,lantern,4)
    ellipsoid('Weak green lantern ember',(0,-.058,-.015),(.022,.01,.022),green,lantern)
    head=empty('Lichen hood head',(0,0,.345),torso)
    ellipsoid('Deep hood opening',(0,-.025,.015),(.083,.075,.103),dark,head,2)
    ellipsoid('Single pale green eye',(0,-.101,.019),(.024,.014,.018),green,head)
    cloth=[]
    for j in range(9):
        t=math.tau*j/9; dt=.39
        panel=empty('Lichen hood flap %d'%j,(0,0,.14),head); cloth.append(panel)
        verts=[]
        for r,z in ((.038,0),(.14,-.12),(.175,-.29-(j%3)*.019)):
            for u in (t-dt,t+dt): verts.append((r*math.cos(u),r*math.sin(u),z))
        # Front split exposes face; broad pale side/back hood stays >30%.
        if math.sin(t)<-.5:
            verts[2]=(verts[2][0],verts[2][1],-.06)
            verts[3]=(verts[3][0],verts[3][1],-.06)
            verts[4]=(verts[4][0],verts[4][1],-.10)
            verts[5]=(verts[5][0],verts[5][1],-.10)
        mesh('Torn pale lichen hood',verts,[(0,1,3,2),(2,3,5,4)],pale,panel)
        taper('Moss tassel',verts[4],(verts[4][0]*1.04,verts[4][1],verts[4][2]-.065),(.016,.003),moss,panel,4)
    legs=[]; feet=[]
    for sign in (-1,1):
        hip=empty('Cedar hip %d'%sign,(sign*.085,0,0),pelvis)
        knee=empty('Cedar knee %d'%sign,(0,.012,-.225),hip)
        taper('Cedar thigh',(0,0,0),tuple(knee.location),(.043,.026),bark,hip)
        taper('Tapered split shin',(0,0,0),(0,-.012,-.215),(.027,.014),lightwood,knee)
        taper('Root toe',(0,-.012,-.215),(sign*.025,-.096,-.227),(.026,.005),bark,knee)
        legs.append((hip,knee,sign)); feet.extend(((sign*.11,-.096,.018),(sign*.085,0,.018)))
    bow=empty('Living branch bow grip',(.18,-.25,.11),torso)
    limbs=[]
    for sign in (-1,1):
        limb=empty('Bow flex hinge %d'%sign,(0,0,0),bow); limbs.append((limb,sign))
        points=[(0,0,0),(.012,-.063,sign*.18),(0,-.087,sign*.36),(-.018,-.025,sign*.51)]
        for j in range(3): taper('Living bow tapered branch',points[j],points[j+1],(.023-j*.005,.016-j*.005),lightwood,limb,5)
        taper('Bow fork spur',points[2],(.055,-.07,sign*.405),(.014,.002),moss,limb,4)
    string=empty('Drawn bow string',parent=bow)
    # Rebuilt vertex positions per pose, keyed string via pivot scaling and nock.
    for sign in (-1,1): taper('Fine bowstring',(0,-.025,sign*.50),(0,.17,0),(.004,.003),pale,string,4)
    nock=empty('Arrow draw hand',(.18,-.08,.11),torso)
    taper('Nocked cedar thorn',(0,.03,0),(0,-.33,0),(.011,.005),lightwood,nock,5)
    release=empty('Impact luminous thorn',(.18,-.33,.11),torso)
    taper('Green released thorn',(0,0,0),(0,-.24,0),(.016,.001),green,release,5)
    arms=[]
    for sign in (-1,1):
        shoulder=empty('Shoulder %d'%sign,(sign*.12,0,.17),torso)
        elbow=empty('Elbow %d'%sign,(sign*.065,-.075,-.10),shoulder)
        taper('Knotted upper arm',(0,0,0),tuple(elbow.location),(.033,.02),bark,shoulder)
        taper('Jointed forearm',(0,0,0),(.18-sign*.185,-.16,.04),(.024,.012),lightwood,elbow)
        arms.append((shoulder,elbow,sign))
    root['foot_reference']=feet; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; release.scale=(.015,)*3
        torso.scale.z=1+.022*math.sin(t+.1)
        head.rotation_euler.z=.045*math.sin(t+.4)
        lantern.rotation_euler.x=.08*math.sin(t-math.pi/4)
        for j,p in enumerate(cloth): p.rotation_euler.x=.035*math.sin(t-.9+j*.4)
        if a=='idle': head.rotation_euler.y=.06*math.sin(t+.3)
        if a=='run':
            pelvis.location.z+=.011*math.sin(2*t)
            for hip,knee,sign in legs:
                p=t+(math.pi if sign<0 else 0)
                # Two-bone IK: stance planted z, swing raised; 30+ degree hips.
                y=.12*math.sin(p); z=.05+.075*max(0,math.cos(p))-pelvis.location.z
                bend=-math.acos(max(-1,min(1,(y*y+z*z-.225**2-.215**2)/(2*.225*.215))))
                hip.rotation_euler.x=math.atan2(y,-z)-math.atan2(.215*math.sin(bend),.225+.215*math.cos(bend))
                knee.rotation_euler.x=bend
            torso.rotation_euler.z=.055*math.sin(t)
            bow.rotation_euler.x=.12*math.sin(t-.5)
            lantern.rotation_euler.x=.22*math.sin(t-math.pi/4)
            for j,p in enumerate(cloth): p.rotation_euler.x=.11*math.sin(t-math.pi/4+j*.4)
        if a=='attack':
            draw=(.0,.045,.085,.12,0,.035,.018,0)[f]
            torso.location.y+=(0,.012,.027,.035,-.03,-.012,0,0)[f]
            nock.location.y+=draw; string.scale.y=1+draw/.17
            bow.location.y-=(0,0,0,.015,.075,.04,.015,0)[f]
            for limb,sign in limbs: limb.rotation_euler.x=sign*(draw*.35+(.055 if f==5 else 0))
            for arm,elbow,sign in arms:
                arm.rotation_euler.x=(-draw*3 if sign<0 else -.18-draw)
                elbow.rotation_euler.z=draw*2 if sign<0 else -.08
            if f==4: release.scale=(1,1,1)
            if f==4 and abs(root.rotation_euler.z)<=math.pi/4+.001:
                torso.rotation_euler.x=.18
                bow.location.y-=.035
                bow.location.x+=.035
                bow.rotation_euler.y=-.22
                nock.location.y-=.06
                release.location.y-=.035
                release.scale=(1.2,1.1,1.2)
                for arm,elbow,sign in arms:
                    arm.rotation_euler.x=-.65 if sign>0 else -.35
                    elbow.rotation_euler.z=-.28 if sign>0 else .16
        if a=='death':
            pelvis.rotation_euler.x=(.08,.38,.65,.82)[f]
            pelvis.location.z-=(0,.035,.06,.08)[f]
            pelvis.location.y-=(0,.02,.035,.05)[f]
            torso.scale.z=1-f*.12; head.rotation_euler.x=f*.12
            bow.rotation_euler.x=-f*.14
            bow.rotation_euler.y=f*.24
            bow.location.y+=f*.04; bow.location.z+=f*.025
            for hip,knee,sign in legs:
                hip.rotation_euler.x=-pelvis.rotation_euler.x+f*.24; knee.rotation_euler.x=-f*.48
    produce('shooter_tier2_moss',(88,104),96,dict(idle=4,run=8,attack=8,death=4),root,pose)


def f1_contact():
    # Reuse pilot assembly at exactly its game scale, substituting F1 assets/ground.
    import common_v2
    import inspect
    source=inspect.getsource(common_v2.contact)
    source=source.replace("def contact():","def assemble():")
    source=source.replace('terrain/terraces/','terrain/fog_forest/')
    source=source.replace("'swarm_tier1'","'swarm_tier1_moss'").replace("'shooter_tier2'","'shooter_tier2_moss'")
    source=source.replace('_mob_v2_t1_contact.png','_mob_v2_f1_contact.png')
    namespace=dict(vars(common_v2)); exec(source,namespace); namespace['assemble']()


if __name__=='__main__':
    if '--audit' in sys.argv:
        def produce(name,size,bottom,counts,root,pose):
            for d in ('e','s','w','n'):
                root.rotation_euler.z=math.radians(90-45*DIRS.index(d))
                rot=root.rotation_euler.to_matrix()
                low=min((rot@Vector(p)).y*.5+p[2]*math.cos(math.pi/6) for p in root['foot_reference'])
                pose('death',3,4); bpy.context.view_layer.update()
                extremes=[]
                for o in root.children_recursive:
                    if o.type!='MESH': continue
                    value=min((o.matrix_world@v.co).y*.5+(o.matrix_world@v.co).z*math.cos(math.pi/6) for v in o.data.vertices)
                    extremes.append((round(bottom+(low-value)*64,1),o.name))
                print('AUDIT',d,sorted(extremes,reverse=True)[:3])
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'swarm'
    {'swarm':swarm,'shooter':shooter,'contact':f1_contact}[role]()
