"""Five passive medallions; shared Nova geometry and cel pipeline; no normal files."""
import sys, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/night'),str(ROOT/'art/tools/ui')]
import icons_norm_build as n
from ui_kit import *
WORK=ROOT/'art/blender/cel/passives_b'
OUT=ROOT/'game/assets/sprites/ui/icons/passives'

def emblem(name):
 if name=='souffle':
  sphere((.03,-.31,.08),(.30,.12,.19),n.glow)
  n.dot(.26,.22,.16);n.dot(.32,.31,.046,n.heart,y=-.43)
  n.line([(-.12,.0),(-.40,-.20),(-.18,-.32),(-.51,-.36)],.063)
  n.line([(.15,.0),(.30,-.12),(.48,.03)],.043)
  for z in [-.02,.18]:n.line([(-.62,z-.16),(-.46,z-.10),(-.34,z)],.022,n.heart)
 elif name=='bourse':
  n.plate([(-.21,.25),(-.42,-.13),(-.34,-.43),(0,-.51),(.34,-.43),(.42,-.13),(.21,.25)],n.wood,d=.18,b=.06)
  n.plate([(-.20,.28),(-.28,.49),(-.04,.42),(.22,.49),(.18,.28)],n.wood)
  n.line([(-.23,.25),(.23,.25)],.046,n.glow,y=-.40)
  n.line([(0,.24),(.29,.06),(.35,.19)],.026,n.heart,y=-.43)
  n.coin(0,-.15,.20)
 elif name=='masse':
  n.blob(-.28,-.12,.31,seed=4);n.blob(.29,.07,.25,seed=9)
  n.line([(-.10,-.04),(.03,.02),(.09,.08)],.045,n.heart)
  n.dot(.02,-.28,.04);n.dot(.02,.31,.035)
 elif name=='fils':
  n.line([(-.42,.36),(.42,.36)],.075,n.wood)
  n.line([(0,.64),(0,.09)],.072,n.wood)
  for x,z in [(-.42,-.42),(0,-.26),(.42,-.42)]:
   n.line([(x,.34),(x,z)],.018,n.glow)
   n.dot(x,z,.048,n.heart)
  n.line([(-.15,.36),(.15,.36)],.025,n.heart,y=-.40)
 elif name=='braise':
  n.nova.shard(0,-.14,1.25,.15)
  n.nova.tongue(-.18,-.33,.78,.16,.19)
  n.nova.tongue(.15,-.28,.58,.12,-.14)
  n.nova.sparks([(-.27,.48,.024),(.30,.34,.022)])

def run():
 n.WORK=WORK;WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(parents=True,exist_ok=True)
 n.cel.archive_folder('ui/icons/passives')
 for name,color in [('souffle','#69BD79'),('bourse','#DBA94D'),('masse','#5CAFA0'),('fils','#A85155'),('braise','#FF7900')]:
  s=n.scene(name,lambda:emblem(name),color);s.eevee.taa_render_samples=8
  tree=s.compositing_node_group
  rl=next(o for o in tree.nodes if o.bl_idname=='CompositorNodeRLayers')
  f=next(o for o in tree.nodes if o.bl_idname=='CompositorNodeOutputFile')
  f.file_name=name+'_e__';tree.links.new(rl.outputs[n.cel.AOV],f.inputs[0])
  bpy.ops.render.render(write_still=True)
  subprocess.run([PY,str(Path(__file__).with_name('passives_b_finish.py')),name],check=True)
  print('PASS '+name,flush=True)
  bpy.context.window.scene=bpy.data.scenes[0];bpy.data.scenes.remove(s);bpy.data.orphans_purge(do_recursive=True)
if __name__=='__main__':run()
