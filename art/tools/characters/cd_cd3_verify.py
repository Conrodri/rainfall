from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image,ImageStat
OUT=Path(__file__).resolve().parent
canvas=Image.new('RGB',(1800,1350),(23,33,45))
for i,id in enumerate(['avare','bourbe']):
 with Image.open(OUT/f'_cd_{id}.png') as im:
  assert im.size==(2400,1350)
  assert max(ImageStat.Stat(im.convert('RGB')).stddev)>10
  canvas.paste(im.resize((1200,675)),(0,i*675))
 with Image.open(OUT/f'cd_{id}_hero.png') as im:
  box=im.getchannel('A').getbbox();print(id,'hero bounds',box)
 for ext in ['build.py','hero.png','jeu.png','sort.png']:
  assert (OUT/f'cd_{id}_{ext}').exists()
 assert (OUT.parents[1]/f'blender/characters/cd_{id}.blend').stat().st_size>100000
for rel,y in [('iso/_c4_contact.png',0),('characters/_m2_contact.png',675)]:
 with Image.open(OUT.parent/rel) as im:
  im.thumbnail((580,665));canvas.paste(im,(1210,y))
canvas.save(OUT/'_cd_cd3_contact.png')
print('PASS CD3: 2 planches, 2 sources, vues et poses')
