"""U4 worn PBR objects and articulated gauntlet; background Eevee only."""
import sys,ast,math,json,random
from pathlib import Path
BASE=Path(__file__).resolve().parent;sys.path.insert(0,str(BASE))
from ui_kit import *
import items_a as a,items_b as b,items_c as c
def fit(raw,rel):
 subprocess.run([PY,str(BASE/'u4_finish.py'),'fit',str(raw),rel],check=True,stdout=subprocess.DEVNULL)
OUT=BASE/'u4_raw';OUT.mkdir(exist_ok=True)
# Reuse the validated U2 metal recipes and medallion geometry without its entrypoint.
tree=ast.parse((BASE/'u2_build.py').read_text())
names={'worn','palette','scene','rivet','ticks','flame','medal'}
plain_mat=mat
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in names],type_ignores=[]),'u2_recipes','exec'))
def hand(k=1,y=-.4,disabled=False):
 m=iron; rim=bronze if disabled else edge
 def plate(points,depth=.07,yy=y):return slab([(x*k,z*k) for x,z in points],m,depth*k,yy,.018*k)
 # Flared wrist, curved metacarpal shell, overlapping tapered knuckle lames.
 plate([(-.35,-.65),(.33,-.65),(.27,-.28),(-.28,-.28)],.16)
 for z in [-.56,-.43]:curve([(-.32*k,y-.1,z*k),(0,y-.13,(z-.025)*k),(.3*k,y-.1,z*k)],.018*k,rim)
 plate([(-.29,-.32),(-.36,.02),(-.24,.26),(.24,.25),(.34,.02),(.26,-.32)],.2)
 for x in [-.19,0,.19]:curve([(x*k,y-.13,-.23*k),(x*k,y-.16,.16*k)],.012*k,bronze)
 for i in range(4):
  x=(-.255+i*.164); length=[.49,.65,.6,.45][i];w=[.139,.148,.142,.123][i]
  for j in range(3):
   z=.19+j*length/3;ww=w*(1-j*.15);h=length/3+.035
   plate([(x-ww/2,z),(x-ww*.55,z+h*.62),(x-ww*.28,z+h),(x+ww*.3,z+h),(x+ww*.55,z+h*.62),(x+ww/2,z)],.11,y-.025-j*.009)
   curve([((x-ww*.43)*k,y-.092-j*.009,(z+.04)*k),(x*k,y-.115-j*.009,(z+.06)*k),((x+ww*.43)*k,y-.092-j*.009,(z+.04)*k)],.012*k,rim)
   if j<2:
    for sx in [-1,1]:rivet((x+sx*ww*.33)*k,(z+.07)*k,y-.104-j*.009,.014*k)
  rivet(x*k,.22*k,y-.15,.038*k)
 # Thumb has its own opposed hinge and two angled lames.
 for j in range(3):
  x=-.3-j*.103;z=-.02+j*.13
  plate([(x-.08,z-.08),(x-.18,z+.03),(x-.12,z+.18),(x-.025,z+.18),(x+.04,z+.02)],.13,y-.03)
  rivet((x-.06)*k,(z+.025)*k,y-.115,.023*k)
 for x in [-.24,.22]:rivet(x*k,-.49*k,y-.12,.033*k)
def aged_materials():
 # Replace every legacy palette, including locally created materials, with PBR patina.
 for ob in meshes():
  for slot in ob.material_slots:
   old=slot.material
   if not old or old.name.startswith('u4_'):continue
   p=old.node_tree.nodes.get('Principled BSDF'); col=p.inputs['Base Color'].default_value
   r,g,bl=col[:3];metal=p.inputs['Metallic'].default_value
   if old==a.ivory:new=worn('#413C30','#B4AA8A',.05,.76)
   elif old==a.steel:new=worn('#171B1D','#7A817D',.75,.48)
   elif old in [a.leather,a.wood]:new=worn('#110F0D','#534031',0,.87)
   elif max(r,g,bl)-min(r,g,bl)<.12:new=worn('#161918','#77756A',max(.45,metal),.56)
   elif r>g*1.5 and r>bl*1.5:new=worn('#301A12','#87502D',.25,.65)
   elif bl>r*1.2 or g>r*1.2:new=worn('#172C29','#6D8D81',.48,.5)
   else:new=worn('#2B2117','#A18B61',max(.35,metal),.58)
   new.name='u4_'+old.name;slot.material=new
def object_build(name):
 a.palette();b.purple=plain_mat('#6D7268');b.burgundy=plain_mat('#69382D')
 if name=='peste_vivante':
  # Apotropaic plague reliquary, angular osseous face rather than floating bubbles.
  slab([(-.48,-.12),(-.65,.34),(-.5,.78),(-.23,.94),(.3,.86),(.58,.48),(.48,-.15),(.24,-.37),(-.24,-.37)],a.ivory,.46,.0,.07)
  for sx in [-1,1]:
   slab([(sx*.08,.32),(sx*.4,.48),(sx*.49,.25),(sx*.27,.09),(sx*.12,.14)],a.dark,.04,-.26,.01)
   curve([(sx*.48,-.27,.52),(sx*.24,-.29,.57),(sx*.08,-.28,.43)],.045,a.ivory)
  slab([(-.1,.02),(0,.2),(.1,.02),(0,-.08)],a.dark,.04,-.27,.005)
  for x in [-.27,-.16,-.05,.06,.17,.28]:slab([(x-.045,-.22),(x+.04,-.22),(x+.03,-.43),(x-.035,-.4)],a.ivory,.09,-.22,.013)
  for sx in [-1,1]:
   curve([(sx*.39,.0,-.37),(sx*.53,.01,-.68),(sx*.27,-.03,-.81),(0,-.02,-.87)],.07,a.gold)
  curve([(-.29,-.27,.78),(-.16,-.28,.61),(-.23,-.28,.49)],.013,a.dark)
 elif name=='phenix_de_poche':
  flat_disk((0,.04,0),.92,.17,a.dark);torus((0,-.07,0),.86,.04,a.gold)
  for sx in [-1,1]:
   for i in range(5):
    x=sx*(.29+i*.1);z=.12+i*.09
    slab([(sx*.08,-.12),(x,z+.21),(sx*(.76+i*.025),.52-i*.125),(sx*.3,-.28)],a.gold,.055,-.12-i*.012,.012)
  slab([(-.11,-.49),(-.2,.08),(-.08,.34),(-.06,.57),(.11,.63),(.27,.48),(.12,.42),(.18,.05),(.07,-.49)],a.steel,.12,-.23,.018)
  for x in [-.16,0,.16]:slab([(x,-.2),(x+.07,-.61),(x-.04,-.79),(x-.07,-.45)],a.gold,.04,-.22,.008)
 else:
  module=next(mod for mod in [c,b,a] if hasattr(mod,name));getattr(module,name)()
 aged_materials()
 # Wear-cut bevels on formerly flat polygon extrusions, no outline shell.
 for ob in meshes():
  if ob.type=='MESH' and not ob.modifiers:
   bevel=ob.modifiers.new('Worn forged edge','BEVEL');bevel.width=.025;bevel.segments=2
 # Small set-in ember seal, consistently one emissive accent.
 sphere((0,-.57,-.18),(.035,.021,.05),ember)
 if name in ['horloge_arcanique','pavois_fele','rune_de_portee','piece_porte_bonheur','marque_du_chasseur']:
  for t in [i*math.tau/8 for i in range(8)]:rivet(.66*math.sin(t),.66*math.cos(t),-.32,.025)
def spell(name):
 flat_disk((0,.07,0),.94,.16,black)
 torus((0,-.035,0),.84,.018,bronze);ticks(.8,-.045,24)
 # Raised forged relief with narrow incandescent seams, each spell has its own silhouette.
 def fire(x,z,k):
  pts=[(-.22,-.4),(-.34,-.1),(-.08,.24),(-.04,.6),(.16,.19),(.1,-.02),(.26,.18),(.3,-.22),(.1,-.4)]
  slab([(x+u*k,z+v*k) for u,v in pts],edge,.05,-.15,.012)
  curve([(x-.06*k,-.19,z-.24*k),(x+.06*k,-.2,z),(x,-.19,z+.3*k)],.018,ember)
 if name=='eclat_de_braise':fire(0,0,1.15)
 elif name=='braises_errantes':
  for t in [0,2.1,4.2]:fire(.43*math.sin(t),.43*math.cos(t),.48)
 elif name=='nova_ardente':
  for i in range(10):
   t=i*math.tau/10;curve([(.24*math.sin(t),-.17,.24*math.cos(t)),(.65*math.sin(t+.12),-.17,.65*math.cos(t+.12))],.032,ember)
  torus((0,-.17,0),.27,.055,edge);fire(0,0,.35)
 elif name=='pluie_de_meteores':
  for x,z,k in [(-.4,.17,.65),(.12,-.28,.8),(.43,.3,.45)]:
   fire(x,z,k);curve([(x,-.18,z),(x+.16,-.18,z+.36)],.035,ember)
 elif name=='phenix':
  slab([(-.09,-.55),(-.22,-.1),(-.7,.35),(-.62,.59),(-.28,.25),(0,.08),(.28,.25),(.62,.59),(.7,.35),(.22,-.1),(.09,-.55)],edge,.07,-.15,.012)
  for sx in [-1,1]:
   for i in range(3):curve([(sx*.1,-.2,-.04),(sx*(.43+i*.09),-.2,.13+i*.15)],.018,ember)
  fire(0,.1,.45)
 elif name=='pilier_de_flamme':
  for x in [-.18,0,.18]:fire(x,-.02, .95 if x==0 else .7)
  for z in [-.52,.53]:curve([(-.42,-.16,z),(.42,-.16,z)],.03,edge)
 elif name=='cendres':
  for i in range(13):
   t=i*2.4;r=.15+.035*i;x=r*math.cos(t);z=r*math.sin(t)
   slab([(x-.04,z-.03),(x+.055,z),(x+.015,z+.09)],ember if i%3==0 else bone,.035,-.15,.005)
 else:
  for x,z,k in [(-.37,-.14,.68),(0,.05,1.1),(.36,-.15,.7)]:fire(x,z,k)
def run():
 inv=json.loads((BASE/'_u4_inventory.json').read_text());rels=list(inv['files']);args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
 start=int(args[0]) if args else 0;stop=int(args[1]) if len(args)>1 else len(rels)
 for index,rel in enumerate(rels[start:stop],start):
  name=Path(rel).stem;s=scene(name)
  if '/items/' in rel:object_build(name);frame_object_ortho(meshes(),.12);s.camera.location=(0,-10,2.1);aim(s.camera,(0,0,0))
  elif '/spells/' in rel:spell(name);front_camera(2.15,2.15,256,256)
  elif '/interact/' in rel:medal(name.removeprefix('interact_'),'interact');front_camera(2.5,2.5,256,256)
  else:hand(1,0);front_camera(1.8,1.8,192,192)
  w,h=inv['files'][rel]['size'];s.render.resolution_x=w*2;s.render.resolution_y=h*2;s.eevee.taa_render_samples=24
  raw=OUT/(name+'.png');s.render.filepath=str(raw);bpy.ops.render.render(write_still=True);fit(raw,rel)
  print('U4_OK',index+1,name,flush=True)
  if (index+1)%8==0:print('U4_PACKET_COMPLETE',index+1,flush=True)
 blend=ROOT/f'art/blender/ui/u4_source_{start:02}_{stop:02}.blend';bpy.ops.wm.save_as_mainfile(filepath=str(blend))
if __name__=='__main__':run()
