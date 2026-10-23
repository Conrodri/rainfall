"""R7c sculpted slate/brass cards, faceted percentile die and chunky HUD objects.
Reuses ui_elements geometry, camera, animation indexing and fit jobs.
"""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import ui_elements as old
from ui_kit import *

def diamond(x,z,r,m,y=-.29):
 o=old.poly_diamond(r,m,.07,y);o.location.x=x;o.location.z=z;return o

def base(back=False):
 W,H=3.7,5.4
 stone=mat('#2B3340',.72,.18);dark=mat('#1D2430',.8,.1)
 steel=mat('#5E7390',.4,.6);gold=mat('#C59A51',.38,.55)
 light=mat('#E0BD79',.36,.45);ember=mat('#FF7A1F',.4,.1,'#FF7A1F',.4)
 slab(rrect(W,H,.18,6),stone,.22,.04,.035)
 rr_ring(W-.035,H-.035,.17,.16,steel,.17,-.08,.025,6)
 rr_ring(W-.13,H-.13,.13,.032,light,.07,-.19,.008,6)
 rr_ring(W-.4,H-.4,.12,.055,dark,.1,-.17,.012,6)
 rr_ring(W-.55,H-.55,.10,.025,gold,.06,-.23,.008,6)
 for sx in [-1,1]:
  for sz in [-1,1]:
   diamond(sx*1.64,sz*2.49,.085,light)
   curve([(sx*1.3,-.23,sz*2.5),(sx*1.49,-.23,sz*2.5),(sx*1.65,-.23,sz*2.32),(sx*1.65,-.23,sz*2.15)],.018,gold)
 return W,H,stone,dark,gold,ember

def front():
 W,H,stone,dark,gold,ember=base()
 # Quiet flat fields with recessed bevels; no ornament inside text regions.
 for w,h,z in [(2.85,2.65,1.17),(3.0,.5,-.51),(3.0,1.66,-1.68)]:
  o=slab(rrect(w,h,.1,6),dark,.07,-.17,.018);o.location.z=z
  o=rr_ring(w,h,.1,.045,gold if z>-.6 else mat('#526177',.6,.3),.07,-.24,.01,6);o.location.z=z
 for sx in [-1,1]:diamond(sx*1.48,-.51,.07,gold)

def back():
 W,H,stone,dark,gold,ember=base(True)
 slab(rrect(3.0,4.65,.12,6),dark,.06,-.17,.02)
 torus((0,-.28,0),1.12,.045,gold)
 torus((0,-.29,0),.94,.023,mat('#5E7390',.4,.5))
 for i in range(8):
  t=i*math.tau/8
  o=diamond(1.12*math.sin(t),1.12*math.cos(t),.10,gold);o.rotation_euler[1]=t
 diamond(0,0,.87,gold,-.3);diamond(0,0,.73,stone,-.36)
 # Three sculpted tongues of ember, matching the remade Ardent icon family.
 for x,z,w,h in [(-.28,-.02,.28,.65),(.27,-.12,.26,.52),(0,.03,.43,1.12)]:
  pts=[(x-w*.5,z-h*.5),(x-w*.62,z),(x-w*.2,z+h*.23),(x+w*.08,z+h*.65),(x+w*.2,z+h*.12),(x+w*.5,z-h*.12),(x+w*.35,z-h*.5)]
  slab(pts,ember,.08,-.46,.018)
 diamond(0,-.25,.14,mat('#FFE9A8',.4,0,'#FFB347',.5),-.53)
 for sz in [-1,1]:
  diamond(0,sz*1.95,.18,gold)
  for k in range(2):
   curve([(-.47+k*.12,-.27,sz*(1.61+k*.19)),(0,-.27,sz*(1.43+k*.19)),(.47-k*.12,-.27,sz*(1.61+k*.19))],.027,gold)

def dice(col,ember_hex='#FF7A1F',name='de'):
 die,wire=original_dice(col,ember_hex,name)
 wire.modifiers['Fil'].thickness=.013
 wire.data.materials.clear();wire.data.materials.append(mat(ember_hex,.42,.45,ember_hex,.18))
 # Varied forged faces rather than an emissive cage.
 from mathutils import Color
 mats=[mat(col,.36,.48),mat('#2B3340',.5,.5),mat(ember_hex,.4,.42)]
 die.data.materials.clear()
 for m in mats:die.data.materials.append(m)
 for p in die.data.polygons:p.material_index=1 if p.index%7==0 else (2 if p.index%11==0 else 0)
 bevel=die.modifiers.new('Forged facet edges','BEVEL');bevel.width=.009;bevel.segments=1
 return die,wire

def gold():
 brass=mat('#C58E28',.36,.6);light=mat('#FFE0 87'.replace(' ',''),.35,.5)
 a.disk((0,0,0),.91,.25,brass);torus((0,-.16,0),.81,.055,light)
 a.disk((0,-.17,0),.70,.05,mat('#A8741A',.5,.5))
 diamond(0,0,.49,light,-.25);diamond(0,0,.26,brass,-.31)
 for i in range(8):
  t=i*math.tau/8;sphere((.79*math.sin(t),-.19,.79*math.cos(t)),(.035,.025,.035),brass)

def ruby():
 red=mat('#D1243A',.3,.18);pink=mat('#FF6B7A',.3,.1)
 # Broad diamond planes, held in a dark garnet bevel.
 diamond(0,-.05,.94,mat('#641E35',.45,.25),0)
 pts=[(-.69,.24),(-.42,.67),(.42,.67),(.69,.24),(0,-.93)]
 slab(pts,red,.34,-.12,.035)
 for p,c in [([(-.42,.67),(0,.29),(.42,.67)],'#FF8B9A'),([(-.69,.24),(0,.29),(-.42,.67)],'#EF4763'),([(0,.29),(.69,.24),(.42,.67)],'#FF6B7A'),([(-.69,.24),(0,-.93),(0,.29)],'#A91D42'),([(0,.29),(0,-.93),(.69,.24)],'#E82C51')]:slab(p,mat(c,.34,.15),.025,-.315,.006)

def xp():
 for x,z,r,h,t in [(0,.06,.45,1.95,-.12),(-.54,-.43,.25,1.05,-.55),(.53,-.36,.24,1.2,.48)]:
  o=crystal((x,0,z),r,h,mat('#5FD4E8' if x==0 else '#2A8FB0',.34,.2,'#5FD4E8',.16));o.rotation_euler[1]=t
 curve([(-.16,-.39,-.1),(-.19,-.39,.34),(-.05,-.29,.77)],.035,mat('#D9F6FF',.4))

def pause():
 a.disk((0,0,0),.95,.24,mat('#2B3340',.6,.4));torus((0,-.15,0),.88,.065,mat('#7C8898',.4,.6))
 torus((0,-.19,0),.75,.022,mat('#C59A51',.4,.5))
 for x in [-.27,.27]:bevelled_box((x,-.24,0),(.28,.17,.92),mat('#FFE9A8',.4,.2),.035)

def settings():
 original_settings()
 for o in meshes():
  if o.name.startswith('Anneau') and o.location.y<-.25:
   o.data.materials.clear();o.data.materials.append(mat('#C59A51',.4,.5))
 # Raised brass hub fasteners read at mobile size.
 for t in [math.pi/4,math.pi*1.25]:sphere((.4*math.sin(t),-.24,.4*math.cos(t)),(.06,.035,.06),a.gold)

def hand():
 old.hud_hand_original()
 # Leather wrist guard and brass clasp anchor the hand silhouette.
 bevelled_box((0,-.1,-.65),(.98,.38,.3),mat('#563B32',.65,.1),.06)
 diamond(0,-.65,.13,a.gold,-.33)

original_dice=old.dice_scene;original_settings=old.hud_settings
old.hud_hand_original=old.hud_hand
old.card_base=base;old.build_card_front=front;old.build_card_back=back
old.dice_scene=dice
old.hud_gold=gold;old.hud_ruby=ruby;old.hud_xp=xp;old.hud_pause=pause;old.hud_settings=settings;old.hud_hand=hand
original_camera=old.front_camera
def camera(w,h,rw,rh,*args,**kwargs):
 return original_camera(w,5.68 if rh==1120 else h,rw,rh,*args,**kwargs)
old.front_camera=camera
old.save_blend=lambda name:save_blend('r7c_ui_elements.blend')
old.main()
