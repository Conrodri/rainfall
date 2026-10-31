"""Lot G: cel relics; background Blender only."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from iv2_lib import *
from mathutils import Matrix, Vector
IDS=['phenix_de_poche','rafale_d_acier','coeur_du_chronomancien','couronne_d_echo','nova_infinie','armure_du_colosse']

def palette():
    return [mat(c) for c in ['#535F66','#A9BBC0','#E3DED0','#C7A56C','#756047','#30383C']]

def ring(x,z,r,thick,m,y=-.2,name='Forged ring'):
    return torus((x,y,z),r,thick,m,name)

def polygon(cx,cz,r,n=12):
    return [(cx+r*math.sin(i*2*math.pi/n),cz+r*math.cos(i*2*math.pi/n)) for i in range(n)]

def phenix_de_poche():
    iron,steel,ivory,gold,bronze,dark=palette();fire=mat('#FF7A1F',emit_hex='#FF7A1F',emit_strength=1)
    disk(0,-.10,1.03,bronze,y=.08,depth=.17);disk(0,-.10,.91,dark,y=-.025)
    ring(0,-.10,.98,.065,gold,y=-.055)
    # Heraldic hooked head, swept wings, three tapering tail feathers.
    bird=[(-.13,-.31),(-.47,-.90),(-.39,-.37),(-.68,-.72),(-.56,-.19),(-.91,.12),(-1.13,.64),(-.82,.45),(-1.02,.98),(-.62,.70),(-.69,1.23),(-.31,.81),(-.16,.34),(.03,.21),(.14,.58),(.09,.87),(.29,1.02),(.47,.94),(.64,.70),(.38,.74),(.32,.46),(.29,.14),(.48,.42),(.73,.77),(.88,1.16),(.98,.72),(1.16,.92),(1.07,.43),(1.27,.53),(1.04,.06),(.59,-.20),(.40,-.37),(.40,-.83),(.13,-.54),(.03,-1.07),(-.08,-.62)]
    plate(bird,.12,gold,'Forged phoenix relief',y=-.16,bevel=.022)
    plate([(-.13,-.31),(-.21,.08),(-.46,.44),(-.61,.82),(-.36,.61),(-.17,.16),(.06,.06),(.24,.39),(.21,-.22),(.03,-.56)],.025,fire,'Single ember feather',y=-.245)
    for side in [-1,1]:
        line([(side*.37,-.03),(side*.67,.15),(side*.88,.49)],ivory,.023,y=-.25,name='Wing ridge')
    disk(.32,.86,.025,dark,y=-.25,depth=.015)
    for a in [135,225,315]:
        t=math.radians(a);disk(.98*math.sin(t),-.1+.98*math.cos(t),.045,steel,y=-.14)

def rafale_d_acier():
    iron,steel,ivory,gold,bronze,dark=palette();glow=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.9)
    for j,angle in enumerate([-23,0,23]):
        made=set(bpy.context.scene.objects);yy=(j-1)*.13
        line([(0,-1.30),(0,.83)],iron,.085,y=yy,name='Steel bolt shaft')
        line([(-.018,-.88),(-.018,.78)],steel,.032,y=yy-.08,name='Shaft light edge')
        plate([(-.23,.71),(0,1.48),(.23,.71),(0,.83)],.11,steel,'Barbed steel point',y=yy,bevel=.016)
        plate([(0,.84),(0,1.43),(.20,.73)],.012,ivory,'Honed facet',y=yy-.065,bevel=0)
        for side in [-1,1]:
            plate([(0,-.70),(side*.28,-.95),(side*.28,-1.36),(0,-1.16)],.055,bronze,'Metal fletching',y=yy)
        line([(-.13,.78),(0,.87),(.13,.78)],glow,.035,y=yy-.085,name='Charged broadhead collar')
        rot=Matrix.Rotation(math.radians(angle),4,'Y')
        for o in set(bpy.context.scene.objects)-made:o.matrix_world=rot@o.matrix_world

def coeur_du_chronomancien():
    iron,steel,ivory,gold,bronze,dark=palette();cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.9)
    ring(0,0,1.11,.075,bronze,y=.08);ring(0,0,1.03,.024,gold,y=-.015)
    for cx,cz,r in [(-.70,-.53,.38),(.72,.53,.37),(.67,-.60,.30)]:
        ring(cx,cz,r,.075,gold,y=-.03)
        for i in range(10):
            a=i*2*math.pi/10
            o=bevelled_box((cx+(r+.035)*math.sin(a),-.03,cz+(r+.035)*math.cos(a)),(.13,.12,.15),bronze,.012,'Gear tooth');o.rotation_euler.y=a
        disk(cx,cz,.105,steel,y=-.11)
        for a in [0,120,240]:
            t=math.radians(a);line([(cx,cz),(cx+r*.82*math.sin(t),cz+r*.82*math.cos(t))],gold,.033,y=-.08,name='Gear spoke')
    shape=[(0,-.88),(-.70,-.12),(-.73,.37),(-.46,.65),(-.17,.64),(0,.42),(.20,.65),(.48,.64),(.74,.35),(.66,-.12)]
    plate(shape,.27,bronze,'Heart bezel',y=-.19,bevel=.035)
    plate([(x*.88,z*.89) for x,z in shape],.10,gold,'Golden heart crystal',y=-.39,bevel=.02)
    plate([(0,-.73),(-.59,-.08),(-.60,.32),(-.37,.51),(-.12,.50),(0,.30)],.01,ivory,'Crystal lit plane',y=-.45,bevel=0)
    plate([(0,-.73),(0,.30),(.19,.53),(.41,.52),(.60,.31),(.52,-.08)],.01,bronze,'Crystal shadow plane',y=-.451,bevel=0)
    line([(-.10,.38),(.02,.13),(-.09,-.10),(.06,-.49)],cyan,.044,y=-.48,name='Time fissure')
    for i in range(12):
        a=i*math.pi/6;line([(1.01*math.sin(a),1.01*math.cos(a)),(.92*math.sin(a),.92*math.cos(a))],steel,.018,y=-.10,name='Time indices')

def crown_shape(dx,dz,scale,m,y):
    pts=[(-.87,-.47),(-1.02,.45),(-.53,.10),(-.44,.71),(-.08,.30),(.23,.92),(.48,.30),(.98,.62),(.81,-.47)]
    plate([(x*scale+dx,z*scale+dz) for x,z in pts],.12,m,'Crown pointed band',y=y,bevel=.023)

def couronne_d_echo():
    iron,steel,ivory,gold,bronze,dark=palette();cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.85)
    # Three stepped metal echoes, restrained cyan patina; solid main crown in front.
    for i,c in [(3,'#466268'),(2,'#66888C'),(1,'#85A7A6')]:
        crown_shape(-i*.15,i*.20,.94,mat(c),.08+i*.14)
    crown_shape(.10,-.18,1,gold,-.30)
    plate([(-.77,-.51),(.90,-.51),(.85,-.73),(-.73,-.73)],.14,bronze,'Heavy crown rim',y=-.34)
    line([(-.72,-.53),(.83,-.53)],ivory,.030,y=-.43,name='Worn rim')
    plate([(.10,-.43),(-.03,-.20),(.10,.04),(.23,-.20)],.065,cyan,'Single echo jewel',y=-.41)
    for x,z in [(-.65,-.23),(.66,-.23)]:disk(x,z,.055,steel,y=-.40)
    line([(-.78,.76),(-.73,.97),(-.60,.79)],cyan,.026,y=.27,name='Echo edge')

def nova_infinie():
    iron,steel,ivory,gold,bronze,dark=palette();glow=mat('#FF7A1F',emit_hex='#FF7A1F',emit_strength=1)
    red=mat('#B8633D');cyan=mat('#72AEB5');green=mat('#84966D')
    # Three solid orbital bands, distinct hues, one orange luminous core.
    for angle,m,yy in [(20,red,.08),(-47,cyan,-.02),(83,green,.18)]:
        a=math.radians(angle);pts=[]
        for i in range(65):
            t=i*2*math.pi/64;x=1.20*math.cos(t);z=.47*math.sin(t)
            pts.append((x*math.cos(a)-z*math.sin(a),yy+.32*math.sin(t),x*math.sin(a)+z*math.cos(a)))
        curve(pts,.058,m,'Orbital band')
    sphere((0,-.10,0),(.47,.35,.47),bronze,'Nova iron cage')
    star=[]
    for i in range(16):
        a=2*math.pi*i/16;r=.73 if i%4==0 else (.53 if i%2==0 else .27)
        star.append((r*math.sin(a),r*math.cos(a)))
    plate(star,.12,gold,'Faceted nova rays',y=-.43,bevel=.013)
    plate([(0,.45),(-.22,.08),(-.16,-.21),(0,-.41),(.23,-.02)],.06,glow,'Single burning core',y=-.52,bevel=.015)
    for x,z,m in [(-1.08,-.39,red),(.78,-.77,cyan),(.13,1.18,green)]:sphere((x,-.1,z),(.10,.08,.10),m,'Orbit anchor')

def armure_du_colosse():
    iron,steel,ivory,gold,bronze,dark=palette();glow=mat('#F2C14E',emit_hex='#F2C14E',emit_strength=.8)
    torso=[(-.46,1.04),(-.70,.82),(-.66,.23),(-.49,-.57),(-.63,-.98),(0,-1.15),(.63,-.98),(.49,-.57),(.66,.23),(.70,.82),(.46,1.04),(.26,.79),(-.26,.79)]
    plate(torso,.46,iron,'Massive slate cuirass',bevel=.04)
    plate([(-.52,.64),(-.39,-.43),(0,-.70),(0,.55),(-.28,.70)],.035,steel,'Left breast plane',y=-.26,bevel=.015)
    plate([(0,.55),(0,-.70),(.39,-.43),(.52,.64),(.28,.70)],.035,mat('#7A8C95'),'Right breast plane',y=-.26)
    line([(-.46,.99),(-.25,.77),(.25,.77),(.46,.99)],ivory,.035,y=-.29,name='Gorget edge')
    for side in [-1,1]:
        def pts(seq):return [(side*x,z) for x,z in seq]
        plate(pts([(.58,.88),(.88,1.06),(1.21,.81),(1.36,.32),(1.22,.13),(.72,.31)]),.45,iron,'Colossus pauldron',y=.015,bevel=.035)
        plate(pts([(.67,.82),(.88,.96),(1.14,.76),(1.24,.46),(.76,.52)]),.04,steel,'Shoulder top facet',y=-.24)
        line(pts([(.77,.37),(1.28,.23)]),bronze,.035,y=-.25,name='Shoulder overlapping lip')
        for x,z in [(.82,.68),(1.14,.50),(.44,-.79)]:disk(side*x,z,.043,gold,y=-.30)
    for z,w in [(-.64,.47),(-.85,.54),(-1.04,.61)]:
        line([(-w,z),(0,z-.13),(w,z)],steel,.037,y=-.28,name='Articulated fauld')
    plate([(-.14,.39),(0,.50),(.14,.39),(.10,.16),(0,.08),(-.10,.16)],.06,bronze,'Chest seal',y=-.32)
    line([(0,.40),(0,.19)],glow,.040,y=-.38,name='Golden seal slit')
    for x,z in [(-.30,.20),(.31,-.30)]:line([(x-.07,z+.08),(x+.04,z-.03)],dark,.014,y=-.30,name='Plate scar')

def deliver_g(ident):
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    bpy.context.view_layer.update();rotation=Matrix.Rotation(math.radians(-7),4,'Z')
    for o in objs:o.matrix_world=rotation@o.matrix_world
    if ident=='rafale_d_acier':
        axis=bpy.context.scene.camera.rotation_euler.to_matrix()@Vector((0,0,1));tilt=Matrix.Rotation(math.radians(-38),4,axis)
        for o in objs:o.matrix_world=tilt@o.matrix_world
    frame_object_ortho(objs,margin=.08)
    camera=bpy.context.scene.camera;basis=camera.rotation_euler.to_matrix();inv=basis.transposed()
    graph=bpy.context.evaluated_depsgraph_get();points=[]
    for obj in objs:
        evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh();points.extend(inv@(obj.matrix_world@v.co) for v in mesh.vertices);evaluated.to_mesh_clear()
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    camera.location=basis@((lo+hi)*.5+Vector((0,0,10)));camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)/.865
    cel.toon_materials('icon');RAW.mkdir(parents=True,exist_ok=True)
    raw=RAW/(ident+'.png');cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    before=ROOT/'art/renders/items_v2/before';before.mkdir(parents=True,exist_ok=True)
    if not (before/(ident+'.png')).exists():shutil.copy2(DEST/(ident+'.png'),before/(ident+'.png'))
    subprocess.run([PY,'-I',str(Path(__file__).with_name('check_g.py')),'--finalize',ident],check=True)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown item')
    scenes=[]
    for ident in chosen:scenes.append(reset(ident));globals()[ident]();deliver_g(ident)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    out=ROOT/'art/blender/items_v2/lot_g.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out));print('PASS lot_g '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()

