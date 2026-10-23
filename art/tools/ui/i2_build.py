"""I2 museum artefacts. New geometry, shared studio, exact U4 raster contract."""
import sys,json,math,random,subprocess,ast
from pathlib import Path
BASE=Path(__file__).resolve().parent
sys.path.insert(0,str(BASE))
from ui_kit import *
from mathutils import Vector,Matrix
OUT=BASE/'i2_raw';OUT.mkdir(exist_ok=True)
INV=json.loads((BASE/'_i2_inventory.json').read_text())

def surface(name,lo,hi,metal=0,rough=.5):
 m=mat(hi,rough,metal);m.name=name;n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
 tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=12;tex.inputs['Detail'].default_value=4
 ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].color=rgba(lo);ramp.color_ramp.elements[1].color=rgba(hi)
 l.new(tex.outputs['Fac'],ramp.inputs[0]);l.new(ramp.outputs[0],p.inputs['Base Color'])
 rm=n.new('ShaderNodeMapRange');rm.inputs['To Min'].default_value=max(.3 if metal==1 else .08,rough-.12);rm.inputs['To Max'].default_value=min(.9,rough+.12)
 l.new(tex.outputs['Fac'],rm.inputs[0]);l.new(rm.outputs[0],p.inputs['Roughness'])
 fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=155;fine.inputs['Detail'].default_value=2
 bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.2;bump.inputs['Distance'].default_value=.009
 l.new(fine.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],p.inputs['Normal'])
 return m

def palette():
 global iron,steel,bronze,gold,wood,hide,bone,black,teal,red,blue,stone,glass,fire,hot,accent
 iron=surface('forged gunmetal','#333E46','#78838B',1,.43)
 steel=surface('honed silver steel','#717F87','#B4BDC0',1,.34)
 bronze=surface('antique bronze','#58452E','#A18A5F',1,.46)
 gold=surface('old electrum','#74602E','#B9A15A',1,.37)
 wood=surface('dark carved walnut','#20150D','#5B3824',0,.63)
 hide=surface('oxblood sewn leather','#211315','#4A2820',0,.66)
 bone=surface('aged carved ivory','#4F4937','#8D8064',0,.52)
 black=surface('recess patina','#101719','#343A3C',.3,.68)
 teal=surface('malachite enamel','#103E34','#30654D',.25,.33)
 red=surface('garnet enamel','#391016','#7F2930',.15,.27)
 blue=surface('cobalt enamel','#14263A','#3B536B',.2,.31)
 stone=surface('green grey whetstone','#293B33','#536558',0,.72)
 glass=surface('smoked optical crystal','#173C49','#4C7580',0,.16)
 p=glass.node_tree.nodes.get('Principled BSDF');p.inputs['Transmission Weight'].default_value=.32;p.inputs['Coat Weight'].default_value=.5
 fire=mat('#8F2105',.35,.0,'#FF3903',1.5);hot=mat('#D05A08',.36,0,'#FF8A16',2.2)
 accent=mat('#735031',.32,.3,'#F78729',2.8)

def studio(name):
 s=new_scene('i2_'+name,24);palette()
 for o in list(s.objects):
  if o.type=='LIGHT':bpy.data.objects.remove(o,do_unlink=True)
 s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast';s.view_settings.exposure=0
 s.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.17,.19,1)
 s.world.node_tree.nodes['Background'].inputs[1].default_value=.12
 env=s.world.node_tree.nodes.new('ShaderNodeTexEnvironment')
 env.image=bpy.data.images.load(str(Path(bpy.utils.resource_path('LOCAL'))/'datafiles/studiolights/world/studio.exr'),check_existing=True)
 s.world.node_tree.links.new(env.outputs['Color'],s.world.node_tree.nodes['Background'].inputs[0])
 if hasattr(s.eevee,'use_raytracing'):s.eevee.use_raytracing=True
 for name,loc,power,color,size in [('warm key',(-3,-4,5),520,(1,.84,.66),3),('cool rear rim',(3,1,3),850,(.53,.72,1),2),('front strip',(.5,-4,.5),160,(.83,.9,1),2.4)]:
  d=bpy.data.lights.new(name,'AREA');d.energy=power;d.color=color;d.shape='DISK';d.size=size
  o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=loc;aim(o,(0,0,0))
 s.camera.location=(2.1,-10,3.7);aim(s.camera,(0,0,0))
 return s

def disk(x,z,r,m,y=0,d=.12):return flat_disk((x,y,z),r,d,m)
def bead(x,z,r=.03,y=-.2,m=None):
 sphere((x,y,z),(r,r*.6,r),m or bronze)
 curve([(x-r*.4,y-r*.65,z),(x+r*.4,y-r*.65,z)],r*.12,black)
def rod(p,q,r,m):return curve([p,q],r,m)
def engraving(x,z,r,y=-.16,n=24,m=None):
 for i in range(n):
  t=math.tau*i/n;rod((x+r*math.sin(t),y,z+r*math.cos(t)),(x+(r-.05)*math.sin(t),y,z+(r-.05)*math.cos(t)),.007,m or bronze)
def band(z,r,m= None):
 o=torus((0,0,z),r,.037,m or bronze);o.rotation_euler[0]=0;return o
def jewel(x,z,m=None,y=-.25,r=.09):
 disk(x,z,r*1.35,gold,y+.025,.065);sphere((x,y-.035,z),(r,r*.55,r),m or accent)
def leather_grip(x,z,h=.6):
 sphere((x,0,z),(.12,.13,h*.58),hide)
 for i in range(8):
  zz=z-h*.43+i*h*.12;curve([(x-.1,-.07,zz-.02),(x,-.135,zz),(x+.1,-.07,zz+.02)],.012,bronze)
def leaf_mesh(points,m,width=.12,depth=.055):
 # Domed continuous leaf/blade with bevelled perimeter and raised central ridge.
 return slab(points,m,depth,-.05,min(width,.04))

def flame_mesh(x,z,k=1,y=-.26,lean=.16):
 # Closed, twisted 3D flame tongues, not a flat pictogram or simulation billboard.
 for j,(dx,dz,w,h) in enumerate([(0,0,.21,.94),(-.2,-.03,.13,.58),(.21,-.06,.12,.68)]):
  verts=[];faces=[];steps=12;seg=12
  for a in range(steps):
   t=a/(steps-1);r=w*(math.sin(math.pi*(t*.9+.07))**.7)*(1-t*.92)
   cx=dx+lean*t*t+.055*math.sin(t*8+j)*t;cz=dz-.35+h*t
   for b in range(seg):
    ang=b*math.tau/seg;verts.append((x+k*(cx+r*math.cos(ang)),y+k*r*.65*math.sin(ang),z+k*cz))
  for a in range(steps-1):
   for b in range(seg):
    c=a*seg+b;d=a*seg+(b+1)%seg;faces.append((c,d,d+seg,c+seg))
  faces.extend([tuple(reversed(range(seg))),tuple(range((steps-1)*seg,steps*seg))])
  o=_mesh_local('sculpted incandescent tongue',verts,faces,fire)
  sub=o.modifiers.new('smooth fire surface','SUBSURF');sub.levels=1
  cv=[(x+k*dx+(vx-x-k*dx)*.43,vy-k*.12,z+k*(dz-.35)+(vz-z-k*(dz-.35))*.55) for vx,vy,vz in verts]
  core=_mesh_local('hot inner flame',cv,faces,hot);sub=core.modifiers.new('soft core','SUBSURF');sub.levels=1

def smooth_curve(points,radius,material):
 d=bpy.data.curves.new('continuous forged sweep','CURVE');d.dimensions='3D';d.resolution_u=16;d.bevel_depth=radius;d.bevel_resolution=5
 sp=d.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new('continuous forged sweep',d);bpy.context.collection.objects.link(o);o.data.materials.append(material);return o

def _mesh_local(name,v,f,m):
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(m)
 for p in me.polygons:p.use_smooth=True
 return o

def bottle(kind):
 tint={'venin_concentre':teal,'tonique_vital':red}[kind]
 lathe([(0,-.82),(.31,-.82),(.46,-.73),(.52,-.46),(.5,-.03),(.36,.28),(.19,.4),(.19,.72),(.23,.74)],material=tint,segments=64)
 # Outer polished glass lip, inset leather seal, metal cage and embossed label.
 band(.68,.205,steel);band(.42,.2,bronze);cylinder((0,0,.79),.21,.16,wood,48)
 for z,r in [(-.66,.43),(-.12,.51)]:band(z,r,bronze)
 for sx in [-1,1]:curve([(sx*.32,-.27,-.72),(sx*.46,-.29,-.4),(sx*.37,-.25,.23)],.025,bronze)
 disk(0,-.25,.255,bone,-.505,.055)
 if kind=='tonique_vital':
  slab([(-.055,-.46),(.055,-.46),(.055,-.3),(.19,-.3),(.19,-.19),(.055,-.19),(.055,-.04),(-.055,-.04),(-.055,-.19),(-.19,-.19),(-.19,-.3),(-.055,-.3)],red,.05,-.55,.015)
 else:
  sphere((0,-.56,-.2),(.145,.055,.15),iron)
  for x in [-.06,.06]:sphere((x,-.61,-.17),(.038,.015,.046),black)
  for x in [-.08,0,.08]:rod((x,-.59,-.29),(x,-.59,-.35),.019,bone)
 jewel(0,.47,accent,-.2,.047)

def blade(x=0,angle=0,arrow=False):
 def build():
  outline=[(-.15,-.3),(-.19,.55),(0,1.05),(.19,.55),(.15,-.3)]
  if arrow:outline=[(-.11,-.4),(-.12,.36),(-.35,.23),(0,1.05),(.35,.23),(.12,.36),(.11,-.4)]
  slab(outline,iron,.15,0,.025)
  slab([(0,-.28),(0,1.02),(.18,.55),(.14,-.28)],steel,.045,-.095,.015)
  rod((0,-.13,-.27),(0,-.13,.82),.012,bronze)
  if not arrow:
   curve([(-.37,0,-.35),(0,-.03,-.4),(.37,0,-.35)],.065,bronze)
  leather_grip(0,-.65,.42);sphere((0,0,-.94),(.14,.12,.12),bronze);jewel(0,-.94,accent,-.11,.045)
 group(build,loc=(x,0,0),rot=(0,angle,0))

def clock(hourglass=False):
 if not hourglass:
  disk(0,0,.87,bronze,d=.22);disk(0,0,.72,blue,-.14,.06)
  for r in [.74,.85]:torus((0,-.16,0),r,.025,steel)
  engraving(0,0,.66,-.19,48)
  for i in range(12):
   t=i*math.tau/12;bead(.56*math.sin(t),.56*math.cos(t),.025,-.21,bronze)
  curve([(-.36,-.25,.2),(0,-.26,0),(.08,-.26,.47)],.031,steel);jewel(0,0,accent,-.28,.065)
  torus((0,0,1.01),.14,.045,bronze)
  for x,z,r in [(-.36,-.27,.17),(.35,-.28,.2)]:
   disk(x,z,r,iron,-.2,.03);engraving(x,z,r,-.23,12,steel)
 else:
  for z in [-.83,.83]:
   cylinder((0,0,z),.57,.14,bronze,64);band(z,.52,steel)
  for t in [0,math.pi*.5,math.pi,math.pi*1.5]:
   x=.45*math.cos(t);y=.37*math.sin(t);rod((x,y,-.8),(x,y,.8),.043,bronze)
   for z in [-.72,.72]:sphere((x,y,z),(.075,.075,.055),steel)
  lathe([(.38,-.74),(.42,-.65),(.38,-.45),(.2,-.16),(.065,0),(.2,.16),(.38,.45),(.42,.65),(.38,.74)],material=glass,segments=64)
  cone((0,-.06,-.5),.31,.38,gold,48);cone((0,0,.43),.27,.35,gold,48,radius2=.09).rotation_euler[0]=math.pi
  rod((0,-.08,-.3),(0,-.08,.29),.014,gold)
  curve([(.18,-.34,.55),(.06,-.25,.33),(.15,-.19,.19),(.03,-.1,.04)],.009,black);jewel(.4,-.72,accent,-.2,.04)

def feather(x=0,z=0,k=1,angle=0,m=None):
 def build():
  rod((0,-.05,-.85),(0,-.05,.92),.025,bone)
  for i in range(17):
   zz=-.55+i*.081;w=.32*(math.sin((i+2)/21*math.pi))
   for side in [-1,1]:
    curve([(0,-.04,zz),(side*w*.55,-.065,zz+.11),(side*w,-.02,zz+.21)],.025*(1-i*.025),m or blue)
  for i in range(9):rod((0,-.08,-.6+i*.15),(.17,-.065,-.47+i*.15),.004,steel)
 group(build,loc=(x,0,z),scale=k,rot=(0,angle,0))

def phoenix(metal=True,k=1):
 sphere((0,-.12,-.05),(.14,.12,.4),bronze if metal else iron)
 for side in [-1,1]:
  for i in range(7):
   x=side*(.28+i*.075);z=.03+i*.075
   curve([(side*.06,-.13,-.09),(x,-.12,z),(side*(.79-i*.025),-.1,.59-i*.09)],.055-i*.004,bronze if metal else fire)
 for i in [-1,0,1]:curve([(0,-.12,-.25),(i*.16,-.1,-.57),(i*.2,-.08,-.76)],.045,bronze if metal else fire)
 sphere((0,-.13,.31),(.12,.09,.13),bronze);slab([(0,.38),(.21,.31),(.08,.27)],steel,.075,-.17,.015)
 jewel(-.04,.35,accent,-.23,.022)
 if not metal:flame_mesh(0,-.02,.55,-.3)

def build_object(name):
 if name=='givre':
  for x,z,h,r in [(-.36,-.24,1.25,.23),(0,.06,1.92,.29),(.42,-.2,1.4,.24)]:
   o=crystal((x,0,z),r,h,glass);o.rotation_euler[1]=x*.45
   b=o.modifiers.new('tiny ice chipped edges','BEVEL');b.width=.015;b.segments=3
   curve([(x-r*.45,-r*.7,z-h*.25),(x-r*.15,-r*.85,z),(x+r*.1,-r*.7,z+h*.27)],.009,steel)
  curve([(-.6,-.01,-.73),(0,-.08,-.88),(.64,0,-.69)],.06,iron);jewel(0,-.67,mat('#33566A',.3,0,'#50BBD3',2.3),-.27,.055)
 elif name=='horloge_arcanique':clock()
 elif name=='sablier_fele':clock(True)
 elif name=='lame_jumelle':blade(-.14,-.48);blade(.14,.48)
 elif name=='pointe_perforante':blade(0,.25,True)
 elif name in ['venin_concentre','tonique_vital']:bottle(name)
 elif name=='lentille_aiguisee':
  torus((-.16,0,.24),.58,.09,bronze);sphere((-.16,-.015,.24),(.51,.13,.51),glass)
  torus((-.16,-.13,.24),.5,.018,steel);engraving(-.16,.24,.58,-.08,32)
  rod((.25,0,-.19),(.77,0,-.91),.11,iron);leather_grip(.6,-.68,.42)
  for x,z in [(-.62,.27),(-.16,.7),(.3,.27)]:bead(x,z,.035,-.12)
  jewel(.28,-.2,accent,-.09,.04)
 elif name=='marque_du_chasseur':
  slab(rrect(1.27,1.4,.18),hide,.17,0,.055)
  for sx in [-1,1]:
   for i in range(11):rod((sx*.55,-.115,-.55+i*.11),(sx*.59,-.115,-.52+i*.11),.009,bone)
  torus((0,-.16,0),.42,.045,iron)
  for t in [0,math.pi/2,math.pi,3*math.pi/2]:rod((.25*math.sin(t),-.23,.25*math.cos(t)),(.62*math.sin(t),-.23,.62*math.cos(t)),.025,steel)
  jewel(0,0,red,-.24,.1);jewel(0,0,accent,-.31,.032)
 elif name=='orbe_de_veille':
  cylinder((0,0,-.69),.5,.14,bronze,64);sphere((0,0,.05),(.57,.46,.57),glass)
  for sx in [-1,1]:curve([(sx*.4,0,-.66),(sx*.58,0,-.16),(sx*.51,-.08,.36)],.045,bronze)
  sphere((0,-.43,.07),(.36,.09,.22),bone);sphere((0,-.52,.07),(.16,.045,.18),teal);sphere((0,-.565,.07),(.04,.02,.14),black)
  jewel(0,.56,accent,-.07,.055)
 elif name=='oeil_du_predateur':
  sphere((0,0,0),(.73,.34,.44),bone)
  for side in [-1,1]:curve([(side*.7,-.1,0),(side*.42,-.3,.39),(0,-.35,.41)],.035,hide)
  sphere((0,-.335,0),(.3,.075,.34),gold);sphere((0,-.41,0),(.055,.018,.28),black)
  for i in range(30):
   t=i*math.tau/30;rod((.13*math.sin(t),-.405,.14*math.cos(t)),(.26*math.sin(t),-.37,.29*math.cos(t)),.007,bronze)
  jewel(-.12,.17,accent,-.42,.037)
 elif name=='pavois_fele':
  disk(0,0,.8,wood,d=.19)
  for i in range(7):
   x=-.61+i*.2;h=math.sqrt(.8**2-x*x);rod((x,-.107,-h),(x,-.107,h),.009,black)
  torus((0,-.11,0),.77,.055,iron);disk(0,0,.24,iron,-.16,.12);sphere((0,-.23,0),(.2,.095,.2),steel)
  for i in range(12):
   t=i*math.tau/12;bead(.7*math.sin(t),.7*math.cos(t),.032,-.18)
  curve([(.33,-.12,.69),(.19,-.13,.48),(.35,-.13,.29),(.23,-.13,.08),(.4,-.13,-.39)],.017,black);jewel(0,0,accent,-.33,.035)
 elif name=='piece_porte_bonheur':
  disk(0,0,.77,gold,d=.16);torus((0,-.1,0),.66,.025,bronze);engraving(0,0,.73,-.105,48,steel)
  for x,z in [(-.19,.1),(.19,.1),(0,.34)]:sphere((x,-.13,z),(.19,.065,.2),teal)
  curve([(0,-.16,.13),(.02,-.16,-.25),(.22,-.16,-.38)],.033,teal);jewel(0,-.53,accent,-.12,.033)
 elif name=='pierre_a_aiguiser':
  o=bevelled_box((0,0,0),(.73,.42,1.5),stone,.16);o.rotation_euler[1]=.3
  for i in range(13):
   x=-.24+i*.038;rod((x-.1,-.222,-.42),(x+.09,-.222,.4),.0035,black)
  for z in [-.58,.58]:curve([(-.33,0,z),(-.3,-.25,z),(.28,-.25,z),(.33,0,z)],.045,hide)
  jewel(0,-.58,accent,-.28,.045)
 elif name=='plume_d_empenne':feather(angle=.4);jewel(-.26,-.57,accent,-.09,.04)
 elif name=='rafale_d_acier':
  for i in [-1,0,1]:group(lambda:blade(0,0,True),loc=(i*.27,i*.08,0),scale=.78,rot=(0,i*.32,0))
 elif name=='rune_de_portee':
  slab([(-.59,-.58),(-.68,.24),(-.39,.71),(.42,.65),(.64,.22),(.56,-.63),(-.2,-.73)],stone,.3,0,.08)
  for r in [.3,.48]:torus((0,-.18,0),r,.016,bronze)
  for side in [-1,1]:curve([(side*.23,-.2,-.12),(side*.5,-.2,0),(side*.23,-.2,.12)],.033,steel)
  jewel(0,0,mat('#35504D',.4,.15,'#63C4B0',2.2),-.22,.08)
 elif name=='morsure_vorace':
  smooth_curve([(-.67,0,.43),(-.68,0,-.2),(-.38,0,-.57),(0,0,-.64),(.38,0,-.57),(.68,0,-.2),(.67,0,.43)],.12,bone)
  for x in [-.56,-.32,-.1,.1,.32,.56]:
   zz=-.48+abs(x)*.38;h=.58 if abs(x)>.4 else .27
   lathe([(.065,0),(.1,.07),(.065,h*.6),(0,h)],(x,-.07,zz),bone,40)
  for i in [-1,1]:jewel(i*.57,-.37,red,-.08,.07)
 elif name=='sang_chaud':
  lathe([(0,-.8),(.27,-.74),(.46,-.47),(.49,-.2),(.35,.18),(.15,.55),(0,.99)],material=red,segments=64)
  curve([(-.25,-.3,-.62),(0,-.49,-.7),(.27,-.3,-.6)],.038,bronze);flame_mesh(0,-.18,.39,-.48)
 elif name=='phenix_de_poche':
  disk(0,0,.84,iron,d=.1);torus((0,-.08,0),.78,.03,bronze);engraving(0,0,.74,-.08,40);phoenix()
 elif name=='peste_vivante':
  skull=sphere((0,0,.2),(.51,.32,.63),bone)
  for side in [-1,1]:
   cutter=sphere((side*.22,-.28,.23),(.17,.16,.18),bone);mod=skull.modifiers.new('carved eye socket','BOOLEAN');mod.operation='DIFFERENCE';mod.object=cutter
   bpy.context.view_layer.objects.active=skull;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
  sphere((0,-.05,-.35),(.33,.22,.17),bone)
  for side in [-1,1]:
   sphere((side*.22,-.18,.23),(.13,.045,.145),black);curve([(side*.45,-.15,.03),(side*.42,-.25,-.17),(side*.25,-.29,-.27)],.08,bone)
  slab([(-.08,-.12),(0,.03),(.08,-.12)],black,.05,-.34,.02)
  for x in [-.24,-.14,-.045,.045,.14,.24]:sphere((x,-.29,-.34),(.04,.045,.105),bone)
  for side in [-1,1]:curve([(side*.41,0,-.2),(side*.53,0,-.55),(side*.27,0,-.73),(0,0,-.77)],.045,bronze)
  curve([(-.28,-.23,.7),(-.1,-.33,.55),(-.18,-.34,.39)],.008,black);jewel(0,.53,teal,-.29,.055);jewel(0,.53,accent,-.34,.022)
 elif name=='moisson':
  for i in range(5):
   x=-.12+i*.13;rod((.15,0,-.8),(x,0,.75),.018,gold)
   for j in range(6):
    z=.22+j*.095
    for side in [-1,1]:
     o=sphere((x+side*.055,0,z),(.04,.035,.09),bronze);o.rotation_euler[1]=side*.45
  smooth_curve([(-.76,0,-.3),(-.83,0,.1),(-.55,0,.57),(-.12,0,.73),(.24,0,.66)],.065,steel)
  leather_grip(-.72,-.57,.52);jewel(-.72,-.35,accent,-.13,.045)
 elif name=='sifflet_de_chasse':
  def whistle():
   lathe([(.15,-.95),(.2,-.9),(.22,-.6),(.25,-.53),(.25,.48),(.17,.6),(.14,.88)],material=bone,segments=64)
   for zz,rr in [(-.58,.24),(.5,.24)]:band(zz,rr,bronze)
   slab(rrect(.14,.22,.025),black,.025,-.245,.01).location.z=.28
   jewel(0,-.35,accent,-.23,.035)
  group(whistle,rot=(0,math.pi/2-.12,0))
  torus((.88,0,.08),.13,.028,bronze)
  smooth_curve([(-.81,0,-.13),(-.48,.05,-.48),(.36,.05,-.5),(.86,0,-.02)],.022,hide)
 elif name=='tempete_de_braises':
  for j in range(3):
   pts=[]
   for i in range(50):
    t=i/49;ang=t*math.tau*1.3+j*math.tau/3;r=.2+t*.54
    pts.append((r*math.sin(ang),r*.23*math.cos(ang),-.72+t*1.4))
   curve(pts,.025,bronze if j else iron)
  for i in range(13):
   t=i/12;ang=t*math.tau*2.1;r=.24+t*.44;x=r*math.sin(ang);z=-.62+t*1.25
   o=crystal((x,-.08,z),.075,.21,iron);o.rotation_euler[1]=ang
   flame_mesh(x,z,.19,-.14,.24)
 elif name=='nova_infinie':
  sphere((0,0,0),(.29,.29,.29),iron)
  for i,(r,rot) in enumerate([(.65,(1.0,.25,.5)),(.82,(.8,1.2,-.4)),(.71,(2,.1,-.6))]):
   o=torus((0,0,0),r,.035,[bronze,steel,teal][i]);o.rotation_euler=rot
   for j in range(3):
    t=j*math.tau/3+i;flame_mesh(r*math.sin(t),r*math.cos(t),.19,-.15,lean=.3)
  jewel(0,0,accent,-.32,.11)
 else:raise ValueError(name)
 # Shared subtle tool wear and a small individual light source, never a full emissive body.
 if name not in ['sang_chaud','tempete_de_braises','nova_infinie','givre']:
  candidates=[o for o in meshes() if o.type=='MESH']
  if candidates:
   for o in candidates:
    for mod in o.modifiers:
     if mod.type=='BEVEL':mod.segments=4

def hand(k=1,y=0,disabled=False):
 def build():
  # Convex dorsal shell and individually curved, thick overlapping finger lames.
  sphere((0,0,-.13),(.38,.18,.38),hide)
  sphere((0,-.1,-.13),(.34,.14,.34),iron)
  slab([(-.36,-.7),(.34,-.7),(.29,-.35),(-.28,-.35)],iron,.25,0,.065)
  for z in [-.63,-.43]:curve([(-.33,-.13,z),(0,-.18,z-.025),(.31,-.13,z)],.03,bronze)
  for x in [-.23,.23]:bead(x,-.53,.04,-.18,steel)
  for i in range(4):
   x=-.26+i*.175;length=[.48,.67,.61,.44][i];width=[.155,.17,.164,.145][i]
   for j in range(3):
    z=.12+(j+.5)*length/3;w=width*(1-j*.08);h=length/3+.055
    sphere((x,-.08-j*.012,z),(w*.56,.105,h*.58),iron)
    # Lamellar forged shell is curved on all axes, with raised rolled bronze edge.
    for zz in [z-h*.39,z+h*.39]:curve([(x-w*.42,-.14,zz),(x,-.2,zz+.008),(x+w*.42,-.14,zz)],.014,bronze)
    if j<2:
     for side in [-1,1]:bead(x+side*w*.34,z-h*.22,.018,-.185,steel)
   sphere((x,-.13,.14),(width*.6,.11,.09),steel)
  for j in range(3):
   x=-.33-j*.1;z=-.1+j*.15;o=sphere((x,-.07,z),(.105,.105,.14),iron);o.rotation_euler[1]=-.5
   bead(x-.04,z,.025,-.18,bronze)
  for x in [-.15,0,.15]:curve([(x,-.22,-.3),(x*.75,-.26,-.08),(x,-.2,.05)],.012,bronze)
  jewel(0,-.14,black if disabled else accent,-.26,.042)
 group(build,loc=(0,y,0),scale=k)

def medallion(state='normal'):
 # The U2 rim geometry stays consistent, the gauntlet inside is newly sculpted.
 y=.06 if state=='pressed' else 0
 torus((0,y,0),1.02,.13,iron);torus((0,y-.13,0),.91,.045,bronze);torus((0,y-.15,0),.83,.018,steel)
 disk(0,0,.83,black,y+.025,.12);engraving(0,0,1.03,y-.15,24)
 for i in range(8):
  t=i*math.tau/8;bead(1.04*math.sin(t),1.04*math.cos(t),.035,y-.16,bronze)
 hand(.79,y-.2,state in ['disabled','cooldown'])

def spell(name):
 # Existing spell_frame overlays the U2 rings in game; keep the painted alpha margins.
 disk(0,0,.87,black,.06,.14);torus((0,-.035,0),.84,.018,bronze);engraving(0,0,.79,-.03,36)
 for i in range(7):
  t=i*math.tau/7;curve([(.64*math.sin(t),-.025,.64*math.cos(t)),(.57*math.sin(t+.2),-.025,.57*math.cos(t+.2)),(.67*math.sin(t+.35),-.025,.67*math.cos(t+.35))],.008,black)
 if name=='eclat_de_braise':
  for o in list(meshes()):bpy.data.objects.remove(o,do_unlink=True)
  slab([(-.8,-.17),(-.65,.2),(.45,.18),(.8,0),(.45,-.18)],iron,.12,0,.025)
  for z in [-.1,.1]:rod((-.55,-.08,z),(.39,-.08,z),.009,bronze)
  group(lambda:flame_mesh(0,0,.7,-.19,.25),rot=(0,math.pi/2,0))
 elif name=='braises_errantes':
  torus((0,-.15,0),.45,.022,bronze)
  for i in range(3):
   t=i*math.tau/3;flame_mesh(.45*math.sin(t),.4*math.cos(t),.45,-.23,.25)
 elif name=='nova_ardente':
  torus((0,-.18,0),.39,.045,fire)
  for i in range(9):
   t=i*math.tau/9
   group(lambda:flame_mesh(0,.43,.32,-.24),rot=(0,t,0))
  flame_mesh(0,0,.5,-.25)
 elif name=='pilier_de_flamme':
  for x in [-.23,0,.23]:flame_mesh(x,-.03,.9 if x==0 else .6,-.24,lean=.04)
  for z in [-.58,.56]:curve([(-.38,-.18,z),(0,-.18,z-.025),(.38,-.18,z)],.026,bronze)
 elif name=='brasier':
  for x in [-.34,0,.34]:flame_mesh(x,-.08,.95 if x==0 else .67,-.25,lean=-x*.5)
 elif name=='phenix':group(lambda:phoenix(False),scale=.83)
 elif name=='pluie_de_meteores':
  for x,z,k in [(-.38,.16,.43),(.04,-.26,.52),(.38,.27,.34)]:
   group(lambda:flame_mesh(0,0,k,-.22,lean=.02),loc=(x,0,z),rot=(0,.62,0))
   sphere((x,-.24,z-.1),(.11,.09,.13),iron)
 elif name=='cendres':
  for i in range(22):
   t=i*2.4;r=.1+.02*i;x=r*math.sin(t);z=r*math.cos(t)
   o=bevelled_box((x,-.16,z),(.07,.07,.045),fire if i%4==0 else iron,.018);o.rotation_euler=(.2*i,0,t)
  for x in [-.31,0,.3]:flame_mesh(x,-.18,.22,-.2)

def run():
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [];start=int(args[0]) if args else 0;stop=int(args[1]) if len(args)>1 else len(INV['files'])
 for i,rel in enumerate(list(INV['files'])[start:stop],start):
  name=Path(rel).stem;s=studio(name)
  if '/items/' in rel:build_object(name)
  elif '/spells/' in rel:spell(name);s.camera.location=(.55,-10,1.9);aim(s.camera,(0,0,0))
  elif '/interact/' in rel:medallion(name.removeprefix('interact_'));s.camera.location=(.25,-10,.8);aim(s.camera,(0,0,0))
  else:hand();s.camera.location=(.9,-10,2);aim(s.camera,(0,0,0))
  # Bevel every polygonal primitive; subdivide all lathed curved surfaces.
  for o in meshes():
   if o.type=='MESH' and not o.modifiers:
    b=o.modifiers.new('forged softened edges','BEVEL');b.width=.008;b.segments=3
    if 'Lathe' in o.name:
     sub=o.modifiers.new('continuous lathe curvature','SUBSURF');sub.levels=1
  for o in meshes():
   if o.type=='MESH' and 'Sphere' in o.name and not any(m.type=='BOOLEAN' for m in o.modifiers):
    sub=o.modifiers.new('smooth curved silhouette','SUBSURF');sub.levels=1
  frame_object_ortho(meshes(),.1)
  w,h=INV['files'][rel]['size'];s.render.resolution_x=max(256,w*2);s.render.resolution_y=max(256,h*2);s.eevee.taa_render_samples=24
  raw=OUT/(name+'.png');s.render.filepath=str(raw)
  bpy.ops.render.render(write_still=True)
  subprocess.run([PY,str(BASE/'i2_finish.py'),'fit',str(raw),rel],check=True,stdout=subprocess.DEVNULL)
  print('I2_OK',i+1,name,flush=True)
 bpy.ops.file.pack_all()
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'art/blender/ui/i2_source_{start:02}_{stop:02}.blend'))
if __name__=='__main__':run()
