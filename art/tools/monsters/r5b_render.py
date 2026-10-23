"""One saved mini-boss at a time; refine, fit 35-degree camera, save and render all passes."""
import sys,math,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
from r5b_refine import refine
assert bpy.app.background
name=sys.argv[sys.argv.index('--')+1]
assert name in ('ash_lord','bramble_queen','brood_mother')
bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
s=bpy.context.scene;s.frame_set(1)
refine(name)
root=bpy.data.objects[{'ash_lord':'AshLord','bramble_queen':'BrambleQueen','brood_mother':'BroodMother'}[name]]
cam=s.camera;target=Vector((0,0,.65))
cam.location=target+Vector((0,-4*math.cos(math.radians(35)),4*math.sin(math.radians(35))))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam.name='Fixed camera 35 degrees'
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
s.render.resolution_x=s.render.resolution_y=340
s.render.resolution_percentage=100;s.render.film_transparent=True
s.view_settings.view_transform='Standard'
framing=fit_camera(root,ANIMS,170,DIRECTIONS)
diffuse_compositor(s);pose(root,1,'s')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
base=ART/'renders/monsters'/name
(base/'r5b_report.json').write_text(json.dumps({'camera_elevation':35,'framing':framing,'anims':ANIMS,'directions':DIRECTIONS},indent=2))
render_all(name,root,ANIMS,DIRECTIONS,resume=False)
print('DONE',name,flush=True)
