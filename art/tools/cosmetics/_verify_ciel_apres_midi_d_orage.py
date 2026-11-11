from pathlib import Path
from PIL import Image
import numpy as np
r=Path(r"C:\Users\const\Documents\Rainfall\.claude\worktrees\agent-aa7c224c816eb5fed")
a=Image.open(r/"game/assets/sprites/ambiance/sky_apres_midi_d_orage_256x64.png").convert("RGBA"); b=Image.open(r/"game/assets/sprites/cosmetics/previews/apres_midi_d_orage.png").convert("RGBA")
def L(i):
 c=np.asarray(i)[...,:3]/255; q=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4); return 116*np.cbrt(q[...,0]*.2126+q[...,1]*.7152+q[...,2]*.0722)-16
s=np.asarray(a).astype(np.int16); seam=int(np.abs(s[:,0]-s[:,-1]).max()); x=L(a); y=L(b); assert a.size==(256,64) and b.size==(256,256) and np.asarray(a)[...,3].min()==255 and np.asarray(b)[...,3].min()==255 and seam<2 and x.mean()>=25 and x.min()>=18 and y.mean()>=32
p=np.asarray(b)[...,:3]/255; m=p.max(2); n=p.min(2); sat=np.where(m>0,(m-n)/m,0); d=m-n; h=np.zeros(m.shape)
for k,z in enumerate([(m==p[...,0])&(d>0),(m==p[...,1])&(d>0),(m==p[...,2])&(d>0)]):
 if k==0:h[z]=((p[...,1][z]-p[...,2][z])/d[z])%6
 elif k==1:h[z]=(p[...,2][z]-p[...,0][z])/d[z]+2
 else:h[z]=(p[...,0][z]-p[...,1][z])/d[z]+4
warm=int(((h*60>=25)&(h*60<=45)&(sat>.4)).sum()); assert warm>=250
z=Image.new("RGB",(768,320)); z.paste(a.resize((768,192))); z.paste(b,(256,64)); z.save(r/"art/tools/cosmetics/_ciel_apres_midi_d_orage_contact.png")
print(f"PASS seam={seam}/255 L*sky={x.mean():.2f} min={x.min():.2f} preview={y.mean():.2f} warm={warm} contact=768x320")
