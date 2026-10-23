"""17 objets UI, uniquement Blender background. -- id [id ...] pour un sous-ensemble."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_lib import *
IDS=['lentille_aiguisee','sablier_fele','antidote','botte_rapiecee','pierre_a_aiguiser','bague_de_vigueur','amulette_de_cuir','aimant_de_poche','sifflet_de_chasse','etincelle','flocon','fiole_verte','pavois_fele','coeur_de_mousse','piece_porte_bonheur','eclat_d_experience','plume_d_empenne']

def palette():
    global gold,steel,dark,wood,leather,ivory,cyan,green,red,orange,light,slate
    gold=mat('#F2C14E',.3,.7); steel=mat('#7C8898',.3,.65); dark=mat('#2B3340',.6,.25)
    wood=mat('#3F2B1E',.8); leather=mat('#6B4A32',.65); ivory=mat('#FFE9A8',.45)
    cyan=mat('#5FD4E8',.25,.2,'#5FD4E8',.3); green=mat('#7FA35B',.3,.05)
    red=mat('#C23B12',.35,.15); orange=mat('#FF7A1F',.3,0,'#FF7A1F',.8)
    light=mat('#B8EAF0',.2,.25); slate=mat('#5E7390',.5,.3)

def disk(loc,r,depth,m):
    o=cylinder(loc,r,depth,m); o.rotation_euler[0]=math.pi/2; return o

def bar(a,b,r,m):
    return curve([a,b],r,m)

def lentille_aiguisee():
    torus((-.12,0,.28),.68,.12,gold)
    sphere((-.12,.025,.28),(.59,.13,.59),mat('#5FD4E8',.16,.48))
    curve([(-.47,-.13,.43),(-.42,-.15,.64),(-.25,-.14,.76)],.045,light)
    bar((.36,0,-.22),(.93,0,-1.03),.14,leather)
    bar((.35,0,-.21),(.5,0,-.43),.16,gold)

def sablier_fele():
    for z in [-.94,.94]:cylinder((0,0,z),.72,.16,leather)
    for x in [-.54,.54]:bar((x,.09,-.87),(x,.09,.87),.08,gold)
    glass=mat('#8FA8C8',.2,.15)
    glass.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.2
    glass.surface_render_method='DITHERED'
    lathe([(0,-.84),(.47,-.8),(.42,-.47),(.12,-.05),(.12,.05),(.42,.47),(.47,.8),(0,.84)],material=glass)
    cone((0,-.06,-.57),.37,.45,cyan,32)
    cone((0,-.03,.45),.29,.42,cyan,32,radius2=.08).rotation_euler[0]=math.pi
    bar((0,-.15,-.3),(0,-.15,.2),.035,cyan)
    curve([(.21,-.39,.65),(.04,-.27,.4),(.15,-.21,.27),(.04,-.2,.04)],.028,light)

def bottle(drop=False):
    if drop:
        lathe([(0,-.83),(.38,-.77),(.59,-.4),(.49,.04),(.22,.48),(.19,.76)],material=green)
    else:
        sphere((0,0,-.16),(.65,.44,.67),green)
        cylinder((0,0,.5),.24,.52,slate)
    cylinder((0,0,.82),.25,.22,leather)
    torus((0,-.015,.67),.23,.06,gold).rotation_euler[0]=0
    curve([(-.34,-.4,-.2),(-.43,-.35,.02),(-.32,-.3,.22)],.045,light)

def antidote():
    bottle()
    bevelled_box((0,-.435,-.15),(.16,.07,.55),ivory,.025)
    bevelled_box((0,-.44,-.15),(.49,.07,.16),ivory,.025)

def botte_rapiecee():
    bevelled_box((-.12,0,.2),(.82,.65,1.3),leather,.17)
    bevelled_box((.2,-.13,-.51),(1.46,.85,.58),leather,.2)
    bevelled_box((.22,-.14,-.82),(1.55,.88,.19),dark,.065)
    bevelled_box((-.12,-.01,.84),(.94,.75,.2),wood,.06)
    bevelled_box((-.25,-.355,.23),(.42,.065,.44),slate,.045)
    for z in [.1,.29,.48]:bar((.07,-.38,z),(.28,-.38,z+.12),.035,ivory)
    for z in [.08,.28,.46]:bar((-.43,-.4,z),(-.32,-.4,z+.07),.018,ivory)

def pierre_a_aiguiser():
    bevelled_box((0,0,-.53),(1.8,.95,.48),slate,.18)
    blade=bevelled_box((.05,-.08,.22),(1.55,.15,.3),steel,.045); blade.rotation_euler[1]=-.55
    h=bevelled_box((-.86,-.08,-.32),(.57,.25,.33),leather,.06); h.rotation_euler[1]=-.55
    bar((-.6,-.08,-.36),(-.79,-.08,.08),.05,gold)
    for a in [-.7,0,.7]:
        bar((.55,-.2,-.1),(.65+a*.3,-.2,.42-abs(a)*.15),.035,orange)

def bague_de_vigueur():
    torus((0,0,-.18),.66,.16,gold)
    bevelled_box((0,-.06,.5),(.74,.4,.28),gold,.08)
    gem=crystal((0,-.17,.7),.36,.63,red); gem.rotation_euler[0]=-.35

def amulette_de_cuir():
    curve([(-.38,0,.15),(-.62,.04,.86),(0,.1,1.17),(.62,.04,.86),(.38,0,.15)],.065,wood)
    disk((0,0,-.37),.64,.18,leather); torus((0,-.12,-.37),.51,.045,gold)
    torus((0,0,.24),.15,.05,gold)
    for a in range(0,360,60):
        t=math.radians(a); sphere((.44*math.sin(t),-.15,-.37+.44*math.cos(t)),(.065,.05,.065),steel)

def aimant_de_poche():
    pts=[(-.58,0,.67),(-.58,0,-.35),(-.43,0,-.65),(0,0,-.79),(.43,0,-.65),(.58,0,-.35),(.58,0,.67)]
    curve(pts,.19,red)
    for x in [-.58,.58]:bevelled_box((x,0,.66),(.4,.42,.4),steel,.04)
    for x,z in [(-.79,.25),(.8,-.16)]:
        disk((x,-.28,z),.27,.1,gold); torus((x,-.35,z),.19,.024,ivory)

def sifflet_de_chasse():
    sphere((-.22,0,-.18),(.59,.36,.49),gold)
    bevelled_box((.4,0,.08),(.93,.48,.32),ivory,.07)
    bevelled_box((.42,-.26,.17),(.28,.035,.11),dark,.015)
    torus((-.64,0,-.05),.17,.06,gold)
    curve([(-.76,0,-.12),(-1,0,.4),(-.68,.04,.92),(.02,.1,1.05),(.65,.05,.74),(.72,0,.45)],.045,wood)

def etincelle():
    sphere((0,0,-.72),(.77,.5,.3),dark)
    def flame(x,z,r,h,m,bend):
        o=lathe([(0,-h*.5),(r*.65,-h*.42),(r,-h*.2),(r*.82,h*.03),(r*.38,h*.25),(0,h*.5)],(x,0,z),m,24,'Flamme')
        for v in o.data.vertices:
            t=max(0,(v.co.z/h+.1))
            v.co.x += bend*t*t
        o.scale.y=.65
        return o
    flame(0,.02,.4,1.7,orange,.55)
    flame(-.38,-.2,.24,1.05,orange,-.4)
    flame(.37,-.25,.22,.9,orange,.35)
    core=flame(0,-.23,.21,.86,mat('#FFE9A8',.3,0,'#FFB347',.7),.12)
    core.location.y=-.29
    for x,z in [(-.7,.38),(.66,.65),(.25,1.05)]:
        sphere((x,0,z),(.055,.045,.1),gold)

def flocon():
    for i in range(6):
        a=i*math.tau/6
        def p(r,offset=0):return (r*math.sin(a+offset),0,r*math.cos(a+offset))
        bar((0,0,0),p(1),.085,cyan)
        for s in [-1,1]:bar(p(.57),p(.9,s*.3),.063,light)
    crystal((0,-.03,0),.24,.5,light)

def fiole_verte():
    bottle(True)
    for x,y,z,r in [(-.16,-.48,-.23,.13),(.19,-.4,.03,.095),(.05,-.25,.39,.07)]:
        sphere((x,y,z),(r,r*.5,r),light)

def pavois_fele():
    disk((0,0,0),.91,.25,wood)
    for x in [-.48,-.23,.02,.27,.52]:
        half=math.sqrt(.81-x*x)
        bevelled_box((x,-.145,0),(.21,.08,half*1.88),leather,.025)
    torus((0,-.12,0),.85,.105,steel)
    disk((0,-.23,0),.26,.16,steel)
    curve([(.31,-.24,.79),(.18,-.25,.52),(.35,-.25,.3),(.28,-.25,.1),(.46,-.24,-.25),(.34,-.24,-.7)],.04,dark)
    for a in range(0,360,60):
        t=math.radians(a); sphere((.84*math.sin(t),-.22,.84*math.cos(t)),(.05,.04,.05),gold)

def coeur_de_mousse():
    # Cœur volumétrique : lobes et pointe en mesh continu.
    outline2=[(0,.47),(-.32,.8),(-.64,.73),(-.83,.44),(-.76,.1),(0,-.84),(.76,.1),(.83,.44),(.64,.73),(.32,.8)]
    verts=[(x,y,z) for y in [-.22,.23] for x,z in outline2]
    faces=[tuple(reversed(range(10))),tuple(range(10,20))]
    faces += [(i,(i+1)%10,(i+1)%10+10,i+10) for i in range(10)]
    mesh=bpy.data.meshes.new('Coeur'); mesh.from_pydata(verts,[],faces); mesh.update()
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new('Coeur pierre',mesh); bpy.context.collection.objects.link(o); o.data.materials.append(slate)
    b=o.modifiers.new('Arêtes usées','BEVEL'); b.width=.14;b.segments=3;o.modifiers.new('Normales','WEIGHTED_NORMAL')
    moss=mat('#5B6B4F',.9)
    for x,z,r in [(-.47,.56,.32),(-.65,.25,.23),(-.27,.48,.23),(.49,-.05,.23),(.29,-.36,.19)]:
        sphere((x,-.26,z),(r,.12,r*.7),moss)
    curve([(-.07,-.24,.23),(.11,-.24,.04),(-.05,-.24,-.14)],.023,dark)

def piece_porte_bonheur():
    disk((0,0,0),.88,.22,gold); torus((0,-.15,0),.73,.05,ivory)
    clover=mat('#5B6B4F',.5,.2)
    for x,z in [(-.18,.1),(.18,.1),(0,.4)]:sphere((x,-.19,z),(.23,.07,.24),clover)
    curve([(0,-.22,.08),(.02,-.22,-.25),(.19,-.22,-.4)],.055,clover)
    for i in range(16):
        a=i*math.tau/16; bar((.78*math.sin(a),-.15,.78*math.cos(a)),(.83*math.sin(a),-.15,.83*math.cos(a)),.019,wood)

def eclat_d_experience():
    o=crystal((0,0,.05),.54,1.98,cyan); o.rotation_euler[1]=.2
    for x,z,s in [(-.65,-.48,.48),(.59,-.37,.64)]:
        o=crystal((x,.03,z),.23,s,light); o.rotation_euler[1]=x*.5
    curve([(-.18,-.44,.03),(-.13,-.4,.55),(.07,-.23,.88)],.025,light)

def plume_d_empenne():
    bar((-.56,-.09,-1.05),(.49,-.09,1.04),.048,ivory)
    for i in range(8):
        z=-.62+i*.2
        for sign in [-1,1]:
            width=.5*(1-abs(z-.05)*.75)
            nxt=.5*(1-abs(z+.17-.05)*.75)
            coords=[(z*.49,z), (z*.49+sign*width,z+.28),
                    ((z+.17)*.49+sign*nxt,z+.44),((z+.17)*.49,z+.17)]
            verts=[(x,y,zz) for y in [-.04,.075] for x,zz in coords]
            faces=[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)]
            mesh=bpy.data.meshes.new('Barbe');mesh.from_pydata(verts,[],faces);mesh.update()
            o=bpy.data.objects.new('Barbe de plume',mesh);bpy.context.collection.objects.link(o)
            import bmesh
            bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
            o.data.materials.append(steel if sign<0 else slate)
            mod=o.modifiers.new('Biseau','BEVEL');mod.width=.018;mod.segments=2
    crystal((.49,0,1.03),.085,.3,steel)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if not chosen:chosen=IDS
    invalid=set(chosen)-set(IDS)
    if invalid:raise ValueError(f'Ids inconnus: {invalid}')
    scenes=[]
    for ident in chosen:
        # Chaque item reste dans sa propre scène dans le blend livré.
        s=bpy.data.scenes.new(ident); bpy.context.window.scene=s
        reset_scene(); setup_render(); palette(); globals()[ident]()
        objs=[o for o in s.objects if o.type in {'MESH','CURVE'}]
        outline(objs); frame_object_ortho([o for o in s.objects if o.type in {'MESH','CURVE'}])
        raw=ROOT/'art/renders/ui/items'/f'{ident}.png'
        render_to(raw); finalize(raw,ROOT/'game/assets/sprites/icons/items'/f'{ident}.png')
        scenes.append(s); print('ITEM_OK',ident,flush=True)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    bpy.context.window.scene=scenes[0]
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui/items_a.blend'))
if __name__=='__main__':main()
