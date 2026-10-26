"""CEL-UI: original geometry/cameras, shared ui shading; system driver / Blender --render."""
import sys, json, hashlib, subprocess, importlib, runpy
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
SPR = ROOT/'game/assets/sprites'
WORK = ROOT/'art/blender/cel/ui'
REPORT = ROOT/'art/tools/night/_cel_ui_verification.json'
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/ui'), str(ROOT/'art/tools/iso')]
import cel_style as cel
FOLDERS = ['ui/'+s for s in ('da','cards','joystick','difficulty','menu','prompts','resource_gauge')]
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'

def targets():
    return sorted([p for d in FOLDERS for p in (SPR/d).glob('*.png')] + list((SPR/'ui').glob('spell_frame*.png')) + [SPR/'ui/spell_cooldown_ring.png'])

def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()

def render():
    import bpy
    import ui_kit as kit
    import ui_lib
    manifest = json.loads((WORK/'baseline.json').read_text())
    done = json.loads((WORK/'renders.json').read_text()) if (WORK/'renders.json').exists() else {}
    configure = None

    def capture(rel, mode='resize', margin=3):
        nonlocal configure
        if rel not in manifest['files']:
            return
        raw = WORK/(rel.replace('/','__'))
        if '--resume' in sys.argv and rel in done and raw.exists() and not rel.endswith('_e.png'):
            return
        s = bpy.context.scene
        if rel.endswith('_e.png'):
            # Original dedicated mask scene includes its lit glints; retain its emission shading.
            s.use_nodes=False
        else:
            configure = cel.install('ui', normals=False)
            configure(raw)
        s.render.filepath = str(raw)
        bpy.ops.render.render(write_still=True)
        # compositor files carry frame suffixes; only accent is retained.
        accents = sorted(raw.parent.glob(raw.stem+'_e__*.png'))
        accent = str(accents[-1]) if accents else None
        done[rel] = dict(raw=str(raw), accent=accent, mode=mode, margin=margin)
        (WORK/'renders.json').write_text(json.dumps(done,indent=1))
        print('CEL_UI_RENDER',rel,flush=True)

    # Saved U1 library retains every original scene and camera.
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/ui/u1_library.blend'))
    # Regenerate the original linked emission ramps before cel conversion removes them.
    u1=importlib.import_module('u1_build')
    for rel in manifest['files']:
        if rel.startswith('ui/da/') and rel.endswith('_e.png'):
            bpy.context.window.scene=bpy.data.scenes['U1 '+Path(rel).stem[:-2]]
            raw=WORK/('original_accent__'+Path(rel).name)
            bpy.context.scene.use_nodes=False
            u1.emit_pass(bpy.context.scene,raw)
            done[rel]=dict(raw=str(raw),accent=None,mode='resize',margin=0)
    (WORK/'renders.json').write_text(json.dumps(done,indent=1))
    # Transparent vignette is an authored falloff, not a lit solid.
    for m in bpy.data.materials:
        if m.name.startswith('Blood vignette transparent falloff'):m['cel_done']=True
    for rel in manifest['files']:
        if not rel.startswith('ui/da/') or rel.endswith('_e.png'):
            continue
        name = Path(rel).stem
        s = bpy.data.scenes.get('U1 '+name)
        if s is None:
            raise RuntimeError('Missing original U1 scene '+name)
        bpy.context.window.scene = s
        capture(rel)

    # U2 original construction functions, same recorded fit as u2_finish.
    u2 = importlib.import_module('u2_build')
    for back in (False,True):
        u2.scene('card'); u2.card(back)
        rel = 'ui/cards/card_'+('back' if back else 'front')+'.png'
        w,h = manifest['files'][rel]['size'];u2.front_camera(3.9,5.7,w*2,h*2)
        capture(rel,'u2')
    for state in ('normal','pressed','cooldown'):
        u2.scene('spell_'+state);u2.medal(state)
        rel='ui/spell_frame'+('' if state=='normal' else '_'+state)+'.png'
        w,h=manifest['files'][rel]['size'];u2.front_camera(2.45,2.45,w*2,h*2);capture(rel,'u2')
    u2.scene('ring');u2.torus((0,0,0),1.03,.085,u2.bronze);u2.torus((0,-.05,0),1.03,.015,u2.edge);u2.ticks(1.07,-.09,48)
    u2.front_camera(2.4,2.4,320,320);capture('ui/spell_cooldown_ring.png','u2')
    for kind in ('base','knob'):
        u2.scene('joystick_'+kind);u2.medal('normal',kind)
        rel='ui/joystick/joystick_'+kind+'.png';w,h=manifest['files'][rel]['size']
        u2.front_camera(2.5,2.5,w*2,h*2);capture(rel,'u2')

    # Existing post jobs supply the exact crop/resize contracts; no original saves.
    pending = {}
    def raw_hook(path):
        pending['path']=str(path)
    def post_hook(job):
        rel=Path(job['dst']).relative_to(SPR).as_posix()
        capture(rel,job['mode'],job.get('margin',3))
    elements=importlib.import_module('ui_elements2')
    elements.render_to=raw_hook;elements.post=post_hook
    elements.make_difficulty()
    # make_menu writes JSON; build its three original subjects directly.
    for name,(w,h,v) in {'button_normal':(1.92,.96,'normal'),'button_pressed':(1.92,.96,'pressed'),'button_primary':(2.56,1.12,'primary')}.items():
        elements.new_scene(name);elements.button(w-.04,h-.04,v);elements.outline(elements.meshes());elements.front_camera(w,h,int(w*200),int(h*200),0)
        capture('ui/menu/'+name+'.png')
    prompts=importlib.import_module('prompts')
    for n,fn,mode,(w,h) in prompts.ITEMS:
        if 'ui/prompts/'+n+'.png' not in manifest['files']:continue
        prompts.new_scene(n,24);fn();prompts.outline(prompts.meshes(),.02);prompts.frame_object_ortho(prompts.meshes(),.05)
        capture('ui/prompts/'+n+'.png',mode)

    # Gauge has no saved source: run its original construction and save() body.
    # Intercept render_to, staging the resulting 2x PNGs outside game/.
    def gauge_hook(path):
        p=Path(path)
        rel='ui/resource_gauge/'+p.name
        if rel not in manifest['files']:return
        capture(rel)
        # Original save() desaturates these neutral materials in Blender.
        # Redirect the path via a staging OUT global, so it cannot write game/.
        raw=Path(done[rel]['raw'])
        import shutil
        shutil.copy2(raw,p)
    kit.render_to=gauge_hook
    # Load definitions and execute the source's construction statements with OUT redirected.
    import ast
    src=ROOT/'art/tools/night/u1_build.py'
    tree=ast.parse(src.read_text(encoding='utf-8-sig'))
    body=[]
    for node in tree.body:
        if isinstance(node,ast.If) and isinstance(node.test,ast.Compare) and '--contact' in ast.unparse(node.test):continue
        if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='OUT' for t in node.targets):
            node.value=ast.parse('Path('+repr(str(WORK/'gauge'))+')').body[0].value
        # Gauge labels are QA only and outside the replacement contract.
        if isinstance(node,ast.For) and ast.unparse(node.target)=='name':break
        body.append(node)
    env={'__file__':str(src),'__name__':'cel_ui_gauge'}
    exec(compile(ast.fix_missing_locations(ast.Module(body=body,type_ignores=[])),str(src),'exec'),env)
    # Original gauge grayscale finalization was applied to staging copies.
    for rel in done:
        if rel.startswith('ui/resource_gauge/'):
            staged=WORK/'gauge'/Path(rel).name
            if staged.exists():
                import shutil
                shutil.copy2(staged,done[rel]['raw'])

def finalize():
    from PIL import Image
    import numpy as np
    import fit
    manifest=json.loads((WORK/'baseline.json').read_text())
    jobs=json.loads((WORK/'renders.json').read_text())
    for rel,spec in manifest['files'].items():
        if rel.endswith('_e.png') and rel not in jobs:
            base=rel[:-6]+'.png';job=jobs[base];source=job['accent']
            if not source:raise RuntimeError('Missing accent '+rel)
        else:
            job=jobs[rel];source=job['raw']
        dst=SPR/rel;w,h=spec['size']
        if rel.endswith('_e.png') and rel not in jobs:
            base_spec=manifest['files'][rel[:-6]+'.png'];tw,th=base_spec['size']
        else:tw,th=w,h
        stage=WORK/'fit.png'
        if job['mode']=='u2':
            im=Image.open(source).convert('RGBA');crop=im.crop(im.getbbox())
            x0,y0,x1,y1=spec['bbox'];crop=crop.resize((x1-x0,y1-y0),Image.Resampling.LANCZOS)
            if crop.getbbox()!=(0,0,crop.width,crop.height):crop=crop.crop(crop.getbbox()).resize(crop.size,Image.Resampling.LANCZOS)
            im=Image.new('RGBA',(tw,th));im.paste(crop,(x0,y0));im.save(stage)
        elif job['mode']=='icon':fit.icon(source,stage,tw,job['margin'])
        elif job['mode']=='fit':fit.fit(source,stage,tw,th,job['margin'])
        else:fit.resize(source,stage,tw,th)
        im=Image.open(stage).convert('RGBA')
        if im.size!=(w,h):im=im.resize((w,h),Image.Resampling.LANCZOS)
        # Contract assembly: keep the original coverage channel, including 9-slice borders.
        # RGB comes exclusively from Blender; Pillow only assembles the archived alpha.
        ref=cel.ARCHIVE/rel
        if not rel.endswith('_e.png') and ref.exists():
            im.putalpha(Image.open(ref).convert('RGBA').getchannel('A'))
        if rel.endswith('_e.png') and not rel.startswith('ui/resource_gauge/'):
            base=SPR/(rel[:-6]+'.png')
            if base.exists() and Image.open(base).size==im.size:
                im.putalpha(Image.open(base).convert('RGBA').getchannel('A'))
        if rel.startswith('ui/resource_gauge/') and rel.endswith('_e.png'):
            sys.path.insert(0,str(ROOT/'art/tools'))
            from halve_emission import downscale
            im=downscale(im)
        im.save(dst,optimize=True,compress_level=9)
    results=[];errors=[];companions=[]
    for rel,spec in manifest['files'].items():
        try:
            im=Image.open(SPR/rel).convert('RGBA');a=np.asarray(im)
            expected=tuple(spec['size'])
            if rel.startswith('ui/resource_gauge/') and rel.endswith('_e.png'):expected=tuple((v+1)//2 for v in expected)
            assert im.size==expected,(rel,'size')
            assert a[:,:,3].max()>0,(rel,'empty')
            if rel.endswith('_e.png'):
                assert (a[:,:,:3].max(axis=2)* (a[:,:,3]/255)).max()>2,(rel,'black emission')
                if rel.startswith('ui/resource_gauge/'):
                    ref=np.asarray(downscale(Image.open(cel.ARCHIVE/rel).convert('RGBA')))
                    x=(ref[:,:,:3].max(2)>100)&(ref[:,:,3]>128);y=(a[:,:,:3].max(2)>100)&(a[:,:,3]>128)
                    iou=float((x&y).sum()/max(1,(x|y).sum()))
                    assert iou>.97,(rel,'half accent IoU',iou)
                else:iou=None
                companions.append(dict(file=rel,size=list(im.size),nonblack=True,accent_iou=iou))
                continue
            r=cel.check_sheet(rel,normals=False,**({} if rel.endswith('vignette_hit.png') else dict(cell=im.size,frames=1,rows=1)))
            assert not (SPR/rel).with_name(Path(rel).stem+'_n.png').exists()
            old=np.asarray(Image.open(cel.ARCHIVE/rel).convert('RGBA'))
            # Entire alpha checked, including all 9-slice fixed border regions.
            r['alpha_exact']=bool(np.array_equal(a[:,:,3],old[:,:,3]))
            r['size']=list(im.size);r['normal_absent']=True
            if rel.startswith(('ui/da/','ui/menu/')) and (SPR/rel).with_suffix('.json').exists():
                assert r['alpha_exact'],(rel,'9-slice alpha')
            results.append(r)
        except Exception as e:errors.append(str(e))
    for rel,digest in manifest['protected'].items():
        if sha(ROOT/rel)!=digest:errors.append('Protected changed '+rel)
    report=dict(profile='ui',normals=False,choices=['2 tones; original cameras, geometry and material hues; night shadow floor from shared ui profile','Original modeled outline geometry retained for prompts/menu/difficulty','Coverage channel assembled from archive; RGB rendered exclusively in Blender','Original dedicated emission shading retained; gauge emission delivered at half size','Preexisting ui root archive contained only crit_icon.png; four missing spell originals recovered from HEAD with baseline SHA256 equality; existing archive files unchanged','Translucent vignette retains authored falloff; nonempty alpha checked without opaque-cell assumption'],files=results,companions=companions,errors=errors,before_bytes=manifest['before_bytes'],after_bytes=sum(p.stat().st_size for p in targets()))
    REPORT.write_text(json.dumps(report,indent=2))
    samples=[]
    for folder in FOLDERS+['ui']:
        candidates=[r for r in results if Path(r['file']).parent.as_posix()==folder]
        if folder=='ui/da':
            names=('panel_small_9slice.png','button_primary.png','icon_gold.png')
            candidates=[r for n in names for r in candidates if Path(r['file']).name==n]
        if candidates:
            selected=candidates[:3];samples.append([(r['file'],tuple(r['size']),0,0) for r in selected])
    cel.contact_pair(samples,ROOT/'art/tools/night/_cel_ui_contact.png',size=(3000,4096))
    print('CEL_UI_VERIFY',len(results),'diffuse;',len(errors),'errors')
    if errors:
        print('\n'.join(errors[:12]));raise SystemExit(1)

def checks(import_game=True):
    report=json.loads(REPORT.read_text());runs=[]
    jobs=[('budget_policy',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy']),('budget',[sys.executable,str(ROOT/'art/tools/texture_budget.py')])]
    if import_game:jobs.append(('import',[GODOT,'--headless','--path','game','--import']))
    for scene in ('sprites','ui_theme','hud_overlays','touch_layout','menu_flow','texture_budget'):
        jobs.append((scene,[GODOT,'--headless','--path','game','res://tests/'+scene+'_test.tscn']))
    for name,cmd in jobs:
        log=ROOT/('art/tools/night/_cel_ui_'+name+'.log')
        with log.open('w') as out:
            p=subprocess.run(cmd,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,timeout=300,creationflags=subprocess.CREATE_NO_WINDOW)
        txt=log.read_text(encoding='utf-8',errors='replace')
        ok=p.returncode==0 and 'SCRIPT ERROR' not in txt and 'ERROR:' not in txt
        if name in ('sprites','ui_theme','hud_overlays','touch_layout','menu_flow','texture_budget'):ok=ok and 'RESULT: OK' in txt
        runs.append(dict(name=name,passed=ok,exit=p.returncode,log=str(log.relative_to(ROOT))))
        print(name,'PASS' if ok else 'FAIL',flush=True)
    baseline=json.loads((WORK/'baseline.json').read_text())
    changed=[rel for rel,digest in baseline['protected'].items() if sha(ROOT/rel)!=digest]
    report['checks']=runs;report['protected_changed']=changed
    REPORT.write_text(json.dumps(report,indent=2))
    if changed or not all(r['passed'] for r in runs):raise SystemExit(1)

def driver():
    WORK.mkdir(parents=True,exist_ok=True)
    baseline=WORK/'baseline.json'
    if not baseline.exists():
        from PIL import Image
        # ui root contains spell sheets; archive once, plus each explicit child folder.
        for folder in FOLDERS+['ui']:cel.archive_folder(folder)
        files={}
        for p in targets():
            im=Image.open(p).convert('RGBA');files[p.relative_to(SPR).as_posix()]={'size':list(im.size),'bbox':list(im.getbbox()),'sha256':sha(p)}
        protected={p.relative_to(ROOT).as_posix():sha(p) for p in (SPR/'ui').rglob('*') if p.is_file() and p.suffix in ('.json','.tres','.import')}
        protected.update({p.relative_to(ROOT).as_posix():sha(p) for p in (ROOT/'art/blender/ui').glob('*.blend')})
        baseline.write_text(json.dumps(dict(files=files,protected=protected,before_bytes=sum(p.stat().st_size for p in targets())),indent=1))
    if '--verify' not in sys.argv:
        with (WORK/'render.log').open('w') as log:
            cmd=[BLENDER,'--background','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--render']
            if '--resume' in sys.argv:cmd.append('--resume')
            result=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
        if result.returncode:raise SystemExit('FAIL Blender; art/blender/cel/ui/render.log')
    finalize()
    if '--assets-only' not in sys.argv:checks()

if __name__=='__main__':
    if '--checks-only' in sys.argv:checks(import_game='--skip-import' not in sys.argv)
    elif '--render' in sys.argv:render()
    else:driver()
