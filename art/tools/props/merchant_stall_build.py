"""Single-prop merchant stall render. Run with Blender 5.2 --background --python."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(ROOT/'art/tools/iso'))
sys.path.insert(0,str(ROOT/'art/tools/night'))
sys.path.insert(0,str(ROOT/'art/tools/cel'))
import bpy
from mathutils import Vector
import iso_rig as rig
import cel_style as cel
C=rig.common
OUT=ROOT/'game/assets/sprites/props/merchant'
SRC=ROOT/'art/blender/props/merchant_stall.blend'

# Preserve the official alpha repair used by the MAP props pipeline.
_configure=C.configure_passes
def configure(path):
    _configure(path)
    tree=getattr(bpy.context.scene,'compositing_node_group',None) or bpy.context.scene.node_tree
    for n in tree.nodes:
        if n.bl_idname=='CompositorNodeSetAlpha':
            if 'Type' in n.inputs:n.inputs['Type'].default_value='Replace Alpha'
            else:n.mode='REPLACE_ALPHA'
C.configure_passes=configure

# The MAP rig normally writes a normal pass. This lot only needs diffuse and emission.
_render_frame=rig.render_frame
def render_frame(path,passes=True):
    if not passes:return _render_frame(path,passes=False)
    from PIL import Image
    from pathlib import Path
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    s=bpy.context.scene;bpy.context.view_layer.update();C.configure_passes(path)
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    for suffix in ('_e',):
        matches=list(path.parent.glob(path.stem+suffix+'__*.png'))
        if len(matches)!=1:raise RuntimeError('Missing/ambiguous pass '+suffix)
        matches[0].replace(path.with_name(path.stem+suffix+'.png'))
    for p in (path,path.with_name(path.stem+'_e.png')):
        with Image.open(p) as src:im=src.convert('RGBA').resize(tuple(s['iso_frame']),Image.Resampling.LANCZOS)
        im.save(p,optimize=True,compress_level=9)
    return path
rig.render_frame=render_frame

def mat(name,color,metal=.0,rough=.7):
    rgb=tuple(int(color[i:i+2],16)/255 for i in (0,2,4))
    m=C.material(name,rgb,metal,rough)
    return m

def emission_mat(name,color):
    rgb=tuple(int(color[i:i+2],16)/255 for i in (0,2,4))
    m=C.material(name,rgb,0,.4,emission=1.8)
    m['rainfall_emissive']=True
    return m

def cyl(name,pos,radius,depth,material,parent,vertices=12,r2=None):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius if r2 is None else r2,depth=depth,location=pos)
    return C.finish(bpy.context.object,name,material,parent,.006)

def build():
    OUT.mkdir(parents=True,exist_ok=True);SRC.parent.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.save_version=0
    s=rig.create_rig('MAP',(192,192))
    s.eevee.taa_render_samples=8
    # Contract: pixels per world unit and floor pivot at y=162.
    s.camera.location+=s.camera.rotation_euler.to_matrix()@Vector((0,(162-96)/rig.R,0))
    sun=bpy.data.objects['Sun_chaud_haut_gauche']
    sun.location=s.camera.rotation_euler.to_matrix()@Vector((-4,9,8))
    sun.rotation_euler=(-sun.location).to_track_quat('-Z','Y').to_euler()
    root=C.empty('merchant_stall')
    wood=mat('Smoke-blackened market oak','382B22',.08,.86)
    iron=mat('Scabbed rusted counter iron','603B28',.58,.76)
    brass=mat('Old green bronze','65796B',.68,.48)
    canvas=mat('Tarred patched canvas','292D2A',.04,.92)
    glass=mat('Smoked glass','343733',.12,.38)
    glow=emission_mat('Open amber lantern','E87524')
    # Counter, plank face, iron cap and prominent riveted corner braces.
    C.box('Heavy plank counter',(0,-.03,.66),(1.50,.72,.16),wood,root,.025)
    for z in (.37,.52):
        C.box('Uneven front oak boards',(0,-.405,z),(1.42,.055,.105),wood,root,.012)
    C.box('Rust plate counter edge',(0,-.425,.735),(1.53,.045,.035),iron,root,.008)
    for x in (-.64,.64):
        C.box('Iron corner strap',(x,-.447,.48),(.075,.025,.43),iron,root,.008)
        for z in (.31,.48,.66):
            cyl('Six-sided brass rivet',(x,-.468,z),.018,.014,brass,root,6)
    # Leaning poles, crossbar, angular pitched canopy and visible ragged valance.
    C.rod('Left crooked canopy pole',(-.67,.12,.69),(-.73,.12,1.91),.032,wood,root)
    C.rod('Right crooked canopy pole',(.67,.12,.69),(.72,.12,1.91),.032,wood,root)
    C.rod('Canopy crossbar',(-.77,.12,1.82),(.77,.12,1.82),.027,iron,root)
    C.box('Taut sloping tar canvas',(0,-.015,1.84),(1.62,1.05,.07),canvas,root,.018)
    # Asymmetric torn awning edge; all pieces remain within 2.2 u height.
    for x in (-.60,-.30,0,.30,.60):
        C.box('Canvas torn valance',(x,-.52,1.70),(.27,.035,.19),canvas,root,.008)
    # Three readable squat jars with rims and dark contents.
    for x,zscale in ((-.43,.16),(0,.20),(.42,.15)):
        cyl('Smoked merchant jar',(x,-.10,.84),.09,zscale,glass,root,10,r2=.072)
        cyl('Bronze jar lip',(x,-.10,.84+zscale*.51),.082,.018,brass,root,10)
    # Small balance: bronze foot, upright, beam and two hanging pans.
    cyl('Balance weighted foot',(.28,-.29,.80),.105,.045,brass,root,10)
    C.rod('Balance upright',(.28,-.29,.82),(.28,-.29,1.11),.019,brass,root)
    C.rod('Balance beam',(.08,-.29,1.08),(.49,-.29,1.08),.018,brass,root)
    for x in (.12,.45):
        C.rod('Balance pan chain',(x,-.29,1.07),(x,-.29,.91),.008,brass,root)
        cyl('Balance weighing pan',(x,-.29,.90),.085,.025,brass,root,12,r2=.055)
    # Hanging, visibly unlit iron lantern with one amber slit marking open stall.
    C.rod('Lantern hanging hook',(.53,.02,1.84),(.53,.02,1.58),.014,iron,root)
    C.box('Lantern iron cage',(.53,.02,1.43),(.22,.22,.29),iron,root,.015)
    C.box('Lantern dark glass',(.53,-.097,1.43),(.115,.012,.18),glass,root,.004)
    C.box('Small open amber wick',(.53,-.108,1.43),(.025,.008,.105),glow,root,.003)
    cyl('Lantern crown',(.53,.02,1.59),.13,.035,brass,root,8)
    cyl('Lantern base',(.53,.02,1.27),.12,.03,iron,root,8)
    rig.bake_ao_shadows(root);bpy.context.view_layer.update()
    cel.install('prop',normals=False)
    diffuse=OUT/'merchant_stall.png'
    rig.render_frame(diffuse,passes=True)
    e=OUT/'merchant_stall_e.png'
    if not e.exists():raise RuntimeError('emission pass missing')
    # Render ground decal with the shared top projection at matching dimensions.
    rot=sun.rotation_euler.copy();rig.create_rig('TOP',(192,192),reset=False);sun.rotation_euler=rot
    rig.render_shadow_decal(root,OUT/'merchant_stall_shadow.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(SRC))
    print('MERCHANT BUILD PASS: 192x192 diffuse/emission/shadow; pivot y=162',flush=True)

if __name__=='__main__':build()
