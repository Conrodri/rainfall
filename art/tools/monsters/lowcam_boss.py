"""Re-rendu des mini-boss avec camera a 35 deg. Usage: blender --background --python lowcam_boss.py -- <nom>
Reutilise ANIMS/DIRECTIONS de boss_pipeline.py (170 px, rendu 2x). Une seule instance Blender a la fois."""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from boss_pipeline import *
ELEV=35
name=sys.argv[sys.argv.index('--')+1]
bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
s=bpy.context.scene
root=[o for o in bpy.data.objects if o.parent is None and o.type=='EMPTY'][0]
cam=s.camera;cam.name='Fixed camera 35 degrees';target=Vector((0,0,.65))
cam.location=target+Vector((0,-4*math.cos(math.radians(ELEV)),4*math.sin(math.radians(ELEV))))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.shift_x=cam.data.shift_y=0
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
framing=fit_camera(root,ANIMS,170,DIRECTIONS)
diffuse_compositor(s);pose(root,1,'s')
base=ART/'renders/monsters'/name;base.mkdir(parents=True,exist_ok=True)
(base/'build_report_35deg.json').write_text(json.dumps(framing,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
render_all(name,root,ANIMS,DIRECTIONS)
print('DONE',name)
