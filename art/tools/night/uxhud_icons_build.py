"""HUD gold/pause only. Blender background, then system Python --verify.

Geometry helpers reused from ui_kit; Pillow only resizes/assembles/checks.
"""
from pathlib import Path
import sys
import json
import hashlib
import shutil

ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / 'art/renders/ui/uxhud_icons'
TARGETS = {'da/icon_gold.png': 64, 'hud/icon_gold.png': 128,
           'da/icon_pause.png': 96, 'hud/icon_pause.png': 128}


def protected():
    paths = list((ROOT / 'game/assets/sprites/icons/spells').rglob('*'))
    paths += [p for p in (ROOT / 'game').rglob('*') if p.suffix in ('.gd', '.tscn', '.tres')]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in paths if p.is_file()}


def render():
    import bpy
    import math
    sys.path[:0] = [str(ROOT / 'art/tools/ui'), str(ROOT / 'art/tools/cel')]
    import ui_kit as kit
    import cel_style as cel
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / 'protected.json').write_text(json.dumps(protected()))
    for rel in TARGETS:
        src = ROOT / 'game/assets/sprites/ui' / rel
        archive = ROOT / 'art/archive_3d/sprites/ui' / rel
        if not archive.exists():
            archive.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, archive)

    # Explicit lot requirement overrides the shared icon profile locally only.
    cel.PROFILES['icon'].update(tones=2, ink_px=1.5)
    cel.install('icon', normals=False)

    def color(h):
        m = kit.mat(h, .4, .7)
        bsdf = m.node_tree.nodes.get('Principled BSDF')
        rgb = kit.rgba(h)
        # High cel plateau reproduces the requested sRGB palette exactly.
        bsdf.inputs['Base Color'].default_value = tuple(c / cel.TONE_SCALES[2] for c in rgb[:3]) + (1,)
        return m

    def diffuse_only(path):
        # Same base compositor as boss_common, without screen-space normals
        # or emission outputs: this lot delivers neither companion file.
        s = bpy.context.scene
        tree = bpy.data.node_groups.new('UXHUD diffuse only', 'CompositorNodeTree')
        s.compositing_node_group = tree
        tree.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
        rl = tree.nodes.new('CompositorNodeRLayers')
        out = tree.nodes.new('NodeGroupOutput')
        tree.links.new(rl.outputs['Image'], out.inputs['Image'])

    for name in ('gold', 'pause'):
        kit.reset_scene()
        s = bpy.context.scene
        cel.setup_scene(samples=8)
        s.render.resolution_x = s.render.resolution_y = 256
        s.render.resolution_percentage = 100
        s.render.image_settings.color_depth = '8'
        s.view_settings.look = 'None'
        s.world.color = (.04, .04, .04)
        cam = bpy.data.objects.new('UXHUD orthographic', bpy.data.cameras.new('UXHUD orthographic'))
        s.collection.objects.link(cam)
        s.camera = cam
        cam.data.type = 'ORTHO'
        cam.data.ortho_scale = 2.22
        cam.location = (0, -10, 0)
        kit.aim(cam, (0, 0, 0))
        for label, position, energy, tint in (
                ('warm upper left', (-3, -4, 5), 6, (1, .88, .70)),
                ('cool fill', (4, -1, 2), .35, (.65, .78, 1))):
            light = bpy.data.objects.new(label, bpy.data.lights.new(label, 'SUN'))
            s.collection.objects.link(light)
            light.location = position
            light.data.energy = energy
            light.data.color = tint
            light.data.angle = .15
            kit.aim(light, (0, 0, 0))
        pale, gold = color('#E8E2D6'), color('#F2C14E')
        shadow = color('#D0A13F')
        if name == 'gold':
            # Pale 2 px visible border at 64 px, after internal cel ink.
            kit.flat_disk((0, .025, 0), 1, .15, pale)
            kit.flat_disk((0, -.08, 0), .878, .09, gold)
            kit.torus((0, -.138, 0), .79, .012, shadow)
            diamond = [(0, .48), (-.32, 0), (0, -.48), (.32, 0)]
            kit.slab(diamond, shadow, .055, -.155, .025, 'Minted diamond recess')
            kit.slab([(0, .36), (-.22, 0), (0, -.36), (.22, 0)], gold,
                     .05, -.195, .022, 'Raised gold mint')
            for i in range(8):
                t = math.tau * i / 8
                o = kit.slab(kit.rrect(.045, .09, .015, 3), shadow,
                             .012, -.14, .003, 'Mint notch')
                o.location.x, o.location.z = .71 * math.sin(t), .71 * math.cos(t)
                o.rotation_euler.y = t
            # Single small integrated luminous accent, upper-left rim only.
            pts = [(.945 * math.cos(t), -.10, .945 * math.sin(t))
                   for t in [math.radians(104 + i * 3) for i in range(18)]]
            kit.curve(pts, .018, kit.mat('#FFF2D6', emit_hex='#FFF2D6', emit_strength=1))
        else:
            for x in (-.37, .37):
                obj = kit.slab(kit.rrect(.40, 1.62, .12, 12), pale,
                               .18, 0, .025, 'Rounded pause bar')
                obj.location.x = x
            # Restrained integrated upper-left accent on the two-bar symbol.
            kit.curve([(-.50, -.115, .64), (-.49, -.115, .70), (-.44, -.115, .72)],
                      .012, kit.mat('#FFF2D6', emit_hex='#FFF2D6', emit_strength=1))
        cel.toon_materials('icon')
        out = WORK / ('icon_' + name + '.png')
        cel.cel_passes(out, 'icon', base_configure=diffuse_only, normals=False)
        assert not any(n.bl_idname == 'CompositorNodeOutputFile' for n in s.compositing_node_group.nodes)
        s.render.filepath = str(out)
        bpy.ops.render.render(write_still=True)
    # Contact-only circular button, drawn by Blender, never delivered in game/.
    kit.reset_scene()
    s = bpy.context.scene
    cam = bpy.data.objects.new('Contact camera', bpy.data.cameras.new('Contact camera'))
    s.collection.objects.link(cam)
    s.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 2.1
    cam.location = (0, -10, 0)
    kit.aim(cam, (0, 0, 0))
    m = bpy.data.materials.new('Contact button sRGB #1D1D28')
    m.use_nodes = True
    nodes = m.node_tree.nodes
    nodes.clear()
    emit = nodes.new('ShaderNodeEmission')
    emit.inputs['Color'].default_value = kit.rgba('#1D1D28')
    output = nodes.new('ShaderNodeOutputMaterial')
    m.node_tree.links.new(emit.outputs[0], output.inputs['Surface'])
    kit.flat_disk((0, 0, 0), 1, .01, m)
    diffuse_only(None)
    s.render.filepath = str(WORK / 'contact_button.png')
    bpy.ops.render.render(write_still=True)
    print('PASS Blender Eevee 8 samples; icon 2 tones; ink 1.5 px; diffuse only')


def verify():
    import numpy as np
    from PIL import Image
    baseline = json.loads((WORK / 'protected.json').read_text())
    current = protected()
    concurrent = [p for p in baseline.keys() | current.keys() if baseline.get(p) != current.get(p)]
    assert not any('icons\\spells\\' in p for p in concurrent), 'spell icons changed concurrently'
    rows = []
    for rel, size in TARGETS.items():
        src = Image.open(WORK / Path(rel).name).convert('RGBA')
        image = src.resize((size, size), Image.Resampling.LANCZOS)
        out = ROOT / 'game/assets/sprites/ui' / rel
        image.save(out, optimize=True, compress_level=9)
        assert image.size == (size, size) and image.mode == 'RGBA'
        assert image.getchannel('A').getextrema() == (0, 255)
        assert not out.with_stem(out.stem + '_n').exists()
        assert not out.with_stem(out.stem + '_e').exists()
        rows.append((rel, image))

    def srgb_to_linear(rgb):
        c = np.asarray(rgb, dtype=float) / 255
        return np.where(c <= .04045, c / 12.92, ((c + .055) / 1.055) ** 2.4)

    def linear_to_srgb(c):
        return np.where(c <= .0031308, c * 12.92, 1.055 * np.maximum(c, 0) ** (1 / 2.4) - .055)

    def luminance(rgb):
        return srgb_to_linear(rgb) @ np.array([.2126, .7152, .0722])

    # Rendered sRGB captures, with the UI alpha layered on the darkest and
    # lightest requested backdrops. Lighter backdrop is the limiting case.
    terrain = (34, 34, 43)
    plate = tuple(round(.55 * c + .45 * t) for c, t in zip((20, 17, 12), terrain))
    button = tuple(round(.6 * c + .4 * t) for c, t in zip((26, 26, 38), terrain))
    backgrounds = [('plate', plate), ('button', button)]
    cell = 168
    button_image = Image.open(WORK / 'contact_button.png').convert('RGBA')
    contact = Image.new('RGBA', (cell * 6, cell * 4), (12, 10, 8, 255))
    results = []
    for row, (rel, image) in enumerate(rows):
        for bgidx, (label, bg) in enumerate(backgrounds):
            for col, size in enumerate((40, 64, 128)):
                icon = image.resize((size, size), Image.Resampling.LANCZOS)
                tile = Image.new('RGBA', (cell, cell), (*(terrain if label == 'button' else bg), 255))
                if label == 'button':
                    diameter = min(cell, round(size * 1.3))
                    circle = button_image.resize((diameter, diameter), Image.Resampling.LANCZOS)
                    tile.alpha_composite(circle, ((cell-diameter)//2, (cell-diameter)//2))
                tile.alpha_composite(icon, ((cell-size)//2, (cell-size)//2))
                contact.paste(tile, ((bgidx*3+col)*cell, row*cell))
                raw = np.asarray(icon).astype(float)
                a = raw[..., 3:4] / 255
                # UI alpha compositing in the sRGB capture; explicit roundtrip
                # verifies the linear_to_srgb transform and WCAG luminance.
                start = (cell-size)//2
                capture = np.asarray(tile)[start:start+size, start:start+size, :3].astype(float)
                assert np.max(np.abs(linear_to_srgb(srgb_to_linear(capture))*255-capture)) < 1e-8
                ratios = (luminance(capture)+.05)/(luminance(bg)+.05)
                opaque = raw[..., 3] >= 250
                readable_fraction = float((opaque & (ratios >= 3)).sum() / opaque.sum())
                assert readable_fraction >= .85, (rel, size, label, 'readable area', readable_fraction)
                # Measure flat cel interiors, excluding anti-aliasing and the
                # prescribed dark ink. Selection does not use contrast/value.
                rgb = raw[..., :3]
                stable = np.ones(opaque.shape, dtype=bool)
                for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                    stable &= np.max(np.abs(rgb-np.roll(rgb, (dy, dx), axis=(0, 1))), axis=2) <= 2
                ink = np.max(np.abs(rgb-np.array((24, 18, 16))), axis=2) <= 4
                fill = opaque & stable & ~ink
                assert fill.sum() >= .10 * opaque.sum(), (rel, size, 'insufficient flat samples')
                minimum = float(ratios[fill].min())
                assert minimum >= 3, (rel, size, label, minimum)
                mean = float(raw[..., :3][fill].mean())
                if 'pause' in rel:
                    assert float(raw[..., :3][opaque].mean()) >= 150
                results.append(dict(file=rel, size=size, background=label, srgb_background=bg,
                                    contrast_min=round(minimum, 3), fill_fraction=round(float(fill.sum()/opaque.sum()), 3),
                                    readable_opaque_fraction=round(readable_fraction, 3),
                                    opaque_mean=round(float(raw[..., :3][opaque].mean()), 2),
                                    fill_mean=round(mean, 2)))
    path = ROOT / 'art/tools/night/_uxhud_icons_contact.png'
    contact.save(path, optimize=True, compress_level=9)
    report = dict(status='PASS', concurrent_protected_changes=concurrent,
                  method='WCAG sRGB capture, flat cel interiors, alpha >=250; prescribed dark ink and anti-aliasing excluded',
                  layout='rows da gold / hud gold / da pause / hud pause; columns plate 40/64/128, button 40/64/128',
                  results=results)
    (ROOT / 'art/tools/night/_uxhud_icons_verification.json').write_text(json.dumps(report, indent=2) + '\n')
    for name in ('gold', 'pause'):
        minimum = min(r['contrast_min'] for r in results if name in r['file'])
        print(f'PASS {name}: minimum contrast {minimum:.3f}:1; 40/64/128 px; 2 backgrounds')
    print('PASS 4 RGBA sizes; spell icons unchanged; no code/resource output; no _n/_e; optimized PNG')


if __name__ == '__main__':
    verify() if '--verify' in sys.argv else render()
