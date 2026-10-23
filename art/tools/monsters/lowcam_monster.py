"""Re-rendu des monstres de base avec camera a 35 deg (au lieu de 55) et tete plus grosse.
Usage: blender.exe --background --python lowcam_monster.py -- <swarm_tier1|shooter_tier2|leaper_tier2|brute_tier3>
Une seule instance Blender a la fois. Source: art/blender/monsters/<nom>.blend (re-enregistree).
Rendus: art/renders/monsters/<nom>/<anim>/<dir>_<ff>[_n|_e].png (2x, reduit par pack_monsters.py / pack.py)."""
import sys, math, json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
ELEV=35
CFG={
 'swarm_tier1':dict(size=96,anims={'run':(1,8)},head=None,k=1.0),
 'shooter_tier2':dict(size=112,anims={'run':(1,8),'attack':(17,8)},head=['Hood','Pointed hood','Face recess','Red slit eye','Red slit eye.001'],k=1.3),
 'leaper_tier2':dict(size=112,anims={'run':(1,8),'charge':(17,8)},head='Head',k=1.3),
 'brute_tier3':dict(size=160,anims={'run':(1,8),'attack':(17,8),'cast':(33,8)},head=['Small head','Dark face','Red slit eye','Red slit eye.001'],k=1.4),
}
name=sys.argv[sys.argv.index('--')+1]; c=CFG[name]
bpy.ops.wm.open_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
s=bpy.context.scene
root=[o for o in bpy.data.objects if o.parent is None and o.type=='EMPTY'][0]
if not s.get('lowcam_done'):
    h=c['head']
    if h=='Head':
        parts=[o for o in bpy.data.objects if o.parent and o.parent.name=='Head' and o.type=='MESH']
        piv=Vector((0,0,0))
    elif h:
        parts=[bpy.data.objects[n] for n in h if n in bpy.data.objects]
        main=parts[0]; piv=Vector((main.location.x,main.location.y,main.location.z-.8*main.scale.z))
    else: parts=[]
    for o in parts:
        if o.animation_data and o.animation_data.action: continue
        o.location=piv+(o.location-piv)*c['k']; o.scale*=c['k']
    s['lowcam_done']=True
from r5a_refine import refine
refine(name)
bpy.context.preferences.filepaths.save_version=0
cam=s.camera;cam.name='Fixed camera 35 degrees';target=Vector((0,0,.65))
cam.location=target+Vector((0,-4*math.cos(math.radians(ELEV)),4*math.sin(math.radians(ELEV))))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.shift_x=cam.data.shift_y=0
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
framing=fit_camera(root,c['anims'],c['size'])
if name=='swarm_tier1':
    xmin,xmax,ymin,ymax=framing['bounds_camera'];margin=9/c['size']
    cam.data.ortho_scale=max(max(abs(xmin),abs(xmax))/(.5-margin),ymax/(.7-margin),-ymin/(.3-margin))
    cam.data.shift_y=0;bpy.context.view_layer.update()
    cam.data.shift_y=world_to_camera_view(s,cam,Vector((0,0,0))).y-.30
    framing['ortho_scale']=cam.data.ortho_scale
diffuse_compositor(s);pose(root,1,'s')
base=ART/'renders/monsters'/name;base.mkdir(parents=True,exist_ok=True)
(base/'build_report_35deg.json').write_text(json.dumps(framing,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ART/'blender/monsters'/f'{name}.blend'))
if name=='swarm_tier1':
    for n in ('run','run_n','run_e'):(base/n).mkdir(exist_ok=True)
    for d in DIRS:
        for i in range(8):
            pose(root,i+1,d);p=base/'run'/f'{d}_{i:02d}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
            passes.render_normal_pass(base/'run_n'/p.name,p,s);passes.render_emission_pass(base/'run_e'/p.name,p,s)
else:
    render_all(name,root,c['anims'])
print('DONE',name)
