import bpy, math, os
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../../..'))
P=os.path.join(ROOT,'game/assets/sprites/props/epreuve'); V=os.path.join(ROOT,'game/assets/sprites/vfx/epreuve')
os.makedirs(P,exist_ok=True); os.makedirs(V,exist_ok=True); os.makedirs(os.path.join(ROOT,'art/blender/props'),exist_ok=True)
SKINS={'fog_forest':((.24,.115,.065,1),(.76,.294,1,1)),'crypts':((.20,.235,.27,1),(.749,.957,1,1))}
def mat(n,c,e=0):
 m=bpy.data.materials.new(n); m.diffuse_color=c; m.use_nodes=True; p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=c; p.inputs['Roughness'].default_value=.9
 if e: p.inputs['Emission Color'].default_value=c; p.inputs['Emission Strength'].default_value=e
 return m
def reset():
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def setup(x,y,scale,target):
 s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=8
 s.render.resolution_x=x; s.render.resolution_y=y; s.render.resolution_percentage=100; s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True; s.view_settings.view_transform='Standard'; s.view_settings.look='None'; s.view_settings.exposure=0; s.view_settings.gamma=1
 d=bpy.data.cameras.new('ortho'); c=bpy.data.objects.new('ortho',d); s.collection.objects.link(c); c.location=(4,-6,4.5); c.rotation_euler=(Vector(target)-Vector(c.location)).to_track_quat('-Z','Y').to_euler(); d.type='ORTHO'; d.ortho_scale=scale; s.camera=c
 l=bpy.data.lights.new('upper left','AREA'); o=bpy.data.objects.new('upper left',l); s.collection.objects.link(o); o.location=(-3,-4,6); l.energy=420; l.size=3
def render(path):
 bpy.context.scene.render.filepath=path; bpy.ops.render.render(write_still=True)
def source(skin,state):
 reset(); base,accent=SKINS[skin]; stone=mat('worn slate',base); glow=mat('skin accent',accent,2.5 if state=='on' else .15)
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(0,0,.70)); o=bpy.context.object; o.name='vein outcrop'; o.scale=(.69,.34,.68); o.data.materials.append(stone)
 # branching V fissures laid across front face
 for i in range(5):
  x=(i-2)*.19; z=.42+(.14 if i%2 else 0)
  for side in (-1,1):
   a=Vector((x,-.355,z)); b=Vector((x+side*.115,-.352,z+.20)); d=b-a
   bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)*.5); q=bpy.context.object; q.dimensions=(.027,.018,d.length); q.rotation_euler[1]=-math.atan2(d.x,d.z); q.data.materials.append(glow)
 bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=.105,radius2=.025,depth=.32,location=(0,0,1.35)); bpy.context.object.data.materials.append(glow if state=='on' else stone)
 setup(128,160,2,(0,0,.70)); render(os.path.join(P,f'vein_source_{skin}_{state}.png'))
 if state=='on':
  for obj in bpy.data.objects:
   if obj.type=='MESH' and obj.name.startswith('Cube') and len(obj.data.materials): obj.data.materials[0]=glow
  # render isolated emission as half resolution
  for m in bpy.data.materials:
   if m.name in ('worn slate','skin accent'):
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(0,0,0,1); p.inputs['Emission Color'].default_value=(1,1,1,1); p.inputs['Emission Strength'].default_value=3 if m.name=='skin accent' else 0
  bpy.context.scene.render.resolution_x=64; bpy.context.scene.render.resolution_y=80; render(os.path.join(P,f'vein_source_{skin}_on_e.png'))
 # soft ground shadow via transparent ellipse geometry
 reset(); shadow=mat('shadow',(.018,.018,.022,1)); bpy.ops.mesh.primitive_circle_add(vertices=32,radius=.43,fill_type='NGON',location=(0,0,0)); bpy.context.object.scale.y=.48; bpy.context.object.data.materials.append(shadow); setup(128,160,2,(0,0,0)); render(os.path.join(P,f'vein_source_{skin}_shadow.png'))
def disc(skin):
 reset(); accent=SKINS[skin][1]; s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=8; s.render.resolution_x=256; s.render.resolution_y=256; s.render.resolution_percentage=100; s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True
 # top down orthographic ground plane, animated pulse frames rendered separately to temporary tiles
 d=bpy.data.cameras.new('top ortho'); c=bpy.data.objects.new('top ortho',d); s.collection.objects.link(c); c.location=(0,0,5); c.rotation_euler=(0,0,0); d.type='ORTHO'; d.ortho_scale=2.7; s.camera=c
 for frame in range(4):
  reset(); # camera recreated after reset
  d=bpy.data.cameras.new('top ortho'); c=bpy.data.objects.new('top ortho',d); s.collection.objects.link(c); c.location=(0,0,5); c.rotation_euler=(0,0,0); d.type='ORTHO'; d.ortho_scale=2.7; s.camera=c
  r=.94+.035*math.sin(frame*math.pi/2)
  glow=mat('vein accent',accent,1.6+frame*.45); fill=mat('translucent fill',(*accent[:3],.22),.25); fill.surface_render_method='DITHERED'
  bpy.ops.mesh.primitive_circle_add(vertices=64,radius=r,fill_type='NGON'); bpy.context.object.data.materials.append(fill)
  bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=.014+frame*.008,major_segments=64,minor_segments=8); bpy.context.object.data.materials.append(glow)
  for i in range(12):
   a=math.tau*i/12; bpy.ops.mesh.primitive_cube_add(size=1,location=(math.cos(a)*r*.52,math.sin(a)*r*.52,.012)); o=bpy.context.object; o.dimensions=(r*.9,.018,.015); o.rotation_euler[2]=a; o.data.materials.append(glow)
  s.render.filepath=os.path.join(V,f'.vein_disc_{skin}_{frame}.png'); bpy.ops.render.render(write_still=True)
 # stitch using Blender image editor API
 imgs=[bpy.data.images.load(os.path.join(V,f'.vein_disc_{skin}_{i}.png'),check_existing=False) for i in range(4)]; out=bpy.data.images.new('disc strip',width=1024,height=256,alpha=True); px=[0.0]*(1024*256*4)
 for i,img in enumerate(imgs):
  data=list(img.pixels[:]);
  for y in range(256): px[(y*1024+i*256)*4:(y*1024+(i+1)*256)*4]=data[y*256*4:(y+1)*256*4]
 out.pixels[:]=px; out.filepath_raw=os.path.join(V,f'vein_disc_{skin}.png'); out.file_format='PNG'; out.save();
 for i in range(4): os.remove(os.path.join(V,f'.vein_disc_{skin}_{i}.png'))
def geyser(skin):
 # create six 128x192 images via same scene, animate height and concatenate using bpy pixels
 reset(); base,accent=SKINS[skin]; glow=mat('geyser accent',accent,1.8); stone=mat('dark shard',base)
 tiles=[]
 for f in range(6):
  reset(); h=(.55,2.15,2.75,2.95,2.45,.62)[f]; spread=(.32,.72,.88,.92,.78,.36)[f]
  # broad luminous fountain with dark crystal ribs; animated silhouette and height
  for i in range(13):
   x=(i-6)*spread/6; hh=h*(.62+.36*((i*7+f*3)%13)/12); lean=x*.18
   bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.09+spread*.09,radius2=.012,depth=hh,location=(x+lean,0,.08+hh*.5)); q=bpy.context.object; q.rotation_euler[1]=-.18 if x>0 else .18; q.data.materials.append(glow if i%4 else stone)
  # bright central plume and a wide foot flare
  bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=spread*.82,radius2=.025,depth=h*.94,location=(0,-.01,.14+h*.47)); bpy.context.object.data.materials.append(glow)
  bpy.ops.mesh.primitive_torus_add(major_radius=spread*.62,minor_radius=.055,major_segments=16,minor_segments=5,location=(0,-.02,.12)); bpy.context.object.data.materials.append(glow)
  # Secondary droplets widen the erupting base.
  for i in range(7):
   x=(i-3)*spread*.23; z=.28+(.16*((i*5+f)%4)); bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(x,-.04,z)); bpy.context.object.scale=(.11,.09,.13); bpy.context.object.data.materials.append(glow)
  setup(128,192,3.35,(0,0,1.15)); path=os.path.join(V,f'.vein_geyser_{skin}_{f}.png'); render(path); tiles.append(bpy.data.images.load(path,check_existing=False))
 out=bpy.data.images.new('geyser strip',width=768,height=192,alpha=True); px=[0.0]*(768*192*4)
 for i,img in enumerate(tiles):
  data=list(img.pixels[:]);
  for y in range(192): px[(y*768+i*128)*4:(y*768+(i+1)*128)*4]=data[y*128*4:(y+1)*128*4]
 out.pixels[:]=px; out.filepath_raw=os.path.join(V,f'vein_geyser_{skin}.png'); out.file_format='PNG'; out.save()
 for f in range(6): os.remove(os.path.join(V,f'.vein_geyser_{skin}_{f}.png'))
reset(); setup(128,160,2,(0,0,.4));
for skin in SKINS:
 for state in ('off','on'): source(skin,state)
 disc(skin); geyser(skin)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art/blender/props/ep_d_vein.blend'))
print('EP-D build complete')
