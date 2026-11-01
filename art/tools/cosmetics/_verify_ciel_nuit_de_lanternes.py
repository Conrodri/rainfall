from PIL import Image, ImageChops
from pathlib import Path
import numpy as np
root=Path(__file__).parents[3]
files=[root/'game/assets/sprites/ambiance/sky_nuit_de_lanternes_256x64.png',root/'game/assets/sprites/ambiance/lantern_glow_64.png',root/'game/assets/sprites/cosmetics/previews/nuit_de_lanternes.png']
ims=[Image.open(p).convert('RGBA') for p in files]
expected=[(256,64),(64,64),(256,256)]
assert [i.size for i in ims]==expected,[(p.name,i.size) for p,i in zip(files,ims)]
sky=np.asarray(ims[0]).astype(np.int16); assert np.max(np.abs(sky[:,0]-sky[:,-1])) < 2, int(np.max(np.abs(sky[:,0]-sky[:,-1])))
assert sky[...,3].min()>=250
glow=np.asarray(ims[1]); assert np.array_equal(glow[...,0],glow[...,1]) and np.array_equal(glow[...,1],glow[...,2]); assert np.max(np.abs(glow[...,3].astype(int)-(255-glow[...,0].astype(int))))<=1
assert np.max(np.abs(glow[...,0].astype(int)-glow[::-1,:,0].astype(int)))<=1
assert np.max(np.abs(glow[...,0].astype(int)-glow[:,::-1,0].astype(int)))<=1
assert glow[...,3].max()==255 and glow[0,0,3]==255 and glow[31,31,0]==255
assert len(np.unique(np.asarray(ims[2]).reshape(-1,4),axis=0))>128
# Ne touche aucune image source: planche réduite 768 px max.
thumbs=[]
for im in ims:
 im.thumbnail((256,256),Image.Resampling.LANCZOS); thumbs.append(im.copy())
sheet=Image.new('RGBA',(768,256),(24,28,38,255))
for j,im in enumerate(thumbs): sheet.alpha_composite(im,(j*256,0))
sheet.convert('RGB').save(root/'art/tools/cosmetics/_ciel_nuit_de_lanternes_contact.png',optimize=True)
print('PASS dims alpha sky_x glow_symmetry scene contact=768x256')
for p in files: print(p.name,p.stat().st_size,'bytes',Image.open(p).size)





