"""Une variante = même médaillon, même accent que son personnage, emblème dérivé
du sort de base (même famille de forme, transformé). Fichier <id variante>.png
ou <id perso>_<id variante>.png, trouvé automatiquement par ArdentKit.spell_icon,
aucun code à changer. Blender --background uniquement; --only a,b; --resume.

Le socle PBR Nova est protégé de la remontée des ombres du cel : le gabarit prime.
Les emblèmes reçoivent les matériaux et l'encre du profil icon, sans fichiers annexes.
"""
import sys, math, random, argparse, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
BASE = Path(__file__).resolve().parent
WORK = ROOT/'art/blender/cel/icons_norm'
sys.dont_write_bytecode = True
sys.path[:0] = [str(BASE), str(ROOT/'art/tools/ui'), str(ROOT/'art/tools/cel')]
import i3_build as nova
import i2_build as kit
import cel_style as cel
from ui_kit import *
from mathutils import Vector, Matrix

def medallion():
    """Exact branche ronde de backing() de Nova, sans copie de sa géométrie."""
    nova.materials()
    nova.backing('nova_ardente')
    for m in (nova.iron, nova.bronze, nova.coal):
        m['cel_done'] = True
    return meshes()

def palette(accent):
    global glow, heart, dark, metal, wood, pale
    rgb = [int(accent[i:i+2],16) for i in (1,3,5)]
    light = '#'+''.join(f'{round(v*.58+255*.42):02X}' for v in rgb)
    glow = mat(accent,.7,0,accent,2.25)
    heart = mat(light,.7,0,light,2.70)
    dark = mat('#26302F',.85)
    metal = mat('#6F7E78',.55,.6)
    wood = mat('#342C23',.85)
    pale = mat('#E8E2D6',.8,0,'#E8E2D6',.72)

def line(points,r=.027,m=None,y=-.29):
    return curve([(x,y,z) for x,z in points],r,m or glow)

def plate(points,m=None,y=-.26,d=.085,b=.018):
    return slab(points,m or glow,d,y,b,name='emblem carved relief')

def dot(x,z,r=.06,m=None,y=-.29):
    return sphere((x,y,z),(r,r*.65,r),m or glow)

def arc(cx,cz,r,a,b,m=None,w=.025,n=40,sy=1,y=-.28):
    return line([(cx+r*math.cos(t),cz+sy*r*math.sin(t)) for t in [a+(b-a)*j/n for j in range(n+1)]],w,m,y)

def crescent(r=.65,a=-1.5,b=1.6,thick=.21,rot=0):
    points=[]
    for j in range(41):
        t=a+(b-a)*j/40;points.append((r*math.cos(t+rot),r*math.sin(t+rot)))
    for j in range(40,-1,-1):
        t=a+(b-a)*j/40;rr=r-thick*math.sin(math.pi*j/40)
        points.append((rr*math.cos(t+rot),rr*math.sin(t+rot)))
    plate(points)
    arc(0,0,r-.025,a+rot+.1,b+rot-.1,heart,.012)

def arrow(p,q,width=.105,m=None,feathers=False):
    v=Vector((q[0]-p[0],q[1]-p[1]));v.normalize();n=Vector((-v.y,v.x));p=Vector(p);q=Vector(q)
    def xy(v):return tuple(v)
    line([xy(p),xy(q-v*width)],width*.20,m)
    plate([xy(q),xy(q-v*width*2+n*width),xy(q-v*width*1.55),xy(q-v*width*2-n*width)],m)
    if feathers:
        for sign in (-1,1):
            plate([xy(p-v*.04),xy(p+v*.18),xy(p+v*.08+n*.09*sign),xy(p-v*.09+n*.09*sign)],m)

def knife(angle=0,x=0,z=0,k=1,branch=False):
    def build():
        plate([(-.06,-.24),(-.09,.23),(-.035,.61),(.065,.40),(.055,-.24)],metal if branch else glow)
        line([(.045,-.19),(.04,.35),(-.035,.59)],.016,heart)
        line([(-.12,-.26),(.13,-.26)],.028,wood if branch else dark)
        line([(0,-.27),(0,-.47)],.047,wood if branch else metal)
        if branch:line([(-.04,-.07),(-.02,.11),(-.07,.28)],.017,wood)
    return kit.group(build,(x,0,z),k,(0,angle,0))

def chain(points,closed=False):
    # Copper round links; no clock marks, no bezel.
    for i,(x,z) in enumerate(points):
        arc(x,z,.084,0,math.tau,glow,.024,22,sy=.66 if i%2 else 1)
        arc(x,z,.067,.2,2.4,heart,.009,12,sy=.66 if i%2 else 1,y=-.32)

def coin(x,z,r=.17):
    o=kit.disk(x,z,r,glow,-.28,.07)
    arc(x,z,r*.72,0,math.tau,heart,.012,28,y=-.335)
    line([(x-.035,z+.06),(x+.025,z+.06),(x-.025,z-.06),(x+.035,z-.06)],.018,heart,-.35)
    return o

def blob(x,z,r=.25,m=None,seed=1):
    rng=random.Random(seed)
    p=[]
    for i in range(18):
        a=i*math.tau/18;rr=r*rng.uniform(.80,1.12);p.append((x+rr*math.cos(a),z+rr*.80*math.sin(a)))
    plate(p,m)
    arc(x-.02,z+.015,r*.63,.4,2.7,heart,.016,15,sy=.6,y=-.33)

def ardent(name):
    # Reuse the original sculpted fire, excluding its per-name backing and camera.
    old=nova.backing;nova.backing=lambda _:None
    try:
        if name=='cendres':
            for i in range(20):
                t=i*.50;r=.08+i*.023
                nova.shard(r*math.cos(t),r*.75*math.sin(t),.16+i*.006,t,-.24)
            line([((.08+j*.007)*math.cos(j*.15),(.08+j*.007)*math.sin(j*.15)*.75) for j in range(64)],.018,nova.ember)
            nova.sparks([(-.35,.23,.018),(.22,.36,.014),(.44,-.18,.018)])
        elif name=='brasier':
            for i in range(13):
                a=i*math.tau/13
                nova.tongue(.36*math.sin(a),.36*math.cos(a),.30,.10,.045,-.25,a)
            for x,z in [(-.17,-.21),(0,-.26),(.17,-.18)]:nova.tongue(x,z,.65,.12,.035,-.31)
        elif name=='braises_errantes':
            nova.build(name)
            for i in range(18):
                a=i*math.tau/18;arc(0,0,.58,a,a+.075,nova.ember,.014,5)
        else:nova.build(name)
    finally:nova.backing=old
    for m in (nova.fire,nova.core,nova.ember):
        m['rainfall_emissive']=True
        m['cel_done']=False
        m.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=2.25 if m==nova.fire else 2.70
    # The reference fire's charcoal veins remain neutral dark in the cel emblem.

def rictus(kind):
    if kind=='dagues_demi_lune':
        crescent(.64,-1.30,1.65,.25,-.60)
        knife(-1.05,-.25,-.12,.67)
    elif kind=='eventail':
        for i in range(5):knife((i-2)*.40,0,-.22,.88)
        dot(0,-.48,.09,metal)
    elif kind=='toupie':
        plate([(-.37,.15),(-.22,-.12),(0,-.43),(.22,-.12),(.37,.15)],glow)
        arc(0,.15,.37,0,math.tau,heart,.026,sy=.32,y=-.34)
        line([(0,.14),(0,.45)],.05,metal)
        arc(0,-.02,.61,.1,4.8,glow,.023,sy=.70)
        arrow((-.49,-.23),(-.41,-.43),.08)
    else:
        for i in range(6):
            a=math.tau*i/6;x=.45*math.cos(a);z=.45*math.sin(a)
            plate([(x-.12,z+.13),(x+.12,z+.13),(x+.105,z-.04),(x,z-.16),(x-.105,z-.04)])
            for dx in (-.045,.045):line([(x+dx-.017,z+.035),(x+dx+.017,z+.035)],.014,dark,-.33)
            arc(x,z-.025,.044,3.3,6.0,dark,.012,10,sy=.65,y=-.33)

def tocsin(kind):
    if kind=='rivets_rougis':
        for x,z in [(-.38,.29),(.35,.32),(.02,-.35)]:
            plate([(x-.10,z-.06),(x+.07,z-.06),(x+.12,z+.08),(x-.13,z+.08)],metal)
            dot(x,z+.07,.12);dot(x-.025,z+.10,.043,heart,-.38)
            line([(x-.18,z-.14),(x-.27,z-.27)],.027)
    elif kind=='bras_grappins':
        chain([(-.45+i*.13,.41-i*.10) for i in range(5)])
        line([(.12,-.03),(.32,-.10),(.39,-.28),(.29,-.47),(.05,-.48),(-.07,-.33)],.065,metal)
        arrow((-.07,-.33),(-.04,-.12),.12)
        line([(.30,-.14),(.33,-.28),(.24,-.38),(.09,-.39)],.025)
    elif kind=='coups_de_botte':
        plate([(-.23,.47),(.20,.47),(.20,.03),(.35,-.22),(.34,-.39),(-.36,-.39),(-.36,-.20),(-.20,.03)],metal)
        plate([(-.25,-.13),(.22,-.13),(.31,-.28),(-.29,-.28)])
        for z in (.12,.26,.40):line([(-.12,z),(.12,z)],.022)
        arc(0,-.30,.57,3.35,6.10,glow,.028,sy=.46)
        arc(0,-.32,.42,3.45,6.0,heart,.016,sy=.42)
    else:
        plate([(-.36,-.26),(-.23,-.04),(-.20,.31),(-.10,.45),(.12,.45),(.23,.29),(.25,-.03),(.38,-.26)],metal)
        line([(-.39,-.27),(.39,-.27)],.048)
        line([(.08,.35),(-.04,.15),(.07,.06),(-.09,-.18)],.039)
        dot(0,-.36,.073,heart)
        arc(0,.44,.11,0,math.pi,glow,.025)

def water(kind):
    if kind=='goutte_lame':
        plate([(0,.64),(-.12,.24),(-.30,-.15),(-.27,-.38),(-.08,-.53),(.15,-.49),(.29,-.30),(.23,-.07)])
        line([(-.09,-.40),(.08,-.24),(.02,.26)],.027,heart,-.33)
    elif kind=='vague':
        for i in range(3):
            z=-.43+i*.31;w=.56-i*.12
            plate([(-w,z),(w,z),(w-.09,z+.16),(w-.17,z+.22),(w-.30,z+.15),(w-.23,z+.05),(-w*.50,z+.09)])
            line([(-w*.78,z+.045),(w-.23,z+.075),(w-.18,z+.17)],.017,heart,-.34)
    elif kind=='flaque_miroir':
        o=kit.disk(0,-.10,.61,glow,-.27,.065);o.scale=(1,.49,1)
        arc(0,-.10,.48,0,math.tau,heart,.018,sy=.43,y=-.325)
        line([(-.33,-.08),(-.04,.01),(.28,.01)],.029,heart,-.33)
        line([(-.15,-.21),(.22,-.16)],.018,heart,-.33)
        dot(.18,.43,.06);line([(.18,.37),(.18,.25)],.025)
    else:
        # Broad open curling breaker with a hollow eye.
        pts=[]
        for j in range(70):
            a=-1.8+j*6.8/69;r=.62-j*.0058;pts.append((r*math.cos(a),r*math.sin(a)))
        line(pts,.095)
        line([(x*.98,z*.98+.03) for x,z in pts[8:]],.025,heart,-.39)
        for x,z in [(-.34,.49),(-.47,.35),(-.55,.18)]:dot(x,z,.032,heart)

def arpenteuse(kind):
    if kind=='chaine':
        arc(-.30,-.28,.24,0,math.tau,metal,.060)
        arc(-.30,-.28,.12,0,math.tau,glow,.042)
        chain([(-.11+i*.10,-.12+i*.105) for i in range(7)])
        line([(-.48,-.49),(-.10,-.49)],.037,wood)
    elif kind=='boucle':
        chain([(.48*math.cos(i*math.tau/15),.48*math.sin(i*math.tau/15)) for i in range(15)],True)
    elif kind=='piquet':
        plate([(-.41,.47),(-.16,.47),(-.19,.22),(-.23,-.43),(-.33,-.58),(-.36,.20)],metal)
        line([(-.43,.43),(-.14,.43)],.042)
        chain([(-.17+i*.13,.19-i*.06) for i in range(6)])
        line([(-.50,-.49),(-.12,-.49)],.024)
    else:
        chain([(-.48,.43),(-.35,.30),(-.22,.17),(-.07,.12),(.09,.12),(.23,.02),(.18,-.12),(.03,-.25),(-.09,-.39)])
        for a in (-.3,.35,.9):line([(.40,.0),(.40+.13*math.cos(a),.13*math.sin(a))],.023,heart)

def rainette(kind):
    if kind=='langue':
        line([(-.57,-.21),(-.34,-.14),(-.08,-.07),(.22,.01)],.071)
        arc(.33,.12,.18,-1.25,4.9,glow,.055,sy=.90)
        line([(-.53,-.19),(-.15,-.08)],.017,heart,-.38)
    elif kind=='grand_saut':
        arc(-.02,-.23,.55,.20,2.95,glow,.045,sy=1.17)
        arrow((.43,.02),(.50,-.22),.11)
        for i in range(5):
            a=math.pi+(i+1)*math.pi/6
            line([(.25+.12*math.cos(a),-.34+.09*math.sin(a)),(.25+.31*math.cos(a),-.34+.25*math.sin(a))],.028,heart)
        line([(-.52,-.35),(-.31,-.35)],.035)
    elif kind=='gluant':
        blob(.0,-.25,.43,seed=43)
        dot(-.20,.28,.09);dot(.20,.42,.065);dot(.37,.12,.05)
        line([(-.20,.20),(-.14,.02)],.038)
    else:
        dot(0,-.04,.30,metal)
        arc(0,-.04,.29,0,math.tau,glow,.048)
        arc(0,-.04,.42,-1.2,1.2,glow,.022)
        arc(0,-.04,.58,-1.05,1.05,glow,.023)
        arc(0,-.04,.42,1.95,4.35,glow,.022)
        arc(0,-.04,.58,2.10,4.20,glow,.023)
        for x in (-.12,.12):dot(x,.30,.073);dot(x,.31,.025,dark,-.36)
        arc(-.04,.0,.17,.5,2.2,heart,.030,y=-.50)

def chest(x=0,z=0,k=1,broken=False):
    def build():
        plate([(-.30,-.26),(.30,-.26),(.30,.24),(-.30,.24)],wood)
        for xx in (-.25,.25):line([(xx,-.22),(xx,.20)],.043)
        line([(-.30,.02),(.30,.02)],.025)
        plate([(-.07,.07),(.07,.07),(.07,-.09),(-.07,-.09)],metal,-.34)
        dot(0,-.01,.027,heart,-.42)
        if broken:
            plate([(-.30,.29),(-.39,.43),(.10,.49),(.19,.33)],metal)
            line([(-.03,.25),(-.11,.13),(.02,.05),(-.07,-.12)],.035,dark,-.37)
        else:line([(-.30,.24),(.30,.24)],.038)
    kit.group(build,(x,0,z),k)

def avare(kind):
    if kind=='coup_de_coffre':
        arc(-.08,.0,.51,.4,3.05,glow,.025)
        chain([(-.50,.12),(-.44,-.02),(-.34,-.15),(-.20,-.23)])
        chest(.16,-.16,.90)
    elif kind=='poignee_de_pieces':
        for i in range(5):
            a=.25+i*.65;coin(.43*math.cos(a),.43*math.sin(a)-.13,.17)
        line([(-.17,-.39),(.21,-.39)],.031,metal)
    elif kind=='rancon':
        coin(0,.16,.31)
        for r in (.32,.52):arc(0,-.32,r,0,math.tau,glow,.024,sy=.28)
        line([(0,-.18),(0,-.29)],.023,heart)
    else:
        chest(0,-.23,1,True)
        for x,z in [(-.44,.22),(-.17,.49),(.24,.48),(.48,.12)]:
            coin(x,z,.105);line([(x*.67,z*.60),(x*.83,z*.80)],.022,heart)

def bourbe(kind):
    if kind=='gifle_de_vase':
        plate([(-.45,-.34),(-.21,-.46),(.08,-.20),(.31,-.04),(.46,.15),(.42,.25),(.21,.12),(.40,.38),(.35,.46),(.10,.22),(.21,.50),(.12,.55),(-.05,.24),(-.09,.49),(-.18,.49),(-.20,.14),(-.35,.23),(-.44,.15),(-.22,-.08)])
        arc(-.04,-.06,.60,2.1,4.2,heart,.022)
    elif kind=='detacher':
        blob(.08,.22,.34,seed=5)
        blob(-.22,-.37,.21,metal,7)
        for x,z in [(-.13,-.13),(.25,-.24),(.41,.0)]:dot(x,z,.045)
        arrow((-.46,-.19),(-.43,.22),.095)
    elif kind=='rappel':
        blob(0,0,.17,seed=8)
        for i in range(3):
            a=i*math.tau/3+.4;x=.51*math.cos(a);z=.51*math.sin(a)
            blob(x,z,.13,seed=i)
            arc(0,0,.38,a+.2,a+.85,glow,.027,15)
            arrow((.33*math.cos(a+.75),.33*math.sin(a+.75)),(.20*math.cos(a+.65),.20*math.sin(a+.65)),.075)
    else:
        pts=[]
        for j in range(90):
            a=j*.13;r=.62-j*.0058;pts.append((r*math.cos(a),r*.70*math.sin(a)))
        line(pts,.065)
        line([(x,z+.025) for x,z in pts[4:]],.016,heart,-.38)
        for x,z in [(-.44,.29),(.32,.40),(.50,-.21)]:dot(x,z,.047,metal)

def vigie(kind):
    if kind=='trait':
        arrow((-.42,-.43),(.43,.45),.15,feathers=True)
        line([(-.48,.08),(-.30,.04),(-.10,-.11),(.04,-.30),(.08,-.48)],.032,metal)
        line([(-.48,.08),(-.42,-.43),(.08,-.48)],.012,heart)
    elif kind=='fusee':
        arrow((-.18,-.38),(.28,.41),.16,feathers=True)
        plate([(-.24,-.28),(-.07,-.38),(-.15,-.55),(-.19,-.44),(-.32,-.57),(-.30,-.38)],heart)
        for i in range(7):
            a=i*math.tau/7;line([(.28+.19*math.cos(a),.40+.19*math.sin(a)),(.28+.28*math.cos(a),.40+.28*math.sin(a))],.021)
    elif kind=='filet':
        arrow((-.44,-.31),(.31,.44),.13,feathers=True)
        # Diamond fishing mesh, heavy lead beads on the outer edge.
        for i in range(5):
            t=i/4
            line([(-.30+t*.50,-.47),(.18+t*.30,.02+t*.23)],.012)
            line([(-.30,-.47+t*.48),(.20+t*.28,-.47+t*.72)],.012)
        for x,z in [(-.30,-.47),(.20,-.47),(.48,.25),(-.30,.01)]:dot(x,z,.045,metal)
    else:
        for x,z,k in [(-.35,.02,.73),(0,-.16,.95),(.34,.12,.65)]:
            arrow((x+.11*k,z+.40*k),(x-.11*k,z-.36*k),.10*k,feathers=True)
            line([(x+.14*k,z+.50*k),(x+.17*k,z+.63*k)],.016,heart)

def morfil(kind):
    if kind=='taille_estoc':
        crescent(.57,-.65,2.55,.13,.55)
        knife(.85,0,-.05,1.05,True)
    elif kind=='fauche_lune':
        crescent(.65,-1.2,1.65,.30,2.75)
        line([(-.33,-.18),(.23,-.48)],.036,wood)
    elif kind=='aiguisage':
        plate([(-.43,-.35),(.13,-.41),(.33,-.19),(-.24,-.13)],metal)
        knife(.90,0,.03,.92,True)
        for a in (.10,.65,1.2):line([(.22,.10),(.22+.20*math.cos(a),.10+.20*math.sin(a))],.022,heart,-.38)
    else:
        knife(-.70,-.03,.03,1.05,True)
        knife(.70,.03,.03,1.05,True)
        for sign in (-1,1):line([(sign*.40,.28),(sign*.46,.38)],.020,heart)

def dodge():
    dot(.16,.31,.12,pale)
    line([(.06,.18),(-.19,.08),(-.26,-.12),(-.04,-.26),(.17,-.18)],.077,pale)
    line([(.02,.13),(.24,.09),(.32,-.08)],.048,pale)
    line([(-.06,-.24),(.08,-.39),(.31,-.36)],.054,pale)
    arc(0,0,.58,.5,4.9,glow,.035)
    arc(0,0,.48,1.15,4.35,pale,.019)

ICONS={
    **{n:('#FF7900',lambda n=n:ardent(n)) for n in ('eclat_de_braise','cendres','brasier','braises_errantes','pilier_de_flamme','pluie_de_meteores','phenix')},
    **{n:('#9FC8C0',lambda n=n:rictus(n)) for n in ('dagues_demi_lune','eventail','toupie','doublures')},
    **{'tocsin_'+n:('#FF7A1F',lambda n=n:tocsin(n)) for n in ('rivets_rougis','bras_grappins','coups_de_botte','tete_cloche')},
    **{'averse_'+n:('#5FD4E8',lambda n=n:water(n)) for n in ('goutte_lame','vague','flaque_miroir','crue')},
    **{'arpenteuse_'+n:('#FF7A1F',lambda n=n:arpenteuse(n)) for n in ('chaine','boucle','piquet','tendeur')},
    **{'rainette_'+n:('#8DBBA8',lambda n=n:rainette(n)) for n in ('langue','grand_saut','gluant','chant_de_crue')},
    **{'avare_'+n:('#F2C14E',lambda n=n:avare(n)) for n in ('coup_de_coffre','poignee_de_pieces','rancon','faillite')},
    **{'bourbe_'+n:('#8DDBA8',lambda n=n:bourbe(n)) for n in ('gifle_de_vase','detacher','rappel','bourbier')},
    **{'vigie_'+n:('#FF3A4F',lambda n=n:vigie(n)) for n in ('trait','fusee','filet','grele')},
    **{'morfil_'+n:('#CDEB6E',lambda n=n:morfil(n)) for n in ('taille_estoc','fauche_lune','aiguisage','lames_jumelles')},
    'dodge':('#F2C14E',dodge),
}

def normalize_emblem(objects):
    bpy.context.view_layer.update()
    points=[]
    for o in objects:
        ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
        if ev.type not in {'MESH','CURVE'}:continue
        me=ev.to_mesh()
        points.extend([o.matrix_world@v.co for v in me.vertices]);ev.to_mesh_clear()
    if not points:return
    # Preserve intentional internal gaps; centre the entire emblem and fit within r=.77.
    cx=(min(v.x for v in points)+max(v.x for v in points))/2
    cz=(min(v.z for v in points)+max(v.z for v in points))/2
    radius=max(math.hypot(v.x-cx,v.z-cz) for v in points)
    factor=min(1.12,.755/max(radius,.001))
    transform=Matrix.Diagonal((factor,1,factor,1))@Matrix.Translation((-cx,0,-cz))
    for o in objects:o.matrix_world=transform@o.matrix_world

def configure_cel(path):
    cel.install('icon',normals=False)
    cel.setup_scene(samples=16)
    cel.toon_materials('icon')
    # Same display transform and lighting as Nova; no cel shadow lift on the medallion.
    s=bpy.context.scene;s.view_settings.view_transform='AgX'
    s.view_settings.look='AgX - Medium High Contrast'
    def composite_base(_):
        tree=bpy.data.node_groups.new('Icon ink only','CompositorNodeTree')
        tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
        s.compositing_node_group=tree
        rl=tree.nodes.new('CompositorNodeRLayers');rl.scene=s
        out=tree.nodes.new('NodeGroupOutput');tree.links.new(rl.outputs['Image'],out.inputs['Image'])
    cel.cel_passes(path,'icon',base_configure=composite_base,normals=False)
    # Proof mask from the actual luminous-material AOV, independent of RGB brightness.
    tree=s.compositing_node_group
    rl=next(n for n in tree.nodes if n.bl_idname=='CompositorNodeRLayers')
    bw=tree.nodes.new('CompositorNodeRGBToBW');tree.links.new(rl.outputs[cel.AOV],bw.inputs[0])
    threshold=tree.nodes.new('ShaderNodeMath');threshold.operation='GREATER_THAN'
    threshold.inputs[1].default_value=.001;tree.links.new(bw.outputs[0],threshold.inputs[0])
    out=tree.nodes.new('CompositorNodeOutputFile')
    out.directory=str(WORK);out.file_name=Path(path).stem.replace('_raw','')+'_accent_mask__'
    out.file_output_items.new('RGBA','Image')
    out.format.media_type='IMAGE';out.format.file_format='PNG';out.format.color_mode='RGBA';out.format.color_depth='8'
    tree.links.new(threshold.outputs[0],out.inputs[0])

def scene(name,emblem=None,accent='#FF7900'):
    random.seed(331)
    s=kit.studio('icons_norm_'+name)
    backing=medallion()
    s.camera.location=(.12,-10,1.0);aim(s.camera,(0,0,0))
    frame_object_ortho(backing,.075)
    s.render.resolution_x=s.render.resolution_y=256
    if emblem:
        before=set(meshes());palette(accent);emblem()
        normalize_emblem(set(meshes())-before)
    s.render.filepath=str(WORK/(name+'_raw.png'))
    configure_cel(s.render.filepath)
    return s

def run():
    parser=argparse.ArgumentParser();parser.add_argument('--only');parser.add_argument('--resume',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    names=args.only.split(',') if args.only else list(ICONS)+['nova_ardente_cel']
    assert set(names)<=set(ICONS)|{'nova_ardente_cel'}
    cel.archive_folder('icons/spells')
    WORK.mkdir(parents=True,exist_ok=True)
    if not args.resume or not (WORK/'medallion_raw.png').exists():
        s=scene('medallion')
        bpy.context.preferences.filepaths.save_version=0
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui/icons_norm_template.blend'))
        bpy.ops.render.render(write_still=True)
    for name in names:
        dest=(WORK/'nova_ardente_cel.png') if name=='nova_ardente_cel' else ROOT/'game/assets/sprites/icons/spells'/f'{name}.png'
        if args.resume and (WORK/(name+'.done')).exists() and dest.exists():continue
        accent,emblem=('#FF7900',lambda:ardent('nova_ardente')) if name=='nova_ardente_cel' else ICONS[name]
        s=scene(name,emblem,accent)
        bpy.ops.render.render(write_still=True)
        subprocess.run([PY,str(BASE/'icons_norm_finish.py'),'fit',name],check=True,stdout=subprocess.DEVNULL)
        (WORK/(name+'.done')).touch()
        print('PASS '+name,flush=True)
        # Keep one working scene: modest memory, no accumulation of geometry or images.
        bpy.context.window.scene=bpy.data.scenes[0]
        bpy.data.scenes.remove(s)
        bpy.data.orphans_purge(do_recursive=True)

if __name__=='__main__':run()
