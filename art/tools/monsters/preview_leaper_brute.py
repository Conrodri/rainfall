"""Assemble Blender renders and verify all monster passes; no sprite drawing."""
import sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'vendor'))
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[3]
DIRS=['e','se','s','sw','w','nw','n','ne']
def main():
 for name,size,anims in [('leaper_tier2',112,['run','charge']),('brute_tier3',160,['run','attack','cast'])]:
    base=ROOT/'art/renders/monsters'/name
    # Eight directions, each full action, then all three creatures at native final scale.
    rows=1+len(anims)+1
    sheet=Image.new('RGBA',(8*160,rows*160),'#2B3340')
    def paste(path,x,y,n):
        with Image.open(path) as im:sheet.alpha_composite(im.convert('RGBA').resize((n,n),Image.Resampling.LANCZOS),(x,y))
    for j,d in enumerate(DIRS):paste(base/'run'/f'{d}_00.png',j*160+(160-size)//2,160-size,size)
    for row,anim in enumerate(anims,1):
        for i in range(8):paste(base/anim/f'se_{i:02d}.png',i*160+(160-size)//2,(row+1)*160-size,size)
    comparison={}
    for j,(other,n) in enumerate([('shooter_tier2',112),('leaper_tier2',112),('brute_tier3',160)]):
        path=ROOT/'art/renders/monsters'/other/'run'/'se_00.png'
        paste(path,j*240+40,(rows-1)*160+112-round(n*.7),n)
        with Image.open(path) as im:
            bb=im.resize((n,n),Image.Resampling.LANCZOS).getchannel('A').getbbox();comparison[other]={'visible_width':bb[2]-bb[0],'visible_height':bb[3]-bb[1]}
    sheet.convert('RGB').save(base/'_preview.png')
    report={'frames':0,'passes':0,'alpha_mismatches':[],'normal_padding_errors':0,'min_margin_final':size,'relative_size_run_se':comparison,'sheets':{}}
    for anim in anims:
      for d in DIRS:
       for i in range(8):
        path=base/anim/f'{d}_{i:02d}.png'
        with Image.open(path) as im:diff=im.convert('RGBA')
        assert diff.size==(2*size,2*size)
        report['frames']+=1
        bb=diff.resize((size,size),Image.Resampling.LANCZOS).getchannel('A').getbbox()
        report['min_margin_final']=min(report['min_margin_final'],bb[0],bb[1],size-bb[2],size-bb[3])
        for suffix in ('_n','_e'):
         with Image.open(path.with_stem(path.stem+suffix)) as im:
          assert im.size==diff.size
          if ImageChops.difference(im.getchannel('A'),diff.getchannel('A')).getbbox():report['alpha_mismatches'].append(str(path)+suffix)
          if suffix=='_n':report['normal_padding_errors']+=sum(1 for r,g,b,a in im.convert('RGBA').get_flattened_data() if a==0 and (r,g,b)!=(128,128,255))
         report['passes']+=1
      for suffix in ('','_n','_e'):
       with Image.open(ROOT/'game/assets/sprites/monsters'/name/f'{anim}{suffix}.png') as im:
        assert im.size==(size*8,size*8);report['sheets'][anim+suffix]=list(im.size)
    (base/'validation_report.json').write_text(json.dumps(report,indent=2))
    assert not report['alpha_mismatches'] and not report['normal_padding_errors'] and report['min_margin_final']>=4,report
    print(name,json.dumps(report))
if __name__=='__main__':main()
