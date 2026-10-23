"""Budget textures de Rainfall : mesure par catégorie, planches trop grandes, estimation d'APK.

Usage : python art/tools/texture_budget.py [--strict] [--json <out.json>] [--top N]
        python art/tools/texture_budget.py --apply-policy   (réécrit les .import hors politique)
  --strict : code de sortie 1 si une règle du budget est violée (côté > max, budget de catégorie).

Lit les budgets dans game/tests/texture_budget.json (partagés avec game/tests/texture_budget_test).
Pour chaque PNG de game/ (hors .godot) :
  raw     = largeur × hauteur × 4 (RGBA8 en mémoire si la texture n'est pas compressée VRAM) ;
  vram    = mémoire GPU estimée (RGBA8, ou 1 octet/px si compression VRAM ETC2/ASTC/BPTC/S3TC) ;
  disk    = fichiers importés (.godot/imported, d'après dest_files du .import) ;
  mobile  = part de « disk » qui part dans un export Android/iOS (lossless/lossy : le même .ctex ;
            VRAM : seulement les .etc2/.astc), compressée deflate comme dans l'APK.
APK estimé = textures mobiles + audio importé + autres fichiers du projet + modèle Godot arm64.
Normal maps interdites (décision du joueur, 22/10/2026 : rendu cel, éclairage 2D plat) : tout
<f>_n.png posé à côté d'un diffus <f>.png est une violation (le déplacer vers art/archive_normals/).
Masques d'émission : <f>_e.png a la taille du diffus (rapport 1) ou sa demi-résolution
((w+1)//2 × (h+1)//2, rapport 1/2 : art/tools/halve_emission.py) ; toute autre taille est une violation.
Sans --apply-policy, rien n'est modifié (mesure seulement).
"""
from __future__ import annotations

import json
import os
import re
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GAME = os.path.join(ROOT, "game")
BUDGET = os.path.join(GAME, "tests", "texture_budget.json")
MB = 1024 * 1024
ENGINE_ARM64_MB = 32.0  # libgodot_android.so arm64 (release) compressé dans l'APK + classes/res

_deflate_cache: dict[str, int] = {}


def png_size(path: str):
    with open(path, "rb") as f:
        h = f.read(24)
    if h[:8] != b"\x89PNG\r\n\x1a\n":
        return 0, 0
    return struct.unpack(">II", h[16:24])


def read_import(path: str) -> dict:
    out = {"dest": [], "params": {}}
    try:
        with open(path, encoding="utf-8") as f:
            txt = f.read()
    except OSError:
        return out
    m = re.search(r"dest_files=\[(.*?)\]", txt)
    if m:
        out["dest"] = re.findall(r'"([^"]+)"', m.group(1))
    for k, v in re.findall(r"^([\w/]+)=(.*)$", txt, re.M):
        out["params"][k] = v
    return out


def deflated(path: str) -> int:
    if path not in _deflate_cache:
        with open(path, "rb") as f:
            _deflate_cache[path] = len(zlib.compress(f.read(), 6))
    return _deflate_cache[path]


def category(rel: str) -> str:
    parts = rel.replace("\\", "/").split("/")
    if parts[0] != "assets":
        return parts[0]
    if len(parts) > 3 and parts[1] == "sprites" and parts[2] == "characters":
        return "characters/" + parts[3]
    if len(parts) > 2 and parts[1] == "sprites":
        return parts[2]
    return parts[1] if len(parts) > 2 else "assets"


def scan(compute_mobile: bool = True):
    rows = []
    for dp, dn, fn in os.walk(GAME):
        dn[:] = [d for d in dn if d not in (".godot", ".git")]
        for f in fn:
            if not f.lower().endswith(".png"):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, GAME).replace(os.sep, "/")
            w, h = png_size(p)
            imp = read_import(p + ".import")
            mode = int(imp["params"].get("compress/mode", "0") or 0)
            disk = mobile = 0
            for d in imp["dest"]:
                ap = os.path.join(GAME, d.replace("res://", "").replace("/", os.sep))
                if not os.path.exists(ap):
                    continue
                sz = os.path.getsize(ap)
                disk += sz
                is_desktop = ".s3tc." in d or ".bptc." in d
                if not is_desktop and compute_mobile:
                    # Un export mobile n'embarque qu'un format VRAM : ASTC si présent, sinon ETC2.
                    if ".etc2." in d and any(".astc." in x for x in imp["dest"]):
                        continue
                    mobile += deflated(ap) if mode == 2 else sz
            vram = w * h * (1 if mode == 2 else 4)
            rows.append({
                "path": rel, "cat": category(rel), "w": w, "h": h, "raw": w * h * 4, "vram": vram,
                "png": os.path.getsize(p), "disk": disk, "mobile": mobile, "mode": mode,
                "mipmaps": imp["params"].get("mipmaps/generate", "false") == "true",
                "size_limit": int(imp["params"].get("process/size_limit", "0") or 0),
            })
    return rows


def other_files_mb() -> tuple[float, float]:
    """(audio importé, autres fichiers exportés hors PNG/imports) en Mo."""
    audio = other = 0
    imp_dir = os.path.join(GAME, ".godot", "imported")
    if os.path.isdir(imp_dir):
        for f in os.listdir(imp_dir):
            if f.endswith((".oggvorbisstr", ".sample", ".mp3str")):
                audio += os.path.getsize(os.path.join(imp_dir, f))
    for dp, dn, fn in os.walk(GAME):
        dn[:] = [d for d in dn if d not in (".godot", ".git", "tests")]
        for f in fn:
            if f.lower().endswith((".png", ".import", ".ogg", ".wav", ".mp3", ".uid", ".md")):
                continue
            other += os.path.getsize(os.path.join(dp, f))
    return audio / MB, other / MB


def load_budget() -> dict:
    with open(BUDGET, encoding="utf-8") as f:
        return json.load(f)


def expected_params(rel: str, budget: dict) -> dict:
    """Paramètres d'import imposés par la politique du budget pour un PNG (chemin relatif à game/)."""
    pol = budget.get("import_policy", {})
    lossless = any(rel.startswith(d) for d in pol.get("lossless_dirs", []))
    params = dict(pol.get("lossless" if lossless else "default", {}))
    params.setdefault("process/size_limit", 0)
    params.update(pol.get("overrides", {}).get(rel, {}))
    return params


def _fmt(v) -> str:
    return ("true" if v else "false") if isinstance(v, bool) else str(v)


def apply_policy(budget: dict) -> int:
    """Réécrit dans les .import les paramètres qui diffèrent de la politique, sans toucher au reste
    (uid, remap, dest_files : l'ancien import reste valable jusqu'au réimport, les tests des autres
    agents ne cassent pas), et supprime le .md5 de l'import pour forcer `godot --headless --path game --import`."""
    changed = 0
    for dp, dn, fn in os.walk(os.path.join(GAME, "assets")):
        for f in fn:
            if not f.lower().endswith(".png"):
                continue
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, GAME).replace(os.sep, "/")
            want = {k: _fmt(v) for k, v in expected_params(rel, budget).items()}
            ip = p + ".import"
            if not os.path.exists(ip):
                # Jamais importé (nouvelle planche) : .import minimal, Godot complète uid et destination.
                with open(ip, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\n'
                             + "".join(f"{k}={v}\n" for k, v in want.items()))
                changed += 1
                continue
            txt = open(ip, encoding="utf-8").read()
            cur = dict(re.findall(r"^([\w/]+)=(.*)$", txt, re.M))
            if all(cur.get(k) == v for k, v in want.items()):
                continue
            for k, v in want.items():
                if k in cur:
                    txt = re.sub(r"^" + re.escape(k) + r"=.*$", f"{k}={v}", txt, count=1, flags=re.M)
                else:
                    txt = txt.rstrip("\n") + f"\n{k}={v}\n"
            with open(ip, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(txt)
            for d in read_import(ip)["dest"]:
                base = re.sub(r"(\.(s3tc|bptc|etc2|astc))?\.ctex$", "", d.replace("res://", ""))
                md5 = os.path.join(GAME, base.replace("/", os.sep) + ".md5")
                if os.path.exists(md5):
                    os.remove(md5)
            changed += 1
    print(f"{changed} fichier(s) .import mis à la politique ; lancer : godot --headless --path game --import")
    return 0


def main(argv):
    if "--apply-policy" in argv:
        return apply_policy(load_budget())
    strict = "--strict" in argv
    top = int(argv[argv.index("--top") + 1]) if "--top" in argv else 15
    budget = load_budget()
    max_side = int(budget["max_side_px"])
    allow = budget.get("oversize_allowlist", {})
    rows = scan()
    cats: dict[str, dict] = {}
    for r in rows:
        c = cats.setdefault(r["cat"], {"n": 0, "raw": 0, "vram": 0, "png": 0, "disk": 0, "mobile": 0})
        c["n"] += 1
        for k in ("raw", "vram", "png", "disk", "mobile"):
            c[k] += r[k]
    tot = {k: sum(c[k] for c in cats.values()) for k in ("n", "raw", "vram", "png", "disk", "mobile")}
    print(f"{'catégorie':28} {'n':>5} {'raw Mo':>9} {'VRAM Mo':>9} {'png Mo':>8} {'import Mo':>9} {'mobile Mo':>9} {'budget':>7}")
    violations = []
    cat_budget = budget.get("category_mobile_mb", {})
    for name, c in sorted(cats.items(), key=lambda kv: -kv[1]["mobile"]):
        b = cat_budget.get(name, cat_budget.get(name.split("/")[0] + "/*", None))
        flag = ""
        if b is not None and c["mobile"] / MB > b:
            flag = " !"
            violations.append(f"catégorie {name} : {c['mobile'] / MB:.1f} Mo mobile > budget {b} Mo")
        print(f"{name:28} {c['n']:5} {c['raw'] / MB:9.1f} {c['vram'] / MB:9.1f} {c['png'] / MB:8.1f} "
              f"{c['disk'] / MB:9.1f} {c['mobile'] / MB:9.1f} {'' if b is None else b:>7}{flag}")
    print(f"{'TOTAL':28} {tot['n']:5} {tot['raw'] / MB:9.1f} {tot['vram'] / MB:9.1f} {tot['png'] / MB:8.1f} "
          f"{tot['disk'] / MB:9.1f} {tot['mobile'] / MB:9.1f}")
    print()
    big = [r for r in rows if max(r["w"], r["h"]) > max_side]
    print(f"Textures > {max_side} px de côté : {len(big)}")
    for r in sorted(big, key=lambda r: -r["raw"]):
        lot = allow.get(r["path"])
        tag = f"  (autorisé jusqu'au re-rendu Codex {lot})" if lot else ""
        print(f"  > {max_side} : {r['w']}x{r['h']}  {r['path']}{tag}")
        if not lot:
            violations.append(f"> {max_side} px : {r['path']} ({r['w']}x{r['h']})")
    off_policy = []
    for r in rows:
        if not r["path"].startswith("assets/"):
            continue
        cur = dict(re.findall(r"^([\w/]+)=(.*)$", open(os.path.join(GAME, r["path"] + ".import"), encoding="utf-8").read(), re.M))             if os.path.exists(os.path.join(GAME, r["path"] + ".import")) else {}
        if any(cur.get(k) != _fmt(v) for k, v in expected_params(r["path"], budget).items()):
            off_policy.append(r["path"])
    if off_policy:
        violations.append(f"{len(off_policy)} .import hors import_policy (corriger : texture_budget.py --apply-policy) : {off_policy[:4]}")
    paths = {r["path"] for r in rows}
    normals = [p for p in sorted(paths) if p.endswith("_n.png") and p[:-6] + ".png" in paths]
    print(f"Normal maps _n (interdites depuis le 22/10/2026) : {len(normals)}")
    if normals:
        violations.append(f"{len(normals)} normal map(s) _n (déplacer vers art/archive_normals/) : {normals[:4]}")
    sizes = {r["path"]: (r["w"], r["h"]) for r in rows}
    bad_e = []
    n_half = 0
    for p in sorted(paths):
        d = p[:-6] + ".png"
        if not p.endswith("_e.png") or d not in sizes:
            continue
        (ew, eh), (dw, dh) = sizes[p], sizes[d]
        if (ew, eh) == ((dw + 1) // 2, (dh + 1) // 2) and (ew, eh) != (dw, dh):
            n_half += 1
        elif (ew, eh) != (dw, dh):
            bad_e.append(f"{p} {ew}x{eh} (diffus {dw}x{dh})")
    print(f"Masques _e : {n_half} à demi-résolution, {len(bad_e)} de taille incohérente")
    if bad_e:
        violations.append(f"{len(bad_e)} _e ni pleine taille ni demi-résolution du diffus : {bad_e[:4]}")
    mips = [r["path"] for r in rows if r["mipmaps"]]
    if mips:
        violations.append(f"{len(mips)} texture(s) 2D avec mipmaps : {mips[:5]}")
    print()
    print(f"Plus grosses textures (VRAM) :")
    for r in sorted(rows, key=lambda r: -r["vram"])[:top]:
        print(f"  {r['vram'] / MB:7.1f} Mo VRAM  {r['mobile'] / MB:6.1f} Mo APK  {r['w']}x{r['h']}  mode={r['mode']}  {r['path']}")
    audio, other = other_files_mb()
    apk = tot["mobile"] / MB + audio + other + ENGINE_ARM64_MB
    print()
    print(f"APK estimé (arm64) : {apk:.0f} Mo = textures {tot['mobile'] / MB:.0f} + audio {audio:.0f} "
          f"+ autres {other:.0f} + moteur {ENGINE_ARM64_MB:.0f}  (budget {budget['apk_mb']} Mo, "
          f"textures {budget['apk_textures_mb']} Mo, cible {budget.get('apk_textures_target_mb', '?')} Mo)")
    if apk > budget["apk_mb"]:
        violations.append(f"APK estimé {apk:.0f} Mo > {budget['apk_mb']} Mo")
    if tot["mobile"] / MB > budget["apk_textures_mb"]:
        violations.append(f"textures mobiles {tot['mobile'] / MB:.0f} Mo > {budget['apk_textures_mb']} Mo")
    if "--json" in argv:
        with open(argv[argv.index("--json") + 1], "w", encoding="utf-8") as f:
            json.dump({"categories": cats, "total": tot, "apk_mb": apk, "violations": violations,
                       "rows": rows}, f, indent=1)
    print()
    if violations:
        print(f"HORS BUDGET ({len(violations)}) :")
        for v in violations:
            print("  - " + v)
    else:
        print("Budget respecté.")
    return 1 if (strict and violations) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
