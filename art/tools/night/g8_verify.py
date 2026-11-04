"""G8 contractual checks and one before/after contact sheet."""
import sys,json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
from g8_build import ROOT,HERE,NAMES,SPR,BEFORE
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel

def lab(a):
    c=a[...,:3]/255.; c=np.where(c<=.04045,c/12.92,((c+.055)/1.055)**2.4)
    y=c@np.array([.2126,.7152,.0722])
    return 116*np.where(y>.008856,np.cbrt(y),7.787*y+16/116)-16

def main():
    protected=json.loads((HERE/'_g8_protected.json').read_text())
    report={}; pairs=[]
    ground=Image.open(ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png').convert('RGBA')
    ga=np.array(ground); gl=lab(ga)[ga[:,:,3]>240]
    for name in NAMES:
        folder=SPR/name; results=[]; all_l=[]; greens=0; count=0
        assert not list(folder.glob('*_n.png'))
        for file,digest in protected[name].items():
            assert hashlib.sha256((folder/file).read_bytes()).hexdigest()==digest,(name,file)
        tres=(folder/(name+'.tres')).read_text()
        assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
        for p in sorted(folder.glob('*.png')):
            if p.stem.endswith('_e'):continue
            a=np.array(Image.open(p).convert('RGBA')); b=np.array(Image.open(BEFORE/name/p.name).convert('RGBA'))
            assert a.shape==b.shape,(name,p.name,'size')
            mask=a[:,:,3]>128; old=b[:,:,3]>128
            iou=float((mask&old).sum()/max(1,(mask|old).sum()))
            assert iou>.97,(name,p.name,'snapshot IoU',iou)
            # Historical N2E archive predates v2 dimensions; G8's immutable snapshot
            # is the contractual before image for this material-only replacement.
            saved_game,saved_archive=cel.GAME_SPRITES,cel.ARCHIVE
            cel.GAME_SPRITES,cel.ARCHIVE=SPR,BEFORE
            try:check=cel.check_sheet(name+'/'+p.name,normals=False,emission=False)
            finally:cel.GAME_SPRITES,cel.ARCHIVE=saved_game,saved_archive
            rgb=a[:,:,:3].astype(float); L=lab(a)
            # Ink/creases and antialiasing excluded; all opaque body surface retained.
            body=(a[:,:,3]>240)&(L>30)&~((rgb[:,:,2]>rgb[:,:,1]*1.1)&(rgb[:,:,2]>rgb[:,:,0]*1.1))
            all_l.extend(L[body].tolist())
            greens+=int((mask&(rgb[:,:,1]>rgb[:,:,0]+2)&(rgb[:,:,1]>rgb[:,:,2]+2)).sum());count+=int(mask.sum())
            ep=p.with_stem(p.stem+'_e'); e=np.array(Image.open(ep).convert('RGBA'))
            assert e.shape[:2]==((a.shape[0]+1)//2,(a.shape[1]+1)//2)
            em=(e[:,:,:3].max(2)>8)&(e[:,:,3]>8)
            assert em.any(),(name,p.name,'empty emission')
            assert np.all(e[:,:,:3][em,2]>=e[:,:,:3][em,1]),(name,'emission hue')
            # Animation frame distinctness from the immutable AtlasTexture grid.
            sizes={'swarm_tier1_moss':(64,56),'shooter_tier2_moss':(88,104),'leaper_tier2_moss':(96,96),'brute_tier3_moss':(128,136)}
            w,h=sizes[name]; cols=a.shape[1]//w; rows=a.shape[0]//h
            distinct=[len({a[r*h:(r+1)*h,f*w:(f+1)*w].tobytes() for f in range(cols)}) for r in range(rows)]
            assert min(distinct)>1,(name,p.name,'identical frames')
            historical=cel.ARCHIVE/'monsters'/name/p.name
            historical_size=list(Image.open(historical).size) if historical.exists() else None
            results.append({'sheet':p.name,'snapshot_iou':iou,'cel_check':check,'historical_archive_size':historical_size,'size':[a.shape[1],a.shape[0]],'distinct_min':min(distinct)})
        assert greens==0,(name,'green pixels',greens)
        vals=np.array(all_l); assert vals.mean()>=60,(name,'body L*',float(vals.mean()))
        report[name]={'body_L_mean':float(vals.mean()),'body_L_p10':float(np.percentile(vals,10)),'green_pixels':greens,'sheets':results}
        w,h=sizes[name]
        pairs.append([Image.open(base/name/'run.png').convert('RGBA').crop((0,2*h,w,3*h)) for base in (BEFORE,SPR)])
    canvas=Image.new('RGBA',(768,560),(38,32,30,255))
    for row,pair in enumerate(pairs):
        for col,im in enumerate(pair):
            x=col*384;y=row*140
            tile=ground.copy();tile.thumbnail((370,136));canvas.alpha_composite(tile,(x+(384-tile.width)//2,y+(140-tile.height)//2))
            im.thumbnail((240,132));canvas.alpha_composite(im,(x+(384-im.width)//2,y+136-im.height))
    out=ROOT/'art/renders/grotte/g8_avant_apres.png';out.parent.mkdir(parents=True,exist_ok=True);canvas.save(out)
    report['ground_L_mean']=float(gl.mean()); report['ground_L_p10_p90']=np.percentile(gl,[10,90]).tolist()
    report['body_measure']='Opaque pixels alpha>240, L*>30, violet accents excluded; ink retained separately in diffuse.'
    report['archive_note']='cel.archive_folder preserved historical N2E archive; v2 dimensions differ. Contractual IoU measured against immutable art/blender/cel/g8/before snapshot.'
    (HERE/'_g8_verification.json').write_text(json.dumps(report,indent=2))
    print('PASS G8',json.dumps({k:round(v['body_L_mean'],2) for k,v in report.items() if isinstance(v,dict)}),'ground',round(gl.mean(),2))

if __name__=='__main__':main()
