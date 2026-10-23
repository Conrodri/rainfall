"""CS1: original C4/A2/C5 geometry and timelines, Eevee ink/cel variants.

Run with system Python (driver), or Blender --background --python this_file -- --render.
Pillow only crops, assembles and verifies. All shading/ink/normal quantization is Blender.
"""
import sys, json, hashlib, re, subprocess
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
WORK = ROOT / 'art/blender/cel'
RAW = WORK / 'frames'
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
DIRS = ['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne']
SPECS = {
    'ardent': dict(folder='characters/ardent', cell=192, root='Ardent_Root',
        sources=[('characters/ardent_iso.blend', {'idle': (1, 8), 'run': (21, 8)}),
                 ('characters/ardent_a2.blend', {'attack': (41, 5), 'cast': (61, 6), 'cast_ult': (81, 8)})]),
    'swarm_tier1': dict(folder='monsters/swarm_tier1', cell=96, root='swarm_tier1',
        sources=[('monsters/swarm_tier1_iso.blend', {'run': (1, 8)})]),
    'brute_tier3': dict(folder='monsters/brute_tier3', cell=160, root='brute_tier3',
        sources=[('monsters/brute_tier3_iso.blend', {'run': (1, 8), 'attack': (17, 8), 'cast': (33, 8)})]),
}


def folder(spec, cel=False):
    return ROOT / 'game/assets/sprites' / (spec['folder'] + ('_cel' if cel else ''))


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def protected():
    paths = []
    for spec in SPECS.values():
        paths.extend(p for p in folder(spec).iterdir() if p.is_file())
        paths.extend(ROOT / 'art/blender' / src for src, _ in spec['sources'])
    return {str(p.relative_to(ROOT)): sha(p) for p in paths}


def baseline():
    path = HERE / '_cs1_baseline.json'
    if not path.exists():
        path.write_text(json.dumps(protected(), indent=2))
    assert json.loads(path.read_text()) == protected(), 'Original files changed'


def toon_materials():
    import bpy
    palettes = {}
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        p = next((n for n in nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if p is None:
            continue
        base = tuple(p.inputs['Base Color'].default_value)
        ramps = [n for n in nodes if n.type == 'VALTORGB']
        # Read the exact PBR palette; discard its procedural grunge, not its hue.
        if ramps:
            ramp = ramps[0].color_ramp
            dark, light = tuple(ramp.elements[0].color), tuple(ramp.elements[-1].color)
            base = tuple(dark[i] * .30 + light[i] * .70 for i in range(3)) + (1,)
        glow = tuple(p.inputs['Emission Color'].default_value)
        strength = p.inputs['Emission Strength'].default_value
        luminous = strength > .01 and (bool(mat.get('rainfall_emissive')) or not ramps)
        nodes.clear()
        output = nodes.new('ShaderNodeOutputMaterial')
        emit = nodes.new('ShaderNodeEmission')
        accent = nodes.new('ShaderNodeOutputAOV'); accent.aov_name = 'CS1_Accent'
        accent.inputs['Color'].default_value = tuple(c * strength for c in glow[:3]) + (1,) if luminous else (0, 0, 0, 1)
        if luminous:
            emit.inputs['Color'].default_value = glow
            emit.inputs['Strength'].default_value = strength
        else:
            diffuse = nodes.new('ShaderNodeBsdfDiffuse')
            diffuse.inputs['Color'].default_value = (.72, .72, .72, 1)
            diffuse.inputs['Roughness'].default_value = 0
            rgb = nodes.new('ShaderNodeShaderToRGB')
            links.new(diffuse.outputs[0], rgb.inputs[0])
            ramp = nodes.new('ShaderNodeValToRGB'); ramp.name = 'CS1 three ink wash tones'
            ramp.color_ramp.interpolation = 'CONSTANT'
            # Lift the shadow floor in linear light: visible on the actual night ground.
            # Preserve the bronze/umber/slate hue and keep recess materials recessed.
            luma = sum(base[i] * w for i, w in enumerate((.2126, .7152, .0722)))
            lift = max(1, .040 / max(luma, .0001))
            base = tuple(min(.72, c * lift) for c in base[:3])
            colors = [tuple(c * scale for c in base) + (1,) for scale in (.63, 1.12, 1.65)]
            ramp.color_ramp.elements[0].position = 0
            ramp.color_ramp.elements[0].color = colors[0]
            ramp.color_ramp.elements[1].position = .34
            ramp.color_ramp.elements[1].color = colors[1]
            ramp.color_ramp.elements.new(.70).color = colors[2]
            links.new(rgb.outputs['Color'], ramp.inputs['Fac'])
            links.new(ramp.outputs['Color'], emit.inputs['Color'])
            palettes[mat.name] = [list(c) for c in colors]
        links.new(emit.outputs[0], output.inputs['Surface'])
    return palettes


def compositor(path):
    """Extend the original normal-space/file-output pipeline, at its original 2x size."""
    import bpy, iso_rig
    iso_rig.common.configure_passes(path)
    s = bpy.context.scene
    tree = getattr(s, 'node_tree', None) or s.compositing_node_group
    nodes, links = tree.nodes, tree.links
    rl = next(n for n in nodes if n.bl_idname == 'CompositorNodeRLayers')
    output = next(n for n in nodes if n.bl_idname == 'NodeGroupOutput')

    def mathnode(op, a=None, b=None):
        n = nodes.new('ShaderNodeMath'); n.operation = op
        for i, value in enumerate((a, b)):
            if value is None:
                continue
            if isinstance(value, (float, int)):
                n.inputs[i].default_value = value
            else:
                links.new(value, n.inputs[i])
        return n.outputs[0]

    # Three signed component plateaus, then normalize: a finite screen-space palette.
    quant = nodes.new('ShaderNodeCombineXYZ')
    dots = [n for n in nodes if n.bl_idname == 'ShaderNodeVectorMath' and n.operation == 'DOT_PRODUCT']
    for i, dot in enumerate(dots):
        q = mathnode('ROUND', dot.outputs['Value'])
        links.new(q, quant.inputs[i])
    unit = nodes.new('ShaderNodeVectorMath'); unit.operation = 'NORMALIZE'
    links.new(quant.outputs[0], unit.inputs[0])
    encoded = nodes.new('ShaderNodeVectorMath'); encoded.operation = 'MULTIPLY_ADD'
    links.new(unit.outputs[0], encoded.inputs[0])
    encoded.inputs[1].default_value = (.5, .5, .5)
    encoded.inputs[2].default_value = (.5, .5, .5)
    normals = nodes.new('CompositorNodeSetAlpha'); normals.inputs['Type'].default_value = 'Replace Alpha'
    links.new(encoded.outputs['Vector'], normals.inputs['Image'])
    links.new(rl.outputs['Alpha'], normals.inputs['Alpha'])
    for n in list(nodes):
        if n.bl_idname != 'CompositorNodeOutputFile':
            continue
        name = n.file_name if hasattr(n, 'file_name') else n.file_slots[0].path
        if '_n__' in name:
            links.new(normals.outputs[0], n.inputs[0])
        elif '_e__' in name:
            alpha = nodes.new('CompositorNodeSetAlpha'); alpha.inputs['Type'].default_value = 'Replace Alpha'
            links.new(rl.outputs['CS1_Accent'], alpha.inputs['Image'])
            links.new(rl.outputs['Alpha'], alpha.inputs['Alpha'])
            links.new(alpha.outputs[0], n.inputs[0])

    # Ink is an inward compositor stroke: exact original silhouette and foot anchor.
    erode = nodes.new('CompositorNodeDilateErode'); erode.inputs['Type'].default_value = 'Distance'
    erode.inputs['Size'].default_value = -3
    links.new(rl.outputs['Alpha'], erode.inputs['Mask'])
    silhouette = mathnode('SUBTRACT', rl.outputs['Alpha'], erode.outputs[0])
    # Thin internal creases from the original smooth geometric normals; no texture speckle.
    sobel = nodes.new('CompositorNodeFilter'); sobel.inputs['Type'].default_value = 'Sobel'
    links.new(rl.outputs['Normal'], sobel.inputs['Image'])
    separate = nodes.new('CompositorNodeSeparateColor')
    links.new(sobel.outputs[0], separate.inputs[0])
    edges = [mathnode('ABSOLUTE', separate.outputs[i]) for i in range(3)]
    edge = mathnode('MAXIMUM', mathnode('MAXIMUM', edges[0], edges[1]), edges[2])
    edge = mathnode('GREATER_THAN', edge, .72)
    edge = mathnode('MULTIPLY', edge, erode.outputs[0])
    edge = mathnode('MULTIPLY', edge, .70)
    ink = mathnode('MAXIMUM', silhouette, edge)
    body = nodes.new('ShaderNodeVectorMath'); body.operation = 'MULTIPLY'
    links.new(rl.outputs['Image'], body.inputs[0])
    links.new(mathnode('SUBTRACT', 1, ink), body.inputs[1])
    mix = nodes.new('ShaderNodeVectorMath'); mix.operation = 'MULTIPLY_ADD'
    links.new(ink, mix.inputs[0]); mix.inputs[1].default_value = (.009, .006, .005)
    links.new(body.outputs[0], mix.inputs[2])
    final = nodes.new('CompositorNodeSetAlpha'); final.inputs['Type'].default_value = 'Replace Alpha'
    links.new(mix.outputs[0], final.inputs['Image']); links.new(rl.outputs['Alpha'], final.inputs['Alpha'])
    links.new(final.outputs[0], output.inputs['Image'])


def render():
    import bpy
    sys.path[:0] = [str(ROOT / 'art/tools/iso')]
    import iso_rig
    from PIL import Image
    baseline()
    WORK.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    original_passes = iso_rig.common.configure_passes
    original_frame = iso_rig.render_frame
    # Keep zero-emission directions: every atlas has the same contractual grid.
    iso_rig.optimize_png = lambda *args, **kwargs: None
    report = {}
    for name, spec in SPECS.items():
        dest = folder(spec, True); dest.mkdir(parents=True, exist_ok=True)
        for source, anims in spec['sources']:
            bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender' / source))
            s = bpy.context.scene; root = bpy.data.objects[spec['root']]
            s.render.engine = 'BLENDER_EEVEE'; s.eevee.taa_render_samples = 8
            s.render.threads_mode = 'FIXED'; s.render.threads = 8
            s.render.use_file_extension = True
            s.render.image_settings.file_format = 'PNG'; s.render.image_settings.color_mode = 'RGBA'
            s.render.dither_intensity = 0
            s.view_settings.view_transform = 'Standard'
            layer = s.view_layers[0]; layer.use_pass_normal = True; layer.use_pass_emit = True
            if not layer.aovs.get('CS1_Accent'):
                layer.aovs.add().name = 'CS1_Accent'
            palettes = toon_materials()
            report[source] = dict(camera=list(s.camera.matrix_world), ortho_scale=s.camera.data.ortho_scale,
                shift_y=s.camera.data.shift_y, frame=list(s['iso_frame']), palettes=palettes)
            report[source]['camera'] = [list(row) for row in s.camera.matrix_world]
            # Persist only our sibling copy, with its runnable shading compositor.
            compositor(RAW / name / 'source.png')
            bpy.ops.wm.save_as_mainfile(filepath=str(WORK / Path(source).name))
            for anim, (start, count) in anims.items():
                paths = [dest / (anim + su + '.png') for su in ('', '_n', '_e')]
                if '--resume' in sys.argv and all(p.exists() for p in paths):
                    continue
                sheets = {su: Image.new('RGBA', (count * spec['cell'], 8 * spec['cell'])) for su in ('', '_n', '_e')}
                for row, direction in enumerate(DIRS):
                    root.rotation_euler.z = iso_rig.DIRECTIONS[direction]
                    for i in range(count):
                        s.frame_set(start + i)
                        path = RAW / name / anim / f'{direction}_{i:02d}.png'
                        # Original renderer, original supersampling, original export convention.
                        # Its configure callback is replaced only for this single render.
                        iso_rig.common.configure_passes = original_passes
                        compositor(path)
                        iso_rig.common.configure_passes = lambda p: None
                        try:
                            original_frame(path)
                        finally:
                            iso_rig.common.configure_passes = original_passes
                        for su, sheet in sheets.items():
                            with Image.open(path.with_stem(path.stem + su)) as im:
                                sheet.paste(im, (i * spec['cell'], row * spec['cell']))
                    print(f'CS1 {name} {anim} {direction}', flush=True)
                for su, sheet in sheets.items():
                    sheet.save(dest / (anim + su + '.png'), optimize=True, compress_level=9)
                    if su == '_n':
                        cached = RAW / 'normals' / (name + '_' + anim + '_n.png')
                        if cached.exists():
                            cached.unlink()
            for tres in folder(spec).glob('*.tres'):
                old = 'res://assets/sprites/' + spec['folder'] + '/'
                (dest / tres.name).write_text(tres.read_text().replace(old, old[:-1] + '_cel/'), encoding='utf-8')
    report['style'] = dict(tones_per_material=3, shadow_floor_linear=.040,
        ink='inward compositor silhouette 1.5 final pixels, thinner geometric normal creases',
        normal_quantization='three signed component plateaus, normalized again after downsampling',
        source_pipeline='C4 idle/run, A2 actions, C5 monsters; original iso_rig.render_frame')
    (HERE / '_cs1_render.json').write_text(json.dumps(report, indent=2))
    quantize_atlases()
    baseline()
    print('PASS CS1 render', flush=True)


def quantize_atlases():
    """Re-quantize AFTER supersampling, entirely in Blender's compositor.

    Filtering otherwise introduces continuous normal gradients at every band edge.
    The 3 signed plateaus make 26 normalized, finite camera-space directions.
    """
    import bpy
    sys.path.insert(0, str(ROOT / 'art/tools/iso'))
    import iso_rig
    from PIL import Image
    work = RAW / 'normals'; work.mkdir(parents=True, exist_ok=True)
    scene = bpy.data.scenes.new('CS1 final normal plateaus')
    scene.render.engine = 'BLENDER_EEVEE'; scene.eevee.taa_render_samples = 1
    scene.render.film_transparent = True; scene.render.dither_intensity = 0
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'; scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'; scene.view_settings.view_transform = 'Raw'
    data = bpy.data.cameras.new('CS1 normal export camera')
    camera = bpy.data.objects.new('CS1 normal export camera', data)
    scene.collection.objects.link(camera); scene.camera = camera
    tree = bpy.data.node_groups.new('CS1 post-filter normal plateaus', 'CompositorNodeTree')
    scene.compositing_node_group = tree
    tree.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    nodes, links = tree.nodes, tree.links
    source = nodes.new('CompositorNodeImage')
    decode = nodes.new('ShaderNodeVectorMath'); decode.operation = 'MULTIPLY_ADD'
    links.new(source.outputs['Image'], decode.inputs[0])
    decode.inputs[1].default_value = (2, 2, 2); decode.inputs[2].default_value = (-1, -1, -1)
    split = nodes.new('ShaderNodeSeparateXYZ'); links.new(decode.outputs[0], split.inputs[0])
    combine = nodes.new('ShaderNodeCombineXYZ')
    for i in range(3):
        rounder = nodes.new('ShaderNodeMath'); rounder.operation = 'ROUND'
        links.new(split.outputs[i], rounder.inputs[0]); links.new(rounder.outputs[0], combine.inputs[i])
    length = nodes.new('ShaderNodeVectorMath'); length.operation = 'LENGTH'
    links.new(combine.outputs[0], length.inputs[0])
    zero = nodes.new('ShaderNodeMath'); zero.operation = 'LESS_THAN'; zero.inputs[1].default_value = .1
    links.new(length.outputs['Value'], zero.inputs[0])
    fallback = nodes.new('ShaderNodeCombineXYZ'); links.new(zero.outputs[0], fallback.inputs[2])
    valid = nodes.new('ShaderNodeVectorMath'); valid.operation = 'ADD'
    links.new(combine.outputs[0], valid.inputs[0]); links.new(fallback.outputs[0], valid.inputs[1])
    unit = nodes.new('ShaderNodeVectorMath'); unit.operation = 'NORMALIZE'
    links.new(valid.outputs[0], unit.inputs[0])
    encode = nodes.new('ShaderNodeVectorMath'); encode.operation = 'MULTIPLY_ADD'
    links.new(unit.outputs[0], encode.inputs[0])
    encode.inputs[1].default_value = (.5, .5, .5); encode.inputs[2].default_value = (.5, .5, .5)
    alpha = nodes.new('CompositorNodeSetAlpha'); alpha.inputs['Type'].default_value = 'Replace Alpha'
    links.new(encode.outputs[0], alpha.inputs['Image']); links.new(source.outputs['Alpha'], alpha.inputs['Alpha'])
    output = nodes.new('NodeGroupOutput'); links.new(alpha.outputs[0], output.inputs['Image'])
    for name, spec in SPECS.items():
        for p in sorted(folder(spec, True).glob('*_n.png')):
            original = work / (name + '_' + p.name)
            if not original.exists():
                import shutil
                shutil.copyfile(p, original)
            with Image.open(original) as im:
                scene.render.resolution_x, scene.render.resolution_y = im.size
            image = bpy.data.images.load(str(original), check_existing=False)
            image.colorspace_settings.name = 'Non-Color'; source.image = image
            scene.render.filepath = str(p)
            bpy.ops.render.render(scene=scene.name, write_still=True)
            bpy.data.images.remove(image)
            print('CS1 final normal ' + name + '/' + p.name, flush=True)
    bpy.data.scenes.remove(scene)
    bpy.data.objects.remove(camera, do_unlink=True)


def verify():
    from PIL import Image
    import numpy as np
    baseline()
    result = {'atlases': [], 'directions': DIRS, 'originals_unchanged': True}
    for name, spec in SPECS.items():
        src, dst = folder(spec), folder(spec, True)
        assert {p.name for p in src.glob('*.png')} == {p.name for p in dst.glob('*.png')}
        for p in sorted(src.glob('*.png')):
            with Image.open(p) as a, Image.open(dst / p.name) as b:
                assert a.size == b.size and max(b.size) <= 4096, p.name
                result['atlases'].append({'subject': name, 'file': p.name, 'size': list(b.size)})
        for _, anims in spec['sources']:
            for anim, (_, count) in anims.items():
                images = [np.asarray(Image.open(dst / (anim + su + '.png')).convert('RGBA')) for su in ('', '_n', '_e')]
                color, normal, emission = images
                assert color.shape[:2] == (8 * spec['cell'], count * spec['cell'])
                assert np.array_equal(color[:, :, 3], normal[:, :, 3]), (name, anim, 'normal alpha')
                assert np.array_equal(color[:, :, 3], emission[:, :, 3]), (name, anim, 'emission alpha')
                opaque = normal[:, :, 3] == 255
                palette = np.unique(normal[:, :, :3][opaque], axis=0)
                assert len(palette) <= 27, (name, anim, 'unquantized normals', len(palette))
                lengths = np.linalg.norm(palette.astype(float) / 127.5 - 1, axis=1)
                assert np.all(np.abs(lengths - 1) < .015), (name, anim, 'normal normalization')
                result.setdefault('normal_palette_sizes', {})[name + '/' + anim] = len(palette)
                assert (emission[:, :, :3].max(axis=2)[color[:, :, 3] > 200] > 100).any(), (name, anim, 'missing accent')
                for row in range(8):
                    cells = []
                    for col in range(count):
                        cell = color[row*spec['cell']:(row+1)*spec['cell'], col*spec['cell']:(col+1)*spec['cell']]
                        assert cell[:, :, 3].max() > 240, (name, anim, row, col, 'empty')
                        cells.append(hashlib.sha256(cell.tobytes()).hexdigest())
                    assert len(set(cells)) == count, (name, anim, row, 'duplicate frames')
                # Compare unchanged geometry alpha, tolerating anti-aliasing changes only.
                original = np.asarray(Image.open(src / (anim + '.png')).convert('RGBA'))
                a, b = original[:, :, 3] > 128, color[:, :, 3] > 128
                iou = float((a & b).sum() / max(1, (a | b).sum()))
                result.setdefault('silhouette_iou', {})[name + '/' + anim] = iou
                assert iou > .97, (name, anim, 'source/pose mismatch', iou)
                original_emission = np.asarray(Image.open(src / (anim + '_e.png')).convert('RGBA'))
                a = (original_emission[:, :, :3].max(axis=2) > 100) & (original_emission[:, :, 3] > 128)
                b = (emission[:, :, :3].max(axis=2) > 100) & (emission[:, :, 3] > 128)
                accent_iou = float((a & b).sum() / max(1, (a | b).sum()))
                assert accent_iou > .97, (name, anim, 'emission region mismatch', accent_iou)
                result.setdefault('emission_region_iou', {})[name + '/' + anim] = accent_iou
        for tres in src.glob('*.tres'):
            old = 'res://assets/sprites/' + spec['folder'] + '/'
            assert (dst / tres.name).read_text() == tres.read_text().replace(old, old[:-1] + '_cel/')
    (HERE / '_cs1_verification.json').write_text(json.dumps(result, indent=2))
    contact()
    print(f"PASS CS1 {len(result['atlases'])} atlases, exact dimensions/resources, unchanged originals", flush=True)


def contact():
    from PIL import Image
    # Actual game ground, assembled without painting. Original left / cel right.
    ground = Image.open(ROOT / 'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    canvas = Image.new('RGBA', (1440, 900), (18, 22, 23, 255))
    rows = [('ardent', [('idle', 0, 2), ('run', 4, 1), ('attack', 2, 2), ('cast_ult', 4, 3)]),
            ('swarm_tier1', [('run', 0, 0), ('run', 2, 1), ('run', 4, 2), ('run', 6, 3)]),
            ('brute_tier3', [('run', 0, 0), ('attack', 3, 1), ('attack', 5, 2), ('cast', 4, 3)])]
    for row, (name, samples) in enumerate(rows):
        spec = SPECS[name]; cell = spec['cell']
        # Lay every ground tile first: overlapping tiles must never cover a sprite.
        for side in range(2):
            for col, (anim, frame, direction) in enumerate(samples):
                cx, cy = side * 720 + col * 176 + 94, row * 300 + 155
                canvas.alpha_composite(ground, (cx - ground.width // 2, cy + 54 - ground.height // 2))
        for side in range(2):
            for col, (anim, frame, direction) in enumerate(samples):
                cx, cy = side * 720 + col * 176 + 94, row * 300 + 155
                atlas = Image.open(folder(spec, bool(side)) / (anim + '.png')).convert('RGBA')
                crop = atlas.crop((frame*cell, direction*cell, (frame+1)*cell, (direction+1)*cell))
                canvas.alpha_composite(crop, (cx-cell//2, cy+54-round(cell*.70)))
    canvas.convert('RGB').save(HERE / '_cs1_contact.png', optimize=True)


def driver():
    baseline()
    if '--verify' not in sys.argv:
        log = HERE / '_cs1_blender.log'
        with log.open('w', encoding='utf-8') as output:
            args = [BLENDER, '--background', '--python', str(Path(__file__).resolve()), '--', '--render']
            if '--resume' in sys.argv:
                args.append('--resume')
            result = subprocess.run(args, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
                creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        assert result.returncode == 0 and 'PASS CS1 render' in log.read_text(encoding='utf-8', errors='replace'), f'Blender failed: {log}'
    verify()
    log = HERE / '_cs1_godot.log'
    with log.open('w', encoding='utf-8') as output:
        result = subprocess.run([GODOT, '--headless', '--path', str(ROOT / 'game'), '--import'],
            cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0), timeout=240)
    errors = [line for line in log.read_text(encoding='utf-8', errors='replace').splitlines()
              if re.search(r'\b(?:ERROR|SCRIPT ERROR|Parse Error)\b', line)]
    assert result.returncode == 0 and not errors, f'Godot import failed: {errors[:3]}'
    baseline()
    print('PASS Godot --headless --path game --import; PASS original hashes', flush=True)


if __name__ == '__main__':
    if '--normals-only' in sys.argv:
        quantize_atlases()
    elif '--render' in sys.argv:
        render()
    else:
        driver()
