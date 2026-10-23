"""Retire les normal maps _n : réécrit les .tres/.tscn (références _n retirées, CanvasTexture
diffus seul aplati en ExtResource direct) puis déplace X_n.png (+ .import) vers art/archive_normals/.
Usage : python art/tools/archive_normals.py [--apply]   (sans --apply : mesure seulement)
Décision du joueur 22/10/2026 : plus de normal maps (budget mobile). À relancer si un lot en livre encore."""
import os, re, sys, shutil
ROOT = r"C:\Users\const\Documents\Rainfall"
GAME = os.path.join(ROOT, "game")
ASSETS = os.path.join(GAME, "assets")
ARCH = os.path.join(ROOT, "art", "archive_normals")
apply = "--apply" in sys.argv

normals = []
for dp, dn, fn in os.walk(ASSETS):
    for f in fn:
        if f.endswith("_n.png") and os.path.exists(os.path.join(dp, f[:-6] + ".png")):
            normals.append(os.path.join(dp, f))
nres = {"res://" + os.path.relpath(p, GAME).replace(os.sep, "/") for p in normals}

EXT = re.compile(r'^\[ext_resource [^\]]*path="([^"]+)"[^\]]*id="([^"]+)"[^\]]*\]\s*$')
EXT2 = re.compile(r'^\[ext_resource [^\]]*id="([^"]+)"[^\]]*path="([^"]+)"[^\]]*\]\s*$')

def rewrite(txt):
    lines = txt.split("\n")
    drop_ids = set()
    out = []
    for ln in lines:
        m = EXT.match(ln)
        if m and m.group(1) in nres:
            drop_ids.add(m.group(2)); continue
        m = EXT2.match(ln)
        if m and m.group(2) in nres:
            drop_ids.add(m.group(1)); continue
        out.append(ln)
    if drop_ids:
        out = [ln for ln in out if not any(re.match(r'^\w+ = ExtResource\("%s"\)\s*$' % re.escape(i), ln) for i in drop_ids)]
        for i in drop_ids:
            if 'ExtResource("%s")' % i in "\n".join(out):
                raise RuntimeError("référence restante à " + i)
    # Aplatit les CanvasTexture qui n'ont plus que diffuse_texture.
    txt2 = "\n".join(out)
    blocks = re.split(r'(?m)^(?=\[)', txt2)
    collapse = {}
    keep = []
    for b in blocks:
        m = re.match(r'\[sub_resource type="CanvasTexture" id="([^"]+)"\]\n', b)
        if m:
            body = [l for l in b[m.end():].split("\n") if l.strip()]
            if len(body) == 1 and re.match(r'^diffuse_texture = ExtResource\("[^"]+"\)$', body[0]):
                collapse[m.group(1)] = body[0].split(" = ", 1)[1]
                continue
        keep.append(b)
    txt3 = "".join(keep)
    for cid, ext in collapse.items():
        txt3 = txt3.replace('SubResource("%s")' % cid, ext)
    txt3 = re.sub(r"\n{3,}", "\n\n", txt3)
    return txt3, len(drop_ids), len(collapse)

changed = []
for dp, dn, fn in os.walk(GAME):
    dn[:] = [d for d in dn if d not in (".godot", ".git")]
    for f in fn:
        if not f.endswith((".tres", ".tscn")):
            continue
        p = os.path.join(dp, f)
        with open(p, encoding="utf-8", newline="") as fh:
            t = fh.read()
        if "_n.png" not in t and 'type="CanvasTexture"' not in t:
            continue
        crlf = "\r\n" in t
        t0 = t.replace("\r\n", "\n")
        new, nd, nc = rewrite(t0)
        if new != t0:
            changed.append((os.path.relpath(p, GAME), nd, nc))
            if apply:
                if crlf: new = new.replace("\n", "\r\n")
                with open(p, "w", encoding="utf-8", newline="") as fh:
                    fh.write(new)
print("normal maps:", len(normals), "%.1f Mo png" % (sum(os.path.getsize(p) for p in normals) / 1048576))
print("ressources réécrites:", len(changed), "refs _n retirées:", sum(c[1] for c in changed), "CanvasTexture aplaties:", sum(c[2] for c in changed))
for c in changed[:5]: print("  ", c)
# Références restantes à des _n (hors .import) dans le projet.
left = []
for dp, dn, fn in os.walk(GAME):
    dn[:] = [d for d in dn if d not in (".godot", ".git")]
    for f in fn:
        if f.endswith((".tres", ".tscn", ".gd", ".json", ".cfg")):
            t = open(os.path.join(dp, f), encoding="utf-8", errors="ignore").read()
            for r in nres:
                if r in t or r.replace("res://", "") in t:
                    left.append((f, r)); break
print("références restantes:", len(left), left[:5])
if apply:
    moved = 0; size = 0
    for p in normals:
        rel = os.path.relpath(p, ASSETS)
        dst = os.path.join(ARCH, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.exists(dst):
            base, ext = os.path.splitext(dst); k = 2
            while os.path.exists(f"{base}.dup{k}{ext}"): k += 1
            dst = f"{base}.dup{k}{ext}"
        size += os.path.getsize(p)
        shutil.move(p, dst)
        if os.path.exists(p + ".import"):
            shutil.move(p + ".import", dst + ".import")
        moved += 1
    print("déplacés:", moved, "%.1f Mo" % (size / 1048576))
