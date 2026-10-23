"""U3 worn PBR inventory objects. Geometry only; reuse U2 materials/UI kit."""
import sys,math,json,ast,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from ui_kit import *
BASE=ROOT/'art/tools/ui';OUT=BASE/'u3_raw';OUT.mkdir(exist_ok=True)
# Reuse U2's worn shader without executing its render entry point.
plain_mat=mat
tree=ast.parse((BASE/'u2_build.py').read_text());exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='worn'],type_ignores=[]),'u2_worn','exec'))
def box(loc,scale,m= None,b=.025):return bevelled_box(loc,scale,m or iron,b)
def line(points,r=.02,m=None):return curve(points,r,m or edge)
def plate(pts,m=None,y=0,d=.15):return slab(pts,m or iron,d,y,.022)
def pin(x,z,y=-.18):
 flat_disk((x,y,z),.045,.035,edge)
 line([(x-.025,y-.024,z),(x+.025,y-.024,z)],.007,black)
def jewel(x,z,r=.1):
 o=crystal((x,-.26,z),r,r*2,accent);o.rotation_euler[0]=math.pi/2
 return o
def band(z,r=.5):
 o=torus((0,0,z),r,.045,bronze);o.rotation_euler[0]=0
 return o
def pendant():
 line([(-.25,0,.38),(-.48,.04,.98),(0,.08,1.2),(.48,.04,.98),(.25,0,.38)],.035,leather)
 torus((0,0,.33),.12,.04,edge)
def magnet(soul):
 pts=[(-.75,.8),(-.75,-.38),(-.5,-.8),(.35,-.86),(.7,-.55),(.72,.8),(.32,.8),(.32,-.3),(.15,-.42),(-.22,-.4),(-.34,-.22),(-.34,.8)]
 plate(pts,iron,d=.38)
 for x in [-.54,.52]:
  box((x,-.03,.67),(.43,.44,.25),edge);pin(x,.17,-.24)
 if soul:
  for x in [-.54,.52]:line([(x,-.25,-.4),(x,-.25,.45)],.018,accent)
  jewel(0,-.65,.11)
 else:jewel(-.54,.47,.07)
def bottle(kind):
 # Thick smoky glass, angular shoulders and actual neck, cork, retaining wire.
 lathe([(0,-.88),(.38,-.87),(.51,-.65),(.49,.2),(.22,.51),(.2,.86)],material=glass,segments=12)
 cylinder((0,0,.88),.2,.2,leather,12);band(.69,.22);band(-.65,.48)
 if kind=='antidote':
  box((0,-.48,-.15),(.5,.05,.16),bone);box((0,-.49,-.15),(.15,.05,.5),bone);jewel(0,-.15,.065)
 elif kind=='eclair_en_bouteille':line([(-.12,-.46,.38),(.15,-.49,.04),(-.12,-.5,-.14),(.18,-.45,-.61)],.035,accent)
 else:
  line([(-.2,-.47,-.49),(.18,-.47,-.49)],.07,accent)
  plate([(-.22,-.28),(.24,-.28),(.19,.12),(-.19,.08)],leather,-.49,.025);pin(0,-.07,-.54)
 line([(-.25,-.3,.42),(-.43,-.3,.15),(-.44,-.3,-.5)],.018,edge)
def shield():
 p=[(-.75,.88),(-.08,1.05),(.75,.84),(.67,-.25),(.36,-.75),(0,-1.05),(-.45,-.66),(-.72,-.18)]
 plate(p,bronze,d=.22);plate([(x*.88,z*.88) for x,z in p],iron,-.14,.13)
 for x in [-.53,.53]:
  for z in [-.12,.55]:pin(x,z,-.24)
 plate([(-.13,.72),(.12,.72),(.16,-.38),(0,-.64),(-.13,-.38)],edge,-.24,.04)
 jewel(0,.2,.16)
 line([(-.4,-.23,.63),(-.28,-.24,.28),(-.39,-.24,.1)],.012,black)
def heart(kind):
 pts=[(0,.48),(-.3,.76),(-.64,.66),(-.76,.25),(-.5,-.23),(0,-.86),(.54,-.22),(.72,.28),(.53,.69),(.24,.74)]
 m=stone if kind=='coeur_de_mousse' else glass if kind=='coeur_de_glace' else iron
 plate(pts,m,d=.48)
 line([(-.46,-.28,.51),(-.13,-.29,.22),(.05,-.29,.33),(.17,-.29,-.15),(0,-.29,-.62)],.028,accent)
 if kind=='coeur_de_mousse':
  for i in range(9):
   t=i*1.8;x=.53*math.sin(t);z=.4*math.cos(t)
   plate([(x,z),(x-.14,z+.18),(x+.04,z+.24)],moss,-.28,.05)
 if kind=='coeur_du_chronomancien':
  torus((0,-.31,0),.45,.065,bronze);clockface(.34,-.4)
def clockface(r,y):
 flat_disk((0,y,0),r,.06,leather)
 for i in range(12):
  t=i*math.tau/12;line([(r*.82*math.sin(t),y-.05,r*.82*math.cos(t)),(r*.96*math.sin(t),y-.05,r*.96*math.cos(t))],.012,edge)
 line([(-r*.37,y-.08,r*.42),(0,y-.08,0),(r*.6,y-.08,r*.18)],.022,bone);jewel(0,0,.055)
def clock():
 torus((0,0,.99),.2,.055,edge);flat_disk((0,0,0),.86,.24,bronze);torus((0,-.16,0),.78,.055,edge);clockface(.72,-.17)
 line([(-.37,-.27,.61),(-.2,-.28,.29),(-.36,-.28,.12),(-.11,-.28,-.17),(-.29,-.28,-.58)],.022,black)
 for x,z in [(-.67,.26),(.59,-.43)]:pin(x,z,-.24)
def crown():
 pts=[(-.9,-.48),(-.91,.52),(-.54,.18),(-.38,.87),(-.06,.35),(.28,1.02),(.47,.25),(.87,.62),(.8,-.48)]
 plate(pts,bronze,d=.26);box((-.02,-.17,-.33),(1.7,.08,.23),iron)
 for x in [-.6,-.2,.2,.6]:pin(x,-.32,-.24)
 jewel(.26,.36,.12)
def boot():
 plate([(-.61,.95),(.22,.95),(.2,.15),(.4,-.24),(.91,-.48),(.94,-.77),(-.62,-.77),(-.66,-.34)],leather,d=.65)
 box((.13,-.05,-.82),(1.65,.76,.16),black)
 box((-.21,-.34,.63),(.83,.1,.14),bronze)
 plate([(-.5,.2),(-.13,.25),(-.03,-.23),(-.47,-.31)],moss,-.36,.03)
 for z in [-.2,0,.2,.4]:line([(-.07,-.37,z),(.16,-.37,z+.1)],.022,bone)
 for z in [-.23,-.08,.06]:line([(-.49,-.4,z),(-.36,-.4,z+.04)],.012,edge)
 jewel(-.2,.63,.06)
def armor():
 pts=[(-.37,.95),(-.85,.75),(-.95,.31),(-.66,.12),(-.55,-.83),(.55,-.83),(.69,.13),(.98,.28),(.8,.76),(.36,.95),(.2,.65),(-.18,.65)]
 plate(pts,iron,d=.45)
 for sx in [-1,1]:
  plate([(sx*.1,.54),(sx*.55,.57),(sx*.63,.12),(sx*.13,-.04)],bronze,-.26,.12)
  for z in [-.59,-.34,-.09]:line([(sx*.1,-.3,z),(sx*.5,-.3,z+.08)],.025,edge)
  pin(sx*.68,.61,-.28)
 jewel(0,.32,.1)
def cape():
 plate([(-.23,1.01),(-.57,.67),(-.48,.3),(-.85,-.83),(-.5,-.68),(-.37,-1.02),(-.1,-.75),(.24,-.98),(.49,-.7),(.78,-.84),(.48,.62),(.23,1.01)],leather,d=.12)
 for x in [-.35,-.1,.19,.37]:line([(x*.6,-.12,.52),(x,-.12,-.2),(x*1.6,-.12,-.76)],.027,black)
 line([(-.4,-.19,.55),(0,-.22,.4),(.38,-.18,.57)],.03,bronze);jewel(0,.43,.09)
def quiver():
 o=box((0,0,-.17),(.73,.52,1.5),leather,.055);o.rotation_euler[1]=-.16
 for z in [-.8,.45]:box((0,-.29,z),(.85,.09,.14),bronze)
 for x,h in [(-.27,1.12),(0,1.3),(.24,1.05)]:
  line([(x,0,.2),(x-.12,0,h)],.025,wood)
  plate([(x-.13,h-.2),(x-.3,h+.12),(x-.13,h+.02),(x+.06,h+.16),(x+.02,h-.15)],bone,.02,.025)
 line([(-.5,.1,-.6),(-.7,.1,.38),(.36,.1,.73)],.055,leather);jewel(0,.45,.06)
def crystal_obj(kind):
 if kind=='cristal_de_feu':
  crystal((0,0,-.23),.52,1.85,glass);jewel(0,.09,.21)
  line([(-.18,-.5,-.62),(.08,-.53,-.22),(-.08,-.46,.13),(.03,-.32,.46)],.035,accent)
  for x,z in [(-.42,-.38),(.39,-.46)]:
   o=crystal((x,0,z),.2,.93,stone);o.rotation_euler[1]=x
 elif kind=='eclat_d_experience':
  plate([(-.72,-.42),(-.26,.28),(.35,1),(.64,.24),(.21,-.9)],glass,d=.45)
  line([(-.45,-.25,-.4),(.15,-.25,.22),(.35,-.25,.8)],.027,accent)
 else:
  # Chipped flint and steel, with a narrow live ember in the flint seam.
  plate([(-.67,-.62),(-.79,.06),(-.24,.5),(.3,.26),(.45,-.36),(0,-.8)],stone,d=.45)
  line([(-.45,-.26,.1),(-.13,-.28,-.1),(.17,-.27,-.43)],.028,accent)
  line([(-.37,.01,.47),(-.44,.01,.85),(.14,.01,1.02),(.69,.01,.72),(.4,.01,.29)],.09,iron)
def build(name):
 if name in ['aimant_d_ame','aimant_de_poche']:magnet(name=='aimant_d_ame')
 elif name in ['antidote','fiole_verte','eclair_en_bouteille']:bottle(name)
 elif name=='amulette_de_cuir':
  pendant();plate([(-.42,.23),(.38,.18),(.51,-.5),(0,-.91),(-.47,-.51)],leather,d=.18)
  for x,z in [(-.31,.05),(.3,.02),(-.3,-.42),(.3,-.43),(0,-.75)]:pin(x,z,-.13)
  line([(-.18,-.15,-.1),(0,-.15,-.48),(.2,-.15,-.09)],.028,edge);jewel(0,-.28,.07)
 elif name=='armure_du_colosse':armor()
 elif name=='bague_de_vigueur':
  torus((0,0,-.1),.59,.135,bronze);box((0,-.1,.48),(.53,.32,.25),iron);jewel(0,.57,.23)
  for x in [-.4,.4]:pin(x,.22,-.15)
 elif name=='botte_rapiecee':boot()
 elif name=='bouclier_reactif':shield()
 elif name=='cape_de_brume':cape()
 elif name=='carquois_affute':quiver()
 elif name=='chronometre_brise':clock()
 elif name.startswith('coeur_'):heart(name)
 elif name=='couronne_d_echo':crown()
 elif name in ['cristal_de_feu','eclat_d_experience','etincelle']:crystal_obj(name)
 elif name=='danseur':
  # Articulated leather dancing shoe, long laces and a steel heel.
  plate([(-.68,.39),(-.43,.62),(-.12,.34),(.13,-.17),(.76,-.49),(.87,-.73),(.4,-.86),(-.5,-.61)],leather,d=.5)
  plate([(-.54,-.49),(-.55,-.88),(-.28,-.88),(-.19,-.63)],iron,d=.52)
  line([(-.37,-.28,.42),(-.65,-.25,.94),(-.2,-.25,1.06),(.3,-.25,.64),(.09,-.26,.29)],.035,bronze)
  for x,z in [(-.26,.1),(-.12,-.08),(.05,-.25)]:line([(x-.13,-.28,z),(x+.15,-.28,z-.08)],.025,bone)
  jewel(-.31,.35,.08)
 elif name=='de_pipe':
  o=box((0,0,0),(1.35,1,1.35),bone,.07);o.rotation_euler=(.12,.2,.15)
  for x,z in [(-.36,.36),(0,0),(.36,-.36)]:flat_disk((x,-.58,z),.095,.035,black)
  jewel(0,0,.065)
  line([(-.6,-.57,-.46),(-.48,-.58,-.14),(-.55,-.58,.12)],.014,bronze)
 elif name=='epines':
  line([(-.54,0,-.8),(-.38,0,-.13),(.05,0,.24),(.32,0,.96)],.12,wood)
  for x,z,s in [(-.47,-.48,-1),(-.3,-.05,1),(.03,.3,-1),(.23,.67,1)]:plate([(x-.07,z-.16),(x+s*.48,z+.29),(x+.08,z+.06)],bone,d=.16)
  jewel(-.13,.02,.1)
 elif name=='faveur_du_marchand':
  pendant();plate([(-.53,.16),(.35,.25),(.58,-.2),(.24,-.83),(-.44,-.76)],bronze,d=.18)
  line([(-.26,-.13,-.54),(-.28,-.13,-.07),(.05,-.13,-.38),(.29,-.13,-.04),(.22,-.13,-.6)],.035,edge)
  pin(-.3,-.62,-.15);jewel(0,.06,.08)
 elif name=='flocon':
  # Six narrow carved quartz arms in a patinated clasp.
  for i in range(6):
   t=i*math.tau/6;dx,dz=math.sin(t),math.cos(t)
   plate([(-dz*.07,dx*.07),(dx*.88-dz*.045,dz*.88+dx*.045),(dx*1.04,dz*1.04),(dx*.88+dz*.045,dz*.88-dx*.045),(dz*.07,-dx*.07)],glass,d=.16)
   for sign in [-1,1]:line([(dx*.5,0,dz*.5),(dx*.68+sign*dz*.19,0,dz*.68-sign*dx*.19)],.045,bronze)
  torus((0,-.1,0),.24,.06,edge);jewel(0,0,.14)
 else:raise ValueError(name)

inv=json.loads((BASE/'_u3_inventory.json').read_text());start=int(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else 0
for name in inv['objects'][start:start+8 if start<24 else 25]:
 s=new_scene('u3_'+name,16)
 # Midtones are linear albedo ~0.25-0.5, with restrained dark recesses.
 iron=worn('#8299AA','#B0C0CB',.48,.48);bronze=worn('#699383','#AFB9A0',.48,.57);edge=worn('#AC9567','#D1BD8A',.55,.4)
 leather=worn('#8F6461','#BF9490',0,.76);wood=worn('#8D795B','#BFA883',0,.78);bone=worn('#AFA58D','#DDD2B6',0,.68)
 black=worn('#202933','#414953',.15,.8);stone=worn('#879288','#B3BBA9',.05,.8);moss=worn('#6E865B','#9CAA7D',0,.87)
 # Deliberate dominant identities for adjacent inventory entries.
 if name=='aimant_de_poche':iron=worn('#A19B85','#C6BFAB',.5,.49)
 if name=='armure_du_colosse':iron=worn('#718DAD','#A1B9D0',.5,.46)
 if name=='bague_de_vigueur':bronze=worn('#AB945D','#D0BC83',.58,.42)
 if name=='botte_rapiecee':leather=worn('#8D7152','#B8A080',0,.8)
 if name=='bouclier_reactif':iron=worn('#77988F','#ABC3B6',.48,.5)
 if name=='cape_de_brume':leather=worn('#7A879F','#ABB8CA',0,.88)
 if name=='carquois_affute':leather=worn('#9A8060','#C2AB8B',0,.78)
 if name=='chronometre_brise':bronze=worn('#A58B60','#D1BC92',.55,.43)
 if name=='coeur_du_chronomancien':iron=worn('#91859C','#B8AFC4',.43,.47)
 if name=='couronne_d_echo':bronze=worn('#A39460','#C8BD85',.58,.43)
 if name=='danseur':leather=worn('#896879','#B797A7',0,.73)
 if name=='faveur_du_marchand':bronze=worn('#65958C','#9CC1B0',.5,.53)
 colors={'antidote':'#8BA778','fiole_verte':'#8CA75A','eclair_en_bouteille':'#8FBBC2','coeur_de_glace':'#8DADB7','flocon':'#A1BEC6','cristal_de_feu':'#D8793E','etincelle':'#D58642','eclat_d_experience':'#78ADA5','aimant_d_ame':'#80A59C','cape_de_brume':'#829EA7'}
 color=colors.get(name,'#B9A06A');accent=plain_mat(color,.3,.15,color,2.8)
 glass=worn('#7B9CA9','#B0CCD1',.22,.2)
 if name=='antidote':glass=worn('#8D9D6A','#BCCA98',.15,.22)
 if name=='fiole_verte':glass=worn('#609583','#98C0A4',.15,.22)
 if name=='eclair_en_bouteille':glass=worn('#818AAF','#B4BED8',.2,.2)
 if name=='cristal_de_feu':glass=worn('#AC795B','#D5A27E',.15,.24);stone=worn('#8D655C','#B78E7B',.1,.72)
 if name=='eclat_d_experience':glass=worn('#6D9E9D','#A2C9BE',.2,.22)
 if name=='etincelle':stone=worn('#8B8170','#B7AB8D',.1,.8)
 glass.node_tree.nodes.get('Principled BSDF').inputs['Coat Weight'].default_value=.5
 s.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.18,.18,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.38
 for o in s.objects:
  if o.type=='LIGHT':o.data.energy=3.2 if 'chaud' in o.name else 1.1;o.data.color=rgba('#FFF0D9' if 'chaud' in o.name else '#B3D4FA')[:3];o.data.angle=.15
 d=bpy.data.lights.new('U3b contour froid','AREA');d.energy=190;d.color=rgba('#AACFED')[:3];d.shape='DISK';d.size=3
 o=bpy.data.objects.new('U3b contour froid',d);s.collection.objects.link(o);o.location=(2,1.8,3);aim(o,(0,0,0))
 build(name)
 # Slight three-quarter view keeps front sculpting legible.
 for o in list(s.objects):
  if o.type in {'MESH','CURVE'}:
   rot=Matrix.Rotation(math.radians(-10),4,'Z');o.matrix_world=rot @ o.matrix_world
 front_camera(2.8,2.8,256,256,16)
 # Keep independent, editable scenes in one source per completed batch.
 s.render.filepath=str(OUT/(name+'.png'));bpy.ops.render.render(write_still=True)
 print('U3 DONE',name,flush=True)
blend=ROOT/'art/blender/ui'/f'u3_batch_{start//8+1}.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
