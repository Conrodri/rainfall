"""Planche de contrôle des props B (assemblage seulement, aucun dessin).
Usage : python b_contact.py <lot> <dossier_props> <biome_terrain> name:fx:fy [name:fx:fy ...] [--ref a,b,c]
Pose chaque prop (pied = foot) sur un champ de ground_a du biome, avec son ombre (calque TOP 512, centre = pied)
et son _e en additif ; refs : props existants du dossier (pied au bas-centre approximatif).
"""
import sys
from pathlib import Path
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[3]
lot, folder, biome = sys.argv[1:4]
args = [a for a in sys.argv[4:] if not a.startswith('--')]
refs = []
if '--ref' in sys.argv:
    refs = sys.argv[sys.argv.index('--ref') + 1].split(',')
    args = [a for a in args if a != sys.argv[sys.argv.index('--ref') + 1]]
P = ROOT / 'game/assets/sprites/props' / folder
g = Image.open(ROOT / f'game/assets/sprites/terrain/{biome}/iso/ground_a.png').convert('RGBA')
items = [(a.split(':')[0], int(a.split(':')[1]), int(a.split(':')[2])) for a in args]
n = len(items) + len(refs)
cw, ch = 340, 330
cols = min(n, 3)
rows = (n + cols - 1) // cols
W, H = cols * cw, rows * ch
canvas = Image.new('RGBA', (W, H), (18, 16, 18, 255))
# champ de sol : losanges 512x256 (4 u) en quinconce
gw, gh = g.size
for y in range(-gh, H + gh, gh // 2):
    for x in range(-gw, W + gw, gw):
        off = (gw // 2) if (y // (gh // 2)) % 2 else 0
        canvas.alpha_composite(g, (x + off, y))


def put(name, fx, fy, cx, cy, tag=''):
    im = Image.open(P / f'{name}.png').convert('RGBA')
    sp = P / f'{name}_shadow.png'
    if sp.exists():
        s = Image.open(sp).convert('RGBA')
        a = s.split()[3]
        layer = Image.new('RGBA', s.size, (0, 0, 0, 0))
        layer.putalpha(a)
        # le jeu projette l'ombre TOP (128 px/u) sur le sol iso : rotation 45 deg, x0,707, écrasement 0,5
        layer = layer.rotate(45, resample=Image.Resampling.BICUBIC, expand=True)
        layer = layer.resize((int(layer.width * 0.707), int(layer.height * 0.707 * 0.5)), Image.Resampling.BILINEAR)
        canvas.alpha_composite(layer, (cx - layer.width // 2, cy - layer.height // 2))
    canvas.alpha_composite(im, (cx - fx, cy - fy))
    ep = P / f'{name}_e.png'
    if ep.exists():
        e = Image.open(ep).convert('RGBA').resize(im.size, Image.Resampling.BILINEAR)
        base = canvas.crop((cx - fx, cy - fy, cx - fx + im.width, cy - fy + im.height))
        add = ImageChops.add(base.convert('RGB'), Image.merge('RGB', [ImageChops.multiply(c, e.split()[3]) for c in e.split()[:3]]))
        base.paste(add, (0, 0))
        canvas.paste(base, (cx - fx, cy - fy))


i = 0
for name, fx, fy in items:
    cx, cy = (i % cols) * cw + cw // 2, (i // cols) * ch + ch * 2 // 3
    put(name, fx, fy, cx, cy)
    i += 1
for name in refs:
    im = Image.open(P / f'{name}.png')
    cx, cy = (i % cols) * cw + cw // 2, (i // cols) * ch + ch * 2 // 3
    put(name, im.width // 2, int(im.height * 0.8), cx, cy)
    i += 1
out = ROOT / 'art/renders/props_b' / f'{lot}.png'
out.parent.mkdir(parents=True, exist_ok=True)
canvas.convert('RGB').save(out)
print(out, canvas.size)
