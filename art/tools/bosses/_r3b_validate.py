from pathlib import Path
import ast,json,hashlib,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
DST=ROOT/'game/assets/sprites/bosses/etage/sonneur'
INV=Path(__file__).with_name('_r3b_inventory.json')
ns={};tree=ast.parse(Path(__file__).with_name('pack_sonneur.py').read_text(encoding='utf-8'))
for node in tree.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ('COUNTS','SIZES') for t in node.targets):exec(compile(ast.Module(body=[node],type_ignores=[]),'spec','exec'),ns)
def snapshot():
    items=[]
    for p in sorted(DST.glob('*.png')):
        name=p.stem
        if name.endswith(('_n','_e')):name=name[:-2]
        n=ns['COUNTS'][name];w,h=ns['SIZES'].get(name,(256,256));rows=4 if name.startswith('walk') else 1
        with Image.open(p) as im:
            assert im.size==(w*n,h*rows),(p.name,im.size)
            items.append(dict(name=p.name,size=list(im.size),frames=n*rows,columns=n,rows=rows,frame_size=[w,h]))
    return dict(files=items,tres_sha256=hashlib.sha256((DST/'sonneur.tres').read_bytes()).hexdigest())
if '--capture' in sys.argv:
    assert not INV.exists(),'inventory already exists'
    INV.write_text(json.dumps(snapshot(),indent=2),encoding='utf-8');print('PASS inventory captured:',len(snapshot()['files']),'PNG')
else:
    original=json.loads(INV.read_text());assert snapshot()==original,'contract mismatch'
    from PIL import ImageChops
    total=0
    for item in original['files']:
        p=DST/item['name']
        with Image.open(p) as im:a=im.convert('RGBA')
        if p.stem.endswith(('_n','_e')):
            base=DST/(p.stem[:-2]+'.png')
            with Image.open(base) as im:b=im.convert('RGBA')
            assert ImageChops.difference(a.getchannel('A'),b.getchannel('A')).getbbox() is None,p.name+' alpha'
            if p.stem.endswith('_n'):assert all(px[:3]==(128,128,255) for px in getattr(a,'get_flattened_data',a.getdata)() if px[3]==0),p.name+' background'
        w,h=item['frame_size']
        for y in range(item['rows']):
            for x in range(item['columns']):assert a.crop((x*w,y*h,(x+1)*w,(y+1)*h)).getchannel('A').getbbox(),p.name+' empty'
        total+=1
    print('PASS contract, alpha, normal backgrounds, nonempty frames:',total,'PNG; tres unchanged')
