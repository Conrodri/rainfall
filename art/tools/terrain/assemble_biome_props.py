"""PIL : reduction LANCZOS 2x -> final + planche de controle. Aucun pixel dessine."""
from pathlib import Path
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / 'art/renders/terrain/props_biomes'
OUT = ROOT / 'game/assets/sprites/props'
rows = []
for bdir in sorted(RAW.iterdir()):
    if not bdir.is_dir(): continue
    for folder in sorted(bdir.iterdir()):
        if not folder.is_dir(): continue
        dest = OUT / bdir.name; dest.mkdir(parents=True, exist_ok=True)
        for suf in ('', '_n', '_e'):
            f = folder / ('00' + suf + '.png')
            if not f.exists(): continue
            with Image.open(f) as im:
                im = im.convert('RGBA'); t = im.resize((im.width // 2, im.height // 2), Image.Resampling.LANCZOS)
            t.save(dest / (folder.name + suf + '.png'))
            bb = t.getchannel('A').getbbox()
            if not suf: assert bb and bb[0] >= 2 and bb[1] >= 2 and bb[2] <= t.width - 2 and bb[3] <= t.height - 2, (folder.name, bb, t.size)
            rows.append((bdir.name, folder.name + suf, t.size, bb))
for r in rows: print(*r)
for suf in ('', '_n', '_e'):
    imgs = []
    for b, n, sz, bb in rows:
        if n.endswith(('_n', '_e')) != bool(suf) or (suf and not n.endswith(suf)): continue
        with Image.open(OUT / b / (n + '.png')) as im:
            im = im.copy(); im.thumbnail((200, 200)); imgs.append(im)
    if not imgs: continue
    sheet = Image.new('RGBA', (200 * 6, 200 * ((len(imgs) + 5) // 6)), (60, 70, 70, 255))
    for i, im in enumerate(imgs): sheet.alpha_composite(im, ((i % 6) * 200, (i // 6) * 200))
    sheet.save(RAW / ('contact' + suf + '.png'))
