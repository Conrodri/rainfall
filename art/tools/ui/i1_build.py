"""I1: individually remodelled museum inventory objects; shared studio and PBR."""
import sys, math, json, random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
BASE=ROOT/'art/tools/ui'; OUT=BASE/'_i1_raw'; OUT.mkdir(exist_ok=True)
random.seed(117)

def pbr(color,metal=0,rough=.5,grain=65):
 m=mat(color,rough,metal); n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
 tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=grain*.45;tex.inputs['Detail'].default_value=3
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[0].color=(*[c*.48 for c in rgba(color)[:3]],1);ramp.color_ramp.elements[1].position=.82;ramp.color_ramp.elements[1].color=rgba(color);l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
 r=n.new('ShaderNodeMapRange');r.inputs['To Min'].default_value=max(.3 if metal else .08,rough-.07);r.inputs['To Max'].default_value=min(.9,rough+.07);l.new(tex.outputs['Fac'],r.inputs[0]);l.new(r.outputs[0],p.inputs['Roughness'])
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.0025 if metal else .005;l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 return m

def uv(loc,scale,m):
 o=sphere(loc,scale,m);q=o.modifiers.new('Continuous surface','SUBSURF');q.levels=1;q.render_levels=1;return o

def rod(pts,r,m):return curve(pts,r,m)
def riv(x,z,y=-.36,r=.034):
 uv((x,y,z),(r,.021,r),silver)
 rod([(x-r*.55,y-.022,z),(x+r*.55,y-.022,z)],.004,dark)
def cab(x,z,r=.09,y=-.4):
 torus((x,y+.01,z),r*1.14,.018,gold);uv((x,y-.015,z),(r,.065,r*1.2),gem)
def stitches(pts,y=-.38):
 for x,z in pts:rod([(x-.022,y,z-.018),(x+.022,y,z+.018)],.009,thread)
def seam(pts,m=None,r=.015):return rod(pts,r,m or silver)
def disk(x,y,z,r,d,m):return flat_disk((x,y,z),r,d,m)
def lat(prof,m,loc=(0,0,0),sub=1):
 o=lathe(prof,loc,m,64);q=o.modifiers.new('Turned smooth profile','SUBSURF');q.levels=sub;q.render_levels=sub;return o

def magnet(soul):
 # Forged rounded horseshoe, rectangular poles, binding wire and inset channels.
 pts=[(.57,0,.83),(.57,0,.35)]+[(.57*math.cos(t),0,-.12-.57*math.sin(t)) for t in [i*math.pi/32 for i in range(33)]]+[(-.57,0,.83)]
 rod(pts,.19,body)
 for x in [-.57,.57]:
  bevelled_box((x,0,.77),(.42,.43,.32),silver,.045)
  for z in [.25,.32,.39]:torus((x,0,z),.193,.014,gold).rotation_euler[0]=0
  riv(x,.61,-.23)
 if soul:rod([(-.55,-.18,.37),(-.55,-.18,-.15),(-.31,-.18,-.53),(0,-.18,-.65),(.35,-.18,-.5),(.55,-.18,-.15)],.019,gem)
 cab(0,-.66,.07,-.21)

def bottle(name):
 # Double wall, open rolled lip, separate liquid reservoir and irregular cork.
 lat([(0,-.85),(.24,-.85),(.43,-.77),(.48,-.58),(.47,.12),(.41,.29),(.2,.52),(.18,.74),(.22,.77),(.22,.85),(.16,.85),(.145,.7),(.15,.5),(.36,.25),(.41,.08),(.41,-.55),(.36,-.7),(0,-.73)],glass)
 lat([(0,-.72),(.34,-.72),(.4,-.55),(.4,-.04),(.38,.02),(0,.02)],body)
 lat([(.14,.74),(.17,.76),(.18,.93),(.16,.96)],leather)
 for z in [.63,.69]:torus((0,0,z),.185,.018,gold).rotation_euler[0]=0
 if name=='eclair_en_bouteille':rod([(-.11,-.39,.29),(.15,-.4,.03),(-.08,-.42,-.16),(.17,-.39,-.48)],.025,gem)
 else:
  slab(rrect(.43,.46,.09),leather,.04,-.46,.025)
  if name=='antidote':
   rod([(-.13,-.5,-.05),(.13,-.5,-.05)],.035,silver);rod([(0,-.5,-.18),(0,-.5,.08)],.035,silver)
  else:rod([(-.13,-.5,-.12),(0,-.51,.08),(.13,-.5,-.12)],.024,gold)
  cab(0,-.34,.045,-.47)
 rod([(-.27,-.18,.5),(-.45,-.22,.14),(-.45,-.24,-.5)],.012,silver)

def pendant(merchant=False):
 
 for i in range(34):
  t=i*math.tau/34;o=torus((.38*math.sin(t),0,.77+.35*math.cos(t)),.035,.009,gold);o.scale=(.75,1,1.25);o.rotation_euler[2]=.7 if i%2 else 0
 torus((0,0,.4),.1,.028,gold)
 if merchant:
  disk(0,0,-.18,.6,.15,body);torus((0,-.095,-.18),.55,.025,gold)
  for i in range(32):
   t=i*math.tau/32;rod([(.47*math.sin(t),-.1,-.18+.47*math.cos(t)),(.51*math.sin(t),-.1,-.18+.51*math.cos(t))],.009,silver)
  rod([(-.28,-.13,-.32),(-.27,-.13,.09),(0,-.13,-.17),(.27,-.13,.09),(.25,-.13,-.44)],.035,gold);cab(0,.1,.06,-.14)
 else:
  o=uv((0,0,-.17),(.46,.16,.64),body)
  rod([(.39*math.sin(t),-.125,-.17+.55*math.cos(t)) for t in [i*math.tau/64 for i in range(65)]],.014,thread)
  stitches([(.35*math.sin(i*.35),-.17+.5*math.cos(i*.35)) for i in range(18)],-.15)
  rod([(-.18,-.17,.02),(0,-.2,-.5),(.18,-.17,.02)],.025,gold);cab(0,-.17,.075,-.18)

def armor(shield=False):
 # Compound convex hammered shell with back thickness and rolled edges.
 pts=[];v=[];f=[];N=40;K=9
 for j in range(K):
  z=-.88+j*1.76/(K-1);w=(.22+.56*((z+.88)/1.76)**.35) if shield else (.5+.25*math.sin((z+.88)*1.25))
  for i in range(N):
   t=-1.35+2.7*i/(N-1);v.append((w*math.sin(t),-.34*math.cos(t),z-(.22*math.cos(t)**6*(j/(K-1))**8 if not shield else 0)))
 for j in range(K-1):
  for i in range(N-1):k=j*N+i;f.append((k,k+1,k+1+N,k+N))
 o=_surface('Hammered shell',v,f,body)
 for j in [0,K-1]:rod([v[j*N+i] for i in range(N)],.035,gold)
 for i in [0,N-1]:rod([v[j*N+i] for j in range(K)],.035,silver)
 if shield:
  disk(0,-.39,.14,.23,.12,silver);cab(0,.14,.09,-.48)
  for x in [-.42,.42]:
   for z in [-.25,.45]:riv(x,z,-.31)
  rod([(0,-.4,.78),(0,-.45,.38),(0,-.45,-.6)],.028,gold)
 else:
  for sx in [-1,1]:
   uv((sx*.72,0,.57),(.34,.30,.22),body)
   uv((sx*.27,-.29,.28),(.29,.12,.29),body)
   rod([(sx*.07,-.36,.02),(sx*.32,-.4,-.02),(sx*.53,-.3,.13)],.02,gold)
   for z in [-.64,-.43,-.22]:rod([(sx*.06,-.36,z),(sx*.28,-.35,z+.06),(sx*.53,-.26,z+.09)],.027,silver)
   for z in [-.58,-.2,.25,.62]:riv(sx*.49,z,-.29)
  cab(0,.4,.11,-.39)

def _surface(name,v,f,m):
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(m)
 for p in me.polygons:p.use_smooth=True
 q=o.modifiers.new('Sculpted curvature','SUBSURF');q.levels=2;q.render_levels=2
 q=o.modifiers.new('Real thickness','SOLIDIFY');q.thickness=.065
 q=o.modifiers.new('Rolled chamfer','BEVEL');q.width=.018;q.segments=3
 return o

def shoe(boot=True):
 # Separate sculpted last, upper shaft, stacked outsole, heel and hand sewn patch.
 uv((.16,0,-.52),(.72,.32,.29),body);uv((-.3,.025,-.16),(.33,.3,.51 if boot else .28),body)
 if boot:lat([(.28,-.25),(.27,.0),(.29,.44),(.32,.76),(.31,.81),(.24,.81),(.23,.5),(.22,.1)],body,(-.3,0,0))
 uv((.16,0,-.73),(.76,.34,.085),dark);bevelled_box((-.35,.04,-.8),(.43,.5,.2),dark,.045)
 rod([(.16+.67*math.cos(t),-.29,-.56+.13*math.sin(t)) for t in [i*math.pi/28 for i in range(29)]],.012,thread)
 for z in [-.36,-.23,-.1,.03]:
  rod([(-.37,-.295,z),(-.06,-.33,z+.08)],.018,thread);riv(-.38,z,-.3,.023);riv(-.06,z+.08,-.31,.023)
 if boot:
  slab(rrect(.3,.32,.07),leather,.04,-.295,.025).location=(-.4,0,.35)
  stitches([(-.52,.25+i*.06) for i in range(5)],-.33)
  rod([(-.58,-.2,.65),(-.3,-.34,.63),(-.03,-.2,.65)],.04,leather);cab(-.28,.63,.05,-.36)
 else:
  rod([(-.35,0,.03),(-.58,0,.69),(-.24,0,.92),(.1,0,.54),(-.14,-.23,.05)],.026,gold);cab(-.27,-.05,.06,-.34)

def cape():
 v=[];f=[];N=25;K=22
 for j in range(K):
  q=j/(K-1);z=.95-1.9*q;w=.27+.52*q
  for i in range(N):
   t=i/(N-1);x=(2*t-1)*w;y=.13*math.sin(t*math.tau*4+q*.5)*(.3+q)+.12*q
   v.append((x,y,z+.05*math.sin(t*24)*q**5))
 for j in range(K-1):
  for i in range(N-1):k=j*N+i;f.append((k,k+1,k+1+N,k+N))
 _surface('Woven folded cloak',v,f,body)
 for side in [0,N-1]:rod([(v[j*N+side][0],v[j*N+side][1]-.02,v[j*N+side][2]) for j in range(K)],.017,gold)
 rod([(-.32,-.12,.64),(0,-.24,.5),(.32,-.12,.64)],.024,silver);cab(0,.52,.08,-.25)

def quiver():
 lat([(.26,-.87),(.3,-.82),(.33,.48),(.35,.55),(.34,.63),(.28,.63),(.27,.48),(.24,-.74)],body)
 for z in [-.72,.47]:torus((0,0,z),.335,.035,gold).rotation_euler[0]=0
 rod([(-.3,0,-.67),(-.57,.08,-.1),(-.46,.05,.54),(.28,.08,.56)],.055,leather)
 stitches([(0,z) for z in [-.64+i*.09 for i in range(12)]],-.33)
 for x,z in [(-.22,1.0),(.02,1.2),(.24,1.03)]:
  rod([(x,0,.0),(x-.08,0,z)],.018,wood)
  for sign in [-1,1]:
   _surface('Feather vanes',[(x-.08,0,z),(x-.08+sign*.16,0,z-.17),(x-.08+sign*.14,0,z-.42),(x-.08,0,z-.26)],[(0,1,2,3)],thread)
   for k in range(4):rod([(x-.08,-.02,z-.13-k*.05),(x-.08+sign*.13,-.02,z-.22-k*.05)],.006,dark)
 cab(0,.47,.055,-.34)

def dial(r=.7,y=-.17):
 disk(0,y,0,r,.045,dark)
 for i in range(60):
  t=i*math.tau/60;ri=r*(.77 if i%5==0 else .88);rod([(ri*math.sin(t),y-.03,ri*math.cos(t)),(r*.95*math.sin(t),y-.03,r*.95*math.cos(t))],.013 if i%5==0 else .006,gold)
 for x,z,r0 in [(-.22,-.22,.16),(.24,-.17,.12)]:
  torus((x,y-.035,z),r0,.018,silver)
  for i in range(8):
   t=i*math.tau/8;uv((x+r0*.76*math.sin(t),y-.05,z+r0*.76*math.cos(t)),(.015,.012,.015),gold)
 rod([(-.24,y-.09,.34),(0,y-.09,0),(.36,y-.09,.11)],.019,silver);cab(0,0,.047,y-.1)

def clock():
 disk(0,0,0,.84,.23,body);torus((0,-.15,0),.77,.045,gold);torus((0,0,1.0),.16,.04,silver);dial()
 rod([(-.34,-.24,.61),(-.16,-.25,.27),(-.26,-.25,.13),(-.12,-.25,-.23),(-.28,-.24,-.57)],.009,silver)
 for x in [-.6,.6]:riv(x,0,-.22)

def heart(name):
 # Rounded continuous heart surface, carved fissures and material specific accretions.
 v=[];f=[];N=64;K=15
 for j in range(K+1):
  p=math.pi*j/K;s=math.sin(p)
  for i in range(N):
   t=i*math.tau/N;x=16*math.sin(t)**3/19;z=(13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t))/19
   v.append((x*s,.3*math.cos(p),z*s))
 for j in range(K):
  for i in range(N):k=j*N+i;ni=j*N+(i+1)%N;f.append((k,ni,ni+N,k+N))
 _surface('Carved heart',v,f,body)
 rod([(-.33,-.28,.42),(-.1,-.32,.2),(.08,-.33,.25),(.0,-.31,-.09),(.17,-.26,-.28),(0,-.18,-.63)],.014,gem)
 if name=='coeur_de_mousse':
  for i in range(22):
   t=i*2.399;x=.62*math.sin(t);z=.57*math.cos(t);uv((x,-.19,z),(.11,.065,.07),moss)
  for i in range(5):rod([(-.5+i*.21,-.25,.38),(-.4+i*.15,-.32,0),(-.25+i*.1,-.15,-.55)],.018,wood)
 elif name=='coeur_du_chronomancien':
  torus((0,-.32,0),.43,.055,gold);dial(.38,-.35)

def crown():
 # Annular band with curved raised fleurons, chased borders and a dark inner lining.
 lat([(.65,-.43),(.77,-.43),(.79,-.35),(.77,-.25),(.77,-.05),(.75,.02),(.69,.02),(.66,-.35)],body)
 for z in [-.38,-.12]:torus((0,0,z),.775,.027,gold).rotation_euler[0]=0
 for i in range(8):
  t=i*math.tau/8;x=.73*math.sin(t);y=.73*math.cos(t)
  pts=[(x,y,-.04),(x*1.04,y*1.04,.2),(x*.93,y*.93,.64 if i%2==0 else .4)]
  
  h=.64 if i%2==0 else .4
  tangent=Vector((math.cos(t),-math.sin(t),0));center=Vector((x,y,0));vv=[]
  for z0,w0 in [(-.08,.16),(.12,.16),(h*.7,.08),(h,0.008)]:
   for sg in [-1,1]:vv.append(tuple(center+tangent*w0*sg+Vector((0,0,z0))))
  _surface('Chased crown leaf',vv,[(0,1,3,2),(2,3,5,4),(4,5,7,6)],body)
  uv(pts[-1],(.045,.045,.06),gold)
  if y<0:cab(x,-.24,.065,y-.04)

def mineral(loc,r,h,m):
 n=9;v=[]
 for z,rr in [(-h*.5,r*.22),(-h*.38,r*.78),(h*.17,r),(h*.36,r*.76),(h*.52,r*.07)]:
  for i in range(n):
   t=i*math.tau/n;v.append((loc[0]+rr*math.cos(t),loc[1]+rr*math.sin(t),loc[2]+z+.022*math.sin(i*3)))
 f=[tuple(reversed(range(n)))]+[(j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i) for j in range(4) for i in range(n)]+[tuple(range(4*n,5*n))]
 me=bpy.data.meshes.new('Natural quartz terminations');me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new('Fractured quartz',me);bpy.context.collection.objects.link(o);o.data.materials.append(m);q=o.modifiers.new('Chipped edges','BEVEL');q.width=.012;q.segments=3
 return o

def shard(name):
 if name=='etincelle':
  for i in range(3):
   o=crystal((-.32+i*.28,0,-.25+i*.14),.3,.9,body);o.rotation_euler[1]=-.6+i*.4
  rod([(-.4,-.25,-.4),(-.12,-.3,-.17),(.16,-.24,.02),(.13,-.1,.33)],.027,gem)
 else:
  o=mineral((0,0,0),.29,1.95,body)
  for x,h in [(-.34,1.15),(.34,1.38)]:mineral((x,.02,-.28),.19,h,body)
  for x in [-.4,.4]:
   o=mineral((x,.03,-.4),.13,.8,body);o.rotation_euler[1]=x
  rod([(-.13,-.37,-.56),(.03,-.47,-.16),(-.12,-.42,.12),(.08,-.28,.63)],.016,gem)
  for z in [-.65,-.53]:torus((0,0,z),.31,.022,gold).rotation_euler[0]=0

def dice():
 bevelled_box((0,0,0),(1.27,1.27,1.27),body,.13)
 for x,z in [(-.31,.31),(0,0),(.31,-.31)]:disk(x,-.638,z,.075,.018,dark)
 for y,z in [(-.3,.3),(.3,-.3),(-.3,-.3),(.3,.3)]:uv((.638,y,z),(.012,.07,.07),dark)
 for x,y in [(-.28,-.28),(.28,.28)]:uv((x,y,.638),(.07,.07,.012),dark)
 cab(0,0,.033,-.66)
 rod([(-.51,-.64,-.48),(-.37,-.65,-.25),(-.44,-.65,-.09)],.008,gold)

def thorns():
 rod([(-.51,0,-.85),(-.35,0,-.28),(.04,0,.25),(.3,0,.92)],.09,wood)
 for x,z,s in [(-.42,-.54,-1),(-.25,-.1,1),(.04,.35,-1),(.24,.74,1)]:
  pts=[(x,0,z),(x+s*.22,-.02,z+.06),(x+s*.38,-.015,z+.28)]
  rod(pts[:2],.07,body);o=cone(pts[-1],.07,.4,body,32);toward(o,(s*.38,0,.24));o.modifiers.new('Thorn bevel','BEVEL').width=.012
 cab(-.12,.05,.07,-.1)

def snow():
 for i in range(6):
  t=i*math.tau/6;dx,dz=math.sin(t),math.cos(t)
  rod([(0,0,0),(dx,0,dz)],.045,body)
  for side in [-1,1]:
   rod([(dx*.5,0,dz*.5),(dx*.75+side*dz*.2,0,dz*.75-side*dx*.2)],.024,silver)
  o=crystal((dx*.85,0,dz*.85),.075,.28,body);o.rotation_euler[1]=t
 torus((0,-.05,0),.21,.025,gold);cab(0,0,.105,-.09)

# Packed linear floating point studio HDRI, neutral dark room with softbox reflections.
env=bpy.data.images.new('I1 neutral studio HDRI',width=256,height=128,float_buffer=True)
pixels=[]
for j in range(128):
 for i in range(256):
  u=i/256;v=j/128
  a=2.6*math.exp(-((u-.16)/.055)**8-((v-.62)/.18)**8)
  b=1.3*math.exp(-((u-.68)/.035)**8-((v-.57)/.23)**8)
  base=.025+.025*max(0,math.sin(v*math.pi))
  pixels.extend((base+a+b,base+a*.97+b,base+a*.92+b*1.06,1))
env.pixels.foreach_set(pixels);env.pack()

inv=json.loads((BASE/'_i1_inventory.json').read_text());args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [];start=int(args[0]) if args else 0;end=int(args[1]) if len(args)>1 else 25
colors=['#526A70','#884D3E','#76553D','#667B45','#566D88','#927345','#78523A','#4D7872','#505D78','#7C6245','#8E754C','#577F8F','#596B40','#705C7B','#8B7B45','#975136','#704759','#9C8D69','#555C8C','#4F8A83','#80725D','#685C50','#527B68','#397C62','#698792']
for idx in range(start,end):
 name=inv['objects'][idx];s=new_scene('I1 '+name,32);s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
 for o in list(s.objects):
  if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
 en=s.world.node_tree.nodes.new('ShaderNodeTexEnvironment');en.image=env;s.world.node_tree.links.new(en.outputs['Color'],s.world.node_tree.nodes['Background'].inputs[0]);s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
 for label,loc,power,size,color in [('Warm key',(-3,-4,5),680,2.4,'#FFE1BB'),('Cold rim',(3,2,3),850,2,'#ACCFFF'),('Front strip',(1,-4,.4),190,1.6,'#D7E4EF')]:
  d=bpy.data.lights.new(label,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=rgba(color)[:3];o=bpy.data.objects.new(label,d);s.collection.objects.link(o);o.location=loc;aim(o,(0,0,0))
 metal=name in ['aimant_d_ame','aimant_de_poche','armure_du_colosse','bague_de_vigueur','bouclier_reactif','chronometre_brise','coeur_du_chronomancien','couronne_d_echo','faveur_du_marchand']
 body=pbr(colors[idx],1 if metal else 0,.4 if metal else (.24 if name in ['coeur_de_glace','cristal_de_feu','eclat_d_experience','flocon'] else .58));silver=pbr('#A5ADB2',1,.37);gold=pbr('#A58B58',1,.42);dark=pbr('#272B30',0,.7);leather=pbr('#59402E',0,.68);wood=pbr('#5C4934',0,.75,17);thread=pbr('#B39B76',0,.78);moss=pbr('#536037',0,.88)
 ec={'cristal_de_feu':'#F47932','etincelle':'#FF9A3D','eclair_en_bouteille':'#929EFF','antidote':'#B3C65B','fiole_verte':'#58CC8C','coeur_de_glace':'#65CBEB','flocon':'#9ADDF5','eclat_d_experience':'#59E0B9','aimant_d_ame':'#67E3C9','coeur_du_chronomancien':'#C28AF0'}.get(name,'#D5B977')
 gem=mat(ec,.2,.15,ec,2.4);glass=pbr({'antidote':'#6D814B','fiole_verte':'#3E8064','eclair_en_bouteille':'#535C8B'}.get(name,'#748D91'),0,.16);p=glass.node_tree.nodes.get('Principled BSDF');p.inputs['Transmission Weight'].default_value=.35;p.inputs['IOR'].default_value=1.46;p.inputs['Coat Weight'].default_value=.35
 if name in ['coeur_de_glace','cristal_de_feu','eclat_d_experience','flocon']:
  p=body.node_tree.nodes.get('Principled BSDF');p.inputs['Roughness'].default_value=.24;p.inputs['Transmission Weight'].default_value=.28;p.inputs['Coat Weight'].default_value=.45
 if name.startswith('aimant_'):magnet(name=='aimant_d_ame')
 elif name in ['antidote','fiole_verte','eclair_en_bouteille']:bottle(name)
 elif name=='amulette_de_cuir':pendant()
 elif name=='faveur_du_marchand':pendant(True)
 elif name=='armure_du_colosse':armor()
 elif name=='bouclier_reactif':armor(True)
 elif name=='bague_de_vigueur':
  torus((0,0,-.14),.55,.105,body);torus((0,-.075,-.14),.55,.023,gold);cab(0,.49,.18,-.02)
  for x in [-.28,.28]:riv(x,.31,-.07)
 elif name in ['botte_rapiecee','danseur']:shoe(name=='botte_rapiecee')
 elif name=='cape_de_brume':cape()
 elif name=='carquois_affute':quiver()
 elif name=='chronometre_brise':clock()
 elif name.startswith('coeur_'):heart(name)
 elif name=='couronne_d_echo':crown()
 elif name in ['cristal_de_feu','eclat_d_experience','etincelle']:shard(name)
 elif name=='de_pipe':dice()
 elif name=='epines':thorns()
 elif name=='flocon':snow()
 # Global engraving: small paired chased scratches on metal, physically raised fine lines.
 if metal and name not in ['couronne_d_echo','bague_de_vigueur']:
  for k in range(3):
   x=-.32+k*.035;z=-.3+k*.05;rod([(x,-.355,z),(x+.11,-.355,z+.045)],.004,silver)
 for o in list(s.objects):
  if o.type=='MESH' and not any(m.type=='BEVEL' for m in o.modifiers):
   q=o.modifiers.new('Edge micro chamfer','BEVEL');q.width=.009;q.segments=3
 # Camera looks down and across; fit each silhouette before contractual alpha fit.
 c=front_camera(3,3,384,384,16);c.location=(2.5,-10,3.6);aim(c,(0,0,0));bpy.context.view_layer.update();frame_object_ortho(meshes(),.13)
 s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
 print('I1 DONE '+name,flush=True)
 if (idx+1)%5==0 or idx==end-1:bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui'/('i1_batch_'+str(idx//5+1)+'.blend')))
