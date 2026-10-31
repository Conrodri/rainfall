"""Lot B: resize, assemble and verify; no painting."""
import sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
IDS=['sablier_fele','antidote','botte_rapiecee','pierre_a_aiguiser','bague_de_vigueur','amulette_de_cuir','aimant_de_poche','sifflet_de_chasse']
BASE=ROOT/'art/renders/items_v2';DEST=ROOT/'game/assets/sprites/icons/items'
def finalize(ident):
    assert ident in IDS
    Image.open(BASE/'raw'/(ident+'.png')).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(DEST/(ident+'.png'),optimize=True)
    for p in (BASE/'raw').glob(ident+'_e*.png'):p.unlink()
def check(chosen):
    sheet=Image.new('RGB',(608,256*len(chosen)),'#20242c');seen=set();margins=[];sizes=[];contrasts=[]
    for row,ident in enumerate(chosen):
        assert ident in IDS
        p=DEST/(ident+'.png');im=Image.open(p);assert im.mode=='RGBA' and im.size==(256,256),ident+' format'
        a=im.getchannel('A');b=a.getbbox();assert b,ident+' empty'
        margin=min(b[0],b[1],256-b[2],256-b[3]);assert margin>=12,ident+' margin '+str(b)
        assert p.stat().st_size<=60*1024,ident+' weight'
        assert a.histogram()[255]>300,ident+' alpha'
        assert not list(DEST.glob(ident+'_e*.png')) and not list(DEST.glob(ident+'_n*.png')),ident+' extra maps'
        digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in seen,ident+' duplicate';seen.add(digest)
        small=im.resize((48,48),Image.Resampling.LANCZOS);stats=ImageStat.Stat(small.convert('L'),small.getchannel('A'))
        assert stats.stddev[0]>12 and stats.mean[0]>65,ident+' contrast 48 '+str(stats.mean[0])
        margins.append(margin);sizes.append(p.stat().st_size);contrasts.append(stats.stddev[0])
        for col,img in enumerate([Image.open(BASE/'before'/p.name).convert('RGBA'),im]):
            sheet.paste(img,(col*304,row*256),img)
            tiny=img.resize((48,48),Image.Resampling.LANCZOS);sheet.paste(tiny,(col*304+256,row*256+104),tiny)
    sheet.save(BASE/'lotB_before_after.png',optimize=True)
    print('PASS '+str(len(chosen))+'/8; 256x256 RGBA; marge min '+str(min(margins))+' px; max '+str(max(sizes))+' octets; contraste 48 min '+str(round(min(contrasts),1))+'; alpha; distincts; sans _e/_n')
if __name__=='__main__':
    if sys.argv[1:2]==['--finalize']:finalize(sys.argv[2])
    else:check(sys.argv[1:] or IDS)
