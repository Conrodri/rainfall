"""Build the Esquive: fumee dodge trail and preview."""
import math, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/vfx')); sys.path.insert(0,str(ROOT/'art/tools/cel'))
import bpy, vfx_lib as fx, cel_style as cel
OUT=ROOT/'game/assets/sprites/cosmetics/sillages/esquive_fumee'
PREVIEW=ROOT/'game/assets/sprites/cosmetics/previews/esquive_fumee.png'
WORK=ROOT/'art/renders/sillage_esquive_fumee'
COLORS=['9A9A9A','6E6E6E','3A3A3A']

def setup(w,h,ppu=64):
 s=fx.setup(w,h,ppu=ppu,samples=8); s.render.dither_intensity=0; s.render.film_transparent=True
 for layer in s.view_layers: layer.use_pass_normal=False
 return s

def material(color):
 key='smoke_'+color
 if key not in fx.G['mats']:
  m=bpy.data.materials.new(key); m.diffuse_color=(*fx.lin(fx.hexc(color)),1); m.use_nodes=True
  ns=m.node_tree.nodes; ns.clear(); em=ns.new('ShaderNodeEmission'); em.inputs[0].default_value=(*fx.lin(fx.hexc(color)),1); em.inputs[1].default_value=1
  out=ns.new('ShaderNodeOutputMaterial'); m.node_tree.links.new(em.outputs[0],out.inputs[0]); fx.G['mats'][key]=m
 return fx.G['mats'][key]

def puff(x,y,w,h,c,a,rot=0):
 fx.sprite('smoke',x,y,w,h,color=fx.hexc(c),alpha=a,rot=rot)

def pixels(w,h):
 img=bpy.data.images.load(str(WORK/'render.png'),check_existing=False); img.scale(w,h); d=list(img.pixels[:]); bpy.data.images.remove(img); return d

def save(path,w,h,d):
 img=bpy.data.images.new(path.stem,width=w,height=h,alpha=True); img.pixels[:]=d; img.filepath_raw=str(path); img.file_format='PNG'; img.save(); bpy.data.images.remove(img)

def build_wake():
 s=setup(128,64,ppu=64)
 puff(-.02,.02,1.95,.56,'3A3A3A',.78,-.04); puff(.02,.035,1.62,.44,'6E6E6E',.78,.03); puff(.10,.055,1.08,.32,'9A9A9A',.70,-.04)
 for i in range(6):
  x=-.82+i*.32; puff(x,-.04,.25,.12,COLORS[i%3],.62,math.sin(i)*.14)
 bpy.context.scene.render.filepath=str(WORK/'render.png'); bpy.ops.render.render(write_still=True)
 d=pixels(64,32)
 for i in range(3,len(d),4): d[i]=min(d[i],.90)
 save(OUT/'wake.png',64,32,d)

def build_burst():
 allpix=[0.0]*(768*96*4)
 for f in range(8):
  t=f/7; s=setup(192,192,ppu=64); s.render.filepath=str(WORK/'render.png')
  fade=[.96,.94,.90,.84,.76,.62,.42,.008][f]; scale=[1.28,1.72,2.24,2.76,3.27,3.78,3.95,3.43][f]; yscale=[1.20,1.10,1.0,.94,.82,.73,.70,.70][f]
  for i in range(9):
   a=i*math.tau/9 + .25*math.sin(t*5); rr=(.12+.32*t)*(.8+.2*math.sin(i*4))
   c=COLORS[(i+f//2)%3]; puff(math.cos(a)*rr,.035+math.sin(a)*rr*.65,scale*(.40+.07*math.sin(i*8)),scale*(.30+.05*math.cos(i*7))*yscale,c,fade*(.72+.08*(i%3)),a)
  puff(0,.035,scale*.92,scale*.60*yscale,'6E6E6E',fade*.72)
  bpy.ops.render.render(write_still=True); d=pixels(96,96)
  ox=f*96
  for y in range(96):
   for x in range(96):
    src=(y*96+x)*4; dst=(y*768+ox+x)*4; allpix[dst:dst+4]=d[src:src+4]
 save(OUT/'burst.png',768,96,allpix)

def card(name,img,x,y,w,h,z,uv=(0,0,1,1)):
 m=bpy.data.materials.new(name); m.use_nodes=True; m.surface_render_method='BLENDED'; ns=m.node_tree.nodes; ns.clear(); ls=m.node_tree.links
 tex=ns.new('ShaderNodeTexImage'); tex.image=img; tex.interpolation='Closest'; em=ns.new('ShaderNodeEmission'); tr=ns.new('ShaderNodeBsdfTransparent'); mix=ns.new('ShaderNodeMixShader'); out=ns.new('ShaderNodeOutputMaterial')
 ls.new(tex.outputs['Color'],em.inputs[0]); ls.new(tex.outputs['Alpha'],mix.inputs[0]); ls.new(tr.outputs[0],mix.inputs[1]); ls.new(em.outputs[0],mix.inputs[2]); ls.new(mix.outputs[0],out.inputs[0])
 me=bpy.data.meshes.new(name); me.from_pydata([(-.5,-.5,0),(.5,-.5,0),(.5,.5,0),(-.5,.5,0)],[],[(0,1,2,3)]); uvlay=me.uv_layers.new(); u,v,uw,vh=uv
 for j,co in enumerate([(u,v),(u+uw,v),(u+uw,v+vh),(u,v+vh)]): uvlay.data[j].uv=co
 o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o); o.rotation_euler=(fx.TILT,0,0); o.location=fx.S(x,y,z); o.scale=(w,h,1); me.materials.append(m)

def build_preview():
 s=setup(256,256,ppu=96); s.render.film_transparent=False; s.world=bpy.data.worlds.new('Smoke preview world'); s.world.color=(.045,.055,.06)
 ground=bpy.data.images.load(str(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png'))
 for row in range(-2,3):
  for col in range(-2,3): card('Terrasses',ground,(col+row)*1.35,(col-row)*.675-.45,2.7,1.35,.4)
 run=bpy.data.images.load(str(ROOT/'game/assets/sprites/characters/ardent/run.png'))
 card('Ardent walking',run,.24,.22,1.95,1.95,-.1,(3/8,6/8,1/8,1/8))
 wake=bpy.data.images.load(str(OUT/'wake.png')); burst=bpy.data.images.load(str(OUT/'burst.png'))
 card('Smoke wake',wake,-.72,-.33,1.45,.72,.1); card('Smoke burst',burst,.18,-.58,.86,.86,.05,(4/8,0,1/8,1))
 s.render.resolution_x=256; s.render.resolution_y=256
 s.render.filepath=str(PREVIEW); bpy.ops.render.render(write_still=True)

def write_tres():
 lines=['[gd_resource type="SpriteFrames" load_steps=11 format=3]','','[ext_resource type="Texture2D" path="res://assets/sprites/cosmetics/sillages/esquive_fumee/wake.png" id="1"]','[ext_resource type="Texture2D" path="res://assets/sprites/cosmetics/sillages/esquive_fumee/burst.png" id="2"]','']
 for ident,atlas,region in [('wake','1','Rect2(0, 0, 64, 32)')]+[(f'burst_{i}','2',f'Rect2({i*96}, 0, 96, 96)') for i in range(8)]:
  lines += [f'[sub_resource type="AtlasTexture" id="{ident}"]',f'atlas = ExtResource("{atlas}")',f'region = {region}','']
 frames1='{"duration": 1.0, "texture": SubResource("wake")}'
 frames8=', '.join('{"duration": 1.0, "texture": SubResource("burst_%d")}'%i for i in range(8))
 lines += ['[resource]',f'animations = [{{"frames": [{frames1}], "loop": false, "name": &"wake", "speed": 1.0}}, {{"frames": [{frames8}], "loop": false, "name": &"burst", "speed": 24.0}}]','']
 (OUT/'esquive_fumee.tres').write_text('\n'.join(lines),encoding='utf-8')

def main():
 OUT.mkdir(parents=True,exist_ok=True); PREVIEW.parent.mkdir(parents=True,exist_ok=True); WORK.mkdir(parents=True,exist_ok=True)
 cel.install('vfx',normals=False); build_wake(); build_burst(); write_tres(); build_preview()
 bpy.context.preferences.filepaths.save_version=0; bpy.ops.file.pack_all(); bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/sillage_esquive_fumee.blend'))
 print('SMOKE_TRAIL_BUILD_OK wake=64x32 burst=768x96 preview=256x256 frames=8')
if __name__=='__main__': main()
