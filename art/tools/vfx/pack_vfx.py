"""Assemble les rendus 2x en planches horizontales + masques _e + SpriteFrames .tres (PIL : assemblage seulement).
Usage : python pack_vfx.py <effet> [effet...]   |   python pack_vfx.py --contact <effet> [anim]"""
import sys
from pathlib import Path
from PIL import Image
sys.path.insert(0, str(Path(__file__).resolve().parent))
from unittest.mock import MagicMock
sys.modules.setdefault("bpy", MagicMock()); sys.modules.setdefault("mathutils", MagicMock())
ROOT = Path(__file__).resolve().parents[3]
SCRATCH = Path(r'C:\Users\const\AppData\Local\Temp\claude\C--Users-const-Documents\db154a60-3b84-46fb-808a-25c4759c2fe6\scratchpad')

def pack(name):
    import fx_all as fx_defs
    E = fx_defs.EFFECTS[name]; w, h = E['size']
    if name.startswith('particles'):
        out = ROOT / 'game/assets/sprites/vfx/particles'; out.mkdir(parents=True, exist_ok=True)
        for anim, A in E['anims'].items():
            for i in range(A['n']):
                for suffix in ('', '_e'):
                    with Image.open(ROOT / 'art/renders/vfx' / name / (anim + suffix) / ('x_%02d.png' % i)) as im:
                        im.convert('RGBA').resize((w, h), Image.Resampling.LANCZOS).save(out / ('%s_%02d%s.png' % (anim, i + 1, suffix)))
        print('OK particules', name); return
    out = ROOT / 'game/assets/sprites/vfx' / name; out.mkdir(parents=True, exist_ok=True)
    ext = []; subs = []; anims = []
    for anim, A in E['anims'].items():
        n = A['n']; tid = str(len(ext) + 1)
        for suffix in ('', '_e'):
            src = ROOT / 'art/renders/vfx' / name / (anim + suffix)
            sheet = Image.new('RGBA', (w * n, h))
            for i in range(n):
                with Image.open(src / ('x_%02d.png' % i)) as im:
                    assert im.size == (w * 2, h * 2), (im.size, w, h)
                    sheet.paste(im.convert('RGBA').resize((w, h), Image.Resampling.LANCZOS), (i * w, 0))
            fn = (name if anim == 'default' and False else anim) + suffix + '.png'
            sheet.save(out / fn)
        ext.append('[ext_resource type="Texture2D" path="res://assets/sprites/vfx/%s/%s.png" id="%s"]' % (name, anim, tid))
        fr = []
        for i in range(n):
            sid = 'a%d' % (len(subs) + 1)
            subs.append('[sub_resource type="AtlasTexture" id="%s"]\natlas = ExtResource("%s")\nregion = Rect2(%d, 0, %d, %d)\n' % (sid, tid, i * w, w, h))
            fr.append('{"duration": 1.0, "texture": SubResource("%s")}' % sid)
        anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (', '.join(fr), str(A['loop']).lower(), anim, float(A['fps'])))
    (out / (name + '.tres')).write_text('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n%s\n[resource]\nanimations = [%s]\n' % (len(ext) + len(subs) + 1, '\n'.join(ext), '\n'.join(subs), ', '.join(anims)), encoding='utf8')
    print('OK', name, w, h)

def contact(name, only=None, scale=2, bg=(30, 36, 46), emis=False):
    import fx_all as fx_defs
    E = fx_defs.EFFECTS[name]; w, h = E['size']; rows = []
    for anim, A in E['anims'].items():
        if only and anim != only: continue
        src = ROOT / 'art/renders/vfx' / name / (anim + ('_e' if emis else ''))
        n = A['n']; cols = min(n, 8 if w <= 256 else 5); r = -(-n // cols)
        cw, ch = int(w * scale / 2 * 1.0) if w * scale > 1100 // cols else w * scale, 0
        z = min(scale, 1400 / (cols * w)); cw = int(w * z); ch = int(h * z)
        sh = Image.new('RGB', (cols * cw, r * ch), bg)
        for i in range(n):
            im = Image.open(src / ('x_%02d.png' % i)).convert('RGBA').resize((cw, ch), Image.Resampling.LANCZOS)
            sh.paste(im, ((i % cols) * cw, (i // cols) * ch), im)
        rows.append(sh)
    H = sum(r.height for r in rows); W = max(r.width for r in rows)
    big = Image.new('RGB', (W, H), bg); y = 0
    for r in rows: big.paste(r, (0, y)); y += r.height
    SCRATCH.mkdir(parents=True, exist_ok=True)
    p = SCRATCH / ('c_%s%s%s.png' % (name, '_' + only if only else '', '_e' if emis else '')); big.save(p); print(p)

if __name__ == '__main__':
    a = sys.argv[1:]
    if a and a[0] == '--contact': contact(a[1], a[2] if len(a) > 2 and a[2] != '-' else None, emis=len(a) > 3)
    else:
        for nm in a: pack(nm)
