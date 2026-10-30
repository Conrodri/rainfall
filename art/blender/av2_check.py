import warnings
warnings.filterwarnings('ignore',category=DeprecationWarning)
from pathlib import Path
import re,hashlib,json
from PIL import Image,ImageStat
ROOT=Path('C:/Users/const/Documents/Rainfall'); b=ROOT/'game/assets/sprites/characters/averse/effects'; results={}
for k in ('wave_cone','puddle_mirror','crue_ring'):
 s=(b/k/(k+'.tres')).read_text(); assert 'normal_texture' not in s and 'CanvasTexture' not in s
 ext={i:b/k/Path(p).name for p,i in re.findall(r'\[ext_resource[^\n]*path="([^"]+)" id="([^"]+)"',s)}
 hashes=[]; contrast=[]
 for block in re.findall(r'\[sub_resource type="AtlasTexture"[^\]]*\]([^\[]+)',s):
  p=ext[re.search(r'ExtResource\("([^"]+)"\)',block)[1]];x,y,w,h=map(int,re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(',')); im=Image.open(p).convert('RGBA'); tile=im.crop((x,y,x+w,y+h)); a=tile.getchannel('A'); assert a.getbbox() and a.getextrema()[0]==0
  hashes.append(hashlib.sha256(tile.tobytes()).hexdigest()); colors=[v[:3] for v in tile.getdata() if v[3]>200]; lum=[sum(v) for v in colors]; assert max(lum)-min(lum)>100;contrast.append(max(lum)-min(lum))
 assert len(set(hashes))==len(hashes),(k,'duplicate')
 for p in set(ext.values()):
  im=Image.open(p);e=Image.open(p.with_name(p.stem+'_e.png')).convert('RGBA');assert e.size==((im.width+1)//2,(im.height+1)//2);assert any(max(v[:3])*v[3]>512 for v in e.getdata());assert not list((b/k).glob('*_n.png'))
 results[k]={'frames':len(hashes),'unique':len(set(hashes)),'contrast_min':min(contrast)}
baseline=json.loads((ROOT/'art/blender/av2_baseline.json').read_text()); budgets=[]
for rel,meta in baseline.items():
 p=b/rel
 if p.suffix=='.tres':assert hashlib.sha256(p.read_bytes()).hexdigest()==meta['sha'],(rel,'resource changed')
 else:
  assert list(Image.open(p).size)==meta['size'],(rel,'dimensions changed')
  if p.stat().st_size>meta['bytes']*1.3:budgets.append((rel,meta['bytes'],p.stat().st_size))
board=Image.new('RGBA',(960,576),(19,24,28,255))
for row,k in enumerate(('wave_cone','puddle_mirror','crue_ring')):
 s=(b/k/(k+'.tres')).read_text();ext={i:b/k/Path(v).name for v,i in re.findall(r'\[ext_resource[^\n]*path="([^"]+)" id="([^"]+)"',s)}
 blocks=re.findall(r'\[sub_resource type="AtlasTexture"[^\]]*\]([^\[]+)',s);n=6 if k!='crue_ring' else 8
 energies=[]
 for f,block in enumerate(blocks[:n]):
  p=ext[re.search(r'ExtResource\("([^"]+)"\)',block)[1]];x,y,w,h=map(int,re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(','))
  import numpy as np
  e=Image.open(p.with_name(p.stem+'_e.png')).convert('RGBA');arr=np.asarray(e.crop((x//2,y//2,(x+w)//2,(y+h)//2)),dtype=float);energies.append(float((arr[:,:,:3].sum(2)*arr[:,:,3]/255).sum()))
  if f in (0,n//2,n-1):
   tile=Image.open(p).convert('RGBA').crop((x,y,x+w,y+h));tile.thumbnail((300,180),Image.Resampling.LANCZOS);col=0 if f==0 else 1 if f==n//2 else 2;board.alpha_composite(tile,(col*320+(300-tile.width)//2,row*192))
 assert max(energies)==energies[0],(k,'frame0 peak',energies)
 results[k]['emission_energy']=[round(v) for v in energies]
board.save(ROOT/'art/blender/characters/averse_av2_water_final/control.png',optimize=True)
print('PASS '+json.dumps(results)+'; per-file budget exceptions '+json.dumps(budgets))
