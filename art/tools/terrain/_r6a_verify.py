"""R6a contract and periodic seam checks; Pillow only inspects/assembles."""
from pathlib import Path
import json, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]
rows=json.loads((ROOT/'art/tools/terrain/_r6a_inventory.json').read_text())
errors=[]; metrics=[]; panels=[]
for row in rows:
 p=ROOT/row['path']
 if not p.exists(): errors.append('missing '+str(p)); continue
 if p.suffix=='.tres':
  if hashlib.sha256(p.read_bytes()).hexdigest()!=row['sha256']: errors.append('modified tres '+p.name)
  continue
 im=Image.open(p).convert('RGBA')
 if list(im.size)!=row['size'] or im.size!=(256,256): errors.append('size '+p.name)
 if hashlib.sha256(p.read_bytes()).hexdigest()==row['sha256']: errors.append('unchanged '+p.parent.name+'/'+p.name)
 pix=im.load(); w,h=im.size
 def delta(a,b): return sum(abs(a[k]-b[k]) for k in range(3))/3
 sx=sum(delta(pix[0,y],pix[w-1,y]) for y in range(h))/h
 sy=sum(delta(pix[x,0],pix[x,h-1]) for x in range(w))/w
 nx=sum(delta(pix[x,y],pix[x+1,y]) for x in range(w-1) for y in range(h))/(h*(w-1))
 ny=sum(delta(pix[x,y],pix[x,y+1]) for x in range(w) for y in range(h-1))/(w*(h-1))
 metrics.append(dict(path=row['path'],seam_x=round(sx,3),seam_y=round(sy,3),neighbor_x=round(nx,3),neighbor_y=round(ny,3)))
 if sx>max(3.0,nx*3) or sy>max(3.0,ny*3): errors.append('seam '+p.parent.name+'/'+p.name)
 if im.getextrema()[3]!=(255,255): errors.append('alpha '+p.name)
 if p.stem.endswith('_n'):
  avg=im.convert('RGB').resize((1,1),Image.Resampling.BOX).getpixel((0,0))
  if abs(avg[0]-128)>15 or abs(avg[1]-128)>15 or avg[2]<220: errors.append('normal '+p.name)
 else:
  panel=Image.new('RGBA',(512,512))
  for xy in ((0,0),(256,0),(0,256),(256,256)): panel.paste(im,xy)
  panels.append(panel.resize((256,256),Image.Resampling.LANCZOS))
expected={r['path'] for r in rows}
actual={p.relative_to(ROOT).as_posix() for b in ('terraces','fog_forest','rust_city') for p in (ROOT/'game/assets/sprites/terrain'/b).glob('*') if p.suffix=='.tres' or (p.suffix=='.png' and p.name.startswith(('ground_','water_','cliff_edge')))}
if actual!=expected: errors.append('inventory set mismatch')
sheet=Image.new('RGBA',(7*256,3*256))
# Inventory sorted by biome; rows: fog_forest, rust_city, terraces.
for i,panel in enumerate(panels): sheet.paste(panel,((i%7)*256,(i//7)*256))
sheet.save(ROOT/'art/tools/terrain/_r6a_contact.png')
(ROOT/'art/tools/terrain/_r6a_validation.json').write_text(json.dumps(dict(errors=errors,metrics=metrics),indent=2))
print('PASS' if not errors else 'FAIL',len(rows),'assets;',len(errors),'errors')
for e in errors[:12]: print(e)
