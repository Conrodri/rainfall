import bpy, math, sys
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent/"_deps"))
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[3]
OUT=ROOT/"game/assets/sprites/projectiles/phoenix_bolt"; OUT.mkdir(parents=True,exist_ok=True)
TMP=ROOT/"art/tools/iso/_phoenix_tmp"; TMP.mkdir(exist_ok=True)
sys.path.insert(0,str(ROOT/"art/tools/iso")); import iso_rig
s=iso_rig.create_rig("CREA",(96,64)); s.render.resolution_x=96; s.render.resolution_y=64; s.render.resolution_percentage=100; s.eevee.taa_render_samples=8; s.render.image_settings.file_format="PNG"; s.render.image_settings.color_mode="RGBA"; s.render.film_transparent=True; s.render.image_settings.color_depth="8"; s.view_settings.view_transform="Standard"; s.render.image_settings.compression=20
cam=s.camera; R=64*math.sqrt(2); ppu=96/s.camera.data.ortho_scale; right=cam.rotation_euler.to_matrix()@Vector((1,0,0)); up=cam.rotation_euler.to_matrix()@Vector((0,1,0)); center=Vector((0,0,0))
def mat(name,c):
 m=bpy.data.materials.new(name); m.diffuse_color=(*c,1); m.use_nodes=True; n=m.node_tree.nodes; n.clear(); e=n.new("ShaderNodeEmission"); e.inputs[0].default_value=(*c,1); o=n.new("ShaderNodeOutputMaterial"); m.node_tree.links.new(e.outputs[0],o.inputs["Surface"]); return m
coal=mat("Phoenix deep ember",(.105,.035,.018)); red=mat("Phoenix mantle",(.34,.075,.018)); orange=mat("Phoenix fire",(1,.24,.035)); gold=mat("Phoenix gold",(1,.53,.12)); white=mat("Phoenix white hot",(1,.88,.62)); embers=mat("Phoenix trail",(.48,.09,.018))
def poly(name,pts,m,z=0):
 coords=[center+right*(x/ppu)+up*(y/ppu)+cam.rotation_euler.to_matrix()@Vector((0,0,z/ppu)) for x,y in pts]; mesh=bpy.data.meshes.new(name); mesh.from_pydata(coords,[],[list(range(len(coords)))]); mesh.materials.append(m); ob=bpy.data.objects.new(name,mesh); s.collection.objects.link(ob); return ob
# flat screen-space mesh planes; form varies each frame to animate folded V wings/trails
for f in range(6):
 for ob in list(s.objects):
  if ob.type=="MESH": bpy.data.objects.remove(ob,do_unlink=True)
 phase=math.sin(f*math.tau/6); flap=phase*3
 # tapered tail and three separated wavering flame streamers trail to screen-left
 poly("tail plume",[(-37,0),(-27,-5),(-14,-3),(-8,0),(-18,3),(-30,4)],red,-.03)
 for k in range(3):
  yy=(k-1)*4; bend=math.sin(f*math.tau/6+k*1.8)*2
  poly("waving trail",[(-44,yy+bend),(-31,yy-1),(-22,yy),(-29,yy+1),(-41,yy+2)],embers,-.02)
 # two angular folded wings swept backward, gentle six-frame beat
 poly("far wing",[(-9,1),(-23,12+flap),(-12,9+flap),(-3,4)],red,.01)
 poly("far wing fire",[(-8,2),(-19,10+flap),(-10,7+flap),(-2,4)],orange,.02)
 poly("near wing",[(-8,-1),(-24,-12-flap),(-12,-8-flap),(-2,-4)],red,.03)
 poly("near wing fire",[(-7,-2),(-19,-9-flap),(-10,-6-flap),(-1,-4)],orange,.04)
 # streamlined body, incandescent heart, raised neck and sharp beak pointing +X
 poly("body shadow",[(-20,-2),(-12,-5),(1,-4),(12,-1),(18,1),(7,3),(-8,3)],coal,.08)
 poly("body flame",[(-17,-1),(-11,-3),(1,-2),(11,0),(16,1),(5,2),(-8,2)],orange,.09)
 poly("breast",[(-2,-2),(4,-2),(12,0),(6,1),(0,1)],gold,.10)
 poly("neck and head",[(6,-1),(10,0),(14,3),(20,3),(16,5),(10,4),(7,2)],gold,.12)
 poly("white hot beak",[(15,3),(24,4),(17,5)],white,.13)
 poly("eye glint",[(12,3),(14,3),(13,4)],white,.14)
 # sparse trailing sparks
 for k,(x,y) in enumerate([(-35,8),(-29,-9),(-40,-4)]):
  drift=math.sin(f*math.tau/6+k)*1.3; poly("ember",[(x+drift,y),(x+drift+2,y+1),(x+drift,y+2)],gold,-.01)
 # render diffuse then emission-only matte (core/head/wings and hot trail)
 s.render.filepath=str(TMP/f"f{f}.png"); bpy.ops.render.render(write_still=True)
 # mask from selected glowing objects based on material name; opaque grayscale RGB with alpha from rendered object alpha
 diffuse=Image.open(TMP/f"f{f}.png").convert("RGBA")
 # temporarily hide every mesh except orange/gold/white-bearing objects, render matte white
 hidden=[]
 for ob in s.objects:
  if ob.type=="MESH":
   emit=any(m.name.startswith(("Phoenix fire","Phoenix gold","Phoenix white hot")) for m in ob.data.materials); hidden.append((ob,ob.hide_render)); ob.hide_render=not emit
 s.render.filepath=str(TMP/f"e{f}.png"); bpy.ops.render.render(write_still=True); matte=Image.open(TMP/f"e{f}.png").convert("RGBA")
 for ob,h in hidden: ob.hide_render=h
 diffuse.save(TMP/f"d{f}.png",optimize=True); matte.save(TMP/f"m{f}.png",optimize=True)
# native atlas; emission reduced directly while combining, with nearest 50% pixel sampling
atlas=Image.new("RGBA",(576,64),(0,0,0,0)); em=Image.new("RGBA",(288,32),(0,0,0,0))
for f in range(6):
 atlas.alpha_composite(Image.open(TMP/f"d{f}.png").convert("RGBA"),(96*f,0)); em.alpha_composite(Image.open(TMP/f"m{f}.png").convert("RGBA").resize((48,32),Image.Resampling.BOX),(48*f,0))
atlas.save(OUT/"default.png",optimize=True); em.save(OUT/"default_e.png",optimize=True)
# SpriteFrames atlas contract
rows=["[gd_resource type=\"SpriteFrames\" load_steps=8 format=3]","","[ext_resource type=\"Texture2D\" path=\"res://assets/sprites/projectiles/phoenix_bolt/default.png\" id=\"1\"]",""]
for i in range(6): rows += [f"[sub_resource type=\"AtlasTexture\" id=\"a{i+1}\"]",'atlas = ExtResource(\"1\")',f"region = Rect2({i*96}, 0, 96, 64)",""]
rows += ["[resource]",'animations = [{','\"frames\": ['+', '.join('{\"duration\": 1.0, \"texture\": SubResource(\"a%d\")} '%(i+1) for i in range(6))+'],','\"loop\": true,','\"name\": &\"default\",','\"speed\": 12.0','}]']
(OUT/"phoenix_bolt.tres").write_text("\n".join(rows)+"\n",encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/"art/blender/vfx/phoenix_bolt.blend"))
# <=1024 contact sheet with native six frames and directional labels (rotated copies)
contact=Image.new("RGBA",(768,210),(20,24,29,255)); d=ImageDraw.Draw(contact)
for f in range(6):
 im=atlas.crop((f*96,0,(f+1)*96,64)); contact.alpha_composite(im,(f*96,8))
for x,angle,label in [(150,90,"up"),(420,-90,"down")]:
 im=atlas.crop((0,0,96,64)).rotate(angle,expand=True); contact.alpha_composite(im,(x,100)); d.text((x+42,178),label,fill=(230,230,230,255))
contact.convert("RGB").save(ROOT/"art/tools/iso/_phoenix_bolt_contact.png",optimize=True)
print("PHOENIX BUILD PASS")
