from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np, colorsys
root=Path(__file__).parents[3]; ps=[root/'game/assets/sprites/ambiance/sky_maree_haute_256x64.png',root/'game/assets/sprites/cosmetics/previews/maree_haute.png']; ims=[Image.open(p).convert('RGBA') for p in ps]; assert [i.size for i in ims]==[(256,64),(256,256)]; a,b=[np.asarray(i).astype(np.int16) for i in ims]; assert a[...,3].min()==255 and b[...,3].min()==255
seam=int(np.abs(a[:,0]-a[:,-1]).max()); assert seam<2,seam
def L(v):
 c=v[...,:3]/255.; q=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4); return 116*np.cbrt(.2126*q[...,0]+.7152*q[...,1]+.0722*q[...,2])-16
ls,lp=L(a),L(b); assert ls.mean()>=25 and ls.min()>=18 and lp.mean()>=32,(ls.mean(),ls.min(),lp.mean())
glow=ls[7:26,141:160]; center=float(ls[14:19,148:153].mean()); entourage=float(ls[4:29,138:163][((np.indices((25,25))[0]-12)**2+(np.indices((25,25))[1]-12)**2>=64)].mean()); glowbright=int((glow>75).sum()); assert glowbright>=40,glowbright; assert center-entourage>=15,(center,entourage)
rgb=b[...,:3]/255.; mx=rgb.max(2);mn=rgb.min(2);sat=np.where(mx>0,(mx-mn)/mx,0); hue=np.zeros(mx.shape);d=mx-mn
for k,(sel,offset) in enumerate([((mx==rgb[...,0])&(d>0),0),((mx==rgb[...,1])&(d>0),2),((mx==rgb[...,2])&(d>0),4)]): hue[sel]=((rgb[...,1][sel]-rgb[...,2][sel])/d[sel])%6 if k==0 else ((rgb[...,2][sel]-rgb[...,0][sel])/d[sel] if k==1 else (rgb[...,0][sel]-rgb[...,1][sel])/d[sel])+offset
hue*=60; bright=int(((hue>=140)&(hue<=175)&(sat>.3)&(lp>55)).sum()); assert bright>=350,bright
board=Image.new('RGB',(768,256),(32,50,48)); sky=ims[0].resize((768,192));board.paste(sky,(0,0)); board.paste(ims[1].resize((256,256)),(512,0)); assert board.width<=1024; board.save(root/'art/tools/cosmetics/_ciel_maree_haute_contact.png')
print('PASS sizes=256x64,256x256 seam=%d Lsky=%.1f min=%.1f Lpreview=%.1f luminous=%d contact=768x256'%(seam,ls.mean(),ls.min(),lp.mean(),bright))
