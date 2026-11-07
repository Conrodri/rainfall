"""Lot UX-B : mesure contraste (WCAG) sur le fond Forge #30201C et distinctivité des silhouettes. Mesure seulement."""
import sys, itertools
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image, ImageFilter
IDS=['meche_silex','rosee_figee','rouage_traque','seve_rampante','ecorce_pluie','prisme_grele']
ICONS=ROOT/'game/assets/sprites/icons'
BG=(0x30,0x20,0x1C)
def lin(c):
    c/=255
    return c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4
def lum(r,g,b): return .2126*lin(r)+.7152*lin(g)+.0722*lin(b)
LBG=lum(*BG)
def ratio(l): return (max(l,LBG)+.05)/(min(l,LBG)+.05)
def median(v):
    v=sorted(v); return v[len(v)//2] if v else 0
def stats(im):
    """Contraste médian (corps) et médian du liseré (bande d'arête ~3 px) sur le fond Forge."""
    px=im.load(); a=im.getchannel('A')
    inner=a.point(lambda v:255 if v>200 else 0).filter(ImageFilter.MinFilter(7))
    body=[];rim=[]
    for y in range(im.height):
        for x in range(im.width):
            r,g,b,al=px[x,y]
            if al<200: continue
            q=ratio(lum(r,g,b))
            body.append(q)
            if inner.getpixel((x,y))==0: rim.append(q)
    return median(body),median(rim)
def mask48(im):
    s=im.resize((48,48),Image.Resampling.LANCZOS).getchannel('A')
    return [1 if s.getpixel((x,y))>128 else 0 for y in range(48) for x in range(48)]
def iou(a,b):
    i=sum(1 for p,q in zip(a,b) if p and q); u=sum(1 for p,q in zip(a,b) if p or q); return i/u if u else 0
ok=True; masks={}
for i in IDS:
    p=ICONS/'items'/f'{i}.png'; im=Image.open(p).convert('RGBA')
    b,r=stats(im); masks[i]=mask48(im)
    has_e=p.with_name(i+'_e.png').exists()
    flag=b>=3.0 and r>=3.0
    ok&=flag
    print(f"{'PASS' if flag else 'FAIL'} {i} corps={b:.2f}:1 liseré={r:.2f}:1 bytes={p.stat().st_size} _e={has_e}")
for a,b in itertools.combinations(IDS,2):
    v=iou(masks[a],masks[b]); bad=v>0.72; ok&=not bad
    if v>0.60 or bad: print(f"{'FAIL' if bad else 'WARN'} silhouette {a}/{b} IoU48={v:.2f}")
print('max IoU48 =',round(max(iou(masks[a],masks[b]) for a,b in itertools.combinations(IDS,2)),2))
for name,path in [('storm_core icône',ICONS/'storm_core.png'),('storm_core pickup',ROOT/'game/assets/sprites/pickups/storm_core.png')]:
    im=Image.open(path).convert('RGBA'); b,r=stats(im); bb=im.getchannel('A').getbbox()
    cx=(bb[0]+bb[2])/2/im.width; cy=(bb[1]+bb[3])/2/im.height
    print(f"{name} {im.size} corps={b:.2f}:1 liseré={r:.2f}:1 centre=({cx:.2f},{cy:.2f}) bytes={path.stat().st_size}")
print('RESULT:','OK' if ok else 'FAIL')
