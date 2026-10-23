"""Freeze and verify the existing Cerf asset contract; no image synthesis."""
import hashlib, json, sys
from pathlib import Path
from PIL import Image
from pack_cerf import DST, COUNTS

INVENTORY = Path(__file__).with_name('_r3a_inventory.json')

def snapshot():
    assets = []
    for path in sorted(DST.glob('*.png')):
        anim = path.stem.removesuffix('_n').removesuffix('_e')
        columns = COUNTS[anim]
        rows = 4 if anim.startswith('walk') else 1
        with Image.open(path) as im:
            assets.append(dict(name=path.name, size=list(im.size), columns=columns,
                               rows=rows, frames=columns*rows,
                               frame_size=[im.width//columns, im.height//rows]))
    return dict(assets=assets, tres_sha256=hashlib.sha256((DST/'cerf.tres').read_bytes()).hexdigest())

if __name__ == '__main__':
    current = snapshot()
    if '--capture' in sys.argv:
        assert not INVENTORY.exists(), 'Inventory already frozen'
        INVENTORY.write_text(json.dumps(current, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    else:
        assert current == json.loads(INVENTORY.read_text(encoding='utf-8')), 'Contract changed'
    print(f"PASS contract: {len(current['assets'])} PNG; names, sizes, grids, frames, tres")
