from pathlib import Path
from PIL import Image, ImageStat
import hashlib, json
R=Path(__file__).resolve().parents[3]; T=R/'art/renders/ep_i_tiles'; V=R/'game/assets/sprites/vfx/epreuve'
names=[]; checks={}
for skin in ('fog_forest','crypts'):
 name='chase_light_'+skin; frames=[Image.open(T/f'{name}_{i}.png').convert('RGBA').resize((96,96),Image.Resampling.LANCZOS) for i in range(8)]
 sheet=Image.new('RGBA',(768,96))
 for i,im in enumerate(frames):
  assert im.getpixel((48,48))[3]>=250, (name,i,'center')
  assert im.getpixel((0,0))[3]==0
  assert max(ImageStat.Stat(im.convert('RGB'),im.getchannel('A')).stddev)>15
  sheet.paste(im,(i*96,0))
 assert len({hashlib.sha256(im.tobytes()).digest() for im in frames})==8
 sheet.save(V/(name+'.png'),optimize=True); names.append(name)
 checks[name]={'size':sheet.size,'distinct':8,'center_opaque':True}
for name in ('ring_zone','ring_wave'):
 im=Image.open(T/(name+'.png')).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
 assert im.getpixel((0,0))[3]==0
 assert im.getpixel((128,128))[3]==0
 assert im.getextrema()[3][1]>200
 im.save(V/(name+'.png'),optimize=True); names.append(name); checks[name]={'size':im.size,'hollow':True}
size=sum((V/(n+'.png')).stat().st_size for n in names); assert size<=1048576
# Contact assembly over the project's actual dark ground texture.
ground=Image.open(R/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
contact=Image.new('RGBA',(768,448),(22,24,28,255))
for y in range(0,448,ground.height):
 for x in range(0,768,ground.width): contact.alpha_composite(ground,(x,y))
for y,name in zip((0,96),names[:2]): contact.alpha_composite(Image.open(V/(name+'.png')),(0,y))
for x,name in zip((96,416),names[2:]): contact.alpha_composite(Image.open(V/(name+'.png')),(x,192))
contact.convert('RGB').save(R/'art/renders/ep_i_contact.png',optimize=True)
checks['bytes']=size; (R/'art/renders/ep_i_verification.json').write_text(json.dumps(checks,indent=2))
print(f'PASS EP-I: 4 PNG; 8+8 distinct frames; alpha/contrast; {size} bytes; contact 768x448')


