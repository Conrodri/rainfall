"""Verify the R5a sheets and assemble one contact sheet, without drawing."""
import hashlib,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image,ImageChops
from r5a_inventory import ROOT,NAMES,snapshot,DEST
assert json.loads(json.dumps(snapshot()))==json.loads(DEST.read_text()),'Contract changed'
report={};contact=Image.new('RGBA',(1280,1280),(43,51,64,255));row=0
for name in NAMES:
    out=ROOT/'game/assets/sprites/monsters'/name
    size={'swarm_tier1':96,'shooter_tier2':112,'leaper_tier2':112,'brute_tier3':160}[name]
    stats={'frames':0,'min_margin':999,'emissive_frames':0,'animations':{}}
    for path in sorted(out.glob('*.png')):
        if path.stem.endswith(('_n','_e')):continue
        with Image.open(path) as source,Image.open(path.with_stem(path.stem+'_n')) as normal,Image.open(path.with_stem(path.stem+'_e')) as emission:
            diff=source.convert('RGBA');norm=normal.convert('RGBA');emit=emission.convert('RGBA')
            assert diff.size==(8*size,8*size)
            assert ImageChops.difference(diff.getchannel('A'),norm.getchannel('A')).getbbox() is None,'Normal alpha differs'
            for direction in range(8):
                signatures=[]
                for f in range(8):
                    box=(f*size,direction*size,(f+1)*size,(direction+1)*size)
                    cell=diff.crop(box);alpha=cell.getchannel('A');bbox=alpha.point(lambda x:255 if x>8 else 0).getbbox()
                    assert bbox,'Empty frame'
                    margin=min(bbox[0],bbox[1],size-bbox[2],size-bbox[3]);stats['min_margin']=min(stats['min_margin'],margin)
                    assert margin>=4,(name,path.stem,direction,f,margin)
                    rgb=emit.crop(box).convert('RGB');bright=rgb.getextrema()
                    if max(v[1] for v in bright)>16:stats['emissive_frames']+=1
                    signatures.append(hashlib.sha256(cell.tobytes()).hexdigest())
                    stats['frames']+=1
                assert len(set(signatures))>1,'Static animation'
            stats['animations'][path.stem]={'frames':8,'directions':['e','se','s','sw','w','nw','n','ne'],'frame_size':size}
            # Four compass views, then anticipation/impact/recovery facing south.
            samples=[(2,0),(0,0),(6,0),(4,0),(2,1),(2,3),(2,5),(2,7)]
            for col,(d,f) in enumerate(samples):
                cell=diff.crop((f*size,d*size,(f+1)*size,(d+1)*size))
                contact.alpha_composite(cell,(col*160+(160-size)//2,row*160+(160-size)//2))
            row+=1
    assert stats['emissive_frames']>0,'Missing emission'
    report[name]=stats
contact.convert('RGB').save(Path(__file__).with_name('_r5a_contact.png'))
Path(__file__).with_name('_r5a_verification.json').write_text(json.dumps(report,indent=2))
print('PASS frames, animation variation, normal alpha, emissions, margins, contract; contact assembled')
print(json.dumps({n:{k:v for k,v in s.items() if k!='animations'} for n,s in report.items()}))
