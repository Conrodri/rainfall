"""U2 inventory, exact alpha-margin fit, assembly and contract verification.
Pillow only crops/resizes/assembles/checks existing images; no raster drawing.
"""
import json,hashlib,sys
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[3]; BASE=ROOT/'art/tools/ui'; UI=ROOT/'game/assets/sprites/ui'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def targets():
 return sorted([*UI.joinpath('cards').glob('*.png'),*UI.joinpath('dice').glob('*.png'),*UI.joinpath('interact').glob('*.png'),*UI.joinpath('joystick').glob('*.png'),*UI.glob('spell_*.png'),*ROOT.joinpath('game/assets/sprites/icons').glob('frame_*.png'),UI/'hud/icon_interact_hand.png'])
def snapshot():
 data={'files':{},'protected':{},'notes':'R7c recorded contract; R7d inventory absent, snapshot of existing spell/interact/joystick assets. Rarity frames: icons/frame_*.png. Explicit toy-hand replacement: ui/hud/icon_interact_hand.png.'}
 for p in targets():
  im=Image.open(p).convert('RGBA');rel=p.relative_to(ROOT).as_posix()
  data['files'][rel]={'size':list(im.size),'mode':'RGBA','bbox':list(im.getbbox()),'sha256':sha(p)}
  for q in p.parent.glob(p.name+'*'):
   if q!=p:data['protected'][q.relative_to(ROOT).as_posix()]=sha(q)
 for p in UI.rglob('*.tres'):data['protected'][p.relative_to(ROOT).as_posix()]=sha(p)
 (BASE/'_u2_inventory.json').write_text(json.dumps(data,indent=2))
 print('PASS snapshot:',len(data['files']),'PNG')
def fit_and_check():
 inv=json.loads((BASE/'_u2_inventory.json').read_text());jobs=json.loads((BASE/'_u2_jobs.json').read_text());errors=[]
 for job in jobs:
  p=ROOT/job['path'];spec=inv['files'][job['path']];im=Image.open(job['raw']).convert('RGBA');crop=im.crop(im.getbbox());x0,y0,x1,y1=spec['bbox']
  crop=crop.resize((x1-x0,y1-y0),Image.Resampling.LANCZOS)
  # Crop any fully transparent resampling edge and refit to the exact recorded bounds.
  if crop.getbbox()!=(0,0,crop.width,crop.height):crop=crop.crop(crop.getbbox()).resize(crop.size,Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',spec['size']);canvas.paste(crop,(x0,y0));canvas.save(p,optimize=True,compress_level=9)
 for rel,spec in inv['files'].items():
  im=Image.open(ROOT/rel)
  if list(im.size)!=spec['size'] or im.mode!=spec['mode'] or list(im.getbbox())!=spec['bbox']:errors.append(rel+': geometry')
  if sha(ROOT/rel)==spec['sha256']:errors.append(rel+': unchanged')
 for rel,digest in inv['protected'].items():
  if sha(ROOT/rel)!=digest:errors.append(rel+': protected')
 # Compare documented R7c values for every U2 member in that inventory.
 for entry in json.loads((BASE/'_r7c_inventory.json').read_text()):
  if entry['path'] in inv['files']:
   im=Image.open(ROOT/entry['path'])
   if list(im.size)!=entry['size'] or list(im.getbbox())!=entry['bbox']:errors.append(entry['path']+': R7c')
  elif entry['path'].removesuffix('.import') in inv['files'] and entry['path'].endswith('.import'):
   if sha(ROOT/entry['path'])!=entry['sha256']:errors.append(entry['path']+': R7c import')
 if set(j['path'] for j in jobs)!=set(inv['files']):errors.append('target coverage')
 # One sheet: every replacement, all animation frames, chest-opening mockup and DA references.
 sheet=Image.new('RGBA',(1800,2000),(18,19,20,255))
 def paste(p,x,y,w,h):
  im=Image.open(p).convert('RGBA');im.thumbnail((w,h),Image.Resampling.LANCZOS);sheet.alpha_composite(im,(x+(w-im.width)//2,y+(h-im.height)//2))
 paste(UI/'cards/card_front.png',40,20,330,480);paste(UI/'cards/card_back.png',400,20,330,480)
 for i,n in enumerate(['commun','peu_commun','rare','legendaire']):
  paste(ROOT/f'game/assets/sprites/icons/frame_{n}.png',790+i*235,30,210,210)
  paste(UI/f'dice/d100_face_{n}.png',825+i*235,270,145,145)
 for i in range(20):paste(UI/f'dice/d100_rot_{i:02}.png',30+i%10*175,520+i//10*165,145,145)
 other=[UI/'spell_frame.png',UI/'spell_frame_pressed.png',UI/'spell_frame_cooldown.png',UI/'spell_cooldown_ring.png',*UI.joinpath('interact').glob('*.png'),*UI.joinpath('joystick').glob('*.png'),UI/'hud/icon_interact_hand.png']
 for i,p in enumerate(other):paste(p,25+i*175,870,155,180)
 panel=Image.open(BASE/'u2_raw/opening_panel.png').convert('RGBA').resize((1140,740))
 # Three cards in the exact original layout, with existing item artwork in the upper field.
 iconnames=['lame_jumelle','horloge_arcanique','cristal_de_feu']
 for i,n in enumerate(iconnames):
  card=Image.open(UI/'cards/card_front.png').convert('RGBA')
  iconpath=ROOT/f'game/assets/sprites/icons/items/{n}.png'
  if iconpath.exists():
   icon=Image.open(iconpath).convert('RGBA');icon.thumbnail((245,245),Image.Resampling.LANCZOS);card.alpha_composite(icon,((384-icon.width)//2,65))
  card=card.resize((245,358),Image.Resampling.LANCZOS);panel.alpha_composite(card,(160+i*290,305))
 die=Image.open(UI/'dice/d100_face_legendaire.png').convert('RGBA').resize((160,160),Image.Resampling.LANCZOS);panel.alpha_composite(die,(490,105))
 sheet.alpha_composite(panel,(35,1120))
 for i,p in enumerate([ROOT/'art/tools/monsters/_r8a_contact.png',ROOT/'art/tools/iso/_c1_contact.png',ROOT/'art/tools/iso/_c4_contact.png']):
  if p.exists():paste(p,1220,1100+i*285,540,265)
 sheet.convert('RGB').save(BASE/'_u2_contact.png',optimize=True)
 report={'status':'FAIL' if errors else 'PASS','png':len(jobs),'dice':24,'protected_files':len(inv['protected']),'checks':['complete target coverage','all assets changed','RGBA dimensions','exact alpha bounding boxes','R7c inventory contract','import and tres hashes unchanged'],'errors':errors,'notes':inv['notes'],'rarity_order':'commun iron / peu_commun green bronze / rare subdued violet-blue dice, blued steel frame / legendaire ember gold'}
 (BASE/'_u2_report.json').write_text(json.dumps(report,indent=2));print(report['status'],len(jobs),'assets;',len(errors),'errors')
 if errors:print('\n'.join(errors[:8]));sys.exit(1)
if __name__=='__main__':
 if len(sys.argv)>1 and sys.argv[1]=='snapshot':snapshot()
 else:fit_and_check()
