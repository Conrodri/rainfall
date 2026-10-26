"""ARPVI raster checks and contact assembly; no painted pixels."""
from pathlib import Path
from PIL import Image
import hashlib
ROOT=Path(__file__).resolve().parents[3]
GAME=ROOT/'game/assets/sprites/icons/spells'
NAMES=['nova_ardente','arpenteuse_chaine_lestee','arpenteuse_noeud','arpenteuse_jalons','arpenteuse_cerceau']
board=Image.new('RGB',(5*144,432))
hashes=[]
for row,bg in enumerate(['#0A0D12','#2E3238']):
    panel=Image.new('RGB',(720,216),bg)
    for col,name in enumerate(NAMES):
        p=GAME/(name+'.png');im=Image.open(p)
        assert im.size==(128,128) and im.mode=='RGBA' and im.getbbox()==(10,8,121,120),name
        assert not any((GAME/(name+s+'.png')).exists() for s in ['_n','_e']),name
        panel.paste(im,(col*144+8,4),im)
        small=im.resize((72,72),Image.Resampling.LANCZOS)
        panel.paste(small,(col*144+36,140),small)
        if row==0:hashes.append(hashlib.sha256(p.read_bytes()).hexdigest())
    board.paste(panel,(0,row*216))
assert len(set(hashes))==5
board.save(ROOT/'art/tools/night/arpvi_contact.png')
print('PASS 4 icons: RGBA 128x128; bbox (10, 8, 121, 120); no _n/_e; unique hashes')
