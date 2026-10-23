"""Measure camera-space geometry bounds without rendering or opening images."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import cerf
from boss_common import *

for anim,(count,dirs,phase,size) in cerf.SPECS.items():
    if not phase:continue
    s=setup_scene(5)
    root,pose=cerf.build(phase)
    basis=s.camera.rotation_euler.to_matrix()
    right,up=basis.col[0],basis.col[1]
    required=0;worst=None
    for direction in dirs:
        for f in range(count):
            pose(f/count,anim);root.rotation_euler.z=DIRECTIONS[direction];bpy.context.view_layer.update()
            for ob in root.children_recursive:
                if ob.hide_render or ob.type not in ('MESH','CURVE'):continue
                for corner in ob.bound_box:
                    pos=ob.matrix_world@Vector(corner)
                    fit=max(abs(pos.dot(right))/.47,pos.dot(up)/.67,-pos.dot(up)/.27)
                    if fit>required:required=fit;worst=(direction,f,ob.name)
    print('FIT',anim,round(required,2),worst,flush=True)
