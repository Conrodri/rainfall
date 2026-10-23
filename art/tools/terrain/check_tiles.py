"""PIL = reduction + recadrage + assemblage 2x2 uniquement (pixels 100 % rendus par Blender).
Rendus 768 px (12 u) -> reduit a 384 puis recadre le centre 256 (periode exacte de 8 u, sans effet de bord).
Rendus 512 px (anciens terraces) -> reduits a 256.
Usage : check_tiles.py --biome fog_forest [--only ground_grass cliff_edge]
Imprime : couleur moyenne, L*, ecart de couture (doit etre ~ ecart voisin) et ecart a la moyenne de la normale."""
from pathlib import Path
import argparse, math
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
p = argparse.ArgumentParser(); p.add_argument("--biome", default="terraces"); p.add_argument("--only", nargs="*"); a = p.parse_args()
dest = ROOT / "game/assets/sprites/terrain" / a.biome; dest.mkdir(parents=True, exist_ok=True)
check = ROOT / "art/renders/terrain/check"; check.mkdir(parents=True, exist_ok=True)


def lstar(c):
    def f(v):
        v /= 255; v = v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4; return v
    y = .2126 * f(c[0]) + .7152 * f(c[1]) + .0722 * f(c[2])
    return 116 * (y ** (1 / 3)) - 16 if y > .008856 else 903.3 * y


def seam(im):
    px = im.convert("RGB").load(); w, h = im.size
    def d(x1, x2): return sum(sum(abs(px[x1, y][k] - px[x2, y][k]) for k in range(3)) for y in range(h)) / (h * 3)
    def e(y1, y2): return sum(sum(abs(px[x, y1][k] - px[x, y2][k]) for k in range(3)) for x in range(w)) / (w * 3)
    return d(0, w - 1), d(w // 2, w // 2 + 1), e(0, h - 1), e(h // 2, h // 2 + 1)


for path in sorted((ROOT / "art/renders/terrain" / a.biome).glob("*.png")):
    if a.only and path.stem.removesuffix("_n") not in a.only: continue
    with Image.open(path) as src:
        src = src.convert("RGBA")
        if src.width == 768:
            tile = src.resize((384, 384), Image.Resampling.LANCZOS).crop((64, 64, 320, 320))
        else:
            tile = src.resize((256, 256), Image.Resampling.LANCZOS)
    tile.save(dest / path.name)
    canvas = Image.new("RGBA", (512, 512))
    for xy in ((0, 0), (256, 0), (0, 256), (256, 256)): canvas.paste(tile, xy)
    canvas.save(check / (a.biome + "_" + path.stem + "_2x2.png"))
    m = tile.convert("RGB").resize((1, 1), Image.Resampling.BOX).getpixel((0, 0))
    sx, nx, sy, ny = seam(tile)
    print(f"{path.name:24s} mean={m} L*={lstar(m):5.1f} seamX={sx:5.1f} (voisin {nx:5.1f}) seamY={sy:5.1f} (voisin {ny:5.1f})")

names = ["ground_moss", "ground_stone", "ground_mud", "ground_grass", "water_deep", "water_shallow", "cliff_edge"]
if a.biome == "fog_forest": names = ["ground_moss", "ground_roots", "ground_needles", "ground_mud", "water_deep", "water_shallow", "cliff_edge"]
if a.biome == "rust_city": names = ["ground_concrete", "ground_rust", "ground_grate", "ground_bridge", "water_deep", "water_shallow", "cliff_edge"]
for suffix in ("", "_n"):
    sheet = Image.new("RGBA", (512 * 4, 512 * 2))
    ok = True
    for i, name in enumerate(names):
        f = check / (a.biome + "_" + name + suffix + "_2x2.png")
        if not f.exists(): ok = False; continue
        with Image.open(f) as im: sheet.paste(im, ((i % 4) * 512, (i // 4) * 512))
    sheet.save(check / (a.biome + suffix + "_overview.png"))
