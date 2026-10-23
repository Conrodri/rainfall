"""Read-only BO1 pixel/atlas audit; run with normal Python from any directory."""
import sys,json,hashlib,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image
P=ROOT/'game/assets/sprites/characters/bourbe'
ANIMS=dict(idle=8,run=8,slap=4,throw=4,recall=4,sink=4,rise=4,attack=4,cast=4,cast_ult=6,death=8)
errors=[];margins=[192]*4;duplicates=[]
for anim,n in ANIMS.items():
    images=[Image.open(P/(anim+s+'.png')).convert('RGBA') for s in ('','_n','_e')]
    if any(im.size!=(n*192,1536) for im in images):errors.append(anim+' wrong size')
    for row in range(8):
        hashes=[]
        for f in range(n):
            box=(f*192,row*192,(f+1)*192,(row+1)*192)
            cell=images[0].crop(box);bb=cell.getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
            if not bb:errors.append(f'{anim}:{row}:{f} empty');continue
            space=[bb[0],bb[1],192-bb[2],192-bb[3]]
            margins=[min(a,b) for a,b in zip(margins,space)]
            if min(space)<4:errors.append(f'{anim}:{row}:{f} margin {bb}')
            hashes.append(hashlib.sha256(cell.tobytes()).hexdigest())
            for im in images[1:2]:
                nb=im.crop(box).getchannel('A').point(lambda a:255 if a>=8 else 0).getbbox()
                if nb is None or max(abs(a-b) for a,b in zip(nb,bb))>2:errors.append(f'{anim}:{row}:{f} pass alpha mismatch')
        if len(set(hashes))!=n:duplicates.append([anim,row,n-len(set(hashes))])
for key in ('gifle_de_vase','detacher','rappel','bourbier'):
    im=Image.open(ROOT/'game/assets/sprites/icons/spells'/('bourbe_'+key+'.png'))
    if im.size!=(128,128):errors.append(key+' icon size')
text=(P/'bourbe.tres').read_text()
if len(re.findall(r'"name": &"',text))!=88:errors.append('SpriteFrames animation count')
report={'errors':errors,'duplicates':duplicates,'minimum_transparent_margins':margins,'atlases':33,'animations':88,'directional_frames':sum(ANIMS.values())*8,'maximum_side':1536}
Path(__file__).with_suffix('.json').write_text(json.dumps(report,indent=2))
print('BO1 AUDIT '+('PASS' if not errors and not duplicates else 'FAIL')+f': {len(errors)} errors, {len(duplicates)} duplicate poses; margins {margins}; '+str(errors[:4]))
sys.exit(bool(errors or duplicates))
