"""Bourbe variants; fixed seed; Nova backing/camera/cel and i3_finish.fit.
Blender --background --python art/tools/night/bouvi_build.py [-- --only ID].
System Python: --finish ID / --contact. No normal or emission files.
"""
import sys, math, random, argparse, subprocess
from pathlib import Path
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
WORK=ROOT/'art/blender/cel/bouvi'
GAME=ROOT/'game/assets/sprites/icons/spells'
NAMES=['bourbe_crachat_de_vase','bourbe_bouture','bourbe_eclatement','bourbe_maree_de_vase']
sys.dont_write_bytecode=True
sys.path.insert(0,str(BASE))

def finish(name):
    import json
    from types import SimpleNamespace
    import i3_finish as f
    from PIL import Image
    box=Image.open(GAME/'nova_ardente.png').getbbox()
    assert box==(10,8,121,120)
    f.BASE=WORK
    f.INV=SimpleNamespace(read_text=lambda:json.dumps({'files':{name:{'bbox':box,'size':[128,128],'path':f'game/assets/sprites/icons/spells/{name}.png'}}}))
    f.fit(name)
    im=Image.open(GAME/(name+'.png'))
    assert im.mode=='RGBA' and im.size==(128,128) and im.getbbox()==box
    assert not any((GAME/(name+s+'.png')).exists() for s in ('_n','_e'))

def contact():
    from PIL import Image
    sheet=Image.new('RGB',(5*144,2*224))
    for row,color in enumerate(('#0A0D12','#2E3238')):
        sheet.paste(Image.new('RGB',(720,224),color),(0,row*224))
        for col,name in enumerate(['nova_ardente']+NAMES):
            im=Image.open(GAME/(name+'.png')).convert('RGBA')
            sheet.paste(im,(col*144+8,row*224+4),im)
            small=im.resize((72,72),Image.Resampling.LANCZOS)
            sheet.paste(small,(col*144+36,row*224+144),small)
    sheet.save(BASE/'bouvi_contact.png')
    print('PASS contact: Nova, crachat, bouture, eclatement, maree; 128/72; 2 fonds')

def build():
    import icons_norm_build as n
    import bpy
    parser=argparse.ArgumentParser();parser.add_argument('--only',choices=NAMES)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    n.cel.archive_folder('icons/spells')
    WORK.mkdir(parents=True,exist_ok=True)
    n.WORK=WORK
    def slime(x,z,r,seed=1):
        n.blob(x,z,r,n.dark,seed)
        # Thick raised wet crest: green accent on dark clay body.
        n.arc(x-.02,z+.015,r*.75,.25,2.85,n.glow,.035,20,sy=.65,y=-.38)
    def leaf(x,z,sign=1):
        n.plate([(x,z),(x+sign*.18,z+.04),(x+sign*.24,z+.21),(x+sign*.07,z+.18)],n.glow,y=-.39)
        n.line([(x,z),(x+sign*.17,z+.15)],.012,n.heart,y=-.43)
    def emblem(name):
        n.dark=n.mat('#5B8066',.88)
        if name==NAMES[0]:
            slime(.20,.02,.31,9)
            for dz,length in [(.20,.52),(0,.64),(-.19,.45)]:
                n.line([(-length,dz-.08),(-.31,dz-.03),(.02,dz)],.035,n.glow)
            for x,z,r in [(.53,.23,.065),(.62,.04,.075),(.47,-.23,.055),(-.66,.12,.03)]:n.dot(x,z,r)
            n.line([(.39,.05),(.56,.15),(.64,.28)],.032)
        elif name==NAMES[1]:
            slime(-.32,-.13,.28,12);slime(.32,-.13,.28,23)
            n.line([(-.18,-.13),(0,-.24),(.18,-.13)],.037,n.glow,y=-.38)
            n.line([(0,-.20),(0,.16),(.07,.35)],.034,n.glow)
            leaf(.035,.24,1);leaf(.01,.15,-1)
        elif name==NAMES[2]:
            slime(0,0,.23,43)
            for i in range(7):
                a=i*math.tau/7+.15
                p=(.20*math.cos(a),.20*math.sin(a));q=(.47*math.cos(a),.47*math.sin(a))
                n.line([p,(q[0]*.8,q[1]*.8),q],.028,n.glow)
                slime(q[0],q[1],.075,i+70)
            for a in (.25,math.pi+.25):
                n.arc(0,0,.64,a,a+1.5,n.glow,.027,25)
                t=a+1.5;p=(.64*math.cos(t),.64*math.sin(t))
                n.arrow(p,(p[0]*.70,p[1]*.70),.078,n.glow)
        else:
            # Single curling tidal mass with an open dark eye.
            n.plate([(-.65,-.40),(-.51,-.13),(-.34,.08),(-.25,.35),(-.04,.51),(.24,.48),(.46,.30),(.48,.06),(.35,-.08),(.16,-.08),(.06,.02),(.17,.17),(.29,.14),(.28,.28),(.10,.32),(-.05,.18),(-.05,-.04),(.15,-.25),(.51,-.31),(.62,-.42)],n.dark)
            n.line([(-.58,-.34),(-.34,-.07),(-.22,.26),(-.03,.43),(.23,.40),(.39,.23),(.36,.06),(.20,.01)],.055,n.glow,y=-.38)
            n.line([(-.45,-.38),(-.18,-.22),(.06,-.30),(.47,-.37)],.025,n.heart,y=-.39)
            for i,(x,z) in enumerate([(-.48,.48),(-.20,.65),(.12,.68),(.43,.53)]):slime(x,z,.065,90+i)
    for name in ([args.only] if args.only else NAMES):
        random.seed(2819)
        s=n.scene(name,lambda:emblem(name),'#8DDBA8')
        s.render.filepath=str(WORK/('i3_raw_'+name+'.png'))
        s.eevee.taa_render_samples=8
        bpy.ops.render.render(write_still=True)
        subprocess.run([n.PY,str(Path(__file__).resolve()),'--finish',name],check=True,stdout=subprocess.DEVNULL)
        print('PASS '+name,flush=True)
        bpy.context.window.scene=bpy.data.scenes[0]
        bpy.data.scenes.remove(s)

if __name__=='__main__':
    if '--finish' in sys.argv:finish(sys.argv[sys.argv.index('--finish')+1])
    elif '--contact' in sys.argv:contact()
    else:build()

