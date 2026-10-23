"""C5 contract verification and assembly-only contact."""
import json,hashlib
from pathlib import Path
from PIL import Image,ImageChops
ROOT=Path(__file__).resolve().parents[3]
INV=ROOT/'art/tools/iso/_c5_inventory.json'
def verify():
    data=json.loads(INV.read_text());old=json.loads((ROOT/'art/tools/monsters/_r5a_inventory.json').read_text());count=0
    for name,c in data.items():
        base=ROOT/'game/assets/sprites/monsters'/name;n=c['size'];margins=[]
        assert {p.name for p in base.glob('*.png')}=={k for k in old[name] if k.endswith('.png')},name
        for k,v in old[name].items():
            p=base/k
            if k.endswith('.png'):
                with Image.open(p) as im:assert list(im.size)==v['size'],str(p)
            else:assert hashlib.sha256(p.read_bytes()).hexdigest()==v['sha256'],str(p)
        for a in c['anims']:
            ims={s:Image.open(base/f'{a}{s}.png').convert('RGBA') for s in ('','_n','_e')}
            assert max(ch.getextrema()[1] for ch in ims['_e'].split()[:3])>0
            for d in range(8):
                hashes=[]
                for f in range(8):
                    box=(f*n,d*n,(f+1)*n,(d+1)*n);tile=ims[''].crop(box)
                    hashes.append(hashlib.sha256(tile.tobytes()).hexdigest());bb=tile.getchannel('A').point(lambda x:255 if x>16 else 0).getbbox();assert bb
                    margin=min(bb[0],bb[1],n-bb[2],n-bb[3]);assert margin>=4,(name,a,d,f,bb);margins.append(margin)
                    for suffix in ('_n','_e'):
                        diff=ImageChops.difference(tile.getchannel('A'),ims[suffix].crop(box).getchannel('A'))
                        assert diff.getextrema()[1]<=2,(name,a,d,f,suffix,'alpha')
                    count+=1
                assert len(set(hashes))==8,(name,a,d,'duplicate frames')
        ratio=90.50966799187809/c['render_px_per_u'];bb=c['bounds'];candidate=[n*.5+(bb[0]-n*.5)*ratio,n*.7+(bb[1]-n*.7)*ratio,n*.5+(bb[2]-n*.5)*ratio,n*.7+(bb[3]-n*.7)*ratio]
        c['bounds_at_90_51']=candidate;c['fits_at_90_51']=min(candidate[:2])>=4 and max(candidate[2:])<=n-4
        if c['render_px_per_u']==64:assert not c['fits_at_90_51']
        c['camera_elevation_degrees']=30;c['normal_space']='screen: right, up, toward camera';c['contact_samples']=['run s frame 0',('attack s frame 5' if 'attack' in c['anims'] else 'charge s frame 5' if 'charge' in c['anims'] else 'run s frame 4 (no attack in original contract)')]
        c['minimum_alpha_margin']=min(margins);c['verification']='PASS dimensions, names, directions, unique frames, alpha, emission, original tres/import hashes'
    INV.write_text(json.dumps(data,indent=2))
    ppu=90.50966799187809;canvas=Image.new('RGBA',(1600,1060),(20,24,27,255))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    for total in range(5):
        for i in range(3):
            j=total-i
            if 0<=j<3:canvas.alpha_composite(ground,(800+(i-j)*256-256,550+(i+j-2)*128-128))
    boss=ROOT/'game/assets/sprites/bosses/mini/ash_lord'
    report=json.loads((ROOT/'art/renders/monsters/ash_lord/build_report.json').read_text())
    bsize=round(report['framing']['ortho_scale']*ppu)
    with Image.open(boss/'run.png') as im:b=im.convert('RGBA').crop((0,170,170,340)).resize((bsize,bsize),Image.Resampling.LANCZOS)
    canvas.alpha_composite(b,(800-bsize//2,430-round(bsize*.70)))
    for k,(name,c) in enumerate(data.items()):
        n=c['size'];sz=round(n*ppu/c['render_px_per_u']);x=350+k*300
        samples=[('run',0,560),('attack' if 'attack' in c['anims'] else 'charge' if 'charge' in c['anims'] else 'run',5 if len(c['anims'])>1 else 4,720)]
        for a,f,y in samples:
            x=(440+k*240) if y==720 else (350+k*300)
            with Image.open(ROOT/'game/assets/sprites/monsters'/name/f'{a}.png') as im:tile=im.convert('RGBA').crop((f*n,2*n,(f+1)*n,3*n)).resize((sz,sz),Image.Resampling.LANCZOS)
            canvas.alpha_composite(tile,(x-sz//2,y-round(sz*.7)))
    canvas.save(ROOT/'art/tools/iso/_c5_contact.png',optimize=True,compress_level=9)
    print('PASS C5',len(data),'monsters;',count,'frames x 3 passes; original tres/import hashes; contact assembled')
if __name__=='__main__':verify()


