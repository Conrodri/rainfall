from pathlib import Path
import re,json,hashlib,subprocess,sys
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
D=ROOT/'game/assets/sprites/characters/averse'
N={'attack':6,'wave':6,'cast':5,'crue':9}
F={'attack':[3,3,2,2,5,5],'wave':[4,4,4,5,9,9],'cast':[5,5,4,7,7],'crue':[5,5,4,4,4,10,10,9,9]}
if '--audit' in sys.argv:
 meta=json.loads((ROOT/'art/tools/night/_av1_actions_check.json').read_text())
 for a,n in N.items():
  w,h=meta[a]['cell']
  for suffix,k in (('',1),('_e',2)):
   im=Image.open(D/(a+suffix+'.png')).convert('RGBA');assert im.size==(n*w//k,8*h//k)
   pixels=np.asarray(im);assert pixels[:,:,3].min()==0 and pixels[:,:,3].max()>200
   if suffix:assert pixels[:,:,:3].max()>2
   for d in range(8):
    cells=[im.crop((f*w//k,d*h//k,(f+1)*w//k,(d+1)*h//k)) for f in range(n)]
    assert all(c.getbbox() for c in cells)
    if not suffix:assert len({hashlib.sha256(c.tobytes()).digest() for c in cells})==n
 for name in ('averse.tres','averse_emission.tres'):
  text=(D/name).read_text();assert text.count('"name":')==72
  assert 'normal_texture' not in text and 'CanvasTexture' not in text
 assert not any(D.glob('*_n.png')) and not any(D.glob('*__Image.png')) and not any(D.glob('*_fix.png'))
 print('PASS audit 208 directional frames; alpha; contrast; emissions; resources; no temporary PNG')
 sys.exit(0)
board=Image.new('RGBA',(960,4*144),(25,29,33,255))
meta={}
# Idle reference reconstructed at the unchanged 192px display cell.
base=subprocess.check_output(['git','show','HEAD:game/assets/sprites/characters/averse/averse.tres'],cwd=ROOT).decode().replace('\r\n','\n')
entry=re.search(r'\{"frames":.*?"name": &"idle_se".*?\}',base,re.S).group()
# Find the last frames opening before idle_se.
entry=entry[entry.rfind('{"frames":'):]
aid=re.search(r'SubResource\("([^"]+)"\)',entry).group(1)
block=re.search(r'\[sub_resource type="AtlasTexture" id="'+aid+r'"\](.*?)(?=\n\[|\Z)',base,re.S).group(1)
reg=list(map(int,re.search(r'region = Rect2\(([^)]+)',block).group(1).split(',')))
margin=re.search(r'margin = Rect2\(([^)]+)',block)
mx,my=map(int,margin.group(1).split(',')[:2]) if margin else (0,0)
idle=Image.new('RGBA',(192,192));idle.alpha_composite(Image.open(D/'idle.png').convert('RGBA').crop((reg[0],reg[1],reg[0]+reg[2],reg[1]+reg[3])),(mx,my))
for row,(a,n) in enumerate(N.items()):
 im=Image.open(D/(a+'.png')).convert('RGBA');assert im.size==(192*n,1536),(a,im.size)
 arr=np.asarray(im);assert arr[:,:,3].min()==0 and arr[:,:,3].max()==255
 boxes=[]
 for d in range(8):
  hashes=[]
  for f in range(n):
   cell=im.crop((f*192,d*192,(f+1)*192,(d+1)*192));bb=cell.getbbox();assert bb,(a,d,f)
   assert bb[0]>0 and bb[1]>0 and bb[2]<192 and bb[3]<192,(a,d,f,bb)
   pixels=np.asarray(cell);visible=pixels[pixels[:,:,3]>220,:3];assert len(visible)>20 and int(visible.max())-int(visible.min())>40,(a,d,f,'contrast')
   boxes.append(bb);hashes.append(hashlib.sha256(cell.tobytes()).digest())
  assert len(set(hashes))==n,(a,d,'duplicates')
 for f in range(n):
  c=im.crop((f*192,192,(f+1)*192,384));c.thumbnail((96,144));board.alpha_composite(c,(96*(f+1),row*144))
 c=idle.copy();c.thumbnail((96,144));board.alpha_composite(c,(0,row*144))
 # Common even crop preserves half resolution emission alignment.
 l=min(b[0] for b in boxes)//2*2;t=min(b[1] for b in boxes)//2*2
 rr=(max(b[2] for b in boxes)+1)//2*2;bb=(max(b[3] for b in boxes)+1)//2*2
 w,h=rr-l,bb-t
 for suffix,k in (('',1),('_e',2)):
  src=Image.open(D/(a+suffix+'.png')).convert('RGBA')
  assert src.size==(n*192//k,1536//k)
  if suffix:assert np.max(np.asarray(src)[:,:,:3])>2
  packed=Image.new('RGBA',(n*w//k,8*h//k))
  for d in range(8):
   for f in range(n):packed.paste(src.crop(((f*192+l)//k,(d*192+t)//k,(f*192+rr)//k,(d*192+bb)//k)),(f*w//k,d*h//k))
  packed.save(D/(a+suffix+'.png'),optimize=True,compress_level=9)
 for name in ('averse.tres','averse_emission.tres'):
  path=D/name;s=path.read_text()
  # Existing resource convention uses diffuse coordinates for emission too.
  def patch(m):
   text=m.group(0)
   if 'id="av_action_' not in text:return text
   ext=re.search(r'atlas = ExtResource\("([^"]+)"\)',text)
   if not ext:return text
   resource=re.search(r'\[ext_resource[^\n]*path="[^"]*/'+a+('_e' if 'emission' in name else '')+r'\.png" id="'+ext.group(1)+r'"\]',s)
   if not resource:return text
   r=list(map(int,re.search(r'region = Rect2\(([^)]+)',text).group(1).split(',')))
   return re.sub(r'region = Rect2\([^)]+\)',f'region = Rect2({r[0]//192*w}, {r[1]//192*h}, {w}, {h})\nmargin = Rect2({l}, {t}, {192-w}, {192-h})',text)
  s=re.sub(r'\[sub_resource[^\n]*\]\n.*?(?=\n\[|\Z)',patch,s,flags=re.S);path.write_text(s)
 meta[a]={'frames':n,'directions':8,'cell':[w,h],'crop':[l,t,rr,bb],'durations':[v*12/60 for v in F[a]]}
for name in ('averse.tres','averse_emission.tres'):
 s=(D/name).read_text();assert 'CanvasTexture' not in s and 'normal_texture' not in s
 assert s.count('"name":')==72
 for a,n in N.items():
  for d in ('e','se','s','sw','w','nw','n','ne'):
   entries=list(re.finditer(r'\{"frames":.*?"name": &"([^"]+)".*?\}(?=,\n|\]\s*$)',s,re.S))
   e=next(m.group(0) for m in entries if m.group(1)==a+'_'+d)
   ds=list(map(float,re.findall(r'"duration": ([0-9.]+)',e)));assert ds==[v*12/60 for v in F[a]],(a,d,ds)
 for m in re.finditer(r'\{"frames":.*?"name": &"([^"]+)".*?\}(?=,\n|\]\s*$)',base if name=='averse.tres' else subprocess.check_output(['git','show','HEAD:game/assets/sprites/characters/averse/'+name],cwd=ROOT).decode().replace('\r\n','\n'),re.S):
  if m.group(1).rsplit('_',1)[0] not in N:assert m.group(0) in s,m.group(1)
assert not list(D.glob('*_n.png'))
before=json.loads((ROOT/'art/tools/night/_av1_actions_before.json').read_text())
old=sum(x['bytes'] for x in before.values());new=sum((D/name).stat().st_size for name in before)
assert new<=old*1.3,(old,new)
meta['bytes']=[old,new]
board.save(ROOT/'art/tools/night/_av1_actions_contact.png',optimize=True)
(ROOT/'art/tools/night/_av1_actions_check.json').write_text(json.dumps(meta,indent=1))
print('PASS 208 directional frames; 72 animations/resource; bytes',old,new)
