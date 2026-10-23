"""Masques d'émission `<f>_e.png` : demi-résolution et masques noirs (budget mobile).

Usage : python art/tools/halve_emission.py                 (mesure seulement, rien n'est modifié)
        python art/tools/halve_emission.py --apply         (réduit les _e pleine taille à 1/2)
        python art/tools/halve_emission.py --black         (liste les _e noirs ou vides et leurs références)
        python art/tools/halve_emission.py --black --apply (supprime les _e noirs NON référencés, PNG + .import)
Options : --min-age-min N (défaut 30) : ignore les fichiers (diffus ou _e) modifiés il y a moins de N min
          (lots Codex en cours d'écriture : ils seront traités au passage suivant) ;
          --before "AAAA-MM-JJ HH:MM" : ignore les fichiers modifiés après cette date ;
          --threshold T (défaut 2/255) : un _e est « noir » si max(alpha × luminance) <= T ;
          --filter peak|lanczos (défaut peak) : voir plus bas.

Règle (art/briefs/STYLE_cel.md) : un `_e` est livré pleine taille (même taille que le diffus) ou à
demi-résolution ((w+1)//2 × (h+1)//2). Le jeu déduit le rapport des tailles diffus/_e
(NormalMaps.emission_ratio) : aucune marque dans le nom, un _e pleine taille livré plus tard marche
tel quel et sera réduit au passage suivant de ce script.
Filtre : en couleurs prémultipliées par l'alpha, Lanczos (Pillow), puis « peak » (défaut) :
max(Lanczos, 0,75 × max du bloc 2×2). Le Lanczos seul divise par ~2 les accents fins de 1 px (œil du
cerf, filets du tisserand) : mesuré sur art/archive_3d, 6 % des pixels d'accent passent sous 60 %
de leur éclat (pire planche 17 %) contre 0,7 % (pire 5 %) avec « peak ». Alpha conservé, mode d'image
conservé. Le passage du 22/10/2026 (617 planches) a été fait en Lanczos seul, avant ce correctif.
Hors champ : ui/ et icons/ (lossless, lus directement par l'UI), _e sans diffus (ex. cliff_corner_e
= coin est), masques de moins de 64 px de côté (gain nul). Après --apply :
godot --headless --path game --import, puis tests/texture_budget_test.
"""
from __future__ import annotations

import datetime
import os
import sys
import time

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")
ASSETS = os.path.join(GAME, "assets")
EXCLUDE_DIRS = ("assets/sprites/ui/", "assets/sprites/icons/")
MIN_SIDE = 64
TEXT_EXT = (".tres", ".tscn", ".gd", ".json", ".cfg")


def half(n: int) -> int:
    return (n + 1) // 2


def png_size(path: str) -> tuple[int, int]:
    with Image.open(path) as im:
        return im.size


def pairs():
    """(chemin relatif à game/ du _e, chemin absolu du _e, chemin absolu du diffus)."""
    for dp, dn, fn in os.walk(ASSETS):
        for f in sorted(fn):
            if not f.endswith("_e.png"):
                continue
            e = os.path.join(dp, f)
            d = os.path.join(dp, f[:-6] + ".png")
            rel = os.path.relpath(e, GAME).replace(os.sep, "/")
            if os.path.exists(d) and not rel.startswith(EXCLUDE_DIRS):
                yield rel, e, d


def downscale(im: Image.Image, peak: bool = True, k: float = 0.75) -> Image.Image:
    """RGBA -> demi-résolution ((w+1)//2 × (h+1)//2), en prémultiplié : Lanczos, et en mode peak
    max(Lanczos, k × max du bloc 2×2) pour garder l'éclat des accents fins."""
    a = np.asarray(im, dtype=np.float32) / 255.0
    pm = a.copy()
    pm[..., :3] *= pm[..., 3:4]
    h, w = pm.shape[:2]
    H, W = half(h), half(w)
    lz = np.asarray(Image.fromarray(np.round(pm * 255.0).astype(np.uint8), "RGBA")
                    .resize((W, H), Image.Resampling.LANCZOS), dtype=np.float32) / 255.0
    if peak:
        pad = np.zeros((H * 2, W * 2, 4), np.float32)
        pad[:h, :w] = pm
        lz = np.maximum(lz, k * pad.reshape(H, 2, W, 2, 4).max(axis=(1, 3)))
    alpha = np.clip(lz[..., 3:4], 0.0, 1.0)
    rgb = np.where(alpha > 1e-6, lz[..., :3] / np.maximum(alpha, 1e-6), 0.0)
    out = np.concatenate([np.clip(rgb, 0.0, 1.0), alpha], axis=2)
    return Image.fromarray(np.round(out * 255.0).astype(np.uint8), "RGBA")


def emission_peak(path: str) -> float:
    with Image.open(path) as im:
        a = np.asarray(im.convert("RGBA"), dtype=np.float32) / 255.0
    lum = 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]
    return float((lum * a[..., 3]).max()) if a.size else 0.0


def text_files():
    out = {}
    for dp, dn, fn in os.walk(GAME):
        dn[:] = [x for x in dn if x not in (".godot", ".git")]
        for f in fn:
            if f.endswith(TEXT_EXT):
                p = os.path.join(dp, f)
                try:
                    with open(p, encoding="utf-8", errors="ignore") as fh:
                        out[os.path.relpath(p, GAME).replace(os.sep, "/")] = fh.read()
                except OSError:
                    pass
    return out


def import_uid(png: str) -> str:
    try:
        with open(png + ".import", encoding="utf-8") as fh:
            for line in fh:
                if line.startswith("uid="):
                    return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return ""


def remove_png(abs_png: str) -> None:
    for p in (abs_png, abs_png + ".import"):
        if os.path.exists(p):
            os.remove(p)


def main(argv) -> int:
    apply = "--apply" in argv
    min_age = float(argv[argv.index("--min-age-min") + 1]) if "--min-age-min" in argv else 30.0
    cutoff = time.time() - min_age * 60.0
    if "--before" in argv:
        cutoff = min(cutoff, datetime.datetime.strptime(argv[argv.index("--before") + 1], "%Y-%m-%d %H:%M").timestamp())
    thr = float(argv[argv.index("--threshold") + 1]) if "--threshold" in argv else 2.0 / 255.0

    if "--black" in argv:
        texts = text_files()
        black = []
        for rel, e, d in pairs():
            if max(os.path.getmtime(e), os.path.getmtime(d)) > cutoff:
                continue
            peak = emission_peak(e)
            if peak <= thr + 1e-9:
                uid = import_uid(e)
                refs = [k for k, t in texts.items() if rel in t or (uid and uid in t)]
                black.append((rel, peak, refs, e))
        print(f"_e noirs ou vides (max alpha×luminance <= {thr * 255:.1f}/255) : {len(black)}")
        removed = 0
        for rel, peak, refs, e in black:
            tag = f"  RÉFÉRENCÉ par {refs}" if refs else ""
            print(f"  {peak * 255:4.1f}/255  {rel}{tag}")
            if apply and not refs:
                remove_png(e)
                removed += 1
        if apply:
            print(f"{removed} supprimé(s) (PNG + .import) ; les référencés sont à défaire d'abord.")
        return 0

    todo = []
    skipped_recent = skipped_small = already = other = 0
    for rel, e, d in pairs():
        dw, dh = png_size(d)
        ew, eh = png_size(e)
        if (ew, eh) == (half(dw), half(dh)):
            already += 1
            continue
        if (ew, eh) != (dw, dh):
            other += 1
            print(f"  ! taille _e incohérente {rel} {ew}x{eh} (diffus {dw}x{dh})")
            continue
        if min(dw, dh) < MIN_SIDE:
            skipped_small += 1
            continue
        if max(os.path.getmtime(e), os.path.getmtime(d)) > cutoff:
            skipped_recent += 1
            print(f"  récent, ignoré : {rel}")
            continue
        todo.append((rel, e, dw, dh))
    px = sum(w * h for _, _, w, h in todo)
    print(f"_e pleine taille à réduire : {len(todo)} ({px / 1e6:.0f} Mpx -> {px / 4e6:.0f} Mpx) ; "
          f"déjà à 1/2 : {already} ; < {MIN_SIDE} px : {skipped_small} ; récents : {skipped_recent} ; incohérents : {other}")
    if not apply:
        for rel, _, w, h in todo[:20]:
            print(f"  {w}x{h} -> {half(w)}x{half(h)}  {rel}")
        if len(todo) > 20:
            print(f"  ... (+{len(todo) - 20})")
        print("Mesure seulement : relancer avec --apply pour réduire.")
        return 0
    peak = (argv[argv.index("--filter") + 1] if "--filter" in argv else "peak") == "peak"
    for rel, e, w, h in todo:
        with Image.open(e) as im:
            im.load()
            mode = im.mode
            out = downscale(im.convert("RGBA"), peak)
            if mode in ("RGB", "L", "LA"):
                out = out.convert(mode)
        out.save(e, optimize=True)
    print(f"{len(todo)} _e réduits ; lancer : godot --headless --path game --import")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
