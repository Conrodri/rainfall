from pathlib import Path
from PIL import Image,ImageDraw
import math
root=Path(r'C:\Users\const\Documents\Rainfall\.claude\worktrees\agent-aa7c224c816eb5fed')
out=root/'game/assets/sprites/props/menu/lanternes_de_riziere'
checks=[]; margins={}
def check(label,ok): checks.append((label,bool(ok)))
def inspect(name,expected):
    with Image.open(out/name) as im:
      im=im.convert('RGBA');check(name+' size',im.size==expected);a=im.getchannel('A');b=a.getbbox();m=(b[0],b[1],im.width-b[2],im.height-b[3]) if b else (0,0,0,0);margins[name]=m;check(name+' nonempty',b is not None);check(name+' margins4',b is not None and min(m)>=4) if name not in ('fire.png','fire_e.png') else None;return im.copy()
fire=inspect('fire.png',(3072,256));fe=inspect('fire_e.png',(1536,128));check('fire_e nonblack',fe.getbbox() is not None)
frames=[]
for i in range(12):
 f=fire.crop((i*256,0,(i+1)*256,256));check('frame'+str(i)+' nonempty',f.getchannel('A').getbbox() is not None);frames.append(f)
check('12 distinct frames',len({x.tobytes() for x in frames})==12)
for i,f in enumerate(frames):
 b=f.getchannel('A').getbbox();check('frame'+str(i)+' margins8',b is not None and min(b[0],b[1],256-b[2],256-b[3])>=8)
 if b:check('frame'+str(i)+' height approx120',105<=b[3]-b[1]<=140);check('frame'+str(i)+' pivot70',abs(b[3]-179)<=20)
check('no normal files',not list(out.glob('*_n.png')))
# Contact sheet from generated assets; no resized deliverables.
thumbs=[frames[i].resize((120,120)) for i in [0,3,6,9]]
sheet=Image.new('RGBA',(520,160),(48,55,42,255));x=10
for im in thumbs:sheet.alpha_composite(im,(x,20));x+=im.width+5
sheet.convert('RGB').save(root/'art/tools/cosmetics/_veillee_lanternes_de_riziere_contact.png')
print('VERIFY '+('PASS' if all(ok for _,ok in checks) else 'FAIL')+' checks='+str(len(checks))+' failed='+','.join(n for n,ok in checks if not ok)+' margins='+str(margins))
