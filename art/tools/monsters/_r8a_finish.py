"""R8a: contractual check, lossless PNG optimisation and assembly-only contact sheet.
Contact rows: cerf / sonneur / eclusier / ash_lord idle;
attack / meteors / flame wall / phase2; run east / run north / death / idle emission.
Every cell uses 60 pixels per world unit; no sprite painting.
"""
import json,hashlib
from pathlib import Path
from PIL import Image
from _r8a_check import ROOT,OUT,INV,scan
HERE=Path(__file__).resolve().parent
SPECS={'idle':(6,['s']),'run':(8,['e','s','w','n']),'attack':(6,['s']),'cast_a':(8,['s']),'cast_b':(8,['s']),'phase2':(8,['s']),'death':(10,['s'])}
def main():
    before=json.loads(INV.read_text())['files'];now=scan();assert before.keys()==now.keys()
    for p in OUT.glob('*.png'):
        with Image.open(p) as src:
            im=src.copy();im.save(p,optimize=True,compress_level=9)
    now=scan()
    for n,old in before.items():
        if n.endswith('.png'):assert all(old[k]==now[n][k] for k in ('size','mode','grid')),n
        else:assert old['sha256']==now[n]['sha256'],n
    frames=0;margins=[];different=[]
    for anim,(count,dirs) in SPECS.items():
        sheets=[Image.open(OUT/f'{anim}{suffix}.png').convert('RGBA') for suffix in ('','_n','_e')]
        assert sheets[0].size==(count*170,len(dirs)*170)
        assert sheets[0].getchannel('A').tobytes()==sheets[1].getchannel('A').tobytes()==sheets[2].getchannel('A').tobytes(),anim+' alpha mismatch'
        for row,dr in enumerate(dirs):
            hashes=[]
            for i in range(count):
                tile=sheets[0].crop((i*170,row*170,(i+1)*170,(row+1)*170));bbox=tile.getchannel('A').getbbox()
                assert bbox, (anim,dr,i,'empty diffuse')
                margin=min(bbox[0],bbox[1],170-bbox[2],170-bbox[3]);margins.append(margin)
                assert margin>=4,(anim,dr,i,'clipping',bbox)
                hashes.append(hashlib.sha256(tile.tobytes()).hexdigest());frames+=1
                for suffix in ('','_n','_e'):
                    p=ROOT/'art/renders/monsters/ash_lord'/anim/f'{dr}_{i:02}{suffix}.png'
                    assert p.exists()
                    with Image.open(p) as im:assert im.size==(340,340)
            different.append({'animation':anim,'direction':dr,'unique_frames':len(set(hashes)),'frames':count})
            assert len(set(hashes))==count,(anim,dr,'duplicate frames')
        assert sheets[2].getextrema()[0][1]>10,anim+' black emission'
        assert all(r>=g>=b for r,g,b,a in sheets[2].get_flattened_data() if a>20 and max(r,g,b)>20),anim+' non-orange emission'
    report=json.loads((ROOT/'art/renders/monsters/ash_lord/build_report.json').read_text())
    scale=report['framing']['ortho_scale'];ppu=60
    canvas=Image.new('RGBA',(1600,900),(25,27,29,255))
    cells=[('cerf','idle_p1',0,0,5.1,.70),('sonneur','idle_p1',0,0,5.3,.65),('eclusier','idle_p1',0,0,6.4,.62),
           ('ash_lord','idle',0,0,scale,.70),('ash_lord','attack',2,0,scale,.70),('ash_lord','cast_a',4,0,scale,.70),
           ('ash_lord','cast_b',5,0,scale,.70),('ash_lord','phase2',4,0,scale,.70),('ash_lord','run',2,0,scale,.70),
           ('ash_lord','run',2,3,scale,.70),('ash_lord','death',9,0,scale,.70),('ash_lord','idle_e',0,0,scale,.70)]
    for k,(name,anim,frame,row,ortho,pivot) in enumerate(cells):
        size=170 if name=='ash_lord' else 256
        p=OUT/f'{anim}.png' if name=='ash_lord' else ROOT/f'game/assets/sprites/bosses/etage/{name}/{anim}.png'
        with Image.open(p) as im:tile=im.convert('RGBA').crop((frame*size,row*size,(frame+1)*size,(row+1)*size))
        pixels=round(ortho*ppu);tile=tile.resize((pixels,pixels),Image.Resampling.LANCZOS)
        x=(k%4)*400+(400-pixels)//2;y=(k//4)*300+260-round(pixels*pivot)
        canvas.alpha_composite(tile,(x,y))
    canvas.convert('RGB').save(HERE/'_r8a_contact.png',optimize=True,compress_level=9)
    summary={'contract':'PASS','files':len(now),'rendered_frames':frames,'passes':3,'minimum_margin_px':min(margins),
             'tres_sha256':now['ash_lord.tres']['sha256'],'old_png_bytes':sum(v['bytes'] for n,v in before.items() if n.endswith('.png')),
             'new_png_bytes':sum(v['bytes'] for n,v in now.items() if n.endswith('.png')),'unique_frames':different,
             'camera_elevation_degrees':30,'rig':'C0 CREA','contact_world_pixels_per_unit':ppu,
             'contact_rows':[[c[0]+'/'+c[1] for c in cells[i:i+4]] for i in range(0,12,4)]}
    (HERE/'_r8a_verification.json').write_text(json.dumps(summary,indent=2))
    print('PASS contract; 78 frames x 3 passes; alpha matching; no clipping or duplicates; optimised PNG; contact assembled')
if __name__=='__main__':main()
