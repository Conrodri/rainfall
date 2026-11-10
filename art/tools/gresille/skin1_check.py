"""Vérif du skin Fulgurite : IoU alpha et accent vs base, planche de comparaison (montage seulement)."""
from pathlib import Path
from PIL import Image
import numpy as np
ROOT = Path(__file__).resolve().parents[3]
B = ROOT / 'game/assets/sprites/characters/gresille'
S = B / 'skins/gresille_skin1'
N = {'idle': 8, 'run': 8, 'attack': 4, 'cast': 5, 'ground': 6, 'call': 8, 'death': 6}
wa = 1.0
we = 1.0
for a, k in N.items():
    for su, t in (('', 192), ('_e', 96)):
        X = np.array(Image.open(B / f'{a}{su}.png').convert('RGBA'))
        Y = np.array(Image.open(S / f'{a}{su}.png').convert('RGBA'))
        assert X.shape == Y.shape, (a, su, X.shape, Y.shape)
        for r in range(8):
            for f in range(k):
                cx = X[r*t:(r+1)*t, f*t:(f+1)*t]
                cy = Y[r*t:(r+1)*t, f*t:(f+1)*t]
                if su == '':
                    p = cx[..., 3] > 127
                    q = cy[..., 3] > 127
                    wa = min(wa, (p & q).sum() / max(1, (p | q).sum()))
                else:
                    p = cx[..., :3].max(-1) > 60
                    q = cy[..., :3].max(-1) > 60
                    if (p | q).sum() > 20:
                        we = min(we, (p & q).sum() / (p | q).sum())
print('alpha IoU min', round(wa, 3), 'accent IoU min', round(we, 3))
cell = 192
out = Image.new('RGBA', (cell * 12, cell * 3), (70, 78, 74, 255))
for i, (a, f) in enumerate([('call', 3), ('call', 6), ('attack', 1)]):
    for j, d in enumerate([1, 2, 5]):
        for k, P in enumerate((B, S)):
            im = Image.open(P / f'{a}.png').convert('RGBA').crop((f*cell, d*cell, (f+1)*cell, (d+1)*cell))
            out.alpha_composite(im, ((i*2+k)*cell, j*cell))
out.convert('RGB').save(ROOT / 'art/renders/gresille/skin1_check.png')
