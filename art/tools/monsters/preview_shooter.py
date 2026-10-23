"""Contact sheet et controles : assemblage de rendus Blender exclusivement."""
import sys,json,re
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'art/renders/monsters/shooter_tier2'
DIRS=['e','se','s','sw','w','nw','n','ne']
entries=[('run',d,0) for d in DIRS]+[('attack','s',i) for i in [0,4,5,7]]
# Diffuse row followed by exactly corresponding screen normal maps.
sheet=Image.new('RGBA',(12*112,2*112),'#2B3340')
for col,(anim,d,i) in enumerate(entries):
    for row,suffix in enumerate(['','_n']):
        with Image.open(BASE/anim/f'{d}_{i:02d}{suffix}.png') as im:
            im=im.convert('RGBA').resize((112,112),Image.Resampling.LANCZOS)
            sheet.alpha_composite(im,(col*112,row*112))
sheet.convert('RGB').save(BASE/'_preview.png')
report={'frames':0,'passes':0,'min_transparent_margin_final':112,'alpha_mismatches':[],'normal_padding_errors':0,'sheets':{}}
for anim in ['run','attack']:
    for d in DIRS:
        for i in range(8):
            path=BASE/anim/f'{d}_{i:02d}.png';diff=Image.open(path).convert('RGBA');assert diff.size==(224,224)
            bbox=diff.getchannel('A').getbbox();report['frames']+=1
            final=diff.resize((112,112),Image.Resampling.LANCZOS);bb=final.getchannel('A').getbbox()
            report['min_transparent_margin_final']=min(report['min_transparent_margin_final'],bb[0],bb[1],112-bb[2],112-bb[3])
            for suffix in ['_n','_e']:
                im=Image.open(path.with_stem(path.stem+suffix)).convert('RGBA');assert im.size==diff.size
                if ImageChops.difference(im.getchannel('A'),diff.getchannel('A')).getbbox():report['alpha_mismatches'].append(str(path.with_stem(path.stem+suffix)))
                if suffix=='_n':report['normal_padding_errors']+=sum(1 for r,g,b,a in im.get_flattened_data() if a==0 and (r,g,b)!=(128,128,255))
                report['passes']+=1
    out=ROOT/'game/assets/sprites/monsters/shooter_tier2'
    for suffix in ['','_n','_e']:
        with Image.open(out/f'{anim}{suffix}.png') as im:
            assert im.size==(896,896);report['sheets'][f'{anim}{suffix}']=list(im.size)
assert not report['alpha_mismatches'],report
assert report['normal_padding_errors']==0,report
assert report['min_transparent_margin_final']>=4,report
(BASE/'validation_report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))



