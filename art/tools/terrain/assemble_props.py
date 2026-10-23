"""Only assemble and LANCZOS-resize Blender rendered PNGs; validate dimensions."""
from pathlib import Path
from PIL import Image
import json
ROOT=Path(__file__).resolve().parents[3]
RAW=ROOT/'art/renders/terrain/props'
OUT=ROOT/'game/assets/sprites/props'
RAIN=('puddle','splash','grass')
def run():
 rows=[];previews=[]
 for folder in sorted(RAW.iterdir()):
  if not folder.is_dir():continue
  name=folder.name;dest=OUT/'rain' if name.startswith(RAIN) else OUT;dest.mkdir(parents=True,exist_ok=True)
  for suffix in ('','_n','_e'):
   frames=sorted(folder.glob('[0-9][0-9]'+suffix+'.png'))
   if not frames:continue
   tiles=[]
   for f in frames:
    with Image.open(f) as im:
     assert im.mode=='RGBA',(f,im.mode)
     tiles.append(im.resize((im.width//2,im.height//2),Image.Resampling.LANCZOS))
   w,h=tiles[0].size
   sheet=Image.new('RGBA',(w*len(tiles),h))
   for i,t in enumerate(tiles):sheet.paste(t,(i*w,0))
   file=dest/(name+suffix+'.png');sheet.save(file)
   bbox=sheet.getchannel('A').getbbox()
   assert bbox and bbox[0]>=2 and bbox[1]>=2 and bbox[2]<=sheet.width-2 and bbox[3]<=sheet.height-2,(file,bbox)
   rows.append(dict(file=file.relative_to(ROOT).as_posix(),width=sheet.width,height=h,bytes=file.stat().st_size,frames=len(tiles),alpha_bbox=bbox))
   if not suffix:previews.append((name,tiles[0]))
 # Contact sheets assemble original rendered pixels, with no painting.
 for suffix in ('','_n','_e'):
  images=[]
  for name,im in previews:
   dest=OUT/'rain' if name.startswith(RAIN) else OUT
   file=dest/(name+suffix+'.png')
   if file.exists():
    with Image.open(file) as sheet:
     tile=sheet.crop((0,0,sheet.height,sheet.height))
     tile.thumbnail((192,192),Image.Resampling.LANCZOS);images.append(tile.copy())
  canvas=Image.new('RGBA',(192*5,192*((len(images)+4)//5)))
  for i,im in enumerate(images):canvas.paste(im,((i%5)*192,(i//5)*192))
  canvas.save(RAW/('contact'+suffix+'.png'))
 (RAW/'manifest.json').write_text(json.dumps(rows,indent=2))
 report=['# Livraison props — étape 2','','Rendus Blender Eevee 2x, caméra orthographique 55°, Standard ; aucun plan recevant une ombre. Normales OpenGL en espace caméra (Y+ écran). Masques émissifs rendus séparément.','','Animations : piliers actifs 8 colonnes (boucle, 12 fps suggérés), splash 4 colonnes, splash8 8 colonnes. Une frame carrée par colonne.','','| Fichier | Dimensions | Octets |','|---|---:|---:|']
 report += [f"| {r['file']} | {r['width']} × {r['height']} | {r['bytes']} |" for r in rows]
 (ROOT/'art/briefs/terrain_props_delivery.md').write_text('\n'.join(report),encoding='utf8')
 print(f'{len(rows)} PNG validated')
if __name__=='__main__':run()
