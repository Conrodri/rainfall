import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).parents[3]
OUT=ROOT/'art/renders/cosmetics/ciel'; OUT.mkdir(parents=True,exist_ok=True)
def lin(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def col(h): return tuple(lin(int(h[i:i+2],16)/255) for i in (1,3,5))
def mat(name,h):
 m=bpy.data.materials.new(name); m.diffuse_color=(*col(h),1); m.use_nodes=True; n=m.node_tree.nodes; n.clear(); e=n.new('ShaderNodeEmission'); e.inputs[0].default_value=(*col(h),1); o=n.new('ShaderNodeOutputMaterial'); m.node_tree.links.new(e.outputs[0],o.inputs['Surface']); return m
def setup(w,h):
 bpy.ops.wm.read_factory_settings(use_empty=True); s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'; s.eevee.taa_render_samples=16; s.render.resolution_x=w; s.render.resolution_y=h; s.render.resolution_percentage=100; s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.image_settings.color_depth='8'; s.render.film_transparent=False; s.render.dither_intensity=0; s.view_settings.view_transform='Standard'; s.view_settings.look='None'; s.view_settings.exposure=0; s.view_settings.gamma=1; return s
def poly(name,verts,m):
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],[tuple(range(len(verts)))]); me.materials.append(m); ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob); return ob
def disc(name,x,y,z,rx,ry,m): return poly(name,[(x+rx*math.cos(i*math.tau/64),y+ry*math.sin(i*math.tau/64),z) for i in range(64)],m)
def plane(name,x,y,z,w,h,m): return poly(name,[(x-w/2,y-h/2,z),(x+w/2,y-h/2,z),(x+w/2,y+h/2,z),(x-w/2,y+h/2,z)],m)
def gradient(name,top,bottom):
 m=mat(name,top); n=m.node_tree.nodes; l=m.node_tree.links; e=next(x for x in n if x.type=='EMISSION'); tc=n.new('ShaderNodeTexCoord'); sep=n.new('ShaderNodeSeparateXYZ'); r=n.new('ShaderNodeValToRGB'); r.color_ramp.elements[0].color=(*col(bottom),1); r.color_ramp.elements[1].color=(*col(top),1); l.new(tc.outputs['Generated'],sep.inputs[0]); l.new(sep.outputs['Y'],r.inputs[0]); l.new(r.outputs[0],e.inputs[0]); return m
def render(s,p): s.render.filepath=str(p); bpy.ops.render.render(write_still=True)
def haze(name,x,y,z,w,h):
 m=mat(name,'#F0C888'); m.surface_render_method='BLENDED'; n=m.node_tree.nodes; l=m.node_tree.links; e=next(v for v in n if v.type=='EMISSION'); out=next(v for v in n if v.type=='OUTPUT_MATERIAL'); tr=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader'); mix.inputs[0].default_value=.24; l.new(tr.outputs[0],mix.inputs[1]); l.new(e.outputs[0],mix.inputs[2]); l.new(mix.outputs[0],out.inputs[0]); plane(name,x,y,z,w,h,m); disc(name,x-w/2,y,z,h/2,h/2,m); disc(name,x+w/2,y,z,h/2,h/2,m)
s=setup(256,64); c=bpy.data.cameras.new('Square pixels'); cam=bpy.data.objects.new('Square pixels',c); bpy.context.collection.objects.link(cam); cam.location=(128,32,200); c.type='ORTHO'; c.ortho_scale=256; s.camera=cam
plane('Ocher gradient',128,32,0,260,64,gradient('Sky gradient','#B8742E','#E8B468'))
# Circle is 16 px across, with two exact cel rings.
disc('Sun outer ring',150,46,1,8,8,mat('Sun outer','#D9A050')); disc('Sun middle ring',150,46,2,6,6,mat('Sun middle','#F4D08A')); disc('Sun core',150,46,3,4,4,mat('Sun core','#FFF2C8'))
for x in (76,184):
 plane('Pale foundry smoke',x,39,2,4,22,mat('Faint smoke','#A8825A'))
for x,y,w,h in ((47,29,70,5),(196,22,54,4)): haze('Heat band',x,y,4,w,h)
for x,y,w,h in ((28,53,12,3),(62,49,10,2),(94,57,17,4),(127,52,13,3),(164,56,14,3),(197,50,9,2),(226,58,16,4)):
 for i in range(5,0,-1): disc('Water reflection',x,64-y,5+(5-i)*.001,w/2*i/5,h/2*i/5,mat('Reflection '+str(i),['#F6D08A','#F3C77C','#EFC16F','#E8B468','#D9A050'][i-1]))
render(s,ROOT/'game/assets/sprites/ambiance/sky_canicule_de_cendres_256x64.png')
def preview():
 sc=setup(256,256)
 def cube(name,loc,scale,h,bev=.02):
  bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.name=name; o.dimensions=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(mat(name+' material',h)); b=o.modifiers.new('Soft edges','BEVEL'); b.width=bev; b.segments=1; return o
 def dia(name,x,y,z,rx,ry,h): return poly(name,[(x,y-ry,z),(x+rx,y,z),(x,y+ry,z),(x-rx,y,z)],mat(name+' material',h))
 # Camera-facing full-frame warm sky and sun.
 target=Vector((0,0,.8)); cd=bpy.data.cameras.new('Preview iso 2:1'); camera=bpy.data.objects.new('Preview iso 2:1',cd); bpy.context.collection.objects.link(camera); camera.location=target+Vector((6,-6,math.sqrt(24))); camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler(); cd.type='ORTHO'; cd.ortho_scale=5.4; sc.camera=camera; R=camera.rotation_euler.to_matrix()@Vector((1,0,0)); U=camera.rotation_euler.to_matrix()@Vector((0,1,0)); T=camera.rotation_euler.to_matrix()@Vector((0,0,1))
 def billboard(o,px,py,d): o.rotation_euler=camera.rotation_euler; o.location=target+R*((px-128)*5.4/256)+U*((128-py)*5.4/256)+T*d
 bg=plane('Full frame ocher sky',0,0,0,5.6,5.6,gradient('Preview gradient','#B8742E','#E8B468')); billboard(bg,128,128,-8)
 sun=disc('Pale preview sun',0,0,0,.20,.20,mat('Pale sun','#FFF2C8')); billboard(sun,53,39,-7)
 # Layered concrete terraces and fractured slab marks.
 cube('Lower concrete', (0,0,.10),(3.6,2.8,.35),'#6A5C4C',.04); cube('Ocher concrete top',(0,0,.30),(3.52,2.72,.16),'#8A7A66',.04); cube('Raised concrete',(0,.75,.52),(2.6,.95,.32),'#6A5C4C',.04); cube('Raised slab',(0,.75,.70),(2.54,.90,.10),'#8A7A66',.03)
 for x,y in ((-.9,-.5),(.65,-.65),(-.35,.95)):
  crack=plane('Slab crack',x,y,.391,.34,.018,mat('Crack','#51483E')); crack.rotation_euler[2]=.55
 # Murky canal foreground.
 cube('Canal bank',(0,-.75,.42),(2.9,.68,.08),'#51483E',.02); cube('Turbid canal',(0,-.76,.47),(2.72,.55,.035),'#6A7A6A',.02)
 for i,(x,y,w) in enumerate(((-.7,-.72,.38),(-.05,-.79,.52),(.64,-.73,.34))): plane('Ocher sky reflection',x,y,.493,w,.035,mat('Water reflection '+str(i),'#D9A050'))
 # Rusted container, thin ink seams.
 cube('Rust container',(-.70,.32,.83),(.94,.62,.76),'#8A4A2A',.04)
 for x in (-1.13,-.27): cube('Container dark seam',(x,.00,.83),(.025,.025,.68),'#4A3028',.004)
 for i in range(4): cube('Container rib',(-1.0+i*.20,.00,.83),(.018,.018,.65),'#A15A32',.003)
 # Brick foundry stack with pale ash plume.
 cube('Foundry base',(.75,.42,.82),(.72,.55,.46),'#6A3A2A',.025); cube('Chimney',(.79,.57,1.25),(.27,.30,.62),'#6A3A2A',.02); cube('Chimney rim',(.79,.57,1.58),(.34,.36,.08),'#4F3028',.01)
 for z in (1.06,1.25,1.43): cube('Brick seam',(.79,.405,z),(.25,.012,.015),'#9A6042',.002)
 # Ash particles rising above the chimney.
 for i,(x,y,z) in enumerate(((.72,.60,1.83),(.82,.58,1.96),(.64,.61,2.08),(.90,.57,2.17),(.76,.60,2.29),(.98,.58,2.37))):
  d=disc('Ash flake',x,y,z,.035,.035,mat('Ash','#B8B0A0')); d.rotation_euler[0]=math.pi/2
 # Two translucent warm convection strokes.
 for i,(x,y) in enumerate(((-.15,1.22),(.10,1.00))):
  ob=plane('Heat shimmer',x,y,2.8,1.45,.055,mat('Heat','#F0C888')); ob.rotation_euler[0]=math.pi/2
 # Ortho camera; ambient top-left illumination from emissive cel palette.
 sc.render.filepath=str(ROOT/'game/assets/sprites/cosmetics/previews/canicule_de_cendres.png'); render(sc,sc.render.filepath)
 sc.render.use_file_extension=True; bpy.context.preferences.filepaths.save_version=0; bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/ciel_canicule_de_cendres.blend'))
preview()
# Periodic sine convection field, attenuated to a neutral seamless border.
t=setup(512,512); m=mat('Periodic heat haze','#808080'); n=m.node_tree.nodes; l=m.node_tree.links; e=next(v for v in n if v.type=='EMISSION'); tc=n.new('ShaderNodeTexCoord'); sep=n.new('ShaderNodeSeparateXYZ'); l.new(tc.outputs['Generated'],sep.inputs[0])
def mathnode(op,a=None,b=None):
 q=n.new('ShaderNodeMath'); q.operation=op
 if a is not None: l.new(a,q.inputs[0])
 if b is not None: l.new(b,q.inputs[1])
 return q.outputs[0]
def const(v): q=n.new('ShaderNodeValue'); q.outputs[0].default_value=v; return q.outputs[0]
x=sep.outputs['X']; y=sep.outputs['Y']; pi=const(math.tau)
def phase(coord,k): return mathnode('MULTIPLY',mathnode('MULTIPLY',coord,const(k)),pi)
u=mathnode('ADD',phase(y,4),mathnode('MULTIPLY',mathnode('SINE',phase(x,2)),const(.8)))
signal=mathnode('ADD',const(.22),mathnode('MULTIPLY',mathnode('SINE',mathnode('MULTIPLY',u,pi)),const(.10)))
signal=mathnode('ADD',signal,mathnode('MULTIPLY',mathnode('SINE',mathnode('ADD',phase(y,2),phase(x,3))),const(.03)))
signal=mathnode('ADD',signal,mathnode('MULTIPLY',mathnode('SINE',phase(x,3)),const(.03)))
envx=mathnode('POWER',mathnode('SINE',phase(x,.5)),const(6)); envy=mathnode('POWER',mathnode('SINE',phase(y,.5)),const(6)); env=mathnode('MULTIPLY',envx,envy)
val=mathnode('ADD',mathnode('MULTIPLY',signal,env),mathnode('MULTIPLY',const(.22),mathnode('SUBTRACT',const(1),env)))
edge=mathnode('MAXIMUM',mathnode('LESS_THAN',x,const(.002)),mathnode('GREATER_THAN',x,const(.998)))
edge=mathnode('MAXIMUM',edge,mathnode('LESS_THAN',y,const(.002))); edge=mathnode('MAXIMUM',edge,mathnode('GREATER_THAN',y,const(.998)))
val=mathnode('ADD',mathnode('MULTIPLY',val,mathnode('SUBTRACT',const(1),edge)),mathnode('MULTIPLY',const(.22),edge))
rgb=n.new('ShaderNodeCombineColor'); rgb.mode='RGB'
for socket in ('Red','Green','Blue'): l.new(val,rgb.inputs[socket])
l.new(rgb.outputs[0],e.inputs[0]); plane('Tile surface',.5,.5,0,1,1,m)
t.render.image_settings.color_mode='RGBA'; t.render.film_transparent=False; c=bpy.data.cameras.new('Tile camera'); o=bpy.data.objects.new('Tile camera',c); bpy.context.collection.objects.link(o); o.location=(.5,.5,2); c.type='ORTHO'; c.ortho_scale=1; t.camera=o; tilepath=ROOT/'game/assets/sprites/ambiance/heat_haze_tile_512.png'; render(t,tilepath)
# Equalize just the opposite border samples in Blender's pixel buffer.
img=bpy.data.images.load(str(tilepath),check_existing=False); px=list(img.pixels[:]); w=h=512
for y in range(h):
 a=(y*w)*4; b=(y*w+w-1)*4; v=(px[a]+px[b])*.5
 for c in range(3): px[a+c]=px[b+c]=v
 px[a+3]=px[b+3]=1
for x in range(w):
 a=x*4; b=((h-1)*w+x)*4; v=(px[a]+px[b])*.5
 for c in range(3): px[a+c]=px[b+c]=v
 px[a+3]=px[b+3]=1
img.pixels[:]=px; img.filepath_raw=str(tilepath); img.file_format='PNG'; img.save(); bpy.data.images.remove(img)
print('PASS sky preview tile blend',flush=True)
