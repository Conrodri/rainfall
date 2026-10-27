"""Scorie: system driver and Blender -- --render. Original geometry/exporters retained."""
from pathlib import Path
import sys,json,subprocess,shutil,inspect,textwrap,hashlib
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
import cel_style as cel
import cs1_build as cs
BASE=cel.GAME_SPRITES/'characters/ardent'; OUT=BASE/'skins/ardent_skin1'
WORK=ROOT/'art/blender/cel/skins'; RAW=WORK/'ardent_skin1_frames'
NAMES={'idle':8,'run':8,'attack':5,'cast':6,'cast_ult':8,'portrait':1}

def materials():
 import bpy
 def linear(h):
  rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
  return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
 mapping={'Frayed rain cloak woven umber':('1F1C1C',.17,.25),'Oiled charcoal leather':('1F1C1C',.2,.3),'Patinated bronze plates':('2E2A33',.18,.55),'Black forged iron':('2B2A29',.3,.8),'Charred torch haft':('2B2A29',.3,.8),'Deep hood interior':('2B2A29',.35,.75),'Worn brass edges and rivets':('A8946E',.5,.7)}
 for m in bpy.data.materials:
  if m.name not in mapping or not m.use_nodes:continue
  h,r,metal=mapping[m.name]; b=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if not b:continue
  col=linear(h); b.inputs['Base Color'].default_value=col;b.inputs['Roughness'].default_value=r;b.inputs['Metallic'].default_value=metal
  for n in m.node_tree.nodes:
   if n.type=='VALTORGB':
    for e in n.color_ramp.elements:e.color=col
 # Existing cloak faces become ash; no volume or silhouette changes.
 cloak=bpy.data.materials.get('Frayed rain cloak woven umber')
 if cloak:
  ash=cloak.copy();ash.name='Scorie ash hem'
  for n in ash.node_tree.nodes:
   if n.type=='BSDF_PRINCIPLED':n.inputs['Base Color'].default_value=linear('6E6963');n.inputs['Roughness'].default_value=.85
   if n.type=='VALTORGB':
    for e in n.color_ramp.elements:e.color=linear('6E6963')
  for o in bpy.context.scene.objects:
   if o.type!='MESH' or cloak not in list(o.data.materials):continue
   idx=list(o.data.materials).index(cloak);zs=[v.co.z for v in o.data.vertices]
   cutoff=min(zs)+.24*(max(zs)-min(zs));o.data.materials.append(ash);ai=len(o.data.materials)-1
   for p in o.data.polygons:
    if p.material_index==idx and sum(o.data.vertices[v].co.z for v in p.vertices)/len(p.vertices)<cutoff:p.material_index=ai

def render():
 import bpy,iso_rig as iso
 from PIL import Image
 import cel_heroes_a_build as legacy,p1_build as p1
 WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
 bpy.context.preferences.filepaths.save_version=0
 src=textwrap.dedent(inspect.getsource(iso.render_frame)).replace("for suffix in ('_n','_e'):","for suffix in ('_e',):")
 exec(compile(src,inspect.getsourcefile(iso.render_frame),'exec'),iso.__dict__)
 iso.optimize_png=lambda *a,**k:None
 original=iso.render_frame
 for source,anims in cs.SPECS['ardent']['sources']:
  bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender'/source));materials();cel.install('creature',normals=False)
  bpy.ops.wm.save_as_mainfile(filepath=str(WORK/('ardent_skin1.blend' if 'iso' in source else 'ardent_skin1_actions.blend')))
  s=bpy.context.scene;root=bpy.data.objects['Ardent_Root']
  for anim,(start,count) in anims.items():
   if '--resume' in sys.argv and (OUT/(anim+'.png')).exists():continue
   sheet=Image.new('RGBA',(count*192,1536))
   for row,d in enumerate(cs.DIRS):
    root.rotation_euler.z=iso.DIRECTIONS[d]
    for i in range(count):
     s.frame_set(start+i);p=RAW/anim/f'{d}_{i:02}.png'
     if not ('--resume' in sys.argv and p.exists()):original(p)
     with Image.open(p) as im:sheet.paste(im,(i*192,row*192))
   sheet.save(OUT/(anim+'.png'),optimize=True,compress_level=9)
   shutil.copy2(BASE/(anim+'_e.png'),OUT/(anim+'_e.png'))
   print('PASS sheet '+anim,flush=True)
 if not ('--resume' in sys.argv and (OUT/'portrait.png').exists()):
  def portrait_frame(path,passes=True):
   materials();cel.install('creature',normals=False);return original(path,passes)
  iso.render_frame=portrait_frame;p1.OUT=OUT;legacy.adapt(p1.build,trim=True)()
  shutil.copy2(BASE/'portrait_e.png',OUT/'portrait_e.png')
 print('PASS render',flush=True)

def verify():
 import numpy as np
 from PIL import Image
 results=[]
 for name,n in NAMES.items():
  cell=256 if name=='portrait' else 192;rows=1 if name=='portrait' else 8
  rel=(OUT/(name+'.png')).relative_to(cel.GAME_SPRITES).as_posix()
  r=cel.check_sheet(rel,cell=cell,frames=n,rows=rows,normals=False)
  a=np.asarray(Image.open(BASE/(name+'.png')).convert('RGBA'));b=np.asarray(Image.open(OUT/(name+'.png')).convert('RGBA'))
  assert a.shape==b.shape
  vals=[]
  for y in range(rows):
   for x in range(n):
    aa=a[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128;bb=b[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128
    v=float((aa&bb).sum()/max(1,(aa|bb).sum()));vals.append(v);assert v>.95,(name,y,x,v)
  e=np.asarray(Image.open(OUT/(name+'_e.png')).convert('RGBA'));ref=np.asarray(Image.open(BASE/(name+'_e.png')).convert('RGBA'))
  assert np.array_equal(e,ref) and (e[...,:3].max(2)*e[...,3].astype(float)/255).max()>2
  assert e.shape[:2]==((b.shape[0]+1)//2,(b.shape[1]+1)//2)
  r.update(alpha_iou_cells=vals,accent_iou=1.0);results.append(r)
 (HERE/'_skin_ardent_verification.json').write_text(json.dumps({'checks':results,'emission':'Original approved masks retained verbatim; radiance and coverage unchanged.'},indent=2))
 # contact_pair uses separate roots; map left side to default via a tiny path adapter.
 class DefaultRoot:
  def __truediv__(self,rel):return BASE/Path(rel).name
 old=cel.ARCHIVE;cel.ARCHIVE=DefaultRoot()
 samples=[[(str((OUT/(name+'.png')).relative_to(cel.GAME_SPRITES)),256 if name=='portrait' else 192,0,0) for name in line] for line in [('idle','run','attack'),('cast_ult','portrait')]]
 cel.contact_pair(samples,HERE/'_skin_ardent_contact.png',size=(1536,768));cel.ARCHIVE=old
 expected={name+s+'.png' for name in NAMES for s in ('','_e')}|{'ardent_skin1.tres'}
 assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
 print('PASS verification',flush=True)

def driver():
 OUT.mkdir(parents=True,exist_ok=True)
 if '--verify-only' not in sys.argv:
  with (HERE/'_skin_ardent_render.log').open('w') as log:
   subprocess.run([cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+(['--resume'] if '--resume' in sys.argv else []),cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 text=(BASE/'ardent.tres').read_text();old='res://assets/sprites/characters/ardent/'
 (OUT/'ardent_skin1.tres').write_text(text.replace(old,old+'skins/ardent_skin1/'),encoding='utf-8')
 verify()
if __name__=='__main__':
 if '--render' in sys.argv:render()
 else:driver()
