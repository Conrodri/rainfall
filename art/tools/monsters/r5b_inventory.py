"""Snapshot/check the exact R5b asset contract; no image decoding needed."""
import hashlib, json, struct, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
NAMES=('ash_lord','bramble_queen','brood_mother')
DEST=Path(__file__).with_name('_r5b_inventory.json')
def snapshot():
    result={}
    for name in NAMES:
        files={}
        for p in sorted((ROOT/'game/assets/sprites/bosses/mini'/name).rglob('*')):
            if not p.is_file():continue
            data=p.read_bytes(); entry={}
            if p.suffix=='.png':entry['size']=struct.unpack('>II',data[16:24])
            else:entry['sha256']=hashlib.sha256(data).hexdigest()
            files[p.relative_to(ROOT/'game/assets/sprites/bosses/mini'/name).as_posix()]=entry
        result[name]=files
    return result
if __name__=='__main__':
    current=snapshot()
    if '--check' in sys.argv:
        assert json.loads(json.dumps(current))==json.loads(DEST.read_text()), 'Asset contract changed'
        print('PASS R5b filenames, sizes and all non-PNG hashes')
    else:
        assert not DEST.exists(), 'Inventory already exists; do not overwrite baseline'
        DEST.write_text(json.dumps(current,separators=(',',':')))
        print('PASS inventory', {n:len(f) for n,f in current.items()})

