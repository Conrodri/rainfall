from pathlib import Path
import bpy, shutil, json
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
src=ROOT/'art/blender/bosses/rain_sower_iso.blend'
dst=Path(__file__).parent/'rain_sower_store.blend'
if not dst.exists(): shutil.copy2(src,dst)
bpy.ops.wm.open_mainfile(filepath=str(dst))
rows=[]
for o in bpy.context.scene.objects:
 if o.type=='MESH':
  pts=[o.matrix_world@Vector(v) for v in o.bound_box]
  rows.append([o.name, [round(min(p[i] for p in pts),2) for i in range(3)], [round(max(p[i] for p in pts),2) for i in range(3)],o.hide_render])
out={'meshes':rows,'roots':[[o.name,list(o.rotation_euler)] for o in bpy.context.scene.objects if o.parent is None],'materials':[m.name for m in bpy.data.materials]}
(Path(__file__).parent/'inspection.json').write_text(json.dumps(out,indent=1))
print('INSPECT PASS',len(rows))
