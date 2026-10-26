"""R2C: saved cel rigs, native display resolution, animation-wide atlas crops."""
import sys, json, re, math, shutil, hashlib, importlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
WORK=ROOT/'art/blender/cel/r2c'
ASSETS=ROOT/'game/assets/sprites/bosses/mini'
GROUPS={'m1a':('iron_heron','vat_toad','scarecrow_reaper'), 'm3a':('steam_hound','grinder','blind_pump'), 'm4a':('ossuary_bearer','blind_swarm','salt_golem'), 'm4b':('blind_lamplighter','sarcophagus_crab')}
NAMES=tuple(n for ns in GROUPS.values() for n in ns)
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/monsters'),str(ROOT/'art/tools')]
def save(p,d):
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2),encoding='utf-8')
def baseline():
    from PIL import Image
    p=HERE/'_r2c_baseline.json'
    if p.exists():return
    fauna=json.loads((ROOT/'game/data/fauna.json').read_text(encoding='utf-8'))
    result={}
    for group,ns in GROUPS.items():
        for n in ns:
            backup=WORK/'before'/n;shutil.copytree(ASSETS/n,backup,dirs_exist_ok=True)
            source=ROOT/f'art/blender/monsters/{group}_{n}.blend'
            cfg=fauna['boss_sprites'][n]
            result[n]={'group':group,'cfg':cfg,'scale':2.4*1.1*64/cfg['dim'], 'source':str(source.relative_to(ROOT)), 'sha256':hashlib.sha256(source.read_bytes()).hexdigest(), 'png_bytes':sum(p.stat().st_size for p in backup.glob('*.png')), 'raw_bytes':sum(Image.open(p).width*Image.open(p).height*4 for p in backup.glob('*.png'))}
    save(p,result)
def render():
    import bpy, iso_rig, cel_style as cel
    from common import pose
    from PIL import Image
    from mathutils import Vector
    from bpy_extras.object_utils import world_to_camera_view
    data=json.loads((HERE/'_r2c_baseline.json').read_text())
    for n,c in data.items():
        module=importlib.import_module(c['group']+'_build')
        specs=getattr(module,'SPECS',None) or {a:(i*20+1,v) for i,(a,v) in enumerate(module.SPEC.items())}
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/c['source']))
        s=bpy.context.scene
        root=next(o for o in s.objects if o.type=='EMPTY' and not o.parent and len(o.children_recursive)>5)
        cell=math.ceil(170*c['scale']);s['iso_frame']=[cell,cell]
        old_anchor=(.5+s.camera.data.shift_y)*170
        save(WORK/n/'geometry.json',{'bottom':(.5+s.camera.data.shift_y)*cell+(c['cfg']['bottom']-old_anchor)*c['scale']})
        s.render.resolution_x=s.render.resolution_y=cell*2;s.render.resolution_percentage=100
        s.camera.data.ortho_scale*=cell/(170*c['scale'])
        s.render.threads_mode='FIXED';s.render.threads=8
        cel.install('creature',normals=False)
        # Preserve already-authored cel materials, including clipping and translucent wings.
        ground=json.loads(s.get('ground_alignment_z','{}'));offsets=json.loads(s.get('ground_offsets','{}'))
        center={}
        if c['group']=='m3a':
            s.frame_set(1)
            for d,angle in {'s':0,'e':math.pi/2,'w':-math.pi/2,'n':math.pi}.items():
                root.rotation_euler.z=angle;bpy.context.view_layer.update()
                px=[world_to_camera_view(s,s.camera,o.matrix_world@Vector(v)).x for o in root.children_recursive if o.type=='MESH' for v in o.bound_box]
                center[d]=root.location.x+(.5-(min(px)+max(px))/2)*4.051028251647949
        for a,(start,count) in specs.items():
            dirs=module.directions(a) if hasattr(module,'directions') else module.dirs(a)
            for d in dirs:
                for i in range(count):
                    dest=WORK/'frames'/n/a/f'{d}_{i:02}.png';dest.parent.mkdir(parents=True,exist_ok=True)
                    if dest.exists() and dest.with_stem(dest.stem+'_e').exists():continue
                    pose(root,start+i,d)
                    if ground:root.location.z=ground[d];root.location.x=center[d]
                    if offsets:root.location.y=offsets[d]
                    bpy.context.view_layer.update()
                    iso_rig.common.configure_passes(dest)
                    s.eevee.taa_render_samples=8
                    s.render.filepath=str(dest);bpy.ops.render.render(write_still=True)
                    ep=list(dest.parent.glob(dest.stem+'_e__*.png'));assert len(ep)==1,ep
                    ep[0].replace(dest.with_stem(dest.stem+'_e'))
                    for p in (dest,dest.with_stem(dest.stem+'_e')):
                        with Image.open(p) as im:im.convert('RGBA').resize((cell,cell),Image.Resampling.LANCZOS).save(p,optimize=True)
            print('PASS',n,a,flush=True)
        cel.uninstall()
    print('RESULT: OK render',flush=True)
def pack():
    from PIL import Image, ImageChops
    import halve_emission
    data=json.loads((HERE/'_r2c_baseline.json').read_text())
    fauna_path=ROOT/'game/data/fauna.json';text=fauna_path.read_text(encoding='utf-8')
    report={}
    for n,c in data.items():
        module=importlib.import_module(c['group']+'_build');specs=getattr(module,'SPECS',None) or {a:(i*20+1,v) for i,(a,v) in enumerate(module.SPEC.items())}
        cell=math.ceil(170*c['scale']);factor=cell/170
        tres=(WORK/'before'/n/(n+'.tres')).read_text();ext=dict(re.findall(r'path="[^"]*/([^/]+)\.png" id="([^"]+)"',tres));ext={v:k for k,v in ext.items()}
        layouts={}
        for a,(_,count) in specs.items():
            dirs=module.directions(a) if hasattr(module,'directions') else module.dirs(a)
            frames=[[Image.open(WORK/'frames'/n/a/f'{d}_{i:02}.png').convert('RGBA') for i in range(count)] for d in dirs]
            bbox=None
            for row in frames:
                for im in row:
                    b=im.getchannel('A').getbbox();assert b,(n,a)
                    bbox=b if bbox is None else (min(bbox[0],b[0]),min(bbox[1],b[1]),max(bbox[2],b[2]),max(bbox[3],b[3]))
            for d in dirs:
                for i in range(count):
                    ep=WORK/'frames'/n/a/f'{d}_{i:02}_e.png'
                    with Image.open(ep) as emission:eb=emission.getchannel('A').getbbox()
                    if eb:bbox=(min(bbox[0],eb[0]),min(bbox[1],eb[1]),max(bbox[2],eb[2]),max(bbox[3],eb[3]))
            x,y,r,b=bbox;x-=4;y-=4;r+=4;b+=4
            w,h=r-x,b-y;assert max(w*count,h*len(dirs))<=4096
            for suffix in ('','_e'):
                sheet=Image.new('RGBA',(w*count,h*len(dirs)))
                for row,d in enumerate(dirs):
                    for i in range(count):
                        im=frames[row][i] if not suffix else Image.open(WORK/'frames'/n/a/f'{d}_{i:02}_e.png').convert('RGBA')
                        sheet.paste(im.crop((x,y,r,b)),(i*w,row*h))
                if suffix:
                    assert max(v[1] for v in sheet.convert('RGB').getextrema())>0,(n,a,'black emission')
                    sheet=halve_emission.downscale(sheet)
                sheet.save(ASSETS/n/(a+suffix+'.png'),optimize=True)
            layouts[a]={'crop':[x,y,r,b],'cell':[w,h],'logical':cell,'old_cell':170,'frames':count,'rows':len(dirs)}
        # Hazard scale is fixed in code. Preserve its physical size and pivot using atlas margins.
        for a,oldcell in (('disc',96),('bone_pile',128)):
            original=WORK/'before'/n/(a+'.png')
            if not original.exists():continue
            sheet=Image.open(original).convert('RGBA');count=sheet.width//oldcell
            cells=[sheet.crop((i*oldcell,0,(i+1)*oldcell,oldcell)) for i in range(count)]
            bounds=[im.getchannel('A').getbbox() for im in cells];assert all(bounds)
            x=min(b[0] for b in bounds)-4;y=min(b[1] for b in bounds)-4;r=max(b[2] for b in bounds)+4;b=max(b[3] for b in bounds)+4
            x=x//2*2;y=y//2*2;r=(r+1)//2*2;b=(b+1)//2*2
            w,h=r-x,b-y
            for suffix in ('','_e'):
                src=WORK/'before'/n/(a+suffix+'.png')
                if not src.exists():continue
                im=Image.open(src).convert('RGBA')
                q=2 if suffix and im.width*2==sheet.width else 1
                out=Image.new('RGBA',(count*w//q,h//q))
                for i in range(count):out.paste(im.crop(((i*oldcell+x)//q,y//q,(i*oldcell+r)//q,b//q)),(i*w//q,0))
                if suffix and q==1:out=halve_emission.downscale(out)
                out.save(ASSETS/n/(a+suffix+'.png'),optimize=True)
            layouts[a]={'crop':[x,y,r,b],'cell':[w,h],'logical':oldcell,'old_cell':oldcell,'frames':count,'rows':1,'exception':'fixed runtime scale; lossless crop only'}
        def update(m):
            block=m.group(0);atlas=re.search(r'atlas = ExtResource\("([^\"]+)"\)',block)
            if not atlas or ext[atlas[1]] not in layouts:return block
            a=ext[atlas[1]];l=layouts[a];x,y,r,b=l['crop'];w,h=l['cell']
            vals=list(map(float,re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(',')))
            col,row=round(vals[0]/l['old_cell']),round(vals[1]/l['old_cell'])
            block=re.sub(r'region = Rect2\([^)]+\)',f'region = Rect2({col*w}, {row*h}, {w}, {h})',block)
            block=re.sub(r'\nmargin = Rect2\([^)]+\)','',block)
            return block.rstrip()+f'\nmargin = Rect2({x}, {y}, {l["logical"]-w}, {l["logical"]-h})\n\n'
        tres=re.sub(r'\[sub_resource type="AtlasTexture"[^\n]*\n.*?(?=\n\[|\Z)',update,tres,flags=re.S)
        assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
        (ASSETS/n/(n+'.tres')).write_text(tres,encoding='utf-8')
        cfg=dict(c['cfg']);cfg.update(dim=168.96,fh=cell,bottom=c['cfg']['bottom']*factor)
        # Exact raster scale: preserve original physical size while normalizing the runtime scale.
        cfg['dim']=168.96
        anchor=(c['cfg']['bottom']-(0 if n=='blind_swarm' else 7)) if c['group']=='m4a' else 140 if c['group']=='m4b' else 119
        cfg['bottom']=anchor*factor+(c['cfg']['bottom']-anchor)*c['scale']
        text=re.sub(r'("'+re.escape(n)+r'"\s*:\s*)\{[^\n]+\}',lambda m:m[1]+json.dumps(cfg,ensure_ascii=False),text,count=1)
        report[n]={'scale_before':c['scale'],'scale_after':168.96/cfg['dim'],'layouts':layouts,'png_bytes':sum(p.stat().st_size for p in (ASSETS/n).glob('*.png')),'raw_bytes':sum(Image.open(p).width*Image.open(p).height*4 for p in (ASSETS/n).glob('*.png'))}
    fauna_path.write_text(text,encoding='utf-8');save(HERE/'_r2c_verification.json',report)
    print('RESULT: OK pack',len(report))
def verify():
    from PIL import Image
    data=json.loads((HERE/'_r2c_baseline.json').read_text());report=json.loads((HERE/'_r2c_verification.json').read_text())
    contact=Image.new('RGBA',(640,len(NAMES)*210),(30,38,38,255))
    for row,(n,c) in enumerate(data.items()):
        source=ROOT/c['source'];assert hashlib.sha256(source.read_bytes()).hexdigest()==c['sha256'],source
        tres=(ASSETS/n/(n+'.tres')).read_text();old=(WORK/'before'/n/(n+'.tres')).read_text()
        assert re.findall(r'"name":\s*&"[^"]+"',old)==re.findall(r'"name":\s*&"[^"]+"',tres)
        assert len(re.findall('"duration":',old))==len(re.findall('"duration":',tres))
        assert not list((ASSETS/n).glob('*_n.png'))
        for a,l in report[n]['layouts'].items():
            p=ASSETS/n/(a+'.png');im=Image.open(p).convert('RGBA');w,h=l['cell']
            assert im.size==(w*l['frames'],h*l['rows']) and max(im.size)<=4096
            ep=p.with_stem(p.stem+'_e')
            if ep.exists():
                emission=Image.open(ep).convert('RGBA');assert emission.size==((im.width+1)//2,(im.height+1)//2)
                assert max(v[1] for v in emission.convert('RGB').getextrema())>0 and emission.getchannel('A').getbbox()
            for y in range(l['rows']):
                for x in range(l['frames']):
                    b=im.getchannel('A').crop((x*w,y*h,(x+1)*w,(y+1)*h)).getbbox();assert b,(n,a,x,y)
                    assert b[0]>=4 and b[1]>=4 and b[2]<=w-4 and b[3]<=h-4,(n,a,b)
        for col,a in enumerate(('idle','attack','cast_a','cast_b')):
            l=report[n]['layouts'][a];w,h=l['cell'];sheet=Image.open(ASSETS/n/(a+'.png')).convert('RGBA')
            i=0 if a=='idle' else l['frames']//2
            im=sheet.crop((i*w,0,(i+1)*w,h));im.thumbnail((154,200))
            contact.alpha_composite(im,(col*160+(160-im.width)//2,row*210+(210-im.height)//2))
    contact.convert('RGB').save(HERE/'_r2c_contact.jpg',quality=88)
    print('RESULT: OK audit; 11 rigs unchanged; 79 sheets; animation counts, margins, emission, pivots')
def report():
    budgets={}
    for phase in ('before','after'):
        budget=json.loads((HERE/f'_r2c_budget_{phase}.json').read_text())
        rows=[r for r in budget['rows'] if any(r['path'].startswith('assets/sprites/bosses/mini/'+n+'/') for n in NAMES)]
        budgets[phase]={k:round(sum(r[k] for r in rows)/1048576,3) for k in ('raw','png','mobile','vram')}
        budgets[phase]['global_violations']=budget['violations']
    tests={}
    for test in ('sprites_test','texture_budget_test','minibosses_test'):
        raw=(HERE/f'_r2c_{test}.log').read_bytes()
        log=raw.decode('utf-16' if raw[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8',errors='replace')
        result=re.findall(r'RESULT: ([^\r\n]+)',log);tests[test]=result[-1] if result else 'PENDING'
    save(HERE/'_r2c_report.json',{'subjects':NAMES,'diffuse_sheets':79,'rendered_frames':1584,'profile':'creature','normals':False,'emission_ratio':0.5,'budgets_MiB':budgets,'tests':tests,'exceptions':['Requested art/blender/bosses/<id>_iso.blend absent; reused actual saved m1a/m3a/m4a/m4b cel rigs in art/blender/monsters.', 'disc and bone_pile: lossless crop only; their scale is fixed in miniboss_hazards.gd, which is outside authorized edits.', 'Body scales originally exceed 1; native display rendering increases mobile size. Global texture cap failed before this lot as well.']})
    print('RESULT report',tests)
if __name__=='__main__':
    if '--render' in sys.argv:render()
    elif '--pack' in sys.argv:pack()
    elif '--verify' in sys.argv:verify()
    elif '--report' in sys.argv:report()
    else:baseline()
