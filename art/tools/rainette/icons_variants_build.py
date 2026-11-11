"""Native 128px Rainette spell variants; Blender --background --python this_file."""
import sys, math, hashlib
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / 'art/renders/rainette_icons'
ICONS = ROOT / 'game/assets/sprites/icons/spells'
NAMES = ('rainette_croassement', 'rainette_ricochet', 'rainette_bulle', 'rainette_choeur')
ACCENT = '#69BD79'


def render():
    import bpy
    sys.path[:0] = [str(ROOT/'art/tools/night'), str(ROOT/'art/tools/cel')]
    import icons_norm_build as kit
    kit.WORK = WORK
    WORK.mkdir(parents=True, exist_ok=True)

    def croassement():
        # Open jaw and vocal sac, with three expanding pressure rings.
        kit.plate([(-.34,-.34),(-.43,-.13),(-.40,.10),(-.25,.29),(0,.36),(.25,.29),(.40,.10),(.43,-.13),(.34,-.34),(.18,-.23),(0,-.18),(-.18,-.23)])
        kit.arc(0,.08,.22,math.pi,math.tau,kit.heart,.025,24,y=-.40)
        kit.plate([(-.17,-.30),(-.11,-.56),(0,-.63),(.11,-.56),(.17,-.30)],kit.glow,y=-.38)
        kit.line([(-.27,.02),(-.15,-.04),(0,-.06),(.15,-.04),(.27,.02)],.022,kit.dark,-.43)
        for r in (.48,.64,.80):
            kit.arc(0,-.02,r,.20,2.94,kit.glow,.024,32,sy=.86,y=-.32)
        for x,z in [(-.66,.39),(.67,.32),(.02,.70)]:
            kit.dot(x,z,.052,kit.pale,y=-.38)

    def ricochet():
        # Two successive hops and two ground shock rings; crouched frog at launch.
        kit.arc(-.08,-.02,.34,.25,2.72,kit.glow,.035,28,sy=1.45)
        kit.arc(.42,.03,.34,.25,2.72,kit.glow,.035,28,sy=1.45)
        for x in (-.52,.62):
            kit.arc(x,-.48,.17,0,math.tau,kit.glow,.026,24,sy=.42,y=-.34)
            kit.arc(x,-.48,.10,0,math.tau,kit.heart,.014,20,sy=.42,y=-.38)
        kit.plate([(-.61,-.33),(-.50,-.21),(-.32,-.17),(-.22,-.23),(-.12,-.12),(.02,-.14),(.12,-.27),(.05,-.36),(-.16,-.38),(-.31,-.33),(-.48,-.38)])
        kit.dot(-.35,-.13,.105,kit.glow,y=-.35)
        kit.dot(-.32,-.12,.027,kit.dark,y=-.42)
        kit.line([(-.24,-.25),(-.08,-.31),(.04,-.29)],.025,kit.heart,-.40)

    def bulle():
        # Clear glass sphere, crescent highlight, floating silhouettes and mud drops.
        glass=kit.mat('#B5E8D0',.30,.1,'#B5E8D0',.42)
        kit.arc(0,.02,.62,0,math.tau,kit.glow,.034,56,sy=1,y=-.27)
        kit.arc(-.04,.04,.52,1.82,4.68,kit.heart,.026,36,sy=1,y=-.34)
        kit.arc(-.04,.04,.57,1.90,4.58,glass,.014,32,sy=1,y=-.37)
        # Two angular, dark monster shapes suspended inside the bubble.
        kit.plate([(-.32,-.12),(-.26,.02),(-.17,.09),(-.09,.02),(-.04,-.13),(-.12,-.22),(-.27,-.22)],kit.dark,y=-.41)
        kit.dot(-.21,.01,.026,kit.pale,y=-.46)
        kit.plate([(.10,.06),(.16,.20),(.25,.26),(.34,.17),(.38,.03),(.30,-.02),(.18,-.01)],kit.dark,y=-.41)
        kit.dot(.25,.18,.023,kit.pale,y=-.46)
        kit.arc(-.22,-.18,.09,3.5,5.9,kit.heart,.012,12,sy=.55,y=-.47)
        kit.arc(.27,-.04,.08,3.5,5.9,kit.heart,.012,12,sy=.55,y=-.47)
        for x,z,r in [(-.76,.43,.055),(.74,.31,.045),(.67,-.38,.038),(-.64,-.45,.035)]:
            kit.plate([(x,z+r),(x-r*.62,z),(x,z-r),(x+r*.62,z)],kit.glow,y=-.34)

    def choeur():
        # Three marsh reeds, their shared ovoid pool, and paired sound arcs.
        pool=kit.sphere((0,-.28,-.42),(.53,.07,.23),kit.glow)
        kit.arc(0,-.42,.40,0,math.tau,kit.heart,.018,32,sy=.38,y=-.37)
        kit.arc(0,-.42,.40,0,math.tau,kit.heart,.018,32,sy=.38,y=-.37)
        for x,top in [(-.40,.48),(0,.72),(.40,.56)]:
            kit.line([(x,-.38),(x,top-.13)],.027,kit.wood,-.34)
            kit.plate([(x-.07,top-.17),(x-.045,top-.02),(x,top+.08),(x+.05,top-.01),(x+.07,top-.17)],kit.glow,y=-.38)
            kit.line([(x,top-.14),(x,top+.045)],.012,kit.heart,-.43)
        for sign in (-1,1):
            kit.arc(sign*.43,.18,.20,-1.0,1.0,kit.glow,.024,20,sy=1.3,y=-.34)
            kit.arc(sign*.48,.18,.34,-.92,.92,kit.heart,.020,24,sy=1.3,y=-.36)

    for name, emblem in zip(NAMES, (croassement, ricochet, bulle, choeur)):
        s=kit.scene(name,emblem,ACCENT)
        s.render.resolution_x=s.render.resolution_y=128
        s.render.resolution_percentage=100
        s.camera.data.ortho_scale*=1.017
        s.camera.data.shift_x-=1.5/128
        s.eevee.taa_render_samples=12
        s.render.threads_mode='FIXED';s.render.threads=8
        for layer in s.view_layers: layer.use_pass_normal=False
        bpy.ops.render.render(write_still=True)
    print('PASS 4 native 128x128 renders; Eevee; normals=False',flush=True)


def pack():
    from PIL import Image, ImageStat
    checks=[]
    for name in NAMES:
        with Image.open(WORK/(name+'_raw.png')) as source:
            assert source.mode=='RGBA' and source.size==(128,128)
            im=source.copy()
        assert im.getchannel('A').getextrema()==(0,255)
        assert im.getbbox()==(10,8,121,120),(name,im.getbbox())
        assert max(ImageStat.Stat(im).stddev[:3])>25
        path=ICONS/(name+'.png');im.save(path,optimize=True)
        assert path.stat().st_size<60*1024
        checks.append(path)
    comparison=('rainette_gluant','rainette_chant_de_crue','rainette_grand_saut','rainette_langue')
    paths=checks+[ICONS/(n+'.png') for n in comparison]
    hashes=set()
    board=Image.new('RGBA',(1008,168),(24,26,31,255))
    for i,path in enumerate(paths):
        with Image.open(path) as im:
            assert im.size==(128,128) and im.mode=='RGBA',path.name
            hashes.add(hashlib.sha256(im.tobytes()).hexdigest())
            board.alpha_composite(im.resize((160,160),Image.Resampling.NEAREST),(i*168+4,4))
    assert len(hashes)==len(paths),len(hashes)
    board.save(WORK/'controle.png',optimize=True)
    assert board.width<=1024
    print('PASS 4 PNG; 128x128 RGBA; alpha; contrast; bbox; <60 KiB; 8 distinct including 4 Rainette icons; contact 1008x168')


if __name__=='__main__':
    if '--pack' in sys.argv: pack()
    else: render()
