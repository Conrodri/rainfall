"""Forge pilot: six crafted inventory icons."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/items_v2'))
from iv2_lib import *

IDS=['meche_silex','rosee_figee','rouage_traque','seve_rampante','ecorce_pluie','prisme_grele']
RAW=ROOT/'art/renders/forge/raw'
DEST=ROOT/'game/assets/sprites/icons/items'
SHEET=ROOT/'art/renders/forge/f3_contact.png'

def meche_silex():
    stone=mat('#9CAEB1'); facet=mat('#CED7CE'); rope=mat('#C7AC79'); ember=mat('#FF7A1F',emit_hex='#FF7A1F',emit_strength=1.15)
    plate([(-.65,-.52),(-.36,.18),(.88,.92),(.48,-.12),(-.10,-.63)],.23,stone,'Diagonal flint',bevel=.025)
    plate([(-.52,-.46),(.79,.81),(-.08,-.46)],.025,facet,'Flaked cutting edge',y=-.16,bevel=.01)
    line([(-.22,-.36),(.16,-.12),(.28,.24)],mat('#75888B'),.018,y=-.19,name='Flint fracture')
    for j in range(3):
        line([(-.44+j*.06,-.53),(-.57+j*.06,-.70),(-.80+j*.06,-.72),(-.88+j*.06,-.91)],rope,.035,y=-.12-j*.015,name='Braided short fuse')
    sphere((-.82,-.16,-.92),(.085,.065,.075),ember,'Ember')


def rosee_figee():
    iron=mat('#B3C8C7',metal=.6);ice=mat('#83BFCD');pale=mat('#E2F0DF');cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.65)
    # Rounded lower bowl, continuous taper to a single upper point.
    pts=[(0,1.04),(.18,.65),(.40,.29),(.54,-.06)]
    pts += [(.54*math.cos(t),-.13+.56*math.sin(t)) for t in [0,-.25,-.5,-.75,-1,-1.25,-1.57,-1.89,-2.14,-2.39,-2.64,-2.89,-math.pi]]
    pts += [(-.40,.29),(-.18,.65)]
    plate(pts,.23,iron,'Dew iron setting',bevel=.045)
    plate([(x*.86,z*.86) for x,z in pts],.055,ice,'Rounded frozen dew',y=-.16,bevel=.04)
    line([(-.32,-.28),(-.36,-.05),(-.26,.27),(-.08,.59)],pale,.035,y=-.22,name='Dew reflection')
    sphere((.16,-.24,-.30),(.15,.04,.23),cyan,'Cyan frost accent')


def rouage_traque():
    iron=mat('#BCAA71',metal=.7);brass=mat('#CDB878',metal=.72);worn=mat('#EEE0A8',metal=.65);copper=mat('#D9803A',metal=.7);cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.22)
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
    line([(.49,.12),(.93,.08),(1.13,-.14),(1.10,-.43),(.90,-.50),(.85,-.32)],iron,.12,y=-.03,name='Tracking hook')
    line([(.94,-.42),(1.03,-.33),(1.04,-.14)],worn,.027,y=-.13,name='Hook sharpened edge')
    for a in [45,135,225,315]:
        t=math.radians(a);disk(.69*math.cos(t),.69*math.sin(t),.055,copper,y=-.32,depth=.04)
    disk(-.30,.32,.035,cyan,y=-.34,depth=.02)

def seve_rampante():
    bark=mat('#B8AE82');mid=mat('#9FAE7C');light=mat('#E0DCAC');copper=mat('#D9803A',metal=.55);sap=mat('#7FA35B',emit_hex='#A5E65B',emit_strength=1.5)
    line([(-.58,-.80),(-.38,-.44),(-.48,-.08),(-.24,.22),(-.32,.56),(.02,.83)],bark,.205,name='Knotted root')
    line([(-.48,-.35),(-.08,-.23),(.22,-.42),(.45,-.26),(.52,.06),(.34,.31),(.50,.56),(.78,.69)],mid,.155,y=-.05,name='Creeping tendril')
    line([(-.67,-.58),(-.48,-.31),(-.57,-.07),(-.33,.25),(-.40,.55),(-.09,.82)],light,.075,y=-.22,name='Root ridge')
    line([(-.03,-.17),(.23,-.34),(.40,-.20),(.46,.05)],light,.039,y=-.205,name='Tendril lit edge')
    line([(-.28,.27),(-.05,.19),(.10,.03),(.15,-.17)],sap,.066,y=-.285,name='Seeping sap')
    sphere((.15,-.31,-.23),(.145,.085,.205),sap,'Sap bead')
    for x,z in [(-.43,-.39),(-.17,.30),(.34,-.30)]:disk(x,z,.065,copper,y=-.28,depth=.035)


def ecorce_pluie():
    bark=mat('#B8A482'); face=mat('#CEBA95'); bronze=mat('#AABD9B',metal=.6);cyan=mat('#5FD4E8')
    pts=[(-.65,.80),(.65,.80),(.61,-.03),(.36,-.65),(0,-.99),(-.36,-.65),(-.61,-.03)]
    plate(pts,.24,bronze,'Shield brass frame',bevel=.045)
    plate([(x*.86,z*.88) for x,z in pts],.08,bark,'Pale bark shield',y=-.18,bevel=.03)
    for x in [-.30,0,.30]:
        line([(x,.62),(x-.04,.17),(x+.025,-.24),(x*.5,-.57)],face,.055,y=-.25,name='Raised bark grain')
    for x,z,r in [(-.32,.46,.085),(.22,.26,.09),(-.12,-.26,.07),(.13,-.51,.06)]:sphere((x,-.32,z),(r,.045,r*1.3),cyan,'Rain pearl')


def prisme_grele():
    ice=mat('#91AEBE');facet=mat('#C5DEDF');pale=mat('#E8F1E4');cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=.65)
    # Three faceted points, open fan; no vertical single jewel.
    for x,z,h,r,angle in [(-.40,.05,1.62,.24,-.58),(.02,.09,1.95,.26,.26),(.42,-.10,1.48,.23,.94)]:
        o=crystal((x,0,z),r,h,ice,'Fan hail crystal');o.rotation_euler.y=angle
        o=crystal((x,-.13,z),r*.60,h*.94,facet,'Cold front facet');o.rotation_euler.y=angle
    line([(-.50,-.52),(-.17,-.68),(.22,-.61),(.53,-.40)],pale,.055,y=-.23,name='Frost binding')
    for x,z in [(-.28,-.39),(.09,-.47),(.39,-.27)]:sphere((x,-.28,z),(.07,.04,.10),cyan,'Cyan ice seed')


BUILDERS={k:v for k,v in list(globals().items()) if k in IDS}

def reset_forge(ident):
    scene=bpy.data.scenes.new(ident);bpy.context.window.scene=scene
    reset_scene();setup_render(256);cel.setup_scene(samples=8)
    scene.view_layers[0].use_pass_normal=False
    scene.render.image_settings.compression=100
    scene.camera.location=(0,-10,1.2);aim(scene.camera,(0,0,0))
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
    prof=dict(cel.profile('icon'),creases=False,ink_px=1.0)
    cel.INK_RGB=rgba('#E5E7C8')[:3]
    cel.toon_materials(prof);frame_object_ortho(objs,margin=.095)
    path=DEST/(ident+'.png');scene=bpy.context.scene
    cel.cel_passes(path,prof,base_configure=passes,normals=False)
    scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    if ident in {'meche_silex','rosee_figee','prisme_grele'}:
        tree=scene.compositing_node_group
        rl=next(n for n in tree.nodes if n.bl_idname=='CompositorNodeRLayers')
        out=next(n for n in tree.nodes if n.bl_idname=='NodeGroupOutput')
        old=out.inputs['Image'].links[0].from_socket
        alpha=tree.nodes.new('CompositorNodeSetAlpha');alpha.inputs['Type'].default_value='Replace Alpha'
        tree.links.new(rl.outputs[cel.AOV],alpha.inputs['Image']);tree.links.new(rl.outputs['Alpha'],alpha.inputs['Alpha'])
        tree.links.new(alpha.outputs[0],out.inputs['Image'])
        scene.render.filepath=str(DEST/(ident+'_e.png'));bpy.ops.render.render(write_still=True)
        tree.links.new(old,out.inputs['Image']);tree.nodes.remove(alpha)


def verify_contact():
    import subprocess
    subprocess.run([PY,"-c","import sys,hashlib,itertools,warnings\nwarnings.filterwarnings('ignore',category=DeprecationWarning)\nfrom pathlib import Path\nroot=Path(sys.argv[1]);sys.path.insert(0,str(root/'art/tools/vendor'))\nfrom PIL import Image\nids=['meche_silex','rosee_figee','rouage_traque','seve_rampante','ecorce_pluie','prisme_grele']\ndest=root/'game/assets/sprites/icons/items';sheet=Image.new('RGBA',(768,512),'#30201C');masks={};hashes=set()\nfor j,i in enumerate(ids):\n p=dest/(i+'.png');im=Image.open(p).convert('RGBA');assert im.size==(256,256) and p.stat().st_size<=60*1024\n bb=im.getchannel('A').getbbox();assert bb and min(bb[0],bb[1],256-bb[2],256-bb[3])>=14,(i,bb)\n assert im.getchannel('A').getextrema()==(0,255)\n hashes.add(hashlib.sha256(im.tobytes()).hexdigest())\n masks[i]=[v>128 for v in im.getchannel('A').resize((48,48),Image.Resampling.LANCZOS).getdata()]\n sheet.alpha_composite(im,((j%3)*256,(j//3)*256))\n if i in {'meche_silex','rosee_figee','prisme_grele'}:\n  e=Image.open(dest/(i+'_e.png')).convert('RGBA');assert e.size in [(128,128),(256,256)]\n  assert any(max(r,g,b)>0 and a>0 for r,g,b,a in e.getdata())\n  assert e.getchannel('A').tobytes()==im.getchannel('A').tobytes()\nassert len(hashes)==6\n(root/'art/renders/forge').mkdir(parents=True,exist_ok=True)\nsheet.save(root/'art/renders/forge/f3_contact.png')\nfor i in ids:\n vals=[]\n for k in ids:\n  if k!=i:\n   a,b=masks[i],masks[k];vals.append(sum(x and y for x,y in zip(a,b))/sum(x or y for x,y in zip(a,b)))\n p=dest/(i+'.png');e=dest/(i+'_e.png')\n print(i+' IoU48='+format(max(vals),'.3f')+' Ko='+format(p.stat().st_size/1024,'.2f')+(' _e='+format(e.stat().st_size/1024,'.2f') if i in {'meche_silex','rosee_figee','prisme_grele'} else ''))\nprint('PASS dimensions alpha margins distinct emission contact')\n",str(ROOT)],check=True)

def main():
    chosen=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else IDS
    if set(chosen)-set(IDS):raise ValueError('Unknown forge item')
    scenes=[]
    for ident in chosen:
        scenes.append(reset_forge(ident));BUILDERS[ident]();deliver(ident)
    for scene in list(bpy.data.scenes):
        if scene not in scenes:bpy.data.scenes.remove(scene)
    out=ROOT/'art/blender/forge/f3_icons.blend';out.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(out))
    verify_contact()
    print('PASS forge f3 '+str(len(chosen))+' icons',flush=True)
if __name__=='__main__':main()
