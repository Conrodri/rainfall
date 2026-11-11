import bpy, math, json
import sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/'game/assets/sprites/ui'
RENDER=ROOT/'art/renders/ui_wave'
def mat(name,color,metal=0,emit=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.66
 if emit:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emit
 return m
def setup(w,h,scale):
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE';s.eevee.taa_render_samples=16;s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.film_transparent=True;s.view_settings.view_transform='Standard';s.view_settings.look='None'
 bpy.ops.object.camera_add(location=(0,-8,0));c=bpy.context.object;c.data.type='ORTHO';c.data.ortho_scale=scale;c.rotation_euler=(math.pi/2,0,0);s.camera=c
 bpy.ops.object.light_add(type='AREA',location=(-4,-5,6));bpy.context.object.data.energy=700;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=6
 bpy.ops.object.light_add(type='AREA',location=(4,-3,2));bpy.context.object.data.energy=180
def box(name,loc,scale,material,bevel=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);b=o.modifiers.new('Worn bevel','BEVEL');b.width=bevel;b.segments=2;o.modifiers.new('Normals','WEIGHTED_NORMAL');o.data.materials.append(material);return o
def render(path):
 bpy.context.scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
def bar(name,a,b,material,width,depth,y=-.12,bevel=.04):
 dx=b[0]-a[0];dz=b[1]-a[1];length=math.hypot(dx,dz);ang=math.atan2(dz,dx)
 o=box(name,((a[0]+b[0])/2,y,(a[1]+b[1])/2),(length,depth,width),material,bevel);o.rotation_euler[1]=-ang
 return o
def arrow_only():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 setup(96,64,3.0)
 dark=mat('Worn iron',(.055,.065,.08),.8);edge=mat('Edge steel',(.3,.33,.38),.72)
 black=mat('Outline',(.006,.008,.012),.2);ember=mat('Left ember',(.32,.035,.018),.2,.3);hot=mat('Right ember',(1,.09,.035),.2,1.1)
 for k,glow in enumerate((ember,hot)):
  x=-.15+.9*k;top=(-1.05+.9*k,.78);tip=(x,0);bottom=(-1.05+.9*k,-.78)
  for a,b in ((top,tip),(tip,bottom)):
   # broad dark silhouette, inset iron face, then a fine warm upper edge
   bar('Black contour',a,b,black,.54,.32,-.02,.10)
   bar('Bevelled iron',a,b,dark,.42,.30,-.205,.075)
   # narrow lit line on the upper-facing side of each stroke
   dx=b[0]-a[0];dz=b[1]-a[1];length=math.hypot(dx,dz)
   nx=-dz/length; nz=dx/length
   p=(a[0]+nx*.15,a[1]+nz*.15);q=(b[0]+nx*.15,b[1]+nz*.15)
   bar('Emissive edge',p,q,glow,.055,.035,-.37,.018)
  bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=.23,location=(x,-.22,0))
  joint=bpy.context.object;joint.name='Rounded joint';joint.scale=(.9,.55,.9);joint.data.materials.append(dark)
 render(RENDER/'wave_arrow.png')
def build():
 OUT.mkdir(parents=True,exist_ok=True);RENDER.mkdir(parents=True,exist_ok=True)
 if '--arrow-only' in sys.argv:
  OUT.mkdir(parents=True,exist_ok=True);RENDER.mkdir(parents=True,exist_ok=True);arrow_only();print('PASS arrow');return
 dark=mat('Worn iron',(.055,.065,.08),.8);edge=mat('Edge steel',(.3,.33,.38),.72);red=mat('Hot ember',(.85,.09,.025),.2,1.6);black=mat('Outline',(.012,.016,.021),.25)
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 setup(96,64,2.6)
 # paired right-facing chevrons, layered for dark outline and bevel extrusion
 for z,sz in [(.48,.60),(-.48,.60)]:
  pts=[(-.72,z+sz/2),(-.25,z+sz/2),(.45,z),(-.25,z-sz/2),(-.72,z-sz/2),(-.05,z)]
  # bars as beveled dark metal strips, local XZ, slight depth
  for a,b in [(pts[0],pts[1]),(pts[1],pts[2]),(pts[2],pts[3]),(pts[3],pts[4]),(pts[4],pts[5])]:
   dx=b[0]-a[0];dz=b[1]-a[1];length=math.hypot(dx,dz);ang=math.atan2(dz,dx)
   box('Chevron',((a[0]+b[0])/2,0,(a[1]+b[1])/2),(length,.18,.18),black,.045).rotation_euler[1]=-ang
   box('Iron face',((a[0]+b[0])/2,-.12,(a[1]+b[1])/2),(length,.11,.11),dark,.025).rotation_euler[1]=-ang
   box('Ember edge',((a[0]+b[0])/2,-.19,(a[1]+b[1])/2),(length*.92,.025,.022),red,.008).rotation_euler[1]=-ang
 render(RENDER/'wave_arrow.png')
 # panel smooth slab; restrained corner-only rivets, uniform stretchable bands
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 setup(128,128,3.2)
 box('Panel', (0,0,0),(3.2,.25,3.2),mat('Charcoal enamel',(.025,.03,.04),.0),.15)
 # four corner rivets
 for x in (-1.42,1.42):
  for z in (-1.42,1.42):
   bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.07,location=(x,-.23,z));bpy.context.object.data.materials.append(edge)
 render(OUT/'menu'/'panel_dark_9slice.png')
 (OUT/'menu').mkdir(parents=True,exist_ok=True)
 (OUT/'menu'/'panel_dark_9slice.json').write_text(json.dumps({'panel_dark_9slice':{'size':[128,128],'margin_left':32,'margin_top':32,'margin_right':32,'margin_bottom':32}},indent=2)+'\n')
 print('PASS rendered')
if __name__=='__main__':build()
