import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../../..'))
OUT=os.path.join(ROOT,'game/assets/sprites/props/epreuve'); BLEND=os.path.join(ROOT,'art/blender/props/ep_e_hold_bell.blend')
os.makedirs(OUT,exist_ok=True); os.makedirs(os.path.dirname(BLEND),exist_ok=True)
def mat(n,c,e=0):
 m=bpy.data.materials.new(n); m.diffuse_color=c; m.use_nodes=True; p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=c; p.inputs['Roughness'].default_value=.88; p.inputs['Metallic'].default_value=.28
 if e: p.inputs['Emission Color'].default_value=c; p.inputs['Emission Strength'].default_value=e
 return m
def box(n,loc,dim,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=n; o.dimensions=dim; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m); b=o.modifiers.new('chipped edges','BEVEL'); b.width=.035;b.segments=1;o.modifiers.new('weighted normals','WEIGHTED_NORMAL');return o
def ico(n,loc,scale,m):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc);o=bpy.context.object;o.name=n;o.scale=scale;o.data.materials.append(m);return o
iron=mat('rusted cast iron',(.20,.105,.075,1)); edge=mat('dark oxide',(.075,.064,.056,1)); ember=mat('ember #F23809',(242/255,56/255,9/255,1),3.0); black=mat('blackened iron',(.035,.032,.03,1)); offglow=mat('dim ember',(242/255,56/255,9/255,1),.16)
def scene(state,angle=0):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 dark=state=='dim'; body=black if dark else iron; glow=black if dark else (ember if state=='ringing' else offglow)
 # square forged post, foot, and upper crossarm
 box('stone foot',(0,0,.075),(.62,.48,.15),edge);box('iron upright',(0,0,1.15),(.16,.17,2.15),edge);box('crossarm',(0,0,2.05),(.72,.18,.16),edge)
 for z in (.29,1.94): ico('rivet',(-.09,-.105,z),(.09,.035,.09),iron)
 pivot=Vector((0,-.12,2.02)); pivotobj=bpy.data.objects.new('bell swing',None);bpy.context.scene.collection.objects.link(pivotobj);pivotobj.location=pivot
 # bell as tapered forged shell, plus crown; pivot swing angle
 bpy.ops.mesh.primitive_cone_add(vertices=10,radius1=.49,radius2=.29,depth=.72,location=pivot+Vector((0,0,-.38)),rotation=(0,0,0));bell=bpy.context.object;bell.name='forged bell';bell.data.materials.append(body);bell.parent=pivotobj;bell.matrix_parent_inverse=pivotobj.matrix_world.inverted()
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=pivot+Vector((0,0,.02)));crown=bpy.context.object;crown.name='bell crown';crown.scale=(.22,.22,.13);crown.data.materials.append(body);crown.parent=pivotobj;crown.matrix_parent_inverse=pivotobj.matrix_world.inverted()
 bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=6,radius=1,location=pivot+Vector((0,0,-.76)));clapper=bpy.context.object;clapper.name='clapper';clapper.scale=(.09,.09,.24);clapper.data.materials.append(edge);clapper.parent=pivotobj;clapper.matrix_parent_inverse=pivotobj.matrix_world.inverted()
 # narrow glowing slit / lower rim
 bpy.ops.mesh.primitive_torus_add(major_radius=.45,minor_radius=.035,major_segments=12,minor_segments=5,location=pivot+Vector((0,-.005,-.73)));rim=bpy.context.object;rim.name='ember rim';rim.data.materials.append(glow);rim.parent=pivotobj;rim.matrix_parent_inverse=pivotobj.matrix_world.inverted()
 # angular weathered iron gallows and braces
 for start,end in (((-.48,0,2.3),(.54,0,2.3)),((-.48,0,2.3),(-.48,0,.25)),((-.48,0,2.3),(-.12,0,1.88)),((.48,0,2.3),(.48,0,.25))):
  a=Vector(start);b=Vector(end);d=b-a; bpy.ops.mesh.primitive_cube_add(size=1,location=(a+b)*.5);q=bpy.context.object;q.dimensions=(.13,.14,d.length);q.rotation_euler[1]=-math.atan2(d.x,d.z);q.data.materials.append(edge)
 # glowing rune band and visible front rivets
 for j in range(9):
  t=math.tau*j/9; x=.38*math.cos(t); y=-.29; z=1.52+.045*math.sin(t*2)
  bpy.ops.mesh.primitive_cube_add(size=1,location=pivot+Vector((x,y,z-2.02)));q=bpy.context.object;q.dimensions=(.035,.025,.09);q.rotation_euler[1]=(j%3-1)*.25;q.data.materials.append(glow)
 pivotobj.rotation_euler[1]=math.radians(angle)
 # camera 3.5 u vertically across 224 px; frame
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=8;s.render.resolution_x=160;s.render.resolution_y=224;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True;s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1;s.render.dither_intensity=0
 d=bpy.data.cameras.new('project iso ortho');c=bpy.data.objects.new('project iso ortho',d);s.collection.objects.link(c);c.location=(4,-6,4.5);target=Vector((0,0,1.15));c.rotation_euler=(target-Vector(c.location)).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=2.25;s.camera=c
 ldata=bpy.data.lights.new('upper left','AREA');l=bpy.data.objects.new('upper left',ldata);s.collection.objects.link(l);l.location=(-3,-4,6);ldata.energy=420;ldata.size=3
 s.world.color=(.045,.045,.045)
 return pivotobj
names=[]
for state in ('off','dim'):
 scene(state);n=f'hold_bell_rust_city_{state}';bpy.context.scene.render.filepath=os.path.join(OUT,n+'.png');bpy.ops.render.render(write_still=True);names.append(n)
# ring frames compose using Blender image editor packing via external simple PNG stitch
for i,a in enumerate((-6,-2,2,6)):
 scene('ringing',a);bpy.context.scene.render.filepath=os.path.join(OUT,f'_ep_e_frame_{i}.png');bpy.ops.render.render(write_still=True)
# isolated emission mask at half resolution, render four then stitch later
for m in bpy.data.materials:
 if m.name in ('rusted cast iron','dark oxide','blackened iron'):
  p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(0,0,0,1);p.inputs['Emission Strength'].default_value=0
 elif m.name=='ember #F23809':
  p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(1,1,1,1);p.inputs['Emission Color'].default_value=(1,1,1,1);p.inputs['Emission Strength'].default_value=3
 elif m.name=='dim ember':
  p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(0,0,0,1);p.inputs['Emission Color'].default_value=(0,0,0,1);p.inputs['Emission Strength'].default_value=0
for i,a in enumerate((-6,-2,2,6)):
 scene('ringing',a);s=bpy.context.scene;s.render.resolution_x=80;s.render.resolution_y=112;s.render.filepath=os.path.join(OUT,f'_ep_e_emit_{i}.png');bpy.ops.render.render(write_still=True)
# shared shadow
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);m=mat('soft charcoal shadow',(.018,.014,.012,1));bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(0,0,.01));o=bpy.context.object;o.scale=(.42,.29,.02);o.data.materials.append(m)
s=bpy.context.scene;d=bpy.data.cameras.new('shadow camera');c=bpy.data.objects.new('shadow camera',d);s.collection.objects.link(c);c.location=(4,-6,4.5);from mathutils import Vector;c.rotation_euler=(Vector((0,0,0))-Vector(c.location)).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=3.5;s.camera=c;s.render.resolution_x=160;s.render.resolution_y=224;s.render.resolution_percentage=100;o.scale=(.62,.42,.02);s.render.filepath=os.path.join(OUT,'hold_bell_rust_city_shadow.png');bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
def stitch(files,path,w,h):
 imgs=[bpy.data.images.load(f,check_existing=False) for f in files]; out=bpy.data.images.new('strip',width=w*len(imgs),height=h,alpha=True); px=[0.0]*(w*len(imgs)*h*4)
 for i,img in enumerate(imgs):
  data=list(img.pixels[:])
  for y in range(h): px[(y*w*len(imgs)+i*w)*4:(y*w*len(imgs)+(i+1)*w)*4]=data[y*w*4:(y+1)*w*4]
 out.pixels[:]=px;out.filepath_raw=path;out.file_format='PNG';out.save()
 for img in imgs: bpy.data.images.remove(img)
stitch([os.path.join(OUT,f'_ep_e_frame_{i}.png') for i in range(4)],os.path.join(OUT,'hold_bell_rust_city_ringing.png'),160,224)
stitch([os.path.join(OUT,f'_ep_e_emit_{i}.png') for i in range(4)],os.path.join(OUT,'hold_bell_rust_city_ringing_e.png'),80,112)
for i in range(4):
 os.remove(os.path.join(OUT,f'_ep_e_frame_{i}.png'));os.remove(os.path.join(OUT,f'_ep_e_emit_{i}.png'))
print('PASS EP-E rendered frames and masks')
