from pathlib import Path
from PIL import Image, ImageChops, ImageStat
import re, math, warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)
ROOT=Path(__file__).resolve().parents[3]; P=ROOT/'game/assets/sprites/props/menu/crypte_veilleuse'; W=ROOT/'art/tools/cosmetics'
def read(path): return Image.open(path).convert('RGBA')
def check(ok,msg):
 if not ok: raise AssertionError(msg)
fire=read(P/'fire.png'); em=read(P/'fire_e.png'); check(fire.size==(3072,256),'fire dimensions');check(em.size==(1536,128),'fire_e dimensions')
frames=[fire.crop((i*256,0,(i+1)*256,256)) for i in range(12)];check(all(f.getchannel('A').getbbox() for f in frames),'empty fire frame')
check(all(ImageChops.difference(frames[0],f).getbbox() for f in frames[1:]),'indistinct fire frames')
check(em.getchannel('A').getbbox() and max(ImageStat.Stat(em).mean[:3])>0,'black fire emission')
FLAME_BASES = [(108,182),(121,173),(137,178),(122,187),(131,186),(147,187),(139,200)]
log=(W/'_logfix4_crypte_blender.txt').read_text(encoding='utf-8')
before=int(re.search(r'MTIME_BEFORE=(\d+)',log)[1])
now=(P/'fire.png').stat().st_mtime_ns//100+621355968000000000
check(now>before,'fire.png mtime unchanged')
measurements=re.findall(r'FLAME_BASE (\d+) measured=([\d.]+),(\d+) error=([\d.]+)',log)
check(len(measurements)==7,'missing isolated opaque flame measurements')
errors=[]
for (index,mx,my,_),(cx,cy) in zip(measurements,FLAME_BASES):
 error=math.hypot(float(mx)-cx,float(my)-cy);check(error<=3,f'base {index}: {error}');errors.append(round(error,3))
 # Final atlas must retain opaque pixels at every measured isolated base.
 for f in frames:
  check(any(f.getpixel((x,y))[3]>=180 for x in range(cx-2,cx+3) for y in range(cy-2,cy+2)),f'base {index} missing in atlas')
check(len({f.tobytes() for f in frames})==12,'12 distinct frames')
check(max(fire.getchannel('A').getdata())==255 and min(fire.getchannel('A').getdata())==0,'alpha range')
sizes={'candles.png':(128,128),'candles_e.png':(64,64),'wreath.png':(128,128),'wreath_shadow.png':(128,128)}
margins={}
for n,sz in sizes.items():
 im=read(P/n);check(im.size==sz,f'{n} dimensions');bbox=im.getchannel('A').getbbox();check(bbox is not None,f'{n} empty')
 margins[n]=min(bbox[0],bbox[1],sz[0]-bbox[2],sz[1]-bbox[3]);check(margins[n]>=4,f'{n} margin {margins[n]}')
 if 'shadow' in n: check(len(set(im.getdata()))<300 and all(r==g==b for r,g,b,a in im.getdata()),f'{n} not grayscale')
e=read(P/'candles_e.png');check(max(ImageStat.Stat(e).mean[:3])>0,'black candles emission')
check(not list(P.glob('*_n.png')),'normal map exists')
preview=read(ROOT/'game/assets/sprites/cosmetics/previews/crypte_veilleuse.png');check(preview.size==(256,256) and min(preview.getchannel('A').getdata())==255,'preview dimensions/alpha');preview_l=ImageStat.Stat(preview.convert('L')).mean[0];check(30<=preview_l<=55,f'preview L* {preview_l:.1f}')
# One contact sheet: native pixels and candles sharing the same ground pivot.
sheet=Image.new('RGBA',(1024,256),(43,49,45,255))
for i,fi in enumerate((0,5,9)):
 tile=Image.new('RGBA',(256,256),(43,49,45,255))
 tile.alpha_composite(read(P/'candles.png'),(64,128));tile.alpha_composite(frames[fi]);sheet.alpha_composite(tile,(i*256,0))
sheet.alpha_composite(preview,(768,0));sheet.save(W/'_veillee_crypte_veilleuse_contact.png',optimize=True)
print('VERIFY_PASS errors_px='+','.join(str(e) for e in errors)+' fire_mtime_ns='+str((P/'fire.png').stat().st_mtime_ns)+' preview_L='+str(round(preview_l,1)))
