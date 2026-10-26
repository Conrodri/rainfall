"""Crop/resize probe only; no pixel painting or production writes."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
import cel_icons_build as build

data = json.loads(build.BASELINE.read_text())
report = json.loads((build.HERE/'_cel_icons_verification.json').read_text())
failed = [r for r in data['files'] if r not in {x['file'] for x in report['checks']}]
results = {}
for rel in failed:
    raw = Image.open(build.WORK/rel).convert('RGBA')
    ref = np.asarray(Image.open(build.cel.ARCHIVE/rel).convert('RGBA'))[:, :, 3] > 128
    x, y, r, b = data['files'][rel]['bbox']
    size = (r-x, b-y)
    best = (0, None)
    for threshold in [0, 1, 2, 4, 8, 16, 32, 64, 96, 128]:
        bb = raw.getchannel('A').point(lambda v: 255 if v > threshold else 0).getbbox()
        for dx in range(-8, 9):
            for dy in range(-8, 9):
                box = (bb[0]+dx, bb[1]+dy, bb[2]-dx, bb[3]-dy)
                im = raw.crop(box).resize(size, Image.Resampling.LANCZOS)
                canvas = Image.new('RGBA', data['files'][rel]['size'])
                canvas.paste(im, (x,y))
                mask = np.asarray(canvas)[:, :, 3] > 128
                iou = float((mask & ref).sum()/max(1,(mask | ref).sum()))
                if iou > best[0]:
                    best = (iou, box)
    results[rel] = {'iou': best[0], 'crop': best[1]}
    print(rel, round(best[0],6), best[1], flush=True)
(build.HERE/'_cel_icons_fit.json').write_text(json.dumps(results, indent=2))
