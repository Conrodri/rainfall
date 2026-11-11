from pathlib import Path
import sys, math, random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/menu/crypte_veilleuse'; WORK=ROOT/'art/blender/cel/cosmetics'; SIZE=(256,256); FRAMES=12
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
import bpy
from mathutils import Vector
import iso_rig as rig, cel_style as cel
C=rig.common
from PIL import Image, ImageFilter
def mat(n,c,e=0): return C.material(n,c,roughness=.82,emission=e)
def cone(n,p,r1,r2,h,m,v=9):
 bpy.ops.mesh.primitive_cone_add(vertices=v,radius1=r1,radius2=r2,depth=h,location=p);o=bpy.context.object;o.name=n;o.data.materials.append(m);return o
def ico(n,p,s,m):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p);o=bpy.context.object;o.name=n;o.scale=s;o.data.materials.append(m);return o
def render(path,size):
 cel.setup_scene(samples=8);cel.toon_materials('prop')
 s=bpy.context.scene;s.use_nodes=False;s.render.resolution_x,s.render.resolution_y=size;s.render.resolution_percentage=100
 s.render.filepath=str(path);bpy.ops.render.render(write_still=True)

def rig_scene(size,scale):
 s=rig.create_rig('MAP',size,target=(0,0,.65));s.render.resolution_percentage=100;s.camera.data.ortho_scale=scale;return s
def save_shadow(name,size):
 with Image.open(OUT/(name+'.png')) as im: a=im.getchannel('A')
 m=Image.new('L',size,0);m.paste(a,(max(2,size[0]//12),max(2,size[1]//10)));m=m.filter(ImageFilter.GaussianBlur(3));sh=Image.new('RGBA',size,(35,35,35,0));sh.putalpha(m.point(lambda x:int(x*.5)));sh.save(OUT/(name+'_shadow.png'),optimize=True)
FLAME_BASES = [(108,182),(121,173),(137,178),(122,187),(131,186),(147,187),(139,200)]

def fire():
 s=rig_scene(SIZE,256)
 cel.install('prop',normals=False)
 cel.setup_scene(samples=16)
 s.use_nodes=False
 s.render.resolution_x=s.render.resolution_y=256
 s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA'
 s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1
 s.render.dither_intensity=0
 basis=s.camera.rotation_euler.to_matrix();origin=Vector((0,0,.65))
 def world(x,y,depth): return origin+basis@Vector((x-128,128-y,depth))
 def material(name,color,alpha=1):
  m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;n.clear()
  out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission')
  em.inputs['Color'].default_value=tuple(((v/255+0.055)/1.055)**2.4 if v>10 else v/3294.6 for v in color)+(1,)
  if alpha<1:
   tr=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');mix.inputs[0].default_value=alpha
   m.node_tree.links.new(tr.outputs[0],mix.inputs[1]);m.node_tree.links.new(em.outputs[0],mix.inputs[2]);m.node_tree.links.new(mix.outputs[0],out.inputs[0])
   m.surface_render_method='DITHERED'
  else:m.node_tree.links.new(em.outputs[0],out.inputs[0])
  return m
 edge=material('Flame #FFC878',(255,200,120));heart=material('Heart #FFE9A8',(255,233,168))
 halos=[material('Halo #FFB060 ring '+str(j),(255,176,96),(.25*(1-j/10)**2-.25*(1-(j+1)/10)**2)/(1-.25*(1-(j+1)/10)**2)) for j in range(10)]
 def mesh(name,points,depth,mat):
  verts=[world(x,y,depth) for x,y in points];me=bpy.data.meshes.new(name);me.from_pydata(verts,[],[tuple(range(len(verts)))]);me.update()
  ob=bpy.data.objects.new(name,me);s.collection.objects.link(ob);ob.data.materials.append(mat);return ob
 def drop(cx,cy,width,height,sway,depth,mat):
  # Smooth sampled outline, a fixed narrow base and a swaying tapered tip.
  points=[]
  for side,steps in ((1,range(41)),(-1,range(40,-1,-1))):
   for j in steps:
    t=j/40;radius=width*.5*(math.sin(math.pi*t)**.78)*(1.25-.65*t)
    points.append((cx+sway*t*t+side*radius,cy-height*t))
  return mesh('Smooth candle flame',points,depth,mat)
 def objects(frame,only=None):
  for i,(cx,cy) in enumerate(FLAME_BASES):
   if only is not None and i!=only:continue
   t=frame*math.tau/FRAMES+i*2.17;height=22*(1+.15*math.sin(t+.6));width=11.5;sway=1.6*math.sin(t)
   if only is None:
    for j in range(9,-1,-1):
     radius=20*(j+1)/10
     mesh('Warm soft halo',[(cx+radius*math.cos(k*math.tau/64),cy-height*.45+radius*math.sin(k*math.tau/64)) for k in range(64)],-2-j*.02,halos[j])
   drop(cx,cy,width,height,sway,.05*i,edge)
   drop(cx,cy-.6,width*.53,height*.71,sway*.5,.05*i+.01,heart)
 def clear():
  for ob in list(s.objects):
   if ob.type=='MESH':bpy.data.objects.remove(ob,do_unlink=True)
 temp=ROOT/'game/_veillee_crypte_render.png'
 s.render.filepath=str(temp)
 # Isolated opaque silhouettes resolve bases even where neighboring flames overlap.
 for i,(cx,cy) in enumerate(FLAME_BASES):
  clear();objects(0,i);s.render.resolution_percentage=100;bpy.ops.render.render(write_still=True)
  with Image.open(temp) as im:
   pixels=im.convert('RGBA');opaque=[(x,y) for y in range(256) for x in range(256) if pixels.getpixel((x,y))[3]>=180]
   bottom=max(y for x,y in opaque);xs=[x for x,y in opaque if y==bottom];mx=sum(xs)/len(xs);error=math.hypot(mx-cx,bottom-cy)
   assert error<=3,(i,error)
   print(f'FLAME_BASE {i} measured={mx:.2f},{bottom} error={error:.3f}',flush=True)
 atlas=Image.new('RGBA',(3072,256));emission=Image.new('RGBA',(1536,128))
 for frame in range(FRAMES):
  clear();objects(frame)
  for percentage,destination,x in ((100,atlas,frame*256),(50,emission,frame*128)):
   s.render.resolution_percentage=percentage;bpy.ops.render.render(write_still=True)
   with Image.open(temp) as im:destination.paste(im.convert('RGBA'),(x,0))
 atlas.save(OUT/'fire.png',optimize=True);emission.save(OUT/'fire_e.png',optimize=True);temp.unlink()
 cel.uninstall()

def props(name):
 rig_scene((128,128),2.55); floor=mat('Crypt slab',(.20,.25,.22)); wax=mat('Ivory wax',(.72,.68,.58));shade=mat('Old wax shade',(.40,.37,.30)); dark=mat('Warm wick glow',(.95,.47,.16),.65);paper=mat('Paper flower',(.62,.59,.52));ribbon=mat('Crepe ribbon',(.13,.105,.13))
 if name=='candles':
  # broad chipped slate slab
  bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,.055));o=bpy.context.object;o.name='Crypt stone slab';o.scale=(1.22,.73,.11);o.data.materials.append(floor)
  for i,(x,y,h,r) in enumerate([(-.45,-.12,.55,.105),(-.22,.02,.77,.10),(0,-.16,.64,.115),(.25,.02,.88,.095),(.48,-.15,.52,.105),(-.08,.23,.48,.09),(.32,.23,.60,.10)]):
   bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=h,location=(x,y,.13+h/2));o=bpy.context.object;o.name='Ivory candle';o.data.materials.append(wax if i%2 else shade)
   bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=.012,depth=.045,location=(x,y,.13+h+.018));bpy.context.object.data.materials.append(dark)
   ico('Pooled wax',(x,y,.145),(r*1.18,r*.95,.025),wax)
 else:
  # circular paper petals, ring arranged as a ground wreath
  for i in range(16):
   a=i*math.tau/16;x=.49*math.cos(a);y=.36*math.sin(a)
   for j in range(5):
    q=j*math.tau/5;ico('Paper flower petal',(x+.09*math.cos(q),y+.08*math.sin(q),.10),(.09,.055,.025),paper)
   ico('Flower center',(x,y,.125),(.035,.035,.02),shade)
  # dark folded crepe ribbon at the near edge
  bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-.51,.09));o=bpy.context.object;o.name='Crepe ribbon';o.scale=(.25,.07,.035);o.data.materials.append(ribbon)
 cel.install('prop',normals=False);render(OUT/(name+'.png'),(128,128))
 if name=='wreath': save_shadow(name,(128,128))
 if name=='wreath': (OUT/'wreath_e.png').unlink(missing_ok=True)
 cel.uninstall()
def preview():
 rig_scene((256,256),3.4);bpy.context.scene.view_settings.exposure=-1.5;ground=mat('Crypt ground',(.055,.085,.075));slabground=mat('Crypt paving',(.09,.14,.125));water=mat('Black reflecting water',(.018,.035,.042),.08);amber=mat('Water amber reflection',(1,.27,.045),.22)
 bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.05));bpy.context.object.scale=(10,10,.1);bpy.context.object.data.materials.append(ground)
 # Full-frame dark crypt gradient via a broad rear wall and overlapping charcoal stone tiles.
 bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.85,.65));o=bpy.context.object;o.scale=(5,.08,2.5);o.data.materials.append(mat('Deep crypt wall',(.035,.052,.055)))
 for row in range(4):
  for col in range(6):
   bpy.ops.mesh.primitive_cube_add(size=1,location=((col-2.5)*.68,(row-1.5)*.62,-.015));o=bpy.context.object;o.scale=(.66,.60,.07);o.data.materials.append(slabground)
 bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-1.0,.012));o=bpy.context.object;o.scale=(2.5,1.0,.035);o.data.materials.append(water)
 candles=mat('Ivory candle',(.72,.68,.58));slab=mat('Crypt slab',(.20,.25,.22));flame=mat('Amber flame',(1,.43,.12),1.8);paper=mat('Paper',(.62,.59,.52))
 bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-.15,.02));o=bpy.context.object;o.scale=(1.1,.65,.1);o.data.materials.append(slab)
 for i in range(7):
  x=(i-3)*.22;h=.50+(i%3)*.11;bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.075,depth=h,location=(x,-.15,.10+h/2));bpy.context.object.data.materials.append(candles);ico('Rounded preview flame',(x,-.15,.10+h+.12),(.067,.045,.12),flame)
 # Vertical amber streaks on dark water, aligned beneath the candle cluster.
 for i in range(7):
  x=(i-3)*.18
  bpy.ops.mesh.primitive_cube_add(size=1,location=(x,-.83,.035));o=bpy.context.object;o.scale=(.018,.29+(.06*(i%3)),.008);o.data.materials.append(amber)
 # Warm point lights create a soft, rendered halo around the candles.
 for i in range(3):
  bpy.ops.object.light_add(type='POINT',location=((i-1)*.32,-.1,.95));o=bpy.context.object;o.data.energy=24;o.data.color=(1,.48,.18);o.data.shadow_soft_size=.48
 for i in range(14):
  a=i*math.tau/14;ico('Paper petal',(-.62+.30*math.cos(a),.25+.23*math.sin(a),.09),(.065,.043,.021),paper)
 cel.install('prop',normals=False);render(ROOT/'game/assets/sprites/cosmetics/previews/crypte_veilleuse.png',(256,256));cel.uninstall()
def main():
 OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True);bpy.context.preferences.filepaths.save_version=0;fire();preview();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/veillee_crypte_veilleuse.blend'));print('VEILLEE_CRYPT_OK fire=12 preview=256')
if __name__=='__main__':main()
