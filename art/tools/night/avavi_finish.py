"""Pillow only fits, assembles and checks; shared i3_finish-derived Nova fit."""
import sys, hashlib
from pathlib import Path
from PIL import Image
import icons_norm_finish as shared
ROOT=Path(__file__).resolve().parents[3]
BASE=Path(__file__).resolve().parent
WORK=ROOT/'art/blender/cel/avavi'
GAME=ROOT/'game/assets/sprites/icons/spells'
NAMES=['avare_coffre_belier','avare_piece_truquee','avare_saisie','avare_tresor_enterre']
shared.WORK=WORK
if len(sys.argv)>1 and sys.argv[1]=='fit':
    shared.fit(sys.argv[2])
else:
    names=['nova_ardente']+NAMES
    board=Image.new('RGB',(5*144,2*220))
    for row,color in enumerate(('#0A0D12','#2E3238')):
        board.paste(Image.new('RGB',(720,220),color),(0,row*220))
        for col,name in enumerate(names):
            im=Image.open(GAME/(name+'.png')).convert('RGBA')
            assert im.size==(128,128) and im.getbbox()==(10,8,121,120)
            assert not (GAME/(name+'_n.png')).exists()
            assert not (GAME/(name+'_e.png')).exists()
            board.paste(im,(col*144+8,row*220+4),im)
            small=im.resize((72,72),Image.Resampling.LANCZOS)
            board.paste(small,(col*144+36,row*220+140),small)
    board.save(BASE/'avavi_contact.png')
    print('PASS 4 icons: 128x128 RGBA; bbox (10, 8, 121, 120); no _n/_e; contact')
