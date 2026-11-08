import math, os, random, sys, warnings
warnings.filterwarnings("ignore",category=DeprecationWarning)
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/renders/feel_sorts2/hail_zone'
SOURCE=ROOT/'game/assets/sprites/characters/vigie/hail_zone'
WORK=ROOT/'art/blender/cel/feel2'
sys.path.insert(0,str(ROOT/'art/tools/cel'))

def build(kind):
 import bpy, cel_style as cel
 from mathutils import Vector
 bpy.ops.wm.open_mainfile(filepath=str(WORK/'vigie_fx_hail_zone.blend'))
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'; sc.eevee.taa_render_samples=8
 sc.render.film_transparent=True; sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGBA'; sc.render.resolution_percentage=100
 sc.view_settings.view_transform='Standard'; sc.render.image_settings.color_depth='8'
 W,H=(128,192) if kind=='flare' else (640,640)
 sc.render.resolution_x=W; sc.render.resolution_y=H
 sc.camera=None; cd=bpy.data.cameras.new('Iso orthographic'); cam=bpy.data.objects.new('Iso orthographic',cd); sc.collection.objects.link(cam)
 cam.location=(0,-20,11.547); target=Vector((0,0,0)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler(); cd.type='ORTHO'; cd.ortho_scale=5.4 if kind=='flare' else 9.93; sc.camera=cam
 def mat(n,c,emit=0):
  m=bpy.data.materials.new(n); m.diffuse_color=(*c,1); m.use_nodes=True; p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1); p.inputs['Roughness'].default_value=.85
  if emit: p.inputs['Emission Color'].default_value=(*c,1); p.inputs['Emission Strength'].default_value=emit
  return m
 dark=mat('rain-black',(.018,.024,.029)); brass=mat('brass',(.55,.30,.075),.7); red=mat('distress-red',(1,.0423,.0782),1); flame=mat('magnesium',(1,.53,.18),7); white=mat('white-hot',(1,.92,.7),14); slate=mat('rain-slate',(.12,.17,.19)); smoke=mat('red smoke',(.15,.025,.04)); earth=mat('earth',(.23,.14,.1)); water=mat('splash',(.35,.43,.45),.5)
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
 # Camera-space footprint preserves the measured original radius (290 px).
 # Ground Y compensation retains its circular screen footprint at 30 degrees.
 OUT.mkdir(parents=True,exist_ok=True)
 random.seed(2718)
 def arrow(name):
  parts=[rod((0,0,0),(.33,0,.78),.026,dark,name+' shaft',6),
         rod((0,0,0),(-.075,0,-.18),.075,brass,name+' brass tip',4)]
  # Real flat feather geometry, broad enough to read at 640 px.
  for side in (-1,1):
   verts=[(.25,0,.60),(.38+side*.095,0,.75),(.35+side*.095,0,.92),(.33,0,.79)]
   mesh=bpy.data.meshes.new('red feather'); mesh.from_pydata(verts,[],[(0,1,2,3)])
   o=bpy.data.objects.new(name+' red feather',mesh); sc.collection.objects.link(o); o.data.materials.append(red); parts.append(o)
  parent=bpy.data.objects.new(name,None); sc.collection.objects.link(parent)
  for o in parts: o.parent=parent
  return parent
 falling=[]; planted=[]; splashes=[]; boundary=[]
 for j in range(98):
  a=random.random()*math.tau; r=math.sqrt(random.random())*3.0
  falling.append((arrow('falling arrow'),r*math.cos(a),2*r*math.sin(a),random.random()))
 for j in range(32):
  a=random.random()*math.tau; r=math.sqrt(random.random())*4.1
  planted.append((arrow('embedded vibrating arrow'),r*math.cos(a),2*r*math.sin(a),random.random()))
  for k in range(3):
   o=ico('impact earth and water',(0,0,0),(.045,.07,.11),water if k==0 else earth)
   splashes.append((o,r*math.cos(a),2*r*math.sin(a),k,random.random()))
 for j in range(62):
  a=j*math.tau/62; r=4.46+random.uniform(-.08,.02)
  # Broken upright rain shreds, no flat disc or ring mesh.
  o=rod((0,0,0),(.04,0,.32),.022,slate,'dark edge rain',5)
  boundary.append((o,r*math.cos(a),2*r*math.sin(a),random.random()))
 light_data=bpy.data.lights.new('soft key','AREA'); light_data.energy=700; light_data.shape='DISK'; light_data.size=9
 light=bpy.data.objects.new('soft key',light_data); sc.collection.objects.link(light); light.location=(-3,-5,9)
 cel.toon_materials('vfx')
 for layer in sc.view_layers: layer.use_pass_normal=False
 sc.use_nodes=False
 # Source blend may carry compositor output nodes: none can write extra passes.
 def animate(label,f):
  t=f/8 if label=='default' else f/8
  decay=1 if label=='default' else (1,.73,.43,.15)[f]
  for j,(o,x,y,phase) in enumerate(falling):
   h=((phase-t*2.35)%1)*1.8
   o.location=(x+(h-.9)*.40,y-2*.866*1.3,h+.2); o.scale=(decay,)*3
  for j,(o,x,y,phase) in enumerate(planted):
   o.location=(x,y-.6,.17); o.rotation_euler=(.06*math.sin(f*2.4+phase*20),.10*math.sin(f*2.8+phase*17),-.2)
   o.scale=(decay*.85,)*3
  for o,x,y,k,phase in splashes:
   age=(phase+t*3)%1; spread=.10+age*.28
   o.location=(x+math.cos(k*2.1+phase)*spread,y+math.sin(k*2.1+phase)*spread*2,.12+math.sin(age*math.pi)*.32)
   o.scale=(decay*(.035+.025*age),decay*.06,decay*.09)
  for o,x,y,phase in boundary:
   o.location=(x,y*.96-.25,.04+((phase-t)%1)*.20); o.scale=(decay,)*3
 materials=[m for m in bpy.data.materials if m.get('cel_done')]
 saved=[]
 for m in materials:
  node=next(n for n in m.node_tree.nodes if n.type=='EMISSION')
  saved.append((m,node,tuple(node.inputs['Color'].default_value),node.inputs['Strength'].default_value))
 for emit in (False,True):
  sc.render.resolution_percentage=50 if emit else 100
  for m,node,color,strength in saved:
   if emit and m not in (red,brass,water):
    for link in list(node.inputs['Color'].links): m.node_tree.links.remove(link)
    node.inputs['Color'].default_value=(0,0,0,1)
  for label,n in (('default',8),('end',4)):
   for f in range(n):
    animate(label,f)
    sc.render.filepath=str(OUT/f'{label}{"_e" if emit else ""}_{f}.png')
    bpy.ops.render.render(write_still=True)
 print('PASS hail_zone render: 24 frames; source blend unchanged')

def pack():
 from PIL import Image, ImageStat
 import hashlib,json,shutil
 limits={'default':390000,'end':134000,'default_e':100000,'end_e':34000}
 checks=[]; report={}
 for stem,limit in limits.items():
  emit=stem.endswith('_e'); label=stem.removesuffix('_e'); n=8 if label=='default' else 4; size=320 if emit else 640
  atlas=Image.new('RGBA',(size*4,size*(n//4)))
  hashes=[]
  for f in range(n):
   frame=Image.open(OUT/f'{stem}_{f}.png').convert('RGBA')
   assert frame.size==(size,size)
   assert frame.getchannel('A').getbbox()
   hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
   atlas.paste(frame,((f%4)*size,(f//4)*size))
  assert len(set(hashes))==n
  for colors in ((16,) if emit else (64,48,32)):
   quant=atlas.quantize(colors=colors,method=Image.Quantize.FASTOCTREE)
   quant.save(OUT/f'{stem}.png',optimize=True)
   if (OUT/f'{stem}.png').stat().st_size<=limit: break
  result=Image.open(OUT/f'{stem}.png').convert('RGBA')
  weight=(OUT/f'{stem}.png').stat().st_size
  assert result.size==atlas.size and weight<=limit,(stem,weight,limit)
  assert len({hashlib.sha256(result.crop((i%4*size,i//4*size,i%4*size+size,i//4*size+size)).tobytes()).hexdigest() for i in range(n)})==n
  assert max(result.getchannel('A').getextrema())>0
  assert max(ImageStat.Stat(result).extrema[c][1] for c in range(3))>50
  # Contrast against the requested grey background, after palette optimization.
  if not emit:
   grey=Image.new('RGBA',result.size,(58,62,70,255)); grey.alpha_composite(result)
   from PIL import ImageChops
   delta=ImageChops.difference(grey.convert('RGB'),Image.new('RGB',result.size,(58,62,70)))
   contrast=sum(1 for px in delta.getdata() if max(px)>=25)
   assert contrast>n*1500,(stem,contrast)
  # All eight full frames must preserve the measured original horizontal footprint.
  if stem=='default':
   for i in range(n):
    box=result.crop((i%4*640,i//4*640,i%4*640+640,i//4*640+640)).getchannel('A').getbbox()
    assert 20<=box[0]<=45 and 595<=box[2]<=620 and 20<=box[1]<=45 and 595<=box[3]<=620,box
  report[stem]={'dimensions':result.size,'before':(SOURCE/f'{stem}.png').stat().st_size,'after':weight,'frames_distinct':n,'alpha':'PASS'}
 # One small contact sheet, assembly only; no Pillow drawing.
 contact=Image.new('RGBA',(1024,512),(58,62,70,255))
 for row,label in enumerate(('default','end')):
  atlas=Image.open(OUT/f'{label}.png').convert('RGBA')
  for col in range(4):
   frame=atlas.crop((col*640,0,col*640+640,640)).resize((256,256),Image.Resampling.LANCZOS)
   contact.alpha_composite(frame,(col*256,row*256))
 contact.convert('RGB').save(OUT.parent/'after_vfx_hail_vigie.png')
 (OUT/'verification.json').write_text(json.dumps(report,indent=2))
 print(json.dumps(report))
 if '--deliver' in sys.argv:
  for stem in limits: shutil.copyfile(OUT/f'{stem}.png',SOURCE/f'{stem}.png')
  print('PASS delivered four validated PNGs')

if __name__=='__main__':
 if '--pack' in sys.argv: pack()
 else: build('hail_zone')
