"""Planche de contrôle des particules d'état (vérification seulement) : fond sombre, x4, puis sur un monstre de 64 px."""
import glob
import os
from PIL import Image, ImageChops

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
D = os.path.join(ROOT, "game", "assets", "sprites", "vfx", "status")
ADD = ("burn_flame", "burn_ember", "shock_arc", "stun_star")
S, W = 4, 1000
x = y = rowh = 0
im = Image.new("RGBA", (W, 1000), (40, 36, 32, 255))
for f in sorted(glob.glob(os.path.join(D, "*.png"))):
    t = Image.open(f).convert("RGBA")
    t = t.resize((t.width * S, t.height * S), Image.NEAREST)
    if x + t.width > W:
        x = 0
        y += rowh + 6
        rowh = 0
    im.alpha_composite(t, (x, y))
    x += t.width + 6
    rowh = max(rowh, t.height)
im = im.crop((0, 0, W, y + rowh + 6))
im.save(os.path.join(ROOT, "art", "renders", "status_fx", "planche.png"))
print(im.size)
