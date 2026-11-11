from pathlib import Path
from PIL import Image,ImageDraw
import json
R=Path(r'C:\Users\const\Documents\Rainfall\.claude\worktrees\agent-aa7c224c816eb5fed');D=R/'game/assets/sprites/props/menu/quai_de_la_cite';W=R/'art/tools/cosmetics';bad=[];margins={}
def check(n,sz):
 p=D/n
 with Image.open(p) as im:
  if im.size!=sz:bad.append(f'{n}:size={im.size}')
  a=im.getchannel('A');b=a.getbbox()
  margins[n]=None if not b else [b[0],b[1],im.width-b[2],im.height-b[3]]
  if b and min(margins[n])<4:bad.append(f'{n}:margin={margins[n]}')
for n,s in [('fire.png',(3072,256)),('fire_e.png',(1536,128)),('barrel.png',(128,128)),('barrel_shadow.png',(128,128)),('crate.png',(128,128)),('crate_shadow.png',(128,128)),('cat.png',(768,96))]:check(n,s)
with Image.open(D/'fire.png') as im:
 crops=[im.crop((i*256,0,(i+1)*256,256)) for i in range(12)]
 if any(c.getchannel('A').getbbox() is None for c in crops):bad.append('empty fire frame')
 for i,c in enumerate(crops):
  b=c.getchannel('A').getbbox()
  if b and not (96<=b[0] and b[2]-1<=158 and 100<=b[1] and b[3]-1<=184):bad.append(f'fire frame {i}:bbox={b}')
 if len({c.tobytes() for c in crops})!=12:bad.append('duplicate fire frames')
for n in ('fire_e.png',):
 with Image.open(D/n) as im:
  if im.convert('RGB').getextrema()==((0,0),(0,0),(0,0)):bad.append(n+':black')
with Image.open(D/'cat.png') as im:
 frames=[im.crop((i*96,0,(i+1)*96,96)) for i in range(8)]
 if len({c.tobytes() for c in frames})!=8:bad.append('duplicate cat frames')
 if any(c.getchannel('A').getbbox() is None for c in frames):bad.append('empty cat frame')
with Image.open(R/'game/assets/sprites/cosmetics/previews/quai_de_la_cite.png') as im:
 if im.size!=(256,256):bad.append(f'preview:size={im.size}')
 # Mean CIELAB L* from the sRGB luminance of the full-frame preview.
 rgb=im.convert('RGB').resize((64,64));vals=[]
 for r,g,b in rgb.getdata():
  q=[v/255 for v in (r,g,b)];q=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in q]
  y=.2126*q[0]+.7152*q[1]+.0722*q[2];v=116*(y**(1/3))-16 if y>.008856 else 903.3*y;vals.append(v)
 mean=sum(vals)/len(vals)
 if not 32<=mean<=55:bad.append(f'preview:Lstar={mean:.1f}')
for n in ('barrel_shadow.png','crate_shadow.png'):
 with Image.open(D/n) as im:
  rgb=im.convert('RGB');
  if not(rgb.getchannel('R').tobytes()==rgb.getchannel('G').tobytes()==rgb.getchannel('B').tobytes()):bad.append(n+':not grayscale')
# Contact: representative assets + three fire frames, neutral background, <=1024 wide
thumbs=[]
for n in ('barrel.png','barrel_shadow.png','cat.png','crate.png','crate_shadow.png'):
 with Image.open(D/n) as im:
  if n=='cat.png':im=im.crop((0,0,96,96))
  thumbs.append(im.convert('RGBA').resize((160,160)))
with Image.open(D/'fire.png') as im:
 for i in (0,5,10):thumbs.append(im.crop((i*256,0,(i+1)*256,256)).resize((160,160)))
out=Image.new('RGBA',(640,480),(70,72,73,255))
for i,im in enumerate(thumbs):out.alpha_composite(im,((i%4)*160,(i//4)*160))
out.convert('RGB').save(W/'_veillee_quai_de_la_cite_contact.png')
print('VERIFY '+json.dumps({'bad':bad,'margins':margins},separators=(',',':')))
