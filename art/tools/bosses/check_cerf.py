"""Read-only checks of delivered PNG encoding, motion, passes and SpriteFrames."""
from pathlib import Path
from PIL import Image, ImageChops
import json,re,math
from pack_cerf import DST,SRC,COUNTS
from r3a_contract import snapshot, INVENTORY

def main():
    assert snapshot()==json.loads(INVENTORY.read_text(encoding='utf-8')), 'R3a inventory mismatch'
    results={};total=0
    for anim,count in COUNTS.items():
        size=64 if anim in ('wisp','wisp_explode','ground_wisp_trail') else 256
        rows=4 if anim.startswith('walk') else 1
        ims=[Image.open(DST/f'{anim}{s}.png').convert('RGBA') for s in ('','_n','_e')]
        assert all(i.size==(size*count,size*rows) for i in ims),anim
        assert all(ImageChops.difference(ims[0].getchannel('A'),im.getchannel('A')).getbbox() is None for im in ims[1:]),anim
        for p in ims[1].get_flattened_data():
            if not p[3]:assert p==(128,128,255,0),(anim,p)
        # Actual normals must carry direction, rather than a neutral/empty pass.
        normals=[p for p in ims[1].get_flattened_data() if p[3]>128]
        if normals:assert max(p[0] for p in normals)-min(p[0] for p in normals)>60,anim
        emission=ims[2].convert('RGB').getbbox()
        if anim not in ('ground_mist',):assert emission,(anim,'missing emission')
        total+=count*rows
        results[anim]={'size':ims[0].size,'alpha_identical':True,'normal_background_valid':True,'emission_rgb_bbox':emission}
    text=(DST/'cerf.tres').read_text(encoding='utf-8')
    ids=re.findall(r'\[sub_resource type="AtlasTexture" id="([^"]+)"\]',text)
    refs=re.findall(r'SubResource\("([^"]+)"\)',text)
    assert len(ids)==total and len(refs)==total and set(ids)==set(refs)
    assert len(re.findall(r'\[ext_resource ',text))==len(COUNTS)
    for anim in COUNTS:assert (DST/f'{anim}.png').exists()
    report={'sheets':len(COUNTS),'png_files':3*len(COUNTS),'total_frames':total,'atlas_regions':len(ids),'checks':results}
    (SRC/'checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(f'PASS: {len(COUNTS)} sheets, {3*len(COUNTS)} PNG, {total} frames; inventory, alpha, normals, emission, atlas')
if __name__=='__main__':main()
