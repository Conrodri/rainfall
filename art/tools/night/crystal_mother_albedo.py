"""Crypt albedo method adapted to crystal mother's body sheets only."""
import json, shutil, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
ASSETS=ROOT/'game/assets/sprites/bosses/etage/crystal_mother'
WORK=ROOT/'art/blender/cel/crystal_mother_albedo'
NAMES=['auto','death','idle_p1','idle_p2','idle_p3','spell_a','spell_b','trans_p2','trans_p3','walk_p1','walk_p2','walk_p3']
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def render():
    import bpy, numpy as np
    bpy.context.scene.render.engine='BLENDER_EEVEE'
    backup=WORK/'before'
    if not backup.exists(): shutil.copytree(ASSETS,backup)
    def read(p):
        im=bpy.data.images.load(str(p),check_existing=False)
        im.colorspace_settings.name='Non-Color'
        a=np.empty(im.size[0]*im.size[1]*4,dtype=np.float32)
        im.pixels.foreach_get(a)
        return im,a.reshape(-1,4)
    weights=np.array([.2126,.7152,.0722])
    def recolor(a,k):
        rgb=a[:,:3]; y=rgb@weights
        cold=.35*rgb+.65*y[:,None]*np.array([.78,.98,1.16])
        target=k*y/(1+.8*y)+.006*np.exp(-y/.09)
        return np.clip(cold*(target/np.maximum(cold@weights,1e-8))[:,None],0,1)
    im,a=read(backup/'idle_p1.png'); mask=a[:,3]>.5
    lo,hi=0.,2.
    for _ in range(24):
        mid=(lo+hi)/2
        if (recolor(a,mid)[mask]@weights).mean()<.325: lo=mid
        else: hi=mid
    k=(lo+hi)/2; bpy.data.images.remove(im)
    for name in NAMES:
        im,a=read(backup/(name+'.png')); a[:,:3]=recolor(a,k)
        im.pixels.foreach_set(a.ravel()); im.filepath_raw=str(ASSETS/(name+'.png'))
        im.file_format='PNG'; im.save(); bpy.data.images.remove(im)
    print('PASS Blender body sheets',len(NAMES),flush=True)
def verify():
    import numpy as np
    from PIL import Image
    backup=WORK/'before'; changed=0
    assert sorted(p.name for p in ASSETS.iterdir())==sorted(p.name for p in backup.iterdir())
    for p in ASSETS.iterdir():
        old=backup/p.name
        if p.name not in [n+'.png' for n in NAMES]:
            assert sha(p)==sha(old),str(p)
            continue
        im=Image.open(p).convert('RGBA'); src=Image.open(old).convert('RGBA')
        assert im.size==src.size and np.array_equal(np.asarray(im)[:,:,3],np.asarray(src)[:,:,3]),str(p)
        im.save(p,optimize=True,compress_level=9); changed+=1
    report={}
    for label,folder in [('before',backup),('after',ASSETS)]:
        a=np.asarray(Image.open(folder/'idle_p1.png').convert('RGBA'))/255
        y=(a[:,:,:3]@np.array([.2126,.7152,.0722]))[a[:,:,3]>.5]
        report[label]=[float(y.mean()),*map(float,np.percentile(y,[90,99]))]
    mean,p90,p99=report['after']; assert .25<=mean<=.36 and p90<=.55 and p99<=.75,report
    board=Image.new('RGBA',(942,380),(17,19,22,255))
    for row,name in enumerate(['idle_p1','idle_p3']):
        for col,folder in enumerate([backup,ASSETS]):
            im=Image.open(folder/(name+'.png')).convert('RGBA')
            # First three original 157x190 frames; crop/assemble only.
            tile=im.crop((0,0,471,190))
            board.alpha_composite(tile,(471*col,190*row))
    board.convert('RGB').save(WORK/'contact.png')
    (WORK/'verification.json').write_text(json.dumps(report,indent=2))
    print('PASS',changed,'sheets; names/sizes/alpha/effects/_e/.tres unchanged',report)
if __name__=='__main__':
    import sys
    verify() if '--verify' in sys.argv else render()
