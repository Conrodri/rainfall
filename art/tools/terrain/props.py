"""Rainfall props. Run exclusively with blender.exe --background --python.
All geometry, normal encoding and emission masks are rendered in Blender.
Use assemble_props.py with system Python for LANCZOS reduction and sheet assembly.
"""
import bpy, math, random, sys, argparse
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
RAW=ROOT/'art/renders/terrain/props'
random.seed(41)
def rgb(h):
 c=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)+(1,)
def mat(name,color,metal=0,emit=0):
 m=bpy.data.materials.new(name); m.use_nodes=True
 n=m.node_tree.nodes; l=m.node_tree.links
 p=n.get('Principled BSDF'); p.inputs['Base Color'].default_value=rgb(color); p.inputs['Metallic'].default_value=metal
 p.inputs['Roughness'].default_value=.38 if metal else .76
 p.inputs['Emission Color'].default_value=rgb(color); p.inputs['Emission Strength'].default_value=emit
 p.name='beauty'
 geo=n.new('ShaderNodeNewGeometry')
 vt=n.new('ShaderNodeVectorTransform'); vt.vector_type='NORMAL'; vt.convert_from='WORLD'; vt.convert_to='CAMERA'; l.new(geo.outputs['Normal'],vt.inputs[0])
 mul=n.new('ShaderNodeVectorMath'); mul.operation='MULTIPLY'; mul.inputs[1].default_value=(.5,.5,-.5); l.new(vt.outputs[0],mul.inputs[0])
 add=n.new('ShaderNodeVectorMath'); add.operation='ADD'; add.inputs[1].default_value=(.5,.5,.5); l.new(mul.outputs[0],add.inputs[0])
 norm=n.new('ShaderNodeEmission'); norm.name='normal'; l.new(add.outputs[0],norm.inputs[0])
 em=n.new('ShaderNodeEmission'); em.name='mask'; em.inputs[0].default_value=rgb(color) if emit else (0,0,0,1); em.inputs[1].default_value=1
 return m
def apply(o,m):
 o.data.materials.append(m); return o
def bevel(o,w=.045):
 mod=o.modifiers.new('Soft worn edges','BEVEL'); mod.width=w; mod.segments=3
 o.modifiers.new('Weighted normals','WEIGHTED_NORMAL'); return o
def box(loc,scale,m):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.scale=scale
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return bevel(apply(o,m))
def sphere(loc,scale,m):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=loc); o=bpy.context.object; o.scale=scale
 for p in o.data.polygons:p.use_smooth=True
 return apply(o,m)
def cyl(loc,r,depth,m,r2=None,vertices=32):
 bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=depth,location=loc)
 return bevel(apply(bpy.context.object,m),.025)
def line(points,r,m):
 c=bpy.data.curves.new('sculpted_line','CURVE'); c.dimensions='3D'; c.resolution_u=2; c.bevel_depth=r; c.bevel_resolution=3
 sp=c.splines.new('POLY'); sp.points.add(len(points)-1)
 for p,v in zip(sp.points,points):p.co=(*v,1)
 o=bpy.data.objects.new('sculpted_line',c); bpy.context.collection.objects.link(o); apply(o,m); return o
def ring(loc,r,minor,m):
 bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=minor,major_segments=48,minor_segments=8,location=loc)
 return apply(bpy.context.object,m)
def setup(name,size,extent):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 for m in list(bpy.data.materials):bpy.data.materials.remove(m)
 s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'
 s.render.resolution_x=size*2; s.render.resolution_y=size*2; s.render.resolution_percentage=100
 s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True
 s.render.image_settings.color_depth='8'; s.view_settings.view_transform='Standard'; s.view_settings.look='None'
 s.render.engine='BLENDER_EEVEE'; s.render.film_transparent=True
 s.world.color=(.16,.16,.16)
 bpy.ops.object.camera_add(location=(0,-10*math.cos(math.radians(55)),10*math.sin(math.radians(55))))
 c=bpy.context.object; c.rotation_euler=(Vector((0,0,0))-c.location).to_track_quat('-Z','Y').to_euler(); c.data.type='ORTHO'; c.data.ortho_scale=extent; s.camera=c
 for name,loc,col,energy,typ in [('Warm key',(-4,-4,8),'FFE2C0',2.0,'SUN'),('Cool fill',(4,1,6),'8FA8C8',350,'AREA')]:
  bpy.ops.object.light_add(type=typ,location=loc); o=bpy.context.object; o.name=name; o.data.color=rgb(col)[:3]; o.data.energy=energy
  o.rotation_euler=(Vector((0,0,0))-o.location).to_track_quat('-Z','Y').to_euler()
  if typ=='SUN':o.data.angle=.4
  else:o.data.shape='DISK';o.data.size=5
 return s
def palette():
 return dict(stone=mat('Rain dark stone','3E4C4D'),rim=mat('Pale upper left edges','8AA09A'),moss=mat('Moss','505E48'),
 bronze=mat('Aged bronze','8C7A4C',.65),patina=mat('Verdigris','466E65',.4),wood=mat('Wet wood','493A2E'),dark=mat('Recess','202E32'),
 leaf=mat('Pine needles','384E46'),water=mat('Rain water','54707A',.25),glow=mat('Electric cyan','83E4F5',.15,4),
 foam=mat('Splash foam','9DB6BC',0,.3),white=mat('Cold white glow','DDEFFF',.1,3),warm=mat('Lantern core','FFD49A',0,3))
def pillar(p,large,state,f):
 h=2.5 if large else 1.5; k=h/1.5
 cyl((0,0,.11*k),.40*k,.22*k,p['stone'],vertices=8)
 cyl((0,0,.25*k),.29*k,.10*k,p['bronze'],vertices=8)
 cyl((0,0,.70*k),.17*k,.85*k,p['patina'],.12*k,12)
 for z in (.38,.55,.95,1.12):cyl((0,0,z*k),.21*k,.065*k,p['bronze'],vertices=12)
 sphere((0,0,1.20*k),(.23*k,.23*k,.16*k),p['bronze'])
 cyl((0,0,1.39*k),.055*k,.38*k,p['bronze'],.012*k,12)
 for x in (-1,1):
  line([(x*.13*k,0,.94*k),(x*.32*k,0,1.10*k),(x*.32*k,0,1.35*k)],.035*k,p['bronze'])
  sphere((x*.32*k,0,1.36*k),(.055*k,)*3,p['glow'] if state=='active' else p['white'] if state=='done' else p['bronze'])
 if state!='off':
  g=p['glow'] if state=='active' else p['white']
  ring((0,0,.31*k),.24*k,.024*k,g)
  sphere((0,-.16*k,.78*k),(.065*k,.035*k,.12*k),g)
  if state=='active':
   phase=math.tau*f/8
   for side in (-1,1):
    pts=[]
    for j in range(11):
     t=j/10; x=side*(.32*(1-t)+.015*t)+.065*math.sin(j*2.4+phase)*math.sin(math.pi*t)
     pts.append((x*k,-.025*k,(1.35+.31*t)*k))
    line(pts,.014*k,g)
   ring((0,0,1.21*k),(.26+.025*math.sin(phase))*k,.014*k,g)
def teleport(p,state,f):
 cyl((0,0,.10),1.0,.20,p['stone'],vertices=12)
 cyl((0,0,.23),.88,.12,p['bronze'],vertices=12)
 cyl((0,0,.30),.73,.045,p['dark'],vertices=48)
 g=p['glow'];ring((0,0,.34),.67,.035,g);ring((0,0,.34),.46,.018,g)
 for i in range(8):
  a=i*math.tau/8; x,y=.82*math.cos(a),.82*math.sin(a)
  o=box((x,y,.34),(.13,.13,.09),p['patina']);o.rotation_euler.z=a
  line([(.5*math.cos(a),.5*math.sin(a),.35),(.62*math.cos(a),.62*math.sin(a),.35)],.026,g)
 if state=='active':
  for side in (-1,1):
   line([(side*.68,0,.35),(side*.82,0,.65),(side*.72,0,1.25),(side*.44,0,1.72),(0,0,1.91)],.11,p['patina'])
   line([(side*.66,-.07,.42),(side*.73,-.07,.70),(side*.63,-.07,1.23),(side*.38,-.07,1.64),(0,-.07,1.81)],.025,g)
  for i in range(3):
   z=.58+i*.36
   line([(-.43,0,z),(-.19,-.025,z+.09),(.02,0,z-.05),(.21,-.025,z+.10),(.43,0,z)],.014,g)
def wall(p,kind):
 cells=[(i*.48,0) for i in range(-2,3)]
 if kind=='corner':cells=[(i*.48-.72,-.72) for i in range(4)]+[(-.72,i*.48-.72) for i in range(1,4)]
 if kind=='gap_stairs':cells=[(-1.1,0),(-.66,0),(.66,0),(1.1,0)]
 for x,y in cells:
  for row in range(3):box((x+(row%2)*.025,y,.13+row*.23),(.46,.43,.215),p['stone'])
  box((x,y,.76),(.48,.48,.12),p['stone'])
  box((x-.22,y,.825),(.026,.46,.018),p['rim'])
  box((x,y+.22,.825),(.46,.026,.018),p['rim'])
  box((x-.09,y,.83),(.24,.27,.025),p['moss'])
 if kind=='gap_stairs':
  for i in range(4):box((0,-.57+i*.24,.07+i*.105),(.78,.30,.14+i*.11),p['stone'])
def pine(p):
 line([(0,0,0),(-.12,0,.6),(.13,.02,1.1),(.1,0,1.7),(.35,.02,2.1)],.13,p['wood'])
 for x,z,side in [(-.55,.8,-1),(.55,1.25,1),(-.35,1.65,-1),(.32,2.02,1)]:
  line([(.04,0,z-.25),(x,.03,z),(x+side*.18,0,z+.12)],.055,p['wood'])
  for j in range(4):
   sphere((x+(j-1.5)*.15,.06*(j%2),z+.13),(.31,.24,.13),p['leaf'])
 for x in (-.3,.3):line([(0,0,.15),(x,-.12,.04)],.07,p['wood'])
def lantern(p):
 cyl((0,0,.08),.40,.16,p['stone'],vertices=6);cyl((0,0,.40),.14,.65,p['stone'],vertices=8)
 cyl((0,0,.75),.31,.12,p['rim'],vertices=4)
 box((0,0,.96),(.34,.34,.37),p['warm'])
 for x in (-.23,.23):
  for y in (-.23,.23):box((x,y,.98),(.085,.085,.43),p['stone'])
 cyl((0,0,1.26),.49,.27,p['stone'],.17,4);cyl((0,0,1.42),.17,.12,p['rim'],.06,8)
def boat(p):
 # Open hull: keel and bent wooden ribs, with individually fitted planks.
 for side in (-1,1):
  for j in range(4):
   z=.12+j*.10; w=.20+j*.075
   line([(-1.05,0,.48),(-.78,side*w*.8,z+.08),(0,side*w,z),(.78,side*w*.8,z+.08),(1.05,0,.48)],.065,p['wood'])
 for x in (-.55,0,.55):box((x,0,.38),(.17,.65,.07),p['bronze'] if x==0 else p['wood'])
 line([(-.85,-.6,.34),(.9,.45,.48)],.035,p['wood']);box((-.8,-.58,.34),(.38,.16,.035),p['wood'])
def jar(p):
 # Lathed hollow ceramic vessel.
 profile=[(.0,.03),(.23,.03),(.35,.19),(.39,.43),(.30,.65),(.19,.74),(.19,.83),(.15,.83),(.15,.74),(.25,.62),(.30,.40),(.24,.15),(.0,.13)]
 verts=[];faces=[]
 for r,z in profile:
  for i in range(48):verts.append((r*math.cos(i*math.tau/48),r*math.sin(i*math.tau/48),z))
 for j in range(len(profile)-1):
  for i in range(48):a=j*48+i;b=j*48+(i+1)%48;faces.append((a,b,b+48,a+48))
 me=bpy.data.meshes.new('Hollow jar');me.from_pydata(verts,[],faces);me.update()
 o=bpy.data.objects.new('Jar',me);bpy.context.collection.objects.link(o);apply(o,p['patina'])
 for f in me.polygons:f.use_smooth=True
 ring((0,0,.80),.175,.028,p['bronze']);ring((0,0,.23),.34,.012,p['bronze'])
def stele(p):
 box((0,0,.10),(.85,.52,.20),p['stone']);box((0,0,.71),(.56,.24,1.10),p['stone'])
 cyl((0,0,1.28),.29,.19,p['rim'],.12,4)
 for z in (.5,.67,.84,1.01):box((-.02,-.129,z),(.18 if z!=.84 else .28,.018,.025),p['rim'])
def rock(p):
 for x,y,z,s in [(0,0,.23,(.62,.43,.40)),(.36,.1,.16,(.32,.30,.23)),(-.36,-.2,.1,(.26,.21,.16))]:
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(x,y,z));o=bpy.context.object;o.scale=s;apply(o,p['stone'])
 sphere((-.18,.03,.52),(.28,.22,.018),p['moss'])
def puddle(p,variant):
 rng=random.Random(60+variant);n=48
 verts=[(0,0,.015)]
 for i in range(n):
  a=math.tau*i/n;r=1+.13*math.sin(a*3+variant)+.08*math.cos(a*5)
  verts.append((r*math.cos(a),.58*r*math.sin(a),.015))
 faces=[(0,i+1,(i+1)%n+1) for i in range(n)]
 me=bpy.data.meshes.new('Puddle');me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new('Puddle',me);bpy.context.collection.objects.link(o);apply(o,p['water'])
 for j in range(2):
  line([((.4+j*.2)*math.cos(t),(.22+j*.11)*math.sin(t),.021) for t in [k*.07+variant for k in range(24)]],.012,p['rim'])
def splash(p,f,count):
 # Eclaboussure lisible sur sol sombre : couronne d'ecume claire epaisse + gouttes plus grosses (ecume = quasi emissive, eclairage plat)
 t=(f+.5)/count;r=.20+t*.62;fade=1-.55*t
 ring((0,0,.03),r,.05*fade+.012,p['foam'])
 ring((0,0,.03),r*.62,.03*fade+.008,p['foam'])
 for i in range(9):
  a=i*math.tau/9+.2;rr=.16+t*.46;z=.05+math.sin(math.pi*t)*(.28+.08*(i%3))
  sphere((rr*math.cos(a),rr*math.sin(a),z),(.06*fade+.02,)*2+(.085*fade+.03,),p['foam'])
def grass(p,v):
 rng=random.Random(90+v)
 for i in range(12+v*3):
  x,y=rng.uniform(-.3,.3),rng.uniform(-.2,.2);h=rng.uniform(.23,.62)
  line([(x,y,.02),(x+.03,y,h*.55),(x+rng.uniform(-.2,.2),y+.03,h)],.017,p['moss'])
def build(name,f=0):
 size=128;extent=2.6;emit=False;count=1
 if name.startswith('pillar_'):
  large='_large_' in name;size=256 if large else 128;extent=3.40 if large else 1.80
  state=name.split('_')[-1];emit=state!='off';count=8 if state=='active' else 1
 elif name.startswith('teleporter'):size=256;extent=3.2;emit=True
 elif name.startswith('stone_wall'):size=256 if name!='stone_wall_corner' else 384;extent=3.3 if size==256 else 4.0
 elif name=='twisted_pine':size=256;extent=3.2
 elif name=='stone_lantern':size=192;extent=2.2;emit=True
 elif name=='boat':size=256;extent=3.0
 elif name=='stele':size=192;extent=2.1
 elif name.startswith('puddle'):size=192;extent=2.7
 elif name.startswith('splash'):extent=2.2;count=8 if name=='splash8' else 4
 elif name.startswith('grass'):extent=1.25
 elif name=='jar':extent=1.25
 elif name=='rock':extent=1.8
 s=setup(name,size,extent);p=palette()
 if name.startswith('pillar'):pillar(p,large,state,f)
 elif name.startswith('teleporter'):teleport(p,name.split('_')[-1],f)
 elif name.startswith('stone_wall'):wall(p,name.removeprefix('stone_wall_'))
 elif name=='twisted_pine':pine(p)
 elif name=='stone_lantern':lantern(p)
 elif name=='boat':boat(p)
 elif name=='jar':jar(p)
 elif name=='stele':stele(p)
 elif name=='rock':rock(p)
 elif name.startswith('puddle'):puddle(p,ord(name[-1])-97)
 elif name.startswith('splash'):splash(p,f,count)
 else:grass(p,ord(name[-1])-97)
 # Center the projected silhouette with a shared framing for every frame.
 meshes=[o for o in s.objects if o.type in ('MESH','CURVE')]
 points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
 bpy.context.view_layer.update()
 points=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
 inv=s.camera.rotation_euler.to_matrix().transposed()
 ys=[(inv@v).y for v in points]
 # Fixed animation center prevents bouncing in sprite sheets.
 center= .44 if name.startswith('pillar_small') else .74 if name.startswith('pillar_large') else (max(ys)+min(ys))/2
 up=s.camera.rotation_euler.to_matrix()@Vector((0,1,0)); s.camera.location+=up*center
 folder=RAW/name;folder.mkdir(parents=True,exist_ok=True)
 if f==0:
  dest=ROOT/'art/blender/terrain'/('props_'+name+'.blend');dest.parent.mkdir(parents=True,exist_ok=True)
  bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(dest))
 for mode in ('beauty','normal','mask') if emit else ('beauty','normal'):
  for m in bpy.data.materials:
   if not m.use_nodes:continue
   n=m.node_tree.nodes;m.node_tree.links.new(n[mode].outputs[0],n.get('Material Output').inputs['Surface'])
  s.view_settings.view_transform='Raw' if mode=='normal' else 'Standard'
  suffix='' if mode=='beauty' else '_n' if mode=='normal' else '_e'
  s.render.filepath=str(folder/(f'{f:02d}'+suffix+'.png'));bpy.ops.render.render(write_still=True)
 return count
NAMES=['pillar_small_off','pillar_small_active','pillar_small_done','pillar_large_off','pillar_large_active','pillar_large_done','teleporter_idle','teleporter_active','stone_wall_straight','stone_wall_corner','stone_wall_gap_stairs','twisted_pine','stone_lantern','boat','jar','stele','rock','puddle_a','puddle_b','puddle_c','splash','splash8','grass_a','grass_b','grass_c']
if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--only',nargs='*');args=a.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
 for name in args.only or NAMES:
  count=build(name)
  for f in range(1,count):build(name,f)

