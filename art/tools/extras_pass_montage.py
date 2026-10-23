"""Assemblage de controle uniquement; aucune texture de jeu dessinee ici."""
from PIL import Image, ImageDraw
from pathlib import Path
b=Path(__file__).resolve().parents[1]/'renders'
rows=[(n,p.name) for n in ('gold_bag','xp_gem_big','ember_shard') for p in sorted((b/n/'default').glob('x_*.png'))]
out=Image.new('RGB',(650,len(rows)*180+30),(38,38,44));d=ImageDraw.Draw(out)
d.text((200,8),'DIFFUS             NORMALE            EMISSION',fill='white')
for i,(n,f) in enumerate(rows):
 d.text((6,i*180+80),n+' '+f,fill='white')
 for j,kind in enumerate(('default','default_n','default_e')):
  p=b/n/kind/f
  if p.exists():
   im=Image.open(p).convert('RGBA');assert im.size==(48,48)
   im=im.resize((144,144),Image.Resampling.NEAREST);out.paste(im,(195+j*150,30+i*180),im)
 assert Image.open(b/n/'default'/f).getchannel('A').tobytes()==Image.open(b/n/'default_n'/f).getchannel('A').tobytes()
out.save(b/'_extras_pass_montage.png')
print('6 alphas exacts, dimensions 48x48')
