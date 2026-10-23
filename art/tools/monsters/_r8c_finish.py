"""R8c contract verification and assembly-only contact, using the R8c scanner."""
import json,hashlib
from pathlib import Path
from PIL import Image
from _r8c_check import ROOT,OUT,INV,scan
HERE=Path(__file__).resolve().parent
SPECS={'idle':(6,['s']),'run':(8,['e','s','w','n']),'attack':(6,['s']),'cast_a':(8,['s']),'cast_b':(8,['s']),'phase2':(8,['s']),'death':(10,['s'])}
NAMES=('rust_archon',)

def main():
    before=json.loads(INV.read_text())['files'];reports={}
    for name in NAMES:
        out=OUT/name
        for p in out.glob('*.png'):
            with Image.open(p) as im:im.save(p,optimize=True,compress_level=9)
        margins=[];unique=[];frames=0;occupancy={}
        for anim,(count,dirs) in SPECS.items():
            sheets=[Image.open(out/f'{anim}{suffix}.png').convert('RGBA') for suffix in ('','_n','_e')]
            assert all(im.size==(count*170,len(dirs)*170) for im in sheets),(name,anim,'grid')
            assert sheets[0].getchannel('A').tobytes()==sheets[1].getchannel('A').tobytes()==sheets[2].getchannel('A').tobytes(),(name,anim,'alpha')
            assert sheets[2].getextrema()[1][1]>20,(name,anim,'black emission')
            assert all(r>=g and g+2>=b for r,g,b,a in sheets[2].get_flattened_data() if a>32 and max(r,g,b)>32),(name,anim,'accent colour')
            for row,dr in enumerate(dirs):
                hashes=[]
                for i in range(count):
                    tile=sheets[0].crop((i*170,row*170,(i+1)*170,(row+1)*170));bb=tile.getchannel('A').getbbox()
                    assert bb,(name,anim,dr,i,'empty')
                    margin=min(bb[0],bb[1],170-bb[2],170-bb[3]);margins.append(margin)
                    assert margin>=4,(name,anim,dr,i,'clipping',bb)
                    hashes.append(hashlib.sha256(tile.tobytes()).hexdigest());frames+=1
                    if anim=='idle' and i==0:occupancy={'bounds':bb,'alpha_pixels':sum(v>32 for v in tile.getchannel('A').get_flattened_data())}
                    for suffix in ('','_n','_e'):
                        p=ROOT/'art/renders/monsters'/name/anim/f'{dr}_{i:02}{suffix}.png'
                        with Image.open(p) as src:assert src.size==(340,340),(str(p),'size')
                assert len(set(hashes))==count,(name,anim,dr,'duplicate')
                unique.append({'animation':anim,'direction':dr,'frames':count,'unique':len(set(hashes))})
        reports[name]={'frames':frames,'passes':3,'minimum_margin':min(margins),'unique_frames':unique,'idle_occupancy':occupancy}
    now=scan();assert before.keys()==now.keys(),'file set changed'
    for n,v in before.items():
        if n.endswith('.png'):assert all(v[k]==now[n][k] for k in ('size','mode','grid')),n
        else:assert v['sha256']==now[n]['sha256'],n
    # Exactly the same physical scale (70px/world unit) across all references.
    canvas=Image.new('RGBA',(1600,800),(25,27,29,255));ppu=70
    cells=[('ash_lord','idle',0,0),('sonneur','idle_p1',0,0),('bramble_queen','idle',0,0),('rust_archon','idle',0,0),
           ('rust_archon','attack',3,0),('rust_archon','cast_a',4,0),('rust_archon','cast_b',4,0),('rust_archon','idle_e',0,0)]
    for k,(name,anim,frame,row) in enumerate(cells):
        if name=='sonneur':size=256;ortho=5.3;p=ROOT/f'game/assets/sprites/bosses/etage/sonneur/{anim}.png'
        else:
            size=170;p=OUT/name/f'{anim}.png'
            ortho=json.loads((ROOT/'art/renders/monsters'/name/'build_report.json').read_text())['framing']['ortho_scale']
        with Image.open(p) as im:tile=im.convert('RGBA').crop((frame*size,row*size,(frame+1)*size,(row+1)*size))
        pixels=round(ortho*ppu);tile=tile.resize((pixels,pixels),Image.Resampling.LANCZOS)
        x=(k%4)*400+(400-pixels)//2;y=(k//4)*400+350-round(pixels*.70)
        canvas.alpha_composite(tile,(x,y))
    canvas.convert('RGB').save(HERE/'_r8c_contact.png',optimize=True,compress_level=9)
    report={'contract':'PASS','files':len(now),'creatures':reports,'camera_elevation':30,'contact_pixels_per_world_unit':ppu,
            'contact_cells':[f'{n}/{a}' for n,a,_,_ in cells],
            'tres_unchanged':{n:now[str(Path(n)/f'{n}.tres')]['sha256'] for n in NAMES}}
    (HERE/'_r8c_verification.json').write_text(json.dumps(report,indent=2))
    print('PASS R8c: contract, 78 frames x 3 passes, margins, unique frames, emission, alpha; contact assembled')

if __name__=='__main__':main()
