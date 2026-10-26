"""Lossless cell storage crops; AtlasTexture margins preserve the 192px logical rig.

No painting or resizing. Even boundaries keep half-resolution emission aligned.
"""
from pathlib import Path
import json,re,sys,shutil
from PIL import Image
import numpy as np

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).parent
GAME=ROOT/'game/assets/sprites/characters/tocsin'
WORK=ROOT/'art/blender/cel/heroes_tocsin/crop_check'
MANIFEST=HERE/'_cel_heroes_tocsin_crops.json'
REPORT=HERE/'_cel_heroes_tocsin_verification.json'
ARCHIVE=ROOT/'art/archive_3d/sprites/characters/tocsin'

def cell_of(rel):
    stem=Path(rel).stem
    return 1032 if stem in ('head_ring','head_blast_top') else 56 if stem=='rivet' else 256 if stem.startswith('portrait') else 192

def transform(im,spec,expand=False,ratio=1):
    cell=spec['cell']//ratio
    x,y,x1,y1=[v//ratio for v in spec['box']]
    cw,ch=x1-x,y1-y
    cols,rows=spec['grid']
    out=Image.new('RGBA',(cols*(cell if expand else cw),rows*(cell if expand else ch)))
    for row in range(rows):
        for col in range(cols):
            if expand:
                tile=im.crop((col*cw,row*ch,(col+1)*cw,(row+1)*ch))
                out.paste(tile,(col*cell+x,row*cell+y))
            else:
                tile=im.crop((col*cell+x,row*cell+y,col*cell+x1,row*cell+y1))
                out.paste(tile,(col*cw,row*ch))
    return out

def restore():
    if not MANIFEST.exists():return
    data=json.loads(MANIFEST.read_text())
    if not data.get('active'):return
    for rel,spec in data['sheets'].items():
        for suffix,ratio in spec['passes'].items():
            p=GAME/rel;p=p.with_name(p.stem+suffix+'.png')
            with Image.open(p) as im:out=transform(im.convert('RGBA'),spec,True,ratio)
            out.save(p,optimize=True,compress_level=9)
    for rel in data['resources']:
        shutil.copy2(ARCHIVE/rel,GAME/rel)
    data['active']=False;MANIFEST.write_text(json.dumps(data,indent=2))

def compact():
    import cel_style as cel
    state=json.loads((HERE/'_cel_heroes_tocsin_state.json').read_text())
    data={'active':False,'sheets':{},'resources':[],
          'scale':'CREA (sqrt(.5),sqrt(2)) has determinant 1; projection converts R=64*sqrt(2) to 64px/u. No scalar downsampling in the kit.',
          'pivot':'Logical frames retained by AtlasTexture.margin; feet, offset and sockets unchanged.'}
    for rel,size in state['png'].items():
        if Path(rel).stem.endswith(('_e','_shadow','_n')) or '/packed/' in rel:continue
        # Portraits are direct UI textures, without an AtlasTexture to restore their framing.
        if Path(rel).stem.startswith('portrait'):continue
        cell=cell_of(rel);cols,rows=size[0]//cell,size[1]//cell
        with Image.open(GAME/rel) as im:
            a=np.asarray(im.convert('RGBA'))[...,3]
        mask=a.reshape(rows,cell,cols,cell).max(axis=(0,2))
        base=GAME/rel
        for suffix in ('_e','_shadow'):
            p=base.with_name(base.stem+suffix+'.png')
            if p.exists():
                with Image.open(p) as im:
                    ratio=2 if im.size==((size[0]+1)//2,(size[1]+1)//2) else 1
                    alpha=np.asarray(im.convert('RGBA'))[...,3]
                small=alpha.reshape(rows,cell//ratio,cols,cell//ratio).max(axis=(0,2))
                mask=np.maximum(mask,np.repeat(np.repeat(small,ratio,axis=0),ratio,axis=1))
        yy,xx=np.where(mask>0)
        assert len(xx),rel
        box=[max(0,(int(xx.min())-4)//2*2),max(0,(int(yy.min())-4)//2*2),
             min(cell,(int(xx.max())+6)//2*2),min(cell,(int(yy.max())+6)//2*2)]
        if box==[0,0,cell,cell]:continue
        spec={'cell':cell,'box':box,'grid':[cols,rows],'passes':{'':1}}
        base=GAME/rel
        for suffix in ('_e','_shadow'):
            p=base.with_name(base.stem+suffix+'.png')
            if p.exists():
                with Image.open(p) as im:
                    ratio=2 if im.size==((size[0]+1)//2,(size[1]+1)//2) else 1
                    assert im.size==(size[0]//ratio,size[1]//ratio),(rel,suffix,im.size)
                spec['passes'][suffix]=ratio
        data['sheets'][rel]=spec
    # Validate the full transaction before changing any delivered image or resource.
    for rel,spec in data['sheets'].items():
        base=GAME/rel
        for suffix,ratio in spec['passes'].items():
            p=base.with_name(base.stem+suffix+'.png')
            with Image.open(p) as im:aa=np.asarray(im.convert('RGBA'))
            out=transform(Image.fromarray(aa),spec,ratio=ratio)
            bb=np.asarray(transform(out,spec,expand=True,ratio=ratio))
            assert np.array_equal(aa[...,3],bb[...,3]),(rel,suffix,'crop preflight')
    # Derive every resource edit from the immutable archive, so resume is idempotent.
    for p in GAME.rglob('*.tres'):
        text=p.read_text(encoding='utf-8');ext={}
        for path,ident in re.findall(r'\[ext_resource[^\n]*path="res://assets/sprites/characters/tocsin/([^"\n]+)" id="([^"\n]+)"\]',text):
            path=re.sub(r'_(e|shadow)\.png$','.png',path)
            if path in data['sheets']:ext[ident]=data['sheets'][path]
        def block(match):
            part=match.group();atlas=re.search(r'atlas = ExtResource\("([^"\n]+)"\)',part)
            if not atlas or atlas[1] not in ext:return part
            spec=ext[atlas[1]];c=spec['cell'];x,y,x1,y1=spec['box'];w,h=x1-x,y1-y
            region=re.search(r'region = Rect2\(([^)]+)\)',part)
            assert region, p
            rx,ry,rw,rh=[float(v) for v in region[1].split(',')]
            assert rw==rh==c and rx%c==ry%c==0,(p,region[0])
            assert 'margin =' not in part,(p,'unexpected source margin')
            value=f'region = Rect2({int(rx/c)*w}, {int(ry/c)*h}, {w}, {h})\nmargin = Rect2({x}, {y}, {c-w}, {c-h})'
            return part[:region.start()]+value+part[region.end():]
        new=re.sub(r'\[sub_resource type="AtlasTexture"[^\[]+',block,text)
        if new!=text:
            p.write_text(new,encoding='utf-8');data['resources'].append(p.relative_to(GAME).as_posix())
    for rel,spec in data['sheets'].items():
        base=GAME/rel
        for suffix,ratio in spec['passes'].items():
            p=base.with_name(base.stem+suffix+'.png')
            with Image.open(p) as im:original=im.convert('RGBA');out=transform(original,spec,ratio=ratio)
            restored=transform(out,spec,expand=True,ratio=ratio)
            # Ignore RGB under alpha zero; opaque and subpixel coverage must be lossless.
            aa,bb=np.asarray(original),np.asarray(restored)
            assert np.array_equal(aa[...,3],bb[...,3]),(rel,suffix,'alpha cropped')
            visible=aa[...,3]>0
            assert np.array_equal(aa[visible],bb[visible]),(rel,suffix,'visible pixels changed')
            out.save(p,optimize=True,compress_level=9)
            q=WORK/'characters/tocsin'/rel;q=q.with_name(q.stem+suffix+'.png');q.parent.mkdir(parents=True,exist_ok=True)
            restored.save(q,optimize=True,compress_level=9)
    data['active']=True;MANIFEST.write_text(json.dumps(data,indent=2))
    # Shared checks run on the exact logical images reconstructed from delivered storage.
    actual=cel.GAME_SPRITES
    try:
        cel.GAME_SPRITES=WORK
        for rel in data['sheets']:cel.check_sheet('characters/tocsin/'+rel,normals=False)
    finally:cel.GAME_SPRITES=actual
    report=json.loads(REPORT.read_text());report['storage_crops']=data
    report['bytes_after']=sum(p.stat().st_size for p in GAME.rglob('*.png'))
    report['raw_bytes_before']=sum(w*h*4 for w,h in state['png'].values())
    report['raw_bytes_after']=sum(Image.open(p).width*Image.open(p).height*4 for p in GAME.rglob('*.png'))
    report['budget_scope_before']={'source':'immutable 3D archive / initial state','png':state['bytes_before'],'raw':report['raw_bytes_before']}
    report['deviations']=[
        f"{sum('static_pose_duplicates' in r for r in report['checks'])} sheets have additional static duplicates after removal of PBR grain; each archive pose pair has silhouette IoU > 0.998.",
        'Portraits retain direct UI framing: no AtlasTexture margin consumer.',
        f"{len(data['resources'])} .tres have region/margin edits for lossless cell storage; packed regions, feet, sockets and JSON unchanged."]
    for check in report['checks']:
        rel=check['file'].removeprefix('characters/tocsin/')
        if rel in data['sheets']:
            check['logical_size']=check['size'];check['size']=list(Image.open(GAME/rel).size)
            check['lossless_storage_crop']=True
    REPORT.write_text(json.dumps(report,indent=2))
    print('CROP',len(data['sheets']),'RESOURCES',len(data['resources']),flush=True)

def contact():
    """Use shared A/B contact layout with large TOP frames fitted into preview cells."""
    import cel_style as cel
    state=json.loads((HERE/'_cel_heroes_tocsin_state.json').read_text())
    data=json.loads(MANIFEST.read_text());preview=WORK.parent/'contact_previews'
    oldbase,newbase=preview/'archive',preview/'cel'
    samples=[]
    for rel,size in state['png'].items():
        if '/layers/' in '/'+rel or Path(rel).stem.endswith(('_e','_n','_shadow')):continue
        c=cell_of(rel);cols,rows=size[0]//c,size[1]//c
        col=min(cols-1,2);row=2 if rows==8 else 0
        # TOP effects use a linear sequence distributed over three columns.
        if Path(rel).stem in ('head_blast_top','head_ring'):col,row=0,1
        name=rel.replace('/','__')
        for base,dst in ((ARCHIVE,oldbase),(GAME,newbase)):
            with Image.open(base/rel) as im:im=im.convert('RGBA')
            if base==GAME and rel in data['sheets']:im=transform(im,data['sheets'][rel],True)
            tile=im.crop((col*c,row*c,(col+1)*c,(row+1)*c))
            tile.thumbnail((192,192),Image.Resampling.LANCZOS)
            frame=Image.new('RGBA',(192,192));frame.paste(tile,((192-tile.width)//2,(192-tile.height)//2))
            dst.mkdir(parents=True,exist_ok=True);frame.save(dst/name)
        samples.append((name,192,0,0))
    ground=newbase/'terrain/terraces/iso/ground_a.png';ground.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png',ground)
    original=(cel.GAME_SPRITES,cel.ARCHIVE)
    path=HERE/'_cel_heroes_tocsin_contact.png'
    try:
        cel.GAME_SPRITES,cel.ARCHIVE=newbase,oldbase
        cel.contact_pair([samples[i:i+4] for i in range(0,len(samples),4)],path,size=(1920,2400))
    finally:cel.GAME_SPRITES,cel.ARCHIVE=original
    with Image.open(path) as main,Image.open(HERE/'_cs1_contact.png') as ref:
        ref=ref.crop((ref.width//2,0,ref.width,ref.height));ref.thumbnail((1920,480),Image.Resampling.LANCZOS)
        board=Image.new('RGB',(1920,2400+ref.height),(18,22,23));board.paste(main,(0,0));board.paste(ref,((1920-ref.width)//2,2400));board.save(path,optimize=True)
