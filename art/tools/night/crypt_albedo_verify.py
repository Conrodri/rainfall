import sys,json
from pathlib import Path
import numpy as np
from PIL import Image
from crypt_albedo import ROOT,NAMES,ASSETS,WORK,sha
rows=[];report={};count=0
for name in NAMES:
    folder=ASSETS/name;backup=WORK/'before'/name
    assert sorted(p.name for p in folder.iterdir())==sorted(p.name for p in backup.iterdir())
    for p in folder.iterdir():
        old=backup/p.name
        if p.suffix!='.png' or p.stem.endswith(('_e','_n','_shadow')):
            assert sha(p)==sha(old),str(p)
            continue
        im=Image.open(p).convert('RGBA');src=Image.open(old).convert('RGBA')
        assert im.size==src.size and np.array_equal(np.asarray(im)[:,:,3],np.asarray(src)[:,:,3]),str(p)
        im.save(p,optimize=True,compress_level=9);count+=1
    a=np.asarray(Image.open(folder/'idle.png').convert('RGBA'))/255.;m=a[:,:,3]>.5;y=(a[:,:,:3]@np.array([.2126,.7152,.0722]))[m]
    mean=float(y.mean());p90,p99=np.percentile(y,[90,99]);assert .25<=mean<=.36 and p90<=.55 and p99<=.75,(name,mean,p90,p99)
    report[name]=[round(mean,4),round(float(p90),4),round(float(p99),4)]
    pair=[]
    for root in (backup,folder):
        im=Image.open(root/'idle.png').convert('RGBA');tile=im.crop((0,0,min(170,im.width),min(170,im.height)));pair.append(tile)
    rows.append(pair)
board=Image.new('RGBA',(340,170*len(rows)),(17,19,22,255))
for r,pair in enumerate(rows):
    for c,im in enumerate(pair):board.alpha_composite(im,(c*170,r*170))
board.convert('RGB').save(WORK/'contact.png')
(WORK/'verification.json').write_text(json.dumps(report,indent=2))
print('PASS',count,'sheets; alpha/sizes/names/_e/.tres unchanged')
for n,v in report.items():print(n,*v)
