"""Outils de raccord et de vérification des textures de sol v2 (rognage/assemblage seulement, aucun dessin).
Usage Blender-side : rendre une image brute N x N (N>=1024) avec matériau en Emission (pas de lampe, pas de dégradé),
puis make_seamless(raw_path, out_path, size=512). Vérif : verify(path), sheet3x3(path, out)."""
import sys
import numpy as np
from PIL import Image


def make_seamless(raw_path, out_path, size=512, band=0.5):
    """Raccord par décalage d'une demi-période et fondu cosinus (les bords du brut deviennent le centre).
    band = largeur relative du fondu (0.5 : fondu sur tout le brut, ghosting maximal ; 0.3 : bande étroite)."""
    im = Image.open(raw_path).convert("RGB")
    a = np.asarray(im, dtype=np.float32)
    n = a.shape[0]
    rolled = np.roll(a, (n // 2, n // 2), axis=(0, 1))
    x = (np.arange(n) + 0.5) / n
    d = np.minimum(x, 1 - x) * 2  # 0 au bord, 1 au centre
    t = np.clip(d / max(band, 1e-3), 0, 1)
    w1 = 0.5 - 0.5 * np.cos(np.pi * t)
    w = np.outer(w1, w1)[..., None]
    out = a * w + rolled * (1 - w)
    img = Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8))
    if size != n:
        img = img.resize((size, size), Image.LANCZOS)
    img.save(out_path, optimize=True)
    return out_path


def seam_ratio(path):
    a = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32)
    sh = np.abs(a[:, 0] - a[:, -1]).mean()
    sv = np.abs(a[0] - a[-1]).mean()
    adj = (np.abs(np.diff(a, axis=1)).mean() + np.abs(np.diff(a, axis=0)).mean()) / 2
    return max(sh, sv) / max(adj, 1e-3)


def verify(path, size=512):
    im = Image.open(path)
    a = np.asarray(im.convert("RGB"), dtype=np.float32)
    import os
    return {"size": im.size, "mode": im.mode, "ok_size": im.size == (size, size),
            "kb": os.path.getsize(path) // 1024, "seam_ratio": round(float(seam_ratio(path)), 2),
            "mean_rgb": [int(v) for v in a.reshape(-1, 3).mean(0)], "std": round(float(a.std()), 1)}


def sheet3x3(path, out):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    s = Image.new("RGB", (w * 3, h * 3))
    for i in range(3):
        for j in range(3):
            s.paste(im, (i * w, j * h))
    s.thumbnail((1024, 1024))
    s.save(out)


if __name__ == "__main__":
    for p in sys.argv[1:]:
        print(p, verify(p))
