"""G10 sequential existing cel pipelines, contract-preserving delivery and audit."""
from pathlib import Path
import sys,json,shutil,subprocess,hashlib
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel')]
import cel_style as cel
def emission(a):
    v=a[...,:3].max(2).astype(float)/255
    t=np.clip((v-.72)/.28,0,1)[...,None]
    out=a.copy()
    out[...,:3]=np.rint(((1-t)*np.array([194,123,255])+t*np.array([230,200,255]))*v[...,None]).astype(np.uint8)
    return out
WORK=ROOT/'art/blender/cel/g10'
NAMES=('bramble_queen','mist_wolf','mist_wolf_cub','moss_mantis')
SPR=ROOT/'game/assets/sprites/bosses/mini'
def arr(p): return np.array(Image.open(p).convert('RGBA'))
def light(a):
    v=a[...,:3]/255.; v=np.where(v<=.04045,v/12.92,((v+.055)/1.055)**2.4)
    y=v@np.array([.2126,.7152,.0722]); return np.where(y>.008856,116*np.cbrt(y)-16,903.3*y)
def baseline():
    WORK.mkdir(parents=True,exist_ok=True)
    for n in NAMES:
        cel.archive_folder('bosses/mini/'+n)
        b=WORK/'before'/n
        if not b.exists(): shutil.copytree(SPR/n,b)
def render():
    exe=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
    for tag in ('a','b'):
        if '--only-b' in sys.argv and tag=='a': continue
        with (WORK/f'render_{tag}.log').open('w') as log:
            subprocess.run([exe,'--background','--python-exit-code','1','--python',str(HERE/f'cel_minis_{tag}_build.py'),'--','--render','--g10'],stdout=log,stderr=subprocess.STDOUT,check=True)
def deliver():
    for n in NAMES:
        tag='a' if n=='bramble_queen' else 'b'
        specs=json.loads((HERE/f'_cel_minis_{tag}_verification.json').read_text())['crops']
        for p in (WORK/'before'/n).glob('*.png'):
            if p.stem.endswith('_n'): raise AssertionError(p)
            old=arr(p)
            if p.stem.endswith('_e'): out=emission(old)
            else:
                sp=specs['bosses/mini/'+n+'/'+p.name]; cols,rows=sp['grid']; x,y,x1,y1=sp['box']; cw,ch=x1-x,y1-y
                source=arr(WORK/f'minis_{tag}'/n/p.name)
                out=np.zeros_like(old)
                for r in range(rows):
                    for f in range(cols): out[r*ch:(r+1)*ch,f*cw:(f+1)*cw]=source[r*170+y:r*170+y1,f*170+x:f*170+x1]
                assert out.shape==old.shape
                # Preserve subtle approved pose-to-pose cel shading differences.
                detail=.94+.12*old[...,:3].max(2)/255.
                out[...,:3]=np.rint(np.clip(out[...,:3]*detail[...,None],0,255)).astype(np.uint8)
                out[...,1]=np.minimum(out[...,1],out[...,0])
                out[...,3]=old[...,3]
            Image.fromarray(out).save(SPR/n/p.name,compress_level=9)
def verify():
    report={'method':'Blender Eevee creature cel; material overrides; original accent mask tinted; original cel shading modulation retained; chroma +10%' ,'assets':{}}
    ground=arr(ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png')
    report['ground_L']=float(np.median(light(ground)[ground[...,3]>128]))
    contact=[]
    for n in NAMES:
        vals=[];green=0;distinct=[];count=0;archive_ious=[];archive_e_ious=[]
        tag='a' if n=='bramble_queen' else 'b'; specs=json.loads((HERE/f'_cel_minis_{tag}_verification.json').read_text())['crops']
        before=WORK/'before'/n
        assert {p.name for p in before.iterdir()}=={p.name for p in (SPR/n).iterdir()}
        for p in before.iterdir():
            q=SPR/n/p.name
            if p.suffix!='.png': assert p.read_bytes()==q.read_bytes(); continue
            a,b=arr(p),arr(q); assert a.shape==b.shape; assert np.array_equal(a[...,3],b[...,3]); count+=1
            if p.stem.endswith('_e'):
                am=(a[...,:3].max(2)>2)&(a[...,3]>0); bm=(b[...,:3].max(2)>2)&(b[...,3]>0)
                assert np.array_equal(am,bm); assert bm.any()
                sp=specs['bosses/mini/'+n+'/'+p.stem[:-2]+'.png']; cols,rows=sp['grid']; x,y,x1,y1=sp['box']
                ae=arr(cel.ARCHIVE/'bosses/mini'/n/p.name); ratio=ae.shape[1]/(cols*170)
                ac=[]
                for rr in range(rows):
                    ac.append(np.concatenate([ae[round((rr*170+y)*ratio):round((rr*170+y1)*ratio),round((ff*170+x)*ratio):round((ff*170+x1)*ratio)] for ff in range(cols)],axis=1))
                ac=np.concatenate(ac,axis=0)
                ac=np.array(Image.fromarray(ac).resize((b.shape[1],b.shape[0]),Image.Resampling.NEAREST))
                am=(ac[...,:3].max(2)>2)&(ac[...,3]>0)
                archive_e_ious.append(float((am&bm).sum()/max(1,(am|bm).sum())))
                diff=Image.open(q.with_stem(q.stem[:-2])); assert Image.open(q).size in (diff.size,((diff.width+1)//2,(diff.height+1)//2))
            else:
                old_game,old_archive=cel.GAME_SPRITES,cel.ARCHIVE
                try:
                    cel.GAME_SPRITES=SPR;cel.ARCHIVE=WORK/'before'
                    cel.check_sheet(n+'/'+p.name,normals=False)
                finally: cel.GAME_SPRITES,cel.ARCHIVE=old_game,old_archive
                rgb=b[...,:3].astype(int); mask=b[...,3]>128
                green+=int(((rgb[...,1]>rgb[...,0])&(rgb[...,1]>rgb[...,2])&mask).sum())
                # Body excludes ink and dark slate; all cel body tones measured separately.
                body=mask&(rgb.max(2)>75)&(rgb[...,0]>=rgb[...,2])
                vals.extend(light(b)[body][::10].tolist())
                sp=specs['bosses/mini/'+n+'/'+p.name]; cols,rows=sp['grid']; h,w=b.shape[:2]; cw,ch=w//cols,h//rows
                archived=arr(cel.ARCHIVE/'bosses/mini'/n/p.name)
                assert archived.shape[:2]==(rows*170,cols*170)
                rebuilt=np.zeros(archived.shape[:2],bool); x,y,x1,y1=sp['box']
                for rr in range(rows):
                    for ff in range(cols): rebuilt[rr*170+y:rr*170+y1,ff*170+x:ff*170+x1]=b[rr*ch:(rr+1)*ch,ff*cw:(ff+1)*cw,3]>128
                am=archived[...,3]>128
                archive_ious.append(float((am&rebuilt).sum()/max(1,(am|rebuilt).sum())))
                def frames(im): return [hashlib.sha256(im[r*ch:(r+1)*ch,f*cw:(f+1)*cw].tobytes()).hexdigest() for r in range(rows) for f in range(cols)]
                distinct.append([p.stem,len(set(frames(a))),len(set(frames(b)))])
                if len(set(frames(b)))<len(set(frames(a))):
                    fa=frames(a);fb=frames(b)
                    for ii in range(len(fb)):
                        for jj in range(ii):
                            if fb[ii]==fb[jj] and fa[ii]!=fa[jj]:
                                ri,fi=divmod(ii,cols);rj,fj=divmod(jj,cols)
                                aa=a[ri*ch:(ri+1)*ch,fi*cw:(fi+1)*cw].astype(int);ab=a[rj*ch:(rj+1)*ch,fj*cw:(fj+1)*cw].astype(int)
                                assert np.max(np.abs(aa-ab))<=3,(n,p.name,ii,jj,'lost distinct pose')
                if p.stem=='idle':
                    contact.append((Image.fromarray(a[:ch,:cw]),Image.fromarray(b[:ch,:cw])))
        assert green==0
        report['assets'][n]={'png':count,'body_L_median':float(np.median(vals)),'body_L_p10':float(np.percentile(vals,10)),'green_pixels':green,'alpha_iou':1.,'emission_iou':1.,'distinct':distinct,'archive_alpha_iou_min':min(archive_ious),'archive_emission_iou_min':min(archive_e_ious)}
    # Contact sheet: original and delivered first idle frame on the actual ground.
    sheet=Image.new('RGBA',(800,800),(30,25,26,255)); tile=Image.open(ROOT/'game/assets/sprites/terrain/fog_forest/iso/ground_a.png').convert('RGBA'); tile.thumbnail((400,200))
    for r,pair in enumerate(contact):
        for c,im in enumerate(pair):
            sheet.alpha_composite(tile,(c*400,r*200)); im.thumbnail((190,190)); sheet.alpha_composite(im,(c*400+100,r*200+5))
    out=ROOT/'art/renders/grotte/g10_avant_apres.png';out.parent.mkdir(parents=True,exist_ok=True); sheet.convert('RGB').save(out)
    (WORK/'verification.json').write_text(json.dumps(report,indent=2))
    print(json.dumps({n:{k:v for k,v in x.items() if k!='distinct'} for n,x in report['assets'].items()}))
if __name__=='__main__':
    baseline()
    if '--verify' not in sys.argv:
        render();deliver()
    verify()
