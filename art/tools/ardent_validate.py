import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'vendor'))
from PIL import Image,ImageDraw
base=Path(__file__).resolve().parents[1]/'renders/ardent'
dirs=['e','se','s','sw','w','nw','n','ne']
report={'count':0,'minimum_margin':384,'problems':[]}
for anim in ['idle','run']:
    board=Image.new('RGB',(192*8,192*8),'#28303c')
    draw=ImageDraw.Draw(board)
    for row,d in enumerate(dirs):
        for f in range(8):
            path=base/anim/f'{d}_{f:02d}.png'
            im=Image.open(path)
            if im.size!=(384,384) or im.mode!='RGBA':report['problems'].append(str(path))
            box=im.getchannel('A').point(lambda x:255 if x>=128 else 0).getbbox()
            margin=min(box[0],box[1],384-box[2],384-box[3]);report['minimum_margin']=min(report['minimum_margin'],margin)
            if margin<6:report['problems'].append([str(path),margin])
            small=im.resize((192,192),Image.Resampling.LANCZOS)
            board.paste(small,(f*192,row*192),small)
            draw.text((f*192+5,row*192+5),f'{d} {f:02d}',fill='#d8dce5')
            report['count']+=1
    board.save(base/f'review_{anim}_192.png')
(base/'validation.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report))
