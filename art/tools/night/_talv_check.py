from pathlib import Path
from PIL import Image
import re,json
root=Path('game/assets/sprites/characters/morfil/variants')
contact=Image.new('RGBA',(960,540),(27,31,28,255));report={}
for row,(name,w,h,n,cols) in enumerate([('cut_kesa',768,768,6,3),('cut_cleave',704,192,6,3),('temper_sheen',128,128,4,4)]):
 p=root/name;im=Image.open(p/'default.png').convert('RGBA');em=Image.open(p/'default_e.png').convert('RGBA');txt=(p/(name+'.tres')).read_text()
 assert im.size==(cols*w,((n+cols-1)//cols)*h)
 assert em.size==((im.width+1)//2,(im.height+1)//2)
 assert max(im.size)<=4096 and not list(p.glob('*_n.png'))
 assert 'CanvasTexture' not in txt and 'normal_texture' not in txt
 assert len(re.findall('type="AtlasTexture"',txt))==n
 assert em.getbbox() and max(em.convert('RGB').getextrema()[c][1] for c in range(3))>2
 bounds=[]
 for f in range(n):
  cell=im.crop((f%cols*w,f//cols*h,(f%cols+1)*w,(f//cols+1)*h));assert cell.getbbox();bounds.append(cell.getbbox())
  cell.thumbnail((155,175));contact.alpha_composite(cell,(f*160+(155-cell.width)//2,row*180+(175-cell.height)//2))
 report[name]={'diffuse':im.size,'emission':em.size,'frames':n,'bounds':bounds}
contact.convert('RGB').save('art/tools/night/_talv_contact.png')
Path('art/tools/night/_talv_verification.json').write_text(json.dumps(report,indent=2))
print('PASS TALV: 16 frames, atlas, emission, resources, no normals')
