"""MN1: survivor's rain bivouac and tintable iron difficulty pips.
Blender --background --python this.py; system Python this.py --verify.
Reuses iso_rig geometry/lights and cel_style; Pillow assembles/checks only.
"""
from pathlib import Path
import sys, math, json, random
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
HERE = Path(__file__).resolve().parent
OUT = ROOT / 'game/assets/sprites/props/menu/campfire'
UI = ROOT / 'game/assets/sprites/ui/menu'
WORK = ROOT / 'art/blender/cel/mn1'
sys.path[:0] = [str(ROOT/'art/tools/iso'), str(ROOT/'art/tools/cel')]
SIZE = (384, 320)
FRAMES = 10

def verify():
    from PIL import Image, ImageChops
    import cel_style as cel
    # MN1 replaces provisional artwork; preserve its grid, not its old silhouette.
    checks = [cel.check_sheet('props/menu/campfire/burn.png', cell=SIZE,
                            frames=FRAMES, rows=1, normals=False, min_iou=0)]
    for size, suffix in [(24,''),(16,'_16')]:
        for state in ['empty','full']:
            rel = 'ui/menu/difficulty_pip_'+state+suffix+'.png'
            checks.append(cel.check_sheet(rel, normals=False, min_iou=0))
            im = Image.open(ROOT/'game/assets/sprites'/rel).convert('RGBA')
            assert im.size == (size,size)
            if state == 'full':
                assert ImageChops.difference(im.getchannel('R'),im.getchannel('G')).getbbox() is None
                assert ImageChops.difference(im.getchannel('G'),im.getchannel('B')).getbbox() is None
    for folder in [OUT,UI]:
        assert not list(folder.glob('difficulty*_n.png')) and not list(folder.glob('burn_n.png'))
    for p in [OUT/'burn_e.png',UI/'difficulty_pip_full_e.png',UI/'difficulty_pip_full_16_e.png']:
        im=Image.open(p).convert('RGBA')
        assert max(ImageChops.multiply(c,im.getchannel('A')).getextrema()[1] for c in im.split()[:3])>2
    tres=(OUT/'campfire.tres').read_text()
    assert 'CanvasTexture' not in tres and 'normal_texture' not in tres and '"burn"' in tres
    # Actual game soil, animation at native rig scale, tint variants, approved references.
    board=Image.new('RGBA',(1536,1110),(23,27,32,255))
    ground=Image.open(ROOT/'game/assets/sprites/terrain/terraces/iso/ground_a.png').convert('RGBA')
    sheet=Image.open(OUT/'burn.png').convert('RGBA')
    for i in range(8):
        panel=Image.new('RGBA',SIZE,(23,27,32,255))
        for y in range(-160,400,ground.height//2):
            for x in range(-ground.width,500,ground.width):
                panel.alpha_composite(ground,(x+(ground.width//2 if (y//(ground.height//2))%2 else 0),y))
        frame=sheet.crop((i*SIZE[0],0,(i+1)*SIZE[0],SIZE[1]))
        panel.alpha_composite(frame)
        board.alpha_composite(panel,((i%4)*384,(i//4)*320))
    for k,(size,suffix) in enumerate([(24,''),(16,'_16')]):
        for j,color in enumerate([(174,174,174),(177,133,78),(157,94,58)]):
            for st,state in enumerate(['empty','full']):
                im=Image.open(UI/('difficulty_pip_'+state+suffix+'.png')).convert('RGBA')
                tint=Image.new('RGBA',im.size,(*color,255))
                if state=='full':im=ImageChops.multiply(im,tint)
                # Nearest enlargement for inspection, native size alongside.
                board.alpha_composite(im.resize((size*4,size*4),Image.Resampling.NEAREST),(25+j*220+st*105,660+k*110))
                board.alpha_composite(im,(140+j*220+st*45,665+k*110))
    for i,rel in enumerate(['art/tools/iso/_c4_contact.png','art/tools/night/_f3p_contact.png','game/assets/sprites/ui/menu/button_normal.png']):
        im=Image.open(ROOT/rel).convert('RGBA'); im.thumbnail((490,215))
        board.alpha_composite(im,(i*512+(512-im.width)//2,890))
    board.convert('RGB').save(HERE/'_mn1_contact.png',optimize=True)
    (HERE/'_mn1_verification.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
    print('MN1 PASS: 10 frames; 24/16 pips; nonempty half-size emissions; no normals')

if '--verify' in sys.argv:
    verify();sys.exit()

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

def campfire():
    random.seed(617)
    s=rig.create_rig('MAP',SIZE,target=(0,0,.85))
    stone=mat('Rain-worn slate',(.17,.19,.20));ash=mat('Warm ash',(.18,.145,.105))
    wood=mat('Bleached driftwood',(.21,.15,.095));end=mat('Fresh split ends',(.31,.24,.16))
    canvas=mat('Storm canvas olive grey',(.145,.17,.145));seam=mat('Canvas worn hems',(.29,.28,.22))
    iron=mat('Cold iron',(.10,.115,.12));brass=mat('Tarnished bell bronze',(.24,.20,.125))
    clay=mat('Smoked amphora clay',(.26,.18,.13));rope=mat('Soaked hemp',(.30,.25,.17))
    ember=mat('Ember orange',(1,.17,.025),2);flame=mat('Amber flame',(1,.34,.055),2.2)
    core=mat('Pale fire heart',(1,.73,.29),2.5)
    # A low slate hearth and scattered warm gravel: baked contact and readable ground.
    ico('Ash hearth',(0,-.50,.015),(.82,.64,.055),ash)
    for i in range(13):
        a=i*math.tau/13
        ob=ico('Irregular hearth stone',(.73*math.cos(a),-.50+.54*math.sin(a),.09),(.16,.13,.12+random.random()*.045),stone)
        ob.rotation_euler.z=a
    for i in range(5):
        a=i*math.pi/2.8
        p=Vector((-.47*math.cos(a),-.50-.36*math.sin(a),.14+i*.019))
        q=Vector((.47*math.cos(a),-.50+.36*math.sin(a),.18+i*.019))
        C.rod('Charred driftwood',p,q,.083,wood)
        ico('Exposed split end',q,(.08,.06,.055),end)
    for i in range(19):
        a=random.random()*math.tau;r=random.random()*.45
        ico('Live coal',(r*math.cos(a),-.5+r*.7*math.sin(a),.09),(.052,.04,.025),ember)
    # Asymmetric lean-to behind the open hearth; rope, patched seams and rain runoff.
    for x,z in [(-1.27,1.59),(1.13,1.82)]:
        C.rod('Forked shelter pole',(x,.46,0),(x,.46,z+.10),.043,wood)
        C.rod('Guy rope',(x,.46,z),(x*1.22,-.05,.04),.012,rope)
        C.rod('Ground peg',(x*1.22,-.05,0),(x*1.22,-.05,.13),.025,iron)
    verts=[(-1.31,.43,1.60),(-.1,.43,1.69),(1.18,.43,1.84),(-1.33,1.26,.70),(-.08,1.28,.61),(1.18,1.22,.79)]
    mesh('Sagging rain tarp',verts,[(0,1,4,3),(1,2,5,4)],canvas)
    C.rod('Ridge driftwood',(-1.34,.44,1.60),(1.20,.44,1.84),.035,wood)
    for a,b in [(0,1),(1,2),(0,3),(3,4),(4,5),(2,5)]:C.rod('Reinforced canvas hem',verts[a],verts[b],.015,seam)
    mesh('Stitched repair',[(-.68,.79,1.24),(-.31,.79,1.27),(-.31,1.01,.98),(-.68,1.01,.96)],[(0,1,2,3)],seam)
    for i in range(6):C.rod('Repair stitches',(-.7+i*.074,.80,1.25),(-.7+i*.074,.85,1.19),.007,rope)
    # Amphora, unstrung bow and a cracked bell: three roster echoes.
    ico('Amphora belly',(.99,.08,.24),(.18,.18,.24),clay)
    cone('Amphora shoulder',(.99,.08,.45),.16,.075,.15,clay)
    cone('Amphora neck',(.99,.08,.56),.075,.075,.12,clay)
    C.ring('Amphora lip',(.99,.08,.625),.078,.018,clay,rotation=(0,0,0))
    for dx in [-.13,.13]:C.tube('Amphora handle',[(.99+dx,.08,.52),(.99+dx*1.7,.08,.48),(.99+dx*1.6,.08,.34)],.023,clay)
    C.tube('Survivor bow',[(-1.02,.18,.12),(-1.18,.29,.43),(-1.22,.41,.76),(-1.08,.53,1.12)],.025,wood)
    C.rod('Bowstring',(-1.02,.18,.12),(-1.08,.53,1.12),.006,rope)
    cone('Salvaged cracked bell',(.95,-.93,.18),.21,.10,.29,brass)
    C.ring('Bell skirt',(.95,-.93,.045),.21,.023,brass,rotation=(0,0,0))
    C.ring('Bell suspension',(.95,-.93,.37),.045,.014,iron)
    C.tube('Bell fracture',[(.96,-1.13,.055),(.985,-1.10,.13),(.956,-1.07,.19),(1.005,-1.045,.24)],.012,iron)
    # One battered crate doubles as a dry seat at the edge of the firelight.
    C.box('Supply crate',(-1.07,-.62,.22),(.45,.46,.43),wood,bevel=.025)
    for x in [-1.25,-.90]:C.box('Crate iron band',(x,-.62,.22),(.025,.48,.45),iron,bevel=.005)
    for z in [.10,.24,.37]:C.rod('Crate plank seam',(-1.28,-.862,z),(-.86,-.862,z),.008,ash)
    bpy.ops.object.light_add(type='POINT',location=(0,-.50,.53))
    light=bpy.context.object;light.name='Fire warmth baked into shelter';light.data.color=(1,.39,.095);light.data.energy=105;light.data.shadow_soft_size=.35
    tongues=[]
    for i in range(7):
        a=i*math.tau/7
        ob=cone('Wind-bent flame',(.19*math.cos(a),-.5+.13*math.sin(a),.52),.15,.012,.70 if i%2 else .90,flame if i%2 else ember,7)
        tongues.append((ob,ob.location.copy(),ob.scale.copy(),i))
    heart=cone('Bright flame core',(0,-.53,.44),.14,.01,.49,core,7)
    sparks=[ico('Rising ember',(.1*i,-.49,.7),(.015,.015,.027),ember) for i in range(4)]
    cel.install('prop',normals=False)
    pivot=world_to_camera_view(s,s.camera,Vector((0,-.5,0)))
    for f in range(FRAMES):
        t=f*math.tau/FRAMES
        for ob,loc,sc,i in tongues:
            ob.location=loc+Vector((.055*math.sin(t+i),.02*math.cos(t+i),.035*math.sin(t+i*1.6)))
            ob.scale.z=1+.18*math.sin(t+i*1.7)
            ob.rotation_euler=(.10*math.cos(t+i),.17*math.sin(t+i*.7),i)
        heart.scale.z=1+.10*math.cos(t)
        light.data.energy=105+15*math.sin(t)
        for i,ob in enumerate(sparks):
            phase=(f/FRAMES+i*.25)%1
            ob.location=(.13*math.sin(t+i),-.50+.06*math.cos(t+i),.55+phase*.86)
            ob.scale=(.012*(1-phase),.012*(1-phase),.028*(1-phase))
        render(WORK/f'burn_{f:02}.png',SIZE,'prop')
    OUT.mkdir(parents=True,exist_ok=True)
    for suffix,factor in [('',1),('_e',2)]:
        cell=(SIZE[0]//factor,SIZE[1]//factor)
        sheet=Image.new('RGBA',(cell[0]*FRAMES,cell[1]))
        for f in range(FRAMES):
            with Image.open(WORK/f'burn_{f:02}{suffix}.png') as src:sheet.paste(src,(f*cell[0],0))
        sheet.save(OUT/f'burn{suffix}.png',optimize=True)
    tres=['[gd_resource type="SpriteFrames" load_steps="12" format=3]','',
          '[ext_resource type="Texture2D" path="res://assets/sprites/props/menu/campfire/burn.png" id="1"]','']
    for i in range(FRAMES):
        tres += [f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i*SIZE[0]}, 0, {SIZE[0]}, {SIZE[1]})','']
    entries=', '.join('{"duration": 1.0, "texture": SubResource("Frame_'+str(i)+'")}' for i in range(FRAMES))
    tres += ['[resource]','animations = [{"frames": ['+entries+'], "loop": true, "name": &"burn", "speed": 10.0}]']
    dest=OUT/'campfire.tres'
    if not dest.exists():dest.write_text('\n'.join(tres)+'\n')
    (HERE/'_mn1_choices.json').write_text(json.dumps({'rig':'MAP / 90.51 px/u / elevation 30 / azimuth 45','frame':SIZE,'frames':FRAMES,'fps':10,'ground_pivot':[round(pivot.x*SIZE[0],2),round((1-pivot.y)*SIZE[1],2)],'choices':['Lean-to patched with sailcloth; open hearth unobstructed','Unstrung bow, smoked amphora, salvaged cracked bell','Dry crate seat; warm point light baked onto slate and canvas','24px base pips; 16px variants use _16 suffix; full is neutral grayscale'],'emission':'half size, flame and coals only'},indent=2))
    cel.uninstall()

def pips():
    for size,suffix in [(24,''),(16,'_16')]:
        for full in [False,True]:
            s=rig.create_rig('TOP',(size,size))
            s.camera.data.ortho_scale=2.35
            grey=mat('Worn iron neutral',(.20,.20,.20));edge=mat('Chipped bevel neutral',(.34,.34,.34))
            dark=mat('Iron incisions neutral',(.065,.065,.065));glow=mat('Tintable ember white',(.75,.75,.75),1.3)
            # Extruded diamond ring: center stays transparent in the empty state.
            outer=[(0,.94),(.83,0),(0,-.94),(-.83,0)]
            inner=[(0,.62),(.53,0),(0,-.62),(-.53,0)]
            for i in range(4):
                j=(i+1)%4
                vs=[(*outer[i],.02),(*outer[j],.02),(*inner[j],.09),(*inner[i],.09)]
                mesh('Hammered diamond rim',vs,[(0,1,2,3)],edge if i%2 else grey)
            for x,y in [(0,.81),(0,-.81),(.70,0),(-.70,0)]:ico('Iron rivet',(x,y,.10),(.055,.055,.025),edge)
            mesh('Worn edge nick',[(.34,.55,.11),(.46,.47,.11),(.37,.44,.11)],[(0,1,2)],dark)
            if full:
                verts=[(0,0,.18)]+[(*v,.08) for v in inner]
                ob=mesh('Four faceted solid iron',verts,[(0,1,2),(0,2,3),(0,3,4),(0,4,1)],grey)
                ob.data.materials.append(edge)
                for i,p in enumerate(ob.data.polygons):p.material_index=i%2
                mesh('Single ember incision',[(-.055,-.25,.19),(.02,-.05,.20),(.0,.33,.19),(.085,.08,.20),(.055,-.28,.19)],[(0,1,2,3,4)],glow)
            # Neutral light preserves strict grayscale and free UI tinting.
            for ob in s.objects:
                if ob.type=='LIGHT':ob.data.color=(1,1,1)
            name='difficulty_pip_'+('full' if full else 'empty')+suffix
            path=UI/(name+'.png');render(path,(size,size),'ui')
            if not full:path.with_name(name+'_e.png').unlink()
    print('MN1 render PASS')

if __name__=='__main__':
    WORK.mkdir(parents=True,exist_ok=True)
    for rel in ['props/menu/campfire','ui/menu']:
        cel.archive_folder(rel)
    campfire();pips()
