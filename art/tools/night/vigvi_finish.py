"""Pillow only fits, assembles, verifies. No drawing."""
import sys
from pathlib import Path
from PIL import Image
import icons_norm_finish as f
BASE=Path(__file__).resolve().parent
f.WORK=f.ROOT/'art/blender/cel/vigvi'
NAMES=['vigie_tir_double','vigie_fanal','vigie_chausse_trapes','vigie_tir_de_signal']
if len(sys.argv)>1 and sys.argv[1]=='fit':
    f.fit(sys.argv[2])
else:
    paths=[f.GAME/(name+'.png') for name in NAMES+['nova_ardente']]
    board=Image.new('RGB',(5*160,2*224))
    for row,bg in enumerate(('#0A0D12','#2E3238')):
        band=Image.new('RGB',(800,224),bg);board.paste(band,(0,row*224))
        for col,p in enumerate(paths):
            im=Image.open(p).convert('RGBA')
            assert im.size==(128,128) and im.getbbox()==(10,8,121,120)
            for size,y in [(128,4),(72,144)]:
                tile=im.resize((size,size),Image.Resampling.LANCZOS)
                board.paste(tile,(col*160+(160-size)//2,row*224+y),tile)
    board.save(BASE/'vigvi_contact.png')
    print('PASS 4 icons: RGBA 128x128 bbox (10, 8, 121, 120); contact 5 columns')
