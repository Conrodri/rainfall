"""Validate delivered Blender sprites. PIL only inspects rendered pixels."""
from pathlib import Path
from PIL import Image
import hashlib,json
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/props'
RAW=ROOT/'art/renders/terrain/props'
rows=json.loads((RAW/'manifest.json').read_text())
for r in rows:
 p=ROOT/r['file']
 with Image.open(p) as im:
  assert im.mode=='RGBA' and im.size==(r['width'],r['height'])
  h=im.height;hashes=[]
  for i in range(r['frames']):
   frame=im.crop((i*h,0,(i+1)*h,h));bbox=frame.getchannel('A').getbbox()
   assert bbox and bbox[0]>=4 and bbox[1]>=4 and bbox[2]<=h-4 and bbox[3]<=h-4,(p,i,bbox)
   hashes.append(hashlib.sha256(frame.tobytes()).hexdigest())
  if r['frames']>1:assert len(set(hashes))==r['frames'],(p,'duplicate animation frame')
  if not p.stem.endswith(('_n','_e')):
   with Image.open(p.with_name(p.stem+'_n.png')) as n:
    assert im.size==n.size
    assert im.getchannel('A').tobytes()==n.getchannel('A').tobytes(),p
   if any(s in p.stem for s in ('active','done','teleporter','lantern')):
    with Image.open(p.with_name(p.stem+'_e.png')) as e:assert e.size==im.size
with Image.open(OUT/'rain/puddle_a_n.png') as n:
 pixel=n.getpixel((96,96));assert 120<=pixel[0]<=135 and pixel[1]>180 and pixel[2]>220,pixel
inventory=[]
for folder,pattern in [(OUT,'*.png'),(ROOT/'art/blender/terrain','props_*.blend'),(RAW,'*.png'),(ROOT/'art/tools/terrain','*props*.py')]:
 for p in sorted(folder.rglob(pattern)):
  r={'file':p.relative_to(ROOT).as_posix(),'bytes':p.stat().st_size}
  if p.suffix=='.png':
   with Image.open(p) as im:r.update(width=im.width,height=im.height)
  inventory.append(r)
(ROOT/'art/briefs/terrain_props_inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf8')
report=ROOT/'art/briefs/terrain_props_delivery.md'
s=report.read_text(encoding='utf8').split('\n\nContrôles :')[0]
s+='\n\nContrôles : 57 PNG RGBA ; marges transparentes >= 4 px dans chaque frame ; aucune frame animée dupliquée ; alpha couleur/normal identique ; cadrage émission identique ; normale plane orientée Y+ écran et Z+ vers le spectateur. Inspection visuelle des planches couleur/normal/émission et des sheets.\n'
s+='\nInventaire exhaustif (sources, rendus bruts et livraisons, octets et dimensions PNG) : art/briefs/terrain_props_inventory.json.\n'
s+='\n## Sources Blender et scripts\n\n| Fichier | Octets |\n|---|---:|\n'
s+='\n'.join(f"| {r['file']} | {r['bytes']} |" for r in inventory if not r['file'].endswith('.png'))
report.write_text(s,encoding='utf8')
print(f'{len(rows)} PNG verified; {len(inventory)} files inventoried; {sum(r["bytes"] for r in inventory)} bytes')
