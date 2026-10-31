from pathlib import Path
import json,hashlib,sys
from PIL import Image
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/terrain/fog_forest/iso'
NAMES=['cliff_sw','cliff_se','cliff_corner_s','cliff_corner_w','cliff_corner_e','void_1024','water_deep','water_shallow']
STATE=Path(__file__).with_name('_g_g2b_retouch_contract.json')
BOARD=ROOT/'art/renders/grotte/g2b_avant_apres.png'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def protected():return {p.name:digest(p) for p in OUT.iterdir() if p.is_file() and p.name not in {n+'.png' for n in NAMES}}
def paste(board,name,i,after):
    im=Image.open(OUT/(name+'.png')).convert('RGBA');im.thumbnail((124,300))
    board.paste(im,(i%4*256+int(after)*128+(128-im.width)//2,i//4*320+(320-im.height)//2),im)
if '--before' in sys.argv:
    state={'protected':protected(),'sizes':{},'pivots':{}}
    board=Image.new('RGB',(1024,640),(18,14,12))
    for i,n in enumerate(NAMES):
        state['sizes'][n]=list(Image.open(OUT/(n+'.png')).size)
        p=ROOT/'art/blender/terrain'/('g_g2b_'+n+'_check.json')
        state['pivots'][n]=json.loads(p.read_text())['pivot']
        paste(board,n,i,False)
    STATE.write_text(json.dumps(state));board.save(BOARD)
    print('PASS baseline: 8 diffuse; protected hashes captured')
else:
    state=json.loads(STATE.read_text());assert protected()==state['protected'],'protected files changed'
    board=Image.open(BOARD).convert('RGB');report={}
    hashes=[]
    for i,n in enumerate(NAMES):
        p=OUT/(n+'.png');a=np.asarray(Image.open(p).convert('RGBA'))
        assert list(Image.open(p).size)==state['sizes'][n],n+' dimensions'
        assert a[:,:,3].max()==255 and (n=='void_1024' or a[:,:,3].min()==0),n+' alpha'
        rgb=a[:,:,:3][a[:,:,3]>240];assert rgb.max()-rgb.min()>3,n+' contrast'
        assert not (OUT/(n+'_n.png')).exists(),n+' normal'
        for e in [OUT/(n+'_e.png')]:
            if e.exists():
                em=Image.open(e);w,h=Image.open(p).size;assert em.size in ((w,h),((w+1)//2,(h+1)//2))
                ea=np.asarray(em.convert('RGBA'));assert np.max(ea[:,:,:3]*(ea[:,:,3:4]/255))>0
        pivot=json.loads((ROOT/'art/blender/terrain'/('g_g2b_'+n+'_check.json')).read_text())['pivot']
        assert max(abs(x-y) for x,y in zip(pivot,state['pivots'][n]))<.01,n+' pivot'
        hashes.append(digest(p));paste(board,n,i,True)
        if n.startswith(('void','water')):
            mean=rgb.mean(0);luma=float(mean@np.array([.2126,.7152,.0722]))
            report[n]={'mean_rgb':mean.round(3).tolist(),'mean_luminance_255':round(luma,3)}
    assert len(set(hashes))==8,'distinct assets'
    assert report['void_1024']['mean_luminance_255']<21
    assert report['water_deep']['mean_rgb'][1]<65
    assert json.loads((ROOT/'art/blender/terrain/g_g2b_geometry.json').read_text())['status']=='PASS'
    board.save(BOARD,optimize=True)
    Path(__file__).with_name('_g_g2b_retouch_results.json').write_text(json.dumps(report,indent=2))
    print('PASS 8: dimensions alpha contrast distinct pivots 2.5u; protected files unchanged; no normals')
    for n,r in report.items():print(n+' RGB '+str(r['mean_rgb'])+' Y '+str(r['mean_luminance_255']))
