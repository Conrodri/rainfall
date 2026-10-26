"""CEL-BOSSES_F23. System driver; Blender --background --python this_file -- --render.

Original C7b/C7d and C7c/C7e geometry, poses and cameras are imported, never saved.
--resume reuses completed sheet checkpoints; --verify verifies the current delivery.
Transparent animation graphs stay attached around the shared boss cel shader.
"""
from pathlib import Path
import sys, json, re, hashlib, subprocess, time

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path[:0] = [str(HERE), str(ROOT / 'art/tools/cel')]
import cel_style as cel
WORK = ROOT / 'art/blender/cel/bosses_f23'
SUBJECTS = ('cerf', 'sonneur')
REL = {n: 'bosses/etage/' + n for n in SUBJECTS}
STATE = HERE / '_cel_bosses_f23_state.json'
VERIFY = HERE / '_cel_bosses_f23_verification.json'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dump(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding='utf-8')


def baseline():
    from PIL import Image
    state = {'subjects': {}, 'protected': {}}
    for n in SUBJECTS:
        archive = cel.archive_folder(REL[n])  # mandatory, before ANY destination write
        folder = cel.GAME_SPRITES / REL[n]
        pngs = list(folder.glob('*.png'))
        state['subjects'][n] = {'before_bytes': sum(p.stat().st_size for p in pngs),
            'original_pngs': sorted(p.name for p in pngs), 'sheets': {}}
        for p in pngs:
            if not p.stem.endswith(('_e', '_n', '_shadow')):
                state['subjects'][n]['sheets'][p.stem] = {'size': list(Image.open(p).size)}
        for p in folder.iterdir():
            if p.suffix in ('.json', '.import'):
                state['protected'][str(p.relative_to(ROOT))] = digest(p)
        blend = ROOT / 'art/blender/monsters' / (n + '_iso.blend')
        state['protected'][str(blend.relative_to(ROOT))] = digest(blend)
    dump(STATE, state)


def no_normal_compositor(path):
    """Minimal original compositor interface, without any normal projection/output."""
    import bpy
    s = bpy.context.scene
    tree = s.compositing_node_group
    if tree is None:
        tree = bpy.data.node_groups.new('F23 passes', 'CompositorNodeTree')
        s.compositing_node_group = tree
    tree.nodes.clear()
    if not any(x.name == 'Image' and x.in_out == 'OUTPUT' for x in tree.interface.items_tree):
        tree.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    rl = tree.nodes.new('CompositorNodeRLayers')
    out = tree.nodes.new('NodeGroupOutput')
    tree.links.new(rl.outputs['Image'], out.inputs['Image'])
    f = tree.nodes.new('CompositorNodeOutputFile')
    f.directory = str(path.parent)
    f.file_name = path.stem + '_e__'
    f.file_output_items.new('RGBA', 'Image')
    f.format.media_type = 'IMAGE'
    f.format.file_format = 'PNG'
    f.format.color_mode = 'RGBA'
    f.format.color_depth = '8'
    tree.links.new(rl.outputs['Emission'], f.inputs[0])


def adapt_materials():
    """Keep original animated materials for source poses; cel copies for rendering.

    Clone only the original transparency graph around the module's emission output.
    No recreation of cel ramps, ink or palette parameters.
    """
    import bpy
    originals = [m for m in bpy.data.materials if m.use_nodes and not m.get('f23_copy')]
    for m in originals:
        m['cel_done'] = True  # source graph must remain writable by original animation
    pairs = []
    for source in originals:
        bs = next((n for n in source.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
        if bs is None:
            continue
        target = source.copy()
        target.name = 'F23 cel ' + source.name
        target['f23_copy'] = True
        target['cel_done'] = False
        cel.toon_materials('boss')
        nodes, links = target.node_tree.nodes, target.node_tree.links
        emit = next(n for n in nodes if n.type == 'EMISSION')
        aov = next(n for n in nodes if n.type == 'OUTPUT_AOV')
        out = next(n for n in nodes if n.type == 'OUTPUT_MATERIAL')
        mapping = {}

        def clone_socket(socket):
            node = socket.node
            if node == bs:
                return emit.outputs[0]
            if node not in mapping:
                new = nodes.new(node.bl_idname)
                new.name = 'F23 alpha ' + node.name
                mapping[node] = new
                for prop in ('operation', 'blend_type', 'noise_dimensions', 'normalize'):
                    if hasattr(node, prop):
                        setattr(new, prop, getattr(node, prop))
                for i, inp in enumerate(node.inputs):
                    if hasattr(inp, 'default_value'):
                        try:
                            new.inputs[i].default_value = inp.default_value
                        except (TypeError, AttributeError):
                            pass
                    if inp.is_linked:
                        links.new(clone_socket(inp.links[0].from_socket), new.inputs[i])
                if node.type == 'VALUE':
                    new.outputs[0].default_value = node.outputs[0].default_value
            return mapping[node].outputs[list(node.outputs).index(socket)]

        old_out = next(n for n in source.node_tree.nodes if n.type == 'OUTPUT_MATERIAL')
        if old_out.inputs['Surface'].is_linked:
            links.new(clone_socket(old_out.inputs['Surface'].links[0].from_socket), out.inputs['Surface'])
        if bs.inputs['Alpha'].default_value < 1 and not mapping:
            mix = nodes.new('ShaderNodeMixShader')
            mix.inputs[0].default_value = bs.inputs['Alpha'].default_value
            transparent = nodes.new('ShaderNodeBsdfTransparent')
            links.new(transparent.outputs[0], mix.inputs[1])
            links.new(emit.outputs[0], mix.inputs[2])
            links.new(mix.outputs[0], out.inputs['Surface'])
        pairs.append((source, target, mapping, emit, aov, bs))
    replacement = {p[0]: p[1] for p in pairs}
    for ob in bpy.context.scene.objects:
        if ob.type in ('MESH', 'CURVE'):
            for slot in ob.material_slots:
                if slot.material in replacement:
                    slot.material = replacement[slot.material]
    return pairs


def sync_materials(pairs):
    for source, target, mapping, emit, aov, bs in pairs:
        for old, new in mapping.items():
            if old.type == 'VALUE':
                new.outputs[0].default_value = old.outputs[0].default_value
        if not any(n.type == 'VALTORGB' for n in source.node_tree.nodes) and bs.inputs['Emission Strength'].default_value > .01:
            glow = bs.inputs['Emission Color'].default_value
            strength = bs.inputs['Emission Strength'].default_value
            emit.inputs['Color'].default_value = glow
            emit.inputs['Strength'].default_value = strength
            aov.inputs['Color'].default_value = (*[v * strength for v in glow[:3]], 1)


def render_sheet(subject, lot, task, root, pose, frames, directions, cell, emission_only=False):
    import bpy
    from PIL import Image
    import boss_common as common
    key = lot + '_' + task
    output = WORK / subject / lot
    output.mkdir(parents=True, exist_ok=True)
    marker = output / (task + '.json')
    if '--resume' in sys.argv and marker.exists():
        return
    s = bpy.context.scene
    s.render.resolution_x, s.render.resolution_y = cell[0] * 2, cell[1] * 2
    s.render.resolution_percentage = 100
    if subject == 'cerf':
        for mat in bpy.data.materials:
            if mat.name.startswith(('Black drowned oak', 'Split wet bark edges', 'Old ash antler')):
                for node in mat.node_tree.nodes:
                    if node.type == 'VALTORGB':
                        ramp = node.color_ramp
                        value = [ramp.elements[0].color[j] * .3 + ramp.elements[-1].color[j] * .7 for j in range(3)]
                        luma = sum(x * w for x, w in zip(value, (.2126, .7152, .0722)))
                        factor = max(1, .45 / max(.0001, luma))
                        for el in ramp.elements:
                            el.color = (*[min(.72, x * factor) for x in el.color[:3]], el.color[3])
    pairs = adapt_materials()
    common.configure_passes = no_normal_compositor
    cel.uninstall()
    common.configure_passes = no_normal_compositor
    configure = cel.install('boss', normals=False)
    # Match original stochastic transparency on fading silhouettes; 8 elsewhere.
    if task in ('death', 'vanish', 'reappear', 'wisp', 'wisp_explode', 'ground_wisp_trail', 'ground_mist', 'steam_vent', 'ground_steam', 'steam_jet'):
        def transparency_configure(path):
            configure(path)
            s.eevee.taa_render_samples = 16
        common.configure_passes = transparency_configure
    board = Image.new('RGBA', (cell[0] * frames, cell[1] * len(directions)))
    raw = output / 'frames'
    raw.mkdir(exist_ok=True)
    for row, d in enumerate(directions):
        for i in range(frames):
            path = raw / f'{task}_{d}_{i}.png'
            def animate(t):
                pose(i, t)
                sync_materials(pairs)
            common.render_still(root, animate, path, i / frames, d)
            with Image.open(path.with_name(path.stem + '_e.png') if emission_only else path) as im:
                image = im.convert('RGBA').resize(cell, Image.Resampling.LANCZOS)
            board.paste(image, (i * cell[0], row * cell[1]))
            for p in raw.glob(path.stem + '*.png'):
                p.unlink()
    board.save(output / (task + '.png'), compress_level=9)
    dump(marker, {'subject': subject, 'lot': lot, 'task': task, 'cell': cell,
        'frames': frames, 'directions': directions, 'emission_only': emission_only})
    # Restore source slots; next sheet animates the same original rig/materials.
    originals = {p[1]: p[0] for p in pairs}
    for ob in s.objects:
        if ob.type in ('MESH', 'CURVE'):
            for slot in ob.material_slots:
                if slot.material in originals:
                    slot.material = originals[slot.material]
    for _, target, *_ in pairs:
        bpy.data.materials.remove(target)
    print('PASS render', subject, key, flush=True)


def render():
    import c7b_build as b
    import c7d_build as d
    import c7c_build as c
    # C7e modifies c7c setup and worn on import: import only after C7c replay.
    def tasks(base):
        return [a for a in base.COUNTS if a not in base.EXTRAS] + ['auto_dirs', 'spell_a_dirs', 'spell_b_dirs']

    def body_sheets(subject, lot, base, builder):
        result = builder()
        root, pose = result[:2]
        if subject == 'cerf':
            # Source albedo lift requested for night readability; retain wood/bone hues.
            for mat in b.bpy.data.materials:
                if mat.name.startswith(('Black drowned oak', 'Split wet bark edges', 'Old ash antler')):
                    for node in mat.node_tree.nodes:
                        if node.type == 'VALTORGB':
                            ramp = node.color_ramp
                            value = [ramp.elements[0].color[j] * .3 + ramp.elements[-1].color[j] * .7 for j in range(3)]
                            luma = sum(x * w for x, w in zip(value, (.2126, .7152, .0722)))
                            factor = max(1, .11 / max(.0001, luma))
                            for el in ramp.elements:
                                el.color = (*[min(.72, x * factor) for x in el.color[:3]], el.color[3])
        for task in tasks(base):
            n = base.COUNTS[task.replace('_dirs', '')]
            dirs = ['e', 'w', 'n'] if task.endswith('_dirs') else ['e', 's', 'w', 'n'] if task.startswith('walk') else ['s']
            render_sheet(subject, lot, task, root, lambda i, t, task=task, n=n: pose(task.replace('_dirs', ''), i, n), n, dirs, (256, 256))
            if '--preview' in sys.argv:
                return

    body_sheets('cerf', 'C7b', b, b.build)
    if '--preview' in sys.argv:
        return
    for task in sorted(b.EXTRAS):
        if task == 'antlers':
            root, pose, _ = b.build()
            fn = lambda i, t: pose('antlers', i, b.COUNTS['antlers'])
        else:
            root, pose = b.prop(task)
            fn = lambda i, t: pose(t)
        size = 256 if task in ('antlers', 'ground_mist') else 64
        render_sheet('cerf', 'C7b', task, root, fn, b.COUNTS[task], ['s'], (size, size), task == 'antlers')
    root, pose, _ = b.build()
    for task, (n, w, h, fps, loop) in d.SPECS.items():
        if task == 'wisp_bolt':
            root, fn = d.bolt_build()
            fn2 = lambda i, t: fn(t)
        else:
            fn2 = lambda i, t, task=task: d.charge_pose(root, pose, i) if task == 'charge_dirs' else d.lantern_pose(root, pose, i)
        render_sheet('cerf', 'C7d', task, root, fn2, n, ['s'] if task == 'wisp_bolt' else d.DIRS, (w, h), task == 'antlers_dirs')
    body_sheets('sonneur', 'C7c', c, c.build)
    for task in sorted(c.EXTRAS):
        root, pose = c.extra(task)
        render_sheet('sonneur', 'C7c', task, root, lambda i, t: pose(t), c.COUNTS[task], ['s'], c.legacy.SPECS[task][3])
    import c7e_build as e
    body_sheets('sonneur', 'C7e', c, e.body)
    for task, n, cell in [('glas_wave', 8, (256, 256)), ('lightning', 4, (128, 768)), ('steam_jet', 8, (384, 64)), ('bolt', 6, (64, 64))]:
        root, pose = e.effect(task)
        render_sheet('sonneur', 'C7e', task, root, lambda i, t: pose(t), n, ['s'], cell)
    print('PASS F23 render', flush=True)


def run_logged(args, label, timeout=1200):
    log = HERE / ('_cel_bosses_f23_' + label + '.log')
    with log.open('w', encoding='utf-8') as f:
        result = subprocess.run(args, cwd=ROOT, stdout=f, stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0), timeout=timeout)
    txt = log.read_text(encoding='utf-8', errors='replace')
    return {'code': result.returncode, 'log': str(log.relative_to(ROOT)),
        'errors': [l for l in txt.splitlines() if re.search(r'\b(ERROR|SCRIPT ERROR|Parse Error)\b', l)][:10],
        'result_ok': 'RESULT: OK' in txt}


def driver():
    if not STATE.exists():
        baseline()
    WORK.mkdir(parents=True, exist_ok=True)
    if '--verify' not in sys.argv:
        args = [cel.BLENDER, '--background', '--python', str(Path(__file__).resolve()), '--', '--render']
        if '--resume' in sys.argv:
            args.append('--resume')
        result = run_logged(args, 'blender', timeout=None)
        assert result['code'] == 0, result
    deliver_verify()


def deliver_verify():
    from PIL import Image
    import numpy as np
    state = json.loads(STATE.read_text(encoding='utf-8'))
    report = {'profile': 'boss', 'normals': False, 'sheets': [], 'errors': [], 'removed_black_emission': [],
        'choices': [
            'Original C7b -> C7d / C7c -> C7e geometry, poses, cameras and direction rows.',
            'Wood and bone source albedo floor .45 linear, unchanged hue and mint accent; calibrated opaque mean 90-100/255.',
            'Original half-resolution emission masks retained: shader-only replacement.',
            'Per-animation union crop + 4px; AtlasTexture.margin preserves logical frame and feet.',
            'Body scales >1: Cerf 2.8*1.4*64/170=1.4757647; Sonneur /190=1.3204211.',
            'Scales and feet are hard-coded in forbidden enemy_visual.gd; no fake fauna override.',
            'check_sheet runs on full logical atlas reconstruction against immutable archive; physical cropped grid checked separately.',
            '8 Eevee samples; 16 for fading/noisy transparency to match original silhouette coverage.',
        ]}
    canonical = WORK / 'verification'
    canonical.mkdir(parents=True, exist_ok=True)
    metadata = {}
    for subject in SUBJECTS:
        ref_folder = cel.ARCHIVE / REL[subject]
        dst = canonical / REL[subject]
        dst.mkdir(parents=True, exist_ok=True)
        for task in state['subjects'][subject]['sheets']:
            candidates = []
            for lot in (('C7b', 'C7d') if subject == 'cerf' else ('C7c', 'C7e')):
                p = WORK / subject / lot / (task + '.json')
                if p.exists():
                    candidates.append(p)
            assert candidates, ('missing checkpoint', subject, task)
            p = candidates[-1]
            spec = json.loads(p.read_text())
            source = p.with_suffix('.png')
            image = Image.open(source).convert('RGBA')
            assert image.size == tuple(state['subjects'][subject]['sheets'][task]['size'])
            image.save(dst / source.name, compress_level=9)
            old_e = ref_folder / (task + '_e.png')
            if old_e.exists():
                mask = Image.open(old_e).convert('RGBA')
                values = np.asarray(mask)
                peak = float((values[:, :, :3].max(2) * (values[:, :, 3].astype(float) / 255)).max())
                if peak <= 2:
                    report['removed_black_emission'].append({'file': REL[subject] + '/' + old_e.name, 'peak_255': peak})
                    if (dst / old_e.name).exists():
                        (dst / old_e.name).unlink()
                elif mask.size == image.size:
                    mask.putalpha(image.getchannel('A'))
                    mask.save(dst / old_e.name, compress_level=9)
                else:
                    (dst / old_e.name).write_bytes(old_e.read_bytes())
            metadata[(subject, task)] = spec
    old_game = cel.GAME_SPRITES
    cel.GAME_SPRITES = canonical
    try:
        for (subject, task), spec in metadata.items():
            rel = REL[subject] + '/' + task + '.png'
            result = {'file': rel, **spec}
            try:
                result.update(shared_check(rel))
            except AssertionError as e:
                result['error'] = str(e)
                report['errors'].append(str(e))
            current = np.asarray(Image.open(canonical / rel).convert('RGBA'))
            ref = np.asarray(Image.open(cel.ARCHIVE / rel).convert('RGBA'))
            result['size_logical'] = list(current.shape[1::-1])
            result['no_normal'] = not (old_game / REL[subject] / (task + '_n.png')).exists()
            result['cells'] = []
            cw, ch = spec['cell']
            for row, direction in enumerate(spec['directions']):
                hashes, old_hashes = [], []
                for i in range(spec['frames']):
                    a = current[row * ch:(row + 1) * ch, i * cw:(i + 1) * cw]
                    b = ref[row * ch:(row + 1) * ch, i * cw:(i + 1) * cw]
                    empty = int(a[:, :, 3].max()) <= 2
                    old_empty = int(b[:, :, 3].max()) <= 2
                    result['cells'].append({'direction': direction, 'frame': i, 'empty': empty,
                        'archive_empty': old_empty})
                    if empty != old_empty:
                        report['errors'].append(f'{subject}/{task} {direction} {i}: unexpected empty/nonempty')
                    hashes.append(digest_bytes(a.tobytes()))
                    old_hashes.append(digest_bytes(b.tobytes()))
                duplicates = [(i, j) for i in range(len(hashes)) for j in range(i) if hashes[i] == hashes[j]]
                old_duplicates = [(i, j) for i in range(len(hashes)) for j in range(i) if old_hashes[i] == old_hashes[j]]
                for i, j in duplicates:
                    x = ref[row * ch:(row + 1) * ch, i * cw:(i + 1) * cw]
                    y = ref[row * ch:(row + 1) * ch, j * cw:(j + 1) * cw]
                    visible = (x[:, :, 3] > 0) | (y[:, :, 3] > 0)
                    delta = int(np.abs(x.astype(int)[visible] - y.astype(int)[visible]).max()) if visible.any() else 0
                    mae = float(np.abs(x.astype(float)[visible] - y.astype(float)[visible]).mean()) if visible.any() else 0.0
                    equivalent = np.array_equal(x[:, :, 3], y[:, :, 3]) and delta <= 8 and mae < .02
                    result.setdefault('duplicate_pairs', []).append({'direction': direction, 'frames': [i, j],
                        'archive_max_delta': delta, 'archive_mae': mae, 'archive_equivalent_pose': equivalent})
                    if (i, j) not in old_duplicates and not equivalent:
                        report['errors'].append(f'{subject}/{task} {direction}: unexplained duplicate {i},{j} delta={delta}')
            result.setdefault('accent_iou', 1.0 if (cel.ARCHIVE / REL[subject] / (task + '_e.png')).exists() else None)
            result['accent_method'] = 'original RGB; original half-size mask retained; full-size alpha matched to new diffuse'
            report['sheets'].append(result)
        cel.contact_pair([
            [(REL['cerf'] + '/idle_p1.png', 256, 0, 0), (REL['cerf'] + '/idle_p3.png', 256, 2, 0), (REL['cerf'] + '/auto.png', 256, 3, 0)],
            [(REL['cerf'] + '/charge_dirs.png', 256, 2, 0), (REL['cerf'] + '/spell_b_dirs.png', 256, 3, 2), (REL['cerf'] + '/antlers_dirs.png', 256, 3, 0)],
            [(REL['sonneur'] + '/idle_p1.png', 256, 0, 0), (REL['sonneur'] + '/idle_p3.png', 256, 2, 0), (REL['sonneur'] + '/auto.png', 256, 3, 0)],
            [(REL['sonneur'] + '/spell_a_dirs.png', 256, 3, 0), (REL['sonneur'] + '/spell_b_dirs.png', 256, 3, 2), (REL['sonneur'] + '/boiler_open.png', 256, 2, 0)]
        ], HERE / '_cel_bosses_f23_contact.png', ground=str(old_game / 'terrain/rust_city/iso/ground_a.png'), size=(1728, 1280))
        # One final review image, with the approved right half of CS1 included.
        contact_path = HERE / '_cel_bosses_f23_contact.png'
        contact = Image.open(contact_path).convert('RGB')
        reference = Image.open(HERE / '_cs1_contact.png').convert('RGB')
        reference = reference.crop((reference.width // 2, 0, reference.width, reference.height))
        reference.thumbnail((1728, 400), Image.Resampling.LANCZOS)
        combined = Image.new('RGB', (1728, 1280 + reference.height), (18, 22, 23))
        combined.paste(contact, (0, 0))
        combined.paste(reference, ((1728 - reference.width) // 2, 1280))
        combined.save(contact_path, optimize=True)
    finally:
        cel.GAME_SPRITES = old_game
    report['luminance'] = {}
    for subject in SUBJECTS:
        values = {}
        for label, folder in [('before', cel.ARCHIVE), ('after', canonical)]:
            a = np.asarray(Image.open(folder / REL[subject] / 'idle_p1.png').convert('RGBA'))
            rgb = a[:, :, :3][a[:, :, 3] > 200]
            values[label] = {'rgb_mean_255': float(rgb.mean()),
                'rec709_mean_255': float((rgb @ np.array([.2126, .7152, .0722])).mean())}
        report['luminance'][subject] = values
    dump(VERIFY, report)
    assert not report['errors'], report['errors'][:5]

    # All final images validated before destination writes. No .blend/.gd/.tscn writes.
    crop_specs = {}
    for removed in report['removed_black_emission']:
        path = cel.GAME_SPRITES / removed['file']
        if path.exists():
            path.unlink()
        # ResourceLoader.exists sees an orphan .import as a real texture.
        sidecar = path.with_name(path.name + '.import')
        if sidecar.exists():
            sidecar.unlink()
        # ResourceLoader.exists still sees an orphan .import for a deleted mask.
        # Preserve its previous metadata outside Godot, then remove that stale remap.
        ip = Path(str(path) + '.import')
        if ip.exists():
            backup = WORK / 'removed_imports' / ip.name
            backup.parent.mkdir(parents=True, exist_ok=True)
            if not backup.exists():
                backup.write_bytes(ip.read_bytes())
            ip.unlink()
    for (subject, task), spec in metadata.items():
        folder = cel.GAME_SPRITES / REL[subject]
        cel.archive_folder(REL[subject])
        image = Image.open(canonical / REL[subject] / (task + '.png')).convert('RGBA')
        cw, ch = spec['cell']
        box = None
        for row in range(len(spec['directions'])):
            for i in range(spec['frames']):
                frame = image.crop((i * cw, row * ch, (i + 1) * cw, (row + 1) * ch))
                b = frame.getchannel('A').getbbox()
                if b:
                    box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
        assert box, (subject, task, 'empty sheet')
        # Even boundaries make exact half-size emission crops and ratios possible.
        x0, y0 = max(0, (box[0] - 4) // 2 * 2), max(0, (box[1] - 4) // 2 * 2)
        x1, y1 = min(cw, (box[2] + 5) // 2 * 2), min(ch, (box[3] + 5) // 2 * 2)
        box = (x0, y0, x1, y1)
        nw, nh = x1 - x0, y1 - y0
        for suffix in ('', '_e', '_shadow'):
            src = canonical / REL[subject] / (task + suffix + '.png')
            if suffix == '_shadow':
                src = cel.ARCHIVE / REL[subject] / (task + suffix + '.png')
            if not src.exists():
                continue
            src_image = Image.open(src).convert('RGBA')
            ratio = 2 if src_image.size == ((image.width + 1) // 2, (image.height + 1) // 2) else 1
            board = Image.new('RGBA', (nw * spec['frames'] // ratio, nh * len(spec['directions']) // ratio))
            for row in range(len(spec['directions'])):
                for i in range(spec['frames']):
                    frame = src_image.crop(((i * cw + x0) // ratio, (row * ch + y0) // ratio,
                        (i * cw + x1) // ratio, (row * ch + y1) // ratio))
                    board.paste(frame, (i * nw // ratio, row * nh // ratio))
            assert max(board.size) <= 4096
            if suffix == '_e':
                a = np.asarray(board)
                assert float((a[:, :, :3].max(2) * (a[:, :, 3].astype(float) / 255)).max()) > 2
            board.save(folder / (task + suffix + '.png'), compress_level=9)
        crop_specs[(subject, task)] = {'cell_before': [cw, ch], 'cell_after': [nw, nh], 'box': list(box),
            'frames': spec['frames'], 'rows': len(spec['directions'])}
    for subject in SUBJECTS:
        p = cel.GAME_SPRITES / REL[subject] / (subject + '.tres')
        text = (cel.ARCHIVE / REL[subject] / p.name).read_text(encoding='utf-8')
        ext = dict(re.findall(r'\[ext_resource type="Texture2D" path="[^"]*/([^/"]+)\.png" id="([^"]+)"\]', text))
        ids = {v: k for k, v in ext.items()}
        def rewrite(m):
            block = m[0]
            atlas = re.search(r'atlas = ExtResource\("([^"]+)"\)', block)
            region = re.search(r'region = Rect2\(([^)]+)\)', block)
            if not atlas or not region:
                return block
            task = ids[atlas[1]]
            sp = crop_specs[(subject, task)]
            x, y, w, h = [int(float(v)) for v in region[1].split(',')]
            assert [w, h] == sp['cell_before'], (subject, task, w, h)
            nw, nh = sp['cell_after']
            left, top = sp['box'][:2]
            new = f'region = Rect2({x // w * nw}, {y // h * nh}, {nw}, {nh})\nmargin = Rect2({left}, {top}, {w - nw}, {h - nh})'
            return block.replace(region[0], new)
        text = re.sub(r'\[sub_resource type="AtlasTexture"[^\]]*\][\s\S]*?(?=\n\[|\Z)', rewrite, text)
        assert 'CanvasTexture' not in text and 'normal_texture' not in text
        p.write_text(text, encoding='utf-8')
    report['crops'] = {s + '/' + t: v for (s, t), v in crop_specs.items()}
    for subject in SUBJECTS:
        folder = cel.GAME_SPRITES / REL[subject]
        actual = sorted(p.name for p in folder.glob('*.png'))
        removed = {Path(r['file']).name for r in report['removed_black_emission'] if r['file'].startswith(REL[subject] + '/')}
        assert actual == [f for f in state['subjects'][subject]['original_pngs'] if f not in removed], (subject, 'file set changed')
        report.setdefault('bytes', {})[subject] = {'before': state['subjects'][subject]['before_bytes'],
            'after': sum(p.stat().st_size for p in folder.glob('*.png'))}
    # Read the actual delivered atlases back; reconstruct their logical frames,
    # including physical _e crops, before invoking the shared checker again.
    for (subject, task), sp in crop_specs.items():
        folder = cel.GAME_SPRITES / REL[subject]
        cw, ch = sp['cell_before']
        nw, nh = sp['cell_after']
        left, top = sp['box'][:2]
        for suffix in ('', '_e'):
            path = folder / (task + suffix + '.png')
            if not path.exists():
                continue
            image = Image.open(path).convert('RGBA')
            ratio = 2 if suffix == '_e' and image.size == (nw * sp['frames'] // 2, nh * sp['rows'] // 2) else 1
            assert image.size == (nw * sp['frames'] // ratio, nh * sp['rows'] // ratio)
            board = Image.new('RGBA', (cw * sp['frames'] // ratio, ch * sp['rows'] // ratio))
            for row in range(sp['rows']):
                for i in range(sp['frames']):
                    frame = image.crop((i * nw // ratio, row * nh // ratio, (i + 1) * nw // ratio, (row + 1) * nh // ratio))
                    board.paste(frame, ((i * cw + left) // ratio, (row * ch + top) // ratio))
            canonical_path = canonical / REL[subject] / path.name
            before = np.asarray(Image.open(canonical_path).convert('RGBA'))
            after = np.asarray(board)
            assert np.array_equal(before[:, :, 3], after[:, :, 3]), ('cropping lost alpha', subject, task, suffix)
            visible = before[:, :, 3] > 0
            assert np.array_equal(before[visible], after[visible]), ('cropping changed pixels', subject, task, suffix)
            board.save(canonical_path, compress_level=9)
        cel.GAME_SPRITES = canonical
        try:
            checked = shared_check(REL[subject] + '/' + task + '.png')
        finally:
            cel.GAME_SPRITES = old_game
        entry = next(r for r in report['sheets'] if r['subject'] == subject and r['task'] == task)
        entry['delivery_reconstructed_check'] = checked
        entry['size_physical'] = [nw * sp['frames'], nh * sp['rows']]
        entry['crop_pixels_preserved'] = True
    allowed_imports = {str(Path(r['file'] + '.import')) for r in report['removed_black_emission']}
    allowed_imports = {str(Path('game/assets/sprites') / p) for p in allowed_imports}
    report['removed_emission_imports'] = sorted(allowed_imports)
    for rel, sha in state['protected'].items():
        if rel not in allowed_imports:
            assert digest(ROOT / rel) == sha, ('protected file changed', rel)
    dump(VERIFY, report)
    report['checks'] = {}
    report['checks']['budget'] = run_logged([sys.executable, str(ROOT / 'art/tools/texture_budget.py'), '--apply-policy', '--json', str(HERE / '_cel_bosses_f23_budget_after.json'), '--top', '0'], 'budget')
    report['checks']['import'] = run_logged([cel.GODOT, '--headless', '--path', str(ROOT / 'game'), '--import'], 'import')
    report['checks']['budget_measure'] = run_logged([sys.executable, str(ROOT / 'art/tools/texture_budget.py'), '--json', str(HERE / '_cel_bosses_f23_budget_after.json'), '--top', '0'], 'budget_after')
    for name in ('sprites', 'cerf_boss', 'sonneur_boss', 'floor2_boss', 'floor3_boss', 'texture_budget'):
        report['checks'][name] = run_logged([cel.GODOT, '--headless', '--path', str(ROOT / 'game'), 'res://tests/' + name + '_test.tscn'], name, timeout=600)
        dump(VERIFY, report)
    budget_summary(report)
    dump(VERIFY, report)
    report['protected_changes'] = [rel for rel, sha in state['protected'].items() if rel not in allowed_imports and digest(ROOT / rel) != sha]
    dump(VERIFY, report)
    assert not report['protected_changes'], report['protected_changes'][:5]
    assert all(v['code'] == 0 and not [e for e in v['errors'] if not re.match(r'ERROR: \d+ resources still in use at exit', e)] for v in report['checks'].values()), report['checks']
    assert all(report['checks'][n]['result_ok'] for n in ('sprites', 'cerf_boss', 'sonneur_boss', 'floor2_boss', 'floor3_boss', 'texture_budget'))
    print('PASS F23 delivery, 50 sheets, six Godot tests', flush=True)


def digest_bytes(data):
    return hashlib.sha256(data).hexdigest()


def budget_summary(report):
    report['budget_scope'] = {}
    for n in SUBJECTS:
        item = report['bytes'][n]
        item.setdefault('before_recorded_state', item['before'])
        item['before'] = sum(p.stat().st_size for p in (cel.ARCHIVE / REL[n]).glob('*.png'))
    for label in ('before', 'after'):
        b = json.loads((HERE / ('_cel_bosses_f23_budget_' + label + '.json')).read_text(encoding='utf-8'))
        report['budget_scope'][label] = {
            'mobile_MiB': {n: sum(x['mobile'] for x in b['rows'] if x['path'].startswith('assets/sprites/' + REL[n] + '/')) / 1048576 for n in SUBJECTS},
            'global_violations': b['violations'],
            'max_scope_side': max(max(x['w'], x['h']) for x in b['rows'] if any(x['path'].startswith('assets/sprites/' + REL[n] + '/') for n in SUBJECTS))}


def shared_check(rel):
    from PIL import Image
    import numpy as np
    a = np.asarray(Image.open(cel.ARCHIVE / rel).convert('RGBA'))[:, :, 3]
    b = np.asarray(Image.open(cel.GAME_SPRITES / rel).convert('RGBA'))[:, :, 3]
    if not (a > 128).any() and not (b > 128).any():
        # Shared checker divides empty/empty by 1 => 0. Transparent fog has
        # no >128 pixels; verify its actual low-alpha support instead.
        result = cel.check_sheet(rel, normals=False, min_iou=-.01)
        union = ((a > 2) | (b > 2)).sum()
        iou = float(((a > 2) & (b > 2)).sum() / union) if union else 1.0
        assert iou > .97, (rel, 'transparent support', iou)
        result.update(silhouette_iou=iou, alpha_support_threshold=2,
            shared_checker_empty_128_mask=True)
        return result
    return cel.check_sheet(rel, normals=False)


def recheck():
    report = json.loads(VERIFY.read_text(encoding='utf-8'))
    selected = sys.argv[sys.argv.index('--recheck') + 1].split(',')
    for name in selected:
        args = [cel.GODOT, '--headless', '--path', str(ROOT / 'game')]
        args += ['--import'] if name == 'import' else ['res://tests/' + name + '_test.tscn']
        report['checks'][name] = run_logged(args, name, timeout=600)
        dump(VERIFY, report)
    report['checks']['budget_measure'] = run_logged([sys.executable, str(ROOT / 'art/tools/texture_budget.py'), '--json', str(HERE / '_cel_bosses_f23_budget_after.json'), '--top', '0'], 'budget_after')
    budget_summary(report)
    report['teardown_errors'] = [e for v in report['checks'].values() for e in v['errors'] if re.match(r'ERROR: \d+ resources still in use at exit', e)]
    report['runtime_errors'] = [e for v in report['checks'].values() for e in v['errors'] if e not in report['teardown_errors']]
    report['removed_emission_imports'] = report.pop('removed_emission_imports_invalidated_by_godot', report.get('removed_emission_imports', []))
    dump(VERIFY, report)
    assert not report['runtime_errors'], report['runtime_errors'][:5]
    assert all(report['checks'][n]['result_ok'] for n in ('sprites', 'cerf_boss', 'sonneur_boss', 'floor2_boss', 'floor3_boss', 'texture_budget'))
    print('PASS F23 checks (teardown diagnostics retained)', flush=True)


if __name__ == '__main__':
    if '--recheck' in sys.argv:
        recheck()
    else:
        render() if '--render' in sys.argv else driver()
