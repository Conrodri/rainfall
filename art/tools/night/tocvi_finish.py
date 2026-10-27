"""TOCVI crop, assemble and verify only; no raster drawing."""
from pathlib import Path
import hashlib
from PIL import Image
import icons_norm_finish as f
ROOT=Path(__file__).resolve().parents[3]
WORK=ROOT/'art/blender/cel/tocvi'
GAME=ROOT/'game/assets/sprites/icons/spells'
NAMES=['tocsin_bras_pilier','tocsin_coup_de_tocsin','tocsin_vapeur','tocsin_tete_fumigene','nova_ardente']
def finish():
    f.WORK=WORK
    for name in NAMES[2:4]:f.fit_image(WORK/(name+'_raw.png')).save(GAME/(name+'.png'),compress_level=9)
    sheet=Image.new('RGBA',(5*144,2*224))
    for row,bg in enumerate(('#0A0D12','#2E3238')):
        panel=Image.new('RGBA',(720,224),bg);sheet.paste(panel,(0,row*224))
        for col,name in enumerate(NAMES):
            im=Image.open(GAME/(name+'.png'))
            assert im.size==(128,128) and im.mode=='RGBA' and im.getbbox()==(10,8,121,120),(name,im.getbbox())
            sheet.alpha_composite(im,(col*144+8,row*224))
            sheet.alpha_composite(im.resize((72,72),Image.Resampling.LANCZOS),(col*144+36,row*224+140))
    sheet.convert('RGB').save(ROOT/'art/tools/night/tocvi_contact.png')
    print('PASS 5 RGBA 128x128 bbox (10, 8, 121, 120)')
if __name__=='__main__':finish()
