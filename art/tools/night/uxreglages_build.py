"""UXREGLAGES: front orthographic Eevee; shared UXA11Y geometry; cel ui, no normals."""
import sys, math, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/ui/menu'

def finish():
    from PIL import Image, ImageOps
    images=[]
    for state in ('on','off'):
        p=OUT/f'toggle_{state}.png'
        im=Image.open(p).convert('RGBA').resize((160,88),Image.Resampling.LANCZOS)
        assert im.getbbox() and im.getchannel('A').getextrema()==(0,255)
        assert im.getbbox()[0]>=4 and im.getbbox()[2]<=156
        im.save(p,optimize=True,compress_level=9)
        images.append(im)
    sheet=Image.new('RGB',(512,352))
    for row,(bg,gray) in enumerate((('#1c1f26',False),('#2B3340',False),('#1c1f26',True),('#2B3340',True))):
        tile=Image.new('RGBA',(512,88),bg)
        for i,im in enumerate(images):
            src=im.copy()
            if gray:
                src=ImageOps.grayscale(src).convert('RGBA'); src.putalpha(im.getchannel('A'))
            tile.alpha_composite(src,(i*160,0))
            tile.alpha_composite(src.resize((88,48),Image.Resampling.LANCZOS),(328+i*92,20))
        sheet.paste(tile.convert('RGB'),(0,row*88))
    sheet.save(ROOT/'art/tools/night/_uxreglages_contact.png',optimize=True,compress_level=9)
    print('PASS: 2 PNG RGBA 160x88; alpha; margins; contact 160x88 + 88x48; 2 backgrounds; grayscale')

if '--finish' in sys.argv:
    finish(); sys.exit(0)
import bpy
sys.path.insert(0,str(Path(__file__).parent))
import uxa11y_build as ux
cel=ux.cel
bpy.ops.wm.read_factory_settings(use_empty=True)
cel.install('ui',normals=False)
cel.setup_scene(samples=8)
bpy.context.scene.view_settings.look='None'
M={k:ux.material(k,c,t) for k,c,t in [('edge','#E8EEF8',False),('ink','#171B23',False),('metal','#3A4250',True),('wear','#8894A4',False),('glass','#171F2B',False),('hot','#FFB347',False),('core','#FFE9A8',False),('warmtrack','#573C2A',True),('track','#2B3340',True),('halo','#7C4C28',False),('rim','#A8946E',True)]}

def capsule(x1,x2,y,r,m,z):
    pts=[]
    for x,start in ((x2,-math.pi/2),(x1,math.pi/2)):
        pts += [(x+r*math.cos(start+i*math.pi/32), y+r*math.sin(start+i*math.pi/32)) for i in range(33)]
    ux.poly(pts,m,z)

for on in (True,False):
    ux.reset(160)
    s=bpy.context.scene
    s.camera.location=(80,-44,200)
    s.render.resolution_x=320; s.render.resolution_y=176
    capsule(34,126,44,27,M['ink'],0)
    capsule(34,126,44,25,M['edge'],.1)
    capsule(34,126,44,23,M['warmtrack' if on else 'track'],.2)
    # Recess channel and a small mechanical stop.
    capsule(39,121,44,13,M['ink'],.3)
    x=122 if on else 38
    ux.circle(x,44,30,M['ink'],.5)
    ux.circle(x,44,28,M['edge'],.6)
    ux.circle(x,44,26,M['metal'],.7)
    ux.circle(x,44,22,M['halo' if on else 'ink'],.8)
    # Worn lantern handle, cap, glass chamber and protective cage.
    ux.circle(x,24,6,M['wear'],1)
    ux.circle(x,24,3.5,M['ink'],1.1)
    ux.poly([(x-10,31),(x-7,27),(x+7,27),(x+10,31)],M['rim' if on else 'metal'],1.2)
    ux.poly([(x-12,33),(x+12,33),(x+10,58),(x-10,58)],M['ink'],1.3)
    ux.poly([(x-8,35),(x+8,35),(x+7,55),(x-7,55)],M['hot' if on else 'glass'],1.4)
    if on:
        ux.poly([(x-4,52),(x-5,46),(x+1,37),(x,45),(x+5,48),(x+3,53)],M['core'],1.5)
    else:
        ux.stroke((x-5,38),(x-3,43),1.5,M['wear'],1.5)
        ux.stroke((x-3,53),(x+3,53),2,M['metal'],1.5)
    for dx in (-10,10):
        ux.stroke((x+dx,34),(x+dx*.8,57),2.5,M['wear'],1.6)
    ux.poly([(x-12,58),(x+12,58),(x+10,62),(x-10,62)],M['metal'],1.7)
    ux.stroke((x-8,60),(x+6,60),1,M['wear'],1.8)
    for dx in (-22,22): ux.circle(x+dx,44,1.3,M['rim'],1.8)
    cel.toon_materials('ui')
    s.render.filepath=str(OUT/f'toggle_{"on" if on else "off"}.png')
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.render.render(write_still=True)
subprocess.run(['python',str(Path(__file__).resolve()),'--finish'],check=True)
