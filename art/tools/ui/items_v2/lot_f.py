"""Lot F: worn inventory relics, cel, background rendering only."""
import sys, math, shutil, subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from iv2_lib import *
from mathutils import Matrix, Vector
IDS=['chronometre_brise','tempete_de_braises','coeur_de_glace','peste_vivante','oeil_du_predateur','bouclier_reactif','faveur_du_marchand','danseur']
def glow(c):return mat(c,emit_hex=c,emit_strength=.85)
def poly(cx,cz,rx,rz,n=6,angle=0):
    return [(cx+rx*math.cos(angle+i*math.tau/n),cz+rz*math.sin(angle+i*math.tau/n)) for i in range(n)]
def studs(points,m,y=-.29,r=.055):
    for x,z in points:disk(x,z,r,m,y=y,depth=.035)
def chronometre_brise():
    brass=mat('#C1AD7A');steel=mat('#899491');dark=mat('#353B3B');face=mat('#C3C4A5');cyan=glow('#5FD4E8')
    disk(0,0,1.02,dark,y=0,depth=.25);disk(0,0,.94,brass,y=-.15,depth=.11);disk(0,0,.80,face,y=-.23)
    # Broken rim and missing dial wedge expose two interlocking gears.
    plate([(.25,.78),(.79,.42),(.78,-.37),(.25,-.56),(.33,-.18),(.15,.03),(.40,.29)],.04,dark,'Torn dial',y=-.27)
    for x,z,r in [(.48,.15,.25),(.43,-.29,.20)]:
        disk(x,z,r,steel,y=-.31);disk(x,z,r*.65,brass,y=-.345);disk(x,z,r*.25,dark,y=-.38)
        for j in range(8):
            a=j*math.tau/8;disk(x+r*math.cos(a),z+r*math.sin(a),.044,steel,y=-.32)
    for i in range(12):
        a=i*math.tau/12
        if i not in [0,1,11]:line([(.66*math.sin(a),.66*math.cos(a)),(.74*math.sin(a),.74*math.cos(a))],dark,.026,y=-.30)
    line([(-.38,.40),(0,0),(-.12,-.49)],dark,.045,y=-.35);disk(0,0,.085,brass,y=-.39)
    line([(-.68,.39),(-.24,.24),(-.09,-.07),(-.39,-.56)],cyan,.033,y=-.40,name='Time fracture')
    line([(-.24,.24),(-.04,.58),(.12,.69)],cyan,.025,y=-.40)
    bevelled_box((0,0,1.09),(.26,.26,.20),brass,.035,'Winding crown');torus((0,0,1.38),.20,.060,brass,'Pocket bow')
    plate([(.69,.71),(.92,.44),(1.07,.57),(.91,.87)],.12,steel,'Broken bezel tooth',y=-.12)
def tempete_de_braises():
    iron=mat('#697579');edge=mat('#BCC4BD');coal=mat('#343530');ash=mat('#999883');fire=glow('#FF7A1F')
    plate([(-.96,-.27),(.96,-.27),(.76,-.84),(.42,-1.02),(-.42,-1.02),(-.76,-.84)],.66,iron,'Forged brazier',bevel=.05)
    line([(-.97,-.27),(0,-.36),(.97,-.27)],edge,.065,y=-.38)
    for x in [-.59,.59]:bevelled_box((x,0,-1.02),(.20,.50,.35),coal,.03,'Brazier foot')
    studs([(-.67,-.50),(.67,-.50)],edge,y=-.36)
    for x,z,r in [(-.58,-.16,.19),(-.18,-.20,.24),(.25,-.13,.22),(.61,-.15,.16)]:
        plate(poly(x,z,r,r*.65,5),.25,coal,'Angular charcoal',y=-.15)
        line([(x-r*.5,z),(x,z+.07),(x+r*.35,z)],fire,.032,y=-.31)
    # A rising helix carries the embers directly out of the brazier.
    points=[]
    for i in range(49):
        t=i/48;a=t*math.tau*1.70+.5;r=.91*(1-t)+.16
        points.append((r*math.cos(a),r*.43*math.sin(a)-.06,-.06+1.48*t))
    curve(points,.065,fire,'Rising ember spiral')
    for x,z,r in [(-.77,.93,.10),(.78,.62,.08),(-.15,1.40,.08)]:plate([(x-r,z),(x,z+r*1.5),(x+r,z),(x,z-r)],.06,fire,'Flying ember',y=-.12)
def coeur_de_glace():
    dark=mat('#3E697C');ice=mat('#88B6C5');light=mat('#C1DDE0');cyan=glow('#5FD4E8')
    pts=[(0,.73),(-.34,1.03),(-.71,1.01),(-1,.65),(-.93,.17),(-.59,-.31),(0,-1.02),(.63,-.37),(.98,.17),(1,.63),(.69,1.03),(.31,1.02)]
    plate(pts,.46,dark,'Fractured frozen heart',bevel=.025)
    for p,m in [([(0,.72),(-.35,.95),(-.88,.57),(-.77,.20),(-.19,.12)],light),([(0,.72),(-.19,.12),(.12,-.60),(.80,.19),(.89,.62),(.49,.90)],ice),([(-.77,.20),(-.19,.12),(.12,-.60),(0,-.92)],ice)]:plate(p,.025,m,'Broad ice facet',y=-.25,bevel=0)
    for x,z,w,h in [(-.64,-.29,.15,.57),(.61,-.31,.16,.64),(.27,-.78,.12,.49)]:
        plate([(x-w,z+.11),(x+w,z+.13),(x+.01,z-h)],.16,light,'Hanging icicle',y=-.12,bevel=0)
    line([(-.33,.78),(-.10,.33),(-.24,.02),(.10,-.24),(.03,-.70)],cyan,.040,y=-.30,name='Frozen core fissure')
    line([(-.24,.02),(-.64,-.04)],cyan,.032,y=-.30)
def peste_vivante():
    bone=mat('#B2B396');shade=mat('#777E67');dark=mat('#303D31');green=glow('#91B45C');iron=mat('#69796A')
    plate([(-.61,1.02),(.41,1.08),(.78,.69),(.81,.17),(.55,-.23),(.48,-.76),(-.43,-.80),(-.55,-.27),(-.82,.15),(-.79,.66)],.54,bone,'Plague reliquary skull',bevel=.06)
    for sign in [-1,1]:
        plate([(sign*.13,.37),(sign*.55,.56),(sign*.66,.18),(sign*.39,.03),(sign*.16,.12)],.035,dark,'Sunken socket',y=-.30)
    plate([(-.04,.09),(-.21,-.24),(.17,-.24)],.04,dark,'Nasal cavity',y=-.31)
    for x in [-.32,-.10,.12,.34]:line([(x,-.43),(x,-.72)],shade,.025,y=-.32)
    line([(-.52,.86),(-.26,.57),(-.35,.23),(-.18,-.04)],green,.045,y=-.35,name='Toxic fissure')
    line([(.61,-.22),(.91,-.07),(1.01,.30),(.90,.69),(1.02,1.03),(.79,1.30),(.40,1.35)],green,.095,y=.02,name='Single poison plume')
    bevelled_box((0,0,-.90),(1.15,.64,.22),iron,.05,'Reliquary clamp')
    studs([(-.43,-.90),(.43,-.90)],bone,y=-.36)
def oeil_du_predateur():
    metal=mat('#677E75');rim=mat('#B1AB8B');flesh=mat('#AD7751');amber=mat('#C39A5A');dark=mat('#212D29');fire=glow('#FF9C38')
    plate([(-1.14,0),(-.73,.72),(0,.96),(.78,.66),(1.12,-.06),(.70,-.72),(-.12,-.90),(-.77,-.61)],.29,metal,'Predator cabochon',bevel=.055)
    plate([(-.98,.04),(-.57,.48),(.05,.59),(.64,.36),(.98,-.04),(.53,-.43),(-.09,-.55),(-.65,-.32)],.10,rim,'Worn almond bezel',y=-.20)
    plate([(-.84,.02),(-.49,.34),(.02,.44),(.54,.28),(.84,-.04),(.45,-.31),(-.07,-.40),(-.55,-.24)],.08,flesh,'Eye sclera',y=-.29)
    disk(.04,0,.40,amber,y=-.36,depth=.10);disk(.04,0,.31,fire,y=-.42,depth=.04)
    plate([(.03,.32),(-.07,.12),(-.06,-.14),(.04,-.33),(.13,-.10),(.12,.12)],.035,dark,'Vertical hunting pupil',y=-.46)
    for x,z in [(-.76,.52),(.77,.45),(-.73,-.42),(.69,-.52)]:
        plate([(x-.10,z+.10),(x+.10,z+.06),(x*.75,z*.63)],.09,rim,'Setting claw',y=-.40)
def bouclier_reactif():
    iron=mat('#596C73');edge=mat('#BAC7C2');face=mat('#718A91');dark=mat('#2F454E');cyan=glow('#5FD4E8')
    pts=[(0,1.25),(.95,.63),(.95,-.49),(0,-1.28),(-.95,-.49),(-.95,.63)]
    plate(pts,.29,edge,'Hexagonal shield rim',bevel=.035)
    plate([(x*.88,z*.88) for x,z in pts],.08,iron,'Shield face',y=-.19)
    plate([(0,1.05),(.77,.52),(.77,-.39),(0,-1.07)],.025,face,'Faceted right plane',y=-.25,bevel=0)
    line([(0,.88),(0,-.87)],edge,.045,y=-.29,name='Central shield ridge')
    line([(-.68,.41),(-.68,-.30),(0,-.86),(.68,-.30),(.68,.41)],dark,.035,y=-.30)
    for x,z in [(-.40,.24),(.40,.24)]:
        plate(poly(x,z,.23,.32,4),.09,dark,'Charge socket',y=-.30)
        plate(poly(x,z,.15,.23,4),.06,cyan,'Cyan charge',y=-.37)
    studs([(0,1.12),(-.83,.53),(.83,.53),(-.83,-.43),(.83,-.43),(0,-1.12)],iron,y=-.24,r=.045)
def faveur_du_marchand():
    leather=mat('#8B6747');light=mat('#B18B5A');dark=mat('#46392D');gold=mat('#D3B975');edge=mat('#F1D799');wax=glow('#F2C14E')
    plate([(-.53,.52),(-.83,.02),(-.91,-.60),(-.58,-1.03),(.48,-1.05),(.87,-.72),(.91,-.16),(.57,.55)],.75,leather,'Full hide purse',bevel=.09)
    plate([(-.53,.40),(-.66,-.25),(-.48,-.83),(-.20,-.93),(-.35,-.15),(-.18,.40)],.025,light,'Worn leather fold',y=-.40)
    plate([(.33,.44),(.17,-.22),(.45,-.91),(.73,-.68),(.56,-.08)],.03,dark,'Fold shadow',y=-.40)
    for x,z,r in [(-.44,.62,.29),(.09,.80,.32),(.50,.58,.28),(-.23,1.10,.26),(.42,1.08,.24)]:
        disk(x,z,r,dark,y=-.02,depth=.10);disk(x,z,r*.86,gold,y=-.09);disk(x,z,r*.62,edge,y=-.125,depth=.01)
        line([(x-.06,z-.10),(x+.06,z+.10)],gold,.028,y=-.15)
    line([(-.61,.45),(-.21,.35),(.24,.35),(.64,.45)],dark,.065,y=-.46,name='Drawstring binding')
    line([(.30,.35),(.53,-.10),(.45,-.43)],light,.035,y=-.48)
    disk(.45,-.53,.23,dark,y=-.49);disk(.45,-.53,.18,wax,y=-.54)
    plate([(.43,-.40),(.36,-.55),(.45,-.65),(.55,-.50)],.025,gold,'Merchant seal imprint',y=-.58)
    for x,z in [(-.70,-.40),(-.66,-.58),(-.55,-.76)]:line([(x-.03,z+.03),(x+.05,z-.02)],light,.016,y=-.44)
def danseur():
    leather=mat('#5B554E');face=mat('#9B9580');edge=mat('#C1BAA0');sole=mat('#303735');wing=mat('#CDD0BD');shade=mat('#86998E');magic=glow('#8A6AB0')
    shape=[(-.36,1.04),(.23,1.04),(.24,.23),(.37,-.23),(.72,-.45),(.87,-.62),(.78,-.79),(-.44,-.78),(-.51,-.48),(-.40,-.17)]
    for ox,oz,y in [(-.37,.14,.18),(.28,-.20,-.23)]:
        plate([(x+ox,z+oz) for x,z in shape],.36,leather,'Dancer leather boot',y=y,bevel=.045)
        plate([(ox-.37,oz-.68),(ox+.83,oz-.68),(ox+.80,oz-.86),(ox-.46,oz-.86)],.41,sole,'Stacked boot sole',y=y)
        plate([(ox-.27,oz+.94),(ox+.12,oz+.94),(ox+.14,oz+.16),(ox-.29,oz+.09)],.02,face,'Worn boot shaft',y=y-.20)
        line([(ox-.33,oz+.90),(ox+.18,oz+.90)],edge,.045,y=y-.23,name='Boot cuff')
        for z in [.57,.34,.12]:line([(ox-.21,oz+z+.05),(ox+.12,oz+z-.02)],sole,.028,y=y-.24,name='Lacing')
    # One broad wing with three angular feather blades.
    for pts,m in [([(.47,.00),(.56,.63),(1.02,1.32),(1.12,1.31),(.92,.64),(.72,.17)],wing),([(.58,.04),(.94,.53),(1.32,.82),(1.35,.70),(1.03,.25),(.71,-.08)],shade),([(.65,-.08),(1.06,.17),(1.35,.29),(1.29,.10),(.93,-.22),(.72,-.25)],wing)]:plate(pts,.09,m,'Angular wing feather',y=-.48,bevel=.012)
    line([(.58,-.08),(.70,.28),(.95,.65)],magic,.042,y=-.55,name='Wing enchanted spine')
def deliver_f(ident):
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    bpy.context.view_layer.update()
    rotation=Matrix.Rotation(math.radians(-9),4,'Z')
    for o in objs:o.matrix_world=rotation@o.matrix_world
    frame_object_ortho(objs,margin=.08)
    camera=bpy.context.scene.camera;basis=camera.rotation_euler.to_matrix()
    if ident in {'chronometre_brise','danseur'}:
        tilt=Matrix.Rotation(math.radians(32 if ident=='chronometre_brise' else -25),4,basis@Vector((0,0,1)))
        for o in objs:o.matrix_world=tilt@o.matrix_world
    bpy.context.view_layer.update();inv=basis.transposed();graph=bpy.context.evaluated_depsgraph_get();points=[]
    for o in objs:
        ev=o.evaluated_get(graph);mesh=ev.to_mesh();points.extend(inv@(o.matrix_world@v.co) for v in mesh.vertices);ev.to_mesh_clear()
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    camera.location=basis@((lo+hi)*.5+Vector((0,0,10)));camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)/.865
    cel.toon_materials('icon');RAW.mkdir(parents=True,exist_ok=True)
    raw=RAW/(ident+'.png');cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    before=ROOT/'art/renders/items_v2/before';before.mkdir(parents=True,exist_ok=True)
    if not (before/(ident+'.png')).exists():shutil.copy2(DEST/(ident+'.png'),before/(ident+'.png'))
    subprocess.run([PY,'-I',str(Path(__file__).with_name('check_f.py')),'--finalize',ident],check=True,stdout=subprocess.DEVNULL)
def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown item')
    scenes=[]
    for ident in chosen:
        scenes.append(reset(ident));globals()[ident]();deliver_f(ident)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    out=ROOT/'art/blender/items_v2/lot_f.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('PASS lot_f '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()
