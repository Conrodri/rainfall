"""AVSVI contact: crop/assemble/verify only, no drawing."""
from pathlib import Path
from PIL import Image
import hashlib
ROOT=Path(__file__).resolve().parents[3]
GAME=ROOT/'game/assets/sprites/icons/spells'
names=['nova_ardente','averse_bruine','averse_geyser','averse_gouttiere','averse_mousson']
sheet=Image.new('RGB',(5*144,2*224))
for row,bg in enumerate(['#0A0D12','#2E3238']):
    sheet.paste(Image.new('RGB',(720,224),bg),(0,row*224))
    for col,name in enumerate(names):
        p=GAME/(name+'.png');im=Image.open(p)
        assert im.mode=='RGBA' and im.size==(128,128) and im.getbbox()==(10,8,121,120),(name,im.getbbox())
        if col:
            assert not (GAME/(name+'_e.png')).exists()
            assert not (GAME/(name+'_n.png')).exists()
        for size,y in [(128,0),(72,140)]:
            tile=im.resize((size,size),Image.Resampling.LANCZOS)
            sheet.paste(tile,(col*144+(144-size)//2,row*224+y),tile)
sheet.save(ROOT/'art/tools/night/avsvi_contact.png')
print('PASS 4 RGBA 128x128 bbox=(10, 8, 121, 120); no _n/_e; contact 128/72')
