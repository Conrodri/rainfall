"""Targeted AR1 validation; Pillow only inspects, crops and assembles."""
import hashlib,json,re
from pathlib import Path
from PIL import Image,ImageStat
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/characters/arpenteuse'
RAW=ROOT/'art/blender/characters/arpenteuse_frames'
SPEC={'plant':(5,2,10,[5,5,4,8,8]),'loop':(6,2,12,[4,4,5,6,6,6]),'whip':(8,4,14,[4,4,4,4,8,9,9,8])}
def verify(contact=False):
    before=json.loads((ROOT/'art/tools/night/ar1_action_before.json').read_text())
    boxes=json.loads((RAW/'packing.json').read_text());text=(OUT/'arpenteuse.tres').read_text()
    errors=[];result={};check=lambda ok,msg:errors.append(msg) if not ok else None
    for name,digest in before['protected'].items():check(hashlib.sha256((OUT/name).read_bytes()).hexdigest()==digest,name+' modified')
    check('CanvasTexture' not in text and 'normal_texture' not in text,'normal resource')
    resource_ids=re.findall(r'\[sub_resource[^\n]* id="([^"]+)"',text)
    check(len(resource_ids)==len(set(resource_ids)),'duplicate resource IDs')
    check(all(s in resource_ids for s in re.findall(r'SubResource\("([^"]+)"\)',text)),'unresolved resource')
    check(not list(OUT.glob('*_n.png')),'normal files')
    check(not [p for p in OUT.glob('*.png') if any(s in p.stem for s in ('__Image','_fix'))],'temporary files')
    for a,(n,hit,speed,times) in SPEC.items():
        im=Image.open(OUT/(a+'.png')).convert('RGBA');em=Image.open(OUT/(a+'_e.png')).convert('RGBA')
        l,t,r,b=boxes[a];cw,ch=r-l,b-t
        check(im.size==(cw*n,ch*8),a+' packed dimensions')
        check(em.size==((im.width+1)//2,(im.height+1)//2),a+' emission dimensions')
        check(max(em.getextrema()[c][1] for c in range(3))>0,a+' empty emission')
        check((OUT/(a+'.png')).stat().st_size<=before['sizes'][a]*1.3,a+' weight >130%')
        for row,d in enumerate(('e','se','s','sw','w','nw','n','ne')):
            hashes=[];areas=[];bounds=[];emission_peaks=[]
            for f in range(n):
                frame=Image.open(RAW/a/f'{d}_{f:02}.png').convert('RGBA');check(frame.size==(192,192),a+' cell !=192')
                alpha=frame.getchannel('A');bb=alpha.point(lambda v:255 if v>16 else 0).getbbox();bounds.append(bb)
                check(bb is not None,a+' empty frame');check(min(bb[:2])>=3 and max(bb[2:])<=189,f'{a}/{d}/{f} clipped {bb}')
                areas.append((bb[2]-bb[0])*(bb[3]-bb[1]));hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
                check(alpha.getextrema()==(0,255),a+' alpha')
                rgb=frame.convert('RGB');ext=rgb.getextrema();check(max(v[1]-v[0] for v in ext)>60,a+' contrast')
                packed=im.crop((f*cw,row*ch,(f+1)*cw,(row+1)*ch));check(packed.tobytes()==frame.crop((l,t,r,b)).tobytes(),a+' packed content')
                with Image.open(RAW/a/f'{d}_{f:02}_e.png') as accent:
                    emission_peaks.append(max((p[0] for p in accent.convert('RGBA').get_flattened_data() if p[3]>200),default=0))
            check(len(set(hashes))==n,a+'/'+d+' duplicate')
            check(areas[hit]==max(areas),f'{a}/{d} impact not largest {areas}')
            check(emission_peaks[hit]>max(emission_peaks[:hit]+emission_peaks[hit+1:]),a+'/'+d+' impact emission')
            m=re.search(r'\{"frames": \[([^\]]*)\], "loop": (?:true|false), "name": &"'+a+'_'+d+r'", "speed": ([\d.]+)\}',text,re.S)
            check(m is not None,a+'/'+d+' missing animation')
            if m:
                durations=[float(x) for x in re.findall(r'"duration": ([\d.]+)',m[1])]
                check(len(durations)==n and all(abs(x-y*speed/60)<.00001 for x,y in zip(durations,times)),a+' durations')
                for sid in re.findall(r'SubResource\("([^"]+)"\)',m[1]):check(f'id="{sid}"' in text,a+' missing atlas '+sid)
        result[a]={'frames':n,'size':im.size,'bytes':(OUT/(a+'.png')).stat().st_size,'box':boxes[a]}
    report={'result':'FAIL' if errors else 'PASS','errors':errors,'animations':result,'frames':152}
    (ROOT/'art/tools/night/ar1_action_verification.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report))
    if contact:
        # One board, each row: idle SE followed by action SE, 96 px thumbnails.
        board=Image.new('RGBA',(864,288),(30,29,27,255))
        idle=Image.open(OUT/'idle.png').convert('RGBA')
        m=re.search(r'\{"frames": \[([^\]]*)\], "loop": true, "name": &"idle_se"',text,re.S)
        sid=re.search(r'SubResource\("([^"]+)"\)',m[1])[1]
        block=re.search(r'\[sub_resource type="AtlasTexture" id="'+sid+r'"\](.*?)(?=\[)',text,re.S)[1]
        x,y,w,h=map(int,re.search(r'region = Rect2\(([^)]+)\)',block)[1].split(','));ml,mt,_,_=map(int,re.search(r'margin = Rect2\(([^)]+)\)',block)[1].split(','))
        idlecell=Image.new('RGBA',(192,192));idlecell.paste(idle.crop((x,y,x+w,y+h)),(ml,mt))
        for row,(a,(n,_,_,_)) in enumerate(SPEC.items()):
            board.alpha_composite(idlecell.resize((96,96)),(0,row*96))
            for f in range(n):
                frame=Image.open(RAW/a/f'se_{f:02}.png').convert('RGBA').resize((96,96))
                board.alpha_composite(frame,((f+1)*96,row*96))
        board.convert('RGB').save(ROOT/'art/tools/night/ar1_action_contact.png',optimize=True)
    return not errors
if __name__=='__main__':
    import sys
    sys.exit(0 if verify('--contact' in sys.argv) else 1)
