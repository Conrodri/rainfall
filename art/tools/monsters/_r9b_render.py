"""R9a: keep R8d sculpt/camera; replace only six attack keys; Eevee passes."""
import sys, json, math
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from boss_pipeline import *
ROOT=HERE.parents[2]
name=sys.argv[sys.argv.index('--boss')+1]
OUT=HERE/'_r9b_frames'/name;OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'art/blender/monsters/{name}.blend'))
s=bpy.context.scene
root=bpy.data.objects[{'ash_lord':'AshLord','bramble_queen':'BrambleQueen','brood_mother':'BroodMother'}[name]]
body=bpy.data.objects[{'ash_lord':'Ash lord','bramble_queen':'Slender queen','brood_mother':'Inverted drop body'}[name]]
head=bpy.data.objects['Head']
cam_state=([v for row in s.camera.matrix_world for v in row],s.camera.data.ortho_scale,s.camera.data.shift_y)
# Six authored keys: recoil/clear windup, violent impact at zero-based N/2,
# then recovery to the original stance. Preserve all other R8 animation keys.
for i in range(6):
    f=41+i;s.frame_set(f)
    body.location=(0,[0,.10,.18,-.15,-.06,0][i],[0,.025,.05,-.06,-.02,0][i])
    if name in ('bramble_queen','brood_mother') and i==2:body.location.z=0
    body.rotation_euler=([0,-.12,-.23,.28,.11,0][i],0,[0,-.08,-.16,.17,.06,0][i]);key(body,f)
    head.rotation_euler=([0,-.10,-.20,.32,.12,0][i],0,0);key(head,f)
    if name in ('ash_lord','bramble_queen'):
        arms=[o for o in body.children if o.name.startswith('Long arm' if name=='ash_lord' else 'Branch arm')]
        for arm in arms:
            sign=1 if arm.location.x>0 else -1
            # Main arm raises behind the shoulder and sweeps forward/down;
            # the off arm counterbalances the torso twist.
            ax=[0,-.85,-1.75,1.05,.4,0][i] if sign==1 else [0,-.18,-.38,.38,.15,0][i]
            arm.rotation_euler=(ax,-sign*[.15,.28,.42,.16,.13,.15][i],sign*[0,.10,.20,-.18,-.06,0][i]);key(arm,f)
    else:
        body.location.y=[0,0,0,-.08,-.03,0][i];body.rotation_euler.x=[0,-.04,-.08,.22,.08,0][i];key(body,f)
        abd=bpy.data.objects['Abdomen pivot'];abd.rotation_euler.x=[0,.16,.30,-.45,-.18,0][i]
        q=[1,1.02,1.0,.93,.98,1][i];abd.scale=(q,q,q);key(abd,f)
        for leg in [o for o in body.children if o.name.startswith('Thin leg')]:
            front=leg.location.y<-.2;sign=1 if leg.location.x>0 else -1
            leg.rotation_euler=([0,.5,1.0,-.38,-.15,0][i] if front else [0,.05,.1,-.1,-.04,0][i],0,sign*[0,-.08,-.18,.12,.04,0][i]);key(leg,f)
s.render.engine='BLENDER_EEVEE'
if hasattr(s,'eevee'):s.eevee.taa_render_samples=16
s.render.threads_mode='FIXED';s.render.threads=8
pose(root,1,'s')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art/blender/monsters/{name}.blend'))
report={'cell':170,'impact_index':3,'direction_rows':['e','w','n'],'camera_scale':s.camera.data.ortho_scale,'camera_shift_y':s.camera.data.shift_y,'ground_pivot':[85,119],'cast_a_arm_elevation_factor':.62 if name=='ash_lord' else 1,'camera_unchanged':True}
assert cam_state==([v for row in s.camera.matrix_world for v in row],s.camera.data.ortho_scale,s.camera.data.shift_y)
diffuse_compositor(s)
for anim,dirs in [('attack',['s','e','w','n']),('cast_a',['e','w','n']),('cast_b',['e','w','n'])]:
    start,count=ANIMS[anim]
    folder=OUT/anim;folder.mkdir(exist_ok=True)
    for d in dirs:
        for i in range(count):
            pose(root,start+i,d)
            if name=='ash_lord' and anim=='cast_a':
                for arm in [o for o in body.children if o.name.startswith('Long arm')]:
                    arm.delta_rotation_euler.y=-arm.rotation_euler.y*.38
                bpy.context.view_layer.update()
            else:
                for arm in [o for o in body.children if o.name.startswith('Long arm')]:arm.delta_rotation_euler.y=0
            p=folder/f'{d}_{i:02}.png'
            refresh=(anim=='attack' and '--refresh-attack' in sys.argv) or (anim=='cast_a' and '--refresh-cast-a' in sys.argv)
            if '--resume' in sys.argv and not refresh and all(p.with_stem(p.stem+x).exists() for x in ('','_n','_e')):continue
            s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
            passes.render_normal_pass(p.with_stem(p.stem+'_n'),p,s)
            passes.render_emission_pass(p.with_stem(p.stem+'_e'),p,s)
            print('R9B_FRAME',anim,d,i,flush=True)
(HERE/f'_r9b_{name}_render_report.json').write_text(json.dumps(report,indent=2))

