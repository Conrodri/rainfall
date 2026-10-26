"""R2A: replay original procedural rigs, display-sized cells, lossless union crop.
System Python: --prepare / --deliver / --test. Blender: --subject ID.
Immutable .blend sources are opened for validation; original build/pose functions
reconstruct their render rigs without saving or changing the source timelines.
"""
from pathlib import Path
import sys, json, re, math, hashlib, subprocess, shutil, importlib
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
WORK = ROOT / 'art/blender/cel/r2a'
IDS = dict(weaver='n2f_build', rain_sower='c8b_build', crystal_mother='c8c_build', crane='c9a_build', recluse='c8a_build')
sys.path[:0] = [str(HERE)] + [str(ROOT/'art/tools'/p) for p in ('cel','iso','monsters','bosses','')]
import cel_style as cel
def dump(p, v):
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(json.dumps(v, indent=2), encoding='utf-8')
def read(p): return json.loads(p.read_text(encoding='utf-8'))
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def folder(who): return ROOT/'game/assets/sprites/bosses/etage'/who
def source(who):
    return ROOT/('art/blender/monsters/' if who=='weaver' else 'art/blender/bosses/')/(who+'_iso.blend')
def specs(who, mod):
    for a, v in mod.SPECS.items():
        if who=='weaver':
            n, dirs, cell = v; cell=(cell,cell) if isinstance(cell,int) else cell
        else:
            n, cell, dirs = v[:3]
            if isinstance(dirs,int): dirs=('e','s','w','n') if dirs==4 else ('s',)
        yield a,n,tuple(cell),tuple(dirs)
def prepare():
    from PIL import Image
    if (WORK/'state.json').exists(): return
    data=read(ROOT/'game/data/fauna.json')['boss_sprites']
    state={}
    for who in IDS:
        cel.archive_folder('bosses/etage/'+who)
        dest=WORK/'original'/who; dest.mkdir(parents=True,exist_ok=True)
        images={}
        for p in folder(who).iterdir():
            if p.suffix in ('.png','.tres','.json'):
                shutil.copy2(p,dest/p.name)
            if p.suffix=='.png':
                images[p.name]={'size':list(Image.open(p).size),'bytes':p.stat().st_size}
        state[who]={'cfg':data[who], 'images':images,'source_sha':sha(source(who)),
                    'cell':2*round(256*(2.8*1.4*64/data[who]['dim'])/2)}
    dump(WORK/'state.json',state)
    budget('before')
    print('PASS prepare',flush=True)
def budget(tag):
    p=WORK/('budget_'+tag+'.json')
    with (WORK/('budget_'+tag+'.log')).open('w') as log:
        subprocess.run([sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--json',str(p)],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,check=True)
    d=read(p); rows=[r for r in d['rows'] if any('/bosses/etage/'+who+'/' in r['path'] for who in IDS)]
    dump(WORK/('scope_'+tag+'.json'),{k:sum(r[k] for r in rows) for k in ('vram','mobile','raw') if rows and k in rows[0]})
def render(who):
    import bpy
    sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
    sys.path.append(str(Path.home()/'AppData/Local/RainfallIsoDeps'))
    from PIL import Image
    from mathutils import Vector
    import numpy as np
    import boss_common as common
    import cel_bosses_f23_build as shared
    state=read(WORK/'state.json')[who]
    assert sha(source(who))==state['source_sha']
    bpy.ops.wm.open_mainfile(filepath=str(source(who)))
    cel.uninstall(); common.configure_passes=shared.no_normal_compositor
    mod=importlib.import_module(IDS[who])
    build=mod.build()
    root,pose=build[:2]
    bodyroot,bodypose=root,pose
    entries=list(specs(who,mod)); stage=WORK/'render'/who; stage.mkdir(parents=True,exist_ok=True)
    for a,n,oldcell,dirs in entries:
        marker=stage/(a+'.json')
        if marker.exists(): continue
        extra=a in mod.EXTRAS
        if extra:
            if who=='weaver':
                for ob in [bodyroot,*bodyroot.children_recursive]: ob.hide_render=True
                root,pose=mod.extra(a,build[2])
            else: root,pose=mod.extra(a)
        else: root,pose=bodyroot,bodypose
        s=bpy.context.scene
        w,h=(state['cell'],)*2 if not extra else oldcell
        s['iso_frame']=[w,h]; s.render.resolution_x=w*2; s.render.resolution_y=h*2
        s.render.resolution_percentage=100
        if who=='crane' and a in ('trans_p2','trans_p3','death'):
            # Delivered source transitions were rendered with --only, with the
            # original 5.15 camera rather than the previous attack's fitted lens.
            s.camera.data.ortho_scale=5.15
        # Preserve C9A's original gesture-wide camera fitting and contact correction.
        if who=='crane' and a in ('auto','spell_a','spell_b'):
            max_width=max_height=max_x=0.
            for d in ('e','s','w','n'):
                for i in range(n):
                    pose(a,i,n);root.rotation_euler.z=common.DIRECTIONS[d];bpy.context.view_layer.update()
                    points=[];inv=s.camera.matrix_world.inverted()
                    for ob in root.children_recursive:
                        if ob.type!='MESH' or ob.hide_render:continue
                        vertices=np.empty(len(ob.data.vertices)*3);ob.data.vertices.foreach_get('co',vertices)
                        matrix=np.array(inv@ob.matrix_world)
                        points.append(vertices.reshape(-1,3)@matrix[:3,:3].T+matrix[:3,3])
                    points=np.concatenate(points)
                    max_width=max(max_width,float(np.ptp(points[:,0])));max_height=max(max_height,float(np.ptp(points[:,1])));max_x=max(max_x,float(np.abs(points[:,0]).max()))
            s.camera.data.ortho_scale=max(5.15,max_width*256/200,max_height*256/200,max_x*256/119)
        # Same animated material preservation as the completed F23 bosses.
        pairs=shared.adapt_materials()
        cel.uninstall();common.configure_passes=shared.no_normal_compositor
        prof=dict(cel.profile('boss'),ink_px=0,creases=False) if who=='weaver' and a in mod.EXTRAS-{'cocoon'} else 'boss'
        cel.install(prof,normals=False)
        boards=[Image.new('RGBA',(w*n,h*len(dirs))) for _ in range(2)]
        raw=stage/'frames';raw.mkdir(exist_ok=True)
        for row,d in enumerate(dirs):
            for i in range(n):
                if who=='weaver':
                    if not extra:
                        s.camera.rotation_euler=(math.pi/3,0,0)
                        s.camera.data.ortho_scale=s.get('n2f_camera_scale',s.camera.data.ortho_scale);build[3](d)
                    pose(a.removesuffix('_dirs'),i,n)
                    if a=='drop' and i>=4:
                        bpy.context.view_layer.update();inv=s.camera.rotation_euler.to_matrix().transposed()
                        low=min((inv@(ob.matrix_world@v.co)).y for ob in root.children_recursive if ob.type=='MESH' and not ob.hide_render and ob.name.startswith('Tapered tibia') for v in ob.data.vertices)
                        target=(inv@s.camera.location).y-82/256*s.camera.data.ortho_scale
                        bpy.data.objects['Thorax'].location.z+=(target-low)/math.cos(math.pi/6)
                    if extra:build[4](.60+.15*math.sin(i/n*math.tau))
                    root.rotation_euler.z=common.DIRECTIONS[d]
                elif who=='crane' and extra:pose(i)
                else:
                    pose(a,i,n)
                    if not extra:root.rotation_euler.z=common.DIRECTIONS[d]
                if who=='crystal_mother' and not extra:mod.fit_hem(root)
                if who=='crane' and not extra:
                    from bpy_extras.object_utils import world_to_camera_view
                    bpy.context.view_layer.update()
                    feet=[o for o in root.children_recursive if o.type=='MESH' and not o.hide_render and ('Riveted track' in o.name or 'Crawler undercarriage /' in o.name or 'Four concrete-piercing' in o.name)]
                    low=min(world_to_camera_view(s,s.camera,o.matrix_world@v.co).y for o in feet for v in o.data.vertices)
                    delta=(215/256-(1-low))*s.camera.data.ortho_scale
                    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,delta,0))
                shared.sync_materials(pairs);bpy.context.view_layer.update()
                path=raw/'frame.png'
                # Original C8C no-normal-file render adapter, shared by this lot.
                adapter=importlib.import_module('c8c_build');adapter.render_frame(path)
                alpha=None
                for k,suffix in enumerate(('','_e')):
                    with Image.open(path.with_name('frame'+suffix+'.png')) as im:im=im.convert('RGBA')
                    if k==0:alpha=im.getchannel('A')
                    else:im.putalpha(alpha)
                    boards[k].paste(im,(i*w,row*h))
        for k,suffix in enumerate(('','_e')):boards[k].save(stage/(a+suffix+'.png'),compress_level=6)
        dump(marker,{'frames':n,'dirs':dirs,'cell':[w,h],'oldcell':oldcell,'extra':extra})
        replacements={p[1]:p[0] for p in pairs}
        for ob in s.objects:
            if ob.type in ('MESH','CURVE'):
                for slot in ob.material_slots:
                    if slot.material in replacements:slot.material=replacements[slot.material]
        for _,target,*_ in pairs:bpy.data.materials.remove(target)
        if who=='weaver' and extra:
            for ob in [root,*root.children_recursive]:ob.hide_render=True
        print('PASS render '+who+'/'+a,flush=True)
    assert sha(source(who))==state['source_sha']
def deliver():
    from PIL import Image
    import numpy as np
    from halve_emission import downscale
    state=read(WORK/'state.json');data_path=ROOT/'game/data/fauna.json';text=data_path.read_text(encoding='utf-8');report=read(WORK/'report.json') if (WORK/'report.json').exists() else {}
    selected=[sys.argv[sys.argv.index('--only-id')+1]] if '--only-id' in sys.argv else IDS
    for who in selected:
        original=WORK/'original'/who;stage=WORK/'render'/who;dst=folder(who)
        tres=(original/(who+'.tres')).read_text(encoding='utf-8')
        ext=dict(re.findall(r'path="[^"]*/([^/]+)\.png" id="([^"]+)"',tres))
        byid={v:k for k,v in ext.items()};crops={};physical={}
        for marker in stage.glob('*.json'):
            a=marker.stem;sp=read(marker);n=sp['frames'];rows=len(sp['dirs']);w,h=sp['cell'];ow,oh=sp['oldcell']
            im=Image.open(stage/(a+'.png')).convert('RGBA');bounds=[]
            for row in range(rows):
                for i in range(n):
                    bb=im.crop((i*w,row*h,(i+1)*w,(row+1)*h)).getchannel('A').getbbox()
                    if bb:bounds.append(bb)
            assert bounds,(who,a,'empty animation')
            box=[max(0,min(b[0] for b in bounds)-4),max(0,min(b[1] for b in bounds)-4),min(w,max(b[2] for b in bounds)+4),min(h,max(b[3] for b in bounds)+4)]
            # Even cell sizes preserve exact half-resolution emission grids.
            box[0]=box[0]//2*2;box[1]=box[1]//2*2;box[2]=min(w,2*math.ceil(box[2]/2));box[3]=min(h,2*math.ceil(box[3]/2))
            x,y,x1,y1=box;nw,nh=x1-x,y1-y
            cap=4096//ow
            glow=Image.open(stage/(a+'_e.png')).convert('RGBA')
            for part,start in enumerate(range(0,n,cap)):
                name=a if part==0 else a+'_'+str(part+1);count=min(cap,n-start)
                assert name+'.png' in state[who]['images'],(who,name,'unexpected file')
                assert count*nw<=4096 and rows*nh<=4096
                boards=[Image.new('RGBA',(count*nw,rows*nh)) for _ in range(2)]
                for row in range(rows):
                    for i in range(start,start+count):
                        for board,src in zip(boards,(im,glow)):
                            board.paste(src.crop((i*w+x,row*h+y,i*w+x1,row*h+y1)),((i-start)*nw,row*nh))
                boards[0].save(dst/(name+'.png'),compress_level=9)
                e=downscale(boards[1]);arr=np.asarray(e,dtype=float)
                lit=float((arr[:,:,:3].max(axis=2)*arr[:,:,3]/255).max())>2
                if lit:e.save(dst/(name+'_e.png'),compress_level=9)
                else:(dst/(name+'_e.png')).unlink(missing_ok=True)
                physical[name]={'oldcell':[ow,oh],'cell':[nw,nh],'virtual':[w,h],'crop':[x,y], 'count':count,'rows':rows}
            crops[a]={'cell':[nw,nh],'box':box,'frames':n,'rows':rows,'virtual':[w,h]}
        # AtlasTexture margins preserve centered logical canvas; offset/pivots
        # remain exact even when each animation uses a different physical crop.
        def atlas(match):
            block=match.group(0);ident=re.search(r'atlas = ExtResource\("([^"]+)"\)',block)
            if not ident:return block
            name=byid[ident[1]]
            if name not in physical:return block
            sp=physical[name];ow,oh=sp['oldcell'];nw,nh=sp['cell'];vw,vh=sp['virtual'];x,y=sp['crop']
            reg=re.search(r'region = Rect2\(([^)]+)\)',block);rx,ry,rw,rh=map(float,reg[1].split(','))
            assert (rw,rh)==(ow,oh),(who,name,'source atlas already cropped')
            region=f'region = Rect2({round(rx/ow)*nw}, {round(ry/oh)*nh}, {nw}, {nh})'
            block=block[:reg.start()]+region+block[reg.end():]
            block=re.sub(r'\nmargin = Rect2\([^\n]+\)','',block)
            return block.rstrip()+f'\nmargin = Rect2({x}, {y}, {vw-nw}, {vh-nh})\n\n'
        tres=re.sub(r'\[sub_resource type="AtlasTexture"[^\n]*\][\s\S]*?(?=\n\[|\Z)',atlas,tres)
        assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
        (dst/(who+'.tres')).write_text(tres,encoding='utf-8')
        cfg=state[who]['cfg'];cell=state[who]['cell'];factor=cell/256
        bottom=210.0 if who=='weaver' else cfg['bottom']
        # Only these data fields change: s=2.8*1.4*64/dim=1.0.
        pat=r'("'+who+r'": \{"dir": "etage/'+who+r'",[^\n]+)'
        def cfgline(m):
            line=m[1]
            for key,value in {'dim':2.8*1.4*64,'bottom':bottom*factor,'fh':float(cell)}.items():
                line=re.sub(r'"'+key+r'": [\d.]+','"'+key+'": '+str(round(value,8)),line)
            return line
        text,nsub=re.subn(pat,cfgline,text);assert nsub==1
        assert sha(source(who))==state[who]['source_sha']
        assert not list(dst.glob('*_n.png'))
        report[who]={'crops':crops,'body_runtime_scale':1.0,'feet':bottom*factor,'source_unchanged':True,
            'vfx_limitation':'Dynamic VFX scales/offsets are hardcoded in forbidden .gd files; original logical cells and scales preserved, physical cells union-cropped.'}
    data_path.write_text(text,encoding='utf-8')
    dump(WORK/'report.json',report)
    print('PASS deliver',flush=True)
def test():
    godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    commands=[('policy',[sys.executable,'art/tools/texture_budget.py','--apply-policy']),('import',[godot,'--headless','--path','game','--import'])]
    commands += [(a,[godot,'--headless','--path','game','res://tests/'+a+'.tscn']) for a in ['sprites_test','texture_budget_test']+[who+'_boss_test' for who in IDS]]
    result={}
    for label,cmd in commands:
        log=WORK/(label+'.log')
        try:
            with log.open('w',encoding='utf-8') as out:code=subprocess.run(cmd,cwd=ROOT,stdout=out,stderr=subprocess.STDOUT,timeout=420).returncode
        except subprocess.TimeoutExpired:code=-1
        content=log.read_text(encoding='utf-8',errors='replace')
        ok=code==0 and ('RESULT: OK' in content if label.endswith('_test') else not re.search(r'^(ERROR|SCRIPT ERROR)',content,re.M))
        result[label]={'ok':ok,'code':code};dump(WORK/'tests.json',result)
        print(('PASS ' if ok else 'FAIL ')+label,flush=True)
    budget('after')
    if not all(v['ok'] for v in result.values()):raise SystemExit(1)
def audit():
    from PIL import Image
    import numpy as np
    state=read(WORK/'state.json');report=read(WORK/'report.json')
    samples=[];checks=read(WORK/'audit.json') if (WORK/'audit.json').exists() else {}
    selected=[sys.argv[sys.argv.index('--only-id')+1]] if '--only-id' in sys.argv else IDS
    for who in selected:
        dst=folder(who);before=state[who]['images'];after={p.name for p in dst.glob('*.png')}
        diffuse={p for p in before if not p.endswith(('_e.png','_n.png'))}
        assert {p for p in after if not p.endswith('_e.png')}==diffuse,(who,'diffuse filenames')
        tres=(dst/(who+'.tres')).read_text(encoding='utf-8')
        original=(WORK/'original'/who/(who+'.tres')).read_text(encoding='utf-8')
        assert re.findall(r'"name": &"([^"]+)"',tres)==re.findall(r'"name": &"([^"]+)"',original)
        assert tres.count('"duration"')==original.count('"duration"')
        for name in diffuse:
            im=Image.open(dst/name).convert('RGBA');assert max(im.size)<=4096
            ep=dst/(Path(name).stem+'_e.png')
            if ep.exists():
                e=Image.open(ep).convert('RGBA');assert e.size==tuple((d+1)//2 for d in im.size)
                arr=np.asarray(e,dtype=float);assert (arr[:,:,:3].max(axis=2)*arr[:,:,3]/255).max()>2
        for a,sp in report[who]['crops'].items():
            cw,ch=sp['cell'];n=sp['frames'];rows=sp['rows'];empty=[]
            stage=WORK/'render'/who;spec=read(stage/(a+'.json'));ow,oh=spec['oldcell'];cap=4096//ow
            vw,vh=spec['cell'];sx,sy,ex,ey=sp['box'];iou=[]
            rendered=Image.open(stage/(a+'.png')).convert('RGBA')
            images={};old_images={}
            for part,start in enumerate(range(0,n,cap)):
                name=a if part==0 else a+'_'+str(part+1)
                images[name]=Image.open(dst/(name+'.png')).convert('RGBA')
                old_images[name]=Image.open(WORK/'original'/who/(name+'.png')).convert('RGBA')
            for row in range(rows):
                for i in range(n):
                    part=i//cap;name=a if part==0 else a+'_'+str(part+1)
                    im=images[name];actual=im.crop(((i%cap)*cw,row*ch,(i%cap+1)*cw,(row+1)*ch));bb=actual.getchannel('A').getbbox()
                    expected=rendered.crop((i*vw+sx,row*vh+sy,i*vw+ex,row*vh+ey))
                    assert np.array_equal(np.asarray(actual),np.asarray(expected)),(who,a,row,i,'crop changed pixels')
                    old=old_images[name].crop(((i%cap)*ow,row*oh,(i%cap+1)*ow,(row+1)*oh)).resize((vw,vh),Image.Resampling.LANCZOS)
                    oa=np.asarray(old)[:,:,3]>127;na=np.asarray(rendered.crop((i*vw,row*vh,(i+1)*vw,(row+1)*vh)))[:,:,3]>127
                    union=np.logical_or(oa,na).sum()
                    if union:iou.append(float(np.logical_and(oa,na).sum()/union))
                    if not bb:empty.append([row,i])
            # Intentional empty fade/impact frames retained from source animation.
            sp['empty_frames']=empty
            sp['source_alpha_iou_min']=min(iou) if iou else 1.0
        a='idle_p1';sp=report[who]['crops'][a];cw,ch=sp['cell'];vw,vh=sp['virtual'];x,y,*_=sp['box']
        new=Image.new('RGBA',(vw,vh));new.paste(Image.open(dst/(a+'.png')).crop((0,ch,cw,2*ch)),(x,y))
        old=Image.open(WORK/'original'/who/(a+'.png')).convert('RGBA').crop((0,256,256,512))
        factor=state[who]['cell']/256;old=old.resize((vw,vh),Image.Resampling.LANCZOS)
        samples.append((old,new))
        checks[who]={'diffuse':len(diffuse),'emission':len(after)-len(diffuse),'scale':1.0,'source_unchanged':sha(source(who))==state[who]['source_sha']}
    if '--only-id' in sys.argv:
        dump(WORK/'audit.json',checks);dump(WORK/'report.json',report)
        print('PASS audit '+selected[0],flush=True);return
    # One contact only: immutable baseline / delivered cel / Eclusier reference.
    eclusier=ROOT/'game/assets/sprites/bosses/etage/eclusier'
    tex=(eclusier/'eclusier.tres').read_text(encoding='utf-8')
    ext={v:k for k,v in re.findall(r'path="[^"]*/([^/]+)\.png" id="([^"]+)"',tex)}
    first=next(b for b in re.findall(r'\[sub_resource type="AtlasTexture"[^\n]*\][\s\S]*?(?=\n\[|\Z)',tex) if 'idle' in b)
    xywh=list(map(float,re.search(r'region = Rect2\(([^)]+)\)',first)[1].split(',')))
    ident=re.search(r'atlas = ExtResource\("([^"]+)"\)',first)[1];x,y,w,h=map(int,xywh)
    reference=Image.open(eclusier/(ext[ident]+'.png')).convert('RGBA').crop((x,y,x+w,y+h))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    board=Image.new('RGBA',(1200,len(samples)*400),(18,24,24,255))
    for row,pair in enumerate(samples):
        for col,im in enumerate((*pair,reference)):
            tile=Image.new('RGBA',(400,400),(18,24,24,255));g=ground.copy();g.thumbnail((400,220));tile.alpha_composite(g,((400-g.width)//2,400-g.height))
            tile.alpha_composite(im,((400-im.width)//2,380-im.height))
            board.alpha_composite(tile,(col*400,row*400))
    board.convert('RGB').save(WORK/'contact.png')
    dump(WORK/'audit.json',checks);dump(WORK/'report.json',report)
    print('PASS audit '+str(sum(c['diffuse'] for c in checks.values()))+' diffuse sheets',flush=True)
def summary():
    before=read(WORK/'scope_before.json');after=read(WORK/'scope_after.json')
    tests=read(WORK/'tests.json');checks=read(WORK/'audit.json');report=read(WORK/'report.json')
    final=WORK/'texture_budget_final_test.log'
    if final.exists():
        output=final.read_text(encoding='utf-8',errors='replace')
        tests['texture_budget_test']={'ok':'RESULT: OK' in output,'log':str(final.relative_to(ROOT))}
    data={'scope_before_bytes':before,'scope_after_bytes':after,'tests':tests,
          'diffuse_sheets':sum(v['diffuse'] for v in checks.values()),'global_budget_violations':read(WORK/'budget_after.json')['violations'],
          'alpha_iou_min':min(s['source_alpha_iou_min'] for k in IDS for s in report[k]['crops'].values()),
          'vfx_limitation':report['weaver']['vfx_limitation'],'source_blends_unchanged':all(checks[k]['source_unchanged'] for k in IDS),
          'contact':'art/blender/cel/r2a/contact.png','details':'art/blender/cel/r2a/report.json'}
    dump(WORK/'summary.json',data)
    for k in ('raw','vram','mobile'):print(f'{k}: {before[k]/1048576:.2f} -> {after[k]/1048576:.2f} MiB')
    print('RESULT: '+str({k:v['ok'] for k,v in tests.items()}))
if __name__=='__main__':
    if '--prepare' in sys.argv:prepare()
    elif '--deliver' in sys.argv:deliver()
    elif '--test' in sys.argv:test()
    elif '--audit' in sys.argv:audit()
    elif '--summary' in sys.argv:summary()
    elif '--subject' in sys.argv:render(sys.argv[sys.argv.index('--subject')+1])
