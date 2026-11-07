from pathlib import Path
import sys
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[3]; out=root/'game/assets/sprites/icons';pick=root/'game/assets/sprites/pickups';raw=root/'art/renders/forge/raw_f2'
out.mkdir(parents=True,exist_ok=True);pick.mkdir(parents=True,exist_ok=True)
for src,dest,size in [(raw/'storm_icon.png',out/'storm_core.png',256),(raw/'storm_pickup.png',pick/'storm_core.png',64)]:
 im=Image.open(src).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)
 if size==64:
  d=ImageDraw.Draw(im);d.ellipse((10,51,54,59),fill=(45,188,218,45))
 im.save(dest,optimize=True)
def frame(size,path):
 im=Image.new('RGBA',(size,size),(0,0,0,0));d=ImageDraw.Draw(im);s=size
 d.rounded_rectangle((2,2,s-3,s-3),radius=round(s*.14),fill='#211918',outline='#D9803A',width=max(1,s//32))
 d.rounded_rectangle((s*.09,s*.09,s*.91,s*.91),radius=s*.1,outline='#75482F',width=max(1,s//48))
 d.rounded_rectangle((s*.16,s*.16,s*.84,s*.84),radius=s*.065,fill='#30201C',outline='#9C5A35',width=max(1,s//64))
 for x,y in [(s*.12,s*.12),(s*.88,s*.12),(s*.12,s*.88),(s*.88,s*.88)]:
  r=max(2,s*.035);d.ellipse((x-r,y-r,x+r,y+r),fill='#D9803A',outline='#F3B77D',width=max(1,s//64));d.point((x-s*.012,y-s*.012),fill='#563320')
 im.save(path,optimize=True)
frame(128,out/'frame_forge_128.png');frame(64,out/'frame_forge.png')
s=64;im=Image.new('RGBA',(s,s),(0,0,0,0));d=ImageDraw.Draw(im);d.ellipse((2,2,62,62),fill='#9B542D',outline='#F0B879',width=3);d.ellipse((6,6,58,58),outline='#D9803A',width=2);d.polygon([(15,36),(27,36),(30,29),(39,29),(43,36),(49,36),(47,41),(36,43),(31,49),(24,49),(26,42),(18,41)],fill='#F0B879',outline='#FFF0CF');d.line([(47,14),(45,21),(50,23),(44,25),(43,32),(40,26),(34,27),(38,22),(36,16),(41,19)],fill='#FFF0CF',width=2);im.save(out/'forge_ready.png',optimize=True)
names=[out/'storm_core.png',pick/'storm_core.png',out/'frame_forge_128.png',out/'frame_forge.png',out/'forge_ready.png'];sheet=Image.new('RGBA',(950,205),(24,24,28,255))
for i,p in enumerate(names):
 a=Image.open(p).convert('RGBA');a.thumbnail((180,180));bg=Image.new('RGBA',(190,205),(48,48,52,255));bg.alpha_composite(a,((190-a.width)//2,4));ImageDraw.Draw(bg).text((4,188),p.name,fill='white');sheet.alpha_composite(bg,(190*i,0))
sheet.save(root/'art/renders/forge/f2_contact.png',optimize=True)
bad=[]
expected=[(256,256),(64,64),(128,128),(64,64),(64,64)]
for p,dim in zip(names,expected):
 a=Image.open(p).convert('RGBA')
 if a.size!=dim or a.getchannel('A').getextrema()==(0,0) or p.stat().st_size>40960:bad.append(p.name)
if bad:raise RuntimeError('asset check failed: '+','.join(bad))
print('PASS 5 PNG dimensions alpha <=40KB; contact 950px')
