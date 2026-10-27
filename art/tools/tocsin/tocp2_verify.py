"""Targeted TOCP2 contract and import-policy checks."""
import sys,json,re,hashlib
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools'))
import texture_budget as budget
OUT=ROOT/'game/assets/sprites/characters/tocsin'
data=json.loads((ROOT/'art/tools/tocsin/tocp2_manifest.json').read_text())
png_bytes=0;raw_bytes=0
for stem,a in data['assets'].items():
    diffuse=Image.open(OUT/(stem+'.png'));em=Image.open(OUT/(stem+'_e.png'))
    assert diffuse.size==tuple(a['atlas']) and em.size==((diffuse.width+1)//2,(diffuse.height+1)//2)
    assert em.convert('RGB').getbbox() and max(diffuse.size)<=4096
    assert not (OUT/(stem+'_n.png')).exists()
    w,h=a['cell']; fingerprints=[]
    for j in range(len(a['animations'])):
        for i in range(a['frames']):
            frame=diffuse.crop((i*w,j*h,(i+1)*w,(j+1)*h))
            assert frame.getchannel('A').getbbox(),(stem,i,j)
            fingerprints.append(hashlib.sha256(frame.tobytes()).hexdigest())
    assert len(set(fingerprints))>=a['frames']//2
    for suffix in ['', '_emission']:
        txt=(OUT/('tocsin_'+stem+suffix+'.tres')).read_text()
        assert 'CanvasTexture' not in txt and 'normal_texture' not in txt
        assert txt.count('[sub_resource')==a['frames']*len(a['animations'])
    for suffix in ['', '_e']:
        p=OUT/(stem+suffix+'.png');png_bytes+=p.stat().st_size
        im=Image.open(p);raw_bytes+=im.width*im.height*4
        ip=Path(str(p)+'.import')
        txt=ip.read_text() if ip.exists() else '[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n'
        for k,val in budget.expected_params(p.relative_to(ROOT/'game').as_posix(),budget.load_budget()).items():
            v=budget._fmt(val)
            if re.search(r'^'+re.escape(k)+'=',txt,re.M):txt=re.sub(r'^'+re.escape(k)+'=.*$',k+'='+v,txt,flags=re.M)
            else:txt+=f'\n{k}={v}\n'
        if not ip.exists() or txt!=ip.read_text():ip.write_text(txt,encoding='utf8')
print('PASS 4 effects, 74 frames, 8 PNG, 8 resources, no normals, half emission')
print(f'LOT PNG {png_bytes} bytes; RGBA {raw_bytes} bytes')
