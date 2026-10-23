from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[3]
out = root/'game/assets/sprites/ui/crit_icon.png'
with Image.open(root/'art/renders/ui/crit_icon_raw.png') as im:
    im.convert('RGBA').resize((128,128), Image.Resampling.LANCZOS).save(out)
for p in [*sorted((root/'game/assets/sprites/props/gold_capsule').glob('*.png')), out]:
    with Image.open(p) as im:
        assert im.size == (128,128) and im.mode == 'RGBA', p
        alpha=im.getchannel('A'); bbox=alpha.getbbox()
        assert alpha.getextrema()==(0,255), p
        assert bbox and min(bbox[0],bbox[1],128-bbox[2],128-bbox[3])>=4, (p,bbox)
        print(p.name, im.size, im.mode, 'bbox',bbox)
with Image.open(root/'game/assets/sprites/props/gold_capsule/open_e.png') as im:
    assert max(hi for lo,hi in im.convert('RGB').getextrema()) <= 1
t=(root/'game/assets/sprites/props/gold_capsule/gold_capsule.tres').read_text()
assert t.count('"loop": false')==2 and t.count('"duration": 1.0')==2
assert '&"closed"' in t and '&"open"' in t
print('PASS: 7 PNG, open emission black, SpriteFrames contract unchanged')

