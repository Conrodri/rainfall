import bpy, math, os, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
V=ROOT/'game/assets/sprites/vfx/epreuve'; TMP=ROOT/'art/renders/ep_i_tiles'
V.mkdir(parents=True,exist_ok=True); TMP.mkdir(parents=True,exist_ok=True)
cel.install('vfx',normals=False)
# Same reset, orthographic camera and strip conventions as ep_d_build.py.
def reset(size,iso=False):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 s=bpy.context.scene; cel.setup_scene(); s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=8
 s.render.resolution_x=size*2; s.render.resolution_y=size*2; s.render.resolution_percentage=100
 s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.image_settings.color_depth='8'; s.render.film_transparent=True
 s.view_settings.view_transform='Standard'; s.view_settings.look='None'; s.render.dither_intensity=0
 d=bpy.data.cameras.new('ortho'); c=bpy.data.objects.new('ortho',d); s.collection.objects.link(c)
 c.location=(4,-6,4.5) if iso else (0,0,5); c.rotation_euler=(Vector((0,0,0))-c.location).to_track_quat('-Z','Y').to_euler(); d.type='ORTHO'; d.ortho_scale=3 if iso else 2; s.camera=c
 l=bpy.data.lights.new('upper left','AREA'); o=bpy.data.objects.new('upper left',l); s.collection.objects.link(o); o.location=(-3,-4,6); l.energy=420; l.size=3
 return c

def mat(name,col,alpha=1):
 m=bpy.data.materials.new(name); m.use_nodes=True; n=m.node_tree.nodes; n.clear(); out=n.new('ShaderNodeOutputMaterial'); e=n.new('ShaderNodeEmission'); e.inputs[0].default_value=(*col,1); e.inputs[1].default_value=1
 if alpha<1:
  t=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader'); mix.inputs[0].default_value=alpha; m.node_tree.links.new(t.outputs[0],mix.inputs[1]); m.node_tree.links.new(e.outputs[0],mix.inputs[2]); m.node_tree.links.new(mix.outputs[0],out.inputs[0]); m.surface_render_method='DITHERED'
 else: m.node_tree.links.new(e.outputs[0],out.inputs[0])
 return m

def band(r,w,m,z=0):
 verts=[]; faces=[]
 for i in range(128):
  a=math.tau*i/128
  for q in (r-w/2,r+w/2): verts.append((q*math.cos(a),q*math.sin(a),z))
 for i in range(128): j=(i+1)%128; faces.append((2*i,2*j,2*j+1,2*i+1))
 mesh=bpy.data.meshes.new('annulus'); mesh.from_pydata(verts,[],faces); o=bpy.data.objects.new('annulus',mesh); bpy.context.collection.objects.link(o); o.data.materials.append(m); return o

def render(name):
 cel.toon_materials('vfx'); bpy.context.scene.render.filepath=str(TMP/(name+'.png')); bpy.ops.render.render(write_still=True)

for skin,col in [('fog_forest',(.55,.25,1)),('crypts',(.52,.90,1))]:
 for f in range(8):
  cam=reset(96,True); a=f*math.tau/8; accent=mat('single accent',col); core=mat('warm white',(1,.91,.74)); dark=mat('muted accent',tuple(v*.24 for v in col))
  # Radial translucent geometry provides halo without an emission sidecar.
  for k in range(10,0,-1):
   r=.31+k*.055; halo=mat('halo',col,.018+(10-k)*.003)
   bpy.ops.mesh.primitive_circle_add(vertices=48,radius=r,fill_type='NGON'); o=bpy.context.object; o.rotation_euler=cam.rotation_euler; o.location=cam.location.normalized()*(-.12-k*.003); o.data.materials.append(halo)
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.34+.025*math.sin(a)); o=bpy.context.object; o.scale=(.8,.8,1.35 if skin=='fog_forest' else 1.6); o.rotation_euler=(.2,a,.3); o.data.materials.append(accent)
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.18,location=cam.location.normalized()*.28); o=bpy.context.object; o.scale=(.72,.72,1.5); o.data.materials.append(core)
  for i in range(5):
   t=a+i*math.tau/5; pos=(.62*math.cos(t),.40*math.sin(t),.22*math.sin(t*2+a))
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.065 if i%2 else .095,location=pos); o=bpy.context.object; o.scale=(.65,.65,2 if skin=='crypts' else 1.4); o.rotation_euler=(.3,t,t); o.data.materials.append(core if i==0 else accent)
  render(f'chase_light_{skin}_{f}')
reset(256); gold=mat('neutral pale gold',(.71,.60,.39)); band(.952,.012,gold)
for i in range(32):
 a=i*math.tau/32
 bpy.ops.mesh.primitive_cube_add(size=1,location=(.916*math.cos(a),.916*math.sin(a),.002)); o=bpy.context.object; o.dimensions=(.040 if i%4==0 else .020,.009,.002); o.rotation_euler[2]=a; o.data.materials.append(gold)
 if i%4==0:
  o=band(.875,.008,gold); break
# Discrete rune ticks, with paired cross strokes at cardinal divisions.
for i in range(32):
 a=i*math.tau/32
 bpy.ops.mesh.primitive_cube_add(size=1,location=(.918*math.cos(a),.918*math.sin(a),.003)); o=bpy.context.object; o.dimensions=(.047 if i%4==0 else .022,.008,.003); o.rotation_euler[2]=a; o.data.materials.append(gold)
render('ring_zone')
reset(256)
for k in range(12):
 offset=(k-5.5)*.012; alpha=max(.05,1-abs(k-5.5)/6)**1.3; band(.90+offset,.013,mat('soft warm wave',(1,.91,.76),alpha),k*.0001)
render('ring_wave')
(ROOT/'art/blender/props').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/props/ep_i_fx.blend'))
print('PASS EP-I Blender: 18 renders, no normal or emission sidecars')
# Pillow only assembles/resizes and verifies the rendered geometry.
import subprocess
with open(ROOT/'art/renders/ep_i_verify.log','w') as log:
 subprocess.run(['python',str(ROOT/'art/tools/epreuve/ep_i_finish.py')],cwd=str(ROOT),stdout=log,stderr=subprocess.STDOUT,check=True)
