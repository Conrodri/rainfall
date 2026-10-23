import ast,json,hashlib,sys
from pathlib import Path
R=Path(__file__).resolve().parents[3];sys.path.insert(0,str(R/'art/tools/vendor'))
from PIL import Image
P=R/'game/assets/sprites/icons/items'; INV=Path(__file__).with_name('_r7a_inventory.json')
def digest(f):return hashlib.sha256(f.read_bytes()).hexdigest()
def snapshot():
 files={}
 for f in sorted(P.iterdir()):
  if not f.is_file():continue
  d={'sha256':digest(f)}
  if f.suffix=='.png':
   im=Image.open(f);d.update(size=list(im.size),mode=im.mode)
  files[f.name]=d
 return files
if sys.argv[-1]=='inventory':
 ids=[]
 for f in ['items_b.py','items_c.py']:
  t=ast.parse((R/'art/tools/ui'/f).read_text(encoding='utf-8-sig'))
  ids+=next(ast.literal_eval(n.value) for n in t.body if isinstance(n,ast.Assign) and any(isinstance(x,ast.Name) and x.id=='IDS' for x in n.targets))
 INV.write_text(json.dumps({'ids':ids,'files':snapshot()},separators=(',',':')))
 print('PASS inventory',len(ids),'items;',len(snapshot()),'files')
else:
 inv=json.loads(INV.read_text());now=snapshot();chosen=inv['ids']
 allowed={i+s+'.png' for i in chosen for s in ['','_n','_e']}
 assert now.keys()==inv['files'].keys(),'file set changed'
 changed=[]
 for name,before in inv['files'].items():
  after=now[name]
  assert all(before[k]==after[k] for k in before if k!='sha256'),name
  if before['sha256']!=after['sha256']:
   assert name in allowed,name
   changed.append(name)
 for i in chosen:
  for suffix in ['','_n','_e']:
   name=i+suffix+'.png'
   if name not in inv['files']:continue
   assert name in changed,name
   im=Image.open(P/name).convert('RGBA');alpha=im.getchannel('A');bb=alpha.getbbox()
   assert bb and min(bb[:2])>=10 and max(bb[2:])<=246,name
   assert alpha.getextrema()==(0,255),name
   assert abs((bb[0]+bb[2])/2-128)<=1 and abs((bb[1]+bb[3])/2-128)<=1,name
   raw=Image.open(R/'art/renders/ui/items'/name);assert raw.size==(512,512) and raw.mode=='RGBA',name
 assert len({now[i+'.png']['sha256'] for i in chosen})==33,'duplicate icon'
 # Assembly only: originals at 256 and 64 pixels, no drawing.
 refs=['lentille_aiguisee','sablier_fele','antidote','botte_rapiecee','pierre_a_aiguiser','bague_de_vigueur','amulette_de_cuir']
 sheet=Image.new('RGBA',(8*256,5*320),(43,51,64,255))
 for j,i in enumerate(chosen+refs):
  x=(j%8)*256;y=(j//8)*320
  im=Image.open(P/(i+'.png')).convert('RGBA');sheet.alpha_composite(im,(x,y))
  sheet.alpha_composite(im.resize((64,64),Image.Resampling.LANCZOS),(x+96,y+256))
 sheet.save(Path(__file__).with_name('_r7a_contact.png'))
 print('PASS contract;',len(changed),'PNGs replaced; other files identical; contact assembled')
