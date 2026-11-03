"""Convertit une planche pixelfx (PNG + JSON Aseprite) en asset de TEST pour Godot.

Assets de test uniquement (accord du joueur, 03/11/2026) : ils ne remplacent aucun
asset Codex/Blender. Sortie dans game/assets/sprites/vfx_test/<owner>/<spell_id>/ :
  <spell_id>.png      planche agrandie au plus proche voisin (x2 par défaut), rognée
  <spell_id>.tres     SpriteFrames, animation "default" (fps et boucle de pixelfx)
  <spell_id>.meta.json  source pixelfx, options, fps, offset à donner à AnimatedSprite2D

Usage :
  python pixelfx_to_godot.py <planche.json> <owner> <spell_id> [--scale 2] [--fps 15]
         [--max-frames 60] [--source ID] [--opts JSON]
"""
import argparse
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
DEST_ROOT = ROOT / "game" / "assets" / "sprites" / "vfx_test"
MAX_TEX = 8192  # reste sous la limite des GPU mobiles


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet_json")
    ap.add_argument("owner")
    ap.add_argument("spell_id")
    ap.add_argument("--scale", type=int, default=2)
    ap.add_argument("--fps", type=float, default=15.0)
    ap.add_argument("--max-frames", type=int, default=60)
    ap.add_argument("--source", default="")
    ap.add_argument("--opts", default="{}")
    a = ap.parse_args()

    src_json = Path(a.sheet_json)
    data = json.loads(src_json.read_text(encoding="utf-8"))
    meta = data["meta"]["pixelfx"]
    sheet = Image.open(src_json.with_suffix(".png")).convert("RGBA")
    fw, fh = meta["frameSize"]
    src_fps = float(meta["fps"])
    loop = bool(meta["loop"])

    # Sous-échantillonnage temporel : fps cible, plafond de frames.
    rects = [f["frame"] for f in data["frames"]]
    step = max(1, round(src_fps / a.fps))
    picked = rects[::step]
    # Au-delà du plafond, on baisse le fps mais jamais sous 12 i/s (sinon ça saccade).
    while len(picked) > a.max_frames and src_fps / (step + 1) >= 12:
        step += 1
        picked = rects[::step]
    fps = src_fps / step
    frames = [sheet.crop((r["x"], r["y"], r["x"] + r["w"], r["y"] + r["h"])) for r in picked]

    # Rognage commun : boîte englobante de toutes les frames.
    box = None
    for f in frames:
        b = f.getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    if box is None:
        raise SystemExit(f"planche vide : {src_json}")
    frames = [f.crop(box) for f in frames]
    s = a.scale
    cw, ch = (box[2] - box[0]) * s, (box[3] - box[1]) * s
    frames = [f.resize((cw, ch), Image.NEAREST) for f in frames]

    cols = max(1, min(len(frames), MAX_TEX // cw, math.ceil(math.sqrt(len(frames) * ch / cw))))
    rows = math.ceil(len(frames) / cols)
    if rows * ch > MAX_TEX:
        raise SystemExit(f"planche trop grande ({cols}x{rows} de {cw}x{ch}) : baisser --max-frames ou --scale")
    out = Image.new("RGBA", (cols * cw, rows * ch), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % cols) * cw, (i // cols) * ch))

    dest = DEST_ROOT / a.owner / a.spell_id
    dest.mkdir(parents=True, exist_ok=True)
    png = dest / f"{a.spell_id}.png"
    out.save(png, optimize=True)

    res_png = "res://" + png.relative_to(ROOT / "game").as_posix()
    lines = ['[gd_resource type="SpriteFrames" format=3]', "",
             f'[ext_resource type="Texture2D" path="{res_png}" id="1_0"]', ""]
    for i in range(len(frames)):
        lines += [f'[sub_resource type="AtlasTexture" id="a{i + 1}"]', 'atlas = ExtResource("1_0")',
                  f"region = Rect2({(i % cols) * cw}, {(i // cols) * ch}, {cw}, {ch})", ""]
    anim_frames = ", ".join('{"duration": 1.0, "texture": SubResource("a%d")}' % (i + 1) for i in range(len(frames)))
    lines += ["[resource]", 'animations = [{', f'"frames": [{anim_frames}],',
              f'"loop": {"true" if loop else "false"},', '"name": &"default",', f'"speed": {fps:.3f}', "}]", ""]
    (dest / f"{a.spell_id}.tres").write_text("\n".join(lines), encoding="utf-8")

    # Offset pour AnimatedSprite2D centré : place le pivot pixelfx (pieds/origine) sur la position du nœud.
    px, py = meta["pivot"]
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    info = {
        "source": a.source or meta["id"], "opts": json.loads(a.opts), "owner": a.owner, "spell_id": a.spell_id,
        "fps": round(fps, 3), "loop": loop, "frames": len(frames), "frame_size": [cw, ch], "scale": s,
        "offset": [round((cx - px) * s, 1), round((cy - py) * s, 1)],
        "filter": "nearest", "test_asset": True,
    }
    (dest / f"{a.spell_id}.meta.json").write_text(json.dumps(info, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"OK {a.owner}/{a.spell_id} {len(frames)}f {cw}x{ch} {out.size[0]}x{out.size[1]} fps={fps:.1f}")


if __name__ == "__main__":
    main()
