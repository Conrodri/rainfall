from PIL import Image, ImageChops, ImageDraw
from pathlib import Path
P=Path('game/assets/sprites/props/epreuve'); V=Path('game/assets/sprites/vfx/epreuve'); errors=[]; thumbs=[]
def check(path,size,label):
 im=Image.open(path).convert('RGBA')
 if im.size!=size: errors.append(f'{path.name}:size{im.size}')
 if im.getchannel('A').getbbox() is None: errors.append(f'{path.name}:alpha-empty')
 thumbs.append((label,im))
 return im
for skin in ('fog_forest','crypts'):
 ims=[]
 for state in ('off','on'):
  im=check(P/f'vein_source_{skin}_{state}.png',(128,160),skin+' '+state); ims.append(im)
 if ImageChops.difference(ims[0],ims[1]).getbbox() is None: errors.append(skin+':same')
 e=check(P/f'vein_source_{skin}_on_e.png',(64,80),skin+' e')
 if e.getchannel('A').getbbox() is None or max(e.getchannel(c).getextrema()[1] for c in 'RGB')<100: errors.append(skin+':weak e')
 gey=check(V/f'vein_geyser_{skin}.png',(768,192),skin+' geyser')
 frames=[gey.crop((i*128,0,(i+1)*128,192)) for i in range(6)]
 if any(ImageChops.difference(frames[i],frames[i+1]).getbbox() is None for i in range(5)): errors.append(skin+':duplicate geyser')
 bell=[]
 for st in ('off','dim'):
  im=check(P/f'hold_bell_rust_city_{st}.png',(160,224),'bell '+st); bell.append(im)
 ringing=check(P/'hold_bell_rust_city_ringing.png',(640,224),'bell ring')
 frames=[ringing.crop((i*160,0,(i+1)*160,224)) for i in range(4)]
 if any(ImageChops.difference(frames[i],frames[i+1]).getbbox() is None for i in range(3)): errors.append('bell:duplicate ring')
check(P/'hold_bell_rust_city_ringing_e.png',(320,112),'bell glow')
# Compose one compact contact sheet, width 1024.
small=[]
for label,im in thumbs:
 im.thumbnail((128,128)); small.append((label,im.copy()))
w=1024; cellw=128; cellh=150; rows=(len(small)+7)//8
canvas=Image.new('RGBA',(w,rows*cellh),(25,25,30,255)); d=ImageDraw.Draw(canvas)
for i,(label,im) in enumerate(small):
 x=i%8*cellw; y=i//8*cellh; canvas.alpha_composite(im,(x,y)); d.text((x+2,y+129),label,fill='white')
canvas.convert('RGB').save('art/renders/ep_d_contact.png',optimize=True)
# requested E contact overwritten after D inspection order.
# Create separate crop sheet from E frames, cap 1024.
parts=[('off',bell[0]),('dim',bell[1])]+[(f'ring{i}',f) for i,f in enumerate(frames)]
ecan=Image.new('RGB',(640,224),(25,25,30))
for i,(label,im) in enumerate(parts):
 x=(i%4)*160; y=(i//4)*112
 im.thumbnail((160,112)); ecan.paste(im.convert('RGB'),(x,y))
ecan.save('art/renders/ep_e_contact.png',optimize=True)
print('FAIL '+','.join(errors) if errors else f'PASS checked source=4+2e geyser=12 bell=6+e contacts=1024x{canvas.height},640x224')
