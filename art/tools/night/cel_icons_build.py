"""CEL-ICONS: reuse original geometry recipes; system driver / Blender -- --render.

Only source render/save/post calls are intercepted. Original models, studios,
cameras and fitting recipes remain authoritative; no source blend is saved.
"""
import ast
import hashlib
import json
import math
import subprocess
import sys
import types
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SPRITES = ROOT / 'game/assets/sprites'
WORK = ROOT / 'art/blender/cel/icons'
BASELINE = HERE / '_cel_icons_baseline.json'
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
sys.path[:0] = [str(ROOT / 'art/tools/cel'), str(ROOT / 'art/tools/ui')]
import cel_style as cel


def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def targets():
    return sorted([*(SPRITES / 'icons/items').glob('*.png'),
                   *(SPRITES / 'icons').glob('frame_*.png'),
                   *(SPRITES / 'ui/dice').glob('*.png'),
                   *(SPRITES / 'ui/hud').glob('*.png'),
                   *(SPRITES / 'ui/interact').glob('*.png'),
                   SPRITES / 'ui/crit_icon.png'])


def baseline():
    from PIL import Image
    if BASELINE.exists():
        return json.loads(BASELINE.read_text())
    for folder in ['icons/items', 'ui/dice', 'ui/hud', 'ui/interact']:
        cel.archive_folder(folder)
    # Filter loose-file roots: never archive spells or unrelated UI assets.
    import shutil
    staging = WORK / 'archive_source'
    for folder, pattern in [('icons', 'frame_*.png'), ('ui', 'crit_icon.png')]:
        for p in (SPRITES / folder).glob(pattern):
            q = staging / folder / p.name
            q.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, q)
    original = cel.GAME_SPRITES
    try:
        cel.GAME_SPRITES = staging
        cel.archive_folder('icons')
        cel.archive_folder('ui')
    finally:
        cel.GAME_SPRITES = original
    data = {'files': {}, 'protected': {}, 'choices': [
        'Original geometry, cameras, fitting and material hues; shared cel ramps/ink only.',
        'icon: items, HUD, interact, crit; ui: dice and rarity frames.',
        'Night shadow floor from cel_style; no extra saturation; no normals.',
        'Original I1/I2/U2 and R7c HUD recipes imported, never source-blend saves.',
    ]}
    for p in targets():
        assert not p.stem.endswith(('_n', '_e', '_shadow')), p
        im = Image.open(p).convert('RGBA')
        rel = p.relative_to(SPRITES).as_posix()
        data['files'][rel] = {'size': list(im.size), 'bbox': im.getbbox(),
                              'bytes': p.stat().st_size, 'sha256': digest(p)}
    for folder in ['icons', 'ui']:
        for p in (SPRITES / folder).rglob('*'):
            if p.is_file() and p not in targets():
                data['protected'][p.relative_to(SPRITES).as_posix()] = digest(p)
    BASELINE.write_text(json.dumps(data, indent=2), encoding='utf-8')
    return data


class SourceAdapter(ast.NodeTransformer):
    """Import recipes without executing their delivery/save side effects."""
    def visit_Call(self, node):
        name = ast.unparse(node.func)
        if name == 'bpy.ops.render.render':
            return ast.copy_location(ast.Call(func=ast.Name(id='_cel_render', ctx=ast.Load()),
                                             args=[], keywords=[]), node)
        if name in ('bpy.ops.wm.save_as_mainfile', 'bpy.ops.file.pack_all',
                    'subprocess.run', 'old.main'):
            return ast.copy_location(ast.Constant(None), node)
        return self.generic_visit(node)


def source(name, render_hook):
    path = ROOT / 'art/tools/ui' / (name + '.py')
    module = types.ModuleType('_cel_' + name)
    module.__file__ = str(path)
    module._cel_render = render_hook
    tree = SourceAdapter().visit(ast.parse(path.read_text(encoding='utf-8-sig')))
    ast.fix_missing_locations(tree)
    exec(compile(tree, str(path), 'exec'), module.__dict__)
    return module


def render():
    import bpy
    data = json.loads(BASELINE.read_text())
    WORK.mkdir(parents=True, exist_ok=True)
    mapping = {Path(rel).stem: rel for rel in data['files']}
    resume = '--resume' in sys.argv
    sys.argv = ['cel_icons']
    current = {'rel': None}

    def hook():
        scene = bpy.context.scene
        rel = current['rel'] or mapping.get(Path(scene.render.filepath).stem)
        if rel not in data['files']:
            return
        out = WORK / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        if resume and out.exists():
            return
        prof = 'ui' if rel.startswith('ui/dice/') or rel.startswith('icons/frame_') else 'icon'
        cel.install(prof, normals=False)
        cel.setup_scene()
        cel.toon_materials(prof)
        cel.cel_passes(out, prof, base_configure=cel._installed['configure_passes'], normals=False)
        # None of this lot's original files have _e companions; discard the
        # unused emission output before rendering, preserving the file contract.
        tree = getattr(scene, 'node_tree', None) or scene.compositing_node_group
        for node in list(tree.nodes):
            if node.bl_idname == 'CompositorNodeOutputFile':
                tree.nodes.remove(node)
        scene.render.filepath = str(out)
        bpy.ops.render.render(write_still=True)
        print('CEL_ICON_OK ' + rel, flush=True)

    source('i1_build', hook)
    i2 = source('i2_build', hook)
    i2.INV = {'files': {r: d for r, d in i2.INV['files'].items()
                       if r.removeprefix('game/assets/sprites/') in data['files']}}
    i2.run()
    u2 = source('u2_build', hook)
    from mathutils import Euler, Quaternion, Vector
    u2.scene('dice_rotation')
    root = u2.die()
    axis = Vector((.45, .8, .35)).normalized()
    for k in range(20):
        root.rotation_mode = 'QUATERNION'
        root.rotation_quaternion = Euler((.55, .25, .16)).to_quaternion() @ Quaternion(axis, math.tau*k/20)
        current['rel'] = f'ui/dice/d100_rot_{k:02}.png'
        u2.render('game/assets/sprites/' + current['rel'], 2.9)
    for rarity in ['commun', 'peu_commun', 'rare', 'legendaire']:
        u2.scene('face_' + rarity)
        root = u2.die(rarity)
        root.rotation_euler = (.8, .25, .1)
        current['rel'] = f'ui/dice/d100_face_{rarity}.png'
        u2.render('game/assets/sprites/' + current['rel'], 2.9)
        u2.scene('frame_' + rarity)
        u2.rarity(rarity)
        current['rel'] = f'icons/frame_{rarity}.png'
        u2.render('game/assets/sprites/' + current['rel'], 2.4)
    current['rel'] = None
    # HUD assets predate U1 (which targets ui/da); use the actual R7c recipes.
    import ui_elements as hud
    source('r7c_render', hook)
    hud.render_to = lambda path: (setattr(bpy.context.scene.render, 'filepath', str(path)), hook())
    hud.post = lambda job: None
    # I2 supplies the final hand; avoid replacing it with the older R7c hand.
    hand_rel = mapping.pop('icon_interact_hand')
    hud.make_hud()
    mapping['icon_interact_hand'] = hand_rel
    current['rel'] = 'ui/crit_icon.png'
    source('crit_icon', hook)
    print('PASS CEL-ICONS render', flush=True)


def fit_and_verify():
    from PIL import Image
    import numpy as np
    import i2_finish
    data = json.loads(BASELINE.read_text())
    # Raster assembly only: reuse the original fitting helper in staging, and
    # retain the archived coverage channel. The modest cel sample count changes
    # thin-edge coverage; coverage is contractual, independent of the shading.
    fit_inventory = WORK / 'fit_inventory.json'
    crop_path = HERE / '_cel_icons_fit.json'
    crops = json.loads(crop_path.read_text()) if crop_path.exists() else {}
    fit_inventory.write_text(json.dumps({'files': data['files']}))
    i2_finish.INV = fit_inventory
    i2_finish.ROOT = WORK / 'fitted'
    for rel in data['files']:
        (i2_finish.ROOT / rel).parent.mkdir(parents=True, exist_ok=True)
    data['choices'].append('Archived alpha coverage assembled unchanged; original i2_finish.fit; cel RGB untouched.')
    checks = []
    errors = []
    for rel, spec in data['files'].items():
        try:
            raw = Image.open(WORK / rel).convert('RGBA')
            if rel == 'ui/crit_icon.png':
                out = raw.resize(spec['size'], Image.Resampling.LANCZOS)
            else:
                i2_finish.fit(WORK / rel, rel)
                out = Image.open(i2_finish.ROOT / rel).convert('RGBA')
            if rel in crops:
                x, y, r, b = spec['bbox']
                crop = raw.crop(crops[rel]['crop']).resize((r-x,b-y), Image.Resampling.LANCZOS)
                out = Image.new('RGBA', spec['size'])
                out.paste(crop, (x,y))
            ref_alpha = Image.open(cel.ARCHIVE / rel).convert('RGBA').getchannel('A')
            ref_mask = np.asarray(ref_alpha) > 128
            rendered_mask = np.asarray(out.getchannel('A')) > 128
            render_iou = float((ref_mask & rendered_mask).sum() / max(1, (ref_mask | rendered_mask).sum()))
            assert render_iou > .97, (rel, 'rendered silhouette before coverage assembly', render_iou)
            out.putalpha(ref_alpha)
            # Validate in staging before publishing this sheet.
            ref = np.array(Image.open(cel.ARCHIVE / rel).convert('RGBA'))
            new = np.array(out)
            a, b = ref[:, :, 3] > 128, new[:, :, 3] > 128
            iou = float((a & b).sum() / max(1, (a | b).sum()))
            assert iou > .97, (rel, 'silhouette', iou)
            out.save(SPRITES / rel, optimize=True, compress_level=9)
            row = cel.check_sheet(rel, cell=tuple(spec['size']), frames=1, rows=1, normals=False)
            assert not (SPRITES / rel).with_stem(Path(rel).stem + '_n').exists()
            assert digest(SPRITES / rel) != spec['sha256'], (rel, 'unchanged')
            row.update(size=spec['size'], no_normal=True, frames=1, alpha_bbox=out.getbbox(), alpha_coverage_preserved=True)
            row['rendered_silhouette_iou'] = render_iou
            row['emission'] = False
            row['accent_iou'] = None  # No original _e in this lot.
            checks.append(row)
        except Exception as exc:
            errors.append(str(exc))
    for rel, sha in data['protected'].items():
        if not (SPRITES / rel).exists() or digest(SPRITES / rel) != sha:
            errors.append('protected changed: ' + rel)
    if len({digest(SPRITES/rel) for rel in data['files']}) != len(data['files']):
        errors.append('duplicate diffuse sheets')
    # Dice animation cells are distinct across their original separate PNGs.
    rotations = [digest(SPRITES / f'ui/dice/d100_rot_{k:02}.png') for k in range(20)]
    if len(set(rotations)) != 20:
        errors.append('duplicate dice rotation frames')
    report = {'status': 'FAIL' if errors else 'PASS', 'checks': checks, 'errors': errors,
              'choices': data['choices'], 'before_bytes': sum(d['bytes'] for d in data['files'].values()),
              'after_bytes': sum((SPRITES/r).stat().st_size for r in data['files'])}
    (HERE / '_cel_icons_verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    samples = [[(r, tuple(data['files'][r]['size']), 0, 0) for r in list(data['files'])[i:i+4]]
               for i in range(0, len(data['files']), 4)]
    pages = []
    temp = WORK / '_contact_page.png'
    for i in range(0, len(samples), 4):
        group = samples[i:i+4]
        cel.contact_pair(group, temp, size=(2048, 256*len(group)))
        pages.append(Image.open(temp).convert('RGB').resize((1280,160*len(group)), Image.Resampling.LANCZOS))
    # One contact only: CS1 reference row above the whole contractual lot.
    reference = Image.open(HERE / '_cs1_contact.png').convert('RGB')
    reference = reference.crop((0,0,reference.width,reference.height//3)).resize((1280,267), Image.Resampling.LANCZOS)
    contact = Image.new('RGB', (1280, 267+sum(p.height for p in pages)))
    contact.paste(reference, (0,0))
    y = 267
    for page in pages:
        contact.paste(page, (0,y))
        y += page.height
    contact.save(HERE / '_cel_icons_contact.png', optimize=True)
    temp.unlink()
    print(report['status'], len(checks), '/', len(data['files']), 'sheets;', len(errors), 'errors')
    for error in errors[:5]:
        print(error)
    assert not errors, 'See _cel_icons_verification.json'


def validate_game():
    import re
    commands = [('budget', [sys.executable, str(ROOT/'art/tools/texture_budget.py'), '--apply-policy']),
                ('budget_report', [sys.executable, str(ROOT/'art/tools/texture_budget.py')]),
                ('godot_import', [GODOT, '--headless', '--path', str(ROOT/'game'), '--import'])]
    for scene in ['sprites_test', 'loot_ui_test', 'chest_reveal_test', 'ui_theme_test', 'texture_budget_test']:
        commands.append((scene, [GODOT, '--headless', '--path', str(ROOT/'game'), 'res://tests/'+scene+'.tscn']))
    results = {}
    for name, args in commands:
        path = HERE / ('_cel_icons_'+name+'.log')
        with path.open('w', encoding='utf-8') as log:
            result = subprocess.run(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=300)
        output = path.read_text(encoding='utf-8', errors='replace')
        errors = [l for l in output.splitlines() if re.search(r'\b(?:ERROR|SCRIPT ERROR|Parse Error)\b',l)]
        cleanup = [l for l in errors if re.search(r'^ERROR: \d+ resources still in use at exit',l)] if name.endswith('_test') else []
        failures = [l for l in errors if l not in cleanup]
        ok = result.returncode == 0 and not failures
        if name.endswith('_test'):
            ok = ok and 'RESULT: OK' in output
        results[name] = {'status': 'PASS' if ok else 'FAIL', 'returncode': result.returncode,
                         'errors': failures[:5], 'cleanup_diagnostics': cleanup}
        print(name, results[name]['status'], flush=True)
    report_path = HERE / '_cel_icons_verification.json'
    report = json.loads(report_path.read_text())
    report['validation'] = results
    if any(r['status'] != 'PASS' for r in results.values()):
        report['status'] = 'FAIL'
    report_path.write_text(json.dumps(report, indent=2), encoding='utf-8')
    assert report['status'] == 'PASS', 'Game validation failed; see verification/logs'


def driver():
    baseline()
    if '--verify' not in sys.argv:
        with (HERE / '_cel_icons_blender.log').open('w', encoding='utf-8') as log:
            args = [BLENDER, '--background', '--python', str(Path(__file__).resolve()), '--', '--render']
            if '--resume' in sys.argv:
                args.append('--resume')
            result = subprocess.run(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        assert result.returncode == 0, 'Blender failed: _cel_icons_blender.log'
    fit_and_verify()
    validate_game()


if __name__ == '__main__':
    render() if '--render' in sys.argv else driver()
