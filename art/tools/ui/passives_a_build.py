"""Five passive reliefs; shared Nova geometry and i3 raster contract. Background only."""
import sys, math, subprocess, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.dont_write_bytecode=True
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/ui')]
if not (len(sys.argv)>1 and sys.argv[-1]=='finish'):
 import icons_norm_build as n

WORK=ROOT/'art/blender/cel/passives_a'
OUT=ROOT/'game/assets/sprites/ui/icons/passives'
IDS={'tension':'#CFA44F','aiguisage':'#BAD2DA','eau':'#80C5DC','membres':'#DB793B','chaine':'#C78B60'}

def emblem(name):
 if name=='tension':
  n.line([(-.35,-.55),(-.08,-.42),(.13,-.17),(.17,.10),(.06,.35),(-.20,.56)],.065,n.wood)
  n.line([(-.35,-.55),(.42,0),(-.20,.56)],.018,n.heart)
  n.line([(.07,-.10),(.13,.10)],.072,n.metal)
  n.arrow((-.32,0),(.60,0),.09,n.glow)
 elif name=='aiguisage':
  n.plate([(-.58,-.29),(.32,-.38),(.54,-.19),(-.35,-.10)],n.dark,d=.17,b=.035)
  n.plate([(-.40,.51),(-.32,.56),(.36,-.10),(.42,-.30),(.24,-.18)],n.metal)
  n.line([(-.32,.51),(.29,-.13),(.42,-.30)],.024,n.heart,y=-.39)
  n.line([(-.42,.55),(-.57,.70)],.055,n.wood)
  n.line([(-.48,.45),(-.27,.62)],.025,n.metal)
  for x,z in [(.51,.06),(.13,.13),(.51,-.12)]:
   n.line([(.30,-.12),(x,z)],.014,n.glow,y=-.40)
 elif name=='eau':
  n.plate([(0,.65),(-.12,.36),(-.25,.10),(-.23,-.08),(-.11,-.19),(.10,-.19),(.23,-.08),(.25,.10),(.12,.36)],n.glow)
  n.line([(-.07,.33),(-.14,.08),(-.10,-.02)],.024,n.heart,y=-.38)
  for r,z in [(.34,-.32),(.56,-.35)]:n.arc(0,z,r,0,math.tau,n.glow,.026,48,sy=.26,y=-.32)
 elif name=='membres':
  n.line([(-.38,.44),(-.25,.02),(.29,-.23)],.13,n.dark)
  n.plate([(-.53,.48),(-.23,.54),(-.13,.13),(-.39,.06)],n.metal)
  n.plate([(-.18,.02),(-.02,.16),(.43,-.12),(.27,-.34)],n.metal)
  for x,z in [(-.37,.44),(-.23,.04),(.32,-.23)]:
   n.dot(x,z,.115,n.dark,y=-.39);n.arc(x,z,.071,0,math.tau,n.glow,.024,y=-.49)
  n.line([(-.37,.33),(-.30,.17)],.026,n.glow,y=-.40)
  n.line([(.39,-.26),(.53,-.34),(.56,-.18)],.050,n.metal,y=-.36)
  n.line([(.33,-.33),(.39,-.49),(.55,-.46)],.050,n.metal,y=-.36)
 elif name=='chaine':
  n.chain([(-.58,-.40),(-.46,-.36),(-.34,-.32),(-.22,-.28),(-.10,-.24),(.02,-.20)])
  n.line([(.25,.52),(-.02,-.36)],.047,n.metal,y=-.40)
  n.line([(.25,.52),(.58,-.34)],.047,n.metal,y=-.40)
  n.arc(.26,.08,.28,3.35,6.05,n.glow,.028,sy=.65,y=-.41)
  n.dot(.25,.47,.085,n.glow,y=-.43)
  n.line([(.25,.55),(.25,.66)],.027,n.heart)

def run():
 WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
 n.cel.archive_folder('ui/icons/passives')
 n.WORK=WORK
 inv={'files':{}}
 for name,accent in IDS.items():
  s=n.scene(name,lambda name=name:emblem(name),accent)
  s.eevee.taa_render_samples=16
  # Shared cel compositor emits a useful accent mask at the raster contract size.
  tree=s.compositing_node_group
  rl=next(x for x in tree.nodes if x.bl_idname=='CompositorNodeRLayers')
  f=tree.nodes.new('CompositorNodeOutputFile');f.directory=str(WORK);f.file_name=name+'_emission__'
  f.file_output_items.new('RGBA','Image');f.format.media_type='IMAGE';f.format.file_format='PNG';f.format.color_mode='RGBA'
  tree.links.new(rl.outputs[n.cel.AOV],f.inputs[0])
  n.bpy.ops.render.render(write_still=True)
  inv['files'][name]={'path':(OUT/(name+'.png')).relative_to(ROOT).as_posix(),'size':[128,128],'bbox':[10,8,121,120]}
  print('PASS render '+name,flush=True)
 (WORK/'inventory.json').write_text(json.dumps(inv))
 subprocess.run([n.PY,str(Path(__file__).resolve()),'finish'],check=True)

def raster():
 import i3_finish as finish
 from PIL import Image
 import numpy as np
 inv=json.loads((WORK/'inventory.json').read_text())
 finish.BASE=WORK;finish.INV=WORK/'inventory.json'
 board=Image.new('RGBA',(5*150,290),'#14110C')
 for i,name in enumerate(IDS):
  import shutil
  shutil.copyfile(WORK/(name+'_raw.png'),WORK/('i3_raw_'+name+'.png'))
  finish.fit(name)
  im=Image.open(OUT/(name+'.png'));assert im.mode=='RGBA' and im.size==(128,128) and im.getbbox()==(10,8,121,120)
  raw=Image.open(WORK/(name+'_raw.png'));box=raw.getbbox()
  e=Image.open(next(WORK.glob(name+'_emission__*.png'))).convert('RGBA').crop(box).resize((111,112),Image.Resampling.LANCZOS)
  mask=Image.new('RGBA',(128,128));mask.paste(e,(10,8));mask.putalpha(im.getchannel('A'));mask=mask.resize((64,64),Image.Resampling.LANCZOS)
  a=np.array(mask);assert (a[:,:,:3].max(axis=2)* (a[:,:,3]/255)).max()>2
  mask.save(OUT/(name+'_e.png'),compress_level=9)
  for size,y in [(128,8),(72,146),(48,232)]:
   tile=im.resize((size,size),Image.Resampling.LANCZOS);board.alpha_composite(tile,(i*150+(150-size)//2,y))
  assert not (OUT/(name+'_n.png')).exists()
 board.convert('RGB').save(ROOT/'art/tools/ui/passives_a_contact.png')
 print('PASS 5 RGBA 128x128 bbox (10, 8, 121, 120); 5 emission 64x64; contact 128/72/48')

if __name__=='__main__':
 if len(sys.argv)>1 and sys.argv[-1]=='finish':raster()
 else:run()


