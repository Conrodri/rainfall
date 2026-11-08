"""Carillon action sheets: shared poses, authoritative base atlas coordinates."""
from pathlib import Path
import sys, json, re, shutil, gzip, hashlib, subprocess
sys.dont_write_bytecode=True
from PIL import Image
import numpy as np
import tocsin_actions_build as t
ROOT=t.ROOT
BASE=t.BASE
SKIN=BASE/'skins/tocsin_skin1'
OUT=ROOT/'art/renders/feel_sorts2/tocsin_skin_actions'
STAGE=OUT/'exports'
PREFIX='res://assets/sprites/characters/tocsin/'
SPREFIX=PREFIX+'skins/tocsin_skin1/'
sha=t.sha

def snapshot():
    assert not (OUT/'before.json').exists()
    data={p.relative_to(SKIN).as_posix():{'sha':sha(p),'bytes':p.stat().st_size} for p in SKIN.rglob('*') if p.is_file()}
    (OUT/'before.json').write_text(json.dumps(data))
    with gzip.open(OUT/'outside_before.json.gz','wt') as f:json.dump(t.outside_files(),f)
    print('PASS baseline',len(data))

def entries(s):
    body=s.split('animations = [',1)[1];result=[];depth=0
    for i,c in enumerate(body):
        if c=='{':
            if depth==0:start=i
            depth+=1
        elif c=='}':
            depth-=1
            if depth==0:result.append(body[start:i+1])
    return result

def is_action(e):
    return re.search(r'"name"\s*:\s*&?"([^"]+)"',e)[1].rsplit('_',1)[0] in t.TARGETS

def resources(src,dest):
    old=(SKIN/dest).read_text();base=src.read_text()
    kept=[e for e in entries(old) if not is_action(e)]
    new=[e for e in entries(base) if is_action(e)]
    if not new:return
    oldsubs=t.blocks(old);basesubs=t.blocks(base)
    if '_emission' in dest:
        counterpart=dest.replace('_emission','')
        if counterpart=='tocsin.tres':counterpart='tocsin_skin1.tres'
        diff=t.blocks((SKIN/counterpart).read_text()) if (SKIN/counterpart).exists() else {}
        paths={m[2]:ROOT/'game'/m[1].removeprefix('res://') for m in re.finditer(r'path="([^"]+)" id="([^"]+)"',old)}
        for sid,b in list(oldsubs.items()):
            em=re.search(r'atlas = ExtResource\("([^"]+)"\)',b)
            region=re.search(r'region = Rect2\(([^)]+)\)',b)
            dr=re.search(r'region = Rect2\(([^)]+)\)',diff.get(sid,''))
            if not em or not region or not dr or region[1]!=dr[1]:continue
            ep=paths[em[1]];dp=ep.with_name(ep.name.replace('_e.png','.png'))
            if not dp.exists():continue
            with Image.open(ep) as ei,Image.open(dp) as di:rx,ry=ei.width/di.width,ei.height/di.height
            def scale(m):
                vals=[float(v) for v in m[2].split(',')]
                return m[1]+' = Rect2('+', '.join(f'{v*r:.8g}' for v,r in zip(vals,(rx,ry,rx,ry)))+')'
            oldsubs[sid]=re.sub(r'(region|margin) = Rect2\(([^)]+)\)',scale,b)
    needed=set(re.findall(r'SubResource\("([^"]+)"\)',','.join(kept)))
    subs=[oldsubs[k].rstrip() for k in oldsubs if k in needed]
    ext=re.findall(r'\[ext_resource[^\]]+\]',old)
    baseext={re.search(r'id="([^"]+)"',e)[1]:e for e in re.findall(r'\[ext_resource[^\]]+\]',base)}
    refs=set(re.findall(r'SubResource\("([^"]+)"\)',','.join(new)))
    usedext=set()
    for sid in sorted(refs):
        b=basesubs[sid].rstrip().replace('id="'+sid+'"','id="carillon_'+sid+'"')
        usedext.update(re.findall(r'ExtResource\("([^"]+)"\)',b))
        b=re.sub(r'ExtResource\("([^"]+)"\)',lambda m:'ExtResource("carillon_'+m[1]+'")',b)
        subs.append(b)
    for eid in sorted(usedext):
        e=baseext[eid].replace('id="'+eid+'"','id="carillon_'+eid+'"')
        e=e.replace(PREFIX,SPREFIX)
        rel=re.search(r'path="([^"]+)"',e)[1].removeprefix(SPREFIX)
        assert (STAGE/rel).exists() or (SKIN/rel).exists(),rel
        ext.append(e)
    new=[re.sub(r'SubResource\("([^"]+)"\)',lambda m:'SubResource("carillon_'+m[1]+'")',e) for e in new]
    header=re.search(r'^\[gd_resource[^\]]+\]',old)[0]
    header=re.sub(r'load_steps=\d+','load_steps='+str(len(ext)+len(subs)+1),header)
    result=header+'\n\n'+'\n\n'.join(ext+subs)+'\n\n[resource]\nanimations = [\n'+',\n'.join(kept+new)+'\n]\n'
    (STAGE/dest).write_text(result)
    assert [e for e in entries(result) if not is_action(e)]==kept

def optimize(path,budget):
    if path.stat().st_size<=budget:return
    original=Image.open(path).convert('RGBA')
    exe=t.WORK/'bin/pngquant.exe'
    if exe.exists():
        subprocess.run([str(exe),'256','--speed','1','--nofs','--force','--ext','.png',str(path)],check=True,capture_output=True)
        if path.stat().st_size<=budget:return
    for colors in (256,192,128,96,64,48,32,24,16):
        original.quantize(colors=colors,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE).save(path,optimize=True,compress_level=9)
        if path.stat().st_size<=budget:return
    raise AssertionError(('budget',str(path),path.stat().st_size,budget))

def finish():
    assert json.loads((OUT/'render_completed.json').read_text())['result']=='PASS'
    before=json.loads((OUT/'before.json').read_text())
    layouts=json.loads((ROOT/'art/renders/feel_sorts2/tocsin_actions/layouts.json').read_text())
    orders=json.loads((BASE/'layers_order.json').read_text())['orders']
    STAGE.mkdir(exist_ok=True)
    for anim,n in t.ANIMS.items():
        tiles={}
        for d in t.DIRS:
            for i in range(n):
                for k in t.PARTS:
                    p=OUT/'raw'/anim/d/f'{k}_{i:02d}.png'
                    tile=Image.open(p).convert('RGBA')
                    arm_hold=anim=='cast' and ((k=='arm_l' and i==4) or (k=='arm_r' and i in (0,4)))
                    stable=arm_hold or (k=='head' and anim in ('cast','throw_arm_l','throw_arm_r')) or k.startswith('leg_') or k=='neck_steam'
                    if stable:
                        donor_index=3 if k=='neck_steam' and anim=='throw_head' and i>=3 else 0
                        if arm_hold:donor_index=1 if i==0 else 3
                        donor=Image.open(p.with_name(f'{k}_{donor_index:02d}.png')).convert('RGBA')
                        a=tile.getchannel('A').getbbox();b=donor.getchannel('A').getbbox()
                        if a and b:
                            dx=round((a[0]+a[2]-b[0]-b[2])/2);dy=round((a[1]+a[3]-b[1]-b[3])/2)
                            tile=Image.new('RGBA',(192,192));tile.paste(donor,(dx,dy))
                    tiles[k,d,i]=tile
                full=Image.new('RGBA',(192,192))
                for k in orders[d]:
                    if k!='neck_steam' or (anim=='throw_head' and i>=3):full.alpha_composite(tiles[k,d,i])
                tiles['composite',d,i]=full
        for k in t.PARTS+['composite']:
            layout=layouts[k+'/'+anim]
            dest=Path('.') if k=='composite' else Path('layers')/k
            jobs=[]
            if k=='composite' or layout.get('spill_frames'):
                jobs=[(dest/(anim+'.png'),layout.get('source_frames',layout['frames']))]
            if k!='composite':jobs.append((dest/'packed'/(anim+'.png'),[f for f in layout['frames'] if f.get('atlas')!='source']))
            for rel,frames in jobs:
                with Image.open(BASE/rel) as ref:sheet=Image.new('RGBA',ref.size)
                for f in frames:
                    x,y,w,h=f['region'];crop=f['crop']
                    tile=tiles[k,f['direction'],f['frame']].crop(tuple(crop))
                    assert tile.size==(w,h),(rel,f)
                    sheet.paste(tile,(x,y))
                p=STAGE/rel;p.parent.mkdir(parents=True,exist_ok=True);sheet.save(p,optimize=True,compress_level=9)
                key=rel.as_posix() if rel.as_posix() in before else (rel.parent/'packed'/rel.name).as_posix()
                budget=before[key]['bytes']*1.3
                if anim=='cast':budget=min(budget,before[key.replace('cast','cast_ult')]['bytes']*1.3)
                optimize(p,budget)
                if anim=='cast':shutil.copy2(p,p.with_name('cast_ult.png'))
    for p in BASE.rglob('*_e.png'):
        if 'skins' in p.relative_to(BASE).parts or not t.allowed(p):continue
        if not (STAGE/p.relative_to(BASE).with_name(p.name.replace('_e.png','.png'))).exists():continue
        rel=p.relative_to(BASE);q=STAGE/rel;q.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(p,q)
        key=rel.as_posix() if rel.as_posix() in before else (rel.parent/'packed'/rel.name).as_posix()
        assert q.stat().st_size<=before[key]['bytes']*1.3,('emission budget',str(rel),q.stat().st_size,before[key]['bytes'])
    for p in BASE.glob('tocsin*.tres'):
        dest='tocsin_skin1.tres' if p.name=='tocsin.tres' else p.name
        if (SKIN/dest).exists():resources(p,dest)
    manifest=json.loads((SKIN/'atlas_manifest.json').read_text());bm=json.loads((BASE/'atlas_manifest.json').read_text())
    for key in bm:
        if key.rsplit('/',1)[-1] in t.TARGETS:manifest[key]=bm[key]
    (STAGE/'atlas_manifest.json').write_text(json.dumps(manifest,indent=2))
    print('PASS staged',len(list(STAGE.rglob('*.png'))))

def resolve(p):
    q=STAGE/p.relative_to(SKIN)
    return q if q.exists() else p

def verify(install=False):
    before=json.loads((OUT/'before.json').read_text());regions=0;clips=0
    cache={}
    def image(p):
        p=resolve(p)
        if p not in cache:
            with Image.open(p) as im:im.load();cache[p]=im.convert('RGBA')
        return cache[p]
    for p in STAGE.rglob('*.png'):
        rel=p.relative_to(STAGE);im=image(SKIN/rel)
        with Image.open(BASE/rel) as base:assert im.size==base.size,rel
        key=rel.as_posix() if rel.as_posix() in before else (rel.parent/'packed'/rel.name).as_posix()
        assert p.stat().st_size<=before[key]['bytes']*1.3,rel
        assert im.getchannel('A').getbbox(),rel
        if p.stem.endswith('_e'):
            assert sha(p)==sha(BASE/rel),rel
            assert max(im.getextrema()[c][1] for c in range(3))>0,rel
            diffuse=image(SKIN/rel.with_name(rel.name.replace('_e.png','.png')))
            assert im.size in (diffuse.size,((diffuse.width+1)//2,(diffuse.height+1)//2)),rel
        assert not p.stem.endswith('_n')
    for p in STAGE.glob('*.tres'):
        s=p.read_text();assert 'CanvasTexture' not in s and 'normal_texture' not in s
        ext={m[2]:ROOT/'game'/m[1].removeprefix('res://') for m in re.finditer(r'path="([^"]+)" id="([^"]+)"',s)}
        bs=t.blocks(s)
        for rid,b in bs.items():
            m=re.search(r'atlas = ExtResource\("([^"]+)"\)',b)
            if not m:continue
            im=image(ext[m[1]]);r=re.search(r'region = Rect2\(([^)]+)\)',b)
            if r:
                x,y,w,h=map(float,r[1].split(','));assert min(x,y)>=0 and min(w,h)>0 and x+w<=im.width+.0001 and y+h<=im.height+.0001,(p.name,rid,str(ext[m[1]]),im.size,r[1],[re.search(r'"name"\s*:\s*&"([^"]+)"',e)[1] for e in entries(s) if 'SubResource("'+rid+'")' in e])
                regions+=1
        for e in entries(s):
            if not is_action(e):continue
            name=re.search(r'"name"\s*:\s*&"([^"]+)"',e)[1];a,d=name.rsplit('_',1);a='cast' if a=='cast_ult' else a
            speed=float(re.search(r'"speed"\s*:\s*([0-9.]+)',e)[1])
            durations=[float(v) for v in re.findall(r'"duration"\s*:\s*([0-9.]+)',e)]
            assert np.allclose(durations,np.array(t.F60[a])*speed/60),(p.name,name)
            assert len(durations)==t.ANIMS[a];clips+=1
    for anim,n in dict(t.ANIMS,cast_ult=6).items():
        for d in t.DIRS:
            if anim.startswith('throw_'):continue  # clips composites throw_* retirés du skin (retime)
            frames=frame_images(anim,d,STAGE/'tocsin_skin1.tres')
            assert len(frames)==n and all(f.getchannel('A').getbbox() for f in frames),(anim,d)
            assert len({hashlib.sha256(f.tobytes()).hexdigest() for f in frames})>1,(anim,d,'duplicates')
            rgb=np.concatenate([np.asarray(f)[:,:,:3][np.asarray(f)[:,:,3]>0] for f in frames]);assert rgb.max()-rgb.min()>20,(anim,d,'contrast')
    untouched={rel:data['sha'] for rel,data in before.items() if rel.endswith('.png') and not t.allowed(Path(rel))}
    assert all(sha(SKIN/rel)==h for rel,h in untouched.items())
    (OUT/'unchanged_sha256.json').write_text(json.dumps(untouched,indent=2))
    for rel,h in sorted(untouched.items()):print('UNCHANGED SHA256',h,rel)
    assert not list(SKIN.rglob('*_n.png'))
    with gzip.open(OUT/'outside_before.json.gz','rt') as f:outside=set(t.outside_files())-set(json.load(f))
    assert not outside,sorted(outside)[:5]
    report={'result':'PASS','png':len(list(STAGE.rglob('*.png'))),'regions':regions,'clips':clips,'unchanged_png':len(untouched),'bytes_before':sum(before.get(p.relative_to(STAGE).as_posix(),{'bytes':0})['bytes'] for p in STAGE.rglob('*.png')),'bytes_after':sum(p.stat().st_size for p in STAGE.rglob('*.png')),'outside_new':len(outside),'new_png':[p.relative_to(STAGE).as_posix() for p in STAGE.rglob('*.png') if p.relative_to(STAGE).as_posix() not in before]}
    (OUT/'verify.json').write_text(json.dumps(report,indent=2));print('PASS',json.dumps(report))
    if install:
        for p in STAGE.rglob('*'):
            if p.is_file():shutil.copy2(p,SKIN/p.relative_to(STAGE))
        assert all(sha(SKIN/p.relative_to(STAGE))==sha(p) for p in STAGE.rglob('*') if p.is_file())
        assert all(sha(SKIN/rel)==h for rel,h in untouched.items())
        with gzip.open(OUT/'outside_before.json.gz','rt') as f:assert not set(t.outside_files())-set(json.load(f))
        print('PASS installed')

def frame_images(anim,d,resource):
    # Reuse the base SpriteFrames decoder, resolving staged skin PNGs.
    s=resource.read_text();ext={m[2]:ROOT/'game'/m[1].removeprefix('res://') for m in re.finditer(r'path="([^"]+)" id="([^"]+)"',s)}
    clip=next(e for e in entries(s) if re.search(r'"name"\s*:\s*&"'+anim+'_'+d+'"',e));bs=t.blocks(s);result=[]
    for rid in re.findall(r'SubResource\("([^"]+)"\)',clip):
        b=bs[rid];p=resolve(ext[re.search(r'atlas = ExtResource\("([^"]+)"\)',b)[1]])
        x,y,w,h=map(lambda v:int(float(v)),re.search(r'region = Rect2\(([^)]+)\)',b)[1].split(','))
        m=re.search(r'margin = Rect2\(([^)]+)\)',b);mx,my,mw,mh=map(lambda v:int(float(v)),m[1].split(',')) if m else (0,0,0,0)
        tile=Image.new('RGBA',(w+mw,h+mh))
        with Image.open(p) as im:tile.paste(im.convert('RGBA').crop((x,y,x+w,y+h)),(mx,my))
        result.append(tile)
    return result

def contact():
    # Pillow assembly only: two groups per row, all frames, direction se.
    sheet=Image.new('RGBA',(1008,5*84),(28,30,38,255))
    for row,anim in enumerate(t.ANIMS):
        for group,resource in enumerate((BASE/'tocsin.tres',SKIN/'tocsin_skin1.tres')):
            frames=t.load_frames(anim,'se',resource)
            for i,im in enumerate(frames):
                im.thumbnail((80,80),Image.Resampling.LANCZOS);sheet.alpha_composite(im,(group*504+i*84,row*84))
    sheet.convert('RGB').save(ROOT/'art/renders/feel_sorts2/after_tocsin_skin.png',optimize=True)
    print('PASS contact 1008x420 rows attack cast throw_arm_l throw_arm_r throw_head; base left Carillon right')

if __name__=='__main__':
    if '--snapshot' in sys.argv:snapshot()
    elif '--finish' in sys.argv:finish();verify()
    elif '--install' in sys.argv:verify();verify(install=True);contact()
