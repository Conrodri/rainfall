"""C7C focused contract verification, Pillow inspection only."""
from pathlib import Path
from PIL import Image,ImageChops
import json,re,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/sonneur'
inv=json.loads((HERE/'_c7c_inventory.json').read_text());report=json.loads((HERE/'_c7c_render_report.json').read_text())
results={};errors=[]
for name,v in inv['files'].items():
    p=DST/name
    if not p.exists():errors.append('missing '+name);continue
    if Image.open(p).size!=tuple(v['size']):errors.append('size '+name)
    if hashlib.sha256(p.read_bytes()).hexdigest()==v['sha256']:errors.append('not replaced '+name)
for a,v in report.items():
    im=Image.open(DST/(a+'.png')).convert('RGBA');w=im.width//v['frames'];h=im.height//len(v['directions']);bounds=[];motion=[]
    for suffix in ('_n','_e'):
        aux=Image.open(DST/(a+suffix+'.png')).convert('RGBA')
        if aux.size!=im.size or ImageChops.difference(im.getchannel('A'),aux.getchannel('A')).getbbox():errors.append('alpha '+a+suffix)
        if suffix=='_n' and any(px[:3]!=(128,128,255) for px in aux.getdata() if px[3]==0):errors.append('normal background '+a)
    for row,d in enumerate(v['directions']):
        unique=set()
        for i in range(v['frames']):
            cell=im.crop((i*w,row*h,(i+1)*w,(row+1)*h));bb=cell.getbbox();unique.add(hashlib.md5(cell.tobytes()).digest())
            if not bb:errors.append(f'empty {a}/{d}/{i}');continue
            bounds.append(min(bb[0],bb[1],w-bb[2],h-bb[3]))
        motion.append(len(unique))
    margin=min(bounds) if bounds else -1
    if margin<4:errors.append(f'margin {a}: {margin}')
    if min(motion)<=1 and v['frames']>1:errors.append('no motion '+a)
    results[a]={'minimum_margin':margin,'unique_frames_by_direction':motion}
text=(DST/'sonneur.tres').read_text();original=inv['original_tres']
for old in re.findall(r'\[sub_resource[^\[]+',original):
    if old.strip() not in text:errors.append('changed original atlas');break
old_anims=re.search(r'\[resource\]\s*animations = \[(.*)\]\s*$',original,re.S)[1]
if old_anims.strip() not in text:errors.append('changed original animations')
names=re.findall(r'"name":\s*&"([^"]+)"',text)
if len(names)!=len(inv['animations'])+9:errors.append('animation count')
results['summary']={'legacy_png':len(inv['files']),'png_total':len(list(DST.glob('*.png'))),'animations':len(names),'errors':errors}
(HERE/'_c7c_verify.json').write_text(json.dumps(results,indent=2))
print(('FAIL '+repr(errors)) if errors else 'PASS: 60 legacy PNG replaced, dimensions/alpha/normals/margins/motion valid; 29 animations preserved + 9 added.')
raise SystemExit(bool(errors))
