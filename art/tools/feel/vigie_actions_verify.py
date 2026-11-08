"""Avare delivery checks, pixel measurements and SpriteFrames references."""
import json,re,subprocess,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'game/assets/sprites/characters/vigie'
WORK=ROOT/'art/blender/cel/vigie_actions'
from vigie_actions_build import ANIMS,F60,HITS,ALIASES



DIRS=['e','se','s','sw','w','nw','n','ne']
errors=[];report={}
def check(ok,message):
 if not ok:errors.append(message)
from functools import lru_cache
@lru_cache(None)
def sheet(a):return Image.open(BASE/(a+'.png')).convert('RGBA')
def frame(a,f,row):return np.asarray(sheet(a).crop((f*192,row*192,(f+1)*192,(row+1)*192)))
def bbox(a):
 y,x=np.where(a[:,:,3]>8)
 return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
idle=bbox(frame('idle',0,1));iw=idle[2]-idle[0];ih=idle[3]-idle[1]
before=json.loads((WORK/'before.json').read_text())
for a,n in ANIMS.items():
 h=HITS[a];metrics={'frames':n,'impact':h,'F60':F60[a],'impact_at_F60':sum(F60[a][:h])};mdiffs=[]
 for suffix,cell in [('',192),('_e',96)]:
  p=BASE/(a+suffix+'.png');im=Image.open(p).convert('RGBA');px=np.asarray(im)
  check(im.size==(n*cell,8*cell),f'{a+suffix} dimensions {im.size}')
  check(max(im.size)<=4096,f'{a+suffix} >4096')
  check(p.stat().st_size<=before[p.name]['bytes']*1.3,f'{p.name} budget')
  metrics['bytes'+suffix]=p.stat().st_size
  check(px[:,:,3].min()==0 and px[:,:,3].max()>200,f'{a+suffix} alpha')
  if suffix:
   check(np.max(px[:,:,:3].max(2).astype(float)*px[:,:,3]/255)>8,f'{a} emission black')
 for row in range(8):
  fs=[frame(a,f,row) for f in range(n)];hashes=[]
  for f,p in enumerate(fs):
   opaque=p[:,:,3]>8
   check(opaque.sum()>500,f'{a}/{row}/{f} missing')
   check(not (opaque[0,:].any() or opaque[-1,:].any() or opaque[:,0].any() or opaque[:,-1].any()),f'{a}/{row}/{f} clipped')
   colors=p[:,:,:3][opaque];check(colors.max()-colors.min()>60,f'{a}/{row}/{f} contrast')
   ink=((colors.max(1)<58).sum()/len(colors));check(ink>.02,f'{a}/{row}/{f} ink')
   hashes.append(hashlib.md5(p.tobytes()).hexdigest())
  check(len(set(hashes))==n,f'{a}/{row} duplicate frames')
  diffs=[]
  for x,y in zip(fs,fs[1:]):
   opaque=(x[:,:,3]>8)|(y[:,:,3]>8)
   changed=np.max(np.abs(x.astype(int)-y.astype(int)),axis=2)>12
   diffs.append(float((changed&opaque).sum()/opaque.sum()))
  check(min(diffs)>=.04,f'{a}/{row} adjacent delta {min(diffs):.3f}')
  mdiffs+=diffs
  if row==1:
   ratios=[]
   for f in range(h-1):
    b=bbox(fs[f]);ratios.append(max((b[2]-b[0])/iw,(b[3]-b[1])/ih))
   b=bbox(fs[h]);impact_ratio=max((b[2]-b[0])/iw,(b[3]-b[1])/ih)
   threshold=1.35 if a=='volley' else 1.25
   check(max(ratios)>=threshold,f'{a} anticipation bbox {max(ratios):.3f}')
   check(impact_ratio>=threshold,f'{a} impact bbox {impact_ratio:.3f}')
   metrics.update(anticipation_bbox_ratio=max(ratios),impact_bbox_ratio=impact_ratio,anticipation_frame=int(np.argmax(ratios)),impact_bbox=b)
 for f in range(n):check(len({hashlib.md5(frame(a,f,row).tobytes()).hexdigest() for row in range(8)})==8,f'{a}/{f} directions duplicate')
 core=[]
 for f in range(n):
  pix=frame(a,f,1);y,x=np.where(pix[:,:,3]>100);core.append(int(x.max()-x.min()+1)*int(y.max()-y.min()+1))
 check(core[h]>=max(core),f'{a} impact core silhouette not largest {core}')
 metrics['core_bbox_areas_se']=core
 metrics['min_adjacent_delta']=min(mdiffs)
 check(sum(F60[a][:h])<=({'attack':8,'flare':12,'net':12,'volley':25}[a]),f'{a} impact late')
 check(sum(F60[a][h+1:])>sum(F60[a][:h]),f'{a} recovery too short')
 report[a]=metrics
for alias,a in ALIASES.items():
 if not (BASE/(alias+'.png')).exists():continue
 for suffix in ('','_e'):
  check((BASE/(alias+suffix+'.png')).read_bytes()==(BASE/(a+suffix+'.png')).read_bytes(),f'alias {alias+suffix}')
  p=BASE/(alias+suffix+'.png');check(p.stat().st_size<=before[p.name]['bytes']*1.3,f'{p.name} budget')
for a in ('idle','run','brace','death','draw'):
 for suffix in ('','_e'):
  p=BASE/(a+suffix+'.png');head=subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)
  check(hashlib.sha256(p.read_bytes()).hexdigest()==before[p.name]['sha256'],f'protected {p.name}')
for filename,cell in [('vigie.tres',192),('vigie_emission.tres',96)]:
 if not (BASE/filename).exists():continue
 raw=(BASE/filename).read_bytes();old=(WORK/filename).read_bytes();s=raw.decode()
 check((b'\r\n' in raw)==(b'\r\n' in old),f'{filename} newline')
 check('CanvasTexture' not in s and 'normal_texture' not in s,f'{filename} normals')
 check(s.rfind('[ext_resource')<s.index('[sub_resource'),f'{filename} ext header')
 exts={m.group(2):Path(m.group(1)).name for m in re.finditer(r'\[ext_resource[^\]]*path="([^"]+)"[^\]]*id="([^"]+)"',s)}
 subs={m.group(1):(m.group(2),list(map(float,m.group(3).split(',')))) for m in re.finditer(r'\[sub_resource[^\]]*id="([^"]+)"\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]+)\)',s)}
 refs=re.findall(r'SubResource\("([^"]+)"\)',s)
 check(set(refs)==set(subs),f'{filename} orphan/missing atlas')
 for sid,(eid,rect) in subs.items():
  im=Image.open(BASE/exts[eid]);x,y,w,h=rect
  check(x>=0 and y>=0 and x+w<=im.width and y+h<=im.height,f'{filename}/{sid} bounds')
 for a in [*ANIMS,*ALIASES]:
  b=ALIASES.get(a,a)
  for d in DIRS:
   match=re.search(r'\{"frames": \[(.*?)\], "loop": false, "name": &"'+a+'_'+d+r'", "speed": 12.0\}',s)
   check(match is not None,f'{filename}/{a}/{d} missing')
   if match:
    durations=list(map(float,re.findall(r'"duration": ([0-9.]+)',match.group(1))))
    check(np.allclose(durations,np.array(F60[b])*12/60) if len(durations)==len(F60[b]) else False,f'{filename}/{a}/{d} duration')
 check(int(re.search(r'load_steps=(\d+)',s).group(1))==len(exts)+len(subs)+1,f'{filename} load_steps')
allowed={a+s+'.png' for a in [*ANIMS,*ALIASES] for s in ('','_e')}|{'vigie.tres','vigie_emission.tres'}|{a+s+'.png' for a in ('idle','run','death') for s in ('','_e')}
for p in BASE.glob('*'):
 if p.suffix in ('.png','.tres') and p.name not in allowed:
  check(p.name in before and hashlib.sha256(p.read_bytes()).hexdigest()==before[p.name]['sha256'],f'protected {p.name}')
check(not list((WORK/'renders').glob('*_n.png')),'normal produced')
report.update(idle_bbox=idle,errors=errors,status='FAIL' if errors else 'PASS')
(WORK/'verification.json').write_text(json.dumps(report,indent=2))
print(report['status'],json.dumps({a:{k:round(v,3) for k,v in report[a].items() if k in ('anticipation_bbox_ratio','impact_bbox_ratio','min_adjacent_delta')} for a in ANIMS}),'; '.join(errors[:8]))
raise SystemExit(bool(errors))
