"""R9c: R9a targeted key replacement and three Eevee passes, original R8 camera."""
import sys,json,math
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from boss_pipeline import *
name=sys.argv[sys.argv.index('--boss')+1]
assert name in ('rust_archon','stone_colossus')
ROOT=HERE.parents[2];OUT=HERE/'_r9c_frames'/name;OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'art/blender/monsters/{name}.blend'))
s=bpy.context.scene
archon=name=='rust_archon'
root=bpy.data.objects['RustArchon' if archon else 'StoneColossus']
body=bpy.data.objects['Floating hollow armor' if archon else 'Massive block torso']
arms=[o for o in body.children if o.name.startswith('Detached arm' if archon else 'Hammer shoulder')]
camera=([v for row in s.camera.matrix_world for v in row],s.camera.data.ortho_scale,s.camera.data.shift_y)
for i in range(6):
    f=41+i;s.frame_set(f)
    body.location=(0,[0,.10,.19,-.19,-.08,0][i],[0,.045,.09,-.07,-.025,0][i])
    if not archon and i==2:body.location.z=.04
    body.rotation_euler=([0,-.08,-.16,.24,.10,0][i],0,[0,-.10,-.20,.17,.06,0][i]);body.scale=(1,1,1);key(body,f)
    for arm in arms:
        sign=1 if arm.location.x>0 else -1
        lift=([0,.25,.48,-.85,-.35,0] if archon else [0,1.10,1.60,-1.30,-.50,0])[i]
        arm.rotation_euler=(lift if sign==1 else -.35*lift,0,sign*[0,.06,.12,-.10,-.04,0][i]);key(arm,f)
    if archon:
        weapon=bpy.data.objects['Two body lengths halberd']
        weapon.location=(.76,-.18,1.38)
        weapon.rotation_euler=([.12,-.15,-.40,.80,.42,.12][i],[-.24,-.35,-.45,-.40,-.30,-.24][i],[0,.22,.40,-.50,-.20,0][i]);key(weapon,f)
s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
s.render.threads_mode='FIXED';s.render.threads=8
diffuse_compositor(s)
report={'boss':name,'cell':170,'impact_index':3,'direction_rows':['e','w','n'],'camera_scale':camera[1],'camera_shift_y':camera[2],'ground_pivot':[85,119],'bounds':[]}
if '--audit-only' not in sys.argv:
    pose(root,1,'s');bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art/blender/monsters/{name}.blend'))
if archon:
    # Temporary render keys: Blender reevaluates animation on each render.
    weapon=bpy.data.objects['Two body lengths halberd']
    for i in range(8):
        s.frame_set(61+i);weapon.rotation_euler.x*=.80;key(weapon,61+i)
def directional_pose(anim,frame,d):
    pose(root,frame,d)
# Project actual evaluated vertices before any expensive render; keep R8 framing.
for anim,dirs in [('attack',['s','e','w','n']),('cast_a',['e','w','n']),('cast_b',['e','w','n'])]:
    start,count=ANIMS[anim]
    for d in dirs:
        for i in range(count):
            directional_pose(anim,start+i,d);deps=bpy.context.evaluated_depsgraph_get();bounds=[1.,1.,0.,0.]
            for o in s.objects:
                if o.type!='MESH' or o.hide_render:continue
                ev=o.evaluated_get(deps);mesh=ev.to_mesh()
                for v in mesh.vertices:
                    q=world_to_camera_view(s,s.camera,ev.matrix_world@v.co)
                    bounds=[min(bounds[0],q.x),min(bounds[1],q.y),max(bounds[2],q.x),max(bounds[3],q.y)]
                ev.to_mesh_clear()
            report['bounds'].append([anim,d,i,[round(v*170,2) for v in bounds]])
            assert min(bounds[0],bounds[1],1-bounds[2],1-bounds[3])>=.025,('CLIPPING',anim,d,i,bounds)
(HERE/f'_r9c_{name}_render_report.json').write_text(json.dumps(report,indent=2))
if '--audit-only' in sys.argv:
    print('R9C_AUDIT PASS',name,flush=True);sys.exit()
for anim,dirs in [('attack',['s','e','w','n']),('cast_a',['e','w','n']),('cast_b',['e','w','n'])]:
    start,count=ANIMS[anim];folder=OUT/anim;folder.mkdir(exist_ok=True)
    for d in dirs:
        for i in range(count):
            directional_pose(anim,start+i,d);p=folder/f'{d}_{i:02}.png'
            if '--resume' in sys.argv and not ((anim=='cast_a' and '--refresh-cast-a' in sys.argv) or (anim=='attack' and '--refresh-attack' in sys.argv)) and all(p.with_stem(p.stem+x).exists() for x in ('','_n','_e')):continue
            s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
            passes.render_normal_pass(p.with_stem(p.stem+'_n'),p,s)
            passes.render_emission_pass(p.with_stem(p.stem+'_e'),p,s)
            print('R9C_FRAME',name,anim,d,i,flush=True)
assert camera==([v for row in s.camera.matrix_world for v in row],s.camera.data.ortho_scale,s.camera.data.shift_y)
print('R9C_RENDER PASS',name,flush=True)
