"""Measure candidate throw anticipation angles with the fixed CREA camera."""
import sys,runpy
from pathlib import Path
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[3]
ns=runpy.run_path(str(ROOT/'art/tools/night/bo1_build.py'),run_name='bo1_bounds')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/bourbe.blend'))
root=bpy.data.objects.get('Bourbe') or next(o for o in bpy.data.objects if o.name.startswith('BOURBE'))
rig=bpy.data.objects['Bourbe_Rig'];s=bpy.context.scene
for angle in (-2.05,-2.3,-2.55,-2.8,-3.0,-1.55):
    ns['pose'](rig,'throw',1,4);rig.pose.bones['arm.R'].rotation_euler.x=angle
    minimum=192
    for az in ns['iso_rig'].DIRECTIONS.values():
        root.rotation_euler.z=az;bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
        for o in root.children_recursive:
            if o.type!='MESH':continue
            ev=o.evaluated_get(deps);data=ev.to_mesh()
            for v in data.vertices:
                q=world_to_camera_view(s,s.camera,ev.matrix_world@v.co)
                minimum=min(minimum,(1-q.y)*192)
            ev.to_mesh_clear()
    print('BO1 BOUNDS',angle,round(minimum,2),flush=True)
