import bpy, math, os
from mathutils import Vector

ROOT=os.path.abspath(os.path.join(os.path.dirname(__file__),'../../..'))
OUT=os.path.join(ROOT,'game/assets/sprites/props/epreuve')
BLEND=os.path.join(ROOT,'art/blender/props/ep_b_chase_post.blend')
os.makedirs(OUT,exist_ok=True); os.makedirs(os.path.dirname(BLEND),exist_ok=True)
SKINS={'fog_forest':((.23,.20,.22,1),(.76,.294,1,1)), 'crypts':((.22,.24,.25,1),(.749,.957,1,1))}

def mat(name,color,emit=0):
 m=bpy.data.materials.new(name); m.diffuse_color=color; m.use_nodes=True
 n=m.node_tree.nodes; n.clear(); o=n.new('ShaderNodeOutputMaterial'); p=n.new('ShaderNodeBsdfPrincipled'); p.inputs['Base Color'].default_value=color; p.inputs['Roughness'].default_value=.86; p.inputs['Metallic'].default_value=.16
 if emit: p.inputs['Emission Color'].default_value=color; p.inputs['Emission Strength'].default_value=emit
 m.node_tree.links.new(p.outputs['BSDF'],o.inputs['Surface']); return m
def cube(name,loc,dim,ma,bevel=.035):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=dim; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(ma)
 if bevel: b=o.modifiers.new('worn edges','BEVEL'); b.width=bevel; b.segments=1; o.modifiers.new('weighted corners','WEIGHTED_NORMAL')
 return o
def ico(name,loc,scale,ma,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=bpy.context.object; o.name=name; o.scale=scale; o.data.materials.append(ma); return o
def clear():
 for o in list(bpy.context.scene.objects):
  if o.type=='MESH': bpy.data.objects.remove(o,do_unlink=True)
def build(skin,state):
 clear(); base,accent=SKINS[skin]; factor={'off':.25,'lit':3.2,'done':3.2,'altar':1.35}[state]; stone=mat('weathered stone',base); dark=mat('charcoal iron',(.075,.075,.085,1)); glow=mat('single skin accent',accent,factor); rune=mat('rune cuts',accent,factor*.72)
 altar=state=='altar'; k=1.4 if altar else 1.0
 cube('broad chipped foot',(0,0,.10*k),(.70*k,.52*k,.20*k),stone,.07)
 if state=='done':
  bpy.ops.mesh.primitive_torus_add(major_radius=.43,minor_radius=.025,major_segments=20,minor_segments=6,location=(0,0,.025)); bpy.context.object.name='completion ring'; bpy.context.object.data.materials.append(glow)
 if skin=='fog_forest':
  # stout stalk and angular lantern cap
  bpy.ops.mesh.primitive_cone_add(vertices=7,radius1=.14*k,radius2=.10*k,depth=.55*k,location=(0,0,.46*k)); bpy.context.object.name='mushroom stalk'; bpy.context.object.data.materials.append(stone)
  bpy.ops.mesh.primitive_cone_add(vertices=9,radius1=.44*k,radius2=.19*k,depth=.34*k,location=(0,0,.78*k)); bpy.context.object.name='lantern cap'; bpy.context.object.data.materials.append(stone)
  ico('mycelium lamp',(0,-.02,.70*k),(.28*k,.27*k,.13*k),glow,2)
  for a in range(5):
   t=a*math.tau/5; ico('mycelium node',(.34*k*math.cos(t),.34*k*math.sin(t),.67*k),(.045*k,.045*k,.045*k),rune)
 else:
  # dark plinth, tapered crystal prism
  cube('crystal socket',(0,0,.30*k),(.43*k,.38*k,.22*k),dark,.035)
  bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=.29*k,radius2=.035*k,depth=.93*k,location=(0,0,.83*k),rotation=(.08,.12,.1)); bpy.context.object.name='faceted crystal'; bpy.context.object.data.materials.append(glow)
 # common carved side runes; accent is limited to the skin color
 for side in (-1,1):
  x=side*.29*k
  for z in (.25,.39,.53): cube('rune stroke',(x,-.205*k,z*k),(.035*k,.018*k,.07*k),rune,.005)
 # altar has a visible larger rune crown
 if altar:
  for x in (-.22,.0,.22): ico('altar rune',(x*k,-.25*k,.36*k),(.045*k,.018*k,.045*k),glow)
def setup():
 s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=8; s.render.resolution_x=128; s.render.resolution_y=160; s.render.resolution_percentage=100
 s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True; s.view_settings.view_transform='Standard'; s.render.dither_intensity=0; s.render.resolution_percentage=100
 camd=bpy.data.cameras.new('iso ortho'); cam=bpy.data.objects.new('iso ortho',camd); s.collection.objects.link(cam); cam.location=(4,-6,4.5); target=Vector((0,0,.48)); cam.rotation_euler=(target-Vector(cam.location)).to_track_quat('-Z','Y').to_euler(); camd.type='ORTHO'; camd.ortho_scale=2.0; s.camera=cam
 l=bpy.data.lights.new('upper left','AREA'); lo=bpy.data.objects.new('upper left',l); s.collection.objects.link(lo); lo.location=(-3,-4,6); l.energy=420; l.size=3
 l=bpy.data.lights.new('cool fill','AREA'); lo=bpy.data.objects.new('cool fill',l); s.collection.objects.link(lo); lo.location=(3,2,4); l.energy=75; l.color=(.5,.7,1); l.size=4
 s.world.color=(.04,.04,.04)
def render_skin(skin):
 s=bpy.context.scene; accent=SKINS[skin][1]
 for state in ('off','lit','done','altar'):
  build(skin,state); name=f'chase_post_{skin}_{state}'; s.render.filepath=os.path.join(OUT,name+'.png'); bpy.ops.render.render(write_still=True)
  if state=='off': continue
  # Isolated white emission mask on transparent film.
  for o in bpy.context.scene.objects:
   if o.type=='MESH':
    for m in o.data.materials:
     if m and m.name in ('single skin accent','rune cuts'):
      for p in m.node_tree.nodes:
       if p.type=='BSDF_PRINCIPLED': p.inputs['Base Color'].default_value=(0,0,0,1); p.inputs['Emission Color'].default_value=(1,1,1,1)
  s.render.filepath=os.path.join(OUT,name+'_e.png'); bpy.ops.render.render(write_still=True)
  # Restore the original base colors after the emission-only pass.
  for m in bpy.data.materials:
   if m.name=='single skin accent': m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=accent
   elif m.name=='rune cuts': m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=accent
 clear(); sh=mat('soft charcoal shadow',(.012,.01,.016,1)); bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(0,0,.01)); o=bpy.context.object; o.name='shared soft shadow'; o.scale=(.61,.38,.025); o.data.materials.append(sh); s.render.filepath=os.path.join(OUT,f'chase_post_{skin}_shadow.png'); bpy.ops.render.render(write_still=True)

setup()
for skin in SKINS: render_skin(skin)
build('crypts','altar'); bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print('PASS EP-B: 8 diffuse, 6 emission, 2 shadows; 128x160')
