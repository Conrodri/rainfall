import bpy, math, sys
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'art/tools/iso'),str(ROOT/'art/tools/cel')]
import iso_rig, cel_style as cel
import boss_common
OUTC=ROOT/'game/assets/sprites/props/compass'
OUTV=ROOT/'game/assets/sprites/chests/chest_small_vitrine'
SRC=ROOT/'art/blender/props'

def mat(name,color,metal=.0,rough=.7,emit=None):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    if emit:
        p.inputs['Emission Color'].default_value=(*emit,1);p.inputs['Emission Strength'].default_value=3
    return m
STONE=mat('Worn basalt',(.105,.115,.12)); BRONZE=mat('Blackened oxidized bronze',(.22,.145,.085),.72,.5); EDGE=mat('Verdigris',(.105,.24,.2),.6); GLASS=mat('Cracked smoky glass',(.17,.31,.33),.25,.22); PAD=mat('Empty dark velvet',(.13,.09,.075)); ORANGE=mat('Single ember accent',(1,.2,.012),.1,.3,(1,.12,.004)); BLUE=mat('Single cold rim',(.025,.32,.5),.2,.25,(.02,.38,.8))
def assign(o,m): o.data.materials.append(m);return o
def cube(n,loc,scale,m,bev=.04):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=n;o.dimensions=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);assign(o,m)
    if bev:
        mod=o.modifiers.new('Worn chipped edges','BEVEL');mod.width=bev;mod.segments=1;o.modifiers.new('Weighted corners','WEIGHTED_NORMAL')
    return o
def cyl(n,loc,r,depth,m,verts=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=depth,location=loc);o=bpy.context.object;o.name=n;assign(o,m);mod=o.modifiers.new('Cut edges','BEVEL');mod.width=.025;mod.segments=1;o.modifiers.new('Weighted corners','WEIGHTED_NORMAL');return o
def ico(n,loc,scale,m):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=loc);o=bpy.context.object;o.name=n;o.scale=scale;assign(o,m);return o
def reset():
    boss_common.setup_scene(scale=2.25)
    scene=bpy.context.scene;scene.render.film_transparent=True;scene.view_settings.view_transform='Standard'
    if hasattr(scene,'eevee'): scene.eevee.taa_render_samples=8
def compass(state):
    reset();cyl('Stone plinth',(0,0,.12),.48,.24,STONE);cyl('Oxidized foot',(0,0,.28),.34,.12,BRONZE)
    # tall battered pedestal and heavy navigation dial
    cube('Angular pedestal',(0,0,.78),(.32,.32,1.0),STONE,.08);cube('Bronze collar',(0,0,1.23),(.46,.46,.15),BRONZE,.045)
    cyl('Compass housing',(0,0,1.56),.62,.22,BRONZE,16);cyl('Rune dial',(0,0,1.69),.52,.055,STONE,16)
    cyl('Verdigris inner ring',(0,0,1.73),.4,.035,EDGE,16);cyl('Dark dial',(0,0,1.76),.34,.025,BRONZE,16)
    for i in range(8):
        a=2*math.pi*i/8;ico('Rune stud',(math.cos(a)*.43,math.sin(a)*.43,1.77),(.045,.045,.025),EDGE)
    needle=cube('Split iron needle',(0,0,1.83),(.09,.67,.035),BRONZE,.012);needle.rotation_euler[2]=.35 if state=='idle' else 1.5
    # luminous broken tip only in ready state; dark cap in used state
    ico('Needle tip',(math.sin(.35 if state=='idle' else 1.5)*.3,-math.cos(.35 if state=='idle' else 1.5)*.3,1.86),(.09,.12,.045),ORANGE if state=='idle' else BRONZE)
    if state=='used': cube('Locked catch',(.34,.03,1.84),(.2,.07,.08),STONE,.015)
    frame_camera((128,192), True)
    cel.install('prop',normals=False)
    save_source('compass');render(state,OUTC,'compass_'+state,128)
def chest(state):
    reset();cube('Stone base',(0,0,.20),(1.02,.72,.36),STONE,.08);cube('Bronze lower band',(0,0,.38),(1.04,.74,.11),BRONZE,.035)
    cube('Empty velvet cushion',(0,0,.48),(.69,.46,.12),PAD,.09)
    # rim and glass dome as a faceted half-sphere, lid lifted on open state
    z=.78 if state=='closed' else 1.06; lift=.0 if state=='closed' else .24
    cube('Front glass frame',(0,-.30,z),(.92,.08,.46),BRONZE,.035);cube('Back glass frame',(0,.30,z),(.92,.08,.46),BRONZE,.035)
    cube('Left frame',(-.42,0,z),(.08,.52,.46),BRONZE,.03);cube('Right frame',(.42,0,z),(.08,.52,.46),BRONZE,.03)
    # faceted dome with transparent tinted surfaces
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=1,location=(0,0,z+.20));d=bpy.context.object;d.name='Cracked smoky glass dome';d.scale=(.40,.26,.23);d.rotation_euler[0]=lift;assign(d,GLASS)
    d.modifiers.new('Flat facets','DECIMATE').ratio=.45
    for x in (-.42,.42): cube('Cold luminous frame inlay',(x,0,z+.245),(.035,.5,.035),BLUE,.006)
    # crack etched as thin jagged bronze seam
    for i,(x,y) in enumerate([(-.08,.0),(.0,.07),(-.05,.13),(.04,.20)]):
        crack=cube('Glass fracture %d'%i,(x,y,z+.40),(.018,.13,.012),BRONZE,.002);crack.rotation_euler[2]=-.5
    frame_camera((128,128), False)
    cel.install('prop',normals=False)
    save_source('vitrine');render(state,OUTV,state,128)

def frame_camera(size, compass_prop):
    # Preserve the model: create_rig defaults to deleting the entire scene.
    scene=iso_rig.create_rig('MAP',size,target=(0,0,0),reset=False)
    scene.camera.rotation_euler=(math.radians(55),0,math.radians(45))
    bpy.context.view_layer.update()
    basis=scene.camera.rotation_euler.to_matrix()
    inv=basis.transposed()
    points=[inv@(o.matrix_world@Vector(v)) for o in scene.objects if o.type=='MESH' for v in o.bound_box]
    lo=[min(v[i] for v in points) for i in range(3)]
    hi=[max(v[i] for v in points) for i in range(3)]
    scale=max(128/90.51,(hi[0]-lo[0])*size[0]/(size[0]-12),(hi[1]-lo[1])*size[0]/(size[1]-12))
    if compass_prop:
        scale=max(scale,(hi[1]-lo[1])*size[0]/(.8*size[1]-8))
        cy=lo[1]+.3*size[1]*scale/size[0]
    else:
        # Both chest states share camera and foot pivot.
        scale=2.1; cy=.55
    scene.camera.data.ortho_scale=scale
    scene.camera.location=basis@Vector(((lo[0]+hi[0])/2,cy,12))
    scene.eevee.taa_render_samples=16
    scene.render.image_settings.color_mode='RGBA'
    bpy.context.view_layer.update()

def save_source(prop):
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC/('boussole_vitrine_'+prop+'.blend')))

def render(state,dest,stem,size):
    from PIL import Image, ImageChops
    diffuse=dest/(stem+'.png');dest.mkdir(parents=True,exist_ok=True)
    iso_rig.render_frame(diffuse,passes=False)
    scene=bpy.context.scene
    # Keep nonaccent geometry as a black occluder; replace final cel outputs.
    changes=[];accent=False
    for m in {slot.material for o in scene.objects if o.type=='MESH' for slot in o.material_slots if slot.material}:
        if not m.use_nodes: continue
        out=next(n for n in m.node_tree.nodes if n.type=='OUTPUT_MATERIAL')
        source=out.inputs['Surface'].links[0].from_socket
        em=m.node_tree.nodes.new('ShaderNodeEmission')
        active=m.name.startswith(('Single ember accent','Single cold rim'))
        accent=accent or active
        em.inputs[0].default_value=(1,1,1,1) if active else (0,0,0,1)
        m.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
        changes.append((m,out,source,em))
    ep=dest/(stem+'_e.png')
    if accent:
        iso_rig.render_frame(ep,passes=False)
        with Image.open(ep) as im:
            im.resize(((im.width+1)//2,(im.height+1)//2),Image.Resampling.LANCZOS).save(ep,optimize=True)
    elif ep.exists(): ep.unlink()
    for m,out,source,em in changes:
        m.node_tree.links.new(source,out.inputs['Surface']);m.node_tree.nodes.remove(em)
    root=bpy.data.objects.new('Shadow caster',None);scene.collection.objects.link(root)
    for o in list(scene.objects):
        if o.type=='MESH': o.parent=root
    iso_rig.render_shadow_decal(root,dest/(stem+'_shadow.png'))
    with Image.open(diffuse) as im:
        alpha=im.getchannel('A');box=alpha.getbbox()
        assert alpha.getextrema()[1]==255 and box, (stem,'empty')
        assert box[3]-box[1]>=im.height*.5,(stem,box,'height')
        assert min(box[0],box[1],im.width-box[2],im.height-box[3])>=4,(stem,box,'margin')

if __name__=='__main__':
    if '--vitrine' in sys.argv: chest('closed');chest('open')
    else: compass('idle');compass('used')
    print('PASS boussole_vitrine rendered')
