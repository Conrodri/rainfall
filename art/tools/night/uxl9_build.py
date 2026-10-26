"""UXL9: front orthographic Eevee, UI two-tone cel, explicit geometry ink."""
import sys, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(Path(__file__).parent))
import uxa11y_build as kit
import bpy
import cel_style as cel
OUT=ROOT/'game/assets/sprites/ui/cues'
NAMES=('cue_boss','cue_elite','cue_telegraph')
cel.install('ui',normals=False)
cel.setup_scene(samples=8)
cel.PROFILES['ui']['ink_px']=0

def mat(h,toon=False):
    m=kit.material('UXL9 '+h,h,toon)
    if toon:
        b=m.node_tree.nodes.get('Principled BSDF')
        c=b.inputs['Base Color'].default_value
        b.inputs['Base Color'].default_value=tuple(v/cel.TONE_SCALES[2] for v in c[:3])+(1,)
        cel.toon_materials('ui')
        rgba=tuple(kit.linear(int(h[i:i+2],16)) for i in (1,3,5))+(1,)
        for n in m.node_tree.nodes:
            if n.type=='VALTORGB': n.color_ramp.elements[-1].color=rgba
    return m

def chevron(p,color):
    kit.poly(p,mat('#0A0505'))
    kit.poly(kit.offset(p,-3),mat(color,True),.1)

OUT.mkdir(parents=True,exist_ok=True)
for name in NAMES:
    kit.reset(96)
    s=bpy.context.scene
    s.render.resolution_x=s.render.resolution_y=192
    s.render.use_compositing=False
    s.view_layers[0].use_pass_normal=False
    s.view_settings.look='None'
    s.render.image_settings.color_depth='8'
    if name=='cue_boss':
        for x in (4,42):
            chevron([(x,12),(x+18,12),(x+50,48),(x+18,84),(x,84),(x+32,48)],'#FF5238')
    elif name=='cue_elite':
        chevron([(14,12),(48,12),(92,48),(48,84),(14,84),(58,48)],'#FFC74D')
    else:
        # Circle left of pivot; double rim and pale right-facing pointer.
        kit.poly([(55,34),(92,48),(55,62)],mat('#0A0505'))
        kit.poly([(57,38),(85,48),(57,58)],mat('#FFE2C8'),.1)
        kit.circle(36,48,32,mat('#0A0505'),.2)
        kit.circle(36,48,28,mat('#FFE2C8'),.3)
        kit.circle(36,48,26,mat('#F21A1A',True),.4)
    s.render.filepath=str(OUT/(name+'.png'))
    bpy.ops.render.render(write_still=True)

# Pillow: resampling, assembly, optimization, verification only.
subprocess.run(['python','-c',r'''
from PIL import Image,ImageOps
from pathlib import Path
import sys
root=Path(sys.argv[1]); out=root/'game/assets/sprites/ui/cues'
names=('cue_boss','cue_elite','cue_telegraph')
for n in names:
 p=out/(n+'.png'); im=Image.open(p).convert('RGBA').resize((96,96),Image.Resampling.LANCZOS)
 # Remove resampling fringes outside the contractual four-pixel margin.
 tile=im.crop((4,4,92,92)); im=Image.new('RGBA',(96,96)); im.paste(tile,(4,4))
 im.save(p,optimize=True,compress_level=9)
 assert im.size==(96,96) and im.mode=='RGBA' and im.getbbox()
 assert not (out/(n+'_n.png')).exists() and not (out/(n+'_e.png')).exists()
canvas=Image.new('RGB',(600,360))
for row,bg in enumerate(('#14110C','#2B3340','#B9AE98')):
 panel=Image.new('RGBA',(600,120),bg)
 for col,n in enumerate(names):
  im=Image.open(out/(n+'.png'))
  for size,dx in ((96,4),(48,106),(32,158)):
   panel.alpha_composite(im.resize((size,size),Image.Resampling.LANCZOS),(col*200+dx,12))
 canvas.paste(panel.convert('RGB'),(0,row*120))
# Separate native grayscale panel, preserving actual pixel sizes.
full=Image.new('RGB',(600,720));full.paste(canvas,(0,0))
for row,bg in enumerate(('#14110C','#2B3340','#B9AE98')):
 panel=Image.new('RGBA',(600,120),bg)
 for col,n in enumerate(names):
  im=Image.open(out/(n+'.png')); g=ImageOps.grayscale(im).convert('RGBA');g.putalpha(im.getchannel('A'))
  for size,dx in ((96,4),(48,106),(32,158)):
   panel.alpha_composite(g.resize((size,size),Image.Resampling.LANCZOS),(col*200+dx,12))
 full.paste(panel.convert('RGB'),(0,360+row*120))
full.save(root/'art/tools/night/_uxl9_contact.png',optimize=True)
def lum(h):
 c=[int(h[i:i+2],16)/255 for i in (1,3,5)]
 c=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in c]
 return sum(a*b for a,b in zip(c,(.2126,.7152,.0722)))
def contrast(a,b):
 a,b=sorted((lum(a),lum(b)));return (b+.05)/(a+.05)
assert min(contrast(c,'#14110C') for c in ('#FF5238','#FFC74D','#F21A1A'))>=3
assert contrast('#0A0505','#B9AE98')>=3
print('PASS UXL9: 3 RGBA 96x96; margin 4; contrast >=3:1; no _n/_e; contact')
''',str(ROOT)],check=True)

