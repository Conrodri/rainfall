"""Sprite finish: 4px tinted outline at 384, soft orange ember halo."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent/'vendor'))
from PIL import Image, ImageFilter, ImageChops

def finish(path):
    im=Image.open(path).convert('RGBA'); alpha=im.getchannel('A')
    mask=Image.new('L',im.size)
    mask.putdata([int(a*.40) if r>200 and g>75 and r>g*1.12 and b<180 else 0 for r,g,b,a in im.getdata()])
    glow=Image.new('RGBA',im.size,(255,122,31,0)); glow.putalpha(mask.filter(ImageFilter.GaussianBlur(5)))
    edge=Image.new('RGBA',im.size,(26,22,32,0)); edge.putalpha(alpha.filter(ImageFilter.MaxFilter(9)))
    out=Image.alpha_composite(glow,edge);out=Image.alpha_composite(out,im);out.save(path)

if __name__=='__main__':
    for arg in sys.argv[1:]: finish(Path(arg))
