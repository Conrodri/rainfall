"""AVSV: Blender Eevee cel geometry, then atlas packing (system Python --pack)."""
import sys, math, random, shutil, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'art/blender/avsv'
OUT=ROOT/'game/assets/sprites/characters/averse/variants'
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/bosses')]
SPECS={'droplet_small':(48,4,True,12),'geyser':(640,8,False,16),'rivulet_tile':(128,4,True,10),'monsoon_zone':(1408,12,True,12)}

def render():
 import bpy, cel_style as cel, boss_common as common
 from mathutils import Vector
 def compositor(path):
  s=bpy.context.scene
  tree=bpy.data.node_groups.new('AVSV passes','CompositorNodeTree'); s.compositing_node_group=tree
  tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
  n=tree.nodes; l=tree.links; rl=n.new('CompositorNodeRLayers'); out=n.new('NodeGroupOutput'); l.new(rl.outputs['Image'],out.inputs['Image'])
  f=n.new('CompositorNodeOutputFile'); f.directory=str(path.parent); f.file_name=path.stem+'_e__'; f.file_output_items.new('RGBA','Image'); f.format.media_type='IMAGE'; f.format.file_format='PNG'; f.format.color_mode='RGBA'; f.format.color_depth='8'; l.new(rl.outputs['Image'],f.inputs[0])
 common.configure_passes=compositor
 for name,(size,count,loop,fps) in SPECS.items():
  bpy.ops.wm.read_factory_settings(use_empty=True)
  s=bpy.context.scene; cel.setup_scene(s,8); s.render.resolution_x=size*2; s.render.resolution_y=size*2; s.render.resolution_percentage=100
  cam=bpy.data.cameras.new('TOP 128px/u' if size>48 else 'projectile 64px/u'); ob=bpy.data.objects.new('Camera',cam); s.collection.objects.link(ob); s.camera=ob; ob.location=(0,0,2000); cam.type='ORTHO'; cam.ortho_scale=size; cam.clip_end=4000
  light=bpy.data.lights.new('studio','SUN'); light.energy=2.5; lo=bpy.data.objects.new('studio',light); s.collection.objects.link(lo); lo.rotation_euler=(.4,-.5,-.5)
  mats=[]
  for title,col,em in [('deep',(0.035,.075,.09),0),('water',(.07,.17,.20),0),('foam',(.54,.7,.73),0),('cyan',tuple(((v/255+.055)/1.055)**2.4 for v in (95,212,232)),1)]:
   mats.append(common.material(title,col,emission=em))
  configure=cel.install('vfx',normals=False)
  for frame in range(count):
   target=WORK/name/('%02d.png'%frame); target.parent.mkdir(parents=True,exist_ok=True)
   if target.exists() and list(target.parent.glob(target.stem+'_e__*.png')): continue
   for ob in list(s.objects):
    if ob.type=='MESH': bpy.data.objects.remove(ob,do_unlink=True)
   batches=[([],[]) for _ in mats]; phase=2*math.pi*(frame%8)/8; rng=random.Random(812)
   def poly(pts,mat=3,z=1):
    vv,ff=batches[mat]; start=len(vv); vv.extend([(x,y,z) for x,y in pts]); ff.append(tuple(range(start,start+len(pts))))
   def line(pts,width=2,mat=3,z=2):
    for a,b in zip(pts,pts[1:]):
     dx=b[0]-a[0]; dy=b[1]-a[1]; length=math.hypot(dx,dy) or 1; x=-dy/length*width/2; y=dx/length*width/2
     poly([(a[0]+x,a[1]+y),(a[0]-x,a[1]-y),(b[0]-x,b[1]-y),(b[0]+x,b[1]+y)],mat,z)
   def arc(x,y,r,a=0,b=math.tau,width=2,mat=3,z=2):
    line([(x+r*math.cos(a+(b-a)*j/32),y+r*math.sin(a+(b-a)*j/32)) for j in range(33)],width,mat,z)
   def disk(x,y,rx,ry,mat=0,z=0):
    poly([(x+rx*math.cos(j*math.tau/48),y+ry*math.sin(j*math.tau/48)) for j in range(48)],mat,z)
   if name=='droplet_small':
    pulse=1+.10*math.sin(frame*math.pi/2)
    sway=math.cos(frame*math.pi/2)
    poly([(-20,sway),(-7,5*pulse),(4,5*pulse),(22,0),(4,-5*pulse),(-7,-4*pulse)],1)
    poly([(-12,1),(0,3),(18,0),(0,-2)],3,3)
    line([(-21,-1+sway),(-12,-2+sway*.5),(-7,-1)],.8,2,4)
   elif name=='rivulet_tile':
    poly([(-66,-64),(66,-64),(66,64),(-66,64)],0,0)
    for k in range(16):
     y=-60+k*8; off=rng.random()*6.28
     pts=[(-66+j*132/96,y+2*math.sin(math.tau*(-66+j*132/96)/128+off-phase*2)) for j in range(97)]
     line(pts,1.2 if k%3 else 2,1 if k%3 else 3,1+k*.01)
    for y in [-60,60]:
     pts=[(x,y+1.2*math.sin(math.tau*x/128+phase*2)) for x in range(-66,67)]
     line(pts,2,2,4)
   elif name=='geyser':
    energy=[.23,.45,.85,1,.93,.7,.45,.16][frame]
    extent=[.55,.78,.96,1,1,1,.96,.9][frame]
    if frame<7:
     # Broken concentric water facets, rather than an opaque effect disc.
     for band in range(7):
      r=(band+1)*34*extent
      for section in range(8):
       a=section*math.tau/8+.06*math.sin(phase+band)
       arc(0,0,r,a,a+.66,15*energy,0,0)
    for k in range(70):
     a=rng.random()*math.tau; r=math.sqrt(rng.random())*240; x=r*math.cos(a); y=r*math.sin(a)
     if k<70*min(1,energy*2):
      arc(x*extent,y*extent,(4+rng.random()*12)*(1+.3*math.sin(phase+k)),phase+k,phase+k+4,1.5*min(1,energy*2),3 if k%4==0 else 2)
    for k in range(20):
     a=k*math.tau/20; r=252-4*math.sin(phase+k)
     arc(0,0,r,a,a+.15,3*energy,3,4)
    if 2<=frame<=5:
     for k in range(15):
      a=k*math.tau/15; length=(90+100*rng.random())*energy
      # Broad folded sheets tapering outward, asymmetrical foam edges.
      pts=[]
      for j in range(9):
       t=j/8; aa=a+.18*math.sin(t*4+phase+k)
       pts.append((math.cos(aa)*(18+t*length),math.sin(aa)*(18+t*length)))
      for j in range(8):
       t=j/8; width=(1-t)*22+3
       line(pts[j:j+2],width,1 if k%3 else 2,5+k*.03)
      line(pts,2.3,3,6+k*.03)
     for k in range(12):
      a=k*math.tau/12; r=(16+8*math.sin(k+phase))*energy
      disk(r*math.cos(a),r*math.sin(a),18*energy,13*energy,2,8+k*.01)
      arc(r*math.cos(a),r*math.sin(a),12*energy,a,a+2.5,2,3,9)
     for k in range(42):
      a=rng.random()*math.tau; r=(90+rng.random()*180)*energy
      disk(r*math.cos(a),r*math.sin(a),2,4,3,8)
   else:
    fade=1 if frame<8 else [0.8,.55,.3,.1][frame-8]
    for k in range(110):
     a=k*math.tau/110
     arc(0,0,637-2*math.sin(phase*2+k),a,a+.028*fade,1.8,3,3)
    for k in range(720):
     x=rng.uniform(-620,620); y=rng.uniform(-620,620); drift=(frame%8)*21
     y=(y+drift+620)%1240-620
     length=(8+22*rng.random())*fade
     if math.hypot(x,y+length)<625 and k%10<max(1,10*fade):
      line([(x,y),(x-.8,y+length)],.8+rng.random()*.7,3 if k%4 else 2,4)
      if k%5==0: arc(x,y,3+4*rng.random(),phase+k,phase+k+4,1,3,2)
    for k in range(80):
     a=rng.random()*math.tau; r=math.sqrt(rng.random())*600
     arc(r*math.cos(a),r*math.sin(a),(4+8*rng.random())*fade,phase+k,phase+k+3,1.1,3,2)
   for mat,(verts,faces) in zip(mats,batches):
    if not faces: continue
    mesh=bpy.data.meshes.new('water facets'); mesh.from_pydata(verts,[],faces); mesh.materials.append(mat); obj=bpy.data.objects.new('water facets',mesh); s.collection.objects.link(obj)
   configure(target); s.render.filepath=str(target); bpy.ops.render.render(write_still=True)
   print('AVSV rendered',name,frame,flush=True)
  cel.uninstall()
 print('AVSV RENDER PASS',flush=True)

def pack():
 from PIL import Image
 import numpy as np
 import cel_style as cel
 samples=[]
 for name,(size,count,loop,fps) in SPECS.items():
  dest=OUT/name; dest.mkdir(parents=True,exist_ok=True)
  per=(4096//size)**2; cols=min(4096//size,count); entries=[]; sheetnames=[]; seen=set()
  for start in range(0,count,per):
   n=min(per,count-start); rows=math.ceil(n/cols); width=cols*size; height=rows*size
   sheets=[Image.new('RGBA',(width,height)),Image.new('RGBA',(width//2,height//2))]
   for j in range(n):
    f=start+j; path=WORK/name/('%02d.png'%f); im=Image.open(path).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
    ep=next(path.parent.glob(path.stem+'_e__*.png')); em=Image.open(ep).convert('RGBA').resize((size//2,size//2),Image.Resampling.LANCZOS)
    if name=='rivulet_tile':
     # Exact periodic pixel boundary, including emission; no painted content.
     im.paste(im.crop((0,0,1,size)),(size-1,0)); em.paste(em.crop((0,0,1,size//2)),(size//2-1,0))
    assert im.getbbox()
    glow=np.asarray(em)
    assert (glow[:,:,:3].max(axis=2)*glow[:,:,3].astype(float)/255).max()>2
    digest=hashlib.sha256(im.tobytes()).digest()
    assert digest not in seen,(name,f,'duplicate frame')
    seen.add(digest)
    if name=='rivulet_tile':
     for image in [im,em]:
      assert image.crop((0,0,1,image.height)).tobytes()==image.crop((image.width-1,0,image.width,image.height)).tobytes()
    x=j%cols*size; y=j//cols*size
    sheets[0].paste(im,(x,y)); sheets[1].paste(em,(x//2,y//2)); entries.append((len(sheetnames),x,y))
    samples.append((name,f,im.copy()))
   stem=name+('_'+str(len(sheetnames)) if count>per else '')
   for sheet,suffix in zip(sheets,['','_e']): sheet.save(dest/(stem+suffix+'.png'),optimize=True)
   sheetnames.append(stem)
   cel.check_sheet(str((dest/(stem+'.png')).relative_to(ROOT/'game/assets/sprites')),normals=False)
  for emission in [False,True]:
   text=['[gd_resource type="SpriteFrames" format=3]']
   for i,stem in enumerate(sheetnames):
    suffix='_e' if emission else ''; path=(dest/(stem+suffix+'.png')).relative_to(ROOT/'game').as_posix()
    text.append(f'[ext_resource type="Texture2D" path="res://{path}" id="{i}"]')
   for f,(idx,x,y) in enumerate(entries):
    # Existing Averse convention: emission regions stay in diffuse coordinates.
    factor=1
    text.append(f'[sub_resource type="AtlasTexture" id="f{f}"]\natlas = ExtResource("{idx}")\nregion = Rect2({x//factor}, {y//factor}, {size//factor}, {size//factor})')
   anims=[]
   for anim,ids,lp in [('default',range(8 if name=='monsoon_zone' else count),loop)]+([('end',range(8,12),False)] if name=='monsoon_zone' else []):
    frames=', '.join('{"duration": 1.0, "texture": SubResource("f%d")}'%f for f in ids)
    anims.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}'%(frames,str(lp).lower(),anim,fps))
   text.append('[resource]\nanimations = ['+', '.join(anims)+']')
   (dest/(name+('_emission' if emission else '')+'.tres')).write_text('\n\n'.join(text)+'\n')
  mirror=ROOT/'game/assets/sprites/characters/averse_cel/variants'/name; mirror.mkdir(parents=True,exist_ok=True)
  for p in dest.iterdir():
   if p.suffix=='.png': shutil.copy2(p,mirror/p.name)
   elif p.suffix=='.tres': (mirror/p.name).write_text(p.read_text().replace('/averse/','/averse_cel/'))
 # Pillow only assembles/resizes rendered images. No drawing.
 thumb=112; sheet=Image.new('RGB',(12*thumb,8*thumb))
 for bi,bg in enumerate(['#0A0D12','#2E3238']):
  for row,name in enumerate(SPECS):
   for nm,f,im in samples:
    if nm!=name: continue
    tile=Image.new('RGBA',(thumb,thumb),bg); im.thumbnail((thumb,thumb),Image.Resampling.LANCZOS); tile.alpha_composite(im,((thumb-im.width)//2,(thumb-im.height)//2)); sheet.paste(tile.convert('RGB'),(f*thumb,(bi*4+row)*thumb))
 sheet.save(ROOT/'art/tools/night/_avsv_contact.png')
 print('AVSV PACK PASS: 28 frames, 4 effects, cel mirrors, emission half-size, no normals')

if __name__=='__main__':
 if '--pack' in sys.argv: pack()
 else: render()

