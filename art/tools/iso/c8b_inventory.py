import json,hashlib
from pathlib import Path
from PIL import Image
r=Path.cwd(); h=r/'art/tools/iso'; d=json.loads((h/'_c8_inventory.json').read_text()); d['assets']=[a for a in d['assets'] if '/chests/' in a['path']]; d['pivots']={k:v for k,v in d['pivots'].items() if '/chests/' in k}; d['protected']={str(p.relative_to(r)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (r/'game/assets/sprites/chests').rglob('*') if p.suffix in ('.import','.tres')}; d['original_files']={str(p.relative_to(r)): {'size':list(Image.open(p).size),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in (r/'game/assets/sprites/chests').rglob('*.png')}; (h/'_c8b_inventory.json').write_text(json.dumps(d,indent=2)); print('PASS inventory',len(d['original_files']))
