"""F2/F3 CEL: original saved scenes and renderer; system driver / -- --render.

Only shading changes. Water/void reuse F1's periodic two-tone method, without ink.
Existing shadow decals and metadata remain byte-identical. No normal-map output.
"""
from pathlib import Path
import sys, json, hashlib, subprocess, inspect, importlib, shutil
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(HERE), str(ROOT/'art/tools/terrain')]
import cel_style as cel
LOTS = {'f2': 'terrain/fog_forest/iso', 'f3': 'terrain/rust_city/iso'}
STATE = HERE/'_cel_terrain_f23_render.json'
REPORT = HERE/'_cel_terrain_f23_verification.json'
BASELINE = HERE/'_cel_terrain_f23_baseline.json'

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def snapshot():
    files = [p for rel in LOTS.values() for p in (cel.GAME_SPRITES/rel).iterdir()
             if p.suffix in ('.tres', '.json', '.import')]
    files += [p for lot in LOTS for p in (ROOT/'art/blender/terrain').glob(lot+'_*.blend')]
    return {str(p.relative_to(ROOT)): digest(p) for p in files}

def render():
    import bpy
    sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
    from PIL import Image
    state = json.loads(STATE.read_text()) if STATE.exists() and '--resume' in sys.argv else {}
    for lot, rel in LOTS.items():
        source = importlib.import_module(lot+'_build')
        rig = source.rig
        # Reuse the original renderer, dropping only compulsory normal enumeration.
        code = inspect.getsource(rig.render_frame).replace("for suffix in ('_n','_e'):", "for suffix in ('_e',):")
        exec(compile(code, str(Path(rig.__file__)), 'exec'), rig.__dict__)
        out, arch = cel.GAME_SPRITES/rel, cel.ARCHIVE/rel
        for name, (size, pivot) in source.SPECS.items():
            key = lot+'/'+name
            path = out/(name+'.png')
            patterned = name.startswith(('water', 'void'))
            if key in state and (not patterned or state[key].get('pattern_revision') == 1) and digest(path) == state[key]['sha256'] and all(
                    digest(out/f) == h for f, h in state[key]['outputs'].items()):
                continue
            cel.uninstall()
            bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/terrain'/(lot+'_'+name+'.blend')))
            scene = bpy.context.scene
            assert tuple(scene['iso_frame']) == tuple(size)
            camera = {k: list(getattr(scene.camera, k)) for k in ('location', 'rotation_euler')}
            profile = 'tile'
            noise_sources = {}
            if name.startswith(('water', 'void')):
                profile = cel.profile('tile'); profile.update(tones=2, creases=False)
                for mat in bpy.data.materials:
                    if not mat.use_nodes: continue
                    noise = next((n for n in mat.node_tree.nodes if n.type == 'TEX_NOISE'), None)
                    if noise:
                        noise_sources[mat] = {s.name: s.default_value for s in noise.inputs if s.type == 'VALUE'}
            cel.install(profile, normals=False)
            # install defers material conversion until configure_passes; build
            # the shared ramp now so the periodic pattern can be connected.
            cel.toon_materials(profile)
            for mat, values in noise_sources.items():
                tree = mat.node_tree
                ramp = tree.nodes.get('CEL tones')
                if ramp is None: continue
                noise = tree.nodes.new('ShaderNodeTexNoise')
                for k, v in values.items():
                    if k in noise.inputs: noise.inputs[k].default_value = v
                source.periodic(mat, 8 if name.startswith('void') else 2)
                scale = tree.nodes.new('ShaderNodeMath'); scale.operation = 'MULTIPLY'
                scale.inputs[1].default_value = 2 * cel.TONE_STOPS[1]
                tree.links.new(noise.outputs['Fac'], scale.inputs[0])
                tree.links.new(scale.outputs[0], ramp.inputs['Fac'])
            rig.render_frame(path)
            if name.startswith('ground'):
                # Same contractual diamond mask assembly as CEL terrain F1.
                with Image.open(path) as im, Image.open(arch/path.name) as old:
                    result=im.convert('RGBA'); result.putalpha(old.getchannel('A'))
                    result.save(path,optimize=True)
            ep = out/(name+'_e.png')
            if not (arch/ep.name).exists(): ep.unlink(missing_ok=True)
            else:
                # Accent is unchanged by diffuse cel shading. Keep the authored
                # half-resolution mask, including its original peak filtering.
                shutil.copy2(arch/ep.name,ep)
            outputs = [path] + ([ep] if ep.exists() else [])
            state[key] = dict(sha256=digest(path), outputs={p.name:digest(p) for p in outputs},
                              size=size, pivot=pivot, camera=camera,
                              profile='tile:2,no-ink' if noise_sources else 'tile',
                              pattern_revision=1 if patterned else None)
            STATE.write_text(json.dumps(state, indent=2))
            print('PASS render '+key, flush=True)
    print('PASS F23 render complete',flush=True)

def verify():
    import numpy as np
    from PIL import Image
    results, samples, edges = [], [], []
    before = after = 0
    for lot, rel in LOTS.items():
        arch, out = cel.ARCHIVE/rel, cel.GAME_SPRITES/rel
        archived = json.loads((arch/'.archived.json').read_text())
        assert all(digest(arch/f) == sha for f, sha in archived.items()), ('archive changed', rel)
        files = sorted(arch.glob('*.png'))
        normal = lambda p: p.stem.endswith('_n') and p.with_name(p.stem[:-2]+'.png').exists()
        emission = lambda p: p.stem.endswith('_e') and p.with_name(p.stem[:-2]+'.png').exists()
        diffuse = [p for p in files if not normal(p) and not emission(p) and not p.stem.endswith('_shadow')]
        assert {p.name for p in out.glob('*.png')} == {p.name for p in files if not normal(p)}
        before += sum(p.stat().st_size for p in files if not normal(p))
        after += sum(p.stat().st_size for p in out.glob('*.png'))
        row = []
        for p in diffuse:
            with Image.open(p) as im: size = im.size
            item = cel.check_sheet(rel+'/'+p.name, cell=size, frames=1, rows=1, normals=False)
            item.update(size=size, no_normal=not (out/(p.stem+'_n.png')).exists(), cells=1)
            assert item['no_normal']
            if p.stem.startswith(('water', 'void')):
                color = np.asarray(Image.open(out/p.name).convert('RGBA'))
                rgb = color[:, :, :3][color[:, :, 3] > 240]
                _, counts = np.unique(rgb, axis=0, return_counts=True)
                item['pattern_tone_pixels'] = sorted(counts.tolist(), reverse=True)[:2]
                assert len(counts) >= 2 and sorted(counts)[-2] > len(rgb)*.01, (p.name, 'flat periodic pattern')
            ep = out/(p.stem+'_e.png')
            if ep.exists():
                a = np.asarray(Image.open(arch/ep.name).convert('RGBA'))
                b = np.asarray(Image.open(ep).convert('RGBA'))
                assert a.shape == b.shape
                aa = (a[:,:,:3].max(2)>100)&(a[:,:,3]>128)
                bb = (b[:,:,:3].max(2)>100)&(b[:,:,3]>128)
                item['accent_iou_half'] = float((aa&bb).sum()/max(1,(aa|bb).sum()))
                assert item['accent_iou_half'] > .97, item
                assert (b[:,:,:3].max(2)*(b[:,:,3].astype(float)/255)).max()>2
            results.append(item)
            # All subjects represented; large void sampled at its central area.
            cell = size if max(size)<=512 else (512,512)
            row.append((rel+'/'+p.name,cell,0,0))
            if len(row)==3: samples.append(row); row=[]
        if row: samples.append(row)
        for p in files:
            if p.stem.endswith('_shadow'): assert digest(p)==digest(out/p.name)
        for suffix in 'abcd':
            arrays = [np.asarray(Image.open(base/('ground_'+suffix+'.png')).convert('RGBA')) for base in (arch,out)]
            a_mask, b_mask = (x[:,:,3] > 128 for x in arrays)
            assert (a_mask & b_mask).sum() / max(1, (a_mask | b_mask).sum()) > .97, (lot,suffix,'floor coverage')
            def seam(a):
                x=np.arange(12,244); y=np.round(128-x*.5).astype(int)
                return float(np.abs(a[y+3,x,:3].astype(float)-a[y+125,x+256,:3]).mean())
            a,b=map(seam,arrays)
            assert b <= max(12.,a*1.5), (lot,suffix,'seam',a,b)
            edges.append(dict(lot=lot,tile=suffix,archive_rgb_delta=a,cel_rgb_delta=b))
    cel.contact_pair(samples,HERE/'_cel_terrain_f23_contact.png',ground=LOTS['f2']+'/ground_a.png',size=(3600,3600))
    # Append CS1 right-half shading reference to the same single inspection board.
    board=Image.open(HERE/'_cel_terrain_f23_contact.png').convert('RGBA')
    ref=Image.open(HERE/'_cs1_contact.png').convert('RGBA')
    ref=ref.crop((ref.width//2,0,ref.width,ref.height)); ref.thumbnail((600,400))
    board.alpha_composite(ref,(3600-ref.width,3600-ref.height))
    board.convert('RGB').save(HERE/'_cel_terrain_f23_contact.png',optimize=True)
    report=dict(status='PASS',sheets=results,floor_edges=edges,bytes_before=before,bytes_after=after,
                choices=['Original F2/F3 saved geometry, cameras, pivots and material hues; original render_frame imported.',
                         'tile: three tones, no silhouette ink; water/void two periodic tones without ink, shared night shadow floor.',
                         'Original shadow decals and authored half-resolution emission masks byte-identical; exact archived diamond alpha assembled as in F1.',
                         '18 diffuse per folder (not 19): actual original inventory; each diffuse is one cell/frame.'])
    REPORT.write_text(json.dumps(report,indent=2))
    print('PASS verification '+str(len(results))+' diffuse',flush=True)

def checks():
    commands=[('policy',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy']),
              ('budget',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--top','0','--json',str(HERE/'_cel_terrain_f23_budget.json')]),
              ('import',[cel.GODOT,'--headless','--path',str(ROOT/'game'),'--import'])]
    commands += [(n,[cel.GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+n+'.tscn'])
                 for n in ('sprites_test','foret_iso_test','cite_iso_test','maps_test','texture_budget_test')]
    results=[]
    for name,args in commands:
        logpath=HERE/('_cel_terrain_f23_'+name+'.log')
        with logpath.open('w',encoding='utf-8') as log:
            run=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=300)
        content=logpath.read_text(encoding='utf-8',errors='replace')
        ok=run.returncode==0
        if name=='budget':
            ok=ok and not any(line.strip().startswith('- > 4096 px :') for line in content.splitlines())
        if name.endswith('_test'): ok=ok and 'RESULT: OK' in content
        if name=='import': ok=ok and 'ERROR:' not in content
        entry=dict(check=name,returncode=run.returncode,pass_check=ok,log=str(logpath.relative_to(ROOT)))
        if name=='budget':
            entry['global_budget_warnings']=[line.strip() for line in content.splitlines() if line.startswith('  - ')]
        results.append(entry)
        print(('PASS ' if ok else 'FAIL ')+name,flush=True)
    protected=json.loads(BASELINE.read_text())
    assert all(digest(ROOT/p)==sha for p,sha in protected.items()), 'protected file changed'
    report=json.loads(REPORT.read_text()); report.update(checks=results,protected_files_unchanged=True,
        status='PASS' if all(r['pass_check'] for r in results) else 'FAIL')
    REPORT.write_text(json.dumps(report,indent=2))
    assert report['status']=='PASS', 'See check logs'

def driver():
    for rel in LOTS.values(): cel.archive_folder(rel)
    if not BASELINE.exists(): BASELINE.write_text(json.dumps(snapshot(),indent=2))
    if '--checks-only' in sys.argv: checks(); return
    if '--verify-only' not in sys.argv:
        args=[cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
        if '--resume' in sys.argv: args.append('--resume')
        with (HERE/'_cel_terrain_f23_blender.log').open('w',encoding='utf-8') as log:
            subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
        assert 'PASS F23 render complete' in (HERE/'_cel_terrain_f23_blender.log').read_text(encoding='utf-8',errors='replace'), 'Blender render failed; see log'
    verify()
    if '--verify-only' not in sys.argv: checks()

if __name__=='__main__':
    render() if '--render' in sys.argv else driver()
