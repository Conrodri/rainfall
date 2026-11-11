import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).parents[3]; O=ROOT/'art/renders/cosmetics/ciel'; O.mkdir(parents=True,exist_ok=True)
def col(h):
 s=h.lstrip('#'); return tuple((((int(s[i:i+2],16)/255)/12.92) if int(s[i:i+2],16)/255<=.04045 else (((int(s[i:i+2],16)/255+.055)/1.055)**2.4)) for i in (0,2,4))
def mat(name,h,emit=1,alpha=1):
 m=bpy.data.materials.new(name); m.diffuse_color=(*col(h),alpha); m.use_nodes=True; n=m.node_tree.nodes; n.clear(); e=n.new('ShaderNodeEmission'); e.inputs[0].default_value=(*col(h),1); e.inputs[1].default_value=emit; o=n.new('ShaderNodeOutputMaterial')
 if alpha<1: t=n.new('ShaderNodeBsdfTransparent'); q=n.new('ShaderNodeMixShader'); q.inputs[0].default_value=alpha; m.node_tree.links.new(t.outputs[0],q.inputs[1]); m.node_tree.links.new(e.outputs[0],q.inputs[2]); m.node_tree.links.new(q.outputs[0],o.inputs['Surface']); m.surface_render_method='BLENDED'
 else: m.node_tree.links.new(e.outputs[0],o.inputs['Surface']); return m
def setup(w,h):
 bpy.ops.wm.read_factory_settings(use_empty=True); s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=24; s.render.resolution_x=w;s.render.resolution_y=h;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG';s.render.image_settings.color_mode='RGBA';s.render.image_settings.color_depth='8';s.render.film_transparent=False;s.view_settings.view_transform='Standard';s.view_settings.look='None';s.view_settings.exposure=0;s.view_settings.gamma=1;s.world=bpy.data.worlds.new('Crypt depths');s.world.color=(.05,.14,.12);return s
def poly(name,v,ma):
 me=bpy.data.meshes.new(name);me.from_pydata(v,[],[tuple(range(len(v)))]);me.materials.append(ma);ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);return ob
def plane(name,x,y,z,w,h,ma):return poly(name,[(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)],ma)
def soft_beam(name,hue,maximum=.35,emit=1):
 m=mat(name,hue,emit,1);n=m.node_tree.nodes;l=m.node_tree.links;e=next(q for q in n if q.type=='EMISSION');out=next(q for q in n if q.type=='OUTPUT_MATERIAL');n.remove(e);t=n.new('ShaderNodeBsdfTransparent');e=n.new('ShaderNodeEmission');e.inputs[0].default_value=(*col(hue),1);e.inputs[1].default_value=emit;q=n.new('ShaderNodeMixShader');tc=n.new('ShaderNodeTexCoord');sp=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Generated'],sp.inputs[0]);rx=n.new('ShaderNodeValToRGB');rx.color_ramp.elements[0].position=0;rx.color_ramp.elements[0].color=(0,0,0,1);rx.color_ramp.elements[1].position=1;rx.color_ramp.elements[1].color=(0,0,0,1);rx.color_ramp.elements.new(.5).color=(1,1,1,1);l.new(sp.outputs['X'],rx.inputs[0]);ry=n.new('ShaderNodeValToRGB');ry.color_ramp.elements[0].position=0;ry.color_ramp.elements[0].color=(0,0,0,1);ry.color_ramp.elements[1].position=1;ry.color_ramp.elements[1].color=(1,1,1,1);l.new(sp.outputs['Y'],ry.inputs[0]);a=n.new('ShaderNodeMath');a.operation='MULTIPLY';l.new(rx.outputs[0],a.inputs[0]);l.new(ry.outputs[0],a.inputs[1]);b=n.new('ShaderNodeMath');b.operation='MULTIPLY';b.inputs[1].default_value=maximum;l.new(a.outputs[0],b.inputs[0]);l.new(b.outputs[0],q.inputs[0]);l.new(t.outputs[0],q.inputs[1]);l.new(e.outputs[0],q.inputs[2]);l.new(q.outputs[0],out.inputs['Surface']);m.surface_render_method='BLENDED';return m
def oval(name,x,y,z,rx,ry,ma):return poly(name,[(x+rx*math.cos(i*math.tau/48),y+ry*math.sin(i*math.tau/48),z) for i in range(48)],ma)
def gradient(name,top,bottom):
 m=mat(name,top);n=m.node_tree.nodes;l=m.node_tree.links;e=next(q for q in n if q.type=='EMISSION');tc=n.new('ShaderNodeTexCoord');sp=n.new('ShaderNodeSeparateXYZ');r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].color=(*col(bottom),1);r.color_ramp.elements[1].color=(*col(top),1);l.new(tc.outputs['Generated'],sp.inputs[0]);l.new(sp.outputs['Y'],r.inputs[0]);l.new(r.outputs[0],e.inputs[0]);return m
def render(s,p):s.render.filepath=str(p);bpy.ops.render.render(write_still=True)
s=setup(256,64);c=bpy.data.cameras.new('Square pixel camera');cam=bpy.data.objects.new('Square pixel camera',c);bpy.context.collection.objects.link(cam);cam.location=(128,32,200);c.type='ORTHO';c.ortho_scale=256;s.camera=cam
plane('Water gradient',128,32,0,260,64,gradient('Deep filtered water','#12433F','#3E8F7C'))
# Filleted diagonal light shafts, inset from tile edges.
for foot in (40,95,190,230):
 x=foot-16.5
 o=plane('Diagonal filtered shaft',x,32,2,14,64,soft_beam('Filtered light','#8FE0C0',.35));o.rotation_euler[2]=-.52
for x,y,w in [(34,50,13),(76,55,10),(119,49,17),(162,57,12),(207,52,16),(232,58,9)]:oval('Water reflection',x,y,4,w/2,1.4,mat('Pale reflection','#A8F0D0',.82))
for x,y in [(42,36),(88,42),(127,33),(184,39),(218,30)]:plane('Fine water ripple',x,y,3,18,.45,mat('Ripple','#2E7468'))
# Soft halo built with nested translucent emission discs.
oval('Glow outer ring',150,48,5,9,9,mat('Glow outer','#7ACDB0'))
oval('Glow middle ring',150,48,5.01,6,6,mat('Glow middle','#B8F0D0'))
oval('Glow core',150,48,5.02,3.5,3.5,mat('Glow core','#D8F8E8'))
render(s,O/'sky_maree_haute_256x64.png')
def preview():
 sc=setup(256,256)
 def cube(name,loc,scale,ma,bev=.025):
  bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(ma)
  if bev:b=o.modifiers.new('Soft stone edge','BEVEL');b.width=bev;b.segments=2
  return o
 stone=mat('Gray green stone','#5A6E68');edge=mat('Crypt stone','#3E504C');ink=mat('Stone seams','#263E3A');water=mat('High green water','#2E7A6A');pale=mat('Bubble light','#CFF5E6',1.6);beam=soft_beam('Filtered ray','#8FE0C0',.35,1.5)
 bg=plane('Full frame submerged gradient',0,0,-3,5.8,5.8,gradient('Crypt background','#12433F','#2E7A6A'))
 cube('Lower foundation',(0,-.4,.12),(3.55,2.2,.42),ink,.08);cube('Lower stone level',(0,-.37,.19),(3.45,2.12,.35),stone,.07);cube('Upper foundation',(-.15,.67,.48),(2.85,1.0,.37),ink,.06);cube('Upper stone level',(-.15,.69,.54),(2.76,.93,.31),stone,.05)
 # Thick arched masonry: two uprights, lintel, and curved crown segments.
 for x in (-.68,.68):cube('Arch pier',(x,.05,.84),(.22,.94,.28),edge,.025)
 cube('Arch crown',(0,.49,.84),(1.58,.22,.28),edge,.03)
 for x in (-.55,-.28,0,.28,.55):cube('Arch crown stone',(x,.55,.86),(.29,.22,.29),stone,.045)
 # Upper water surface obscures lower terrace.
 cube('Submerged lower half',(.0,-.72,.43),(3.05,1.05,.04),water,.01)
 for x,y,w in [(-.95,-.69,.42),(-.38,-.83,.34),(.34,-.67,.48),(.9,-.83,.38)]:plane('Water glint',x,y,.47,w,.035,mat('Water highlight','#A8F0D0',1.4))
 # Unlit candle on the exposed platform.
 cube('Unlit candle base',(.98,.68,.84),(.20,.20,.12),edge,.025);cube('Unlit wax',(.98,.68,1.08),(.11,.11,.39),mat('Unlit wax','#B7C2B5'),.025);cube('Candle wick',(.98,.68,1.29),(.018,.018,.07),ink,.004)
 camd=bpy.data.cameras.new('Preview iso 2:1');camera=bpy.data.objects.new('Preview iso 2:1',camd);bpy.context.collection.objects.link(camera);target=Vector((0,0,.78));camera.location=target+Vector((6,-6,math.sqrt(24)));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler();camd.type='ORTHO';camd.ortho_scale=4.5;sc.camera=camera
 right=camera.rotation_euler.to_matrix()@Vector((1,0,0));up=camera.rotation_euler.to_matrix()@Vector((0,1,0));toward=camera.rotation_euler.to_matrix()@Vector((0,0,1))
 def billboard(ob,px,py,depth):ob.rotation_euler=camera.rotation_euler;ob.location=target+right*((px-128)*5.3/256)+up*((128-py)*5.3/256)+toward*depth
 billboard(bg,128,128,-7)
 for x,y,w in [(38,68,.052),(66,111,.036),(92,56,.044),(126,89,.055),(153,50,.038),(181,123,.048),(207,82,.035),(230,104,.043)]:billboard(oval('Rising pale bubble',0,0,0,w,w,pale),x,y,3.5)
 for x,y,w,h in [(77,127,.17,1.25),(128,119,.15,1.18),(179,132,.18,1.3)]:
  o=plane('Filtered diagonal ray',0,0,0,w,h,beam);o.rotation_euler=camera.rotation_euler;billboard(o,x,y,5);o.rotation_euler.rotate_axis('Z',-.5)
 sc.render.filepath=str(ROOT/'game/assets/sprites/cosmetics/previews/maree_haute.png');render(sc,Path(sc.render.filepath));sc.render.use_file_extension=True;bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/ciel_maree_haute.blend'))
 dest=ROOT/'game/assets/sprites/ambiance/sky_maree_haute_256x64.png';dest.parent.mkdir(parents=True,exist_ok=True);import shutil;shutil.copyfile(O/'sky_maree_haute_256x64.png',dest)
preview();print('PASS maree_haute sky / preview / blend',flush=True)


