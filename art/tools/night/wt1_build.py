"""WT1: top-down cel shore; Blender background, no auxiliary game assets."""
import sys, math, random
from pathlib import Path
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/iso')]
import bpy
import iso_rig
import cel_style as cel
from PIL import Image
OUT = ROOT/'game/assets/sprites/terrain/shore/shore_foam_256x32.png'
CONTACT = ROOT/'art/tools/night/_wt1_contact.png'
rng = random.Random(220026)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
s = bpy.context.scene
cel.install('tile', normals=False)
cel.setup_scene(s, samples=8)
s.render.resolution_x=512; s.render.resolution_y=64; s.render.resolution_percentage=100
s.render.image_settings.color_depth='8'
s.world.color=(.18,.18,.18)
s.view_settings.look='None'

def linear(v):
    v=v/255
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4

def material(name, rgb, alpha=1, ink=False):
    m=bpy.data.materials.new(name); m.use_nodes=True
    if ink or alpha<1:
        n=m.node_tree.nodes; n.clear()
        out=n.new('ShaderNodeOutputMaterial'); em=n.new('ShaderNodeEmission')
        em.inputs[0].default_value=tuple(linear(c) for c in rgb)+(1,)
        if alpha<1:
            tr=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader')
            mix.inputs[0].default_value=alpha
            m.node_tree.links.new(tr.outputs[0],mix.inputs[1]); m.node_tree.links.new(em.outputs[0],mix.inputs[2])
            m.node_tree.links.new(mix.outputs[0],out.inputs[0])
        else:m.node_tree.links.new(em.outputs[0],out.inputs[0])
    else:
        m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=tuple(linear(c)/1.65 for c in rgb)+(1,)
    return m
stone=material('Wet slate',(66,73,76)); chip=material('Slate facets',(83,91,94))
ink=material('Bank ink #181210',(24,18,16),ink=True)
foam=material('Opaque foam #D6EDF5',(214,237,245))
shadow=material('Bank shadow',(0,0,0),.23)
tails=[material('Dissolving foam '+str(a),(185,219,231),a) for a in (.72,.43,.18,.055)]

def poly(name, pts, mat, z):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([(x,16-y,z) for x,y in pts],[],[list(range(len(pts)))])
    mesh.update(); ob=bpy.data.objects.new(name,mesh); s.collection.objects.link(ob); ob.data.materials.append(mat)

def wave(x):
    return 13.0+1.5*math.sin(2*math.pi*x/256*7+.4)+.65*math.sin(2*math.pi*x/256*19)
# Geometry extends beyond the image: no camera-edge seam or outline.
xs=list(range(-8,265))
poly('Shadow',[(x,8) for x in xs]+[(x,22+math.sin(x*.13)) for x in reversed(xs)],shadow,0)
poly('Stone lip',[(x,1.2+.7*math.sin(x*2*math.pi/256*9)) for x in xs]+[(264,8),(-8,8)],stone,.1)
for i in range(37):
    x=rng.uniform(0,256);w=rng.uniform(2,8)
    for offset in (-256,0,256):
        poly('Wet stone facet',[(x+offset,2),(x+w+offset,2.7),(x+w*.6+offset,4.5),(x-1+offset,4)],chip,.2)
poly('Exact bank edge y8',[(-8,4),(264,4),(264,8),(-8,8)],ink,.3)
poly('Foam rim',[(x,8) for x in xs]+[(x,wave(x)) for x in reversed(xs)],foam,.4)
for i in range(46):
    x=rng.uniform(0,256);width=rng.uniform(.6,2.3);length=rng.uniform(3,14)
    start=wave(x)-.5
    for offset in (-256,0,256):
        for j,mat in enumerate(tails):
            y0=start+length*j/4;y1=min(30,start+length*(j+1)/4)
            if y1<=y0:continue
            w0=width*(1-j/4);w1=width*(1-(j+1)/4)
            drift=length*.16
            poly('Foam filament',[(x+offset-w0+drift*j/4,y0),(x+offset+w0+drift*j/4,y0),(x+offset+w1+drift*(j+1)/4,y1),(x+offset-w1+drift*(j+1)/4,y1)],mat,.45)
for i in range(30):
    x=rng.uniform(0,256);y=rng.uniform(13,20);r=rng.uniform(.35,.85)
    for offset in (-256,0,256):
        poly('Small foam bubble',[(x+offset+math.cos(a*math.tau/10)*r,y+math.sin(a*math.tau/10)*r*.7) for a in range(10)],tails[1],.5)
bpy.ops.object.light_add(type='SUN',location=(0,0,100));bpy.context.object.data.energy=2.5
bpy.ops.object.camera_add(location=(128,0,100));cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=256;s.camera=cam
cel.toon_materials(dict(cel.profile('tile'),tones=2,creases=False))
# No compositor file outputs, normal passes or emission images.
for layer in s.view_layers:layer.use_pass_normal=False
s.use_nodes=False
OUT.parent.mkdir(parents=True,exist_ok=True)
s.render.filepath=str(OUT)
bpy.ops.render.render(write_still=True)
im=Image.open(OUT).convert('RGBA').resize((256,32),Image.Resampling.LANCZOS)
# Periodic endpoint convention: equal endpoint columns, averaged antialiasing.
a=im.crop((0,0,1,32));b=im.crop((255,0,256,32));edge=Image.blend(a,b,.5)
im.paste(edge,(0,0));im.paste(edge,(255,0));im.save(OUT,optimize=True,compress_level=9)
assert im.size==(256,32) and im.getchannel('A').getextrema()==(0,255)
assert im.crop((0,0,1,32)).tobytes()==im.crop((255,0,256,32)).tobytes()
assert all(im.getpixel((x,7))[3]==255 for x in range(256))
assert all(im.getpixel((x,31))[3]==0 for x in range(256))
# Contact assembly only: repetition, then top-down square projected to a 2:1 diamond.
contact=Image.new('RGBA',(1088,440),(9,18,26,255))
for k in range(4):contact.alpha_composite(im,(32+k*256,24))
ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
for y in range(90,440,max(1,ground.height//2)):
    for x in range(-ground.width,1088,ground.width):contact.alpha_composite(ground,(x+(ground.width//2 if (y//max(1,ground.height//2))%2 else 0),y))
flat=Image.new('RGBA',(272,272))
flat.alpha_composite(Image.new('RGBA',(256,256),(9,18,26,255)),(8,8))
flat.alpha_composite(im,(8,0));flat.alpha_composite(im.transpose(Image.Transpose.ROTATE_180),(8,240))
flat.alpha_composite(im.transpose(Image.Transpose.ROTATE_90),(0,8));flat.alpha_composite(im.transpose(Image.Transpose.ROTATE_270),(240,8))
# u=x-y+272, v=(x+y)/2; inverse x=u/2+v-136,y=-u/2+v+136.
diamond=flat.transform((544,272),Image.Transform.AFFINE,(.5,1,-136,-.5,1,136),Image.Resampling.BICUBIC)
contact.alpha_composite(diamond,(272,130));contact.convert('RGB').save(CONTACT,optimize=True)
print('WT1 PASS: RGBA 256x32; seam x identical; edge y = 8; bottom alpha 0; bytes',OUT.stat().st_size)

