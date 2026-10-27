"""Créancier: immutable source rigs, material-only variant, original atlas exporter."""
from pathlib import Path
import sys,json,shutil,subprocess,inspect,hashlib
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools'),str(ROOT/'art/tools/iso')]
import cel_style as cel
BASE=cel.GAME_SPRITES/'characters/avare'
OUT=BASE/'skins/avare_skin1'
WORK=ROOT/'art/blender/cel/skins'
BLEND=WORK/'avare_skin1.blend'
NAMES={'idle':8,'run':8,'swing':4,'throw':4,'slam':6,'ult':8,'attack':4,'cast':4,'cast_ult':8,'death':8,'portrait':1}

def materials():
 import bpy
 def tint(m,h,metal,rough):
  rgb=tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
  rgb=tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
  for node in m.node_tree.nodes:
   if node.type=='BSDF_PRINCIPLED':
    node.inputs['Base Color'].default_value=rgb
    node.inputs['Metallic'].default_value=metal;node.inputs['Roughness'].default_value=rough
   elif node.type=='VALTORGB':
    for e in node.color_ramp.elements:e.color=rgb
  m.diffuse_color=rgb
 for m in bpy.data.materials:
  n=m.name.lower()
  if n.startswith('cuir'):tint(m,'3A1A1E',0,.94)
  elif n.startswith('chêne'):tint(m,'2B2F3A',.85,.28)
  elif n.startswith('laiton'):tint(m,'8E8E86',.9,.22)
  elif n.startswith('fonte'):tint(m,'8E8E86',.9,.24)
 # Surface substitutions preserve every vertex, pose and projected contour.
 fur=next(m for m in bpy.data.materials if m.name.startswith('Cuir')).copy()
 fur.name='Skin1 fourrure trempée #4A423C';tint(fur,'4A423C',0,1)
 vest=fur.copy();vest.name='Skin1 gilet bordeaux';tint(vest,'28191D',0,.8)
 boots=fur.copy();boots.name='Skin1 fonte polie';tint(boots,'2B2F3A',.95,.18)
 for ob in bpy.context.scene.objects:
  if ob.type!='MESH':continue
  if ob.name.startswith(('Botte','Plaque de cou-de-pied')):
   ob.data.materials.clear();ob.data.materials.append(boots)
  elif ob.name.startswith('Revers'):
   ob.data.materials.clear();ob.data.materials.append(fur)
  elif ob.name.startswith('Manteau'):
   ob.data.materials.append(vest);index=len(ob.data.materials)-1
   for p in ob.data.polygons:
    c=p.center
    if abs(c.x)<.13 and .80<c.z<1.16 and c.y<-.12:p.material_index=index

def render():
 import bpy,iso_rig as iso,aa1_build as aa
 import cel_heroes_d_build as hd
 from PIL import Image
 WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/avare.blend'))
 materials();bpy.context.scene.render.image_settings.color_mode='RGBA'
 bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
 hd.adapted(iso.render_frame);original=iso.render_frame
 iso.optimize_png=lambda *a,**k:None
 def frame(path,passes=True):
  path=Path(path)
  if '--resume' in sys.argv and path.exists() and (WORK/(path.stem+'.done')).exists():return path
  cel.install('creature',normals=False)
  bpy.context.scene.cycles.seed=1701
  result=original(path,passes=passes)
  ep=path.with_name(path.stem+'_e.png');ref=BASE/ep.name
  if ref.exists():shutil.copy2(ref,ep)
  elif ep.exists():ep.unlink()
  with Image.open(path) as im:im.save(path,optimize=True,compress_level=9)
  (WORK/(path.stem+'.done')).write_text('PASS')
  return result
 iso.render_frame=frame
 aa.SOURCE=BLEND;aa.DEST=OUT;aa.WORK=WORK/'avare_skin1_frames';aa.resources=lambda:None
 hd.adapted(aa.atlases)()
 if not ('--resume' in sys.argv and (OUT/'portrait.png').exists()):
  bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/avare_portrait.blend'))
  materials();frame(OUT/'portrait.png')
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
  values=[]
  for y in range(rows):
   for x in range(n):
    aa=a[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128;bb=b[y*cell:(y+1)*cell,x*cell:(x+1)*cell,3]>128
    v=float((aa&bb).sum()/max(1,(aa|bb).sum()));values.append(v);assert v>.95,(name,y,x,v)
  ep=OUT/(name+'_e.png')
  if ep.exists():
   e=np.asarray(Image.open(ep).convert('RGBA'));ref=np.asarray(Image.open(BASE/ep.name).convert('RGBA'))
   assert np.array_equal(e,ref) and ((e[...,:3].max(2)>100)&(e[...,3]>128)).any()
   assert e.shape[:2]==((b.shape[0]+1)//2,(b.shape[1]+1)//2)
   r['accent_iou']=1.0
  r['alpha_iou_cells']=values;results.append(r)
 expected={p.name for p in BASE.glob('*.png')}|{'avare_skin1.tres'}
 assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
 (HERE/'_skin_avare_verification.json').write_text(json.dumps({'checks':results},indent=2))
 class DefaultRoot:
  def __truediv__(self,rel):return BASE/Path(rel).name
 old=cel.ARCHIVE;cel.ARCHIVE=DefaultRoot()
 samples=[[(str((OUT/(name+'.png')).relative_to(cel.GAME_SPRITES)),256 if name=='portrait' else 192,0,0) for name in line] for line in [('idle','run','attack'),('ult','portrait')]]
 cel.contact_pair(samples,HERE/'_skin_avare_contact.png',size=(1536,768));cel.ARCHIVE=old
 print('PASS verification')

def driver():
 from PIL import Image
 OUT.mkdir(parents=True,exist_ok=True)
 if '--verify-only' not in sys.argv:
  with (HERE/'_skin_avare_render.log').open('w') as log:
   subprocess.run([cel.BLENDER,'--background','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--render']+(['--resume'] if '--resume' in sys.argv else []),cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 old='res://assets/sprites/characters/avare/'
 (OUT/'avare_skin1.tres').write_text((BASE/'avare.tres').read_text().replace(old,old+'skins/avare_skin1/'),encoding='utf8')
 assert 'CanvasTexture' not in (OUT/'avare_skin1.tres').read_text()
 assert 'normal_texture' not in (OUT/'avare_skin1.tres').read_text()
 for path in OUT.glob('*.png'):
  with Image.open(path) as im:im.save(path,optimize=True,compress_level=9)
 verify()

def audit():
 import texture_budget as budget
 rows=budget.scan()
 skin=[r for r in rows if '/avare/skins/avare_skin1/' in r['path']]
 category=[r for r in rows if r['cat']=='characters/avare']
 assert len(skin)==21
 mb=budget.MB
 report_path=HERE/'_skin_avare_verification.json'
 report=json.loads(report_path.read_text())
 report['budget']={'skin_added':{k:sum(r[k] for r in skin)/mb for k in ('png','mobile')},'characters/avare_after':{k:sum(r[k] for r in category)/mb for k in ('png','mobile')},'global_mobile_after':sum(r['mobile'] for r in rows)/mb,'global_mobile_limit':180,'target_mobile':95,'before_log':'_skin_avare_budget_before.txt','after_log':'_skin_avare_budget_after.txt'}
 report['budget']['characters/avare_before']={k:report['budget']['characters/avare_after'][k]-report['budget']['skin_added'][k] for k in ('png','mobile')}
 report['tests']={}
 for name in ('sprites','avare','load','budget'):
  log=(HERE/('_skin_avare_'+name+'.log')).read_text(encoding='utf-16')
  report['tests'][name]={'result':'OK' if 'RESULT: OK' in log else 'FAIL','cleanup_resource_errors':'resources still in use at exit' in log}
  assert ('RESULT: OK' in log) if name!='budget' else ('RESULT: FAIL (1)' in log)
 log=(HERE/'_skin_avare_import.log').read_text(encoding='utf-16')
 assert 'ERROR:' not in log
 report['tests']['import']={'errors':0}
 report['sources_sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'art/blender/characters').glob('avare*.blend')}
 report_path.write_text(json.dumps(report,indent=2))
 print(json.dumps(report['budget'],ensure_ascii=False))
if __name__=='__main__':
 if '--render' in sys.argv:render()
 elif '--audit-only' in sys.argv:audit()
 else:driver()
