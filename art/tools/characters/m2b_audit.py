import sys
from pathlib import Path
import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent))
import m2_build as m
bpy.ops.wm.open_mainfile(filepath=str(m.ROOT/'art/blender/characters/rictus.blend'))
s=bpy.context.scene;r=bpy.data.objects['Rictus'];rig=bpy.data.objects['Rictus_Rig'];rig.animation_data_clear();r.animation_data_clear()
m.base.iso_rig.create_rig('CREA',192,target=(0,0,0),reset=False);s.camera.data.shift_y=.21
for a,d,f in [('slash','s',1),('throw','n',2),('throw_ult','e',3),('throw_ult','s',3),('spin','e',2)]:
 m.pose('rictus',r,rig,a,f,m.ANIMS['rictus'][a]);r.rotation_euler.z=m.base.DIRECTIONS[d]+(6.283185307*f/8 if a=='spin' else 0);bpy.context.view_layer.update()
 bounds=[]
 for o in r.children_recursive:
  if o.type!='MESH' or o.hide_render:continue
  ob=o.evaluated_get(bpy.context.evaluated_depsgraph_get())
  ps=[world_to_camera_view(s,s.camera,ob.matrix_world @ Vector(v)) for v in ob.bound_box]
  bounds.append((min((1-p.y)*192 for p in ps),min(p.x*192 for p in ps),max(p.x*192 for p in ps),o.name))
 print('AUDIT',a,d,f,sorted(bounds)[:2],flush=True)
 if a in ('spin','throw_ult'):print('WIDTH',sorted(bounds,key=lambda v:v[1])[:1],sorted(bounds,key=lambda v:-v[2])[:1],flush=True)
