"""Verification des livrables et assemblage de la planche de controle."""
from pathlib import Path
from PIL import Image,ImageChops
import json,re
ROOT=Path(__file__).resolve().parents[3];raw=ROOT/'art/renders/bosses/eclusier';out=ROOT/'game/assets/sprites/bosses/etage/eclusier'
r=json.loads((raw/'validation.json').read_text());board=Image.new('RGBA',(768,128*len(r)),(0,0,0,0));results={}
for row,(anim,v) in enumerate(r.items()):
    w,h=v['frame_size'];n=v['frames'];dirs=v['directions'];base=Image.open(out/f'{anim}.png').convert('RGBA')
    assert base.size==tuple(v['sheet_size'])
    for suffix in ('_n','_e'):
        im=Image.open(out/f'{anim}{suffix}.png').convert('RGBA');assert im.size==base.size
        assert ImageChops.difference(base.getchannel('A'),im.getchannel('A')).getbbox() is None
        if suffix=='_n':assert all(p[:3]==(128,128,255) for p in im.getdata() if p[3]==0)
    motion=[]
    for d in dirs:
        ims=[Image.open(raw/anim/f'{d}_{f:02}.png').convert('RGBA') for f in range(n)]
        motion.append(len(set(im.tobytes() for im in ims)))
        assert n==1 or motion[-1]>1,(anim,d,'no motion')
    margin=min(min(b[0],b[1],w-b[2],h-b[3]) for b in v['bounds'])
    assert anim=='ground_water' or margin>=4,(anim,margin)
    for col,f in enumerate(sorted(set([0,n//2,n-1]))):
        im=base.crop((f*w,0,(f+1)*w,h));im.thumbnail((256,128));board.paste(im,(col*256,row*128))
    results[anim]={'unique_frames_by_direction':motion,'minimum_margin':margin}
board.save(raw/'contact_overview.png')
t=(out/'eclusier.tres').read_text();assert len(re.findall('"name":',t))==28
assert len(re.findall('type="AtlasTexture"',t))==sum(v['frames']*len(v['directions']) for v in r.values())
(raw/'checks.json').write_text(json.dumps(results,indent=2));print('PASS: dimensions, alpha, normal backgrounds, motion, margins, 28 SpriteFrames animations and all atlas regions.')
