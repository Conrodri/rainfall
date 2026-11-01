from pathlib import Path
from PIL import Image
import numpy as np
root=Path(__file__).parents[3]
paths=[root/'game/assets/sprites/ambiance/sky_nuit_de_lanternes_256x64.png',root/'game/assets/sprites/ambiance/lantern_glow_64.png',root/'game/assets/sprites/cosmetics/previews/nuit_de_lanternes.png']
ims=[Image.open(p).convert('RGBA') for p in paths]
assert [i.size for i in ims]==[(256,64),(64,64),(256,256)]
sky,glow,preview=[np.asarray(i).astype(np.int16) for i in ims]
assert np.max(np.abs(sky[:,0]-sky[:,-1]))<2 and sky[...,3].min()>=250
assert np.array_equal(glow[...,0],glow[::-1,:,0]) and np.array_equal(glow[...,0],glow[:,::-1,0])
assert glow[31,31,0]>glow[31,31,2] and glow[31,31,3]>=254 and glow[0,0,3]==0
def lstar(a):
 c=a[...,:3]/255.; y=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4); return 116*np.cbrt(.2126*y[...,0]+.7152*y[...,1]+.0722*y[...,2])-16
ls,lp=float(lstar(sky).mean()),float(lstar(preview).mean())
assert ls>=25 and lp>=32,(ls,lp)
luma=116*(.2126*np.where(sky[...,0]/255<=.04045,sky[...,0]/255/12.92,((sky[...,0]/255+.055)/1.055)**2.4)+.7152*np.where(sky[...,1]/255<=.04045,sky[...,1]/255/12.92,((sky[...,1]/255+.055)/1.055)**2.4)+.0722*np.where(sky[...,2]/255<=.04045,sky[...,2]/255/12.92,((sky[...,2]/255+.055)/1.055)**2.4))**(1/3)-16
assert np.count_nonzero(luma>85)>=40
rgbp=preview[...,:3]/255.; mx=rgbp.max(axis=2); mn=rgbp.min(axis=2); sat=np.where(mx>0,(mx-mn)/mx,0); hue=np.zeros(mx.shape); d=mx-mn
sel=(mx==rgbp[...,0])&(d>0); hue[sel]=((rgbp[...,1][sel]-rgbp[...,2][sel])/d[sel])%6
sel=(mx==rgbp[...,1])&(d>0); hue[sel]=(rgbp[...,2][sel]-rgbp[...,0][sel])/d[sel]+2
sel=(mx==rgbp[...,2])&(d>0); hue[sel]=(rgbp[...,0][sel]-rgbp[...,1][sel])/d[sel]+4
hue*=60
assert np.count_nonzero((hue>=25)&(hue<=45)&(sat>.5))>=250
assert all(Image.open(p).format=='PNG' for p in paths)
bright=lstar(sky)>85
y,x=np.where(bright); mw=int(x.max()-x.min()+1); mh=int(y.max()-y.min()+1)
assert abs(mw-mh)<=1,(mw,mh)
assert lstar(sky).min()>=18,lstar(sky).min()
assert preview[...,3].min()==255
amber=int(np.count_nonzero((hue>=25)&(hue<=45)&(sat>.5)))
# Single final contact: repeated sky, original halo composited, preview.
board=Image.new('RGB',(768,340),(70,75,85))
for i in range(3): board.paste(ims[0],(256*i,0))
back=Image.new('RGBA',(96,96),(22,31,49,255)); back.alpha_composite(ims[1],(16,16)); board.paste(back.convert('RGB'),(40,100))
board.paste(ims[2],(256,80),ims[2]); board.save(root/'art/tools/cosmetics/_ciel_nuit_de_lanternes_contact.png')
import json
before=json.loads((root/'art/renders/cosmetics/ciel/ambiance_mtime_before.json').read_text())
changed=[p for p in (root/'game/assets/sprites/ambiance').iterdir() if p.is_file() and (p.name not in before or p.stat().st_mtime_ns!=before[p.name])]
assert {p.name for p in changed}=={'sky_nuit_de_lanternes_256x64.png','lantern_glow_64.png'},[p.name for p in changed]
print('PASS 256x64 / 64x64 / 256x256 RGBA; seam=%d/255; L* sky=%.2f min=%.2f preview=%.2f; moon=%dx%d bright=%d; amber=%d; contact=768x340'%(np.max(np.abs(sky[:,0]-sky[:,-1])),ls,lstar(sky).min(),lp,mw,mh,bright.sum(),amber))
for p in changed: print(p.name,p.stat().st_mtime_ns)
