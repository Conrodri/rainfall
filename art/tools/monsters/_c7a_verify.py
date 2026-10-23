"""Read-only asset contract audit against the pre-render inventory."""
from pathlib import Path
from PIL import Image,ImageChops
import json,re,hashlib
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
DST=ROOT/'game/assets/sprites/bosses/etage/eclusier'
inv=json.loads((HERE/'_c7a_inventory.json').read_text());errors=[];bounds={}
def require(ok,msg):
    if not ok:errors.append(msg)
for name,spec in inv['files'].items():
    p=DST/name;require(p.exists(),'missing '+name)
    if not p.exists() or not name.endswith('.png'):continue
    im=Image.open(p).convert('RGBA');require(list(im.size)==spec['size'],'size '+name)
    require(hashlib.sha256(p.read_bytes()).hexdigest()!=spec['sha256'],'unchanged '+name)
t=(DST/'eclusier.tres').read_text()
original=inv['original_tres']
pattern=r'\{"frames": \[.*?\], "loop": (?:true|false), "name": &"[^"]+", "speed": [\d.]+\}'
for definition in re.findall(pattern,original):require(definition in t,'modified original animation')
all_anims=re.findall(pattern,t);require(len(all_anims)==len(inv['animations'])+9,'animation count')
for anim,n in [('auto',6),('spell_a',8),('spell_b',8)]:
    for d in ('e','w','n'):require(f'"name": &"{anim}_{d}"' in t,'direction '+anim+d)
    require(Image.open(DST/f'{anim}_dirs.png').size==(n*256,768),'direction sheet '+anim)
for p in sorted(DST.glob('*.png')):
    if p.stem.endswith(('_n','_e')):continue
    diff=Image.open(p).convert('RGBA');alpha=diff.getchannel('A')
    for suffix in ('_n','_e'):
        mp=p.with_name(p.stem+suffix+'.png');require(mp.exists(),'pass '+mp.name)
        im=Image.open(mp).convert('RGBA');require(im.size==diff.size,'pass size '+mp.name)
        require(ImageChops.difference(alpha,im.getchannel('A')).getbbox() is None,'pass alpha '+mp.name)
        if suffix=='_n':require(all(a or (r,g,b)==(128,128,255) for r,g,b,a in im.getdata()),'normal background '+mp.name)
    if p.stem.startswith(('ground_','wave','wheel','geyser')):continue
    rects=[];unique=[]
    for y in range(0,diff.height,256):
        for x in range(0,diff.width,256):
            frame=diff.crop((x,y,x+256,y+256));b=frame.getbbox();require(b is not None,'empty '+p.stem)
            require(b is not None and b[0]>=4 and b[1]>=4 and b[2]<=252 and b[3]<=252,'clipped '+p.stem)
            rects.append(b);unique.append(hashlib.sha256(frame.tobytes()).hexdigest())
    bounds[p.stem]={'bounds':rects,'unique_frames':len(set(unique))}
    if len(unique)>1:require(len(set(unique))>1,'static animation '+p.stem)
require((ROOT/'art/blender/monsters/eclusier_iso.blend').exists(),'blend source')
require((HERE/'_c7a_contact.png').exists(),'contact')
report={'contract':'PASS' if not errors else 'FAIL','original_files':len(inv['files']),'animations':len(all_anims),'errors':errors,'bounds':bounds}
(HERE/'_c7a_verification.json').write_text(json.dumps(report,indent=2))
print(report['contract'],len(inv['files']),'original files;',len(all_anims),'animations;',len(errors),'errors')
for e in errors[:12]:print(e)
raise SystemExit(bool(errors))
