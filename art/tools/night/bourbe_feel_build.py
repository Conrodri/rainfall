import sys,math,shutil,json
from pathlib import Path
ROOT=Path('C:/Users/const/Documents/Rainfall')
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools')]
import bo1_build as bo,cel_style as cel,bpy
from mathutils import Vector
from PIL import Image
WORK=ROOT/'art/blender/feel2/bourbe';WORK.mkdir(parents=True,exist_ok=True)
copy=WORK/'bourbe.blend'
shutil.copy2(ROOT/'art/blender/characters/bourbe.blend',copy)
bpy.ops.wm.open_mainfile(filepath=str(copy))
root=next(o for o in bpy.data.objects if o.name.startswith('BOURBE') and o.type=='EMPTY')
rig=bpy.data.objects['Bourbe_Rig'];rig.animation_data_clear()
for obj in bpy.data.objects:
 for mod in obj.modifiers:
  if mod.type=='ARMATURE':mod.use_deform_preserve_volume=False
cel.install('creature',normals=False);cel.toon_materials('creature')
bo.iso_rig.optimize_png=lambda *a,**k:None
# Adapt the shared exporter locally; it must never request a normal output.
import inspect,re
export=inspect.getsource(bo.iso_rig.render_frame)
export=re.sub(r"for suffix in .*?:", "for suffix in ('_e',):", export, count=1)
exec(compile(export,bo.iso_rig.__file__,'exec'),bo.iso_rig.__dict__)
clay=next(m for m in bpy.data.materials if 'argile' in m.name.lower() or 'vase' in m.name.lower())
def blob(name,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8)
 o=bpy.context.object;o.name=name;o.scale=scale;o.parent=root;o.data.materials.append(mat)
 for p in o.data.polygons:p.use_smooth=True
 return o
motte=blob('FEEL thrown clay',(.15,.14,.13),clay)
drops=[blob('FEEL splash '+str(i),(.035,.04,.08),clay) for i in range(7)]
ghostmat=bpy.data.materials.new('FEEL translucent mud');ghostmat.use_nodes=True
t=ghostmat.node_tree;t.nodes.clear();out=t.nodes.new('ShaderNodeOutputMaterial');mix=t.nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.32
tr=t.nodes.new('ShaderNodeBsdfTransparent');em=t.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=(.12,.22,.17,1)
t.links.new(tr.outputs[0],mix.inputs[1]);t.links.new(em.outputs[0],mix.inputs[2]);t.links.new(mix.outputs[0],out.inputs['Surface'])
ghosts=[blob('FEEL smear '+str(i),(.08,.08,.35),ghostmat) for i in range(3)]
FIT={}
original=bo.pose
lum=[]
for m in bpy.data.materials:
 if m.use_nodes:
  for node in m.node_tree.nodes:
   if node.type=='OUTPUT_AOV' and node.inputs['Color'].default_value[1]>.1:
    lum.append((node.inputs['Color'],tuple(node.inputs['Color'].default_value)))
def pose(rig,a,f,n):
 root.scale=(FIT.get(a,1)*(1.09 if a=="slap" and f==2 else 1),)*3
 original(rig,a,f,n);hit=3 if a=='cast_ult' else 2
 if a=='slap' and f==1:
  arm=rig.pose.bones['arm.R'];assert abs((arm.tail-arm.head).length/rig.data.bones['arm.R'].length-1.6)<.001
 for o in [motte,*drops,*ghosts]:o.hide_render=True
 bpy.context.view_layer.update()
 if a=='throw' and f<=2:
  motte.hide_render=False
  L=rig.pose.bones['hand.L'].tail;R=rig.pose.bones['hand.R'].tail
  motte.location=(L+R)/2+Vector((0,-.03,.05))
  if f==2:motte.location+=Vector((0,-.22,.16))
  if f==3:motte.location+=Vector((0,-.45,.3));motte.scale=(.13,.14,.13)
  else:motte.scale=(.15,.14,.13)
 if f==hit:
  hand=rig.pose.bones['hand.R'].tail
  for i,o in enumerate(drops):
   o.hide_render=False;ang=i*math.tau/7
   o.location=hand+Vector((math.cos(ang)*(.09+.012*i),-.08-.012*i,math.sin(ang)*.12))
   o.rotation_euler=(.6*math.sin(ang),.8*math.cos(ang),ang)
 if f==hit-1:
  h=rig.pose.bones['hand.R'].tail;s=rig.pose.bones['arm.R'].head
  for i,o in enumerate(ghosts):
   o.hide_render=False;o.location=(h+s)/2+Vector((-.1*(i+1),.1*(i+1),.07*i))
   v=h-s+Vector((-.1*i,.1*i,0));o.rotation_euler=v.to_track_quat('Z','Y').to_euler();o.scale=(.07-i*.012,.08-i*.012,v.length*.52)
 for socket,color in lum:socket.default_value=tuple(c*(2 if f==hit and i<3 else 1) for i,c in enumerate(color))
 bpy.context.view_layer.update()
# Fit the full action, all directions, once; fixed scale prevents camera breathing.
import numpy as np
from bpy_extras.object_utils import world_to_camera_view
scene=bpy.context.scene
origin=world_to_camera_view(scene,scene.camera,Vector((0,0,0)))
axes=[world_to_camera_view(scene,scene.camera,Vector(v)) for v in ((1,0,0),(0,1,0),(0,0,1))]
proj=np.array([[(v.x-origin.x)*192,(origin.y-v.y)*192] for v in axes])
pivot=np.array((origin.x*192,(1-origin.y)*192))
for a in bo.ACTION_ANIMS:
 factor=1.0
 for f in range(bo.ANIMS[a]):
  pose(rig,a,f,bo.ANIMS[a])
  for direction in bo.iso_rig.DIRECTIONS.values():
   root.rotation_euler.z=direction;bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
   for obj in root.children_recursive:
    if obj.type!='MESH' or obj.hide_render:continue
    ev=obj.evaluated_get(dg);coords=np.empty(len(ev.data.vertices)*3,dtype=np.float32);ev.data.vertices.foreach_get('co',coords)
    mat=np.array(ev.matrix_world);world=coords.reshape(-1,3)@mat[:3,:3].T+mat[:3,3];screen=world@proj+pivot
    low=screen.min(axis=0)-pivot;high=screen.max(axis=0)-pivot
    for k in range(2):
     if low[k]<0:factor=min(factor,(pivot[k]-4)/(-low[k]))
     if high[k]>0:factor=min(factor,(188-pivot[k])/high[k])
 FIT[a]=factor
print('FIT', {a:round(v,3) for a,v in FIT.items()},flush=True)

bo.pose=pose
bo.OUT=WORK/'stage';bo.WORK=WORK/'raw';bo.build_model=lambda:(root,rig)
bo.ANIMS={a:bo.ANIMS[a] for a in bo.ACTION_ANIMS}
# Working copy contains the revised keyed actions; never save the source.
bpy.context.preferences.filepaths.save_version=0
for a,n in bo.ANIMS.items():
 rig.animation_data_clear()
 for f in range(n):
  original(rig,a,f,n)
  for b in rig.pose.bones:
   for p in ('rotation_euler','location','scale'):b.keyframe_insert(p,frame=f)
 rig.animation_data.action.name='bourbe_feel_'+a;rig.animation_data.action.use_fake_user=True
rig.animation_data_clear()
bpy.ops.wm.save_as_mainfile(filepath=str(copy))
if '--only-slap' in sys.argv:
 bo.ACTION_ANIMS=('slap',);bo.ANIMS={'slap':7};bo.ALIASES={'attack':'slap'}
if '--probe' in sys.argv:
 for a in bo.ACTION_ANIMS:
  for f in (0,3 if a=='cast_ult' else 2):
   pose(rig,a,f,bo.ANIMS[a]);root.rotation_euler.z=bo.iso_rig.DIRECTIONS['se']
   bo.iso_rig.render_frame(WORK/f'probe_{a}_{f}.png')
 print('PASS probe',flush=True)
else:
 # Suppress the legacy manifest: only requested PNG assets are delivered.
 import inspect
 src=inspect.getsource(bo.render_actor);src=src[:src.index('    # Replace only action')]
 exec(compile(src,bo.__file__,'exec'),bo.__dict__)
 bo.render_actor()
 from halve_emission import downscale
 for a in bo.ACTION_ANIMS:
  for suf in ('','_e'):
   p=bo.OUT/f'{a}{suf}.png';im=Image.open(p).convert('RGBA')
   if suf:im=downscale(im)
   im.save(ROOT/f'game/assets/sprites/characters/bourbe/{a}{suf}.png',optimize=True,compress_level=9)
 for a,b in bo.ALIASES.items():
  for suf in ('','_e'):shutil.copy2(ROOT/f'game/assets/sprites/characters/bourbe/{b}{suf}.png',ROOT/f'game/assets/sprites/characters/bourbe/{a}{suf}.png')
 print('PASS render and delivery',flush=True)
