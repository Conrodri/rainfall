"""Eight worn inventory objects, cel render; background Blender only."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from iv2_lib import *
from mathutils import Matrix

IDS=['morsure_vorace','tonique_vital','orbe_de_veille','sang_chaud','marque_du_chasseur','carquois_affute','pointe_perforante','aimant_d_ame']

def accent(color):return mat(color,emit_hex=color,emit_strength=.85)
def rivet(x,z,m,y=-.24):disk(x,z,.045,m,y=y,depth=.035)
def polygon(points,m,name,y=-.15,depth=.08):return plate(points,depth,m,name,y=y,bevel=.018)

def morsure_vorace():
    bone=mat('#CAB98F');light=mat('#EFE0B9');shadow=mat('#776953');iron=mat('#565C59');blood=mat('#762D2D');red=accent('#E45039')
    polygon([(-1.15,.63),(-.90,.88),(-.53,.74),(-.20,.45),(.20,.25),(.70,.28),(1.05,.55),(1.20,.34),(1.10,-.05),(.75,-.38),(.26,-.52),(-.24,-.40),(-.69,-.12),(-1.07,.18)],bone,'Broken monster mandible',depth=.28,y=.02)
    polygon([(-1.04,.47),(-.67,.34),(-.20,-.02),(.30,-.16),(.76,-.08),(1.10,.23),(.87,-.18),(.26,-.36),(-.19,-.27),(-.65,.02)],shadow,'Lower jaw bevel',y=-.14)
    line([(-.96,.55),(-.67,.46),(-.23,.10),(.25,-.03),(.74,.04)],light,.045,y=-.20,name='Worn bone ridge')
    for x,z,h,w in [(-.82,.51,.75,.28),(-.44,.23,.52,.25),(-.02,.06,.45,.24),(.40,.03,.46,.25),(.83,.14,.80,.30)]:
        polygon([(x-w/2,z),(x-w*.38,z+h*.60),(x+w*.15,z+h),(x+w*.30,z+h*.53),(x+w/2,z-.06)],light,'Uneven predatory fang',y=-.10,depth=.16)
        line([(x-w*.15,z+.08),(x-w*.11,z+h*.45)],bone,.020,y=-.20)
    line([(-.80,.03),(-.63,.10),(-.58,-.07)],shadow,.018,y=-.22,name='Bone fracture')
    line([(.75,.62),(.80,.43),(.73,.25)],blood,.046,y=-.21,name='Blood on long fang')
    polygon([(.72,.14),(.59,-.15),(.63,-.32),(.74,-.39),(.85,-.29),(.83,-.14)],red,'Single falling blood drop',y=-.25,depth=.08)

def tonique_vital():
    glass=mat('#899998');rim=mat('#C8D0BB');dark=mat('#384E52');red=mat('#9A3D3D');wine=mat('#592D35');paper=mat('#D1BF96');cork=mat('#94724E');iron=mat('#606359');glow=accent('#F16A45')
    body=[(-.48,-1.05),(-.66,-.82),(-.65,.28),(-.35,.63),(-.28,.92),(.28,.92),(.35,.63),(.65,.28),(.66,-.82),(.48,-1.05)]
    polygon(body,dark,'Thick smoked bottle',y=.03,depth=.48)
    polygon([(x*.89,z*.94) for x,z in body],glass,'Bottle pale glass wall',y=-.24)
    polygon([(-.49,-.88),(-.53,-.65),(-.53,.12),(.53,.12),(.53,-.65),(.43,-.88)],red,'Crimson vital tonic',y=-.30)
    polygon([(-.48,-.85),(-.49,-.45),(.49,-.63),(.40,-.85)],wine,'Deep liquid facet',y=-.35,depth=.015)
    polygon([(-.45,-.48),(-.47,-.04),(.42,.01),(.48,-.48)],paper,'Worn cross label',y=-.39,depth=.035)
    polygon([(-.085,-.40),(-.085,-.27),(-.23,-.27),(-.23,-.12),(-.085,-.12),(-.085,.0),(.08,.0),(.08,-.12),(.23,-.12),(.23,-.27),(.08,-.27),(.08,-.40)],wine,'Apothecary cross',y=-.43,depth=.025)
    bevelled_box((0,0,1.01),(.48,.37,.33),cork,.035,'Chipped cork')
    bevelled_box((0,-.02,.80),(.66,.51,.14),iron,.025,'Neck iron band')
    line([(-.48,-.70),(-.48,.16),(-.29,.42)],rim,.035,y=-.36,name='Thick bottle highlight')
    line([(.40,.14),(.16,.14),(.02,.14)],glow,.042,y=-.37,name='Warm liquid meniscus')

def orbe_de_veille():
    iron=mat('#505A60');brass=mat('#B5A37A');light=mat('#DADEC7');glass=mat('#5B848D');dark=mat('#304650');facet=mat('#91B6BB');glow=accent('#69D5DE')
    polygon([(-.65,-1.00),(-.56,-.77),(-.31,-.63),(-.24,-.35),(.24,-.35),(.31,-.63),(.56,-.77),(.65,-1.00)],iron,'Heavy watch pedestal',y=.02,depth=.38)
    line([(-.57,-.84),(.57,-.84)],brass,.045,y=-.22,name='Pedestal brass lip')
    sphere((0,0,.28),(.79,.55,.79),glass,'Smoky watch orb')
    polygon([(-.63,.53),(-.40,.89),(-.06,1.03),(.36,.86),(.53,.56),(.16,.65),(-.19,.58)],facet,'Broad glass reflection',y=-.43,depth=.015)
    polygon([(-.57,-.01),(-.30,-.36),(.21,-.40),(.58,-.12),(.33,-.20),(-.05,-.20)],dark,'Lower glass plane',y=-.45,depth=.015)
    # Angular eye slit, avoiding a round cartoon pupil.
    polygon([(-.55,.27),(-.28,.47),(.16,.49),(.55,.27),(.23,.07),(-.24,.06)],iron,'Ancient eye socket',y=-.55,depth=.025)
    line([(-.44,.27),(-.20,.37),(.14,.38),(.43,.27)],glow,.041,y=-.60,name='Single cyan eye accent')
    polygon([(-.055,.34),(0,.44),(.055,.34),(.025,.13),(-.025,.13)],light,'Narrow eye slit',y=-.62,depth=.02)
    for side in [-1,1]:
        line([(side*.28,-.55),(side*.62,-.28),(side*.73,.07)],brass,.054,y=-.18,name='Orb retaining claw')
        rivet(side*.34,-.54,light,y=-.25)

def sang_chaud():
    red=mat('#C86C60');dark=mat('#994E51');light=mat('#E39876');edge=mat('#F1BC91');glow=accent('#FF862F')
    pts=[(0,1.26),(-.20,.74),(-.60,.18),(-.75,-.26),(-.64,-.69),(-.30,-.99),(.17,-1.04),(.57,-.82),(.76,-.43),(.70,-.05),(.36,.48)]
    polygon(pts,dark,'Faceted hot blood drop',y=.02,depth=.40)
    polygon([(0,1.10),(-.16,.63),(-.52,.12),(-.59,-.30),(-.45,-.70),(-.12,-.88),(.15,-.90),(.38,-.52),(.33,-.03),(.13,.46)],red,'Crimson broad plane',y=-.22,depth=.025)
    polygon([(-.08,.83),(-.18,.39),(-.46,-.12),(-.38,-.52),(-.18,-.60),(-.25,-.18),(-.04,.35)],light,'Blood cut highlight',y=-.25,depth=.025)
    line([(-.38,-.24),(-.39,-.43),(-.26,-.63)],edge,.028,y=-.29,name='Sharp liquid reflection')
    line([(.14,-.76),(.36,-.53),(.27,-.22),(.34,.02),(.14,.42)],glow,.055,y=-.28,name='Thick ember vein')

def marque_du_chasseur():
    wood=mat('#8B704D');dark=mat('#4D3D30');grain=mat('#B39B70');iron=mat('#68777A');silver=mat('#C3CECC');glow=accent('#E7B74E')
    polygon([(-.77,-.91),(-.86,.77),(-.54,1.00),(.78,.88),(.84,-.78),(.54,-.99)],dark,'Weathered hunter board',y=.03,depth=.24)
    polygon([(-.68,-.80),(-.75,.71),(-.51,.88),(.67,.77),(.72,-.68),(.50,-.87)],wood,'Planed board face',y=-.13)
    for x in [-.35,.27]:line([(x,-.75),(x-.05,-.10),(x+.02,.75)],dark,.018,y=-.20,name='Board joint')
    for x,z in [(-.52,.60),(.53,-.59),(-.49,-.49)]:line([(x,z-.10),(x+.07,z+.15)],grain,.018,y=-.22,name='Scraped wood')
    torus((0,-.27,.03),.55,.065,iron,'Forged sight ring')
    torus((0,-.30,.03),.46,.020,silver,'Worn sight bevel')
    for side in [-1,1]:
        line([(side*.29,.03),(side*.75,.03)],silver,.044,y=-.34,name='Horizontal sight')
        line([(0,.03+side*.28),(0,.03+side*.75)],silver,.044,y=-.34,name='Vertical sight')
    polygon([(-.09,.03),(0,.17),(.09,.03),(0,-.11)],glow,'Golden hunter mark',y=-.37,depth=.035)
    for x,z in [(-.58,.70),(.55,.64),(-.54,-.67),(.55,-.62)]:rivet(x,z,iron,y=-.24)

def carquois_affute():
    leather=mat('#8D6445');shade=mat('#4F3A30');wear=mat('#BA9263');iron=mat('#8F9C9C');steel=mat('#CED5C6');shaft=mat('#B5A17B');feather=mat('#C0C3A9');gold=accent('#E7B65B')
    # Arrow shafts behind the mouth: three large, distinct fletchings.
    for x,top in [(-.27,1.60),(.04,1.78),(.34,1.49)]:
        line([(x,-.05),(x,top)],shaft,.033,y=.09,name='Ash arrow shaft')
        for side in [-1,1]:
            polygon([(x,top-.41),(x+side*.15,top-.25),(x+side*.15,top+.03),(x,top-.10)],feather,'Cut feather vane',y=.07,depth=.035)
        line([(x-.04,top-.39),(x+.04,top-.39)],shade,.023,y=.02,name='Fletching binding')
    polygon([(-.46,.60),(-.36,-1.21),(-.19,-1.40),(.29,-1.35),(.44,-1.16),(.49,.60)],shade,'Deep leather quiver',y=.04,depth=.48)
    polygon([(-.36,.44),(-.26,-1.16),(-.12,-1.26),(.27,-1.21),(.37,-1.08),(.38,.44)],leather,'Leather front panel',y=-.23)
    line([(-.27,.35),(-.17,-1.13),(.24,-1.09)],wear,.026,y=-.29,name='Thick stitched edge')
    for z in [-.94,-.65,-.36,-.07,.22]:line([(-.27,z),(-.18,z+.02)],wear,.018,y=-.30,name='Leather stitch')
    for z in [.50,-1.15]:bevelled_box((.02,-.015,z),(.99,.60,.15),iron,.035,'Metal quiver binding')
    line([(-.36,-.56),(.39,-.22)],shade,.10,y=-.32,name='Diagonal carrying strap')
    polygon([(-.12,-.50),(-.23,-.24),(.11,-.09),(.22,-.35)],iron,'Strap buckle',y=-.43)
    line([(-.08,-.38),(.09,-.30)],gold,.045,y=-.50,name='Gold buckle tongue')
    for x in [-.30,.33]:rivet(x,.50,steel,y=-.35)

def pointe_perforante():
    steel=mat('#91A6AD');light=mat('#DFE6DF');dark=mat('#495961');shaft=mat('#92734F');iron=mat('#696D60');glow=accent('#64CDD9')
    polygon([(0,1.65),(-.51,.20),(-.29,.32),(-.29,-.27),(0,-.51),(.29,-.27),(.29,.32),(.51,.20)],steel,'Long hardened bodkin',y=.01,depth=.24)
    polygon([(0,1.59),(-.06,.14),(-.02,-.40),(-.25,-.21),(-.25,.42)],light,'Honed left ridge',y=-.145,depth=.015)
    polygon([(0,1.59),(.46,.24),(.25,.36),(.25,-.20),(.02,-.40),(.06,.14)],dark,'Tempered right face',y=-.145,depth=.015)
    line([(0,-.43),(0,1.45)],light,.022,y=-.18,name='Central forged ridge')
    bevelled_box((0,0,-.54),(.48,.33,.22),iron,.025,'Arrowhead socket')
    line([(0,-.65),(0,-1.25)],shaft,.095,y=.02,name='Broken arrow shaft')
    for z in [-.75,-.86,-.97]:line([(-.085,z),(.085,z)],iron,.025,y=-.08,name='Socket binding')
    line([(-.33,-1.52),(-.48,-.91),(-.47,-.50)],glow,.039,y=.08,name='Single piercing wake')
    line([(.27,-1.38),(.35,-.96)],steel,.023,y=.06,name='Secondary speed streak')

def aimant_d_ame():
    iron=mat('#929CA8');dark=mat('#505163');purple=mat('#756380');edge=mat('#C6C7C7');glow=accent('#67D0DA')
    pts=[(-.79,.94),(-.35,.94),(-.35,-.20),(-.23,-.43),(.02,-.52),(.26,-.43),(.38,-.20),(.38,.94),(.82,.94),(.82,-.29),(.67,-.67),(.35,-.91),(-.03,-1.00),(-.40,-.88),(-.68,-.63),(-.79,-.24)]
    polygon(pts,dark,'Forged horseshoe magnet',y=.04,depth=.36)
    polygon([(x*.96,z*.96) for x,z in pts],purple,'Patinated violet iron face',y=-.17)
    line([(-.69,.48),(-.69,-.22),(-.56,-.54),(-.28,-.75),(.04,-.81),(.37,-.69),(.62,-.42),(.71,-.18),(.71,.49)],iron,.043,y=-.24,name='Worn horseshoe rim')
    for x in [-.57,.60]:
        bevelled_box((x,-.02,.81),(.49,.44,.39),iron,.025,'Polished magnet pole')
        line([(x-.18,.91),(x+.18,.91)],edge,.023,y=-.26,name='Pole exposed edge')
        rivet(x,-.02,edge,y=-.27)
    # One continuous thick soul wisp suspended between poles.
    line([(-.50,1.02),(-.30,1.30),(.01,1.38),(.28,1.23),(.27,1.03),(.07,.90),(-.02,.68),(.12,.48)],glow,.062,y=-.26,name='Single cyan soul volute')
    line([(-.31,-.63),(-.17,-.54),(-.05,-.62)],edge,.018,y=-.26,name='Forging nick')

def render_icon(ident):
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    bpy.context.view_layer.update()
    yaw=Matrix.Rotation(math.radians(-9),4,'Z')
    for o in objs:o.matrix_world=yaw@o.matrix_world
    angle={'morsure_vorace':-23,'tonique_vital':-12,'orbe_de_veille':0,'sang_chaud':-12,'marque_du_chasseur':-15,'carquois_affute':-38,'pointe_perforante':-40,'aimant_d_ame':-20}[ident]
    camera=bpy.context.scene.camera;basis=camera.rotation_euler.to_matrix()
    tilt=Matrix.Rotation(math.radians(angle),4,basis@Vector((0,0,1)))
    for o in objs:o.matrix_world=tilt@o.matrix_world
    bpy.context.view_layer.update()
    inv=basis.transposed();graph=bpy.context.evaluated_depsgraph_get();points=[]
    for o in objs:
        ev=o.evaluated_get(graph);mesh=ev.to_mesh()
        points.extend(inv@(o.matrix_world@v.co) for v in mesh.vertices);ev.to_mesh_clear()
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
    camera.location=basis@((lo+hi)*.5+Vector((0,0,10)))
    camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)/.865
    cel.toon_materials('icon');RAW.mkdir(parents=True,exist_ok=True)
    raw=RAW/(ident+'.png');cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    before=ROOT/'art/renders/items_v2/before';before.mkdir(parents=True,exist_ok=True)
    if not (before/raw.name).exists():shutil.copy2(DEST/raw.name,before/raw.name)
    subprocess.run([PY,'-I',str(Path(__file__).with_name('check_e.py')),'--finalize',ident],check=True)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown item')
    scenes=[]
    for ident in chosen:
        scenes.append(reset(ident));globals()[ident]();render_icon(ident)
    for s in list(bpy.data.scenes):
        if s not in scenes:bpy.data.scenes.remove(s)
    out=ROOT/'art/blender/items_v2/lot_e.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('PASS lot_e '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()
