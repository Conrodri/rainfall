"""Lot E: resize, inspect and assemble only; no painting."""
import sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
IDS=['morsure_vorace','tonique_vital','orbe_de_veille','sang_chaud','marque_du_chasseur','carquois_affute','pointe_perforante','aimant_d_ame']
BASE=ROOT/'art/renders/items_v2';DEST=ROOT/'game/assets/sprites/icons/items'

def finalize(ident):
    assert ident in IDS
    raw=BASE/'raw'/(ident+'.png')
    Image.open(raw).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(DEST/raw.name,optimize=True)
    for p in (BASE/'raw').glob(ident+'_e*.png'):p.unlink()

def check(chosen):
    assert chosen and set(chosen)<=set(IDS)
    sheet=Image.new('RGB',(608,256*len(chosen)),'#20242c');seen=set();report=[];dark=[]
    for row,ident in enumerate(chosen):
        p=DEST/(ident+'.png');im=Image.open(p);a=im.getchannel('A');box=a.getbbox()
        assert im.size==(256,256) and im.mode=='RGBA',ident+' format'
        margin=min(box[0],box[1],256-box[2],256-box[3]) if box else -1
        assert margin>=12,ident+' margin '+str(box)
        assert p.stat().st_size<=60*1024,ident+' bytes'
        assert a.histogram()[255]>300,ident+' empty'
        digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in seen,ident+' duplicate';seen.add(digest)
        small=im.resize((48,48),Image.Resampling.LANCZOS);sa=small.getchannel('A')
        stats=ImageStat.Stat(small.convert('L'),sa)
        assert stats.stddev[0]>12,ident+' contrast 48 '+str(stats.stddev[0])
        if stats.mean[0]<=65:dark.append(ident+' dark 48 '+str(round(stats.mean[0],1)))
        for suffix in ['_e','_n']:assert not list(DEST.glob(ident+suffix+'*.png')),ident+suffix
        for col,img in enumerate([Image.open(BASE/'before'/p.name).convert('RGBA'),im]):
            sheet.paste(img,(col*304,row*256),img)
            sm=img.resize((48,48),Image.Resampling.LANCZOS);sheet.paste(sm,(col*304+256,row*256+104),sm)
        report.append((margin,p.stat().st_size,round(stats.stddev[0],1)))
    sheet.save(BASE/'lotE_before_after.png',optimize=True)
    assert not dark,'; '.join(dark)
    print('PASS '+str(len(chosen))+'/'+str(len(chosen))+'; 256x256 RGBA; margin >=12; <=60 KiB; alpha; distinct; contrast 48; no _e/_n; '+str(report))
if __name__=='__main__':
    if sys.argv[1:2]==['--finalize']:finalize(sys.argv[2])
    else:check(sys.argv[1:] or IDS)
