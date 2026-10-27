"""TOCP3 contract checks; one contact only. Pillow crops, assembles and checks."""
from pathlib import Path
import sys,json,re,hashlib
import numpy as np
from PIL import Image,ImageChops
sys.path.insert(0,str(Path(__file__).parent))
from tocp3_build import ROOT,WORK,GAME,ICONS,ANIMS,DIRS
data=json.loads((WORK/'verification.json').read_text())
count=0
for rel,(x,y,w,h) in data['sheets'].items():
    p=GAME/rel;n=ANIMS[p.stem]
    im=Image.open(p).convert('RGBA')
    assert im.size==(n*w,8*h) and max(im.size)<=4096,(rel,im.size)
    for row in range(8):
        for i in range(n):
            bb=im.crop((i*w,row*h,(i+1)*w,(row+1)*h)).getchannel('A').getbbox()
            absent=rel.startswith('layers/arm_') and rel.split('/')[1]==p.stem[6:] and i>=2
            if absent:assert bb is None,(rel,row,i,'release')
            else:assert bb and min(bb[:2])>=4 and bb[2]<=w-4 and bb[3]<=h-4,(rel,row,i,bb)
    ep=p.with_name(p.stem+'_e.png')
    if ep.exists():
        em=Image.open(ep).convert('RGBA');a=np.asarray(em,dtype=float)
        assert em.size==((im.width+1)//2,(im.height+1)//2),(rel,'emission size')
        assert (a[...,:3].max(axis=-1)*a[...,3]/255).max()>2,(rel,'black emission')
    assert not p.with_name(p.stem+'_n.png').exists()
    count+=1
resources=0
for old in (WORK/'before/assets/sprites/characters/tocsin').glob('*.tres'):
    p=GAME/old.name;text=p.read_text();before=old.read_text()
    # Animation names, durations, speeds, loops, frame IDs and all resource paths retained.
    assert text[text.index('[resource]'):]==before[before.index('[resource]'):],p.name
    assert re.findall(r'\[ext_resource[^\n]+',text)==re.findall(r'\[ext_resource[^\n]+',before),p.name
    assert 'CanvasTexture' not in text and 'normal_texture' not in text
    ext={i:r.removesuffix('_e.png')+'.png' if r.endswith('_e.png') else r for r,i in re.findall(r'path="res://assets/sprites/characters/tocsin/([^"\n]+)" id="([^"\n]+)"',text)}
    target=set()
    for block in re.findall(r'\[sub_resource type="AtlasTexture"[^\[]+',text):
        atlas=re.search(r'atlas = ExtResource\("([^"\n]+)"\)',block)
        rel=ext.get(atlas[1]) if atlas else None
        if rel not in data['sheets']:continue
        x,y,w,h=data['sheets'][rel]
        rx,ry,rw,rh=map(float,re.search(r'region = Rect2\(([^)]+)',block)[1].split(','))
        assert (rw,rh)==(w,h) and rx%w==ry%h==0,(p.name,rel,'region')
        assert f'margin = Rect2({x}, {y}, {192-w}, {192-h})' in block
        target.add(rel)
    assert target,p.name
    resources+=1
pose=json.loads((WORK/'pose.json').read_text());assert len(pose)>=8 and max(e['contact_error_u'] for e in pose)<1e-6
for name in ('tocsin_bras_pilier','tocsin_coup_de_tocsin'):
    p=ICONS/(name+'.png');im=Image.open(p);assert im.size==(128,128) and im.mode=='RGBA'
    before=WORK/'before/assets/sprites/icons/spells'/p.name
    assert before.exists() and before.read_bytes()!=p.read_bytes()
    neighbor=Image.open(ICONS/'tocsin_rivets_rougis.png').convert('RGBA')
    assert im.getchannel('A').getbbox()==neighbor.getchannel('A').getbbox(),name
# Compose displayed CREA sprites over actual terrace ground; no drawing.
cw,ch=224,304
canvas=Image.new('RGBA',(cw*8,ch*4),(18,22,23,255))
ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
for row in range(4):
    for col in range(8):
        for gy in range(0,ch,ground.height):
            for gx in range(0,cw,ground.width):
                tile=ground.crop((0,0,min(ground.width,cw-gx),min(ground.height,ch-gy)))
                canvas.alpha_composite(tile,(col*cw+gx,row*ch+gy))
samples=[[(a,'s',i) for a in ('throw_arm_l','throw_arm_r') for i in range(4)],
         [('throw_arm_l',d,1) for d in DIRS],
         [('cast',d,3) for d in DIRS],
         [('cast','s',i) for i in range(6)]]
for row,line in enumerate(samples):
    for col,(anim,d,i) in enumerate(line):
        x,y,w,h=data['sheets'][anim+'.png'];dr=DIRS.index(d)
        atlas=Image.open(GAME/(anim+'.png'))
        sprite=Image.new('RGBA',(192,192));sprite.paste(atlas.crop((i*w,dr*h,(i+1)*w,(dr+1)*h)),(x,y))
        display=sprite.resize((136,272),Image.Resampling.LANCZOS)
        canvas.alpha_composite(display,(col*cw+(cw-136)//2,row*ch+240-round(136.32*272/192)))
for col,name in enumerate(('tocsin_bras_pilier','tocsin_coup_de_tocsin'),6):
    for j,p in enumerate((WORK/'before/assets/sprites/icons/spells'/(name+'.png'),ICONS/(name+'.png'))):
        icon=Image.open(p).convert('RGBA').resize((104,104),Image.Resampling.LANCZOS)
        canvas.alpha_composite(icon,(col*cw+j*108+4,3*ch+100))
canvas.save(ROOT/'art/tools/tocsin/tocp3_contact.png',optimize=True)
stats={'PASS':True,'sheets':count,'resources':resources,'fist_error_u':max(e['contact_error_u'] for e in pose)}
pngs=list((WORK/'before').rglob('*.png'))
stats['png_bytes_before']=sum(p.stat().st_size for p in pngs)
stats['png_bytes_after']=sum((ROOT/'game'/p.relative_to(WORK/'before')).stat().st_size for p in pngs)
(WORK/'checks.json').write_text(json.dumps(stats,indent=2));print(json.dumps(stats))
