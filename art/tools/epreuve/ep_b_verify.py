from PIL import Image, ImageChops, ImageDraw
from pathlib import Path
root=Path('game/assets/sprites/props/epreuve'); errors=[]; thumbs=[]
for skin in ('fog_forest','crypts'):
 ims={}
 for state in ('off','lit','done','altar'):
  p=root/f'chase_post_{skin}_{state}.png'; im=Image.open(p).convert('RGBA'); ims[state]=im
  if im.size!=(128,160) or im.getchannel('A').getextrema()[0]!=0: errors.append(f'{p}:dimensions/alpha')
  if state!='off':
   ep=root/f'chase_post_{skin}_{state}_e.png'; e=Image.open(ep).convert('RGBA')
   if e.size==(128,160): e.resize((64,80),Image.Resampling.LANCZOS).save(ep,optimize=True)
   e=Image.open(ep).convert('RGBA')
   if e.size!=(64,80) or e.getchannel('A').getbbox() is None or max(e.getchannel(c).getextrema()[1] for c in 'RGB')==0: errors.append(f'{ep}:size/empty')
  if state!='off' and ImageChops.difference(ims['off'].convert('RGB'),im.convert('RGB')).getbbox() is None: errors.append(f'{skin}/{state}:identical')
 sh=Image.open(root/f'chase_post_{skin}_shadow.png').convert('RGBA')
 if sh.size!=(128,160) or sh.getchannel('A').getbbox() is None: errors.append(f'{skin}:shadow')
 for state,im in ims.items(): thumbs.append((skin+' '+state,im.resize((96,120))))
canvas=Image.new('RGBA',(640,296),(24,24,28,255)); d=ImageDraw.Draw(canvas)
for i,(label,im) in enumerate(thumbs):
 x=i%4*160+32;y=i//4*148+20;canvas.alpha_composite(im,(x,y));d.text((i%4*160+8,i//4*148+4),label,fill=(235,235,235,255))
canvas.convert('RGB').save('art/renders/ep_b_contact.png')
print('FAIL '+'; '.join(errors) if errors else f'PASS: 8 diffuse 128x160 alpha; 6 emission 64x80 nonempty; 6 distinct checks; contact {canvas.width}x{canvas.height}')
