"""R9b assembly-only contact: boss columns; S/E/W/N rows; windup/impact/return."""
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[2]
names=['ash_lord','bramble_queen','brood_mother']
canvas=Image.new('RGBA',(1620,720),(105,105,105,255))
for b,name in enumerate(names):
    out=ROOT/'game/assets/sprites/bosses/mini'/name
    for row,d in enumerate(['s','e','w','n']):
        with Image.open(out/('attack.png' if d=='s' else 'attack_dirs.png')) as sh:
            y=0 if d=='s' else (row-1)*170
            for col,i in enumerate([2,3,5]):
                canvas.alpha_composite(sh.crop((i*170,y,(i+1)*170,y+170)).convert('RGBA'),(b*540+col*175+8,row*180+5))
canvas.convert('RGB').save(HERE/'_r9b_contact.png',optimize=True)
print('R9B_CONTACT PASS: columns ash_lord/bramble_queen/brood_mother; rows S/E/W/N; keys 2/3/5')
