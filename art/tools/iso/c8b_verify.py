"""C8b contract verification and contact sheet (Pillow assembly only)."""
from pathlib import Path
import json,hashlib,math
from PIL import Image
R=Path(__file__).resolve().parents[3]; H=R/'art/tools/iso'; S=R/'game/assets/sprites'
d=json.loads((H/'_c8b_inventory.json').read_text()); errors=[]
now={str(p.relative_to(R)) for p in (S/'chests').rglob('*.png')}
if now!=set(d['original_files']):errors.append('file inventory')
for rel,a in d['original_files'].items():
    p=R/rel; im=Image.open(p)
    if list(im.size)!=a['size'] or im.mode!='RGBA':errors.append(rel+' format')
    if hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256']:errors.append(rel+' unchanged')
    if not any(t in p.stem for t in ('_n','_e','shadow')):
        b=im.getchannel('A').point(lambda x:255 if x>24 else 0).getbbox()
        if not b or min(b[0],b[1],128-b[2],128-b[3])<3:errors.append(rel+' clipping')
for rel,sha in d['protected'].items():
    if hashlib.sha256((R/rel).read_bytes()).hexdigest()!=sha:errors.append(rel+' protected')
audit=json.loads((H/'_c8b_geometry.json').read_text())
for name,poses in audit.items():
    if len({p['lid_sha256'] for p in poses})!=1:errors.append(name+' lid mismatch')
board=Image.new('RGBA',(1600,1200),(19,25,28,255))
tile=Image.open(S/'terrain/terraces/iso/ground_a.png').convert('RGBA'); tile=tile.resize(tuple(round(v/math.sqrt(2)) for v in tile.size),Image.Resampling.LANCZOS)
ard=Image.open(S/'characters/ardent/idle.png').convert('RGBA').crop((0,192,192,384)); ard=ard.resize((136,136),Image.Resampling.LANCZOS)
for row,name in enumerate(('chest_small','chest_large','chest_legendary')):
    oy=row*400
    for col,suff in enumerate(('','_sw')):
        panel=Image.new('RGBA',(340,400),(19,25,28,255))
        cx=170;cy=245
        for i,j in sorted(((i,j) for i in range(-1,2) for j in range(-1,2)),key=lambda v:sum(v)):
            x=round(cx+(i-j)*tile.width/2);y=round(cy+(i+j)*tile.height/2)
            panel.alpha_composite(tile,(x-tile.width//2,y-tile.height//2))
        panel.alpha_composite(ard,(cx-ard.width//2,cy+58-round(ard.height*.62)))
        for k,pose in enumerate(('closed','open')):
            im=Image.open(S/f'chests/{name}/{pose}{suff}.png').convert('RGBA')
            panel.alpha_composite(im,(cx-135+k*150,cy-90))
        board.alpha_composite(panel,(col*340,oy))
    for k,pose in enumerate(('closed','open')):
        im=Image.open(S/f'chests/{name}/{pose}.png').convert('RGBA').resize((384,384),Image.Resampling.NEAREST)
        board.alpha_composite(im,(805+k*390,oy+8))
board.convert('RGB').save(H/'_c8b_contact.png',optimize=True)
result={'result':'FAIL' if errors else 'PASS','errors':errors,'files':len(now),'pivot':[64,89.6],'px_per_u':64,'contact_rows':['small','large','legendary'],'contact_columns':['SE closed/open with Ardent','SW closed/open with Ardent','SE closed x3','SE open x3'],'emission_contract':'Existing _e files retained; small/large cavity emission baked into beauty, no new pass files.'}
(H/'_c8b_verification.json').write_text(json.dumps(result,indent=2));print(result['result'],len(now),'PNGs; errors:',errors[:8])

