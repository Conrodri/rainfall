"""Build the Encre cosmetic trail sprites and Blender preview."""
import math, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'art/tools/vfx'))
sys.path.insert(0, str(ROOT / 'art/tools/cel'))
import bpy
import vfx_lib as fx
import cel_style as cel

OUT = ROOT / 'game/assets/sprites/cosmetics/sillages/encre'
PREVIEW = ROOT / 'game/assets/sprites/cosmetics/previews/encre.png'
# Desaturated wet ink: black body, blue-gray wet edge, muted haze.
INK = fx.hexc('16120F')
MID = fx.hexc('3A4650')
AMBER = fx.hexc('8FA0AC')
DARK = fx.hexc('090D11')
WORK = ROOT / 'art/renders/sillage_encre'
FADE = [1,1,1,1,1,1,.82,.64,.44,.28,.16,.08,.03,.01,.006,.002]


def setup(w, h, ppu=64):
    s = fx.setup(w, h, ppu=ppu, samples=8)
    s.render.dither_intensity = 0
    s.render.film_transparent = True
    s.view_layers[0].use_pass_normal = False
    return s


def muted_sprite(kind, x, y, w, h, color, alpha, **kw):
    o = fx.sprite(kind, x, y, w, h, color=color, alpha=alpha, **kw)
    if o is None: return
    # Reuse fx_p3.p_ember geometry, with flat unlit pigments and no hot core/glow.
    key = kind + str(color)
    if key not in fx.G['mats']:
        m = o.data.materials[0].copy()
        ns = m.node_tree.nodes
        em = next(n for n in ns if n.type == 'EMISSION')
        for link in list(em.inputs[0].links): m.node_tree.links.remove(link)
        em.inputs[0].default_value = (*fx.lin(color), 1)
        em.inputs[1].default_value = 1
        m['emissive'] = False
        fx.G['mats'][key] = m
    o.data = o.data.copy()
    o.data.materials.clear(); o.data.materials.append(fx.G['mats'][key])
    return o


def p_ember(f, n):
    t = f / (n - 1)
    # Irregular spreading ink blot; taper opacity after the initial splash.
    size = .055 + .11 * min(t * 1.65, 1.0)
    color = INK
    alpha = FADE[f]
    muted_sprite('drop', 0, 0, size, size * 1.2, color, alpha, rot=.35 + .17*f)
    if f >= 2:
        for k in range(5):
            ang = k * math.tau / 5 + .21*f
            r = size * (.38 + .2 * ((k*7+f)%3)/2)
            muted_sprite('disc', math.cos(ang)*r, math.sin(ang)*r, size*.40, size*.34,
                         DARK if k%2 else MID, alpha*.92, rot=ang)


def render_pixels(s, name):
    s.render.filepath = str(WORK / (name + '.png'))
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(s.render.filepath, check_existing=False)
    img.scale(s.render.resolution_x//2, s.render.resolution_y//2)
    w, h = img.size[:]; data = list(img.pixels[:])
    bpy.data.images.remove(img)
    return w, h, data


def save_pixels(name, w, h, pixels):
    # Fix low-alpha render quantization to the three muted cel pigments.
    colors = (INK, MID, DARK, AMBER)
    palette = [fx.lin(c) for c in colors]
    for j in range(0,len(pixels),4):
        if pixels[j+3] > 0:
            rgb = min(palette,key=lambda c:sum((pixels[j+k]-c[k])**2 for k in range(3)))
            pixels[j:j+3] = rgb
        else: pixels[j:j+3] = [0,0,0]
    img = bpy.data.images.new(name, width=w, height=h, alpha=True)
    img.pixels[:] = pixels
    img.filepath_raw = str(OUT / name); img.file_format = 'PNG'; img.save()
    bpy.data.images.remove(img)


def build_particle():
    pix = [0.0] * (128*128*4)
    colors = {c:fx.lin(c) for c in (INK,MID,AMBER,DARK)}
    for f in range(16):
        radius = 3.4 if 2 <= f <= 6 else (2.8 if f < 2 else max(1.2, 3.4*(1-f/16)))
        fade = FADE[f]
        for y in range(32):
            for x in range(32):
                dx,dy=x-15.5,y-15.5
                ang=math.atan2(dy,dx)
                edge=radius*(1+.22*math.sin(5*ang+.7*f)+.12*math.sin(9*ang-f))
                d=math.hypot(dx,dy)
                if d>edge+1.4: continue
                color = AMBER if d>edge-.45 else (MID if d>edge-1.4 else INK)
                a=fade
                ox,oy=(f%4)*32,(3-f//4)*32
                p=((oy+y)*128+ox+x)*4
                pix[p:p+4]=[*colors[color],a]
    save_pixels('particle_32.png',128,128,pix)


def build_step():
    data=[0.0]*(64*64*4); cols={c:fx.lin(c) for c in (INK,MID,AMBER,DARK)}
    for y in range(64):
        for x in range(64):
            dx,dy=x-31.5,y-31.5; a=math.atan2(dy,dx); d=math.hypot(dx,dy)
            edge=10.2*(1+.28*math.sin(5*a)+.14*math.sin(9*a+.4))
            if d>edge+2: continue
            c=AMBER if d>edge-.5 else MID if d>edge-2 else INK
            p=(y*64+x)*4; data[p:p+4]=[*cols[c],1.0]
    save_pixels('step_64.png',64,64,data)


def texture_card(name, image, x, y, w, h, d, uv=(0,0,1,1)):
    m = bpy.data.materials.new(name); m.use_nodes=True
    m.surface_render_method='BLENDED'
    ns=m.node_tree.nodes; ns.clear(); ls=m.node_tree.links
    tex=ns.new('ShaderNodeTexImage'); tex.image=image; tex.interpolation='Closest'
    em=ns.new('ShaderNodeEmission'); em.inputs[1].default_value=1
    tr=ns.new('ShaderNodeBsdfTransparent'); mix=ns.new('ShaderNodeMixShader')
    out=ns.new('ShaderNodeOutputMaterial')
    ls.new(tex.outputs['Color'],em.inputs[0]); ls.new(tex.outputs['Alpha'],mix.inputs[0])
    ls.new(tr.outputs[0],mix.inputs[1]); ls.new(em.outputs[0],mix.inputs[2]); ls.new(mix.outputs[0],out.inputs[0])
    me=bpy.data.meshes.new(name)
    me.from_pydata([(-.5,-.5,0),(.5,-.5,0),(.5,.5,0),(-.5,.5,0)],[],[(0,1,2,3)])
    layer=me.uv_layers.new(); u,v,uw,vh=uv
    for j,co in enumerate([(u,v),(u+uw,v),(u+uw,v+vh),(u,v+vh)]): layer.data[j].uv=co
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    o.rotation_euler=(fx.TILT,0,0); o.location=fx.S(x,y,d); o.scale=(w,h,1)
    me.materials.append(m)
    return o


def build_preview():
    s = setup(256,256,ppu=96)
    s.render.film_transparent=False
    s.world=bpy.data.worlds.new('Encre preview world'); s.world.color=(.045,.055,.06)
    ground=bpy.data.images.load(str(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'))
    for row in range(-2,3):
        for col in range(-2,3):
            texture_card('Terrasses',ground,(col+row)*1.35,(col-row)*.675-.45,2.7,1.35,.4)
    run=bpy.data.images.load(str(ROOT/'game/assets/sprites/characters/ardent/run.png'))
    # Southeast walking pose: column 3, row 1 of the established 8x8 sheet.
    texture_card('Ardent walking',run,.24,.22,1.95,1.95,-.1,(3/8,6/8,1/8,1/8))
    step=bpy.data.images.load(str(OUT/'step_64.png'))
    particle=bpy.data.images.load(str(OUT/'particle_32.png'))
    for j,(x,y) in enumerate([(-.85,-.18),(-.64,-.34),(-.39,-.29),(-.15,-.47)]):
        texture_card('Ink star step',step,x,y,1,1,.1)
        frame=7-j*2
        texture_card('Ink splash',particle,x+.05,y+.09,.5,.5,0,((frame%4)/4,(3-frame//4)/4,.25,.25))
    s.render.filepath=str(PREVIEW); s.render.resolution_x=256; s.render.resolution_y=256
    bpy.ops.render.render(write_still=True)


def write_tres():
    p=OUT/'encre.tres'
    particle_frames=', '.join('{"duration": 1.0, "texture": SubResource("AtlasTexture_particle_%d")}'%i for i in range(16))
    lines=['[gd_resource type="SpriteFrames" load_steps=20 format=3]', '', '[ext_resource type="Texture2D" path="res://assets/sprites/cosmetics/sillages/encre/particle_32.png" id="1"]', '[ext_resource type="Texture2D" path="res://assets/sprites/cosmetics/sillages/encre/step_64.png" id="2"]', '', '[resource]', 'animations = [{"frames": ['+particle_frames+'], "loop": false, "name": &"particle", "speed": 24.0}, {"frames": [{"duration": 1.0, "texture": SubResource("AtlasTexture_step")}], "loop": false, "name": &"step", "speed": 1.0}]']
    for i in range(16):
        lines += ['', f'[sub_resource type="AtlasTexture" id="AtlasTexture_particle_{i}"]', 'atlas = ExtResource("1")', f'region = Rect2({(i%4)*32}, {(i//4)*32}, 32, 32)']
    lines += ['', '[sub_resource type="AtlasTexture" id="AtlasTexture_step"]', 'atlas = ExtResource("2")', 'region = Rect2(0, 0, 64, 64)', '']
    resource = lines[5:7]
    lines = lines[:5] + lines[7:] + [''] + resource
    text = '\n'.join(lines)
    if not p.exists() or p.read_text(encoding='utf-8') != text: p.write_text(text,encoding='utf-8')

def main():
    OUT.mkdir(parents=True,exist_ok=True); PREVIEW.parent.mkdir(parents=True,exist_ok=True)
    WORK.mkdir(parents=True,exist_ok=True)
    cel.install('vfx', normals=False)
    build_particle(); build_step(); build_preview(); write_tres()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/sillage_encre.blend'))
    print('ENCRE_BUILD_OK particle=128x128 step=64x64 preview=256x256 frames=16')

if __name__=='__main__': main()
