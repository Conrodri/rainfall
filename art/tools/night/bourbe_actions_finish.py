from pathlib import Path
import re, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
D=ROOT/'game/assets/sprites/characters/bourbe'
AN={'slap':7,'attack':7,'throw':7,'cast':7,'recall':7,'sink':7,'rise':7,'cast_ult':9}
F={'slap':[2,2,5,2,4,5,5],'attack':[2,2,5,2,4,5,5],'throw':[3,3,6,2,4,5,5],'cast':[3,3,6,2,4,5,5],'recall':[3,3,6,2,4,5,5],'sink':[3,3,6,2,4,5,5],'rise':[3,3,6,2,4,5,5],'cast_ult':[4,4,4,7,4,5,5,5,5]}
ids={'slap':5,'attack':13,'throw':7,'cast':15,'recall':9,'sink':11,'rise':17,'cast_ult':19}
path=D/'bourbe.tres';raw=path.read_bytes();nl='\r\n' if b'\r\n' in raw else '\n';s=raw.decode('utf8').replace('\r\n','\n').replace('\r','')
pat=r'\{"frames": \[.*?\], "loop": (?:true|false), "name": &"([^"]+)", "speed": [0-9.]+\}'
def replace(m):
 name=m.group(1);a,d=name.rsplit('_',1)
 if a not in AN:return m.group(0)
 n=AN[a];row={'e':0,'se':1,'s':2,'sw':3,'w':4,'nw':5,'n':6,'ne':7}[d]
 frames=', '.join(f'{{"duration": {F[a][f]*.2:.6g}, "texture": SubResource("b{a}_{row}_{f}")}}' for f in range(n))
 return f'{{"frames": [{frames}], "loop": false, "name": &"{name}", "speed": 12.0}}'
s=re.sub(pat,replace,s)
# Remove old canvas wrappers and action atlas resources; retain all other animations/resources.
s=re.sub(r'\[sub_resource type="CanvasTexture" id="c\d+"\]\n[^\[]*?(?=\[)', '', s, flags=re.S)
blocks=list(re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n[^\[]*?(?=\[)',s,re.S))
for m in reversed(blocks):
 if m.group(1).startswith(tuple('b'+a+'_' for a in AN)) or re.search(r'atlas = ExtResource\("(?:5|7|9|11|13|15|17|19)"\)',m.group(0)):s=s[:m.start()]+s[m.end():]
new=[]
for a,n in AN.items():
 for row in range(8):
  for f in range(n):new.append(f'[sub_resource type="AtlasTexture" id="b{a}_{row}_{f}"]\natlas = ExtResource("{ids[a]}")\nregion = Rect2({f*192}, {row*192}, 192, 192)')
s=s.replace('[resource]','\n'.join(new)+'\n\n'+'[resource]',1)
heads=len(re.findall(r'^\[ext_resource',s,re.M));subs=len(re.findall(r'^\[sub_resource',s,re.M))
s=re.sub(r'load_steps=\d+',f'load_steps={heads+subs+1}',s,count=1)
path.write_bytes(re.sub(r'\n{3,}', '\n\n', s).replace('\n',nl).encode())
for a,n in AN.items():
 if not (D/f'{a}.png').exists() or Image.open(D/f'{a}.png').width!=n*192:
  # the cel driver may have only refreshed the work atlas; promote the validated staged sheet
  src=ROOT/'art/blender/cel/heroes_e/stage/characters/bourbe'
  import shutil
  shutil.copy2(src/f'{a}.png',D/f'{a}.png');shutil.copy2(src/f'{a}_e.png',D/f'{a}_e.png')
 if a in ('attack','cast'):
  srcname={'attack':'slap','cast':'throw'}[a]
  import shutil
  shutil.copy2(D/f'{srcname}.png',D/f'{a}.png');shutil.copy2(D/f'{srcname}_e.png',D/f'{a}_e.png')
 for suff,k in (('',1),('_e',2)):
  im=Image.open(D/f'{a}{suff}.png').convert('RGBA');assert im.size==((n*192,1536) if not suff else ((n*192+1)//2,(1536+1)//2)),(a,suff,im.size)
  assert im.getchannel('A').getextrema()[0]==0
  if suff:assert im.getchannel('R').getextrema()[1]>2
  else:
   cells=[]
   for row in range(8):cells.append([hashlib.md5(im.crop((f*192,row*192,(f+1)*192,(row+1)*192)).tobytes()).digest() for f in range(n)])
   assert all(len(set(row))==n for row in cells),a
for a,b in (('attack','slap'),('cast','throw')):
 for suff in ('','_e'):assert (D/f'{a}{suff}.png').read_bytes()==(D/f'{b}{suff}.png').read_bytes()
assert not list(D.glob('*_n.png')) and 'CanvasTexture' not in s and 'normal_texture' not in s
print('PASS action sheets, alpha, emission, aliases, resources')
