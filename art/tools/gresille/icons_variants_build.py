"""Native 128px Gresille variants; Blender --background --python this_file.
Use system Python with --pack for validation and the six-icon contact sheet.
"""
import sys, math, json
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / 'art/renders/gresille_vfx'
ICONS = ROOT / 'game/assets/sprites/icons/spells'
NAMES = ('gresille_paratonnerre', 'gresille_leyde')


def render():
    import bpy
    sys.path[:0] = [str(ROOT/'art/tools/night'), str(ROOT/'art/tools/cel')]
    import icons_norm_build as kit
    kit.WORK = WORK
    WORK.mkdir(parents=True, exist_ok=True)

    def bolt(points, width=.026):
        kit.line(points, width, kit.glow, y=-.40)
        kit.line(points, width*.30, kit.heart, y=-.44)

    def lightning_rod():
        glass = kit.mat('#56646B', .28, .35)
        # Small distant footing, thin shaft, three visible glass insulators.
        kit.plate([(-.16,-.65),(.19,-.65),(.12,-.60),(-.10,-.60)], kit.dark)
        kit.arc(.02,-.60,.22,0,math.tau,kit.glow,.012,32,sy=.22)
        kit.line([(.02,-.61),(.02,.13)], .025, kit.metal)
        for z in (-.04,-.12,-.20):
            kit.plate([(-.055,z-.025),(.095,z-.025),(.075,z+.025),(-.035,z+.025)],glass,y=-.32,b=.009)
            kit.line([(-.045,z+.018),(.075,z+.018)],.009,kit.metal,y=-.36)
        kit.line([(.02,.05),(.02,.23)],.014,kit.metal)
        # One uninterrupted vertical strike, terminating exactly on the tip.
        bolt([(.11,.78),(-.045,.57),(.055,.57),(-.075,.36),(.025,.38),(.02,.23)],.044)
        kit.dot(.02,.23,.047,kit.heart,y=-.45)

    def leyden():
        glass = kit.mat('#35494E', .33, .24)
        glint = kit.mat('#708585', .35, .25)
        copper = kit.mat('#8E6753', .58, .65)
        angle = -.43
        def xy(x,z):
            return (x*math.cos(angle)-z*math.sin(angle),x*math.sin(angle)+z*math.cos(angle))
        def plate(points, material, y=-.28):
            kit.plate([xy(x,z) for x,z in points],material,y=y,b=.016)
        def line(points,width,material,y=-.33):
            kit.line([xy(x,z) for x,z in points],width,material,y=y)
        # Faceted smoked-glass jar, copper foil bands, neck and electrode.
        plate([(-.23,-.37),(-.28,-.28),(-.28,.15),(-.13,.28),(-.10,.37),(.10,.37),(.13,.28),(.28,.15),(.28,-.28),(.23,-.37)],glass)
        plate([(-.28,-.25),(.28,-.25),(.28,-.16),(-.28,-.16)],copper,y=-.35)
        plate([(-.28,.10),(.28,.10),(.26,.18),(-.26,.18)],copper,y=-.35)
        line([(-.19,-.10),(-.19,.06)],.016,glint)
        line([(-.12,.34),(.12,.34)],.026,copper)
        line([(0,.34),(0,.58)],.022,kit.metal)
        x,z=xy(0,.58);kit.dot(x,z,.049,copper)
        # Bright internal fissure with asymmetric star of escaping arcs.
        bolt([xy(-.04,-.30),xy(.04,-.10),xy(-.035,.015),xy(.08,.22)],.031)
        for pts,w in [([(0,0),(-.28,.06),(-.39,.22),(-.57,.20)],.027),
                      ([(0,0),(.30,.03),(.36,-.08),(.63,.02)],.029),
                      ([(0,0),(-.07,.32),(-.20,.40),(-.15,.62)],.022),
                      ([(0,0),(-.30,-.24),(-.28,-.42),(-.44,-.53)],.024),
                      ([(0,0),(.24,-.25),(.41,-.24),(.48,-.43)],.024)]:
            bolt([xy(x,z) for x,z in pts],w)
        kit.dot(0,0,.061,kit.heart,y=-.46)

    for name, emblem in zip(NAMES,(lightning_rod,leyden)):
        s=kit.scene(name,emblem,'#B9A6FF')
        s.render.resolution_x=s.render.resolution_y=128
        s.render.resolution_percentage=100
        s.camera.data.ortho_scale*=1.017
        s.camera.data.shift_x-=1.5/128
        s.eevee.taa_render_samples=12
        s.render.threads_mode='FIXED'; s.render.threads=8
        for layer in s.view_layers: layer.use_pass_normal=False
        bpy.ops.render.render(write_still=True)
    print('PASS 2 native 128x128 renders; normals=False',flush=True)


def pack():
    from PIL import Image, ImageStat
    import hashlib
    checks=[]
    for name in NAMES:
        with Image.open(WORK/(name+'_raw.png')) as source:
            assert source.mode=='RGBA' and source.size==(128,128)
            im=source.copy()
        assert im.getchannel('A').getextrema()==(0,255)
        assert im.getbbox()==(10,8,121,120),im.getbbox()
        assert max(ImageStat.Stat(im).stddev[:3])>25
        path=ICONS/(name+'.png'); im.save(path,optimize=True)
        assert path.stat().st_size<60*1024
        checks.append({'file':name+'.png','size':im.size,'alpha':(0,255),'bytes':path.stat().st_size})
    names=('gresille_arc','gresille_decharge','gresille_terre','gresille_orage')+NAMES
    board=Image.new('RGBA',(1008,168),(24,26,31,255))
    hashes=set()
    for i,name in enumerate(names):
        with Image.open(ICONS/(name+'.png')) as im:
            assert im.size==(128,128) and im.mode=='RGBA'
            hashes.add(hashlib.sha256(im.tobytes()).hexdigest())
            # Enlargement is restricted to this control montage.
            board.alpha_composite(im.resize((160,160),Image.Resampling.NEAREST),(i*168+4,4))
    assert len(hashes)==6
    board.save(WORK/'controle_icones_variantes.png',optimize=True)
    (WORK/'verification_icones_variantes.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
    print('PASS 2 PNG; 128x128 RGBA; alpha; contrast; <60 KiB; 6 distinct icons; contact 1008x168')


if __name__=='__main__':
    if '--pack' in sys.argv: pack()
    else: render()
