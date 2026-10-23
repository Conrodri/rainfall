import sys
sys.dont_write_bytecode=True
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image
p=Path(__file__).parent
canvas=Image.new('RGB',(2400,3200),(23,31,41))
for j,id in enumerate(['tocsin','averse']):
    im=Image.open(p/f'_cd_{id}.png');assert im.size==(2400,1350);canvas.paste(im,(0,j*1350))
    hero=Image.open(p/f'_cd_{id}_hero.png');print(id, 'hero bounds',hero.getchannel('A').getbbox())
for j,path in enumerate([p.parent/'iso/_c4_contact.png',p/'_m2_contact.png']):
    im=Image.open(path).convert('RGB');im.thumbnail((1190,490));canvas.paste(im,(j*1200,2700))
canvas.save(p/'_cd_cd1_contact.png')
print('PASS two boards / references assembled / 2400x3200')
