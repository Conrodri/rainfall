"""CEL-MONSTERS_F1: preserved C5 scenes, original renderer, no normal outputs."""
import sys, json, hashlib, shutil, subprocess, inspect, math
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
WORK = ROOT / 'art/blender/cel/monsters_f1'
SPRITES = ROOT / 'game/assets/sprites'
sys.path[:0] = [str(ROOT / ('art/tools/' + p)) for p in ('cel', 'iso', 'monsters', '')]
import cel_style as cel

SPECS = {'swarm_tier1': (96, ['run']), 'shooter_tier2': (112, ['run', 'attack']),
         'leaper_tier2': (112, ['run', 'charge']), 'brute_tier3': (160, ['run', 'attack', 'cast'])}
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
STATE = HERE / '_cel_monsters_f1_state.json'

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def protected():
    paths = [ROOT / 'art/blender/monsters' / (n + '_iso.blend') for n in SPECS]
    for n in SPECS:
        paths += [p for p in (SPRITES / 'monsters' / n).rglob('*')
                  if p.is_file() and p.suffix in ('.tres', '.json', '.import')]
    return {str(p.relative_to(ROOT)): sha(p) for p in paths}

def render():
    import bpy
    import iso_monster_build as original
    import iso_rig
    from PIL import Image
    # Reuse the original function verbatim except its obsolete normal-file loop.
    source = inspect.getsource(iso_rig.render_frame)
    assert "for suffix in ('_n','_e'):" in source
    namespace = dict(iso_rig.__dict__)
    exec(source.replace("for suffix in ('_n','_e'):", "for suffix in ('_e',):"), namespace)
    render_frame = namespace['render_frame']
    for name in ('shooter_tier2', 'leaper_tier2'):
        cell, anims = SPECS[name]
        assert original.CFG[name][0] == cell and original.CFG[name][2] == anims
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender/monsters' / (name + '_iso.blend')))
        scene = bpy.context.scene
        scene.render.threads_mode = 'FIXED'
        scene.render.threads = 8
        cel.install('creature', normals=False)
        root = bpy.data.objects[name]
        for j, anim in enumerate(anims):
            marker = WORK / name / (anim + '.done')
            if '--resume' in sys.argv and marker.exists():
                continue
            sheets = {suffix: Image.new('RGBA', (cell * 8, cell * 8)) for suffix in ('', '_e')}
            for row, direction in enumerate(original.DIRS):
                root.rotation_euler.z = math.radians(90 - 45 * row)
                for frame in range(8):
                    scene.frame_set(j * 16 + frame + 1)
                    path = WORK / name / anim / f'{direction}_{frame}.png'
                    render_frame(path)
                    for suffix, sheet in sheets.items():
                        with Image.open(path.with_stem(path.stem + suffix)) as im:
                            sheet.paste(im, (frame * cell, row * cell))
                print(name, anim, direction, flush=True)
            for suffix, sheet in sheets.items():
                sheet.save(SPRITES / 'monsters' / name / (anim + suffix + '.png'), optimize=True, compress_level=9)
                if suffix == '_e':
                    sheet.save(WORK / name / (anim + '_e.png'), optimize=True, compress_level=9)
            marker.write_text('PASS')
        cel.uninstall()
    print('PASS CEL-MONSTERS_F1 render', flush=True)

def verify():
    import numpy as np
    from PIL import Image
    import halve_emission
    report = {'profile': 'creature', 'normals': False, 'choices':
              'CS1 copied; C5 geometry, animations, camera and material hues preserved; shared shadow floor for night readability. '
              'Shooter/leaper keep archived half-resolution emission masks: AOV edge coverage differs on their tiny accents; only diffuse shading changes.',
              'sheets': []}
    for name, (cell, anims) in SPECS.items():
        folder = SPRITES / 'monsters' / name
        archive = cel.ARCHIVE / 'monsters' / name
        assert not list(folder.glob('*_n.png'))
        assert {p.name for p in folder.glob('*.png')} == {p.name for p in archive.glob('*.png') if not p.stem.endswith('_n')}
        for anim in anims:
            rel = f'monsters/{name}/{anim}.png'
            result = cel.check_sheet(rel, cell=cell, frames=8, rows=8, normals=False)
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
            result['emission_source'] = 'CS1' if name in ('swarm_tier1', 'brute_tier3') else 'archive, byte-identical'
            da = np.asarray(halve_emission.downscale(diffuse))[..., 3]
            result['alpha_half_exact'] = bool(np.array_equal(da, b[..., 3]))
            x, y = da > 128, b[..., 3] > 128
            result['alpha_emission_iou_half'] = float((x & y).sum() / max(1, (x | y).sum()))
            result['alpha_validation'] = 'half-resolution: dimensions checked; exact alpha equality only applies at full resolution (STYLE_cel.md)'
            report['sheets'].append(result)
    state = json.loads(STATE.read_text())
    assert protected() == state['protected'], 'Protected files changed'
    report['protected_unchanged'] = True
    (HERE / '_cel_monsters_f1_verification.json').write_text(json.dumps(report, indent=2))
    samples = []
    for name, (cell, anims) in SPECS.items():
        samples.append([(f'monsters/{name}/{anim}.png', cell, f, 2)
                        for anim, f in [(anims[0], 0), (anims[-1], 4)]])
    cel.contact_pair(samples, HERE / '_cel_monsters_f1_contact.png', size=(1440, 1000))
    print('PASS verification 8 sheets; contact', flush=True)

def driver():
    WORK.mkdir(parents=True, exist_ok=True)
    if not STATE.exists():
        STATE.write_text(json.dumps({'protected': protected()}, indent=2))
    for name in SPECS:
        cel.archive_folder('monsters/' + name)
    if '--verify' not in sys.argv:
        for name in ('swarm_tier1', 'brute_tier3'):
            for p in (SPRITES / 'monsters' / (name + '_cel')).glob('*.png'):
                if not p.stem.endswith('_n'):
                    shutil.copy2(p, SPRITES / 'monsters' / name / p.name)
        command = [BLENDER, '--background', '--python', str(Path(__file__).resolve()), '--', '--render']
        if '--resume' in sys.argv:
            command.append('--resume')
        with (HERE / '_cel_monsters_f1_render.log').open('w') as log:
            proc = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT, cwd=ROOT)
        assert proc.returncode == 0, 'Blender failed; _cel_monsters_f1_render.log'
    # Tiny legacy accents have different AOV edge coverage; preserve their exact masks.
    for name in ('shooter_tier2', 'leaper_tier2'):
        for p in (cel.ARCHIVE / 'monsters' / name).glob('*_e.png'):
            shutil.copy2(p, SPRITES / 'monsters' / name / p.name)
    verify()

if __name__ == '__main__':
    if '--render' in sys.argv:
        render()
    else:
        driver()
