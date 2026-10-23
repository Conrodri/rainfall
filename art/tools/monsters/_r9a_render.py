"""R9a: keep R8d sculpt/camera; replace only six attack keys; Eevee passes."""
import sys, json, math
from pathlib import Path
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE))
from boss_pipeline import *
ROOT=HERE.parents[2]
OUT=HERE/'_r9a_frames'
OUT.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/monsters/frost_bear.blend'))
s=bpy.context.scene
root=bpy.data.objects['FrostBear']
body=bpy.data.objects['Long low bear body']
head=bpy.data.objects['Low muzzle head']
legs=[o for o in body.children if o.name.startswith(('Front paw','Hind paw'))]
camera_before=(tuple(s.camera.matrix_world.flattened()) if hasattr(s.camera.matrix_world,'flattened') else [v for row in s.camera.matrix_world for v in row],s.camera.data.ortho_scale,s.camera.data.shift_y)
# Local Y is forward-negative. Rear and raise both front paws clear of the
# silhouette, then slam down exactly at zero-based index 3 == N/2.
recoil=[0,.13,.23,-.075,-.035,0]
height=[0,.06,.11,.015,.025,0]
pitch=[0,-.12,-.24,.075,.03,0]
paw_x=[0,-.95,-1.70,.08,-.22,0]
paw_y=[0,-.3,-.6,-.05,-.10,0]
for i in range(6):
    f=41+i;s.frame_set(f)
    body.location=(0,recoil[i],height[i]);body.rotation_euler=(pitch[i],0,[0,-.07,-.14,.08,.03,0][i]);body.scale=(1,1,1);key(body,f)
    head.location=(0,-.87,.97);head.rotation_euler=(pitch[i]*-.5,0,[0,.05,.12,-.10,-.035,0][i]);key(head,f)
    for leg in legs:
        front=leg.name.startswith('Front paw');right=leg.location.x>0
        sign=1 if right else -1
        leg.rotation_euler=(paw_x[i],sign*paw_y[i],sign*[0,-.1,-.14,.05,.015,0][i]) if front else (-pitch[i],0,0)
        key(leg,f)
s.render.engine='BLENDER_EEVEE'
if hasattr(s,'eevee'):s.eevee.taa_render_samples=16
s.render.threads_mode='FIXED';s.render.threads=8
pose(root,1,'s')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/monsters/frost_bear.blend'))
report={'cell':170,'impact_index':3,'direction_rows':['e','w','n'],'camera_scale':s.camera.data.ortho_scale,'camera_shift_y':s.camera.data.shift_y,'ground_pivot':[85,119],'poses':[]}
diffuse_compositor(s)
for anim,dirs in [('attack',['s','e','w','n']),('cast_a',['e','w','n']),('cast_b',['e','w','n'])]:
    start,count=ANIMS[anim]
    folder=OUT/anim;folder.mkdir(exist_ok=True)
    for d in dirs:
        for i in range(count):
            pose(root,start+i,d)
            breath=bpy.data.objects['Volumetric frost breath']
            breath.delta_scale.y=.18 if anim=='cast_a' else 1
            if anim=='cast_a':
                # R8d's south-only breath exceeds the fixed cell in profile.
                # Retain its ice sculpt, thickness and pulse; shorten reach only.
                bpy.context.view_layer.update()
            p=folder/f'{d}_{i:02}.png'
            refresh=anim=='attack' and '--refresh-attack' in sys.argv
            if '--resume' in sys.argv and not refresh and all(p.with_stem(p.stem+x).exists() for x in ('','_n','_e')):continue
            s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
            passes.render_normal_pass(p.with_stem(p.stem+'_n'),p,s)
            passes.render_emission_pass(p.with_stem(p.stem+'_e'),p,s)
            print('R9A_FRAME',anim,d,i,flush=True)
(HERE/'_r9a_render_report.json').write_text(json.dumps(report,indent=2))
# A real plane and UV-distance shader produce the soft, frame-free vignette.
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.render.engine='BLENDER_EEVEE'
s.render.resolution_x=s.render.resolution_y=1024;s.render.resolution_percentage=100
s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
if hasattr(s,'eevee'):s.eevee.taa_render_samples=16
bpy.ops.mesh.primitive_plane_add(size=2)
plane=bpy.context.object;plane.name='R9a blood vignette UV gradient'
m=bpy.data.materials.new('R9a radial blood edge');m.use_nodes=True
t=m.node_tree;t.nodes.clear()
uv=t.nodes.new('ShaderNodeTexCoord')
center=t.nodes.new('ShaderNodeVectorMath');center.operation='SUBTRACT';center.inputs[1].default_value=(.5,.5,0);t.links.new(uv.outputs['UV'],center.inputs[0])
length=t.nodes.new('ShaderNodeVectorMath');length.operation='LENGTH';t.links.new(center.outputs[0],length.inputs[0])
fade=t.nodes.new('ShaderNodeMapRange');fade.interpolation_type='SMOOTHERSTEP';fade.clamp=True
fade.inputs['From Min'].default_value=math.sqrt(.60/math.pi)
fade.inputs['From Max'].default_value=.655
fade.inputs['To Min'].default_value=0;fade.inputs['To Max'].default_value=.88
t.links.new(length.outputs['Value'],fade.inputs['Value'])
transparent=t.nodes.new('ShaderNodeBsdfTransparent')
blood=t.nodes.new('ShaderNodeEmission');blood.inputs['Color'].default_value=(.115,.0018,.004,1);blood.inputs['Strength'].default_value=1
mix=t.nodes.new('ShaderNodeMixShader');t.links.new(fade.outputs['Result'],mix.inputs[0]);t.links.new(transparent.outputs[0],mix.inputs[1]);t.links.new(blood.outputs[0],mix.inputs[2])
output=t.nodes.new('ShaderNodeOutputMaterial');t.links.new(mix.outputs[0],output.inputs[0]);plane.data.materials.append(m)
# Render an opaque emission mask, then use it as continuous composited alpha.
# This avoids stochastic transparency in Eevee's dithered material renderer.
mask=t.nodes.new('ShaderNodeEmission');t.links.new(fade.outputs['Result'],mask.inputs['Color']);t.links.new(mask.outputs[0],output.inputs[0])
bpy.ops.object.camera_add(location=(0,0,3));s.camera=bpy.context.object;s.camera.data.type='ORTHO';s.camera.data.ortho_scale=2
s.view_settings.view_transform='Raw'
tree,comp=passes._tree(s,'R9a blood alpha')
rl=tree.nodes.new('CompositorNodeRLayers');rl.scene=s
tree.links.new(passes._setalpha(tree,(.115,.0018,.004,1),rl.outputs['Image']),comp.inputs['Image'])
s.view_settings.view_transform='Standard'
# Mask values must remain linear; compositor consumes scene-linear render data.
bpy.ops.wm.save_as_mainfile(filepath=str(HERE/'_r9a_vignette.blend'))
s.render.filepath=str(ROOT/'game/assets/sprites/ui/da/vignette_hit.png');bpy.ops.render.render(write_still=True)
print('R9A_RENDER_PASS',flush=True)
