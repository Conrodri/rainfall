import bpy, math, json, subprocess
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/ui/forge'; RAW=ROOT/'art/renders/ux/ux_e_raw'
OUT.mkdir(parents=True,exist_ok=True); RAW.mkdir(parents=True,exist_ok=True)
exec(compile((ROOT/'art/tools/ui/ui_lib.py').read_text(encoding='utf-8'),str(ROOT/'art/tools/ui/ui_lib.py'),'exec'))
import sys
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import cel_style as cel

def mat(name,color,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 n=m.node_tree.nodes; n.clear(); o=n.new('ShaderNodeOutputMaterial'); e=n.new('ShaderNodeEmission'); e.inputs[0].default_value=(*color,1); e.inputs[1].default_value=1+emit; m.node_tree.links.new(e.outputs[0],o.inputs['Surface']); return m
def poly(name,pts,y,ma):
 me=bpy.data.meshes.new(name); me.from_pydata([(x,y,z) for x,z in pts],[],[tuple(range(len(pts)))]); me.materials.append(ma); ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
def rect(name,x0,z0,x1,z1,y,ma): poly(name,[(x0,z0),(x1,z0),(x1,z1),(x0,z1)],y,ma)
def ring(name,x0,z0,x1,z1,t,y,ma):
 rect(name+'top',x0,z1-t,x1,z1,y,ma); rect(name+'bottom',x0,z0,x1,z0+t,y,ma); rect(name+'left',x0,z0+t,x0+t,z1-t,y,ma); rect(name+'right',x1-t,z0+t,x1,z1-t,y,ma)
def circle(name,x,z,r,y,ma): poly(name,[(x+math.cos(i*math.tau/24)*r,z+math.sin(i*math.tau/24)*r) for i in range(24)],y,ma)
def draw(kind):
 if kind=='recipe': edge,inner,face,rivet=(.30,.16,.095),(.47,.27,.15),(.043,.045,.043),(.67,.42,.23)
 elif kind=='off': edge,inner,face,rivet=(.22,.19,.15),(.30,.26,.21),(.043,.045,.043),(.26,.22,.18)
 else: edge,inner,face,rivet=(.43,.25,.13),(.62,.37,.19),(.043,.045,.043),(.78,.52,.28)
 # Full border with clipped ornamental corner geometry; broad straight runs repeat cleanly.
 rect('dark backing',-1.04,-1.04,1.04,1.04,.08,mat('ink',( .025,.028,.028)))
 rect('inset field',-.78,-.78,.78,.78,.03,mat('field',face))
 ring('outer forged rim',-.94,-.94,.94,.94,.085,-.02,mat('copper edge',edge))
 ring('inner rim',-.84,-.84,.84,.84,.035,-.04,mat('copper inner',inner))
 # Small angular corner plates within 28 px margin.
 for x in (-.83,.83):
  for z in (-.83,.83):
   sx=1 if x>0 else -1; sz=1 if z>0 else -1
   poly('corner filigree',[(x,z),(x-sx*.19,z),(x-sx*.19,z-sz*.04),(x-sx*.04,z-sz*.04),(x-sx*.04,z-sz*.19),(x,z-sz*.19)],-.06,mat('corner bronze',inner))
   if kind!='off':
    circle('rivet socket',x-sx*.075,z-sz*.075,.033,-.075,mat('socket',edge))
    circle('rivet',x-sx*.075,z-sz*.075,.018,-.09,mat('rivet',rivet))
 if kind=='gain': ring('warm inner glint',-.765,-.765,.765,.765,.012,-.095,mat('emission orange',(1,.34,.075),1.7))
def reset(size):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=8; s.render.resolution_x=s.render.resolution_y=size; s.render.resolution_percentage=100; s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True; s.render.image_settings.color_mode='RGBA'; s.view_settings.view_transform='Standard'; s.view_settings.look='None'; bpy.ops.object.camera_add(location=(0,-10,0)); c=bpy.context.object; c.data.type='ORTHO'; c.data.ortho_scale=2.08; c.rotation_euler=(math.pi/2,0,0); s.camera=c; return s
def run():
 for name,kind in [('forge_recipe_9slice','recipe'),('forge_recipe_9slice_off','off'),('forge_gain_9slice','gain')]:
  s=reset(192); draw(kind); s.render.filepath=str(RAW/(name+'.png')); bpy.ops.render.render(write_still=True)
  subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-c',"from PIL import Image;import sys;Image.open(sys.argv[1]).convert('RGBA').save(sys.argv[2],optimize=True)",str(RAW/(name+'.png')),str(OUT/(name+'.png'))],check=True)
 # Binary/soft mask extracted from Blender's material pass: retain only warm inner rule.
 subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-c',"from PIL import Image;import sys;im=Image.open(sys.argv[1]).convert('RGBA'); p=im.load();\nfor y in range(im.height):\n for x in range(im.width):\n  r,g,b,a=p[x,y];p[x,y]=(255,105,24,a if a and r>180 and g<145 else 0)\nim.resize((96,96),Image.Resampling.LANCZOS).save(sys.argv[2],optimize=True)",str(OUT/'forge_gain_9slice.png'),str(OUT/'forge_gain_9slice_e.png')],check=True)
 margins={'left':28,'top':28,'right':28,'bottom':28}
 for name in ('forge_recipe_9slice','forge_gain_9slice'):
  data={'name':name,'size':[192,192],'frames':1,'passes':['diffuse'],'normal':'none: face-on UI','emission':name=='forge_gain_9slice','nine_slice':margins,'content_insets':margins}
  (OUT/(name+'.json')).write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
run()
