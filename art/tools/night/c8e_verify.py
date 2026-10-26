from pathlib import Path
from PIL import Image
import json,hashlib,numpy as np
root=Path.cwd();here=root/'art/tools/night';dst=root/'game/assets/sprites/bosses/etage/deep_eel'
w=Image.open(dst/'wake.png').convert('RGBA');e=Image.open(dst/'wake_e.png').convert('RGBA')
assert w.size==(768,128) and e.size==(384,64)
frames=[w.crop((i*128,0,(i+1)*128,128)) for i in range(6)]
assert len({f.tobytes() for f in frames})==6
assert not list(dst.glob('*_n.png'))
a=np.asarray(w);em=np.asarray(e)
assert (a[:,::128,3]==0).all() and (a[[0,-1],:,3]==0).all()
coverage=[round(float((np.asarray(f)[:,:,3]>32).mean()),3) for f in frames]
assert max(coverage)<.15,coverage
energy=[round(float((em[:,i*64:(i+1)*64,:3]* (em[:,i*64:(i+1)*64,3:4]/255)).sum()),1) for i in range(6)]
assert min(energy)>0 and max(energy)>min(energy)*1.15,energy
contact=Image.new('RGBA',(768,256))
for row,color in enumerate(('#0A0D12','#2E3238')):
    contact.paste(Image.new('RGBA',(768,128),color),(0,row*128))
    contact.alpha_composite(w,(0,row*128))
contact.convert('RGB').save(here/'_c8e_contact.png')
before=json.loads((here/'_c8e_before.json').read_text())
after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in dst.iterdir() if p.is_file()}
changed=sorted(n for n in before.keys()|after.keys() if before.get(n)!=after.get(n))
assert set(changed)=={'wake.png','wake_e.png','black_pool_e.png.import'},changed
result=dict(result='PASS',diffuse=w.size,emission=e.size,coverage=coverage,emission_energy=energy,changed=changed)
(here/'_c8e_verify.json').write_text(json.dumps(result,indent=2))
print('PASS dimensions, 6 unique frames, transparency, cyan pulse, scope; coverage',coverage)
