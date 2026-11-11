from pathlib import Path
import sys, math, json, random
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
OUT=ROOT/'game/assets/sprites/props/menu/quai_de_la_cite'
WORK=ROOT/'game/_veillee_quai_de_la_cite_work'
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

def render(path,size,profile,save_emission=True):
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
    if save_emission:
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
    ember=mat('Coal',(.7,.16,.025),1.1);flame=mat('Low amber flame',(1,.30,.045),2);core=mat('Fire heart',(1,.65,.19),2.4)
    ico('Ash bed',(0,-.1,.02),(.62,.44,.04),ash)
    for i in range(9):
      a=i*math.tau/9;ico('Hearth stone',(.56*math.cos(a),-.1+.38*math.sin(a),.07),(.12,.1,.08),stone)
    for i in range(4):
      a=i*math.pi/4;p=Vector((-.38*math.cos(a),-.12-.3*math.sin(a),.12));q=Vector((.38*math.cos(a),-.12+.3*math.sin(a),.14));C.rod('Cedar log',p,q,.07,wood);ico('Log end',q,(.06,.05,.045),end)
    for i in range(11):
      a=i*math.tau/11;ico('Coal',(.3*math.cos(a),-.12+.21*math.sin(a),.08),(.035,.03,.02),ember)
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
    s=setup_rig(size);s.camera.data.ortho_scale=4.25 if name=='lantern_hanging' else 3.45;z=mat('Cedar dark waxed cloth',(.22,.18,.10));mid=mat('Ochre canvas',(.34,.27,.14));edge=mat('Worn seams',(.12,.11,.075));copper=mat('Old copper',(.33,.19,.095),.2);gold=mat('Lanternglass glow',(0.62,.31,.07),1.4);rope=mat('Wet rope',(.28,.22,.12))
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
    bbox=mask.getbbox()
    if bbox:
      bw,bh=bbox[2]-bbox[0],bbox[3]-bbox[1];limit_w,limit_h=size[0]-8,size[1]-8
      if bw>limit_w or bh>limit_h:
        scale=min(limit_w/bw,limit_h/bh);mask=mask.resize((max(1,round(size[0]*scale)),max(1,round(size[1]*scale))),Image.Resampling.LANCZOS)
        canvas=Image.new('L',size,0);canvas.paste(mask,((size[0]-mask.width)//2,(size[1]-mask.height)//2));mask=canvas
    mask=mask.filter(ImageFilter.GaussianBlur(max(2,size[0]//40)));sh.putalpha(mask.point(lambda a:int(a*.42)));sh.save(OUT/(name+'_shadow.png'),optimize=True)
    cel.uninstall()

def preview():
    # True cel render: build a single composed camp scene, with every prop in frame.
    s=setup_rig((256,256));s.camera.data.ortho_scale=5.2;floor=mat('Forest floor',(.12,.16,.11));bark=mat('Cedar trunk',(.16,.12,.075));leaf=mat('Cedar canopy',(.10,.17,.105))
    C.box('Forest ground',(0,0,-.08),(4.5,3.2,.12),floor)
    for x,y,h in [(-1.75,.65,2.2),(1.8,.85,2.4),(-2.0,-.9,1.7),(2.1,-.85,1.8)]:
      C.rod('Cedar trunk',(x,y,0),(x,y,h),.095,bark);ico('Cedar bough',(x,y,h),(.42,.38,.4),leaf)
    # Place actual props in one coordinated rig; use compact geometry sized to fit the view.
    tentmat=mat('Preview canvas',(.34,.27,.14));tentdark=mat('Preview tent shade',(.22,.18,.10));rope=mat('Preview rope',(.28,.22,.12));metal=mat('Preview copper',(.33,.19,.095));glow=mat('Preview lantern glow',(.95,.43,.10),1.7)
    mesh('Preview tent',[(-1.35,.25,.03),(-.35,.25,.03),(-.85,.78,.83)],[(0,1,2)],tentmat)
    mesh('Preview tent side',[(-.85,.78,.83),(-.35,.25,.03),(-.38,.68,.03)],[(0,1,2)],tentdark)
    C.rod('Preview tent ridge',(-1.37,.25,.04),(-.85,.78,.85),.025,rope)
    # fire ring and animated flame, centered forward
    ash=mat('Preview ash',(.12,.105,.085));stone=mat('Preview slate',(.2,.2,.17));wood=mat('Preview cedar',(.25,.16,.08));ember=mat('Preview coal',(.8,.17,.025),1.0);fire=mat('Preview flame',(1,.30,.045),2.0);heart=mat('Preview fire heart',(1,.65,.19),2.4)
    ico('Preview ash bed',(0,-.78,.025),(.48,.34,.035),ash)
    for i in range(9):
      a=i*math.tau/9;ico('Preview hearth stone',(.43*math.cos(a),-.78+.32*math.sin(a),.065),(.09,.075,.06),stone)
    for i in range(2):C.rod('Preview log',(-.26,-.78+i*.15,.105),(.26,-.78-i*.15,.12),.06,wood)
    for i in range(7):
      a=i*math.tau/7;ico('Preview coal',(.23*math.cos(a),-.78+.17*math.sin(a),.09),(.027,.025,.02),ember)
    cone('Preview flame',(0,-.78,.32),.09,.006,.4,fire,7);cone('Preview heart',(0,-.79,.29),.06,.005,.27,heart,7)
    # Pack at right; lantern hangs visibly from a fine branch above the fire.
    C.box('Preview pack',(1.15,-.5,.32),(.34,.26,.48),tentdark,bevel=.05);C.box('Preview pack flap',(1.15,-.68,.61),(.27,.05,.12),tentmat,bevel=.03)
    C.rod('Preview branch',(-.35,.5,1.48),(.68,.5,1.48),.035,bark);C.rod('Preview chain',(.2,.48,1.46),(.2,.48,1.2),.012,rope)
    C.box('Preview lantern',(.2,.46,1.02),(.20,.17,.23),metal,bevel=.025);C.box('Preview lantern roof',(.2,.46,1.17),(.25,.2,.07),metal,bevel=.02);C.box('Preview lantern base',(.2,.46,.87),(.22,.18,.055),metal,bevel=.015)
    cone('Preview lantern flame',(.2,.35,1.02),.04,.004,.14,glow,6)
    cel.install('prop',normals=False);render(ROOT/'game/assets/sprites/cosmetics/previews/bivouac_des_cedres.png',(256,256),'prop');cel.uninstall()


def fire_only():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    s=setup_rig(SIZE);s.camera.data.ortho_scale=4.25
    ember=mat('Embers',(1,.24,.025),2.5);flame=mat('Amber flame',(1,.30,.045),2.8);core=mat('Fire core',(1,.65,.22),3.0)
    tongues=[]
    def flame_mesh(name,matl,height,width):
      rings=9;sides=16;verts=[]
      for k in range(rings):
        u=k/(rings-1);cx=.075*math.sin(u*math.pi*1.7);cz=height*u;rad=width*(1-u)**.7*(.78+.22*math.sin(math.pi*u))
        for q in range(sides):
          a=q*math.tau/sides;verts.append((cx+rad*math.cos(a),rad*math.sin(a),cz))
      faces=[]
      for k in range(rings-1):
        for q in range(sides):
          a=k*sides+q;b=k*sides+(q+1)%sides;faces.append((a,b,b+sides,a+sides))
      ob=mesh(name,verts,faces,matl)
      for p in ob.data.polygons:p.use_smooth=True
      sub=ob.modifiers.new('Liquid flame','SUBSURF');sub.levels=1;return ob
    for j,(x,z,h,w) in enumerate([(-.24,.12,.57,.126),(-.12,.14,.65,.132),(0,.13,.66,.143),(.12,.12,.62,.132),(.24,.11,.54,.116)]):
      ob=flame_mesh('Wavering flame',flame,h,w);ob.location=(x,0,z);tongues.append((ob,x,z,j))
    for x,z in [(-.24,.10),(-.13,.09),(.13,.10),(.24,.11),(.02,.08)]:ico('Flying ember',(x,-.02,z),(.018,.018,.018),ember)
    heart=flame_mesh('Bright flame core',core,.35,.068);heart.location=(0,-.03,.12);cel.install('prop',normals=False)
    atlas=Image.new('RGBA',(3072,256));em=Image.new('RGBA',(1536,128))
    for f in range(12):
      t=f*math.tau/12
      for ob,x,z,j in tongues:ob.location=(x+.025*math.sin(t+j),0,z+.020*math.sin(t*1.2+j));ob.scale=(1+.06*math.sin(t+j),1,1+.10*math.sin(t+j))
      heart.location.z=.12+.018*math.cos(t)
      render(WORK/f'_qfire_{f:02}.png',SIZE,'prop')
      for suffix,dest,xp in [('',atlas,f*256),('_e',em,f*128)]:
        with Image.open(WORK/f'_qfire_{f:02}{suffix}.png') as im:dest.paste(im,(xp,0))
    atlas.save(OUT/'fire.png');em.save(OUT/'fire_e.png');cel.uninstall()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/veillee_quai_de_la_cite.blend'),compress=True)
    import shutil;shutil.rmtree(WORK,ignore_errors=True)
    print('FIRE_ONLY_OK frames=12')

def main():
    global Image
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    # Barrel and crate renders; geometry is intentionally inset for transparent safety margins.
    for name in ():
      s=setup_rig((128,128));s.camera.data.ortho_scale=3.15
      rust=mat('Rust dark',(.20,.105,.065));rustmid=mat('Rust',(.34,.19,.12));rusthi=mat('Rust lit',(.48,.29,.18));iron=mat('Iron hoops',(.13,.14,.14));wood=mat('Wet wood',(.22,.16,.105));woodhi=mat('Wood worn',(.34,.27,.19))
      if name=='barrel':
        bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.52,depth=1.05,location=(0,0,.58));C.finish(bpy.context.object,'Rusted drum',rustmid)
        for z in (.28,.52,.81):
          bpy.ops.mesh.primitive_torus_add(major_radius=.50,minor_radius=.035,major_segments=12,minor_segments=4,location=(0,0,z));C.finish(bpy.context.object,'Iron band',iron)
        bpy.ops.mesh.primitive_torus_add(major_radius=.47,minor_radius=.035,major_segments=12,minor_segments=4,location=(0,0,1.12));C.finish(bpy.context.object,'Rim',iron)
        for x in (-.19,.19): C.rod('Handle',(x,-.45,.8),(x,-.5,.97),.045,iron)
        for x,z in [(-.25,.33),(.12,.31),(.27,.7),(-.12,.73)]:
          bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=.07,location=(x,-.48,z));C.finish(bpy.context.object,'Perforation',mat('Black hole',(.018,.012,.01)))
      else:
        C.box('Wood crate',(0,0,.46),(.88,.72,.82),wood,bevel=.06)
        for x in (-.28,0,.28):C.rod('Plank',(x,-.38,.08),(x,-.38,.84),.025,woodhi)
        for z in (.12,.8):C.rod('Iron binding',(-.49,-.4,z),(.49,-.4,z),.035,iron)
      cel.install('prop',normals=False);render(OUT/(name+'.png'),(128,128),'prop');cel.uninstall()
      from PIL import Image,ImageFilter
      with Image.open(OUT/(name+'.png')) as im: a=im.getchannel('A')
      sh=Image.new('RGBA',(128,128),(0,0,0,0));m=Image.new('L',(128,128),0);m.paste(a,(8,8));m=m.filter(ImageFilter.GaussianBlur(3));sh.putalpha(m.point(lambda v:int(v*.42)));sh.save(OUT/(name+'_shadow.png'))
    # Flame and ember only, rendered above the barrel; 12 true animation poses.
    s=setup_rig(SIZE);s.camera.data.ortho_scale=4.25
    ember=mat('Embers',(1,.24,.025),2.5);flame=mat('Amber flame',(1,.30,.045),2.8);core=mat('Fire core',(1,.65,.22),3.0)
    tongues=[]
    def flame_mesh(name,matl,height,width):
      rings=9; sides=16; verts=[]
      for k in range(rings):
        u=k/(rings-1); cx=.075*math.sin(u*math.pi*1.7); cz=height*u
        rad=width*(1-u)**.7*(.78+.22*math.sin(math.pi*u))
        for q in range(sides):
          a=q*math.tau/sides; verts.append((cx+rad*math.cos(a),rad*math.sin(a),cz))
      faces=[]
      for k in range(rings-1):
        for q in range(sides):
          a=k*sides+q;b=k*sides+(q+1)%sides;faces.append((a,b,b+sides,a+sides))
      ob=mesh(name,verts,faces,matl)
      for p in ob.data.polygons:p.use_smooth=True
      sub=ob.modifiers.new('Liquid flame','SUBSURF');sub.levels=1;return ob
    for j,(x,z,h,w) in enumerate([(-.24,.12,.57,.126),(-.12,.14,.65,.132),(0,.13,.66,.143),(.12,.12,.62,.132),(.24,.11,.54,.116)]):
      ob=flame_mesh('Wavering flame',flame,h,w);ob.location=(x,0,z);tongues.append((ob,x,z,j))
    for j,(x,z) in enumerate([(-.24,.10),(-.13,.09),(.13,.10),(.24,.11),(.02,.08)]):ico('Flying ember',(x,-.02,z),(.018,.018,.018),ember)
    heart=flame_mesh('Bright flame core',core,.35,.068);heart.location=(0,-.03,.12);cel.install('prop',normals=False)
    atlas=Image.new('RGBA',(3072,256));em=Image.new('RGBA',(1536,128))
    for f in range(12):
      t=f*math.tau/12
      for ob,x,z,j in tongues:ob.location=(x+.025*math.sin(t+j),0,z+.020*math.sin(t*1.2+j));ob.scale=(1+.06*math.sin(t+j),1,1+.10*math.sin(t+j))
      heart.location.z=.12+.018*math.cos(t)
      render(WORK/f'_qfire_{f:02}.png',SIZE,'prop')
      for suffix,dest,xp in [('',atlas,f*256),('_e',em,f*128)]:
        with Image.open(WORK/f'_qfire_{f:02}{suffix}.png') as im:dest.paste(im,(xp,0))
    atlas.save(OUT/'fire.png');em.save(OUT/'fire_e.png')
    # Existing fire.tres remains byte-for-byte unchanged (same 12 x 256 frames).
    cel.uninstall()
    # Cat sheet: eight poses, round sleeping alley cat, breathing and ear twitch.
    sheet=Image.new('RGBA',(768,96))
    for f in range(8):
      s=setup_rig((96,96));s.camera.data.ortho_scale=2.25
      fur=mat('Alley cat grey #6E6E72',(.162,.162,.175));patch=mat('Silver tabby patches',(.31,.31,.33));dark=mat('Paws',(.09,.09,.105));eye=mat('Closed eyes',(.025,.025,.03));inner=mat('Ear inner',(.25,.20,.21))
      breath=math.sin(f*math.tau/8)
      bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=32,radius=1,location=(.02,0,.35+.012*breath));ob=C.finish(bpy.context.object,'Rounded curled sleeping body',fur);ob.scale=(.76*(1+.03*breath),.49,.32*(1+.03*breath))
      for p in ob.data.polygons:p.use_smooth=True
      # Two soft-edged coat markings follow the flanks.
      for x,y,sc in [(-.22,-.39,(.22,.10,.025)),(.36,.23,(.20,.11,.023))]:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=1,location=(x,y,.53));ob=C.finish(bpy.context.object,'Light grey tabby marking',patch);ob.scale=sc
        for p in ob.data.polygons:p.use_smooth=True
      bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=28,radius=1,location=(-.48,-.16,.48+.008*math.sin(f*math.tau/8)));ob=C.finish(bpy.context.object,'Round sleeping head',fur);ob.scale=(.31,.31,.27);ob.rotation_euler.y=.025*math.cos(f*math.tau/8)
      for p in ob.data.polygons:p.use_smooth=True
      twitch=.055*math.sin(f*math.pi) if f in (5,6) else 0
      for x,dx in [(-.70,-.04),(-.29,.04)]:
        z=.67+(twitch if x<-.5 else 0)
        ob=mesh('Soft triangular cat ear',[(x-.12,-.17,.56),(x+.12,-.17,.56),(x+dx,-.16,z)],[(0,1,2)],fur)
        sol=ob.modifiers.new('Ear thickness','SOLIDIFY');sol.thickness=.055;bev=ob.modifiers.new('Soft ear edge','BEVEL');bev.width=.035;bev.segments=3
        for p in ob.data.polygons:p.use_smooth=True
        mesh('Ear inner',[(x-.065,-.207,.59),(x+.065,-.207,.59),(x+dx,-.20,z-.045)],[(0,1,2)],inner)
      C.rod('Left closed eyelid',(-.62,-.442,.48),(-.54,-.455,.465),.013,eye);C.rod('Right closed eyelid',(-.45,-.45,.48),(-.37,-.442,.465),.013,eye)
      for x in (-.19,.15):ico('Tucked paw',(x,-.39,.23),(.18,.115,.075),dark)
      # Continuous curled tail, built as a smooth tube around the rump.
      cu=bpy.data.curves.new('Curled tail curve','CURVE');cu.dimensions='3D';cu.resolution_u=24;cu.bevel_depth=.085;cu.bevel_resolution=5
      sp=cu.splines.new('BEZIER');sp.bezier_points.add(4)
      for bp,co in zip(sp.bezier_points,[(.49,-.02,.34),(.73,-.12,.36),(.77,-.34,.39),(.55,-.44,.38),(.35,-.31,.36)]):bp.co=co;bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
      tail=bpy.data.objects.new('Smooth curled tail',cu);bpy.context.collection.objects.link(tail);tail.data.materials.append(fur)
      cel.install('prop',normals=False);render(WORK/f'_qcat_{f:02}.png',(96,96),'prop');cel.uninstall()
      with Image.open(WORK/f'_qcat_{f:02}.png') as im:sheet.paste(im,(f*96,0))
    sheet.save(OUT/'cat.png')
    # Blender-native title preview, compact tableau.
    s=setup_rig((256,256));s.camera.data.ortho_scale=4.2;floor=mat('Dark concrete quay gradient',(.14,.14,.16))
    floor.use_nodes=True;nt=floor.node_tree;bs=next(n for n in nt.nodes if n.type=='BSDF_PRINCIPLED')
    tex=nt.nodes.new('ShaderNodeTexCoord');sep=nt.nodes.new('ShaderNodeSeparateXYZ');ramp=nt.nodes.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=(.055,.055,.068,1)
    ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=(.17,.17,.19,1)
    nt.links.new(tex.outputs['Generated'],sep.inputs[0]);nt.links.new(sep.outputs['Y'],ramp.inputs[0]);nt.links.new(ramp.outputs['Color'],bs.inputs['Base Color'])
    C.box('Wet quay',(0,0,-.1),(12,12,.15),floor)
    # Broad concrete backing gives a subdued full-frame top gradient.
    bg=mat('Quay dusk backdrop',(.055,.055,.068));C.box('Full frame quay backdrop',(0,1.6,-.24),(4.2,3.3,.12),bg)
    # stylized barrel fire, crate, sleeping cat
    rust=mat('Preview rust',(.24,.12,.075));metal=mat('Preview iron',(.10,.11,.12));glow=mat('Preview fire',(1,.29,.04),2.5);wood=mat('Preview crate',(.24,.18,.12));fur=mat('Preview cat',(.16,.16,.175));
    bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=.43,depth=.8,location=(-.55,.1,.42));C.finish(bpy.context.object,'Barrel',rust)
    for z in (.2,.55,.78):bpy.ops.mesh.primitive_torus_add(major_radius=.42,minor_radius=.03,major_segments=12,minor_segments=4,location=(-.55,.1,z));C.finish(bpy.context.object,'Hoop',metal)
    for j,x in enumerate((-.7,-.48,-.25)):
      ob=flame_mesh('Preview organic flame',glow,.52,.12);ob.location=(x,-.08,.80);ob.rotation_euler.y=.1*math.sin(j)
    C.box('Quay crate',(-1.25,-.15,.33),(.62,.58,.58),wood,bevel=.05)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,radius=1,location=(.86,-.58,.24));ob=C.finish(bpy.context.object,'Resting curled cat',fur);ob.scale=(.63,.38,.20)
    for p in ob.data.polygons:p.use_smooth=True
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,radius=1,location=(.48,-.58,.34));ob=C.finish(bpy.context.object,'Cat head',fur);ob.scale=(.24,.24,.2)
    for x in (.38,.58):
      bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=.09,radius2=.005,depth=.18,location=(x,-.58,.52));C.finish(bpy.context.object,'Cat ear',fur)
    # Cat head and ears at right, with closed eyes; warm light glints on a puddle.
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=16,radius=1,location=(.48,-.58,.34));ob=C.finish(bpy.context.object,'Preview cat head',fur);ob.scale=(.24,.24,.2)
    for x in (.38,.58):
      bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.085,radius2=.003,depth=.16,location=(x,-.58,.52));ob=C.finish(bpy.context.object,'Preview cat ear',fur)
    eyelid=mat('Preview closed eyes',(.025,.025,.03));C.rod('Preview closed eye left',(.38,-.815,.34),(.44,-.82,.33),.009,eyelid);C.rod('Preview closed eye right',(.53,-.82,.34),(.59,-.815,.33),.009,eyelid)
    puddle=mat('Amber puddle reflection',(.42,.12,.025),.35);bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=16,radius=1,location=(-.05,-1.06,.005));ob=C.finish(bpy.context.object,'Fire reflection puddle',puddle);ob.scale=(.82,.23,.012)
    cel.install('prop',normals=False);render(WORK/'_preview_quai.png',(256,256),'prop',save_emission=False);cel.uninstall()
    with Image.open(WORK/'_preview_quai.png') as im:im.save(ROOT/'game/assets/sprites/cosmetics/previews/quai_de_la_cite.png',optimize=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/cel/cosmetics/veillee_quai_de_la_cite.blend'),compress=True)
    import shutil
    shutil.rmtree(WORK,ignore_errors=True)
    print('QUAI_DE_LA_CITE_OK fire=12 props=3 cat=8')

if __name__=='__main__':
    if '--fire-only' in sys.argv: fire_only()
    else: main()
