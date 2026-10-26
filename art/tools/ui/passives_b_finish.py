"""Raster finishing: only crop, resize, assemble, verify."""
import sys,json
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'art/blender/cel/passives_b';OUT=ROOT/'game/assets/sprites/ui/icons/passives'
NAMES=['souffle','bourse','masse','fils','braise']
if len(sys.argv)>1:
 name=sys.argv[1];im=Image.open(WORK/(name+'_raw.png')).convert('RGBA');box=im.getbbox()
 def fit(src,size):
  a=Image.open(src).convert('RGBA').crop(box).resize((111,112),Image.Resampling.LANCZOS)
  out=Image.new('RGBA',(128,128));out.paste(a,(10,8));return out.resize(size,Image.Resampling.LANCZOS)
 fit(WORK/(name+'_raw.png'),(128,128)).save(OUT/(name+'.png'))
 e=next(WORK.glob(name+'_e__*.png'));fit(e,(64,64)).save(OUT/(name+'_e.png'))
else:
 sheet=Image.new('RGB',(720,300),(20,17,12));rows=[]
 for i,name in enumerate(NAMES):
  im=Image.open(OUT/(name+'.png'));e=Image.open(OUT/(name+'_e.png'))
  assert im.mode=='RGBA' and im.size==(128,128) and im.getbbox()==(10,8,121,120),(name,im.getbbox())
  assert e.size==(64,64) and max(max(p[:3]) for p in e.getdata())>2
  assert not (OUT/(name+'_n.png')).exists()
  for size,y in [(128,4),(72,145),(48,235)]:
   a=im.resize((size,size),Image.Resampling.LANCZOS);sheet.paste(a,(i*144+(144-size)//2,y),a)
  rows.append({'id':name,'size':im.size,'bbox':im.getbbox(),'emission':e.size})
 sheet.save(Path(__file__).with_name('passives_b_contact.png'))
 Path(__file__).with_name('passives_b_verification.json').write_text(json.dumps(rows,indent=2))
 print('PASS 5 RGBA 128x128; bbox (10, 8, 121, 120); emission 64x64; no normals')
