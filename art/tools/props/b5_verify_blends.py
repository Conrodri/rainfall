from pathlib import Path
import bpy,math
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
R=Path(__file__).resolve().parents[3]
for b,name,size,foot in [(1,'rails',(400,224),(200,116)),(2,'crypt_stairs',(400,304),(200,196)),(3,'pontoon',(400,272),(200,166)),(4,'stone_stairs',(432,384),(216,268))]:
 bpy.ops.wm.open_mainfile(filepath=str(R/f'art/blender/props/b5_{name}.blend'))
 s=bpy.context.scene;o=bpy.data.objects[name];assert abs(o.rotation_euler.z-math.pi/2)<1e-5
 assert s.render.resolution_x==size[0]*2 and s.render.resolution_y==size[1]*2
 q=world_to_camera_view(s,s.camera,Vector((0,0,0)));assert abs(q.x*size[0]-foot[0])<.01 and abs((1-q.y)*size[1]-foot[1])<.01
 assert list(s.get('g4_foot' if b==3 else f'b{b}_foot'))==list(foot)
 if b in (2,4):
  label='Fractured stair masonry' if b==2 else 'Split worn stair block'
  blocks=[c for c in o.children if c.name.startswith(label)]
  centers=[c.matrix_world @ (sum((v.co for v in c.data.vertices), Vector())/len(c.data.vertices)) for c in blocks]
  points=[(v.z,world_to_camera_view(s,s.camera,v)) for v in centers]
  low=min(points,key=lambda p:p[0]);high=max(points,key=lambda p:p[0])
  assert high[1].x>low[1].x and high[1].y>low[1].y, 'Stair rise must project upper-right'
 assert 'EEVEE' in s.render.engine, s.render.engine
 assert s.render.engine!='CYCLES'
print('PASS 4 blend roots +pi/2; MAP canvas/foot identical; Eevee')
