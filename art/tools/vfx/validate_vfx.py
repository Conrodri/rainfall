"""Controle des planches livrees : taille, marge transparente (>= 4 px), frames vides, raccord de boucle."""
import sys
from pathlib import Path
from unittest.mock import MagicMock
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.modules.setdefault('bpy', MagicMock()); sys.modules.setdefault('mathutils', MagicMock())
from PIL import Image, ImageChops, ImageStat
import fx_all
ROOT = Path(__file__).resolve().parents[3]
names = sys.argv[1:] or [k for k in fx_all.EFFECTS if not k.startswith('particles')]
for name in names:
    E = fx_all.EFFECTS[name]; w, h = E['size']; out = ROOT / 'game/assets/sprites/vfx' / name
    for anim, A in E['anims'].items():
        im = Image.open(out / (anim + '.png')).convert('RGBA'); n = A['n']
        ok = im.size == (w * n, h); worst = 99; empty = []
        frames = [im.crop((i * w, 0, i * w + w, h)) for i in range(n)]
        for i, fr in enumerate(frames):
            a = fr.getchannel('A').point(lambda v: 255 if v > 8 else 0); bb = a.getbbox()
            if not bb: empty.append(i); continue
            worst = min(worst, bb[0], bb[1], w - bb[2], h - bb[3])
        seam = ''
        if A['loop'] and n > 2:
            bg = Image.new('RGBA', (w, h), (28, 34, 44, 255))
            def flat(x): return Image.alpha_composite(bg, x).convert('RGB')
            d = [sum(ImageStat.Stat(ImageChops.difference(flat(frames[i]), flat(frames[(i + 1) % n]))).mean) / 3 for i in range(n)]
            seam = ' seam/mean=%.2f' % (d[-1] / (sum(d) / n))
        print('%-20s %-10s size_ok=%s n=%d min_margin=%s empty=%s%s' % (name, anim, ok, n, worst, empty, seam))
