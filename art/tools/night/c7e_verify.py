"""C7E contracts, pixel inspection and a single assembled DA contact (no drawing)."""
from pathlib import Path
from PIL import Image, ImageChops
import re,json,hashlib
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
DST=ROOT/'game/assets/sprites/bosses/etage/sonneur';BEFORE=HERE/'_c7e_before'
errors=[];checks={};report=json.loads((HERE/'_c7e_render_report.json').read_text())
def fail(message):errors.append(message)
for task,spec in report.items():
    w,h=spec['cell'];n=spec['frames'];rows=len(spec['directions'])
    im=Image.open(DST/(task+'.png')).convert('RGBA');alpha=im.getchannel('A')
    if im.size!=(w*n,h*rows) or max(im.size)>4096:fail('dimensions '+task)
    for suffix in ('_n','_e'):
        aux=Image.open(DST/(task+suffix+'.png')).convert('RGBA')
        if aux.size!=im.size or ImageChops.difference(alpha,aux.getchannel('A')).getbbox():fail('pass alignment '+task+suffix)
        if suffix=='_n' and any(v[:3]!=(128,128,255) for v in aux.getdata() if v[3]==0):fail('normal background '+task)
        if suffix=='_e' and task=='steam_jet' and max(aux.getextrema()[j][1] for j in range(3))>0:fail('steam emission')
    boxes=[];unique=[]
    for row in range(rows):
        hashes=set()
        for i in range(n):
            cell=im.crop((w*i,h*row,w*(i+1),h*(row+1)));box=cell.getbbox()
            if not box:fail('empty '+task);continue
            boxes.append(box);hashes.add(hashlib.md5(cell.tobytes()).hexdigest())
        unique.append(len(hashes))
    if min(unique)<2:fail('static '+task)
    checks[task]={'unique':unique,'bounds':boxes}
    if task=='lightning' and min(b[3]-b[1] for b in boxes)<735:fail('short lightning')
    if task=='steam_jet' and min(b[2]-b[0] for b in boxes)<330:fail('short steam jet')

old=(BEFORE/'sonneur.tres').read_text(encoding='utf-8');now=(DST/'sonneur.tres').read_text(encoding='utf-8')
for block in re.findall(r'\[sub_resource[^\[]+',old):
    if 'ExtResource("bolt")' in block:
        block=re.sub(r'(region = Rect2\()(\d+), 0, 32, 32\)',lambda m:m[1]+str(int(m[2])*2)+', 0, 64, 64)',block)
    if block.strip() not in now:fail('changed existing AtlasTexture');break
old_names=re.findall(r'"name":\s*&"([^"]+)"',old);names=re.findall(r'"name":\s*&"([^"]+)"',now)
if set(names)!=set(old_names)|{'glas_wave','steam_jet'}:fail('animations')
old_anims=re.search(r'\[resource\]\s*animations = \[(.*)\]\s*$',old,re.S)[1]
if old_anims.strip() not in now:fail('changed existing animation definitions')
inventory=json.loads((HERE/'_c7c_inventory.json').read_text())
for name,v in inventory['files'].items():
    expected=(384,64) if name in ('bolt.png','bolt_n.png','bolt_e.png') else tuple(v['size'])
    if Image.open(DST/name).size!=expected:fail('legacy size '+name)
for name in ('idle_p1','idle_p2','idle_p3'):
    values=[]
    for folder in (BEFORE,DST):
        im=Image.open(folder/(name+'.png')).convert('RGBA');p=[(r+g+b)/3 for r,g,b,a in im.getdata() if a>200];values.append(round(sum(p)/len(p),2))
    checks[name]['before_after_mean']=values
    if values[1]<values[0]*1.7:fail('body readability '+name)

# One contact: top before/after P1,P2,P3; next four directions + real passes;
# next 8 wave frames + six rotating bolts; bottom columns and horizontal jets.
canvas=Image.new('RGBA',(1536,1536),(19,25,28,255))
floor=Image.open(ROOT/'game/assets/sprites/terrain/rust_city/iso/ground_a.png').convert('RGBA')
def stage(im,x,y):
    canvas.alpha_composite(floor.crop((128,0,384,256)),(x,y+64))
    canvas.alpha_composite(im,(x,y))
for j,name in enumerate(('idle_p1','idle_p2','idle_p3')):
    for k,folder in enumerate((BEFORE,DST)):
        im=Image.open(folder/(name+'.png')).convert('RGBA').crop((0,0,256,256));stage(im,(j*2+k)*256,0)
walk=Image.open(DST/'walk_p1.png').convert('RGBA')
for row in range(4):stage(walk.crop((0,row*256,256,(row+1)*256)),row*256,320)
for j,suffix in enumerate(('_n','_e')):
    im=Image.open(DST/('idle_p3'+suffix+'.png')).convert('RGBA').crop((0,0,256,256));canvas.alpha_composite(im,(1024+j*256,320))
wave=Image.open(DST/'glas_wave.png').convert('RGBA')
for i in range(8):
    im=wave.crop((i*256,0,(i+1)*256,256)).resize((128,128));canvas.alpha_composite(im,(i*128,640))
for k,folder in enumerate((BEFORE,DST)):
    bolts=Image.open(folder/'bolt.png').convert('RGBA');w=bolts.width//6
    for i in range(6):canvas.alpha_composite(bolts.crop((i*w,0,(i+1)*w,w)),(1024+i*80,640+k*80))
for i in range(4):
    im=Image.open(DST/'lightning.png').convert('RGBA').crop((i*128,0,(i+1)*128,768));im.thumbnail((96,576));canvas.alpha_composite(im,(i*110,800))
before=Image.open(BEFORE/'lightning.png').convert('RGBA').crop((0,0,128,768));before.thumbnail((96,576));canvas.alpha_composite(before,(450,800))
jet=Image.open(DST/'steam_jet.png').convert('RGBA')
for j,i in enumerate((0,2,4,6)):
    im=jet.crop((i*384,0,(i+1)*384,64));canvas.alpha_composite(im,(580,820+j*140))
for j,p in enumerate(('art/tools/night/_f3_contact.png','art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png')):
    im=Image.open(ROOT/p).convert('RGBA');im.thumbnail((350,150));canvas.alpha_composite(im,(j*384,1380))
canvas.convert('RGB').save(HERE/'_c7e_contact.png',compress_level=9)
checks['summary']={'status':'FAIL' if errors else 'PASS','errors':errors,'animations':len(names),'sheets':len(report),'max_atlas':max(max(v['size']) for v in report.values())}
(HERE/'_c7e_verify.json').write_text(json.dumps(checks,indent=2))
print('C7E '+checks['summary']['status']+': '+str(errors)+'; '+str(len(report))+' sheets; '+str(len(names))+' animations')
raise SystemExit(bool(errors))
