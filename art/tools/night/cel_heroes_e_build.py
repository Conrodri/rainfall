"""CEL-HEROES_E: original scene/pose/export functions; shading only, no normals.
System driver; Blender -- --render; --resume restarts completed subject groups.
"""
import sys, json, hashlib, subprocess, inspect
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
WORK=ROOT/'art/blender/cel/heroes_e'
SPR=ROOT/'game/assets/sprites'
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(HERE),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/characters'),str(ROOT/'art/tools')]
import cel_style as cel
RELS=['characters/bourbe','characters/bourbe/motte',*[f'characters/bourbe/{k}' for k in ('bog_zone','ally_ring','mud_slap','mud_splash')],'characters/montreur']
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'

def patched(module,name,replacements):
    """Adapt legacy pass lists locally; keep source modules untouched."""
    try:src=inspect.getsource(getattr(module,name))
    except OSError:
        import av1_build
        src=inspect.getsource(getattr(av1_build,name)).replace("['Averse']","['Motte']").replace('AV1','BO2')
    for a,b in replacements:
        assert a in src,(name,a)
        src=src.replace(a,b)
    exec(compile(src,str(Path(module.__file__)), 'exec'),module.__dict__)
    return getattr(module,name)

def render():
    import bpy, iso_rig
    from PIL import Image
    import bo1_build as bo1, bo2_build as bo2, bo3_build as bo3, m2_build as m2
    # Shared exporter otherwise unconditionally expects a removed normal output.
    patched(iso_rig,'render_frame',[("for suffix in ('_n','_e'):","for suffix in ('_e',):")])
    iso_rig.optimize_png=lambda *a,**k:None
    def open_source(name,profile):
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters'/name))
        cel.install(profile,normals=False)
        return bpy.context.scene
    def actor_source():
        open_source('bourbe.blend','creature')
        root=next(o for o in bpy.data.objects if o.name.startswith('BOURBE') and o.type=='EMPTY')
        rig=bpy.data.objects['Bourbe_Rig'];rig.animation_data_clear()
        return root,rig
    bo1.build_model=actor_source;bo1.OUT=WORK/'stage/characters/bourbe';bo1.WORK=WORK/'raw/bourbe';bo1.resources=lambda:None
    patched(bo1,'render_actor',[("('','_n','_e')","('','_e')")])
    bo2.SOURCE=ROOT/'art/blender/characters/bourbe_motte.blend';bo2.DEST=WORK/'stage/characters/bourbe/motte';bo2.WORK=WORK/'raw/motte';bo2.resources=lambda:None
    bo3.OUT=WORK/'stage/characters/bourbe';bo3.WORK=WORK/'raw/effects';bo3.resources=lambda key:None
    def effect_source(key):
        open_source('bourbe_'+key+'.blend','vfx')
        return bpy.data.objects['BO3 '+key]
    bo3.build_effect=effect_source
    def strength(mat,value):
        nodes=mat.node_tree.nodes
        node=nodes.get('Principled BSDF') or nodes.get('Emission')
        node.inputs['Emission Strength' if node.type=='BSDF_PRINCIPLED' else 'Strength'].default_value=value
    bo3.cel_strength=strength
    patched(bo3,'effects',[("('','_n','_e')","('','_e')"),("mat.node_tree.nodes.get('Principled BSDF').inputs['Emission Strength'].default_value=1.25+.25*math.sin(phase)","cel_strength(mat,1.25+.25*math.sin(phase))")])
    m2.OUT=WORK/'raw/montreur';m2.DEST=WORK/'stage/characters';m2.resources=lambda actor:None
    m2.cel=cel
    patched(m2,'build',[("('','_n','_e')","('','_e')"),("s=bpy.context.scene", "cel.install('creature',normals=False);s=bpy.context.scene"),("bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/characters'/(actor+'.blend')))", "# Source immutable; no save.")])
    def group(name,fn):
        marker=WORK/(name+'.done')
        if '--resume' in sys.argv and marker.exists():return
        fn();marker.write_text('PASS');print('PASS '+name,flush=True)
    group('bourbe',bo1.render_actor)
    bo2.cel=cel
    patched(bo2,'atlases',[("if '--resume' in sys.argv and","if False and"),("('','_n','_e')","('','_e')"),("s=bpy.context.scene;root=", "cel.install('prop',normals=False);s=bpy.context.scene;s.compositing_node_group=None;cel.setup_scene();cel.toon_materials('prop');bpy.context.view_layer.update();root=")])
    group('motte',bo2.atlases)
    def portrait():
        open_source('bourbe_portrait.blend','creature')
        iso_rig.render_frame(bo1.OUT/'portrait.png')
    group('portrait',portrait)
    group('effects',bo3.effects)
    group('montreur',lambda:m2.build('montreur'))

def protected():
    paths=[p for rel in ('characters/bourbe','characters/montreur') for p in (SPR/rel).rglob('*') if p.suffix in ('.tres','.json','.import') or 'string_tile' in p.parts and p.is_file()]
    paths+=list((ROOT/'art/blender/characters').glob('bourbe*.blend'))+[ROOT/'art/blender/characters/montreur.blend']
    return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}

def deliver():
    from PIL import Image
    import numpy as np
    import halve_emission
    stage=WORK/'stage'
    files=[]
    for rel in ('characters/bourbe','characters/montreur'):
        for old in sorted((cel.ARCHIVE/rel).rglob('*.png')):
            r=old.relative_to(cel.ARCHIVE)
            if 'string_tile' in r.parts or old.stem.endswith(('_n','_shadow')):continue
            if old.stem in ('bog_zone_0','bog_zone_1','bog_zone_0_e','bog_zone_1_e'):
                import shutil
                shutil.copy2(old,SPR/r)
                continue
            source=stage/r
            assert source.exists(),str(source)
            with Image.open(source) as im:im=im.convert('RGBA')
            with Image.open(old) as ref:expected=ref.size
            if old.stem.endswith('_e'):
                # Emissive materials are unchanged by cel: retain exact validated masks,
                # including the original mobile peak/downsampling and alpha coverage.
                import shutil
                shutil.copy2(old,SPR/r)
                continue
            assert im.size==expected,(str(r),im.size,expected)
            im.save(SPR/r,optimize=True,compress_level=9)
            if not old.stem.endswith('_e'):files.append(str(r).replace('\\','/'))
    return files

def verify(files):
    from PIL import Image
    import numpy as np
    report={'choices':['Original models, rigs, poses, cameras and material hues. Night shadow floor from shared cel module.','creature: Bourbe, portrait, Montreur; prop: motte; vfx without ink: four ground effects.','Exact archived emission masks retained: luminous materials unchanged; original half-resolution coverage preserved.','Two legacy bog_zone_0/1 atlases are absent from all SpriteFrames references; preserved byte-identically because their historical geometry differs from the available source. Rendered all referenced bog_zone atlases.'], 'sheets':[], 'errors':[]}
    # Include retained legacy sheets in contract checks, while distinguishing
    # them from the sheets actually rerendered by this lot.
    legacy=[f'characters/bourbe/bog_zone/bog_zone_{i}.png' for i in (0,1)]
    for rel in dict.fromkeys([*files,*legacy]):
        name=Path(rel);im=Image.open(SPR/rel);w,h=im.size
        cell=192 if name.parent.name in ('bourbe','motte','montreur') and name.stem!='portrait' else (256 if name.stem=='portrait' else 648 if name.stem in ('bog_zone_0','bog_zone_1') else 720 if name.parent.name=='bog_zone' else 64 if name.parent.name=='ally_ring' else 288)
        try:
            res=cel.check_sheet(rel,cell=cell,frames=w//cell,rows=h//cell,normals=False)
            assert not (SPR/name.with_stem(name.stem+'_n')).exists()
            ep=SPR/name.with_stem(name.stem+'_e');old=cel.ARCHIVE/name.with_stem(name.stem+'_e')
            if ep.exists():
                e=np.asarray(Image.open(ep).convert('RGBA'));ref=np.asarray(Image.open(old).convert('RGBA'))
                a=(ref[:,:,:3].max(2)>100)&(ref[:,:,3]>128);b=(e[:,:,:3].max(2)>100)&(e[:,:,3]>128)
                res['emission_size']=[e.shape[1],e.shape[0]]
                res['emission_alpha_matches_archive']=bool(np.array_equal(e[:,:,3],ref[:,:,3]))
                res['emission_nonblack']=bool(np.max(e[:,:,:3].max(2)*(e[:,:,3].astype(float)/255))>2)
                assert res['emission_alpha_matches_archive'] and res['emission_nonblack']
                if a.any() or b.any():
                    res['accent_iou_half']=float((a&b).sum()/max(1,(a|b).sum()))
                    assert res['accent_iou_half']>.97,(rel,'accent',res['accent_iou_half'])
            res.update(size=[w,h],cell=cell,frames=w//cell,rows=h//cell,normals_absent=True,rewritten=rel not in legacy)
            report['sheets'].append(res)
        except Exception as exc:report['errors'].append(str(exc))
    assert all((SPR/rel).read_bytes()==(cel.ARCHIVE/rel).read_bytes() for rel in legacy)
    roots=('characters/bourbe','characters/montreur')
    archived={str(p.relative_to(cel.ARCHIVE)) for rel in roots for p in (cel.ARCHIVE/rel).rglob('*.png') if not p.stem.endswith('_n')}
    delivered={str(p.relative_to(SPR)) for rel in roots for p in (SPR/rel).rglob('*.png')}
    assert archived==delivered,('PNG inventory changed',sorted(archived^delivered))
    assert not any(p.stem.endswith('_n') for rel in roots for p in (SPR/rel).rglob('*.png'))
    assert not any('CanvasTexture' in p.read_text() or 'normal_texture' in p.read_text() for rel in roots for p in (SPR/rel).rglob('*.tres'))
    assert protected()==json.loads((WORK/'protected.json').read_text())
    report['contract']={'png_inventory_matches_archive':True,'protected_files_unchanged':True,'normal_maps':0,'normal_texture_references':0,'max_dimension':max(max(s['size']) for s in report['sheets'])}
    report['bytes_before']=sum(p.stat().st_size for rel in ('characters/bourbe','characters/montreur') for p in (cel.ARCHIVE/rel).rglob('*.png') if not p.stem.endswith('_n'))
    report['bytes_after']=sum(p.stat().st_size for rel in ('characters/bourbe','characters/montreur') for p in (SPR/rel).rglob('*.png'))
    (HERE/'_cel_heroes_e_verification.json').write_text(json.dumps(report,indent=2))
    samples=[[('characters/bourbe/'+a+'.png',192,0,2) for a in ('idle','run','cast_ult')],[('characters/bourbe/portrait.png',256,0,0),('characters/bourbe/motte/run.png',192,2,2),('characters/montreur/pull.png',192,2,2)],[('characters/bourbe/bog_zone/bog_zone.png',720,0,0)],[('characters/bourbe/'+k+'/'+k+'.png',64 if k=='ally_ring' else 288,0,0) for k in ('ally_ring','mud_slap','mud_splash')]]
    cel.contact_pair(samples,HERE/'_cel_heroes_e_contact.png',size=(1800,1900))
    with Image.open(HERE/'_cel_heroes_e_contact.png') as board, Image.open(HERE/'_cs1_contact.png') as ref:
        strip=ref.crop((ref.width//2,0,ref.width,ref.height));strip.thumbnail((900,650))
        combined=Image.new('RGB',(1800,1900+strip.height),(18,22,23));combined.paste(board,(0,0));combined.paste(strip,(450,1900));combined.save(HERE/'_cel_heroes_e_contact.png',optimize=True)
    print(json.dumps({'sheets':len(report['sheets']),'errors':report['errors'],'bytes_before':report['bytes_before'],'bytes_after':report['bytes_after']}))
    assert not report['errors'],'Verification failed; see JSON'

def checks():
    results=[]
    commands=[('policy',[sys.executable,'art/tools/texture_budget.py','--apply-policy']),('budget',[sys.executable,'art/tools/texture_budget.py','--strict','--top','1']),('import',[GODOT,'--headless','--path','game','--import'])]
    commands += [(name,[GODOT,'--headless','--path','game',f'res://tests/{name}_test.tscn']) for name in ('sprites','bourbe','rictus','player','texture_budget')]
    for name,args in commands:
        log=HERE/('_cel_heroes_e_'+name+'.log')
        with log.open('w',encoding='utf8') as output:
            try:code=subprocess.call(args,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,timeout=180)
            except subprocess.TimeoutExpired:code=-1
        text=log.read_text(encoding='utf8',errors='replace')
        okay=code==0 and (name in ('policy','budget','import') or 'RESULT: OK' in text)
        if name=='import':okay=okay and not any(token in text for token in ('ERROR:','SCRIPT ERROR:'))
        results.append(dict(name=name,exit_code=code,passed=okay,log=str(log.relative_to(ROOT))))
        print(('PASS ' if okay else 'FAIL ')+name,flush=True)
    report_path=HERE/'_cel_heroes_e_verification.json';report=json.loads(report_path.read_text());report['checks']=results;report_path.write_text(json.dumps(report,indent=2))
    assert all(x['passed'] for x in results),'Engine/budget checks failed; see logs'


def driver():
    WORK.mkdir(parents=True,exist_ok=True)
    for rel in RELS:cel.archive_folder(rel)
    baseline=WORK/'protected.json'
    if not baseline.exists():baseline.write_text(json.dumps(protected(),indent=2))
    if '--verify' not in sys.argv:
        with (HERE/'_cel_heroes_e_blender.log').open('a',encoding='utf8') as log:
            code=subprocess.call([BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']+(['--resume'] if '--resume' in sys.argv else []),stdout=log,stderr=subprocess.STDOUT,cwd=ROOT)
        assert code==0,('Blender',code)
        assert all((WORK/(g+'.done')).exists() for g in ('bourbe','motte','portrait','effects','montreur')),'Incomplete Blender render'
        files=deliver();(WORK/'files.json').write_text(json.dumps(files))
    else:files=json.loads((WORK/'files.json').read_text())
    assert protected()==json.loads(baseline.read_text()),'Protected files changed'
    verify(files)
    checks()

if __name__=='__main__':
    render() if '--render' in sys.argv else driver()

