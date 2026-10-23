"""Blender background terrain generator. Patterns and normals are Blender shaders."""
import bpy, math, argparse, sys, random
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[3]
COLORS={"terraces":["4A5B50","505D60","4A5552","526252","1F3139","54707A","2F3A3C"],
"fog_forest":["48564E","4B555B","454D49","4E5B50","202D32","4C636A","303A39"],
"rust_city":["50594F","555C60","534F49","545D50","273238","56676B","383D40"]}
NAMES=["ground_moss","ground_stone","ground_mud","ground_grass","water_deep","water_shallow","cliff_edge"]
def material(name,color):
 m=bpy.data.materials.new(name); m.use_nodes=True
 ns=m.node_tree.nodes; ns.clear(); ls=m.node_tree.links
 def node(t): return ns.new(t)
 def op(t,a,b=0):
  n=node("ShaderNodeMath"); n.operation=t
  for i,v in enumerate((a,b)):
   if isinstance(v,(int,float)): n.inputs[i].default_value=v
   else: ls.new(v,n.inputs[i])
  return n.outputs[0]
 tc=node("ShaderNodeTexCoord"); tc.object=bpy.data.objects["pattern_origin"]
 sep=node("ShaderNodeSeparateXYZ"); ls.new(tc.outputs["Object"],sep.inputs[0])
 x,y=sep.outputs["X"],sep.outputs["Y"]
 a=op("SINE",op("MULTIPLY",x,math.tau/8))
 b=op("COSINE",op("MULTIPLY",y,math.tau*2/8))
 c=op("SINE",op("ADD",op("MULTIPLY",x,math.tau*3/8),b))
 d=op("COSINE",op("ADD",op("MULTIPLY",y,math.tau*(5 if "water" in name else 3)/8),a))
 h=op("ADD",op("MULTIPLY",c,.55),op("MULTIPLY",d,.45))
 ramp=node("ShaderNodeValToRGB"); ls.new(op("ADD",op("MULTIPLY",h,.5),.5),ramp.inputs[0])
 rgb=[int(color[i:i+2],16)/255 for i in (0,2,4)]
 rgb=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 for e,f in zip(ramp.color_ramp.elements,(.82,1.16)): e.color=tuple(v*f for v in rgb)+(1,)
 em=node("ShaderNodeEmission"); ls.new(ramp.outputs[0],em.inputs[0])
 out=node("ShaderNodeOutputMaterial"); ls.new(em.outputs[0],out.inputs["Surface"])
 bump=node("ShaderNodeBump"); bump.inputs["Strength"].default_value=.35; bump.inputs["Distance"].default_value=.10
 ls.new(h,bump.inputs["Height"])
 vt=node("ShaderNodeVectorTransform"); vt.vector_type="NORMAL"; vt.convert_from="WORLD"; vt.convert_to="CAMERA"
 ls.new(bump.outputs["Normal"],vt.inputs[0])
 mul=node("ShaderNodeVectorMath"); mul.operation="MULTIPLY"; mul.inputs[1].default_value=(.5,.5,-.5); ls.new(vt.outputs[0],mul.inputs[0])
 add=node("ShaderNodeVectorMath"); add.operation="ADD"; add.inputs[1].default_value=(.5,.5,.5); ls.new(mul.outputs[0],add.inputs[0])
 normal=node("ShaderNodeEmission"); normal.name="normal_output"; ls.new(add.outputs[0],normal.inputs[0])
 return m
def plane(name,verts,faces,mat):
 me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
 ob=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(ob); me.materials.append(mat)
def run():
 p=argparse.ArgumentParser(); p.add_argument("--biome",choices=COLORS,default="terraces")
 a=p.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
 raw=ROOT/"art/renders/terrain"/a.biome; raw.mkdir(parents=True,exist_ok=True)
 for index,(name,color) in enumerate(zip(NAMES,COLORS[a.biome])):
  if index==0:
   bpy.ops.object.select_all(action="SELECT"); bpy.ops.object.delete(use_global=False)
   s=bpy.context.scene; s.name=name
  else:
   s=bpy.data.scenes.new(name); bpy.context.window.scene=s
  s.render.engine="BLENDER_EEVEE"; s.render.resolution_x=512; s.render.resolution_y=512; s.render.resolution_percentage=100
  s.render.image_settings.file_format="PNG"; s.render.image_settings.color_mode="RGBA"; s.render.film_transparent=True
  s.view_settings.view_transform="Standard"; s.view_settings.look="None"
  bpy.ops.object.empty_add(); origin=bpy.context.object; origin.name="pattern_origin"
  # Use explicit object reference so each saved scene retains its own origin.
  mat=material(name,color)
  for n in mat.node_tree.nodes:
   if n.type=="TEX_COORD": n.object=origin
  if name=="cliff_edge":
   rows=[(-16,-.9),(-1.4,-.9),(-.8,-.85),(-.3,.7),(0,.9),(16,.9)]
   verts=[(-4+i/8,y,z+.04*math.sin(math.tau*(-4+i/8)/8)*(abs(y)<2)) for y,z in rows for i in range(65)]
   faces=[(j*65+i,j*65+i+1,(j+1)*65+i+1,(j+1)*65+i) for j in range(5) for i in range(64)]
   plane(name,verts,faces,mat)
   cliff=bpy.data.objects[name]
   for label,tint in (("face","263234"),("rim","657772"),("foot","3A4748")):
    layer=material("cliff_"+label,tint)
    for n in layer.node_tree.nodes:
     if n.type=="TEX_COORD": n.object=origin
    cliff.data.materials.append(layer)
   for polygon in cliff.data.polygons:
    row=polygon.index//64
    polygon.material_index=1 if row==2 else (2 if row==3 else (3 if row==1 else 0))
  else: plane(name,[(-12,-12,0),(12,-12,0),(12,12,0),(-12,12,0)],[(0,1,2,3)],mat)
  if name in ("ground_moss","ground_stone","ground_grass"):
   rng=random.Random(37)
   rock=material(name+"_stones","566464" if name=="ground_stone" else "536156")
   for n in rock.node_tree.nodes:
    if n.type=="TEX_COORD": n.object=origin
   for i in range(16 if name=="ground_stone" else 7):
    x,y=rng.uniform(-4,4),rng.uniform(-4,4); r=rng.uniform(.22,.52)
    for dx in (-8,0,8):
     for dy in (-8,0,8):
      bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,location=(x+dx,y+dy,-.09))
      ob=bpy.context.object; ob.scale=(r,r*.7,.14); ob.data.materials.append(rock)
      for f in ob.data.polygons: f.use_smooth=True
  bpy.ops.object.camera_add(location=(0,-9,13) if name=="cliff_edge" else (0,0,16))
  cam=bpy.context.object; cam.data.type="ORTHO"; cam.data.ortho_scale=8
  if name=="cliff_edge": cam.rotation_euler=(Vector((0,0,0))-cam.location).to_track_quat("-Z","Y").to_euler()
  s.camera=cam
  s.render.filepath=str(raw/(name+".png")); bpy.ops.render.render(write_still=True)
  switched=[]
  for ob in s.objects:
   if ob.type!="MESH": continue
   for m in ob.data.materials:
    if m in [entry[0] for entry in switched]: continue
    out=next(n for n in m.node_tree.nodes if n.type=="OUTPUT_MATERIAL")
    switched.append((m,out,out.inputs["Surface"].links[0].from_socket))
    m.node_tree.links.new(m.node_tree.nodes["normal_output"].outputs[0],out.inputs["Surface"])
  s.view_settings.view_transform="Raw"; s.render.filepath=str(raw/(name+"_n.png")); bpy.ops.render.render(write_still=True)
  for m,out,prev in switched: m.node_tree.links.new(prev,out.inputs["Surface"])
  s.view_settings.view_transform="Standard"
 dest=ROOT/"art/blender/terrain"/("ground_"+a.biome+".blend"); dest.parent.mkdir(parents=True,exist_ok=True)
 bpy.context.preferences.filepaths.save_version=0; bpy.ops.wm.save_as_mainfile(filepath=str(dest))
if __name__=="__main__": run()


