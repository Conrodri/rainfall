from pathlib import Path
from PIL import Image
import subprocess,io,json
root=Path(r'C:/Users/const/Documents/Rainfall'); names=['coffre_arc','coin_burst']; report={}
board=Image.new('RGBA',(1024,512),(22,24,29,255))
for i,name in enumerate(names):
 p=root/'game/assets/sprites/characters/avare/effects'/name/(name+'.png'); old=subprocess.check_output(['git','show',f'HEAD:{p.relative_to(root).as_posix()}'])
 with Image.open(io.BytesIO(old)) as a, Image.open(p) as b:
  cell=192 if name=='coffre_arc' else 512
  def mass(im): return sum(px[3] for px in im.convert('RGBA').getdata())
  aa=a.crop((0,0,cell,cell)); bb=b.crop((0,0,cell,cell))
  report[name]={'dims':b.size,'oldbytes':len(old),'newbytes':p.stat().st_size,'mass_ratio':round(mass(bb)/max(1,mass(aa)),2),'headmass':mass(aa),'newmass':mass(bb)}
  board.alpha_composite(bb.resize((512,512)),(i*512,0))
board.save(root/'art/renders/feel_sorts2/after_vfx_avare.png',optimize=True)
(root/'art/blender/feel2/rv2_avare/measurements.json').write_text(json.dumps(report)); print(json.dumps(report))
