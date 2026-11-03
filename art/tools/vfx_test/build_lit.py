"""VFX de TEST pixelfx, version lumineuse (deux couches + courbe de lumière).

Pour chaque game/assets/sprites/vfx_test/<owner>/<spell>/<spell>.meta.json (source et opts pixelfx) :
  - rend l'effet avec export_lit.mjs (couleur seule + tampon de lumière, lueur poussée à --light) ;
  - ramène à 15 i/s, rogne sur la boîte commune aux deux couches ;
  - recolore la couleur sur la palette du propriétaire et la lumière sur le haut de la rampe (accent) :
    aucune teinte hors DA ;
  - écrit <spell>.png / .tres (corps, mélange normal) et <spell>_e.png / _e.tres (halo, mélange additif,
    modulé en HDR en jeu pour la lueur), plus dans le meta : light_curve (intensité 0..1 par image),
    light_pos (centre de la lumière par image, px relatifs au pivot), light_color (accent).
  - planche > 4096 px : rendu à l'échelle 1 et "node_scale" pour agrandir le nœud (sans perte).
Usage : python build_lit.py [owner|owner/spell ...] [--light 1.0]
"""
import json
import math
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "game" / "assets" / "sprites" / "vfx_test"
EXPORTER = Path(__file__).with_name("export_lit.mjs")
TMP = Path(__file__).with_name("_tmp_lit")
MAX_SIDE = 4096
TARGET_FPS = 15.0
LIGHT_EPS = 6  # en dessous (sur 255), pas de lumière


def hex_rgb(h: str) -> tuple:
    h = h.lstrip("#")
    if len(h) == 3:
        h = "".join(c * 2 for c in h)
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def luma(a: np.ndarray) -> np.ndarray:
    return (0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]) / 255.0


def ramp_of(palette: list) -> np.ndarray:
    cols = sorted((hex_rgb(h) for h in palette), key=lambda c: luma(np.array(c, dtype=float)))
    return np.array(cols, dtype=np.uint8)


def accent_of(palette: list) -> str:
    # Accent = couleur la plus saturée et vive de la palette.
    def score(h):
        r, g, b = (v / 255 for v in hex_rgb(h))
        mx, mn = max(r, g, b), min(r, g, b)
        return (mx - mn) * mx
    return max(palette, key=score)


def remap(rgb: np.ndarray, ramp: np.ndarray, lum: np.ndarray) -> np.ndarray:
    lo = luma(ramp[0].astype(float))
    hi = luma(ramp[-1].astype(float))
    t = np.clip((lum - lo) / max(1e-6, hi - lo), 0.0, 1.0)
    return ramp[np.rint(t * (len(ramp) - 1)).astype(np.intp)]


def pack(frames: list, cw: int, ch: int):
    n = len(frames)
    cols = max(1, min(n, MAX_SIDE // cw, math.ceil(math.sqrt(n * ch / cw))))
    rows = math.ceil(n / cols)
    out = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % cols) * cw, (i // cols) * ch))
    return out, cols


def write_tres(path: Path, png: Path, n: int, cols: int, cw: int, ch: int, loop: bool, fps: float) -> None:
    res_png = "res://" + png.relative_to(ROOT / "game").as_posix()
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             f'[ext_resource type="Texture2D" path="{res_png}" id="1_0"]', ""]
    for i in range(n):
        lines += [f'[sub_resource type="AtlasTexture" id="a{i + 1}"]', 'atlas = ExtResource("1_0")',
                  f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim = ", ".join('{"duration": 1.0, "texture": SubResource("a%d")}' % (i + 1) for i in range(n))
    lines += ["[resource]", "animations = [{", f'"frames": [{anim}],',
              f'"loop": {"true" if loop else "false"},', '"name": &"default",', f'"speed": {fps:.3f}', "}]", ""]
    path.write_text("\n".join(lines), encoding="utf-8")


def build(meta_path: Path, light_k: float) -> str:
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    sid, owner = meta["spell_id"], meta["owner"]
    opts = dict(meta.get("opts") or {})
    palette = opts.get("palette")
    if not palette:
        return "SANS PALETTE, ignoré"
    tmp = TMP / owner / sid
    run = subprocess.run(["node", str(EXPORTER), meta["source"], str(tmp), json.dumps(opts), str(light_k)],
                         capture_output=True, text=True)
    if run.returncode != 0:
        return "ÉCHEC export : " + run.stderr.strip().splitlines()[-1]
    info = json.loads((tmp / "info.json").read_text())
    w, h, n = info["w"], info["h"], info["n"]
    base = np.fromfile(tmp / "base.rgba", dtype=np.uint8).reshape(n, h, w, 4)
    light = np.fromfile(tmp / "light.rgba", dtype=np.uint8).reshape(n, h, w, 4)
    shutil.rmtree(tmp, ignore_errors=True)

    step = max(1, round(info["fps"] / TARGET_FPS))
    base, light = base[::step], light[::step]
    fps = info["fps"] / step
    n = base.shape[0]

    lmax = light[..., :3].max(axis=-1)                    # intensité de lumière 0..255
    mask = (base[..., 3] > 0) | (lmax > LIGHT_EPS)
    ys, xs = np.nonzero(mask.any(axis=0))
    if len(xs) == 0:
        return "VIDE"
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    base, light, lmax = base[:, y0:y1, x0:x1], light[:, y0:y1, x0:x1], lmax[:, y0:y1, x0:x1]

    ramp = ramp_of(palette)
    body = base.copy()
    body[..., :3] = remap(base[..., :3], ramp, luma(base[..., :3].astype(float)))
    # Halo : teinte prise sur le haut de la rampe (accent), intensité portée par l'alpha.
    top = ramp[-3:]
    li = lmax.astype(float) / 255.0
    emis = np.zeros_like(light)
    emis[..., :3] = top[np.clip(np.rint(li * 2.999 - 0.5), 0, 2).astype(np.intp)]
    emis[..., 3] = np.where(lmax > LIGHT_EPS, np.clip(lmax.astype(float) * 1.15, 0, 255), 0).astype(np.uint8)

    # Courbe et centre de lumière par image (px pixelfx relatifs au pivot).
    px, py = info["pivot"]
    tot = li.sum(axis=(1, 2))
    curve = (tot / max(1e-6, tot.max())).round(3).tolist()
    gy, gx = np.mgrid[0:li.shape[1], 0:li.shape[2]]
    pos = []
    for i in range(n):
        s = tot[i]
        if s <= 1e-6:
            pos.append([0.0, 0.0])
        else:
            pos.append([round(float((li[i] * gx).sum() / s + x0 - px), 1), round(float((li[i] * gy).sum() / s + y0 - py), 1)])

    s = int(meta.get("scale", 2))
    ch0, cw0 = body.shape[1], body.shape[2]
    node_scale = 1
    for scale in (s, 1):
        cw, ch = cw0 * scale, ch0 * scale
        fb = [Image.fromarray(f, "RGBA").resize((cw, ch), Image.NEAREST) for f in body]
        out_b, cols = pack(fb, cw, ch)
        if max(out_b.size) <= MAX_SIDE or scale == 1:
            node_scale = s if scale == 1 and s > 1 else 1
            break
    if max(out_b.size) > MAX_SIDE:
        return f"TROP GRAND {out_b.size}"
    fe = [Image.fromarray(f, "RGBA").resize((cw, ch), Image.NEAREST) for f in emis]
    out_e, _ = pack(fe, cw, ch)

    k = cw / cw0  # facteur pixelfx -> px de la planche
    dest = meta_path.parent
    png_b, png_e = dest / f"{sid}.png", dest / f"{sid}_e.png"
    out_b.save(png_b, optimize=True)
    out_e.save(png_e, optimize=True)
    write_tres(dest / f"{sid}.tres", png_b, n, cols, cw, ch, info["loop"], fps)
    write_tres(dest / f"{sid}_e.tres", png_e, n, cols, cw, ch, info["loop"], fps)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    meta.update({
        "version": 2, "fps": round(fps, 3), "loop": info["loop"], "frames": n, "frame_size": [cw, ch],
        "scale": s, "node_scale": node_scale, "offset": [round((cx - px) * k, 1), round((cy - py) * k, 1)],
        "emission": f"{sid}_e.tres", "light_k": light_k, "light_color": accent_of(palette),
        "light_curve": curve, "light_pos": [[round(a * k, 1), round(b * k, 1)] for a, b in pos],
        "filter": "nearest", "test_asset": True,
    })
    for old in ("finalized", "palette_remapped"):
        meta.pop(old, None)
    meta_path.write_text(json.dumps(meta, indent=1, ensure_ascii=False), encoding="utf-8")
    return f"{n}f {fps:.0f}fps {out_b.size[0]}x{out_b.size[1]} x{node_scale}"


def main() -> None:
    args = sys.argv[1:]
    light_k = 1.0
    if "--light" in args:
        i = args.index("--light")
        light_k = float(args[i + 1])
        del args[i:i + 2]
    metas = sorted(BASE.glob("*/*/*.meta.json"))
    if args:
        metas = [m for m in metas if m.parent.parent.name in args or f"{m.parent.parent.name}/{m.parent.name}" in args]
    for m in metas:
        print(f"{m.parent.parent.name}/{m.parent.name}: {build(m, light_k)}", flush=True)
    shutil.rmtree(TMP, ignore_errors=True)


if __name__ == "__main__":
    main()
