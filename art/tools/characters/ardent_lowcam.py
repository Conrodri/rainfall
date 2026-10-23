"""Ardent re-render, camera 35 deg (au lieu de 55), tete ~25 % plus grosse. Blender --background.
Usage: blender.exe --background --python ardent_lowcam.py   (une seule instance a la fois)
Source: art/blender/characters/ardent.blend ; rendus: art/renders/characters/ardent/<anim>[_n|_e]/<dir>_<ff>.png"""
import bpy, math, json
from pathlib import Path
from mathutils import Vector
BASE=Path(r'C:\Users\const\Documents\Rainfall\art')
NS={'__name__':'ardent_build_lib'}
build_source=(BASE/'tools/ardent_build.py').read_text(encoding='utf-8-sig')
exec(compile(build_source,'ardent_build.py','exec'),NS)
BLEND=BASE/'blender/characters/ardent.blend'; OUT=BASE/'renders/characters/ardent'
NS['BLEND']=BLEND
ELEV=35; HEAD_K=1.25
bpy.ops.wm.open_mainfile(filepath=str(BLEND))
s=bpy.context.scene
if not s.get('lowcam_done'):
    piv=Vector((0,0,.66))
    for n in ['Oversized hood','Face shadow','Face','Hood brow','Eye','Eye.001','Eye glint','Eye glint.001','Nose']:
        o=bpy.data.objects.get(n)
        if o: o.location=piv+(o.location-piv)*HEAD_K; o.scale*=HEAD_K
    s['lowcam_done']=True
cam=s.camera; target=Vector((0,0,.47))
cam.location=target+Vector((0,-4*math.cos(math.radians(ELEV)),4*math.sin(math.radians(ELEV))))
cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.shift_x=cam.data.shift_y=0
bpy.context.view_layer.update()

# Preserve the original rig and closing keys; steady the torch during the stride.
if not s.get('r4_stride_done'):
    body=bpy.data.objects['Body']
    for i in range(9):
        t=2*math.pi*i/8; s.frame_set(17+i)
        body.rotation_euler.x=.14
        body.keyframe_insert('rotation_euler',frame=17+i)
        for side,sign in [('L',1),('R',-1)]:
            leg=bpy.data.objects['Leg_'+side]
            leg.rotation_euler.x=sign*.85*math.sin(t)
            leg.keyframe_insert('rotation_euler',frame=17+i)
            arm=bpy.data.objects['Arm_'+side]
            arm.rotation_euler.x=-sign*(.23 if side=='R' else .46)*math.sin(t)
            arm.keyframe_insert('rotation_euler',frame=17+i)
    # A swept flame tip reads clearly beside the enlarged hood at game scale.
    flame=bpy.data.objects['Staff ember']
    for v in flame.data.vertices:
        if v.co.z>0:
            z=v.co.z
            v.co.x += .18*z*z
            v.co.z *= 1.10
    s['r4_stride_done']=True

# Quarter-cycle torso/cape twist distinguishes the passing and landing poses;
# a sine-only rig otherwise repeats frames 1/3 and 5/7.
if not s.get('r4_twist_done'):
    for i in range(9):
        t=2*math.pi*i/8; s.frame_set(17+i)
        body=bpy.data.objects['Body']; body.rotation_euler.z=.025*math.cos(t)
        body.keyframe_insert('rotation_euler',frame=17+i)
        cape=bpy.data.objects['Cape hinge']; cape.rotation_euler.y=.04*math.cos(t)
        cape.keyframe_insert('rotation_euler',frame=17+i)
    s['r4_twist_done']=True
def render_one(anim,d,i,kind):
    NS['set_pose'](anim,d,i); p=NS['_passes_module']()
    suf={'diffuse':'','normal':'_n','emission':'_e'}[kind]
    out=OUT/(anim+suf)/f'{d}_{i:02d}.png'; out.parent.mkdir(parents=True,exist_ok=True)
    diffuse=OUT/anim/out.name
    if kind=='normal': p.render_normal_pass(out,diffuse,s)
    elif kind=='emission': p.render_emission_pass(out,diffuse,s)
    else: s.render.filepath=str(out); bpy.ops.render.render(write_still=True)
s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=16
s.render.resolution_x=s.render.resolution_y=384
s.render.resolution_percentage=100
s.render.film_transparent=True
s.view_settings.view_transform='Standard'; s.view_settings.look='None'
p=NS['_passes_module']()
# Reuse the evaluated union fitter with a tighter ground-pivot contract and
# enough raw margin to retain four transparent pixels after packing to 192.
fit_source='def fit_union_camera():'+build_source.split('def fit_union_camera():',1)[1].split('\ndef _passes_module():',1)[0]
fit_source=fit_source.replace('margin=9.5/384','margin=19/384').replace('range(700,741)','range(700,711)')
exec(compile(fit_source,'r4_fit_union','exec'),NS)
fr=NS['fit_union_camera'](); p.setup_diffuse_compositor(s)
(OUT/'pass_report.json').write_text(json.dumps(fr,indent=2))
for kind in ['diffuse','normal','emission']:
    for anim in ['idle','run']:
        for d in NS['DIRS']:
            for i in range(8): render_one(anim,d,i,kind)
    print('R4 PASS rendered '+kind,flush=True)
s.frame_set(1); bpy.data.objects['Ardent_Root'].rotation_euler.z=0
s.render.filepath=str(OUT/'idle/s_00.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
print('DONE')
