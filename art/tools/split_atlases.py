"""Découpe une planche de SpriteFrames trop grande (> 4096 px de côté) en plusieurs atlases.

Rognage / assemblage seulement (règle CLAUDE.md) : chaque cellule est copiée pixel pour pixel
depuis la planche d'origine vers un atlas <= 4096 px, pour le diffus ET ses passes _n / _e
(même découpage). Les .tres SpriteFrames qui pointent la planche (diffus direct, CanvasTexture
diffus+normale, ou SpriteFrames d'émission) sont réécrits : un ext_resource par atlas, une
CanvasTexture par atlas si besoin, et chaque AtlasTexture reçoit sa nouvelle région.
Les noms d'animations, les ids de sous-ressources et le bloc [resource] restent identiques.

Nommage : <base>.png -> <base>_0.png, <base>_1.png… ; <base>_n.png -> <base>_0_n.png… ;
<base>_e.png -> <base>_0_e.png… (convention NormalMaps conservée : <f>_n / <f>_e).
Les planches d'origine sont déplacées (pas supprimées) dans art/renders/_presplit/.

Usage : python art/tools/split_atlases.py <sheet.png> [<sheet.png> ...] [--max 4096] [--dry]
"""
from __future__ import annotations

import math
import os
import re
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")
BACKUP = os.path.join(ROOT, "art", "renders", "_presplit")

RE_EXT = re.compile(r'^\[ext_resource type="Texture2D"(?: uid="[^"]*")? path="([^"]+)" id="([^"]+)"\]\s*$')
RE_SUB = re.compile(r'^\[sub_resource type="(\w+)" id="([^"]+)"\]\s*$')
RE_RECT = re.compile(r'Rect2\(([-\d.]+), ([-\d.]+), ([-\d.]+), ([-\d.]+)\)')


def res_to_abs(p: str) -> str:
    return os.path.join(GAME, p.replace("res://", "").replace("/", os.sep))


def abs_to_res(p: str) -> str:
    return "res://" + os.path.relpath(p, GAME).replace(os.sep, "/")


def pass_paths(diffuse_abs: str) -> dict:
    b, ext = os.path.splitext(diffuse_abs)
    out = {"": diffuse_abs}
    for s in ("_n", "_e"):
        if os.path.exists(b + s + ext):
            out[s] = b + s + ext
    return out


def atlas_name(diffuse_abs: str, idx: int, suffix: str) -> str:
    b, ext = os.path.splitext(diffuse_abs)
    return f"{b}_{idx}{suffix}{ext}"


def parse_tres(path: str):
    """Renvoie (header, exts{id: res_path}, subs[ {type,id,props(list of lines)} ], resource_block)."""
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    header = None
    exts: dict[str, str] = {}
    subs: list[dict] = []
    resource: list[str] = []
    cur = None
    mode = ""
    for ln in lines:
        if ln.startswith("[gd_resource"):
            header = ln
            continue
        m = RE_EXT.match(ln)
        if m:
            exts[m.group(2)] = m.group(1)
            mode = ""
            continue
        if ln.startswith("[ext_resource"):
            raise ValueError(f"ext_resource non géré dans {path}: {ln}")
        m = RE_SUB.match(ln)
        if m:
            cur = {"type": m.group(1), "id": m.group(2), "props": []}
            subs.append(cur)
            mode = "sub"
            continue
        if ln.startswith("[resource]"):
            mode = "res"
            resource.append(ln)
            continue
        if mode == "sub" and ln.strip():
            cur["props"].append(ln)
        elif mode == "res":
            resource.append(ln)
    return header, exts, subs, resource


def prop(sub: dict, key: str):
    for ln in sub["props"]:
        if ln.startswith(key + " = "):
            return ln[len(key) + 3:]
    return None


def ref_id(val: str):
    m = re.match(r'(ExtResource|SubResource)\("([^"]+)"\)', val or "")
    return (m.group(1), m.group(2)) if m else (None, None)


def plan_layout(regions: list[tuple], limit: int):
    """regions uniques (x,y,w,h) dans l'ordre -> [(atlas_idx, nx, ny)], tailles des atlases."""
    sizes = {(r[2], r[3]) for r in regions}
    if len(sizes) != 1:
        raise ValueError(f"cellules non uniformes {sizes} : découpe manuelle requise")
    cw, ch = sizes.pop()
    maxc, maxr = limit // cw, limit // ch
    cap = maxc * maxr
    n = len(regions)
    k = math.ceil(n / cap)
    per = math.ceil(n / k)
    best = None
    for cols in range(1, maxc + 1):
        rows = math.ceil(per / cols)
        if rows > maxr:
            continue
        key = (cols * rows, abs(cols * cw - rows * ch))  # moins de cases vides, puis plus carré
        if best is None or key < best[0]:
            best = (key, cols, rows)
    _, cols, rows = best
    place = []
    for i in range(n):
        a, j = divmod(i, per)
        place.append((a, (j % cols) * cw, (j // cols) * ch))
    counts = [min(per, n - a * per) for a in range(k)]
    atlas_sizes = []
    for c in counts:
        used_rows = math.ceil(c / cols)
        atlas_sizes.append((min(cols, c) * cw, used_rows * ch))
    return place, atlas_sizes


def tres_files_referencing(sheet_res: str):
    out = []
    for dp, _dn, fn in os.walk(os.path.join(GAME, "assets")):
        for f in fn:
            if f.endswith(".tres"):
                p = os.path.join(dp, f)
                with open(p, encoding="utf-8") as fh:
                    if sheet_res in fh.read():
                        out.append(p)
    return out


def split_sheet(diffuse_abs: str, limit: int, dry: bool) -> list[str]:
    diffuse_res = abs_to_res(diffuse_abs)
    passes = pass_paths(diffuse_abs)
    res_of_pass = {s: abs_to_res(p) for s, p in passes.items()}
    tres_list = []
    for s in passes:
        tres_list += tres_files_referencing(res_of_pass[s])
    tres_list = sorted(set(tres_list))
    if not tres_list:
        raise ValueError(f"aucun .tres ne référence {diffuse_res}")
    # Régions utilisées (union de tous les .tres), dans l'ordre d'apparition.
    regions: list[tuple] = []
    for t in tres_list:
        _h, _e, subs, _r = parse_tres(t)
        for s in subs:
            if s["type"] == "AtlasTexture":
                m = RE_RECT.search(prop(s, "region") or "")
                if m:
                    r = tuple(int(float(v)) for v in m.groups())
                    if r not in regions:
                        regions.append(r)
    place, atlas_sizes = plan_layout(regions, limit)
    new_of = {r: place[i] for i, r in enumerate(regions)}
    log = [f"{diffuse_res}: {len(regions)} cellules -> {len(atlas_sizes)} atlas {atlas_sizes} ; .tres {[(abs_to_res(t)) for t in tres_list]}"]
    if dry:
        return log
    # 1) Atlases (diffus + passes), copie pixel pour pixel.
    for s, src in passes.items():
        im = Image.open(src)
        im.load()
        for a, (w, h) in enumerate(atlas_sizes):
            out = Image.new(im.mode, (w, h), (0, 0, 0, 0) if im.mode == "RGBA" else 0)
            for r, (ai, nx, ny) in new_of.items():
                if ai == a:
                    out.paste(im.crop((r[0], r[1], r[0] + r[2], r[1] + r[3])), (nx, ny))
            out.save(atlas_name(diffuse_abs, a, s), optimize=True)
    # 2) .tres réécrits.
    for t in tres_list:
        rewrite_tres(t, res_of_pass, diffuse_abs, new_of, len(atlas_sizes))
    # 3) Planches d'origine mises de côté (hors du projet Godot).
    for s, src in passes.items():
        dst = os.path.join(BACKUP, os.path.relpath(src, GAME))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        if os.path.exists(src + ".import"):
            shutil.move(src + ".import", dst + ".import")
    return log


def rewrite_tres(path: str, res_of_pass: dict, diffuse_abs: str, new_of: dict, n_atlas: int):
    header, exts, subs, resource = parse_tres(path)
    pass_of_ext = {}
    for eid, rp in exts.items():
        for s, prp in res_of_pass.items():
            if rp == prp:
                pass_of_ext[eid] = s
    new_exts: list[tuple[str, str]] = []  # (id, path)
    ext_for = {}  # (pass, atlas) -> new ext id
    for eid, rp in exts.items():
        if eid in pass_of_ext:
            s = pass_of_ext[eid]
            for a in range(n_atlas):
                nid = f"{eid}_{a}"
                ext_for[(s, a)] = nid
                new_exts.append((nid, abs_to_res(atlas_name(diffuse_abs, a, s))))
        else:
            new_exts.append((eid, rp))
    canvas = {s["id"]: s for s in subs if s["type"] == "CanvasTexture"}
    canvas_split = {}  # canvas id -> True si elle pointe une planche découpée
    for cid, c in canvas.items():
        _k, d = ref_id(prop(c, "diffuse_texture"))
        canvas_split[cid] = d in pass_of_ext
    out_subs: list[str] = []
    for s in subs:
        if s["type"] == "CanvasTexture" and canvas_split.get(s["id"]):
            for a in range(n_atlas):
                body = []
                for ln in s["props"]:
                    m = re.match(r'(\w+) = ExtResource\("([^"]+)"\)', ln)
                    if m and m.group(2) in pass_of_ext:
                        body.append(f'{m.group(1)} = ExtResource("{ext_for[(pass_of_ext[m.group(2)], a)]}")')
                    else:
                        body.append(ln)
                out_subs.append(f'[sub_resource type="CanvasTexture" id="{s["id"]}_{a}"]\n' + "\n".join(body))
            continue
        if s["type"] == "AtlasTexture":
            kind, rid = ref_id(prop(s, "atlas"))
            m = RE_RECT.search(prop(s, "region") or "")
            r = tuple(int(float(v)) for v in m.groups()) if m else None
            target = None
            if kind == "ExtResource" and rid in pass_of_ext:
                target = ("ext", pass_of_ext[rid])
            elif kind == "SubResource" and canvas_split.get(rid):
                target = ("canvas", rid)
            if target and r in new_of:
                a, nx, ny = new_of[r]
                atlas_ref = (f'ExtResource("{ext_for[(target[1], a)]}")' if target[0] == "ext"
                             else f'SubResource("{target[1]}_{a}")')
                body = []
                for ln in s["props"]:
                    if ln.startswith("atlas = "):
                        body.append(f"atlas = {atlas_ref}")
                    elif ln.startswith("region = "):
                        body.append(f"region = Rect2({nx}, {ny}, {r[2]}, {r[3]})")
                    else:
                        body.append(ln)
                out_subs.append(f'[sub_resource type="AtlasTexture" id="{s["id"]}"]\n' + "\n".join(body))
                continue
        out_subs.append(f'[sub_resource type="{s["type"]}" id="{s["id"]}"]\n' + "\n".join(s["props"]))
    header = re.sub(r' load_steps=\d+', '', header)
    text = header + "\n\n"
    text += "\n".join(f'[ext_resource type="Texture2D" path="{p}" id="{i}"]' for i, p in new_exts) + "\n\n"
    text += "\n\n".join(out_subs) + "\n\n" + "\n".join(resource).rstrip("\n") + "\n"
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def main(argv):
    limit = 4096
    dry = "--dry" in argv
    args = [a for a in argv if not a.startswith("--")]
    if "--max" in argv:
        limit = int(argv[argv.index("--max") + 1])
        args = [a for a in args if a != str(limit)]
    for a in args:
        p = a if os.path.isabs(a) else os.path.join(ROOT, a)
        for ln in split_sheet(os.path.normpath(p), limit, dry):
            print(ln)


if __name__ == "__main__":
    main(sys.argv[1:])
