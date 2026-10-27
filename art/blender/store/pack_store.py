from pathlib import Path
from PIL import Image
import hashlib, json, math
ROOT=Path(__file__).resolve().parents[3]
WORK=Path(__file__).parent
OUT=ROOT/'game/assets/store'
SIZES={'icon_512':(512,512),'icon_192':(192,192),'icon_256':(256,256),'icon_foreground_432':(432,432),'icon_background_432':(432,432),'feature_1024x500':(1024,500),'logo_title':(1600,480)}
report={}
for name,size in SIZES.items():
    src=WORK/('icon_master.png' if name in ('icon_512','icon_192','icon_256') else name+'.png')
    im=Image.open(src).convert('RGBA').resize(size,Image.Resampling.LANCZOS)
    transparent=name in ('icon_foreground_432','logo_title')
    if not transparent:
        assert im.getchannel('A').getextrema()==(255,255),(name,'opacity')
    im.save(OUT/(name+'.png'),optimize=True,compress_level=9)
    a=im.getchannel('A');bbox=a.getbbox()
    assert bbox and (not transparent or a.getextrema()==(0,255)),(name,'alpha')
    if name=='icon_foreground_432':
        radius=max(math.hypot(x-215.5,y-215.5) for y in range(432) for x in range(432) if a.getpixel((x,y))>8)
        assert radius<=132,(name,'safe circle',radius)
    report[name]={'size':size,'bytes':(OUT/(name+'.png')).stat().st_size,'alpha':a.getextrema(),'bbox':bbox}
assert report['icon_512']['bytes']<=1048576
assert not list(OUT.glob('*_n.png'))
source=ROOT/'art/blender/bosses/rain_sower_iso.blend'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(source)==sha(WORK/'rain_sower_store.blend'),'Source model modified'
report['source_sha256']=sha(source)
(WORK/'verification.json').write_text(json.dumps(report,indent=2))
# Assembly only: each asset shown once, icons also at actual 48/96 px.
board=Image.new('RGB',(1600,1140),(19,25,30))
def paste(im,xy):
    im=im.convert('RGBA');board.paste(im,xy,im)
paste(Image.open(OUT/'logo_title.png').resize((1200,360),Image.Resampling.LANCZOS),(200,0))
paste(Image.open(OUT/'feature_1024x500.png'),(16,375))
paste(Image.open(OUT/'icon_512.png'),(1072,370))
paste(Image.open(OUT/'icon_foreground_432.png').resize((216,216),Image.Resampling.LANCZOS),(20,906))
paste(Image.open(OUT/'icon_background_432.png').resize((216,216),Image.Resampling.LANCZOS),(250,906))
x=510
for name in ('icon_512','icon_192','icon_256','icon_foreground_432'):
    im=Image.open(OUT/(name+'.png'))
    paste(im.resize((96,96),Image.Resampling.LANCZOS),(x,925))
    paste(im.resize((48,48),Image.Resampling.LANCZOS),(x+24,1050));x+=145
board.save(ROOT/'art/tools/night/_store_contact.png',optimize=True,compress_level=9)
print('PASS 7 PNG; exact sizes; alpha; adaptive safe circle; source SHA256; no normals; contact')
for k in ('icon_foreground_432','logo_title'): print(k,report[k]['bbox'])
