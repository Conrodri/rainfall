"""Prévisualisation des tuiles brutes de Tocsin (art/renders/feel_sorts2/tocsin_actions/raw) pour une direction.
Usage : python art/tools/feel/tocsin_preview_raw.py <sortie.png> <direction> [skin] anim1 anim2 ..."""
import sys, json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
out, d = sys.argv[1], sys.argv[2]
args = sys.argv[3:]
skin = False
if args and args[0] == 'skin':
    skin = True
    args = args[1:]
raw = ROOT / 'art/renders/feel_sorts2' / ('tocsin_skin_actions' if skin else 'tocsin_actions') / 'raw'
orders = json.loads((ROOT / 'game/assets/sprites/characters/tocsin/layers_order.json').read_text())['orders'][d]
rows = []
for a in args:
    frames = []
    i = 0
    while (raw / a / d / f'torso_{i:02d}.png').exists():
        im = Image.new('RGBA', (192, 192))
        for k in orders:
            if k == 'neck_steam' and not (a == 'throw_head' and i >= 3):
                continue
            q = raw / a / d / f'{k}_{i:02d}.png'
            if q.exists():
                im.alpha_composite(Image.open(q).convert('RGBA'))
        frames.append(im)
        i += 1
    rows.append(frames)
W = max(len(r) for r in rows) * 192
s = Image.new('RGBA', (W, 192 * len(rows)), (58, 62, 70, 255))
for y, r in enumerate(rows):
    for x, f in enumerate(r):
        s.alpha_composite(f, (x * 192, y * 192))
s.save(out)
print(out, s.size)
