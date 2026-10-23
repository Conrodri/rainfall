import ast, hashlib, json, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
SPR=ROOT/'game/assets/sprites'
WORK=ROOT/'art/blender/cel/props_core'
BLENDER=r'C:\Program Files\Blender Foundation\Blender 5.2\blender.exe'
GODOT=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso')]
import cel_style as cel
MAN=WORK/'manifest.json'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def sha_bytes(b):return hashlib.sha256(b).hexdigest()
def manifest():
    if MAN.exists():return json.loads(MAN.read_text())
    folders=['chests/chest_'+x for x in ('small','large','legendary')]+['props','props/gold_capsule','pickups']+['pickups/'+x for x in ('gold_bag','gold_coin','xp_gem','xp_gem_big')]+['projectiles/ember_shard','vfx/ember_shard_impact']
    for rel in folders:cel.archive_folder(rel)
    files=[]
    for rel in folders:
        for p in (SPR/rel).glob('*.png'):
            if rel=='props' and not p.name.startswith(('pillar_','teleporter_')):continue
            if rel=='pickups' and p.stem not in ('coin','gold_bag','xp_gem','xp_gem_big'):continue
            if '_n' in p.stem:continue
            files.append(str(p.relative_to(SPR)).replace('\\','/'))
    from PIL import Image
    d={'files':sorted(set(files)),'before_bytes':sum((SPR/x).stat().st_size for x in files),'sizes':{x:list(Image.open(SPR/x).size) for x in files},'protected':{str(p.relative_to(SPR)).replace('\\','/'):sha(p) for rel in folders for p in (SPR/rel).glob('*') if p.is_file() and p.suffix in ('.tres','.json','.import')},'normals':[str(p.relative_to(SPR)).replace('\\','/') for rel in folders for p in (SPR/rel).glob('*_n*.png')]}
    MAN.parent.mkdir(parents=True,exist_ok=True);MAN.write_text(json.dumps(d,indent=2));return d

def render():
    import bpy, inspect, types
    import iso_rig as rig
    from PIL import Image
    # Adapt only legacy collection of the removed normal output; reuse original renderer.
    src=inspect.getsource(rig.render_frame).replace("('_n','_e')","('_e',)")
    exec(compile(src,str(ROOT/'art/tools/iso/iso_rig.py'),'exec'),rig.__dict__)
    bpy.ops.wm.save_as_mainfile=lambda **kw:None
    d=json.loads(MAN.read_text())
    cel.install('prop',normals=False)
    def finished(job):return '--resume' in sys.argv and (WORK/(job+'.done')).exists()
    def done(job):(WORK/(job+'.done')).write_text('PASS')
    import c8_build as c
    if not finished('c8'):
        # Import C8b definitions, excluding its old executable build/write footer.
        p=ROOT/'art/tools/iso/c8b_build.py';tree=ast.parse(p.read_text(encoding='utf-8-sig'));tree.body=[n for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom,ast.FunctionDef))]
        mod=types.ModuleType('c8b_reuse');mod.__file__=str(p);mod.audit={};exec(compile(tree,str(p),'exec'),mod.__dict__);c.chest=mod.chest
        inv=json.loads((ROOT/'art/tools/iso/_c8_inventory.json').read_text())
        # Include emission files introduced by C8b and retained by the delivered contract.
        known={a['path'] for a in inv['assets']}
        for rel in d['files']:
            if not rel.startswith(('chests/','props/')) or '_e' not in Path(rel).stem or '_sw' in Path(rel).stem:continue
            key='game/assets/sprites/'+rel
            if key not in known:
                base=key.replace('_e.png','.png');a=dict(next(a for a in inv['assets'] if a['path']==base));a['path']=key;inv['assets'].append(a)
        assets=[];pivots={}
        for a in inv['assets']:
            if Path(a['path']).stem.endswith('_n'):continue
            a=dict(a);old=a['path'];rel=str(Path(old).relative_to('game/assets/sprites'));a['path']=(WORK/'c8'/rel).relative_to(ROOT).as_posix();assets.append(a)
            if old in inv['pivots']:pivots[a['path']]=inv['pivots'][old]
        inv['assets']=assets;inv['pivots']=pivots;c.INV=WORK/'c8_inventory.json';c.INV.write_text(json.dumps(inv));c.old_pivots=lambda x:x
        c.build();done('c8')
    def tag_emission():
        # Legacy C10 grain ramps do not imply a non-emissive material.
        for m in bpy.data.materials:
            if m.use_nodes:
                bsdf=next((n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
                if bsdf and bsdf.inputs['Emission Strength'].default_value>.01:m['rainfall_emissive']=True
    import c10_build as c10
    if not finished('c10'):
        for kind in ('gold_coin','gold_bag','xp_gem','xp_gem_big'):
            bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'art/blender/props/c10_{kind}.blend'))
            tag_emission();cel.install('prop',normals=False)
            count=8 if kind in ('gold_coin','xp_gem') else 1;frames=[];ems=[]
            for f in range(count):
                if kind=='xp_gem' and f:
                    bpy.ops.wm.open_mainfile(filepath=str(ROOT/f'art/blender/props/c10_{kind}.blend'));cel.install('prop',normals=False)
                bpy.context.scene.frame_set(f+1);tag_emission();p=WORK/'frames'/f'{kind}_{f}.png';rig.render_frame(p);frames.append(Image.open(p).convert('RGBA').copy());ems.append(Image.open(p.with_name(p.stem+'_e.png')).convert('RGBA').copy())
            out=WORK/'c10/pickups'/kind;out.mkdir(parents=True,exist_ok=True)
            for suffix,ims in [('',frames),('_e',ems)]:
                atlas=Image.new('RGBA',(48*count,48))
                for i,im in enumerate(ims):atlas.paste(im,(i*48,0))
                atlas.save(out/f'default{suffix}.png',optimize=True)
            # C10 is the recorded replacement source of these still-loaded root icons.
            frames[0].save(WORK/'c10/pickups'/('coin.png' if kind=='gold_coin' else kind+'.png'),optimize=True)
        done('c10')
    import v2_build as v2
    if not finished('v2'):
        v2.DIRS=[WORK/'v2/projectiles/ember_shard',WORK/'v2/vfx/ember_shard_impact']
        for p in v2.DIRS:p.mkdir(parents=True,exist_ok=True)
        def passes(s,size,folder,frame):
            s['iso_frame']=[size,size];p=WORK/'frames'/f'v2_{folder}_{frame}.png';cel.install('prop',normals=False);rig.render_frame(p)
            return {suffix:Image.open(p.with_name(p.stem+suffix+'.png')).convert('RGBA').copy() for suffix in ('','_e')}
        v2.passes=passes
        # Remove only legacy normal atlas assembly; geometry/animation functions unchanged.
        src=inspect.getsource(v2.build).replace("('','_e','_n')","('','_e')")
        exec(compile(src,str(ROOT/'art/tools/iso/v2_build.py'),'exec'),v2.__dict__)
        for k in (0,1):v2.build(k)
        done('v2')
    print('PASS CEL-PROPS_CORE render',flush=True)

def publish_verify():
    from PIL import Image
    import numpy as np
    d=json.loads(MAN.read_text());results=[]
    for rel in d['files']:
        p=SPR/rel
        if '_shadow' in p.stem:continue # Shading-independent original ground decals retained byte for byte.
        job='c8' if rel.startswith(('chests/','props/')) else 'c10' if rel.startswith('pickups/') else 'v2'
        src=(cel.ARCHIVE/rel) if '_e' in p.stem else WORK/job/rel
        assert src.exists(),str(src)
        im=Image.open(src).convert('RGBA');expected=tuple(d['sizes'][rel])
        # C8's historic SW naming puts the pass before the orientation.
        if '_e' in p.stem:
            base=SPR/p.relative_to(SPR).parent/(p.name.replace('_e',''))
            full=tuple(d['sizes'][str(base.relative_to(SPR)).replace('\\','/')])
            if im.size==full:
                import importlib.util
                spec=importlib.util.spec_from_file_location('halve',ROOT/'art/tools/halve_emission.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h);im=h.downscale(im)
            im.save(p,optimize=True,compress_level=9);continue
        if im.size!=expected:
            assert '_e' in p.stem and expected==((im.width+1)//2,(im.height+1)//2),(rel,im.size,expected)
            # Reuse the project's peak-preserving emission reducer.
            import importlib.util
            spec=importlib.util.spec_from_file_location('halve',ROOT/'art/tools/halve_emission.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
            im=h.downscale(im)
        im.save(p,optimize=True,compress_level=9)
    for rel in d['normals']:
        p=SPR/rel
        if p.exists():p.unlink()
    for rel in d['files']:
        p=SPR/rel
        if '_e' in p.stem or '_shadow' in p.stem:continue
        w,h=d['sizes'][rel];cell=h
        ref=Image.open(cel.ARCHIVE/rel).convert('RGBA');new=Image.open(p).convert('RGBA');n=w//cell
        key=lambda im,i:sha_bytes(im.crop((i*cell,0,(i+1)*cell,cell)).tobytes())
        old_unique=len({key(ref,i) for i in range(n)});new_unique=len({key(new,i) for i in range(n)})
        try:
            r=cel.check_sheet(rel,cell=cell,frames=n if old_unique==n and not rel.startswith('vfx/') else None,rows=1,normals=False)
            assert new_unique>=old_unique,(rel,'new duplicate frames',new_unique,old_unique)
            assert all(new.crop((i*cell,0,(i+1)*cell,cell)).getchannel('A').getextrema()[1]>0 for i in range(n)),(rel,'empty cell')
            r['frames']=n;r['unique_cells']=new_unique;r['archive_unique_cells']=old_unique
            if old_unique<n:r['inherited_duplicate_frames']=n-old_unique
        except AssertionError as e:r={'file':rel,'error':str(e)}
        r['size']=[w,h];r['no_normal']=not p.with_name(p.stem+'_n.png').exists();results.append(r)
    emissions=[]
    for rel in d['files']:
        if '_e' not in Path(rel).stem:continue
        new=Image.open(SPR/rel).convert('RGBA');ref=Image.open(cel.ARCHIVE/rel).convert('RGBA')
        if ref.size!=new.size:
            import importlib.util
            spec=importlib.util.spec_from_file_location('halve',ROOT/'art/tools/halve_emission.py');h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h);ref=h.downscale(ref)
        a=np.asarray(new);b=np.asarray(ref)
        am=(a[:,:,:3].max(2)>100)&(a[:,:,3]>128);bm=(b[:,:,:3].max(2)>100)&(b[:,:,3]>128)
        union=(am|bm).sum();iou=float((am&bm).sum()/union) if union else 1.0
        peak=float((a[:,:,:3].max(2)*a[:,:,3].astype(float)/255).max())
        assert iou>.97 and peak>2,(rel,'accent',iou,peak)
        emissions.append({'file':rel,'size':list(new.size),'accent_iou':iou,'alpha_matches_archived_mask':bool(np.array_equal(a[:,:,3],b[:,:,3])),'peak':peak})
    assert not any((SPR/x).exists() for x in d['normals']),'legacy SW normal remains'
    protected=[k for k,v in d['protected'].items() if sha(SPR/k)!=v]
    report={'profile':'prop','normals':False,'choices':['Original ground shadow decals retained','Root pickup stills use C10, their recorded delivered source','Original tint and camera; shared night shadow floor','Original continuous emission masks retained; full-size masks reduced with project peak filter','XP cycle inherits 5 unique poses / 8 frames; translucent impact fade retained'],'sheets':results,'emissions':emissions,'removed_normals':d['normals'],'protected_changed':protected,'before_bytes':d['before_bytes']+sum((cel.ARCHIVE/x).stat().st_size for x in d['normals']),'after_bytes':sum((SPR/x).stat().st_size for x in d['files'])}
    (HERE/'_cel_props_core_verification.json').write_text(json.dumps(report,indent=2))
    samples=[];line=[]
    for r in results:
        rel=r['file'];w,h=r['size'];line.append((rel,h,0,0))
        if len(line)==4:samples.append(line);line=[]
    if line:samples.append(line)
    cel.contact_pair(samples,HERE/'_cel_props_core_contact.png',size=(1600,max(900,len(samples)*290)))
    errors=[r for r in results if 'error' in r]
    assert not errors and not protected,str(errors[:4])+str(protected[:2])
    print('PASS verification',len(results),flush=True)

def driver():
    manifest()
    if '--verify' not in sys.argv:
        with (HERE/'_cel_props_core_blender.log').open('w') as log:
            cmd=[BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
            if '--resume' in sys.argv:cmd+=['--resume']
            r=subprocess.run(cmd,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,creationflags=0x08000000)
        assert r.returncode==0 and 'PASS CEL-PROPS_CORE render' in (HERE/'_cel_props_core_blender.log').read_text(errors='replace'),'Blender failed: art/tools/night/_cel_props_core_blender.log'
    publish_verify()
    checks=[('budget',[sys.executable,'art/tools/texture_budget.py','--apply-policy']),('import',[GODOT,'--headless','--path','game','--import'])]
    checks += [(name,[GODOT,'--headless','--path','game','res://tests/'+name+'.tscn']) for name in ('sprites_test','capsule_test','gold_pickup_test','loot_test','action_vfx_test','texture_budget_test')]
    outcomes={}
    for name,cmd in checks:
        log=HERE/('_cel_props_core_'+name+'.log')
        with log.open('w') as out:r=subprocess.run(cmd,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,timeout=300,creationflags=0x08000000)
        txt=log.read_text(errors='replace');errors=[x for x in txt.splitlines() if any(t in x for t in ('SCRIPT ERROR:','Parse Error:','ERROR:'))]
        blocking=errors if name=='import' else [x for x in errors if 'resources still in use at exit' not in x]
        ok=r.returncode==0 and not blocking and (name in ('budget','import') or 'RESULT: OK' in txt)
        outcomes[name]={'ok':ok,'returncode':r.returncode,'errors':blocking[:3],'exit_resource_warnings':[x for x in errors if 'resources still in use at exit' in x],'result_ok':'RESULT: OK' in txt}
    p=HERE/'_cel_props_core_verification.json';report=json.loads(p.read_text());report['checks']=outcomes;p.write_text(json.dumps(report,indent=2))
    assert all(x['ok'] for x in outcomes.values()),str({k:v for k,v in outcomes.items() if not v['ok']})
    print('PASS budget, import, 6 Godot tests',flush=True)
if __name__=='__main__':
    if '--render' in sys.argv:render()
    else:driver()
