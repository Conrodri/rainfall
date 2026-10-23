import bpy, math, os, json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
BASE=Path(r'C:\Users\const\Documents\Rainfall\art')
BLEND=BASE/'blender/pickups_chests.blend'
def mat(n,h,e=.32,metal=0,rough=.78):
 c=[int(h[i:i+2],16)/255 for i in (0,2,4)]; c=[v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in c]
 m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
 for k,v in [('Base Color',(*c,1)),('Roughness',rough),('Metallic',metal),('Emission Color',(*c,1)),('Emission Strength',e)]:p.inputs[k].default_value=v
 return m

def empty(n,loc=(0,0,0),parent=None):
 o=bpy.data.objects.new(n,None);bpy.context.collection.objects.link(o);o.parent=parent;o.location=loc;return o

def cube(n,loc,dim,m,p=None,bev=.035):
 bpy.ops.mesh.primitive_cube_add();o=bpy.context.object;o.name=n;o.dimensions=dim;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.parent=p;o.location=loc;o.data.materials.append(m)
 if bev:
  b=o.modifiers.new('Soft edges','BEVEL');b.width=bev;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o

def cyl(n,loc,r,dep,m,p=None):
 bpy.ops.mesh.primitive_cylinder_add(vertices=48,radius=r,depth=dep);o=bpy.context.object;o.name=n;o.parent=p;o.location=loc;o.data.materials.append(m);b=o.modifiers.new('Rounded rim','BEVEL');b.width=.018;b.segments=3;o.modifiers.new('Normals','WEIGHTED_NORMAL');return o

def gem(n,loc,scale,m,p=None):
 verts=[(0,0,1),(0,0,-1)]+[(math.cos(i*math.pi/2),math.sin(i*math.pi/2),0) for i in range(4)]
 faces=[(0,2+i,2+(i+1)%4) for i in range(4)]+[(1,2+(i+1)%4,2+i) for i in range(4)]
 me=bpy.data.meshes.new(n);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.parent=p;o.location=loc;o.scale=scale;o.data.materials.append(m);return o

def setup():
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [v.identifier for v in s.render.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE';s.render.film_transparent=True;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
 s.world=bpy.data.worlds.new('Rainfall ambient');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.17,.21,.29,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.65
 for name,loc,power,color,kind,size,target in [('Warm upper left',(-3,-4,6),2.4,(1,.76,.53),'SUN',.15,.45),('Cool fill',(3,-2,4),220,(.46,.62,1),'AREA',4,.5),('Cold silhouette rim #9FB8D8',(2,3,4),330,(.624,.722,.847),'AREA',2.5,.55)]:
  d=bpy.data.lights.new(name,kind);d.energy=power;d.color=color
  if kind=='SUN':d.angle=size
  else:d.shape='DISK';d.size=size
  o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,target))-o.location).to_track_quat('-Z','Y').to_euler()
 d=bpy.data.cameras.new('Fixed orthographic 55deg');o=bpy.data.objects.new('Camera',d);s.collection.objects.link(o);t=Vector((0,0,.47));o.location=t+Vector((0,-4*math.cos(math.radians(55)),4*math.sin(math.radians(55))));o.rotation_euler=(t-o.location).to_track_quat('-Z','Y').to_euler();d.type='ORTHO';s.camera=o;s.render.fps=12;s.frame_start=1;s.frame_end=8
 # Subtle dark silhouette generated inside Blender compositor.
 nt=bpy.data.node_groups.new('Pickups contour compositor','CompositorNodeTree');s.compositing_node_group=nt;rl=nt.nodes.new('CompositorNodeRLayers');dil=nt.nodes.new('CompositorNodeDilateErode');dil.inputs['Size'].default_value=1;nt.links.new(rl.outputs['Alpha'],dil.inputs[0]);rgba=nt.nodes.new('CompositorNodeRGB');rgba.outputs[0].default_value=(.0103,.008,.0144,1);sa=nt.nodes.new('CompositorNodeSetAlpha');nt.links.new(rgba.outputs[0],sa.inputs[0]);nt.links.new(dil.outputs[0],sa.inputs[1]);over=nt.nodes.new('CompositorNodeAlphaOver');nt.links.new(sa.outputs[0],over.inputs['Background']);nt.links.new(rl.outputs['Image'],over.inputs['Foreground']);nt.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor');out=nt.nodes.new('NodeGroupOutput');nt.links.new(over.outputs[0],out.inputs[0])
 return s

def build():
 assert Path(bpy.data.filepath)==BLEND
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 s=setup();global GOLD,DARK,IRON,EMBER,CORE
 GOLD=mat('Gold #F2C14E','F2C14E',.4,.45,.3);DARK=mat('Contour #1A1620','1A1620',0);IRON=mat('Iron #4A5565','4A5565',.32,.25,.42);EMBER=mat('Ember #FF7A1F','FF7A1F',1.2);CORE=mat('Golden light','FFE9A8',1.1)
 roots={};poses={}
 r=empty('gold_coin');roots['gold_coin']=r;axis=empty('Coin inclined face',(0,0,.53),r);axis.rotation_euler.x=math.radians(72)
 cyl('Thick gold coin',(0,0,0),.43,.105,mat('Gold edge shadow','A8741A',.4,.4,.3),axis)
 for side in [-1,1]:
  cyl('Raised rim',(0,0,side*.06),.427,.025,GOLD,axis);cyl('Recessed field',(0,0,side*.077),.351,.012,mat('Coin field','D9A135',.4,.35,.3),axis)
  o=cube('Embossed diamond',(0,0,side*.095),(.31,.31,.028),GOLD,axis,.025);o.rotation_euler.z=math.pi/4
  for x in [-.255,.255]:cyl('Relief dot',(x,0,side*.095),.034,.025,GOLD,axis)
 cyan=mat('XP #5FD4E8','5FD4E8',.7,.1,.24);cyan.node_tree.nodes['Principled BSDF'].inputs['Transmission Weight'].default_value=.18
 r=empty('xp_gem');roots['xp_gem']=r;g=gem('Cyan faceted crystal',(0,0,.62),(.34,.34,.59),cyan,r);g.rotation_euler.z=.25
 # Alternate facets retain strong cyan shading.
 g.data.materials.append(mat('XP shadow #2A8FB0','2A8FB0',.5,.1,.28))
 for f in g.data.polygons:f.material_index=f.index%3==0
 for name,w,woodhex,legend in [('chest_small',1.5,'6B4A32',False),('chest_large',1.9,'3F2B1E',False),('chest_legendary',1.9,'291D35',True)]:
  r=empty(name);roots[name]=r;wood=mat(name+' wood',woodhex);trim=GOLD if legend else IRON;dep=.95;h=.68
  cube('Dark cavity floor',(0,0,.12),(w,dep,.12),DARK,r)
  for y in [-dep/2,dep/2]:
   for z in [.17,.39,.61]:cube('Wood plank',(0,y,z),(w,.10,.205),wood,r,.018)
  for x in [-w/2,w/2]:cube('Side wall',(x,0,.36),(.1,dep,.65),wood,r)
  for z in [.07,.69]:
   for y in [-dep/2,dep/2]:cube('Box border',(0,y,z),(w+.09,.09,.075),trim,r)
   for x in [-w/2,w/2]:cube('Box border side',(x,0,z),(.09,dep,.075),trim,r)
  for x in [-w*.35,w*.35]:
   for y in [-.53,.53]:
    cube('Iron strap',(x,y,.38),(.115,.045,.62),trim,r,.012)
    if name!='chest_small':
     for z in [.15,.36,.60]:
      o=cyl('Rivet',(x,y-.025 if y<0 else y+.025,z),.033,.025,GOLD if legend else IRON,r);o.rotation_euler.x=math.pi/2
  lock=GOLD if name!='chest_small' else IRON;cube('Lock plate',(0,-.565,.49),(.22,.08,.29),lock,r);cube('Keyhole',(0,-.611,.49),(.045,.012,.09),DARK,r,.009)
  lid=empty(name+' lid hinge',(0,.48,.72),r);poses[name]=lid
  cube('Lid dark rim',(0,-.48,.035),(w+.12,1.08,.13),trim,lid)
  for j in range(5):cube('Lid board',((j-2)*w/5,-.48,.16),(w/5-.012,1,.22),wood,lid,.055)
  for x in [-w*.35,w*.35]:cube('Lid binding',(x,-.48,.28),(.13,1.06,.055),trim,lid,.018)
  cube('Lid latch',(0,-1.02,.12),(.18,.07,.24),lock,lid)
  treasure=empty(name+' treasure',(0,0,0),r)
  for i in range(13 if legend else 7):
   o=cyl('Treasure coin',((i%4-1.5)*.20,(i//4-1)*.17,.64+(i%2)*.025),.12,.035,GOLD,treasure)
  if legend:
   for x in [-.61,.61]:
    gem('Ruby ember',(x,-.61,.42),(.10,.045,.13),mat('Ruby','C23B12',.8,.1,.25),r)
    for z in [.30,.45,.60]:
     o=cube('Simple rune',(x*.5,-.542,z),(.095,.018,.026),EMBER,r,.006);o.rotation_euler.y=.65 if z==.45 else -.65
   for x,z in [(-.30,1.05),(.05,1.32),(.33,1.03)]:gem('Rising golden mote',(x,0,z),(.045,.045,.085),CORE,treasure)
  ld=bpy.data.lights.new(name+' interior warm','POINT');ld.energy=10 if legend else 3;ld.color=(1,.35,.055);ld.shadow_soft_size=.3;lo=bpy.data.objects.new(ld.name,ld);s.collection.objects.link(lo);lo.parent=treasure;lo.location=(0,0,.85)
  treasure['open_only']=True
  r.scale=(1,.65,.80) if name=='chest_small' else (1,.85,1)
 for name in ['gold_coin','xp_gem']:
  r=roots[name]
  for i in range(9):
   t=2*math.pi*i/8;r.rotation_euler.z=t;r.keyframe_insert('rotation_euler',frame=i+1)
   m=GOLD if name=='gold_coin' else cyan;p=m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'];p.default_value=(.4+.10*math.cos(t)) if name=='gold_coin' else (.7+.25*math.sin(t));p.keyframe_insert('default_value',frame=i+1)
  if r.animation_data:
   for layer in r.animation_data.action.layers:
    for strip in layer.strips:
     for bag in strip.channelbags:
      for fc in bag.fcurves:
       for k in fc.keyframe_points:k.interpolation='LINEAR'
 s['asset_roots']=json.dumps(list(roots));s['style_source']='art/briefs/STYLE.md and ardent_build.py final revised setup';s.frame_set(1)
 for name in roots:fit(name)
 select('chest_legendary','open',1);bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

def descendants(r):return [r]+list(r.children_recursive)
def select(name,pose='default',frame=1):
 s=bpy.context.scene
 for n in json.loads(s['asset_roots']):
  for o in descendants(bpy.data.objects[n]):o.hide_render=n!=name;o.hide_set(n!=name)
 s.frame_set(frame)
 if name.startswith('chest'):
  bpy.data.objects[name+' lid hinge'].rotation_euler.x=math.radians(-105) if pose=='open' else 0
  detail=bpy.data.objects.get(name+' lid interior')
  if detail:
   for o in descendants(detail):o.hide_render=pose!='open';o.hide_set(pose!='open')
  for o in descendants(bpy.data.objects[name+' treasure']):o.hide_render=pose!='open';o.hide_set(pose!='open')
 s.camera.data.ortho_scale=bpy.data.objects[name]['ortho_scale'];s.camera.data.shift_y=bpy.data.objects[name]['shift_y'];bpy.context.view_layer.update()

def fit(name):
 s=bpy.context.scene;r=bpy.data.objects[name];cam=s.camera;cam.data.ortho_scale=3;cam.data.shift_y=0;bpy.context.view_layer.update();cam.data.shift_y=world_to_camera_view(s,cam,Vector((0,0,0))).y-.30
 required=0
 for pose in (['closed','open'] if name.startswith('chest') else ['default']):
  if name.startswith('chest'):bpy.data.objects[name+' lid hinge'].rotation_euler.x=math.radians(-105) if pose=='open' else 0
  for frame in (range(1,9) if not name.startswith('chest') else [1]):
   s.frame_set(frame);bpy.context.view_layer.update()
   for o in descendants(r):
    if o.type!='MESH':continue
    if pose=='closed' and o in bpy.data.objects[name+' treasure'].children_recursive:continue
    for v in o.data.vertices:
     q=world_to_camera_view(s,cam,o.matrix_world@v.co);required=max(required,3*abs(q.x-.5)/.40,3*(q.y-.3)/.64,3*(.3-q.y)/.23)
 required*=1.25 if not name.startswith('chest') else 1
 cam.data.ortho_scale=required;cam.data.shift_y=0;bpy.context.view_layer.update();cam.data.shift_y=world_to_camera_view(s,cam,Vector((0,0,0))).y-.30;r['ortho_scale']=required;r['shift_y']=cam.data.shift_y

def downsample_lanczos(im,size):
 import numpy as np
 a=np.array(im.pixels[:],dtype=np.float32).reshape(size*2,size*2,4);a[:,:,:3]*=a[:,:,3:4]
 pos=(np.arange(size)+.5)*2-.5;ix=np.floor(pos[:,None]).astype(int)+np.arange(-5,7)[None,:];delta=(pos[:,None]-ix)/2
 weights=np.sinc(delta)*np.sinc(delta/3);weights[np.abs(delta)>=3]=0;weights/=weights.sum(axis=1,keepdims=True);ix=ix.clip(0,size*2-1)
 a=(a[:,ix,:]*weights[None,:,:,None]).sum(axis=2);a=(a[ix,:,:]*weights[:,:,None,None]).sum(axis=1);a[:,:,3]=a[:,:,3].clip(0,1);a[:,:,:3]/=np.maximum(a[:,:,3:4],1e-7);a=a.clip(0,1);a[a[:,:,3]<.02]=0;a[:,:,3][a[:,:,3]>.98]=1
 out=bpy.data.images.new('Lanczos final',width=size,height=size,alpha=True,float_buffer=False);out.pixels.foreach_set(a.astype(np.float32).ravel());out.file_format='PNG';out.update();bpy.data.images.remove(im);return out

def render(name,pose='default',frame=1,test=False):
 select(name,pose,frame);s=bpy.context.scene;size=128 if name.startswith('chest') else 48;s.render.resolution_x=s.render.resolution_y=size*2;s.render.resolution_percentage=100
 out=BASE/'renders'/('_pickups_tests' if test else name)
 if test:out=out/(name+'_'+pose+'.png')
 else:out=out/pose/f'x_{frame-1:02d}.png'
 out.parent.mkdir(parents=True,exist_ok=True);s.render.filepath=str(out);bpy.ops.render.render(write_still=True)
 if not test:
  raw=BASE/'renders/_pickups_raw'/name/pose/out.name;raw.parent.mkdir(parents=True,exist_ok=True)
  im=bpy.data.images.load(str(out),check_existing=False);_loaded=im.pixels[:];im.filepath_raw=str(raw);im.save();im=downsample_lanczos(im,size);im.filepath_raw=str(out);im.save();bpy.data.images.remove(im)
 return str(out)
def tests():
 return [render(n,p,test=True) for n in json.loads(bpy.context.scene['asset_roots']) for p in (['closed','open'] if n.startswith('chest') else ['default'])]
def final():
 for n in json.loads(bpy.context.scene['asset_roots']):
  for p in (['closed','open'] if n.startswith('chest') else ['default']):
   for f in (range(1,9) if p=='default' else [1]):render(n,p,f)
 select('chest_legendary','open');bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
def improve_open_lids():
 """Doublure sculptee sous le couvercle, sans changer la silhouette fermee."""
 assert Path(bpy.data.filepath)==BLEND
 for name,w,legend in [('chest_small',1.5,False),('chest_large',1.9,False),('chest_legendary',1.9,True)]:
  old=bpy.data.objects.get(name+' lid interior')
  if old:
   for o in reversed(descendants(old)):bpy.data.objects.remove(o,do_unlink=True)
  hinge=bpy.data.objects[name+' lid hinge'];root=empty(name+' lid interior',parent=hinge)
  trim=next(o.data.materials[0] for o in hinge.children if o.name.startswith('Lid binding'))
  wood=mat(name+' lining','A77449' if not legend else 'A6754C',.08,0,.73)
  recess=mat(name+' lining shadow','493022',.04)
  cube('Inner lid dark surround',(0,-.48,-.045),(w-.04,.94,.065),recess,root,.035)
  for j in range(5):
   cube('Raised inner wood panel',((j-2)*(w-.16)/5,-.48,-.09),((w-.16)/5-.018,.79,.075),wood,root,.025)
  for y in [-.90,-.06]:cube('Interior end rail',(0,y,-.09),(w,.065,.09),trim,root,.018)
  for x in [-w*.35,w*.35]:
   cube('Interior iron binding',(x,-.48,-.135),(.10,.84,.035),trim,root,.012)
   for y in [-.82,-.14]:cyl('Interior rivet',(x,y,-.161),.028,.025,trim,root)
  cube('Interior latch back',(0,-.965,-.08),(.19,.085,.12),trim,root,.018)
  fit(name)
 # Explicit light sources only; diffuse fill emission is not part of the mask.
 for m in bpy.data.materials:
  if m.use_nodes:m['rainfall_emissive']=m.name.startswith(('Ruby','Ember','Golden light'))

def render_auxiliary(name,pose='default',frame=1,emission=False):
 """Passes a taille finale AA, alpha diffus exact et normales renormalisees."""
 import sys,numpy as np
 if str(BASE/'tools') not in sys.path:sys.path.insert(0,str(BASE/'tools'))
 import passes
 select(name,pose,frame);s=bpy.context.scene;size=128 if name.startswith('chest') else 48
 s.render.resolution_x=s.render.resolution_y=size;s.render.resolution_percentage=100
 diffuse=BASE/'renders'/name/pose/f'x_{frame-1:02d}.png'
 target=BASE/'renders'/name/(pose+('_e' if emission else '_n'))/diffuse.name
 (passes.render_emission_pass if emission else passes.render_normal_pass)(target,diffuse,s)
 if not emission:
  im=bpy.data.images.load(str(target),check_existing=False);im.colorspace_settings.name='Non-Color';im.alpha_mode='STRAIGHT'
  a=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4);v=a[:,:3]*2-1;v/=np.maximum(np.linalg.norm(v,axis=1,keepdims=True),1e-8);a[:,:3]=v*.5+.5;a[a[:,3]==0,:3]=(128/255,128/255,1)
  im.pixels.foreach_set(a.ravel());im.filepath_raw=str(target);im.save();bpy.data.images.remove(im)
 return str(target)

def revised_final():
 for n in ['chest_small','chest_large','chest_legendary']:
  for p in ['closed','open']:render(n,p)
 for n in json.loads(bpy.context.scene['asset_roots']):
  for p in (['closed','open'] if n.startswith('chest') else ['default']):
   for f in ([1] if n.startswith('chest') else range(1,9)):render_auxiliary(n,p,f)
   if n=='chest_legendary':render_auxiliary(n,p,emission=True)
 select('chest_legendary','open');bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

if __name__=='__main__':
 bpy.ops.wm.open_mainfile(filepath=str(BLEND));improve_open_lids();revised_final()











