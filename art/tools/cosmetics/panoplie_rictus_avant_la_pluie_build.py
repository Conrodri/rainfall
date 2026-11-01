"""Premiere: original Rictus exporters, surface substitutions, no normals."""
from pathlib import Path
import sys,json,subprocess,shutil,inspect,textwrap,hashlib,re,zlib
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/night'),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools')]
import cel_style as cel
# Clean theme: middle cel tone stays above L*=45 without changing source hex hues.
cel.SHADOW_FLOOR_LUMA=.15
sys.path.insert(0,str(ROOT/'art/tools/characters'))
BASE=cel.GAME_SPRITES/'characters/rictus'; OUT=BASE/'skins/rictus_avant_la_pluie'
WORK=ROOT/'art/blender/cel/skins'; RAW=WORK/'rictus_avant_la_pluie_frames'
NAMES={'catch':4,'idle':8,'run':8,'slash':4,'throw':4,'spin':8,'stagger':3,'summon':6,'lift':3,'death':6,'throw_ult':6,'portrait':1}

def materials():
 import bpy,math
 if bpy.context.scene.get('Premiere_materials'):return
 def linear(h):
  rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
  return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
 def color(m,h,r=.5,metal=0):
  if not m.use_nodes:return
  b=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if not b:return
  for key in ('Base Color','Roughness','Normal'):
   for link in list(b.inputs[key].links):m.node_tree.links.remove(link)
  b.inputs['Base Color'].default_value=linear(h);b.inputs['Roughness'].default_value=r;b.inputs['Metallic'].default_value=metal
  for n in m.node_tree.nodes:
   if n.type=='VALTORGB':
    for e in n.color_ramp.elements:e.color=linear(h)
 mapping={'Dirty ivory porcelain D9CFC4':('D6D0C4',.2,0),'Hand painted cracked chalk, charcoal and blood red':('D6D0C4',.2,0),'Oxidised silent lead bells':('D9D4C7',.25,.15),'Water stained linen ruff':('B8AE9A',.85,0),'Old sackcloth patches':('2E4A3A',.92,0),'Rain dissolved charcoal brows':('36302D',.7,0),'Flaking dried blood red nose pigment':('9A6E6A',.5,0),'Rain soaked green flax hair':('50473C',.42,0),'Soaked faded diamond motley 4A5565 7A3B24':('2E4A3A',.92,0)}
 for m in list(bpy.data.materials):
  key=next((k for k in mapping if m.name.startswith(k)),None)
  if key:color(m,*mapping[key])
 def surface(o,h,r=.5,metal=0):
  for slot in o.material_slots:
   if slot.material:
    slot.material=slot.material.copy();slot.material.name='Premiere '+o.name;color(slot.material,h,r,metal)
 for o in bpy.context.scene.objects:
  if o.type not in {'MESH','CURVE'}:continue
  name=o.name.lower()
  if 'forehead to jaw fracture' in name or 'branching porcelain fracture' in name:o.hide_render=True
  if name.startswith('wood dagger handle') or name.startswith('handle wire wrap'):surface(o,'D9D4C7',.22,.12)
  if name.startswith('angular wooden dagger blade') or name.startswith('ferrule and forged dagger edge') or name.startswith('black iron quillon'):surface(o,'A9B4B2',.2,.75)
  if name.startswith('thigh articulated'):surface(o,'6A6B70',.32)
  if name.startswith('shin articulated'):surface(o,'D6D0C4',.8)
  if name.startswith('uneven patch stitches') or 'string' in name or 'thread' in name:surface(o,'C9BE9C',.8)
  if name.startswith('dull lead fastening'):surface(o,'D9D4C7',.25,.12)
  if name.startswith('sodden torn coat lapel'):surface(o,'B8AE9A',.85)
  if name.startswith('small collapsed soaked fool cap'):
   surface(o,'50473C',.42)
   ribbon=o.data.materials[0].copy();ribbon.name='Premiere velvet hair ribbon 2E4A3A';color(ribbon,'2E4A3A',.92)
   o.data.materials.append(ribbon);ri=len(o.data.materials)-1
   low=min(v.co.z for v in o.data.vertices);high=max(v.co.z for v in o.data.vertices)
   for poly in o.data.polygons:
    if low+(high-low)*.30<poly.center.z<low+(high-low)*.72:poly.material_index=ri
   o['Premiere_surface']='Velvet hair ribbon, retained approved silhouette'
  if name.startswith('collapsed pleated ruff'):o['Premiere_surface']='Pressed linen jabot, same collar envelope'
  if name.startswith('clinging wet green flax strand'):
   for poly in o.data.polygons:poly.use_smooth=True
  if name.startswith('fissured porcelain face'):
   for poly in o.data.polygons:poly.use_smooth=True
   base=o.data.materials[0];cheek=base.copy();cheek.name='Premiere painted cheeks 9A6E6A';color(cheek,'9A6E6A',.4)
   o.data.materials.append(cheek);ci=len(o.data.materials)-1
   for poly in o.data.polygons:
    x,y,z=poly.center
    if False and ((abs(x)-.062)/.032)**2+((z+.025)/.038)**2<1:poly.material_index=ci # joues retirées (correction 01/11/2026)
 bpy.context.scene['Premiere_materials']=True

def render():
 import bpy,iso_rig as iso,m2_build as m2,m3_build as m3,random
 random.seed(271026)
 WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True);RAW.mkdir(parents=True,exist_ok=True)
 bpy.context.preferences.filepaths.save_version=0
 src=textwrap.dedent(inspect.getsource(iso.render_frame));src=src.replace("(('_e',) if not passes else ('_n','_e'))","('_e',)").replace("('_n','_e')","('_e',)")
 exec(compile(src,inspect.getsourcefile(iso.render_frame),'exec'),iso.__dict__)
 iso.optimize_png=lambda *a,**k:None
 original=iso.render_frame
 def frame(path,passes=True):
  path=Path(path)
  if '--resume' in sys.argv and path.exists():return path
  cel.install('creature',normals=False)
  bpy.context.scene.eevee.taa_render_samples=8
  result=original(path,passes=passes)
  if not getattr(frame,'reported',False):
   tones={}
   for m in bpy.data.materials:
    if not m.use_nodes:continue
    ramp=m.node_tree.nodes.get('CEL tones')
    if ramp:
     rgb=ramp.color_ramp.elements[1].color[:3];y=sum(c*w for c,w in zip(rgb,(.2126,.7152,.0722)));tones[m.name]=116*y**(1/3)-16
   (RAW/'material_middle_lstar.json').write_text(json.dumps(tones,indent=2));frame.reported=True
  return result
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
 m2.skin_materials=materials;m2.SKIN_BLEND=WORK/'rictus_avant_la_pluie.blend';m2.SKIN_OUT=OUT
 exec(compile(src,inspect.getsourcefile(m2.build),'exec'),m2.__dict__)
 m2.ACTION_F60={}
 m2.build('rictus')
 # Catch uses the existing fitted catch exporter, including its spectral echoes.
 if '--pilot' not in sys.argv:
  catch_source=(ROOT/'art/tools/feel/feel2_catch_build.py').read_text().split("anims=['catch']")[0]
  catch_source=catch_source.replace("WORK=ROOT/'art/blender/feel2/rv2_catch'","WORK=SKIN_RAW/'catch'")
  catch_source=catch_source.replace("DEST=ROOT/'game/assets/sprites/characters/rictus'","DEST=SKIN_OUT")
  catch_source=catch_source.replace("source=WORK/'rictus.blend'","source=SKIN_BLEND")
  catch_source=catch_source.replace("if not source.exists():shutil.copy2(ROOT/'art/blender/characters/rictus.blend',source)",'')
  catch_source=catch_source.replace("Image.open(DEST/'idle.png')","Image.open(DEFAULT_BASE/'idle.png')")
  spec=importlib.util.spec_from_file_location('premiere_feel_m2',ROOT/'art/tools/feel/m2_build.py');feel=importlib.util.module_from_spec(spec);spec.loader.exec_module(feel)
  sys.modules['m2_build']=feel
  ns={'__file__':str(ROOT/'art/tools/feel/feel2_catch_build.py'),'SKIN_RAW':RAW,'SKIN_OUT':OUT,'SKIN_BLEND':WORK/'rictus_avant_la_pluie.blend','DEFAULT_BASE':BASE}
  exec(compile(catch_source,'premiere_catch','exec'),ns)
  from PIL import Image
  sheet=Image.new('RGBA',(768,1536))
  for row,d in enumerate(feel.DIRS):
   for f in range(4):
    p=ns['render_one']('catch',d,f)
    with Image.open(p) as im:sheet.paste(im,(f*192,row*192))
  sheet.save(OUT/'catch.png',compress_level=9)
  ns['clear']();sys.modules['m2_build']=m2
 for name in NAMES:
  if name!='portrait':shutil.copy2(BASE/(name+'_e.png'),OUT/(name+'_e.png'))
 if not ('--resume' in sys.argv and (OUT/'portrait.png').exists()):
  src=textwrap.dedent(inspect.getsource(m3.portrait))
  src=src[:src.index("    dest=ROOT/")]
  src=src.replace("bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/rictus.blend'))","bpy.ops.wm.open_mainfile(filepath=str(SKIN_BLEND))");m3.SKIN_BLEND=WORK/'rictus_avant_la_pluie.blend'
  m3.skin_materials=materials;m3.OUT=OUT
  exec(compile(src,inspect.getsourcefile(m3.portrait),'exec'),m3.__dict__);m3.portrait()
 for p in OUT.glob('*_e.png'):
  if p.stem=='portrait_e':p.unlink()
 print('PASS render',flush=True)

def verify():
 import numpy as np
 from PIL import Image
 results=[]
 assert min(json.loads((RAW/'material_middle_lstar.json').read_text()).values())>=45
 import texture_budget as budget
 mobile_estimate=0
 for p in OUT.glob('*.png'):
  ref=ROOT/'game/assets/sprites/ui/portraits/rictus.png' if p.stem=='portrait' else BASE/p.name
  imp=budget.read_import(str(ref)+'.import');mobile=0
  for dest in imp['dest']:
   if '.s3tc.' in dest or '.bptc.' in dest:continue
   if '.etc2.' in dest and any('.astc.' in v for v in imp['dest']):continue
   cache=ROOT/'game'/dest.replace('res://','')
   if cache.exists():mobile+=budget.deflated(str(cache)) if int(imp['params'].get('compress/mode','0'))==2 else cache.stat().st_size
  with Image.open(p) as im:new_size=len(zlib.compress(im.convert('RGBA').tobytes(),9))
  with Image.open(ref) as im:ref_size=len(zlib.compress(im.convert('RGBA').tobytes(),9))
  mobile_estimate+=mobile*new_size/max(1,ref_size)
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
    v=float((aa&bb).sum()/max(1,(aa|bb).sum()));vals.append(v)
    expanded=np.asarray(Image.fromarray(aa).filter(__import__('PIL.ImageFilter',fromlist=['MaxFilter']).MaxFilter(5)))
    assert not (bb & ~expanded).any(),(name,y,x,'accessory > 2 px')
    assert v>.95,(name,y,x,v)
  if name!='portrait':
   e=np.asarray(Image.open(OUT/(name+'_e.png')).convert('RGBA'));ref=np.asarray(Image.open(BASE/(name+'_e.png')).convert('RGBA'))
   assert np.array_equal(e,ref) and (e[...,:3].max(2)*e[...,3].astype(float)/255).max()>2
   assert e.shape[:2]==((b.shape[0]+1)//2,(b.shape[1]+1)//2)
   r.update(accent_iou=1.0,accent_iou_cells=[1.0]*(rows*n))
  opaque=b[...,3]>128
  rgb=b[...,:3][opaque].astype(float)
  assert np.isfinite(rgb).all() and rgb.max()-rgb.min()>20,(name,'contrast')
  r.update(alpha_iou_cells=vals,contrast_range=float(rgb.max()-rgb.min()));results.append(r)
 (HERE/'_panoplie_rictus_avant_la_pluie_verification.json').write_text(json.dumps({'checks':results,'emission':'Original approved masks retained verbatim; radiance and coverage unchanged.','alpha_threshold':128,'alpha_required':0.95,'accent_required':0.90,'seed':271026,'alpha_iou_min':min(min(r['alpha_iou_cells']) for r in results),'accent_iou_min':1.0,'png_added_mb':sum(p.stat().st_size for p in OUT.glob('*.png'))/1048576,'mobile_estimated_mb':mobile_estimate/1048576,'mobile_estimate_method':'Default imported mobile texture bytes scaled by deflated RGBA pixel entropy ratio per corresponding texture; exact value requires orchestrator Godot import','accessory_max_outside_px':2,'material_middle_lstar_min':min(json.loads((RAW/'material_middle_lstar.json').read_text()).values())},indent=2))
 # contact_pair uses separate roots; map left side to default via a tiny path adapter.
 class DefaultRoot:
  def __truediv__(self,rel):return ROOT/'game/assets/sprites/ui/portraits/rictus.png' if Path(rel).name=='portrait.png' else BASE/Path(rel).name
 old=cel.ARCHIVE;cel.ARCHIVE=DefaultRoot()
 samples=[[(str((OUT/(name+'.png')).relative_to(cel.GAME_SPRITES)),256 if name=='portrait' else 192,{'run':3,'slash':2,'throw_ult':3}.get(name,0),0 if name=='portrait' else 2) for name in line] for line in [('idle','run'),('slash','portrait')]]
 cel.contact_pair(samples,HERE/'_panoplie_rictus_avant_la_pluie_contact.png',size=(1024,640));cel.ARCHIVE=old
 base_text=(BASE/'rictus.tres').read_text();skin_text=(OUT/'rictus_avant_la_pluie.tres').read_text()
 names=re.findall(r'"name": &"([^"]+)"',base_text);assert len(names)>0 and names==re.findall(r'"name": &"([^"]+)"',skin_text)
 assert skin_text==base_text.replace('res://assets/sprites/characters/rictus/','res://assets/sprites/characters/rictus/skins/rictus_avant_la_pluie/')
 assert not any(x in skin_text for x in ('CanvasTexture','normal_texture','_n.png'))
 assert not list(OUT.glob('*_n.png')) and not list(RAW.rglob('*_n.png'))
 expected={name+s+'.png' for name in NAMES for s in (('',) if name=='portrait' else ('','_e'))}|{'rictus_avant_la_pluie.tres'}
 assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
 print('PASS verification',flush=True)

def driver():
 OUT.mkdir(parents=True,exist_ok=True)
 if '--verify-only' not in sys.argv:
  with (HERE/'_logpanoplie_rictus.txt').open('w') as log:
   subprocess.run([cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+(['--resume'] if '--resume' in sys.argv else []),cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
 text=(BASE/'rictus.tres').read_text();old='res://assets/sprites/characters/rictus/'
 (OUT/'rictus_avant_la_pluie.tres').write_text(text.replace(old,old+'skins/rictus_avant_la_pluie/'),encoding='utf-8')
 verify()
if __name__=='__main__':
 if '--render' in sys.argv:
  import bpy
  WORK.mkdir(parents=True,exist_ok=True)
  shutil.copy2(ROOT/'art/blender/characters/rictus.blend',WORK/'rictus_avant_la_pluie.blend')
  bpy.ops.wm.open_mainfile(filepath=str(WORK/'rictus_avant_la_pluie.blend'));materials()
  bpy.context.preferences.filepaths.save_version=0
  cel.install('creature',normals=False)
  bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'rictus_avant_la_pluie.blend'))
  render()
 else:driver()
