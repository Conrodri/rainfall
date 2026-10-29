"""Terraces v2: new articulated basin salamander and sluice operator.
Blender --background --python t2_build.py -- leaper|brute|contact
"""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common_v2 import *
from t1_build import resetters, front_impact

def plate(name,loc,size,mat,parent,bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1)
    o=bpy.context.object; o.name=name; o.parent=parent; o.location=loc
    o.scale=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    m=o.modifiers.new('Worn visible bevels','BEVEL'); m.width=bevel; m.segments=1
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=m.name)
    return o

def fin(name,points,width,mat,parent):
    vs=[(x,y,z+dz) for dz in (-width/2,width/2) for x,y,z in points]
    n=len(points); fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    fs += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    return mesh(name,vs,fs,mat,parent)

def ring(name,loc,radius,thick,mat,parent):
    bpy.ops.mesh.primitive_torus_add(major_segments=16,minor_segments=4,location=(0,0,0),major_radius=radius,minor_radius=thick)
    o=bpy.context.object; o.name=name; o.parent=parent; o.location=loc
    o.data.materials.append(mat); return o

def plant(hip,knee,foot,upper,lower,y,z):
    """Two-bone sagittal IK: stance feet remain level at the ground plane."""
    l1=math.hypot(*upper); l2=math.hypot(*lower)
    d=min(l1+l2-.001,max(abs(l1-l2)+.001,math.hypot(y,z)))
    axis=math.atan2(y,-z)
    c1=max(-1,min(1,(l1*l1+d*d-l2*l2)/(2*l1*d)))
    c2=max(-1,min(1,(l2*l2+d*d-l1*l1)/(2*l2*d)))
    hip.rotation_euler.x=axis+math.acos(c1)-math.atan2(upper[0],-upper[1])
    knee.rotation_euler.x=axis-math.acos(c2)-math.atan2(lower[0],-lower[1])-hip.rotation_euler.x
    foot.rotation_euler.x=-hip.rotation_euler.x-knee.rotation_euler.x

def finish(name,size,bottom,counts,root,pose):
    # Shared writer supports variable action counts; fix its pilot-only load_steps.
    import common_v2 as cv
    original=cv.tres
    def write(*args):
        original(*args)
        p=args[3]/(args[0]+'.tres'); txt=p.read_text(encoding='utf8')
        import re
        steps=1+len(args[2])+sum(n*(4 if a=='death' else 8) for a,n in args[2].items())
        p.write_text(re.sub(r'load_steps=\d+','load_steps='+str(steps),txt,count=1),encoding='utf8')
    cv.tres=write
    produce(name,size,bottom,counts,root,pose)

def leaper():
    rig((96,96),82)
    pale=material('Pale mineral dorsal skin','B6C6AE'); mud=material('Basin mud skin 4A5B5A','4A5B5A')
    rust=material('Corroded bronze rings','8E704A'); dark=material('Mouth and mottled skin','303F3C')
    glow=material('Water cyan 5EC8FF','5EC8FF',1)
    root=empty('Basin salamander direction'); body=empty('Breathing low spine',(0,.015,.285),root)
    ellipsoid('Broad pale dorsal mantle',(0,.015,.025),(.235,.295,.175),pale,body,2)
    ellipsoid('Heavy hindquarters',(0,.215,-.025),(.25,.18,.15),mud,body,2)
    head=empty('Lateral neck hinge',(0,-.235,.005),body)
    ellipsoid('Wide flat shovel skull',(0,-.08,0),(.255,.20,.10),pale,head,2)
    jaw=empty('Lower jaw pivot',(0,-.025,-.055),head)
    ellipsoid('Lower mud jaw',(0,-.08,0),(.225,.155,.045),mud,jaw,2)
    mouth=empty('Impact open cyan palate',(0,-.16,-.04),head)
    ellipsoid('Mouth water light',(0,0,0),(.17,.085,.025),glow,mouth)
    for sign in (-1,1):
        ellipsoid('Raised dark eye socket',(sign*.175,-.135,.065),(.061,.065,.035),dark,head)
        ellipsoid('Cyan eye',(sign*.185,-.155,.084),(.031,.034,.018),glow,head)
        for j in range(3):
            x=sign*(.19+j*.018); y=.015+j*.065
            g=empty('Articulated external gill',(x,y,0),head)
            fin('Pale gill blade',[(0,0,0),(sign*.15,.025,.08),(sign*.11,.075,.09),(0,.055,0)],.035,pale,g)
            fin('Cyan gill tip',[(sign*.105,.035,.07),(sign*.15,.025,.08),(sign*.11,.075,.09)],.038,glow,g)
    gills=[o for o in head.children if o.type=='EMPTY' and 'gill' in o.name]
    tail=empty('Delayed flattened tail',(0,.32,-.05),body)
    fin('Flattened muscular tail',[(-.13,0,0),(-.12,.10,.005),(-.035,.22,-.03),(.04,.26,-.035),(.12,.08,.015),(.13,0,0)],.095,mud,tail)
    for j in range(2):
        o=ring('Rust bronze tail collar',(0,.10+j*.10,0),.105-j*.018,.015,rust,tail)
        o.rotation_euler.x=math.pi/2; o.scale.z=.47
    for j in range(9):
        x=(-1 if j%2 else 1)*(.12+.025*(j%3)); y=-.15+.047*j
        ellipsoid('Mud skin mottling',(x,y,.12),(.037,.045,.014),mud,body)
    legs=[]; refs=[]
    for i,y in enumerate((-.16,.22)):
        for sign in (-1,1):
            hip=empty('Hip %d %d'%(i,sign),(sign*.22,y,-.065),body)
            knee=empty('Knee %d %d'%(i,sign),(sign*.075,.025,-.105),hip)
            taper('Powerful tapered thigh',(0,0,0),tuple(knee.location),(.080 if i else .06,.045),mud,hip,6)
            taper('Tapered shin',(0,0,0),(sign*.035,-.08,-.085),(.042,.022),pale,knee,6)
            foot=empty('Ankle',(sign*.035,-.08,-.085),knee)
            for toe in range(3):
                taper('Splayed toe',(0,0,0),(sign*(toe-1)*.028,-.065,.0),(.019,.006),pale,foot,4)
            legs.append((hip,knee,foot,i,sign)); refs.append((sign*.33,y-.08,.025))
    root.scale=(.88,)*3
    root['foot_reference']=[tuple(v*.88 for v in p) for p in refs]; reset=resetters(root)
    def pose(a,f,n):
        reset(); t=math.tau*f/n; mouth.scale=(.025,)*3
        body.scale.z=1+.025*math.sin(t+.2); head.rotation_euler.z=.035*math.sin(t+.4)
        tail.rotation_euler.z=.10*math.sin(t-math.pi/4)
        for j,g in enumerate(gills): g.rotation_euler.y=.07*math.sin(t-j*.3)
        if a=='idle': head.rotation_euler.x=.045*math.sin(t+.7)
        if a=='run':
            body.location.z+=.008*math.cos(2*t)
            for hip,knee,foot,i,sign in legs:
                p=t+i*math.pi+(math.pi if sign<0 else 0); lift=max(0,math.sin(p))
                plant(hip,knee,foot,(.025,-.105),(-.08,-.085),-.045+.055*math.cos(p),-.19-.008*math.cos(2*t)+.075*lift)
            tail.rotation_euler.z=.21*math.sin(t-math.pi/4)
        if a=='charge':
            p=f/(n-1); body.location.z-=.05*p; body.scale.z=1-.12*p
            head.rotation_euler.x=-.12*p; tail.rotation_euler.x=-.16*p
            for g in gills: g.rotation_euler.z=.65*p
            for hip,knee,foot,i,sign in legs: hip.rotation_euler.x=.40*p; knee.rotation_euler.x=-.7*p
        if a=='leap':
            body.location.z+=.055+.012*math.sin(t); body.scale.y=1.035
            for hip,knee,foot,i,sign in legs:
                hip.rotation_euler.x=-.65+.10*math.sin(t+i); knee.rotation_euler.x=.4+.06*math.cos(t)
            tail.rotation_euler.z=.18*math.sin(t-.8)
        if a=='attack':
            ext=(0,-.035,-.07,.075,.025,.005)[f]
            head.location.y-=ext; head.rotation_euler.z=(.08,.22,.35,-.30,-.12,.01)[f]
            body.location.y-=ext*.28; jaw.rotation_euler.x=(.03,.14,.25,.8,.3,.04)[f]
            if f==3: mouth.scale=(1,1,1)
        if a=='death':
            p=f/(n-1); body.location.y-=.075*p; body.location.z-=.11*p
            body.rotation_euler.x=.25*math.sin(p*math.pi/2); body.scale.z=1-.30*p
            head.rotation_euler.x=.35*p; jaw.rotation_euler.x=.18*p
            for hip,knee,foot,i,sign in legs: hip.rotation_euler.y=-sign*.55*p; knee.rotation_euler.x=-.25*p
    finish('leaper_tier2',(96,96),82,dict(idle=4,run=8,charge=6,leap=4,attack=6,death=4),root,pose)

def brute():
    rig((128,136),124)
    pale=material('Bleached sluice timber','C4BE9E'); wood=material('Waterlogged heartwood','655A45')
    bronze=material('Worn noria bronze','A18A62'); moss=material('Moss in beam joints','5F7861')
    dark=material('Lantern recess','303A35'); glow=material('Water cyan 5EC8FF','5EC8FF',1)
    root=empty('Sluice operator direction'); hips=empty('Heavy pelvis',(0,0,.62),root)
    torso=empty('Articulated timber torso',(0,0,.15),hips)
    plate('Pelvis bronze binding',(0,0,0),(.52,.32,.24),bronze,hips)
    for x in (-.24,0,.24):
        o=plate('Pale upright gate beam',(x,0,.32),(.20,.34,.64),pale,torso)
        o.rotation_euler.y=x*.25
        for z in (.1,.49): plate('Bronze transverse strap',(x,-.185,z),(.215,.025,.065),bronze,torso,.008)
    for sign in (-1,1):
        plate('Moss joint',(sign*.13,-.186,.30),(.055,.028,.19),moss,torso,.008)
        plate('Pale massive shoulder',(sign*.39,.01,.48),(.28,.40,.25),pale,torso)
    # Broken diagonal seam, luminous only at impact in addition to the eyes.
    seam=empty('Chest fissure cyan',(0,-.195,.32),torso)
    for j in range(4):
        o=plate('Diagonal water filled crack',(-.22+j*.14,0,-.07+j*.045),(.16,.018,.025),glow,seam,.004)
        o.rotation_euler.y=-.29
    head=empty('Recessed stone lantern',(0,-.005,.59),torso)
    plate('Small pale lantern cap',(0,0,.15),(.25,.26,.08),pale,head)
    plate('Unlit lantern core',(0,0,.055),(.19,.20,.15),dark,head)
    for sign in (-1,1):
        plate('Lantern pillar',(sign*.095,-.095,.07),(.035,.035,.17),pale,head,.008)
        ellipsoid('Cyan lantern eye',(sign*.047,-.11,.08),(.024,.016,.018),glow,head)
    arms=[]
    for sign in (-1,1):
        shoulder=empty('Shoulder '+str(sign),(sign*.43,0,.43),torso)
        elbow=empty('Elbow '+str(sign),(sign*.075,0,-.26),shoulder)
        taper('Swollen timber upper arm',(0,0,0),tuple(elbow.location),(.13,.09),wood,shoulder,6)
        plate('Pale upper arm face',(sign*.025,-.09,-.10),(.16,.11,.24),pale,shoulder)
        taper('Short tapered forearm',(0,0,0),(0,-.07,-.21),(.095,.065),bronze,elbow,6)
        arms.append((shoulder,elbow,sign))
        if sign<0: plate('Short left fist',(0,-.07,-.23),(.18,.20,.17),pale,elbow)
        else: right=elbow
    wheel=empty('Broken noria wheel weapon',(0,-.08,-.25),right)
    tor=ring('Bronze wheel rim',(0,0,0),.285,.055,bronze,wheel); tor.rotation_euler.x=math.pi/2
    plate('Wheel hub',(0,0,0),(.14,.17,.14),pale,wheel)
    for j in range(8):
        a=math.tau*j/8
        if j==2: continue
        o=plate('Wood wheel spoke',(math.sin(a)*.14,0,math.cos(a)*.14),(.065,.10,.27),wood,wheel,.012)
        o.rotation_euler.y=a
        o=plate('Large noria gear tooth',(math.sin(a)*.32,0,math.cos(a)*.32),(.11,.13,.11),pale,wheel,.014)
        o.rotation_euler.y=a
    flash=empty('Impact wheel accent',(0,-.071,0),wheel)
    for j in range(3):
        a=j*.7
        o=plate('Water in broken gear',(math.sin(a)*.29,0,math.cos(a)*.29),(.095,.025,.045),glow,flash,.007); o.rotation_euler.y=a
    legs=[]; refs=[]
    for sign in (-1,1):
        hip=empty('Hip '+str(sign),(sign*.20,0,-.05),hips)
        knee=empty('Knee '+str(sign),(0,0,-.26),hip)
        taper('Tapered gate thigh',(0,0,0),(0,0,-.26),(.145,.10),wood,hip,6)
        plate('Pale thigh armour',(0,-.09,-.11),(.21,.15,.24),pale,hip)
        taper('Tapered lower timber',(0,0,0),(0,0,-.24),(.105,.075),wood,knee,6)
        foot=empty('Ankle '+str(sign),(0,0,-.24),knee)
        plate('Splayed sluice foot',(sign*.025,-.07,-.025),(.25,.34,.10),bronze,foot)
        legs.append((hip,knee,foot,sign))
        refs.extend((sign*.35,y,-.005) for y in (-.24,.10))
    root.scale=(.85,)*3
    root['foot_reference']=[tuple(v*.85 for v in p) for p in refs]; reset=resetters(root)
    solid=[o for o in root.children_recursive if o.type=='MESH']
    def pose(a,f,n):
        reset(); t=math.tau*f/n; flash.scale=(.02,)*3; seam.scale=(.025,)*3
        torso.scale.z=1+.018*math.sin(t+.15); head.rotation_euler.z=.04*math.sin(t+.5)
        wheel.rotation_euler.y=.06*math.sin(t-math.pi/4)
        if a=='idle': arms[0][1].rotation_euler.x=.09*math.sin(t+.8)
        if a=='run':
            hips.location.z+=.018*math.cos(2*t); torso.rotation_euler.z=.065*math.sin(t)
            for hip,knee,foot,sign in legs:
                p=t+(math.pi if sign<0 else 0); lift=max(0,math.sin(p))
                plant(hip,knee,foot,(0,-.26),(0,-.24),.14*math.cos(p),-.47-.018*math.cos(2*t)+.12*lift)
            for shoulder,elbow,sign in arms: shoulder.rotation_euler.x=-sign*.23*math.cos(t-.45)
            wheel.rotation_euler.y=.15*math.sin(t-math.pi/4)
        if a in ('attack','cast'):
            ext=(0,-.12,-.30,-.42,1,.55,.22,.04)[f]
            torso.rotation_euler.z=-.35*ext if a=='attack' else .035*math.sin(t)
            torso.rotation_euler.x=.16*ext if a=='cast' else .04*ext
            for shoulder,elbow,sign in arms:
                if a=='attack':
                    shoulder.rotation_euler.x=(-1.0*ext if sign>0 else -.12*ext)
                    shoulder.rotation_euler.y=(-.15*ext if sign>0 else .06*ext)
                    shoulder.rotation_euler.z=-.72*ext if sign>0 else .08*ext
                else:
                    shoulder.rotation_euler.x=5.2*ext if ext<0 else -.65*ext
                    shoulder.rotation_euler.y=(.3 if sign>0 else -1.1)*max(0,ext)
                elbow.rotation_euler.x=-.28*abs(ext)
            if a=='cast': hips.location.z-=.065*max(0,ext)
            if f==n//2: flash.scale=(1,1,1); seam.scale=(1,1,1)
        if a=='death':
            p=f/(n-1); hips.location.z-=.25*p; hips.location.y+=.04*p
            torso.rotation_euler.x=.95*p; torso.scale.z=1-.22*p
            head.rotation_euler.x=.2*p
            for hip,knee,foot,sign in legs:
                hip.rotation_euler.x=-.6*p; knee.rotation_euler.x=-.8*p; foot.rotation_euler.x=1.4*p
            for shoulder,elbow,sign in arms: shoulder.rotation_euler.x=.55*p; elbow.rotation_euler.x=-.3*p
            bpy.context.view_layer.update()
            floor=min((o.matrix_world@Vector(v)).z for o in solid for v in o.bound_box)
            hips.location.z+=max(0,(.015-floor)/root.scale.z)
    finish('brute_tier3',(128,136),124,dict(idle=4,run=8,attack=8,cast=8,death=6),root,pose)

def contact_t2():
    # Pilot layout; reference reconstructed from actual AtlasTexture margins.
    import re
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(720,480))
    for y in range(-ground.height,board.height,ground.height//2):
        for x in range(-ground.width,board.width,ground.width):
            board.alpha_composite(ground,(x+(ground.width//2 if (y//(ground.height//2))%2 else 0),y))
    refdir=ROOT/'game/assets/sprites/bosses/mini/ash_lord'
    txt=(refdir/'ash_lord.tres').read_text(encoding='utf8')
    exts=dict(re.findall(r'\[ext_resource[^\n]*path="([^"]+)"[^\n]*id="([^"]+)"',txt))
    exts={v:ROOT/'game'/k.removeprefix('res://') for k,v in exts.items()}
    def reference(a,d):
        blocks=re.findall(r'\{\s*"frames":\s*\[(.*?)\].*?"name":\s*&"([^"]+)"',txt,re.S)
        frames=next(fr for fr,name in blocks if name==a+'_'+d)
        ids=re.findall(r'SubResource\("([^"]+)"\)',frames); ident=ids[0 if a=='run' else len(ids)//2]
        block=re.search(r'\[sub_resource[^\n]*id="'+re.escape(ident)+r'"\]\n(.*?)(?=\n\[)',txt,re.S).group(1)
        atlas=re.search(r'ExtResource\("([^"]+)"\)',block).group(1)
        x,y,w,h=map(int,re.search(r'region = Rect2\(([^)]+)\)',block).group(1).split(','))
        crop=Image.open(exts[atlas]).convert('RGBA').crop((x,y,x+w,y+h))
        margin=re.search(r'margin = Rect2\(([^)]+)\)',block)
        if margin:
            mx,my,mw,mh=map(int,margin.group(1).split(',')); full=Image.new('RGBA',(w+mw,h+mh)); full.paste(crop,(mx,my)); crop=full
        factor=2.4*1.1*64/100
        return crop.resize((round(crop.width*factor),round(crop.height*factor)),Image.Resampling.LANCZOS),factor
    for panel,(a,d) in enumerate((('run','s'),('run','e'),('attack','s'),('attack','e'))):
        ox=(panel%2)*360; baseline=(panel//2)*240+218
        for x,name,size,bottom,n in ((57,'leaper_tier2',(96,96),82,6),(168,'brute_tier3',(128,136),124,8)):
            f=0 if a=='run' else n//2; row=DIRS.index(d)
            im=Image.open(ROOT/'game/assets/sprites/monsters'/name/(a+'.png')).convert('RGBA')
            tile=im.crop((f*size[0],row*size[1],(f+1)*size[0],(row+1)*size[1]))
            board.alpha_composite(tile,(ox+x-size[0]//2,baseline-bottom))
        ref,factor=reference(a,d)
        board.alpha_composite(ref,(ox+280-ref.width//2,baseline-round(117*factor)))
    board.save(ROOT/'art/tools/night/_mob_v2_t2_contact.png',optimize=True)

if __name__=='__main__':
    role=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'leaper'
    if '--front-impact' in sys.argv: front_impact(role)
    else: {'leaper':leaper,'brute':brute,'contact':contact_t2}[role]()
