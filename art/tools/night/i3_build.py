"""Ardent: charred museum reliefs and incandescent orange fire. Background only."""
import sys,math,random,json,subprocess
from pathlib import Path
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[2]
sys.dont_write_bytecode=True
sys.path.insert(0,str(ROOT/'art/tools/ui'))
import i2_build as kit
from ui_kit import *
from mathutils import Vector
random.seed(331)
INV=json.loads((BASE/'i3_inventory.json').read_text())

def materials():
 global coal,ash,iron,bronze,fire,core,ember
 coal=kit.surface('fractured charcoal crust','#090C0E','#343331',0,.82)
 ash=kit.surface('cinder grey ash','#25282A','#66675F',0,.92)
 iron=kit.surface('blackened iron with worn edges','#080B0D','#282D2D',1,.58)
 bronze=kit.surface('smoke patinated bronze','#302B20','#76634A',1,.48)
 fire=mat('#170901',.95,0,'#FF7900',.72)
 core=mat('#241001',.95,0,'#FFAD12',1.05)
 for m,low,high in [(fire,.22,.86),(core,.65,1.12)]:
  p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Specular IOR Level'].default_value=0
  n=m.node_tree.nodes;l=m.node_tree.links
  tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=5;tex.inputs['Detail'].default_value=3
  mapping=n.new('ShaderNodeMapRange');mapping.inputs['To Min'].default_value=low;mapping.inputs['To Max'].default_value=high
  l.new(tex.outputs['Fac'],mapping.inputs[0]);l.new(mapping.outputs[0],p.inputs['Emission Strength'])
 ember=mat('#75200A',.72,0,'#ED3902',1.5)
 # Vein network from Voronoi distance-to-edge: real charcoal surrounding molten fissures.
 n=coal.node_tree.nodes;l=coal.node_tree.links;p=n.get('Principled BSDF')
 tex=n.new('ShaderNodeTexVoronoi');tex.feature='DISTANCE_TO_EDGE';tex.inputs['Scale'].default_value=5.6
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.018;ramp.color_ramp.elements[0].color=(1,1,1,1);ramp.color_ramp.elements[1].position=.052;ramp.color_ramp.elements[1].color=(0,0,0,1)
 l.new(tex.outputs['Distance'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Emission Strength']);p.inputs['Emission Color'].default_value=rgba('#FF6505')

def shard(x,z,k=1,angle=0,y=-.24):
 # Irregular elongated fractured clinker, never a dart, arrow or metal bar.
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(x,y,z));o=bpy.context.object;o.name='incandescent fractured charcoal'
 for v in o.data.vertices:
  v.co*=random.uniform(.83,1.15)
 o.scale=(.24*k,.14*k,.38*k);o.rotation_euler[1]=angle;o.data.materials.append(coal)
 b=o.modifiers.new('worn charcoal fracture edges','BEVEL');b.width=.022;b.segments=2
 return o

def tongue(x,z,h=.5,w=.13,lean=.1,y=-.28,angle=0):
 # Asymmetrical tapered fire sheet with 3D ridged section, torn tip and orange core.
 def make(k,depth,material):
  verts=[];faces=[];steps=13
  for j in range(steps):
   t=j/(steps-1);r=w*k*(math.sin(math.pi*(.10+t*.90))**.8)*(1-t*.97)*(1+.19*math.sin(t*21+x*5))
   cx=lean*t*t+w*.42*math.sin(t*11+z*4)*t;zz=h*t
   for dx,dy in [(-r,0),(0,-r*.6),(r,0),(0,r*.24)]:
    xx=cx+dx;vz=zz*k
    verts.append((x+xx*math.cos(angle)+vz*math.sin(angle),y+dy+depth,z+vz*math.cos(angle)-xx*math.sin(angle)))
  for j in range(steps-1):
   for i in range(4):
    a=j*4+i;b=j*4+(i+1)%4;faces.append((a,b,b+4,a+4))
  faces.extend([(3,2,1,0),tuple(range(48,52))]);o=kit._mesh_local('torn flame with ridged volume',verts,faces,material)
  sub=o.modifiers.new('continuous lick of flame','SUBSURF');sub.levels=1
 make(1,0,fire);make(.62,-w*.65,core)

def sparks(points):
 for x,z,r in points:
  o=sphere((x,-.38,z),(r,r*.55,r*1.8),core);o.name='flying ember spark'

def backing(name):
 # No added rim or bars: only a recessed engraved iron ground.
 if name=='eclat_de_braise':sx,sz=.95,.49
 elif name=='pilier_de_flamme':sx,sz=.40,.92
 else:sx,sz=.87,.87
 o=kit.disk(0,0,1,iron,.11,.14);o.scale=(sx,sz,1)
 # flat_disk rotates cylinder about X: local XY scale maps to screen XZ.
 for i in range(19):
  a=i*math.tau/19;r=.83
  pts=[]
  for j in range(3):
   t=a+j*.032;rr=r-(.08 if j==1 else 0)
   pts.append((sx*rr*math.cos(t),.015,sz*rr*math.sin(t)))
  curve(pts,.007,bronze)
 # Inset irregular radial fissures, low contrast and safely behind the emblem.
 for a in [.5,2.3,3.9,5.1]:
  curve([(sx*r*math.cos(a+.08*math.sin(r*13)),.008,sz*r*math.sin(a+.08*math.sin(r*13))) for r in [.45,.58,.71,.79]],.009,coal)

def build(name):
 backing(name)
 if name=='eclat_de_braise':
  shard(.31,-.035,.82,1.12)
  # Wind-sheared tongues and a tapering spark wake toward the left.
  for x,z,h,w in [(.16,-.06,.60,.095),(.12,.10,.57,.065),(.10,-.18,.41,.060)]:tongue(x,z,h,w,-.03,-.32,-1.68)
  sparks([(-.73,.11,.019),(-.57,-.19,.014),(-.42,.28,.022),(-.76,-.10,.012),(-.30,.18,.019)])
 elif name=='nova_ardente':
  # Empty central eye distinguishes nova instantly from all column spells.
  for i in range(16):
   a=i*math.tau/16;x=.49*math.sin(a);z=.49*math.cos(a)
   tongue(x,z,.22+random.random()*.10,.060,.06,-.25,a)
  torus((0,-.26,0),.49,.026,ember)
  torus((0,-.28,0),.43,.013,core)
 elif name=='cendres':
  # A broad, low bed of flaky clinker, distinct from a fireball or flames.
  o=kit.disk(0,-.18,1,ember,-.14,.04);o.scale=(.64,.32,1)
  for i in range(31):
   a=i*2.399;r=.58*math.sqrt((i+.5)/31);x=r*math.cos(a);z=r*.50*math.sin(a)-.16
   radius=random.uniform(.085,.16);pts=[]
   for j in range(6):
    t=j*math.tau/6;rr=radius*random.uniform(.75,1.20);pts.append((x+rr*math.cos(t),z+rr*.63*math.sin(t)))
   slab(pts,ash if i%3 else coal,.07,-.21-random.uniform(0,.045),.012,name='splintered ash flake')
  for x,z in [(-.53,-.28),(.46,-.32),(.12,-.08),(-.23,-.37)]:shard(x,z,.24,.8,-.29)
  sparks([(-.34,.27,.013),(.12,.35,.016),(.39,.20,.012)])
 elif name=='brasier':
  # Broad turbulent ignition rising from charcoal; no horizontal hardware.
  for x,z,h,w,lean in [(-.40,-.49,.62,.14,.12),(-.22,-.52,.94,.17,-.07),(0,-.53,1.22,.19,.04),(.23,-.52,.91,.14,.13),(.42,-.47,.55,.12,.03)]:tongue(x,z,h,w,lean)
  for x in [-.34,-.13,.12,.35]:shard(x,-.53,.28,.8,-.38)
 elif name=='braises_errantes':
  # Three orbiting charred embers, separate and legible.
  for i in range(3):
   a=i*math.tau/3+.3;x=.45*math.sin(a);z=.44*math.cos(a)
   shard(x,z,.53,a);tongue(x,z,.34,.085,.10,-.31,a+1.5)
   pts=[(.47*math.sin(a-t),-.20,.47*math.cos(a-t)) for t in [.1,.3,.5,.7]];curve(pts,.012,ember)
  sparks([(-.26,.49,.014),(.49,-.26,.014),(-.42,-.39,.014)])
 elif name=='phenix':
  # Hooked avian skull, swept wings, long split tail: sculpted bronze reliquary.
  slab([(-.06,-.37),(-.17,.01),(-.08,.36),(.03,.51),(.16,.54),(.29,.42),(.16,.43),(.19,.34),(.09,.36),(.10,.04),(.14,-.28)],bronze,.10,-.20,.025)
  for sign in [-1,1]:
   for j in range(5):
    root=(sign*.07,-.19-j*.014,.12-j*.055);tip=(sign*(.68-j*.075),-.22,.53-j*.19)
    curve([root,(sign*(.36-j*.035),-.26,.15-j*.085),tip],.041-j*.004,bronze)
    tongue(tip[0],tip[2]-.06,.28,.042,sign*.06,-.31,sign*.4)
   tongue(sign*.075,-.66,.50,.050,sign*.02,-.31,sign*.18)
  curve([(0,-.29,-.29),(-.035,-.30,.05),(.015,-.30,.34)],.022,core)
  sparks([(.11,.44,.017),(-.46,.55,.012),(.49,.57,.013)])
 elif name=='pilier_de_flamme':
  # Narrow vertical lance of combustion and twisting dark core.
  for x,z,h,w,lean in [(0,-.75,1.46,.15,.025),(-.12,-.64,1.01,.085,.02),(.13,-.48,.96,.075,-.04)]:tongue(x,z,h,w,lean)
  curve([(-.08,-.37,-.65),(.11,-.36,-.27),(-.065,-.34,.10),(.09,-.33,.41)],.029,coal)
  shard(0,-.69,.34,0,-.34)
 elif name=='pluie_de_meteores':
  for x,z,k in [(-.36,.15,.52),(.10,-.34,.68),(.43,.32,.37)]:
   shard(x,z,k,.48);tongue(x-.035,z+.10,.69*k,.12*k,.07,-.31,.46)
  sparks([(-.10,.68,.015),(.38,.68,.012),(-.43,.46,.013),(.41,-.09,.014)])

def run():
 for name,d in INV['files'].items():
  s=kit.studio('i3_'+name);s.name='i3_'+name;materials();build(name)
  s.camera.location=(.12,-10,1.0);aim(s.camera,(0,0,0));frame_object_ortho(meshes(),.075)
  x,y,r,b=d['bbox'];s.render.resolution_x=round((r-x)*2.6);s.render.resolution_y=round((b-y)*2.6)
  # Camera ortho scale is the horizontal extent in landscape, vertical in portrait.
  if r-x>b-y:s.camera.data.ortho_scale*=1.12
  s.eevee.taa_render_samples=24
  s.render.filepath=str(BASE/f'i3_raw_{name}.png');bpy.ops.render.render(write_still=True)
  subprocess.run([PY,str(BASE/'i3_finish.py'),'fit',name],check=True,stdout=subprocess.DEVNULL)
  print('I3_PASS '+name,flush=True)
 bpy.ops.file.pack_all();s.render.image_settings.color_mode='RGBA';bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui/i3_ardent.blend'))
 rows=[]
 for s in bpy.data.scenes:
  if not s.name.startswith('i3_'):continue
  objects=[o for o in s.objects if o.type in {'MESH','CURVE'}];mats={m for o in objects for m in o.data.materials if m}
  metals=[m for m in mats if m.use_nodes and m.node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value==1]
  row={'scene':s.name,'objects':len(objects),'bevels':sum(m.type=='BEVEL' for o in objects for m in o.modifiers),'true_metals':len(metals),'samples':s.eevee.taa_render_samples,'engine':s.render.engine,'view':s.view_settings.view_transform}
  assert row['bevels'] and row['true_metals'] and row['engine']=='BLENDER_EEVEE';rows.append(row)
 assert len(rows)==8
 (BASE/'i3_geometry.json').write_text(json.dumps({'status':'PASS','scenes':rows},indent=2))
if __name__=='__main__':run()
