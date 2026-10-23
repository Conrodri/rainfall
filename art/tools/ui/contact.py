"""Planche de contrôle (assemblage Pillow uniquement) : python -I contact.py out.png dossier_ou_png ... [--cols N] [--cell N]."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image, ImageDraw

def sheet(out,paths,cols=6,cell=160,bg=(43,51,64)):
    rows=(len(paths)+cols-1)//cols
    S=Image.new('RGB',(cols*cell,rows*(cell+14)),bg); d=ImageDraw.Draw(S)
    for i,p in enumerate(paths):
        im=Image.open(p).convert('RGBA'); x=(i%cols)*cell; y=(i//cols)*(cell+14)
        big=im.copy(); big.thumbnail((cell-70,cell-4),Image.Resampling.LANCZOS)
        S.paste(big,(x+2,y+2),big)
        sm=im.copy(); sm.thumbnail((64,64),Image.Resampling.LANCZOS)
        S.paste(sm,(x+cell-66,y+2),sm)
        d.text((x+3,y+cell-2),Path(p).stem[:26],fill=(225,225,225))
    S.save(out)

if __name__=='__main__':
    a=sys.argv[1:]; cols=6; cell=160
    if '--cols' in a:
        i=a.index('--cols'); cols=int(a[i+1]); del a[i:i+2]
    if '--cell' in a:
        i=a.index('--cell'); cell=int(a[i+1]); del a[i:i+2]
    paths=[]
    for s in a[1:]:
        p=Path(s); paths+= sorted(p.glob('*.png')) if p.is_dir() else [p]
    sheet(a[0],paths,cols,cell)
