"""Freeze contract, validate replacements, assemble contact (Pillow crop/resize only)."""
import sys,json,hashlib
from pathlib import Path
R=Path(__file__).resolve().parents[3];sys.path.insert(0,str(R/'art/tools/vendor'))
from PIL import Image
D=Path(__file__).parent;F=D/'_r7c_inventory.json'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def files():return sorted(p for n in ['cards','dice','hud'] for p in (R/'game/assets/sprites/ui'/n).rglob('*') if p.is_file())
if '--inventory' in sys.argv:
 assert not F.exists(),'Inventory already exists'
 rows=[]
 for p in files():
  q=dict(path=p.relative_to(R).as_posix(),sha256=digest(p))
  if p.suffix=='.png':
   im=Image.open(p);q.update(size=list(im.size),mode=im.mode,bbox=im.getchannel('A').getbbox())
  rows.append(q)
 F.write_text(json.dumps(rows,separators=(',',':')))
 print('PASS inventory:',len(rows),'files;',sum('size' in q for q in rows),'PNG')
 sys.exit()
rows=json.loads(F.read_text());assert {q['path'] for q in rows}=={p.relative_to(R).as_posix() for p in files()}
if '--fit' in sys.argv:
 for q in rows:
  if 'size' not in q:continue
  p=R/q['path'];im=Image.open(p).convert('RGBA');bb=im.getchannel('A').getbbox();x,y,x2,y2=q['bbox']
  crop=im.crop(bb).resize((x2-x,y2-y),Image.Resampling.LANCZOS)
  out=Image.new('RGBA',tuple(q['size']));out.alpha_composite(crop,(x,y));out.save(p)
imgs=[]
for q in rows:
 p=R/q['path']
 if 'size' not in q:assert digest(p)==q['sha256'],p;continue
 im=Image.open(p);assert list(im.size)==q['size'] and im.mode==q['mode'],p
 assert digest(p)!=q['sha256'],p
 assert im.getchannel('A').getextrema()==(0,255),p
 bb=im.getchannel('A').getbbox();assert list(bb)==q['bbox'],(p,bb,q['bbox'])
 imgs.append((p,im.copy()))
assert len({digest(p) for p,_ in imgs})==len(imgs)
sheet=Image.new('RGBA',(1200,960),'#2B3340')
cards=[x for x in imgs if x[0].parent.name=='cards'];hud=[x for x in imgs if x[0].parent.name=='hud'];dice=[x for x in imgs if x[0].parent.name=='dice']
for j,(p,im) in enumerate(cards):sheet.alpha_composite(im,(j*400+8,8))
for j,(p,im) in enumerate(hud):sheet.alpha_composite(im,(j*132+8,590))
for j,(p,im) in enumerate(dice):sheet.alpha_composite(im,((j%12)*96+8,740+(j//12)*100)) if im.width<=96 else sheet.alpha_composite(im.resize((88,88),Image.Resampling.LANCZOS),((j%12)*96+8,740+(j//12)*100))
for j,n in enumerate(['_r7a_contact.png','_r7b_contact.png']):
 im=Image.open(D/n).convert('RGBA');im.thumbnail((185,555));sheet.alpha_composite(im,(806+j*195,8))
sheet.save(D/'_r7c_contact.png')
print('PASS:',len(imgs),'PNG replaced; names, dimensions, RGBA, alpha margins and all metadata preserved')
