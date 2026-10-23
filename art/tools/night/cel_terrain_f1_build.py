"""CEL terrain F1: system driver / Blender -- --render [--resume]."""
from pathlib import Path
import sys, json, hashlib, subprocess, inspect
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/terrain')]
import cel_style as cel
REL = 'terrain/terraces/iso'
OUT = cel.GAME_SPRITES/REL
ARCH = cel.ARCHIVE/REL
HERE = Path(__file__).resolve().parent
REPORT = HERE/'_cel_terrain_f1_verification.json'
STATE = HERE/'_cel_terrain_f1_render.json'

def digest(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def render():
    import bpy
    import terraces_iso_build as source
    from PIL import Image
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/terrain/terraces_iso.blend'))
    rig = source.rig
    # Compatibility with the legacy assembler: import its function, remove only
    # its compulsory normal-file enumeration; no renderer/settings duplicated.
    code = inspect.getsource(rig.render_frame).replace("for suffix in ('_n','_e'):", "for suffix in ('_e',):")
    exec(compile(code, str(Path(rig.__file__)), 'exec'), rig.__dict__)
    two = cel.profile('tile'); two.update(tones=2, creases=False)
    # Convert only the water/void scene materials with the two-tone profile.
    two_mats = {slot.material for name in source.SPECS if name.startswith(('water','void'))
                for ob in bpy.data.scenes[name].objects for slot in ob.material_slots if slot.material}
    noise_sources = {}
    for mat in two_mats:
        noise = next((n for n in mat.node_tree.nodes if n.type == 'TEX_NOISE'), None)
        if noise:
            noise_sources[mat] = {s.name: s.default_value for s in noise.inputs if s.type == 'VALUE'}
    saved = [(m, m.use_nodes) for m in bpy.data.materials]
    for m, enabled in saved:
        if m not in two_mats: m.use_nodes = False
    cel.toon_materials(two)
    for m, enabled in saved: m.use_nodes = enabled
    # Flat water/abyss must actually show both tones: retain the authored periodic
    # noise as a two-value pattern, using the shared module's installed tone ramp.
    for mat, values in noise_sources.items():
        scene_name = next(name for name in source.SPECS if name.startswith(('water','void')) and
                          any(slot.material == mat for ob in bpy.data.scenes[name].objects for slot in ob.material_slots))
        bpy.context.window.scene = bpy.data.scenes[scene_name]
        tree = mat.node_tree
        noise = tree.nodes.new('ShaderNodeTexNoise')
        for key, value in values.items():
            if key in noise.inputs: noise.inputs[key].default_value = value
        source.periodic(mat,8 if scene_name.startswith('void') else 2)
        ramp = tree.nodes.get('CEL tones')
        scale = tree.nodes.new('ShaderNodeMath'); scale.operation = 'MULTIPLY'
        scale.inputs[1].default_value = 2 * cel.TONE_STOPS[1]
        tree.links.new(noise.outputs['Fac'],scale.inputs[0])
        tree.links.new(scale.outputs[0],ramp.inputs['Fac'])
    state = json.loads(STATE.read_text()) if STATE.exists() and '--resume' in sys.argv else {}
    if '--refresh-water' in sys.argv:
        state = {k:v for k,v in state.items() if not k.startswith(('water','void'))}
    for name, (size, pivot, height) in source.SPECS.items():
        if '--resume' in sys.argv and name in state and digest(OUT/(name+'.png')) == state[name]['sha256']:
            continue
        bpy.context.window.scene = bpy.data.scenes[name]
        scene = bpy.context.scene
        assert list(scene['iso_frame']) == size
        cel.uninstall()
        cel.install(two if name.startswith(('water','void')) else 'tile', normals=False)
        path = OUT/(name+'.png')
        rig.render_frame(path)
        # Original floor diamond is a separately rendered mask. Reuse that exact
        # archived crop rather than invoking the old mask routine (requires _n).
        if name.startswith('ground'):
            with Image.open(path) as im, Image.open(ARCH/path.name) as old:
                result = im.convert('RGBA'); result.putalpha(old.getchannel('A'))
                result.save(path, optimize=True)
        ep = path.with_name(name+'_e.png')
        if not (ARCH/ep.name).exists(): ep.unlink(missing_ok=True)
        elif ep.exists():
            with Image.open(ep) as im, Image.open(ARCH/ep.name) as old:
                result = im.convert('RGBA')
                if result.size != old.size: result = result.resize(old.size, Image.Resampling.LANCZOS)
                result.save(ep, optimize=True)
        state[name] = {'sha256': digest(path), 'profile': 'tile:2,no-ink' if name.startswith(('water','void')) else 'tile',
                       'size': size, 'pivot': pivot, 'camera': list(scene.camera.location)}
        STATE.write_text(json.dumps(state, indent=2))
        print('PASS render '+name, flush=True)

def verify():
    import numpy as np
    from PIL import Image
    files = sorted(ARCH.glob('*.png'))
    is_normal = lambda p: p.stem.endswith('_n') and p.with_name(p.stem[:-2]+'.png').exists()
    is_emission = lambda p: p.stem.endswith('_e') and p.with_name(p.stem[:-2]+'.png').exists()
    diffuse = [p for p in files if not p.stem.endswith('_shadow') and not is_emission(p) and not is_normal(p)]
    results = []
    assert {p.name for p in OUT.glob('*.png')} == {p.name for p in files if not is_normal(p)}
    for p in diffuse:
        with Image.open(p) as im: size = im.size
        item = cel.check_sheet(REL+'/'+p.name, cell=size, frames=1, rows=1, normals=False)
        item.update(size=size, no_normal=not (OUT/(p.stem+'_n.png')).exists())
        assert item['no_normal']
        ep = OUT/(p.stem+'_e.png')
        if ep.exists():
            old = np.asarray(Image.open(ARCH/ep.name).convert('RGBA'))
            new = np.asarray(Image.open(ep).convert('RGBA'))
            a = (old[:,:,:3].max(2)>100)&(old[:,:,3]>128)
            b = (new[:,:,:3].max(2)>100)&(new[:,:,3]>128)
            item['accent_iou_half'] = float((a&b).sum()/max(1,(a|b).sum()))
            assert item['accent_iou_half'] > .97, item
            assert (new[:,:,:3].max(2)* (new[:,:,3].astype(float)/255)).max()>2
        results.append(item)
    # Check unchanged shadow geometry and source file contracts.
    for p in files:
        if p.stem.endswith('_shadow'): assert digest(p) == digest(OUT/p.name)
    # Floor boundaries: identical alpha coverage and seam continuity relative to
    # the archived renderer, sampled between neighbouring diamonds in a 4x4 map.
    def mosaic(base):
        canvas = Image.new('RGBA', (2048,1024))
        for r in range(4):
            for c in range(4):
                tile = Image.open(base/('ground_'+'abcd'[(r*4+c)%4]+'.png')).convert('RGBA')
                canvas.alpha_composite(tile, (768+(c-r)*256,(c+r)*128))
        return canvas
    old, new = mosaic(ARCH), mosaic(OUT)
    aa, bb = np.asarray(old)[:,:,3], np.asarray(new)[:,:,3]
    assert np.array_equal(aa,bb), '4x4 coverage changed'
    # Compare strips just inside all four diamond edges, across one tile period.
    edges = []
    for suffix in 'abcd':
        arr = np.asarray(Image.open(OUT/('ground_'+suffix+'.png')).convert('RGBA')).astype(float)
        ref = np.asarray(Image.open(ARCH/('ground_'+suffix+'.png')).convert('RGBA')).astype(float)
        # Opposite borders follow the same periodic world coordinates.
        def score(a):
            x = np.arange(12,244); y = np.round(128-x*.5).astype(int)
            d = np.abs(a[y+3,x,:3]-a[y+131,x+256,:3])
            return float(d.mean())
        before, after = score(ref), score(arr)
        assert after <= max(12., before*1.5), ('floor edge',suffix,before,after)
        edges.append(dict(tile=suffix, archive_rgb_delta=before, cel_rgb_delta=after))
    # Duplicate floors are authored aliases, retained intentionally.
    assert digest(OUT/'ground_a.png') == digest(OUT/'ground_c.png')
    assert digest(OUT/'ground_b.png') == digest(OUT/'ground_d.png')
    samples = []
    for i in range(0,len(diffuse),3):
        row=[]
        for p in diffuse[i:i+3]:
            with Image.open(p) as im: sz=im.size
            row.append((REL+'/'+p.name,sz,0,0))
        samples.append(row)
    cel.contact_pair(samples,HERE/'_cel_terrain_f1_contact.png',size=(3600,3000))
    # Single final inspection board: pairs, assembled floor, CS1 shading reference.
    contact = Image.open(HERE/'_cel_terrain_f1_contact.png').convert('RGBA')
    board = Image.new('RGBA',(3600,3800),(18,22,23,255))
    board.alpha_composite(contact)
    board.alpha_composite(old.resize((1400,700)),(50,3050))
    board.alpha_composite(new.resize((1400,700)),(1500,3050))
    reference = Image.open(HERE/'_cs1_contact.png').convert('RGBA')
    reference = reference.crop((reference.width//2,0,reference.width,reference.height))
    reference.thumbnail((650,700))
    board.alpha_composite(reference,(2930,3050))
    board.convert('RGB').save(HERE/'_cel_terrain_f1_contact.png',optimize=True)
    old.resize((1024,512)).save(HERE/'_cel_terrain_f1_4x4_archive.png')
    new.resize((1024,512)).save(HERE/'_cel_terrain_f1_4x4.png')
    result = dict(status='PASS', sheets=results, floor_edges=edges, coverage_4x4='identical',
                  bytes_before=sum(p.stat().st_size for p in files if not is_normal(p)),
                  bytes_after=sum(p.stat().st_size for p in OUT.glob('*.png')),
                  choices=['Original scenes, geometry, camera and material hues retained; shading only.',
                           'tile; water/void 2 tones without ink; original periodic noise posterized through shared CEL ramp; night shadow floor from shared module.',
                           'Original shadows unchanged; exact archived diamond alpha reused.',
                           '18 diffuse (not 19); authored ground a/c and b/d duplicates retained.'])
    REPORT.write_text(json.dumps(result,indent=2))
    print('PASS verification '+str(len(results))+' diffuse',flush=True)

def checks():
    protected = {str(p): digest(p) for p in OUT.iterdir() if p.suffix in ('.tres','.json','.import')}
    protected[str(ROOT/'art/blender/terrain/terraces_iso.blend')] = digest(ROOT/'art/blender/terrain/terraces_iso.blend')
    results = []
    commands = [('policy',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy']),
                ('budget',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--top','0','--json',str(HERE/'_cel_terrain_f1_budget.json')]),
                ('import',[cel.GODOT,'--headless','--path',str(ROOT/'game'),'--import'])]
    commands += [(name,[cel.GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+name+'.tscn'])
                 for name in ('sprites_test','maps_test','stage_test','minimap_iso_test','texture_budget_test')]
    for name, args in commands:
        logpath = HERE/('_cel_terrain_f1_'+name+'.log')
        with logpath.open('w') as log:
            run = subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=300)
        logtext = logpath.read_text(encoding='utf-8',errors='replace')
        ok = run.returncode == 0
        if name.endswith('_test'): ok = ok and 'RESULT: OK' in logtext
        if name == 'import': ok = ok and 'ERROR:' not in logtext
        results.append(dict(check=name,returncode=run.returncode,pass_check=ok,log=str(logpath.relative_to(ROOT))))
        print(('PASS ' if ok else 'FAIL ')+name,flush=True)
    assert all(digest(Path(p)) == sha for p,sha in protected.items()), 'protected file changed'
    for p in ARCH.iterdir():
        if p.suffix in ('.tres','.json') and p.name != '.archived.json':
            assert digest(p) == digest(OUT/p.name), 'contract metadata changed'
    report = json.loads(REPORT.read_text())
    report['checks'] = results
    report['protected_files_unchanged'] = True
    report['status'] = 'PASS' if all(r['pass_check'] for r in results) else 'FAIL'
    REPORT.write_text(json.dumps(report,indent=2))
    assert report['status'] == 'PASS', 'See check logs'

def driver():
    cel.archive_folder(REL)
    if '--checks-only' in sys.argv:
        checks(); return
    if '--verify-only' not in sys.argv:
        args=[cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
        if '--resume' in sys.argv: args.append('--resume')
        if '--refresh-water' in sys.argv: args.append('--refresh-water')
        with (HERE/'_cel_terrain_f1_blender.log').open('w') as log:
            subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    verify()
    if '--verify-only' not in sys.argv: checks()

if __name__ == '__main__':
    render() if '--render' in sys.argv else driver()
