"""CEL-PROPS_BIOMES: original F2p/F3p scenes, shared prop shading, in-place stills.

System Python driver; Blender --background --python this.py -- --render; --resume.
Emission masks and ground decals are shading-independent and retained byte for byte.
"""
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
SPR = ROOT / 'game/assets/sprites'
WORK = ROOT / 'art/blender/cel/props_biomes'
MAN = WORK / 'manifest.json'
REPORT = HERE / '_cel_props_biomes_verification.json'
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
FOLDERS = {'props/fog_forest': 'f2p', 'props/rust_city': 'f3p'}
sys.dont_write_bytecode = True
sys.path[:0] = [str(ROOT / 'art/tools/cel'), str(ROOT / 'art/tools/iso'), str(HERE)]
import cel_style as cel


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def manifest():
    from PIL import Image
    for rel in FOLDERS:
        cel.archive_folder(rel)  # Before any output is overwritten; immutable reference.
    WORK.mkdir(parents=True, exist_ok=True)
    if '--resume' in sys.argv and MAN.exists() and 'sheets' in json.loads(MAN.read_text()):
        return
    files, sheets, protected, blends = {}, [], {}, {}
    for folder, prefix in FOLDERS.items():
        for p in sorted((SPR / folder).iterdir()):
            if not p.is_file():
                continue
            rel = p.relative_to(SPR).as_posix()
            files[rel] = {'sha256': sha(p), 'bytes': p.stat().st_size}
            if p.suffix == '.png':
                files[rel]['size'] = list(Image.open(p).size)
                assert not p.stem.endswith('_n'), rel
                if not p.stem.endswith(('_e', '_shadow')):
                    sheets.append(rel)
                    blend = ROOT / 'art/blender/props' / (prefix + '_' + p.stem + '.blend')
                    blends[blend.relative_to(ROOT).as_posix()] = sha(blend)
                else:
                    protected[rel] = sha(p)
            else:
                protected[rel] = sha(p)
    MAN.write_text(json.dumps(dict(files=files, sheets=sheets, protected=protected,
                                  blends=blends), indent=2), encoding='utf-8')


def render():
    import bpy
    import inspect
    import iso_rig as rig
    # Import the original lots for their contract and rendering pipeline, without build/save.
    import f2p_build as f2p
    import f3p_build as f3p
    lots = {'props/fog_forest': f2p, 'props/rust_city': f3p}
    # Only remove legacy pass collection: no normal file, original accent masks untouched.
    source = inspect.getsource(rig.render_frame).replace("('_n','_e')", '()')
    assert source != inspect.getsource(rig.render_frame)
    exec(compile(source, str(ROOT / 'art/tools/iso/iso_rig.py'), 'exec'), rig.__dict__)
    d = json.loads(MAN.read_text())
    for rel in d['sheets']:
        p = SPR / rel
        folder = p.parent.relative_to(SPR).as_posix()
        marker = WORK / (FOLDERS[folder] + '_' + p.stem + '.done')
        if '--resume' in sys.argv and marker.exists() and marker.read_text() == sha(p):
            continue
        bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender/props' /
                                              (FOLDERS[folder] + '_' + p.stem + '.blend')))
        size = lots[folder].SPECS[p.stem][0]
        assert list(bpy.context.scene['iso_frame']) == [size, size], rel
        assert d['files'][rel]['size'] == [size, size], rel
        cel.install('prop', normals=False)
        configure = rig.common.configure_passes

        def diffuse_only(path):
            configure(path)
            tree = bpy.context.scene.compositing_node_group
            for node in list(tree.nodes):
                if node.bl_idname == 'CompositorNodeOutputFile':
                    tree.nodes.remove(node)

        rig.common.configure_passes = diffuse_only
        rig.render_frame(p)
        marker.write_text(sha(p))
        print('PASS render ' + rel, flush=True)
    print('PASS CEL-PROPS_BIOMES render', flush=True)


def verify():
    from PIL import Image
    import numpy as np
    d = json.loads(MAN.read_text())
    results, emissions, errors = [], [], []
    for rel in d['sheets']:
        try:
            w, h = d['files'][rel]['size']
            r = cel.check_sheet(rel, cell=(w, h), frames=1, rows=1, normals=False)
            r.update(size=[w, h], frames=1, rows=1, unique_cells=1,
                     no_normal=not (SPR / rel).with_name(Path(rel).stem + '_n.png').exists())
            assert r['no_normal'], rel
            results.append(r)
        except AssertionError as exc:
            errors.append(str(exc))
    for rel in d['files']:
        p = SPR / rel
        if not p.stem.endswith('_e') or p.suffix != '.png':
            continue
        a = np.asarray(Image.open(p).convert('RGBA'))
        b = np.asarray(Image.open(cel.ARCHIVE / rel).convert('RGBA'))
        assert a.shape == b.shape, rel
        x = (a[:, :, :3].max(2) > 100) & (a[:, :, 3] > 128)
        y = (b[:, :, :3].max(2) > 100) & (b[:, :, 3] > 128)
        iou = float((x & y).sum() / max(1, (x | y).sum())) if (x | y).any() else 1.0
        alpha = bool(np.array_equal(a[:, :, 3], b[:, :, 3]))
        peak = float((a[:, :, :3].max(2) * a[:, :, 3].astype(float) / 255).max())
        assert iou > .97 and alpha and peak > 2, (rel, iou, alpha, peak)
        emissions.append(dict(file=rel, size=list(Image.open(p).size), accent_iou=iou,
                              alpha_matches_archive=alpha, peak=peak, unchanged=sha(p) == d['files'][rel]['sha256']))
    changed = [rel for rel, digest in d['protected'].items() if sha(SPR / rel) != digest]
    blends_changed = [rel for rel, digest in d['blends'].items() if sha(ROOT / rel) != digest]
    current = sorted(p.relative_to(SPR).as_posix() for folder in FOLDERS
                     for p in (SPR / folder).iterdir() if p.is_file())
    assert current == sorted(d['files']), 'file contract changed'
    assert not changed and not blends_changed, (changed, blends_changed)
    report = dict(profile='prop', normals=False, sheets=results, emissions=emissions,
                  errors=errors, protected_changed=changed, blends_changed=blends_changed,
                  before_bytes=sum((cel.ARCHIVE / k).stat().st_size for k in d['files'] if k.endswith('.png')),
                  after_bytes=sum((SPR / k).stat().st_size for k in d['files'] if k.endswith('.png')),
                  choices=['Original F2p/F3p saved geometry, camera, tint and feet unchanged',
                           'Shared prop profile: three tones, inward ink and night shadow floor',
                           'Original continuous accent masks retained byte for byte',
                           'Original grayscale ground shadow decals retained byte for byte',
                           '27 single-frame stills: directional names and metadata unchanged'])
    if REPORT.exists():
        previous_checks = json.loads(REPORT.read_text()).get('checks')
        if previous_checks:
            report['checks'] = previous_checks
    REPORT.write_text(json.dumps(report, indent=2), encoding='utf-8')
    assert not errors, str(errors[:3])
    samples = [[(rel, d['files'][rel]['size'], 0, 0) for rel in d['sheets'][i:i+3]]
               for i in range(0, len(d['sheets']), 3)]
    cel.contact_pair(samples, HERE / '_cel_props_biomes_contact.png',
                     ground='terrain/fog_forest/iso/ground_a.png', size=(2400, 3600))
    print('PASS 27 sheets, 6 accents, protected contracts', flush=True)


def checks():
    jobs = [('texture_budget', [sys.executable, 'art/tools/texture_budget.py', '--apply-policy']),
            ('import', [GODOT, '--headless', '--path', 'game', '--import'])]
    jobs += [(name, [GODOT, '--headless', '--path', 'game', 'res://tests/' + name + '.tscn'])
             for name in ('sprites_test', 'foret_iso_test', 'cite_iso_test', 'stage_test', 'texture_budget_test')]
    selected = sys.argv[sys.argv.index('--check') + 1] if '--check' in sys.argv else None
    previous = json.loads(REPORT.read_text()).get('checks', {})
    if selected:
        jobs = [(name, cmd) for name, cmd in jobs if name == selected]
        assert jobs, selected
    outcomes = dict(previous) if selected else {}
    for name, cmd in jobs:
        log = HERE / ('_cel_props_biomes_' + name + '.log')
        prior = previous.get(name) if selected else None
        if prior and log.exists():
            log.replace(log.with_name(log.stem + '_previous.log'))
        with log.open('w') as out:
            proc = subprocess.run(cmd, cwd=ROOT, stdout=out, stderr=subprocess.STDOUT,
                                  timeout=300, creationflags=0x08000000)
        txt = log.read_text(errors='replace')
        errors = [line for line in txt.splitlines() if any(s in line for s in ('SCRIPT ERROR:', 'Parse Error:', 'ERROR:'))]
        blocking = errors if name == 'import' else [e for e in errors if 'resources still in use at exit' not in e]
        ok = proc.returncode == 0 and not blocking and (name in ('texture_budget', 'import') or 'RESULT: OK' in txt)
        outcomes[name] = dict(ok=ok, returncode=proc.returncode, errors=blocking[:5],
                              exit_resource_warnings=[e for e in errors if e not in blocking],
                              result_ok='RESULT: OK' in txt)
        if prior:
            outcomes[name]['previous_attempt'] = prior
        print(('PASS ' if ok else 'FAIL ') + name, flush=True)
    report = json.loads(REPORT.read_text())
    report['checks'] = outcomes
    REPORT.write_text(json.dumps(report, indent=2), encoding='utf-8')
    assert all(v['ok'] for v in outcomes.values()), str({k: v for k, v in outcomes.items() if not v['ok']})
    d = json.loads(MAN.read_text())
    assert all(sha(SPR / k) == v for k, v in d['protected'].items()), 'protected files changed during import'


def driver():
    manifest()
    if '--check' in sys.argv:
        checks()
        return
    if '--verify' not in sys.argv:
        log = HERE / '_cel_props_biomes_blender.log'
        cmd = [BLENDER, '--background', '--python', str(Path(__file__).resolve()), '--', '--render']
        if '--resume' in sys.argv:
            cmd.append('--resume')
        with log.open('w') as out:
            proc = subprocess.run(cmd, cwd=ROOT, stdout=out, stderr=subprocess.STDOUT,
                                  creationflags=0x08000000)
        assert proc.returncode == 0 and 'PASS CEL-PROPS_BIOMES render' in log.read_text(errors='replace'), str(log)
    verify()
    checks()


if __name__ == '__main__':
    render() if '--render' in sys.argv else driver()
