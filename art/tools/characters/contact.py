"""Planche de contact (PIL: assemblage seulement). Usage: contact.py <sheet.png> <frame> <size> <out.png> [frame_index]"""
import sys
sys.path.insert(0,r'C:\Users\const\Documents\Rainfall\art\tools\vendor')
from PIL import Image
if '--r4' in sys.argv:
    from pathlib import Path
    root=Path(__file__).resolve().parents[3]
    assets=root/'game/assets/sprites/characters/ardent'
    bg=Image.new('RGBA',(768,1088),(43,51,64,255))
    run=Image.open(assets/'run.png').convert('RGBA')
    for r in range(8):
        for f in range(8):
            tile=run.crop((f*192,r*192,(f+1)*192,(r+1)*192))
            bg.alpha_composite(tile.resize((96,96),Image.LANCZOS),(f*96,r*96))
    for a,anim in enumerate(['idle','run']):
        im=Image.open(assets/(anim+'.png')).convert('RGBA')
        for r in range(8):
            tile=im.crop((384,r*192,576,(r+1)*192))
            bg.alpha_composite(tile.resize((64,64),Image.LANCZOS),(r*96,768+a*64))
    for k,suffix in enumerate(['','_n','_e']):
        im=Image.open(assets/('run'+suffix+'.png')).convert('RGBA')
        bg.alpha_composite(im.crop((384,384,576,576)),(k*256,896))
    out=root/'art/renders/characters/ardent_r4_contact.png'
    bg.convert('RGB').save(out)
    print('PASS contact assembled')
    raise SystemExit
sheet,fs,out=sys.argv[1],int(sys.argv[2]),sys.argv[3]
fi=int(sys.argv[4]) if len(sys.argv)>4 else 2
im=Image.open(sheet).convert('RGBA'); rows=im.size[1]//fs
bg=Image.new('RGBA',(rows*fs,fs*2),(43,51,64,255))
for r in range(rows):
    f=im.crop((fi*fs,r*fs,(fi+1)*fs,(r+1)*fs)); bg.alpha_composite(f,(r*fs,0))
    sm=f.resize((fs//2,fs//2),Image.LANCZOS); bg.alpha_composite(sm,(r*fs,fs+0))
    sm2=f.resize((fs//3,fs//3),Image.LANCZOS); bg.alpha_composite(sm2,(r*fs+fs//2,fs))
bg.convert('RGB').save(out)
