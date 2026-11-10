"""Five passive medallions; shared Nova geometry and cel pipeline; no normal files."""
import sys, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/ui')]
import icons_norm_build as n
from ui_kit import *
WORK=ROOT/'art/blender/cel/passives_c'
OUT=ROOT/'game/assets/sprites/ui/icons/passives'

def emblem(name):
 if name=='statique':
  n.plate([(.12,.52),(-.28,-.02),(-.03,-.02),(-.14,-.52),(.30,.06),(.06,.06),(.24,.52)],n.glow,d=.16,b=.05)
  n.line([(.10,.46),(-.20,-.02)],.02,n.heart,y=-.42)
  for x,z,r in [(-.42,.30,.05),(.44,-.22,.05),(-.40,-.30,.04),(.40,.34,.04)]:
   n.dot(x,z,r,n.heart)
  n.line([(-.50,.14),(-.40,.04),(-.50,-.06)],.018,n.glow)
  n.line([(.50,.12),(.40,.02),(.50,-.08)],.018,n.glow)
 elif name=='avalement':
  n.plate([(-.52,-.02),(-.36,.22),(0,.28),(.36,.22),(.52,-.02),(.40,-.36),(0,-.48),(-.40,-.36)],n.glow,d=.16,b=.05)
  for x in (-.30,.30):
   n.dot(x,.34,.15,n.glow);n.dot(x,.34,.075,n.dark,y=-.40)
  n.line([(-.40,-.12),(-.15,-.22),(.15,-.22),(.40,-.12)],.045,n.dark,y=-.42)
  n.line([(0,-.20),(.12,-.36),(.30,-.44),(.46,-.30)],.06,n.heart,y=-.44)
  n.dot(.50,-.14,.10,n.heart,y=-.46)

def run():
 n.WORK=WORK;WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
 n.cel.archive_folder('ui/icons/passives')
 for name,color in [('statique','#B9A6FF'),('avalement','#69BD79')]:
  s=n.scene(name,lambda:emblem(name),color);s.eevee.taa_render_samples=8
  tree=s.compositing_node_group
  rl=next(o for o in tree.nodes if o.bl_idname=='CompositorNodeRLayers')
  f=next(o for o in tree.nodes if o.bl_idname=='CompositorNodeOutputFile')
  f.file_name=name+'_e__';tree.links.new(rl.outputs[n.cel.AOV],f.inputs[0])
  bpy.ops.render.render(write_still=True)
  subprocess.run([PY,str(Path(__file__).with_name('passives_c_finish.py')),name],check=True)
  print('PASS '+name,flush=True)
  bpy.context.window.scene=bpy.data.scenes[0];bpy.data.scenes.remove(s);bpy.data.orphans_purge(do_recursive=True)
if __name__=='__main__':run()
