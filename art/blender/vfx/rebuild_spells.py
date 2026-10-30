import sys,json,re,hashlib
from pathlib import Path
ROOT=Path('C:/Users/const/Documents/Rainfall');sys.path.insert(0,str(ROOT/'art/tools/iso'))
import a2_build as a
from PIL import Image
base=ROOT/'art/blender/vfx';targets={}
for kind in a.FX:
 d=ROOT/'game/assets/sprites/vfx'/kind
 targets[kind]={p.name:{'size':Image.open(p).size,'bytes':p.stat().st_size} for p in d.glob('*.png')}
if not (base/'spell_before.json').exists():(base/'spell_before.json').write_text(json.dumps(targets))
a.render_vfx()
for kind,(size,slots,count,radius) in a.FX.items():
 d=ROOT/'game/assets/sprites/vfx'/kind;text=(d/(kind+'.tres')).read_text()
 ext=dict(re.findall(r'path="res://assets/sprites/vfx/[^/]+/([^"/]+)" id="([^"]+)"',text));ext={v:k for k,v in ext.items()}
 blocks=re.findall(r'\[sub_resource type="AtlasTexture"[^\]]*\]\s*atlas = ExtResource\("([^"]+)"\)\s*region = Rect2\(([^)]+)\)',text)
 sheets={name:Image.new('RGBA',tuple(info['size'])) for name,info in targets[kind].items()}
 counters={}
 for ident,rect in blocks:
  name=ext[ident];label='end' if name.startswith('end') else 'default';i=counters.get(label,0);counters[label]=i+1
  x,y,w,h=map(lambda v:int(float(v.strip())),rect.split(','))
  p=base/'ardent_spell_frames'/kind/label/('%02d.png'%i)
  if not p.exists():continue
  for suffix in ('','_e'):
   src=p.with_name(p.stem+suffix+'.png');im=Image.open(src).convert('RGBA')
   if label=='end' and i==3:im=Image.new('RGBA',im.size)
   canvas=Image.new('RGBA',(w,h));canvas.paste(im,((w-size)//2,(h-size)//2))
   dest=Path(name).stem+suffix+'.png'
   if suffix:
    canvas=canvas.resize(((w+1)//2,(h+1)//2),Image.Resampling.LANCZOS);xy=(x//2,y//2)
   else:xy=(x,y)
   sheets[dest].paste(canvas,xy)
 for name,im in sheets.items():im.save(d/name,optimize=True,compress_level=9)
print('SPELL RENDER PACK PASS',flush=True)
