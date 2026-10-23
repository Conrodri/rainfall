"""CEL-HEROES_D: original geometry/exporters, shared cel shading, no normal files."""
from pathlib import Path
import sys, json, hashlib, shutil, subprocess, ast, inspect, textwrap
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import cel_style as cel
from cel_heroes_a_build import Adapt
SPR=cel.GAME_SPRITES
WORK=ROOT/'art/blender/cel/heroes_d'
STATE=HERE/'_cel_heroes_d_state.json'
REPORT=HERE/'_cel_heroes_d_verification.json'
FX={'avare':['coffre_arc','coin_burst','coin_pickup','coin_projectile','gold_bleed','ransom_ring'], 'rainette':['goo','goo_projectile','land_ring','tongue']}
FOLDERS=['characters/'+h for h in FX]+['characters/'+h+'/effects/'+f for h,fs in FX.items() for f in fs]
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def targets():return sorted(p for rel in FOLDERS for p in (SPR/rel).glob('*.png'))
def protected():
    paths=[p for rel in FOLDERS for p in (SPR/rel).glob('*') if p.suffix in ('.tres','.json','.import')]
    paths += list((ROOT/'art/blender/characters').glob('avare*.blend'))+list((ROOT/'art/blender/characters').glob('rainette*.blend'))
    paths += list((ROOT/'game').rglob('*.gd'))+list((ROOT/'game').rglob('*.tscn'))
    paths += list((SPR/'characters/rainette/effects/shadow').glob('*'))
    return {str(p.relative_to(ROOT)):digest(p) for p in paths if p.is_file()}
def adapted(fn=None,source=None,namespace=None):
    source=source or textwrap.dedent(inspect.getsource(fn))
    namespace=namespace if namespace is not None else fn.__globals__
    tree=ast.fix_missing_locations(Adapt().visit(ast.parse(source)))
    exec(compile(tree,str(Path(__file__)),'exec'),namespace)
    return namespace[tree.body[0].name]
def restore_emission():
    state=json.loads(STATE.read_text())
    for rel in state['png']:
        if Path(rel).stem.endswith('_e'):shutil.copy2(cel.ARCHIVE/rel,SPR/rel)
    expected=set(state['png'])
    for p in targets():
        if p.stem.endswith('_e') and p.relative_to(SPR).as_posix() not in expected:p.unlink()
def render():
    import bpy, iso_rig as iso
    import aa1_build as aa1, aa2_build as aa2, ra1_build as ra1, ra2_build as ra2
    stage=next((s.split('=',1)[1] for s in sys.argv if s.startswith('--stage=')),'all')
    WORK.mkdir(parents=True,exist_ok=True)
    adapted(iso.render_frame)
    original=iso.render_frame
    active=['creature']
    resume='--resume' in sys.argv
    def frame(path,passes=True):
        path=Path(path)
        # Completion markers track cel renders, never mistake original assets for resumed output.
        marker=WORK/'done'/(hashlib.sha256(str(path).encode()).hexdigest()+'.json')
        if resume and marker.exists() and path.exists():return path
        cel.install(active[0],normals=False)
        result=original(path,passes=passes)
        if path.is_relative_to(SPR):restore_emission()
        marker.parent.mkdir(parents=True,exist_ok=True);marker.write_text(json.dumps({'path':str(path)}))
        return result
    iso.render_frame=frame
    aa1.resources=lambda:None;ra1.resources=lambda:None
    aa2.resource=lambda *args:None;ra2.resource=lambda *args:None
    aa1.WORK=WORK/'avare';ra1.WORK=WORK/'rainette'
    aa2.RAW=WORK/'avare_effects';ra2.WORK=WORK/'rainette_effects'
    # No saves: source blends remain immutable. Only legacy normal enumeration is removed.
    sys.argv=[s for s in sys.argv if s!='--resume']
    if stage in ('all','avare'):adapted(aa1.atlases)()
    if stage in ('all','rainette'):
        source=inspect.getsource(ra1.common.atlases).replace("['Averse']","['Rainette']").replace('AV1','RA1')
        adapted(source=source,namespace=ra1.__dict__)()
    if stage in ('all','portraits'):adapted(aa2.portrait)();adapted(ra2.portrait)()
    for mod,src in [(aa2,None),(ra2,ra2._effects_source)]:
        if stage not in ('all','avare_effects' if mod is aa2 else 'rainette_effects'):continue
        specs=dict(mod.SPECS)
        exporter=adapted(mod.effects if src is None else None,source=src,namespace=mod.__dict__)
        for name,spec in specs.items():
            active[0]='vfx' if name in ('ransom_ring','land_ring') else 'prop'
            mod.SPECS={name:spec}
            exporter()
            restore_emission()
        mod.SPECS=specs
    restore_emission()
def verify():
    from PIL import Image
    state=json.loads(STATE.read_text());results=[];errors=[]
    for rel,size in state['png'].items():
        if Path(rel).stem.endswith(('_e','_shadow')):continue
        p=SPR/rel;cell=256 if p.stem=='portrait' else 192
        if '/effects/' in rel:
            cell={'coffre_arc':192,'coin_burst':512,'coin_pickup':48,'coin_projectile':48,'gold_bleed':192,'ransom_ring':256,'goo':352,'goo_projectile':128,'land_ring':384,'tongue':512}[p.stem]
        try:
            result=cel.check_sheet(rel,cell=cell,frames=size[0]//cell,rows=size[1]//cell,normals=False)
            assert digest(p)!=digest(cel.ARCHIVE/rel),(rel,'diffuse not rerendered')
            assert not p.with_name(p.stem+'_n.png').exists(),(rel,'normal forbidden')
            ep=p.with_name(p.stem+'_e.png');old=cel.ARCHIVE/ep.relative_to(SPR)
            if ep.exists():
                assert digest(ep)==digest(old),(rel,'accent mask changed')
                result.update(accent_iou=1.0,emission='archived radiance and alpha retained')
            result.update(size=size,normal_absent=True,cells='PASS');results.append(result)
        except AssertionError as exc:errors.append(str(exc))
    actual={p.relative_to(SPR).as_posix() for p in targets()}
    if actual!=set(state['png']):errors.append('inventory '+repr(sorted(actual^set(state['png']))))
    now=protected();changed=[p for p,h in state['protected'].items() if now.get(p)!=h]
    if changed:errors.append('protected changed '+repr(changed))
    for rel in FOLDERS:
        for p in (SPR/rel).glob('*.tres'):
            if any(s in p.read_text() for s in ('CanvasTexture','normal_texture')):errors.append('normal resource '+str(p))
    data={'checks':results,'errors':errors,'profiles':['creature','prop','vfx'],'choices':'Original models, animation, cameras, materials as tint sources. Shared night shadow floor. Archived half-resolution emission retained verbatim for exact accent/radiance/alpha. Ring light uses vfx; physical effects prop. No source saves or normal maps.','bytes_before':state['bytes_before'],'bytes_after':sum(p.stat().st_size for p in targets())}
    if REPORT.exists():data['runtime_checks']=json.loads(REPORT.read_text()).get('runtime_checks',[])
    REPORT.write_text(json.dumps(data,indent=2))
    samples=[]
    for hero in FX:
        samples.append([(f'characters/{hero}/idle.png',192,0,2),(f'characters/{hero}/attack.png',192,2,2),(f'characters/{hero}/portrait.png',256,0,0)])
        for name in FX[hero]:
            cell={'coffre_arc':192,'coin_burst':512,'coin_pickup':48,'coin_projectile':48,'gold_bleed':192,'ransom_ring':256,'goo':352,'goo_projectile':128,'land_ring':384,'tongue':512}[name]
            samples.append([(f'characters/{hero}/effects/{name}/{name}.png',cell,1,0)])
    # Pair effect subjects on shared rows; one final board including the approved CS1 reference.
    samples=[samples[0],samples[1]+samples[2],samples[3]+samples[4],samples[5]+samples[6],samples[7],samples[8]+samples[9],samples[10]+samples[11]]
    board=HERE/'_cel_heroes_d_contact.png'
    cel.contact_pair(samples,board,size=(3072,3584))
    with Image.open(board) as im, Image.open(HERE/'_cs1_contact.png') as reference:
        canvas=Image.new('RGB',(3072,4096));canvas.paste(im,(0,0))
        reference=reference.crop((reference.width//2,0,reference.width,reference.height));reference.thumbnail((3072,512))
        canvas.paste(reference,(0,3584));canvas.save(board,optimize=True)
    print('VERIFY',len(results),'PASS;',len(errors),'FAIL',flush=True)
    if errors:print('\n'.join(errors[:8]));raise SystemExit(1)
def checks():
    jobs=[('texture_budget',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy']),('import',[cel.GODOT,'--headless','--path',str(ROOT/'game'),'--import'])]
    jobs += [(n,[cel.GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+n+'.tscn']) for n in ['sprites_test','avare_test','rainette_test','player_test','texture_budget_test']]
    results=[]
    for name,cmd in jobs:
        log=HERE/('_cel_heroes_d_'+name+'.log')
        with log.open('w',encoding='utf-8') as f:r=subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT)
        content=log.read_text(encoding='utf-8',errors='replace')
        errors=[s for s in content.splitlines() if 'ERROR:' in s and 'resources still in use at exit' not in s]
        ok=r.returncode==0 and not errors and 'SCRIPT ERROR' not in content and (not name.endswith('_test') or 'RESULT: OK' in content)
        results.append({'name':name,'pass':ok,'exit_code':r.returncode,'errors':errors[:3]})
        print(name,'PASS' if ok else 'FAIL',flush=True)
    data=json.loads(REPORT.read_text());data['runtime_checks']=results;REPORT.write_text(json.dumps(data,indent=2))
    if not all(x['pass'] for x in results):raise SystemExit(1)
def driver():
    from PIL import Image
    WORK.mkdir(parents=True,exist_ok=True)
    for rel in FOLDERS:cel.archive_folder(rel)
    if not STATE.exists():STATE.write_text(json.dumps({'png':{p.relative_to(SPR).as_posix():list(Image.open(p).size) for p in targets()},'protected':protected(),'bytes_before':sum(p.stat().st_size for p in targets())},indent=1))
    if '--verify-only' not in sys.argv:
        for stage in ['avare','rainette','portraits','avare_effects','rainette_effects']:
            done=WORK/(stage+'.done')
            if '--resume' in sys.argv and done.exists():continue
            cmd=[cel.BLENDER,'--background','--threads','1','--python-exit-code','1','--python',str(Path(__file__).resolve()),'--','--render','--stage='+stage]
            if '--resume' in sys.argv:cmd.append('--resume')
            with (HERE/('_cel_heroes_d_'+stage+'_render.log')).open('w') as f:subprocess.run(cmd,cwd=ROOT,stdout=f,stderr=subprocess.STDOUT,check=True)
            done.write_text('PASS')
    verify()
    if '--verify-only' not in sys.argv:checks()
if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--checks-only' in sys.argv:checks()
    else:driver()
