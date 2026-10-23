import ast,json,hashlib,sys
from pathlib import Path
from PIL import Image
R=Path(__file__).resolve().parents[3]; T=Path(__file__).parent
src=ast.parse((T/'props_biomes.py').read_text())
d=next(n.value for n in src.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SPECS' for t in n.targets))
spec=[(ast.literal_eval(k),ast.literal_eval(v.elts[0]),ast.literal_eval(v.elts[2])) for k,v in zip(d.keys,d.values)]
def scan():
 rows=[]
 for name,biome,size in spec:
  for p in sorted((R/'game/assets/sprites/props'/biome).glob(name+'*')):
   if p.name not in [name+s+ext for s in ('','_n','_e') for ext in ('.png','.png.import','.tres')]:continue
   row={'file':p.relative_to(R).as_posix()}
   if p.suffix=='.png':
    with Image.open(p) as im:row.update(size=list(im.size),mode=im.mode,frames=1)
   else:row['sha256']=hashlib.sha256(p.read_bytes()).hexdigest()
   rows.append(row)
 return rows
inv=T/'_r6b_inventory.json'
if '--inventory' in sys.argv:
 assert not inv.exists(),'Inventory already exists'
 inv.write_text(json.dumps(scan(),separators=(',',':')))
 print('PASS inventory:',len(spec),'props,',len(scan()),'files')
else:
 old=json.loads(inv.read_text());assert old==scan(),'Inventory mismatch'
 tiles=[]
 for name,biome,size in spec:
  p=R/'game/assets/sprites/props'/biome/(name+'.png')
  with Image.open(p) as im:
   assert im.size==(size,size) and im.mode=='RGBA',(name,im.size)
   a=im.getchannel('A');bb=a.getbbox();assert bb and min(bb[:2])>=2 and bb[2]<=size-2 and bb[3]<=size-2,(name,bb)
   with Image.open(p.with_stem(name+'_n')) as n:assert a.tobytes()==n.getchannel('A').tobytes(),name
   ep=p.with_stem(name+'_e')
   if ep.exists():
    with Image.open(ep) as e:assert max(e.convert('RGB').getextrema()[1])>0 and e.size==im.size
   tile=im.copy();tile.thumbnail((192,192));tiles.append(tile)
 sheet=Image.new('RGBA',(6*208,3*208),(47,56,61,255))
 for i,im in enumerate(tiles):sheet.alpha_composite(im,((i%6)*208+(208-im.width)//2,(i//6)*208+(208-im.height)//2))
 sheet.save(T/'_r6b_contact.png');print('PASS inventory, dimensions, margins, normal alpha, emissions;',len(spec),'props')
