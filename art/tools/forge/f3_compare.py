"""Planche de contrôle UX-B (assemblage seulement) : anciennes vs nouvelles icônes à 256 et 48 px sur #30201C,
noyau icône, pickup sur sol sombre (ancien/nouveau, x1 et x3). Usage : f3_compare.py <dossier des anciennes copies>."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image
old=Path(sys.argv[1]); IC=ROOT/'game/assets/sprites/icons'; PK=ROOT/'game/assets/sprites/pickups'
ids=['meche_silex','rosee_figee','rouage_traque','seve_rampante','ecorce_pluie','prisme_grele']
BG=(0x30,0x20,0x1C,255); FLOOR=(0x24,0x20,0x1E,255)
W=6*260+20; H=20+2*(260)+ (60+10)*2 + 40 + 330
sheet=Image.new('RGBA',(W,H),BG)
def put(im,x,y,size=None):
    if size: im=im.resize((size,size),Image.Resampling.LANCZOS)
    sheet.alpha_composite(im,(x,y))
y=10
for row,(label,src) in enumerate([('old',lambda i:old/f'{i}.png'),('new',lambda i:IC/'items'/f'{i}.png')]):
    for c,i in enumerate(ids):
        im=Image.open(src(i)).convert('RGBA'); put(im,10+c*260,y)
        put(im,10+c*260+100,y+260+4,48)
    y+=260+60
# noyau : icône ancienne/nouvelle 256 + 48
x0=10
for k,p in enumerate([old/'storm_core.png',IC/'storm_core.png']):
    im=Image.open(p).convert('RGBA'); put(im,x0+k*330,y); put(im,x0+k*330+260,y+100,48)
# pickup sur sol sombre : ancien/nouveau a x1 (taille jeu 0.707) et x3
px=x0+680
floor=Image.new('RGBA',(520,300),FLOOR); sheet.alpha_composite(floor,(px,y))
for k,p in enumerate([old/'pickup_storm_core.png',PK/'storm_core.png']):
    im=Image.open(p).convert('RGBA')
    sh=PK/'storm_core_shadow.png'
    x=px+10+k*250
    if k==1 and sh.exists(): sheet.alpha_composite(Image.open(sh).convert('RGBA').resize((im.width*2,im.height*2),Image.Resampling.LANCZOS),(x,y+10))
    sheet.alpha_composite(im.resize((im.width*2,im.height*2),Image.Resampling.LANCZOS),(x,y+10))
    # taille réelle en jeu (x0,707 de SPRITE_K)
    g=int(im.width*0.7071)
    if k==1 and sh.exists(): sheet.alpha_composite(Image.open(sh).convert('RGBA').resize((g,g),Image.Resampling.LANCZOS),(x+20,y+230))
    sheet.alpha_composite(im.resize((g,g),Image.Resampling.LANCZOS),(x+20,y+230))
out=ROOT/'art/renders/forge/f3_compare.png'; sheet.convert('RGB').save(out,optimize=True); print(out,sheet.size)
