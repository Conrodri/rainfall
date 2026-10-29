"""MOB_V2_T1. New articulated meshes; build one complete creature at a time."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *

def resetters(root):
    base=[(o,o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive if o.type=='EMPTY']
    def reset():
        for o,l,r,s in base: o.location=l; o.rotation_euler=r; o.scale=s
    return reset

def swarm():
    rig((64,56),48)
    pale=material('Pale patinated jar bronze','BAC6A2'); patina=material('Verdigris grooves','5F8F80')
    mud=material('Wet grey green abdomen','61766B'); dark=material('Pointed dark joints','343D32')
    glow=material('Water cyan 5EC8FF','5EC8FF',1.3)
    root=empty('Tesson de vase - direction'); body=empty('Breathing thorax',(0,0,.17),root)
    ellipsoid('Soft abdomen',(0,.18,.015),(.17,.22,.12),mud,body,2)
    tail=empty('Lagged abdomen tip',(0,.30,0),body)
    ellipsoid('Exposed rear fold',(0,0,0),(.13,.115,.09),mud,tail,2)
    # A broken curved jar fragment: asymmetric rim, nested inner surface, chipped edges.
    verts=[]; n=12
    for inner in (False,True):
        for level in range(3):
            for j in range(n):
                t=math.tau*j/n; rad=(.225,.23,.13)[level]-(.023 if inner else 0)
                z=(.015,.15,.265)[level]+(.025*math.sin(j*2.4) if level!=1 else 0)
                verts.append((rad*math.cos(t),rad*1.12*math.sin(t)+.025,z-(.018 if inner else 0)))
    faces=[]
    for side in (0,36):
        faces += [(side+k*n+j,side+k*n+(j+1)%n,side+(k+1)*n+(j+1)%n,side+(k+1)*n+j) for k in range(2) for j in range(n)]
    faces += [(j,(j+1)%n,36+(j+1)%n,36+j) for j in range(n)]
    faces += [(24+j,24+(j+1)%n,60+(j+1)%n,60+j) for j in range(n)]
    mesh('New chipped jar fragment',verts,faces,pale,body)
    # Raised dark incisions form an unmistakable broken water-wave motif.
    for j in range(7):
        t=j*.34+.15
        a=(.218*math.cos(t),.245*math.sin(t)+.025,.14)
        b=(.201*math.cos(t+.28),.225*math.sin(t+.28)+.025,.18)
        taper('Incised wave %d'%j,a,b,(.009,.005),patina,body,4)
    head=empty('Telescoping head',(0,-.18,.005),body)
    ellipsoid('Armoured brow',(0,-.025,0),(.145,.13,.09),mud,head,2)
    for sign in (-1,1):
        ellipsoid('Cyan eye slit',(sign*.083,-.127,.034),(.037,.017,.016),glow,head)
    jaws=[]
    for sign in (-1,1):
        jaw=empty('Mandible hinge',(sign*.075,-.085,-.025),head); jaws.append(jaw)
        taper('Curved mandible root',(0,0,0),(sign*.035,-.06,-.012),(.028,.017),pale,jaw)
        taper('Mandible tooth',(sign*.035,-.06,-.012),(sign*.012,-.075,0),(.017,.002),pale,jaw)
    mouth=empty('Impact mouth',(0,-.14,-.02),head)
    ellipsoid('Cyan open mouth',(0,0,0),(.052,.021,.04),glow,mouth)
    legs=[]; footrefs=[]
    for i,y in enumerate((-.15,.01,.18)):
        for sign in (-1,1):
            hip=empty('Hip %d %d'%(i,sign),(sign*.12,y,.005),body)
            knee=empty('Knee %d %d'%(i,sign),(sign*.11,.025,-.055),hip)
            taper('Thick upper leg',(0,0,0),tuple(knee.location),(.035,.022),mud,hip)
            taper('Pointed lower leg',(0,0,0),(sign*.06,-.015,-.10),(.022,.002),dark,knee)
            legs.append((hip,knee,i,sign)); footrefs.append((sign*.29,y+.01,.02))
    root['foot_reference']=footrefs; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; mouth.scale=(.04,)*3
        body.scale.z=1+.035*math.sin(t+.2); tail.rotation_euler.x=.12*math.sin(t-.8)
        head.rotation_euler.z=.05*math.sin(t+.4)
        if a=='idle':
            jaws[0].rotation_euler.z=.16*math.sin(t+.5); head.location.y-=.008*math.sin(t)
        if a=='run':
            body.location.z+=.006*math.sin(2*t)
            for hip,knee,i,sign in legs:
                p=t+i*math.tau/3+(math.pi if sign<0 else 0)
                hip.rotation_euler.z=.48*math.sin(p); hip.rotation_euler.y=sign*.22*max(0,math.cos(p))
                knee.rotation_euler.x=.32*max(0,math.cos(p))
            tail.rotation_euler.y=.16*math.sin(t-math.pi/4)
        if a=='attack':
            ext=(0,-.025,-.045,.055,.025,.008)[f]
            head.location.y-=ext; body.location.y+=.012 if f in (1,2) else -.008*f/6
            for j,sign in zip(jaws,(-1,1)): j.rotation_euler.z=sign*(.8 if f==3 else .15*f/6)
            if f==3: mouth.scale=(1,1,1)
        if a=='death':
            body.rotation_euler.x=(.10,.45,.65,.78)[f]
            body.location.z+=.05+f*.008; body.location.y+=.012*f
            body.scale.z=1-f*.11
            for hip,knee,i,sign in legs:
                hip.rotation_euler.y=-sign*(.25+f*.18); knee.rotation_euler.x=f*.22
    produce('swarm_tier1',(64,56),48,dict(idle=4,run=8,attack=6,death=4),root,pose)

def shooter():
    rig((88,104),96)
    straw=material('Pale soaked straw','C5BF95'); bronze=material('Dented pale bronze','B9BE94')
    wood=material('Waterlogged pine','766D4B'); shade=material('Hollow face and bindings','303C35')
    bamboo=material('Bamboo blowpipe','8F9B70'); cyan=material('Water cyan 5EC8FF','5EC8FF',1.3)
    root=empty('Guetteur des rizieres - direction'); pelvis=empty('Pelvis',(0,0,.53),root)
    torso=empty('Bound upper stakes',(0,0,.15),pelvis)
    for x in (-.065,.065): taper('Split pine stake',(x,0,-.23),(x*.8,0,.35),(.055,.035),wood,torso)
    # Irregular overlapping mantle panels, with thickness and torn pale straw tips.
    cloth=[]
    for j in range(10):
        t=math.tau*j/10
        panel=empty('Straw panel pivot %02d'%j,(.10*math.cos(t),.10*math.sin(t),.27),torso); cloth.append(panel)
        dt=.36; v=[]
        for r,z in ((.055,0),(.15,-.22),(.19,-.47-(j%3)*.018)):
            for u in (t-dt,t+dt): v.append((r*math.cos(u),r*math.sin(u),z))
        mesh('Layered wet straw mantle %02d'%j,v,[(0,1,3,2),(2,3,5,4)],straw,panel)
        taper('Straw ridge',(v[0][0],v[0][1],-.04),v[4],(.012,.004),wood,panel,4)
    head=empty('Hidden face',(0,-.015,.35),torso)
    ellipsoid('Black face hollow',(0,-.025,0),(.09,.075,.11),shade,head,2)
    ellipsoid('Single cyan eye',(.025,-.108,-.068),(.026,.018,.023),cyan,head)
    n=12; v=[(0,.005,.20)]
    for j in range(n):
        t=math.tau*j/n; r=.255*(1+.06*math.sin(3*t))
        v.append((r*math.cos(t),r*math.sin(t),.055+.018*math.sin(2*t)))
    v.append((0,0,.028)); mesh('Dented conical bronze hat',v,[(0,j+1,(j+1)%n+1) for j in range(n)]+[(n+1,(j+1)%n+1,j+1) for j in range(n)],bronze,head)
    for z in (-.12,.04,.19):
        for x in (-.1,0,.1): taper('Rotten rope knots',(x,-.065,z),(x+.035,-.07,z+.02),(.015,.008),shade,torso,4)
    legs=[]; feet=[]
    for sign in (-1,1):
        hip=empty('Hip %d'%sign,(sign*.09,0,0),pelvis)
        knee=empty('Knee %d'%sign,(0,.015,-.25),hip)
        taper('Tapered pine thigh',(0,0,0),tuple(knee.location),(.05,.031),wood,hip)
        taper('Tapered pine shin',(0,0,0),(0,-.015,-.24),(.034,.018),wood,knee)
        taper('Splayed root foot',(0,-.015,-.24),(sign*.025,-.10,-.25),(.031,.01),shade,knee)
        legs.append((hip,knee,sign)); feet.extend(((sign*.115,-.10,.01),(sign*.09,0,.01)))
    arms=[]
    weapon=empty('Blowpipe aim',(0,-.06,.22),torso)
    # Full 1.2u pipe; rear counterbalances its forward muzzle inside the fixed cell.
    taper('Bamboo 1.2u',(.035,.60,0),(.035,-.60,0),(.030,.024),bamboo,weapon,8)
    for y in (-.54,-.22,.07,.36,.57):
        taper('Bamboo node',(.035,y-.012,0),(.035,y+.012,0),(.036,.033),bronze,weapon,6)
    taper('Muzzle dark opening',(.035,-.603,0),(.035,-.609,0),(.022,.018),shade,weapon,8)
    puff=empty('Impact water puff',(.035,-.61,0),weapon)
    for j in range(3): ellipsoid('Water impact droplet',((j-1)*.025,0,(j%2)*.025),(.022,.018,.024),cyan,puff)
    for sign in (-1,1):
        arm=empty('Shoulder %d'%sign,(sign*.14,0,.21),torso)
        elbow=empty('Elbow %d'%sign,(sign*.035,-.08,-.16),arm)
        taper('Upper pine arm',(0,0,0),tuple(elbow.location),(.037,.025),wood,arm)
        taper('Bound forearm',(0,0,0),(-sign*.08,-.17,.04),(.028,.017),wood,elbow)
        arms.append((arm,elbow,sign))
    root['foot_reference']=feet; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; puff.scale=(.01,)*3
        torso.scale.z=1+.022*math.sin(t+.1)
        head.rotation_euler.z=.06*math.sin(t+.3)
        weapon.rotation_euler.x=.85
        for j,p in enumerate(cloth): p.rotation_euler.x=.035*math.sin(t-.9+j*.3)
        if a=='idle': head.rotation_euler.y=.07*math.sin(t+.2)
        if a=='run':
            pelvis.location.z+=.012*math.sin(2*t)
            for hip,knee,sign in legs:
                p=t+(math.pi if sign<0 else 0)
                y=.17*math.sin(p); z=.065+.09*max(0,math.cos(p))-pelvis.location.z
                bend=-math.acos(max(-1,min(1,(y*y+z*z-.25**2-.24**2)/(2*.25*.24))))
                hip.rotation_euler.x=math.atan2(y,-z)-math.atan2(.24*math.sin(bend),.25+.24*math.cos(bend))
                knee.rotation_euler.x=bend
            torso.rotation_euler.z=.07*math.sin(t)
            for arm,elbow,sign in arms: arm.rotation_euler.x=-sign*.32*math.sin(t)
            for j,p in enumerate(cloth): p.rotation_euler.x=.12*math.sin(t-math.pi/4+j*.3)
        if a=='attack':
            weapon.rotation_euler.x=(.75,.90,.65,.20,0,.18,.48,.72)[f]
            torso.rotation_euler.x=(0,-.08,-.12,-.04,.04,.04,.02,0)[f]
            weapon.location.y+=(.015,.03,.045,.06,.085,.07,.04,.008)[f]
            for arm,elbow,sign in arms:
                arm.rotation_euler.x=-.65*(1-weapon.rotation_euler.x)
                elbow.rotation_euler.x=-.35*(1-weapon.rotation_euler.x)
            if f==4: puff.scale=(1,1,1)
        if a=='death':
            pelvis.rotation_euler.x=(.15,.48,.74,.90)[f]
            pelvis.location.z-=f*.057; pelvis.location.y+=f*.035
            torso.scale.z=1-f*.13; head.rotation_euler.x=f*.14
            weapon.rotation_euler.x=.8+f*.18
            for hip,knee,sign in legs:
                hip.rotation_euler.x=-pelvis.rotation_euler.x
                knee.rotation_euler.x=-f*.3
    produce('shooter_tier2',(88,104),96,dict(idle=4,run=8,attack=8,death=4),root,pose)


def front_impact(role):
    """Retouch existing keyed sources; patch only s/se/sw impact cells."""
    import tempfile
    specs={'swarm':('swarm_tier1',(64,56),48),
           'shooter':('shooter_tier2',(88,104),96),
           'leaper':('leaper_tier2',(96,96),82),
           'brute':('brute_tier3',(128,136),124)}
    name,size,bottom=specs[role]
    source=ROOT/'art/blender/monsters/v2'/(name+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    s=bpy.context.scene
    root=next(o for o in s.objects if 'v2_cell' in o)
    s.render.engine='BLENDER_EEVEE'
    s.eevee.taa_render_samples=8
    cel.install('creature',normals=False)
    out=ROOT/'game/assets/sprites/monsters'/name
    work=Path(tempfile.mkdtemp(prefix='rainfall_terr_render_'))
    objects={o.name:o for o in root.children_recursive}
    def edit(action):
        touched=[]
        def node(n):
            o=objects[n]; touched.append(o); return o
        if role=='swarm':
            h=node('Telescoping head'); h.location.y=-.35; h.location.z=.04
            h.rotation_euler.x=-.22; h.rotation_euler.z=0
            for o in objects.values():
                if o.type=='EMPTY' and o.name.startswith('Mandible hinge'):
                    touched.append(o); o.rotation_euler.z=1.05 if o.location.x>0 else -1.05
            node('Impact mouth').scale=(1.25,1.3,1.3)
        elif role=='shooter':
            w=node('Blowpipe aim'); w.rotation_euler.x=-.28; w.location.y=-.095; w.location.z=.255
            node('Impact water puff').scale=(1.65,1.8,1.5)
            for o in objects.values():
                if o.type=='EMPTY' and o.name.startswith('Shoulder '):
                    touched.append(o); o.rotation_euler.x=-1.15
        elif role=='leaper':
            h=node('Lateral neck hinge'); h.location.y=-.43; h.location.z=.05
            h.rotation_euler.z=0; h.rotation_euler.x=-.20
            node('Lower jaw pivot').rotation_euler.x=1.05
            node('Impact open cyan palate').scale=(1.05,1.25,1.4)
        else:
            for sign in (-1,1):
                sh=node('Shoulder '+str(sign)); el=node('Elbow '+str(sign))
                if sign>0 or action=='cast':
                    sh.rotation_euler.x=-1.6; sh.rotation_euler.y=0
                    sh.rotation_euler.z=-.25*sign if action=='cast' else .12
                    el.rotation_euler.x=-.12
            w=node('Broken noria wheel weapon'); w.rotation_euler.y=.22; w.rotation_euler.z=-.18
        for o in touched:
            for prop in ('location','rotation_euler','scale'):
                o.keyframe_insert(data_path=prop,frame=s.frame_current)
    markers=sorted(s.timeline_markers,key=lambda m:m.frame)
    for action in ('attack','cast') if role=='brute' else ('attack',):
        marker=next(m for m in markers if m.name==action)
        n=6 if role in ('swarm','leaper') else 8
        f=n//2; s.frame_set(marker.frame+f); edit(action)
        sheets={suffix:Image.open(out/(action+suffix+'.png')).convert('RGBA') for suffix in ('','_e')}
        for d in ('se','s','sw'):
            row=DIRS.index(d); root.rotation_euler.z=math.radians(90-45*row)
            rot=root.rotation_euler.to_matrix(); refs=[Vector(v) for v in root['foot_reference']]
            lowest=min((rot@p).y*.5+p.z*math.cos(math.pi/6) for p in refs)
            s.camera.data.shift_y=(bottom-size[1]/2+lowest*64)/size[0]
            bpy.context.view_layer.update()
            path=work/(action+'_'+d+'.png'); iso_rig.common.configure_passes(path)
            s.render.filepath=str(path); bpy.ops.render.render(write_still=True)
            for suffix in ('','_e'):
                src=path if not suffix else next(work.glob(path.stem+'_e__*.png'))
                tile=Image.open(src).convert('RGBA').resize(size,Image.Resampling.LANCZOS)
                if suffix: tile=tile.resize((size[0]//2,size[1]//2),Image.Resampling.LANCZOS)
                sheets[suffix].paste(tile,(f*tile.width,row*tile.height))
        for suffix,im in sheets.items():
            im.save(out/(action+suffix+'.png'),optimize=True,compress_level=9)
    root.rotation_euler.z=0; s.frame_set(1)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print('FRONT IMPACT PASS',name,flush=True)

if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'swarm'
    if '--front-impact' in sys.argv: front_impact(role)
    else:
        {'swarm':swarm,'shooter':shooter,'contact':contact}[role]()
        if role=='shooter': contact()
