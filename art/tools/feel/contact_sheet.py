"""Planche de contrôle : idle + anims d'action, direction donnée (rangée), une ligne par anim. Usage : contact_sheet.py <perso> <sortie.png> <dir_idx> anim1 anim2 ..."""
import sys
from pathlib import Path
from PIL import Image
perso, out, di = sys.argv[1], sys.argv[2], int(sys.argv[3])
anims = ['idle'] + sys.argv[4:]
base = f'game/assets/sprites/characters/{perso}/'
C = 192
rows = []
for a in anims:
    im = Image.open(base + a + '.png').convert('RGBA')
    if perso == 'tocsin' and im.height != C * 8:
        from tocsin_actions_build import load_frames, DIRS
        frames = load_frames(a, DIRS[di])
    else:
        frames = [im.crop((i * C, di * C, (i + 1) * C, (di + 1) * C)) for i in range(im.width // C)]
    rows.append((a, frames))
W = max(len(r[1]) for r in rows) * C
sheet = Image.new('RGBA', (W, C * len(rows)), (58, 62, 70, 255))
for y, (a, fr) in enumerate(rows):
    for x, f in enumerate(fr):
        sheet.alpha_composite(f, (x * C, y * C))
s = min(1.0, 1024 / W)
sheet = sheet.resize((int(W * s), int(C * len(rows) * s)), Image.LANCZOS)
sheet.save(out)
print(out, sheet.size)
