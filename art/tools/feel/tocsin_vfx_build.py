import math, sys, subprocess, json, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/renders/feel_sorts2/tocsin'
GAME=ROOT/'game/assets/sprites/vfx/tocsin'
STAGE=OUT/'validated'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'

def render():
 import bpy, random
 from mathutils import Vector
 sys.path.insert(0,str(ROOT/'art/tools/cel'))
 import cel_style as cel
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 s=bpy.context.scene; cel.setup_scene(s,samples=12)
 s.render.resolution_x=s.render.resolution_y=512
 s.render.resolution_percentage=100
 tree=bpy.data.node_groups.new('Cloud alpha dissipation','CompositorNodeTree')
 tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
 s.compositing_node_group=tree
 rl=tree.nodes.new('CompositorNodeRLayers'); output=tree.nodes.new('NodeGroupOutput')
 alpha=tree.nodes.new('ShaderNodeMath'); alpha.operation='MULTIPLY'
 setalpha=tree.nodes.new('CompositorNodeSetAlpha'); setalpha.inputs['Type'].default_value='Replace Alpha'
 tree.links.new(rl.outputs['Image'],setalpha.inputs['Image']); tree.links.new(rl.outputs['Alpha'],alpha.inputs[0])
 tree.links.new(alpha.outputs[0],setalpha.inputs['Alpha']); tree.links.new(setalpha.outputs[0],output.inputs[0])
 s.world.color=(.06,.06,.06)
 cd=bpy.data.cameras.new('TOP'); cam=bpy.data.objects.new('TOP',cd); s.collection.objects.link(cam)
 cam.location=(0,0,20); cd.type='ORTHO'; cd.ortho_scale=8; s.camera=cam
 ld=bpy.data.lights.new('large upper left','AREA'); light=bpy.data.objects.new('large upper left',ld)
 s.collection.objects.link(light); light.location=(-3, -4,8); ld.energy=650; ld.size=4
 light.rotation_euler=(Vector((0,0,0))-light.location).to_track_quat('-Z','Y').to_euler()
 def mat(n,c,e=0):
  m=bpy.data.materials.new(n); m.use_nodes=True
  p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*c,1)
  p.inputs['Roughness'].default_value=.9
  if e: p.inputs['Emission Color'].default_value=(*c,1); p.inputs['Emission Strength'].default_value=e
  return m
 steam=mat('warm white steam',(.86,.79,.64)); bronze=mat('bronze ridge',(.43,.23,.075))
 rust=mat('rust facets',(.25,.065,.022)); orange=mat('hearth orange',(1,.197,.012),1.5)
 dark=mat('ground fissures',(.019,.012,.008)); resonance=mat('bronze resonance',(.58,.31,.10))
 cel.install('vfx',normals=False); cel.toon_materials('vfx')
 # Explicit cel conversion is needed: this script renders directly, without iso_rig.
 materials=[steam,bronze,rust,orange,dark,resonance]
 original_colors={}
 for m in materials:
  nodes=m.node_tree.nodes; output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
  shader=output.inputs['Surface'].links[0].from_socket
  trans=nodes.new('ShaderNodeBsdfTransparent'); mix=nodes.new('ShaderNodeMixShader'); mix.name='Dissipation'
  m.node_tree.links.new(trans.outputs[0],mix.inputs[1]); m.node_tree.links.new(shader,mix.inputs[2])
  m.node_tree.links.new(mix.outputs[0],output.inputs['Surface'])
  m.surface_render_method='DITHERED'
  emit=next(n for n in nodes if n.type=='EMISSION'); original_colors[m.name]=tuple(emit.inputs['Color'].default_value)
 def mesh(n,verts,faces,ma):
  me=bpy.data.meshes.new(n); me.from_pydata(verts,[],faces); me.update()
  o=bpy.data.objects.new(n,me); s.collection.objects.link(o); me.materials.append(ma); return o
 def cloud(n,balls,R,angle=None):
  mb=bpy.data.metaballs.new(n); mb.resolution=.065; mb.render_resolution=.045; mb.threshold=.6
  o=bpy.data.objects.new(n,mb); s.collection.objects.link(o)
  for x,y,z,rx,ry,rz in balls:
   e=mb.elements.new(type='ELLIPSOID'); e.co=(x,y,z); e.radius=1
   e.size_x=rx; e.size_y=ry; e.size_z=rz; e.stiffness=2
  bpy.context.view_layer.objects.active=o; o.select_set(True); bpy.ops.object.convert(target='MESH'); o=bpy.context.object
  maxr=max(math.hypot(v.co.x,v.co.y) for v in o.data.vertices)
  for v in o.data.vertices:
   v.co.x*=R/maxr; v.co.y*=R/maxr
   if angle is not None:
    r=math.hypot(v.co.x,v.co.y); a=max(-angle,min(angle,math.atan2(v.co.y,v.co.x)))
    v.co.x=r*math.cos(a); v.co.y=r*math.sin(a)
  o.data.materials.append(steam)
  for p in o.data.polygons: p.use_smooth=True
  o.select_set(False); return o
 def ridge(n,R,width,ma,phase=0,height=.22):
  verts=[]; faces=[]; N=192
  for i in range(N):
   a=i*math.tau/N; tooth=(.5+.5*math.sin(37*a+phase))
   rim=R-(.018+.035*tooth+.012*math.sin(13*a+phase))
   for j in range(5):
    t=j/4; r=rim-width*(1-t)
    z=.015+height*math.sin(math.pi*t)*(.65+.35*math.sin(29*a+phase))
    verts.append((r*math.cos(a),r*math.sin(a),z))
  for i in range(N):
   for j in range(4):
    a=i*5+j; b=((i+1)%N)*5+j; faces.append((a,b,b+1,a+1))
  o=mesh(n,verts,faces,ma)
  if n=='shock front':
   o.data.materials.append(rust)
   for p in o.data.polygons: p.material_index=int((p.index//4)%11 in (0,1,5))
  return o
 def line(n,points,width,ma):
  cu=bpy.data.curves.new(n,'CURVE'); cu.dimensions='3D'; cu.bevel_depth=width; cu.bevel_resolution=0
  sp=cu.splines.new('POLY'); sp.points.add(len(points)-1)
  for p,co in zip(sp.points,points): p.co=(*co,1)
  o=bpy.data.objects.new(n,cu); s.collection.objects.link(o); cu.materials.append(ma)
 OUT.mkdir(parents=True,exist_ok=True)
 for name in ('steam_cone','steam_ring','toll_wave'):
  for f in range(6):
   for o in list(s.objects):
    if o.type not in ('LIGHT','CAMERA'): bpy.data.objects.remove(o,do_unlink=True)
   rng=random.Random(841+f); age=f/5
   if name=='steam_cone':
    R=[90,125,160,190,220,240][f]/64; angle=math.radians([12,17,22,26,29,30][f]); balls=[]
    for j in range(1,8):
     t=j/8; x=R*t; span=x*math.tan(angle)*.76
     for lane in (-1,0,1):
      y=lane*span*.57; rad=max(.045,span*(.68+.14*math.sin(j*2.1+lane)))
      balls.append((x,y,.13+rad*(.4+.2*math.sin(j)),rad*.91,rad*.95,rad*(.8+.3*math.cos(j+lane))))
    cloud('fused steam fan',balls,R,angle)
    line('hot throat',[(0,0,.65),(R*.12,0,.75),(R*.30,0,.80)],.048,orange)
    for i in range(3):
     x=R*(.15+i*.08); line('orange curl',[(x,-x*.07,.77),(x*1.10,x*.06,.82)],.035,orange)
   elif name=='steam_ring':
    R=[100,130,160,190,220,240][f]/64; balls=[]
    for i in range(24):
     a=i*math.tau/24; r=R*(.72+.047*math.sin(7*a+age)); q=R*(.26+.060*math.sin(11*a+age))
     balls.append((r*math.cos(a),r*math.sin(a),.16+q*.18*math.sin(9*a),q,q*.92,q*(.8+.25*math.sin(5*a))))
    cloud('fused rolling steam crown',balls,R)
    for i in range(9):
     a=i*math.tau/9+age*.2; r=R*.53
     line('inner hearth embers',[(r*math.cos(a),r*math.sin(a),.9),((r+.09)*math.cos(a+.035),(r+.09)*math.sin(a+.035),.95)],.026,orange)
   else:
    R=[40,90,140,185,215,240][f]/64
    ridge('shock front',R,min(35/64,R*.45),bronze,age*2,.30)
    for ratio in (.63,.79): ridge('resonance',R*ratio,.028,resonance,age,.065)
    if f<2:
     for i in range(12):
      a=i*math.tau/12+rng.uniform(-.06,.06)
      points=[((R*t)*math.cos(a+da),(R*t)*math.sin(a+da),.005) for t,da in ((.12,0),(.43,.045),(.62,-.03),(.91,.015))]
      line('radial ground fissure',points,.018,dark)
    for i in range(22):
     a=i*math.tau/22+age*.2; r=R*(.87+.06*rng.random())
     line('orange impact spark',[(r*math.cos(a),r*math.sin(a),.30),((r-.055)*math.cos(a+.012),(r-.055)*math.sin(a+.012),.38)],.018,orange)
   fade=([1,1,.94,.83,.54,.25] if name!='toll_wave' else [1,1,1,.92,.55,.22])[f]
   for emitpass in (False,True):
    s.render.resolution_percentage=50 if emitpass else 100
    alpha.inputs[1].default_value=fade
    for m in materials:
     nodes=m.node_tree.nodes; nodes['Dissipation'].inputs[0].default_value=1
     em=next(n for n in nodes if n.type=='EMISSION')
     if emitpass:
      for link in list(em.inputs['Color'].links): m.node_tree.links.remove(link)
      em.inputs['Color'].default_value=original_colors[m.name] if m==orange else (0,0,0,1)
     else:
      ramp=next((n for n in nodes if n.type=='VALTORGB'),None)
      if ramp and not em.inputs['Color'].is_linked: m.node_tree.links.new(ramp.outputs['Color'],em.inputs['Color'])
      elif not ramp: em.inputs['Color'].default_value=original_colors[m.name]
    s.render.filepath=str(OUT/(f'{name}_{f}'+('_e' if emitpass else '')+'.png')); bpy.ops.render.render(write_still=True)
 print('PASS render tocsin 36 frames')

def pack():
 from PIL import Image
 import shutil
 for name in ('steam_cone','steam_ring','toll_wave'):
  folder=STAGE/name; folder.mkdir(parents=True,exist_ok=True)
  for emit in (False,True):
   size=256 if emit else 512; atlas=Image.new('RGBA',(size*6,size))
   for f in range(6):
    im=Image.open(OUT/(f'{name}_{f}'+('_e' if emit else '')+'.png')).convert('RGBA'); atlas.paste(im,(f*size,0))
   if not emit:
    for colors in (64,48,32):
     q=atlas.quantize(colors=colors,method=Image.Quantize.FASTOCTREE); q.save(folder/'default.png',optimize=True)
     if (folder/'default.png').stat().st_size<=150000: break
   else:
    for colors in (16,8,4,2):
     atlas.quantize(colors=colors,method=Image.Quantize.FASTOCTREE).save(folder/'default_e.png',optimize=True)
     if (folder/'default_e.png').stat().st_size<=30000: break
  # Preserve resource layout; repair only durations required by the original contract.
  import re
  tres=(GAME/name/f'{name}.tres').read_text(encoding='utf8')
  durations=iter([3,4,5,6,8,12] if name=='toll_wave' else [4,5,6,8,10,14])
  tres=re.sub(r'"duration": [0-9.]+',lambda m:'"duration": '+str(next(durations)*12/60),tres)
  (folder/f'{name}.tres').write_text(tres,encoding='utf8')
 print('PASS pack tocsin')

def verify():
 from PIL import Image
 import hashlib, numpy as np
 out={}
 for name in ('steam_cone','steam_ring','toll_wave'):
  folder=STAGE/name; im=Image.open(folder/'default.png').convert('RGBA'); em=Image.open(folder/'default_e.png').convert('RGBA'); boxes=[]; hashes=[]; radii=[]; sectors=[]; masses=[]; widths=[]; emission=[]
  assert im.size==(3072,512) and em.size==(1536,256)
  assert (folder/'default.png').stat().st_size<=150000 and (folder/'default_e.png').stat().st_size<=30000
  for f in range(6):
   tile=im.crop((f*512,0,(f+1)*512,512)); box=tile.getchannel('A').getbbox(); assert box; boxes.append(box); hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
   rgba=np.asarray(tile); alpha=rgba[:,:,3].astype(float); yy,xx=np.indices(alpha.shape); dx=xx+.5-256; dy=yy+.5-256; rr=np.hypot(dx,dy)
   radii.append(round(float(rr[alpha>12].max()),1)); masses.append(round(float(alpha.sum()/255)))
   widths.append(box[3]-box[1])
   e=np.asarray(em.crop((f*256,0,(f+1)*256,256)))
   emission.append(round(float((e[:,:,:3].max(axis=2)*e[:,:,3].astype(float)/255).sum()),1))
   assert emission[-1]>100,'empty emission frame'
   assert np.ptp(rgba[alpha>12,:3].astype(float))>40
   if name=='steam_cone':
    sector=(dx>=0)&(np.abs(dy)<=dx*math.tan(math.radians(35)))
    sectors.append(round(float(alpha[sector].sum()/alpha.sum()*100),3)); assert sectors[-1]>=95
   elif name=='steam_ring' and f>=2: assert alpha[rr<radii[-1]*.30].max()==0,'central hole'
  assert len(set(hashes))==6; assert em.getchannel('A').getbbox()
  extrema=em.getextrema(); assert max(x[1] for x in extrema[:3])>0
  targets=([90,125,160,190,220,240] if name=='steam_cone' else [100,130,160,190,220,240] if name=='steam_ring' else [40,90,140,185,215,240])
  assert all(abs(a-b)<4 for a,b in zip(radii,targets)),(name,radii)
  if name=='steam_cone': assert all(a<b for a,b in zip(widths,widths[1:])),widths
  assert masses[-1]<masses[-2] if name=='toll_wave' else True
  assert not list((GAME/name).glob('*_n.png'))
  assert 'CanvasTexture' not in (folder/f'{name}.tres').read_text() and 'normal_texture' not in (folder/f'{name}.tres').read_text()
  out[name]={'bytes':[(folder/'default.png').stat().st_size,(folder/'default_e.png').stat().st_size],'radii':radii,'sector_percent':sectors,'widths':widths,'alpha_mass':masses,'emission':emission}
 # single contact sheet, nearest assembly only
 contact=Image.new('RGBA',(1020,510),(58,62,70,255))
 for row,name in enumerate(('steam_cone','steam_ring','toll_wave')):
  im=Image.open(STAGE/name/'default.png').convert('RGBA')
  for f in range(6): contact.alpha_composite(im.crop((f*512,0,(f+1)*512,512)).resize((170,170)),(f*170,row*170))
 dest=ROOT/'art/renders/feel_sorts2/after_vfx_tocsin.png'; dest.parent.mkdir(parents=True,exist_ok=True); contact.convert('RGB').save(dest)
 (OUT/'verification.json').write_text(json.dumps(out,indent=2))
 print('PASS verify '+json.dumps(out))

def deliver():
 import shutil
 verify()
 for name in ('steam_cone','steam_ring','toll_wave'):
  for file in ('default.png','default_e.png',f'{name}.tres'):
   shutil.copy2(STAGE/name/file,GAME/name/file)
 print('PASS deliver 6 PNG; 3 durations repaired')

if __name__=='__main__':
 if '--render' in sys.argv: render()
 elif '--pack' in sys.argv: pack()
 elif '--deliver' in sys.argv: deliver()
 else: verify()
