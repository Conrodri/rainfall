"""Read-only scene validation, background Blender only; bounded PASS/FAIL output."""
import bpy,json,math,sys
from pathlib import Path
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parents[3]
checks=[]
for id in ('arpenteuse','rainette'):
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'art/blender/characters/cd_{id}.blend'))
    s=bpy.data.scenes['CD2 model and calibrated studio'];bpy.context.window.scene=s
    root=next(o for o in s.objects if o.type=='EMPTY' and o.name.startswith('Arpenteuse —' if id=='arpenteuse' else 'Rainette —'))
    s.frame_set(30);bpy.context.view_layer.update()
    pose={'lift':round(root.location.z,3)}
    if id=='rainette':
        sac=next(o for o in root.children_recursive if o.name.startswith('Inflatable vocal sac'))
        pose['sac_scale']=list(sac.scale)
        assert root.location.z>.5 and sac.scale.z>1.9,'Signature jump pose missing'
    else:
        arm=next(o for o in root.children_recursive if o.name=='Arm 1')
        assert abs(arm.rotation_euler.x)>0.9,'Signature whip pose missing'
    # Reproduce the original calibrated camera without rendering or changing disk sources.
    cam=bpy.data.objects.get('ISO_CREA');s.camera=cam;cam.data.shift_y=0;cam.data.shift_x=0
    cam.data.ortho_scale=650/(64*math.sqrt(2));s.render.resolution_x=650;s.render.resolution_y=280
    s.frame_set(1);root.location=(.9,0,0);root.rotation_euler.z=math.pi/4;bpy.context.view_layer.update()
    from mathutils import Vector
    points=[]
    for o in root.children_recursive:
        if o.type=='MESH' and not o.hide_render:
            points.extend(world_to_camera_view(s,cam,o.matrix_world@Vector(v)) for v in o.bound_box)
    bounds=[round(min(p.x for p in points),3),round(min(p.y for p in points),3),round(max(p.x for p in points),3),round(max(p.y for p in points),3)]
    assert 0<bounds[0]<bounds[2]<1 and 0<bounds[1]<bounds[3]<1,('Cropped CREA',bounds)
    meshes=sum(o.type=='MESH' for o in root.children_recursive)
    assert meshes>80
    checks.append(dict(character=id,mesh_objects=meshes,signature=pose,crea_bounds=bounds,ppu=64*math.sqrt(2),pass_check=True))
(ROOT/'art/tools/characters/_cd_cd2_check.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
print('PASS CD2: both detailed models, signature poses, full CREA framing, calibrated scale; '+str(checks),flush=True)
