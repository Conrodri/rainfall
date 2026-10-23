"""U1: Blender PBR resource vessel. Reuses UI geometry and Ash Lord worn shader.
Assets only in ui/resource_gauge; frame nine-patch L/R=12 T/B=8 pixels.
Run Blender --background --python this_file; python this_file --contact assembles QA.
"""
from pathlib import Path
import sys, math, ast, re
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/ui/resource_gauge'

def contact():
    from PIL import Image, ImageChops, ImageOps
    sizes={'frame':(256,48),'frame_bg':(256,48),'fill':(256,32),'fill_e':(256,32),'pip_empty':(32,32),'pip_full':(32,32),'pip_full_e':(32,32),'notch':(16,32)}
    for p in OUT.glob('*.png'):
        im=Image.open(p).convert('RGBA'); target=sizes.get(p.stem,(240,20))
        if im.size==(target[0]*2,target[1]*2):im.resize(target,Image.Resampling.LANCZOS).save(p,optimize=True)
    assets={k:Image.open(OUT/(k+'.png')).convert('RGBA') for k in sizes}
    for k,im in assets.items():
        assert im.size==sizes[k] and im.getchannel('A').getbbox(),k
        if k in ('fill','fill_e','pip_full','pip_full_e'):
            r,g,b,a=im.split();assert ImageChops.difference(r,g).getextrema()[1]<=1 and ImageChops.difference(g,b).getextrema()[1]<=1,k
    board=Image.new('RGBA',(1024,768),(15,18,22,255))
    def label(text,x,y):
        # Text is rendered by Blender, Pillow only assembles.
        p=OUT/('_label_'+text+'.png')
        if p.exists():board.alpha_composite(Image.open(p),(x,y))
    for i,name in enumerate(['Ardent','Rictus','Arpenteuse','Avare','Averse','Bourbe','Rainette','Tocsin']):
        col='#FF8C33'
        p=ROOT/'game/scripts/spells'/ (name.lower()+'_kit.gd')
        if p.exists():
            m=re.search(r'const (?:ACCENT|GOLD|STRING_COLOR) := Color\("(#[A-Fa-f0-9]+)"\)',p.read_text(encoding='utf-8'))
            if m:col=m.group(1)
        x=35+(i%2)*495;y=38+(i//2)*115
        label(name,x,y)
        board.alpha_composite(assets['frame_bg'],(x,y+22))
        f=assets['fill'];rgb=ImageChops.multiply(f.convert('RGB'),Image.new('RGB',f.size,col));f=rgb.convert('RGBA');f.putalpha(assets['fill'].getchannel('A'))
        board.alpha_composite(f.crop((0,0,155+i*10,32)),(x+10,y+30))
        board.alpha_composite(assets['frame'],(x,y+22));board.alpha_composite(assets['notch'],(x+180,y+30))
        for j in range(5):
            p=assets['pip_full' if j<3 else 'pip_empty'].copy()
            if j<3:
                rgb=ImageChops.multiply(p.convert('RGB'),Image.new('RGB',p.size,col)).convert('RGBA');rgb.putalpha(p.getchannel('A'));p=rgb
            board.alpha_composite(p,(x+275+j*34,y+30))
    # Validated DA references and existing spell frame, on the sole contact sheet.
    refs=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','game/assets/sprites/ui/spell_frame_pressed.png']
    for i,p in enumerate(refs):
        im=Image.open(ROOT/p).convert('RGBA');im.thumbnail((230,200));board.alpha_composite(im,(20+i*250,540))
    board.save(ROOT/'art/tools/night/_u1_contact.png')
    for p in OUT.glob('_label_*.png'):p.unlink()
    print('PASS: 8 RGBA assets, exact sizes, neutral masks, contact 1024x768')

if '--contact' in sys.argv:
    contact();sys.exit()
import bpy
sys.path.insert(0,str(ROOT/'art/tools/ui'))
from ui_kit import reset_scene,setup_render,front_camera,rr_ring,slab,rrect,sphere,curve,mat,render_to
# Reuse exactly the established procedural worn material, without running its build.
src=ast.parse((ROOT/'art/tools/monsters/ash_lord_build.py').read_text(encoding='utf-8'))
fn=next(n for n in src.body if isinstance(n,ast.FunctionDef) and n.name=='worn')
def material(name,color,_):return mat('#'+color)
exec(compile(ast.Module(body=[fn],type_ignores=[]),'ash_lord.worn','exec'))
OUT.mkdir(parents=True,exist_ok=True)

def scene(w,h,neutral=False):
    reset_scene();setup_render();s=bpy.context.scene;s.eevee.taa_render_samples=24;s.render.dither_intensity=0
    front_camera(w,h,w*2,h*2)
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.18
    if neutral:s.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1)
    for ob in s.objects:
        if ob.type=='LIGHT':
            ob.data.color=(1,1,1) if neutral else ((1,.72,.46) if 'chaud' in ob.name else (.5,.67,1))
            ob.data.energy=2.5 if 'chaud' in ob.name else .65
            ob.data.angle=.15
    return s

def save(name,w,h):
    render_to(OUT/(name+'.png'))
    if name in ('fill','fill_e','pip_full','pip_full_e'):
        import numpy as np
        im=bpy.data.images.load(str(OUT/(name+'.png')),check_existing=False)
        a=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(a);a=a.reshape(-1,4)
        grey=a[:,:3] @ np.array([.2126,.7152,.0722]);a[:,:3]=grey[:,None]
        im.pixels.foreach_set(a.ravel());im.save();bpy.data.images.remove(im)
    # Render 2x, resize losslessly in the external Pillow finalization step.

def palette():
    return worn('Pitted black iron','202123','66645C',.65,.58),worn('Rubbed iron edges','3D3832','8B7860',.65,.6),worn('Deep oily recess','080A0B','242728',.4,.7)

scene(256,48);iron,edge,dark=palette()
rr_ring(252,44,3,6,iron,4,0,1,3)
rr_ring(242,34,2,1.15,edge,1.4,-2.1,.35,3)
# End straps and slotted rivets remain wholly inside the fixed 12px caps.
for x in (-121,121):
    slab([(x-2,-17),(x+2,-17),(x+2,17),(x-2,17)],edge,1.2,-2.6,.5)
    for z in (-16,16):
        sphere((x,-3.6,z),(2,1.1,2),edge)
        curve([(x-1,-4.6,z+.5),(x+1,-4.6,z-.5)],.28,dark)
save('frame',256,48)
scene(256,48);iron,edge,dark=palette()
slab(rrect(250,42,3,3),dark,2,1,.7)
rr_ring(244,36,2,1.2,iron,2,-.4,.5,3)
save('frame_bg',256,48)

for emission in (False,True):
    scene(256,32,True)
    liquid=worn('Neutral quicksilver','707070','C8C8C8',.65,.27)
    glint=mat('#CECECE',.25,.4, '#FFFFFF' if emission else None, .7 if emission else 0)
    if not emission:
        slab(rrect(254,29,1.5,3),liquid,3,0,1.3)
    # Long meniscus and broken secondary streaks: liquid under tension.
    curve([(-126,-2.3,9),(-84,-2.6,10),(-25,-2.3,8.7),(42,-2.4,10),(91,-2.3,9),(126,-2.3,10)],.6 if emission else .8,glint)
    for x,length,z in [(-100,30,3),(-36,17,-6),(26,42,4),(87,24,-5)]:
        curve([(x,-2.5,z),(x+length*.55,-2.6,z+.65),(x+length,-2.4,z)],.32,glint)
    save('fill_e' if emission else 'fill',256,32)
for kind in ('empty','full','full_e'):
    scene(32,32,kind!='empty');iron,edge,dark=palette()
    neutral=worn('Grey charge socket','262626','828282',.6,.48)
    if kind!='full_e':
        rr_ring(28,28,4,3.5,iron if kind=='empty' else neutral,3,0,.8,2)
        slab(rrect(21,21,2,2),dark if kind=='empty' else worn('Charge silver','686868','CCCCCC',.55,.3),2,.4,.7)
    if kind!='empty':
        glint=mat('#DADADA',.3,.3,'#FFFFFF' if kind=='full_e' else None,1 if kind=='full_e' else 0)
        curve([(-7,-1.7,5),(0,-2,7),(7,-1.7,5)],.7,glint)
        curve([(-3,-1.6,-5),(0,-1.8,-3),(3,-1.6,-5)],.4,glint)
    save('pip_'+kind,32,32)
scene(16,32);iron,edge,dark=palette()
slab([(-5,14),(5,14),(4,6),(1,-1),(1,-13),(-1,-13),(-1,-1),(-4,6)],edge,2,-1,.45)
slab([(-2,12),(2,12),(0,5)],dark,1,-2.2,.2)
save('notch',16,32)
# Blender typography for QA (no Pillow drawing).
for name in ['Ardent','Rictus','Arpenteuse','Avare','Averse','Bourbe','Rainette','Tocsin']:
    scene(240,20,True)
    bpy.ops.object.text_add(location=(-118,-1,-5),rotation=(math.pi/2,0,0))
    o=bpy.context.object;o.data.body=name;o.data.size=13;o.data.materials.append(mat('#B0B6B8',emit_hex='#B0B6B8',emit_strength=1))
    save('_label_'+name,240,20)
print('U1 RENDER PASS')




