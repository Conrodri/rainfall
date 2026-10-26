"""RICVI: fixed seed; shared Nova backing/camera/cel and shared raster fit. No auxiliary maps."""
import sys, math, random
from pathlib import Path
BASE=Path(__file__).resolve().parent
ROOT=BASE.parents[2]
sys.dont_write_bytecode=True
sys.path.insert(0,str(BASE))
NAMES=['rictus_main_du_montreur','rictus_lame_pendule','rictus_pirouette','rictus_rideau']

def emblem(name):
    if name==NAMES[0]:
        n.plate([(-.23,.34),(.16,.38),(.29,.13),(.20,-.08),(-.12,-.12),(-.27,.08)])
        for x,end in [(-.17,-.40),(-.055,-.53),(.065,-.48),(.18,-.36)]:
            n.line([(x,.02),(x-.025,-.22),(x+.015,end)],.039,n.glow)
            n.line([(x,.56),(x,.29)],.013,n.heart)
        n.line([(-.21,.21),(-.39,.04),(-.36,-.18)],.047)
        n.arc(0,-.50,.34,3.35,6.05,n.heart,.019,sy=.24)
        n.arc(0,-.51,.49,3.45,5.95,n.glow,.015,sy=.30)
    elif name==NAMES[1]:
        n.line([(-.23,.61),(-.23,.42),(.18,.19),(.31,-.15)],.020,n.heart)
        n.arc(-.16,.43,.085,0,math.tau,n.glow,.017,sy=1.2)
        n.knife(2.78,.27,-.25,.73)
        for i in range(10):
            a=3.30+i*.25
            n.arc(0,.27,.73,a,a+.11,n.glow,.016,n=5)
    elif name==NAMES[2]:
        n.dot(0,.23,.13,n.heart)
        n.plate([(-.14,.10),(.14,.10),(.12,-.19),(-.10,-.19)],n.metal)
        for p in [[(-.11,.04),(-.32,.16),(-.42,.06)],[(.11,.04),(.33,-.02),(.42,.14)],[(-.06,-.17),(-.23,-.34),(-.15,-.46)],[(.07,-.17),(.27,-.26),(.35,-.16)]]:
            n.line(p,.044,n.glow)
            n.dot(*p[1],.052,n.heart)
        for a,b in [(.1,1.65),(2.05,3.8),(4.15,5.8)]:
            n.arc(0,0,.59,a,b,n.glow,.023)
        for a in [.1,2.05,4.15]:
            n.line([(.40*math.cos(a),.40*math.sin(a)),(.66*math.cos(a+.16),.66*math.sin(a+.16))],.017,n.heart)
    else:
        n.line([(-.66,.30),(-.22,.24),(.22,.30),(.66,.24)],.022,n.heart)
        for x in [-.48,-.16,.16,.48]:
            n.line([(x,.29),(x,.13)],.015,n.heart)
            n.plate([(x-.125,.12),(x+.125,.12),(x+.105,-.19),(x,-.32),(x-.105,-.19)])
            for dx in [-.045,.045]:
                n.line([(x+dx-.018,-.015),(x+dx+.018,-.025)],.019,n.dark,-.36)
            n.arc(x,-.12,.05,3.3,6.0,n.dark,.015,sy=.65,y=-.36)

def finish():
    from PIL import Image
    import icons_norm_finish as f
    game=ROOT/'game/assets/sprites/icons/spells'
    for name in NAMES:
        f.fit(name)
        im=Image.open(game/(name+'.png'))
        assert im.size==(128,128) and im.mode=='RGBA' and im.getbbox()==(10,8,121,120)
        assert not any((game/(name+s+'.png')).exists() for s in ['_n','_e'])
    sheet=Image.new('RGB',(5*148,440))
    for row,bg in enumerate(['#0A0D12','#2E3238']):
        sheet.paste(Image.new('RGB',(740,220),bg),(0,row*220))
        for col,name in enumerate(NAMES+['nova_ardente']):
            im=Image.open(game/(name+'.png')).convert('RGBA')
            for size,y in [(128,0),(72,140)]:
                a=im.resize((size,size),Image.Resampling.LANCZOS)
                sheet.paste(a,(col*148+(148-size)//2,row*220+y),a)
    sheet.save(BASE/'ricvi_contact.png')
    print('PASS 4 RGBA 128x128 bbox (10, 8, 121, 120); contact')

if __name__=='__main__':
    if '--finish' in sys.argv:finish()
    else:
        import icons_norm_build as n
        random.seed(331)
        n.cel.archive_folder('icons/spells')
        n.WORK.mkdir(parents=True,exist_ok=True)
        # Reuse the established Nova run pipeline through its scene/fit functions;
        # no template or existing icon outside this batch is rewritten.
        for name in NAMES:
            s=n.scene(name,lambda name=name:emblem(name),'#9FC8C0')
            s.eevee.taa_render_samples=8
            n.bpy.ops.render.render(write_still=True)
            print('PASS render '+name,flush=True)
            n.bpy.context.window.scene=n.bpy.data.scenes[0]
            n.bpy.data.scenes.remove(s)
            n.bpy.data.orphans_purge(do_recursive=True)
        import subprocess
        subprocess.run([n.PY,str(__file__),'--finish'],check=True)
