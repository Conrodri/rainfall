"""Resize/optimize/assemble/check only; never paint sprite pixels."""
from pathlib import Path
from PIL import Image, ImageChops
import hashlib, json

ROOT=Path(r'C:\Users\const\Documents\Rainfall\.claude\worktrees\agent-a00f1c2bdb6d72b46')
WORK=ROOT/'art/renders/status_fx'
OUT=ROOT/'game/assets/sprites/vfx/status'
OUT.mkdir(parents=True,exist_ok=True)
FAMILIES=[('poison_bubble',32,32,4),('burn_flame',32,48,4),('burn_ember',16,16,2),('burn_ash',24,24,4),('wet_drip',16,32,4),('shock_arc',64,64,4),('stun_star',32,32,2)]
board=Image.new('RGBA',(800,700),'#252B33')
report=[]; errors=[]; total=0
for row,(family,w,h,count) in enumerate(FAMILIES):
    hashes=set()
    for i in range(1,count+1):
        name=f'{family}_{i:02}.png'
        raw=Image.open(WORK/'raw'/name).convert('RGBA')
        assert raw.size==(w*2,h*2)
        im=raw.resize((w,h),Image.Resampling.LANCZOS)
        im.save(OUT/name,optimize=True,compress_level=9)
        im=Image.open(OUT/name)
        alpha=im.getchannel('A'); box=alpha.getbbox()
        margin=min(box[0],box[1],w-box[2],h-box[3]) if box else -1
        pixels=[p for p in im.get_flattened_data() if p[3]>80]
        rgb_ranges=[max(p[c] for p in pixels)-min(p[c] for p in pixels) for c in range(3)]
        contrast=max(rgb_ranges)
        digest=hashlib.sha256(im.tobytes()).hexdigest();hashes.add(digest)
        if im.mode!='RGBA' or im.size!=(w,h) or margin<2 or (alpha.getextrema()[0]!=0 or alpha.getextrema()[1]<160) or contrast<20:
            errors.append(f'{name}: margin={margin}, alpha={alpha.getextrema()}, contrast={contrast}')
        if family=='shock_arc':
            if any(p[0]>p[1]+12 and p[2]>p[1]+12 for p in pixels): errors.append(name+': lilac')
        if family=='wet_drip':
            if not any(min(p[:3])>235 and p[3]>150 for p in pixels): errors.append(name+': missing white reflection')
        size=(OUT/name).stat().st_size;total+=size
        report.append(dict(file=name,size=[w,h],margin=margin,alpha=alpha.getextrema(),contrast=contrast,bytes=size,sha256=digest))
        # Contact sheet: same asset on dark and light backgrounds.
        for half,bg in enumerate(('#252B33','#B2BAC2')):
            tile=Image.new('RGBA',(100,100),bg)
            zoom=min(2,88/w,88/h)
            preview=im.resize((round(w*zoom),round(h*zoom)),Image.Resampling.NEAREST)
            tile.alpha_composite(preview,((100-preview.width)//2,(100-preview.height)//2))
            board.paste(tile,((i-1)*200+half*100,row*100))
    if len(hashes)!=count: errors.append(f'{family}: duplicate frames')
if total>300000:errors.append(f'budget: {total}')
expected={f'{f}_{i:02}.png' for f,w,h,n in FAMILIES for i in range(1,n+1)}
if {p.name for p in OUT.glob('*.png')}!=expected:errors.append('unexpected/missing PNG')
board.convert('RGB').save(WORK/'contact.png',optimize=True)
(WORK/'verification.json').write_text(json.dumps(dict(ok=not errors,count=len(report),bytes=total,errors=errors,files=report),indent=2),encoding='utf8')
print(('FAIL: '+'; '.join(errors)) if errors else f'PASS: {len(report)} PNG RGBA; sizes, alpha, margins >=2, contrast, distinct frames; {total} bytes; contact 800x700')
raise SystemExit(bool(errors))

