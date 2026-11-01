from pathlib import Path
from PIL import Image
import subprocess,io,json
root=Path(r'C:/Users/const/Documents/Rainfall'); report={}
for n,c in [('coffre_arc',192),('coin_burst',512)]:
 p=root/'game/assets/sprites/characters/avare/effects'/n/(n+'.png'); old=subprocess.check_output(['git','show',f'HEAD:{p.relative_to(root).as_posix()}'])
 with Image.open(io.BytesIO(old)) as a, Image.open(p) as b:
  def m(i): return sum(i.convert('RGBA').getchannel('A').getdata())
  report[n]={'old_px':a.size,'new_px':b.size,'old_bytes':len(old),'new_bytes':p.stat().st_size,'old_alpha':m(a.crop((0,0,c,c))),'new_alpha':m(b.crop((0,0,c,c))),'ratio':round(m(b.crop((0,0,c,c)))/m(a.crop((0,0,c,c))),2)}
print(json.dumps(report))
