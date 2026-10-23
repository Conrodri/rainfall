"""Assemble renders into sprite sheets + Godot SpriteFrames .tres (diffuse + normal via CanvasTexture).
Usage: uv run --with pillow python art/tools/pack.py <category> <name> <size> <anim[:fps[:noloop]]>... [--dirs]
Renders: art/renders/<name>/<anim>/<dir>_<ff>.png ; optional passes in art/renders/<name>/<anim>_n/ (normal) and <anim>_e/ (emission mask), same names.
dir = e,se,s,sw,w,nw,n,ne or 'x' for non-directional.
Output : game/assets/sprites/<category>/<name>/<anim>.png, <anim>_n.png, <anim>_e.png and <name>.tres
Normal : resized with LANCZOS then renormalised; transparent px -> (128,128,255).
"""
import sys, os, glob
from PIL import Image
DIRS = ["e","se","s","sw","w","nw","n","ne"]
root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = [a for a in sys.argv[1:] if a != "--dirs"]
directional = "--dirs" in sys.argv
cat, name, size = args[0], args[1], int(args[2])
anims = []
for a in args[3:]:
    p = a.split(":"); anims.append((p[0], int(p[1]) if len(p) > 1 else 12, not (len(p) > 2 and p[2] == "noloop")))
out = os.path.join(root, "game/assets/sprites", cat, name); os.makedirs(out, exist_ok=True)
res = f"res://assets/sprites/{cat}/{name}"
ext, sub, body = [], [], []
sid = 0
def build_sheet(d, suffix, nf, dirs, fill):
    sheet = Image.new("RGBA", (nf*size, len(dirs)*size), fill)
    for r, dr in enumerate(dirs):
        for f in range(nf):
            im = Image.open(os.path.join(d, f"{dr}_{f:02d}.png")).convert("RGBA").resize((size,size), Image.LANCZOS)
            sheet.paste(im, (f*size, r*size))
    return sheet
for anim, fps, loop in anims:
    base = os.path.join(root, "art/renders", name)
    d = os.path.join(base, anim)
    dirs = DIRS if directional else ["x"]
    nf = len(glob.glob(os.path.join(d, f"{dirs[0]}_*.png")))
    sheet = build_sheet(d, "", nf, dirs, (0,0,0,0)); sheet.save(os.path.join(out, f"{anim}.png"))
    ext.append(f'[ext_resource type="Texture2D" path="{res}/{anim}.png" id="{len(ext)+1}"]'); tid = len(ext)
    ntid = None
    if os.path.isdir(d + "_n"):
        ns = build_sheet(d + "_n", "_n", nf, dirs, (128,128,255,0))
        # transparent -> flat normal, alpha kept equal to diffuse alpha
        a = sheet.split()[3]; px = ns.load(); ap = a.load()
        for y in range(ns.size[1]):
            for x in range(ns.size[0]):
                r,g,b,_ = px[x,y]
                px[x,y] = (r,g,b,255) if ap[x,y] > 0 else (128,128,255,0)
        ns.save(os.path.join(out, f"{anim}_n.png"))
        ext.append(f'[ext_resource type="Texture2D" path="{res}/{anim}_n.png" id="{len(ext)+1}"]'); ntid = len(ext)
    if os.path.isdir(d + "_e"):
        build_sheet(d + "_e", "_e", nf, dirs, (0,0,0,0)).save(os.path.join(out, f"{anim}_e.png"))
    cid = None
    if ntid:
        sid += 1; cid = f"c{sid}"
        sub.append(f'[sub_resource type="CanvasTexture" id="{cid}"]\ndiffuse_texture = ExtResource("{tid}")\nnormal_texture = ExtResource("{ntid}")\n')
    for r, dr in enumerate(dirs):
        ids = []
        for f in range(nf):
            sid += 1; ids.append(f'SubResource("a{sid}")')
            atlas = f'SubResource("{cid}")' if cid else f'ExtResource("{tid}")'
            sub.append(f'[sub_resource type="AtlasTexture" id="a{sid}"]\natlas = {atlas}\nregion = Rect2({f*size}, {r*size}, {size}, {size})\n')
        aname = f"{anim}_{dr}" if directional else anim
        fr = ", ".join('{"duration": 1.0, "texture": %s}' % i for i in ids)
        body.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %d.0\n}' % (fr, "true" if loop else "false", aname, fps))
tres = f'[gd_resource type="SpriteFrames" load_steps={len(ext)+len(sub)+1} format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n".join(sub) + "\n[resource]\nanimations = [" + ", ".join(body) + "]\n"
open(os.path.join(out, f"{name}.tres"), "w", newline="\n").write(tres)
print("ok", out)
