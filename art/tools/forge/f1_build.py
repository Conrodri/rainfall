"""Forge pilot: six crafted inventory icons."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/items_v2'))
from iv2_lib import *

IDS=['meche_silex','rosee_figee','rouage_traque','seve_rampante','ecorce_pluie','prisme_grele']
RAW=ROOT/'art/renders/forge/raw'
DEST=ROOT/'game/assets/sprites/icons/items'
SHEET=ROOT/'art/renders/forge/f1_contact.png'

def meche_silex():
    iron=mat('#25292A',metal=.58);steel=mat('#515B5A',metal=.65);rope=mat('#8B6240');copper=mat('#D9803A',metal=.65);ember=mat('#FF7A1F',emit_hex='#FF7A1F',emit_strength=1.15)
    plate([(-.88,-.35),(-.65,.1),(-.28,.38),(.08,.30),(.46,.05),(.83,-.25),(.50,-.62),(.04,-.82),(-.45,-.70)],.30,iron,'Black flint',bevel=.035)
    line([(-.58,-.35),(-.32,-.12),(-.05,.03),(.29,-.17),(.57,-.40)],steel,.035,y=-.18,name='Flint edge')
    # Coiled mine fuse, clearly open at center.
    for r,y in [(.43,-.29),(.33,-.34),(.23,-.39)]:
        torus((-.02,y,.28),r,.075,rope,'Coiled fuse')
    line([(.38,.51),(.62,.55),(.73,.67)],ember,.045,y=-.35,name='Smoldering tip')
    for x,z in [(-.51,-.42),(.47,-.48)]:disk(x,z,.075,copper,y=-.35,depth=.055)

def rosee_figee():
    iron=mat('#272D30',metal=.7);ice=mat('#72909A',metal=.15);pale=mat('#B8D9DA');copper=mat('#D9803A',metal=.65);cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.6)
    torus((0,0,0),.79,.115,iron,'Dark iron setting')
    torus((0,-.03,0),.69,.035,copper,'Copper rim')
    crystal((0,-.02,.06),.58,1.72,ice,'Frost crystal')
    sphere((0,-.39,.08),(.31,.12,.43),cyan,'Frozen dew')
    plate([(-.30,-.15),(-.14,.57),(.02,.77),(.10,.27)],.015,pale,'Ice facet',y=-.44,bevel=0)
    for a in [35,155,275]:
        t=math.radians(a);disk(.77*math.cos(t),.77*math.sin(t),.085,copper,y=-.18,depth=.08)

def rouage_traque():
    iron=mat('#323738',metal=.7);brass=mat('#AD8951',metal=.72);worn=mat('#D0AF70',metal=.65);copper=mat('#D9803A',metal=.7);cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.22)
    # Eight hunting teeth on a stout gear.
    pts=[]
    for i in range(32):
        a=i*math.tau/32;r=.82 if i%4 in (0,1) else .64
        pts.append((r*math.cos(a),r*math.sin(a)))
    plate(pts,.25,iron,'Hunting gear',bevel=.03)
    disk(0,0,.55,brass,y=-.17,depth=.12);disk(0,0,.37,iron,y=-.25,depth=.08)
    disk(0,0,.13,worn,y=-.31,depth=.09)
    for a in range(0,360,60):
        t=math.radians(a);line([(.17*math.cos(t),.17*math.sin(t)),(.48*math.cos(t),.48*math.sin(t))],worn,.035,y=-.30,name='Gear spoke')
    # Hook curves outward from lower hub.
    line([(.04,-.20),(.15,-.53),(.39,-.72),(.60,-.66),(.69,-.48)],iron,.12,y=-.03,name='Tracking hook')
    line([(.50,-.65),(.64,-.50),(.70,-.34)],worn,.027,y=-.13,name='Hook sharpened edge')
    for a in [45,135,225,315]:
        t=math.radians(a);disk(.69*math.cos(t),.69*math.sin(t),.055,copper,y=-.32,depth=.04)
    disk(-.30,.32,.035,cyan,y=-.34,depth=.02)

def seve_rampante():
    bark=mat('#363B2D');mid=mat('#68704D');light=mat('#B0B780');copper=mat('#D9803A',metal=.55);sap=mat('#7FA35B',emit_hex='#A5E65B',emit_strength=1.5)
    line([(-.58,-.80),(-.38,-.44),(-.48,-.08),(-.24,.22),(-.32,.56),(.02,.83)],bark,.205,name='Knotted root')
    line([(-.48,-.35),(-.08,-.23),(.22,-.42),(.45,-.26),(.52,.06),(.34,.31),(.50,.56),(.78,.69)],mid,.155,y=-.05,name='Creeping tendril')
    line([(-.67,-.58),(-.48,-.31),(-.57,-.07),(-.33,.25),(-.40,.55),(-.09,.82)],light,.075,y=-.22,name='Root ridge')
    line([(-.03,-.17),(.23,-.34),(.40,-.20),(.46,.05)],light,.039,y=-.205,name='Tendril lit edge')
    line([(-.28,.27),(-.05,.19),(.10,.03),(.15,-.17)],sap,.066,y=-.285,name='Seeping sap')
    sphere((.15,-.31,-.23),(.145,.085,.205),sap,'Sap bead')
    for x,z in [(-.43,-.39),(-.17,.30),(.34,-.30)]:disk(x,z,.065,copper,y=-.28,depth=.035)


def ecorce_pluie():
    bark=mat('#514337');face=mat('#796249');dark=mat('#342F2A');bronze=mat('#657B67',metal=.68);copper=mat('#D9803A',metal=.68);cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.55)
    plate([(-.78,-.48),(-.67,.25),(-.34,.59),(.30,.62),(.73,.24),(.78,-.36),(.32,-.66),(-.31,-.67)],.23,dark,'Bark slab',bevel=.06)
    plate([(-.65,-.40),(-.55,.22),(-.29,.48),(.25,.50),(.59,.19),(.63,-.28),(.27,-.51),(-.25,-.52)],.045,face,'Raised bark',y=-.15,bevel=.04)
    torus((0,-.16,0),.68,.085,bronze,'Verdigris bronze ring')
    torus((0,-.22,0),.56,.027,copper,'Copper maker rim')
    line([(-.35,.35),(-.18,.12),(-.29,-.16),(.02,-.40),(.30,-.14)],bark,.055,y=-.25,name='Bark cleft')
    for x,z,r in [(-.38,.34,.095),(.19,.38,.075),(.43,-.12,.11),(-.22,-.39,.08)]:sphere((x,-.31,z),(r,.045,r*1.25),cyan,'Pearled rain')
    for x,z in [(-.57,0),(.50,.23),(0,-.58)]:disk(x,z,.052,copper,y=-.32,depth=.04)

def prisme_grele():
    iron=mat('#303639',metal=.7);ice=mat('#61777D',metal=.22);facet=mat('#8EA8A9',metal=.2);pale=mat('#C6D9D4');copper=mat('#D9803A',metal=.7);cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.55)
    # Tall smoke-glass angular prism in a dark iron cradle.
    crystal((0,0,.05),.66,1.72,ice,'Smoked hail prism')
    plate([(-.32,-.36),(-.20,.36),(0,.69),(.17,.20),(.10,-.48)],.025,facet,'Glass facet',y=-.42,bevel=0)
    plate([(-.15,-.45),(.12,-.37),(.38,.30),(.12,.20)],.02,pale,'Cold facet',y=-.45,bevel=0)
    line([(-.63,-.03),(-.48,-.59),(0,-.77),(.48,-.59),(.63,-.03)],iron,.085,y=-.03,name='Iron lower cradle')
    line([(-.58,.18),(-.48,.67),(-.30,.81)],iron,.075,y=-.02,name='Iron upper arm')
    line([(.58,.18),(.48,.67),(.30,.81)],iron,.075,y=-.02,name='Iron upper arm')
    for x,z in [(-.50,-.54),(.50,-.54),(0,.76)]:disk(x,z,.09,copper,y=-.18,depth=.075)
    for x,z,s in [(-.84,.25,.13),(.82,.40,.12),(-.78,-.45,.11),(.83,-.43,.14)]:
        sphere((x,-.24,z),(s,s*.8,s),cyan,'Hailstone')

BUILDERS={k:v for k,v in list(globals().items()) if k in IDS}

def reset_forge(ident):
    scene=bpy.data.scenes.new(ident);bpy.context.window.scene=scene
    reset_scene();setup_render(512);cel.setup_scene(samples=16)
    for obj in scene.objects:
        if obj.type=='LIGHT':
            warm='chaud' in obj.name
            obj.data.color=rgba('#FFC287' if warm else '#80A8D9')[:3]
            obj.data.energy=2.5 if warm else .35;obj.data.angle=math.radians(8)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.15
    return scene

def passes(path):
    tree=bpy.data.node_groups.new('Forge cel image passthrough','CompositorNodeTree');bpy.context.scene.compositing_node_group=tree
    tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    rl=tree.nodes.new('CompositorNodeRLayers');out=tree.nodes.new('NodeGroupOutput');tree.links.new(rl.outputs['Image'],out.inputs['Image'])

def deliver(ident):
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    cel.toon_materials('icon');frame_object_ortho(objs,margin=.15)
    RAW.mkdir(parents=True,exist_ok=True);raw=RAW/(ident+'.png')
    cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    # Pillow runs in the configured standalone Python, as in the items_v2 pipeline.
    import subprocess
    subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-I',str(Path(__file__).with_name('f1_finalize.py')),str(raw),str(DEST/(ident+'.png'))],check=True)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown forge item')
    scenes=[]
    for ident in chosen:
        scenes.append(reset_forge(ident));BUILDERS[ident]();deliver(ident)
    for scene in list(bpy.data.scenes):
        if scene not in scenes:bpy.data.scenes.remove(scene)
    out=ROOT/'art/blender/forge/f1.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    print('PASS forge f1 '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()
