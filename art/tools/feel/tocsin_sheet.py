"""Planche d'une direction, une ligne par anim, cellules 192 px pleine taille (relecture des poses de Tocsin).
Usage : python art/tools/feel/tocsin_sheet.py <sortie.png> <direction> anim1 anim2 ..."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from tocsin_actions_build import load_frames
from PIL import Image

out, d = sys.argv[1], sys.argv[2]
rows = [load_frames(a, d) for a in sys.argv[3:]]
W = max(len(r) for r in rows) * 192
s = Image.new('RGBA', (W, 192 * len(rows)), (58, 62, 70, 255))
for y, r in enumerate(rows):
    for x, f in enumerate(r):
        s.alpha_composite(f, (x * 192, y * 192))
s.save(out)
print(out, s.size)
