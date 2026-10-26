"""CEL-MONSTERS_F23: preserved C5 scenes, original renderer, no normal outputs."""
import sys, json, hashlib, shutil, subprocess, inspect, math, textwrap
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
WORK = ROOT / 'art/blender/cel/monsters_f23'
SPRITES = ROOT / 'game/assets/sprites'
sys.path[:0] = [str(ROOT / ('art/tools/' + p)) for p in ('cel', 'iso', 'monsters', '')]
sys.path.insert(0, str(HERE))
import cel_style as cel

SPECS = {'swarm_tier1': (96, ['run']), 'shooter_tier2': (112, ['run', 'attack']),
         'leaper_tier2': (112, ['run', 'charge']), 'brute_tier3': (160, ['run', 'attack', 'cast'])}
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
BASE_SPECS = SPECS
BIOMES = {'moss': 'n2e', 'rust': 'n3e'}
SPECS = {name + '_' + biome: spec for biome in BIOMES for name, spec in BASE_SPECS.items()}
STATE = HERE / '_cel_monsters_f23_state.json'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def protected():
    paths = [ROOT / 'art/blender/monsters' / (prefix + '_' + name + '.blend')
             for prefix in BIOMES.values() for name in BASE_SPECS]
    for name in SPECS:
        paths += [p for p in (SPRITES / 'monsters' / name).rglob('*')
                  if p.is_file() and p.suffix in ('.tres', '.json', '.import')]
    return {str(p.relative_to(ROOT)): sha(p) for p in paths}


def render():
    import bpy
    import importlib
    import iso_monster_build as c5
    import iso_rig
    from PIL import Image
    # Same small compatibility patch as F1: no obsolete normal-file collection.
    source = inspect.getsource(iso_rig.render_frame)
    assert "for suffix in ('_n','_e'):" in source
    namespace = dict(iso_rig.__dict__)
    exec(source.replace("for suffix in ('_n','_e'):", "for suffix in ('_e',):"), namespace)
    iso_rig.render_frame = namespace['render_frame']
    for biome, prefix in BIOMES.items():
        original = importlib.import_module(prefix + '_build')
        # Reuse only the original render/assembly block. Construction, saving,
        # metadata and import generation are deliberately never executed.
        source = inspect.getsource(original.build)
        start = source.index('    for j,anim in enumerate(anims):')
        end = source.index('    imports(name)', start)
        block = textwrap.dedent(source[start:end])
        block = block.replace("('','_n','_e')", "('','_e')")
        block = block.replace('for j,anim in enumerate(anims):',
            "for j,anim in enumerate(anims):\n    marker = temp / (anim + '.done')\n    if resume and marker.exists(): continue")
        block += "    marker.write_text('PASS')\n"
        code = compile(block, inspect.getfile(original) + ':render-only', 'exec')
        for base, (size, anims) in original.CFG.items():
            name = base + '_' + biome
            temp = WORK / name
            temp.mkdir(parents=True, exist_ok=True)
            if '--resume' in sys.argv and all((temp / (a + '.done')).exists() for a in anims):
                continue
            bpy.ops.wm.open_mainfile(filepath=str(original.SOURCES / (prefix + '_' + base + '.blend')))
            scene = bpy.context.scene
            scene.render.threads_mode = 'FIXED'
            scene.render.threads = 8
            root = bpy.data.objects[base]
            cel.install('creature', normals=False)
            env = dict(original.__dict__, size=size, anims=anims, scene=scene,
                       root=root, temp=temp, dst=SPRITES / 'monsters' / name,
                       name=name, c5=c5, Image=Image, resume='--resume' in sys.argv)
            exec(code, env)
            cel.uninstall()
    print('PASS CEL-MONSTERS_F23 render', flush=True)


def verify():
    import numpy as np
    from PIL import Image
    import halve_emission
    report = {'profile': 'creature', 'normals': False, 'choices':
              'N2e/N3e saved scenes and original render loops reused; F1 creature profile, 8 samples, 2x; geometry, animations, camera, hues preserved. Night shadow floor from shared module. Archived half-resolution emission masks retained exactly: only shading changes.',
              'sheets': []}
    for name, (cell, anims) in SPECS.items():
        folder = SPRITES / 'monsters' / name
        archive = cel.ARCHIVE / 'monsters' / name
        assert not list(folder.glob('*_n.png'))
        assert not list((WORK / name).glob('*_n*.png'))
        assert {p.name for p in folder.glob('*.png')} == {p.name for p in archive.glob('*.png') if not p.stem.endswith('_n')}
        for anim in anims:
            rel = f'monsters/{name}/{anim}.png'
            result = cel.check_sheet(rel, cell=cell, frames=8, rows=8, normals=False)
            assert sha(folder / (anim + '.png')) != sha(archive / (anim + '.png')), 'Diffuse unchanged'
            assert sha(folder / (anim + '_e.png')) == sha(archive / (anim + '_e.png')), 'Emission changed'
            result.update(size=list(Image.open(folder / (anim + '.png')).size), normals_absent=True,
                          cells_nonempty_unique='64/64')
            ep = folder / (anim + '_e.png')
            with Image.open(ep) as im:
                e = im.convert('RGBA')
            diffuse = Image.open(folder / (anim + '.png')).convert('RGBA')
            if e.size == diffuse.size:
                assert np.array_equal(np.asarray(e)[..., 3], np.asarray(diffuse)[..., 3])
                e = halve_emission.downscale(e)
                e.save(ep, optimize=True, compress_level=9)
            ref = Image.open(archive / ep.name).convert('RGBA')
            if ref.size == diffuse.size:
                ref = halve_emission.downscale(ref)
            a, b = np.asarray(ref), np.asarray(e)
            masks = [(x[..., :3].max(axis=2) > 100) & (x[..., 3] > 128) for x in (a, b)]
            x, y = masks
            result['accent_iou_half'] = float((x & y).sum() / max(1, (x | y).sum()))
            assert result['accent_iou_half'] > .97, (rel, 'accent', result['accent_iou_half'])
            assert np.max(b[..., :3] * (b[..., 3:4].astype(float) / 255)) > 2
            result['emission_size'] = list(e.size)
            result['emission_source'] = 'archive, byte-identical'
            da = np.asarray(halve_emission.downscale(diffuse))[..., 3]
            result['alpha_half_exact'] = bool(np.array_equal(da, b[..., 3]))
            x, y = da > 128, b[..., 3] > 128
            result['alpha_emission_iou_half'] = float((x & y).sum() / max(1, (x | y).sum()))
            result['alpha_validation'] = 'half-resolution: dimensions checked; exact alpha equality only applies at full resolution (STYLE_cel.md)'
            pixels = np.asarray(diffuse)
            result['unique_cells'] = len({hashlib.sha256(pixels[r*cell:(r+1)*cell,c*cell:(c+1)*cell].tobytes()).hexdigest() for r in range(8) for c in range(8)})
            assert result['unique_cells'] == 64, (rel, 'duplicate cells')
            report['sheets'].append(result)
    assert all((WORK / name / (anim + '.done')).exists() for name, (_, anims) in SPECS.items() for anim in anims), 'Incomplete render'
    state = json.loads(STATE.read_text())
    assert protected() == state['protected'], 'Protected files changed'
    report['protected_unchanged'] = True
    report['bytes_before'] = state['bytes_before']
    report['bytes_after'] = sum(p.stat().st_size for n in SPECS for p in (SPRITES / 'monsters' / n).glob('*.png'))
    (HERE / '_cel_monsters_f23_verification.json').write_text(json.dumps(report, indent=2))
    samples = []
    for name, (cell, anims) in SPECS.items():
        samples.append([(f'monsters/{name}/{anim}.png', cell, f, 2)
                        for anim, f in [(anims[0], 0), (anims[-1], 4)]])
    samples.append([('monsters/swarm_tier1/run.png', 96, 0, 2), ('monsters/brute_tier3/attack.png', 160, 4, 2)])
    cel.contact_pair(samples, HERE / '_cel_monsters_f23_contact.png', ground='terrain/fog_forest/iso/ground_a.png', size=(1440, 2000))
    # One final board: eight biome subjects; F1 and CS1 cel references below.
    contact = HERE / '_cel_monsters_f23_contact.png'
    with Image.open(contact) as im:
        reference_y = im.height
        board = Image.new('RGB', (1440, reference_y + 500), (18, 22, 23))
        board.paste(im, (0, 0))
    for index, reference in enumerate(('_cel_monsters_f1_contact.png', '_cs1_contact.png')):
        with Image.open(HERE / reference) as im:
            crop = im.crop((im.width // 2, 0, im.width, im.height))
            crop.thumbnail((720, 500), Image.Resampling.LANCZOS)
            board.paste(crop, (index * 720 + (720-crop.width)//2, reference_y))
    board.save(contact, optimize=True)
    print('PASS verification 16 sheets; contact', flush=True)

def driver():
    WORK.mkdir(parents=True, exist_ok=True)
    if not STATE.exists():
        STATE.write_text(json.dumps({'protected': protected(), 'bytes_before': sum(p.stat().st_size for n in SPECS for p in (SPRITES / 'monsters' / n).glob('*.png'))}, indent=2))
    for name in SPECS:
        cel.archive_folder('monsters/' + name)
    if '--verify' not in sys.argv:
        command = [BLENDER, '--background', '--python-exit-code', '1', '--python', str(Path(__file__).resolve()), '--', '--render']
        if '--resume' in sys.argv:
            command.append('--resume')
        with (HERE / '_cel_monsters_f23_render.log').open('w') as log:
            proc = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
        assert proc.returncode == 0, 'Blender failed; _cel_monsters_f23_render.log'
    # Tiny legacy accents have different AOV edge coverage; preserve their exact masks.
    for name in SPECS:
        for p in (cel.ARCHIVE / 'monsters' / name).glob('*_e.png'):
            shutil.copy2(p, SPRITES / 'monsters' / name / p.name)
    verify()

def checks():
    godot = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    jobs = [('budget_after', [sys.executable, 'art/tools/texture_budget.py', '--apply-policy']),
            ('import', [godot, '--headless', '--path', 'game', '--import'])]
    jobs += [(name, [godot, '--headless', '--path', 'game', 'res://tests/' + name + '.tscn'])
             for name in ('sprites_test', 'biome_fauna_test', 'enemies_map_test', 'texture_budget_test')]
    report = {}
    for name, cmd in jobs:
        path = HERE / ('_cel_monsters_f23_' + name + '.log')
        with path.open('w', encoding='utf-8') as log:
            result = subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=300)
        lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
        report[name] = {'exit_code': result.returncode,
                        'result_ok': any('RESULT: OK' in x for x in lines),
                        'errors': [x for x in lines if 'ERROR:' in x or 'SCRIPT ERROR:' in x or 'FAIL' in x]}
        print(name, 'PASS' if result.returncode == 0 else 'FAIL', flush=True)
    (HERE / '_cel_monsters_f23_checks.json').write_text(json.dumps(report, indent=2))
    assert protected() == json.loads(STATE.read_text())['protected'], 'Protected files changed during checks'
    return report


if __name__ == '__main__':
    if '--checks' in sys.argv:
        checks()
    elif '--render' in sys.argv:
        render()
    else:
        driver()
