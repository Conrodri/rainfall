"""Lot D: eight serious cel inventory icons, background render only."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from iv2_lib import *
from mathutils import Matrix, Vector
IDS=['cristal_de_feu','givre','horloge_arcanique','lame_jumelle','venin_concentre','cape_de_brume','epines','rune_de_portee']

def accent(c):return mat(c,emit_hex=c,emit_strength=.9)

def crystal(ice=False):
    dark=mat('#426C83' if ice else '#79392E');mid=mat('#8BB2BF' if ice else '#BD6341');light=mat('#CFDFDB' if ice else '#E99C66');glow=accent('#5FD4E8' if ice else '#FF7A1F')
    outline=[(-.38,-1.24),(-.67,-.62),(-.49,.47),(.08,1.62),(.60,.53),(.55,-.69),(.12,-1.28)]
    plate(outline,.40,dark,'Raw mineral',bevel=.018)
    plate([(-.38,-1.24),(-.44,-.56),(-.22,.39),(.08,1.62),(.15,.36),(.02,-.58)],.015,mid,'Broad mineral facet',y=-.217,bevel=0)
    plate([(.08,1.62),(.60,.53),(.55,-.69),(.15,.36)],.018,light,'Light catching facet',y=-.223,bevel=0)
    plate([(-.44,-.56),(.02,-.58),(.12,-1.28)],.02,light,'Basal fracture',y=-.23,bevel=0)
    line([(-.16,-.70),(.05,-.25),(-.08,.10),(.10,.63)],glow,.043,y=-.265,name='Incandescent heart')
    for side in [-1,1]:
        plate([(side*.36,-.94),(side*.82,-.47),(side*.93,.18),(side*.53,-.10)],.22,mid,'Satellite shard',y=.10,bevel=.012)
    if ice:line([(-.32,-.94),(-.10,-.82),(.24,-.93),(.45,-.60)],light,.03,y=-.27,name='Frost crust')

def cristal_de_feu():crystal()
def givre():crystal(True)

def horloge_arcanique():
    bronze=mat('#8E8972');brass=mat('#C4B18B');rim=mat('#585F59');face=mat('#C4C4AF');ink=mat('#303C40');glow=accent('#8A6AB0')
    disk(0,0,1.12,rim,y=.03,depth=.24);disk(0,0,1.025,brass,y=-.12,depth=.08);disk(0,0,.88,face,y=-.18,depth=.04)
    torus((0,-.23,0),.94,.045,bronze,'Heavy brass bezel')
    for i in range(12):
        a=math.tau*i/12;s,c=math.sin(a),math.cos(a)
        line([(.70*s,.70*c),(.81*s,.81*c)],ink,.024,y=-.224,name='Hour index')
    line([(0,-.10),(0,.59)],ink,.045,y=-.28,name='Minute hand');line([(-.08,-.05),(.42,.26)],ink,.052,y=-.29,name='Hour hand');disk(0,0,.095,brass,y=-.32)
    for a in [0,120,240]:
        t=math.radians(a);x=.985*math.sin(t);z=.985*math.cos(t)
        line([(x-.07,z-.06),(x,z+.06),(x+.07,z-.06)],glow,.028,y=-.30,name='Arcane rune')
    bevelled_box((0,0,1.16),(.35,.25,.23),brass,.035,'Winding crown')
    torus((0,0,1.40),.19,.055,bronze,'Suspension loop')

def lame_jumelle():
    steel=mat('#9DAFB4');edge=mat('#DCE4DD');dark=mat('#48565A');leather=mat('#78604D');brass=mat('#C3AC7D');glow=accent('#EF715A')
    for side in [-1,1]:
        start=set(bpy.context.scene.objects)
        plate([(-.13,-.35),(-.23,.95),(0,1.66),(.22,.94),(.12,-.35)],.09,steel,'Dagger blade',bevel=.012)
        plate([(0,-.30),(0,1.66),(.22,.94),(.12,-.35)],.015,edge,'Honed facet',y=-.059,bevel=0)
        line([(0,-.12),(0,.98)],dark,.019,y=-.08,name='Blade fuller')
        plate([(-.43,-.34),(-.36,-.22),(.36,-.22),(.43,-.34),(.14,-.43),(-.14,-.43)],.16,brass,'Quillon')
        bevelled_box((0,0,-.80),(.23,.20,.77),leather,.035,'Leather hilt')
        for z in [-.54,-.72,-.90,-1.08]:line([(-.10,z-.035),(.10,z+.035)],brass,.018,y=-.115)
        disk(0,-1.25,.16,dark,y=0,depth=.20)
        line([(.10,.30),(.15,.69)],glow,.026,y=-.09)
        rot=Matrix.Rotation(math.radians(side*39),4,'Y')
        for o in set(bpy.context.scene.objects)-start:o.matrix_world=Matrix.Translation((0,side*.14,0))@rot@o.matrix_world

def venin_concentre():
    glass=mat('#6D8D85');facet=mat('#A7BCAF');dark=mat('#3C5149');liquid=mat('#759557');metal=mat('#B9AE87');glow=accent('#9AC968')
    plate([(-.56,-1.05),(-.69,-.73),(-.61,.28),(-.25,.59),(-.23,1.15),(.21,1.15),(.26,.59),(.63,.27),(.65,-.76),(.44,-1.08)],.42,glass,'Angular poison vessel',bevel=.055)
    plate([(-.48,-.89),(-.54,-.63),(-.49,.03),(.49,.03),(.52,-.64),(.35,-.92)],.02,liquid,'Opaque venom',y=-.24,bevel=.025)
    plate([(-.54,-.66),(-.48,.25),(-.28,.43),(-.30,-.76)],.02,facet,'Worn glass facet',y=-.265,bevel=.015)
    bevelled_box((0,-.01,.90),(.56,.51,.19),metal,.025,'Neck collar')
    plate([(-.25,1.05),(-.23,1.33),(.26,1.33),(.68,1.08),(.64,.88),(.18,1.07)],.32,dark,'Pouring beak',bevel=.035)
    line([(-.41,.06),(.43,.06)],glow,.035,y=-.275,name='Poison meniscus')
    plate([(.70,.81),(.58,.53),(.60,.37),(.73,.30),(.84,.43),(.81,.57)],.12,glow,'Single venom drop',y=-.03,bevel=.022)

def cape_de_brume():
    shadow=mat('#455863');cloth=mat('#82959E');light=mat('#B6C2C4');inside=mat('#26373E');clasp=mat('#B6A482');glow=accent('#5FD4E8')
    silhouette=[(-.43,.82),(-.81,.53),(-.87,-.15),(-1.10,-1.18),(-.75,-1.07),(-.56,-1.35),(-.25,-1.14),(.05,-1.40),(.31,-1.15),(.66,-1.27),(1.05,-.98),(.78,-.41),(.64,.40),(.37,.80)]
    plate(silhouette,.18,shadow,'Tattered mantle',bevel=.024)
    plate([(-.43,.66),(-.69,.37),(-.56,-.47),(-.77,-1.10),(-.49,-1.24),(-.23,-.74),(-.16,.40)],.02,cloth,'Left drape',y=-.12,bevel=.012)
    plate([(.12,.54),(.42,.65),(.59,.22),(.53,-.53),(.91,-.99),(.55,-1.14),(.17,-.66)],.02,cloth,'Right drape',y=-.13,bevel=.012)
    plate([(-.43,.67),(-.52,1.10),(-.26,1.50),(.13,1.60),(.46,1.25),(.46,.76),(.23,.48),(-.22,.48)],.28,cloth,'Angular hood',y=-.02,bevel=.035)
    plate([(-.27,.65),(-.32,1.04),(-.10,1.34),(.13,1.34),(.31,1.07),(.25,.67)],.02,inside,'Hood cavity',y=-.18,bevel=.015)
    line([(-.29,.67),(-.36,1.08),(-.13,1.40)],light,.040,y=-.205,name='Hood folded rim')
    line([(-.49,.34),(-.44,-.20),(-.61,-.87)],light,.027,y=-.16,name='Cloth light fold')
    disk(0,.49,.105,clasp,y=-.25);line([(-.11,.42),(.03,.28),(.17,.41)],glow,.032,y=-.26,name='Mist clasp')

def epines():
    wood=mat('#737462');pale=mat('#B1AB8B');dark=mat('#444C42');glow=accent('#AF715D')
    points=[(-.82,-.86),(-.50,-.39),(-.46,.17),(-.18,.70),(.28,1.02),(.66,.69),(.75,.13),(.52,-.36),(.05,-.61),(-.45,-.36)]
    line(points,wood,.12,y=0,name='Twisted thorn branch')
    line([(-.40,-.33),(.04,.12),(.64,.28),(1.01,.69)],dark,.10,y=.04,name='Forked branch')
    for i,(x,z) in enumerate(points[:-1]):
        a=i*2.13;dx=math.cos(a);dz=math.sin(a)
        plate([(x-dz*.09,z+dx*.09),(x+dx*.51-dz*.12,z+dz*.51+dx*.12),(x+dz*.09,z-dx*.09)],.09,pale,'Long woody thorn',y=-.08,bevel=.009)
    line([(-.48,-.33),(-.39,-.07),(-.43,.15)],glow,.035,y=-.145,name='Ember split')

def rune_de_portee():
    stone=mat('#8D9892');light=mat('#B9C1B3');edge=mat('#4E5C58');groove=mat('#354542');glow=accent('#B296CD')
    pts=[(-.80,-.91),(-1.01,-.33),(-.84,.66),(-.34,1.11),(.46,1.01),(.94,.45),(.87,-.62),(.32,-1.02)]
    plate(pts,.33,edge,'Fractured runestone',bevel=.05)
    plate([(x*.96,z*.96) for x,z in pts],.035,stone,'Stone face',y=-.19,bevel=.023)
    plate([(-.80,.60),(-.34,1.06),(.44,.95),(.21,.74),(-.34,.79)],.015,light,'Broken light edge',y=-.22,bevel=0)
    for r in [.43,.69]:
        ring=[(math.sin(i*math.tau/32)*r,math.cos(i*math.tau/32)*r) for i in range(33)]
        line(ring,groove,.031,y=-.232,name='Concentric carved circle')
    line([(-.29,-.36),(0,.45),(.29,-.36)],glow,.045,y=-.255,name='Range rune');line([(-.18,-.06),(.20,-.06)],glow,.039,y=-.255)
    line([(-.68,-.68),(-.52,-.45),(-.61,-.23)],edge,.020,y=-.235,name='Stone fracture')

def deliver_d(ident):
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    bpy.context.view_layer.update()
    rot=Matrix.Rotation(math.radians(-9),4,'Z')
    for o in objs:o.matrix_world=rot@o.matrix_world
    if ident in {'cristal_de_feu','givre','venin_concentre'}:
        axis=bpy.context.scene.camera.rotation_euler.to_matrix()@Vector((0,0,1))
        tilt=Matrix.Rotation(math.radians(-36 if ident=='givre' else 39),4,axis)
        for o in objs:o.matrix_world=tilt@o.matrix_world
    frame_object_ortho(objs,margin=.075)
    camera=bpy.context.scene.camera;basis=camera.rotation_euler.to_matrix();inv=basis.transposed();graph=bpy.context.evaluated_depsgraph_get();points=[]
    for obj in objs:
        ev=obj.evaluated_get(graph);mesh=ev.to_mesh();points.extend(inv@(obj.matrix_world@v.co) for v in mesh.vertices);ev.to_mesh_clear()
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    camera.location=basis@((lo+hi)*.5+Vector((0,0,10)));camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)/.87
    cel.toon_materials('icon');RAW.mkdir(parents=True,exist_ok=True)
    raw=RAW/(ident+'.png');cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    before=ROOT/'art/renders/items_v2/before';before.mkdir(parents=True,exist_ok=True)
    if not (before/(ident+'.png')).exists():shutil.copy2(DEST/(ident+'.png'),before/(ident+'.png'))
    subprocess.run([PY,'-I',str(Path(__file__).with_name('check_d.py')),'--finalize',ident],check=True)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown item')
    scenes=[]
    for ident in chosen:scenes.append(reset(ident));globals()[ident]();deliver_d(ident)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    out=ROOT/'art/blender/items_v2/lot_d.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out));print('PASS lot_d '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()
