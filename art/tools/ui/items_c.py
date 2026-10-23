"""Items 35-50 + correction du sifflet. Blender background uniquement. -- id [id ...] pour un sous-ensemble."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_lib import *
from mathutils import Matrix, Euler
import items_a as a
import items_b as b
IDS=['chronometre_brise','tempete_de_braises','coeur_de_glace','peste_vivante','oeil_du_predateur','bouclier_reactif','faveur_du_marchand','danseur','phenix_de_poche','rafale_d_acier','coeur_du_chronomancien','couronne_d_echo','nova_infinie','armure_du_colosse','moisson','de_pipe']
FIX=['sifflet_de_chasse']
poly=b.poly; drop=b.drop

def group(build, loc=(0,0,0), scale=1, rot=(0,0,0), pivot=(0,0,0)):
    """Construit puis déplace/tourne/redimensionne les objets créés par build()."""
    before=set(bpy.context.scene.objects); build()
    new=set(bpy.context.scene.objects)-before; bpy.context.view_layer.update()
    P=Matrix.Translation(pivot)
    M=Matrix.Translation(loc)@P@Euler(rot).to_matrix().to_4x4()@Matrix.Scale(scale,4)@P.inverted()
    for o in new:o.matrix_world=M@o.matrix_world
    return new

def toward(o,v):
    o.rotation_euler=Vector(v).to_track_quat('Z','Y').to_euler()

def heart(m,depth=.45,name='Coeur'):
    ol=[(0,.47),(-.32,.8),(-.64,.73),(-.83,.44),(-.76,.1),(0,-.84),(.76,.1),(.83,.44),(.64,.73),(.32,.8)]
    verts=[(x,y,z) for y in [-depth/2,depth/2] for x,z in ol]
    faces=[tuple(reversed(range(10))),tuple(range(10,20))]+[(i,(i+1)%10,(i+1)%10+10,i+10) for i in range(10)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); o.data.materials.append(m)
    bb=o.modifiers.new('Arêtes','BEVEL'); bb.width=.14; bb.segments=3; o.modifiers.new('Normales','WEIGHTED_NORMAL')
    return o

def gear(x,z,r,teeth,m,y=0,depth=.18):
    a.disk((x,y,z),r,depth,m)
    for i in range(teeth):
        t=i*math.tau/teeth
        o=bevelled_box((x+(r+.05)*math.sin(t),y,z+(r+.05)*math.cos(t)),(.15*r+.06,depth,.22*r+.06),m,.02); o.rotation_euler[1]=t
    a.disk((x,y-depth/2-.02,z),r*.3,.05,a.dark)

def coin(x,z,r,rot=0,y=0):
    o=a.disk((x,y,z),r,.09,a.gold); o.rotation_euler[1]=rot
    t=torus((x,y-.05,z),r*.72,r*.07,a.ivory); t.rotation_euler[1]=rot

def chronometre_brise():
    a.disk((0,0,-.05),.92,.3,a.gold)
    torus((0,-.17,-.05),.9,.09,a.gold)
    a.disk((0,-.17,-.05),.72,.06,a.ivory)
    bevelled_box((0,0,.98),(.26,.22,.2),a.gold,.04); torus((0,0,1.22),.17,.06,a.gold)
    for i in range(12):
        t=i*math.tau/12
        o=bevelled_box((.6*math.sin(t),-.23,-.05+.6*math.cos(t)),(.05,.03,.12 if i%3==0 else .07),a.dark,.01); o.rotation_euler[1]=t
    gear(.34,-.38,.34,8,a.steel,-.26,.1)
    for p in [[(-.1,-.27,.62),(-.04,-.27,.3),(.12,-.27,.05),(.02,-.27,-.2)],[(-.12,-.27,.0),(-.45,-.27,-.18),(-.6,-.27,-.5)],[(.05,-.27,.02),(.5,-.27,.5),(.6,-.27,.3)]]:
        curve(p,.03,a.dark)
    curve([(-.05,-.28,-.05),(-.05,-.28,.4)],.05,a.dark); curve([(-.05,-.28,-.05),(.3,-.28,-.1)],.05,a.dark)

def tempete_de_braises():
    lathe([(0,-.9),(.48,-.88),(.85,-.55),(1.02,-.05),(.88,-.02),(0,-.1)],(0,0,-.2),a.dark,36)
    torus((0,0,-.24),.95,.07,a.steel).rotation_euler[0]=0
    for x in [-.55,.55]:bevelled_box((x,0,-1.0),(.2,.3,.18),a.steel,.03)
    cylinder((0,0,-.2),.88,.05,a.orange)
    pts=[]
    for i in range(40):
        t=i/39; ang=t*math.pi*5; r=.25+t*.8
        pts.append((r*math.sin(ang),r*math.cos(ang)*.45,-.1+1.55*t))
    curve(pts,.045,mat('#FFB347',.3,0,'#FFB347',1.0))
    for i in range(14):
        t=(i+.5)/14; ang=t*math.pi*5+.9; r=.3+t*.85; s=.2-.1*t
        sphere((r*math.sin(ang),r*math.cos(ang)*.45-.1,-.05+1.5*t),(s,s,s),a.orange if i%2 else a.gold)
    for x,z in [(-.95,.9),(.9,1.25),(.1,1.55)]:sphere((x,0,z),(.07,.07,.07),a.gold)

def coeur_de_glace():
    heart(mat('#8FD8F0',.12,.1,'#5FD4E8',.25))
    pale=mat('#D6F4FA',.1,.2)
    for x,z,h,r in [(-.62,-.2,.85,.14),(-.28,-.55,.7,.11),(.3,-.62,.8,.12),(.62,-.23,.9,.14)]:
        o=cone((x,-.04,z-h*.4),r,h,pale,6); o.rotation_euler[0]=math.pi
    for x,z,s in [(-.45,.62,.5),(.4,.7,.42)]:
        o=crystal((x,-.28,z),.1,s,pale); o.rotation_euler[1]=x*.5
    curve([(-.55,-.26,.55),(-.62,-.26,.25),(-.45,-.26,.05)],.04,a.light)
    curve([(.1,-.26,.3),(.0,-.26,-.1),(.15,-.26,-.4)],.03,a.light)

def peste_vivante():
    bone=mat('#D9CBA0',.5)
    sphere((0,0,.22),(.78,.62,.68),bone); bevelled_box((0,-.02,-.5),(.8,.5,.34),bone,.1)
    glow=mat('#9FD05B',.3,0,'#9FD05B',2.0)
    for x in [-.28,.28]:
        sphere((x,-.5,.2),(.2,.1,.22),a.dark); sphere((x,-.58,.2),(.09,.04,.1),glow)
    cone((0,-.56,-.1),.09,.24,a.dark,3).rotation_euler[0]=math.pi
    for x in [-.27,-.09,.09,.27]:bevelled_box((x,-.28,-.55),(.1,.06,.2),a.dark,.01)
    for x,z,r in [(-.82,.72,.4),(.9,.45,.34),(.5,1.0,.3),(-.35,1.05,.3),(-.9,.2,.22),(.9,-.15,.2)]:
        sphere((x,.05,z),(r,r*.7,r),a.green)
    for x,z,r in [(-.82,.8,.12),(.5,1.08,.1),(.9,.5,.1)]:sphere((x,-.2,z),(r,r*.6,r),mat('#C6E88A',.3,0,'#9FD05B',.6))
    drop(-.55,-.1,-.85,.12,.4,a.green); drop(.6,-.1,-.7,.09,.32,a.green)

def oeil_du_predateur():
    torus((0,0,0),.92,.15,a.gold)
    sphere((0,.03,0),(.84,.35,.84),mat('#F28A22',.25,0,'#FF7A1F',.5))
    torus((0,-.3,0),.45,.08,mat('#C23B12',.3,0,'#C23B12',.3))
    sphere((0,-.29,0),(.17,.07,.52),a.dark)
    sphere((-.26,-.34,.25),(.1,.04,.1),a.ivory)
    for i in range(8):
        t=i*math.tau/8+.2
        o=cone((1.05*math.sin(t),0,1.05*math.cos(t)),.12,.34,a.gold,4); toward(o,(math.sin(t),0,math.cos(t)))

def bouclier_reactif():
    hexa=lambda r:[(0,r),(.87*r,.5*r),(.87*r,-.5*r),(0,-r),(-.87*r,-.5*r),(-.87*r,.5*r)]
    poly(hexa(1.0),a.slate,.3)
    poly(hexa(.82),a.cyan,.08,-.17)
    poly(hexa(.58),mat('#2A8FB0',.3,.2,'#5FD4E8',.5),.05,-.23)
    for i in range(6):
        t=i*math.tau/6; sphere((.93*math.sin(t),-.16,.93*math.cos(t)),(.07,.05,.07),a.gold)
    for x in [-.28,.28]:
        g=crystal((x,-.32,.0),.17,.55,mat('#8A6AB0',.2,.2,'#8A6AB0',1.0)); g.rotation_euler[0]=-.2
        torus((x,-.28,0),.2,.04,a.gold)
    curve([(-.15,-.3,-.45),(0,-.3,-.62),(.15,-.3,-.45)],.045,a.light)

def faveur_du_marchand():
    lathe([(0,-.8),(.55,-.76),(.86,-.3),(.74,.2),(.4,.48),(.3,.62),(.5,.9)],(0,0,-.1),a.leather,32)
    torus((0,0,.45),.33,.075,a.gold).rotation_euler[0]=0
    curve([(.3,-.05,.45),(.5,-.12,.12),(.62,-.1,-.2)],.05,a.gold)
    wax=cylinder((0,-.74,-.25),.27,.1,a.red); wax.rotation_euler[0]=math.pi/2
    torus((0,-.8,-.25),.2,.04,a.gold)
    coin(-.2,.98,.34,.25,-.12); coin(.32,1.02,.3,-.3,-.05); coin(.02,1.28,.28,.1,-.2)
    coin(-.95,-.6,.26,.2,-.35); coin(1.0,-.62,.28,-.2,-.35); coin(.85,-.85,.24,.4,-.55)

def danseur():
    cuir=mat('#5E7390',.5,.15)
    bevelled_box((-.1,0,.25),(.62,.5,1.05),cuir,.16)
    bevelled_box((.22,-.08,-.5),(1.3,.6,.52),cuir,.2)
    bevelled_box((.25,-.09,-.83),(1.35,.64,.14),a.dark,.05)
    bevelled_box((-.38,-.09,-.78),(.3,.64,.34),a.dark,.05)
    bevelled_box((-.1,0,.82),(.74,.58,.14),a.gold,.04)
    bevelled_box((.22,-.3,-.35),(.5,.06,.12),a.gold,.02)
    for k,(ang,L,m) in enumerate([(.9,1.2,a.ivory),(1.25,1.05,a.light),(1.6,.88,a.ivory),(1.95,.7,a.light)]):
        base=(-.38,.32,.5+.1*k)
        tip=(base[0]-L*math.cos(ang*.6),0,base[2]+L*math.sin(ang*.9)*.9)
        mid=((base[0]+tip[0])/2,0,(base[2]+tip[2])/2)
        dx,dz=tip[0]-base[0],tip[2]-base[2]; n=math.hypot(dx,dz); px,pz=-dz/n*.17,dx/n*.17
        poly([(base[0],base[2]),(mid[0]+px,mid[2]+pz),(tip[0],tip[2]),(mid[0]-px,mid[2]-pz)],m,.08,.28-k*.02)
    curve([(-.4,.3,.3),(-.8,.25,.2)],.06,a.gold)

def phenix_de_poche():
    a.disk((0,.1,0),.98,.2,a.dark); torus((0,-.02,0),.95,.1,a.gold); torus((0,-.1,0),.75,.03,a.gold)
    fire=mat('#FF7A1F',.3,0,'#FF7A1F',1.0); gl=mat('#FFB347',.3,0,'#FFB347',1.0); core=mat('#FFE9A8',.3,0,'#FFE9A8',.8)
    for s in [-1,1]:
        poly([(s*.12,.12),(s*.5,.62),(s*.95,.58),(s*.8,.3),(s*.88,.1),(s*.7,-.08),(s*.35,-.1)],fire,.12,-.13)
        poly([(s*.15,.1),(s*.5,.45),(s*.72,.4),(s*.55,.15),(s*.6,.0)],gl,.06,-.2)
    sphere((0,-.18,-.04),(.26,.2,.4),gl); sphere((0,-.22,.0),(.16,.1,.28),core)
    sphere((.0,-.2,.46),(.17,.15,.17),gl)
    c=cone((.22,-.2,.47),.07,.22,a.gold,4); c.rotation_euler[1]=math.pi/2
    sphere((.07,-.33,.5),(.04,.02,.04),a.dark)
    for i,x in enumerate([-.22,0,.22]):
        poly([(x,-.2),(x+.14,-.55),(x,-.75),(x-.14,-.55)],fire if i!=1 else gl,.08,-.2)
    for x,z in [(-.12,.67),(0,.72),(.13,.64)]:
        poly([(x-.05,z-.1),(x,z+.1),(x+.05,z-.1)],fire,.05,-.2)

def rafale_d_acier():
    for ang in (-.5,0,.5):
        group(lambda:b.arrow(0,.3),rot=(0,ang,0),pivot=(0,0,-1.0))
    for x in [-.6,.6]:curve([(x*.9,.2,-.9),(x*.55,.2,-.4)],.04,a.cyan)

def coeur_du_chronomancien():
    gear(-.75,.75,.45,9,a.gold,.28); gear(.8,-.65,.5,10,a.steel,.28)
    torus((0,.25,0),1.12,.06,a.cyan)
    heart(mat('#F2C14E',.2,.5,'#F2C14E',.9),.5,'Coeur doré')
    crystal((-.3,-.3,.4),.12,.5,a.ivory).rotation_euler[1]=.4
    for x,z in [(-.6,.4),(.6,.4),(0,-.4)]:sphere((x,-.27,z),(.07,.05,.07),a.cyan)

def couronne_d_echo():
    def crown(m,gem):
        cylinder((0,0,0),.75,.4,m)
        cylinder((0,0,.19),.64,.06,a.dark)
        for i in range(5):
            t=i*math.tau/5
            cone((.68*math.sin(t),.68*math.cos(t),.55),.17,.6,m,4)
            sphere((.68*math.sin(t),.68*math.cos(t),.9),(.1,.1,.1),gem)
        for t in [-.5,0,.5]:
            sphere((.76*math.sin(t+math.pi),.76*math.cos(t+math.pi),0),(.09,.09,.09),gem)
    ghost=mat('#8FD8F0',.2,.1,'#5FD4E8',.6)
    ghost.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.55; ghost.surface_render_method='DITHERED'
    red=mat('#C23B12',.3,.2,'#C23B12',.4)
    tilt=(-math.radians(62),0,0)
    group(lambda:crown(ghost,ghost),loc=(-.75,.6,.5),scale=.8,rot=tilt)
    group(lambda:crown(ghost,ghost),loc=(.75,.6,.8),scale=.8,rot=tilt)
    group(lambda:crown(a.gold,red),loc=(0,-.1,-.4),scale=1,rot=tilt)

def nova_infinie():
    sphere((0,0,0),(.42,.42,.42),mat('#FFE9A8',.2,0,'#FFE9A8',3.0))
    sphere((0,0,0),(.62,.62,.62),mat('#FF7A1F',.3,0,'#FF7A1F',1.2))
    for rot,m,r in [((1.2,0,.55),mat('#FF7A1F',.2,.2,'#C23B12',1.2),1.0),((1.95,0,-.5),mat('#5FD4E8',.2,.2,'#5FD4E8',1.2),.9),((2.7,0,.2),mat('#7FA35B',.2,.2,'#9FD05B',1.2),.78)]:
        t=torus((0,0,0),r,.09,m); t.rotation_euler=rot
    for i in range(8):
        t=i*math.tau/8
        o=cone((1.18*math.sin(t),-.1,1.18*math.cos(t)),.09,.5 if i%2==0 else .3,a.gold,4); toward(o,(math.sin(t),0,math.cos(t)))

def armure_du_colosse():
    poly([(-.55,.82),(-.92,.48),(-.84,-.22),(-.58,-.72),(0,-.88),(.58,-.72),(.84,-.22),(.92,.48),(.55,.82),(.26,.68),(0,.62),(-.26,.68)],a.steel,.5)
    poly([(-.26,.68),(0,.62),(.26,.68),(.1,.9),(-.1,.9)],a.dark,.55,0)
    bevelled_box((0,-.27,.0),(.2,.1,1.3),a.light,.04)
    for z in [-.5,-.2]:bevelled_box((0,-.28,z),(1.4,.1,.12),a.gold,.03)
    for x in [-1,1]:
        sphere((x*.95,0,.58),(.5,.45,.38),a.slate); torus((x*.95,-.3,.58),.3,.05,a.gold)
    for x,z in [(-.5,.25),(.5,.25),(-.55,-.6),(.55,-.6)]:sphere((x,-.3,z),(.07,.05,.07),a.gold)

def moisson():
    wheat=mat('#E0B13E',.5)
    for i,x in enumerate([-.35,-.15,.05,.25,.45]):
        top=(.55+x*1.1,0,.95+.1*(i%2)); base=(.25,0,-.95)
        curve([base,((base[0]+top[0])/2,0,0),top],.04,wheat)
        for k in range(5):
            t=.75+k*.06; px=base[0]+(top[0]-base[0])*t; pz=base[2]+(top[2]-base[2])*t
            for s in [-1,1]:
                e=sphere((px+s*.07,0,pz),(.06,.05,.13),wheat); e.rotation_euler[1]=-s*.5
        sphere((top[0],0,top[2]+.08),(.06,.05,.13),wheat)
    torus((.25,-.02,-.4),.18,.05,a.leather)
    pts=[(-.9*math.cos(t)-.1,0,.9*math.sin(t)-.1) for t in [i*math.pi*1.15/16-.1 for i in range(17)]]
    curve(pts,.1,a.steel)
    curve([(p[0]*.97,-.07,p[2]*.97) for p in pts],.035,a.light)
    curve([pts[0],(pts[0][0]-.2,0,pts[0][2]-.55)],.13,a.wood)
    torus((pts[0][0]-.1,0,pts[0][2]-.33),.14,.05,a.gold)

def de_pipe():
    ivory=mat('#F1E3B6',.35,.05); glow=mat('#F2C14E',.25,.5,'#F2C14E',1.4)
    def build():
        h=.62
        bevelled_box((0,0,0),(2*h,2*h,2*h),ivory,.2)
        pip=lambda p,m:sphere(p,(.11,.11,.11),m)
        for dx,dy in [(-.3,-.3),(.3,.3),(-.3,.3),(.3,-.3),(0,0)]:pip((dx,dy,h),glow)
        for d in [-.3,0,.3]:pip((d,-h,d),a.dark)
        for d in [-.3,.3]:pip((-h,d,-d),a.dark)
    group(build,rot=(0,0,math.radians(38)))
    sphere((.9,-.3,.95),(.05,.05,.05),glow); sphere((-.95,-.3,.85),(.04,.04,.04),glow)

def sifflet_de_chasse():
    bone=mat('#EFE2B8',.45)
    def build():
        for (x,r,l,m) in [(-.45,.34,1.15,bone),(.62,.37,1.0,a.gold),(-1.12,.22,.5,bone)]:
            t=cylinder((x,0,0),r,l,m,24); t.rotation_euler[1]=math.pi/2
        for x in [-.1,.1]:
            o=cylinder((x,0,0),.4,.1,a.gold,24); o.rotation_euler[1]=math.pi/2
        bevelled_box((0,-.16,.3),(.38,.34,.1),a.dark,.02)
        bevelled_box((.17,-.14,.36),(.12,.3,.12),a.gold,.02)
        bevelled_box((-.14,0,.36),(.24,.3,.07),bone,.02)
        torus((1.18,0,-.05),.2,.06,a.gold)
        curve([(-.95,0,-.2),(-.65,0,-.95),(0,0,-1.2),(.75,0,-.95),(1.1,0,-.28)],.05,a.leather)
    group(build,rot=(0,math.radians(-12),0))
    for r in [.35,.62,.9]:
        pts=[(1.75+r*math.cos(t),0,.05+r*math.sin(t)) for t in [(-.7+i*1.4/10) for i in range(11)]]
        curve(pts,.045,mat('#B8EAF0',.3,0,'#B8EAF0',.6))

def render_all(chosen,blend_name):
    scenes=[]
    for ident in chosen:
        s=bpy.data.scenes.new(ident);bpy.context.window.scene=s
        reset_scene();setup_render();s.eevee.taa_render_samples=32;a.palette()
        b.purple=mat('#8A6AB0',.35,.2,'#8A6AB0',.2);b.burgundy=mat('#A92232',.3,.1)
        globals()[ident]()
        outline([o for o in s.objects if o.type in {'MESH','CURVE'}]);frame_object_ortho([o for o in s.objects if o.type in {'MESH','CURVE'}])
        raw=ROOT/'art/renders/ui/items'/f'{ident}.png'
        render_to(raw);finalize(raw,ROOT/'game/assets/sprites/icons/items'/f'{ident}.png')
        scenes.append(s);print('ITEM_OK',ident,flush=True)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    bpy.context.window.scene=scenes[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui'/blend_name))

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS+FIX
    if not chosen:chosen=IDS+FIX
    if set(chosen)-set(IDS+FIX):raise ValueError(chosen)
    render_all(chosen,'items_c.blend' if len(chosen)>3 else 'items_c_part.blend')
if __name__=='__main__':main()
