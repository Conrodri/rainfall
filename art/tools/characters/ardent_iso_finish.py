"""C4 atlas assembly and contract checks. Pillow only assembles/crops/resizes.
Normal vectors are normalized numerically using the existing pack.py convention.
Contact positions: idle E..NE; run SE frames 0..7; 3x3 ground at native CREA scale.
Right column: same-scale ash lord; R8a/R8d/C1 material and lighting references.
"""
import json,hashlib,math,re
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
TOOLS=ROOT/'art/tools/characters'
ASSET=ROOT/'game/assets/sprites/characters/ardent'
RAW=TOOLS/'ardent_iso_frames'
DIRS=['e','se','s','sw','w','nw','n','ne']
SUFFIX=['','_n','_e']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inventory():
    result={}
    for p in sorted(ASSET.iterdir()):
        if not p.is_file():continue
        result[p.name]={'sha256':sha(p),'bytes':p.stat().st_size}
        if p.suffix=='.png':
            with Image.open(p) as im:result[p.name].update(size=list(im.size),mode=im.mode)
    return result
baseline=TOOLS/'ardent_iso_inventory.json'
if not baseline.exists():baseline.write_text(json.dumps(inventory(),indent=2))
initial=json.loads(baseline.read_text())
r4=json.loads((TOOLS/'_r4_inventory.json').read_text())
assert r4['directions']==DIRS and r4['frames']==8 and r4['cell']==192
with (ASSET/'ardent.tres').open() as source:
    names=[m.group(1) for line in source if (m:=re.search(r'"name": &"([^"]+)"',line))]
assert names==r4['animations']
staged={};summary=[]
for anim in ('idle','run'):
    sheets=[Image.new('RGBA',(1536,1536)) for _ in SUFFIX]
    unique=[];bounds=[];emission=[]
    for row,d in enumerate(DIRS):
        hashes=[]
        for i in range(8):
            images=[Image.open(RAW/anim/(d+'_%02d'%i+su+'.png')).convert('RGBA') for su in SUFFIX]
            assert all(im.size==(192,192) for im in images)
            diffuse=np.asarray(images[0]);normal=np.array(images[1]);emit=np.array(images[2])
            v=normal[:,:,:3].astype(float)/127.5-1
            lengths=np.linalg.norm(v,axis=2,keepdims=True)
            v/=np.maximum(lengths,1e-8)
            normal[:,:,:3]=np.rint((v+1)*127.5).clip(0,255).astype(np.uint8)
            normal[:,:,3]=diffuse[:,:,3];normal[diffuse[:,:,3]==0]=[128,128,255,0]
            emit[:,:,3]=diffuse[:,:,3]
            images[1]=Image.fromarray(normal);images[2]=Image.fromarray(emit)
            b=images[0].getchannel('A').getbbox()
            assert b and min(b[:2])>=4 and max(b[2:])<=188,(anim,d,i,b)
            assert np.any((emit[:,:,:3].max(axis=2)>100)&(emit[:,:,3]>100)),(anim,d,i,'black fire')
            hashes.append(hashlib.sha256(images[0].tobytes()).hexdigest());bounds.append(b)
            for sheet,im in zip(sheets,images):sheet.paste(im,(i*192,row*192))
        assert len(set(hashes))==8,(anim,d,'duplicate frames')
        unique.append(len(set(hashes)))
    for su,sheet in zip(SUFFIX,sheets):staged[anim+su+'.png']=sheet
    normal=np.asarray(sheets[1]);vectors=normal[:,:,:3].astype(float)/127.5-1
    selected=normal[:,:,3]>200
    assert np.max(np.abs(np.linalg.norm(vectors[selected],axis=1)-1))<.015
    summary.append({'animation':anim,'unique_frames_each_direction':unique,'union_bbox':[min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds)]})
for name,sheet in staged.items():sheet.save(ASSET/name,optimize=True,compress_level=9)
current=inventory()
assert current.keys()==initial.keys()
for name,before in initial.items():
    if name.endswith('.png'):
        assert current[name]['size']==before['size']==[1536,1536]
        assert current[name]['mode']==before['mode']=='RGBA'
        assert current[name]['sha256']!=before['sha256']
    else:assert current[name]==before,('metadata changed',name)
report={'contract':'PASS','sheets':6,'cell':192,'size':[1536,1536],'directions':DIRS,'frames':8,'metadata_unchanged':True,'tres_sha256':sha(ASSET/'ardent.tres'),'normal_space':'screen right / up / viewer; unit vectors','emission':'orange flame, rising embers and discrete hood eyes; nonblack in every frame','animations':summary,'rig':json.loads((TOOLS/'ardent_iso_bounds.json').read_text()),'files':current}
(ROOT/'art/tools/iso/_c4_verification.json').write_text(json.dumps(report,indent=2))
# No drawing: compose the actual PNGs at their physical render scale.
canvas=Image.new('RGBA',(2048,1232),(24,29,31,255))
idle=staged['idle.png'];run=staged['run.png']
for r in range(8):canvas.alpha_composite(idle.crop((0,r*192,192,(r+1)*192)),(r*192,0))
canvas.alpha_composite(run.crop((0,192,1536,384)),(0,208))
tile=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
assert tile.size==(512,256)
for depth in range(5):
    for i in range(3):
        j=depth-i
        if 0<=j<3:canvas.alpha_composite(tile,(512+(i-j)*256,432+(i+j)*128))
ash=Image.open(ROOT/'game/assets/sprites/bosses/mini/ash_lord/idle.png').convert('RGBA').crop((0,0,170,170))
fit=json.loads((ROOT/'art/renders/monsters/ash_lord/build_report.json').read_text())['framing']
ash_side=round(64*math.sqrt(2)*fit['ortho_scale'])
ash=ash.resize((ash_side,ash_side),Image.Resampling.LANCZOS)
canvas.alpha_composite(ash,(1616,0))
def actor(im,foot,pivot):canvas.alpha_composite(im,(round(foot[0]-pivot[0]),round(foot[1]-pivot[1])))
actor(ash,(920,760),(ash_side/2,.70*ash_side))
actor(idle.crop((0,384,192,576)),(672,830),(96,136.32))
actor(idle.crop((0,960,192,1152)),(800,894),(96,136.32))
actor(run.crop((384,192,576,384)),(1056,900),(96,136.32))
for path,top,height in [('art/tools/monsters/_r8a_contact.png',368,256),('art/tools/monsters/_r8d_contact.png',640,256),('art/tools/iso/_c1_contact.png',912,304)]:
    ref=Image.open(ROOT/path).convert('RGBA');ref.thumbnail((496,height),Image.Resampling.LANCZOS)
    canvas.alpha_composite(ref,(1544,top))
canvas.convert('RGB').save(ROOT/'art/tools/iso/_c4_contact.png',optimize=True,compress_level=9)
(ROOT/'art/tools/iso/_c4_contact.json').write_text(json.dumps({'idle_row':DIRS,'run_row':'se, frames 0..7','terrain':'3x3 ground_a, 512x256 native MAP; CREA R=90.5097','ash_rescale':{'original_frame':170,'original_R':170/fit['ortho_scale'],'contact_frame':ash_side},'right_column':['ash_lord same R','R8a reference','R8d reference','C1 reference']},indent=2))
print('PASS C4: 6 RGBA atlases, 128 unique poses, margins, normals, fire, metadata; contact assembled')
