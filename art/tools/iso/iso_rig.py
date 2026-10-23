"""Shared C0 rigs. Units are metres; frame sizes are FINAL pixels.
Use create_rig/load_rig, render_frame; crop=False preserves contractual frames.
AO and direct shadows are integrated by Eevee into the exported diffuse.
"""
import bpy, math, sys
sys.path.insert(0,str(__import__("pathlib").Path(__file__).resolve().parent/"_deps"))
sys.path.append(str(__import__("pathlib").Path.home()/"AppData/Local/RainfallIsoDeps"))
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'art/tools/bosses'))
import boss_common as common
material = common.material
R = 64 * math.sqrt(2)
DIRECTIONS = common.DIRECTIONS

def set_frame(size=(512,512), rig=None):
    s=bpy.context.scene
    if isinstance(size,int): size=(size,size)
    rig=rig or s.get('iso_rig','MAP')
    s['iso_frame']=list(size)
    s.camera.data.sensor_fit='HORIZONTAL'
    s.camera.data.ortho_scale=size[0]/(128 if rig=='TOP' else R)
    s.render.resolution_x=size[0]*2; s.render.resolution_y=size[1]*2
    s.render.resolution_percentage=100
    return s

def create_rig(rig='MAP', size=(512,512), target=(0,0,0), reset=True):
    if rig not in ('MAP','CREA','TOP'): raise ValueError(rig)
    if reset: s=common.setup_scene()
    else: s=bpy.context.scene
    s['iso_rig']=rig
    name='ISO_'+rig
    cam=bpy.data.objects.get(name)
    if cam is None:
        data=bpy.data.cameras.new(name);cam=bpy.data.objects.new(name,data);s.collection.objects.link(cam)
    cam.data.type='ORTHO';cam.rotation_euler=(0,0,0) if rig=='TOP' else (math.pi/3,0,math.pi/4 if rig=='MAP' else 0)
    cam.location=Vector(target)+cam.rotation_euler.to_matrix()@Vector((0,0,12))
    s.camera=cam
    s.render.engine='BLENDER_EEVEE';s.render.film_transparent=True
    if hasattr(s,'eevee'): s.eevee.taa_render_samples=32
    s.view_settings.view_transform='Standard'
    # Reuse official boss lights, rotating their studio arrangement with the rig.
    basis=cam.rotation_euler.to_matrix()
    for name,offset in [('Sun_chaud_haut_gauche',(-4,6,8)),('Fill_froid',(4,3,6))]:
        light=bpy.data.objects.get(name)
        if light:
            light.location=Vector(target)+basis@Vector(offset)
            light.rotation_euler=(Vector(target)-light.location).to_track_quat('-Z','Y').to_euler()
    set_frame(size,rig);bpy.context.view_layer.update()
    return s

def load_rig(rig='MAP',size=(512,512),target=(0,0,0),path=None):
    bpy.ops.wm.open_mainfile(filepath=str(path or ROOT/'art/blender/iso_rig.blend'))
    return create_rig(rig,size,target,reset=False)

def bake_ao_shadows(obj):
    """Bake AO/contact shading into diffuse at sprite render time (no UV requirement).
    Shader AO modulates PBR base colour; Eevee bakes direct self-shadows in PNG.
    Accepts a mesh or a hierarchy root; leaves the emission and normals intact.
    """
    for ob in [obj,*obj.children_recursive]:
        if ob.type!='MESH': continue
        for slot in ob.material_slots:
            mat=slot.material
            if not mat or not mat.use_nodes: continue
            nodes=mat.node_tree.nodes; links=mat.node_tree.links
            if nodes.get('ISO_Baked_AO'): continue
            p=nodes.get('Principled BSDF')
            if not p: continue
            ao=nodes.new('ShaderNodeAmbientOcclusion');ao.name='ISO_Baked_AO';ao.inputs['Distance'].default_value=.7
            mul=nodes.new('ShaderNodeMixRGB');mul.blend_type='MULTIPLY';mul.inputs[0].default_value=.8
            base=p.inputs['Base Color']
            if base.is_linked: links.new(base.links[0].from_socket,mul.inputs[1])
            else: mul.inputs[1].default_value=base.default_value
            links.new(ao.outputs['Color'],mul.inputs[2]);links.new(mul.outputs[0],base)
    return obj

def optimize_png(path,crop=False,margin=6):
    """Lossless max compression; optional shared diffuse/pass crop (never by default).
    Returns crop rectangle, or None for omitted black emission.
    """
    from PIL import Image
    path=Path(path);im=Image.open(path).convert('RGBA')
    if path.stem.endswith('_e') and all(c.getextrema()[1]<=1 for c in im.split()[:3]):
        path.unlink();return None
    rect=(0,0,*im.size)
    if crop:
        bbox=im.getchannel('A').getbbox()
        if bbox: rect=(max(0,bbox[0]-margin),max(0,bbox[1]-margin),min(im.width,bbox[2]+margin),min(im.height,bbox[3]+margin))
        for suffix in ('','_n','_e','_shadow'):
            p=path.with_name(path.stem+suffix+'.png')
            if p.exists():
                with Image.open(p) as source: source.crop(rect).save(p,optimize=True,compress_level=9)
    else: im.save(path,optimize=True,compress_level=9)
    return rect

def render_frame(path,passes=True):
    from PIL import Image
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    s=bpy.context.scene;bpy.context.view_layer.update()
    if passes: common.configure_passes(path)
    else:
        if hasattr(s,'compositing_node_group'): s.compositing_node_group=None
        if hasattr(s,'use_nodes'): s.use_nodes=False
    s.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    size=tuple(s['iso_frame'])
    files=[path]
    if passes:
        for suffix in ('_n','_e'):
            candidates=list(path.parent.glob(path.stem+suffix+'__*.png'))
            if len(candidates)!=1: raise RuntimeError('Missing/ambiguous pass '+suffix)
            dest=path.with_name(path.stem+suffix+'.png');candidates[0].replace(dest);files.append(dest)
    for p in files:
        with Image.open(p) as src: im=src.convert('RGBA').resize(size,Image.Resampling.LANCZOS)
        if p.stem.endswith('_n'):
            # Fix transparent normal background explicitly, without drawing.
            pixels=list(im.getdata()); im.putdata([(128,128,255,0) if v[3]==0 else v for v in pixels])
        im.save(p,optimize=True,compress_level=9);optimize_png(p)
    return path

def render_shadow_decal(obj,path=None):
    """Project evaluated silhouette along the DA sun onto z=0, same camera/frame.
    Sun-only opaque silhouette, black/alpha; no receiver plane in diffuse.
    """
    path=Path(path or obj.get('iso_output',str(ROOT/'art/renders/iso_calib'/obj.name)+'.png'))
    if not path.stem.endswith('_shadow'): path=path.with_name(path.stem+'_shadow.png')
    s=bpy.context.scene;sun=bpy.data.objects['Sun_chaud_haut_gauche']
    ray=sun.rotation_euler.to_matrix()@Vector((0,0,-1))
    if ray.z>=0: raise ValueError('Sun must illuminate ground')
    hidden=[(o,o.hide_render) for o in s.objects if o.type=='MESH']
    projected=[];mat=bpy.data.materials.new('ISO_Shadow');mat.use_nodes=True
    n=mat.node_tree.nodes;n.clear();out=n.new('ShaderNodeOutputMaterial');em=n.new('ShaderNodeEmission');em.inputs[0].default_value=(0,0,0,1);mat.node_tree.links.new(em.outputs[0],out.inputs['Surface'])
    try:
        deps=bpy.context.evaluated_depsgraph_get()
        for ob in [obj,*obj.children_recursive]:
            if ob.type!='MESH': continue
            ev=ob.evaluated_get(deps);mesh=ev.to_mesh()
            verts=[]
            for v in mesh.vertices:
                w=ob.matrix_world@v.co;w-=ray*(w.z/ray.z);verts.append(tuple(w))
            data=bpy.data.meshes.new('ISO_projection');data.from_pydata(verts,[],[tuple(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
            sh=bpy.data.objects.new('ISO_projection',data);s.collection.objects.link(sh);sh.data.materials.append(mat);projected.append(sh)
        for ob,_ in hidden: ob.hide_render=True
        render_frame(path,passes=False)
        from PIL import Image
        with Image.open(path) as src: im=src.convert('RGBA')
        im.putalpha(im.getchannel('A').point(lambda a:round(a*.55)));im.save(path,optimize=True,compress_level=9)
    finally:
        for ob,value in hidden: ob.hide_render=value
        for ob in projected: bpy.data.objects.remove(ob,do_unlink=True)
    return path

