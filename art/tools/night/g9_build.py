"""G9 delivery: existing F23 cel render, unchanged cropped atlas/alpha and emission support.

Run Blender cel_bosses_f23_build.py -- --render --g9 --resume first.
No diffuse HSV/LUT fallback. Emission uses the original mask, as in F23 delivery.
"""
from pathlib import Path
import hashlib, json, re, sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'art/tools/cel'))
import cel_style as cel
WORK = ROOT / 'art/blender/cel/g9'
DST = ROOT / 'game/assets/sprites/bosses/etage/cerf'
BEFORE = WORK / 'before'
ARCHIVE = cel.archive_folder('bosses/etage/cerf')
SPECS = json.loads((ROOT / 'art/tools/night/_cel_bosses_f23_verification.json').read_text())['crops']


def rgba(p):
    return np.array(Image.open(p).convert('RGBA'))


def iou(a, b):
    u = np.count_nonzero(a | b)
    return float(np.count_nonzero(a & b) / u) if u else 1.


def reconstruct(a, sp, ratio=1):
    cw, ch = sp['cell_before']; nw, nh = sp['cell_after']; x, y = sp['box'][:2]
    out = np.zeros((ch * sp['rows'] // ratio, cw * sp['frames'] // ratio, 4), np.uint8)
    cw, ch, nw, nh, x, y = [v // ratio for v in (cw, ch, nw, nh, x, y)]
    for r in range(sp['rows']):
        for f in range(sp['frames']):
            out[r*ch+y:r*ch+y+nh, f*cw+x:f*cw+x+nw] = a[r*nh:(r+1)*nh, f*nw:(f+1)*nw]
    return out


def emission(a):
    # Preserve alpha and exact nonblack support. Tint intensity is retained;
    # brighter mycelium cores shift from C27BFF toward E6C8FF.
    v = a[:, :, :3].max(2).astype(float) / 255
    t = np.clip((v - .72) / .28, 0, 1)[..., None]
    lo, hi = np.array([194, 123, 255]), np.array([230, 200, 255])
    out = a.copy()
    out[:, :, :3] = np.rint(((1-t)*lo + t*hi) * v[..., None]).astype(np.uint8)
    return out


def deliver():
    fringe_pixels = 0
    for p in BEFORE.glob('*.png'):
        if p.stem.endswith('_e'):
            out = emission(rgba(p))
        else:
            sp = SPECS['cerf/' + p.stem]
            candidates = [WORK / 'cerf' / lot / p.name for lot in ('C7b', 'C7d')]
            source = next(q for q in reversed(candidates) if q.exists())
            source = rgba(source)
            cw, ch = sp['cell_before']; nw, nh = sp['cell_after']; x0,y0,x1,y1 = sp['box']
            out = np.zeros_like(rgba(p))
            for r in range(sp['rows']):
                for f in range(sp['frames']):
                    out[r*nh:(r+1)*nh, f*nw:(f+1)*nw] = source[r*ch+y0:r*ch+y1, f*cw+x0:f*cw+x1]
            # Materials only: immutable cel baseline coverage, including fading frames.
            out[:, :, 3] = rgba(p)[:, :, 3]
            # Lanczos ringing can overshoot R/B around ochre/violet boundaries.
            # Correct only green fringes on newly rendered sheets, never the baseline.
            rgb = out[:, :, :3]
            fringe = (rgb[:, :, 1] > rgb[:, :, 0]) & (rgb[:, :, 1] > rgb[:, :, 2])
            fringe_pixels += int((fringe & (out[:, :, 3] > 2)).sum())
            rgb[:, :, 1][fringe] = np.maximum(rgb[:, :, 0], rgb[:, :, 2])[fringe]
        Image.fromarray(out).save(DST / p.name, compress_level=9)
    (WORK / 'fringe_cleanup.json').write_text(json.dumps({'new_render_green_fringe_pixels': fringe_pixels}))


def verify():
    report = {'method': 'Blender Eevee boss cel material rerender; original emission support tinted',
              'diffuse_lut_fallback': False, 'render_fringe_cleanup': json.loads((WORK / 'fringe_cleanup.json').read_text()), 'sheets': [], 'green_pixels': 0, 'visible_pixels': 0}
    assert {p.name for p in DST.glob('*.png')} == {p.name for p in BEFORE.glob('*.png')}
    assert not list(DST.glob('*_n.png'))
    for p in BEFORE.glob('*.tres'):
        assert p.read_bytes() == (DST / p.name).read_bytes()
        assert not re.search('CanvasTexture|normal_texture', p.read_text())
    for p in BEFORE.glob('*.png'):
        a, old = rgba(DST / p.name), rgba(p)
        assert a.shape == old.shape, p.name
        assert np.array_equal(a[:, :, 3], old[:, :, 3]), p.name
        name = p.stem.removesuffix('_e'); sp = SPECS['cerf/' + name]
        is_emission = p.stem.endswith('_e')
        diffuse = rgba(DST / (name + '.png')) if is_emission else a
        ratio = 2 if is_emission and a.shape != diffuse.shape else 1
        logical = reconstruct(a, sp, ratio)
        ref = rgba(ARCHIVE / p.name)
        assert logical.shape == ref.shape, p.name
        support = lambda z: (z[:, :, 3] > 2) if not is_emission else (z[:, :, :3].max(2).astype(float) * z[:, :, 3] / 255 > 2)
        score = iou(support(logical), support(ref))
        assert score > .97, (p.name, score)
        rgb = a[:, :, :3].astype(int); vis = a[:, :, 3] > 2
        # All green hues, including desaturated forest greens, counted.
        green = vis & (rgb[:,:,1] > rgb[:,:,0]) & (rgb[:,:,1] > rgb[:,:,2])
        report['green_pixels'] += int(green.sum()); report['visible_pixels'] += int(vis.sum())
        assert not green.any(), (p.name, int(green.sum()))
        entry = {'name': p.name, 'size': list(a.shape[1::-1]), 'archive_logical_size': list(logical.shape[1::-1]), 'archive_iou': score}
        if is_emission:
            diffuse = rgba(DST / (name + '.png'))
            assert a.shape[1::-1] in (diffuse.shape[1::-1], tuple((v+1)//2 for v in diffuse.shape[1::-1]))
            assert (rgb.max(2).astype(float)*a[:,:,3]/255).max() > 2
        else:
            nw,nh=sp['cell_after']; hashes=[]; old_hashes=[]
            for r in range(sp['rows']):
                for f in range(sp['frames']):
                    sl=(slice(r*nh,(r+1)*nh),slice(f*nw,(f+1)*nw))
                    hashes.append(hashlib.sha256(a[sl].tobytes()).hexdigest())
                    old_hashes.append(hashlib.sha256(old[sl].tobytes()).hexdigest())
            assert len(set(hashes)) >= len(set(old_hashes)), p.name
            lum=rgb[vis] @ np.array([.2126,.7152,.0722])
            entry.update(unique_frames=len(set(hashes)), luminance_p05_p95=np.percentile(lum,[5,95]).tolist())
            assert np.ptp(lum) > 8, p.name
        report['sheets'].append(entry)
    report['green_proportion']=report['green_pixels']/report['visible_pixels']
    (WORK / 'verification.json').write_text(json.dumps(report,indent=2))
    return report


def contact():
    # One final before/after board; Pillow assembly/cropping only.
    names=['idle_p1','walk_p3','spell_b_dirs','charge_dirs','antlers','ground_mist','ground_wisp_trail','wisp_bolt']
    board=Image.new('RGB',(1024,128*len(names)),(26,22,30))
    for row,name in enumerate(names):
        sp=SPECS['cerf/'+name]; w,h=sp['cell_after']
        for col,folder in enumerate((BEFORE,DST)):
            im=Image.open(folder/(name+'.png')).convert('RGBA')
            frame=im.crop((w*(sp['frames']//2),0,w*(sp['frames']//2+1),h))
            frame.thumbnail((480,120))
            board.paste(frame,(col*512+(512-frame.width)//2,row*128+(128-frame.height)//2),frame)
    path=ROOT/'art/renders/grotte/g9_avant_apres.png';path.parent.mkdir(parents=True,exist_ok=True);board.save(path)


if __name__ == '__main__':
    if '--verify' not in sys.argv:
        deliver()
    result=verify(); contact()
    print('PASS G9',len(result['sheets']),'PNG; green',result['green_proportion'],'; min archive IoU',min(x['archive_iou'] for x in result['sheets']))
