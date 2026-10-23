import json,hashlib,sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'art/tools/ui'; DIR=ROOT/'game/assets/sprites/icons/items'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 p=BASE/'_u3_inventory.json'
 if p.exists(): print('PASS inventory exists');return
 bases=sorted(x for x in DIR.glob('*.png') if not x.stem.endswith(('_n','_e')))[:25]
 data={'objects':[p.stem for p in bases],'files':{},'protected':{}}
 for base in bases:
  for f in [base,*[base.with_stem(base.stem+s) for s in ('_n','_e') if base.with_stem(base.stem+s).exists()]]:
   im=Image.open(f).convert('RGBA');data['files'][f.name]={'size':list(im.size),'mode':Image.open(f).mode,'bbox':list(im.getchannel('A').getbbox()),'sha256':sha(f)}
   imp=Path(str(f)+'.import')
   if imp.exists():data['protected'][imp.name]=sha(imp)
 p.write_text(json.dumps(data,indent=2));print('PASS inventory',len(bases),'objects',len(data['files']),'PNG')
def finish():
 inv=json.loads((BASE/'_u3_inventory.json').read_text());errors=[];done=[]
 for name in inv['objects']:
  raw=BASE/'u3_raw'/f'{name}.png'
  if not raw.exists():continue
  for f,s in inv['files'].items():
   if f!=name+'.png' and f not in [name+'_n.png',name+'_e.png']:continue
   source=BASE/'u3_raw'/f
   if not source.exists():errors.append(f+' missing render');continue
   im=Image.open(source).convert('RGBA');box=im.getchannel('A').getbbox();im=im.crop(box);x,y,r,b=s['bbox'];im=im.resize((r-x,b-y),Image.Resampling.LANCZOS)
   for _ in range(3):
    bb=im.getchannel('A').getbbox()
    if bb==(0,0,im.width,im.height):break
    im=im.crop(bb).resize(im.size,Image.Resampling.LANCZOS)
   out=Image.new('RGBA',s['size']);out.paste(im,(x,y));out.save(DIR/f,optimize=True)
  done.append(name)
 for f,s in inv['files'].items():
  im=Image.open(DIR/f)
  if list(im.size)!=s['size'] or im.mode!=s['mode'] or list(im.getchannel('A').getbbox())!=s['bbox']:errors.append(f+' format/bounds')
  if f.removesuffix('.png') in done and sha(DIR/f)==s['sha256']:errors.append(f+' unchanged')
 for f,h in inv['protected'].items():
  if sha(DIR/f)!=h:errors.append(f+' import changed')
 items={i['id']:i for i in json.loads((ROOT/'game/data/items.json').read_text(encoding='utf-8'))}
 sheet=Image.new('RGBA',(5*240,5*216),(20,21,23,255))
 for i,name in enumerate(inv['objects']):
  frame=Image.open(ROOT/('game/assets/sprites/icons/frame_'+items[name]['quality']+'.png')).convert('RGBA');icon=Image.open(DIR/(name+'.png')).convert('RGBA')
  for size,off in [(64,0),(128,80)]:
   tile=frame.resize((size,size),Image.Resampling.LANCZOS);tile.alpha_composite(icon.resize((size,size),Image.Resampling.LANCZOS));sheet.alpha_composite(tile,(i%5*240+off,i//5*216+20))
 sheet.save(BASE/'_u3_contact.png',optimize=True)
 report={'status':'FAIL' if errors else 'PASS','completed':done,'remaining':[x for x in inv['objects'] if x not in done],'errors':errors,'checks':['dimensions','mode','exact alpha bounds','imports hashes','changed diffuse'],'contact_order':inv['objects']}
 (BASE/'_u3_report.json').write_text(json.dumps(report,indent=2));print(report['status'],len(done),'/25;',len(errors),'errors');print(errors[:4])
if __name__=='__main__':snapshot() if 'snapshot' in sys.argv else finish()
