"""Targeted structural checks and one contact sheet. Pillow: crop/assemble/check only."""
from pathlib import Path
import json,re,sys,hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'art/blender/cel/tocp1'
GAME=ROOT/'game/assets/sprites/characters/tocsin'
report=json.loads((WORK/'verification.json').read_text())
dirs=['e','se','s','sw','w','nw','n','ne']
results={}
for anim,spec in report.items():
    w,h=spec['cell'];n=spec['frames'];im=Image.open(GAME/(anim+'.png')).convert('RGBA')
    assert im.size==(n*w,8*h) and max(im.size)<=4096
    assert not (GAME/(anim+'_n.png')).exists()
    hashes=[]
    for row in range(8):
        for i in range(n):
            tile=im.crop((i*w,row*h,(i+1)*w,(row+1)*h));bb=tile.getchannel('A').getbbox()
            assert bb and bb[0]>=4 and bb[1]>=4 and bb[2]<=w-4 and bb[3]<=h-4
            hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
    assert len(set(hashes))==len(hashes),(anim,'duplicated tiles')
    ep=GAME/(anim+'_e.png')
    if spec['emission']:
        em=Image.open(ep).convert('RGBA');assert em.size==((im.width+1)//2,(im.height+1)//2)
        a=np.asarray(em,dtype=float)/255;assert (a[...,:3].max(axis=-1)*a[...,3]).max()>2/255
    else:assert not ep.exists()
    for suffix in ('','_emission'):
        txt=(GAME/('tocsin_'+anim+suffix+'.tres')).read_text()
        assert 'CanvasTexture' not in txt and 'normal_texture' not in txt
        if suffix and not spec['emission']:continue
        assert len(re.findall('type="AtlasTexture"',txt))==n*8
        for d in dirs:assert f'&"{anim}_{d}"' in txt
        assert txt.count('"loop": true')==(8 if anim!='arm_fly' else 0)
    results[anim]={'unique_tiles':len(set(hashes)),'PASS':True}

# CREA display transform, original logical framing and real terrace ground.
samples=[ [('arm_clamp',d,0) for d in dirs],
          [('arm_clamp','s',i) for i in range(8)],
          [('arm_fly','s',i) for i in range(6)]+[('arm_ground',d,0) for d in ('s','e')],
          [('arm_ground',d,0) for d in dirs] ]
cw,ch=224,304
canvas=Image.new('RGBA',(8*cw,4*ch),(18,22,23,255))
ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
for row,line in enumerate(samples):
    for col,(anim,d,i) in enumerate(line):
        cx=col*cw+cw//2;fy=row*ch+240
        panel=Image.new('RGBA',(cw,ch),(18,22,23,255))
        for gy in range(-ground.height,ch,ground.height):
            for gx in range(-ground.width,cw,ground.width):panel.alpha_composite(ground,(gx,gy))
        canvas.alpha_composite(panel,(col*cw,row*ch))
        spec=report[anim];w,h=spec['cell'];x,y=spec['crop'][:2];dy=dirs.index(d)
        with Image.open(GAME/(anim+'.png')) as atlas:tile=atlas.crop((i*w,dy*h,(i+1)*w,(dy+1)*h))
        logical=Image.new('RGBA',(192,192));logical.paste(tile,(x,y))
        display=logical.resize((136,272),Image.Resampling.LANCZOS)
        canvas.alpha_composite(display,(cx-68,fy-round(136.32*2**.5)))
canvas.convert('RGB').save(WORK/'contact.png',optimize=True)
(WORK/'checks.json').write_text(json.dumps({'checks':results,'contact_rows':samples,'scale_px_per_u':64,'scalar_scale':1,'CREA':[.70710678,1.4142136]},indent=2))
print('TOCP1 CHECK PASS: 120 unique tiles; 4px margins; half emission; no normals; CREA 64 px/u')
