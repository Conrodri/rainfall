import bpy, math, os, json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
BASE=Path(r'C:\Users\const\Documents\Rainfall\art')
BLEND=BASE/'blender/extras.blend'
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

def downsample_lanczos(im,size):
 import numpy as np
 a=np.array(im.pixels[:],dtype=np.float32).reshape(size*2,size*2,4);a[:,:,:3]*=a[:,:,3:4]
 pos=(np.arange(size)+.5)*2-.5;ix=np.floor(pos[:,None]).astype(int)+np.arange(-5,7)[None,:];delta=(pos[:,None]-ix)/2
 weights=np.sinc(delta)*np.sinc(delta/3);weights[np.abs(delta)>=3]=0;weights/=weights.sum(axis=1,keepdims=True);ix=ix.clip(0,size*2-1)
 a=(a[:,ix,:]*weights[None,:,:,None]).sum(axis=2);a=(a[ix,:,:]*weights[:,:,None,None]).sum(axis=1);a[:,:,3]=a[:,:,3].clip(0,1);a[:,:,:3]/=np.maximum(a[:,:,3:4],1e-7);a=a.clip(0,1);a[a[:,:,3]<.02]=0;a[:,:,3][a[:,:,3]>.98]=1
 out=bpy.data.images.new('Lanczos final',width=size,height=size,alpha=True,float_buffer=False);out.pixels.foreach_set(a.astype(np.float32).ravel());out.file_format='PNG';out.update();bpy.data.images.remove(im);return out

# Scene, camera, lighting, contour and Lanczos copied from pickups_chests_build.py.
UP=Vector((0,math.sin(math.radians(55)),math.cos(math.radians(55))))
FRONT=Vector((0,-math.cos(math.radians(55)),math.sin(math.radians(55))))
def screen(x,y,d=0):return Vector((x,0,0))+UP*y+FRONT*d

def mesh(n,vs,fs,m,p):
 me=bpy.data.meshes.new(n);me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new(n,me);bpy.context.collection.objects.link(o);o.parent=p;o.data.materials.append(m);return o

def line(n,coords,r,m,p):
 cu=bpy.data.curves.new(n,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=3;sp=cu.splines.new('POLY');sp.points.add(len(coords)-1)
 for v,co in zip(sp.points,coords):v.co=(*co,1)
 o=bpy.data.objects.new(n,cu);bpy.context.collection.objects.link(o);o.parent=p;o.data.materials.append(m);return o

def crystal(n,center,length,width,m,p,axis='z',sides=8):
 vs=[(0,0,-length*.50),(0,0,length*.5)]
 for z,r,off in [(-length*.16,width,.0),(length*.20,width*.78,.18)]:
  vs.extend((r*math.cos(i*2*math.pi/sides+off),r*math.sin(i*2*math.pi/sides+off),z) for i in range(sides))
 fs=[]
 for i in range(sides):
  j=(i+1)%sides;fs.extend([(0,2+j,2+i),(2+i,2+j,2+sides+j),(2+i,2+sides+j,2+sides+i),(1,2+sides+i,2+sides+j)])
 if axis=='x':vs=[tuple(screen(z,x,y)) for x,y,z in vs]
 o=mesh(n,vs,fs,m,p);o.location=center;return o

def build():
 assert Path(bpy.data.filepath)==BLEND
 
 for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
 s=setup();s.frame_end=4;s.render.resolution_x=s.render.resolution_y=96
 roots={}
 leather=mat('Bag leather #8A6A3A','8A6A3A',.20,0,.88);fold=mat('Leather folds','6B4A32',.16);rope=mat('Hemp cord','CAB080',.23);gold=mat('Gold #F2C14E','F2C14E',.4,.45,.3)
 r=empty('gold_bag');roots[r.name]=r
 # Rounded low polygon pouch, pinched neck and flared gathered opening.
 vs=[];N=20
 for z,rad in [(.05,.25),(.14,.43),(.42,.48),(.67,.39),(.83,.17),(.96,.23)]:
  for i in range(N):
   a=i*2*math.pi/N;rr=rad*(1+.065*math.cos(a*5));vs.append((rr*math.cos(a),rr*.78*math.sin(a),z+.015*math.cos(a*5)))
 fs=[tuple(reversed(range(N)))]
 for j in range(5):
  for i in range(N):fs.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
 o=mesh('Gathered leather pouch',vs,fs,leather,r);b=o.modifiers.new('Soft leather edges','BEVEL');b.width=.025;b.segments=2;o.modifiers.new('Leather normals','WEIGHTED_NORMAL')
 for a in [-2.7,-2.1,-1.4,-.7]:line('Gathered seam',[(.43*math.cos(a),.35*math.sin(a),.24),(.40*math.cos(a),.32*math.sin(a),.58),(.17*math.cos(a),.14*math.sin(a),.83)],.012,fold,r)
 for z in [.80,.84]:line('Cord around neck',[(.185*math.cos(i*math.pi/24),.15*math.sin(i*math.pi/24),z) for i in range(49)],.021,rope,r)
 line('Tied bow left',[(-.01,-.17,.82),(-.17,-.21,.91),(-.25,-.23,.85),(-.18,-.23,.78),(0,-.17,.82)],.020,rope,r)
 line('Tied bow right',[(0,-.17,.82),(.17,-.23,.91),(.25,-.23,.83),(.16,-.23,.78),(0,-.17,.82)],.020,rope,r)
 for x in [-.07,.08]:line('Loose cord end',[(0,-.18,.82),(x,-.25,.68),(x*1.5,-.25,.61)],.019,rope,r)
 for x,z,a in [(-.11,.95,68),(.07,1.065,80)]:
  o=cyl('Coin peeking out',(x,-.025,z),.135,.045,gold,r);o.rotation_euler=(math.radians(a),.1,-.2)
  o=cyl('Coin embossed face',(x,-.055,z+.015),.092,.048,mat('Gold field '+str(x),'D9A135',.35,.3,.3),r);o.rotation_euler=(math.radians(a),.1,-.2)
 cyan=mat('XP #5FD4E8','5FD4E8',.7,.1,.24);cyan.node_tree.nodes['Principled BSDF'].inputs['Transmission Weight'].default_value=.18
 shadow=mat('XP shadow #2A8FB0','2A8FB0',.5,.1,.28);shine=mat('XP bright facets','A1F2FA',1.25,.1,.22)
 r=empty('xp_gem_big');roots[r.name]=r;o=crystal('Large many faceted XP',screen(0,.65),1.35,.36,cyan,r);o.rotation_euler.z=.22;o.data.materials.append(shadow);o.data.materials.append(shine)
 for f in o.data.polygons:f.material_index=1 if f.index%7==0 else (2 if f.index%7==3 else 0)
 spark=mat('XP glints','BEF8FF',2)
 for x,y,k in [(-.51,.72,.08),(.47,.98,.07),(.39,.20,.05),(-.35,1.23,.045)]:
  # Four pointed glints in camera plane.
  mesh('Cyan star',[screen(x-k,y),screen(x,y+k*1.65),screen(x+k,y),screen(x,y-k*1.65),screen(x,y,.015)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],spark,r)
 # Small halo: transparent emissive sphere behind the gem, made entirely in Blender.
 halo=mat('Soft cyan halo','5FD4E8',.8);nt=halo.node_tree;nt.nodes.clear();out=nt.nodes.new('ShaderNodeOutputMaterial');mix=nt.nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.07;tr=nt.nodes.new('ShaderNodeBsdfTransparent');em=nt.nodes.new('ShaderNodeEmission');em.inputs[0].default_value=(.12,.66,.8,1);em.inputs[1].default_value=.8;nt.links.new(tr.outputs[0],mix.inputs[1]);nt.links.new(em.outputs[0],mix.inputs[2]);nt.links.new(mix.outputs[0],out.inputs[0])
 bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16);o=bpy.context.object;o.name='Subtle cyan halo';o.parent=r;o.location=screen(0,.65,-.18);o.scale=(.43,.43,.67);o.data.materials.append(halo)
 r=empty('ember_shard');roots[r.name]=r
 rim=mat('Ember border #C23B12','C23B12',1.3);orange=mat('Flame #FF7A1F','FF7A1F',3);core=mat('Hot core #FFE9A8','FFE9A8',5);goldfire=mat('Flame gold','FFB347',3)
 axis=empty('Shard axial rotation',screen(.22,.6),r)
 o=crystal('Long pointed ember',Vector((0,0,0)),1.15,.19,rim,axis,'x',6);o.data.materials.append(orange)
 for f in o.data.polygons:f.material_index=f.index%3!=0
 o=crystal('Incandescent central splinter',FRONT*.16,1.0,.085,core,axis,'x',5)
 for i,(dy,tail) in enumerate([(.10,-.91),(-.12,-.83),(.0,-1.02)]):
  o=mesh('Flickering flame ribbon '+str(i),[screen(x,y,.02+i*.015) for x,y in [(tail,.6+dy),(-.66,.72+dy),(-.49,.65+dy),(-.28,.79+dy),(.05,.6),(-.26,.49+dy),(-.48,.57+dy),(-.71,.50+dy)]],[(0,1,2,3,4,5,6,7)],orange if i!=2 else goldfire,r)
  for f in range(5):
   phase=f*math.pi/2;o.scale.z=1+.12*math.sin(phase+i);o.location=UP*(.035*math.sin(phase+i));o.keyframe_insert('scale',frame=f+1);o.keyframe_insert('location',frame=f+1)
 for i,(x,y,k) in enumerate([(-.99,.78,.035),(-.79,.39,.043),(-.59,.85,.025),(-.99,.49,.023)]):
  o=crystal('Flying ember '+str(i),screen(x,y),k*2,k*.5,orange if i%2 else core,r,'x',4)
  for f in range(5):o.location=screen(x+.04*math.sin(f*math.pi/2+i),y+.025*math.cos(f*math.pi/2+i));o.keyframe_insert('location',frame=f+1)
 for f in range(5):axis.rotation_mode='AXIS_ANGLE';axis.rotation_axis_angle=(.12*math.sin(f*math.pi/2),1,0,0);axis.keyframe_insert('rotation_axis_angle',frame=f+1)
 s['asset_roots']=json.dumps(list(roots));s['style_source']='STYLE.md; setup copied verbatim from pickups_chests_build.py'
 # Ignore translucent halo alpha when forming the dark silhouette.
 nt=s.compositing_node_group;rl=next(n for n in nt.nodes if n.bl_idname=='CompositorNodeRLayers');dil=next(n for n in nt.nodes if n.bl_idname=='CompositorNodeDilateErode')
 threshold=nt.nodes.new('ShaderNodeMath');threshold.operation='GREATER_THAN';threshold.inputs[1].default_value=.3;nt.links.new(rl.outputs['Alpha'],threshold.inputs[0]);nt.links.new(threshold.outputs[0],dil.inputs[0])
 for n in roots:fit(n)
 select('gold_bag');bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

def fit(n):
 s=bpy.context.scene;r=bpy.data.objects[n];cam=s.camera;cam.data.ortho_scale=3;cam.data.shift_y=0;bpy.context.view_layer.update();pts=[]
 for f in range(1,5):
  s.frame_set(f);bpy.context.view_layer.update()
  for o in r.children_recursive:
   if o.type=='MESH':pts.extend(world_to_camera_view(s,cam,o.matrix_world@Vector(v)) for v in o.bound_box)
 lo=min(q.y for q in pts);hi=max(q.y for q in pts);left=min(q.x for q in pts);right=max(q.x for q in pts)
 r['ortho_scale']=3*max(hi-lo,right-left)/.78;r['shift_y']=((hi+lo)/2-.5)*3/r['ortho_scale'];r['shift_x']=((right+left)/2-.5)*3/r['ortho_scale']

def select(n,frame=1):
 s=bpy.context.scene
 for name in json.loads(s['asset_roots']):
  for o in [bpy.data.objects[name]]+list(bpy.data.objects[name].children_recursive):o.hide_render=name!=n;o.hide_set(name!=n)
 s.frame_set(frame);r=bpy.data.objects[n];s.camera.data.ortho_scale=r['ortho_scale'];s.camera.data.shift_y=r['shift_y'];s.camera.data.shift_x=r['shift_x'];bpy.context.view_layer.update()

def render(n,frame=1,test=False):
 select(n,frame);s=bpy.context.scene;s.render.resolution_x=s.render.resolution_y=96;s.render.resolution_percentage=100
 out=BASE/'renders'/('_extras_tests' if test else n)
 out=out/(n+'.png') if test else out/'default'/f'x_{frame-1:02d}.png';out.parent.mkdir(parents=True,exist_ok=True);s.render.filepath=str(out);bpy.ops.render.render(write_still=True)
 if not test:
  im=bpy.data.images.load(str(out),check_existing=False);_=im.pixels[:];raw=BASE/'renders/_extras_raw'/n/out.name;raw.parent.mkdir(parents=True,exist_ok=True);im.filepath_raw=str(raw);im.save();im=downsample_lanczos(im,48);im.filepath_raw=str(out);im.save();bpy.data.images.remove(im)
 return str(out)

def tests():return [render(n,test=True) for n in json.loads(bpy.context.scene['asset_roots'])]
def final():
 for n in json.loads(bpy.context.scene['asset_roots']):
  for f in range(1,5) if n=='ember_shard' else [1]:render(n,f)
 select('ember_shard');bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
def companion_passes():
 """Passes seules : cadrage existant, Lanczos 2x, normales OpenGL unitaires.

 Le diffus existant est la reference immuable pour l'alpha, contour et halo inclus.
 Les textures finales sont ecrites par Blender, sans transformation sRGB des normales.
 """
 import sys, hashlib, numpy as np
 sys.path.insert(0,str(BASE/'tools'))
 import passes
 assert Path(bpy.data.filepath).resolve()==BLEND.resolve()
 s=bpy.context.scene
 files=sorted(p for n in ('gold_bag','xp_gem_big','ember_shard') for p in (BASE/'renders'/n/'default').glob('x_*.png'))
 before={str(p):hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
 def pixels(path):
  im=bpy.data.images.load(str(path),check_existing=False);im.colorspace_settings.name='Non-Color';im.alpha_mode='STRAIGHT'
  a=np.array(im.pixels[:],dtype=np.float32).reshape(im.size[1],im.size[0],4);bpy.data.images.remove(im);return a
 def reduce(a):
  pos=(np.arange(48)+.5)*2-.5;ix=np.floor(pos[:,None]).astype(int)+np.arange(-5,7)[None,:];d=(pos[:,None]-ix)/2
  w=np.sinc(d)*np.sinc(d/3);w[np.abs(d)>=3]=0;w/=w.sum(axis=1,keepdims=True);ix=ix.clip(0,95)
  return ((a[:,ix,:]*w[None,:,:,None]).sum(axis=2)[ix,:,:]*w[:,:,None,None]).sum(axis=1)
 report=[]
 for path in files:
  name=path.parents[1].name;frame=int(path.stem.split('_')[1])+1;select(name,frame)
  s.render.resolution_x=s.render.resolution_y=96;s.render.resolution_percentage=100
  diffuse=pixels(path);assert diffuse.shape==(48,48,4)
  objects=[o for o in bpy.data.objects[name].children_recursive if o.type in {'MESH','CURVE'}]
  materials={m for o in objects for m in o.data.materials if m}
  tags={m:dict(m.items()) for m in materials}
  hidden={o:o.hide_render for o in objects}
  try:
   for m in materials:
    m['rainfall_emissive']=False
    m['rainfall_flat_normal']=name=='ember_shard' or m.name.startswith(('XP glints','Soft cyan halo'))
   # Le halo translucide ne doit pas devenir une sphere opaque devant les facettes.
   for o in objects:
    if o.name.startswith('Subtle cyan halo'):o.hide_render=True
   raw=BASE/'renders/_extras_raw'/name/('normal_'+path.name)
   passes.render_normal_pass(raw,scene=s)
   a=pixels(raw);v=a[:,:,:3]*2-1
   weighted=np.concatenate((v*a[:,:,3:4],a[:,:,3:4]),axis=2);low=reduce(weighted)
   v=low[:,:,:3]/np.maximum(low[:,:,3:4],1e-7)
   v[low[:,:,3]<=.02]=(0,0,1)
   norm=np.linalg.norm(v,axis=2,keepdims=True);v=np.where(norm>1e-5,v/np.maximum(norm,1e-7),np.array([0,0,1]))
   if name=='ember_shard':v[:]=(0,0,1)
   a=np.concatenate(((v+1)*.5,diffuse[:,:,3:4]),axis=2);a[diffuse[:,:,3]==0,:3]=(128/255,128/255,1)
   dest=path.parent.parent/'default_n'/path.name;dest.parent.mkdir(parents=True,exist_ok=True)
   im=bpy.data.images.new('Extras normal final',width=48,height=48,alpha=True);im.colorspace_settings.name='Non-Color';im.alpha_mode='STRAIGHT';im.pixels.foreach_set(a.astype(np.float32).ravel());im.filepath_raw=str(dest);im.file_format='PNG';im.save();bpy.data.images.remove(im)
   assert np.array_equal(np.rint(pixels(dest)[:,:,3]*255),np.rint(diffuse[:,:,3]*255))
   if name in {'ember_shard','xp_gem_big'}:
    for o,h in hidden.items():o.hide_render=h
    # Masque blanc : tout le projectile / gemme, etoiles et halo sont emissifs.
    # Le rendu Blender definit le masque et le diffus conserve la couverture exacte.
    for m in materials:
     m['rainfall_emissive']=True
     cached=bpy.data.materials.get('_Rainfall emission '+m.name)
     if cached:bpy.data.materials.remove(cached)
    raw_e=BASE/'renders/_extras_raw'/name/('emission_'+path.name)
    passes.render_emission_pass(raw_e,scene=s)
    # Masque d'intensite unitaire, incluant le halo et les contours emissifs.
    # Render alpha is filtered in the same Lanczos pipeline before authoritative alpha.
    coverage=reduce(pixels(raw_e))
    coverage[:,:,:3]=1;coverage[:,:,3]=diffuse[:,:,3]
    dest_e=path.parent.parent/'default_e'/path.name;dest_e.parent.mkdir(parents=True,exist_ok=True)
    im=bpy.data.images.new('Extras emission mask',width=48,height=48,alpha=True);im.colorspace_settings.name='Non-Color';im.alpha_mode='STRAIGHT';im.pixels.foreach_set(coverage.astype(np.float32).ravel());im.filepath_raw=str(dest_e);im.file_format='PNG';im.save();bpy.data.images.remove(im)
   report.append({'asset':name,'frame':frame-1,'size':[48,48],'alpha_exact':True})
  finally:
   for o,h in hidden.items():o.hide_render=h
   for m,old in tags.items():
    for key in ('rainfall_emissive','rainfall_flat_normal'):
     if key in old:m[key]=old[key]
     elif key in m:del m[key]
 assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in before.items())
 select('ember_shard');s.render.resolution_x=s.render.resolution_y=96
 s['companion_passes']='OpenGL screen: X right, Y up, Z viewer; 96 -> Lanczos 48, normalized; diffuse alpha exact'
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
 (BASE/'renders/_extras_pass_report.json').write_text(json.dumps(report,indent=2))
 return report

if __name__=='__main__':
 bpy.ops.wm.open_mainfile(filepath=str(BLEND));companion_passes()

