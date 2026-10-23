"""Resize only; validate original contract and assemble one contact sheet."""
import sys,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];sys.path.insert(0,str(R/'art/tools/vendor'))
from PIL import Image
D=Path(__file__).parent;inv=json.loads((D/'_r7b_inventory.json').read_text());(D/'_r7b_inventory.json').write_text(json.dumps(inv,separators=(',',':')))
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if '--write' in sys.argv:
 for q in inv:
  if 'size' not in q:continue
  p=R/q['path'];src=Image.open(R/'art/renders/ui/spells'/p.name).convert('RGBA')
  src.resize(tuple(q['size']),Image.Resampling.LANCZOS).save(p)
  if '/spells/' in q['path']:
   b=R/'art/renders/ui/spells_256'/p.name;b.parent.mkdir(parents=True,exist_ok=True);src.resize((256,256),Image.Resampling.LANCZOS).save(b)
expected={q['path'] for q in inv};base=R/'game/assets/sprites/icons'
now={p.relative_to(R).as_posix() for p in list(base.glob('frame_*.png'))+list((base/'spells').rglob('*')) if p.is_file()}
assert now==expected,'file list'
imgs=[]
for q in inv:
 p=R/q['path']
 if 'size' not in q:assert digest(p)==q['sha256'],p;continue
 im=Image.open(p);assert list(im.size)==q['size'] and im.mode==q['mode'],p
 assert digest(p)!=q['sha256'],p
 alpha=im.getchannel('A');assert alpha.getextrema()==(0,255) and alpha.getbbox(),p
 if p.stem.startswith('frame_'):assert alpha.getpixel((im.width//2,im.height//2))==0,p
 imgs.append((p,im.copy()))
assert len({digest(p) for p,_ in imgs})==12
sheet=Image.new('RGBA',(1280,1056),(43,51,64,255))
frames=[x for x in imgs if x[0].stem.startswith('frame_')];order=['frame_commun','frame_peu_commun','frame_rare','frame_legendaire'];frames.sort(key=lambda x:order.index(x[0].stem))
spells=[x for x in imgs if not x[0].stem.startswith('frame_')];order=['eclat_de_braise','braises_errantes','nova_ardente','pilier_de_flamme','cendres','pluie_de_meteores','brasier','phenix'];spells.sort(key=lambda x:order.index(x[0].stem))
for j,(p,im) in enumerate(frames+spells):
 x=(j%4)*256;y=(j//4)*352
 sheet.alpha_composite(im.resize((256,256),Image.Resampling.LANCZOS),(x,y))
 sheet.alpha_composite(im.resize((64,64),Image.Resampling.LANCZOS),(x+96,y+272))
ref=Image.open(D/'_r7a_contact.png').convert('RGBA');ref.thumbnail((256,1000));sheet.alpha_composite(ref,(1024,0))
sheet.save(D/'_r7b_contact.png')
print('PASS: 12 PNG replaced; names/sizes/modes preserved; 8 imports unchanged; transparent centers; 256 masters refreshed; contact with R7a reference')
