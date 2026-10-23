"""Read-only Blender audit of the delivered source and looping rig."""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[3]
bpy.ops.wm.open_mainfile(filepath=str(root/'art/blender/characters/ardent.blend'))
s=bpy.context.scene
forward=s.camera.rotation_euler.to_quaternion()@Vector((0,0,-1))
elevation=math.degrees(math.asin(-forward.z))
assert abs(elevation-35)<.001
assert abs(bpy.data.objects['Oversized hood'].scale.x-.258*1.25)<.001
assert s.render.engine=='BLENDER_EEVEE' and s.render.resolution_x==384
names=['Body','Leg_L','Leg_R','Arm_L','Arm_R','Cape hinge','Staff ember']
def pose(frame):
    s.frame_set(frame)
    return {n:list(bpy.data.objects[n].location)+list(bpy.data.objects[n].rotation_euler)+list(bpy.data.objects[n].scale) for n in names}
error=0
for first,last in [(1,9),(17,25)]:
    a,b=pose(first),pose(last)
    error=max(error,max(abs(x-y) for n in names for x,y in zip(a[n],b[n])))
assert error<1e-5, error
report={'camera_degrees':round(elevation,4),'head_scale':1.25,'loop_closure_error':error,'engine':s.render.engine,'samples':s.eevee.taa_render_samples}
(root/'art/renders/characters/ardent/r4_scene_check.json').write_text(json.dumps(report,indent=2))
print('PASS scene: camera 35, head +25%, idle/run closing keys, Eevee')
