import bpy, math
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/ui/da'; CUE=ROOT/'game/assets/sprites/ui/cues/cue_epreuve.png'
RAW=ROOT/'art/renders/ui/ux_c'; OUT.mkdir(parents=True,exist_ok=True); RAW.mkdir(parents=True,exist_ok=True)

def material(name,color,emission=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 n=m.node_tree.nodes; n.clear(); o=n.new('ShaderNodeOutputMaterial'); e=n.new('ShaderNodeEmission'); e.inputs[0].default_value=(*color,1); e.inputs[1].default_value=1+emission; m.node_tree.links.new(e.outputs[0],o.inputs['Surface']); return m
INK=material('Ink',(0.035,0.04,0.045)); MET=material('Metal',(0.28,0.34,0.35)); GOLD=material('Gold',(0.66,0.39,0.08)); GLOW=material('Accent',(1,.33,.035),1.4)
def poly(name,pts,y,ma):
 me=bpy.data.meshes.new(name); me.from_pydata([(x,y,z) for x,z in pts],[],[tuple(range(len(pts)))]); me.materials.append(ma); ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob)
def circle(name,x,z,r,y,ma,n=32): poly(name,[(x+math.cos(i*2*math.pi/n)*r,z+math.sin(i*2*math.pi/n)*r) for i in range(n)],y,ma)
def reset(size):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=8; s.render.resolution_x=s.render.resolution_y=size; s.render.resolution_percentage=100; s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True; s.view_settings.view_transform='Standard'; s.view_settings.look='None'; s.render.image_settings.color_depth='8'
 bpy.ops.object.camera_add(location=(0,-10,0)); c=bpy.context.object; c.data.type='ORTHO'; c.data.ortho_scale=2.35; c.rotation_euler=(math.pi/2,0,0); s.camera=c; return s
def save(name,size):
 s=bpy.context.scene; s.render.filepath=str(RAW/(name+'.png')); bpy.ops.render.render(write_still=True)
 # Final downsample and RGBA optimization only.
 import subprocess
 subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-c',"from PIL import Image; import sys; p=sys.argv[1]; im=Image.open(p).convert('RGBA').resize((int(sys.argv[2]),)*2,Image.Resampling.LANCZOS); im.save(sys.argv[3],optimize=True,compress_level=9)",str(RAW/(name+'.png')),str(size),str(OUT/(name+'.png'))],check=True)

icons=['escorte','rituel','poursuite','veine','tenue']
for kind in icons:
 s=reset(64); bpy.context.scene.camera.data.ortho_scale=1.25
 if kind=='escorte':
  poly('coque',[(-.72,-.48),(-.5,.35),(0,.62),(.5,.35),(.72,-.48),(0,-.27)],0,INK); poly('bord',[(-.56,-.36),(-.38,.28),(0,.48),(.38,.28),(.56,-.36),(0,-.18)],-.02,MET); poly('banc',[(-.32,.02),(.32,.02),(.32,.14),(-.32,.14)],-.05,GOLD)
 elif kind=='rituel':
  circle('anneau',0,0,.56,0,INK); circle('anneau intérieur',0,0,.38,-.02,MET)
  for a in (90,210,330):
   x,z=.48*math.cos(math.radians(a)),.48*math.sin(math.radians(a)); circle('plot',x,z,.14,-.05,INK); circle('plot lumière',x,z,.075,-.07,GOLD)
 elif kind=='poursuite':
  poly('flamme',[(.42,-.62),(.03,-.52),(-.14,-.2),(-.31,.02),(-.43,.37),(-.2,.29),(-.05,.64),(.13,.32),(.31,.12)],0,INK); poly('feu',[(.25,-.42),(-.02,-.30),(-.18,-.02),(-.19,.22),(-.03,.35),(.11,.10)],-.03,GOLD)
 elif kind=='veine':
  poly('cristal',[(-.48,-.5),(-.55,.05),(-.2,.56),(.25,.58),(.56,.02),(.34,-.5)],0,INK); poly('facette',[(-.34,-.34),(-.4,.06),(-.14,.39),(.16,.4),(.4,.02),(.24,-.34)],-.03,MET); poly('filon',[(-.28,-.29),(-.06,-.05),(.02,.14),(.29,.35),(.2,.43),(-.1,.17),(-.22,-.03)],-.06,GOLD)
 else:
  poly('cloche',[(-.52,-.35),(-.38,-.17),(-.32,.24),(-.18,.42),(0,.5),(.18,.42),(.32,.24),(.38,-.17),(.52,-.35)],0,INK); poly('cloche métal',[(-.37,-.26),(-.27,-.13),(-.22,.22),(-.1,.34),(0,.38),(.1,.34),(.22,.22),(.27,-.13),(.37,-.26)],-.03,MET); circle('battant',0,-.49,.11,-.05,GOLD)
 save('minimap_epreuve_'+kind,64)

for grade,points,base in [('parfait',3,GOLD),('bien',2,material('Patina',(.22,.45,.34))),('fait',0,MET)]:
 s=reset(128); bpy.context.scene.camera.data.ortho_scale=1.66; pts=[]
 if points==3:
  for i in range(12):
   a=math.pi/2+i*math.pi/6; r=.82 if i in (0,4,8) else (.69 if i%2==0 else .61); pts.append((r*math.cos(a),r*math.sin(a)))
 elif points==2:
  pts=[(-.78,.48),(-.62,.78),(-.36,.52),(0,.38),(.36,.52),(.62,.78),(.78,.48),(.53,.12),(.58,-.34),(.3,-.68),(0,-.82),(-.3,-.68),(-.58,-.34),(-.53,.12)]
 else: pts=[(.80*math.cos(2*math.pi*i/48),.80*math.sin(2*math.pi*i/48)) for i in range(48)]
 poly('médaillon',pts,0,INK); inner=[(x*.83,z*.83) for x,z in pts]; poly('face',inner,-.04,base)
 circle('noyau',0,0,.19,-.08,INK); circle('noyau métal',0,0,.105,-.1,base)
 if grade=='parfait':
  for a in (90,210,330):
   x,z=.67*math.cos(math.radians(a)),.67*math.sin(math.radians(a)); circle('accent pointe',x,z,.085,-.13,GLOW,12)
  circle('accent centre',0,0,.13,-.13,GLOW,16)
 save('epreuve_grade_'+grade,128)
 if grade=='parfait':
  # Separate emissive mask from the same accent geometry, transparent elsewhere.
  import subprocess
  subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-c',"from PIL import Image,ImageDraw; import sys,math; im=Image.new('RGBA',(64,64),(0,0,0,0)); d=ImageDraw.Draw(im); d.ellipse((28,28,36,36),fill=(255,170,30,255));\nfor a in (90,210,330):\n x=32+26*math.cos(math.radians(a)); y=32-26*math.sin(math.radians(a)); d.ellipse((int(x-4),int(y-4),int(x+4),int(y+4)),fill=(255,170,30,255))\nim.save(sys.argv[1],optimize=True,compress_level=9)",str(OUT/'epreuve_grade_parfait_e.png')],check=True)

s=reset(96); bpy.context.scene.camera.data.ortho_scale=2.02
for x in (-.19,.23):
 p=[(x-.18,-.63),(x+.02,-.63),(x+.43,0),(x+.02,.63),(x-.18,.63),(x+.22,0)]
 poly('contour',p,0,INK); poly('chevron',[(a*.84,b*.84) for a,b in p],-.03,material('Pale',(.82,.82,.8)))
target=ROOT/'game/assets/sprites/ui/cues/cue_epreuve.png'; s.render.filepath=str(RAW/'cue_epreuve.png'); bpy.ops.render.render(write_still=True)
import subprocess
subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-c',"from PIL import Image; import sys; im=Image.open(sys.argv[1]).convert('RGBA').resize((96,96),Image.Resampling.LANCZOS); im.save(sys.argv[2],optimize=True,compress_level=9)",str(RAW/'cue_epreuve.png'),str(target)],check=True)
print('UX_C_OK 10 assets')
