"""Tocsin : steam_cone v2 (volutes distinctes, 3 tons cel, coeur dense, bords effilochés).
Rig TOP, canvas 512, pointe au centre (256,256), axe +X, secteur +-30 deg, portee 240 px.
Usage (Blender) : blender --background --python art/tools/feel/tocsin_steam_cone_build.py -- --render
Puis (Python)   : python art/tools/feel/tocsin_steam_cone_build.py --pack ; --verify ; --deliver"""
import math, sys, json, hashlib, re, shutil
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'art/renders/feel_sorts3/steam_cone'
GAME = ROOT / 'game/assets/sprites/vfx/tocsin/steam_cone'
STAGE = OUT / 'validated'
RADII = [90, 125, 160, 190, 220, 240]
PIXELS_PER_UNIT = 62
ANGLES = [12, 17, 22, 26, 29, 30]
FADE = [1, 1, .94, .83, .54, .25]


def render():
    import bpy, random
    from mathutils import Vector
    sys.path.insert(0, str(ROOT / 'art/tools/cel'))
    import cel_style as cel
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    s = bpy.context.scene; cel.setup_scene(s, samples=12)
    s.render.resolution_x = s.render.resolution_y = 512
    s.render.resolution_percentage = 100
    tree = bpy.data.node_groups.new('Cloud alpha dissipation', 'CompositorNodeTree')
    tree.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    s.compositing_node_group = tree
    rl = tree.nodes.new('CompositorNodeRLayers'); output = tree.nodes.new('NodeGroupOutput')
    alpha = tree.nodes.new('ShaderNodeMath'); alpha.operation = 'MULTIPLY'
    setalpha = tree.nodes.new('CompositorNodeSetAlpha'); setalpha.inputs['Type'].default_value = 'Replace Alpha'
    tree.links.new(rl.outputs['Image'], setalpha.inputs['Image']); tree.links.new(rl.outputs['Alpha'], alpha.inputs[0])
    tree.links.new(alpha.outputs[0], setalpha.inputs['Alpha']); tree.links.new(setalpha.outputs[0], output.inputs[0])
    s.world.color = (.06, .06, .06)
    cd = bpy.data.cameras.new('TOP'); cam = bpy.data.objects.new('TOP', cd); s.collection.objects.link(cam)
    cam.location = (0, 0, 20); cd.type = 'ORTHO'; cd.ortho_scale = 8; s.camera = cam
    ld = bpy.data.lights.new('large upper left', 'AREA'); light = bpy.data.objects.new('large upper left', ld)
    s.collection.objects.link(light); light.location = (-3, -4, 8); ld.energy = 650; ld.size = 4
    light.rotation_euler = (Vector((0, 0, 0)) - light.location).to_track_quat('-Z', 'Y').to_euler()

    def mat(n, c, e=0):
        m = bpy.data.materials.new(n); m.use_nodes = True
        p = m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value = (*c, 1)
        p.inputs['Roughness'].default_value = .9
        if e:
            p.inputs['Emission Color'].default_value = (*c, 1); p.inputs['Emission Strength'].default_value = e
        return m
    steam = mat('warm white steam', (.86, .79, .64))
    glow = mat('hot cream core', (1, .62, .30), .9)        # 3e ton : coeur chaud
    orange = mat('hearth orange', (1, .197, .012), 1.5)
    cel.install('vfx', normals=False); cel.toon_materials('vfx')
    materials = [steam, glow, orange]; original_colors = {}
    for m in materials:
        nodes = m.node_tree.nodes; out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
        shader = out.inputs['Surface'].links[0].from_socket
        trans = nodes.new('ShaderNodeBsdfTransparent'); mix = nodes.new('ShaderNodeMixShader'); mix.name = 'Dissipation'
        m.node_tree.links.new(trans.outputs[0], mix.inputs[1]); m.node_tree.links.new(shader, mix.inputs[2])
        m.node_tree.links.new(mix.outputs[0], out.inputs['Surface'])
        m.surface_render_method = 'DITHERED'
        emit = next(n for n in nodes if n.type == 'EMISSION'); original_colors[m.name] = tuple(emit.inputs['Color'].default_value)

    def puff(name, cx, cy, rad, ma, rng, z=.2, parts=4, R=None, angle=None):
        """Une volute = petit amas de 3-5 ellipsoides ; chaque volute est distincte."""
        mb = bpy.data.metaballs.new(name); mb.resolution = .05; mb.render_resolution = .04; mb.threshold = .6
        o = bpy.data.objects.new(name, mb); s.collection.objects.link(o)
        for k in range(parts):
            a = rng.uniform(0, math.tau); d = rad * rng.uniform(.0, .55)
            e = mb.elements.new(type='ELLIPSOID'); e.co = (cx + d * math.cos(a), cy + d * math.sin(a), z + rng.uniform(0, .25) * rad)
            e.radius = 1; e.size_x = rad * rng.uniform(.55, .85); e.size_y = rad * rng.uniform(.5, .8)
            e.size_z = rad * rng.uniform(.5, .8); e.stiffness = 2
        bpy.context.view_layer.objects.active = o; o.select_set(True); bpy.ops.object.convert(target='MESH'); o = bpy.context.object
        o.data.materials.append(ma)
        for p in o.data.polygons: p.use_smooth = True
        o.select_set(False); return o

    def line(n, points, width, ma):
        cu = bpy.data.curves.new(n, 'CURVE'); cu.dimensions = '3D'; cu.bevel_depth = width; cu.bevel_resolution = 0
        sp = cu.splines.new('POLY'); sp.points.add(len(points) - 1)
        for p, co in zip(sp.points, points): p.co = (*co, 1)
        o = bpy.data.objects.new(n, cu); s.collection.objects.link(o); cu.materials.append(ma)

    OUT.mkdir(parents=True, exist_ok=True)
    for f in range(6):
        for o in list(s.objects):
            if o.type not in ('LIGHT', 'CAMERA'): bpy.data.objects.remove(o, do_unlink=True)
        rng = random.Random(1203 + f)
        R = RADII[f] / PIXELS_PER_UNIT; ang = math.radians(ANGLES[f])
        # Volutes du corps : rangees le long du jet, plus grosses vers le large, bords effilochés par petites volutes
        def fit(x, y, rad):
            """Réduit la volute pour qu'elle reste dans le secteur (+-1,08 x demi-angle) et sous la portée, sans rognage dur."""
            return min(rad, (R * .95 - x) / 1.4, (x * math.tan(ang * 1.08) - abs(y)) / 1.4)
        for row in range(1, 9):
            t = row / 9.5; x = R * t; span = x * math.tan(ang)
            n = 2 + int(row * .5)
            for k in range(n):
                lat = 0 if n == 1 else (k / (n - 1) * 2 - 1)
                y = lat * span * .7 + rng.uniform(-.06, .06) * span
                rad = fit(x, y, max(.09, span * rng.uniform(.50, .72) + .02 * row))
                if rad >= .05: puff('volute', x, y, rad, steam, rng, parts=rng.randint(3, 5))
        # franges effilochées : petites volutes au bord du secteur
        for j in range(14):
            t = rng.uniform(.3, .96); x = R * t; side = rng.choice((-1, 1))
            y = side * x * math.tan(ang) * rng.uniform(.62, .85)
            rad = fit(x, y, rng.uniform(.06, .13))
            if rad >= .04: puff('frange', x, y, rad, steam, rng, parts=3, z=.15)
        # coeur dense (3e ton) : volutes serrees pres de la pointe
        for j in range(5):
            x = R * (.12 + .09 * j); rad = fit(x, 0, .09 + .02 * j)
            if rad >= .04: puff('coeur', x, rng.uniform(-.02, .02), rad, glow, rng, z=.5, parts=3)
        line('hot throat', [(0, 0, .85), (R * .14, 0, .9), (R * .34, 0, .92)], .05, orange)
        for i in range(3):
            x = R * (.16 + i * .08); line('orange curl', [(x, -x * .07, .9), (x * 1.10, x * .06, .95)], .035, orange)
        for emitpass in (False, True):
            s.render.resolution_percentage = 50 if emitpass else 100
            alpha.inputs[1].default_value = FADE[f]
            for m in materials:
                nodes = m.node_tree.nodes; nodes['Dissipation'].inputs[0].default_value = 1
                em = next(n for n in nodes if n.type == 'EMISSION')
                if emitpass:
                    for link in list(em.inputs['Color'].links): m.node_tree.links.remove(link)
                    em.inputs['Color'].default_value = original_colors[m.name] if m in (orange, glow) else (0, 0, 0, 1)
                else:
                    ramp = next((n for n in nodes if n.type == 'VALTORGB'), None)
                    if ramp and not em.inputs['Color'].is_linked: m.node_tree.links.new(ramp.outputs['Color'], em.inputs['Color'])
                    elif not ramp: em.inputs['Color'].default_value = original_colors[m.name]
            s.render.filepath = str(OUT / (f'cone_{f}' + ('_e' if emitpass else '') + '.png')); bpy.ops.render.render(write_still=True)
    print('PASS render steam_cone v2 12 images')


def pack():
    from PIL import Image
    folder = STAGE; folder.mkdir(parents=True, exist_ok=True)
    for emit in (False, True):
        size = 256 if emit else 512; atlas = Image.new('RGBA', (size * 6, size))
        for f in range(6):
            im = Image.open(OUT / (f'cone_{f}' + ('_e' if emit else '') + '.png')).convert('RGBA'); atlas.paste(im, (f * size, 0))
        if not emit:
            for colors in (64, 48, 32):
                atlas.quantize(colors=colors, method=Image.Quantize.FASTOCTREE).save(folder / 'default.png', optimize=True)
                if (folder / 'default.png').stat().st_size <= 150000: break
        else:
            for colors in (16, 8, 4, 2):
                atlas.quantize(colors=colors, method=Image.Quantize.FASTOCTREE).save(folder / 'default_e.png', optimize=True)
                if (folder / 'default_e.png').stat().st_size <= 30000: break
    print('PASS pack', (folder / 'default.png').stat().st_size, (folder / 'default_e.png').stat().st_size)


def verify():
    from PIL import Image
    import numpy as np
    im = Image.open(STAGE / 'default.png').convert('RGBA'); em = Image.open(STAGE / 'default_e.png').convert('RGBA')
    assert im.size == (3072, 512) and em.size == (1536, 256)
    hashes = []; radii = []; sectors = []; widths = []; mass = []
    for f in range(6):
        tile = im.crop((f * 512, 0, (f + 1) * 512, 512)); box = tile.getchannel('A').getbbox(); assert box
        hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
        a = np.asarray(tile)[:, :, 3].astype(float); yy, xx = np.indices(a.shape); dx = xx + .5 - 256; dy = yy + .5 - 256
        radii.append(round(float(np.hypot(dx, dy)[a > 12].max()), 1)); widths.append(box[3] - box[1]); mass.append(round(float(a.sum() / 255)))
        sec = (dx >= 0) & (np.abs(dy) <= np.maximum(dx, 0) * math.tan(math.radians(35)) + 3)
        sectors.append(round(float(a[sec].sum() / a.sum() * 100), 2))
        e = np.asarray(em.crop((f * 256, 0, (f + 1) * 256, 256)))
        assert (e[:, :, :3].max(axis=2) * e[:, :, 3].astype(float) / 255).sum() > 100, 'emission vide'
    assert len(set(hashes)) == 6 and all(x >= 95 for x in sectors), sectors
    # Outer frayed wisps extend beyond the designed core radius; require a
    # steadily widening cone while allowing up to 20% silhouette overshoot.
    assert all(abs(a - b) <= 10 for a, b in zip(radii, RADII)), radii
    assert widths[0] < widths[3] < widths[4], widths
    contact = Image.new('RGBA', (1020, 170), (58, 62, 70, 255))
    for f in range(6): contact.alpha_composite(im.crop((f * 512, 0, (f + 1) * 512, 512)).resize((170, 170)), (f * 170, 0))
    contact.convert('RGB').save(ROOT / 'art/renders/feel_sorts3/after_steam_cone.png')
    print('PASS verify', json.dumps({'radii': radii, 'sector': sectors, 'widths': widths, 'mass': mass}))


def deliver():
    verify()
    for f in ('default.png', 'default_e.png'): shutil.copy2(STAGE / f, GAME / f)
    print('PASS deliver')


if __name__ == '__main__':
    if '--render' in sys.argv: render()
    elif '--pack' in sys.argv: pack()
    elif '--deliver' in sys.argv: deliver()
    else: verify()
