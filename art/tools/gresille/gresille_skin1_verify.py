"""Check Fulgurite against default sheets; assemble one comparison, no drawing."""
import sys,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
BASE=ROOT/'game/assets/sprites/characters/gresille'
DEST=BASE/'skins/gresille_skin1'
ANIMS={'idle':8,'run':8,'attack':4,'cast':5,'ground':6,'call':8,'death':6}
DIRS=['e','se','s','sw','w','nw','n','ne']
def iou(a,b):
    u=np.logical_or(a,b).sum()
    return float(np.logical_and(a,b).sum()/u) if u else 1.
def main():
    assert {p.name for p in BASE.glob('*.png')}=={p.name for p in DEST.glob('*.png')}
    assert not list(DEST.glob('*_n.png'))
    mins=[1.,1.];count=0;contrast=255
    for anim,n in ANIMS.items():
        for su,tile in [('',192),('_e',96)]:
            with Image.open(BASE/f'{anim}{su}.png') as b,Image.open(DEST/f'{anim}{su}.png') as s:
                assert s.size==b.size==(n*tile,8*tile),(anim,su,s.size,b.size)
                aa=np.array(b.convert('RGBA'));bb=np.array(s.convert('RGBA'))
            assert np.max(bb[:,:,:3])>30,(anim,su,'empty sheet')
            for row in range(8):
                sig=set()
                for frame in range(n):
                    ys=slice(row*tile,(row+1)*tile);xs=slice(frame*tile,(frame+1)*tile)
                    a=aa[ys,xs];b=bb[ys,xs]
                    if su:
                        x=(np.max(a[:,:,:3],axis=2)>30)&(a[:,:,3]>0)
                        y=(np.max(b[:,:,:3],axis=2)>30)&(b[:,:,3]>0)
                        value=iou(x,y);mins[1]=min(mins[1],value)
                        assert value>.90,(anim,row,frame,'accent',value)
                    else:
                        assert np.any(b[:,:,3]),(anim,row,frame,'empty cell')
                        assert b[:,:,3].min()==0
                        x=a[:,:,3]>127;y=b[:,:,3]>127
                        value=iou(x,y);mins[0]=min(mins[0],value)
                        assert value>.95,(anim,row,frame,'alpha',value)
                        lum=b[:,:,:3].max(axis=2)[b[:,:,3]>200]
                        c=int(lum.max())-int(lum.min());contrast=min(contrast,c)
                        assert c>65,(anim,row,frame,'contrast',c)
                        sig.add(hashlib.sha256(b.tobytes()).digest());count+=1
                if not su:assert len(sig)==n,(anim,row,'duplicate frames')
    for su,size in [('',(256,256)),('_e',(128,128))]:
        with Image.open(DEST/f'portrait{su}.png') as im:
            assert im.size==size and im.convert('RGBA').getchannel('A').getbbox()
            assert np.array(im.convert('RGBA').convert('RGB')).max()>30
    expected=(BASE/'gresille.tres').read_text(encoding='utf8').replace('res://assets/sprites/characters/gresille/','res://assets/sprites/characters/gresille/skins/gresille_skin1/')
    actual=(DEST/'gresille_skin1.tres').read_text(encoding='utf8')
    assert actual==expected and 'CanvasTexture' not in actual and 'normal_texture' not in actual
    contact=Image.new('RGBA',(768,576),(90,100,95,255))
    for row,d in enumerate(['se','s','nw']):
        for col,(anim,f) in enumerate([('call',4),('attack',1)]):
            for side,folder in enumerate([BASE,DEST]):
                with Image.open(folder/f'{anim}.png') as im:
                    y=DIRS.index(d)*192
                    fr=im.convert('RGBA').crop((f*192,y,(f+1)*192,y+192))
                    contact.alpha_composite(fr,((side*2+col)*192,row*192))
    contact.convert('RGB').save(ROOT/'art/renders/gresille/skin1_ctrl.png',optimize=True,compress_level=9)
    weight=sum(p.stat().st_size for p in DEST.glob('*.png'))
    print(f'PASS {count} cells; 16 PNG; {weight} bytes; {weight/1e6:.6f} Mo; IoU alpha min {mins[0]:.9f}; accent min {mins[1]:.9f}; contrast min {contrast}')
if __name__=='__main__':main()
