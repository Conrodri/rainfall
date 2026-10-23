"""Verify the exported BO1 contract without loading Blender or changing assets."""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib, json, re
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/characters/bourbe'
m=json.loads((OUT/'bo1_manifest.json').read_text());issues=[];margins={};maxside=0
for anim,n in m['animations'].items():
    ims=[Image.open(OUT/(anim+s+'.png')).convert('RGBA') for s in ('','_n','_e')]
    for im in ims:
        maxside=max(maxside,*im.size)
        if im.size!=(n*192,1536):issues.append(anim+' dimensions')
    for im in ims[1:]:
        if ImageChops.difference(ims[0].getchannel('A'),im.getchannel('A')).getbbox():issues.append(anim+' pass alpha')
    margin=192
    for row in range(8):
        hashes=[]
        for f in range(n):
            cell=ims[0].crop((f*192,row*192,(f+1)*192,(row+1)*192));b=cell.getchannel('A').getbbox()
            if b:margin=min(margin,b[0],b[1],192-b[2],192-b[3])
            else:issues.append(anim+' empty frame')
            hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
        if len(set(hashes))!=n:issues.append(anim+' duplicate frames '+m['directions'][row])
    margins[anim]=margin
    if margin<4:issues.append(anim+' clipped')
t=(OUT/'bourbe.tres').read_text();frames=sum(m['animations'].values())*8
if len(re.findall('type="AtlasTexture"',t))!=frames or len(re.findall('"name": &"',t))!=88:issues.append('SpriteFrames contract')
if maxside>4096:issues.append('texture budget')
report=dict(status='FAIL' if issues else 'PASS',atlases=33,max_side=maxside,animations=88,frames=frames,min_margins=margins,issues=issues)
(ROOT/'art/blender/characters/bourbe_verify.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report));raise SystemExit(bool(issues))
