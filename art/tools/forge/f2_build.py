import sys, math, subprocess
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/items_v2'))
from iv2_lib import *
OUT=ROOT/'game/assets/sprites/icons'; PICK=ROOT/'game/assets/sprites/pickups'; RAW=ROOT/'art/renders/forge/raw_f2'

def setup(name,size=512):
 s=bpy.data.scenes.new(name); bpy.context.window.scene=s; reset_scene(); setup_render(size); cel.setup_scene(samples=16); s.world.node_tree.nodes['Background'].inputs[1].default_value=.15
 for light in s.objects:
  if light.type=='LIGHT' and light.data.type=='SUN':
   warm='chaud' in light.name.lower();light.data.color=(1,.57,.29) if warm else (.35,.7,.9);light.data.energy=2.5 if warm else .45
 return s

def make_core(pickup=False):
 iron=mat('#202629',rough=.38,metal=.82); facets=mat('#394346',rough=.4,metal=.75); copper=mat('#D9803A',rough=.32,metal=.7); cyan=mat('#5FD4E8',emit_hex='#5FD4E8',emit_strength=2.0)
 sphere((0,0,0),(.83,.7,.83),iron,'Storm iron core')
 for x,z,rx,rz in [(-.42,.38,.35,.27),(.34,.42,.38,.25),(-.49,-.17,.3,.34),(.42,-.22,.34,.34),(0,-.56,.32,.16)]:
  o=sphere((x,-.43,z),(rx,.10,rz),facets,'Raised shell');o.rotation_euler.y=math.radians((x-z)*20)
 ring=torus((0,-.12,0),.78,.105,copper,'Copper band');ring.rotation_euler.x=math.radians(72)
 branches=[[(-.08,.81),(-.02,.49),(-.24,.26),(-.13,-.02),(-.43,-.39)],[(-.02,.49),(.22,.38),(.18,.13),(.42,-.12),(.32,-.52)],[(-.24,.26),(-.47,.12),(-.36,-.12),(-.62,-.3)],[(.18,.13),(.02,-.07),(.08,-.31),(-.12,-.55)]]
 for i,p in enumerate(branches):
  line(p,cyan,.022,y=-.57,name='Lightning fissure')
  for x,z in p[1:-1]: sphere((x,-.59,z),(.035,.018,.035),cyan,'Crack node')
 # camera from front elevated; world backdrop transparent
 cam=bpy.context.scene.camera;cam.location=(3,-7,4 if pickup else 3.75);aim(cam,(0,0,0));cam.data.type='ORTHO';cam.data.ortho_scale=2.35

def passes(path):
 tree=bpy.data.node_groups.new('Forge cel passthrough','CompositorNodeTree');bpy.context.scene.compositing_node_group=tree;tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');rl=tree.nodes.new('CompositorNodeRLayers');out=tree.nodes.new('NodeGroupOutput');tree.links.new(rl.outputs['Image'],out.inputs['Image'])

def render_raw(path,pickup=False):
 setup('Forge pickup' if pickup else 'Forge icon',512);make_core(pickup);cel.toon_materials('icon');scene=bpy.context.scene
 cel.cel_passes(path,'icon',base_configure=passes,normals=False);scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)

def main():
 RAW.mkdir(parents=True,exist_ok=True)
 render_raw(RAW/'storm_icon.png');render_raw(RAW/'storm_pickup.png',True)
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/forge/f2.blend'))
 subprocess.run([PY,'-I',str(Path(__file__).with_name('f2_finalize.py'))],check=True)
 print('PASS forge f2 5 PNG',flush=True)
if __name__=='__main__':main()
