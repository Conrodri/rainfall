"""R7b: forged rarity borders and sculpted Ardent fire glyphs; reuses Claude UI kit."""
import sys,math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import spells_frames as old
from ui_kit import *
poly=old.poly

def fire(x,z,w,h,bend=0,y=0):
 pts=[(-.42,-.5),(-.62,-.12),(-.45,.21),(-.26,.04),(-.12,.54),(.16,.86),(.12,.36),(.46,.09),(.49,-.22),(.26,-.5)]
 for scale,col,yy in [(1,'#C23B12',y),(.78,'#FF7A1F',y-.08),(.46,'#FFCF64',y-.16)]:
  p=[(x+w*(u*scale+bend*(v+.5)**2),z+h*(v*scale-.5*(1-scale))) for u,v in pts]
  o=poly(p,mat(col,.4,.05,col,.28),.12,yy)
  m=o.modifiers.new('Sculpted flame edge','BEVEL');m.width=.025;m.segments=2

def jewel(x,z,r,m,y=-.32):
 return poly([(x-r,z),(x,z+r*1.4),(x+r,z),(x,z-r*1.4)],m,.09,y)

def frame(n):
 rank=list(old.FRAMES).index(n);col=old.FRAMES[n]
 metal=mat(col,.34,.5);dark=mat(old.tint(col,.4),.6,.3);edge=mat(old.tint(col,1.45),.33,.4,col,.15)
 rr_ring(2.30,2.30,.34,.21,dark,.22,0,.025)
 rr_ring(2.26,2.26,.32,.125,metal,.15,-.14,.025)
 rr_ring(2.02,2.02,.21,.035,edge,.08,-.23,.01)
 rr_ring(2.29,2.29,.34,.035,edge,.08,-.23,.01)
 for sx in [-1,1]:
  for sz in [-1,1]:
   x,z=sx*.99,sz*.99
   if rank==0:
    sphere((x,-.25,z),(.035,.025,.035),edge)
   else:
    jewel(x,z,.075+rank*.009,edge)
    if rank>=2:
     curve([(sx*.65,-.26,sz*1.07),(sx*.82,-.26,sz*1.07),(sx*1.07,-.26,sz*.82),(sx*1.07,-.26,sz*.65)],.023,edge)
 if rank>=1:
  for s in [-1,1]:jewel(0,s*1.07,.06,edge)
 if rank>=2:
  for s in [-1,1]:jewel(s*1.07,0,.075,edge)
 if rank==3:
  gold=mat('#FFE9A8',.28,.45,'#FFB347',.5)
  for s in [-1,1]:
   for x in [-.26,0,.26]:
    poly([(x-.09,s*1.02),(x-.055,s*1.15),(x,s*(1.21 if x==0 else 1.17)),(x+.055,s*1.15),(x+.09,s*1.02)],gold,.07,-.28)
   for z in [-.22,.22]:jewel(s*1.08,z,.045,gold)

def eclat():
 def build():
  fire(0,0,.95,1.5,.18)
  for x,z,h in [(-.5,-.55,.75),(.48,-.5,.63)]:fire(x,z,.32,h,.12,.08)
 old.group(build,rot=(0,.9,0))

def nova():
 for i in range(9):
  t=i*math.tau/9
  def build():fire(0,1.0,.43,.65,.3)
  old.group(build,rot=(0,t,0))
 torus((0,-.05,0),.86,.12,mat('#C23B12',.4,0,'#C23B12',.25))
 torus((0,-.19,0),.81,.055,mat('#FFCF64',.4,0,'#FFCF64',.4))
 jewel(0,0,.16,a.ivory)

def embers():
 o=torus((0,.12,0),.94,.045,a.gold);o.scale.z=.62
 for x,z in [(-.84,-.12),(.5,-.48),(.5,.63)]:
  def build():fire(0,0,.54,.72,.12)
  old.group(build,loc=(x,-.08,z),rot=(0,.55,0))

def ashes():
 rock=mat('#414653',.85);hot=mat('#FF7A1F',.5,0,'#FF7A1F',.4)
 for x,z,r in [(-.65,-.6,.46),(0,-.64,.6),(.65,-.6,.45),(-.29,-.18,.4),(.35,-.22,.38)]:
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=r,location=(x,0,z));o=bpy.context.object;o.scale=(1,.65,.65);o.data.materials.append(rock)
  curve([(x-r*.3,-r*.68,z+r*.25),(x,-r*.75,z-r*.1),(x+r*.36,-r*.68,z+r*.12)],.04,hot)
 for x,z in [(-.3,.35),(.2,.68),(-.05,1.03)]:
  sphere((x,.16,z),(.25,.16,.23),mat('#7C8898',.85))
 for x,z in [(-.72,.23),(.67,.55)]:jewel(x,z,.055,hot)

def blaze():
 for x,z,w,h,b in [(-.65,-.3,.6,1.1,-.17),(.6,-.35,.65,1.35,.14),(0,-.1,1.05,2.0,.08)]:fire(x,z,w,h,b,-.08 if x==0 else .08)
 for x in [-.55,.55]:
  o=bevelled_box((x,.12,-1.0),(1.6,.3,.23),mat('#3F2B1E',.8),.05);o.rotation_euler[1]=x*.65

def pillar():
 o=torus((0,0,-1.04),.77,.095,a.gold);o.scale.z=.32
 fire(0,0,.85,2.5,.045)
 for x in [-.58,.58]:fire(x,-.6,.31,.85,x*.25)
 for z,r in [(-.6,.62),(.18,.48),(.86,.32)]:
  o=torus((0,-.3,z),r,.038,a.gold);o.scale.z=.28

def meteors():
 for x,z,s in [(-.65,-.45,.4),(.13,.3,.49),(.8,-.65,.29)]:
  def build():
   fire(0,s*.75,s*1.7,s*2.6,.06,.1)
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=s,location=(0,-.17,-s*.5));o=bpy.context.object;o.data.materials.append(mat('#414653',.8))
   poly([(-s*.6,-s*.2),(0,-s*.65),(s*.5,-s*.45)],mat('#FF7A1F',.5,0,'#FF7A1F',.6),.05,-s-.12)
  old.group(build,loc=(x,0,z),rot=(0,-.55,0))

def phoenix():
 for s in [-1,1]:
  for k in range(4):
   x=s*(1.4-k*.19);z=1.0-k*.34
   poly([(s*.12,-.18),(s*.6,.62),(x,z+.42),(x-s*.1,z-.14),(s*.64,-.34)],mat('#C23B12' if k%2==0 else '#FF7A1F',.4,0,'#FF7A1F',.25),.13,-k*.055)
  curve([(s*.17,-.3,.05),(s*.58,-.3,.52),(s*1.22,-.3,1.13)],.035,a.gold)
 for x in [-.3,0,.3]:fire(x,-.9,.31,.9,x*.6,.08)
 fire(0,-.1,.6,1.35,.04,-.28)
 sphere((0,-.32,.7),(.18,.13,.2),a.gold)
 poly([(.1,.76),(.4,.66),(.1,.61)],a.ivory,.08,-.36)
 sphere((.07,-.47,.76),(.035,.02,.035),a.dark)

FUNCS=dict(zip(old.SPELLS,[eclat,nova,ashes,blaze,embers,pillar,meteors,phoenix]))
for n in list(old.FRAMES)+old.SPELLS:
 s=new_scene('R7b_'+n,24)
 if n in old.FRAMES:
  frame(n);outline(meshes(),.009);front_camera(2.56,2.56,512,512)
 else:
  FUNCS[n]();outline(meshes(),.016);front_camera(4,4,512,512);frame_object_ortho(meshes(),.09)
 render_to(old.RAW/f'{n}.png')
save_blend('r7b_spells_frames.blend')
print('R7B_RENDER_PASS',flush=True)
