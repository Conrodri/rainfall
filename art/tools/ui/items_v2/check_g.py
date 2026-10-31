"""Lot G: resize, verify, assemble; no painting."""
import sys,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path.insert(0,str(ROOT/'art/tools/vendor'))
from PIL import Image,ImageStat
IDS=['phenix_de_poche','rafale_d_acier','coeur_du_chronomancien','couronne_d_echo','nova_infinie','armure_du_colosse']
BASE=ROOT/'art/renders/items_v2';DEST=ROOT/'game/assets/sprites/icons/items'
def finalize(ident):
    im=Image.open(BASE/'raw'/(ident+'.png')).convert('RGBA').resize((256,256),Image.Resampling.LANCZOS)
    out=im.convert('RGB').quantize(colors=128,dither=Image.Dither.NONE).convert('RGBA');out.putalpha(im.getchannel('A'));out.save(DEST/(ident+'.png'),optimize=True)
    for p in (BASE/'raw').glob(ident+'_e*.png'):p.unlink()
def check(chosen):
    sheet=Image.new('RGB',(608,256*len(chosen)),'#20242c');seen=set();sizes=[];margins=[];contrasts=[]
    for row,ident in enumerate(chosen):
        p=DEST/(ident+'.png');im=Image.open(p);assert im.mode=='RGBA' and im.size==(256,256),ident+' format'
        alpha=im.getchannel('A');box=alpha.getbbox();assert box,ident+' empty'
        margin=min(box[0],box[1],256-box[2],256-box[3]);assert margin>=12,ident+' margin '+str(box)
        assert p.stat().st_size<=60*1024,ident+' weight'
        assert alpha.histogram()[255]>300,ident+' silhouette'
        assert not list(DEST.glob(ident+'_e*.png')) and not list(DEST.glob(ident+'_n*.png')),ident+' forbidden maps'
        digest=hashlib.sha256(im.tobytes()).hexdigest();assert digest not in seen,ident+' duplicate';seen.add(digest)
        small=im.resize((48,48),Image.Resampling.LANCZOS);mask=small.getchannel('A')
        contrast=ImageStat.Stat(small.convert('L'),mask).stddev[0];assert contrast>12,ident+' contrast 48'
        opaque=mask.point(lambda v:255 if v>=200 else 0)
        assert ImageStat.Stat(small.convert('L'),opaque).mean[0]>65,ident+' dark at 48'
        for col,img in enumerate([Image.open(BASE/'before'/p.name).convert('RGBA'),im]):
            sheet.paste(img,(col*304,row*256),img);thumb=img.resize((48,48),Image.Resampling.LANCZOS);sheet.paste(thumb,(col*304+256,row*256+104),thumb)
        sizes.append(p.stat().st_size);margins.append(margin);contrasts.append(round(contrast,1))
    sheet.save(BASE/'lotG_before_after.png',optimize=True)
    print('PASS '+str(len(chosen))+'/6; 256x256 RGBA; margin min='+str(min(margins))+' px; bytes max='+str(max(sizes))+'; contrast48 min='+str(min(contrasts))+'; alpha; distinct; no _e/_n')
if __name__=='__main__':
    if sys.argv[1:2]==['--finalize']:finalize(sys.argv[2])
    else:check(sys.argv[1:] or IDS)


