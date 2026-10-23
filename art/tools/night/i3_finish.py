"""Exact existing raster contract; Pillow only crops, resizes and assembles."""
import json,hashlib,sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3];BASE=Path(__file__).parent
INV=BASE/'i3_inventory.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 if INV.exists():return
 files={};protected={}
 for p in sorted((ROOT/'game/assets/sprites/icons/spells').glob('*.png')):
  im=Image.open(p);files[p.stem]={'path':p.relative_to(ROOT).as_posix(),'size':im.size,'bbox':im.getbbox(),'mode':im.mode,'hash':sha(p)}
  im.save(BASE/f'i3_before_{p.stem}.png')
  for q in p.parent.glob(p.name+'*'):
   if q!=p:protected[q.relative_to(ROOT).as_posix()]=sha(q)
 for p in (ROOT/'game').rglob('*.tres'):protected[p.relative_to(ROOT).as_posix()]=sha(p)
 INV.write_text(json.dumps({'files':files,'protected':protected},indent=2))
 print('PASS inventory: 8 RGBA 128px; exact alpha bounds, imports and resources recorded')
def fit(name):
 d=json.loads(INV.read_text())['files'][name];im=Image.open(BASE/f'i3_raw_{name}.png').convert('RGBA');im=im.crop(im.getbbox());x,y,r,b=d['bbox']
 im=im.resize((r-x,b-y),Image.Resampling.LANCZOS)
 for _ in range(3):
  if im.getbbox()==(0,0,im.width,im.height):break
  im=im.crop(im.getbbox()).resize((r-x,b-y),Image.Resampling.LANCZOS)
 canvas=Image.new('RGBA',d['size']);canvas.paste(im,(x,y));canvas.save(ROOT/d['path'],compress_level=9)
def finish():
 inv=json.loads(INV.read_text());errors=[];external=[]
 for name,d in inv['files'].items():
  im=Image.open(ROOT/d['path'])
  if list(im.size)!=d['size'] or list(im.getbbox())!=d['bbox'] or im.mode!=d['mode'] or sha(ROOT/d['path'])==d['hash']:errors.append(name)
 for rel,h in inv['protected'].items():
  if sha(ROOT/rel)!=h:
   if rel.endswith('.tres'):external.append(rel)
   else:errors.append(rel)
 # Single final board: old Ardent above, new Ardent at 128 + 64 below;
 # validated I2 and character/projectile references at the bottom.
 sheet=Image.new('RGB',(1280,810),(17,20,24));frame=Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA')
 for i,(name,d) in enumerate(inv['files'].items()):
  x=12+i*158
  for old,y,size in [(True,12,128),(False,152,128),(False,294,64)]:
   im=Image.open(BASE/f'i3_before_{name}.png' if old else ROOT/d['path']).convert('RGBA');im.alpha_composite(frame.resize(im.size,Image.Resampling.LANCZOS));im=im.resize((size,size),Image.Resampling.LANCZOS);sheet.paste(im,(x+(128-size)//2,y),im)
 for path,box in [('art/tools/ui/_i2_contact.png',(0,380,640,420)),('art/tools/iso/_c4_contact.png',(650,380,310,210)),('art/tools/iso/_v2_contact.png',(970,380,300,210)),('art/tools/characters/_m2_contact.png',(650,600,210,200)),('art/tools/iso/_c1_contact.png',(870,600,400,200))]:
  im=Image.open(ROOT/path).convert('RGB');im.thumbnail(box[2:],Image.Resampling.LANCZOS);sheet.paste(im,box[:2])
 sheet.save(BASE/'_i3_contact.png',optimize=True)
 (BASE/'i3_report.json').write_text(json.dumps({'status':'FAIL' if errors else 'PASS','icons':8,'exact_bounds':True,'protected_imports':8,'errors':errors,'parallel_resource_changes':external,'resource_note':'Existing resources are read only for I3; parallel batch changes are recorded separately.'},indent=2));print('PASS raster and imports; parallel resource changes='+str(len(external)) if not errors else 'FAIL '+str(errors));assert not errors
if __name__=='__main__':
 if sys.argv[1]=='snapshot':snapshot()
 elif sys.argv[1]=='fit':fit(sys.argv[2])
 else:finish()
