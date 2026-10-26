from pathlib import Path
import re,hashlib,json
from PIL import Image
import numpy as np
root=Path('.');names=['leaper_tier2','leaper_tier2_moss','leaper_tier2_rust']
for name in names:
 p=root/'game/assets/sprites/monsters'/name
 s=(p/(name+'.tres')).read_text();assert len(re.findall('"name": &"attack_',s))==8
 assert 'CanvasTexture' not in s and 'normal_texture' not in s and not list(p.glob('*_n.png'))
 assert Image.open(p/'attack.png').size==(896,896)
 e=Image.open(p/'attack_e.png');assert e.size==(448,448)
 a=np.array(e);assert (a[:,:,:3]* (a[:,:,3:4]/255)).max()>2
 for row in range(8):
  im=Image.open(p/'attack.png');cells=[im.crop((f*112,row*112,(f+1)*112,(row+1)*112)) for f in range(8)]
  assert all(c.getbbox() for c in cells)
  assert len({hashlib.sha256(c.tobytes()).hexdigest() for c in cells})>=7
print('PASS MB1 sizes, masks, 24 animations, cells, normals absent')
