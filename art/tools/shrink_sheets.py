"""Réduit les planches de CORPS d'un boss (re-échantillonnage fait par Blender, pas par PIL).

Lancement :
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --python art/tools/shrink_sheets.py -- \
      <dossier relatif à game/assets/sprites> <facteur> [--apply] [--fauna <id>] [--force] [--only a_s,b_s]
  --only : 2e passage, ne traite que ces animations (corps hors regex : phase2_s, ascend_s...) ; sans --fauna.

Exemple : ... -- bosses/etage/ox_herder 0.70 --apply --fauna ox_herder

Sans --apply : rapport seul. Avec --apply :
  - chaque planche de corps (animations idle/walk/auto/spell/... du .tres, jamais partagée avec un extra) est
    réduite : cellule -> round(cellule x facteur), planche = nb_cellules x nouvelle cellule ; couleurs
    prémultipliées par l'alpha avant le filtre (pas de halo sombre), espace non linéaire comme Godot ;
  - le masque `<f>_e.png` suit à demi-résolution ((w+1)//2 x (h+1)//2) ;
  - le .tres est réécrit : region et margin des AtlasTexture touchés x facteur (taille à l'écran inchangée
    une fois dim/bottom/fh de data/fauna.json multipliés par le facteur, fait ici avec --fauna) ;
  - les extras (effets de sol, projectiles, ...) ne sont pas touchés : le code les met à l'échelle en pixels.
Idempotent par dossier : art/tools/shrunk/<dossier>.txt bloque un second passage.
"""
import json
import os
import re
import sys

import bpy
import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPR = os.path.join(ROOT, "game", "assets", "sprites")
BODY_RE = re.compile(r"^(idle|walk|run|attack|auto|spell_[ab]|cast_[ab]|trans_p\d|death|bogged|hit|stun|enter|rise|roar|charge|slam)(_p\d)?_(e|s|w|n|ne|nw|se|sw)$")


def parse_tres(text):
    ext = {m[1]: m[0] for m in re.findall(r'\[ext_resource type="Texture2D"[^\]]*?path="res://([^"]+)" id="([^"]+)"\]', text)}
    subs = {}
    for m in re.finditer(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n((?:[^\[\n][^\n]*\n)+)', text):
        body = m.group(2)
        a = re.search(r'atlas = ExtResource\("([^"]+)"\)', body)
        r = re.search(r"region = Rect2\(([^)]*)\)", body)
        mg = re.search(r"margin = Rect2\(([^)]*)\)", body)
        subs[m.group(1)] = (a.group(1), [float(x) for x in r.group(1).split(",")] if r else None,
                            [float(x) for x in mg.group(1).split(",")] if mg else None)
    anims = []
    for m in re.finditer(r'\{"frames": \[(.*?)\], "loop": (?:true|false), "name": &"([^"]+)"', text):
        frames = re.findall(r'SubResource\("([^"]+)"\)', m.group(1))
        direct = re.findall(r'ExtResource\("([^"]+)"\)', m.group(1))
        anims.append((m.group(2), frames, direct))
    return ext, subs, anims


def load_np(path):
    img = bpy.data.images.load(path)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    w, h = img.size
    buf = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return buf.reshape(h, w, 4), w, h


def save_np(path, arr, w, h):
    img = bpy.data.images.new("out", w, h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    img.pixels.foreach_set(arr.reshape(-1))
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def resize(arr, w, h, nw, nh):
    """Prémultiplie, réduit avec le filtre de Blender (image.scale), dé-prémultiplie."""
    a = arr.copy()
    a[..., :3] *= a[..., 3:4]
    img = bpy.data.images.new("tmp", w, h, alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    img.pixels.foreach_set(a.reshape(-1))
    img.scale(nw, nh)
    out = np.empty(nw * nh * 4, dtype=np.float32)
    img.pixels.foreach_get(out)
    bpy.data.images.remove(img)
    out = out.reshape(nh, nw, 4)
    al = out[..., 3:4]
    rgb = np.where(al > 1e-4, out[..., :3] / np.maximum(al, 1e-4), 0.0)
    out[..., :3] = np.clip(rgb, 0.0, 1.0)
    return np.clip(out, 0.0, 1.0)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    rel, factor = argv[0], float(argv[1])
    apply = "--apply" in argv
    only = set(argv[argv.index("--only") + 1].split(",")) if "--only" in argv else set()
    fauna_id = argv[argv.index("--fauna") + 1] if "--fauna" in argv else ""
    d = os.path.join(SPR, rel)
    tres = [f for f in os.listdir(d) if f.endswith(".tres")]
    assert len(tres) == 1, tres
    tpath = os.path.join(d, tres[0])
    os.makedirs(os.path.join(ROOT, "art", "tools", "shrunk"), exist_ok=True)
    marker = os.path.join(ROOT, "art", "tools", "shrunk", rel.replace("/", "_") + ".txt")
    if os.path.exists(marker) and "--force" not in argv:
        print("deja traite", marker)
        return
    text = open(tpath, encoding="utf-8", newline="").read()
    crlf = "\r\n" in text
    text = text.replace("\r\n", "\n")
    ext, subs, anims = parse_tres(text)
    body_files, other_files = set(), set()
    for name, frames, direct in anims:
        is_body = (name in only) if only else bool(BODY_RE.match(name))
        for sid in frames:
            if sid in subs:
                (body_files if is_body else other_files).add(ext[subs[sid][0]])
        for eid in direct:
            if eid in ext:
                other_files.add(ext[eid])  # texture directe : pas de region à corriger -> jamais touchée
    shared = body_files & other_files
    todo = sorted(body_files - other_files)
    print("corps:", len(todo), "partagés (ignorés):", sorted(shared))
    plan = {}  # id ext -> (sx, sy) par fichier
    for path in todo:
        eid = [k for k, v in ext.items() if v == path][0]
        regs = [(sid, s) for sid, s in subs.items() if s[0] == eid and s[1]]
        cw, ch = regs[0][1][1][2], regs[0][1][1][3]
        if any((s[1][2], s[1][3]) != (cw, ch) for _, s in regs):
            print("  cellules non uniformes, ignoré", path)
            continue
        full = os.path.join(ROOT, "game", path)
        arr, W, H = load_np(full)
        if W % int(cw) or H % int(ch) or any(s[1][0] % cw or s[1][1] % ch for _, s in regs):
            print("  hors grille, ignoré", path, W, H, cw, ch)
            continue
        ncw, nch = max(1, round(cw * factor)), max(1, round(ch * factor))
        NW, NH = W // int(cw) * ncw, H // int(ch) * nch
        sx, sy = ncw / cw, nch / ch
        print(f"  {os.path.basename(path)}: {W}x{H} cell {int(cw)}x{int(ch)} -> {NW}x{NH} cell {ncw}x{nch}")
        plan[eid] = (sx, sy, ncw, nch)
        if not apply:
            continue
        save_np(full, resize(arr, W, H, NW, NH), NW, NH)
        epath = full[:-4] + "_e.png"
        if os.path.exists(epath):
            earr, EW, EH = load_np(epath)
            eW, eH = (NW + 1) // 2, (NH + 1) // 2
            save_np(epath, resize(earr, EW, EH, eW, eH), eW, eH)
    if not apply:
        return
    # .tres : region (x sx / y sy, taille = nouvelle cellule), margin x facteur
    def fix(m):
        sid = m.group(1)
        block = m.group(0)
        s = subs.get(sid)
        if s is None or s[0] not in plan or not s[1]:
            return block
        sx, sy, ncw, nch = plan[s[0]]
        x, y, w, h = s[1]
        reg = f"region = Rect2({x * sx:g}, {y * sy:g}, {ncw}, {nch})"
        block = re.sub(r"region = Rect2\([^)]*\)", reg, block)
        if s[2]:
            mx, my, mw, mh = s[2]
            block = re.sub(r"margin = Rect2\([^)]*\)", f"margin = Rect2({mx * factor:g}, {my * factor:g}, {mw * factor:g}, {mh * factor:g})", block)
        return block
    text = re.sub(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]\n(?:[^\[\n][^\n]*\n)+', fix, text)
    open(tpath, "w", encoding="utf-8", newline="").write(text.replace("\n", "\r\n") if crlf else text)
    if fauna_id:
        fp = os.path.join(ROOT, "game", "data", "fauna.json")
        ft = open(fp, encoding="utf-8", newline="").read()
        m = re.search(r'("%s": \{[^\n]*?)"dim": ([\d.]+), "bottom": ([\d.]+), "fh": ([\d.]+)' % re.escape(fauna_id), ft)
        assert m, "entrée fauna introuvable"
        dim, bottom, fh = (float(m.group(i)) * factor for i in (2, 3, 4))
        new = '%s"dim": %.6g, "bottom": %.6g, "fh": %.6g' % (m.group(1), dim, bottom, fh)
        ft = ft[:m.start()] + new + ft[m.end():]
        open(fp, "w", encoding="utf-8", newline="").write(ft)
        print("fauna:", fauna_id, dim, bottom, fh)
    open(marker, "w").write(str(factor))
    print("OK")


main()
