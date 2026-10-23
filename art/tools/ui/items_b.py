"""Items 18–34 : volumes Blender, rendu background uniquement."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_lib import *
import items_a as a
IDS=['cristal_de_feu','givre','horloge_arcanique','lame_jumelle','venin_concentre','cape_de_brume','epines','eclair_en_bouteille','rune_de_portee','morsure_vorace','tonique_vital','orbe_de_veille','sang_chaud','marque_du_chasseur','carquois_affute','pointe_perforante','aimant_d_ame']
def poly(coords,m,depth=.2,y=0,name='Volume'):
    n=len(coords); vs=[(x,yy,z) for yy in [y-depth/2,y+depth/2] for x,z in coords]
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    import bmesh
    bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(m);return o
def drop(x,y,z,r,h,m):
    return lathe([(0,-h*.5),(r*.7,-h*.43),(r,-h*.2),(r*.8,0),(r*.4,h*.26),(0,h*.5)],(x,y,z),m,24,'Goutte')
def cristal_de_feu():
    crystal((0,0,0),.65,2.1,a.red)
    crystal((0,-.5,.03),.29,1.5,a.orange)
    for x in [-.63,.64]:
        o=crystal((x,.03,-.55),.27,.92,a.orange);o.rotation_euler[1]=x*.65
    crystal((-.06,-.71,.12),.12,.66,a.ivory)
def givre():
    for x,z,h,r in [(0,.15,2.2,.43),(-.5,-.39,1.25,.32),(.53,-.3,1.55,.3)]:
        o=crystal((x,0,z),r,h,a.light if x==0 else a.cyan);o.rotation_euler[1]=x*.62
    for x in [-.5,0,.5]:
        curve([(x-.19,-.38,-.65),(x,-.4,-.46),(x+.12,-.38,-.65)],.038,a.light)
def horloge_arcanique():
    a.disk((0,0,0),.94,.23,a.gold);a.disk((0,-.16,0),.77,.06,a.dark)
    torus((0,-.22,0),.7,.035,purple)
    for i in range(8):
        t=i*math.tau/8;x=.6*math.sin(t);z=.6*math.cos(t)
        o=bevelled_box((x,-.25,z),(.085,.07,.18),purple,.015);o.rotation_euler[1]=t
    curve([(-.35,-.29,.19),(0,-.3,0),(.08,-.3,.48)],.065,a.light)
    sphere((0,-.32,0),(.105,.07,.105),a.gold);torus((0,0,1),.15,.06,a.gold)
def dagger(sign):
    before=set(bpy.context.scene.objects)
    poly([(-.16,-.35),(-.18,.5),(0,1.03),(.18,.5),(.16,-.35)],a.steel,.19,name='Lame')
    poly([(0,-.33),(0,1.03),(.18,.5),(.16,-.35)],a.light,.025,-.115,'Tranchant')
    bevelled_box((0,0,-.42),(.67,.27,.13),a.gold,.04)
    bevelled_box((0,0,-.77),(.22,.24,.57),a.leather,.05)
    sphere((0,0,-1.07),(.17,.15,.13),a.gold)
    from mathutils import Matrix
    bpy.context.view_layer.update()
    rot=Matrix.Rotation(sign*.62,4,'Y')
    for o in set(bpy.context.scene.objects)-before:o.matrix_world=rot@o.matrix_world

def lame_jumelle():dagger(-1);dagger(1)
def venin_concentre():
    lathe([(0,-.84),(.46,-.8),(.57,-.5),(.5,.02),(.24,.28),(.22,.68)],material=a.green)
    curve([(0,0,.63),(.34,0,.85),(.63,0,.84)],.19,a.slate)
    torus((0,0,.47),.24,.055,a.gold).rotation_euler[0]=0
    drop(.7,0,.25,.15,.46,a.green)
    poly([(-.24,-.13),(-.13,.04),(.13,.04),(.24,-.13),(.17,-.38),(-.17,-.38)],a.ivory,.07,-.52)
    for x in [-.09,.09]:sphere((x,-.58,-.14),(.055,.025,.06),a.dark)
    curve([(-.31,-.41,-.48),(-.39,-.39,-.25)],.04,a.light)
def cape_de_brume():
    poly([(-.38,.5),(-.64,.08),(-.92,-.84),(-.52,-.68),(-.31,-1.03),(0,-.8),(.3,-.98),(.56,-.7),(.91,-.83),(.62,.12),(.35,.5)],a.slate,.34,name='Cape')
    poly([(-.43,.42),(-.47,.78),(-.22,1.1),(.17,1.13),(.46,.77),(.39,.4),(0,.23)],a.slate,.46,-.04,'Capuche')
    poly([(-.28,.52),(-.24,.77),(0,.94),(.26,.72),(.25,.47),(0,.37)],a.dark,.04,-.3,'Ombre capuche')
    for x in [-.4,.4]:curve([(x*.6,-.24,.19),(x,-.25,-.26),(x*1.45,-.25,-.64)],.045,a.steel)
    sphere((0,-.3,.22),(.12,.08,.1),a.gold)
def epines():
    sphere((0,0,0),(.58,.36,.55),a.wood)
    for i in range(9):
        t=i*math.tau/9
        p=(.4*math.sin(t),0,.4*math.cos(t));q=(1.03*math.sin(t+.12),0,1.03*math.cos(t+.12))
        o=cone(tuple((p[j]+q[j])/2 for j in range(3)),.18,.7,a.dark,6);o.rotation_euler=(Vector(q)-Vector(p)).to_track_quat('Z','Y').to_euler()
    curve([(-.59,-.29,-.13),(-.25,-.4,.3),(.28,-.4,.3),(.58,-.24,-.07),(.24,-.4,-.42)],.09,a.leather)
    for x in [-.22,.22]:cone((x,-.36,.2),.14,.59,a.steel,5)
def eclair_en_bouteille():
    lathe([(0,-.94),(.53,-.9),(.59,-.69),(.58,.24),(.27,.55),(.24,.88)],material=a.slate)
    poly([(-.37,-.67),(-.37,.18),(-.17,.38),(.25,.38),(.4,.17),(.4,-.67)],a.dark,.035,-.49,'Verre sombre')
    poly([(.08,.38),(-.28,-.13),(-.03,-.13),(-.16,-.68),(.34,.02),(.08,.02)],a.cyan,.1,-.56,'Eclair')
    cylinder((0,0,.91),.27,.19,a.leather)
    curve([(-.45,-.43,-.58),(-.45,-.43,.12),(-.25,-.3,.4)],.045,a.light)
    torus((0,0,.67),.25,.05,a.gold).rotation_euler[0]=0
def rune_de_portee():
    poly([(-.77,-.61),(-.85,.39),(-.45,.85),(.53,.77),(.85,.27),(.68,-.76),(-.23,-.91)],a.slate,.35)
    for r in [.32,.62]:torus((0,-.23,-.02),r,.045,purple)
    for sign in [-1,1]:poly([(sign*.13,.01),(sign*.42,.19),(sign*.42,.08),(sign*.72,.08),(sign*.72,-.1),(sign*.42,-.1),(sign*.42,-.22)],a.cyan,.06,-.28)
    crystal((0,-.31,.03),.13,.42,a.light)
def morsure_vorace():
    curve([(-.8,0,.42),(-.68,0,-.3),(-.37,0,-.64),(0,0,-.72),(.37,0,-.64),(.68,0,-.3),(.8,0,.42)],.18,a.ivory)
    for x in [-.65,-.33,0,.33,.65]:
        z=-.48+abs(x)*.45
        o=cone((x,-.1,z+.25),.13,.65 if abs(x)>.5 else .4,a.ivory,8)
    for x in [-.69,.69]:drop(x,-.12,-.74,.12,.4,a.red)
    curve([(-.43,-.18,-.63),(0,-.2,-.78),(.42,-.18,-.62)],.075,a.red)
def tonique_vital():
    lathe([(0,-.85),(.62,-.81),(.72,-.54),(.7,.17),(.29,.5),(.27,.76)],material=burgundy)
    cylinder((0,0,.83),.3,.24,a.leather)
    torus((0,0,.6),.29,.065,a.gold).rotation_euler[0]=0
    bevelled_box((0,-.65,-.18),(.92,.08,.72),a.ivory,.09)
    bevelled_box((0,-.72,-.18),(.16,.06,.5),a.red,.02);bevelled_box((0,-.72,-.18),(.5,.06,.16),a.red,.02)
    curve([(-.45,-.5,.16),(-.28,-.36,.37)],.045,a.light)
def orbe_de_veille():
    cylinder((0,0,-.78),.65,.19,a.gold)
    sphere((0,0,.07),(.7,.53,.7),a.cyan)
    # Oeil en relief, iris arcane et pupille verticale.
    sphere((0,-.51,.12),(.49,.075,.28),a.ivory)
    sphere((0,-.6,.12),(.22,.05,.25),purple)
    sphere((0,-.66,.12),(.065,.025,.19),a.dark)
    sphere((-.07,-.69,.22),(.06,.025,.06),a.light)
    for x in [-.49,.49]:curve([(x,0,-.73),(x*.98,-.06,-.38),(x*1.3,-.02,-.16)],.07,a.gold)
def sang_chaud():
    drop(0,0,0,.69,2.1,burgundy)
    drop(.05,-.53,-.29,.3,1.12,a.orange)
    drop(.06,-.77,-.46,.13,.59,a.ivory)
    curve([(-.38,-.42,-.35),(-.46,-.38,-.06),(-.33,-.3,.28)],.045,a.red)
def marque_du_chasseur():
    bevelled_box((0,0,0),(1.53,.27,1.64),a.leather,.13)
    for x in [-.52,.52]:bevelled_box((x,-.16,0),(.08,.05,1.4),a.wood,.015)
    torus((0,-.25,0),.55,.085,a.steel)
    for sign in [-1,1]:
        curve([(sign*.3,-.35,0),(sign*.85,-.35,0)],.06,a.ivory)
        curve([(0,-.35,sign*.3),(0,-.35,sign*.86)],.06,a.ivory)
    sphere((0,-.36,0),(.14,.08,.14),a.red)
def arrow(x,z):
    curve([(x,0,z-.7),(x,0,z+.65)],.045,a.ivory)
    poly([(x-.14,z+.44),(x,z+.81),(x+.14,z+.44)],a.steel,.13)
    for sign in [-1,1]:poly([(x,z+.05),(x+sign*.18,z+.18),(x+sign*.18,z-.17),(x,z-.32)],a.slate,.09)
def carquois_affute():
    for x,z in [(-.32,.51),(0,.72),(.32,.58)]:arrow(x,z)
    lathe([(0,-1.02),(.34,-.98),(.45,-.8),(.48,.43)],(0,-.12,0),a.leather)
    for z in [-.7,.35]:
        o=torus((0,-.12,z),.46,.075,a.gold);o.rotation_euler[0]=0
    curve([(-.43,.05,-.76),(-.88,.06,-.12),(-.75,.06,.48),(-.32,.06,.65)],.085,a.wood)
    curve([(-.22,-.55,-.7),(-.22,-.6,.19)],.04,a.gold)
def pointe_perforante():
    poly([(-.47,.17),(0,1.2),(.47,.17),(.18,.28),(.18,-.48),(-.18,-.48),(-.18,.28)],a.steel,.3)
    poly([(0,1.2),(.47,.17),(.18,.28),(.18,-.48),(0,-.48)],a.light,.04,-.18)
    bevelled_box((0,0,-.69),(.25,.23,.51),a.leather,.04)
    for x in [-.43,0,.43]:curve([(x,.1,-1.2),(x*.76,.1,-.72)],.045,a.cyan)
def aimant_d_ame():
    curve([(-.56,0,.6),(-.56,0,-.36),(-.4,0,-.64),(0,0,-.78),(.4,0,-.64),(.56,0,-.36),(.56,0,.6)],.19,purple)
    for x in [-.56,.56]:bevelled_box((x,0,.6),(.4,.4,.36),a.cyan,.04)
    drop(0,-.12,.43,.29,.87,a.cyan)
    for x in [-.1,.1]:sphere((x,-.38,.41),(.05,.03,.07),a.dark)
    for sign in [-1,1]:curve([(sign*.75,0,.85),(sign*.96,0,.52),(sign*.83,0,.18)],.055,a.light)
def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError(chosen)
    scenes=[]
    for ident in chosen:
        s=bpy.data.scenes.new(ident);bpy.context.window.scene=s
        reset_scene();setup_render();a.palette()
        global purple,burgundy
        purple=mat('#8A6AB0',.35,.2,'#8A6AB0',.2);burgundy=mat('#A92232',.3,.1)
        globals()[ident]()
        outline([o for o in s.objects if o.type in {'MESH','CURVE'}])
        frame_object_ortho([o for o in s.objects if o.type in {'MESH','CURVE'}])
        raw=ROOT/'art/renders/ui/items'/f'{ident}.png'
        render_to(raw);finalize(raw,ROOT/'game/assets/sprites/icons/items'/f'{ident}.png')
        scenes.append(s);print('ITEM_OK',ident,flush=True)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    bpy.context.window.scene=scenes[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui/items_b.blend'))
if __name__=='__main__':main()

