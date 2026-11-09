"""Read-only concept checks and a single small board preview, no drawing."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageStat
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/renders/gresille'
def main():
    report={};hashes=[]
    for k in 'ABC':
        for label,size in [('sprite',(192,192)),('big',(900,930)),('jeu',(480,192))]:
            p=OUT/f'{label}_{k}.png'
            with Image.open(p) as im:
                assert im.size==size,(p,im.size)
                if label!='jeu':
                    alpha=im.getchannel('A');box=alpha.getbbox();assert box,(p,'empty')
                    assert box[0]>0 and box[1]>0 and box[2]<size[0] and box[3]<size[1],(p,'clipped',box)
                    assert alpha.getextrema()==(0,255),(p,'alpha')
                    opaque=im.convert('RGB').crop(box)
                    assert max(ImageStat.Stat(opaque).stddev)>15,(p,'contrast')
                    report[p.name]={'size':size,'bbox':box}
                if label=='sprite':hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
        for label in ['sprite','big']:
            p=OUT/f'{label}_{k}_e.png'
            with Image.open(p) as e,Image.open(OUT/f'{label}_{k}.png') as d:
                assert e.size in [d.size,tuple((v+1)//2 for v in d.size)]
                assert max(e.convert('RGB').getextrema()[c][1] for c in range(3))>2,(p,'black')
    assert len(set(hashes))==3,'duplicate variants'
    assert not list(OUT.glob('*_n*.png')),'normal map'
    with Image.open(OUT/'planche_silhouettes.png') as im:
        assert im.size==(2400,1350)
        im.thumbnail((960,540));im.save(OUT/'controle.png')
    assert (ROOT/'art/blender/characters/gresille_concept.blend').is_file()
    (OUT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('PASS dimensions, alpha, framing, contrast, 3 distinct silhouettes, 6 emission masks, no normals')
if __name__=='__main__':main()
