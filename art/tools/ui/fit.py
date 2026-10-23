"""Post-traitement Pillow : réduire/rogner/assembler uniquement. Usage : fit.py jobs.json"""
import sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image

def resize(src,dst,w,h):
    im=Image.open(src).convert('RGBA')
    if im.size!=(w,h):im=im.resize((w,h),Image.Resampling.LANCZOS)
    Path(dst).parent.mkdir(parents=True,exist_ok=True); im.save(dst)

def icon(src,dst,size,margin):
    im=Image.open(src).convert('RGBA'); bb=im.getchannel('A').getbbox()
    if not bb:raise ValueError(src)
    c=im.crop(bb); side=max(c.size); sq=Image.new('RGBA',(side,side)); sq.alpha_composite(c,((side-c.width)//2,(side-c.height)//2))
    inner=size-2*margin; sq=sq.resize((inner,inner),Image.Resampling.LANCZOS)
    out=Image.new('RGBA',(size,size)); out.alpha_composite(sq,(margin,margin))
    Path(dst).parent.mkdir(parents=True,exist_ok=True); out.save(dst)

def fit(src,dst,w,h,margin):
    """Rogne au contenu et inscrit dans w x h (ratio conservé), centré."""
    im=Image.open(src).convert('RGBA'); bb=im.getchannel('A').getbbox(); c=im.crop(bb)
    k=min((w-2*margin)/c.width,(h-2*margin)/c.height); nw,nh=max(1,round(c.width*k)),max(1,round(c.height*k))
    c=c.resize((nw,nh),Image.Resampling.LANCZOS); out=Image.new('RGBA',(w,h)); out.alpha_composite(c,((w-nw)//2,(h-nh)//2))
    Path(dst).parent.mkdir(parents=True,exist_ok=True); out.save(dst)

if __name__=='__main__':
    for j in json.loads(Path(sys.argv[1]).read_text()):
        m=j['mode']
        if m=='resize':resize(j['src'],j['dst'],j['w'],j['h'])
        elif m=='icon':icon(j['src'],j['dst'],j['size'],j['margin'])
        elif m=='fit':fit(j['src'],j['dst'],j['w'],j['h'],j.get('margin',2))
