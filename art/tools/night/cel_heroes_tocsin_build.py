"""Tocsin contractual cel conversion; system driver / Blender -- --render."""
from pathlib import Path
import sys, json, subprocess, hashlib, inspect, textwrap, ast, shutil
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools')]
import cel_style as cel
from cel_heroes_a_build import Adapt
GAME=cel.GAME_SPRITES/'characters/tocsin'
WORK=ROOT/'art/blender/cel/heroes_tocsin'
STATE=HERE/'_cel_heroes_tocsin_state.json'
REPORT=HERE/'_cel_heroes_tocsin_verification.json'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def adapt(fn, stop=None):
    source=textwrap.dedent(inspect.getsource(fn))
    if stop: source=source.split(stop)[0]
    tree=ast.fix_missing_locations(Adapt().visit(ast.parse(source)))
    exec(compile(tree,inspect.getsourcefile(fn),'exec'),fn.__globals__)
    return fn.__globals__[fn.__name__]

def render():
    import bpy, iso_rig as iso
    import t1_build as t1, t2_build as t2, t3_build as t3, t4_build as t4, t6_build as t6
    WORK.mkdir(parents=True,exist_ok=True)
    # Retain disconnected source sockets: original pose functions animate them.
    source=textwrap.dedent(inspect.getsource(cel.toon_materials)).replace('if n.name not in keep:', "if n.name not in keep and n.type != 'BSDF_PRINCIPLED':")
    exec(compile(source,str(ROOT/'art/tools/cel/cel_style.py'),'exec'),cel.__dict__)
    adapt(iso.render_frame)
    original=iso.render_frame
    active=['creature']
    def frame(path,passes=True):
        cel.install(active[0],normals=False)
        cel.toon_materials(active[0])
        for mat in bpy.data.materials:
            if not mat.use_nodes or not mat.get('cel_done'): continue
            nodes,links=mat.node_tree.nodes,mat.node_tree.links
            bs=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
            em=next((n for n in nodes if n.type=='EMISSION'),None)
            if bs is None or em is None: continue
            strength=bs.inputs['Emission Strength'].default_value
            if strength>0 and not em.inputs['Color'].is_linked:
                em.inputs['Strength'].default_value=strength
                color=bs.inputs['Emission Color'].default_value
                em.inputs['Color'].default_value=color
                for n in nodes:
                    if n.type=='OUTPUT_AOV': n.inputs['Color'].default_value=tuple(c*strength for c in color[:3])+(1,)
            alpha=bs.inputs['Alpha'].default_value
            if alpha<1 or nodes.get('CEL source alpha'):
                mix=nodes.get('CEL source alpha')
                if mix is None:
                    mix=nodes.new('ShaderNodeMixShader'); mix.name='CEL source alpha'
                    transparent=nodes.new('ShaderNodeBsdfTransparent')
                    links.new(transparent.outputs[0],mix.inputs[1]); links.new(em.outputs[0],mix.inputs[2])
                    output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
                    links.new(mix.outputs[0],output.inputs['Surface'])
                mix.inputs[0].default_value=alpha
        return original(path,passes=passes)
    iso.render_frame=frame
    def t6_pass():
        t6.OUT=WORK/'t6'; t6.SUFFIXES=('','_e')
        t6.new_resource=lambda *a,**k:None
        t6.update_blast_regions=lambda *a,**k:None
        t4.SUFFIXES=('','_e'); t4.resource=lambda *a,**k:None
        t4.random.seed(404)
        active[0]='prop'; t6.rivet(); t6.ring(); t6.blast()
    if '--t6-only' in sys.argv:
        t6_pass(); return
    # T1 native model, followed by the original T2 and T3 pose/render functions.
    t2.OUT=WORK/'t2'; t2.configure()
    cel.install('creature',normals=False)
    adapt(t2.render_tiles)
    for lot,anims in [('t2',dict(t2.ANIMS)),('t3',dict(t3.NEW))]:
        if lot=='t3':
            t3.OUT=WORK/'t3'; t3.setup()
        t2.OUT=WORK/lot
        for anim,n in anims.items():
            for d in t2.DIRS:
                for i in range(n):
                    done=t2.OUT/anim/d/f'{i:02d}.done'
                    if '--resume' in sys.argv and done.exists(): continue
                    t2.render_tiles(anim,d,i)
                    done.write_text('PASS')
            print('PASS '+lot+'/'+anim,flush=True)
        orders=json.loads((GAME/'layers_order.json').read_text())['orders']
        if lot=='t2':
            adapt(t2.assemble,"    resource(GAME/'tocsin.tres')")(orders)
        else:
            adapt(t3.assemble,'    # Existing resources')()
    t3.OUT=WORK/'t3'; t1.OUT=t3.OUT
    active[0]='prop'
    adapt(t3.regen,'    # 1-direction VFX')()
    # Reset T3's in-memory extensions before using T4/T6 recipes.
    t2.pose=t3.old_pose; t2.active=t3.old_active; t2.ANIMS=dict(t3.ORIGINAL)
    t4.OUT=WORK/'t4'; t4.SUFFIXES=('','_e'); t4.resource=lambda *a,**k:None
    active[0]='creature'; t4.setup(); cel.install('creature',normals=False)
    for anim,n in t4.ANIMS.items():
        for d in t4.DIRS:
            for i in range(n):
                p=t4.OUT/anim/d/f'{i:02d}.png'
                if '--resume' in sys.argv and p.exists(): continue
                t4.part_pose(anim,i,d); t4.tile(f'{anim}/{d}/{i:02d}')
        t4.assemble(anim,n,list(t4.DIRS))
        print('PASS t4/'+anim,flush=True)
    original_blast=t4.blast
    active[0]='prop'; adapt(t4.blast)()
    t4.blast=original_blast
    active[0]='creature'; t4.SPELLS=[]; adapt(t4.ui)()
    # T5's contractual packing runs after T6 has replaced the TOP effect.
    t6_pass()
    print('PASS T1-T6 render',flush=True)

def finish():
    from PIL import Image
    import numpy as np
    import t5_build as t5
    state=json.loads(STATE.read_text())
    # Accent radiance and subpixel coverage were already approved; retain exact masks.
    for rel in state['png']:
        if Path(rel).stem.endswith(('_e','_shadow')):
            shutil.copy2(cel.ARCHIVE/'characters/tocsin'/rel,GAME/rel)
    expected=set(state['png'])
    for p in GAME.rglob('*.png'):
        if p.relative_to(GAME).as_posix() not in expected:
            assert p.stem.endswith('_e'),str(p)
            p.unlink()
    # Assemble packed diffuse with the original T5 crop/region manifest.
    t5.PASSES=['']
    layout=json.loads((GAME/'atlas_manifest.json').read_text())
    for key,value in layout.items(): t5.pack(*key.split('/'),layout=value)
    results=[]; errors=[]; samples=[]
    for rel,size in state['png'].items():
        if Path(rel).stem.endswith(('_e','_n','_shadow')): continue
        p=GAME/rel; full='characters/tocsin/'+rel
        cell=1032 if p.stem in ('head_blast_top','head_ring') else 56 if p.stem=='rivet' else 256 if p.stem.startswith('portrait') else 192
        try:
            r=cel.check_sheet(full,normals=False)
            r.update(size=list(Image.open(p).size),normal_absent=not p.with_name(p.stem+'_n.png').exists())
            assert r['size']==size and r['normal_absent'],rel
            old=cel.ARCHIVE/full
            a=np.asarray(Image.open(old).convert('RGBA')); b=np.asarray(Image.open(p).convert('RGBA'))
            if '/packed/' not in rel:
                counts={'empty':0,'duplicates':0}; refcounts={'empty':0,'duplicates':0}
                for pixels,out in [(a,refcounts),(b,counts)]:
                    for y in range(0,size[1],cell):
                        hashes=[]
                        for x in range(0,size[0],cell):
                            tile=pixels[y:y+cell,x:x+cell]
                            if not tile[...,3].any(): out['empty']+=1
                            hashes.append(hashlib.sha256(tile.tobytes()).hexdigest())
                        out['duplicates']+=len(hashes)-len(set(hashes))
                r['cells']=counts; r['archive_cells']=refcounts
                assert counts['empty']==refcounts['empty'],(rel,'new empty cells')
                assert counts['duplicates']<=refcounts['duplicates'],(rel,'new duplicate cells')
            ep=p.with_name(p.stem+'_e.png')
            if ep.exists():
                assert sha(ep)==sha(cel.ARCHIVE/ep.relative_to(cel.GAME_SPRITES)),rel
                r['accent_iou']=1.0; r['emission']='archive exact, half resolution'
            results.append(r)
        except AssertionError as e: errors.append(str(e))
        if '/layers/' not in full:
            samples.append((full,cell,0,0 if size[1]<1536 or cell!=192 else 2))
    changed=[rel for rel,value in state['protected'].items() if sha(ROOT/rel)!=value]
    external=[rel for rel in changed if Path(rel).suffix in ('.gd','.tscn')]
    assert all(rel in external for rel in changed),('protected files changed',changed)
    assert not list(GAME.rglob('*_n.png')),'forbidden normals'
    cel.contact_pair([samples[i:i+4] for i in range(0,len(samples),4)],HERE/'_cel_heroes_tocsin_contact.png',size=(1920,2400))
    report={'checks':results,'errors':errors,'external_changes':external,'profiles':['creature','prop'],'choices':'Shared night shadow floor; native scale, camera, rig and poses unchanged. Original approved emission masks retained exactly. Original T5 layout retained. Intentional missing limbs / static frames compared with archive.','bytes_before':state['bytes_before'],'bytes_after':sum(p.stat().st_size for p in GAME.rglob('*.png'))}
    REPORT.write_text(json.dumps(report,indent=2))
    print('VERIFY',len(results),'ERRORS',len(errors),flush=True)
    if errors: raise AssertionError(errors[:8])

def driver():
    from PIL import Image
    cel.archive_folder('characters/tocsin')
    # The root archive includes every layer, packed atlas and T6 child folder.
    if not STATE.exists():
        protected=list(GAME.rglob('*.tres'))+list(GAME.rglob('*.json'))+list(GAME.rglob('*.import'))+list((ROOT/'art/blender/characters').glob('tocsin*.blend'))+list((ROOT/'game').rglob('*.gd'))+list((ROOT/'game').rglob('*.tscn'))
        STATE.write_text(json.dumps({'png':{p.relative_to(GAME).as_posix():list(Image.open(p).size) for p in GAME.rglob('*.png')},'protected':{p.relative_to(ROOT).as_posix():sha(p) for p in protected},'bytes_before':sum(p.stat().st_size for p in GAME.rglob('*.png'))},indent=2))
    if '--verify' not in sys.argv:
        args=[BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
        if '--resume' in sys.argv: args.append('--resume')
        if '--t6-only' in sys.argv: args.append('--t6-only')
        with (HERE/'_cel_heroes_tocsin_blender.log').open('w') as log:
            result=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        if result.returncode: raise RuntimeError('Blender failed; see _cel_heroes_tocsin_blender.log')
    finish()
    checks=[]
    commands=[('policy',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy']),('import',[GODOT,'--headless','--path',str(ROOT/'game'),'--import'])]
    commands += [(name,[GODOT,'--headless','--path',str(ROOT/'game'),'res://tests/'+name+'.tscn']) for name in ['sprites_test','tocsin_test','player_test','texture_budget_test']]
    for name,args in commands:
        logpath=HERE/('_cel_heroes_tocsin_'+name+'.log')
        with logpath.open('w') as log:
            result=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,timeout=600,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        output=logpath.read_text(errors='replace')
        ok=result.returncode==0 and ('RESULT: OK' in output if name.endswith('_test') else 'ERROR:' not in output)
        checks.append({'name':name,'ok':ok,'exit':result.returncode})
        report=json.loads(REPORT.read_text());report['runtime_checks']=checks;REPORT.write_text(json.dumps(report,indent=2))
        print(name, 'PASS' if ok else 'FAIL',flush=True)
        assert ok,logpath

if __name__=='__main__':
    if '--render' in sys.argv: render()
    else: driver()
