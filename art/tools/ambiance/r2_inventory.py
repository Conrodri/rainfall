import json,hashlib
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[3]
items=[]
for p in sorted((root/'game/assets/sprites/ambiance').glob('*.png')):
 im=Image.open(p); n=p.stem
 data='normal' if n.endswith('_n') or n.startswith('ripple_normal') else 'emission' if n.endswith('_e') else 'puddle_rgb' if n.startswith('puddle_mask') else 'rain_rgb' if n.startswith('rain_sheet') else 'diffuse_alpha'
 family='drops' if n.startswith(('drop_','splash_','rain_')) else 'fog' if n.startswith(('fog_','cloud_','canopy_','steam_')) else 'water' if n.startswith(('water_','ripple_','puddle_','bubble_')) else 'particles' if n.startswith(('leaf_','ash_','firefly_','ember_','frost_','mote_','spark_','glint_')) else 'sky_light'
 tile=n.startswith(('fog_tile','fog_volume','cloud_shadow','canopy_shadow','water_caustics','puddle_mask','ripple_normal','rain_'))
 items.append(dict(file=p.name,size=list(im.size),frames=8 if '_8x64' in n else 1,mode=im.mode,bands=list(im.getbands()),use=data,family=family,seamless=tile,extrema=im.getextrema(),sha256=hashlib.sha256(p.read_bytes()).hexdigest()))
out=root/'art/tools/ambiance/_r2_inventory.json'
if out.exists(): raise RuntimeError('Inventaire existant : ne pas ecraser')
out.write_text(json.dumps(dict(source='Claude p0a/p0b/p1p2, racine uniquement; rain/ conserve',files=items),indent=2))
print(len(items),'PNG inventories')
