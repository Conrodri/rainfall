import json, hashlib, re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/bosses/mini'
INV=Path(__file__).with_name('_r8b_inventory.json')
def scan():
    result={}
    for p in sorted(q for name in ('bramble_queen','brood_mother') for q in (OUT/name).rglob('*')):
        if not p.is_file():continue
        item={'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
        if p.suffix=='.png':
            with Image.open(p) as im:item.update(size=list(im.size),mode=im.mode,grid=[im.width//170,im.height//170])
        result[str(p.relative_to(OUT))]=item
    return result
if __name__=='__main__':
    import sys
    if '--verify' not in sys.argv:
        assert not INV.exists(), 'Inventory already exists'
        INV.write_text(json.dumps({'frame':170,'files':scan()},indent=2))
        print('PASS inventory',len(scan()),'files')
    else:
        old=json.loads(INV.read_text())['files'];new=scan();assert old.keys()==new.keys(), 'File set changed'
        for n,v in old.items():
            if n.endswith('.png'):assert all(v[k]==new[n][k] for k in ('size','mode','grid')),n
            else:assert v['sha256']==new[n]['sha256'],n
        print('PASS names, dimensions, grids, non-PNG hashes:',len(new),'files')
