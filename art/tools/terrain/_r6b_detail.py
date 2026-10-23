"""R6b geometry refinements; Blender-only surfaces and soft ground shadows."""
import math,random,bpy
from mathutils import Vector

def enrich(P,name,p):
 B=P.box; C=P.cyl; L=P.line; S=P.sphere; R=P.ring
 rng=random.Random(160+sum(map(ord,name)))
 if name=='cedar_giant':
  for i in range(11):
   a=i*2.399;z=2.4+i*.19
   L([(.4*math.cos(a),.4*math.sin(a),z), (1.12*math.cos(a),1.12*math.sin(a),z+.25),(1.55*math.cos(a),1.55*math.sin(a),z+.18)],.085,p['bark2'])
   for j in range(3):
    x=(.9+j*.27)*math.cos(a);y=(.9+j*.27)*math.sin(a)
    S((x,y,z+.26),(.46,.29,.16),p['needles'] if j%2 else p['moss'])
  for i in range(11):
   a=i*math.tau/11
   L([(.96*math.cos(a),.96*math.sin(a),.3),(.87*math.cos(a+.04),.87*math.sin(a+.04),1.5),(.78*math.cos(a),.78*math.sin(a),3.6)],.025,p['rim'] if i%4==0 else p['bark2'])
 elif name.startswith('root_arch'):
  for o in list(bpy.context.scene.objects):
   if o.type!='CURVE' or o.data.bevel_depth<.15:continue
   pts=[Vector(pt.co[:3]) for pt in o.data.splines[0].points]
   for a,b in zip(pts,pts[1:]):
    for f in (.2,.48,.76):
     v=a.lerp(b,f);S(v+Vector((0,-.13,.09)),(.16,.055,.07),p['lichen'])
  # fine tendrils hang from the arch, with pale weathered bark ridges
  for x in (-.6,.1,.7):
   z=1.0 if name.endswith('a') else 1.12
   L([(x,.08,z),(x+.04,.1,z-.25),(x-.04,.08,z-.42)],.018,p['bark2'])
 elif name=='lantern_shrine':
  for y in (-.36,.36):
   for x in (-.19,0,.19):B((x,y,.88),(.035,.045,.58),p['wood'])
  for z in (.56,1.16):B((0,-.37,z),(.72,.065,.055),p['rim'])
  for i in range(5):
   z=1.37+i*.095;w=.78-i*.13;B((0,0,z),(w,w,.05),p['bark2'])
  for x in (-.38,.32):S((x,-.12,.17),(.2,.22,.06),p['moss'])
 elif name=='mushrooms':
  for x,y,s in [(0,0,1),(.5,.25,.7),(-.45,.15,.75),(.25,-.4,.55),(-.2,-.45,.5)]:
   R((x,y,.445*s),.24*s,.018*s,p['stem'])
   for i in range(4):
    a=i*2.4;S((x+.15*s*math.cos(a),y+.15*s*math.sin(a),.59*s),(.035*s,.04*s,.012*s),p['stem'])
 elif name=='stump':
  for i in range(12):
   a=i*math.tau/12;L([(.63*math.cos(a),.63*math.sin(a),.1),(.59*math.cos(a+.03),.59*math.sin(a+.03),.54)],.022,p['bark2'])
  for a in (.3,2,4.5):L([(.51*math.cos(a),.51*math.sin(a),.686),(.28*math.cos(a+.1),.28*math.sin(a+.1),.69)],.013,p['bark2'])
 elif name=='standing_stone':
  for z in (.55,.86,1.18):
   L([(-.15,-.257,z+.08),(0,-.26,z-.04),(.17,-.257,z+.12)],.018,p['stone2'])
  L([(.22,-.23,1.64),(.12,-.24,1.4),(.24,-.24,1.15)],.014,p['stone2'])
  for i in range(7):S((rng.uniform(-.3,.3),-.24,rng.uniform(.15,.5)),(.08,.022,.06),p['lichen'])
 elif name=='steam_lamp':
  for i in range(4):
   a=i*math.pi/2;L([(.45+.13*math.cos(a),.13*math.sin(a),1.3),(.45+.16*math.cos(a),.16*math.sin(a),1.57)],.018,p['steel'])
  C((.45,0,1.27),.18,.045,p['steel'],vertices=12)
  B((0,-.082,.95),(.14,.045,.18),p['brass'])
 elif name=='valve':
  for x in (-.57,.57):
   for a in range(6):
    t=a*math.tau/6;S((x,-.2*math.cos(t),.32+.2*math.sin(t)),(.04,.035,.035),p['brass'])
  C((0,0,.755),.09,.08,p['brass'],vertices=6)
 elif name=='ticket_booth':
  for x in (-.43,-.22,0,.22,.43):B((x,-.565,.75),(.025,.035,.46),p['iron'])
  B((0,-.568,1.03),(.64,.04,.12),p['brass'])
  for x in (-.23,-.12,0,.12,.23):B((x,-.594,1.035),(.05,.015,.025),p['steel'])
  for x in (-.6,.6):
   for z in (.2,.85):S((x,-.54,z),(.035,.025,.035),p['pale'])
  for x in (-.4,-.2,0,.2,.4):B((x,-.515,.19),(.012,.018,.3),p['steel'])
 elif name=='crate':
  for x in (-.22,0,.22):B((x,-.407,.4),(.018,.025,.51),p['bark2'])
  for x in (-.36,.36):
   for z in (.12,.68):S((x,-.434,z),(.028,.018,.028),p['brass'])
  L([(-.29,-.428,.2),(.29,-.428,.6)],.04,p['rust'])
 elif name=='cables':
  for x in (-.05,.05):
   for y in (-.27,.27):S((x,y,.3),(.035,.035,.02),p['brass'])
  for z in (.16,.26,.36,.46):B((.8,-.111,z),(.26,.025,.025),p['steel'])
 elif name=='bell':
  for z,r in ((.51,.58),(.62,.54),(1.23,.29)):R((0,0,z),r,.018,p['pale'])
  for x in (-.8,.8):
   for y in (-.16,.16):C((x,y,.115),.04,.035,p['rust'],vertices=6)
 elif name.startswith('tank_'):
  r,h=(.85,1.5) if name.endswith('small') else (1.5,2.3)
  for x in (-.2,.2):
   L([(x,-r-.09,.08),(x,-r-.09,h+.12)],.026,p['pale'])
  for i in range(int(h/.2)):
   z=.15+i*.2;L([(-.2,-r-.115,z),(.2,-r-.115,z)],.022,p['iron'])
  for i in range(8):
   a=i*math.tau/8;C((r*.83*math.cos(a),r*.83*math.sin(a),h+.12),.035,.055,p['brass'],vertices=6)
  R((r*.55,-r*.3,h+.38),r*.15,.025,p['pale'])
  for i in range(9):
   a=math.pi+i*math.pi/9;z=rng.uniform(.3,h*.75)
   L([(r*1.006*math.cos(a),r*1.006*math.sin(a),z),(r*1.007*math.cos(a),r*1.007*math.sin(a),z-.18)],.02,p['rust'])
 elif name=='catwalk':
  for y in (-.55,.55):
   L([(-1.25,y,.1),(-.6,y,.48)],.045,p['rust']);L([(.6,y,.48),(1.25,y,.1)],.045,p['rust'])
  for x in (-1.4,-.7,0,.7,1.4):
   for y in (-.62,.62):S((x,y,.58),(.045,.045,.025),p['brass'])
 # Subtle short cast shadow, requested by R6b. Same alpha in all passes.
 objs=[o for o in bpy.context.scene.objects if o.type in ('MESH','CURVE')]
 pts=[o.matrix_world @ Vector(v) for o in objs for v in o.bound_box]
 bpy.context.view_layer.update()
 pts=[o.matrix_world @ Vector(v) for o in objs for v in o.bound_box]
 low=[v for v in pts if v.z<.4]
 if low:
  xs=[v.x for v in low];ys=[v.y for v in low]
  w=max(.25,(max(xs)-min(xs))*.44);d=max(.18,(max(ys)-min(ys))*.44)
  sh=P.mat('R6b soft cast shadow','1C252B')
  n=sh.node_tree.nodes;l=sh.node_tree.links
  tex=n.new('ShaderNodeTexCoord');sub=n.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=(.5,.5,.5);l.new(tex.outputs['Generated'],sub.inputs[0])
  scale=n.new('ShaderNodeVectorMath');scale.operation='MULTIPLY';scale.inputs[1].default_value=(2,2,0);l.new(sub.outputs[0],scale.inputs[0])
  length=n.new('ShaderNodeVectorMath');length.operation='LENGTH';l.new(scale.outputs[0],length.inputs[0])
  ramp=n.new('ShaderNodeMapRange');ramp.clamp=True;ramp.interpolation_type='SMOOTHSTEP';ramp.inputs['From Min'].default_value=.15;ramp.inputs['From Max'].default_value=1;ramp.inputs['To Min'].default_value=.24;ramp.inputs['To Max'].default_value=0;l.new(length.outputs['Value'],ramp.inputs['Value'])
  transparent=n.new('ShaderNodeBsdfTransparent')
  for mode,color in [('beauty',(.012,.018,.023,1)),('normal',(.5,.91,.79,1)),('mask',(0,0,0,1))]:
   n[mode].name='old_'+mode
   em=n.new('ShaderNodeEmission');em.inputs[0].default_value=color
   mix=n.new('ShaderNodeMixShader');mix.name=mode;l.new(ramp.outputs[0],mix.inputs[0]);l.new(transparent.outputs[0],mix.inputs[1]);l.new(em.outputs[0],mix.inputs[2])
  S(((min(xs)+max(xs))/2+.06,(min(ys)+max(ys))/2-.06,-.025),(w,d,.008),sh)
