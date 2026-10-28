"""Crypt albedo correction in Blender image space; exact sheet geometry retained."""
import sys, json, shutil, hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/night'))
from cel_minis_b_build import sha
NAMES=('ossuary_bearer','blind_swarm','salt_golem','blind_lamplighter','sarcophagus_crab')
ASSETS=ROOT/'game/assets/sprites/bosses/mini'
WORK=ROOT/'art/blender/cel/crypt_albedo'
def render():
    import bpy, numpy as np
    bpy.context.scene.render.engine='BLENDER_EEVEE'
    for name in NAMES:
        folder=ASSETS/name; backup=WORK/'before'/name
        if not backup.exists(): shutil.copytree(folder,backup)
        def read(p):
            im=bpy.data.images.load(str(p),check_existing=False)
            a=np.empty(im.size[0]*im.size[1]*4,dtype=np.float32);im.pixels.foreach_get(a)
            return im,a.reshape(-1,4)
        def to_srgb(x): return np.where(x<=.0031308,12.92*x,1.055*np.maximum(x,0)**(1/2.4)-.055)
        def linear(x): return np.where(x<=.04045,x/12.92,((x+.055)/1.055)**2.4)
        def recolor(a,k):
            rgb=a[:,:3];y=rgb@np.array([.2126,.7152,.0722])
            cold=rgb*.35+y[:,None]*np.array([.92,1.01,1.12])*.65
            target=k*y/(1+.8*y)+.012*np.exp(-y/.09)
            return np.clip(cold*(target/np.maximum(cold@np.array([.2126,.7152,.0722]),1e-8))[:,None],0,1)
        im,a=read(backup/'idle.png');mask=a[:,3]>.5
        lo,hi=0.,2.
        for _ in range(24):
            mid=(lo+hi)/2
            if (recolor(a,mid)[mask]@np.array([.2126,.7152,.0722])).mean()<.325:lo=mid
            else:hi=mid
        k=(lo+hi)/2;bpy.data.images.remove(im)
        count=0
        for p in sorted(backup.glob('*.png')):
            if p.stem.endswith(('_e','_n','_shadow')):continue
            im,a=read(p);a[:,:3]=recolor(a,k);im.pixels.foreach_set(a.ravel());im.filepath_raw=str(folder/p.name);im.file_format='PNG';im.save();bpy.data.images.remove(im);count+=1
        print('PASS',name,count,'sheets',flush=True)
if __name__=='__main__':render()
