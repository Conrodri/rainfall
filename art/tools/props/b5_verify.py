from pathlib import Path
import subprocess,io,json
from PIL import Image
import numpy as np
R=Path.cwd(); board=Image.new('RGBA',(864,400),(35,32,35,255))
specs=[('rust_city','rails',(400,224)),('crypts','crypt_stairs',(400,304)),('fog_forest','pontoon',(400,272)),('terraces','stone_stairs',(432,384))]
for i,(folder,name,size) in enumerate(specs):
 p=Path('game/assets/sprites/props')/folder/(name+'.png');new=Image.open(p).convert('RGBA'); old=Image.open(io.BytesIO(subprocess.check_output(['git','show','HEAD:'+p.as_posix()]))).convert('RGBA')
 assert new.size==old.size==size
 a=np.array(new); mask=a[:,:,3]>20;assert mask.any() and (~mask).any() and np.ptp(a[:,:,:3][mask])>50
 assert new.tobytes()!=old.tobytes()
 y,x=np.where(mask);cov=np.cov(x,y)[0,1];yo,xo=np.where(np.array(old)[:,:,3]>20);prev=np.cov(xo,yo)[0,1]
 assert cov<0 and prev>0,(name,cov,prev)
 sh=Image.open(p.with_name(name+'_shadow.png')).convert('RGBA');assert sh.size==(512,512) and 0<np.array(sh)[:,:,3].max()<=140
 assert not p.with_name(name+'_n.png').exists()
 for row,im in enumerate((old,new)):
  im=im.copy();im.thumbnail((216,194));board.alpha_composite(im,(i*216+(216-im.width)//2,row*200+(200-im.height)//2))
board.save('art/renders/props_b/b5_codex.png')
print('PASS 4 canvases; alpha contrast distinct; axis covariance + to -; shadows 512x512 alpha <= 140; no normals')
