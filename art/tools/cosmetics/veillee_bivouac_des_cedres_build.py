from pathlib import Path
import sys, math, json, random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/menu/bivouac_des_cedres'
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
    s=setup_rig(SIZE);random.seed(617)
    ash=mat('Cedar ash',(.12,.105,.085));stone=mat('Rain-dark slate',(.14,.15,.14));wood=mat('Wet cedar',(.19,.135,.075));end=mat('Split cedar',(.27,.20,.12))
    tarp=mat('Ocher waxed canvas',(.18,.15,.085));seam=mat('Worn tarp seams',(.30,.25,.14));ember=mat('Coal',(.7,.16,.025),1.1);flame=mat('Low amber flame',(1,.30,.045),2);core=mat('Fire heart',(1,.65,.19),2.4)
    ico('Ash bed',(0,-.1,.02),(.62,.44,.04),ash)
    for i in range(9):
      a=i*math.tau/9;ico('Hearth stone',(.56*math.cos(a),-.1+.38*math.sin(a),.07),(.12,.1,.08),stone)
    for i in range(4):
      a=i*math.pi/4;p=Vector((-.38*math.cos(a),-.12-.3*math.sin(a),.12));q=Vector((.38*math.cos(a),-.12+.3*math.sin(a),.14));C.rod('Cedar log',p,q,.07,wood);ico('Log end',q,(.06,.05,.045),end)
    for i in range(11):
      a=i*math.tau/11;ico('Coal',(.3*math.cos(a),-.12+.21*math.sin(a),.08),(.035,.03,.02),ember)
    # Lean-to tarp overhead, open toward viewer.
    for x,z in [(-.9,1.45),(.86,1.63)]:C.rod('Tarp fork',(x,.45,0),(x,.45,z),.035,wood);C.rod('Guy line',(x,.45,z), (x*1.2,-.5,.02),.012,seam)
    v=[(-.95,.42,1.45),(0,.42,1.52),(.9,.42,1.64),(-.96,1.1,.76),(0,1.1,.69),(.9,1.1,.83)]
    mesh('Rain tarp',v,[(0,1,4,3),(1,2,5,4)],tarp)
    for a,b in [(0,1),(1,2),(0,3),(3,4),(4,5),(2,5)]:C.rod('Tarp hem',v[a],v[b],.014,seam)
    light=bpy.context.object if False else None
    bpy.ops.object.light_add(type='POINT',location=(0,-.12,.45));light=bpy.context.object;light.data.color=(1,.3,.07);light.data.energy=32;light.data.shadow_soft_size=.3
    tongues=[]
    for i in range(5):
      ob=cone('Low flame',(0,-.12,.36),.10,.008,.50,flame,7);tongues.append((ob,ob.location.copy(),i))
    heart=cone('Flame core',(0,-.14,.32),.08,.006,.32,core,7)
    cel.install('prop',normals=False)
    for f in range(FRAMES):
      t=f*math.tau/FRAMES
      for ob,loc,i in tongues:ob.location=loc+Vector((.035*math.sin(t+i),0,.025*math.sin(t*1.3+i)));ob.scale.z=1+.14*math.sin(t+i)
      heart.scale.z=1+.09*math.cos(t);light.data.energy=32+5*math.sin(t)
      render(WORK/f'_fire_{f:02}.png',SIZE,'prop')
    atlas=Image.new('RGBA',(SIZE[0]*FRAMES,SIZE[1]))
    em=Image.new('RGBA',(SIZE[0]//2*FRAMES,SIZE[1]//2))
    for f in range(FRAMES):
      for suffix,dest,x in [('',atlas,f*SIZE[0]),('_e',em,f*SIZE[0]//2)]:
        with Image.open(WORK/f'_fire_{f:02}{suffix}.png') as im:dest.paste(im,(x,0))
    atlas.save(OUT/'fire.png',optimize=True);em.save(OUT/'fire_e.png',optimize=True)
    lines=['[gd_resource type="SpriteFrames" load_steps=14 format=3]','', '[ext_resource type="Texture2D" path="res://assets/sprites/props/menu/bivouac_des_cedres/fire.png" id="1"]','']
    for i in range(FRAMES):lines += [f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i*256}, 0, 256, 256)','']
    frames=', '.join('{"duration": 1.0, "texture": SubResource("Frame_'+str(i)+'")}' for i in range(FRAMES))
    lines += ['[resource]','animations = [{"frames": ['+frames+'], "loop": true, "name": &"burn", "speed": 10.0}]']
    (OUT/'fire.tres').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    cel.uninstall()

def prop_scene(name,size):
    s=setup_rig(size);z=mat('Cedar dark waxed cloth',(.22,.18,.10));mid=mat('Ochre canvas',(.34,.27,.14));edge=mat('Worn seams',(.12,.11,.075));copper=mat('Old copper',(.33,.19,.095),.2);gold=mat('Lanternglass glow',(0.62,.31,.07),1.4);rope=mat('Wet rope',(.28,.22,.12))
    if name=='tent':
      mesh('Wax canvas tent',[(-.92,-.2,0),(.92,-.2,0),(0,.62,1.28)],[(0,1,2)],mid);mesh('Tent side',[(0,.62,1.28),(.92,-.2,0),(.88,.48,0)],[(0,1,2)],z)
      C.rod('Tent ridge',(-.96,-.2,.02),(0,.62,1.3),.035,rope);C.rod('Tent seam',(0,.62,1.3),(.96,-.2,.02),.026,edge)
      for x in [-.98,.98]:C.rod('Tent peg',(x,-.22,0),(x,-.22,.2),.025,copper)
    elif name=='pack':
      C.box('Canvas pack',(0,0,.47),(.55,.36,.73),z,bevel=.08);C.box('Folded flap',(0,-.2,.83),(.42,.07,.18),mid,bevel=.04)
      for x in [-.19,.19]:C.rod('Pack strap',(x,-.25,.12),(x,-.25,.9),.03,rope)
      ico('Gourd',( .4,.02,.2),(.16,.16,.22),copper);C.rod('Gourd neck',(.4,.02,.37),(.4,.02,.48),.045,rope)
    else:
      C.rod('Hanging branch',(-.8,.4,1.65),(.8,.4,1.65),.07,wood if 'wood' in locals() else z)
      C.rod('Lantern chain',(0,.3,1.64),(0,.3,1.12),.022,rope)
      C.box('Copper lantern',(0,.3,.78),(.36,.3,.55),copper,bevel=.045)
      for x in [-.16,.16]:C.rod('Glass guard',(x,.12,.55),(x,.12,1.02),.025,mid)
      C.box('Lantern roof',(0,.3,1.1),(.46,.37,.12),copper,bevel=.035);C.box('Lantern base',(0,.3,.46),(.4,.34,.1),copper,bevel=.025)
      cone('Lantern flame',(0,.08,.77),.07,.005,.25,gold,6)
    cel.install('prop',normals=False)
    # Save diffuse and lantern-only emission through the shared cel output pipeline.
    render(OUT/(name+'.png'),size,'prop')
    if name=='lantern_hanging':
      # Amber flame accent, stored at half resolution.
      with Image.open(OUT/'lantern_hanging.png') as im:
        glow=Image.new('RGBA',im.size,(217,162,74,0)); glow.putalpha(im.getchannel('A')); glow=glow.resize((64,64),Image.Resampling.LANCZOS); glow.save(OUT/'lantern_hanging_e.png',optimize=True)
    # Alpha silhouette shadow, displaced down-right, grayscale RGB.
    from PIL import ImageDraw,ImageFilter
    with Image.open(OUT/(name+'.png')) as im: alpha=im.getchannel('A')
    sh=Image.new('RGBA',size,(0,0,0,0)); mask=Image.new('L',size,0); mask.paste(alpha,(max(2,size[0]//12),max(2,size[1]//10)))
    mask=mask.filter(ImageFilter.GaussianBlur(max(2,size[0]//40)));sh.putalpha(mask.point(lambda a:int(a*.42)));sh.save(OUT/(name+'_shadow.png'),optimize=True)
    cel.uninstall()

def preview():
    from PIL import Image,ImageDraw
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA').resize((256,256))
    board=Image.new('RGBA',(256,256),(25,29,32,255));board.alpha_composite(ground)
    for fname,pos in [('tent.png',(18,38)),('pack.png',(150,126)),('lantern_hanging.png',(92,30)),('fire.png',(0,0))]:
      with Image.open(OUT/fname) as im:
        if fname=='fire.png':im=im.crop((0,0,256,256))
        im.thumbnail((110,100));board.alpha_composite(im,pos)
    board.convert('RGB').save(ROOT/'game/assets/sprites/cosmetics/previews/bivouac_des_cedres.png')

def main():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    fire_scene()
    (OUT/'layout.json').write_text('{"tent":{"offset_u":[-2.5,-1.0],"z":-1},"lantern_hanging":{"offset_u":[-1.6,-1.4],"z":1},"pack":{"offset_u":[1.4,0.6],"z":-1}}',encoding='utf-8')
    for n,sz in [('tent',(256,256)),('lantern_hanging',(128,128)),('pack',(128,128))]:prop_scene(n,sz)
    preview()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/veillee_bivouac_des_cedres.blend'))
    print('BIVOUAC_BUILD_OK fire=3072x256 frames=12 props=3 preview=256')

if __name__=='__main__':main()
