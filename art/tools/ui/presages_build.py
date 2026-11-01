import bpy, math, sys, subprocess, json
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/icons/omens'; OUT.mkdir(parents=True,exist_ok=True)
BLEND=ROOT/'art/blender/ui/presages.blend'; BLEND.parent.mkdir(parents=True,exist_ok=True)
LOG=ROOT/'art/tools/ui/_logpresages.txt'

def mat(name,color,metal=0,em=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*color,1);e.inputs[1].default_value=em if em else 1;m.node_tree.links.new(e.outputs[0],o.inputs['Surface']);return m
def poly(name,pts,ma,y=-.15,depth=.12):
 n=len(pts);v=[(x,y,z) for x,z in pts]+[(x,y+depth,z) for x,z in pts];f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],f);me.materials.append(ma);ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);return ob
def disk(name,x,z,r,ma,y=-.18,n=32):
 return poly(name,[(x+r*math.cos(2*math.pi*i/n),z+r*math.sin(2*math.pi*i/n)) for i in range(n)],ma,y,.12)
def line(name,pts,ma,r=.025,y=-.30):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=1;p=c.splines.new('POLY');p.points.add(len(pts)-1)
 for a,b in zip(p.points,pts):a.co=(b[0],y,b[1],1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(ma)
def base(accent,clear=False):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16
 s.render.resolution_x=s.render.resolution_y=128;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True
 s.view_settings.view_transform='Standard';s.view_settings.look='Medium High Contrast';s.display.shading.light='STUDIO'
 s.camera_data if False else None
 bpy.ops.object.camera_add(location=(0,-10,0));cam=bpy.context.object;cam.data.type='ORTHO';cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=2.12;s.camera=cam
 # cel-stepped metal palette
 iron=mat('Iron',(0.075,0.085,0.09));shade=mat('Iron shade',(0.035,0.04,0.045));light=mat('Iron edge',(0.24,0.25,0.23));bronze=mat('Bronze',(0.32,0.20,0.095));glow=mat('Omen accent',accent,em=2.0)
 rim=mat('Pale medallion',(0.40,0.43,0.44)) if clear else bronze
 disk('Medallion',0,0,.91,shade,y=.10,n=48);disk('Iron face',0,0,.80,light,y=-.02,n=48);disk('Inset',0,0,.73,iron,y=-.11,n=48)
 for i in range(12):
  a=2*math.pi*i/12; pts=[]
  for rr,aa in [(0.84,a-.075),(0.98,a),(0.84,a+.075)]:pts.append((rr*math.cos(aa),rr*math.sin(aa)))
  poly('Bronze chevron',pts,rim,-.22,.07)
 return (iron,shade,light,bronze,glow)
def icon(id):
 combat=id in {'pluie_de_cendres','carapaces','fievre','eveil_des_elites'}
 accents={'pluie_de_cendres':(.95,.20,.045),'carapaces':(.72,.10,.075),'fievre':(1,.12,.035),'eveil_des_elites':(1,.32,.045),'marche_noir':(.88,.56,.12),'offrande':(1,.65,.13),'usure':(.78,.34,.10),'maree':(.14,.48,.66),'ciel_clair':(.55,.77,.95)}
 iron,shade,light,bronze,g=base(accents[id],id=='ciel_clair')
 if id=='pluie_de_cendres':
  for x,z,r in [(-.25,.28,.22),(0,.34,.27),(.25,.26,.2)]:disk('Ash cloud',x,z,r,shade,-.28,20)
  for x,z in [(-.34,-.02),(-.12,-.10),(.1,-.04),(.3,-.1)]:line('Falling ember',[(x,z+.08),(x-.025,z),(x,z-.12)],g,.018)
 elif id=='carapaces':
  poly('Shell',[(0,.56),(.42,.35),(.36,-.23),(0,-.52),(-.36,-.23),(-.42,.35)],bronze,-.35,.16)
  line('Shell seam',[(0,.48),(0,-.43)],light,.025,-.44)
  for z in [.23,0,-.23]:line('Shell plate',[(-.3,z+.1),(0,z+.18),(.3,z+.1)],g if z==0 else light,.022,-.46)
 elif id=='fievre':
  poly('Cracked hourglass',[(-.22,.50),(.22,.50),(.13,.10),(.26,-.42),(-.26,-.42),(-.13,.10)],light,-.36,.13)
  line('Glass split',[(-.19,.25),(.05,.12),(-.04,-.02),(.19,-.2)],g,.035,-.5)
  for x in [-.37,.37]:line('Flame',[ (x,-.08),(x-.06,.06),(x,.16),(x+.05,.08)],g,.025,-.4)
 elif id=='eveil_des_elites':
  line('Eye', [(-.46,0),(-.22,.19),(0,.25),(.24,.17),(.46,0),(.22,-.18),(0,-.24),(-.22,-.16),(-.46,0)],light,.045,-.4)
  disk('Pupil',0,0,.09,g,-.5)
  for i in range(7):
   x=-.42+i*.14;line('Thorn',[(x,.40),(x+.04,.55 if i%2 else .50),(x+.10,.39)],g,.018,-.3)
 elif id=='marche_noir':
  poly('Draped stall',[(-.46,-.36),(-.39,.25),(0,.45),(.39,.25),(.46,-.36),(.25,-.25),(0,-.4),(-.25,-.25)],shade,-.32,.12)
  line('Canopy', [(-.42,.25),(0,.48),(.42,.25)],bronze,.04,-.48)
  disk('Coin',0,-.02,.21,g,-.5,12);line('Coin slash',[(-.16,-.2),(.16,.16)],shade,.035,-.58)
 elif id=='offrande':
  poly('Reliquary', [(-.38,-.26),(-.34,.27),(0,.48),(.34,.27),(.38,-.26)],bronze,-.3,.15)
  disk('Open shrine',0,.03,.22,shade,-.48)
  line('Offering bowl',[(-.3,-.17),(-.2,-.34),(0,-.39),(.2,-.34),(.3,-.17)],g,.035,-.52)
  for x,z in [(-.13,-.14),(0,-.1),(.14,-.15)]:disk('Coin',x,z,.07,g,-.55,12)
 elif id=='usure':
  poly('Shield',[(-.42,.36),(0,.48),(.42,.36),(.35,-.12),(0,-.48),(-.35,-.12)],light,-.32,.15)
  line('Crack',[(-.08,.4),(.05,.12),(-.10,-.02),(.08,-.24),(0,-.43)],g,.035,-.5)
  for x,z in [(-.31,.22),(.31,.22),(-.24,-.12),(.24,-.12)]:disk('Rivet',x,z,.045,bronze,-.5,10)
 elif id=='maree':
  line('Rising wave',[(-.46,-.18),(-.25,-.05),(-.05,.10),(.14,.04),(.30,.22),(.44,.28)],g,.075,-.44)
  line('Wave crest',[(-.43,-.30),(-.18,-.23),(.08,-.19),(.38,-.08)],light,.035,-.46)
  for x,z in [(-.2,-.02),(.05,.02),(.28,.14)]:disk('Carried coin',x,z,.065,bronze,-.53,12)
 else:
  disk('Pale sun',0,.08,.30,g,-.35,32)
  for x in [-.43,.43]:
   disk('Riven cloud',x,-.05,.24,light,-.46,20)
   poly('Cloud cut',[(x-.22,-.12),(x+.22,-.12),(x+.12,-.23),(x-.18,-.23)],shade,-.55,.08)
 s=bpy.context.scene;s.render.filepath=str(OUT/(id+'.png'));bpy.ops.render.render(write_still=True)
def main():
 ids=['pluie_de_cendres','carapaces','fievre','eveil_des_elites','marche_noir','offrande','usure','maree','ciel_clair']
 for x in ids:icon(x)
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
 verification = r"""
from pathlib import Path
from PIL import Image
import hashlib
root=Path.cwd();out=root/'game/assets/sprites/icons/omens'
ids=IDS
contact=Image.new('RGBA',(9*112,150),(25,27,30,255));hashes=set();small=set()
for i,name in enumerate(ids):
 p=out/(name+'.png');im=Image.open(p).convert('RGBA');a=im.getchannel('A')
 assert im.size==(128,128) and a.getextrema()==(0,255),name
 disk=[a.getpixel((x,y)) for y in range(128) for x in range(128) if (x-63.5)**2+(y-63.5)**2<=55**2]
 assert sum(v==255 for v in disk)/len(disk)>=.55,name
 assert a.getbbox() and 114<=a.getbbox()[2]-a.getbbox()[0]<=120,name
 hashes.add(hashlib.sha256(im.tobytes()).digest())
 sm=im.resize((48,48),Image.Resampling.LANCZOS);center=sm.crop((13,13,35,35)).convert('RGB')
 assert max(hi-lo for lo,hi in center.getextrema())>=40,name
 small.add(hashlib.sha256(center.tobytes()).digest())
 contact.alpha_composite(im.resize((96,96),Image.Resampling.LANCZOS),(i*112+8,0));contact.alpha_composite(sm,(i*112+32,100))
 im.save(p,optimize=True)
 e=out/(name+'_e.png')
 if e.exists():
  em=Image.open(e);assert em.size in [(64,64),(128,128)] and any(hi>0 for lo,hi in em.convert('RGB').getextrema()),name
assert len(hashes)==len(small)==9
assert not list(out.glob('*_n.png'))
contact.convert('RGB').save(root/'art/tools/ui/_presages_contact.png',optimize=True)
print('PASS icons=9 alpha_max=255 opaque_disk>=55% distinct=9 contrast48=PASS')
""".replace('IDS',repr(ids))
 subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-c',verification],check=True,cwd=str(ROOT))
 with open(LOG,'w') as f:f.write('PASS icons=9 size=128x128 alpha=RGBA visible48=checked normals=0\n')
 print('PASS icons=9 size=128x128 alpha=RGBA visible48=checked normals=0')
main()


