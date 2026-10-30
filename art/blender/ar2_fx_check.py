from pathlib import Path
from PIL import Image,ImageStat
import json,hashlib,re
R=Path('C:/Users/const/Documents/Rainfall');F=R/'game/assets/sprites/characters/arpenteuse/effects';out=R/'art/blender';base=json.loads((out/'characters/ar2_fx_baseline.json').read_text());report={};board=Image.new('RGBA',(896,6*136),(35,32,31,255))
for row,(name,n) in enumerate([('chain_tile',4),('chain_snap',6),('chain_rewind',6),('loop_blaze',6),('peg_burst',6)]):
 p=F/(name+'.png');im=Image.open(p).convert('RGBA');e=Image.open(F/(name+'_e.png')).convert('RGBA');cw=im.width//n
 assert e.size in [im.size,((im.width+1)//2,(im.height+1)//2)]
 assert e.getbbox() and max(e.getchannel('R').getextrema())>10
 hashes=set();counts=[]
 for f in range(n):
  cell=im.crop((f*cw,0,(f+1)*cw,im.height));assert cell.getbbox();hashes.add(hashlib.sha256(cell.tobytes()).hexdigest());counts.append(sum(v>16 for v in cell.getchannel('A').getdata()))
  cell.thumbnail((128,128));board.alpha_composite(cell,(f*144,row*136))
 assert len(hashes)==n
 text=(F/(name+'.tres')).read_text();assert 'CanvasTexture' not in text and 'normal_texture' not in text
 assert not (F/(name+'_n.png')).exists()
 ratio=round(sum((F/(name+q+'.png')).stat().st_size for q in ('','_e'))/sum(base[name].values()),3) if name in base else None
 report[name]={'size':im.size,'emission':e.size,'distinct':len(hashes),'bytes':p.stat().st_size,'budget_ratio':ratio,'alpha_pixels':counts}
idle=R/'game/assets/sprites/characters/arpenteuse/idle.png'
if idle.exists():
 im=Image.open(idle);cell=im.crop((0,0,im.width//8,im.height//8));cell.thumbnail((128,128));board.alpha_composite(cell,(0,680))
board.convert('RGB').save(out/'ar2_fx_contact.jpg',quality=90)
(out/'ar2_fx_verification.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
