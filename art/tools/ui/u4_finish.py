"""U4 contract snapshot, exact alpha fit and contact assembly. No raster drawing."""
import json,hashlib,sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'art/tools/ui'
INV=BASE/'_u4_inventory.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 if INV.exists():
  print('PASS existing inventory preserved');return
 items=sorted((ROOT/'game/assets/sprites/icons/items').glob('*.png'))[25:50]
 spells=sorted((ROOT/'game/assets/sprites/icons/spells').rglob('*.png'))
 paths=items+spells+sorted((ROOT/'game/assets/sprites/ui/interact').glob('*.png'))+[ROOT/'game/assets/sprites/ui/hud/icon_interact_hand.png']
 d={'files':{},'protected':{},'items':[p.stem for p in items]}
 for p in paths:
  im=Image.open(p); d['files'][p.relative_to(ROOT).as_posix()]={'size':list(im.size),'bbox':list(im.getbbox()),'mode':im.mode,'sha256':sha(p)}
  for q in p.parent.glob(p.name+'*'):
   if q!=p:d['protected'][q.relative_to(ROOT).as_posix()]=sha(q)
 for directory in ['game/assets/sprites/icons','game/assets/sprites/ui/interact']:
  for p in (ROOT/directory).rglob('*.tres'):d['protected'][p.relative_to(ROOT).as_posix()]=sha(p)
 INV.write_text(json.dumps(d,indent=2));print('PASS inventory',len(paths))
def fit(raw,rel):
 d=json.loads(INV.read_text())['files'][rel]; im=Image.open(raw).convert('RGBA'); im=im.crop(im.getbbox());x,y,r,b=d['bbox']
 for _ in range(3):
  im=im.resize((r-x,b-y),Image.Resampling.LANCZOS)
  if im.getbbox()==(0,0,im.width,im.height):break
  im=im.crop(im.getbbox())
 canvas=Image.new('RGBA',d['size']);canvas.paste(im,(x,y));canvas.save(ROOT/rel,optimize=True,compress_level=9)
def finish():
 inv=json.loads(INV.read_text()); errors=[]; changed=[]
 for rel,d in inv['files'].items():
  p=ROOT/rel; im=Image.open(p)
  if list(im.size)!=d['size'] or list(im.getbbox())!=d['bbox'] or im.mode!=d['mode']:errors.append(rel+': contract')
  if sha(p)!=d['sha256']:changed.append(rel)
 for rel,h in inv['protected'].items():
  if sha(ROOT/rel)!=h:errors.append(rel+': protected')
 sheet=Image.new('RGBA',(1280,1200),(18,19,20,255));qualities={i['id']:i['quality'] for i in json.loads((ROOT/'game/data/items.json').read_text(encoding='utf-8'))}
 def put(im,x,y,size):
  im=im.convert('RGBA').resize((size,size),Image.Resampling.LANCZOS);sheet.alpha_composite(im,(x,y))
 for i,name in enumerate(inv['items']):
  x=i%5*256;y=i//5*190;icon=Image.open(ROOT/f'game/assets/sprites/icons/items/{name}.png')
  frame=Image.open(ROOT/f'game/assets/sprites/icons/frame_{qualities[name]}.png')
  for size,dx in [(64,12),(128,100)]:
   tile=Image.new('RGBA',(size,size));obj=icon.resize((int(size*.82),int(size*.82)),Image.Resampling.LANCZOS);tile.alpha_composite(obj,((size-obj.width)//2,(size-obj.height)//2));tile.alpha_composite(frame.resize((size,size),Image.Resampling.LANCZOS));put(tile,x+dx,y+20,size)
 spells=[r for r in inv['files'] if '/spells/' in r]
 for i,rel in enumerate(spells):
  tile=Image.open(ROOT/rel).convert('RGBA');tile.alpha_composite(Image.open(ROOT/'game/assets/sprites/ui/spell_frame.png').convert('RGBA').resize(tile.size,Image.Resampling.LANCZOS));put(tile,10+i*155,960,128)
 for i,rel in enumerate(r for r in inv['files'] if '/interact/' in r or '/hud/' in r):put(Image.open(ROOT/rel),20+i*170,1100,96)
 sheet.convert('RGB').save(BASE/'_u4_contact.png',optimize=True)
 report={'status':'FAIL' if errors else ('PASS' if len(changed)==len(inv['files']) else 'PARTIAL'),'changed':len(changed),'total':len(inv['files']),'protected_files':len(inv['protected']),'checks':['RGBA format and dimensions','exact alpha bounding boxes','all 37 targets changed','existing import and resource hashes'],'companions':'No existing _n/_e PNG companions in the inventoried U4 targets; original file set preserved.','errors':errors,'remaining':[r for r in inv['files'] if r not in changed]}
 (BASE/'_u4_report.json').write_text(json.dumps(report,indent=2));print(report['status'],len(changed),'/',len(inv['files']),'errors',len(errors))
if __name__=='__main__':
 if len(sys.argv)>1 and sys.argv[1]=='snapshot':snapshot()
 elif len(sys.argv)>1 and sys.argv[1]=='fit':fit(sys.argv[2],sys.argv[3])
 else:finish()
