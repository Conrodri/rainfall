from pathlib import Path
import sys, math, json, random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/menu/lanternes_de_riziere'
WORK=ROOT/'art/blender/cel/cosmetics'
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
SIZE=(256,256)
FRAMES=12
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
import iso_rig as rig
import cel_style as cel
C=rig.common
from PIL import Image

def mesh(name, verts, faces, mat):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    ob=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob

def ico(name,p,scale,mat):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=p)
    ob=C.finish(bpy.context.object,name,mat);ob.scale=scale;return ob

def cone(name,p,r1,r2,h,mat,n=12):
    bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r1,radius2=r2,depth=h,location=p)
    return C.finish(bpy.context.object,name,mat)

def mat(name,col,emit=0):return C.material(name,col,roughness=.8,emission=emit)

def emission_base(path):
    """Only accent output; no normal-file nodes or normal-space conversion."""
    s=bpy.context.scene
    tree=bpy.data.node_groups.new('MN1_cel_outputs','CompositorNodeTree')
    s.compositing_node_group=tree
    tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    rl=tree.nodes.new('CompositorNodeRLayers');out=tree.nodes.new('NodeGroupOutput')
    tree.links.new(rl.outputs['Image'],out.inputs['Image'])
    f=tree.nodes.new('CompositorNodeOutputFile')
    f.directory=str(path.parent);f.file_name=path.stem+'_e__'
    f.file_output_items.new('RGBA','Image')
    f.format.media_type='IMAGE';f.format.file_format='PNG';f.format.color_mode='RGBA';f.format.color_depth='8'
    tree.links.new(rl.outputs['Emission'],f.inputs[0])

def render(path,size,profile):
    path.parent.mkdir(parents=True,exist_ok=True)
    cel.setup_scene(samples=8);cel.toon_materials(profile)
    cel.cel_passes(path,profile,base_configure=emission_base,normals=False)
    s=bpy.context.scene;s.render.filepath=str(path)
    if profile=='ui':
        # Neutralise the shared brown ink in Blender: the whole pip must tint evenly.
        tree=s.compositing_node_group
        output=next(n for n in tree.nodes if n.bl_idname=='NodeGroupOutput')
        source=output.inputs['Image'].links[0].from_socket
        grey=tree.nodes.new('CompositorNodeRGBToBW')
        tree.links.new(source,grey.inputs[0])
        alpha=tree.nodes.new('CompositorNodeSetAlpha')
        alpha.inputs['Type'].default_value='Replace Alpha'
        tree.links.new(grey.outputs[0],alpha.inputs['Image'])
        layers=next(n for n in tree.nodes if n.bl_idname=='CompositorNodeRLayers')
        tree.links.new(layers.outputs['Alpha'],alpha.inputs['Alpha'])
        tree.links.new(alpha.outputs[0],output.inputs['Image'])
    bpy.ops.render.render(write_still=True)
    with Image.open(path) as src:
        src.convert('RGBA').resize(size,Image.Resampling.LANCZOS).save(path,optimize=True)
    candidates=list(path.parent.glob(path.stem+'_e__*.png'))
    assert len(candidates)==1,candidates
    with Image.open(candidates[0]) as src:
        src.convert('RGBA').resize(((size[0]+1)//2,(size[1]+1)//2),Image.Resampling.LANCZOS).save(path.with_name(path.stem+'_e.png'),optimize=True)
    candidates[0].unlink()

def setup_rig(size):
    scene=rig.create_rig('MAP',size,target=(0,0,.85))
    scene.render.resolution_percentage=100
    return scene

def fire_scene():
    s=setup_rig(SIZE);s.camera.data.ortho_scale=3.9;s.camera.data.shift_y=-.15;random.seed(617)
    ash=mat('Cedar ash',(.12,.105,.085));stone=mat('Rain-dark slate',(.14,.15,.14));wood=mat('Wet cedar',(.19,.135,.075));end=mat('Split cedar',(.27,.20,.12))
    ember=mat('Coal',(.7,.16,.025),1.1);flame=mat('Low amber flame',(1,.30,.045),2);core=mat('Fire heart',(1,.65,.19),2.4)
    iron=mat('Dented iron bucket',(.19,.19,.17));rim=mat('Worn iron rim',(.34,.32,.27))
    N=16;verts=[]
    for z,r in [(.08,.36),(.48,.48)]:
      for j in range(N):a=j*math.tau/N;verts.append((r*math.cos(a),-.08+r*math.sin(a),z))
    mesh('Old iron pail',verts,[(j,(j+1)%N,(j+1)%N+N,j+N) for j in range(N)],iron)
    for z,r in [(.08,.36),(.48,.48)]:
      for j in range(N):
        a=j*math.tau/N;b=(j+1)*math.tau/N;C.rod('Bucket rim',(r*math.cos(a),-.08+r*math.sin(a),z),(r*math.cos(b),-.08+r*math.sin(b),z),.035,rim)
    for i in range(9):
      a=i*math.tau/9;ico('Bucket coal',(.29*math.cos(a),-.08+.22*math.sin(a),.40),(.04,.035,.025),ember)
    bpy.ops.object.light_add(type='POINT',location=(0,-.08,.65));light=bpy.context.object;light.data.color=(1,.3,.07);light.data.energy=32;light.data.shadow_soft_size=.3
    tongues=[]
    for i in range(5):
      x=(i-2)*.105; y=-.08-(i%2)*.025; base=.48; height=.54+(i%3)*.06
      verts=[];faces=[]; sides=16; rings=12
      for k in range(rings):
        q=k/(rings-1); radius=(.115*(1-q)**.72)*(1+.22*math.sin(q*math.tau*1.4+i))
        cx=x+.075*math.sin(q*math.pi*1.7+i*.8); cy=y+.018*math.sin(q*math.pi+i)
        for j in range(sides):
          a=j*math.tau/sides; verts.append((cx+radius*math.cos(a),cy+radius*math.sin(a),base+height*q))
      for k in range(rings-1):
        for j in range(sides): faces.append((k*sides+j,k*sides+(j+1)%sides,(k+1)*sides+(j+1)%sides,(k+1)*sides+j))
      faces.append(tuple(range((rings-1)*sides,rings*sides)))
      ob=mesh('Sinous flame tongue',verts,faces,flame);tongues.append((ob,ob.location.copy(),i))
    heart=ico('Flame core',(0,-.1,.58),(.10,.075,.20),core)
    cel.install('prop',normals=False)
    for f in range(FRAMES):
      t=f*math.tau/FRAMES
      for ob,loc,i in tongues:
        ob.location=loc+Vector((.035*math.sin(t+i),0,.015*math.sin(t*1.3+i)))
        ob.scale.x=1+.12*math.sin(t+i);ob.scale.z=1+.12*math.sin(t+i*.7)
      heart.scale.z=1+.09*math.cos(t);light.data.energy=32+5*math.sin(t)
      render(WORK/f'_fire_{f:02}.png',SIZE,'prop')
    atlas=Image.new('RGBA',(SIZE[0]*FRAMES,SIZE[1]))
    em=Image.new('RGBA',(SIZE[0]//2*FRAMES,SIZE[1]//2))
    for f in range(FRAMES):
      for suffix,dest,x in [('',atlas,f*SIZE[0]),('_e',em,f*SIZE[0]//2)]:
        with Image.open(WORK/f'_fire_{f:02}{suffix}.png') as im:dest.paste(im,(x,0))
    atlas.save(OUT/'fire.png',optimize=True);em.save(OUT/'fire_e.png',optimize=True)
    lines=['[gd_resource type="SpriteFrames" load_steps=14 format=3]','', '[ext_resource type="Texture2D" path="res://assets/sprites/props/menu/lanternes_de_riziere/fire.png" id="1"]','']
    for i in range(FRAMES):lines += [f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i*256}, 0, 256, 256)','']
    frames=', '.join('{"duration": 1.0, "texture": SubResource("Frame_'+str(i)+'")}' for i in range(FRAMES))
    lines += ['[resource]','animations = [{"frames": ['+frames+'], "loop": true, "name": &"burn", "speed": 10.0}]']
    # fire.tres remains the authored asset.
    cel.uninstall()

def prop_scene(name,size):
    s=setup_rig(size);s.camera.data.ortho_scale=5.2
    bamboo=mat('Bamboo muted olive',(.30,.24,.10));bamboo_hi=mat('Bamboo worn nodes',(.47,.39,.20));paper=mat('Amber rice paper',(1,.40,.10),1.5)
    hull=mat('Weathered boat planks',(.18,.12,.075));plank=mat('Boat plank edges',(.30,.22,.14));rope=mat('Oar wood',(.28,.20,.12))
    if name=='lantern_post':
      C.rod('Bamboo post',(0,0,.06),(0,0,2.95),.075,bamboo)
      for z0 in [.3,.95,1.65,2.35,2.82]:C.rod('Bamboo node',(-.08,0,z0),(.08,0,z0),.018,bamboo_hi)
      for z0,x in [(2.42,-.62),(1.72,.62),(1.02,-.62)]:
        C.rod('Bamboo cross arm',(0,0,z0),(x,0,z0),.035,bamboo);C.rod('Lantern hanger',(x,0,z0),(x,0,z0-.16),.014,bamboo_hi)
        C.box('Paper lantern body',(x,0,z0-.40),(.40,.28,.44),paper,bevel=.075)
        C.box('Lantern cap',(x,0,z0-.15),(.46,.34,.07),bamboo,bevel=.02);C.box('Lantern base',(x,0,z0-.65),(.42,.32,.06),bamboo,bevel=.02)
        for xx in [x-.12,x,x+.12]:C.rod('Fine paper rib',(xx,-.15,z0-.60),(xx,-.15,z0-.20),.008,bamboo_hi)
    else:
      mesh('Shallow skiff hull',[(-1.42,-.30,.10),(1.42,-.30,.10),(1.20,.30,.10),(-1.20,.30,.10),(-1.12,-.18,.42),(1.12,-.18,.42),(.94,.18,.42),(-.94,.18,.42)],[(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],hull)
      for i in range(7):
        x=-.90+i*.30;C.rod('Crosswise worn plank',(x,-.17,.39),(x,.17,.39),.018,plank)
      C.rod('Near gunwale',(-1.45,-.30,.14),(1.45,-.30,.14),.035,plank);C.rod('Far gunwale',(-1.45,.30,.14),(1.45,.30,.14),.035,plank)
      C.rod('Oar shaft',(-.92,-.48,.27),(.78,.42,.27),.025,rope);C.rod('Oar blade',(.73,.39,.27),(1.08,.63,.27),.07,plank)
    cel.install('prop',normals=False)
    render(OUT/(name+'.png'),size,'prop')
    if name=='lantern_post':
      from PIL import Image,ImageFilter
      with Image.open(OUT/(name+'.png')) as im: alpha=im.getchannel('A')
      glow=Image.new('RGBA',size,(255,179,90,0));glow.putalpha(alpha.point(lambda a:int(a*.7)));glow=glow.resize(((size[0]+1)//2,(size[1]+1)//2),Image.Resampling.LANCZOS);glow.save(OUT/(name+'_e.png'),optimize=True)
    from PIL import Image,ImageFilter
    with Image.open(OUT/(name+'.png')) as im: alpha=im.getchannel('A')
    mask=Image.new('L',size,0);mask.paste(alpha,(max(3,size[0]//20),max(3,size[1]//16)))
    mask=mask.filter(ImageFilter.GaussianBlur(3));sh=Image.new('RGBA',size,(35,35,35,0));sh.putalpha(mask.point(lambda a:int(a*.42)));sh.save(OUT/(name+'_shadow.png'),optimize=True)
    cel.uninstall()

def preview():
    s=setup_rig((256,256));s.camera.data.ortho_scale=5.5
    soil=mat('Terrace soil',(.19,.20,.13));bamboo=mat('Preview bamboo',(.30,.24,.10));bhi=mat('Preview bamboo joints',(.47,.39,.20));paper=mat('Preview amber paper',(1,.38,.08),1.4);wood=mat('Preview boat wood',(.18,.12,.075));edge=mat('Preview plank edge',(.30,.22,.14));iron=mat('Preview iron bucket',(.19,.19,.17));rim=mat('Preview rim',(.34,.32,.27));coal=mat('Preview ember',(.8,.16,.025),1.2);fire=mat('Preview flame',(1,.30,.045),2);heart=mat('Preview flame core',(1,.65,.19),2.4)
    C.box('Rice terrace ground',(0,0,-.08),(6.4,5.0,.14),soil,bevel=.04)
    s.render.film_transparent=False
    # post left
    C.rod('Preview bamboo post',(-1.15,.15,.05),(-1.15,.15,2.5),.065,bamboo)
    for z0,x in [(2.03,-1.65),(1.43,-.65),(.83,-1.65)]:
      C.rod('Preview arm',(-1.15,.15,z0),(x,.15,z0),.03,bamboo);C.box('Preview rice lantern',(x,.15,z0-.3),(.30,.24,.34),paper,bevel=.05)
    # little skiff right
    C.box('Skiff body',(.85,.2,.24),(1.8,.42,.22),wood,bevel=.1)
    for i in range(5):C.rod('Skiff plank',(.18+i*.3,.0,.34),(.18+i*.3,.4,.34),.016,edge)
    C.rod('Preview oar',(.25,-.16,.38),(1.45,.58,.38),.025,edge)
    # iron bucket with visible fire
    C.box('Preview fire bucket',(.05,-.55,.26),(.48,.42,.42),iron,bevel=.07)
    C.rod('Bucket upper rim',(-.20,-.55,.48),(.30,-.55,.48),.04,rim)
    for i in range(7):
      x=-.12+i*.055;cone('Preview flame',(x,-.56,.67),.055,.004,.40,fire,7)
    ico('Preview bright core',(.05,-.58,.60),(.11,.08,.07),heart)
    cel.install('prop',normals=False);preview_path=ROOT/'game/assets/sprites/cosmetics/previews/lanternes_de_riziere.png';render(preview_path,(256,256),'prop');cel.uninstall()
    from PIL import Image
    with Image.open(preview_path) as im: im.convert('RGB').convert('RGBA').save(preview_path,optimize=True)

def main():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    fire_scene()
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/'veillee_lanternes_de_riziere.blend'))
    print('LANTERNE_RIZIERE_OK frames=12')

if __name__=='__main__':main()
