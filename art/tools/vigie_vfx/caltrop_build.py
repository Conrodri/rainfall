import bpy, math, os
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..','..'))
OUT=os.path.join(ROOT,'game/assets/sprites/characters/vigie/caltrop_field')
os.makedirs(OUT,exist_ok=True)
os.makedirs(os.path.join(ROOT,'art/blender'),exist_ok=True)
sc=bpy.context.scene
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
sc.render.engine='BLENDER_EEVEE'; sc.eevee.taa_render_samples=16
sc.render.film_transparent=True; sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGBA'; sc.render.image_settings.color_depth='8'
sc.view_settings.view_transform='Standard'; sc.view_settings.look='Medium High Contrast'; sc.view_settings.exposure=0; sc.view_settings.gamma=1
sc.render.resolution_x=576; sc.render.resolution_y=576; sc.render.resolution_percentage=100
sc.world.color=(0.025,0.025,0.025)
def mat(name,color,metal=0,rough=.8,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF'); bs.inputs['Base Color'].default_value=(*color,1); bs.inputs['Metallic'].default_value=metal; bs.inputs['Roughness'].default_value=rough
 if emit: bs.inputs['Emission Color'].default_value=(*color,1); bs.inputs['Emission Strength'].default_value=emit
 return m
iron=mat('forged bright steel',(.34,.39,.43),.72,.3); edge=mat('cel-cut bright steel ridge',(.88,.93,.96),.35,.27); red=mat('signal ember',(1,.025,.065),.1,.5,2.3)
def set_alpha(m,a):
 m.node_tree.nodes.get('Principled BSDF').inputs['Alpha'].default_value=a
 m.surface_render_method='DITHERED'
# lights and top camera
ld=bpy.data.lights.new('large upper-left','AREA'); lo=bpy.data.objects.new('large upper-left',ld); sc.collection.objects.link(lo); lo.location=(-3,4,7); ld.energy=480; ld.size=5
ld2=bpy.data.lights.new('soft fill','AREA'); lo2=bpy.data.objects.new('soft fill',ld2); sc.collection.objects.link(lo2); lo2.location=(4,-3,5); ld2.energy=110; ld2.size=5
cd=bpy.data.cameras.new('TOP 96px per unit'); cam=bpy.data.objects.new('TOP 96px per unit',cd); sc.collection.objects.link(cam); cam.location=(0,0,12); cam.rotation_euler=(0,0,0); cd.type='ORTHO'; cd.ortho_scale=6; sc.camera=cam
# 48 Vogel distribution, four long conical tetrahedral prongs each
shadow=mat('soft short contact shadow',(.018,.024,.032))
def spike(name,base,tip,radius,material):
 axis=Vector(tip)-Vector(base); mid=(Vector(tip)+Vector(base))*.5
 bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=radius, radius2=.006, depth=axis.length, location=mid)
 ob=bpy.context.object; ob.name=name; ob.rotation_mode='QUATERNION'; ob.rotation_quaternion=axis.to_track_quat('Z','Y'); ob.data.materials.append(material)
 for p in ob.data.polygons:
  if p.normal.z > .4: p.material_index=0
 return ob
for i in range(48):
 r=2.82*math.sqrt((i+.5)/48); a=i*math.pi*(3-math.sqrt(5)); x=r*math.cos(a); y=r*math.sin(a); z=-.04
 size=.375+(.025*((i*7)%5)); rot=(i*2.399963)% (2*math.pi); spread=size*.28; length=size*.91
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=1,location=(x+.045,y-.045,-.115)); sh=bpy.context.object; sh.name='soft short contact shadow'; sh.scale=(size*.52,size*.22,.006); sh.data.materials.append(shadow)
 # Three ground spikes radiate evenly; the fourth rises vertically.
 for j in range(3):
  ang=rot+j*2*math.pi/3; dx=math.cos(ang); dy=math.sin(ang)
  spike('Caltrop_%02d_ground_%d'%(i,j),(x-dx*length*.5,y-dy*length*.5,z),(x+dx*length*.5,y+dy*length*.5,z+.018),size*.072,iron)
  # narrow bright ridge along the exposed side
  spike('Caltrop_%02d_edge_%d'%(i,j),(x-dx*length*.42-dy*size*.035,y-dy*length*.42+dx*size*.035,z+.012),(x+dx*length*.43-dy*size*.035,y+dy*length*.43+dx*size*.035,z+.025),size*.023,edge)
 spike('Caltrop_%02d_upright'%i,(x,y,z),(x+math.cos(rot)*spread,y+math.sin(rot)*spread,z+length),size*.082,iron)
 if i in (2,8,14,20,26,32,38,44):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.026,location=(x+math.cos(rot)*spread,y+math.sin(rot)*spread,z+length*.94)); bpy.context.object.name='red ember'; bpy.context.object.data.materials.append(red)
# utility render atlases from same fixed scene; end alpha fade and rust tint
from mathutils import Color

def hide_embers(v):
 for ob in sc.objects:
  if ob.name.startswith('red ember'): ob.hide_render=not v

def render_sheet(anim,n,cols,alpha):
 w=cols*576; h=math.ceil(n/cols)*576
 # render each frame then assemble with Blender image pixels
 sc.render.resolution_x=576; sc.render.resolution_y=576; sc.render.filepath=''
 frames=[]
 for f in range(n):
  hide_embers(anim=='default' and f%2==0)
  factor=alpha[f] if anim=='end' else 1
  for ob in sc.objects:
   if ob.name.startswith('Caltrop'):
    for m in ob.data.materials:
     if m:
      bs=m.node_tree.nodes.get('Principled BSDF')
      if bs:
       bs.inputs['Alpha'].default_value=factor
       if anim=='end' and f>0: bs.inputs['Base Color'].default_value=(.24,.12,.08,1)
  sc.render.filepath=os.path.join(OUT,'_tmp_%s_%d.png'%(anim,f)); bpy.ops.render.render(write_still=True)
  im=bpy.data.images.load(sc.render.filepath); frames.append(list(im.pixels[:]))
 sheet=bpy.data.images.new(anim+'_sheet',width=w,height=h,alpha=True)
 px=[0.0]*(w*h*4)
 for idx,pix in enumerate(frames):
  ox=(idx%cols)*576; oy=(idx//cols)*576
  for row in range(576):
   src=row*576*4; dst=((oy+row)*w+ox)*4; px[dst:dst+576*4]=pix[src:src+576*4]
 sheet.pixels[:]=px; sheet.filepath_raw=os.path.join(OUT,anim+'.png'); sheet.file_format='PNG'; sheet.save(); bpy.data.images.remove(sheet)
 for f in range(n):
  p=os.path.join(OUT,'_tmp_%s_%d.png'%(anim,f))
  if os.path.exists(p): os.remove(p)
render_sheet('default',4,4,[1]*4); render_sheet('end',3,3,[1,.6,.25])
# emission atlas: red-only sparse markers, rendered in half resolution using emission materials
for ob in sc.objects:
 ob.hide_render=not ob.name.startswith('red ember')
 if ob.name.startswith('red ember'):
  ob.hide_render=False
sc.render.resolution_percentage=50
for anim,n,cols in [('default',4,4),('end',3,3)]:
 # constant low red dot masks; animated flicker via material strength
 ims=[]
 for f in range(n):
  for ob in sc.objects:
   if ob.name.startswith('red ember'):
    bs=ob.data.materials[0].node_tree.nodes.get('Principled BSDF'); bs.inputs['Emission Strength'].default_value=(1.2 if f%2==0 else .65)
  sc.render.filepath=os.path.join(OUT,'_tmp_e_%s_%d.png'%(anim,f)); bpy.ops.render.render(write_still=True)
  im=bpy.data.images.load(sc.render.filepath); ims.append(list(im.pixels[:]))
 w=cols*288; h=math.ceil(n/cols)*288; sh=bpy.data.images.new('emission',width=w,height=h,alpha=True); px=[0.0]*(w*h*4)
 for idx,pix in enumerate(ims):
  ox=idx%cols*288; oy=idx//cols*288
  for row in range(288):
   src=row*288*4; dst=((oy+row)*w+ox)*4; px[dst:dst+288*4]=pix[src:src+288*4]
 sh.pixels[:]=px; sh.filepath_raw=os.path.join(OUT,anim+'_e.png'); sh.file_format='PNG'; sh.save(); bpy.data.images.remove(sh)
 for f in range(n):
  p=os.path.join(OUT,'_tmp_e_%s_%d.png'%(anim,f));
  if os.path.exists(p): os.remove(p)
# restore regular world


for ob in sc.objects: ob.hide_render=False
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'art/blender/caltrop_field.blend'))

