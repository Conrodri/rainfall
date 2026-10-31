"""Resize, assemble and verify only: no asset painting."""
import sys,json,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
IDS=['eclair_en_bouteille','de_pipe','moisson','lentille_aiguisee']
BASE=ROOT/'art/renders/items_v2';DEST=ROOT/'game/assets/sprites/icons/items'

def finalize(ident):
    raw=BASE/'raw'/(ident+'.png')
    Image.open(raw).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(DEST/raw.name,optimize=True)
    for folder in [DEST,BASE/'raw']:
        for p in folder.glob(ident+'_e*.png'):p.unlink()

def check():
    report=[];seen=set();sheet=Image.new('RGB',(608,1024),'#20242c')
    for row,ident in enumerate(IDS):
        p=DEST/(ident+'.png');im=Image.open(p);a=im.getchannel('A');box=a.getbbox()
        assert im.size==(256,256) and im.mode=='RGBA',ident+' format'
        assert box and min(box[0],box[1],256-box[2],256-box[3])>=12,ident+' margin '+str(box)
        assert all(a.getpixel(pt)==0 for pt in [(0,0),(255,0),(0,255),(255,255)]),ident+' corners'
        assert p.stat().st_size<=60*1024,ident+' weight'
        assert a.histogram()[255]>300,ident+' empty silhouette'
        lum=im.convert('L');stats=ImageStat.Stat(lum,a);assert stats.stddev[0]>12,ident+' contrast'
        digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in seen;seen.add(digest)
        if ident in {'eclair_en_bouteille','moisson'}:
            assert 218<=max(box[2]-box[0],box[3]-box[1])<=232,ident+' fill '+str(box)
            assert not list(DEST.glob(ident+'_e*.png')),ident+' emission'
            assert not list(DEST.glob(ident+'_n*.png')),ident+' normal'
            small=im.resize((48,48),Image.Resampling.LANCZOS)
            assert ImageStat.Stat(small.convert('L'),small.getchannel('A')).stddev[0]>12,ident+' contrast 48px'
        for col,img in enumerate([Image.open(BASE/'before'/p.name).convert('RGBA'),im]):
            sheet.paste(img,(col*304,row*256),img)
            small=img.resize((48,48),Image.Resampling.LANCZOS);sheet.paste(small,(col*304+256,row*256+104),small)
        report.append(dict(id=ident,bbox=box,bytes=p.stat().st_size,contrast=round(stats.stddev[0],1)))
    sheet.save(BASE/'lotA_before_after.png',optimize=True)
    (BASE/'validation_a.json').write_text(json.dumps(report,indent=2))
    print('PASS 4/4; 256x256 RGBA; margin >=12; <=60 KiB; alpha; contrast; distinct; retouches sans _e ni _n')
if __name__=='__main__':
    if sys.argv[1:2]==['--finalize']:finalize(sys.argv[2])
    else:check()
