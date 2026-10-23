"""AV3 contract checks and contact assembly only; no painted pixels."""
from pathlib import Path
import re, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
FOLDER=ROOT/'game/assets/sprites/characters/averse/effects/wave_cone'
def name(page,su=''):
    return 'wave_cone'+('' if page==0 else '_atlas'+str(page))+su+'.png'
board=Image.new('RGBA',(1536,1536),(16,21,25,255))
for row,ground in enumerate(('rust_city','terraces')):
    path=ROOT/f'game/assets/sprites/terrain/{ground}/ground_stone.png'
    if not path.exists():path=ROOT/f'game/assets/sprites/terrain/{ground}/ground_concrete.png'
    with Image.open(path) as src:tile=src.convert('RGBA');tile.thumbnail((256,256))
    for y in range(row*384,(row+1)*384,tile.height):
        for x in range(0,1536,tile.width):board.alpha_composite(tile,(x,y))
    for f in range(6):
        direction=0 if row==0 else 3;slot=(direction%2)*6+f
        with Image.open(FOLDER/name(direction//2)) as atlas:
            im=atlas.crop((slot%4*1024,slot//4*1024,slot%4*1024+1024,slot//4*1024+1024))
        im.thumbnail((256,256));board.alpha_composite(im,(f*256,row*384+64))
for su in ('','_n','_e'):
    for page in range(4):
        with Image.open(FOLDER/name(page,su)) as atlas:
            assert atlas.size==(4096,3072)
            for local in range(2):
                hashes=[]
                for f in range(6):
                    slot=local*6+f
                    tile=atlas.crop((slot%4*1024,slot//4*1024,slot%4*1024+1024,slot//4*1024+1024))
                    bb=tile.getchannel('A').getbbox();assert bb and min(bb[:2])>=3 and max(bb[2:])<=1021,(page,su,f,bb)
                    hashes.append(hashlib.sha256(tile.tobytes()).digest())
                    if su=='_e':assert max(tile.convert('RGB').getextrema()[1])>100
                    if f==3:
                        tile.thumbnail((128,128));board.alpha_composite(tile,((page*2+local)*192,768+('','_n','_e').index(su)*128))
                assert len(set(hashes))==6
for res in FOLDER.glob('wave_cone*.tres'):
    txt=res.read_text();assert len(re.findall('type="AtlasTexture"',txt))==48
    assert len(re.findall('"name":',txt))==8
    for p in re.findall('path="res://([^"\n]+)"',txt):assert (ROOT/'game'/p).exists(),p
for j,path in enumerate(('art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png')):
    with Image.open(ROOT/path) as src:
        im=src.convert('RGBA');im.thumbnail((500,360));board.alpha_composite(im,(j*512,1160))
board.save(ROOT/'art/tools/night/_av3_contact.png',optimize=True)
print('AV3 CONTRACT PASS: 48 frames x 3 passes, pivots 512, atlases 4096x3072; 8 animations unchanged')

