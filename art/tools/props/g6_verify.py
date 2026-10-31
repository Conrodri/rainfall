from pathlib import Path
from PIL import Image, ImageStat
import hashlib, sys
root=Path(__file__).resolve().parents[3]
out=root/'game/assets/sprites/props/secret'
sys.path.insert(0,str(root/'art/tools/cel'))
import cel_style as cel
# Contract sizes, alpha, content, frames, no normals.
for stem,size in [('lever_fog_forest_off',(128,128)),('lever_fog_forest_on',(128,128)),('lever_fog_forest_off_shadow',(128,128)),('lever_fog_forest_on_shadow',(128,128)),('wall_fog_forest_0',(256,256)),('wall_fog_forest_1',(256,256)),('wall_fog_forest_2',(256,256)),('wall_fog_forest_break',(1280,256))]:
 im=Image.open(out/f'{stem}.png').convert('RGBA'); assert im.size==size,(stem,im.size)
 assert im.getchannel('A').getbbox(),stem
for stem,size in [('wall_fog_forest_1_e',(128,128)),('wall_fog_forest_2_e',(128,128)),('wall_fog_forest_break_e',(640,128))]:
 im=Image.open(out/f'{stem}.png').convert('RGBA'); assert im.size==size,(stem,im.size)
 assert im.getchannel('A').getbbox() and sum(ImageStat.Stat(im.convert('RGB')).mean)>2,stem
assert not list(out.glob('*_fog_forest_*_n.png'))
wall=Image.open(out/'wall_fog_forest_break.png').convert('RGBA')
assert len({hashlib.sha256(wall.crop((i*256,0,(i+1)*256,256)).tobytes()).hexdigest() for i in range(5)})==5
# Mycelium fades during collapse; final frames contain no light.
em=Image.open(out/'wall_fog_forest_break_e.png').convert('RGBA')
energy=[sum(sum(px[:3])*px[3]/255 for px in em.crop((i*128,0,(i+1)*128,128)).getdata()) for i in range(5)]
assert energy[0]>energy[1]>energy[2]>0 and energy[3]==energy[4]==0,energy
for name in ('wall_fog_forest_1.png','wall_fog_forest_2.png','wall_fog_forest_break.png'):
 im=Image.open(out/name).convert('RGBA')
 for i in range(im.width//256):
  frame=im.crop((i*256,0,(i+1)*256,256));assert frame.getchannel('A').getbbox()
  assert frame.getchannel('A').getpixel((0,0))==0
  assert max(ImageStat.Stat(frame.convert('RGB'),frame.getchannel('A')).stddev)>5
# Existing archive/new comparison, intact states and five collapse frames.
before=root/'art/archive_3d/sprites/props/secret'; names=['wall_fog_forest_0.png','wall_fog_forest_1.png','wall_fog_forest_2.png','wall_fog_forest_break.png']
canvas=Image.new('RGBA',(1024,256),(24,24,28,255))
for row,base in enumerate((before,out)):
 for col,name in enumerate(names):
  p=base/name
  if p.exists():
   im=Image.open(p).convert('RGBA')
   if col==3:
    for frame in range(5):
     cell=im.crop((frame*256,0,(frame+1)*256,256));cell.thumbnail((128,128),Image.Resampling.LANCZOS);canvas.alpha_composite(cell,((3+frame)*128,row*128))
   else:
    im.thumbnail((128,128),Image.Resampling.LANCZOS);canvas.alpha_composite(im,(col*128,row*128))
(root/'art/renders/grotte').mkdir(parents=True,exist_ok=True);canvas.save(root/'art/renders/grotte/g6_avant_apres.png')
print('PASS G6 sizes alpha emission frames normals contacts')

