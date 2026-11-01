"""Build the Braises cosmetic trail sprites and Blender preview."""
import math, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'art/tools/vfx'))
sys.path.insert(0, str(ROOT / 'art/tools/cel'))
import bpy
import vfx_lib as fx
import cel_style as cel

OUT = ROOT / 'game/assets/sprites/cosmetics/sillages/braises'
PREVIEW = ROOT / 'game/assets/sprites/cosmetics/previews/braises.png'
# Bright amber embers, fading through orange to coal.
INK = fx.hexc('5A3418')
MID = fx.hexc('C8782E')
AMBER = fx.hexc('FFC878')
WORK = ROOT / 'art/renders/sillage_braises'
FADE = [1, .96, .92, .88, .82, .80, .68, .55, .38, .15, .10, .06, .03, .015, .008, .006]


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
    rise = .09375 * min(f, 9) / 9  # exactly six pixels, then extinction
    size = .125 * (1 - .28*t)
    pigment = AMBER if f < 4 else MID if f < 9 else INK
    muted_sprite('spark', 0, rise, size*.9, size*.62, pigment, FADE[f], rot=1.15)


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
    palette = [fx.lin(c) for c in (INK, MID, AMBER)]
    for j in range(0,len(pixels),4):
        if pixels[j+3] > 0:
            rgb = min(palette,key=lambda c:sum((pixels[j+k]-c[k])**2 for k in range(3)))
            pixels[j:j+3] = (INK, MID, AMBER)[palette.index(rgb)]
        else: pixels[j:j+3] = [0,0,0]
    img = bpy.data.images.new(name, width=w, height=h, alpha=True)
    img.pixels[:] = pixels
    img.filepath_raw = str(OUT / name); img.file_format = 'PNG'; img.save()
    bpy.data.images.remove(img)


def build_particle():
    pix = [0.0] * (128*128*4)
    for i in range(16):
        s = setup(32, 32)
        p_ember(i, 16)
        w, h, data = render_pixels(s, 'frame_%02d'%i)
        ox, oy = (i%4)*32, (3-i//4)*32  # Blender image pixels are bottom-up
        for y in range(32):
            for x in range(32):
                src = (y*32+x)*4; dst = ((oy+y)*128+ox+x)*4
                rgba = data[src:src+4]
                rgba[3] = min(1.0, rgba[3])
                if rgba[3] < .5/255: rgba = [0,0,0,0]
                pix[dst:dst+4] = rgba
    save_pixels('particle_32.png',128,128,pix)


def build_step():
    s = setup(64,64)
    muted_sprite('disc',0,0,.19,.14,MID,.68)
    muted_sprite('disc',-.018,.005,.11,.075,AMBER,.50,d=.01)
    w,h,data = render_pixels(s,'step')
    for j in range(3,len(data),4): data[j] = min(1.0,data[j])
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
    s.world=bpy.data.worlds.new('Braises preview world'); s.world.color=(.045,.055,.06)
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
        texture_card('Ash step',step,x,y,1,1,.1)
        frame=7-j*2
        texture_card('Amber ember',particle,x+.05,y+.09,.5,.5,0,((frame%4)/4,(3-frame//4)/4,.25,.25))
    s.render.filepath=str(PREVIEW); s.render.resolution_x=256; s.render.resolution_y=256
    bpy.ops.render.render(write_still=True)


def write_tres():
    p=OUT/'braises.tres'
    particle_frames=', '.join('{"duration": 1.0, "texture": SubResource("AtlasTexture_particle_%d")}'%i for i in range(16))
    lines=['[gd_resource type="SpriteFrames" load_steps=20 format=3]', '', '[ext_resource type="Texture2D" path="res://assets/sprites/cosmetics/sillages/braises/particle_32.png" id="1"]', '[ext_resource type="Texture2D" path="res://assets/sprites/cosmetics/sillages/braises/step_64.png" id="2"]', '', '[resource]', 'animations = [{"frames": ['+particle_frames+'], "loop": false, "name": &"particle", "speed": 24.0}, {"frames": [{"duration": 1.0, "texture": SubResource("AtlasTexture_step")}], "loop": false, "name": &"step", "speed": 1.0}]']
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
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/sillage_braises.blend'))
    print('BRAISES_BUILD_OK particle=128x128 step=64x64 preview=256x256 frames=16')

if __name__=='__main__': main()
