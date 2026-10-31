"""Lot C: resize, assembly, measurements only; no painting."""
import sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
IDS=['etincelle','flocon','fiole_verte','pavois_fele','coeur_de_mousse','piece_porte_bonheur','eclat_d_experience','plume_d_empenne']
BASE=ROOT/'art/renders/items_v2';DEST=ROOT/'game/assets/sprites/icons/items'

def finalize(ident):
    assert ident in IDS
    raw=BASE/'raw'/(ident+'.png')
    Image.open(raw).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(DEST/raw.name,optimize=True)
    for p in (BASE/'raw').glob(ident+'_e*.png'):p.unlink()

def check(chosen):
    assert chosen and not set(chosen)-set(IDS)
    seen=set();sheet=Image.new('RGB',(608,256*len(chosen)),'#20242c');sizes=[];margins=[];contrasts=[];deltas=[]
    for row,ident in enumerate(chosen):
        p=DEST/(ident+'.png');im=Image.open(p);a=im.getchannel('A');box=a.getbbox()
        assert im.size==(256,256) and im.mode=='RGBA',ident+' format'
        margin=min(box[0],box[1],256-box[2],256-box[3]) if box else -1
        assert margin>=12,ident+' margin '+str(box)
        assert all(a.getpixel(pt)==0 for pt in [(0,0),(255,0),(0,255),(255,255)]),ident+' corners'
        assert p.stat().st_size<=60*1024,ident+' weight'
        assert a.histogram()[255]>300,ident+' empty'
        assert not list(DEST.glob(ident+'_e*.png')) and not list(DEST.glob(ident+'_n*.png')),ident+' auxiliary map'
        digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in seen;seen.add(digest)
        old=Image.open(BASE/'before'/p.name).convert('RGBA')
        assert hashlib.sha256(old.tobytes()).hexdigest()!=digest,ident+' unchanged'
        small=im.resize((48,48),Image.Resampling.LANCZOS);mask=small.getchannel('A')
        stats=ImageStat.Stat(small.convert('L'),mask)
        assert stats.stddev[0]>12,ident+' contrast 48px'
        rgb=small.convert('RGB')
        opaque=[rgb.getpixel((x,y)) for y in range(48) for x in range(48) if mask.getpixel((x,y))>=224]
        assert opaque,ident+' empty at 48px'
        delta=sum(abs(.2126*r+.7152*g+.0722*b-35.8) for r,g,b in opaque)/len(opaque)
        assert delta>25,ident+' dark background contrast'
        for col,img in enumerate([old,im]):
            sheet.paste(img,(col*304,row*256),img)
            tiny=img.resize((48,48),Image.Resampling.LANCZOS);sheet.paste(tiny,(col*304+256,row*256+104),tiny)
        sizes.append(p.stat().st_size);margins.append(margin);contrasts.append(stats.stddev[0]);deltas.append(delta)
    sheet.save(BASE/'lotC_before_after.png',optimize=True)
    print('PASS '+str(len(chosen))+'/8; 256x256 RGBA; margin min='+str(min(margins))+' px; max='+str(max(sizes))+' bytes; contrast48 min='+str(round(min(contrasts),1))+'; background delta min='+str(round(min(deltas),1))+'; alpha/distinct/changed; no _e/_n')

if __name__=='__main__':
    if sys.argv[1:2]==['--finalize']:finalize(sys.argv[2])
    else:check(sys.argv[1:] or IDS)
