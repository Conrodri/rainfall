import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/monsters/stone_colossus.blend'))
r=bpy.data.objects['StoneColossus'];s=bpy.context.scene;inv=s.camera.matrix_world.inverted();g=inv@Vector((0,0,0));worst=(0,None)
for a,(start,n) in ANIMS.items():
 for i in range(n):
  for d in DIRECTIONS[a]:
   pose(r,start+i,d)
   for o in r.children_recursive:
    if o.type!='MESH':continue
    for v in o.bound_box:
     y=(inv@(o.matrix_world@Vector(v))-g).y
     if y<worst[0]:worst=(y,(a,i,d,o.name))
print('WORST',worst)
