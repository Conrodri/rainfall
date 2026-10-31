"""Lot D resize, assembly and numeric verification; no painting."""
import sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
IDS=['cristal_de_feu','givre','horloge_arcanique','lame_jumelle','venin_concentre','cape_de_brume','epines','rune_de_portee']
BASE=ROOT/'art/renders/items_v2';DEST=ROOT/'game/assets/sprites/icons/items'
def finalize(ident):
    Image.open(BASE/'raw'/(ident+'.png')).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(DEST/(ident+'.png'),optimize=True)
    for folder in [DEST,BASE/'raw']:
        for p in folder.glob(ident+'_e*.png'):p.unlink()
def check():
    chosen=sys.argv[1:] or IDS;seen=set();sheet=Image.new('RGB',(608,256*len(chosen)),'#20242c');weights=[];margins=[];contrasts=[]
    for row,ident in enumerate(chosen):
        assert ident in IDS
        p=DEST/(ident+'.png');im=Image.open(p);a=im.getchannel('A');box=a.getbbox()
        assert im.size==(256,256) and im.mode=='RGBA',ident+' format'
        assert box,ident+' empty'
        margin=min(box[0],box[1],256-box[2],256-box[3]);assert margin>=12,ident+' margin '+str(box)
        assert p.stat().st_size<=60*1024,ident+' weight'
        assert a.histogram()[255]>300,ident+' silhouette'
        assert all(a.getpixel(pt)==0 for pt in [(0,0),(255,0),(0,255),(255,255)]),ident+' corners'
        digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in seen,ident+' duplicate';seen.add(digest)
        small=im.resize((48,48),Image.Resampling.LANCZOS);stat=ImageStat.Stat(small.convert('L'),small.getchannel('A'))
        assert stat.stddev[0]>12,ident+' contrast 48px'
        assert stat.mean[0]>65,ident+' dark 48px'
        assert not list(DEST.glob(ident+'_e*.png')),ident+' emission'
        assert not list(DEST.glob(ident+'_n*.png')),ident+' normal'
        for col,img in enumerate([Image.open(BASE/'before'/p.name).convert('RGBA'),im]):
            sheet.paste(img,(col*304,row*256),img)
            sm=img.resize((48,48),Image.Resampling.LANCZOS);sheet.paste(sm,(col*304+256,row*256+104),sm)
        weights.append(p.stat().st_size);margins.append(margin);contrasts.append(stat.stddev[0])
    sheet.save(BASE/'lotD_before_after.png',optimize=True)
    print('PASS %d/%d; 256x256 RGBA; margin min %d px; max %d bytes; contrast48 min %.1f; distinct; no _e/_n'%(len(chosen),len(chosen),min(margins),max(weights),min(contrasts)))
if __name__=='__main__':
    if sys.argv[1:2]==['--finalize']:finalize(sys.argv[2])
    else:check()
