"""(planches en grille : cellules lues de gauche à droite puis ligne suivante)
Génère les SpriteFrames .tres des VFX de Grésille à partir des planches (une ligne de cellules).
Usage : python make_tres.py  (depuis n'importe où ; écrit à côté des PNG)."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
VFX = ROOT / "game/assets/sprites/vfx/gresille"

# nom -> (cellule w, h, [(animation, première frame, nombre, fps, boucle)])
SPECS = {
    "static_crawl": (64, 64, [("default", 0, 4, 14.0, True)]),
    "zap_flash": (96, 96, [("default", 0, 3, 18.0, False)]),
    "discharge_burst": (192, 192, [("default", 0, 6, 20.0, False)]),
    "bolt_strike": (192, 384, [("default", 0, 6, 20.0, False)]),
    "ground_field": (384, 384, [("default", 0, 8, 12.0, True), ("end", 8, 3, 12.0, False)]),
    "rod_planted": (128, 192, [("appear", 0, 4, 14.0, False), ("idle", 4, 6, 10.0, True)]),
    "jar_fly": (64, 64, [("default", 0, 8, 16.0, True)]),
    "jar_burst": (512, 320, [("default", 0, 6, 16.0, False)]),
}


def build(name, cw, ch, anims):
    png = VFX / name / f"{name}.png"
    w, h = Image.open(png).size
    cols = w // cw
    assert h % ch == 0 and w % cw == 0, (name, w, h)
    total = sum(a[2] for a in anims)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={total + 2} format=3]', "",
             f'[ext_resource type="Texture2D" path="res://assets/sprites/vfx/gresille/{name}/{name}.png" id="1"]', ""]
    for i in range(cols * (h // ch)):
        lines += [f'[sub_resource type="AtlasTexture" id="a{i}"]', 'atlas = ExtResource("1")',
                  f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    entries = []
    for an, first, n, fps, loop in anims:
        frs = ", ".join('{"duration": 1.0, "texture": SubResource("a%d")}' % (first + k) for k in range(n))
        entries.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' % (frs, "true" if loop else "false", an, fps))
    lines += ["[resource]", "animations = [" + ", ".join(entries) + "]", ""]
    (VFX / name / f"{name}.tres").write_text("\n".join(lines), encoding="utf-8")


if __name__ == "__main__":
    for k, (cw, ch, an) in SPECS.items():
        if (VFX / k / f"{k}.png").exists():
            build(k, cw, ch, an)
            print("ok", k)
