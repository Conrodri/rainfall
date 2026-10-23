"""Per-animation camera-space bounds of a saved boss scene. Background Blender only."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
name=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
root=[o for o in bpy.data.objects if o.parent is None and o.type=='EMPTY'][0]
s=bpy.context.scene;cam=s.camera;inv=cam.matrix_world.inverted();ground=inv@Vector((0,0,0))
for anim,(start,count) in ANIMS.items():
    x0=y0=1e9;x1=y1=-1e9
    for i in range(count):
        for d in DIRECTIONS[anim]:
            pose(root,start+i,d);deps=bpy.context.evaluated_depsgraph_get()
            for obj in s.objects:
                if obj.type!='MESH' or obj.hide_render:continue
                ev=obj.evaluated_get(deps);m=ev.to_mesh()
                if ev.scale.x<.01 or max(ev.matrix_world.to_scale())<.01:ev.to_mesh_clear();continue
                for v in m.vertices:
                    q=inv@(ev.matrix_world@v.co)-ground;x0=min(x0,q.x);x1=max(x1,q.x);y0=min(y0,q.y);y1=max(y1,q.y)
                ev.to_mesh_clear()
    print('BOUNDS',anim,round(x0,2),round(x1,2),round(y0,2),round(y1,2))
