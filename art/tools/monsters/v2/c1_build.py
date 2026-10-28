"""MOB_V2_C1: new nut maggot and gas-lamp riveter; CREA 64 px/u."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters

def setup(size,bottom):
    s=rig(size,bottom)
    s.eevee.taa_render_samples=8
    return s

def nut_quarter(name,j,mat,parent):
    # Four separate bevelled annular jaws, axis along forward -Y.
    verts=[]
    for y,r in ((.035,.115),(-.025,.135),(-.075,.118)):
        for rad in (r,.058):
            for k in range(3):
                a=j*math.pi/2+(k/2)*math.pi/2+.025
                verts.append((rad*math.cos(a),y,rad*math.sin(a)))
    faces=[]
    for layer in range(2):
        for ring in range(2):
            for k in range(2):
                a=layer*6+ring*3+k; faces.append((a,a+1,a+7,a+6))
    for layer in (0,2):
        for k in range(2):
            a=layer*6+k; faces.append((a,a+1,a+4,a+3))
    for k in (0,2):
        for layer in range(2):
            a=layer*6+k; faces.append((a,a+3,a+9,a+6))
    return mesh(name,verts,faces,mat,parent)

def swarm():
    setup((64,56),48)
    cream=material('Pale tallow belly and dorsal folds','D3C7A0')
    seam=material('Tallow crease','A99B77')
    rust=material('Rusted jaw iron','875032')
    iron=material('Black iron sockets','41413B')
    brass=material('Broad worn rivet caps','B9A57A')
    orange=material('Lamp filament FF9A3C','FF9A3C',1.3)
    root=empty('Larve boulon direction'); body=empty('Undulating tallow core',(0,0,.18),root)
    segments=[]
    for j in range(5):
        y=.235-j*.108; r=(.073,.112,.13,.125,.105)[j]
        p=empty('Segment hinge %d'%j,(0,y,0),body); segments.append(p)
        ellipsoid('Tallow lobe %d'%j,(0,0,0),(r,.085,r*.86),cream,p,2)
        # Single broad dorsal rivet per segment; useful silhouette, no microgeometry.
        taper('Rivet shoulder',(0,.005,r*.68),(0,.005,r*.98),(.039,.026),rust,p,5)
        ellipsoid('Rivet cap',(0,.005,r*1.01),(.043,.04,.022),brass,p)
    head=empty('Nut head swivel',(0,-.285,.065),body)
    taper('Dark inner throat',(0,.02,0),(0,-.078,0),(.082,.068),iron,head,6)
    jaws=[]
    for j in range(4):
        p=empty('Jaw hinge %d'%j,parent=head); nut_quarter('Bevelled nut quadrant',j,rust,p); jaws.append(p)
    for sign in (-1,1):
        ellipsoid('Orange eye filament',(sign*.068,-.078,.047),(.027,.014,.018),orange,head)
    mouth=empty('Impact glowing throat',(0,-.088,0),head)
    ellipsoid('Hot open mouth',(0,0,0),(.06,.015,.049),orange,mouth,2)
    legs=[]; feet=[]
    for j in range(3):
        for sign in (-1,1):
            hip=empty('Belly lappet hip %d %d'%(j,sign),(sign*.082,.15-j*.14,-.045),body)
            knee=empty('Lappet joint',(sign*.055,0,-.055),hip)
            taper('Fat lappet',(0,0,0),tuple(knee.location),(.039,.026),cream,hip,5)
            taper('Small hooked foot',(0,0,0),(sign*.025,-.035,-.055),(.026,.008),seam,knee,5)
            legs.append((hip,knee,j,sign)); feet.append((sign*.162,.115-j*.14,.025))
    root['foot_reference']=feet; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; mouth.scale=(.02,)*3
        body.scale.z=1+.028*math.sin(t+.2)
        head.rotation_euler.z=.045*math.sin(t+.35)
        if a=='idle': head.rotation_euler.x=.055*math.sin(t+.6)
        if a=='run':
            body.location.z+=.005*math.sin(2*t)
            for j,p in enumerate(segments):
                p.location.z+=.009*math.sin(t-j*.8)
                p.rotation_euler.x=.10*math.sin(t-j*.8-.7)
            for hip,knee,j,sign in legs:
                phase=t+j*math.tau/3+(math.pi if sign<0 else 0)
                hip.rotation_euler.x=.51*math.sin(phase)
                # Stance retains ground height; swing folds at second joint.
                knee.rotation_euler.x=-.51*math.sin(phase)
                knee.location.z+=.055*(1-math.cos(hip.rotation_euler.x))
                if math.cos(phase)>0: knee.rotation_euler.y=sign*.55*math.cos(phase)
            head.rotation_euler.x=.075*math.sin(t-1.1)
        if a=='attack':
            reach=(0,-.027,-.048,.043,.022,.006)[f]
            body.location.y-=reach*.32; head.location.y-=reach*.68
            for j,p in enumerate(segments): p.scale.y=1+reach*(j+1)*.8
            opening=(.0,.12,.20,1,.40,.06)[f]
            for j,p in enumerate(jaws):
                a0=j*math.pi/2+math.pi/4
                p.location.x=.042*opening*math.cos(a0); p.location.z=.042*opening*math.sin(a0)
                p.rotation_euler.x=-.35*opening*math.sin(a0)
                p.rotation_euler.z=.35*opening*math.cos(a0)
            if f==3: mouth.scale=(1,)*3
            head.rotation_euler.x=-.07*opening
        if a=='death':
            body.location.y-=(0,.009,.014,.018)[f]
            body.location.z-=(0,.012,.025,.035)[f]
            body.rotation_euler.x=(.04,.12,.17,.14)[f]
            body.scale.z=(1,.82,.63,.48)[f]
            head.rotation_euler.x=f*.13
            for j,p in enumerate(segments): p.rotation_euler.z=f*.035*math.sin(j+1)
            for hip,knee,j,sign in legs: hip.rotation_euler.y=sign*f*.20
    produce('swarm_tier1_rust',(64,56),48,dict(idle=4,run=8,attack=6,death=4),root,pose)

def shooter():
    setup((88,104),96)
    pale=material('Weathered pale oilcloth','B8B09A')
    tar=material('Tar soaked hems','514B3F')
    iron=material('Dark iron lamp and riveter','454944')
    rust=material('Warm rust joints','875637')
    brass=material('Light brass gas cylinder A8946E','A8946E')
    orange=material('Lamp and muzzle FF9A3C','FF9A3C',1.3)
    root=empty('Riveteur direction'); pelvis=empty('Pelvis',(0,0,.45),root)
    torso=empty('Hunched shoulders',(0,.025,.24),pelvis)
    ellipsoid('Clothed narrow chest',(0,0,0),(.13,.11,.23),pale,torso,2)
    # Actual draped polygon panels with irregular hems and a forward split.
    cloth=[]
    for j in range(8):
        a=math.tau*j/8; panel=empty('Oilcloth shoulder fold %d'%j,(0,0,.20),torso); cloth.append(panel)
        verts=[]
        for r,z in ((.08,0),(.19,-.14),(.145,-.43-(j%3)*.025)):
            for u in (a-.36,a+.36): verts.append((r*math.cos(u),r*.78*math.sin(u),z))
        mesh('Pale creased tarpaulin',verts,[(0,1,3,2),(2,3,5,4)],pale,panel)
        taper('Dark tar hem',verts[4],verts[5],(.018,.012),tar,panel,4)
    tank=empty('Dorsal pressure cylinder',(0,.15,.04),torso)
    taper('Broad light brass bottle',(0,0,-.22),(0,0,.22),(.092,.066),brass,tank,8)
    for z in (-.13,.10): taper('Iron cylinder band',(0,0,z-.015),(0,0,z+.015),(.096,.092),iron,tank,8)
    taper('Gas valve',(0,0,.21),(.055,0,.27),(.026,.014),rust,tank,5)
    head=empty('Gas lamp head',(0,-.055,.33),torso)
    taper('Gas lamp top cap',(0,0,.08),(0,0,.125),(.094,.04),brass,head,6)
    taper('Lamp lower bowl',(0,0,-.075),(0,0,-.035),(.066,.085),iron,head,6)
    ellipsoid('Orange gas mantle',(0,0,.005),(.046,.045,.072),orange,head,2)
    for j in range(6):
        a=math.tau*j/6; x=.072*math.cos(a); y=.072*math.sin(a)
        taper('Lamp cage tapered bar',(x,y,-.055),(x*.9,y*.9,.085),(.014,.009),iron,head,4)
    legs=[]; feet=[]
    for sign in (-1,1):
        hip=empty('Hip %d'%sign,(sign*.075,0,0),pelvis)
        knee=empty('Knee',(0,.018,-.215),hip)
        taper('Trouser thigh',(0,0,0),tuple(knee.location),(.054,.033),tar,hip,6)
        taper('Gaiter shin',(0,0,0),(0,-.018,-.205),(.036,.023),pale,knee,5)
        taper('Work boot',(0,-.002,-.192),(0,-.102,-.205),(.041,.027),iron,knee,5)
        legs.append((hip,knee,sign)); feet.extend(((sign*.075,-.102,.025),(sign*.075,.035,.025)))
    gun=empty('Riveter two hand grip',(.09,-.15,.015),torso)
    taper('Riveter steam chamber',(0,.06,0),(0,-.18,0),(.065,.047),brass,gun,8)
    taper('Riveter tapered barrel',(0,-.17,0),(0,-.30,0),(.042,.025),iron,gun,6)
    taper('Riveter muzzle ring',(0,-.28,0),(0,-.32,0),(.045,.034),rust,gun,6)
    taper('Riveter trigger grip',(0,0,0),(0,.015,-.115),(.027,.019),iron,gun,5)
    flash=empty('Impact muzzle', (0,-.335,0),gun)
    taper('Hot rivet steam flash',(0,0,0),(0,-.06,0),(.051,.006),orange,flash,6)
    # Curved tapered hose built with a small number of variable-section segments.
    hose=empty('Flexible pressure hose',parent=torso)
    pts=[(.06,.17,.13),(.18,.14,.07),(.215,.04,-.07),(.20,-.12,-.13),(.12,-.20,-.025)]
    for j in range(len(pts)-1): taper('Steam hose',pts[j],pts[j+1],(.023,.018),tar,hose,5)
    arms=[]
    for sign in (-1,1):
        shoulder=empty('Shoulder %d'%sign,(sign*.14,-.015,.12),torso)
        elbow=empty('Elbow',(sign*.035,-.09,-.09),shoulder)
        taper('Heavy sleeve upper arm',(0,0,0),tuple(elbow.location),(.056,.037),pale,shoulder,6)
        target=(.09-sign*.175,-.14,.015)
        taper('Gloved tapered forearm',(0,0,0),target,(.039,.027),tar,elbow,6)
        ellipsoid('Gloved supporting hand',target,(.039,.045,.035),rust,elbow)
        arms.append((shoulder,elbow,sign))
    root['foot_reference']=feet; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; flash.scale=(.01,)*3
        torso.scale.z=1+.018*math.sin(t+.15)
        head.rotation_euler.z=.045*math.sin(t+.5)
        for j,p in enumerate(cloth): p.rotation_euler.x=.025*math.sin(t-.8+j*.3)
        if a=='idle': head.rotation_euler.x=.055*math.sin(t+.4)
        if a=='run':
            pelvis.location.z+=.011*math.sin(2*t)
            for hip,knee,sign in legs:
                p=t+(math.pi if sign<0 else 0); y=.115*math.sin(p)
                z=.035+.07*max(0,math.cos(p))-pelvis.location.z
                bend=-math.acos(max(-1,min(1,(y*y+z*z-.215**2-.205**2)/(2*.215*.205))))
                hip.rotation_euler.x=math.atan2(y,-z)-math.atan2(.205*math.sin(bend),.215+.205*math.cos(bend))
                knee.rotation_euler.x=bend
            torso.rotation_euler.z=.045*math.sin(t)
            gun.rotation_euler.x=.10*math.sin(t-.8)
            hose.rotation_euler.x=.07*math.sin(t-1.2)
            for j,p in enumerate(cloth): p.rotation_euler.x=.11*math.sin(t-1+j*.3)
        if a=='attack':
            reach=(0,-.025,-.06,-.045,.065,-.025,.025,.005)[f]
            gun.location.y-=reach; gun.location.z+=(0,.02,.055,.07,.07,.04,.02,0)[f]
            gun.rotation_euler.x=(0,-.08,-.12,-.09,0,.14,.05,0)[f]
            torso.location.y-=reach*.22
            for shoulder,elbow,sign in arms:
                shoulder.rotation_euler.x=-reach*.9-.12*(f in (2,3,4))
                elbow.rotation_euler.z=sign*reach*.7
            hose.scale.y=1+reach*.9
            if f==4: flash.scale=(1,)*3
        if a=='death':
            pelvis.rotation_euler.x=(.05,.35,.63,.88)[f]
            pelvis.location.z-=(0,.035,.065,.095)[f]
            pelvis.location.y-=(0,.02,.04,.055)[f]
            torso.scale.z=1-f*.13; head.rotation_euler.x=f*.12
            gun.rotation_euler.x=-f*.16; gun.rotation_euler.y=f*.17
            gun.location.y+=f*.055; gun.location.z+=f*.018
            for hip,knee,sign in legs:
                hip.rotation_euler.x=-pelvis.rotation_euler.x+f*.22; knee.rotation_euler.x=-f*.48
            for j,p in enumerate(cloth): p.rotation_euler.x=-f*.075
    produce('shooter_tier2_rust',(88,104),96,dict(idle=4,run=8,attack=8,death=4),root,pose)

def c1_contact():
    # Reuse the pilot's assembly and in-game Ash Lord scaling, with this biome.
    import inspect, common_v2
    source=inspect.getsource(common_v2.contact)
    source=source.replace('def contact():','def assemble():').replace('terrain/terraces/','terrain/rust_city/')
    source=source.replace("'swarm_tier1'","'swarm_tier1_rust'").replace("'shooter_tier2'","'shooter_tier2_rust'")
    source=source.replace('_mob_v2_t1_contact.png','_mob_v2_c1_contact.png')
    ns=dict(globals()); exec(source,ns); ns['assemble']()

def audit(name,size,bottom,counts,root,pose):
    from bpy_extras.object_utils import world_to_camera_view
    scene=bpy.context.scene; failures=[]; extrema=[999,999,0,0]
    meshes=[o for o in root.children_recursive if o.type=='MESH']
    tris=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    assert tris<=(1500 if name.startswith('swarm') else 3000),(name,tris)
    for a,n in counts.items():
        for d in (('e','s','w','n') if a=='death' else DIRS):
            root.rotation_euler.z=math.radians(90-45*DIRS.index(d)); rot=root.rotation_euler.to_matrix()
            low=min((rot@Vector(p)).y*.5+p[2]*math.cos(math.pi/6) for p in root['foot_reference'])
            scene.camera.data.shift_y=(bottom-size[1]/2+low*64)/size[0]
            for f in range(n):
                pose(a,f,n); bpy.context.view_layer.update(); pts=[]
                for o in meshes:
                    for v in o.data.vertices:
                        p=world_to_camera_view(scene,scene.camera,o.matrix_world@v.co)
                        pts.append((p.x*size[0],(1-p.y)*size[1]))
                box=(min(p[0] for p in pts),min(p[1] for p in pts),max(p[0] for p in pts),max(p[1] for p in pts))
                extrema=[min(extrema[0],box[0]),min(extrema[1],box[1]),max(extrema[2],box[2]),max(extrema[3],box[3])]
                if box[0]<4 or box[1]<4 or box[2]>size[0]-4 or box[3]>size[1]-4: failures.append((a,d,f,tuple(round(v,1) for v in box)))
    print('C1 AUDIT',name,'tris',tris,'bounds',tuple(round(v,1) for v in extrema),'failures',len(failures),failures[:4],flush=True)
    assert not failures

if __name__=='__main__':
    if '--audit' in sys.argv: produce=audit
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'swarm'
    {'swarm':swarm,'shooter':shooter,'contact':c1_contact}[role]()
