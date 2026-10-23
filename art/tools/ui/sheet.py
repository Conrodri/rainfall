"""Planche de contrôle générique : sheet.py out.png bg cell file1 file2 ... (Pillow, assemblage seulement)."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image
out,cell=sys.argv[1],int(sys.argv[2]); files=sys.argv[3:]
cols=min(len(files),6); rows=(len(files)+cols-1)//cols
W=cell+64+16
sh=Image.new('RGBA',(cols*W,rows*(cell+16)),(40,46,60,255))
for i,f in enumerate(files):
    im=Image.open(f).convert('RGBA'); x,y=(i%cols)*W,(i//cols)*(cell+16)
    a=im.copy(); a.thumbnail((cell,cell)); sh.alpha_composite(a,(x+4,y+4))
    b=im.copy(); b.thumbnail((64,64)); sh.alpha_composite(b,(x+cell+8,y+4))
sh.save(out)
