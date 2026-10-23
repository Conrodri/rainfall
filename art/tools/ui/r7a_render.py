"""R7a: modeled replacements using the existing UI geometry and palette."""
import sys,math,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_lib import *
import items_a as a
import items_b as b
import items_c as c
poly=b.poly

def bevel(o,w=.035):
 if o.type=='MESH' and not o.modifiers:
  m=o.modifiers.new('Small forged edge','BEVEL');m.width=w;m.segments=2
  o.modifiers.new('Weighted corners','WEIGHTED_NORMAL')
 return o

def front_ring(x,z,r,m,y=-.25,width=.045):return torus((x,y,z),r,width,m)
def jewel(x,z,r=.12,m=None,y=-.32):return sphere((x,y,z),(r,r*.6,r),m or a.cyan)
def crystal_fire():
 # Asymmetric volcanic shard, bright split face and basalt footing.
 rock=mat('#3F2B1E',.8);ember=mat('#C23B12',.45,.2)
 for x,z,h,r,ang in [(-.15,.12,2.2,.5,-.18),(.53,-.48,1.1,.33,.5),(-.65,-.61,.85,.28,-.65)]:
  o=crystal((x,0,z),r,h,ember);o.rotation_euler[1]=ang
 poly([(-.29,-.64),(-.4,.14),(-.27,.75),(-.1,1.16),(.15,.25),(.08,-.53)],a.orange,.07,-.4)
 poly([(-.19,-.44),(-.21,.11),(-.13,.6),(-.03,.87),(.03,.15)],a.ivory,.04,-.46)
 for x in [-.52,0,.5]:bevel(poly([(x-.24,-.9),(x-.3,-.7),(x-.06,-.57),(x+.2,-.7),(x+.23,-.98)],rock,.48,.04))

def ice():
 # Tall tapered ice spear with asymmetric fractured buttresses.
 for x,y,z,h,r,tilt in [(0,0,.16,2.5,.34,-.12),(-.48,.05,-.4,1.25,.3,-.55),(.44,.12,-.27,1.6,.27,.37)]:
  o=crystal((x,y,z),r,h,a.light if x==0 else a.cyan);o.rotation_euler[1]=tilt
 for z in [-.55,-.16,.23]:
  curve([(-.22,-.34,z+.1),(-.06,-.39,z),(.18,-.33,z+.17)],.028,a.light)
 # Chunky frost stars near the base rather than fine noise.
 for x in [-.52,.47]:
  for angle in [0,math.pi/3,-math.pi/3]:
   dx=.18*math.sin(angle);dz=.18*math.cos(angle)
   curve([(x-dx,-.36,-.65-dz),(x+dx,-.36,-.65+dz)],.035,a.light)

def clock():
 a.disk((0,0,0),.94,.3,a.gold);front_ring(0,0,.89,a.ivory,-.18,.035)
 a.disk((0,-.19,0),.78,.07,a.dark);front_ring(0,0,.7,b.purple,-.26)
 for i in range(8):
  t=i*math.tau/8;v=Vector((math.sin(t),0,math.cos(t)));p=v*.58
  o=poly([(-.045,-.1),(.045,-.1),(.08,.05),(0,.13),(-.08,.05)],b.purple,.035,-.29)
  o.rotation_euler[1]=t;o.location.x=p.x;o.location.z=p.z
 for pts in [[(0,0),(-.34,.24) ],[(0,0),(.13,.53)]]:
  curve([(x,-.35,z) for x,z in pts],.055,a.ivory)
 jewel(0,0,.105,a.gold,-.38)
 for x in [-.7,.7]:bevelled_box((x,.05,.79),(.24,.26,.25),a.gold,.06)
 front_ring(0,1.02,.16,a.gold,0,.06)

def blades():
 # Two spatially separated diagonals, readable edge and wrapped grips.
 for sign in [-1,1]:
  def build():
   bevel(poly([(-.13,-.22),(-.17,.53),(0,1.25),(.18,.53),(.13,-.22)],a.steel,.19),.018)
   poly([(0,-.22),(0,1.25),(.18,.53),(.13,-.22)],a.light,.025,-.115)
   bevelled_box((0,0,-.31),(.73,.29,.13),a.gold,.04)
   bevelled_box((0,0,-.65),(.21,.24,.55),a.leather,.04)
   for z in [-.46,-.61,-.76]:curve([(-.11,-.13,z-.04),(.11,-.13,z+.04)],.027,a.gold)
   jewel(0,-.98,.14,a.gold,0)
  c.group(build,loc=(sign*.17,sign*.12,0),rot=(0,sign*.6,0))

def poison():
 # Bulbous green retort and long hooked nozzle, separate falling drop.
 lathe([(0,-.87),(.44,-.85),(.64,-.56),(.61,-.13),(.39,.2),(.21,.39),(.2,.69)],material=a.green)
 cylinder((0,0,.62),.24,.19,a.gold)
 curve([(0,0,.7),(.15,0,.95),(.55,0,1.04),(.74,0,.82)],.13,a.dark)
 curve([(-.4,-.44,-.47),(-.49,-.4,-.21),(-.33,-.27,.05)],.045,a.light)
 b.drop(.76,0,.38,.14,.45,a.green)
 # Skull label, no text.
 bevel(poly([(-.25,-.12),(-.2,.05),(.2,.05),(.25,-.12),(.15,-.34),(-.15,-.34)],a.ivory,.07,-.59),.03)
 for x in [-.09,.09]:jewel(x,-.1,.055,a.dark,-.65)
 for x in [-.09,0,.09]:bevelled_box((x,-.65,-.31),(.045,.03,.11),a.ivory,.01)

def cloak():
 # Actual draped mesh: flared hem and alternating raised cloth folds.
 xs=[-.95,-.68,-.38,0,.38,.68,.95]
 vs=[]
 for row in range(4):
  t=row/3
  for j,x in enumerate(xs):
   vs.append((x*(.43+.57*t),-.02-(.17 if j%2 else -.04)*t,.58-1.55*t+( .12 if row==3 and j%2 else 0)))
 fs=[]
 for r in range(3):
  for j in range(6):q=r*7+j;fs.append((q,q+1,q+8,q+7))
 me=bpy.data.meshes.new('Draped cloak');me.from_pydata(vs,[],fs);me.update();o=bpy.data.objects.new('Draped cloak',me);bpy.context.collection.objects.link(o);o.data.materials.append(a.slate)
 sol=o.modifiers.new('Heavy cloth','SOLIDIFY');sol.thickness=.08
 bevel(poly([(-.43,.43),(-.47,.8),(-.2,1.14),(.2,1.14),(.47,.8),(.43,.43),(0,.24)],a.slate,.5,-.02),.06)
 poly([(-.28,.49),(-.26,.78),(0,.99),(.26,.78),(.28,.49),(0,.36)],a.dark,.04,-.31)
 for s in [-1,1]:curve([(s*.38,-.28,.45),(s*.29,-.29,.1),(s*.58,-.25,-.76)],.028,a.light)
 front_ring(0,.22,.115,a.gold,-.35,.04);jewel(0,.22,.055,b.purple,-.39)

def thorns():
 # A thorny curved bramble, open central negative space.
 pts=[]
 for i in range(25):
  t=i/24*math.tau*1.22;r=.55+.25*i/24
  pts.append((r*math.sin(t),.1*math.sin(t*2),r*math.cos(t)))
 curve(pts,.12,a.wood)
 for i in [1,4,7,10,13,16,19,22]:
  p=Vector(pts[i]);out=Vector((p.x,0,p.z)).normalized();q=p+out*.5+Vector((.08,-.07,.03))
  o=cone((p+q)/2,.16,(q-p).length,a.dark,5);c.toward(o,q-p)
 curve([(-.45,-.18,-.6),(-.27,-.22,-.3),(.04,-.22,-.06),(.35,-.2,.39)],.085,a.leather)
 for p,v in [((-.27,-.22,-.3),(-.35,-.1,.28)),((.12,-.22,.03),(.35,-.1,.2))]:
  p=Vector(p);v=Vector(v);o=cone(p+v/2,.14,v.length,a.steel,5);c.toward(o,v)

def lightning():
 b.eclair_en_bouteille()
 # Reinforced neck, blue glass bevel and a powerful forked discharge.
 front_ring(0,-.72,.18,a.gold,-.55,.035)
 poly([(.01,.03),(-.24,.05),(-.41,.29),(-.34,.0),(-.12,-.13)],a.light,.035,-.64)
 for x in [-.35,.35]:jewel(x,-.61,.035,a.cyan,-.61)

NEW=dict(zip(b.IDS[:8],[crystal_fire,ice,clock,blades,poison,cloak,thorns,lightning]))

def refine(ident):
 # Explicit semantic modeling additions to the existing volumes.
 if ident=='rune_de_portee':
  for x,z in [(-.55,.55),(.54,.48),(-.55,-.53),(.48,-.57)]:jewel(x,z,.055,a.gold,-.29)
  curve([(-.7,-.23,.2),(-.5,-.26,.12),(-.6,-.24,-.05)],.025,a.dark)
 elif ident=='morsure_vorace':
  for s in [-1,1]:
   curve([(s*.72,-.14,.35),(s*.66,-.2,.69),(s*.4,-.2,.84)],.12,a.ivory)
   curve([(s*.75,-.18,.35),(s*.7,-.2,.57)],.028,a.red)
 elif ident=='tonique_vital':
  for z in [.71,.79,.87]:curve([(-.22,-.19,z),(.22,-.19,z+.025)],.023,a.wood)
  curve([(.47,-.51,-.53),(.52,-.49,-.25)],.04,a.red)
 elif ident=='orbe_de_veille':
  front_ring(0,.1,.73,a.gold,.06,.045)
  for z in [-.88,-.73]:cylinder((0,0,z),.54,.09,a.dark)
 elif ident=='sang_chaud':
  # Ember motes reinforce the low-health rage identity.
  for x,z,h in [(-.64,.2,.38),(.64,-.23,.3),(.38,.72,.27)]:b.drop(x,.02,z,.09,h,a.orange)
 elif ident=='marque_du_chasseur':
  for x in [-.62,.62]:
   for z in [-.68,.68]:jewel(x,z,.065,a.steel,-.2)
  poly([(-.12,-.02),(0,.2),(.12,-.02),(0,-.19)],a.red,.08,-.44)
 elif ident=='carquois_affute':
  for z in [-.65,-.4,-.15,.1]:
   curve([(.2,-.55,z-.055),(.34,-.48,z+.055)],.024,a.ivory)
  bevelled_box((-.03,-.6,.21),(.28,.08,.25),a.gold,.04)
  bevelled_box((-.03,-.65,.21),(.14,.025,.12),a.dark,.01)
 elif ident=='pointe_perforante':
  for z in [-.55,-.67,-.79]:curve([(-.13,-.13,z),(.13,-.13,z+.06)],.027,a.gold)
  curve([(0,-.205,-.3),(0,-.205,.9)],.02,a.ivory)
 elif ident=='aimant_d_ame':
  for s in [-1,1]:
   b.drop(s*.83,-.12,.96,.13,.44,a.cyan)
   for dx in [-.04,.04]:jewel(s*.83+dx,1.01,.022,a.dark,-.24)
 elif ident=='chronometre_brise':
  # Physically missing rim wedge and exposed, offset cog.
  c.gear(.73,.46,.25,7,a.steel,-.25,.12)
  poly([(.57,.72),(.78,.85),(.64,.94),(.45,.81)],a.dark,.06,-.23)
 elif ident=='tempete_de_braises':
  for x,z in [(-.64,.22),(.6,.62),(-.32,1.12)]:
   o=crystal((x,-.15,z),.1,.36,a.orange);o.rotation_euler[1]=.5
 elif ident=='coeur_de_glace':
  poly([(-.6,.41),(-.34,.65),(-.06,.4),(-.23,-.23)],a.light,.02,-.24)
  curve([(.12,-.3,.58),(-.05,-.31,.17),(.21,-.3,-.11),(.03,-.3,-.55)],.032,a.cyan)
 elif ident=='peste_vivante':
  for x in [-.48,.48]:curve([(x,-.55,.51),(x*.85,-.59,.62)],.045,a.dark)
 elif ident=='oeil_du_predateur':
  for i in range(12):
   t=i*math.tau/12;curve([(.55*math.sin(t),-.3,.55*math.cos(t)),(.68*math.sin(t),-.23,.68*math.cos(t))],.025,a.red)
 elif ident=='bouclier_reactif':
  for s in [-1,1]:curve([(s*.72,-.28,.3),(s*.63,-.29,.36),(s*.5,-.3,.3)],.035,a.light)
 elif ident=='faveur_du_marchand':
  for x in [-.48,.48]:curve([(x,-.57,-.55),(x*1.15,-.57,-.26),(x,-.5,.04)],.025,a.wood)
  poly([(-.11,-.26),(0,-.1),(.11,-.26),(0,-.4)],a.gold,.025,-.83)
 elif ident=='danseur':
  for z in [-.02,.16,.34]:curve([(-.27,-.28,z),(.06,-.28,z+.13)],.025,a.ivory)
  bevelled_box((.26,-.41,-.35),(.28,.04,.19),a.gold,.025)
 elif ident=='phenix_de_poche':
  front_ring(0,1.12,.13,a.gold,.05,.045)
  for s in [-1,1]:curve([(s*.32,-.29,.17),(s*.53,-.28,.28),(s*.68,-.26,.35)],.025,a.ivory)
 elif ident=='rafale_d_acier':
  for x,z in [(-.9,-.3),(.85,.05)]:curve([(x,.12,z-.42),(x*.85,.12,z)],.045,a.light)
 elif ident=='coeur_du_chronomancien':
  front_ring(0,0,.35,a.dark,-.31,.035)
  curve([(-.18,-.37,.12),(0,-.37,0),(.05,-.37,.26)],.035,a.cyan)
 elif ident=='couronne_d_echo':
  # Third ghost, scaled smaller and raised behind the two existing echoes.
  ghost=mat('#5FD4E8',.4,.1,'#5FD4E8',.25)
  def tiny():
   poly([(-.36,0),(-.42,.46),(-.2,.29),(0,.62),(.2,.29),(.42,.46),(.36,0)],ghost,.08)
   curve([(-.35,0,.03),(.35,0,.03)],.04,a.light)
  c.group(tiny,loc=(0,.9,1.15),scale=.8)
 elif ident=='nova_infinie':
  # Visible central pale nova in front of the orange envelope.
  jewel(0,0,.26,a.ivory,-.59)
 elif ident=='armure_du_colosse':
  for s in [-1,1]:
   bevel(poly([(s*.12,.15),(s*.24,.48),(s*.63,.45),(s*.74,.16),(s*.55,-.02)],a.slate,.12,-.33),.05)
   for z in [.4,.66]:jewel(s*1.05,z,.065,a.steel,-.43)
 elif ident=='moisson':
  # Broad crescent blade, with an unmistakably tapered cutting tip.
  poly([(-1.0,-.15),(-.98,.35),(-.72,.72),(-.25,.96),(.27,.87),(.62,.61),(.22,.7),(-.17,.69),(-.5,.5),(-.71,.16),(-.76,-.2)],a.steel,.13,-.15)
  curve([(-.76,-.23,-.12),(-.71,-.23,.16),(-.5,-.23,.5),(-.17,-.23,.69),(.22,-.23,.7),(.62,-.23,.61)],.026,a.light)
 elif ident=='de_pipe':
  for x,z in [(.9,.95),(-.95,.85)]:
   poly([(x-.13,z),(x-.035,z+.035),(x,z+.17),(x+.035,z+.035),(x+.13,z),(x+.035,z-.035),(x,z-.17),(x-.035,z-.035)],a.gold,.035,-.34)

def echo_crown():
 # Upright front-facing crests: keep the gold crown legible beside its echoes.
 ghost=mat('#5FD4E8',.35,.15,'#5FD4E8',.25)
 ghost.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.58
 ghost.surface_render_method='DITHERED'
 def crown(m,gem):
  bevel(poly([(-.73,-.3),(-.87,.53),(-.5,.27),(-.37,.84),(0,.45),(.37,.84),(.5,.27),(.87,.53),(.73,-.3)],m,.22),.035)
  curve([(-.74,-.17,-.2),(-.38,-.23,-.28),(0,-.25,-.31),(.38,-.23,-.28),(.74,-.17,-.2)],.075,m)
  for x,z in [(-.37,.84),(.37,.84),(-.87,.53),(.87,.53)]:jewel(x,z,.07,gem,-.04)
  for x in [-.42,0,.42]:jewel(x,-.08,.085,gem,-.16)
 for loc,scale in [((-.57,.5,.6),.72),((.55,.6,.81),.72),((0,.9,1.12),.58)]:
  c.group(lambda:crown(ghost,a.light),loc=loc,scale=scale)
 c.group(lambda:crown(a.gold,a.red),loc=(0,-.25,-.48))

NEW['couronne_d_echo']=echo_crown

# Run each packet in its own background process; never touches items_a or its assets.
if __name__=='__main__':
 packet=int(sys.argv[sys.argv.index('--')+1]);ids=b.IDS+c.IDS
 chosen=ids[packet*8:min((packet+1)*8,len(ids))]
 # Final packet contains nine objects, avoiding a one-item packet.
 if packet==3:chosen=ids[24:]
 scenes=[]
 for ident in chosen:
  s=bpy.data.scenes.new(ident);bpy.context.window.scene=s;reset_scene();setup_render();s.eevee.taa_render_samples=32;a.palette()
  b.purple=mat('#8A6AB0',.35,.2,'#8A6AB0',.2);b.burgundy=mat('#A92232',.3,.1)
  if ident in NEW:NEW[ident]()
  else:
   getattr(b if ident in b.IDS else c,ident)();refine(ident)
  objects=[o for o in s.objects if o.type in {'MESH','CURVE'}]
  for o in objects:
   if o.name.startswith(('Volume','Lame','Tranchant')):bevel(o,.018)
  outline(objects,.012)
  frame_object_ortho([o for o in s.objects if o.type in {'MESH','CURVE'}])
  raw=ROOT/'art/renders/ui/items'/f'{ident}.png';render_to(raw);finalize(raw,ROOT/'game/assets/sprites/icons/items'/f'{ident}.png')
  scenes.append(s);print('R7A_OK',ident,flush=True)
 for s in list(bpy.data.scenes):
  if s not in scenes:bpy.data.scenes.remove(s)
 bpy.context.window.scene=scenes[0]
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui'/f'r7a_packet_{packet+1}.blend'))
 print('PASS packet',packet+1,len(chosen),flush=True)
