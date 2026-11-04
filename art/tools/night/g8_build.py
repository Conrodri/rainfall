"""G8 material parameters; reuses F23 and MB1 render loops."""
import sys,json,hashlib,shutil,colorsys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel')]
NAMES=[n+'_moss' for n in ('swarm_tier1','shooter_tier2','leaper_tier2','brute_tier3')]
SPR=ROOT/'game/assets/sprites/monsters'
BEFORE=ROOT/'art/blender/cel/g8/before'
def linear(rgb):
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)
def materials():
    import bpy,cel_style as cel
    cel.toon_materials('creature')
    accent=linear(tuple(int('C27BFF'[i:i+2],16)/255 for i in (0,2,4)))
    for mat in bpy.data.materials:
        if not mat.use_nodes:continue
        nodes=mat.node_tree.nodes
        ramps=[n for n in nodes if n.name=='CEL tones']
        if ramps:
            grey=any(k in mat.name.lower() for k in ('lichen','pale','stone','tooth'))
            base='8A8478' if grey else ('5A4232' if any(k in mat.name.lower() for k in ('dark','wood','recess')) else '7A5D45')
            h,s,v=colorsys.rgb_to_hsv(*(int(base[i:i+2],16)/255 for i in (0,2,4)))
            # Powdered light surface, three cel values; chroma +10%.
            for el,value in zip(ramps[0].color_ramp.elements,(.90,.95,1.0)):
                el.color=linear(colorsys.hsv_to_rgb(h,min(1,s*1.1),value))
        else:
            for n in nodes:
                if n.type=='EMISSION':n.inputs['Color'].default_value=accent
                if n.type=='OUTPUT_AOV' and max(n.inputs['Color'].default_value[:3])>0:n.inputs['Color'].default_value=accent

def prepare():
    import cel_style as cel
    state={}
    for name in NAMES:
        cel.archive_folder('monsters/'+name)
        dst=BEFORE/name
        if not dst.exists():shutil.copytree(SPR/name,dst)
        state[name]={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (SPR/name).iterdir() if p.suffix in ('.tres','.import','.json')}
    (HERE/'_g8_protected.json').write_text(json.dumps(state))
    print('PASS archives and snapshot')
def render():
    sys.path.insert(0,str(ROOT/'art/tools/monsters/v2'))
    import f1_build as f1, f2_build as f2
    f1.swarm(); f1.shooter(); f2.leaper(); f2.brute()
    finish_emission()
    print('PASS G8 render')
def finish_emission():
    # LANCZOS on transparent emission edges can introduce stray channel values.
    # Keep the rendered intensity/alpha and enforce the single contractual hue.
    import numpy as np
    from PIL import Image
    for name in NAMES:
        for p in (SPR/name).glob('*.png'):
            if p.stem.endswith('_e'):continue
            a=np.array(Image.open(p).convert('RGBA')); rgb=a[:,:,:3].astype(int)
            stray=(a[:,:,3]>128)&(rgb[:,:,1]>rgb[:,:,0]+2)&(rgb[:,:,1]>rgb[:,:,2]+2)
            if stray.any():
                assert int(stray.sum())<32,(p,'unexpected green surface')
                a[:,:,0][stray]=a[:,:,1][stray]
                Image.fromarray(a).save(p,optimize=True)
        for p in (SPR/name).glob('*_e.png'):
            a=np.array(Image.open(p).convert('RGBA'))
            intensity=a[:,:,:3].max(axis=2).astype(float)
            a[:,:,:3]=np.rint(intensity[:,:,None]*np.array([194,123,255])/255).astype('uint8')
            assert np.any((a[:,:,:3].max(2)>0)&(a[:,:,3]>0)),p
            Image.fromarray(a).save(p,optimize=True)
if __name__=='__main__':
    if '--prepare' in sys.argv:prepare()
    elif '--render' in sys.argv:render()
    elif '--finish-emission' in sys.argv:finish_emission()
