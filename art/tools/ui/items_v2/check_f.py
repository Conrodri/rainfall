"""Lot F: resizing, assembly and quantitative image checks; no painting."""
import sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
IDS=['chronometre_brise','tempete_de_braises','coeur_de_glace','peste_vivante','oeil_du_predateur','bouclier_reactif','faveur_du_marchand','danseur']
BASE=ROOT/'art/renders/items_v2';DEST=ROOT/'game/assets/sprites/icons/items'
def finalize(ident):
    assert ident in IDS
    Image.open(BASE/'raw'/(ident+'.png')).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS).save(DEST/(ident+'.png'),optimize=True)
    for p in (BASE/'raw').glob(ident+'_e*.png'):p.unlink()
def check(chosen):
    seen=set();sheet=Image.new('RGB',(608,256*len(chosen)),'#20242c');sizes=[];margins=[];contrasts=[]
    for row,ident in enumerate(chosen):
        p=DEST/(ident+'.png');im=Image.open(p);assert im.size==(256,256) and im.mode=='RGBA',ident+' format'
        alpha=im.getchannel('A');box=alpha.getbbox();assert box,ident+' empty'
        margin=min(box[0],box[1],256-box[2],256-box[3]);assert margin>=12,ident+' margin '+str(box)
        assert p.stat().st_size<=60*1024,ident+' weight'
        assert alpha.histogram()[255]>300,ident+' alpha'
        assert not list(DEST.glob(ident+'_e*.png')) and not list(DEST.glob(ident+'_n*.png')),ident+' auxiliary maps'
        digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in seen,ident+' duplicate';seen.add(digest)
        small=im.resize((48,48),Image.Resampling.LANCZOS);a=small.getchannel('A');gray=small.convert('L');stats=ImageStat.Stat(gray,a)
        assert stats.stddev[0]>12,ident+' local contrast'
        bg=Image.new('RGBA',(48,48),'#20242c');bg.alpha_composite(small)
        values=[v for v,al in zip(bg.convert('L').tobytes(),a.tobytes()) if al>=180]
        assert values and sum(v>64 for v in values)/len(values)>.30,ident+' dark-background separation'
        for col,img in enumerate([Image.open(BASE/'before'/p.name).convert('RGBA'),im]):
            sheet.paste(img,(col*304,row*256),img);thumb=img.resize((48,48),Image.Resampling.LANCZOS);sheet.paste(thumb,(col*304+256,row*256+104),thumb)
        sizes.append(p.stat().st_size);margins.append(margin);contrasts.append(stats.stddev[0])
    sheet.save(BASE/'lotF_before_after.png',optimize=True)
    print('PASS '+str(len(chosen))+'/8; 256x256 RGBA; margin min='+str(min(margins))+' px; max='+str(max(sizes))+' bytes; contrast48 min='+str(round(min(contrasts),1))+'; distinct; no _e/_n')
if __name__=='__main__':
    if sys.argv[1:2]==['--finalize']:finalize(sys.argv[2])
    else:check(sys.argv[1:] or IDS)
