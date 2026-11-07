"""Verify Forge icon delivery and create one compact visual contact sheet."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
ids=['meche_silex','rosee_figee','rouage_traque','seve_rampante','ecorce_pluie','prisme_grele']
dest=ROOT/'game/assets/sprites/icons/items';out=ROOT/'art/renders/forge/f1_contact.png'
sheet=Image.new('RGBA',(1024,512),(30,34,39,255))
for i,ident in enumerate(ids):
 p=dest/(ident+'.png');im=Image.open(p)
 assert im.size==(256,256) and im.mode=='RGBA',f'{ident} dimensions/mode'
 a=im.getchannel('A');box=a.getbbox()
 assert box and min(box[0],box[1],256-box[2],256-box[3])>=12,f'{ident} margin {box}'
 assert all(a.getpixel(q)==0 for q in [(0,0),(255,0),(0,255),(255,255)]),f'{ident} alpha corners'
 assert p.stat().st_size<=60*1024,f'{ident} size {p.stat().st_size}'
 assert a.histogram()[255]>100 and ImageStat.Stat(im.convert('L'),a).stddev[0]>12,f'{ident} silhouette/contrast'
 small=im.resize((48,48),Image.Resampling.LANCZOS)
 assert ImageStat.Stat(small.convert('L'),small.getchannel('A')).stddev[0]>12,f'{ident} 48px contrast'
 x=(i%4)*256+104;y=(i//4)*256+34
 thumb=im.resize((152,152),Image.Resampling.LANCZOS);sheet.alpha_composite(thumb,(x,y))
 sheet.convert('RGB').crop((x,y+153,x+152,y+176)).save(ROOT/'art/renders/forge'/f'_label_{ident}.png')
 # Labels remain outside the contact PNG; avoid fonts and text assets in the art image.
 print(f'PASS {ident} bytes={p.stat().st_size} bbox={box} contrast48={ImageStat.Stat(small.convert("L"),small.getchannel("A")).stddev[0]:.1f}')
sheet.convert('RGB').save(out,optimize=True)
print('PASS contact 1024x512')
