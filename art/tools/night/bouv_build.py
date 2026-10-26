"""BOUV: deterministic Blender cel VFX; python bouv_build.py builds and verifies."""
from pathlib import Path
import sys, math, json, subprocess
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/characters/bourbe/variants'
WORK=ROOT/'art/blender/bouv'
SPECS={'mud_glob':(48,48,4,True,4/.45),'mud_burst':(448,448,6,False,6/.35),'bourbe_shield':(256,320,8,True,8.0)}

def build():
 import bpy
 from mathutils import Vector
 sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
 import iso_rig as rig
 import cel_style as cel
 from PIL import Image
 for name,(w,h,n,loop,speed) in SPECS.items():
  for f in range(n):
   scene=rig.create_rig('TOP' if name=='mud_burst' else 'CREA',(w,h))
   scene.camera.data.ortho_scale=w/128
   basis=scene.camera.rotation_euler.to_matrix()
   def pos(x,y,z=0): return basis@Vector((x,y,z))
   mud=rig.material('Argile vert de gris',(0.116,0.275,0.216),roughness=.24)
   dark=rig.material('Creux bleu ardoise',(.024,.033,.051),roughness=.6)
   light=rig.material('Argile bronze claire',(.25,.39,.31),roughness=.28)
   glow=rig.material('Follet jade unique',(.266,.708,.392),emission=1.6)
   def ball(label,x,y,z,r,mat,scale=(1,1,1)):
    ob=rig.common.sphere(label,pos(x,y,z),tuple(r*v for v in scale),mat)
    ob.rotation_euler=scene.camera.rotation_euler
    return ob
   def tube(label,points,r,mat):
    return rig.common.tube(label,[pos(*p) for p in points],r,mat)
   t=f/n; phase=2*math.pi*t
   if name=='mud_glob':
    ball('Masse humide',0,0,0,.119,mud)
    for k in range(7):
     a=k*2.399+phase
     x=.082*math.cos(a); y=.082*math.sin(a)
     ball('Bourrelet tournant',x,y,.058+.008*math.sin(a),.032,light if k%3==0 else mud, (1,.7,.65))
    a=phase
    tube('Fissure follet',[(.055*math.cos(a+j*.22),.05*math.sin(a+j*.22),.12) for j in range(7)],.010,glow)
    ball('Goutte detachee',-.15-.009*math.sin(phase),-.048,.0,.018,mud,(1.4,.7,.7))
    ball('Trace courte',-.126,-.036,.015,.009,light)
   elif name=='mud_burst':
    # TOP: radius maximum 1.5 u (192 px), aspect 1. No ground or baked flattening.
    if f<5:
     r=[.33,.85,1.30,1.44,1.10][f]
     for k in range(17):
      a=2*math.pi*k/17
      rr=r*(.82+.14*math.sin(k*4.1))
      points=[]
      for j in range(5):
       q=j/4; rad=rr*(.45+.55*q)
       points.append((rad*math.cos(a+.09*q),rad*math.sin(a+.09*q),.08+(.22 if f<3 else .06)*math.sin(q*math.pi)))
      if f<3:
       verts=[]
       for j,(x,y,z) in enumerate(points):
        half=(.16*(1-j/5)**1.4+.018)*(1-.12*f)
        verts.extend([tuple(pos(x-half*math.sin(a),y+half*math.cos(a),z)),tuple(pos(x+half*math.sin(a),y-half*math.cos(a),z))])
       mesh=bpy.data.meshes.new('Langue argile etiree')
       mesh.from_pydata(verts,[],[(j*2,j*2+1,j*2+3,j*2+2) for j in range(4)])
       ob=bpy.data.objects.new('Gerbe membrane epaisse',mesh); scene.collection.objects.link(ob); mesh.materials.append(mud)
       tube('Crete de vase',points,.025*(1-.12*f),light)
      ball('Grumeau retombant',rr*math.cos(a),rr*math.sin(a),.13,.060 if f<3 else .044,light if k%4==0 else mud,(1,.72,1))
      if f>0:
       ball('Eclaboussure',min(1.46,rr+.16)*math.cos(a+.10),min(1.46,rr+.16)*math.sin(a+.10),.02,.024,mud)
     if f<3:
      tube('Couronne brisee',[(r*.53*math.cos(k*.12),r*.53*math.sin(k*.12),.03) for k in range(49)],.085,mud)
    if f<5:
     a=.4+f*.42
     tube('Follet libere',[(.10*math.cos(a+j*.2),.10*math.sin(a+j*.2)-f*.08,.36) for j in range(8)],.021,glow)
    else:
     tube('Fil vers corps centre bas',[(.06*math.sin(j*.6)*(1-j/17),-.25-j*.068,.05) for j in range(17)],.010,glow)
     ball('Derniere braise',0,-1.35,.05,.018,glow)
   else:
    # Hollow open shell: only irregular peripheral bands, transparent centre.
    for band in range(3):
     pts=[]
     for k in range(97):
      a=2*math.pi*k/96
      ripple=1+.018*math.sin(a*7-phase)+.012*math.sin(a*11+phase)
      x=(.60-band*.026)*math.cos(a)*ripple
      y=(.80-band*.027)*math.sin(a)*ripple
      pts.append((x,y,.015*band))
     tube('Coque vase ondulee',pts,.030 if band==0 else .032,mud if band!=1 else light)
    pts=[((.608+.006*math.sin(k*.39+phase))*math.cos(k*2*math.pi/96),(.808+.008*math.sin(k*.51-phase))*math.sin(k*2*math.pi/96),.05) for k in range(97)]
    tube('Contour jade',pts,.008,glow)
    for k in range(9):
     q=(k/9+t*.35)%1; y=-.67+1.34*q
     x=(1 if k%2 else -1)*.60*math.sqrt(max(.04,1-(y/.8)**2))
     ball('Bulle montante',x,y,.08,.014+.008*(k%3),glow if k%3==0 else light)
   cel.install('vfx',normals=False)
   folder=WORK/name; folder.mkdir(parents=True,exist_ok=True)
   path=folder/('%02d.png'%f)
   rig.common.configure_passes(path)
   scene.render.filepath=str(path)
   bpy.ops.render.render(write_still=True)
   for suffix in ('','_e'):
    src=path if not suffix else next(folder.glob(path.stem+'_e__*.png'))
    with Image.open(src) as im: im.convert('RGBA').resize((w,h),Image.Resampling.LANCZOS).save(folder/('%02d%s.png'%(f,suffix)),compress_level=9)
    if src!=path and suffix: src.unlink()
   cel.uninstall()
 print('PASS render 18 frames',flush=True)

def assemble():
 from PIL import Image
 import numpy as np
 sys.path.insert(0,str(ROOT/'art/tools/cel'))
 import cel_style as cel
 rows=[]
 for name,(w,h,n,loop,speed) in SPECS.items():
  dest=OUT/name; dest.mkdir(parents=True,exist_ok=True)
  for suffix in ('','_e'):
   sheet=Image.new('RGBA',(w*n,h))
   for f in range(n):
    with Image.open(WORK/name/('%02d%s.png'%(f,suffix))) as im: sheet.paste(im,(w*f,0))
   if suffix:
    sheet=sheet.resize(((sheet.width+1)//2,(sheet.height+1)//2),Image.Resampling.LANCZOS)
    a=np.asarray(sheet); assert (a[:,:,:3].max(2)* (a[:,:,3]/255)).max()>2
   sheet.save(dest/(name+suffix+'.png'),compress_level=9)
  text=['[gd_resource type="SpriteFrames" load_steps=%d format=3]'%(n+2),'','[ext_resource type="Texture2D" path="res://assets/sprites/characters/bourbe/variants/%s/%s.png" id="d0"]'%(name,name),'']
  for f in range(n):
   text+=['[sub_resource type="AtlasTexture" id="f%d"]'%f,'atlas = ExtResource("d0")','region = Rect2(%d, 0, %d, %d)'%(f*w,w,h),'']
  frames=', '.join('{"duration": 1.0, "texture": SubResource("f%d")}'%f for f in range(n))
  text+=['[resource]','animations = [{"frames": [%s], "loop": %s, "name": &"default", "speed": %.8f}]'%(frames,str(loop).lower(),speed)]
  (dest/(name+'.tres')).write_text('\n'.join(text)+'\n',encoding='utf-8')
  cel.check_sheet('characters/bourbe/variants/%s/%s.png'%(name,name),cell=(w,h),frames=n,rows=1,normals=False)
  assert not list(dest.glob('*_n.png'))
  for bg in ('#0A0D12','#2E3238'):
   row=Image.new('RGBA',(1344,176),bg)
   for f in range(n):
    with Image.open(WORK/name/('%02d.png'%f)) as im:
     im.thumbnail((164,164),Image.Resampling.LANCZOS)
     row.alpha_composite(im,(f*168+(168-im.width)//2,(176-im.height)//2))
   rows.append(row)
 contact=Image.new('RGB',(1344,176*len(rows)))
 for i,row in enumerate(rows):contact.paste(row,(0,176*i))
 contact.save(HERE/'_bouv_contact.png')
 print('PASS atlases, emission half-size, frames, no normals; contact',flush=True)

if __name__=='__main__':
 if '--render' in sys.argv: build()
 elif '--assemble' in sys.argv: assemble()
 else:
  WORK.mkdir(parents=True,exist_ok=True)
  with (WORK/'render.log').open('w') as log:
   result=subprocess.run([r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe','--background','--python',str(Path(__file__).resolve()),'--','--render'],stdout=log,stderr=subprocess.STDOUT)
  assert result.returncode==0,'FAIL art/blender/bouv/render.log'
  assemble()
