"""Sol v2 (GroundSplat) : textures de base PROVISOIRES tirées des tuiles iso livrées par Codex.

Aucun dessin : on « déprojette » (rééchantillonnage géométrique) le losange 512x256 d'une tuile
`ground_<v>.png` (bloc de 4 u x 4 u vu en dimétrique 2:1) vers un carré vu de dessus de 512 px
(128 px/u), éventuellement recadré sur une sous-zone (pour éviter les canaux / plaques uniques qui
marquaient la grille de 4 u), fenêtre calée sur le pas des dalles pour un raccord exact.
Les vraies textures (contrat art/briefs/SOL_contrat.md) remplaceront ces fichiers sous les mêmes noms.

Usage : python tools/sol_v2_reproject.py            (régénère tout game/assets/sprites/terrain/*/sol/)
        python tools/sol_v2_reproject.py --preview <png>   (planche de contrôle)
"""
import os
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "sprites", "terrain")
PX_PER_U = 128  # densité >= écran (72 px/u)
OUT_PX = 512  # tuile entière (4 u)

# biome -> dossier de tuiles iso ; couches -> (tuile source, sous-zone u0,v0,u1,v1 du bloc en fraction)
# Une sous-zone répétée = période plus courte mais sans motif unique (canal, plaque, cercle gravé).
SPEC = {
    # Fenêtres calées sur le pas des dalles (relevé des lignes sombres, 31/10/2026) et choisies sans
    # motif unique (variance minimale) : la texture se raccorde exactement, sans fondu.
    "terraces": {
        "base_0": ("ground_a", (0.2426, 0.3685, 0.4926, 0.6185)),
        "base_1": ("ground_b", (0.2426, 0.3685, 0.4926, 0.6185)),
    },
    "fog_forest": {  # sol organique : tuile entière
        "base_0": ("ground_a", (0.0, 0.0, 1.0, 1.0)),
        "base_1": ("ground_c", (0.0, 0.0, 1.0, 1.0)),
    },
    "rust_city": {
        "base_0": ("ground_a", (0.3707, 0.0787, 0.6207, 0.3287)),
        "base_1": ("ground_b", (0.6207, 0.2454, 0.8707, 0.4954)),
    },
    "crypts": {
        "base_0": ("ground_b", (0.1207, 0.1207, 0.3707, 0.3707)),
        "base_1": ("ground_d", (0.2457, 0.2457, 0.4957, 0.4957)),
    },
    "source": {
        "base_0": ("ground_a", (0.3293, 0.3293, 0.6626, 0.6626)),
        "base_1": ("ground_c", (0.1626, 0.4959, 0.4959, 0.8292)),
    },
}
INSET = 0.012  # évite la bordure antialiasée du losange


def reproject(src: Image.Image, box) -> Image.Image:
    """Carré vu de dessus (u, v) -> pixel du losange : x = 256 + (u - v) * 256, y = (u + v) * 128."""
    w, h = src.size
    u0, v0, u1, v1 = box
    u0, v0 = max(u0, INSET), max(v0, INSET)
    u1, v1 = min(u1, 1.0 - INSET), min(v1, 1.0 - INSET)
    out_px = int(round((box[2] - box[0]) * 4 * PX_PER_U))
    # transformation affine inverse (PIL : sortie -> entrée)
    su = (u1 - u0) / out_px
    sv = (v1 - v0) / out_px
    hw, hh = w * 0.5, h * 0.5
    # x_in = hw + (u - v) * hw = hw + hw*(u0 + su*X) - hw*(v0 + sv*Y)
    a = hw * su
    b = -hw * sv
    c = hw + hw * u0 - hw * v0
    d = hh * su
    e = hh * sv
    f = hh * u0 + hh * v0
    out = src.convert("RGBA").transform((out_px, out_px), Image.AFFINE, (a, b, c, d, e, f), resample=Image.BICUBIC)
    return out


def main() -> None:
    preview = None
    if "--preview" in sys.argv:
        preview = sys.argv[sys.argv.index("--preview") + 1]
    tiles = []
    for biome, layers in SPEC.items():
        out_dir = os.path.join(ROOT, biome, "sol")
        os.makedirs(out_dir, exist_ok=True)
        for name, (tile, box) in layers.items():
            src = Image.open(os.path.join(ROOT, biome, "iso", tile + ".png"))
            img = reproject(src, box)
            img.putalpha(255)
            img.convert("RGB").save(os.path.join(out_dir, name + ".png"), optimize=True)
            tiles.append(img)
    if preview:
        cols = 4
        rows = (len(tiles) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * 256 * 2, rows * 256))
        for i, t in enumerate(tiles):
            n = max(1, OUT_PX // t.size[0])  # répété sur 4 u x 2 pour juger le raccord
            t2 = Image.new("RGBA", (t.size[0] * n * 2, t.size[1] * n))
            for k in range(n * 2):
                for m in range(n):
                    t2.paste(t, (k * t.size[0], m * t.size[1]))
            sheet.paste(t2.resize((512, 256)).convert("RGB"), ((i % cols) * 512, (i // cols) * 256))
        sheet.save(preview)


if __name__ == "__main__":
    main()
