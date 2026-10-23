import sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from boss_pipeline import *
bpy.ops.wm.open_mainfile(filepath=str(HERE.parents[2]/'art/blender/monsters/brood_mother.blend'))
s=bpy.context.scene;pose(bpy.data.objects['BroodMother'],42,'e');deps=bpy.context.evaluated_depsgraph_get();bad=[]
for o in s.objects:
 if o.type!='MESH' or o.hide_render:continue
 ev=o.evaluated_get(deps);me=ev.to_mesh()
 ys=[world_to_camera_view(s,s.camera,ev.matrix_world@v.co).x for v in me.vertices];ev.to_mesh_clear()
 if ys and min(ys)<.03:bad.append((round(min(ys),3),o.name,o.parent.name if o.parent else ''))
print('R9B_BOUNDS',sorted(bad,reverse=True)[:10])
