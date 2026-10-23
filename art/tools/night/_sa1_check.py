"""SA1 delivery checks/contact; no painting, only existing PNG assembly."""
import sys, json, hashlib, re
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
SPRITES=ROOT/'game/assets/sprites'
DEST=SPRITES/'characters/morfil'
OUT=ROOT/'art/tools/night'
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel
ANIMS=dict(idle=8,run=8,cut_circle=6,thrust=6,crescent=8,sharpen=8,twin_draw=8,dodge=5,hurt=3,death=8,idle_dual=8,run_dual=8,cut_circle_dual=6,thrust_dual=6,crescent_dual=8)
IMPACTS=dict(cut_circle=2,thrust=2,crescent=4,sharpen=5,twin_draw=4)

def check():
    results=[];edges=[]
    for anim,n in ANIMS.items():
        results.append(cel.check_sheet('characters/morfil/'+anim+'.png',cell=192,frames=n,rows=8,normals=False))
        with Image.open(DEST/(anim+'.png')) as im:
            for y in range(8):
                for x in range(n):
                    b=im.crop((x*192,y*192,(x+1)*192,(y+1)*192)).getbbox()
                    assert b,(anim,y,x,'empty')
                    if min(b[:2])<2 or max(b[2:])>190:edges.append((anim,y,x,b))
    assert not edges,edges[:10]
    for path in DEST.rglob('*.png'):
        with Image.open(path) as im:
            assert max(im.size)<=4096,(path,im.size)
            assert not path.stem.endswith('_n'),path
            if path.stem.endswith('_e'):
                base=path.with_name(path.stem[:-2]+'.png')
                with Image.open(base) as diffuse:
                    assert im.size in (diffuse.size,tuple((v+1)//2 for v in diffuse.size)),path
                assert max(im.convert('RGB').getextrema()[1])>0,(path,'black emission')
    for name,n,size in [('cut_circle',6,320),('cut_thrust',5,448),('cut_crescent',6,480),('twin_draw',8,352),('iai_trail',4,400),('sharpen_sparks',6,192)]:
        results.append(cel.check_sheet(f'characters/morfil/{name}/{name}.png',cell=size,frames=n,rows=1,normals=False))
    resources=[]
    for path in DEST.rglob('*.tres'):
        text=path.read_text()
        assert 'CanvasTexture' not in text and 'normal_texture' not in text,path
        for ref in re.findall(r'path="res://([^"]+)"',text):assert (ROOT/'game'/ref).exists(),ref
        resources.append(str(path.relative_to(ROOT)))
    assert len(resources)==7,len(resources)
    with Image.open(SPRITES/'ui/portraits/morfil.png') as im:assert im.size==(256,256)
    report=dict(result='PASS',character_frames=sum(ANIMS.values())*8,vfx_frames=35,resources=resources,sheets=results,clipped_frames=edges,pivot=[96,136.32],normals=False,icons='Excluded by player 2026-10-23')
    (OUT/'_sa1_verification.json').write_text(json.dumps(report,indent=2))
    print('PASS SA1 832 character frames, 35 VFX frames, 7 SpriteFrames; no clipping; no normals')

def crop(rel,cell,col=0,row=0):
    with Image.open(SPRITES/rel) as im:return im.convert('RGBA').crop((col*cell,row*cell,(col+1)*cell,(row+1)*cell))

def contact():
    # Actual terrace floor beneath every sample. No invented pixels or Pillow drawing.
    ground=Image.open(SPRITES/'terrain/terraces/iso/ground_a.png').convert('RGBA')
    canvas=Image.new('RGBA',(1536,1344),(18,22,23,255))
    for y in range(-ground.height,1344,ground.height//2):
        for x in range(-ground.width,1536,ground.width):canvas.alpha_composite(ground,(x+(ground.width//2 if (y//(ground.height//2))%2 else 0),y))
    samples=[]
    def add(im,x,y,label):
        canvas.alpha_composite(im,(x,y));samples.append(dict(x=x,y=y,label=label))
    for row,d in enumerate(cel.DIRS):add(crop('characters/morfil/idle.png',192,0,row),row*192,0,'idle_'+d)
    for i,(anim,n) in enumerate(ANIMS.items()):
        f=IMPACTS.get(anim.replace('_dual',''),n//2)
        add(crop('characters/morfil/'+anim+'.png',192,f,2),(i%8)*192,192+(i//8)*192,anim+' frame '+str(f))
    refs=[('characters/ardent/idle.png',192),('characters/rictus/idle.png',192),('monsters/swarm_tier1/run.png',96)]
    for i,(rel,size) in enumerate(refs):add(crop(rel,size,0,2),i*192+(192-size)//2,576+136-round(size*.71),rel)
    add(Image.open(SPRITES/'ui/portraits/morfil.png').convert('RGBA'),640,560,'Taliant portrait 256')
    add(Image.open(SPRITES/'ui/portraits/rictus.png').convert('RGBA'),928,560,'Rictus portrait 256')
    names=[('cut_circle',320),('cut_thrust',448),('cut_crescent',480),('twin_draw',352),('iai_trail',400),('sharpen_sparks',192)]
    for i,(name,size) in enumerate(names):
        im=crop(f'characters/morfil/{name}/{name}.png',size,2)
        im.thumbnail((248,248),Image.Resampling.LANCZOS);add(im,i*256+(256-im.width)//2,824+(248-im.height)//2,name)
    references=['art/tools/iso/_c4_contact.png','art/tools/characters/_m2_contact.png','art/tools/iso/_c1_contact.png','art/tools/night/_cs1_contact.png']
    for i,rel in enumerate(references):
        with Image.open(ROOT/rel) as src:
            im=src.convert('RGBA')
            if '_cs1_' in rel:im=im.crop((im.width//2,0,im.width,im.height))
            im.thumbnail((370,240),Image.Resampling.LANCZOS);add(im,i*384+(384-im.width)//2,1096,rel)
    canvas.convert('RGB').save(OUT/'_sa1_contact.png',optimize=True)
    (OUT/'_sa1_contact.json').write_text(json.dumps(samples,indent=1))
    print('PASS art/tools/night/_sa1_contact.png')

if __name__=='__main__':
    if '--contact' in sys.argv:contact()
    else:check()
