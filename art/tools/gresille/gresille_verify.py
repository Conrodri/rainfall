"""Read-only concept checks and a single small board preview, no drawing."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageStat,ImageChops
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'art/renders/gresille'
def main():
    report={};hashes=[];silhouettes=[]
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
                if label=='sprite':
                    hashes.append(hashlib.sha256(im.tobytes()).hexdigest())
                    silhouettes.append(im.getchannel('A').point(lambda v:255 if v>127 else 0))
        for label in ['sprite','big']:
            p=OUT/f'{label}_{k}_e.png'
            with Image.open(p) as e,Image.open(OUT/f'{label}_{k}.png') as d:
                assert e.size in [d.size,tuple((v+1)//2 for v in d.size)]
                signal=e.convert('RGB')
                if 'A' in e.getbands():signal=ImageChops.multiply(signal,Image.merge('RGB',[e.getchannel('A')]*3))
                assert max(signal.getextrema()[c][1] for c in range(3))>2,(p,'black')
    assert len(set(hashes))==3,'duplicate variants'
    for a,b in [(0,1),(0,2),(1,2)]:
        difference=ImageChops.difference(silhouettes[a],silhouettes[b])
        assert difference.histogram()[255]>25,'silhouettes differ only in colour'
    assert not list(OUT.glob('*_n*.png')),'normal map'
    board=OUT/'planche_silhouettes.png'
    with Image.open(board) as im:assert im.size==(2400,1350)
    assert board.stat().st_size<2*1024*1024,'board exceeds 2 MiB'
    # One contact sheet: A/B/C large views, native sprites, existing Vigie/Ardent.
    # Preview assembly only: delivered assets are never resized here.
    preview=Image.new('RGBA',(1024,960),(23,33,45,255))
    for i,k in enumerate('ABC'):
        with Image.open(OUT/f'big_{k}.png') as im:
            cut=im.crop(im.getchannel('A').getbbox());cut.thumbnail((325,600))
            preview.alpha_composite(cut,(i*341+(341-cut.width)//2,600-cut.height))
        with Image.open(OUT/f'sprite_{k}.png') as im:preview.alpha_composite(im,(i*200,615))
        with Image.open(OUT/f'jeu_{k}.png') as im:
            cut=im.convert('RGBA');cut.thumbnail((320,128))
            preview.alpha_composite(cut,(i*341+10,818))
    for i,k in enumerate(['vigie','ardent']):
        with Image.open(ROOT/f'game/assets/sprites/characters/{k}/attack.png') as im:
            preview.alpha_composite(im.crop((0,0,192,192)),(620+i*200,615))
    preview.convert('RGB').save(OUT/'controle.png',optimize=True)
    assert (ROOT/'art/blender/characters/gresille_concept.blend').is_file()
    (OUT/'verification.json').write_text(json.dumps(report,indent=2),encoding='utf8')
    print('PASS dimensions, alpha, framing, contrast, 3 distinct silhouettes, 6 emission masks, no normals, board <2 MiB')
if __name__=='__main__':main()
