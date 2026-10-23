"""Freeze/check the R4 delivery contract; Pillow only inspects images."""
import hashlib, json, re, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'vendor'))
from PIL import Image
ROOT = Path(__file__).resolve().parents[3]
ASSETS = ROOT / 'game/assets/sprites/characters/ardent'
INVENTORY = Path(__file__).with_name('_r4_inventory.json')
def snapshot():
    files = {}
    for p in sorted(ASSETS.iterdir()):
        if p.is_file():
            d = {'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
            if p.suffix == '.png':
                with Image.open(p) as im: d.update(size=list(im.size), mode=im.mode)
            files[p.name] = d
    tres = (ASSETS / 'ardent.tres').read_text()
    return {'files': files, 'directions': ['e','se','s','sw','w','nw','n','ne'],
            'cell': 192, 'frames': 8, 'animations': re.findall(r'"name": &"([^"]+)"', tres)}
if __name__ == '__main__':
    current = snapshot()
    if '--inventory' in sys.argv:
        assert not INVENTORY.exists(), 'Do not overwrite initial inventory'
        INVENTORY.write_text(json.dumps(current, separators=(',', ':')))
        print('PASS initial inventory:', len(current['files']), 'files')
    else:
        initial = json.loads(INVENTORY.read_text())
        assert initial.keys() == current.keys()
        assert initial['files'].keys() == current['files'].keys()
        for name, before in initial['files'].items():
            after = current['files'][name]
            if name.endswith('.png'):
                assert before['size'] == after['size'] and before['mode'] == after['mode'], name
                assert before['sha256'] != after['sha256'], 'Unchanged sprite: '+name
            else: assert before == after, 'Modified metadata: '+name
        assert initial['animations'] == current['animations']
        raw=ROOT/'art/renders/characters/ardent'
        expected={f'{d}_{f:02d}.png' for d in current['directions'] for f in range(8)}
        for anim in ['idle','run']:
            for suffix in ['','_n','_e']:
                folder=raw/(anim+suffix)
                assert {p.name for p in folder.glob('*.png')}==expected, folder
                for name in expected:
                    with Image.open(folder/name) as im: assert im.size==(384,384), name
        for anim in ['idle','run']:
            images = [Image.open(ASSETS / (anim+s+'.png')).convert('RGBA') for s in ['', '_n', '_e']]
            assert images[0].getchannel('A').tobytes() == images[2].getchannel('A').tobytes(), 'Emission alpha'
            for row in range(8):
                frames = []
                for col in range(8):
                    box = (col*192,row*192,(col+1)*192,(row+1)*192)
                    frame = images[0].crop(box); bounds=frame.getchannel('A').getbbox()
                    assert bounds and min(bounds[:2]) >= 4 and max(bounds[2:]) <= 188, (anim,row,col,bounds)
                    frames.append(hashlib.sha256(frame.tobytes()).hexdigest())
                    emission=images[2].crop(box)
                    assert any(max(p[:3]) > 100 and p[3] > 100 for p in emission.get_flattened_data()), 'No flame'
                assert len(set(frames)) == 8, 'Frozen animation'
            normal=images[1]
            worst=0
            for r,g,b,a in list(normal.get_flattened_data())[::97]:
                if a:
                    length=sum((2*c/255-1)**2 for c in (r,g,b))**.5
                    worst=max(worst,abs(length-1))
            assert worst<.015, ('Normal length',worst)
        report={'result':'PASS','sheets':6,'size':[1536,1536],'cell':192,
                'directions':current['directions'],'frames_per_direction':8,
                'metadata_unchanged':True,'unique_frames':True,'emission_each_frame':True,
                'minimum_transparent_margin':4,'normal_unit_length_tolerance':.015,
                'files':current['files']}
        (ROOT/'art/renders/characters/ardent/r4_delivery_check.json').write_text(json.dumps(report,indent=2))
        print('PASS contract: six changed sheets, dimensions/grid/directions/frames, metadata unchanged, margins, emission, animation')
