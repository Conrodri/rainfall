"""Le Sonneur. Blender 5.2 --background --python sonneur.py -- [--anims ...] [--preview]
Tout est modelise, anime et rendu dans Blender (Eevee). Le modele contient toutes les phases ;
state(p) (p continu de 1 a 3) active arcs, rivets brillants, chaudiere ouverte, vapeur.
Specs (noms/tailles/frames) : voir SPECS ; livraison par pack_sonneur.py.
"""
import sys, math, argparse, random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_common import *
OUT=ROOT/'art/renders/bosses/sonneur'
BOSS_SCALE=5.3
SPECS={**{f'idle_p{p}':(6,['s'],p,(256,256)) for p in (1,2,3)},
       **{f'walk_p{p}':(8,['e','s','w','n'],p,(256,256)) for p in (1,2,3)},
       **{a:(n,['s'],p,(256,256)) for a,n,p in [('auto',6,1),('spell_a',8,1),('spell_b',8,1),('trans_p2',8,1),('trans_p3',8,2),('death',10,3),('bell_ring',6,1),('boiler_open',6,3)]},
       'lightning':(4,['s'],0,(128,768)),'bolt':(6,['s'],0,(32,32)),'steam_vent':(8,['s'],0,(64,384)),
       'ground_lightning':(6,['s'],0,(128,128)),'ground_scorch':(4,['s'],0,(128,128)),'ground_steam':(8,['s'],0,(64,384))}

def linear(h):
    c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)
def mat(name,h,metal=0,rough=.6,grain=False):
    return material(name,linear(h),metal,rough,0,grain)
def emissive(name,h,strength=1.0):
    m=material(name,linear(h),0,.5,strength);m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(0,0,0,1);return m
def set_emit(m,strength):m.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=strength
def clamp(x,a=0,b=1):return max(a,min(b,x))

def lathe(name,prof,m,parent=None,seg=48):
    verts=[];faces=[]
    for r,z in prof:
        for k in range(seg):
            a=math.tau*k/seg;verts.append((r*math.cos(a),r*math.sin(a),z))
    for i in range(len(prof)-1):
        for k in range(seg):
            a=i*seg+k;b=i*seg+(k+1)%seg;faces.append((a,a+seg,b+seg,b))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    for p in mesh.polygons:p.use_smooth=True
    ob=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(ob);ob.parent=parent;ob.data.materials.append(m);return ob

O='Chaudiere_ouverte '
def build():
    root=empty('SONNEUR_ROOT');root['height_u']=3.8
    rust=mat('Rouille #6B3A22','6B3A22',.15,.78,True);rust2=mat('Rouille sombre','3E2419',.1,.8,True)
    iron=mat('Fer noir','2B2A29',.6,.5);bellm=mat('Bronze vert-de-gris #5F8F80','5F8F80',.55,.42,True)
    bellhi=mat('Bronze clair','8DBBA8',.65,.3);rivet=mat('Rivets','A8946E',.7,.3)
    rivet.node_tree.nodes.get('Principled BSDF').inputs['Emission Color'].default_value=(*linear('FFE3A8'),1)
    cream=mat('Cadran','D9D2B8',0,.6);dark=mat('Interieur','0A0605',0,.9)
    eyes=emissive('Yeux','FFB36B',1.0);ember=emissive('Braise #FF9A3C','FF9A3C',1.0)
    bolt=emissive('Foudre #CFE8FF','CFE8FF',1.0);steam=material('Vapeur',linear('DCE3E0'),0,.9,.12)
    torso=empty('Torse_pivot',(0,0,.55),root)
    lathe('Fut chaudiere',[(0,1.6),(.4,1.57),(.72,1.45),(.92,1.28),(1.0,1.1),(1.03,.8),(1.03,.4),(1.0,.2),(.9,.06),(.8,0),(0,0)],rust,torso)
    for z,r in ((.22,1.03),(.78,1.05),(1.22,.98)):
        ring('Cerclage',(0,0,z),r+.01,.05,iron,torso,rotation=(0,0,0))
        for i in range(20):
            a=i*math.tau/20+(.08 if z>.5 else 0);sphere('Rivet corps',((r+.03)*math.sin(a),-(r+.03)*math.cos(a),z+.075),(.05,.05,.05),rivet,torso)
    for k in range(8):
        a=k*math.pi/4+math.pi/8
        box('Sangle',(1.04*math.sin(a),-1.04*math.cos(a),.72),(.12,.05,1.15),rust2,torso).rotation_euler.z=a
    for side in (-1,1):
        tube('Tuyau avant',[(side*.74,-.78,.12),(side*.77,-.86,.7),(side*.72,-.8,1.4)],.08,iron,torso)
        for z in (.35,.9):ring('Bride tuyau',(side*.75,-.83,z),.1,.03,bellhi,torso,rotation=(0,0,0))
        sphere('Soupape',(side*.72,-.8,1.42),(.12,.12,.08),bellhi,torso)
    ring('Cadran lunette',(0,-1.0,1.2),.17,.035,bellhi,torso);d=rod('Cadran face',(0,-.98,1.2),(0,-1.03,1.2),.15,cream,torso)
    needle=box('Aiguille',(.03,-1.07,1.24),(.015,.01,.13),dark,torso);needle.rotation_euler.y=.6
    hinge=empty('Panneau_pivot',(-.5,-1.12,.65),torso)
    box('Panneau chaudiere',(.5,0,0),(1.0,.09,.9),rust2,hinge)
    for z in (-.28,.28):box('Traverse panneau',(.5,-.06,z),(1.0,.05,.1),iron,hinge)
    ring('Poignee panneau',(.82,-.08,0),.07,.02,bellhi,hinge)
    for x in (.08,.92):
        for z in (-.38,.38):sphere('Clou panneau',(x,-.06,z),(.045,.03,.045),rivet,hinge)
    box(O+'cavite',(0,-.97,.65),(.98,.12,.92),dark,torso)
    box(O+'plaque braise',(0,-1.03,.65),(.82,.03,.72),ember,torso)
    for j in range(6):sphere(O+'flamme %d'%j,(-.3+j*.12,-1.07,.45+(j%3)*.16),(.07,.04,.12),ember,torso)
    for ang,z0 in ((-52,.3),(48,.35),(-70,.9)):
        pts=[]
        for i in range(5):
            a=math.radians(ang+(8 if i%2 else -8));pts.append((1.05*math.sin(a),-1.05*math.cos(a),z0+i*.19))
        tube(O+'fissure noire',pts,.06,dark,torso)
        tube(O+'fissure braise',[(x*1.005,y*1.005-.02,z) for x,y,z in pts],.03,ember,torso)
    vents=[(-.72,-.8,1.46),(.72,-.8,1.46),(0,-1.0,1.25)]
    puffs=[]
    for vi,(vx,vy,vz) in enumerate(vents):
        for j in range(5):puffs.append((sphere(O+'vapeur %d_%d'%(vi,j),(vx,vy,vz),(.1,.1,.1),steam,torso),vx,vy,vz,j/5+vi*.13))
    bell=empty('Cloche_pivot',(0,0,1.5),torso)
    lathe('Cloche',[(0,1.28),(.10,1.27),(.22,1.20),(.34,1.08),(.44,.90),(.52,.68),(.58,.46),(.66,.26),(.78,.10),(.90,-.02),(.95,-.08),(.95,-.11),(.88,-.08),(.74,.10),(.60,.30),(.4,.6),(0,.7)],bellm,bell)
    for z,r in ((.0,.93),(.36,.64),(.9,.45)):ring('Cerclage cloche',(0,0,z),r,.04,bellhi,bell,rotation=(0,0,0))
    for side in (-1,1):
        box('Oeil lumineux',(side*.2,-.565,.5),(.2,.07,.075),eyes,bell,.02).rotation_euler.z=side*.53
        box('Sourcil cloche',(side*.2,-.55,.60),(.26,.07,.05),iron,bell,.015).rotation_euler.z=side*.35
    for x in (-.15,0,.15):box('Fente bouche',(x,-.66,.2),(.05,.06,.16),dark,bell,.01).rotation_euler.z=x
    for i in range(10):
        a=i*math.tau/10;sphere('Rivet cloche',(.96*math.sin(a),-.96*math.cos(a),-.05),(.045,.045,.045),rivet,bell)
    rod('Paratonnerre',(0,0,1.25),(0,0,1.8),.032,bellhi,bell)
    for z in (1.33,1.45,1.57):ring('Spire paratonnerre',(0,0,z),.07,.014,bellhi,bell,rotation=(0,0,0))
    sphere('Pointe paratonnerre',(0,0,1.84),(.06,.06,.06),bolt,bell)
    arcs=[tube('Arc electrique %d'%k,[(0,0,1.84)]*5,.011,bolt,bell) for k in range(5)]
    # R3b: cast ribs, suspension yoke and striking rim read at sprite scale.
    for k in range(12):
        a=k*math.tau/12
        tube('Nervure bronze',[(r*math.sin(a),-r*math.cos(a),z) for r,z in ((.22,1.18),(.45,.9),(.6,.46),(.79,.12))],.025,bellhi,bell)
    ring('Levre massive',(0,0,-.075),.93,.065,bellm,bell,rotation=(0,0,0))
    rod('Battant visible',(0,0,.35),(0,0,-.23),.07,iron,bell)
    sphere('Battant bronze',(0,0,-.23),(.14,.14,.16),rivet,bell)
    for side in (-1,1):
        tube('Berceau cloche',[(side*.88,.26,1.12),(side*.91,.26,1.85),(side*.45,.26,2.64)],.075,iron,torso)
        box('Plaque berceau',(side*.83,.24,1.65),(.22,.24,.37),bellm,torso,.05)
        for z in (1.54,1.76):sphere('Rivet berceau',(side*.83,.09,z),(.055,.035,.055),rivet,torso)
    # Two storm collectors physically unfold in phase 2.
    collectors=[]
    for side in (-1,1):
        c=empty('Collecteur articul?',(side*.84,.24,1.38),torso);collectors.append((c,side))
        rod('Isolateur porteur',(0,0,0),(side*.18,0,.67),.09,iron,c)
        for z in (.18,.30,.42):
            ring('Disque isolant',(side*.18*z/.67,0,z),.16,.045,cream,c,rotation=(0,0,0))
        tube('Fourche capteur',[(side*.18,0,.5),(side*.29,0,.68),(side*.29,0,.90)],.04,bellhi,c)
        rod('Dent capteur',(side*.18,0,.57),(side*.10,0,.88),.025,bellhi,c)
        sphere('Charge capteur',(side*.29,0,.90),(.065,.065,.065),bolt,c)
    # Ruptured boiler: splayed casing plates and four exposed vent mouths.
    plates=[]
    for side in (-1,1):
        plate=empty('Blindage ?ventr?',(side*.86,.22,.82),torso);plates.append((plate,side))
        box('Ecaille chaudiere',(side*.13,0,.05),(.24,.72,.94),rust,plate,.065)
        for z in (-.24,.34):box('Bande blindage',(side*.26,0,z),(.06,.77,.08),iron,plate)
        for y in (-.25,.25):sphere('Rivet blindage',(side*.28,y,.31),(.05,.05,.05),rivet,plate)
    for side in (-1,1):
        for back in (-1,1):
            a=(side*.87,back*.45,.98);b=(side*1.17,back*.58,1.08)
            rod(O+'buse vapeur',a,b,.14,iron,torso)
            rod(O+'gorge vapeur',b,(b[0]+side*.025,b[1]+back*.012,b[2]+.008),.105,dark,torso)
    for x in (-.28,-.14,0,.14,.28):
        box(O+'grille foyer',(x,-1.10,.65),(.035,.045,.7),iron,torso,.008)
    arms=[];elbows=[];legs=[]
    for side in (-1,1):
        leg=empty('Jambe_%d'%side,(side*.55,0,.72),root);legs.append(leg)
        rod('Pilier jambe',(0,0,.1),(0,0,-.52),.27,rust2,leg)
        ring('Genouillere',(0,0,-.05),.28,.05,iron,leg,rotation=(0,0,0))
        box('Pied',(0,-.2,-.6),(.85,1.15,.24),iron,leg,.06)
        for x in (-.25,0,.25):box('Griffe',(x,-.8,-.62),(.17,.2,.14),bellhi,leg,.03)
        for x in (-.3,.3):sphere('Boulon pied',(x,.0,-.47),(.06,.06,.04),rivet,leg)
        arm=empty('Bras_%d'%side,(side*1.12,0,1.1),torso);arms.append(arm)
        box('Capot epaule',(side*.06,.02,.12),(.73,.73,.40),rust,arm,.10)
        for y in (-.26,.26):sphere('Boulon epaule',(side*.13,y,.33),(.065,.065,.04),rivet,arm)
        sphere('Epaule',(0,0,0),(.34,.32,.32),rust,arm);ring('Collier epaule',(0,0,0),.3,.045,bellhi,arm,rotation=(0,math.pi/2,0))
        rod('Bras haut',(0,0,0),(side*.3,-.05,-.7),.17,iron,arm);rod('Verin',(side*.12,-.2,-.05),(side*.3,-.22,-.55),.05,bellhi,arm)
        el=empty('Coude_%d'%side,(side*.3,-.05,-.7),arm);elbows.append(el)
        sphere('Coude',(0,0,0),(.2,.2,.2),rust,el);rod('Manche marteau',(0,0,0),(0,-.1,-.5),.14,iron,el)
        box('Marteau tete',(0,-.15,-.66),(.86,.64,.62),iron,el,.07)
        for x in (-.37,.37):box('Frette marteau',(x,-.15,-.66),(.12,.68,.66),bellm,el,.03)
        box('Table de frappe',(0,-.51,-.66),(.66,.13,.49),rust2,el,.045)
        for z in (-.80,-.53):box('Denture marteau',(0,-.59,z),(.60,.06,.065),bellhi,el,.012)
        for x in (-.2,.2):sphere('Rivet marteau',(x,-.48,-.66),(.06,.04,.06),rivet,el)
    debris=[]
    for j in range(16):
        a=j*2.39996;r=.5+(j%5)*.32
        debris.append((box('Debris',(math.cos(a)*r,math.sin(a)*r-.2,.07),(.3+.1*(j%3),.2+.07*(j%4),.1),rust2 if j%2 else iron,root,.02),a))
    rest={o:(o.location.copy(),o.rotation_euler.copy(),o.scale.copy()) for o in root.children_recursive}
    def set_arcs(seed,amp):
        r=random.Random(seed)
        for k,a in enumerate(arcs):
            ang=r.random()*math.tau;L=.22+.28*r.random()
            pts=[(0,0,1.84)]
            for i in range(1,5):
                f=i/4;pts.append((math.cos(ang)*L*f+r.uniform(-.08,.08),math.sin(ang)*L*f+r.uniform(-.08,.08),1.84+r.uniform(-.3,.35)*f))
            for bp,pt in zip(a.data.splines[0].bezier_points,pts):bp.co=pt
            a.hide_render=amp<.05 or k>=2+int(amp*3.01)
    def state(p):
        q=clamp(p-1);r=clamp(p-2)
        for c,side in collectors:
            c.rotation_euler.y=side*(-1.05+.94*q);c.location.z=1.25+.16*q
        for plate,side in plates:
            plate.rotation_euler.y=side*.68*r;plate.rotation_euler.z=side*.28*r;plate.location.x=side*(.86+.12*r)
        set_emit(rivet,.30*q);set_emit(bolt,1.2+.6*q);set_emit(eyes,1.0+.4*q+.4*r);set_emit(ember,1.0)
        hinge.rotation_euler.z=math.radians(-140)*r;hinge.location.x=-.5-.02*r
        for o in root.children_recursive:
            if o.name.startswith(O):o.hide_render=r<.02
            if o.name.startswith(O+'fissure'):o.hide_render=r<.45
    def pose(t,anim='idle_p1'):
        count=SPECS[anim][0]
        for o,(l,rr,sc) in rest.items():o.location=l;o.rotation_euler=rr;o.scale=sc;o.hide_render=False
        for dd,a in debris:dd.hide_render=True
        u=t*count/max(1,count-1);i=round(t*count)%count
        p={'trans_p2':1+u,'trans_p3':2+u}.get(anim,SPECS[anim][2])
        state(p);r=clamp(p-2);w=math.sin(math.tau*t)
        torso.location.z+=.04*w;bell.rotation_euler.z=.07*w;bell.rotation_euler.x=.03*math.cos(math.tau*t)
        for k,a in enumerate(arms):a.rotation_euler.x=.07*w*(-1 if k else 1);elbows[k].rotation_euler.x=.05*w
        set_arcs(int(t*count)+7+SPECS[anim][2]*13,clamp(p-1))
        for ob,vx,vy,vz,ph in puffs:
            s=(t+ph)%1.0;vis=r if r>.4 else 0
            ob.location=(vx+.12*math.sin(s*5+ph*9),vy-.05-.1*s,vz+s*1.2)
            k=(.06+.14*s)*(1 if s<.7 else (1-s)/.3)*vis
            ob.scale=(max(k,.001),)*3
            if k<=.01 or not ob.name.startswith(O):ob.hide_render=True
        if anim.startswith('walk'):
            c=math.tau*t
            torso.location.z+=.07*abs(math.cos(c));torso.rotation_euler.y=.05*math.sin(c);bell.rotation_euler.y=-.08*math.sin(c)
            for k,leg in enumerate(legs):
                s=-1 if k else 1;leg.rotation_euler.x=.5*math.sin(c)*s;leg.location.z+=.12*max(0,math.cos(c)*(-s))
            for k,a in enumerate(arms):a.rotation_euler.x=-.35*math.sin(c)*(-1 if k else 1);elbows[k].rotation_euler.x=-.2*max(0,math.sin(c)*(1 if k else -1))
        if anim=='auto':
            arm=arms[1];el=elbows[1]
            arm.rotation_euler.x=[0,1.0,1.9,-.7,-.9,-.2][i];el.rotation_euler.x=[0,-.3,-.7,.3,.5,0][i]
            arm.rotation_euler.z=[0,.2,.3,-.1,-.1,0][i]
            torso.rotation_euler.x=[0,-.1,-.2,.28,.15,0][i];torso.location.z+=[0,.0,.1,-.12,-.08,0][i]
            bell.rotation_euler.x+=[0,-.1,-.15,.22,.1,0][i]
            for k,leg in enumerate(legs):leg.rotation_euler.x=[0,0,0,.12,.06,0][i]*(1 if k else -1)
        if anim=='spell_a':
            torso.location.z+=[0,.05,.12,.2,-.2,-.1,-.03,0][i]
            torso.rotation_euler.x=[0,-.1,-.15,-.2,.25,.1,0,0][i]
            for k,a in enumerate(arms):
                a.rotation_euler.x=[0,.8,1.5,1.9,-.4,0,.1,0][i];a.rotation_euler.z=(-1 if k==0 else 1)*[0,.1,.3,.4,.1,0,0,0][i]
            sg=(-1)**i
            bell.rotation_euler.z+=[0,0,.05,.08,.35,.28,.2,.1][i]*sg;bell.rotation_euler.x+=[0,-.1,-.2,-.3,.3,.15,.1,0][i]
            e=[0,0,0,.03,.12,.09,.05,.02][i]*sg;bell.scale=(1+e,1+e,1-e*.7)
            for leg in legs:leg.location.z-=[0,.03,.06,.06,0,0,0,0][i]
        if anim=='spell_b':
            for k,a in enumerate(arms):
                j=min(7,max(0,i-k));a.rotation_euler.x=[0,1.0,1.7,2.0,.6,-.4,-.2,0][j];elbows[k].rotation_euler.x=[0,-.3,-.7,-.9,.2,.4,.2,0][j]
            torso.rotation_euler.x=[0,-.1,-.2,-.25,.1,.2,.1,0][i];bell.rotation_euler.x+=[0,-.1,-.2,-.25,.1,.2,.1,0][i]
            torso.location.z+=[0,.03,.08,.1,-.1,-.05,0,0][i]
        if anim=='bell_ring':
            amp=[.0,.16,.12,.08,.05,.02][i];s=(-1)**i
            bell.rotation_euler.z+=amp*s*1.6;bell.rotation_euler.x+=-amp*.6*s
            bell.scale=(1+amp*.35*s,1-amp*.35*s,1+amp*.1);torso.location.z+=amp*.12*s
        if anim.startswith('trans'):
            sh=math.sin(math.pi*u);s=(-1)**i
            torso.rotation_euler.x=-.18*sh if anim=='trans_p2' else .2*sh
            torso.location.z+=.08*sh;bell.rotation_euler.z+=.2*sh*s
            if anim=='trans_p2':bell.rotation_euler.x+=-.25*sh
            for k,a in enumerate(arms):a.rotation_euler.x=1.0*sh;a.rotation_euler.z=(-1 if k==0 else 1)*.5*sh
        if anim=='death':
            f=clamp((u-.08)/.92);ease=f*f*(3-2*f)
            torso.location.z-=.32*ease;torso.location.y-=.05*ease;torso.rotation_euler.x=.42*ease;torso.rotation_euler.y=.12*ease
            bell.location+=Vector((.4*ease,-.4*ease,-1.3*ease));bell.rotation_euler.y=1.0*ease;bell.rotation_euler.z=.4*ease;bell.rotation_euler.x=.35*ease
            for k,a in enumerate(arms):
                a.rotation_euler.x=-.7*ease;a.rotation_euler.z=(-1 if k==0 else 1)*.6*ease;elbows[k].rotation_euler.x=.5*ease
            for k,leg in enumerate(legs):leg.rotation_euler.x=(-1 if k==0 else 1)*.45*ease;leg.rotation_euler.z=(-1 if k==0 else 1)*.2*ease;leg.scale.z=1-.22*ease
            rub=clamp((u-.25)/.6)
            for dd,a in debris:dd.hide_render=rub<=.02;dd.scale=(max(rub,.001),)*3
            set_arcs(int(t*10)+3,clamp(1-ease*1.4))
        if anim=='boiler_open':
            for o in root.children_recursive:
                if o.type in ('MESH','CURVE'):o.hide_render=not o.name.startswith(O)
    return root,pose

def prop(anim):
    root=empty('VFX_ROOT');n=SPECS[anim][0]
    def clear(prefixes=None):
        for o in list(root.children):
            if prefixes is None or o.name.startswith(prefixes):bpy.data.objects.remove(o,do_unlink=True)
    if anim=='lightning':
        core=emissive('Eclair coeur','FFFFFF',1.0);glow=emissive('Eclair halo','9CC4FF',1.0)
        def pose(t):
            v=int(round(t*n))%n;r=random.Random(100+v*17);clear()
            def path(x0,z0,x1,z1,jit,steps):
                return [(x0+(x1-x0)*k/steps+(r.uniform(-jit,jit) if 0<k<steps else 0),0,z0+(z1-z0)*k/steps) for k in range(steps+1)]
            main=path(0,11.8,r.uniform(-.2,.2),.25,.42,16);paths=[(main,.05,.13)]
            for b in range(3):
                k=r.randint(3,12);x,_,z=main[k];dd=r.choice((-1,1))
                paths.append((path(x,z,x+dd*r.uniform(.35,.8),z-r.uniform(1.5,3.2),.18,5),.028,.07))
            for pts,rc,rg in paths:
                tube('Eclair halo',pts,rg,glow,root);tube('Eclair coeur',pts,rc,core,root)
            sphere('Impact eclair',(main[-1][0],0,.25),(.4,.1,.2),core,root)
        return root,pose
    if anim=='bolt':
        iron=mat('Boulon fer','4A4640',.7,.35);hot=emissive('Boulon braise','FF9A3C',1.0)
        lathe('Tete boulon',[(0,.0),(.17,.0),(.2,.05),(.2,.14),(.15,.18),(0,.18)],iron,root,6)
        rod('Tige boulon',(0,0,0),(0,0,-.5),.085,iron,root)
        for z in (-.14,-.26,-.38):ring('Filet boulon',(0,0,z),.09,.02,iron,root,rotation=(0,0,0))
        sphere('Pointe chaude',(0,0,-.5),(.07,.07,.05),hot,root)
        root.location=(0,0,.15)
        def pose(t):root.rotation_euler=(math.tau*t,0,.5)
        return root,pose
    if anim=='steam_vent':
        m=material('Vapeur chaude',linear('E8EDEA'),0,.9,.18);hot=material('Vapeur braise',linear('FFB070'),0,.8,.7)
        parts=[(sphere('Volute',(0,0,0),(.1,.1,.1),hot if j<2 else m,root),j/16) for j in range(16)]
        def pose(t):
            for k,(o,ph) in enumerate(parts):
                s=(t+ph)%1.0;o.location=(.12*math.sin(s*7+k*2.1)*(.4+s),-.1*(k%3),.15+s*5.5)
                sz=(.1+.34*s)*(1 if s<.82 else (1-s)/.18);o.scale=(max(sz,.002),)*3
        return root,pose
    if anim=='ground_steam':
        m=material('Vapeur sol',linear('E0E8E4'),0,.9,.2)
        parts=[(sphere('Volute sol',(0,0,0),(.1,.1,.1),m,root),j/20) for j in range(20)]
        def pose(t):
            for k,(o,ph) in enumerate(parts):
                s=(t+ph)%1.0;o.location=(.07*math.sin(s*9+k*1.7)*(.3+s),-2.6+s*5.2,.12+.25*s)
                sz=max((.11+.28*s)*(1 if s<.85 else (1-s)/.15),.002);o.scale=(sz,sz*1.1,sz*.55)
        return root,pose
    if anim=='ground_lightning':
        scorch=mat('Sol calcine','120D0B',0,.9);ring_m=emissive('Anneau impact','CFE8FF',1.0);core=emissive('Impact coeur','FFFFFF',1.0)
        sphere('Brulure impact',(0,0,0),(.9,.9,.03),scorch,root)
        def pose(t):
            clear(('Arc sol','Anneau'))
            i=round(t*n)%n;fade=[1,.9,.7,.5,.3,.18][i];set_emit(ring_m,fade);set_emit(core,fade)
            r=random.Random(40+i*11)
            for k in range(9):
                a=k*math.tau/9+r.uniform(-.2,.2);L=.45+.4*r.random();pts=[(0,0,.05)]
                for s in range(1,5):
                    f=s/4;pts.append((math.cos(a)*L*f+r.uniform(-.05,.05),math.sin(a)*L*f+r.uniform(-.05,.05),.05))
                tube('Arc sol',pts,.028*(1.2-i*.1),ring_m,root)
            ring('Anneau impact',(0,0,.05),.68+.04*i,.03,ring_m,root,rotation=(0,0,0))
            sphere('Arc sol coeur',(0,0,.05),(.17*fade+.03,.17*fade+.03,.04),core,root)
        return root,pose
    if anim=='ground_scorch':
        scorch=mat('Brulure','0E0A08',0,.95);ash=mat('Cendre','2C2622',0,.95);glow=emissive('Braise sol','FF7A2A',1.0)
        def pose(t):
            clear();v=round(t*n)%n;r=random.Random(900+v*31)
            for j in range(5):
                a=r.random()*math.tau;d=r.uniform(.1,.55);sphere('Cendre',(math.cos(a)*d,math.sin(a)*d,.01),(r.uniform(.4,.65),r.uniform(.35,.6),.02),ash,root)
            for j in range(7):
                a=r.random()*math.tau;d=r.uniform(0,.45);sphere('Brulure',(math.cos(a)*d,math.sin(a)*d,.03),(r.uniform(.3,.55),r.uniform(.28,.5),.02),scorch,root)
            for j in range(4):
                a=r.random()*math.tau;pts=[(math.cos(a)*s*.2+r.uniform(-.05,.05),math.sin(a)*s*.2+r.uniform(-.05,.05),.06) for s in range(1,5)]
                tube('Braise fissure',pts,.012,glow,root)
        return root,pose

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--anims',nargs='*');ap.add_argument('--preview',action='store_true');args=ap.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for anim in args.anims or SPECS:
        count,dirs,phase,(fw,fh)=SPECS[anim]
        S=BOSS_SCALE if phase else 1.0
        s=setup_scene(S);s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
        s.render.resolution_x=fw*2;s.render.resolution_y=fh*2
        cam=s.camera;rot=cam.rotation_euler.to_matrix()
        if phase:cam.location+=rot@Vector((0,S*.03,0))
        else:
            cam.location-=rot@Vector((0,S*.12,0))
            if anim in ('lightning','steam_vent'):
                cam.rotation_euler=(math.pi/2,0,0);cam.location=(0,-20,6 if anim=='lightning' else 3);cam.data.ortho_scale=12 if anim=='lightning' else 6
            elif anim in ('ground_steam','ground_lightning','ground_scorch'):
                cam.rotation_euler=(0,0,0);cam.location=(0,0,10);cam.data.ortho_scale=6 if anim=='ground_steam' else 2.4
            elif anim=='bolt':cam.data.ortho_scale=1.15
        root,pose=build() if phase else prop(anim)
        fn=(lambda t,a=anim:pose(t,a)) if phase else pose
        if anim=='idle_p1':
            fn(0);bpy.context.scene['rebuild']='sonneur.py --background; --anims choisit les animations; poses deterministes'
            bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/bosses/sonneur.blend'))
        if args.preview:render_still(root,fn,OUT/'_preview'/f'{anim}.png',0,'s')
        else:
            for d in dirs:
                for f in range(count):render_still(root,fn,OUT/anim/f'{d}_{f:02}.png',f/count,d)
if __name__=='__main__':main()
