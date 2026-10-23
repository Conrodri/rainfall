"""V2: charcoal ember and ballistic impact; Blender Eevee, deterministic mesh particles."""
import sys, math, json, hashlib, random, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
INV=Path(__file__).with_name('_v2_inventory.json')
DIRS=[ROOT/'game/assets/sprites/projectiles/ember_shard',ROOT/'game/assets/sprites/vfx/ember_shard_impact']
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory():
 from PIL import Image
 data={}
 for d in DIRS:
  data[d.name]={'files':{p.name:{'sha256':digest(p),**({'size':list(Image.open(p).size)} if p.suffix=='.png' else {})} for p in d.iterdir() if p.is_file()},'frames':4 if d==DIRS[0] else 6,'fps':14 if d==DIRS[0] else 18,'pivot':'unchanged atlas regions; centered VFX','loop':d==DIRS[0]}
 INV.write_text(json.dumps(data,indent=2));print('INVENTORY PASS')
if '--inventory' in sys.argv:inventory();sys.exit()
import bpy
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent/'_deps'))
sys.path.append(str(Path.home()/'AppData/Local/RainfallIsoDeps'))
from PIL import Image
sys.path.insert(0,str(ROOT/'art/tools/vfx'))
import vfx_lib as V
V.TILT=math.radians(60);V.CT=math.cos(V.TILT);V.ST=math.sin(V.TILT)
TMP=Path(tempfile.mkdtemp(prefix='rainfall_v2_'))

def mat(name,col,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
 n=m.node_tree.nodes;p=n.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=.89
 p.inputs['Emission Color'].default_value=(*col,1);p.inputs['Emission Strength'].default_value=emit
 noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=24;noise.inputs['Detail'].default_value=3
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.6;bump.inputs['Distance'].default_value=.06
 m.node_tree.links.new(noise.outputs['Fac'],bump.inputs['Height']);m.node_tree.links.new(bump.outputs['Normal'],p.inputs['Normal'])
 m['emit']=emit>0;return m

def rock(name,pos,scale,material,seed):
 rng=random.Random(seed);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=V.S(*pos))
 o=bpy.context.object;o.name=name
 for v in o.data.vertices:v.co*=rng.uniform(.77,1.19)
 o.scale=scale;o.data.materials.append(material);return o

def line(a,b,width,material,name='ballistic ember particle'):
 # Camera-space streak, tapered irregular prism.
 p,q=V.S(*a),V.S(*b);v=q-p
 bpy.ops.mesh.primitive_cone_add(vertices=5,radius1=width*.35,radius2=width,depth=v.length,location=(p+q)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=v.to_track_quat('Z','Y').to_euler();o.data.materials.append(material);return o

def scene(size):
 s=V.setup(size,size,ppu=64,samples=16);s.world=bpy.data.worlds.new('dark studio');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1)
 for loc,col,power in [((-3,-4,7),(1,.54,.24),2.5),((4,0,3),(.24,.39,.65),.55)]:
  b=bpy.data.lights.new('warm key / cold fill','SUN');b.energy=power;b.color=col;o=bpy.data.objects.new(b.name,b);s.collection.objects.link(o);o.rotation_euler=Vector(loc).to_track_quat('Z','Y').to_euler()
 return s

def passes(s,size,folder,frame):
 originals={o:o.hide_render for o in s.objects};over=s.view_layers[0].material_override
 # Camera-space normal shader, preserving actual geometry and coverage.
 normal=bpy.data.materials.get('camera normals')
 if normal is None:
  normal=bpy.data.materials.new('camera normals');normal.use_nodes=True;n=normal.node_tree.nodes;l=normal.node_tree.links;n.clear();out=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');g=n.new('ShaderNodeNewGeometry');v=n.new('ShaderNodeVectorTransform');v.vector_type='NORMAL';v.convert_from='WORLD';v.convert_to='CAMERA';a=n.new('ShaderNodeVectorMath');a.operation='MULTIPLY_ADD';a.inputs[1].default_value=(.5,.5,.5);a.inputs[2].default_value=(.5,.5,.5);l.new(g.outputs['Normal'],v.inputs[0]);l.new(v.outputs[0],a.inputs[0]);l.new(a.outputs[0],e.inputs[0]);l.new(e.outputs[0],out.inputs[0])
 result={}
 for suffix in ('','_e','_n'):
  s.view_layers[0].material_override=normal if suffix=='_n' else None
  for o in s.objects:
   o.hide_render=originals[o]
   if o.type=='MESH' and suffix=='_e':o.hide_render=not any(m.get('emit',False) for m in o.data.materials)
   if o.get('k')=='smoke' and suffix in ('_e','_n'):o.hide_render=True
  p=TMP/f'{folder}_{frame}{suffix}.png';s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
  result[suffix]=Image.open(p).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
 for o in s.objects:o.hide_render=originals[o]
 s.view_layers[0].material_override=over
 return result

def build(kind):
 size,count=(48,4) if kind==0 else (96,6);s=scene(size)
 coal=mat('fractured porous charcoal',(.012,.007,.004));hot=mat('orange white incandescent core',(1,.24,.035),1.25);orange=mat('hot orange fracture',(1,.095,.006),1.3);ash=mat('cooling ember',(.25,.035,.004),.65)
 frames=[]
 for f in range(count):
  for o in list(s.objects):
   if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
  rng=random.Random(618+f);V.G['objs']=[];t=f/(count-1)
  if kind==0:
   # Head aligned +screen X, centered at original projectile pivot.
   rock('molten irregular core',(.055,0,0),(.165,.063,.065),hot,40+f)
   for k in range(13):
    x=rng.uniform(-.095,.16);ang=rng.uniform(0,math.tau)
    rock('charcoal crust flake',(x,math.sin(ang)*.065,math.cos(ang)*.067),(.042,.025,.027),coal,k+f*13)
   line((.12,0,-.03),(.23,.007,-.03),.025,hot,'pointed molten shard')
   white=mat('white orange hottest fracture',(1,.62,.27),1.1)
   line((.06,-.009,-.085),(.17,.004,-.085),.012,white,'exposed incandescent fracture')
   for k in range(13):
    x=rng.uniform(-.31,-.07);y=rng.uniform(-.08,.08);line((x,y,0),(x+rng.uniform(.015,.065),y+.005,0),rng.uniform(.003,.008),orange)
   for k in range(9):V.sprite('smoke',-.15-k*.018,.015+math.sin(k+f)*.025,.09+k*.007,.08,color=(.23,.16,.11),alpha=.40,d=.10+k*.004)
  else:
   # Ballistic fan: fast flash, angular fragments, cooling smoke.
   for k in range(32):
    r=random.Random(820+k);ang=r.uniform(0,math.tau);speed=r.uniform(.17,.65);age=.1+t*.85
    x=math.cos(ang)*speed*age;y=math.sin(ang)*speed*age*.48+.28*age-.30*age*age
    dx=math.cos(ang)*.045*(1-t*.7);dy=math.sin(ang)*.025+.025*(1-t)
    line((x-dx,y-dy,0),(x,y,0),r.uniform(.003,.012)*(1-.65*t),hot if f<2 and k%4==0 else orange if f<4 else ash)
   if f<3:
    for k in range(7):
     a=k*2.4;rr=.065*(1-t);line((0,-.01,-.02),(math.cos(a)*rr,math.sin(a)*rr,-.02),.012*(1-t),hot,'brief fractured light flash')
   for k in range(11):
    r=random.Random(k+52);V.sprite('smoke',r.uniform(-.21,.21)*(.4+t),.02+t*.22+r.uniform(-.09,.10),.13+t*.17,.11+t*.21,color=(.20,.17,.14),alpha=.36*(1-t*.4),d=.14+k*.002)
  s['v2_frame']=f;s['v2_fps']=14 if kind==0 else 18;s['v2_notes']='STYLE.md; camera elevation 30; mesh incandescent core, crust and seeded ballistic particles; +X screen'
  if f==0:
   dest=ROOT/'art/blender/vfx'/('v2_projectile.blend' if kind==0 else 'v2_impact.blend');dest.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(dest))
  frames.append(passes(s,size,kind,f))
 for suffix in ('','_e','_n'):
  atlas=Image.new('RGBA',(size*count,size))
  for i,fr in enumerate(frames):atlas.paste(fr[suffix],(i*size,0))
  atlas.save(DIRS[kind]/f'default{suffix}.png',optimize=True)
 return frames

def contact(allframes):
 tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA');canvas=Image.new('RGBA',(1100,700),(19,23,28,255))
 for j in range(2):
  for i in range(7):canvas.alpha_composite(tile,(i*160-100,200+j*80))
 ard=Image.open(ROOT/'game/assets/sprites/characters/ardent/idle.png').convert('RGBA');sz=ard.height//8;ard=ard.crop((0,sz*2,sz,sz*3));canvas.alpha_composite(ard,(20,235))
 for f,fr in enumerate(allframes[0]):canvas.alpha_composite(fr[''],(225+f*90,275))
 for f,fr in enumerate(allframes[1]):canvas.alpha_composite(fr[''],(170+f*145,365))
 for k,frames in enumerate(allframes):
  for i,fr in enumerate(frames):
   im=fr[''];canvas.alpha_composite(im.resize((im.width*2,im.height*2)),(50+i*165,25 if k==0 else 490))
 # Reference excerpts assembled without drawing or altering their pixels.
 for p,x in [(ROOT/'art/tools/iso/_c4_contact.png',650),(ROOT/'art/tools/ui/_i2_contact.png',870)]:
  im=Image.open(p).convert('RGBA');im.thumbnail((210,160));canvas.alpha_composite(im,(x,15))
 canvas.convert('RGB').save(Path(__file__).with_name('_v2_contact.png'),optimize=True)

if __name__=='__main__':
 data=json.loads(INV.read_text());allframes=[build(0),build(1)];contact(allframes)
 errors=[]
 for d in DIRS:
  old=data[d.name]['files']
  for name,meta in old.items():
   p=d/name
   if p.suffix=='.png':
    if list(Image.open(p).size)!=meta['size']:errors.append(name+' size')
   elif digest(p)!=meta['sha256']:errors.append(name+' modified')
  if set(old)!=set(p.name for p in d.iterdir() if p.is_file()):errors.append('file set')
 data['verification']={'result':'FAIL' if errors else 'PASS','errors':errors,'render':'Blender Eevee 16 samples, 2x AA','passes':['diffuse','emission','camera-space geometry normals']};INV.write_text(json.dumps(data,indent=2));print('V2 CONTRACT',data['verification']['result'])


