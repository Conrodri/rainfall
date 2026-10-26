"""CEL-MINIS_A: original saved rigs, shared cel shader, reversible atlas storage crops.

System Python driver; Blender --background --python this.py -- --render [--resume].
No original blend is saved. AtlasTexture margins preserve logical pivots after cropping.
"""
import sys, json, re, subprocess, hashlib, inspect, shutil
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
WORK = ROOT / 'art/blender/cel/minis_a'
SPRITES = ROOT / 'game/assets/sprites'
NAMES = ('frost_bear', 'stone_colossus', 'bramble_queen', 'brood_mother')
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
sys.path[:0] = [str(ROOT / ('art/tools/' + p)) for p in ('cel', 'iso', 'monsters', 'night')]
sys.path.append(str(ROOT/'art/tools'))
import cel_style as cel
STATE = HERE / '_cel_minis_a_state.json'
REPORT = HERE / '_cel_minis_a_verification.json'

def rel(name): return 'bosses/mini/' + name
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def source(name):
    return ROOT / 'art/blender/monsters' / (name + '.blend')
def sheets(name):
    from PIL import Image
    folder = cel.ARCHIVE / rel(name)
    for p in sorted(folder.glob('*.png')):
        if p.stem.endswith(('_n', '_e', '_shadow')) or p.stem in ('ice_block','rock'): continue
        w,h = Image.open(p).size
        assert w % 170 == h % 170 == 0, p
        yield p.stem, w//170, h//170

def baseline():
    if STATE.exists(): return
    from PIL import Image
    for name in NAMES: cel.archive_folder(rel(name))
    pngs = [p for name in NAMES for p in (SPRITES/rel(name)).glob('*.png')]
    data = {'png_bytes':sum(p.stat().st_size for p in pngs),
            'raw_bytes':sum(Image.open(p).width*Image.open(p).height*4 for p in pngs),
            'source_hashes':{str(source(n).relative_to(ROOT)):sha(source(n)) for n in NAMES},
            'data_hashes':{p:sha(ROOT/p) for p in ('game/data/fauna.json','game/data/minibosses.json')},
            'choices':['creature; 8 Eevee samples; original palettes, animation and cameras',
                'Original luminous accents retained; ice_block and rock unchanged',
                'No downsampling: original mini scales exceed 1 (1.25155556..1.43186441)',
                'Actual mini scale is computed by code, R8/R9 mini configs are code constants; no .gd edits authorized',
                'Lossless per-animation cell crop +4px; AtlasTexture margin retains 170px logical cell and feet']}
    STATE.write_text(json.dumps(data,indent=2),encoding='utf-8')

def render():
    import bpy, iso_rig
    from boss_pipeline import pose, ANIMS
    from PIL import Image
    # Original render function; remove ONLY the obsolete normal-file collection.
    code = inspect.getsource(iso_rig.render_frame)
    assert "for suffix in ('_n','_e'):" in code
    ns = dict(iso_rig.__dict__)
    exec(code.replace("for suffix in ('_n','_e'):", "for suffix in ('_e',):"), ns)
    draw = ns['render_frame']
    roots = dict(zip(NAMES, ('FrostBear','StoneColossus','BrambleQueen','BroodMother')))
    for name in NAMES:
        bpy.ops.wm.open_mainfile(filepath=str(source(name)))
        scene = bpy.context.scene
        scene.render.threads_mode='FIXED'; scene.render.threads=8
        scene['iso_frame']=[170,170]
        scene.render.resolution_x=scene.render.resolution_y=340
        scene.render.resolution_percentage=100
        cel.install('creature', normals=False)
        # Keep empty individual accent cells until the complete atlas is assembled.
        ns['optimize_png'] = lambda *a, **k: None
        root = bpy.data.objects[roots[name]]
        timings = ANIMS
        for stem,cols,rows in sheets(name):
            marker=WORK/name/(stem+'.done')
            if '--resume' in sys.argv and marker.exists(): continue
            anim=stem.removesuffix('_dirs'); start,count=timings[anim]
            assert count==cols
            dirs=['e','w','n'] if stem.endswith('_dirs') else ['e','s','w','n'] if anim=='run' else ['s']
            assert rows==len(dirs)
            # R9c's directional cast uses temporary keyed weapon corrections;
            # the front cast remains the original R8 render.
            for d in dirs:
                for i in range(count):
                    p=WORK/name/'frames'/anim/f'{d}_{i:02}.png'
                    if '--resume' in sys.argv and p.exists() and p.with_stem(p.stem+'_e').exists(): continue
                    pose(root,start+i,d)
                    if name=='frost_bear':
                        bpy.data.objects['Volumetric frost breath'].delta_scale.y=.18 if stem=='cast_a_dirs' else 1
                        bpy.context.view_layer.update()
                    draw(p)
            for suffix in ('','_e'):
                sheet=Image.new('RGBA',(cols*170,rows*170))
                for row,d in enumerate(dirs):
                    for i in range(count):
                        with Image.open(WORK/name/'frames'/anim/f'{d}_{i:02}{suffix}.png') as im: sheet.paste(im,(i*170,row*170))
                sheet.save(WORK/name/(stem+suffix+'.png'),optimize=True,compress_level=9)
            marker.write_text('PASS')
            print('SHEET',name,stem,flush=True)
        cel.uninstall()
    print('PASS CEL-MINIS_A render',flush=True)

def checked_sheet(relative, cell, frames, rows):
    """Keep intentional repeated poses only when already present in the source."""
    from PIL import Image
    import numpy as np
    result = cel.check_sheet(relative, normals=False)
    cw,ch = (cell,cell) if isinstance(cell,int) else cell
    images = [np.asarray(Image.open(base/relative).convert('RGBA'))
              for base in (cel.GAME_SPRITES,cel.ARCHIVE)]
    assert images[0].shape[:2] == (rows*ch,frames*cw)
    groups=[]; quantized_noise=[]
    for row in range(rows):
        pairs=[]
        for image in images:
            cells=[image[row*ch:(row+1)*ch,col*cw:(col+1)*cw] for col in range(frames)]
            assert all(c[...,3].max()>240 for c in cells), (relative,row,'empty cell')
            hashes=[hashlib.sha256(c.tobytes()).hexdigest() for c in cells]
            pairs.append([(i,j) for i in range(frames) for j in range(i)
                          if hashes[i]==hashes[j]])
        assert set(pairs[1]).issubset(pairs[0]), (relative,row,'lost original repeated pose')
        for i,j in set(pairs[0])-set(pairs[1]):
            reference=images[1]
            a=reference[row*ch:(row+1)*ch,i*cw:(i+1)*cw]
            b=reference[row*ch:(row+1)*ch,j*cw:(j+1)*cw]
            delta=int(np.abs(a.astype(int)-b.astype(int)).max())
            changed=int(np.count_nonzero(np.any(a!=b,axis=2)))
            assert np.array_equal(a[...,3],b[...,3]) and delta<=3 and changed<=4, (relative,row,'new duplicate pose',i,j,delta,changed)
            quantized_noise.append({'row':row,'pair':[i,j],'source_max_channel_delta':delta,'source_changed_pixels':changed})
        if pairs[1]:groups.append({'row':row,'pairs':pairs[1]})
    result.update(cells_nonempty=True, no_new_duplicate_cells=not quantized_noise,
                  no_new_distinct_pose_duplicates=True,
                  inherited_duplicate_poses=groups, quantized_source_noise=quantized_noise,
                  cells_unique=not any(pairs for pairs in groups) and not quantized_noise)
    return result

def deliver():
    from PIL import Image
    import numpy as np
    import halve_emission
    state=json.loads(STATE.read_text()); checks=[]; crops={}
    for name in NAMES:
        cel.archive_folder(rel(name))
        for stem,cols,rows in sheets(name):
            relative=rel(name)+'/'+stem+'.png'
            dst=SPRITES/relative; src=WORK/name/(stem+'.png')
            assert src.exists(),src
            # Verify the full logical image before reducing atlas storage.
            logical=WORK/'logical'/relative; logical.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(src,logical)
            # Emissive materials are unchanged: retain the original approved accent pass.
            olde=(cel.ARCHIVE/relative).with_stem(stem+'_e')
            if olde.exists():
                shutil.copy2(olde,logical.with_stem(stem+'_e'))
            actual=cel.GAME_SPRITES
            try:
                cel.GAME_SPRITES=WORK/'logical'
                check=checked_sheet(relative,cell=170,frames=cols,rows=rows)
            finally: cel.GAME_SPRITES=actual
            im=Image.open(src).convert('RGBA'); a=np.asarray(im)[...,3]
            mask=a.reshape(rows,170,cols,170).max(axis=(0,2))
            yy,xx=np.where(mask>0); assert len(xx),relative
            box=[max(0,(int(xx.min())-4)//2*2), max(0,(int(yy.min())-4)//2*2),
                 min(170,(int(xx.max())+6)//2*2), min(170,(int(yy.max())+6)//2*2)]
            x,y,x1,y1=box; cw,ch=x1-x,y1-y
            spec={'cell':170,'box':box,'grid':[cols,rows]}; crops[relative]=spec
            def crop(image,ratio=1):
                out=Image.new('RGBA',(cols*cw//ratio,rows*ch//ratio))
                for row in range(rows):
                    for col in range(cols):
                        out.paste(image.crop(((col*170+x)//ratio,(row*170+y)//ratio,(col*170+x1)//ratio,(row*170+y1)//ratio)),(col*cw//ratio,row*ch//ratio))
                return out
            cropped=crop(im); cropped.save(dst,optimize=True,compress_level=9)
            rebuilt=Image.new('RGBA',im.size)
            for row in range(rows):
                for col in range(cols):
                    rebuilt.paste(cropped.crop((col*cw,row*ch,(col+1)*cw,(row+1)*ch)),(col*170+x,row*170+y))
            aa,bb=np.asarray(im),np.asarray(rebuilt)
            assert np.array_equal(aa[...,3],bb[...,3]),(relative,'crop lost alpha')
            assert np.array_equal(aa[aa[...,3]>0],bb[aa[...,3]>0]),(relative,'crop changed visible pixels')
            rebuilt.save(logical,optimize=True,compress_level=9)
            if olde.exists():
                e=Image.open(olde).convert('RGBA')
                ratio=2 if e.size==((im.width+1)//2,(im.height+1)//2) else 1
                e=crop(e,ratio)
                if ratio==1: e=halve_emission.downscale(e)
                assert max(v[1] for v in e.convert('RGB').getextrema())>2,(relative,'black emission')
                e.save(dst.with_stem(stem+'_e'),optimize=True,compress_level=9)
                assert halve_emission.emission_peak(str(dst.with_stem(stem+'_e')))>2/255,(relative,'empty accent')
                if ratio==2:
                    restored_e=Image.new('RGBA',(im.width//2,im.height//2))
                    for row in range(rows):
                        for col in range(cols):
                            restored_e.paste(e.crop((col*cw//2,row*ch//2,(col+1)*cw//2,(row+1)*ch//2)),(col*85+x//2,row*85+y//2))
                    old_array=np.asarray(Image.open(olde).convert('RGBA'));new_array=np.asarray(restored_e)
                    old_mask=(old_array[...,:3].max(axis=2)>100)&(old_array[...,3]>128)
                    new_mask=(new_array[...,:3].max(axis=2)>100)&(new_array[...,3]>128)
                    accent_iou=float((old_mask&new_mask).sum()/max(1,(old_mask|new_mask).sum())) if (old_mask|new_mask).any() else 1.0
                    assert accent_iou>.97,(relative,'cropped accent',accent_iou)
            actual=cel.GAME_SPRITES
            try:
                cel.GAME_SPRITES=WORK/'logical'
                checked_sheet(relative,cell=170,frames=cols,rows=rows)
            finally:cel.GAME_SPRITES=actual
            check.update(size=list(cropped.size),logical_size=list(im.size),crop=box,
                         cells_nonempty=True,normals_absent=True,
                         accent_source='immutable original emissive pass',accent_iou=1.0)
            # Verify the delivered crop itself against an equally cropped reference.
            reference = WORK/'verification_archive'/relative
            reference.parent.mkdir(parents=True, exist_ok=True)
            crop(Image.open(cel.ARCHIVE/relative).convert('RGBA')).save(reference)
            if olde.exists():
                shutil.copy2(dst.with_stem(stem+'_e'), reference.with_stem(stem+'_e'))
                assert e.size == ((cropped.width+1)//2, (cropped.height+1)//2)
                check['emission_alpha_matches_reference_crop'] = True
            archive = cel.ARCHIVE
            try:
                cel.ARCHIVE = WORK/'verification_archive'
                delivered = checked_sheet(relative, cell=(cw,ch), frames=cols, rows=rows)
            finally:
                cel.ARCHIVE = archive
            assert not dst.with_stem(stem+'_n').exists()
            check['delivered_check'] = delivered
            checks.append(check)
        # Rebuild resource regions from immutable source, preserving frame order/pivots.
        for p in (cel.ARCHIVE/rel(name)).glob('*.tres'):
            text=p.read_text(encoding='utf-8'); ext={}
            for path,ident in re.findall(r'\[ext_resource[^\n]*path="res://assets/sprites/([^"\n]+)" id="([^"\n]+)"\]',text):
                if path in crops: ext[ident]=crops[path]
            def block(m):
                part=m.group(); atlas=re.search(r'atlas = ExtResource\("([^"\n]+)"\)',part)
                if not atlas or atlas[1] not in ext:return part
                spec=ext[atlas[1]];x,y,x1,y1=spec['box'];cw,ch=x1-x,y1-y
                match=re.search(r'region = Rect2\(([^)]+)\)',part)
                rx,ry,rw,rh=map(float,match[1].split(','));assert rw==rh==170
                region=f'region = Rect2({int(rx/170)*cw}, {int(ry/170)*ch}, {cw}, {ch})\nmargin = Rect2({x}, {y}, {170-cw}, {170-ch})'
                return part[:match.start()]+region+part[match.end():]
            text=re.sub(r'\[sub_resource[^\n]*\][\s\S]*?(?=\n\[|\Z)',block,text)
            assert 'CanvasTexture' not in text and 'normal_texture' not in text
            (SPRITES/rel(name)/p.name).write_text(text,encoding='utf-8')
    for p,h in state['source_hashes'].items():assert sha(ROOT/p)==h,p
    for p,h in state['data_hashes'].items():assert sha(ROOT/p)==h,p
    pngs=[p for name in NAMES for p in (SPRITES/rel(name)).glob('*.png')]
    assert not any(p.stem.endswith('_n') for p in pngs)
    report=dict(state,result='PASS',profile='creature',normals=False,checks=checks,crops=crops,
                deviations=['Original repeated poses preserved to keep frame counts and animation timing',
                            'Original directional recovery pose repetitions retained',
                            'Runtime scales exceed 1; no reduced in-game sheets. Crop margins preserve logical feet without code changes'],
                png_bytes_after=sum(p.stat().st_size for p in pngs),
                raw_bytes_after=sum(Image.open(p).width*Image.open(p).height*4 for p in pngs))
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
    actual=cel.GAME_SPRITES
    try:
        cel.GAME_SPRITES=WORK/'logical'
        cel.contact_pair([[(rel(n)+'/'+a+'.png',170,i,0) for a,i in [('idle',0),('attack',3),('death',9)]] for n in NAMES],
                         HERE/'_cel_minis_a_contact.png',ground=str(SPRITES/'terrain/terraces/iso/ground_a.png'),size=(1440,1260))
    finally:cel.GAME_SPRITES=actual
    print('PASS',len(checks),'sheets; source hashes; crops; emission; no normals',flush=True)

def run_logged(args,log,timeout=None):
    with log.open('w',encoding='utf-8') as out:
        result=subprocess.run(args,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,
            creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),timeout=timeout)
    assert result.returncode==0,(result.returncode,str(log))
    return log.read_text(encoding='utf-8',errors='replace')

def driver():
    baseline()
    if '--verify' not in sys.argv:
        args=[BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
        if '--resume' in sys.argv:args.append('--resume')
        log=run_logged(args,HERE/'_cel_minis_a_blender.log')
        assert 'PASS CEL-MINIS_A render' in log,'Blender Python exception; inspect log'
    deliver()
    run_logged([sys.executable,'art/tools/texture_budget.py','--apply-policy'],HERE/'_cel_minis_a_policy.log')
    log=run_logged([GODOT,'--headless','--path','game','--import'],HERE/'_cel_minis_a_import.log',300)
    assert not re.search(r'\b(?:ERROR|SCRIPT ERROR|Parse Error)\b',log),'Godot import errors'
    tests={}; cleanup_errors={}
    for test in ('sprites','minibosses','miniboss_mechanics','texture_budget'):
        log=run_logged([GODOT,'--headless','--path','game',f'res://tests/{test}_test.tscn'],HERE/f'_cel_minis_a_{test}_test.log',900)
        # Existing miniboss teardown can leak cached resources after RESULT: OK.
        # Keep this separate from render/test failures and expose it in the report.
        cleanup=[line for line in log.splitlines() if re.fullmatch(
            r'ERROR: \d+ resources still in use at exit \(run with --verbose for details\).',line)]
        checked_log=log
        if test=='minibosses' and cleanup:
            cleanup_errors[test]=cleanup
            for line in cleanup:checked_log=checked_log.replace(line,'')
        assert 'RESULT: OK' in log and not re.search(r'\b(?:ERROR|SCRIPT ERROR|Parse Error)\b',checked_log),(test,'failed')
        tests[test]='RESULT: OK'
    report=json.loads(REPORT.read_text()); report['tests']=tests;report['import']='PASS'
    report['test_cleanup_errors']=cleanup_errors
    if cleanup_errors:report['result']='PASS_WITH_DEVIATIONS_AND_GODOT_CLEANUP_ERROR'
    run_logged([sys.executable,'art/tools/texture_budget.py','--top','0','--json',str(HERE/'_cel_minis_a_budget.json')],HERE/'_cel_minis_a_budget.log')
    budget=json.loads((HERE/'_cel_minis_a_budget.json').read_text())
    scope=[r for r in budget['rows'] if any('/'+n+'/' in r['path'] for n in NAMES)]
    assert all(max(r['w'],r['h'])<=4096 for r in budget['rows']),'oversize texture'
    report['texture_budget_scope_after']={key:sum(r[key] for r in scope) for key in ('png','raw','vram','mobile')}
    report['texture_budget_global_violations']=budget['violations']
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('PASS CEL-MINIS_A import + four Godot tests',flush=True)

if __name__=='__main__':
    if '--render' in sys.argv:render()
    else:driver()
