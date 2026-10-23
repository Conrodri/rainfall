"""Verify the frozen asset contract and all cells; assemble one final contact sheet, no drawing."""
import hashlib,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image,ImageChops
from r5c_inventory import ROOT,NAMES,snapshot,DEST
assert json.loads(json.dumps(snapshot()))==json.loads(DEST.read_text()),'Contract changed'
counts={'idle':6,'run':8,'attack':6,'cast_a':8,'cast_b':8,'phase2':8,'death':10}
contact=Image.new('RGBA',(1360,1020),(43,51,64,255));report={}
for boss_index,name in enumerate(NAMES):
    out=ROOT/'game/assets/sprites/bosses/mini'/name
    render_report=json.loads((ROOT/'art/renders/monsters'/name/'r5c_report.json').read_text())
    assert render_report['camera_elevation']==35
    assert render_report['framing']['ground_pivot_percent']==70
    stats={'frames':0,'min_margin':999,'emissive_frames':0,'animations':{}}
    for anim,count in counts.items():
        path=out/f'{anim}.png';rows=4 if anim=='run' else 1
        with Image.open(path) as source,Image.open(path.with_stem(path.stem+'_n')) as normal,Image.open(path.with_stem(path.stem+'_e')) as emission:
            diff=source.convert('RGBA');norm=normal.convert('RGBA');emit=emission.convert('RGBA')
            assert diff.size==norm.size==emit.size==(count*170,rows*170)
            assert ImageChops.difference(diff.getchannel('A'),norm.getchannel('A')).getbbox() is None,'Normal alpha differs'
            for direction in range(rows):
                signatures=[]
                for f in range(count):
                    box=(f*170,direction*170,(f+1)*170,(direction+1)*170)
                    cell=diff.crop(box);bbox=cell.getchannel('A').point(lambda x:255 if x>8 else 0).getbbox()
                    assert bbox,'Empty frame'
                    margin=min(bbox[0],bbox[1],170-bbox[2],170-bbox[3]);stats['min_margin']=min(stats['min_margin'],margin)
                    assert margin>=4,(name,anim,direction,f,margin)
                    rgb=emit.crop(box).convert('RGB')
                    if max(v[1] for v in rgb.getextrema())>16:stats['emissive_frames']+=1
                    signatures.append(hashlib.sha256(cell.tobytes()).hexdigest());stats['frames']+=1
                assert len(set(signatures))>1,(name,anim,'static animation')
            assert norm.getpixel((0,0))==(128,128,255,0),'Normal transparent padding'
            stats['animations'][anim]={'frames':count,'directions':['e','s','w','n'] if rows==4 else ['s'],'size':170}
    assert stats['emissive_frames']>0
    with Image.open(out/'run.png') as run:
        assert len({hashlib.sha256(run.crop((0,d*170,170,(d+1)*170)).tobytes()).hexdigest() for d in range(4)})==4,'Run directions are duplicated'
    samples=[('idle',0,0,''),('run',0,1,''),('run',1,1,''),('run',2,1,''),('run',3,1,''),('attack',0,2,''),('cast_a',0,5,''),('cast_b',0,5,''),('phase2',0,6,''),('death',0,4,''),('death',0,9,''),('idle',0,0,'_n'),('idle',0,0,'_e'),('cast_a',0,5,'_e'),('cast_b',0,5,'_e'),('phase2',0,6,'_e')]
    for index,(anim,d,f,suffix) in enumerate(samples):
        with Image.open(out/f'{anim}{suffix}.png') as source:
            cell=source.convert('RGBA').crop((f*170,d*170,(f+1)*170,(d+1)*170))
        contact.alpha_composite(cell,((index%8)*170,(boss_index*2+index//8)*170))
    report[name]=stats
contact.convert('RGB').save(Path(__file__).with_name('_r5c_contact.png'))
Path(__file__).with_name('_r5c_verification.json').write_text(json.dumps(report,indent=2))
print('PASS contract, frame counts, directions, variation, normal alpha, emission, margins; contact assembled')
print(json.dumps({n:{k:v for k,v in s.items() if k!='animations'} for n,s in report.items()}))
