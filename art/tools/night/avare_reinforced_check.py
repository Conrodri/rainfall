"""Targeted preflight/validation; Pillow only crops, assembles and checks."""
from pathlib import Path
import sys,json,hashlib,subprocess,shutil
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/renders/feel_sorts2'
BASE=OUT/'avare_reinforced_before'
SPR=ROOT/'game/assets/sprites/characters/avare/effects'
SPECS={'coffre_arc':(192,4,8),'coin_burst':(512,6,1)}
STATE=BASE/'state.json'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def protected():
    paths=[p for p in SPR.rglob('*') if p.is_file() and (p.suffix=='.tres' or p.parent.name not in SPECS)]
    paths += [ROOT/'art/blender/characters'/('avare_'+n+'.blend') for n in ('coffre_arc','coin_burst','ransom_ring')]
    return {str(p.relative_to(ROOT)):digest(p) for p in paths if p.exists()}
def mass(im):return float(np.asarray(im.getchannel('A'),dtype=np.float64).sum()/255)
if '--before' in sys.argv:
    assert not STATE.exists(),'baseline already recorded'
    BASE.mkdir(parents=True,exist_ok=True)
    state={'protected':protected(),'files':{}}
    for name in SPECS:
        for p in (SPR/name).glob('*.png'):
            shutil.copy2(p,BASE/p.name)
            with Image.open(p) as im:size=im.size
            head=subprocess.check_output(['git','show','HEAD:'+p.relative_to(ROOT).as_posix()],cwd=ROOT)
            state['files'][p.name]={'size':size,'before_bytes':p.stat().st_size,'head_bytes':len(head)}
    STATE.write_text(json.dumps(state,indent=2))
    print('PASS baseline saved')
else:
    state=json.loads(STATE.read_text());assert protected()==state['protected'],'protected files changed'
    checks={};board=Image.new('RGBA',(1024,832),(23,27,34,255))
    # Requested AVANT capture included in the sole contact sheet.
    with Image.open(OUT/'before_vfx.png') as old:
        old.thumbnail((1024,160));board.alpha_composite(old.convert('RGBA'),(0,0))
    for i,(name,(cell,frames,rows)) in enumerate(SPECS.items()):
        path=SPR/name/(name+'.png')
        with Image.open(path) as src:im=src.convert('RGBA')
        with Image.open(BASE/path.name) as src:before=src.convert('RGBA')
        assert list(im.size)==state['files'][path.name]['size']
        values=[];ratios=[];thickness=[]
        for row in range(rows):
            tiles=[im.crop((f*cell,row*cell,(f+1)*cell,(row+1)*cell)) for f in range(frames)]
            assert len({hashlib.sha256(x.tobytes()).hexdigest() for x in tiles})==frames
            mm=[mass(x) for x in tiles];values.append(mm)
            ratios.append(mm[0]/mass(before.crop((0,row*cell,cell,(row+1)*cell))))
            assert mm[0]==max(mm),'frame 0 not peak'
            a=np.asarray(tiles[0])[:,:,3]>127
            # Diameter of an inscribed square: conservative visible thickness.
            k=0
            while a.any():
                k+=1;a=a[:-1,:-1]&a[1:,:-1]&a[:-1,1:]&a[1:,1:]
            thickness.append(k)
        assert min(ratios)>=3,(name,ratios)
        assert min(thickness)>=cell*.1,(name,thickness)
        alpha=np.asarray(im)[:,:,3];assert alpha.min()==0 and alpha.max()==255
        rgb=np.asarray(im)[:,:,:3][alpha>127];assert int(rgb.max())-int(rgb.min())>100
        with Image.open(SPR/name/(name+'_e.png')) as e:
            assert e.size==((im.width+1)//2,(im.height+1)//2)
            ea=np.asarray(e.convert('RGBA'),dtype=float);assert (ea[:,:,:3]*ea[:,:,3:]/255).max()>100
        for suffix in ('','_e'):
            p=SPR/name/(name+suffix+'.png');assert p.stat().st_size<=state['files'][p.name]['head_bytes']*1.3,(p.name,p.stat().st_size)
        assert not list((SPR/name).glob('*_n.png'))
        checks[name]={'mass_ratio':ratios,'thickness_px':thickness,'frame_mass':values,
            'bytes':{s:(SPR/name/(name+s+'.png')).stat().st_size for s in ('','_e')}}
        y=172 if i==0 else 400
        for j,f in enumerate((0,1,frames-1)):
            tile=im.crop((f*cell,0,(f+1)*cell,cell));tile.thumbnail((330,400 if i else 220))
            board.alpha_composite(tile,(j*340,y))
        tile=before.crop((0,0,cell,cell));tile.thumbnail((160,160));board.alpha_composite(tile,(856,672))
    board.convert('RGB').save(OUT/'after_vfx_avare.png',optimize=True)
    (OUT/'avare_reinforced_checks.json').write_text(json.dumps(checks,indent=2))
    print('PASS dimensions/alpha/contrast/frames/peak/3x/thickness/emission/budget/protected; '+json.dumps({n:{'ratio_min':round(min(v['mass_ratio']),2),'thickness_min':min(v['thickness_px']),'bytes':v['bytes']} for n,v in checks.items()}))
