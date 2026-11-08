"""Numerical checks against real PNGs and all actual SpriteFrames atlas references."""
from pathlib import Path
import sys,json,re,math,hashlib,gzip
import numpy as np
from PIL import Image
import tocsin_actions_build as t
ROOT,BASE,OUT=t.ROOT,t.BASE,t.OUT
STAGED='--staged' in sys.argv
EXPORT=OUT/'exports'
before=json.loads((OUT/'before.json').read_text())
errors=[];stats={};cache={}
def check(ok,message):
    if not ok:errors.append(str(message))
def resolve(p):
    q=EXPORT/p.relative_to(BASE)
    return q if STAGED and q.exists() else p
def image(p):
    p=resolve(p)
    if p not in cache:
        check(p.exists() and p.stat().st_size>40,('file',str(p)))
        with Image.open(p) as im:im.load();cache[p]=im.convert('RGBA')
    return cache[p]
def resource(p):return resolve(p).read_text()
def frames(anim,d,layer='composite'):
    p=BASE/('tocsin.tres' if layer=='composite' else f'tocsin_{layer}.tres');s=resource(p)
    ext={m[2]:BASE/m[1].split('/tocsin/')[1] for m in re.finditer(r'path="([^"]+)" id="([^"]+)"',s)}
    bs=t.blocks(s);line=next(x for x in s.splitlines() if '"name": &"'+anim+'_'+d+'"' in x);result=[]
    for rid in re.findall(r'"texture": SubResource\("([^"]+)"\)',line):
        b=bs[rid];eid=re.search(r'atlas = ExtResource\("([^"]+)"\)',b)[1]
        x,y,w,h=[int(float(v)) for v in re.search(r'region = Rect2\(([^)]+)\)',b)[1].split(',')]
        m=re.search(r'margin = Rect2\(([^)]+)\)',b);mx,my,mw,mh=[int(float(v)) for v in m[1].split(',')] if m else (0,0,0,0)
        im=Image.new('RGBA',(w+mw,h+mh));im.paste(image(ext[eid]).crop((x,y,x+w,y+h)),(mx,my));result.append(im)
    return result

resources=regions=0
for p in sorted(BASE.glob('tocsin*.tres')):
    s=resource(p);resources+=1
    check('CanvasTexture' not in s and 'normal_texture' not in s,('normals resource',p.name))
    ext={m[2]:ROOT/'game'/m[1].removeprefix('res://') for m in re.finditer(r'path="([^"]+)" id="([^"]+)"',s)}
    check(s.rfind('[ext_resource')<s.find('[sub_resource') if '[ext_resource' in s and '[sub_resource' in s else True,('ext order',p.name))
    used=set(re.findall(r'SubResource\("([^"]+)"\)',s));bs=t.blocks(s)
    check(set(bs)<=used,('orphan',p.name,sorted(set(bs)-used)[:3]))
    for rid,b in bs.items():
        eid=re.search(r'atlas = ExtResource\("([^"]+)"\)',b)
        check(eid is not None and eid[1] in ext,('missing atlas',p.name,rid))
        if eid is None or eid[1] not in ext:continue
        im=image(ext[eid[1]]);r=re.search(r'region = Rect2\(([^)]+)\)',b)
        check(r is not None,('missing region',p.name,rid))
        if not r:continue
        x,y,w,h=map(float,r[1].split(','));regions+=1
        check(all(math.isfinite(v) for v in (x,y,w,h)) and x>=0 and y>=0 and w>0 and h>0 and x+w<=im.width+1e-4 and y+h<=im.height+1e-4,('invalid region',p.name,rid,(x,y,w,h),im.size))
    for m in re.finditer(r'\{"frames": \[(.*?)\], "loop": (true|false), "name": &"([^"]+)", "speed": ([0-9.]+)\}',s,re.S):
        name=m[3];anim,d=name.rsplit('_',1) if '_' in name else ('','')
        if anim not in t.TARGETS or d not in t.DIRS:continue
        a='cast' if anim=='cast_ult' else anim;dur=[float(x) for x in re.findall(r'"duration": ([0-9.]+)',m[1])]
        check(len(dur)==t.ANIMS[a],('frame count',p.name,name,len(dur)))
        check(np.allclose(dur,np.array(t.F60[a])*float(m[4])/60),('durations',p.name,name,dur))
        check(m[2]=='false',('loop',p.name,name))
        check(all(r in bs for r in re.findall(r'SubResource\("([^"]+)"\)',m[1])),('frame references',p.name,name))
    original=(OUT/p.name).read_bytes();current=resolve(p).read_bytes()
    check((b'\r\n' in original)==(b'\r\n' in current),('line endings',p.name))

manifest=json.loads(resolve(BASE/'atlas_manifest.json').read_text());spill=0
for layer in t.PARTS:
    for a in t.TARGETS:
        layout=manifest[layer+'/'+a];spill+=layout.get('spill_frames',0)
        n=t.ANIMS['cast' if a=='cast_ult' else a]
        check(len(layout['frames'])==8*n,('manifest frames',layer,a))
        for f in layout['frames']:
            source=f.get('atlas')=='source';p=BASE/'layers'/layer/('' if source else 'packed')/(a+'.png')
            im=image(p);x,y,w,h=f['region'];check(x+w<=im.width and y+h<=im.height,('manifest region',layer,a,f))
            check(w+f['margin'][2]==192 and h+f['margin'][3]==192,('logical size',layer,a,f['direction'],f['frame']))
        check('_n' not in layout['passes'],('manifest normals',layer,a))

for anim,n in t.ANIMS.items():
    anticipation=[];recovery=[];direction_hashes=[];contrast=[]
    for d in t.DIRS:
        ff=frames(anim,d);check(len(ff)==n,('composite frames',anim,d))
        arrays=[np.asarray(f) for f in ff];masks=[a[...,3]>32 for a in arrays]
        check(all(m.any() for m in masks),('empty composite',anim,d))
        for i,f in enumerate(ff):
            box=f.getchannel('A').getbbox()
            check(box and min(box[:2])>=1 and max(box[2:])<=191,('clipped frame',anim,d,i,box))
        hashes=[hashlib.sha256(a.tobytes()).hexdigest() for a in arrays]
        check(len(set(hashes))==n,('duplicate frames',anim,d))
        direction_hashes.append(hashlib.sha256(''.join(hashes).encode()).hexdigest())
        idle=np.asarray(t.load_frames('idle',d)[0])[...,3]>32
        outside=max(float((m&~idle).sum()/max(1,m.sum())) for m in masks[:t.HITS[anim]])
        anticipation.append(outside);check(outside>=.25,('anticipation <25%',anim,d,round(outside,4)))
        ib=t.load_frames('idle',d)[0].getchannel('A').getbbox();rb=ff[-1].getchannel('A').getbbox()
        ratio=(rb[3]-rb[1])/(ib[3]-ib[1]);recovery.append(ratio)
        check(.70<=ratio<=1.30,('recovery scale',anim,d,round(ratio,3)))
        for i,a in enumerate(arrays):
            visible=a[a[...,3]>128,:3]
            val=float(np.percentile(visible,95)-np.percentile(visible,5));contrast.append(val)
            check(val>=35,('contrast',anim,d,i,val))
        for layer in t.PARTS:
            for i,im in enumerate(frames(anim,d,layer)):
                empty=im.getchannel('A').getbbox() is None
                missing=anim.startswith('throw_') and layer==anim[6:] and i>=t.HITS[anim]
                check(empty==missing,('layer visibility/release',anim,d,layer,i,empty))
        if anim=='cast':
            arm=frames(anim,d,'arm_l')[1].getchannel('A').getbbox();head=frames(anim,d,'head')[1].getchannel('A').getbbox()
            check(arm[1]<=head[1]-8,('fist not above head',d,arm,head))
    check(len(set(direction_hashes))==8,('directions not distinct',anim))
    check(sum(t.F60[anim][t.HITS[anim]+1:])>sum(t.F60[anim][:t.HITS[anim]]),('recovery duration',anim))
    stats[anim]={'frames':n,'impact':t.HITS[anim],'F60':t.F60[anim],'anticipation_min':min(anticipation),'recovery_scale_range':[min(recovery),max(recovery)],'contrast_min':min(contrast)}

png_changed=[];resized=[];max_weight=0
for rel,old in before['png'].items():
    p=BASE/rel;q=resolve(p);changed=t.sha(q)!=old['sha']
    if changed:png_changed.append(rel);check(t.allowed(p),('protected PNG changed',rel))
    if changed:
        im=image(p);max_weight=max(max_weight,q.stat().st_size/old['bytes'])
        check(q.stat().st_size<=old['bytes']*1.3,('weight',rel,q.stat().st_size,old['bytes']))
        if list(im.size)!=old['size']:resized.append(rel);check('cast_ult' in rel or im.size[0]*im.size[1]<=old['size'][0]*old['size'][1]*1.4,('size changed',rel,im.size,old['size']))
        if p.stem.endswith('_e'):
            diffuse=image(p.with_name(p.name.replace('_e.png','.png')))
            check(im.size==((diffuse.width+1)//2,(diffuse.height+1)//2),('emission dimensions',rel,im.size,diffuse.size))
            pixels=np.asarray(im);check(np.any(pixels[...,:3][pixels[...,3]>0]>1),('black emission',rel))
    if Path(rel).stem in ('cast','cast_e'):
        alias=resolve(p.with_name(p.name.replace('cast','cast_ult')));check(t.sha(q)==t.sha(alias),('alias bytes',rel))
for p in EXPORT.rglob('*.png'):
    if p.relative_to(EXPORT).as_posix() not in before['png']:check(t.allowed(p),('new PNG',str(p)))
check(not list(BASE.rglob('*_n.png')) and not list(OUT.rglob('*_n.png')) and not list(t.WORK.rglob('*_n.png')),'forbidden normal map')
if not STAGED:
    with gzip.open(OUT/'outside_before.json.gz','rt') as f:outside_before=set(json.load(f))
    outside=set(t.outside_files())-outside_before
    (OUT/'outside_new.json').write_text(json.dumps(sorted(outside),indent=2));check(not outside,('outside new files',len(outside)))
report={'result':'FAIL' if errors else 'PASS','staged':STAGED,'errors':errors,'animations':stats,'resources':resources,'regions_checked':regions,'png_changed':png_changed,'protected_intact':len(before['png'])-len(png_changed),'alias_resized':resized,'max_weight_ratio':max_weight,'source_spill_frames':spill}
protected=sorted(set(before['png'])-set(png_changed))
report['protected_sha256_before']=hashlib.sha256('\n'.join(rel+':'+before['png'][rel]['sha'] for rel in protected).encode()).hexdigest()
report['protected_sha256_after']=hashlib.sha256('\n'.join(rel+':'+t.sha(resolve(BASE/rel)) for rel in protected).encode()).hexdigest()
(OUT/('verify_staged.json' if STAGED else 'verify.json')).write_text(json.dumps(report,indent=2))
(OUT/'changed_png.txt').write_text('\n'.join(png_changed)+'\n')
print(report['result'],'resources',resources,'regions',regions,'changed PNG',len(png_changed),'protected',report['protected_intact'],'max weight',round(max_weight,4),'spill',spill,'errors',len(errors))
for error in errors[:8]:print(error)
if not STAGED:
    for rel in png_changed:print('CHANGED '+rel)
sys.exit(bool(errors))
