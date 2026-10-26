"""R2B: original source timelines, shared cel, cropped physical atlases.
System: --prepare / --deliver / --verify. Blender: --render [--subject ID].
"""
from pathlib import Path
import sys, json, re, shutil, hashlib, importlib, math
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
WORK=ROOT/'art/blender/cel/r2b'
IDS={'ox_herder':'n1c','smelter':'c9b','jar_bearer':'n1d','hermit_cedar':'n2d','deep_eel':'c8d'}
sys.path[:0]=[str(HERE),str(ROOT/'art/tools/cel'),str(ROOT/'art/tools')]
if '--background' in sys.argv:sys.path.insert(0,str(ROOT/'art/tools/iso/_deps'))
import cel_style as cel
def dst(n):return ROOT/'game/assets/sprites/bosses/etage'/n
def dump(p,v):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(v,indent=2),encoding='utf-8')
def state():return json.loads((WORK/'state.json').read_text())
def budget():
    import texture_budget as tb
    walk=tb.os.walk
    try:
        tb.os.walk=lambda _: (row for n in IDS for row in walk(dst(n)))
        rows=tb.scan()
    finally:tb.os.walk=walk
    return dict(n=len(rows),**{k:sum(r[k] for r in rows) for k in ('raw','vram','png','mobile')})
def prepare():
    from PIL import Image
    if (WORK/'state.json').exists():print('PASS prepared');return
    fauna=json.loads((ROOT/'game/data/fauna.json').read_text(encoding='utf-8'))
    st={'before':budget(),'subjects':{}}
    for n in IDS:
        cel.archive_folder('bosses/etage/'+n)
        old=WORK/'before'/n;old.mkdir(parents=True,exist_ok=True)
        for p in dst(n).iterdir():
            if p.suffix in ('.png','.tres','.json'):shutil.copy2(p,old/p.name)
        text=(old/(n+'.tres')).read_text()
        ext=dict(re.findall(r'path="[^"]*/([^/]+)\.png" id="([^"]+)"',text))
        sheets={}
        for stem,eid in ext.items():
            m=re.search(r'atlas = ExtResource\("'+re.escape(eid)+r'"\)\s*region = Rect2\(([^)]+)\)',text)
            assert m,stem
            x,y,w,h=map(int,m[1].split(','))
            im=Image.open(old/(stem+'.png'))
            sheets[stem]={'oldcell':[w,h],'cols':im.width//w,'rows':im.height//h,'ext':eid}
        cfg=fauna['boss_sprites'][n]
        source=ROOT/'art/blender/bosses'/(n+'_iso.blend')
        if not source.exists():source=ROOT/'art/blender/monsters'/(n+'_iso.blend')
        st['subjects'][n]={'cfg':cfg,'sheets':sheets,'source':str(source),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest()}
    dump(WORK/'state.json',st)
    print('PASS baseline',st['before'])
def specs(base,n):
    result={}
    for a,v in base.SPECS.items():
        if n=='ox_herder':nf,rows,w,h,_=v;dirs=('e','s','w','n') if rows==4 else ('s',)
        elif n=='jar_bearer':nf,w,rows=v;h=w;dirs=('e','s','w','n') if rows==4 else ('s',)
        elif n=='smelter':nf,dirs,(w,h),_=v
        elif n=='deep_eel':nf,(w,h),dirs,_=v
        else:
            nf,dirs,size=v;w,h=base.dims(size)
        result[a]=(nf,dirs,w,h)
    return result
def render():
    import bpy
    from PIL import Image
    from mathutils import Vector
    from types import SimpleNamespace
    st=state()
    selected=sys.argv[sys.argv.index('--subject')+1] if '--subject' in sys.argv else None
    for n,lot in IDS.items():
        if selected and selected!=n:continue
        base=importlib.import_module(lot+'_build')
        if n=='smelter':base.EXTRAS={'molten_pool','splash','molten_arc'}
        sp=specs(base,n)
        subjects=st['subjects'][n];out=WORK/'render'/n;out.mkdir(parents=True,exist_ok=True)
        for a,(nf,dirs,w,h) in sp.items():
            marker=out/(a+'.done')
            if marker.exists():continue
            if n=='deep_eel' and a=='wake':
                marker.write_text('existing C8E cel');continue
            # Hermit extras already have the exact N2G cel treatment; crop them unchanged.
            if n=='hermit_cedar' and a in base.EXTRAS:
                marker.write_text('existing N2G cel');continue
            cel.uninstall()
            if a not in base.EXTRAS:
                bpy.ops.wm.open_mainfile(filepath=subjects['source'])
                s=bpy.context.scene
                root=bpy.data.objects[{'ox_herder':'OX_HERDER','jar_bearer':'JAR_BEARER_N1D','deep_eel':'DEEP_EEL_3_8U','hermit_cedar':'HERMIT_CEDAR_N2D','smelter':'LE FONDEUR - 3.5u'}[n]]
                # These sources key the root too. Rendering re-evaluates its yaw;
                # directions belong to the renderer, while the root stays at rest.
                if n in ('smelter','hermit_cedar'):root.animation_data_clear()
                anim=a.removesuffix('_dirs')
                starts={m.name:m.frame for m in s.timeline_markers}
                assert anim in starts,(n,anim,list(starts))
                if n=='deep_eel':
                    # P2 adds nerve branches: topology changes, so saved shape keys
                    # cannot reproduce it. Replay the authored C8D mesh recipe.
                    root,eelpose=base.build();s=bpy.context.scene
                camera_base=s.camera.location.copy()
                ratio=2.8*1.4*64/subjects['cfg']['dim']
                size=(round(w*ratio),round(h*ratio))
                if n=='hermit_cedar':
                    for mat in bpy.data.materials:
                        if mat.name.startswith(('Cedar heartwood','Bleached fibrous','Dead moss')):
                            for node in mat.node_tree.nodes if mat.use_nodes else ():
                                if node.type=='VALTORGB':
                                    for el in node.color_ramp.elements:el.color=tuple(min(.72,v*1.28) for v in el.color[:3])+(el.color[3],)
            else:
                # Reuse the authored extra constructors and their deterministic animation functions.
                if n in ('jar_bearer','hermit_cedar'):built=base.build()
                if n=='jar_bearer':
                    for ob in [built[0],*built[0].children_recursive]:ob.hide_render=True
                if n=='hermit_cedar':root,pose=base.extra(a,built[2])
                else:root,pose=base.extra(a)
                s=bpy.context.scene;size=(w,h);ratio=1
            import boss_common as common
            from cel_bosses_f23_build import no_normal_compositor
            common.configure_passes=no_normal_compositor
            cel.install('boss',normals=False)
            s['iso_frame']=list(size)
            s.render.resolution_x=size[0]*2;s.render.resolution_y=size[1]*2;s.render.resolution_percentage=100
            tmp=out/'frame.png'
            pages=[]
            for stem,v in subjects['sheets'].items():
                if stem==a or (stem.startswith(a+'_') and stem[len(a)+1:].isdigit()):pages.append((stem,v))
            assert pages,(n,a)
            start=0
            for stem,v in pages:
                boards=[Image.new('RGBA',(size[0]*v['cols'],size[1]*v['rows'])) for _ in range(2)]
                for row,d in enumerate(dirs):
                    for j in range(v['cols']):
                        i=start+j
                        if a not in base.EXTRAS:
                            if n=='deep_eel':eelpose(a,i,nf)
                            else:s.frame_set(starts[anim]+i)
                            root.rotation_euler.z=common.DIRECTIONS[d]
                            if n=='ox_herder':
                                s.camera.location=s.camera.rotation_euler.to_matrix()@Vector((0,82*5.5/256-{'s':.955,'e':.67,'w':.67,'n':1.295}[d]*.5,12))
                            elif n in ('jar_bearer','smelter'):
                                corr=({'e':-6,'s':0,'w':-6,'n':7} if n=='jar_bearer' else {'e':-5,'s':0,'w':-5,'n':8})[d]
                                s.camera.location=camera_base+s.camera.rotation_euler.to_matrix()@Vector((0,corr*s.camera.data.ortho_scale/256,0))
                            elif n=='deep_eel':
                                base.fit_body(root,eelpose)
                            if n=='smelter':
                                # The source stores object keys; the recipe also animates
                                # sodium material strengths, which are not keyed in the blend.
                                phase=int(a[-1]) if a[-2:-1]=='p' else 1
                                if a=='trans_p2':phase=2
                                if a in ('trans_p3','death'):phase=3
                                wave=math.sin(i/nf*math.tau);q=i/(nf-1)
                                power=(1.5,3,12)[phase-1]*(1+.08*wave)
                                if a=='death':power=12*(1-q)**3
                                for mat in bpy.data.materials:
                                    if mat.name.startswith('SODIUM FF9A3C'):value=power
                                    elif mat.name.startswith('Sodium incandescence'):value=.22*(1+.15*wave)*(max(0,1-q) if a=='death' else 1)
                                    else:continue
                                    for node in mat.node_tree.nodes:
                                        if node.type=='EMISSION':node.inputs['Strength'].default_value=value
                                        if node.type=='OUTPUT_AOV':node.inputs['Color'].default_value=(value,value*.323,value*.045,1)
                        else:
                            if n=='ox_herder':pose(i/nf)
                            elif n=='jar_bearer':pose(i,nf)
                            elif n=='smelter':pose(a,i,nf)
                            else:pose(a,i,nf)
                            root.rotation_euler.z=common.DIRECTIONS[d or 's']
                        bpy.context.view_layer.update()
                        if n=='deep_eel':base.render_frame(tmp)
                        else:
                            common.configure_passes(tmp);s.render.filepath=str(tmp);bpy.ops.render.render(write_still=True)
                            for p in out.glob('frame_e__*.png'):p.replace(out/'frame_e.png')
                        for k,suffix in enumerate(('','_e')):
                            with Image.open(out/('frame'+suffix+'.png')) as src:im=src.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
                            if k==0:
                                alpha=im.getchannel('A')
                                if n=='deep_eel' and a not in base.EXTRAS:
                                    import numpy as np
                                    yy=np.where(np.asarray(alpha)>128)[0]
                                    shift=round(210*ratio)-int(yy.max())
                                else:shift=0
                            else:im.putalpha(alpha)
                            cell=Image.new('RGBA',size);cell.paste(im,(0,shift));boards[k].paste(cell,(j*size[0],row*size[1]))
                for board,suffix in zip(boards,('','_e')):board.save(out/(stem+suffix+'.png'),compress_level=6)
                start+=v['cols']
            marker.write_text(json.dumps({'size':size,'ratio':ratio}))
            print('PASS rendered',n,a,flush=True)
    print('PASS R2B render',flush=True)

def crop_atlas(im,box,cell,cols,rows):
    from PIL import Image
    x,y,x1,y1=box;w,h=x1-x,y1-y;cw,ch=cell
    out=Image.new('RGBA',(w*cols,h*rows))
    for r in range(rows):
        for c in range(cols):out.paste(im.crop((c*cw,r*ch,(c+1)*cw,(r+1)*ch)).crop(box),(c*w,r*h))
    return out

def deliver():
    from PIL import Image
    import numpy as np
    from halve_emission import downscale
    st=state();report={'before':st['before'],'subjects':{}}
    for n,lot in IDS.items():
        old=WORK/'before'/n;rendered=WORK/'render'/n
        # Specs are literal assignments, usable without importing Blender-only builders.
        import ast
        module=ast.parse((HERE/(lot+'_build.py')).read_text(encoding='utf-8'))
        ns={}
        for node in module.body:
            if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SPECS' for t in node.targets):
                exec(compile(ast.Module(body=[node],type_ignores=[]),'<specs>','exec'),ns)
        base=type('Specs',(),{'SPECS':ns['SPECS'],'dims':staticmethod(lambda x:(x,x) if isinstance(x,int) else x)})
        sp=specs(base,n);subject=st['subjects'][n];text=(old/(n+'.tres')).read_text()
        results={}
        for a,(nf,dirs,ow,oh) in sp.items():
            marker=rendered/(a+'.done');assert marker.exists(),(n,a,'incomplete')
            body=(ow,oh)==(256,256) and (a.startswith(('idle','walk','auto','spell','trans','death','bogged')))
            ratio=2.8*1.4*64/subject['cfg']['dim'] if body else 1
            cw,ch=(round(ow*ratio),round(oh*ratio))
            pages=[(stem,v) for stem,v in subject['sheets'].items() if stem==a or (stem.startswith(a+'_') and stem[len(a)+1:].isdigit())]
            boards={};boxes=[]
            for stem,v in pages:
                path=rendered/(stem+'.png') if (rendered/(stem+'.png')).exists() else old/(stem+'.png')
                im=Image.open(path).convert('RGBA');assert im.size==(cw*v['cols'],ch*v['rows']),(n,stem,im.size,(cw,ch))
                if n=='deep_eel' and body:
                    # C8D aligns each 256px frame to integer y210 after rendering.
                    # At the new density, match that archived subpixel placement
                    # by assembly translations only (no painted/shaded pixels).
                    ref=Image.open(old/(stem+'.png')).convert('RGBA').resize(im.size,Image.Resampling.LANCZOS)
                    aligned=Image.new('RGBA',im.size)
                    for r in range(v['rows']):
                        for c in range(v['cols']):
                            bounds=(c*cw,r*ch,(c+1)*cw,(r+1)*ch)
                            frame=im.crop(bounds);mask=np.asarray(frame)[:,:,3]>128;target=np.asarray(ref.crop(bounds))[:,:,3]>128
                            options=[]
                            for dy in range(-2,3):
                                for dx in range(-2,3):
                                    moved=np.roll(mask,(dy,dx),axis=(0,1));score=(moved&target).sum()/max(1,(moved|target).sum())
                                    options.append((score,-abs(dx)-abs(dy),dx,dy))
                            _,_,dx,dy=max(options);cell=Image.new('RGBA',(cw,ch));cell.paste(frame,(dx,dy));aligned.paste(cell,(c*cw,r*ch))
                    im=aligned
                boards[stem]=im
                for r in range(v['rows']):
                    for c in range(v['cols']):
                        bb=im.crop((c*cw,r*ch,(c+1)*cw,(r+1)*ch)).getchannel('A').getbbox()
                        if bb:boxes.append(bb)
            assert boxes,(n,a)
            # Pad clipped source cells too. Negative AtlasTexture margins retain
            # their original virtual dimensions/pivot while adding transparent ink clearance.
            box=((min(b[0] for b in boxes)-4)//2*2,(min(b[1] for b in boxes)-4)//2*2,
                 math.ceil((max(b[2] for b in boxes)+4)/2)*2,math.ceil((max(b[3] for b in boxes)+4)/2)*2)
            x,y,x1,y1=box;w,h=x1-x,y1-y
            # Even physical cells keep half-resolution emission atlas coordinates exact.
            if w%2:x1-=1;w-=1
            if h%2:y1-=1;h-=1
            box=(x,y,x1,y1)
            for stem,v in pages:
                im=crop_atlas(boards[stem],box,(cw,ch),v['cols'],v['rows'])
                assert max(im.size)<=4096,(n,stem,im.size)
                im.save(dst(n)/(stem+'.png'),compress_level=9)
                ep=dst(n)/(stem+'_e.png')
                # Retain the authored accent mask; preserve existing half-resolution pixels
                # exactly when the virtual frame is unchanged.
                if (old/ep.name).exists():
                    emission=Image.open(old/ep.name).convert('RGBA')
                    if ratio==1 and emission.size==(ow*v['cols']//2,oh*v['rows']//2):
                        emission=crop_atlas(emission,tuple(q//2 for q in box),(ow//2,oh//2),v['cols'],v['rows'])
                    else:
                        emission=emission.resize((cw*v['cols'],ch*v['rows']),Image.Resampling.LANCZOS)
                        emission=downscale(crop_atlas(emission,box,(cw,ch),v['cols'],v['rows']))
                    data=np.asarray(emission)
                    assert (data[:,:,:3].max(2).astype(float)*data[:,:,3]/255).max()>2,(n,stem,'black emission')
                    assert emission.size==((im.width+1)//2,(im.height+1)//2)
                    emission.save(ep,compress_level=9)
                else:ep.unlink(missing_ok=True)
                pattern=r'(\[sub_resource type="AtlasTexture"[^\]]*\]\s*atlas = ExtResource\("'+re.escape(v['ext'])+r'"\)\s*)region = Rect2\(([^)]+)\)(?:\s*margin = Rect2\([^)]+\))?'
                def replace(m):
                    rx,ry,rw,rh=map(int,m[2].split(','));assert (rw,rh)==tuple(v['oldcell'])
                    return m[1]+f'region = Rect2({rx//rw*w}, {ry//rh*h}, {w}, {h})\nmargin = Rect2({x}, {y}, {cw-w}, {ch-h})'
                text,count=re.subn(pattern,replace,text);assert count,(n,stem,'atlas')
                results[stem]={'cell':[w,h],'virtual':[cw,ch],'box':box,'cols':v['cols'],'rows':v['rows'],'ratio':ratio,'body':body}
        (dst(n)/(n+'.tres')).write_text(text,encoding='utf-8')
        report['subjects'][n]=results
    # Target the existing entries without reformatting unrelated fauna data.
    fp=ROOT/'game/data/fauna.json';text=fp.read_text(encoding='utf-8')
    for n,subject in st['subjects'].items():
        cfg=subject['cfg'];ratio=2.8*1.4*64/cfg['dim']
        pat=r'("'+n+r'"\s*:\s*\{[^{}]*?)(?=\n|\})'
        def update(m):
            s=m[1]
            for key,val in [('dim',250.88),('bottom',cfg['bottom']*ratio),('fh',round(256*ratio))]:
                s,c=re.subn(r'("'+key+r'"\s*:\s*)[\d.]+',lambda q:q[1]+str(round(val,6)),s);assert c,(n,key)
            return s
        text,c=re.subn(pat,update,text,count=1);assert c,n
    fp.write_text(text,encoding='utf-8')
    report['after']=budget();dump(WORK/'report.json',report)
    print('PASS delivered',report['after'])

def verify():
    from PIL import Image
    import numpy as np
    report=json.loads((WORK/'report.json').read_text());st=state()
    count=0;frames=0;ious=[]
    for n,sheets in report['subjects'].items():
        assert hashlib.sha256(Path(st['subjects'][n]['source']).read_bytes()).hexdigest()==st['subjects'][n]['source_sha256'],n+' source changed'
        assert not list(dst(n).glob('*_n.png'))
        assert not re.search('CanvasTexture|normal_texture',(dst(n)/(n+'.tres')).read_text())
        assert {p.name for p in dst(n).glob('*.png')}=={p.name for p in (WORK/'before'/n).glob('*.png')},n+' filenames'
        for stem,v in sheets.items():
            im=Image.open(dst(n)/(stem+'.png')).convert('RGBA');w,h=v['cell']
            assert im.size==(w*v['cols'],h*v['rows']) and max(im.size)<=4096
            for r in range(v['rows']):
                hashes=[]
                for c in range(v['cols']):
                    frame=im.crop((c*w,r*h,(c+1)*w,(r+1)*h));bb=frame.getchannel('A').getbbox();assert bb,(n,stem,r,c,'empty')
                    assert min(bb[0],bb[1],w-bb[2],h-bb[3])>=4,(n,stem,r,c,'margin <4')
                    hashes.append(hashlib.sha256(frame.tobytes()).hexdigest());frames+=1
                if len(hashes)>1:assert len(set(hashes))>1,(n,stem,r,'static')
            ep=dst(n)/(stem+'_e.png')
            if ep.exists():
                e=Image.open(ep).convert('RGBA');assert e.size==((im.width+1)//2,(im.height+1)//2)
                data=np.asarray(e);assert (data[:,:,:3].max(2).astype(float)*data[:,:,3]/255).max()>2
            # Compare silhouettes in the same rendered frame/crop coordinate system.
            ref=Image.open(WORK/'before'/n/(stem+'.png')).convert('RGBA')
            vcw,vch=v['virtual'];ref=ref.resize((vcw*v['cols'],vch*v['rows']),Image.Resampling.LANCZOS)
            ref=crop_atlas(ref,v['box'],v['virtual'],v['cols'],v['rows'])
            aa=np.asarray(im)[:,:,3]>128;bb=np.asarray(ref)[:,:,3]>128
            iou=float((aa&bb).sum()/max(1,(aa|bb).sum()));ious.append(iou)
            v['silhouette_iou']=iou
            assert iou>.97,(n,stem,'silhouette IoU',iou)
            count+=1
    report['after']=budget();report['verification']={'sheets':count,'frames':frames,'min_iou':min(ious),'margin_px':4,'result':'PASS'}
    dump(WORK/'report.json',report)
    print('PASS verification',count,'sheets',frames,'frames')

def contact():
    from PIL import Image
    report=json.loads((WORK/'report.json').read_text())
    names=['eclusier',*IDS]
    board=Image.new('RGBA',(1200,280*len(names)))
    floor=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for row,y in enumerate(range(-floor.height//2,board.height,max(1,floor.height//2))):
        for x in range(-floor.width,board.width,floor.width):board.alpha_composite(floor,(x+(floor.width//2 if row%2 else 0),y))
    for row,n in enumerate(names):
        for col,a in enumerate(('idle_p1','idle_p3','spell_a','death')):
            im=Image.open(dst(n)/(a+'.png')).convert('RGBA')
            if n=='eclusier':
                text=(dst(n)/(n+'.tres')).read_text()
                eid=re.search(r'path="[^"]*/'+a+r'\.png" id="([^"]+)"',text)[1]
                regs=re.findall(r'atlas = ExtResource\("'+re.escape(eid)+r'"\)\s*region = Rect2\(([^)]+)\)',text)
                _,_,w,h=map(int,regs[0].split(','));cols=im.width//w
            else:v=report['subjects'][n][a];w,h=v['cell'];cols=v['cols']
            i=cols-1 if a=='death' else cols//2 if a=='spell_a' else 0
            frame=im.crop((i*w,0,(i+1)*w,h));frame.thumbnail((292,268),Image.Resampling.LANCZOS)
            board.alpha_composite(frame,(col*300+(300-frame.width)//2,row*280+276-frame.height))
    board.convert('RGB').save(HERE/'_r2b_contact.png')
    print('PASS contact eclusier,ox_herder,smelter,jar_bearer,hermit_cedar,deep_eel')

def checks():
    import subprocess
    godot=r'C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
    log=HERE/'_r2b_import.log'
    resume='--resume-checks' in sys.argv
    if not resume:
        with log.open('w') as f:
            result=subprocess.run([godot,'--headless','--path',str(ROOT/'game'),'--editor','--import','--quit'],stdout=f,stderr=subprocess.STDOUT,timeout=600)
        assert result.returncode==0,'import failed: '+str(log)
        print('PASS import',flush=True)
        with (HERE/'_r2b_budget.log').open('w') as f:
            subprocess.run([sys.executable,str(ROOT/'art/tools/texture_budget.py'),'--top','0'],stdout=f,stderr=subprocess.STDOUT,timeout=120)
    results={}
    for test in ['sprites_test','texture_budget_test',*[n+'_boss_test' for n in IDS]]:
        if not (ROOT/'game/tests'/(test+'.tscn')).exists():continue
        log=HERE/('_r2b_'+test+'.log')
        if resume and log.exists() and re.search(r'RESULT: (?:OK|FAIL)',log.read_text(encoding='utf-8',errors='replace')):
            text=log.read_text(encoding='utf-8',errors='replace');results[test]='OK' if 'RESULT: OK' in text else 'FAIL'
            print(test+': RESULT: '+results[test]+' (completed)',flush=True);continue
        with log.open('w') as f:
            result=subprocess.run([godot,'--headless','--fixed-fps','60','--path',str(ROOT/'game'),'res://tests/'+test+'.tscn'],stdout=f,stderr=subprocess.STDOUT,timeout=240)
        text=log.read_text(encoding='utf-8',errors='replace')
        ok=result.returncode==0 and 'RESULT: OK' in text
        results[test]='OK' if ok else 'FAIL'
        print(test+': RESULT: '+results[test],flush=True)
    report=json.loads((WORK/'report.json').read_text());report['tests']=results;report['after']=budget();dump(WORK/'report.json',report)
    report['limitations']=['Extras with scales embedded in forbidden .gd retain their virtual dimensions and scale.',
                          'Native body resolution increases compressed mobile payload; global Android budget remains exceeded.']
    dump(WORK/'report.json',report)
    before,after=report['before'],report['after']
    lines=['R2B : 87 planches, 1542 frames ; cel boss ; marge 4 px ; corps echelle 1.0.',
           f'texture_budget.py, perimetre : VRAM {before["vram"]} -> {after["vram"]} octets ; mobile {before["mobile"]} -> {after["mobile"]} octets.',
           '; '.join(k+': RESULT: '+v for k,v in results.items()),
           '_e demi-resolution, non noirs ; aucun _n ; sources .blend inchangees ; aucun .gd/.tscn ecrit.',
           'Extras : echelles codees dans les .gd conservees ; budget Android global depasse.',
           'Contact : art/tools/night/_r2b_contact.png ; details : art/blender/cel/r2b/report.json.']
    (HERE/'_r2b_report.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    assert all(v=='OK' for v in results.values()),results

if __name__=='__main__':
    if '--prepare' in sys.argv:prepare()
    elif '--render' in sys.argv:render()
    elif '--deliver' in sys.argv:deliver()
    elif '--verify' in sys.argv:verify()
    elif '--contact' in sys.argv:contact()
    elif '--checks' in sys.argv:checks()
