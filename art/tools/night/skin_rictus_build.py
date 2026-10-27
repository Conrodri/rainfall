"""Gala noir: original Rictus exporters, isolated material substitutions, --resume."""
from pathlib import Path
import sys,json,subprocess,shutil,inspect,textwrap,hashlib
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
import cel_style as cel
sys.path.insert(0,str(ROOT/'art/tools/characters'))
BASE=cel.GAME_SPRITES/'characters/rictus'; OUT=BASE/'skins/rictus_skin1'
WORK=ROOT/'art/blender/cel/skins'; RAW=WORK/'rictus_skin1_frames'
NAMES={'idle':8,'run':8,'slash':4,'throw':4,'spin':8,'stagger':3,'summon':6,'lift':3,'death':6,'throw_ult':6,'portrait':1}

def materials():
 import bpy,math
 def linear(h):
  rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
  return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
 def color(m,h,r=.5,metal=0):
  if not m.use_nodes:return
  b=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if not b:return
  for link in list(b.inputs['Base Color'].links):m.node_tree.links.remove(link)
  b.inputs['Base Color'].default_value=linear(h);b.inputs['Roughness'].default_value=r;b.inputs['Metallic'].default_value=metal
  for n in m.node_tree.nodes:
   if n.type=='VALTORGB':
    for e in n.color_ramp.elements:e.color=linear(h)
 # Dagger surfaces retain approved wood/iron and their original radiance.
 for o in bpy.context.scene.objects:
  anc=o
  while anc and not anc.name.startswith('Dagger_'):anc=anc.parent
  if anc:
   for slot in o.material_slots:
    if slot.material:
     slot.material=slot.material.copy();slot.material.name='Gala unchanged dagger '+slot.material.name
 mapping={'Black brown cracked varnished timber':('141214',.12,0),'Dirty ivory porcelain D9CFC4':('E6E0D8',.24,0),'Hand painted cracked chalk, charcoal and blood red':('E6E0D8',.24,0),'Oxidised silent lead bells':('8E8E86',.27,.8),'Water stained linen ruff':('8E8E86',.66,.15),'Old sackcloth patches':('2A1E2C',.82,0),'Rain dissolved charcoal brows':('E6E0D8',.24,0),'Flaking dried blood red nose pigment':('E6E0D8',.24,0),'Rain soaked green flax hair':('141214',.22,0)}
 for m in list(bpy.data.materials):
  if m.name.startswith('Gala unchanged dagger'):continue
  key=next((k for k in mapping if m.name.startswith(k)),None)
  if key:color(m,*mapping[key])
  elif 'cloth' in m.name.lower() or 'harlequin' in m.name.lower() or 'motley' in m.name.lower():color(m,'2A1E2C',.88)
 for o in bpy.context.scene.objects:
  if o.type!='MESH':continue
  if o.name.startswith('Small collapsed soaked fool cap'):
   for slot in o.material_slots:
    slot.material=slot.material.copy();color(slot.material,'141214',.88)
  if o.name.startswith('Fissured porcelain face'):
   base=o.data.materials[0]
   red=base.copy();red.name='Gala dark red smile';color(red,'7A2A28',.35)
   gold=base.copy();gold.name='Gala tarnished gold forehead repair';color(gold,'8A7342',.3,.7)
   o.data.materials.append(red);ri=len(o.data.materials)-1
   o.data.materials.append(gold);gi=len(o.data.materials)-1
   for p in o.data.polygons:
    x,y,z=p.center
    if abs(x)<.080 and abs(z-(-.062+.037*(abs(x)/.078)**1.7))<.010:p.material_index=ri
    elif z>.045 and abs(x-(.004+.011*math.sin(z*69)))<.004:p.material_index=gi

def render():
 import bpy,iso_rig as iso,m2_build as m2,m3_build as m3,random
 random.seed(271026)
 WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True);RAW.mkdir(parents=True,exist_ok=True)
 bpy.context.preferences.filepaths.save_version=0
 src=textwrap.dedent(inspect.getsource(iso.render_frame)).replace("for suffix in ('_n','_e'):","for suffix in ('_e',):")
 exec(compile(src,inspect.getsourcefile(iso.render_frame),'exec'),iso.__dict__)
 iso.optimize_png=lambda *a,**k:None
 original=iso.render_frame
 def frame(path,passes=True):
  path=Path(path)
  if '--resume' in sys.argv and path.exists():return path
  cel.install('creature',normals=False)
  bpy.context.scene.eevee.taa_render_samples=8
  return original(path,passes=passes)
 iso.render_frame=frame
 m2.OUT=RAW;m2.DEST=OUT.parent;m2.resources=lambda *a:None
 # Imported exporter, retaining projection, poses, direction order and cell assembly.
 import importlib
 importlib.reload(m2);m2.OUT=RAW;m2.DEST=OUT.parent;m2.resources=lambda *a:None
 src=textwrap.dedent(inspect.getsource(m2.build))
 src=src[:src.index("    if actor=='rictus':\n        for direction,view")]
 src=src.replace("bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene","bpy.ops.wm.open_mainfile(filepath=str(source));skin_materials();s=bpy.context.scene")
 src=src.replace("filepath=str(ROOT/'art/blender/characters'/(actor+'.blend'))","filepath=str(SKIN_BLEND)")
 src=src.replace("for suffix in ('','_n','_e'):","for suffix in ('',):")
 src=src.replace("dest=DEST/actor;","dest=SKIN_OUT;")
 src=src.replace('optimize=True)', 'optimize=True,compress_level=9)')
 m2.skin_materials=materials;m2.SKIN_BLEND=WORK/'rictus_skin1.blend';m2.SKIN_OUT=OUT
 exec(compile(src,inspect.getsourcefile(m2.build),'exec'),m2.__dict__)
 m2.build('rictus')
 for name in NAMES:
  if name!='portrait':shutil.copy2(BASE/(name+'_e.png'),OUT/(name+'_e.png'))
 if not ('--resume' in sys.argv and (OUT/'portrait.png').exists()):
  src=textwrap.dedent(inspect.getsource(m3.portrait))
  src=src[:src.index("    dest=ROOT/")]
  src=src.replace("bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/rictus.blend'))","bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/rictus.blend'));skin_materials()")
  m3.skin_materials=materials;m3.OUT=OUT
  exec(compile(src,inspect.getsourcefile(m3.portrait),'exec'),m3.__dict__);m3.portrait()
 for p in OUT.glob('*_e.png'):
  if p.stem=='portrait_e':p.unlink()
 print('PASS render',flush=True)

def verify():
 import numpy as np
 from PIL import Image
 results=[]
 for name,n in NAMES.items():
  cell=256 if name=='portrait' else 192;rows=1 if name in ('portrait','spin') else 8
  rel=(OUT/(name+'.png')).relative_to(cel.GAME_SPRITES).as_posix()
  r=cel.check_sheet(rel,cell=cell,frames=n,rows=rows,normals=False)
  a=np.asarray(Image.open(ROOT/'game/assets/sprites/ui/portraits/rictus.png' if name=='portrait' else BASE/(name+'.png')).convert('RGBA'));b=np.asarray(Image.open(OUT/(name+'.png')).convert('RGBA'))
  assert a.shape==b.shape
  vals=[]
  for y in range(rows):
   for x in range(n):
    aa=a[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128;bb=b[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128
    v=float((aa&bb).sum()/max(1,(aa|bb).sum()));vals.append(v);assert v>.95,(name,y,x,v)
  if name!='portrait':
   e=np.asarray(Image.open(OUT/(name+'_e.png')).convert('RGBA'));ref=np.asarray(Image.open(BASE/(name+'_e.png')).convert('RGBA'))
   assert np.array_equal(e,ref) and (e[...,:3].max(2)*e[...,3].astype(float)/255).max()>2
   assert e.shape[:2]==((b.shape[0]+1)//2,(b.shape[1]+1)//2)
   r.update(accent_iou=1.0,accent_iou_cells=[1.0]*(rows*n))
  r.update(alpha_iou_cells=vals);results.append(r)
 (HERE/'_skin_rictus_verification.json').write_text(json.dumps({'checks':results,'emission':'Original approved masks retained verbatim; radiance and coverage unchanged.','alpha_threshold':128,'alpha_required':0.95,'accent_required':0.90,'seed':271026},indent=2))
 # contact_pair uses separate roots; map left side to default via a tiny path adapter.
 class DefaultRoot:
  def __truediv__(self,rel):return ROOT/'game/assets/sprites/ui/portraits/rictus.png' if Path(rel).name=='portrait.png' else BASE/Path(rel).name
 old=cel.ARCHIVE;cel.ARCHIVE=DefaultRoot()
 samples=[[(str((OUT/(name+'.png')).relative_to(cel.GAME_SPRITES)),256 if name=='portrait' else 192,{'run':3,'slash':2,'throw_ult':3}.get(name,0),0 if name=='portrait' else 2) for name in line] for line in [('idle','run','slash'),('throw_ult','portrait')]]
 cel.contact_pair(samples,HERE/'_skin_rictus_contact.png',size=(1536,768));cel.ARCHIVE=old
 expected={name+s+'.png' for name in NAMES for s in (('',) if name=='portrait' else ('','_e'))}|{'rictus_skin1.tres'}
 assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
 print('PASS verification',flush=True)

def driver():
 OUT.mkdir(parents=True,exist_ok=True)
 if '--verify-only' not in sys.argv:
  with (HERE/'_skin_rictus_render.log').open('w') as log:
   subprocess.run([cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+(['--resume'] if '--resume' in sys.argv else []),cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 text=(BASE/'rictus.tres').read_text();old='res://assets/sprites/characters/rictus/'
 (OUT/'rictus_skin1.tres').write_text(text.replace(old,old+'skins/rictus_skin1/'),encoding='utf-8')
 verify()
if __name__=='__main__':
 if '--render' in sys.argv:render()
 else:driver()
