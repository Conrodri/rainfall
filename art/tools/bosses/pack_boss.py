"""Assemblage/reduction uniquement : aucune creation graphique hors Blender."""
from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[3]
folder=ROOT/'art/renders/bosses/eclusier/_preview'
report={}
for source in sorted((folder/'raw').glob('*.png')):
    im=Image.open(source).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
    if source.stem.endswith(('_n','_e')) and source.with_name(source.stem[:-2]+'.png').exists():
        base=source.with_name(source.stem[:-2]+'.png')
        im.putalpha(Image.open(base).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).getchannel('A'))
    if source.stem.endswith('_n'):
        # Encodage conventionnel du fond transparent apres filtrage premultiplie.
        pixels=list(im.get_flattened_data())
        im.putdata([(128,128,255,0) if p[3]==0 else p for p in pixels])
    im.save(folder/source.name)
    bbox=im.getchannel('A').getbbox()
    assert bbox and min(bbox[0],bbox[1],256-bbox[2],256-bbox[3])>=4,(source.name,bbox)
    report[source.name]={'size':[256,256],'alpha_bbox':bbox,'margin_min':min(bbox[0],bbox[1],256-bbox[2],256-bbox[3])}
# Simple contact sheet, paste existing images only, no drawing.
names=['idle_p1_s','idle_p2_s','idle_p3_s','walk_p1_e']
board=Image.new('RGBA',(1024,768),(0,0,0,0))
for col,name in enumerate(names):
    for row,suffix in enumerate(('','_n','_e')):
        board.paste(Image.open(folder/(name+suffix+'.png')),(col*256,row*256))
board.save(folder/'contact_sheet.png')
(folder/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))


