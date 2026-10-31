from pathlib import Path
import json,re,hashlib,subprocess
import numpy as np
from PIL import Image
R=Path("C:/Users/const/Documents/Rainfall");D=R/"game/assets/sprites/characters/bourbe"
A={"slap":7,"throw":7,"recall":7,"sink":7,"rise":7,"cast_ult":9};aliases={"attack":"slap","cast":"throw"}
F={"slap":[2,2,5,2,4,5,5],"throw":[3,3,6,2,4,5,5],"recall":[3,3,6,2,4,5,5],"sink":[3,3,6,2,4,5,5],"rise":[3,3,6,2,4,5,5],"cast_ult":[4,4,4,7,4,5,5,5,5]}
base=json.loads((R/"art/blender/cel/bourbe_baseline.json").read_text());report={};errors=[]
def check(ok,label):
 if not ok:errors.append(label)
idle=np.array(Image.open(D/"idle.png").convert("RGBA"))[192:384,:192]
def box(ar):
 b=Image.fromarray(ar[:,:,3]).getbbox();return (b[2]-b[0],b[3]-b[1])
iw,ih=box(idle)
for a,n in A.items():
 ar=np.array(Image.open(D/f"{a}.png").convert("RGBA"));check(ar.shape==(1536,n*192,4),a+" dimensions")
 hit=3 if a=="cast_ult" else 2;row=[ar[192:384,i*192:(i+1)*192] for i in range(n)]
 ratios=[max(box(x)[0]/iw,box(x)[1]/ih) for x in row]
 diffs=[float(np.any(np.abs(x.astype(int)-y.astype(int))>24,axis=2)[(x[:,:,3]>32)|(y[:,:,3]>32)].mean()) for x,y in zip(row,row[1:])]
 check(max(ratios[:hit-1])>(1.35 if a=="cast_ult" else 1.25),a+" anticipation");check(ratios[hit]>1.25,a+" impact");check(min(diffs)>=.04,a+" differences")
 clipping=[]
 for d in range(8):
  cells=[ar[d*192:(d+1)*192,f*192:(f+1)*192] for f in range(n)]
  check(len({hashlib.sha256(x.tobytes()).digest() for x in cells})==n,a+" distinct "+str(d))
  for f,x in enumerate(cells):
   al=x[:,:,3];check(al.max()>128 and al.min()==0,a+" alpha")
   if np.any(np.concatenate((al[0],al[-1],al[:,0],al[:,-1]))>32):clipping.append((d,f))
 check(not clipping,a+" clipping "+str(clipping))
 sizes=[]
 for suf in ("","_e"):
  p=D/f"{a}{suf}.png";ratio=p.stat().st_size/base[p.name]["size"];sizes.append(round(ratio,4));check(ratio<=1.3,p.name+" budget "+str(round(ratio,4)))
  if suf:
   e=np.array(Image.open(p).convert("RGBA"));check(e.shape==(768,n*96,4),a+" emission dimensions");check(np.max(e[:,:,:3].astype(float)*e[:,:,3:4]/255)>2,a+" emission black")
 report[a]={"frames":n,"impact":hit,"F60":F[a],"bbox_ratios":[round(max(ratios[:hit-1]),3),round(ratios[hit],3)],"min_diff_percent":round(min(diffs)*100,2),"size_ratios":sizes}
for a,b in aliases.items():
 for suf in ("","_e"):check((D/f"{a}{suf}.png").read_bytes()==(D/f"{b}{suf}.png").read_bytes(),a+" alias")
for a in ("idle","run","death"):
 for suf in ("","_e"):
  p=D/f"{a}{suf}.png";head=subprocess.run(["git","show","HEAD:"+p.relative_to(R).as_posix()],capture_output=True);check(head.returncode==0 and head.stdout==p.read_bytes(),p.name+" HEAD")
raw=(D/"bourbe.tres").read_bytes();s=raw.decode().replace("\r\n","\n")
check("CanvasTexture" not in s and "normal_texture" not in s and not list(D.glob("*_n.png")),"normals")
blocks={m.group(1):m.group(2) for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(.*?)(?=\n\[|\Z)',s,re.S)}
anim=re.findall(r'\{"frames": \[(.*?)\], "loop": (?:true|false), "name": &"([^"]+)", "speed": ([0-9.]+)\}',s,re.S)
allids=re.findall(r'\[sub_resource[^\]]* id="([^"]+)"',s)
check(len(allids)==len(set(allids)),"duplicate resources")
check(s.index("[ext_resource")<s.index("[sub_resource"),"ext resource order")
for a,n in {**A,**{k:A[v] for k,v in aliases.items()}}.items():
 entries=[x for x in anim if x[1].rsplit("_",1)[0]==a];check(len(entries)==8,a+" directions")
 for frames,name,speed in entries:
  direction=name.rsplit("_",1)[1];d=("e","se","s","sw","w","nw","n","ne").index(direction)
  vals=re.findall(r'"duration": ([0-9.]+), "texture": SubResource\("([^"]+)"\)',frames);check(len(vals)==n,name+" count")
  for f,(duration,ref) in enumerate(vals):
   check(abs(float(duration)-F[aliases.get(a,a)][f]*float(speed)/60)<1e-6,name+" duration")
   check(f"region = Rect2({f*192}, {d*192}, 192, 192)" in blocks.get(ref,""),name+" region")
for ref,body in blocks.items():
 if ref.startswith(tuple("b"+a+"_" for a in (*A,*aliases))):check(s.count('SubResource("'+ref+'")')>0,ref+" orphan")
result={"status":"FAIL" if errors else "PASS","animations":report,"errors":errors}
(R/"art/blender/cel/bourbe_verify2.json").write_text(json.dumps(result,indent=2))
print(json.dumps(result,separators=(",",":")))
raise SystemExit(bool(errors))
