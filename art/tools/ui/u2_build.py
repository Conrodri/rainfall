"""U2: engraved iron/bronze UI. Run with Blender 5.2 --background.
Reuses ui_kit and the R7c card layout; all raster art is rendered geometry.
"""
import sys, math, json, hashlib, ast
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
from mathutils import Matrix, Euler
BASE=ROOT/'art/tools/ui'
OUT=BASE/'u2_raw'; OUT.mkdir(exist_ok=True)
UI=ROOT/'game/assets/sprites/ui'
targets=sorted([*UI.joinpath('cards').glob('*.png'),*UI.joinpath('dice').glob('*.png'),*UI.joinpath('interact').glob('*.png'),*UI.joinpath('joystick').glob('*.png'),*UI.glob('spell_*.png'),*ROOT.joinpath('game/assets/sprites/icons').glob('frame_*.png'),UI/'hud/icon_interact_hand.png'])
# Snapshot before first replacement; do not overwrite on a rerun.
snapshot=BASE/'_u2_inventory.json'
if not snapshot.exists():
 import subprocess
 subprocess.run([PY,str(BASE/'u2_finish.py'),'snapshot'],check=True)

plain_mat=mat
def worn(dark,light,metal=.6,rough=.6):
 m=plain_mat(light,rough,metal); n=m.node_tree.nodes; l=m.node_tree.links; p=n.get('Principled BSDF')
 noise=n.new('ShaderNodeTexNoise'); noise.inputs['Scale'].default_value=24; noise.inputs['Detail'].default_value=3
 ramp=n.new('ShaderNodeValToRGB'); ramp.color_ramp.elements[0].position=.2; ramp.color_ramp.elements[1].position=.82
 ramp.color_ramp.elements[0].color=rgba(dark); ramp.color_ramp.elements[1].color=rgba(light)
 l.new(noise.outputs['Fac'],ramp.inputs[0]); l.new(ramp.outputs[0],p.inputs['Base Color'])
 fine=n.new('ShaderNodeTexNoise'); fine.inputs['Scale'].default_value=135
 bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.24; bump.inputs['Distance'].default_value=.018
 l.new(fine.outputs['Fac'],bump.inputs['Height']); l.new(bump.outputs[0],p.inputs['Normal'])
 return m

def palette():
 global iron,bronze,edge,leather,bone,ember,black
 iron=worn('#10100F','#41403A',.65,.57)
 bronze=worn('#293A30','#8C8862',.7,.55)
 edge=worn('#51402B','#B49C6C',.72,.46)
 leather=worn('#100E0D','#30241E',0,.88)
 bone=worn('#6C6250','#C9B99A',.08,.73)
 black=worn('#090B0C','#191C1D',.2,.8)
 ember=plain_mat('#B54A19',.6,.25,'#FF701C',.6)

def scene(name):
 s=new_scene('u2_'+name,24); palette()
 s.world.node_tree.nodes['Background'].inputs[1].default_value=.18
 for o in s.objects:
  if o.type=='LIGHT':
   o.data.energy=2.5 if 'chaud' in o.name else .48
   o.data.color=rgba('#FFC287' if 'chaud' in o.name else '#80A8D9')[:3];o.data.angle=.15
 return s

def rivet(x,z,y=-.27,r=.04):
 flat_disk((x,y,z),r,.035,edge)
 curve([(x-r*.45,y-.025,z),(x+r*.45,y-.025,z)],.006,black)

def ticks(radius,y=-.2,n=24):
 for i in range(n):
  t=i*math.tau/n; r=radius
  curve([(r*math.sin(t),y,r*math.cos(t)),((r-.06)*math.sin(t),y,(r-.06)*math.cos(t))],.009,edge)

def flame(x=0,z=0,scale=1,y=-.4):
 pts=[(-.32,-.43),(-.44,-.1),(-.18,.23),(-.16,.63),(.15,.25),(.11,.04),(.31,.32),(.38,-.14),(.22,-.43)]
 slab([(x+a*scale,z+b*scale) for a,b in pts],ember,.025,y,.008)

# Load existing card functions without running the old rendering entrypoint.
tree=ast.parse((BASE/'r7c_render.py').read_text())
selected=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['diamond','base','front','back']]
import ui_elements as old
def mat(h,rough=.6,metal=.5,emit_hex=None,emit_strength=0):
 if emit_hex:return ember
 return {'#2B3340':iron,'#1D2430':leather,'#5E7390':bronze,'#C59A51':edge,'#E0BD79':edge,'#526177':bronze}.get(h,iron)
exec(compile(ast.Module(body=selected,type_ignores=[]),'r7c_card_layout','exec'))

def card(backside):
 (back if backside else front)()
 for sx in [-1,1]:
  for z in [-2.34,-1.3,0,1.3,2.34]:rivet(sx*1.73,z,-.23,.033)
  for i in range(17):
   z=-2.15+i*.265
   curve([(sx*1.58,-.265,z-.055),(sx*1.52,-.265,z),(sx*1.58,-.265,z+.055)],.008,bronze)
 if backside:
  for t in [i*math.tau/32 for i in range(32)]:
   curve([(1.3*math.sin(t),-.25,1.3*math.cos(t)),(1.4*math.sin(t),-.25,1.4*math.cos(t))],.009,bronze)

def medal(state='normal',kind='spell'):
 pressed=state=='pressed'; disabled=state in ['cooldown','disabled']; y=.06 if pressed else 0
 torus((0,y,0),1.02,.13,iron)
 torus((0,y-.13,0),.91,.045,bronze)
 torus((0,y-.15,0),.83,.018,edge if not disabled else iron)
 ticks(1.03,y-.142)
 for i in range(8):
  t=i*math.tau/8;rivet(1.04*math.sin(t),1.04*math.cos(t),y-.16,.035)
 if kind!='spell':flat_disk((0,y+.025,0),.83,.12,leather)
 if kind=='interact':hand(.69,y-.22,disabled)
 elif kind=='knob':
  flat_disk((0,y-.08,0),.77,.18,leather)
  for t in [-.45,.45]:curve([(-.55,y-.19,t),(.55,y-.19,t)],.012,bronze)
  flame(scale=.58,y=y-.24)
 elif kind=='base':
  for i in range(4):
   t=i*math.pi/2;slab([(0,.64),(-.06,.74),(.06,.74)],edge,.03,-.1,.003).rotation_euler[1]=t
 if not disabled:
  for sx in [-1,1]:
   o=slab([(-.025,-.07),(.025,-.07),(.025,.07),(-.025,.07)],ember,.025,y-.19,.004);o.location.x=sx*.97

def hand(k=1,y=-.4,disabled=False):
 # Angular engraved gauntlet, four articulated fingers and thumb; no toy flesh.
 m=iron if disabled else bone
 pts=[(-.38,-.33),(-.43,.03),(-.26,.21),(.22,.23),(.39,.04),(.32,-.35)]
 slab([(x*k,z*k) for x,z in pts],m,.12,y,.018)
 for i in range(4):
  x=(-.25+i*.155)*k;h=[.46,.61,.56,.39][i]*k
  o=slab(rrect(.12*k,h,.025,2),m,.11,y-.005,.01);o.location.x=x;o.location.z=.13*k+h/2
  for z in [.25*k,.4*k]:curve([(x-.05*k,y-.07,z),(x+.05*k,y-.07,z)],.012*k,bronze)
 slab([(-.36*k,-.11*k),(-.63*k,.12*k),(-.68*k,.37*k),(-.57*k,.43*k),(-.43*k,.18*k),(-.22*k,.04*k)],m,.13,y+.015,.012)
 o=slab(rrect(.8*k,.25*k,.025,2),leather,.15,y-.015,.012);o.location.z=-.42*k
 for x in [-.28,.28]:rivet(x*k,-.42*k,y-.11,.04*k)
 curve([(-.28*k,y-.07,-.2*k),(0,y-.075,.11*k),(.27*k,y-.07,-.2*k)],.015*k,bronze)

def rarity(name):
 col={'commun':('#1B1B1A','#636159'),'peu_commun':('#263C32','#719681'),'rare':('#1C2938','#6A8499'),'legendaire':('#5C3519','#C79C50')}[name]
 m=worn(*col,.7,.52)
 rr_ring(2.15,2.15,.1,.15,iron,.17,0,.02,3)
 rr_ring(2.08,2.08,.08,.055,m,.07,-.12,.009,3)
 rr_ring(1.86,1.86,.04,.018,edge if name=='legendaire' else m,.035,-.15,.004,3)
 for sx in [-1,1]:
  for sz in [-1,1]:
   rivet(sx*.98,sz*.98,-.17,.032)
   curve([(sx*.71,-.17,sz*.98),(sx*.87,-.17,sz*.98),(sx*.98,-.17,sz*.86),(sx*.98,-.17,sz*.71)],.012,m)
 if name=='legendaire':
  for sz in [-1,1]:
   o=slab([(-.2,0),(0,.17),(.2,0),(0,-.1)],m,.06,-.14,.009);o.location.z=sz*1.05
   o=slab([(-.04,0),(0,.06),(.04,0),(0,-.04)],ember,.025,-.19,.003);o.location.z=sz*1.05

def die(tint='commun'):
 # Solid ten-faced percentile trapezohedron with inset bone kites and engraved tens.
 col={'commun':('#36322C','#8F8878'),'peu_commun':('#263C32','#718C65'),'rare':('#342B45','#81718D'),'legendaire':('#644321','#C3A15E')}[tint]
 metal=worn(*col,.72,.49)
 verts=[Vector((0,0,1.25)),Vector((0,0,-1.25))]+[Vector((math.cos(i*math.tau/10),math.sin(i*math.tau/10),.132 if i%2==0 else -.132)) for i in range(10)]
 faces=[]
 for i in range(5):
  faces.append((0,2+(2*i)%10,2+(2*i+1)%10,2+(2*i+2)%10))
  faces.append((1,2+(2*i+1)%10,2+(2*i+2)%10,2+(2*i+3)%10))
 root=bpy.data.objects.new('U2_percentile_rotation',None);bpy.context.collection.objects.link(root)
 from ui_kit import _mesh
 body=_mesh('Solid bronze d100',verts,faces,metal);body.parent=root
 b=body.modifiers.new('Worn casting edges','BEVEL');b.width=.025;b.segments=2
 for idx,f in enumerate(faces):
  vv=[verts[j] for j in f];c=sum(vv,Vector())/4;n=(vv[1]-vv[0]).cross(vv[2]-vv[0]).normalized()
  if n.dot(c)<0:n=-n
  inset=[c+(v-c)*.83+n*.012 for v in vv]
  plaque=_mesh('Inset bone kite',inset,[(0,1,2,3)],bone);plaque.parent=root
  up=(Vector((0,0,1))-n*n.z).normalized();right=up.cross(n).normalized()
  basis=Matrix((right,up,n)).transposed().to_quaternion()
  cu=bpy.data.curves.new('Engraved percentile tens','FONT');cu.body=f'{idx*10:02}';cu.align_x='CENTER';cu.align_y='CENTER';cu.size=.36;cu.extrude=.001;cu.bevel_depth=.001
  ob=bpy.data.objects.new(cu.body,cu);bpy.context.collection.objects.link(ob);ob.data.materials.append(black);ob.location=c+n*.027;ob.rotation_mode='QUATERNION';ob.rotation_quaternion=basis;ob.parent=root
  # Narrow bronze underline distinguishes 60/90 after rotation.
  a1=c+n*.03-up*.21-right*.13;a2=c+n*.03-up*.21+right*.13
  o=curve([a1,a2],.009,metal);o.parent=root
 return root

jobs=[]
def render(path,fw,fh=None):
 p=Path(path); inv=json.loads(snapshot.read_text())['files'][p.as_posix()]
 w,h=inv['size'];front_camera(fw,fh or fw,w*2,h*2)
 raw=OUT/(p.stem+'.png');bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
 jobs.append({'path':p.as_posix(),'raw':str(raw)})

def main():
 for backflag in [False,True]:
  scene('card');card(backflag);render('game/assets/sprites/ui/cards/card_'+('back' if backflag else 'front')+'.png',3.9,5.7)
 scene('dice_rotation');root=die();axis=Vector((.45,.8,.35)).normalized()
 for k in range(20):
  root.rotation_mode='QUATERNION';root.rotation_quaternion=Euler((.55,.25,.16)).to_quaternion() @ __import__('mathutils').Quaternion(axis,math.tau*k/20)
  render(f'game/assets/sprites/ui/dice/d100_rot_{k:02}.png',2.9)
 for rarityname in ['commun','peu_commun','rare','legendaire']:
  scene('face_'+rarityname);root=die(rarityname);root.rotation_euler=(.8,.25,.1)
  render('game/assets/sprites/ui/dice/d100_face_'+rarityname+'.png',2.9)
  scene('frame_'+rarityname);rarity(rarityname);render('game/assets/sprites/icons/frame_'+rarityname+'.png',2.4)
 for state in ['normal','pressed','cooldown']:
  scene('spell_'+state);medal(state);suffix='' if state=='normal' else '_'+state
  render('game/assets/sprites/ui/spell_frame'+suffix+'.png',2.45)
 scene('ring');torus((0,0,0),1.03,.085,bronze);torus((0,-.05,0),1.03,.015,edge);ticks(1.07,-.09,48)
 render('game/assets/sprites/ui/spell_cooldown_ring.png',2.4)
 for state in ['normal','pressed','disabled']:
  scene('interact_'+state);medal(state,'interact');render('game/assets/sprites/ui/interact/interact_'+state+'.png',2.5)
 for kind in ['base','knob']:
  scene('joystick_'+kind);medal('normal',kind);render('game/assets/sprites/ui/joystick/joystick_'+kind+'.png',2.5)
 scene('hand');hand(1,0);render('game/assets/sprites/ui/hud/icon_interact_hand.png',1.8)
 # Separate modeled backdrop for the contact-sheet chest-opening mockup.
 scene('opening_panel');slab(rrect(9,5.8,.08,2),leather,.2,.1,.02);rr_ring(8.9,5.7,.07,.08,iron,.1,-.05,.01,2)
 front_camera(9.2,6,1200,780);bpy.context.scene.render.filepath=str(OUT/'opening_panel.png');bpy.ops.render.render(write_still=True)
 blend=ROOT/'art/blender/ui/u2_source.blend';blend.parent.mkdir(parents=True,exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(blend))
 (BASE/'_u2_jobs.json').write_text(json.dumps(jobs))
 import subprocess
 subprocess.run([PY,str(BASE/'u2_finish.py')],check=True)
if __name__=='__main__':main()
