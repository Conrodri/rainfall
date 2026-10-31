import bpy, math, os, random, sys, json
from mathutils import Vector
ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'..','..','..'))
OUT=os.path.join(ROOT,'game','assets','sprites','terrain','terraces','sol')
BLEND=os.path.join(ROOT,'art','blender','sol','terrasses_sol.blend')
REND=os.path.join(ROOT,'art','renders','sol_v2','codex','terrasses')
sys.path.insert(0,os.path.dirname(__file__))
sys.path.insert(0,os.path.join(REND,'_deps'))
from sol_tools import make_seamless, verify, sheet3x3
for p in (OUT,REND,os.path.dirname(BLEND)): os.makedirs(p,exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
sc=bpy.context.scene; sc.render.engine='BLENDER_EEVEE'
if hasattr(sc,'eevee'): sc.eevee.taa_render_samples=16
sc.render.resolution_x=sc.render.resolution_y=1024; sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG'; sc.render.image_settings.color_mode='RGB'
sc.render.film_transparent=False; sc.view_settings.view_transform='Standard'
sc.view_settings.look='None'; sc.view_settings.exposure=0; sc.view_settings.gamma=1
sc.world.color=(0,0,0); sc.render.image_settings.color_depth='8'
bpy.ops.object.camera_add(location=(0,0,10)); cam=bpy.context.object
cam.data.type='ORTHO'; cam.data.ortho_scale=8; sc.camera=cam

def linear(c):
 return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c)+(1,)
def rgb(h): return linear(tuple(int(h[i:i+2],16)/255 for i in (0,2,4)))
def material(name):
 m=bpy.data.materials.new(name); m.use_nodes=True; m.node_tree.nodes.clear()
 return m,m.node_tree.nodes,m.node_tree.links

def base_material(idx):
 m,n,l=material('terraces_base_'+str(idx))
 def node(t): return n.new(t)
 def mathn(op,a,b=None):
  q=node('ShaderNodeMath'); q.operation=op
  for k,v in enumerate((a,b)):
   if v is None: continue
   if isinstance(v,(int,float)): q.inputs[k].default_value=v
   else: l.new(v,q.inputs[k])
  return q.outputs[0]
 def ramp(f,stops):
  q=node('ShaderNodeValToRGB'); cr=q.color_ramp
  for e in list(cr.elements)[1:]: cr.elements.remove(e)
  for j,(pos,col) in enumerate(stops):
   e=cr.elements[0] if j==0 else cr.elements.new(pos)
   e.position=pos; e.color=rgb(col)
  l.new(f,q.inputs[0]); return q.outputs[0]
 tc=node('ShaderNodeTexCoord'); sep=node('ShaderNodeSeparateXYZ'); l.new(tc.outputs['Generated'],sep.inputs[0])
 # A torus embeds both image periods in 4D; every procedural field is periodic.
 u=mathn('MULTIPLY',sep.outputs['X'],2*math.pi); v=mathn('MULTIPLY',sep.outputs['Y'],2*math.pi)
 xyz=node('ShaderNodeCombineXYZ')
 for k,s in enumerate((mathn('SINE',u),mathn('COSINE',u),mathn('SINE',v))): l.new(mathn('MULTIPLY',s,1.65),xyz.inputs[k])
 w=mathn('MULTIPLY',mathn('COSINE',v),1.65)
 def noise(scale,detail=2):
  q=node('ShaderNodeTexNoise'); q.noise_dimensions='4D'; q.inputs['Scale'].default_value=scale; q.inputs['Detail'].default_value=detail; q.inputs['Roughness'].default_value=.68
  l.new(xyz.outputs[0],q.inputs['Vector']); l.new(w,q.inputs['W']); return q
 warp=noise(2.1); sub=node('ShaderNodeVectorMath'); sub.operation='SUBTRACT'; l.new(warp.outputs['Color'],sub.inputs[0]); sub.inputs[1].default_value=(.5,.5,.5)
 mul=node('ShaderNodeVectorMath'); mul.operation='SCALE'; l.new(sub.outputs[0],mul.inputs[0]); mul.inputs['Scale'].default_value=.30
 add=node('ShaderNodeVectorMath'); add.operation='ADD'; l.new(xyz.outputs[0],add.inputs[0]); l.new(mul.outputs[0],add.inputs[1])
 def vor(scale,feature):
  q=node('ShaderNodeTexVoronoi'); q.voronoi_dimensions='4D'; q.feature=feature; q.distance='EUCLIDEAN'; q.inputs['Scale'].default_value=scale; q.inputs['Randomness'].default_value=1
  l.new(add.outputs[0],q.inputs['Vector']); l.new(w,q.inputs['W']); return q
 broad=noise(.65).outputs['Fac']; grain=noise(29,2).outputs['Fac']; fine=noise(8,3).outputs['Fac']
 a=vor(1.05 if idx==0 else 2.7,'F1'); b=vor(1.05 if idx==0 else 2.7,'F2')
 gap=mathn('SUBTRACT',b.outputs['Distance'],a.outputs['Distance'])
 height=mathn('MULTIPLY_ADD',gap,2.9)
 # Variable cell sizes, two scales of fractured joints, soft height-driven colour.
 small1=vor(3.8,'F1'); small2=vor(3.8,'F2'); microgap=mathn('SUBTRACT',small2.outputs['Distance'],small1.outputs['Distance'])
 if idx in (0,3):
  joint=mathn('MULTIPLY',gap,mathn('ADD',fine,.35))
  field=mathn('ADD',mathn('MULTIPLY',joint,2.9 if idx==0 else 3.8),mathn('MULTIPLY',fine,.20))
  field=mathn('ADD',field,mathn('MULTIPLY',microgap,.18))
  stops=[(.015,'2B403D'),(.10,'3B504C'),(.24,'4B605A'),(.48,'60746B'),(.80,'707F73')]
  if idx==3: stops=[(.02,'384642'),(.14,'4A5850'),(.34,'657067'),(.62,'7F8575'),(.9,'969883')]
 elif idx==1:
  field=mathn('ADD',mathn('MULTIPLY',broad,.75),mathn('MULTIPLY',fine,.27))
  stops=[(.22,'3B5041'),(.40,'4D634A'),(.49,'627154'),(.56,'777B61'),(.78,'92917A')]
 else:
  field=mathn('ADD',mathn('MULTIPLY',fine,.60),mathn('MULTIPLY',broad,.4))
  stops=[(.20,'1F3139'),(.40,'2C4145'),(.48,'3C5050'),(.60,'52635C'),(.8,'637167')]
 color=ramp(field,stops)
 mix=node('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=.14 if idx!=2 else .045
 l.new(color,mix.inputs[1]); l.new(ramp(grain,[(.2,'809181'),(.8,'FFFFFF')]),mix.inputs[2])
 em=node('ShaderNodeEmission'); l.new(mix.outputs[0],em.inputs[0]); out=node('ShaderNodeOutputMaterial'); l.new(em.outputs[0],out.inputs['Surface'])
 return m

planes=[]
for idx in range(4):
 bpy.ops.mesh.primitive_plane_add(size=8); plane=bpy.context.object; plane.name='base_'+str(idx); plane.data.materials.append(base_material(idx)); planes.append(plane)
 raw=os.path.join(REND,f'base_{idx}_raw.png'); sc.render.filepath=raw; bpy.ops.render.render(write_still=True)
 make_seamless(raw,os.path.join(OUT,f'base_{idx}.png'),size=512)
 sheet3x3(os.path.join(OUT,f'base_{idx}.png'),os.path.join(REND,f'base_{idx}_sheet3x3.png'))
 plane.hide_render=True

# Flat painted meshes: radial UV alpha feather, emission only, no lights.
sc.render.resolution_x=sc.render.resolution_y=512; sc.render.image_settings.color_mode='RGBA'; sc.render.film_transparent=True
random.seed(791)
def pigment(name,color,opacity=1):
 m,n,l=material(name); uv=n.new('ShaderNodeTexCoord'); sep=n.new('ShaderNodeSeparateXYZ'); l.new(uv.outputs['UV'],sep.inputs[0])
 ramp=n.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.65; ramp.color_ramp.elements[0].color=(opacity,opacity,opacity,1); ramp.color_ramp.elements[1].position=1; ramp.color_ramp.elements[1].color=(0,0,0,1); l.new(sep.outputs['X'],ramp.inputs[0])
 em=n.new('ShaderNodeEmission'); em.inputs[0].default_value=rgb(color); tr=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader'); l.new(ramp.outputs[0],mix.inputs[0]); l.new(tr.outputs[0],mix.inputs[1]); l.new(em.outputs[0],mix.inputs[2]); out=n.new('ShaderNodeOutputMaterial'); l.new(mix.outputs[0],out.inputs[0]); return m
mats={k:pigment(k,c,o) for k,c,o in [('water','1F3139',.88),('rim','59716B',.65),('rice','8B9460',1),('rice_dark','53674A',1),('crack','263D39',.90),('stone','7B877A',1),('stone_dark','4A5D56',1),('moss','697B4D',.9),('bamboo','8C7A4C',1),('leaf','788553',1)]}

def blob(name,x,y,rx,ry,ang,mat,z=.1,count=17,jitter=.16):
 verts=[(x,y,z)]; theta=[]
 for j in range(count):
  t=2*math.pi*j/count; r=1+random.uniform(-jitter,jitter); xx=rx*math.cos(t)*r; yy=ry*math.sin(t)*r
  verts.append((x+xx*math.cos(ang)-yy*math.sin(ang),y+xx*math.sin(ang)+yy*math.cos(ang),z))
 faces=[(0,j+1,(j+1)%count+1) for j in range(count)]
 mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update(); uv=mesh.uv_layers.new()
 for poly in mesh.polygons:
  for li in poly.loop_indices: uv.data[li].uv=(0 if mesh.loops[li].vertex_index==0 else 1,0)
 ob=bpy.data.objects.new(name,mesh); sc.collection.objects.link(ob); ob.data.materials.append(mats[mat]); return ob

def stroke(name,x,y,length,width,angle,mat,z=.14):
 return blob(name,x,y,length/2,width/2,angle,mat,z,count=12,jitter=.05)
# Row-major: first seven families, a second leaf, then eight new compositions.
for i in range(16):
 cx=-3+2*(i%4); cy=3-2*(i//4); typ=i%8; variant=i//8
 tag=f'decal_{i:02d}'
 if typ==0:
  for j in range(2+variant):
   x=cx+random.uniform(-.26,.26); y=cy+random.uniform(-.24,.24); a=random.uniform(.3,2.7); rx=random.uniform(.24,.43); ry=random.uniform(.17,.27)
   blob(tag+'_rim',x,y,rx,ry,a,'rim'); blob(tag+'_water',x,y,rx*.92,ry*.88,a,'water',.12)
 elif typ==1:
  a=random.uniform(.4,2.6)
  for j in range(10+3*variant):
   stroke(tag+'_rice',cx+random.uniform(-.22,.22),cy+random.uniform(-.23,.23),random.uniform(.45,.95),.035,a+random.uniform(-.4,.4),'rice' if j%3 else 'rice_dark')
 elif typ==2:
  x=cx-.42; y=cy-.30
  for j in range(5+variant):
   dx=random.uniform(.10,.19); dy=random.uniform(.03,.17); xx=x+dx; yy=y+dy
   stroke(tag+'_fracture',(x+xx)/2,(y+yy)/2,math.hypot(dx,dy)*1.25,.033,math.atan2(dy,dx),'crack');
   if j%2: stroke(tag+'_branch',x-.05,y+.11,.30,.025,2.05,'crack')
   x,y=xx,yy
 elif typ==3:
  for j in range(5+variant*2):
   x=cx+random.uniform(-.46,.46); y=cy+random.uniform(-.4,.4); r=random.uniform(.07,.16)
   blob(tag+'_pebble',x,y,r,r*.75,random.uniform(.3,2.8),'stone_dark',count=7); blob(tag+'_facet',x-.014,y+.015,r*.75,r*.55,.8,'stone',.13,count=6)
 elif typ==4:
  for j in range(17+variant*5): blob(tag+'_moss',cx+random.uniform(-.48,.48),cy+random.uniform(-.4,.4),random.uniform(.07,.18),random.uniform(.055,.12),random.random()*3,'moss',count=12)
 elif typ==5:
  for j in range(4+variant):
   x=cx+random.uniform(-.30,.30); y=cy+random.uniform(-.32,.32); a=random.uniform(.35,2.75); le=random.uniform(.3,.65)
   stroke(tag+'_bamboo',x,y,le,.09,a,'bamboo'); stroke(tag+'_split',x+.012,y+.012,le*.82,.024,a,'rice_dark',.16)
 else:
  for j in range(6+variant*3+(typ-6)*2):
   x=cx+random.uniform(-.44,.44); y=cy+random.uniform(-.4,.4); a=random.uniform(.3,2.8)
   stroke(tag+'_leaf',x,y,random.uniform(.22,.38),.10,a,'leaf' if typ==6 else 'bamboo'); stroke(tag+'_vein',x,y,.20,.014,a,'rice',.17)
sc.render.filepath=os.path.join(REND,'decals_raw.png'); bpy.ops.render.render(write_still=True)
from PIL import Image
Image.open(sc.render.filepath).save(os.path.join(OUT,'decals.png'),optimize=True)
sc.render.use_file_extension=True; bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
checks=[verify(os.path.join(OUT,f'base_{i}.png')) for i in range(4)]
import numpy as np
im=Image.open(os.path.join(OUT,'decals.png')); a=np.asarray(im); cells=[]
for i in range(16):
 c=a[(i//4)*128:(i//4+1)*128,(i%4)*128:(i%4+1)*128]; ys,xs=np.where(c[:,:,3]>0)
 cells.append({'visible':len(xs),'margin':int(min(xs.min(),ys.min(),127-xs.max(),127-ys.max())),'hash':hash(c.tobytes())})
ok=all(v['ok_size'] and v['mode']=='RGB' and v['kb']<=450 and v['seam_ratio']<2.5 and 8<=v['std']<=28 for v in checks)
ok=ok and im.size==(512,512) and im.mode=='RGBA' and min(c['margin'] for c in cells)>=8 and len(set(c['hash'] for c in cells))==16
report={'pass':bool(ok),'bases':checks,'decals':{'size':im.size,'mode':im.mode,'distinct':len(set(c['hash'] for c in cells)),'margin':min(c['margin'] for c in cells)}}
with open(os.path.join(REND,'verification.txt'),'w') as f: f.write(json.dumps(report,indent=2))
# One final contact sheet; PIL assembles/resizes only.
contact=Image.new('RGB',(1024,640),(25,32,30))
for i in range(4): contact.paste(Image.open(os.path.join(REND,f'base_{i}_sheet3x3.png')).resize((256,256)),(i*256,0))
for i in range(4): contact.paste(Image.open(os.path.join(OUT,f'base_{i}.png')).resize((192,192)),(i*192,256))
contact.paste(im.resize((256,256)),(768,320),im.resize((256,256)))
contact.save(os.path.join(REND,'contact.png'))
print('TERRACES '+('PASS' if ok else 'FAIL')+' '+json.dumps(report))


