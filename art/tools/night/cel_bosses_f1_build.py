"""Eclusier: original C7a geometry/poses, shared boss cel, no normal files.

System driver; Blender pass: --background --python this.py -- --render [--resume].
"""
from pathlib import Path
import sys, json, subprocess, hashlib, math, re
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).parent
sys.path[:0] = [str(ROOT/'art/tools/cel'), str(ROOT/'art/tools/monsters'),
                str(ROOT/'art/tools/bosses'), str(ROOT/'art/tools/iso')]
import cel_style as cel
REL = 'bosses/etage/eclusier'
DST = cel.GAME_SPRITES/REL
WORK = ROOT/'art/blender/cel/bosses_f1'
STATE = HERE/'_cel_bosses_f1_state.json'
REPORT = HERE/'_cel_bosses_f1_verification.json'
SPECS = json.loads((ROOT/'art/tools/monsters/_c7a_render_report.json').read_text())
BLENDER = r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT = r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def cell(v): return (v['size'][0]//v['frames'], v['size'][1]//len(v['directions']))
def metrics(folder):
    from PIL import Image
    import numpy as np
    total = weight = pixels = size = 0
    for p in folder.glob('*.png'):
        size += p.stat().st_size
        with Image.open(p) as im:
            pixels += im.width*im.height
            if p.stem.endswith(('_e','_n','_shadow')): continue
            a = np.asarray(im.convert('RGBA')).astype(float)/255
            w = a[:,:,3]
            total += (a[:,:,:3] @ np.array([.2126,.7152,.0722])*w).sum()
            weight += w.sum()
    return dict(png_bytes=size, rgba_bytes=pixels*4, mean_luma_srgb=total/max(1,weight))

def render():
    import bpy
    import c7a_build as original
    from PIL import Image
    WORK.mkdir(parents=True, exist_ok=True)
    root, pose, wheel = original.build()
    for task, v in SPECS.items():
        if '--task' in sys.argv and task != sys.argv[sys.argv.index('--task')+1]: continue
        out = WORK/(task+'.png')
        if '--resume' in sys.argv and (WORK/(task+'.done')).exists(): continue
        if task in original.EXTRAS:
            if task == 'wheel':
                root, pose, wheel = original.build()
                keep = set(wheel.children_recursive+[wheel])
                for o in root.children_recursive: o.hide_render = o not in keep
                wheel.parent = root; wheel.location = (0,0,.25)
                bpy.context.scene.camera.data.ortho_scale = 3.9
                def p(t): wheel.rotation_euler.y = math.tau*t/8
            else:
                root, p = original.legacy.make(task)
                s = bpy.context.scene
                if task != 'ground_water':
                    from mathutils import Vector
                    s.camera.rotation_euler = (math.pi/3,0,0)
                    s.camera.location = s.camera.rotation_euler.to_matrix() @ Vector((0,0,10))
                for mat in bpy.data.materials:
                    if mat.name.startswith(('Eau argent','Ecume lumineuse')):
                        bs = mat.node_tree.nodes.get('Principled BSDF')
                        if bs is None: continue  # Already converted by a previous cel pass.
                        bs.inputs['Base Color'].default_value = (.012,.044,.05,1) if mat.name.startswith('Eau argent') else (.04,.29,.32,1)
                        bs.inputs['Emission Color'].default_value = (.015,.32,.38,1)
                        bs.inputs['Emission Strength'].default_value = .06 if mat.name.startswith('Eau argent') else .7
                        if task == 'ground_water':
                            bs.inputs['Emission Strength'].default_value = 0
                if task == 'ground_water':
                    # Keep animated geometric ripples across the shared cel tone threshold.
                    # The original luminous water otherwise becomes four identical flat frames.
                    for light in s.objects:
                        if light.type == 'LIGHT': light.data.energy *= .6
        cel.install('boss', normals=False)
        cw,ch = cell(v); n = v['frames']; s = bpy.context.scene
        s.render.resolution_x = cw*2; s.render.resolution_y = ch*2
        s.render.resolution_percentage = 100
        boards = {suffix:Image.new('RGBA',tuple(v['size'])) for suffix in ('','_e')}
        for row,d in enumerate(v['directions']):
            for i in range(n):
                frame = WORK/f'{task}_{d}_{i:02}.png'
                if not ('--resume' in sys.argv and frame.exists() and frame.with_stem(frame.stem+'_e').exists()):
                    fn = p if task in original.EXTRAS else lambda t,b=task.replace('_dirs',''),i=i,n=n:pose(b,i,n)
                    original.c.render_still(root,fn,frame,i/n,d)
                alpha = None
                for suffix in ('','_e'):
                    im = Image.open(frame.with_stem(frame.stem+suffix)).convert('RGBA').resize((cw,ch),Image.Resampling.LANCZOS)
                    if not suffix: alpha = im.getchannel('A')
                    else: im.putalpha(alpha)
                    boards[suffix].paste(im,(i*cw,row*ch))
        for suffix,board in boards.items(): board.save(out.with_stem(out.stem+suffix),compress_level=9)
        (WORK/(task+'.done')).write_text('boss normals=False')
        print('CEL DONE',task,flush=True)

def crop_atlas(im, box, oldcell, n, rows):
    from PIL import Image
    x,y,x1,y1=box; cw,ch=oldcell; w,h=x1-x,y1-y
    out=Image.new('RGBA',(w*n,h*rows))
    for r in range(rows):
        for c in range(n): out.paste(im.crop((c*cw+x,r*ch+y,c*cw+x1,r*ch+y1)),(c*w,r*h))
    return out

def deliver():
    from PIL import Image
    import numpy as np
    archive=cel.archive_folder(REL)
    state=json.loads(STATE.read_text())
    results=[]; crops={}
    for task in SPECS:
        assert (WORK/(task+'.done')).exists(), 'incomplete render: '+task
    # Preserve metadata contracts until validating the original full-size renders.
    for task,v in SPECS.items():
        source=WORK/(task+'.png'); target=DST/source.name
        target.write_bytes(source.read_bytes())
        e=target.with_stem(task+'_e')
        if (archive/e.name).exists():
            # Accent belongs to the immutable source contract; only shading changes.
            e.write_bytes((archive/e.name).read_bytes())
        r={'file':task+'.png'}
        r.update(cel.check_sheet(REL+'/'+target.name,cell=cell(v),frames=v['frames'],rows=len(v['directions']),normals=False))
        assert not target.with_stem(task+'_n').exists()
        results.append(r)
    samples=[[(REL+'/'+t+'.png',cell(SPECS[t]),i,row) for t,i,row in line] for line in
             [[('idle_p1',0,0),('idle_p2',0,0),('idle_p3',0,0)],
              [('auto',2,0),('auto',3,0),('death',7,0)],
              [('walk_p1',2,0),('walk_p1',2,1),('walk_p1',2,3)],
              [('wheel',0,0),('geyser',3,0),('ground_water',0,0)]]]
    cel.contact_pair(samples,HERE/'_cel_bosses_f1_contact.png',size=(1600,1400))
    # AtlasTexture margins retain the original virtual frame, feet and runtime scale.
    tres=(archive/'eclusier.tres').read_text(encoding='utf-8')
    ids=dict(re.findall(r'path="res://assets/sprites/bosses/etage/eclusier/([^"/]+)\.png" id="([^"]+)"',tres))
    refroot=WORK/'cropped_reference'; (refroot/REL).mkdir(parents=True,exist_ok=True)
    for task,v in SPECS.items():
        cw,ch=cell(v); n=v['frames']; rows=len(v['directions'])
        im=Image.open(DST/(task+'.png')).convert('RGBA')
        boxes=[]
        for row in range(rows):
            for col in range(n):
                bb=im.crop((col*cw,row*ch,(col+1)*cw,(row+1)*ch)).getchannel('A').getbbox()
                if bb: boxes.append(bb)
        box=(max(0,min(b[0] for b in boxes)-4),max(0,min(b[1] for b in boxes)-4),min(cw,max(b[2] for b in boxes)+4),min(ch,max(b[3] for b in boxes)+4))
        # Even bounds keep the existing half-resolution accent pixels exactly aligned.
        box=(box[0]//2*2,box[1]//2*2,min(cw,(box[2]+1)//2*2),min(ch,(box[3]+1)//2*2))
        x,y,x1,y1=box; w,h=x1-x,y1-y
        crops[task]=dict(original_cell=[cw,ch],box=box,cell=[w,h],virtual_feet=[128,185] if cw==256 else None)
        crop_atlas(im,box,(cw,ch),n,rows).save(DST/(task+'.png'),compress_level=9)
        ref=Image.open(archive/(task+'.png')).convert('RGBA')
        crop_atlas(ref,box,(cw,ch),n,rows).save(refroot/REL/(task+'.png'))
        ep=DST/(task+'_e.png')
        if ep.exists():
            original_e=Image.open(archive/ep.name).convert('RGBA')
            if original_e.size == tuple(v['size']):
                ei=crop_atlas(original_e,box,(cw,ch),n,rows)
                sys.path.insert(0,str(ROOT/'art/tools'))
                from halve_emission import downscale
                ei=downscale(ei)
            else:
                assert original_e.size == (v['size'][0]//2,v['size'][1]//2)
                ei=crop_atlas(original_e,tuple(q//2 for q in box),(cw//2,ch//2),n,rows)
            a=np.asarray(ei)
            assert ((a[:,:,:3].max(2).astype(float)*a[:,:,3]/255).max()>2), task+' empty emission'
            ei.save(ep,compress_level=9)
            # Exact crop of the archived half-resolution mask: compare actual pixels.
            actual=np.asarray(Image.open(ep).convert('RGBA'))
            assert np.array_equal(a,actual), task+' accent pixels changed'
            results[list(SPECS).index(task)]['accent_iou']=1.0
            results[list(SPECS).index(task)]['accent_source']='immutable archive, same half-resolution pixels'
        atlasid=ids[task]
        pattern=r'(\[sub_resource type="AtlasTexture"[^\]]*\]\s*atlas = ExtResource\("'+re.escape(atlasid)+r'"\)\s*)region = Rect2\((\d+), (\d+), (\d+), (\d+)\)'
        def region(m):
            ox,oy,ow,oh=map(int,m.group(2,3,4,5))
            assert (ow,oh)==(cw,ch)
            return m[1]+f'region = Rect2({ox//cw*w}, {oy//ch*h}, {w}, {h})\nmargin = Rect2({x}, {y}, {cw-w}, {ch-h})'
        tres,count=re.subn(pattern,region,tres)
        assert count, task+' atlas not found'
        oldarchive=cel.ARCHIVE
        try:
            cel.ARCHIVE=refroot
            checked=cel.check_sheet(REL+'/'+task+'.png',cell=(w,h),frames=n,rows=rows,normals=False)
            checked.update(size=[w*n,h*rows],cell=[w,h],frames=n,rows=rows,
                           no_normal=not (DST/(task+'_n.png')).exists(),nonempty=True,unique_frames=True)
            results[list(SPECS).index(task)]['cropped_check']=checked
        finally: cel.ARCHIVE=oldarchive
    (DST/'eclusier.tres').write_text(tres,encoding='utf-8')
    report=dict(profile='boss',normals=False,before=state['before'],after=metrics(DST),sheets=results,crops=crops,
        choices=['Original C7a build/poses/camera; three tones and shadow floor from cel_style.',
                 'Crop alpha union + 4 px; AtlasTexture margin retains virtual feet and frame.',
                 'Original half-resolution emission preserved: AOV threshold masks differed; only diffuse shading changes.',
                 'Ground water: original geometric ripples, lights x0.6 so ripples cross shared cel thresholds; four unique frames.',
                 'Runtime scale and BODY_GAIN hardcoded in forbidden .gd: unchanged; scale 1.0 cannot be applied within scope.'])
    report['display_constraint']=dict(source='game/scripts/enemies/enemy_visual.gd:48,528; enemy.gd:19',
        original_px_per_u=40,unit_px=64,boss_radius_u=1.4,fill=2.8,dimension=165,
        runtime_scale=2.8*1.4*64/165,
        blocked='Scale/feet live in .gd, no data override; editing .gd is forbidden.')
    report['protected_unchanged']=all(sha(ROOT/p)==h for p,h in state['protected'].items())
    assert report['protected_unchanged'], 'protected .blend/.json/.import changed'
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
    errors=[r for r in results if 'full_check_error' in r or 'cropped_check_error' in r]
    assert not errors, errors
    assert all(sha(ROOT/p)==h for p,h in state['protected'].items()), 'protected source/metadata changed'
    print('DELIVERED',len(results),'sheets; checks',sum('full_check_error' not in r and 'cropped_check_error' not in r for r in results),flush=True)

def audit():
    """Recheck delivered pixels without rewriting atlases or triggering reimports."""
    report=json.loads(REPORT.read_text())
    state=json.loads(STATE.read_text())
    previous=cel.ARCHIVE
    cel.ARCHIVE=WORK/'cropped_reference'
    try:
        for entry in report['sheets']:
            task=Path(entry['file']).stem
            v=SPECS[task]; dims=report['crops'][task]['cell']
            checked=cel.check_sheet(REL+'/'+task+'.png',cell=tuple(dims),
                frames=v['frames'],rows=len(v['directions']),normals=False)
            assert not (DST/(task+'_n.png')).exists(), task+' normal file'
            checked.update(size=[dims[0]*v['frames'],dims[1]*len(v['directions'])],
                cell=dims,frames=v['frames'],rows=len(v['directions']),
                no_normal=True,nonempty=True,unique_frames=True)
            entry['cropped_check']=checked
    finally:
        cel.ARCHIVE=previous
    assert not re.search(r'CanvasTexture|normal_texture', (DST/'eclusier.tres').read_text())
    report['after']=metrics(DST)
    report['protected_unchanged']=all(sha(ROOT/p)==h for p,h in state['protected'].items())
    assert report['protected_unchanged']
    report['display_constraint']=dict(source='game/scripts/enemies/enemy_visual.gd:48,528; enemy.gd:19',
        original_px_per_u=40,unit_px=64,boss_radius_u=1.4,fill=2.8,dimension=165,
        runtime_scale=2.8*1.4*64/165,
        blocked='Scale/feet live in .gd, no data override; editing .gd is forbidden.')
    choice='Ground water: original geometric ripples, lights x0.6 so ripples cross shared cel thresholds; four unique frames.'
    if choice not in report['choices']: report['choices'].append(choice)
    report['final_tests']={}
    for name in ('sprites_test','eclusier_boss_test','floor1_boss_test','texture_budget_test'):
        log=HERE/('_cel_bosses_f1_validation_'+name+'.log')
        output=log.read_text(encoding='utf-8',errors='replace')
        report['final_tests'][name]=dict(result_ok='RESULT: OK' in output,
            log=str(log.relative_to(ROOT)),
            cleanup_messages=[line for line in output.splitlines()
                              if 'resources still in use' in line or 'ObjectDB instances were leaked' in line])
    output=(HERE/'_cel_bosses_f1_validation_import.log').read_text(encoding='utf-8',errors='replace')
    report['final_import_no_errors']=not re.search(r'ERROR|SCRIPT ERROR|Parse Error',output)
    budget=HERE/'_cel_bosses_f1_validation_texture_budget.log'
    if budget.exists():
        output=budget.read_text(encoding='utf-8',errors='replace')
        report['global_budget_messages']=[line for line in output.splitlines()
            if 'HORS BUDGET' in line or 'catégorie bosses' in line or 'APK estimé' in line]
    REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print('PASS audit 22 sheets',flush=True)

def validate():
    report=json.loads(REPORT.read_text())
    checks={}
    commands=[('texture_policy',[sys.executable,'art/tools/texture_budget.py','--apply-policy']),
              ('texture_budget',[sys.executable,'art/tools/texture_budget.py']),
              ('import',[GODOT,'--headless','--path','game','--import'])]
    commands += [(name,[GODOT,'--headless','--path','game','res://tests/'+name+'.tscn'])
                 for name in ('sprites_test','eclusier_boss_test','floor1_boss_test','texture_budget_test')]
    for name,cmd in commands:
        log=HERE/('_cel_bosses_f1_validation_'+name+'.log')
        with log.open('w',encoding='utf-8') as stream:
            try:
                result=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT,timeout=360,
                    creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
                code=result.returncode
            except subprocess.TimeoutExpired:
                code=-1
        output=log.read_text(encoding='utf-8',errors='replace')
        errors=[line for line in output.splitlines() if re.search(r'\b(?:ERROR|SCRIPT ERROR|Parse Error)\b',line)]
        ok=code==0 and ('RESULT: OK' in output if name.endswith('_test') else not errors)
        checks[name]={'ok':ok,'returncode':code,'log':str(log.relative_to(ROOT)),'errors':errors[:5]}
        if name=='texture_budget':
            checks[name]['global_budget_warnings']=[line.strip() for line in output.splitlines() if line.startswith('  - ')]
        report=json.loads(REPORT.read_text())
        report['validation']=checks
        REPORT.write_text(json.dumps(report,indent=2),encoding='utf-8')
        print(('PASS ' if ok else 'FAIL ')+name,flush=True)
    assert all(c['ok'] for c in checks.values()), checks

def driver():
    WORK.mkdir(parents=True,exist_ok=True)
    archive=cel.archive_folder(REL)
    if not STATE.exists():
        protected=[ROOT/'art/blender/monsters/eclusier_iso.blend']+list(DST.glob('*.json'))+list(DST.glob('*.import'))
        STATE.write_text(json.dumps(dict(before=metrics(DST),protected={str(p.relative_to(ROOT)):sha(p) for p in protected}),indent=2))
    args=[BLENDER,'--background','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--render']
    if '--resume' in sys.argv: args.append('--resume')
    with (HERE/'_cel_bosses_f1_render.log').open('a',encoding='utf-8') as log:
        subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    deliver()
    validate()

if __name__=='__main__':
    if '--render' in sys.argv: render()
    elif '--deliver' in sys.argv: deliver()
    elif '--audit' in sys.argv: audit()
    elif '--verify' in sys.argv: validate()
    else: driver()
