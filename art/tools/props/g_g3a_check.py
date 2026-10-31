from pathlib import Path
from PIL import Image
import json,hashlib
ROOT=Path(__file__).resolve().parents[3]
out=ROOT/'game/assets/sprites/props/fog_forest'
errors=[];report=[];seen=set()
for name,size,foot in [('stump',128,94),('mushrooms',128,94),('standing_stone',192,166),('root_arch_a',256,224)]:
    im=Image.open(out/(name+'.png')).convert('RGBA');bb=im.getchannel('A').point(lambda p:255 if p>24 else 0).getbbox()
    digest=hashlib.sha256(im.tobytes()).hexdigest()
    if im.size!=(size,size) or not bb or min(bb[0],bb[1],size-bb[2],size-bb[3])<3:errors.append(name+' dimensions/alpha/clipping')
    if max(h-l for l,h in im.convert('RGB').getextrema())<50:errors.append(name+' contrast')
    if digest in seen:errors.append(name+' duplicate frame')
    seen.add(digest)
    sh=Image.open(out/(name+'_shadow.png')).convert('RGBA');sa=sh.getchannel('A').getextrema()[1]
    if sh.size!=(512,512) or not 0<sa<=153:errors.append(name+' shadow')
    ep=out/(name+'_e.png')
    if ep.exists():
        em=Image.open(ep).convert('RGBA')
        if em.size!=((size+1)//2,(size+1)//2) or max(em.getchannel(c).getextrema()[1] for c in 'RGB')==0 or not em.getchannel('A').getbbox():errors.append(name+' emission')
    elif name=='mushrooms':errors.append(name+' missing emission')
    if (out/(name+'_n.png')).exists():errors.append(name+' normal present')
    for tres in out.glob(name+'*.tres'):
        if any(k in tres.read_text() for k in ('CanvasTexture','normal_texture')):errors.append(tres.name+' normal material')
    report.append(dict(name=name,size=im.size,bbox=bb,foot=[size//2,foot],shadow_alpha=sa,emission=ep.exists()))
if Image.open(ROOT/'art/renders/grotte/g3a_avant_apres.png').size!=(1024,512):errors.append('board dimensions')
result=dict(status='FAIL' if errors else 'PASS',errors=errors,props=report)
(ROOT/'art/tools/props/_g3a_retouch_check.json').write_text(json.dumps(result,indent=2))
print(result['status'],json.dumps(report),errors)
raise SystemExit(bool(errors))
