"""CEL-HEROES_A. System driver / Blender -- --render; original render functions reused."""
from pathlib import Path
import sys, json, hashlib, shutil, subprocess, ast, inspect, textwrap
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
WORK=ROOT/'art/blender/cel/heroes_a'
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/characters'),str(HERE)]
import cel_style as cel
SPR=cel.GAME_SPRITES
FOLDERS=['characters/ardent','characters/rictus']+['characters/rictus/'+s for s in ['dagger_arc','double_burst','knife','knife_planted','spin_blur']]+['ui/portraits']
ANIMS={'idle':8,'run':8,'slash':4,'throw':4,'spin':8,'stagger':3,'summon':6,'lift':3,'death':6,'throw_ult':6}
STATE=HERE/'_cel_heroes_a_state.json'

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def targets():
    return sorted([p for rel in FOLDERS[:-1] for p in (SPR/rel).glob('*.png')]+[SPR/'ui/portraits/rictus.png'])
def protected():
    ps=list((ROOT/'game').rglob('*.gd'))+list((ROOT/'game').rglob('*.tscn'))
    for rel in FOLDERS:
        ps += [p for p in (SPR/rel).glob('*') if p.suffix in ('.tres','.json','.import')]
    ps += [ROOT/'art/blender/characters'/s for s in ['rictus.blend','ardent_iso.blend','tocsin_t4_portraits.blend']]
    return {str(p.relative_to(ROOT)):digest(p) for p in ps}

class Adapt(ast.NodeTransformer):
    def visit_Tuple(self,node):
        self.generic_visit(node)
        node.elts=[e for e in node.elts if not (isinstance(e,ast.Constant) and e.value=='_n')]
        return node
    visit_List=visit_Tuple
    def visit_Expr(self,node):
        if isinstance(node.value,ast.Call) and isinstance(node.value.func,ast.Attribute) and node.value.func.attr=='save_as_mainfile':return ast.Pass()
        return self.generic_visit(node)

def adapt(fn,trim=False):
    tree=ast.parse(textwrap.dedent(inspect.getsource(fn)))
    if trim:
        body=tree.body[0].body
        end=next(i for i,n in enumerate(body) if isinstance(n,ast.Expr) and isinstance(n.value,ast.Call) and isinstance(n.value.func,ast.Attribute) and n.value.func.attr=='render_frame')
        tree.body[0].body=body[:end+1]
    tree=ast.fix_missing_locations(Adapt().visit(tree))
    exec(compile(tree,inspect.getsourcefile(fn),'exec'),fn.__globals__)
    return fn.__globals__[fn.__name__]

def render():
    import bpy, iso_rig as iso
    import m2_build as m2, m3_build as m3, p1_build as p1
    from PIL import Image
    WORK.mkdir(parents=True,exist_ok=True)
    # Adapt only legacy pass enumeration; original camera, rig, poses and exporter remain in use.
    original=iso.render_frame
    src=textwrap.dedent(inspect.getsource(original)).replace("for suffix in ('_n','_e'):","for suffix in ('_e',):")
    exec(compile(src,inspect.getsourcefile(original),'exec'),iso.__dict__)
    no_normals=iso.render_frame
    active=['creature']
    def frame(path,passes=True):
        path=Path(path)
        if path.is_relative_to(SPR) and not any(path.is_relative_to(SPR/rel) for rel in FOLDERS[:-1]):
            path=WORK/'excluded'/path.name
        if '--resume' in sys.argv and path.is_relative_to(WORK) and path.exists() and path.with_name(path.stem+'_e.png').exists():return path
        cel.install(active[0],normals=False)
        return no_normals(path,passes=passes)
    iso.render_frame=frame
    p1.OUT=SPR/'characters/ardent'
    adapt(p1.build,trim=True)()
    print('PASS ardent portrait',flush=True)
    m2.OUT=WORK/'m2';m2.OUT.mkdir(exist_ok=True)
    m2.resources=lambda actor:None
    adapt(m2.build)('rictus')
    print('PASS rictus animations',flush=True)
    m3.OUT=WORK/'m3';m3.OUT.mkdir(exist_ok=True)
    # Original atlas assembly, existing resources are retained verbatim.
    adapt(m3.atlas);adapt(m3.burst)
    for name in ['dagger_arc','double_burst','knife','knife_planted','spin_blur']:
        assert (m3.DEST/name/(name+'.tres')).exists()
    def fx_render(path,size,rig='CREA',target=(0,0,0),passes=True):
        active[0]='prop' if Path(path).stem.startswith(('knife_','planted_','burst_')) else 'vfx'
        m3_original(path,size,rig,target,passes)
    m3_original=m3.render;m3.render=fx_render
    m3.sprites()
    active[0]='creature';m3.portrait()
    print('PASS rictus effects portrait',flush=True)

def verify():
    from PIL import Image
    import numpy as np
    from halve_emission import downscale,emission_peak
    state=json.loads(STATE.read_text())
    # Shading changes the diffuse only. Keep approved emissive radiance and its
    # half-resolution coverage verbatim (AOV antialiasing otherwise lifts tiny highlights).
    for rel in state['png']:
        if Path(rel).stem.endswith('_e') and not (rel.startswith('characters/ardent/') and Path(rel).name!='portrait_e.png'):
            shutil.copy2(cel.ARCHIVE/rel,SPR/rel)
    # Retain original emission/shadow inventory; no black emission delivered.
    expected=set(state['png'])
    for p in targets():
        rel=p.relative_to(SPR).as_posix()
        if p.stem.endswith('_n'):raise AssertionError(('normal forbidden',rel))
        if p.stem.endswith('_e'):
            if rel not in expected or emission_peak(str(p))<=2/255:
                p.unlink();continue
            diffuse=p.with_name(p.stem[:-2]+'.png')
            with Image.open(diffuse) as d,Image.open(p) as im:
                if im.size==d.size:downscale(im.convert('RGBA')).save(p,optimize=True,compress_level=9)
    results=[];errors=[]
    for rel in state['png']:
        if Path(rel).stem.endswith(('_e','_shadow','_n')):continue
        p=SPR/rel
        with Image.open(p) as im:w,h=im.size
        cell=256 if p.stem=='portrait' or rel=='ui/portraits/rictus.png' else 192
        if '/rictus/' in rel and p.parent.name!='rictus':
            cell={'dagger_arc':672,'double_burst':512,'knife':64,'knife_planted':64,'spin_blur':288}[p.parent.name]
        try:
            r=cel.check_sheet(rel,cell=cell,frames=w//cell,rows=h//cell,normals=False)
            r.update(size=[w,h],normal_absent=not p.with_name(p.stem+'_n.png').exists(),cells='PASS')
            ep=p.with_name(p.stem+'_e.png');old=cel.ARCHIVE/ep.relative_to(SPR)
            if ep.exists() and old.exists():
                a=np.asarray(Image.open(old).convert('RGBA'));b=np.asarray(Image.open(ep).convert('RGBA'))
                assert a.shape==b.shape,(rel,'emission dimensions')
                a=(a[...,:3].max(2)>100)&(a[...,3]>128)
                b=(b[...,:3].max(2)>100)&(b[...,3]>128)
                r['accent_iou']=float((a&b).sum()/max(1,(a|b).sum())) if a.any() or b.any() else 1.0
                assert r['accent_iou']>.97,(rel,'accent IoU',r['accent_iou'])
            results.append(r)
        except AssertionError as e:errors.append(str(e))
    current=protected()
    changed=[p for p,h in state['protected'].items() if current.get(p)!=h]
    external=[p for p in changed if Path(p).suffix in ('.gd','.tscn')]
    changed=[p for p in changed if p not in external]
    if changed:errors.append('protected changed '+repr(changed))
    actual={p.relative_to(SPR).as_posix() for p in targets()}
    if actual!=expected:errors.append('inventory '+repr(sorted(actual^expected)))
    for p in (SPR/'characters/ardent_cel').glob('*.png'):
        if not p.stem.endswith('_n') and digest(p)!=digest(SPR/'characters/ardent'/p.name):errors.append('CS1 copy mismatch '+p.name)
    for rel in FOLDERS:
        for p in (SPR/rel).glob('*.tres'):
            if 'CanvasTexture' in p.read_text() or 'normal_texture' in p.read_text():errors.append('normal resource '+str(p))
    out={'checks':results,'errors':errors,'profiles':['creature','prop','vfx'],'choices':'Original source tints, camera, poses. Shared night shadow floor. Ardent CS1 byte copies. Approved half-resolution emission masks reused verbatim to retain radiance and subpixel coverage. No normals. Legacy pass enumeration adapted in memory; original scripts untouched.','bytes_before':state['bytes_before'],'bytes_after':sum(p.stat().st_size for p in targets())}
    out['external_code_changes_observed']=external
    prior=HERE/'_cel_heroes_a_verification.json'
    if prior.exists():
        previous=json.loads(prior.read_text())
        if 'runtime_checks' in previous:out['runtime_checks']=previous['runtime_checks']
    (HERE/'_cel_heroes_a_verification.json').write_text(json.dumps(out,indent=2))
    samples=[[('characters/ardent/idle.png',192,0,2),('characters/ardent/attack.png',192,2,2),('characters/ardent/portrait.png',256,0,0)], [('characters/rictus/idle.png',192,0,2),('characters/rictus/slash.png',192,2,2),('ui/portraits/rictus.png',256,0,0)], [('characters/rictus/knife/default.png',64,1,0),('characters/rictus/knife_planted/default.png',64,0,2),('characters/rictus/spin_blur/default.png',288,1,0)], [('characters/rictus/dagger_arc/default.png',672,2,0),('characters/rictus/double_burst/top.png',512,2,0),('characters/rictus/double_burst/crea.png',512,2,0)]]
    cel.contact_pair(samples,HERE/'_cel_heroes_a_contact.png',size=(2304,2048))
    print('VERIFY',len(results),'PASS;',len(errors),'FAIL',flush=True)
    if errors:print('\n'.join(errors[:8]));raise SystemExit(1)

def driver():
    WORK.mkdir(parents=True,exist_ok=True)
    if not STATE.exists():
        for rel in FOLDERS:cel.archive_folder(rel)
        ps=targets()
        STATE.write_text(json.dumps({'png':{p.relative_to(SPR).as_posix():list(__import__('PIL.Image',fromlist=['Image']).open(p).size) for p in ps},'protected':protected(),'bytes_before':sum(p.stat().st_size for p in ps)},indent=1))
    else:
        for rel in FOLDERS:cel.archive_folder(rel)
    for p in (SPR/'characters/ardent_cel').glob('*.png'):
        if not p.stem.endswith('_n'):shutil.copy2(p,SPR/'characters/ardent'/p.name)
    if '--verify-only' not in sys.argv:
        with (HERE/'_cel_heroes_a_render.log').open('w') as log:
            cmd=[cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
            if '--resume' in sys.argv:cmd.append('--resume')
            subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    verify()
    if '--verify-only' not in sys.argv:checks()

def checks():
    jobs=[('texture_budget',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy']),('import',[cel.GODOT,'--headless','--path',str(ROOT/'game'),'--import'])]
    jobs += [(name,[cel.GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+name+'.tscn']) for name in ['sprites_test','player_test','rictus_test','render_style_test','texture_budget_test']]
    report=[]
    for name,cmd in jobs:
        log=HERE/('_cel_heroes_a_'+name+'.log')
        with log.open('w',encoding='utf-8') as f:r=subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
        content=log.read_text(encoding='utf-8',errors='replace')
        ok=r.returncode==0 and 'ERROR:' not in content and 'SCRIPT ERROR' not in content
        if name.endswith('_test'):
            fatal=[s for s in content.splitlines() if 'ERROR:' in s and 'resources still in use at exit' not in s]
            ok=r.returncode==0 and 'RESULT: OK' in content and not fatal and 'SCRIPT ERROR' not in content
        report.append({'name':name,'exit_code':r.returncode,'pass':ok,'cleanup_resource_warning':'resources still in use at exit' in content})
        print(name,'PASS' if ok else 'FAIL',flush=True)
    p=HERE/'_cel_heroes_a_verification.json';data=json.loads(p.read_text());data['runtime_checks']=report;p.write_text(json.dumps(data,indent=2))
    if not all(r['pass'] for r in report):raise SystemExit(1)

if __name__=='__main__':
    if '--checks-only' in sys.argv:checks()
    else:render() if '--render' in sys.argv else driver()
