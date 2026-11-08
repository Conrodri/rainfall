from pathlib import Path
from PIL import Image, ImageChops, ImageStat
import hashlib, json
ROOT=Path(__file__).resolve().parents[3]
V=ROOT/'game/assets/sprites/vfx/epreuve'
S={'geyser_tele':(256,256),'geyser_flash':(256,256),'chevron':(128,128),'progress_ring':(256,256),'path_tile':(64,32),'pad_start':(128,128),'pad_end':(128,128),'rope':(64,16),'link':(64,24),'bar_frame':(192,24),'bar_fill':(192,24)}
errors=[]; hashes=set(); total=0; metrics={}
for n,size in S.items():
 p=V/('ep2_'+n+'.png')
 if not p.exists(): errors.append(n+': missing'); continue
 total+=p.stat().st_size
 im=Image.open(p).convert('RGBA'); w,h=im.size; a=im.getchannel('A')
 if im.size!=size: errors.append(n+': size '+str(im.size))
 if max(a.getpixel(xy) for xy in [(0,0),(w-1,0),(0,h-1),(w-1,h-1)])>2: errors.append(n+': corners')
 if a.getextrema()[1]<240: errors.append(n+': opaque content')
 visible=[sum(px[:3])/3 for px in im.get_flattened_data() if px[3]>128]
 if not visible or max(visible)<65: errors.append(n+': contrast')
 digest=hashlib.sha256(im.tobytes()).hexdigest()
 if digest in hashes: errors.append(n+': duplicate')
 hashes.add(digest)
 if n in ('path_tile','rope','link'):
  # Compare premultiplied RGB and alpha: transparent RGB carries no visible seam.
  edge=[]
  for y in range(h):
   l=im.getpixel((0,y)); r=im.getpixel((w-1,y)); edge.append([abs(l[3]-r[3])]+[abs(l[c]*l[3]/255-r[c]*r[3]/255) for c in range(3)])
  means=[sum(e[c] for e in edge)/h for c in range(4)]; peak=max(max(e) for e in edge)
  metrics[n]={'edge_mean':round(max(means),3),'edge_peak':round(peak,3)}
  if max(means)>12 or peak>85: errors.append(n+': seam '+str(metrics[n]))
 if list(V.glob('ep2_'+n+'_[ne].png')): errors.append(n+': sidecar')
if total>1500000: errors.append('budget '+str(total))
# Assembly only: native-size assets over native-size dark terrain, no drawing or resizing.
ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
board=Image.new('RGBA',(768,1024),(20,19,18,255))
for y in range(0,1024,ground.height):
 for x in range(0,768,ground.width): board.alpha_composite(ground,(x,y))
for i,n in enumerate(S):
 im=Image.open(V/('ep2_'+n+'.png')).convert('RGBA'); board.alpha_composite(im,((i%3)*256+(256-im.width)//2,(i//3)*256+(256-im.height)//2))
out=ROOT/'art/renders/epreuves_fx'; out.mkdir(parents=True,exist_ok=True); board.save(out/'ep2_contact.png')
(out/'ep2_verify.json').write_text(json.dumps({'bytes':total,'seams':metrics,'errors':errors},indent=2))
print(('FAIL '+ '; '.join(errors)) if errors else 'PASS EP-II: 11 PNG; sizes/alpha/contrast/distinct/seams; '+str(total)+' bytes')
raise SystemExit(bool(errors))
