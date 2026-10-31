from pathlib import Path
from PIL import Image
import json,hashlib,io,itertools,math
R=Path('C:/Users/const/Documents/Rainfall');W=R/'art/blender/cel/rictus_vfx_retry';before=json.loads((W/'before.json').read_text());report={'assets':[],'checks':{}}
for rel,v in before.items():
 p=R/rel
 if '/dagger_arc/' not in rel and '/double_burst/' not in rel:
  assert hashlib.sha256(p.read_bytes()).hexdigest()==v['hash'];continue
 if not rel.endswith('.png'):
  assert hashlib.sha256(p.read_bytes()).hexdigest()==v['hash'];continue
 im=Image.open(p).convert('RGBA');assert list(im.size)==v['size'];limit=int(v['head_bytes']*1.3)
 if p.stat().st_size>limit:
  for colors in [192,128,96,64,48,32]:
   q=im.quantize(colors=colors,method=Image.Quantize.FASTOCTREE,dither=Image.Dither.NONE);out=io.BytesIO();q.save(out,format='PNG',optimize=True,compress_level=9)
   if len(out.getvalue())<=limit:p.write_bytes(out.getvalue());break
 assert p.stat().st_size<=limit,(rel,p.stat().st_size,limit)
 im=Image.open(p).convert('RGBA');em='_e' in p.stem;n=4 if 'dagger_arc' in rel else 6;cell=im.height
 cells=[im.crop((f*cell,0,(f+1)*cell,cell)) for f in range(n)]
 assert len({hashlib.sha256(c.tobytes()).hexdigest() for c in cells})==n
 for c in cells:
  assert c.getchannel('A').getextrema()[0]==0 and c.getchannel('A').getextrema()[1]>=128
  assert c.getbbox() and min(c.getbbox()[:2])>0 and max(c.getbbox()[2:])<cell
 if em:assert max(im.getextrema()[i][1] for i in range(3))>10
 if 'dagger_arc' in rel and not em:
  a=cells[0].getchannel('A');mass=sum(a.getdata());ratio=mass/v['alpha0'];assert ratio>=3,ratio
  runs=[sum(1 for _ in g) for k,g in itertools.groupby([a.getpixel((x,336))>=128 for x in range(336,672)]) if k];thick=max(runs);assert thick>=67.2,thick
  masses=[sum(c.getchannel('A').getdata()) for c in cells];assert masses==sorted(masses,reverse=True)
  report['checks'].update(alpha_ratio=ratio,alpha0_before=v['alpha0'],alpha0_after=mass,main_thickness_px=thick,radius_geometry_px=2.49*128,blades=11,arc_degrees=140,alpha_masses=masses)
 report['assets'].append({'file':rel,'before':v['bytes'],'head':v['head_bytes'],'after':p.stat().st_size,'size':im.size})
assert not list((R/'game/assets/sprites/characters/rictus/dagger_arc').glob('*_n.png'))
assert not list((R/'game/assets/sprites/characters/rictus/double_burst').glob('*_n.png'))
for folder in ['dagger_arc','double_burst']:
 for p in (R/'game/assets/sprites/characters/rictus'/folder).glob('*.tres'):
  assert 'CanvasTexture' not in p.read_text() and 'normal_texture' not in p.read_text()
board=Image.new('RGB',(1008,1008),(22,27,32))
def put(im,x,y,w,h):
 im=im.convert('RGBA');im.thumbnail((w,h),Image.Resampling.LANCZOS);board.paste(im,(x+(w-im.width)//2,y+(h-im.height)//2),im)
put(Image.open(R/'art/renders/feel_sorts2/before_vfx.png'),0,0,504,252)
put(Image.open(W/'first_arc.png').crop((0,0,672,672)),504,0,252,252)
im=Image.open(R/'game/assets/sprites/characters/rictus/dagger_arc/default.png');put(im.crop((0,0,672,672)),756,0,252,252)
for f in range(4):put(im.crop((f*672,0,(f+1)*672,672)),f*252,252,252,252)
for row,name in enumerate(['top','crea']):
 im=Image.open(R/f'game/assets/sprites/characters/rictus/double_burst/{name}.png')
 for f in range(6):put(im.crop((f*512,0,(f+1)*512,512)),f*168,504+row*252,168,252)
p=R/'art/renders/feel_sorts2/after_vfx_rictus.png';board.save(p,optimize=True)
(W/'verify.json').write_text(json.dumps(report,indent=2));print('PASS',json.dumps(report['checks']));print('BYTES',[(Path(a['file']).name,a['head'],a['before'],a['after']) for a in report['assets']])

