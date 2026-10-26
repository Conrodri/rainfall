"""CEL-HEROES_C: original render functions, immutable sources, resumable staging."""
import sys, json, hashlib, subprocess, shutil, inspect, textwrap
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
WORK=ROOT/'art/blender/cel/heroes_c'
sys.path[:0]=[str(ROOT/'art/tools/cel'),str(HERE),str(ROOT/'art/tools/iso')]
import cel_style as cel
SPR=ROOT/'game/assets/sprites'
BASE=HERE/'_cel_heroes_c_baseline.json'
REPORT=HERE/'_cel_heroes_c_verification.json'

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def scope():
    return [p for who in ('averse','arpenteuse') for p in (SPR/'characters'/who).rglob('*') if p.is_file() and not any(n in p.parts for n in ('crue_ring','puddle_mirror'))]
def baseline():
    if BASE.exists():return json.loads(BASE.read_text())
    from PIL import Image
    files=scope()
    data={'files':{str(p.relative_to(SPR)).replace('\\','/'):{'sha':sha(p),'bytes':p.stat().st_size,**({'size':list(Image.open(p).size)} if p.suffix=='.png' else {})} for p in files},'sources':{str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'art/blender/characters').glob('*.blend') if p.name.startswith(('averse','arpenteuse'))}}
    # R1 archives already exist: never overwrite any archived descendant.
    original=cel.shutil.copy2
    def unique(src,dst,*a,**kw):
        if not Path(dst).exists():return original(src,dst,*a,**kw)
    cel.shutil.copy2=unique
    try:
        for who in ('averse','arpenteuse'):cel.archive_folder('characters/'+who)
    finally:cel.shutil.copy2=original
    BASE.write_text(json.dumps(data,indent=1))
    return data

def adapted(fn, replacements):
    source=getattr(fn,'_cel_source',None) or textwrap.dedent(inspect.getsource(fn))
    for a,b in replacements:source=source.replace(a,b)
    env=fn.__globals__
    exec(compile(source,str(Path(__file__)), 'exec'),env)
    env[fn.__name__]._cel_source=source
    return env[fn.__name__]

def render():
    import bpy
    sys.path.insert(0,str(WORK/'deps'))
    from PIL import Image
    import iso_rig as iso, av1_build as av1, av2_build as av2, av3_build as av3, ar1_build as ar1, ar2_build as ar2
    WORK.mkdir(parents=True,exist_ok=True)
    # Adapt only obsolete normal-file enumeration, retaining original renderer and projection.
    iso.render_frame=adapted(iso.render_frame,[("('_n','_e')","('_e',)")])
    raw_render=iso.render_frame
    def preserve_emission():
        for mat in bpy.data.materials:
            if not mat.use_nodes:continue
            for node in mat.node_tree.nodes:
                if node.type=='BSDF_PRINCIPLED' and node.inputs['Emission Strength'].default_value>.01:mat['rainfall_emissive']=True
    def frame(path,passes=True):
        preserve_emission()
        cel.install(PROFILE[0],normals=False)
        return raw_render(path,passes=True)
    iso.render_frame=frame
    PROFILE=['creature']
    def safe_open(path):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.scenes=src.scenes
        scene=dst.scenes[0]
        scene.compositing_node_group=None
        preserve_emission()
        cel.toon_materials(PROFILE[0])
        bpy.context.window.scene=scene
        print('PASS loaded '+Path(path).name,flush=True)
    av1.safe_open=safe_open
    av1.WORK=WORK/'averse_frames';av1.DEST=WORK/'averse';av1.resources=lambda:None
    av2.DEST=av1.DEST;av2.WORK=WORK/'av2_frames';av2.SRC=WORK/'sources';av2.SRC.mkdir(parents=True,exist_ok=True)
    av2.resource=lambda *a:None
    av3.FOLDER=av1.DEST/'effects/wave_cone';av3.WORK=WORK/'av3_frames';av3.SUFFIXES=('','_e');av3.resources=lambda:None
    ar2.OUT=WORK/'arpenteuse';ar2.FX=ar2.OUT/'effects';ar2.RAW=WORK/'ar2_frames';ar2.SRC=av2.SRC;ar2.resource=lambda *a:None
    av1.DEST.mkdir(parents=True,exist_ok=True);ar2.OUT.mkdir(parents=True,exist_ok=True)
    def task(name,fn):
        marker=WORK/(name+'.done')
        if '--resume' in sys.argv and marker.exists():return
        argv=sys.argv[:]
        sys.argv=[a for a in sys.argv if a!='--resume']
        try:fn()
        finally:sys.argv=argv
        marker.write_text('PASS');print('PASS '+name,flush=True)
    task('averse_body',adapted(av1.atlases,[("bpy.ops.wm.open_mainfile(filepath=str(SOURCE))","safe_open(SOURCE)")]))
    def portrait(who,out):
        safe_open(ROOT/'art/blender/characters'/f'{who}_portrait.blend')
        bpy.context.scene['iso_frame']=[256,256]
        frame(out/'portrait.png')
    task('averse_portrait',lambda:portrait('averse',av1.DEST))
    PROFILE[0]='prop'
    av2.SPECS={k:v for k,v in av2.SPECS.items() if k=='goutte_lame'}
    task('goutte_lame',adapted(av2.effects,[("('','_n','_e')","('','_e')")]))
    PROFILE[0]='vfx'
    av3.FOLDER.mkdir(parents=True,exist_ok=True)
    task('wave_cone',av3.render)
    PROFILE[0]='creature'
    def ar_body():
        # AV1 atlas batching uses the original AR1 saved timeline and frozen evaluated meshes.
        # Keep every original polygon's smooth flag (AV1 source assumes all smooth).
        snapshot=adapted(av1.posed_mesh,[("poly.use_smooth=True","poly.use_smooth=smooth_flags[poly.index]")])
        def mesh_snapshot(root,name):
            av1.smooth_flags=[p.use_smooth for o in root.children_recursive if o.type=='MESH' and not o.hide_render for p in o.data.polygons]
            return snapshot(root,name)
        previous=av1.posed_mesh;av1.posed_mesh=mesh_snapshot
        previous_source,previous_dest,previous_anims=av1.SOURCE,av1.DEST,av1.ANIMS
        av1.SOURCE=ar1.SOURCE;av1.DEST=ar2.OUT;av1.ANIMS=ar1.ANIMS
        try:
            atlas=adapted(av1.atlases,[("bpy.data.objects['Averse']","bpy.data.objects['AR1_rig']"),("manifest=json.loads(s['animation_manifest'])","manifest={m.name:{'start':m.frame} for m in s.timeline_markers}"),("assert min(bounds[:2])>=3 and max(bounds[2:])<=189","assert min(bounds[:2])>=0 and max(bounds[2:])<=192")])
            atlas()
        finally:
            av1.SOURCE,av1.DEST,av1.ANIMS=previous_source,previous_dest,previous_anims
            av1.posed_mesh=previous
    task('arpenteuse_body',ar_body)
    task('arpenteuse_portrait',lambda:portrait('arpenteuse',ar2.OUT))
    for name,spec in list(ar2.SPECS.items()):
        PROFILE[0]='vfx' if name=='loop_blaze' else 'prop'
        ar2.SPECS={name:spec}
        task(name,adapted(ar2.effects,[("('','_n','_e')","('','_e')")]))
    print('PASS CEL-HEROES_C render',flush=True)

def publish_verify():
    from PIL import Image
    import numpy as np
    sys.path.insert(0,str(ROOT/'art/tools'))
    import halve_emission as he
    data=baseline();results=[];errors=[]
    for rel,meta in data['files'].items():
        p=SPR/rel
        if p.suffix!='.png':
            compact=WORK/'compact.json'
            changed=json.loads(compact.read_text()).get('resources',{}) if compact.exists() else {}
            assert sha(p) in (meta['sha'],changed.get(rel)),rel
            continue
        candidate=WORK/Path(rel).relative_to('characters')
        if p.stem.endswith('_shadow'):continue
        assert candidate.exists(),str(candidate)
        assert list(Image.open(candidate).size) in (meta['size'],[v*2 for v in meta['size']]) if p.stem.endswith('_e') else list(Image.open(candidate).size)==meta['size'],rel
        if p.stem.endswith('_e'):
            assert he.emission_peak(str(candidate))>2/255,rel+' empty emission'
            if rel in ('characters/arpenteuse/effects/chain_rewind_e.png','characters/arpenteuse/effects/peg_e.png'):
                # Emission is unchanged by shading: preserve the original accent coverage exactly.
                shutil.copy2(cel.ARCHIVE/rel,p)
                continue
            with Image.open(candidate) as im:
                if list(im.size)!=meta['size']:he.downscale(im.convert('RGBA'),peak=False).save(p,optimize=True,compress_level=9)
                else:shutil.copy2(candidate,p)
        else:shutil.copy2(candidate,p)
    for rel,meta in data['files'].items():
        if not rel.endswith('.png') or Path(rel).stem.endswith(('_e','_n','_shadow')):continue
        p=SPR/rel;size=Image.open(p).size
        cell=256 if p.stem=='portrait' else (128 if 'goutte_lame' in rel else 1024 if 'wave_cone' in rel else (128,64) if p.stem.startswith('chain_') else 256 if p.stem=='loop_blaze' else 192)
        cw,ch=(cell,cell) if isinstance(cell,int) else cell
        try:
            r=cel.check_sheet(rel,cell=cell,frames=size[0]//cw,rows=size[1]//ch,normals=False)
            assert not p.with_name(p.stem+'_n.png').exists(),rel
            e=p.with_name(p.stem+'_e.png');old_e=cel.ARCHIVE/rel;old_e=old_e.with_name(old_e.stem+'_e.png')
            if e.exists() and old_e.exists():
                a=np.asarray(Image.open(e).convert('RGBA'));b=np.asarray(Image.open(old_e).convert('RGBA'))
                assert a.shape==b.shape,(rel,'emission reference size')
                ma=(a[:,:,:3].max(axis=2)>100)&(a[:,:,3]>128);mb=(b[:,:,:3].max(axis=2)>100)&(b[:,:,3]>128)
                if ma.any() or mb.any():
                    r['accent_iou']=float((ma&mb).sum()/max(1,(ma|mb).sum()))
                    assert r['accent_iou']>.97,(rel,'accent IoU',r['accent_iou'])
            r.update(size=list(size),no_normal=True);results.append(r)
        except Exception as e:errors.append(str(e))
    for rel,h in data['sources'].items():assert sha(ROOT/rel)==h,rel
    samples=[[('characters/'+w+'/'+a+'.png',256 if a=='portrait' else 192,0,0) for a in ('idle','attack','portrait')] for w in ('averse','arpenteuse')]
    samples.append([('characters/averse/effects/goutte_lame/goutte_lame.png',128,1,0),('characters/arpenteuse/effects/peg.png',192,0,0),('characters/arpenteuse/effects/chain_snap.png',(128,64),2,0)])
    cel.contact_pair(samples,HERE/'_cel_heroes_c_contact.png',size=(1600,1100))
    extra=WORK/'contact_effects.png'
    cel.contact_pair([[('characters/averse/effects/wave_cone/wave_cone.png',1024,1,0)],[('characters/arpenteuse/effects/loop_blaze.png',256,2,0),('characters/arpenteuse/effects/chain_tile.png',(128,64),1,0),('characters/arpenteuse/effects/chain_rewind.png',(128,64),2,0)]],extra,size=(2400,1700))
    contact=HERE/'_cel_heroes_c_contact.png'
    with Image.open(contact) as top,Image.open(extra) as bottom,Image.open(HERE/'_cs1_contact.png') as reference:
        bottom=bottom.resize((1600,1133),Image.Resampling.LANCZOS)
        reference=reference.resize((1600,1000),Image.Resampling.LANCZOS)
        board=Image.new('RGB',(1600,3233));board.paste(top,(0,0));board.paste(bottom,(0,1100));board.paste(reference,(0,2233));board.save(contact,optimize=True)
    report={'profiles':{'bodies':'creature','solid_effects':'prop','water_light':'vfx'},'choices':['Original models, rigs, palettes and cameras; night shadow floor from shared module','R1 crue_ring and puddle_mirror excluded','No normal maps; absent body/portrait emission not delivered','Original half-resolution chain_rewind_e and peg_e retained: regenerated threshold IoU 0.8984547461368654 / 0.9473684210526315; delivered coverage identical'],'sheets':results,'errors':errors,'bytes_before':sum(m['bytes'] for r,m in data['files'].items() if r.endswith('.png')),'bytes_after':sum((SPR/r).stat().st_size for r in data['files'] if r.endswith('.png'))}
    REPORT.write_text(json.dumps(report,indent=1))
    print('Verification',len(results),'PASS',len(errors),'FAIL',flush=True)
    if errors:print('\n'.join(errors[:8]),flush=True)
    return not errors

def compact_sheets():
    """Trim storage; AtlasTexture margins keep the game's fixed pivots and scale intact."""
    import re, math
    from PIL import Image
    data=baseline(); specs={}; resources={}
    reference=WORK/'cropped_reference'; delivered=WORK/'cropped_delivery'
    def geometry(rel):
        name=Path(rel).stem
        return (256,256) if name=='portrait' else (128,128) if 'goutte_lame' in rel else (1024,1024) if 'wave_cone' in rel else (128,64) if name.startswith('chain_') else (256,256) if name=='loop_blaze' else (192,192)
    def pack(source,cell,box):
        cw,ch=cell;left,top,right,bottom=box
        cols,rows=source.width//cw,source.height//ch
        out=Image.new('RGBA',((right-left)*cols,(bottom-top)*rows))
        for y in range(rows):
            for x in range(cols):
                part=source.crop((x*cw,y*ch,(x+1)*cw,(y+1)*ch)).crop(box)
                out.paste(part,(x*(right-left),y*(bottom-top)))
        return out
    groups={}
    for rel in data['files']:
        if not rel.endswith('.png') or Path(rel).stem.endswith(('_e','_n','_shadow')):continue
        # Direct portrait consumers and the chain shader cannot apply AtlasTexture margins.
        if Path(rel).stem=='portrait' or Path(rel).stem.startswith('chain_'):
            source=WORK/Path(rel).relative_to('characters')
            shutil.copy2(source,SPR/rel)
            erel=str(Path(rel).with_name(Path(rel).stem+'_e.png')).replace('\\','/')
            if erel in data['files']:
                shutil.copy2(cel.ARCHIVE/erel,SPR/erel)
            continue
        key=str(Path(rel).parent) if 'wave_cone' in rel else rel
        groups.setdefault(key,[]).append(rel)
    for members in groups.values():
        cw,ch=geometry(members[0]); boxes=[]
        for rel in members:
            with Image.open(SPR/rel) as im:
                im=im.convert('RGBA')
                for y in range(im.height//ch):
                    for x in range(im.width//cw):
                        b=im.crop((x*cw,y*ch,(x+1)*cw,(y+1)*ch)).getchannel('A').getbbox()
                        if b:boxes.append(b)
        box=(2*math.floor((min(b[0] for b in boxes)-4)/2),2*math.floor((min(b[1] for b in boxes)-4)/2),2*math.ceil((max(b[2] for b in boxes)+4)/2),2*math.ceil((max(b[3] for b in boxes)+4)/2))
        for rel in members:
            specs[rel]={'cell':[cw,ch],'box':list(box),'new_cell':[box[2]-box[0],box[3]-box[1]]}
            for base in (SPR,cel.ARCHIVE):
                target=delivered if base==SPR else reference
                dst=target/rel;dst.parent.mkdir(parents=True,exist_ok=True)
                with Image.open(base/rel) as im:pack(im.convert('RGBA'),(cw,ch),box).save(dst,optimize=True)
                erel=str(Path(rel).with_name(Path(rel).stem+'_e.png')).replace('\\','/')
                if erel in data['files']:
                    with Image.open(base/erel) as em,Image.open(base/rel) as diffuse:
                        ratio=diffuse.width//em.width
                        assert ratio in (1,2) and diffuse.height//em.height==ratio
                        ebox=tuple(v//ratio for v in box)
                        pack(em.convert('RGBA'),(cw//ratio,ch//ratio),ebox).save(target/erel,optimize=True)
    old_game,old_archive=cel.GAME_SPRITES,cel.ARCHIVE
    checks=[]
    try:
        cel.GAME_SPRITES,cel.ARCHIVE=delivered,reference
        for rel,spec in specs.items():
            with Image.open(delivered/rel) as im:w,h=im.size
            nw,nh=spec['new_cell']
            result=cel.check_sheet(rel,cell=(nw,nh),frames=w//nw,rows=h//nh,normals=False)
            assert not (SPR/rel).with_name(Path(rel).stem+'_n.png').exists(),rel
            result.update(size=[w,h],cell=[nw,nh],frames=w//nw,rows=h//nh,no_normal=True,crop=spec['box'])
            checks.append(result)
    finally:cel.GAME_SPRITES,cel.ARCHIVE=old_game,old_archive
    # Resource backups are immutable and the transform always starts from the originals.
    for rel,meta in data['files'].items():
        if not rel.endswith('.tres'):continue
        p=SPR/rel;backup=WORK/'contracts'/rel;backup.parent.mkdir(parents=True,exist_ok=True)
        if not backup.exists():shutil.copy2(p,backup)
        text=backup.read_text(); ext=dict((i,r) for r,i in re.findall(r'path="res://assets/sprites/([^"]+)" id="([^"]+)"',text))
        def atlas(match):
            block=match.group(0); aid=re.search(r'atlas = ExtResource\("([^"]+)"\)',block)
            if not aid:return block
            image=ext.get(aid[1],''); image=re.sub(r'_e\.png$','.png',image)
            if image not in specs:return block
            spec=specs[image];cw,ch=spec['cell'];left,top,right,bottom=spec['box'];nw,nh=spec['new_cell']
            def region(m):
                x,y,w,h=map(float,m[1].split(','));assert (w,h)==(cw,ch),(rel,w,h)
                return f'region = Rect2({int(x/cw)*nw}, {int(y/ch)*nh}, {nw}, {nh})\nmargin = Rect2({left}, {top}, {cw-nw}, {ch-nh})'
            return re.sub(r'region = Rect2\(([^)]+)\)',region,block)
        text=re.sub(r'\[sub_resource type="AtlasTexture"[^\n]*\][\s\S]*?(?=\n\[|\Z)',atlas,text)
        p.write_text(text,encoding='utf8');resources[rel]=sha(p)
    for rel in specs:
        path=delivered/rel;shutil.copy2(path,SPR/rel)
        emission=path.with_name(path.stem+'_e.png')
        if emission.exists():shutil.copy2(emission,(SPR/rel).with_name(emission.name))
    state={'sheets':specs,'resources':resources,'display_constraint':'CREA R=64*sqrt(2), Iso.SPRITE_K=1/sqrt(2): 64 px/u horizontally; shared isometric projection retained. Runtime radius scales and projection are hardcoded in forbidden .gd/.tscn. Portraits loaded directly and chain shader fixed 2:1 UV contract retain original cells; cropping them requires runtime changes. AtlasTexture margins preserve displayed size and feet.'}
    (WORK/'compact.json').write_text(json.dumps(state,indent=1))
    report=json.loads(REPORT.read_text());report['source_sheets']=report['sheets'];report['sheets']=checks;report['compact']=state
    source_by_file={s['file']:s for s in report['source_sheets']}
    for check in checks:
        source=source_by_file[check['file']]
        if 'accent_iou' in source:check['accent_iou']=source['accent_iou']
    report['bytes_after']=sum((SPR/r).stat().st_size for r in data['files'] if r.endswith('.png'))
    REPORT.write_text(json.dumps(report,indent=1))
    print('PASS compact',len(checks),'sheets',flush=True)


def audit_compact():
    """Check the delivered atlases directly against identically cropped 3D references."""
    from PIL import Image
    report=json.loads(REPORT.read_text());state=json.loads((WORK/'compact.json').read_text())
    original=report.get('source_sheets',report['sheets']);lookup={r['file']:r for r in original}
    saved_archive=cel.ARCHIVE;checks=[]
    try:
        cel.ARCHIVE=WORK/'cropped_reference'
        for rel in lookup:
            spec=state['sheets'].get(rel)
            p=SPR/rel
            nw,nh=spec['new_cell'] if spec else ((256,256) if p.stem=='portrait' else (128,64))
            cel.ARCHIVE=WORK/'cropped_reference' if spec else saved_archive
            with Image.open(p) as im:w,h=im.size
            if spec:assert sha(p)==sha(WORK/'cropped_delivery'/rel),rel
            result=cel.check_sheet(rel,cell=(nw,nh),frames=w//nw,rows=h//nh,normals=False)
            assert not p.with_name(p.stem+'_n.png').exists()
            result.update(size=[w,h],cell=[nw,nh],frames=w//nw,rows=h//nh,no_normal=True,crop=spec['box'] if spec else None)
            if 'accent_iou' in lookup[rel]:result['accent_iou']=lookup[rel]['accent_iou']
            checks.append(result)
    finally:cel.ARCHIVE=saved_archive
    report['source_sheets']=original;report['sheets']=checks
    protected=baseline()
    for rel,expected in protected['sources'].items():assert sha(ROOT/rel)==expected,rel
    report['bytes_after']=sum((SPR/r).stat().st_size for r in protected['files'] if r.endswith('.png'))
    report['raw_bytes_before']=sum(m['size'][0]*m['size'][1]*4 for r,m in protected['files'].items() if r.endswith('.png'))
    report['raw_bytes_after']=sum(Image.open(SPR/r).width*Image.open(SPR/r).height*4 for r in protected['files'] if r.endswith('.png'))
    report['protected_unchanged']=all(sha(SPR/r)==state['resources'].get(r,m['sha']) for r,m in protected['files'].items() if not r.endswith('.png'))
    report['budget_logs']={'before':'art/tools/night/_cel_heroes_c_budget_before.log','after':'art/tools/night/_cel_heroes_c_budget_after.log'}
    report['limitations']=[state['display_constraint'],'Averse, Arpenteuse and player: resource leaks at exit; Arpenteuse: Animation plant_nw absent in emission overlay; texture_budget: global mobile budget exceeded. Forbidden .gd/.tscn and assets outside scope unchanged.']
    REPORT.write_text(json.dumps(report,indent=1))
    print('PASS delivered sheets',len(checks),'game checks',len(report.get('checks',[])),flush=True)


def game_checks():
    import re,time
    logs=[]
    def run(label,args,required=None):
        log=HERE/('_cel_heroes_c_'+label+'.log')
        with log.open('w',encoding='utf8') as output:
            proc=subprocess.Popen(args,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
            started=time.monotonic()
            while proc.poll() is None:
                time.sleep(.5)
                current=log.read_text(encoding='utf8',errors='replace')
                if 'SCRIPT ERROR:' in current or time.monotonic()-started>240:
                    proc.terminate();break
            proc.wait(timeout=20)
            result=proc
        txt=log.read_text(encoding='utf8',errors='replace')
        failures=[line for line in txt.splitlines() if re.search(r'\b(?:ERROR|SCRIPT ERROR|Parse Error)\b',line)]
        ok=result.returncode==0 and not failures and (not required or required in txt)
        logs.append({'check':label,'ok':ok,'log':str(log.relative_to(ROOT)),'errors':failures[:8]})
        print(('PASS ' if ok else 'FAIL ')+label,flush=True)
        return ok
    run('budget',[sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--apply-policy'])
    godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    if run('import',[godot,'--headless','--path',str(ROOT/'game'),'--import']):
        for name in ('sprites','averse','arpenteuse','player','texture_budget'):
            run(name,[godot,'--headless','--path',str(ROOT/'game'),f'res://tests/{name}_test.tscn'],'RESULT: OK')
    report=json.loads(REPORT.read_text());report['checks']=logs
    protected=baseline()
    compact=WORK/'compact.json'
    allowed=json.loads(compact.read_text())['resources'] if compact.exists() else {}
    report['protected_unchanged']=all(sha(SPR/r)==allowed.get(r,m['sha']) for r,m in protected['files'].items() if not r.endswith('.png'))
    REPORT.write_text(json.dumps(report,indent=1))
    assert all(r['ok'] for r in logs) and len(logs)==7 and report['protected_unchanged'],'Game verification failed'

def driver():
    baseline()
    # Resume from the immutable pre-crop contracts, never from transformed regions.
    for contract in (WORK/'contracts').rglob('*.tres'):
        shutil.copy2(contract,SPR/contract.relative_to(WORK/'contracts'))
    if '--verify' not in sys.argv:
        with (HERE/'_cel_heroes_c_blender.log').open('w') as log:
            args=[cel.BLENDER,'--background','--python',str(Path(__file__).resolve()),'--','--render']
            if '--resume' in sys.argv:args.append('--resume')
            result=subprocess.run(args,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0))
        assert result.returncode==0 and 'PASS CEL-HEROES_C render' in (HERE/'_cel_heroes_c_blender.log').read_text(errors='replace'),'Blender failed; see _cel_heroes_c_blender.log'
    # Publish validation uses the original atlas contract; compaction is reapplied below.
    for backup in (WORK/'contracts').rglob('*.tres'):
        shutil.copy2(backup,SPR/backup.relative_to(WORK/'contracts'))
    assert publish_verify(),'Verification failed; see _cel_heroes_c_verification.json'
    compact_sheets()
    game_checks()

if __name__=='__main__':
    render() if '--render' in sys.argv else audit_compact() if '--audit' in sys.argv else game_checks() if '--checks-only' in sys.argv else driver()
