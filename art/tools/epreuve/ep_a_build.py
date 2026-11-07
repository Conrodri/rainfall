import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../../..'))
OUT=os.path.join(ROOT,'game/assets/sprites/props/epreuve'); BLEND=os.path.join(ROOT,'art/blender/props/ep_a_escort_boat.blend')
os.makedirs(OUT,exist_ok=True); os.makedirs(os.path.dirname(BLEND),exist_ok=True)
WOOD=(138/255,106/255,74/255,1); DARK=(.075,.07,.063,1); WATER=(20/255,214/255,176/255,1); EDGE=(216/255,194/255,154/255,1)
def mat(name,c,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=c; m.use_nodes=True; p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=c; p.inputs['Roughness'].default_value=.9
 if emit: p.inputs['Emission Color'].default_value=c; p.inputs['Emission Strength'].default_value=4
 return m
def box(name,loc,dim,m,bev=.02):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name;o.dimensions=dim;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if bev: b=o.modifiers.new('worn edge','BEVEL');b.width=bev;b.segments=1;o.modifiers.new('weighted normals','WEIGHTED_NORMAL')
 return o
wood=mat('weathered oak',WOOD);alternate=mat('sun bleached boards',(.40,.31,.21,1));iron=mat('tarred iron',DARK);glow=mat('bow lantern water accent',WATER,4);edge=mat('pale oak edge',EDGE)
def scene(angle,mode='color'):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 if mode=='shadow':
  shadow=mat('soft shadow',(.015,.014,.013,1)); bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=8,radius=1,location=(.035*math.cos(math.radians(angle)),.035*math.sin(math.radians(angle)),.01));o=bpy.context.object;o.scale=(.94,.48,.025);o.data.materials.append(shadow);o.rotation_euler[2]=math.radians(angle)
 else:
  # Hull length 1.5 u and beam 1.0 u, bow points local +X.
  box('keel',(0,0,.18),(1.50,.42,.14),iron)
  for j in range(5):
   y=(j-2)*.19
   # tapered plank silhouette, individually laid for visible seams
   length=1.65-abs(y)*.48
   box('oak hull plank',(0,y,.27),(length,.17,.18),wood if j%2 else alternate,.035)
  for y in (-.39,.39): box('bright upper gunwale',(0,y,.40),(1.48,.035,.055),edge,.012)
  for x in (-.57,.57):
   box('raised prow and stern',(x,0,.39),(.20,.88,.34),wood,.04)
  for i in range(5): box('deck plank',(-.22+i*.11,0,.38),(.085,.68,.055),alternate if i%2 else wood,.012)
  box('bench',(-.15,0,.52),(.19,.76,.08),iron,.015)
  # Hooded passenger, seated low; angular cloak and hood.
  cloak=mat('dark travel cloak',(60/255,74/255,92/255,1)); hood=mat('blue gray hood',(107/255,127/255,149/255,1)); face=mat('visible face',(.72,.53,.38,1)); box('passenger body',(.03,0,.67),(.36,.37,.48),cloak,.07)
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(.05,0,.98));o=bpy.context.object;o.name='hood';o.scale=(.19,.18,.21);o.data.materials.append(hood)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=1,location=(.12,-.14,.96));o=bpy.context.object;o.name='visible face';o.scale=(.075,.035,.095);o.data.materials.append(face)
  # front lantern mounted on the bow tip
  box('lantern frame',(.82,0,.53),(.13,.16,.24),iron,.025);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(.83,-.01,.54));o=bpy.context.object;o.scale=(.11,.11,.13);o.data.materials.append(glow)
  # Local boat +X faces screen-right at direction e, rotated by requested 45°.
  root=bpy.data.objects.new('boat heading',None);bpy.context.scene.collection.objects.link(root);root.rotation_euler[2]=math.radians(angle)
  for o in list(bpy.context.scene.objects):
   if o.type=='MESH': o.parent=root
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=8;s.render.resolution_x=160;s.render.resolution_y=112;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True;s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1;s.render.dither_intensity=0
 d=bpy.data.cameras.new('fixed iso camera');c=bpy.data.objects.new('fixed iso camera',d);s.collection.objects.link(c);c.location=(4,-6,4.5);target=Vector((0,0,.67));c.rotation_euler=(target-Vector(c.location)).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';d.ortho_scale=1.9;s.camera=c
 ld=bpy.data.lights.new('high left','AREA');lo=bpy.data.objects.new('high left',ld);s.collection.objects.link(lo);lo.location=(-3,-4,6);ld.energy=420;ld.size=3
 s.world.color=(.045,.045,.045)
def stitch(tiles,path,w,h):
 imgs=[bpy.data.images.load(p,check_existing=False) for p in tiles];out=bpy.data.images.new('horizontal strip',width=w*len(imgs),height=h,alpha=True);px=[0.0]*(w*len(imgs)*h*4)
 for i,img in enumerate(imgs):
  data=list(img.pixels[:])
  for y in range(h):px[(y*w*len(imgs)+i*w)*4:(y*w*len(imgs)+(i+1)*w)*4]=data[y*w*4:(y+1)*w*4]
 out.pixels[:]=px;out.filepath_raw=path;out.file_format='PNG';out.save()
 for img in imgs:bpy.data.images.remove(img)
angles=(0,45,90,135,180,225,270,315)
for mode,suffix,height in (('color','','112'),('emit','_e','56'),('shadow','_shadow','112')):
 temps=[]
 for i,a in enumerate(angles):
  scene(a,mode)
  if mode=='emit':
   for m in bpy.data.materials:
    p=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
    if p:
     if m.name=='bow lantern water accent':p.inputs['Base Color'].default_value=(1,1,1,1);p.inputs['Emission Color'].default_value=(1,1,1,1);p.inputs['Emission Strength'].default_value=4
     else:p.inputs['Base Color'].default_value=(0,0,0,1);p.inputs['Emission Color'].default_value=(0,0,0,1);p.inputs['Emission Strength'].default_value=0
  s=bpy.context.scene
  if mode=='emit':s.render.resolution_x=80;s.render.resolution_y=56
  path=os.path.join(OUT,f'_ep_a_{mode}_{i}.png');s.render.filepath=path;bpy.ops.render.render(write_still=True);temps.append(path)
 name='escort_boat_terraces'+suffix+'.png';stitch(temps,os.path.join(OUT,name),80 if mode=='emit' else 160,56 if mode=='emit' else 112)
 for p in temps:os.remove(p)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print('PASS EP-A 8 headings, emission, shadow')
