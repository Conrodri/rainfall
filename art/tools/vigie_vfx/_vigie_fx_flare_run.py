import math, os, random, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/characters/vigie'
WORK=ROOT/'art/blender/cel/feel2'
sys.path.insert(0,str(ROOT/'art/tools/cel'))

def build(kind):
 import bpy, cel_style as cel
 from mathutils import Vector
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'; sc.eevee.taa_render_samples=8
 sc.render.film_transparent=True; sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGBA'; sc.render.resolution_percentage=100
 sc.view_settings.view_transform='Standard'; sc.render.image_settings.color_depth='8'
 W,H=(128,192) if kind=='flare' else (640,640)
 sc.render.resolution_x=W; sc.render.resolution_y=H
 sc.camera=None; cd=bpy.data.cameras.new('Iso orthographic'); cam=bpy.data.objects.new('Iso orthographic',cd); sc.collection.objects.link(cam)
 cam.location=(0,-12,7); target=Vector((0,0,1.8)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler(); cd.type='ORTHO'; cd.ortho_scale=5.4 if kind=='flare' else 11; sc.camera=cam
 def mat(n,c,emit=0):
  m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True; p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Roughness'].default_value=.85
  if emit: p.inputs['Emission Color'].default_value=(*c,1); p.inputs['Emission Strength'].default_value=emit
  return m
 dark=mat('rain-black',(.025,.035,.04)); brass=mat('brass',(.66,.34,.07),.5); red=mat('distress-red',(1,.035,.075),2.5); flame=mat('magnesium',(1,.53,.18),7); white=mat('white-hot',(1,.92,.7),14); slate=mat('rain-slate',(.12,.17,.19)); smoke=mat('red smoke',(.15,.025,.04)); earth=mat('earth',(.23,.14,.1)); water=mat('splash',(.35,.43,.45),.5)
 cel.install('vfx',normals=False)
 def ico(name,loc,scale,ma,sub=1):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=bpy.context.object; o.name=name; o.scale=scale; o.data.materials.append(ma); return o
 def rod(a,b,r,ma,name,verts=7):
  a,b=Vector(a),Vector(b); d=b-a; bpy.ops.mesh.primitive_cone_add(vertices=verts,radius1=r,radius2=.006,depth=d.length,location=(a+b)/2); o=bpy.context.object; o.name=name; o.rotation_mode='QUATERNION'; o.rotation_quaternion=d.to_track_quat('Z','Y'); o.data.materials.append(ma); return o
 if kind=='flare':
  # One planted flare; jagged upward flame, smoke, falling sparks, uneven ground glow.
  for j in range(8):
   ang=j*math.tau/8; ico('glow fragments',(math.cos(ang)*(.3+.1*(j%3)),math.sin(ang)*.17,.04),(.24,.12,.045),red,2)
  rod((0,0,.08),(0,0,1.25),.095,dark,'flare casing',8); ico('flare cap',(0,0,1.27),(.12,.12,.1),brass)
  for j in range(5):
   x=(j-2)*.09; z=.9+j*.26; ico('flame lobe',(x,0,z),(.13 if j%2 else .19,.10,.32),red if j%2 else flame,2)
  ico('white core',(0,-.08,1.15),(.09,.08,.38),white,2)
  for j in range(22):
   random.seed(j); x=random.uniform(-1.4,1.4); z=random.uniform(.4,3.4); y=random.uniform(-.35,.4)
   ico('falling spark',(x,y,z),(.035,.035,random.uniform(.05,.13)),flame if j%3 else white,1)
   if j%2==0: rod((x,y,z+.18),(x*.94,y,z-.08),.018,flame,'spark trail',5)
  for j in range(13):
   random.seed(100+j); x=random.uniform(-.65,.65); z=2.5+random.random()*1.1
   ico('smoke plume',(x,.18,z),(.2+random.random()*.2,.18,.27),smoke,2)
  return
 # Raised elliptical impact footprint, intentionally broken and lumpy rather than ring geometry.
 for j in range(27):
  random.seed(j); a=j*math.tau/27; r=3.7+random.uniform(-.5,.35)
  if kind=='hail_zone':
   x,y=math.cos(a)*r,math.sin(a)*r*.47
   ico('dark rain boundary',(x,y,.04),(.42,.2,.09),slate,1)
   # dozens of oblique falling arrows above the footprint, staged across depths/heights
   for k in range(3):
    xx=x+random.uniform(-1.3,1.3); yy=y+random.uniform(-.3,.3); zz=1.4+k*1.25
    rod((xx+.42,yy,zz+.72),(xx-.05,yy,zz),.045,dark,'arrow shaft',6)
    rod((xx-.05,yy,zz),(xx-.24,yy,zz-.3),.11,brass,'arrowhead',5)
    for q in (-1,1): rod((xx+.4,yy,zz+.62),(xx+.58,yy+q*.06,zz+.48),.035,red,'red fletching',5)
  else:
   ico('broken flare-lit ground',(math.cos(a)*r*.36,math.sin(a)*r*.18,.06),(.5,.22,.07),red,1)
 if kind=='hail_zone':
  for j in range(14):
   random.seed(300+j); x=random.uniform(-3.4,3.4); y=random.uniform(-1.55,1.55)
   rod((x+.45,y,3.2+random.random()*1.3),(x,y,1.3),.045,dark,'rain arrow',6); rod((x,y,1.3),(x-.19,y,.98),.11,brass,'arrowhead',5)
   for q in (-1,1): rod((x+.36,y,2.9),(x+.53,y+q*.07,2.7),.035,red,'fletching',5)
   if j%2==0:
    rod((x,y,.05),(x-.2,y,.85),.045,dark,'embedded vibrating arrow',6)
    for q in range(3): rod((x,y,.12),(x+random.uniform(-.3,.3),y+random.uniform(-.2,.2),.35),.07,earth,'dirt spray',5)
    ico('water splash',(x+.12,y-.08,.1),(.22,.15,.12),water,1)
  anims=[('default',8,True),('end',4,False)]
 else:
  anims=[('default',6,True),('end',4,False)]
 def compose(label,n,emit=False):
  import bpy
  cols=n; cellw=W//(6 if kind=='flare' else 1); cellh=H//(4 if kind=='flare' else 1)
  # Preserve atlas geometry: hail has four columns and two/one rows.
  sw,sh=(128,192) if kind=='flare' else (640,640)
  cols=(3 if label=='default' else 2) if kind=='flare' else 4
  rows=(2 if label=='default' else 2) if kind=='flare' else (2 if n==8 else 1)
  w=sw*cols; h=sh*rows
  frames=[]
  for f in range(n):
   phase=(1.0 if f==0 else max(.18,1-f/(n+1))) if label=='end' else (0.83+.17*math.sin(f*math.tau/n))
   sc.frame_set(f+1)
   for o in sc.objects:
    if o.type=='MESH' and f>0: o.rotation_euler.z += f*.035
   for o in sc.objects:
    if o.type=='MESH': o.hide_render=False
   # Retain a vivid opening then progressively sink/fade the effect through material opacity.
   sc.render.filepath=str(WORK/f'_{kind}_{label}_{f}.png'); bpy.ops.render.render(write_still=True)
   im=bpy.data.images.load(sc.render.filepath); im.scale(sw,sh); frames.append(list(im.pixels[:]))
   bpy.data.images.remove(im)
  px=[0.]*(w*h*4)
  for idx,pix in enumerate(frames):
   ox=(idx%cols)*sw; oy=(idx//cols)*sh
   for row in range(sh): px[((oy+row)*w+ox)*4:((oy+row)*w+ox+sw)*4]=pix[row*sw*4:(row+1)*sw*4]
  image=bpy.data.images.new('packed',width=w,height=h,alpha=True); image.pixels[:]=px
  path=OUT/kind/(label+('_e' if emit else '')+'.png'); path.parent.mkdir(parents=True,exist_ok=True); image.filepath_raw=str(path); image.file_format='PNG'; image.save(); bpy.data.images.remove(image)
 for label,n,loop in anims: compose(label,n,False)
 for o in sc.objects:
  if o.type=='MESH': o.hide_render=not any(m and any(k in m.name.lower() for k in ('red','magnesium','white-hot','brass','splash')) for m in o.data.materials)
 sc.render.resolution_percentage=50
 for label,n,loop in anims: compose(label,n,True)
 sc.render.resolution_percentage=100
 for p in WORK.glob(f'_{kind}_*.png'): p.unlink(missing_ok=True)
 WORK.mkdir(parents=True,exist_ok=True); bpy.ops.wm.save_as_mainfile(filepath=str(WORK/f'vigie_fx_{kind}.blend'))

if __name__=='__main__':
 build('flare')

