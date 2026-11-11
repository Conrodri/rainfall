from pathlib import Path
import numpy as np
from PIL import Image
root=Path(__file__).parents[3]
sky=np.array(Image.open(root/'game/assets/sprites/ambiance/sky_canicule_de_cendres_256x64.png').convert('RGBA'),dtype=np.int16)
preview=np.array(Image.open(root/'game/assets/sprites/cosmetics/previews/canicule_de_cendres.png').convert('RGBA'),dtype=np.int16)
tile=np.array(Image.open(root/'game/assets/sprites/ambiance/heat_haze_tile_512.png').convert('RGBA'),dtype=np.int16)
assert sky.shape==(64,256,4) and preview.shape==(256,256,4) and tile.shape==(512,512,4)
assert min(sky[...,3].min(),preview[...,3].min(),tile[...,3].min())==255
seam=int(max(np.abs(sky[:,0]-sky[:,-1]).max(),np.abs(tile[:,0]-tile[:,-1]).max(),np.abs(tile[0]-tile[-1]).max()))
gray=int(max(np.abs(tile[...,0]-tile[...,1]).max(),np.abs(tile[...,1]-tile[...,2]).max()))
def lstar(a):
 c=a[...,:3]/255; c=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4); y=.2126*c[...,0]+.7152*c[...,1]+.0722*c[...,2]; return 116*np.cbrt(y)-16
sl,pl=lstar(sky),lstar(preview)
warm=((preview[...,0]>=preview[...,1])&(preview[...,1]>preview[...,2])&((preview[...,0]-preview[...,2])>20)).sum()
avg=float(tile[...,0].mean()/255)
assert np.abs(sky[:,0]-sky[:,-1]).max()<2
assert sl.mean()>=25 and sl.min()>=18 and pl.mean()>=32
assert gray==0 and seam<2 and .3<=avg<=.8 and abs(avg-.5)<.08
assert warm>=250
# One final control sheet, sky x3 beside preview, maximum width 1024.
si=Image.open(root/'game/assets/sprites/ambiance/sky_canicule_de_cendres_256x64.png').convert('RGB').resize((768,192),Image.Resampling.NEAREST)
pi=Image.open(root/'game/assets/sprites/cosmetics/previews/canicule_de_cendres.png').convert('RGB').resize((192,192),Image.Resampling.LANCZOS)
board=Image.new('RGB',(960,192),(30,24,18)); board.paste(si,(0,0)); board.paste(pi,(768,0)); board.save(root/'art/tools/cosmetics/_ciel_canicule_de_cendres_contact.png')
print(f'PASS sky seam={np.abs(sky[:,0]-sky[:,-1]).max()} L*={sl.mean():.1f}/{sl.min():.1f}; preview L*={pl.mean():.1f} warm={warm}; tile seam={seam} gray={gray} mean={avg:.3f}; contact=960x192')
