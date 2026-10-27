"""Bourbe Grès noir: source functions and material-only scene copies; resumable."""
import sys,json,subprocess,shutil,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
WORK=ROOT/'art/blender/cel/skins/bourbe_skin1_work'
SOURCE=ROOT/'art/blender/characters'
BASE=ROOT/'game/assets/sprites/characters/bourbe'
OUT=BASE/'skins/bourbe_skin1'
COPY=ROOT/'art/blender/cel/skins/bourbe_skin1.blend'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
sys.dont_write_bytecode=True
import cel_style as cel
ANIMS=['idle','run','slap','throw','recall','sink','rise','attack','cast','cast_ult','death']

def materials():
 import bpy
 def linear(hex):
  v=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
  return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in v)+(1,)
 palette={'Argile':('1E1C1A',.18,.25),'Bronze':('8A7342',.28,.9),'Tranches':('8A7342',.32,.85),'Mousse':('B8B4A4',.85,0),'Racines':('2A2420',.7,0)}
 for m in bpy.data.materials:
  entry=next((v for k,v in palette.items() if m.name.startswith(k)),None)
  if entry is None or not m.use_nodes:continue
  p=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
  if p is None:continue
  color,rough,metal=entry
  rgba=linear(color)
  p.inputs['Base Color'].default_value=rgba
  p.inputs['Roughness'].default_value=rough
  p.inputs['Metallic'].default_value=metal
  for n in m.node_tree.nodes:
   if n.type=='VALTORGB':
    for el in n.color_ramp.elements:el.color=rgba
 # Existing narrow strata are surface details: no vertices, modifiers or poses change.
 clay=next(m for m in bpy.data.materials if m.name.startswith('Argile'))
 crack=clay.copy();crack.name='Grès craquelures claires'
 p=next(n for n in crack.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 p.inputs['Base Color'].default_value=linear('8C8578')
 for n in crack.node_tree.nodes:
  if n.type=='VALTORGB':
   for el in n.color_ramp.elements:el.color=linear('8C8578')
 for o in bpy.data.objects:
  if o.type=='MESH' and any(k in o.name.lower() for k in ('fissure','craquel','strate')):
   for i,m in enumerate(o.data.materials):
    if m and not m.name.startswith('Unique feu follet'):o.data.materials[i]=crack
 print('MATERIALS',[(m.name) for m in bpy.data.materials],flush=True)

def render():
 import bpy,iso_rig
 import bo1_build as bo1
 from cel_heroes_e_build import patched
 WORK.mkdir(parents=True,exist_ok=True)
 patched(iso_rig,'render_frame',[("for suffix in ('_n','_e'):","for suffix in ('_e',):")])
 iso_rig.optimize_png=lambda *a,**k:None
 def actor_source():
  bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'bourbe.blend'))
  materials()
  COPY.parent.mkdir(parents=True,exist_ok=True)
  bpy.context.preferences.filepaths.save_version=0
  bpy.ops.wm.save_as_mainfile(filepath=str(COPY))
  cel.install('creature',normals=False)
  root=next(o for o in bpy.data.objects if o.name.startswith('BOURBE') and o.type=='EMPTY')
  rig=bpy.data.objects['Bourbe_Rig'];rig.animation_data_clear()
  return root,rig
 bo1.build_model=actor_source;bo1.OUT=WORK/'stage';bo1.WORK=WORK/'raw';bo1.resources=lambda:None
 patched(bo1,'render_actor',[("('','_n','_e')","('','_e')")])
 if '--resume' in sys.argv:sys.argv.append('--reuse')
 bo1.render_actor()
 if not ('--resume' in sys.argv and (WORK/'stage/portrait.png').exists()):
  bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'bourbe_portrait.blend'))
  materials();cel.install('creature',normals=False)
  iso_rig.render_frame(WORK/'stage/portrait.png')
 print('SKIN RENDER PASS',flush=True)

def deliver():
 from PIL import Image
 import numpy as np
 OUT.mkdir(parents=True,exist_ok=True)
 for name in ANIMS+['portrait']:
  for suffix in ('','_e'):
   src=WORK/'stage'/f'{name}{suffix}.png'
   ref=BASE/src.name
   assert src.exists() and ref.exists(),str(src)
   with Image.open(src) as im:
    im=im.convert('RGBA')
    if suffix:
     # Emission materials, geometry and pose are invariant: keep canonical masks.
     # This preserves the already approved historical downsampling exactly.
     im=Image.open(ref).convert('RGBA')
     b=np.array(im)
     assert np.any((b[:,:,:3].max(2)>2)&(b[:,:,3]>2)),name+' empty emission'
    assert im.size==Image.open(ref).size,(name,im.size,Image.open(ref).size)
    im.save(OUT/src.name,optimize=True,compress_level=9)
 text=(BASE/'bourbe.tres').read_text(encoding='utf-8')
 text=text.replace('res://assets/sprites/characters/bourbe/','res://assets/sprites/characters/bourbe/skins/bourbe_skin1/')
 assert 'CanvasTexture' not in text and 'normal_texture' not in text
 (OUT/'bourbe_skin1.tres').write_text(text,encoding='utf-8')

def verify():
 from PIL import Image
 import numpy as np
 report={'sheets':[],'status':'PASS','emission_provenance':'Canonical default masks; emission materials and geometry unchanged'}
 for name in ANIMS+['portrait']:
  cell=256 if name=='portrait' else 192
  rel=f'characters/bourbe/skins/bourbe_skin1/{name}.png'
  im=np.array(Image.open(OUT/f'{name}.png').convert('RGBA'))
  ref=np.array(Image.open(BASE/f'{name}.png').convert('RGBA'))
  h,w=im.shape[:2];assert ref.shape==im.shape
  entry=cel.check_sheet(rel,cell=cell,frames=w//cell,rows=h//cell,normals=False)
  ious=[]
  for r in range(h//cell):
   for c in range(w//cell):
    a=im[r*cell:(r+1)*cell,c*cell:(c+1)*cell,3]>128
    b=ref[r*cell:(r+1)*cell,c*cell:(c+1)*cell,3]>128
    iou=float((a&b).sum()/max(1,(a|b).sum()));ious.append(iou)
  entry['alpha_iou_cells']=ious
  a=np.array(Image.open(OUT/f'{name}_e.png').convert('RGBA'))
  b=np.array(Image.open(BASE/f'{name}_e.png').convert('RGBA'))
  mask=lambda x:(x[:,:,:3].max(2)>100)&(x[:,:,3]>128)
  a,b=mask(a),mask(b);eh,ew=a.shape;ec=cell//2;ei=[]
  for r in range(eh//ec):
   for c in range(ew//ec):
    x=a[r*ec:(r+1)*ec,c*ec:(c+1)*ec];y=b[r*ec:(r+1)*ec,c*ec:(c+1)*ec]
    ei.append(float((x&y).sum()/(x|y).sum()) if (x|y).any() else 1.)
  entry['accent_iou_cells']=ei
  entry['pass']=min(ious)>.95 and min(ei)>.90
  if not entry['pass']:report['status']='FAIL'
  report['sheets'].append(entry)
 expected={f'{n}{s}.png' for n in ANIMS+['portrait'] for s in ('','_e')}|{'bourbe_skin1.tres'}
 assert {p.name for p in OUT.iterdir() if p.suffix!='.import'}==expected
 (HERE/'_skin_bourbe_verification.json').write_text(json.dumps(report,indent=2))
 # cel.contact_pair uses ARCHIVE as its left-side root. Stage references only.
 archive=WORK/'contact_default';archive.mkdir(exist_ok=True)
 for name in ['idle','run','attack','cast_ult','portrait']:
  target=archive/'characters/bourbe/skins/bourbe_skin1'/f'{name}.png'
  target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(BASE/f'{name}.png',target)
 previous=cel.ARCHIVE;cel.ARCHIVE=archive
 cel.contact_pair([[(f'characters/bourbe/skins/bourbe_skin1/{n}.png',192,2,2) for n in ['idle','run']],[(f'characters/bourbe/skins/bourbe_skin1/{n}.png',192,2,2) for n in ['attack','cast_ult']], [('characters/bourbe/skins/bourbe_skin1/portrait.png',256,0,0)]],HERE/'_skin_bourbe_contact.png',size=(1200,1000))
 cel.ARCHIVE=previous
 print('VERIFY',report['status'],[(x['file'].split('/')[-1],min(x['alpha_iou_cells']),min(x['accent_iou_cells'])) for x in report['sheets']],flush=True)
 assert report['status']=='PASS'

def checks():
 import tempfile
 def run(name,argv):
  log=HERE/('_skin_bourbe_'+name+'.log')
  with log.open('w',encoding='utf-8') as f:
   result=subprocess.run(argv,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
  output=log.read_text(encoding='utf-8',errors='replace')
  errors=[x for x in output.splitlines() if 'ERROR:' in x or 'SCRIPT ERROR:' in x]
  passed=result.returncode==0 and not errors
  if name in ('sprites','bourbe','skin_load'):passed=passed and 'RESULT: OK' in output
  print(name, 'PASS' if passed else 'FAIL', 'exit',result.returncode,flush=True)
  return {'exit':result.returncode,'pass':passed,'errors':errors[:8],'result':[x for x in output.splitlines() if 'RESULT:' in x]}
 results={}
 results['policy']=run('policy',[sys.executable,'art/tools/texture_budget.py','--apply-policy'])
 results['import']=run('import',[GODOT,'--headless','--path','game','--import'])
 for name in ('sprites','bourbe','texture_budget'):
  results[name]=run(name,[GODOT,'--headless','--path','game',f'res://tests/{name}_test.tscn'])
 # Ephemeral verifier outside the project; no project .gd/.tscn edits.
 code='''extends SceneTree
func _initialize():
    var base = load("res://assets/sprites/characters/bourbe/bourbe.tres")
    var skin = load("res://assets/sprites/characters/bourbe/skins/bourbe_skin1/bourbe_skin1.tres")
    if not (skin is SpriteFrames) or not (base is SpriteFrames):
        print("RESULT: FAIL SpriteFrames")
        quit(1)
        return
    if base.get_animation_names() != skin.get_animation_names():
        print("RESULT: FAIL animations")
        quit(1)
        return
    for anim in base.get_animation_names():
        if base.get_frame_count(anim) != skin.get_frame_count(anim) or base.get_animation_speed(anim) != skin.get_animation_speed(anim) or base.get_animation_loop(anim) != skin.get_animation_loop(anim):
            print("RESULT: FAIL frame contract")
            quit(1)
            return
    print("RESULT: OK")
    quit(0)
'''
 with tempfile.TemporaryDirectory(prefix='rainfall_bourbe_verify_') as tmp:
  script=Path(tmp)/'verify.gd';script.write_text(code)
  results['skin_load']=run('skin_load',[GODOT,'--headless','--path','game','--script',str(script)])
 results['budget']=run('budget',[sys.executable,'art/tools/texture_budget.py','--json',str(HERE/'_skin_bourbe_budget_after.json')])
 before=json.loads((HERE/'_skin_bourbe_budget_before.json').read_text())
 after=json.loads((HERE/'_skin_bourbe_budget_after.json').read_text())
 cat='characters/bourbe'
 results['added']={k:after['categories'][cat][k]-before['categories'][cat][k] for k in ('png','mobile')}
 results['global_mobile_bytes']=after['total']['mobile']
 path=HERE/'_skin_bourbe_verification.json'
 report=json.loads(path.read_text());report['checks']=results
 path.write_text(json.dumps(report,indent=2))
 assert all(results[n]['pass'] for n in ('policy','import','sprites','bourbe','skin_load')),'Godot validation failure'
 print('ADDED',results['added'],'GLOBAL',results['global_mobile_bytes'],flush=True)

def driver():
 WORK.mkdir(parents=True,exist_ok=True)
 if '--verify' not in sys.argv:
  with (HERE/'_skin_bourbe_render.log').open('w') as log:
   code=subprocess.call([BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+(['--resume'] if '--resume' in sys.argv else []),cwd=ROOT,stdout=log,stderr=subprocess.STDOUT)
  assert code==0,'Blender failure: _skin_bourbe_render.log'
  deliver()
 verify()
 checks()

if __name__=='__main__':
 render() if '--render' in sys.argv else driver()
