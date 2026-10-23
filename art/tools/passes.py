"""Passes Blender RGBA, normales camera OpenGL et emission, sans post-traitement externe.
Blender 5.2. diffuse_path impose exactement la couverture du rendu diffus.
"""
import bpy
from pathlib import Path
from contextlib import contextmanager


def _tree(scene, name):
    if hasattr(scene, 'compositing_node_group'):
        tree = bpy.data.node_groups.new(name, 'CompositorNodeTree')
        scene.compositing_node_group = tree
        tree.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
        output = tree.nodes.new('NodeGroupOutput')
    else:
        scene.use_nodes = True
        tree = scene.node_tree
        tree.nodes.clear()
        output = tree.nodes.new('CompositorNodeComposite')
    scene.use_nodes = True
    return tree, output


def _setalpha(t, color, alpha):
    n=t.nodes.new('CompositorNodeSetAlpha')
    if isinstance(color, tuple): n.inputs['Image'].default_value=color
    else: t.links.new(color,n.inputs['Image'])
    t.links.new(alpha,n.inputs['Alpha'])
    return n.outputs[0]


def _over(t, back, front):
    n=t.nodes.new('CompositorNodeAlphaOver')
    for name,value in [('Background',back),('Foreground',front)]:
        socket=n.inputs.get(name) or n.inputs[1 if name=='Background' else 2]
        if isinstance(value,tuple): socket.default_value=value
        else:t.links.new(value,socket)
    return n.outputs[0]


def _blur(t, socket, size=4):
    n=t.nodes.new('CompositorNodeBlur')
    if 'Size' in n.inputs: n.inputs['Size'].default_value=(size,size)
    else:n.size_x=n.size_y=size
    t.links.new(socket,n.inputs['Image'])
    return n.outputs[0]


def is_emissive(material):
    """Explicit tag wins; low cloth fill emission is deliberately not a light source."""
    if 'rainfall_emissive' in material:return bool(material['rainfall_emissive'])
    if material.name.startswith(('Ember','Core')):return True
    return any(n.type=='EMISSION' for n in material.node_tree.nodes) if material.use_nodes else False


def normal_material(flat=False):
    name='_Rainfall normal flat' if flat else '_Rainfall normal camera'
    m=bpy.data.materials.get(name)
    if m:return m
    m=bpy.data.materials.new(name);m.use_nodes=True
    t=m.node_tree;t.nodes.clear()
    out=t.nodes.new('ShaderNodeOutputMaterial');em=t.nodes.new('ShaderNodeEmission')
    t.links.new(em.outputs[0],out.inputs['Surface'])
    if flat:em.inputs['Color'].default_value=(.5,.5,1,1)
    else:
        geo=t.nodes.new('ShaderNodeNewGeometry')
        transform=t.nodes.new('ShaderNodeVectorTransform');transform.vector_type='NORMAL';transform.convert_from='WORLD';transform.convert_to='CAMERA'
        t.links.new(geo.outputs['Normal'],transform.inputs[0])
        scale=t.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs['Scale'].default_value=.5
        flip=t.nodes.new('ShaderNodeVectorMath');flip.operation='MULTIPLY';flip.inputs[1].default_value=(1,1,-1)
        # Vector Transform camera uses a forward-positive Z; OpenGL normals need viewer-positive Z.
        t.links.new(transform.outputs[0],flip.inputs[0]);t.links.new(flip.outputs[0],scale.inputs[0])
        add=t.nodes.new('ShaderNodeVectorMath');add.operation='ADD';add.inputs[1].default_value=(.5,.5,.5)
        t.links.new(scale.outputs[0],add.inputs[0]);t.links.new(add.outputs[0],em.inputs['Color'])
    return m


def emission_material(source):
    name='_Rainfall emission '+source.name
    m=bpy.data.materials.get(name)
    if m:return m
    m=bpy.data.materials.new(name);m.use_nodes=True
    t=m.node_tree;t.nodes.clear();out=t.nodes.new('ShaderNodeOutputMaterial');em=t.nodes.new('ShaderNodeEmission');t.links.new(em.outputs[0],out.inputs['Surface'])
    color=(0,0,0,1)
    if is_emissive(source):
        p=next((n for n in source.node_tree.nodes if n.type in {'BSDF_PRINCIPLED','EMISSION'}),None)
        if p:color=tuple(p.inputs['Emission Color' if p.type=='BSDF_PRINCIPLED' else 'Color'].default_value)
    em.inputs['Color'].default_value=color
    return m


@contextmanager
def _pass_state(scene, kind):
    old_group=getattr(scene,'compositing_node_group',None)
    settings=(scene.view_settings.view_transform,scene.view_settings.look,scene.view_settings.exposure,scene.view_settings.gamma,scene.render.use_freestyle,scene.render.filepath,scene.use_nodes)
    slots=[]
    try:
        scene.view_settings.view_transform='Raw';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
        scene.render.film_transparent=True;scene.render.use_freestyle=False
        for obj in scene.objects:
            if obj.type not in {'MESH','CURVE','SURFACE','FONT','META'}:continue
            for slot in obj.material_slots:
                src=slot.material
                if src:
                    slots.append((slot,src))
                    slot.material=normal_material(is_emissive(src) or bool(src.get('rainfall_flat_normal',False))) if kind=='normal' else emission_material(src)
        yield
    finally:
        for slot,src in slots:slot.material=src
        scene.view_settings.view_transform,scene.view_settings.look,scene.view_settings.exposure,scene.view_settings.gamma,scene.render.use_freestyle,scene.render.filepath,scene.use_nodes=settings
        if hasattr(scene,'compositing_node_group'):
            temp=scene.compositing_node_group;scene.compositing_node_group=old_group
            if temp and temp!=old_group:bpy.data.node_groups.remove(temp)


def _render_pass(output_path, diffuse_path, scene, kind):
    with _pass_state(scene,kind):
        t,out=_tree(scene,'Rainfall '+kind)
        r=t.nodes.new('CompositorNodeRLayers');r.scene=scene
        im=None
        if diffuse_path:
            im=bpy.data.images.load(str(diffuse_path),check_existing=False)
            n=t.nodes.new('CompositorNodeImage');n.image=im;alpha=n.outputs['Alpha']
        else:alpha=r.outputs['Alpha']
        base=(.5,.5,1,1) if kind=='normal' else (0,0,0,1)
        color=_over(t,base,r.outputs['Image'])
        if kind=='emission':
            blur=_blur(t,color,5)
            mix=t.nodes.new('ShaderNodeMixRGB');mix.blend_type='ADD';mix.inputs[0].default_value=.35
            t.links.new(color,mix.inputs[1]);t.links.new(blur,mix.inputs[2]);color=mix.outputs[0]
        t.links.new(_setalpha(t,color,alpha),out.inputs['Image'])
        scene.render.filepath=str(output_path);Path(output_path).parent.mkdir(parents=True,exist_ok=True)
        scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.image_settings.color_depth='8'
        bpy.ops.render.render(write_still=True,scene=scene.name)
        if kind=='normal':
            # Blender's premultiplied render writer zeros RGB at alpha=0.
            # Store the required neutral padding using Blender Image, without changing alpha.
            import numpy as np
            pad=bpy.data.images.load(str(output_path),check_existing=False)
            pad.colorspace_settings.name='Non-Color';pad.alpha_mode='STRAIGHT'
            pixels=np.empty(len(pad.pixels),dtype=np.float32);pad.pixels.foreach_get(pixels)
            pixels=pixels.reshape((-1,4));pixels[pixels[:,3]==0,:3]=(128/255,128/255,1)
            pad.pixels.foreach_set(pixels.ravel());pad.filepath_raw=str(output_path);pad.file_format='PNG';pad.save();bpy.data.images.remove(pad)
        if im:bpy.data.images.remove(im)


def render_normal_pass(output_path, diffuse_path=None, scene=None):
    """Smooth shading world normal -> camera NORMAL -> .5*n+.5, Raw, +Y up, +Z viewer.
    Emissive effects use flat (0,0,1). Loaded diffuse alpha includes outline/halo.
    Transparent shaders should be tagged rainfall_flat_normal; diffuse alpha is authoritative.
    """
    _render_pass(output_path,diffuse_path,scene or bpy.context.scene,'normal')


def render_emission_pass(output_path, diffuse_path=None, scene=None):
    """Only tagged light sources emit; cloth readability fill stays black."""
    _render_pass(output_path,diffuse_path,scene or bpy.context.scene,'emission')


def setup_diffuse_compositor(scene):
    """2px tinted outline and soft halo from the explicit emissive AOV, in Blender."""
    for mat in list(bpy.data.materials):
        if not mat.use_nodes or mat.name.startswith('_Rainfall'):continue
        t=mat.node_tree
        a=next((n for n in t.nodes if n.type=='OUTPUT_AOV' and n.aov_name=='RainfallGlow'),None)
        if not a:a=t.nodes.new('ShaderNodeOutputAOV');a.aov_name='RainfallGlow'
        a.inputs['Color'].default_value=(1,1,1,1) if is_emissive(mat) else (0,0,0,1)
    layer=scene.view_layers[0]
    if not layer.aovs.get('RainfallGlow'):
        a=layer.aovs.add();a.name='RainfallGlow';a.type='COLOR'
    t,out=_tree(scene,'Ardent diffuse finish')
    r=t.nodes.new('CompositorNodeRLayers');r.scene=scene
    dil=t.nodes.new('CompositorNodeDilateErode')
    if 'Size' in dil.inputs:dil.inputs['Size'].default_value=2
    else:dil.distance=2
    t.links.new(r.outputs['Alpha'],dil.inputs[0])
    glow=_blur(t,r.outputs['RainfallGlow'],5)
    mult=t.nodes.new('ShaderNodeMath');mult.operation='MULTIPLY';mult.inputs[1].default_value=.35;t.links.new(glow,mult.inputs[0])
    halo=_setalpha(t,(1,.195,.012,1),mult.outputs[0])
    outline=_setalpha(t,(.0103,.008,.0144,1),dil.outputs[0])
    color=_over(t,_over(t,halo,outline),r.outputs['Image'])
    t.links.new(color,out.inputs['Image'])


def validate_normal_convention(directory):
    """Render smooth test sphere; sample PNG through Blender, +X/right +Y/up +Z/front."""
    import math
    directory=Path(directory);directory.mkdir(parents=True,exist_ok=True)
    old=bpy.context.window.scene
    s=bpy.data.scenes.new('_Rainfall normal verification');bpy.context.window.scene=s
    s.render.engine='BLENDER_EEVEE';s.render.resolution_x=s.render.resolution_y=128;s.render.resolution_percentage=100;s.render.film_transparent=True
    if hasattr(s,'eevee'):s.eevee.taa_render_samples=24
    cam=bpy.data.objects.new('_verify camera',bpy.data.cameras.new('_verify camera'));s.collection.objects.link(cam);cam.location=(0,0,4);cam.data.type='ORTHO';cam.data.ortho_scale=2.4;s.camera=cam
    bpy.ops.mesh.primitive_uv_sphere_add(segments=64,ring_count=32)
    sphere=bpy.context.object
    for p in sphere.data.polygons:p.use_smooth=True
    sphere.data.materials.append(bpy.data.materials.new('_verify diffuse'))
    path=directory/'sphere_normal.png'
    try:
        render_normal_pass(path,scene=s)
        im=bpy.data.images.load(str(path),check_existing=False);im.colorspace_settings.name='Non-Color'
        pix=list(im.pixels)
        def sample(x,y):return [round(255*v) for v in pix[4*(y*128+x):4*(y*128+x)+4]]
        right,top,center=sample(92,64),sample(64,92),sample(64,64)
        result={'right':right,'top':top,'center':center,'passed':right[0]>128 and top[1]>128 and center[2]>=250}
        bpy.data.images.remove(im)
        assert result['passed'],result
        # Lit reconstruction: a material decodes the rendered normal and dots a camera light.
        m=bpy.data.materials.new('_verification normal relight');m.use_nodes=True;t=m.node_tree;t.nodes.clear()
        tex=t.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(path),check_existing=False);tex.image.colorspace_settings.name='Non-Color'
        tc=t.nodes.new('ShaderNodeTexCoord');t.links.new(tc.outputs['Window'],tex.inputs['Vector'])
        sub=t.nodes.new('ShaderNodeVectorMath');sub.operation='SUBTRACT';sub.inputs[1].default_value=(.5,.5,.5);t.links.new(tex.outputs['Color'],sub.inputs[0])
        norm=t.nodes.new('ShaderNodeVectorMath');norm.operation='NORMALIZE';t.links.new(sub.outputs[0],norm.inputs[0])
        dot=t.nodes.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';dot.inputs[1].default_value=(.4,.5,.768);t.links.new(norm.outputs[0],dot.inputs[0])
        em=t.nodes.new('ShaderNodeEmission');t.links.new(dot.outputs['Value'],em.inputs['Color']);out=t.nodes.new('ShaderNodeOutputMaterial');t.links.new(em.outputs[0],out.inputs[0]);sphere.data.materials[0]=m
        s.use_nodes=False;s.view_settings.view_transform='Standard';s.render.filepath=str(directory/'sphere_relit.png');bpy.ops.render.render(write_still=True,scene=s.name)
        return result
    finally:
        bpy.context.window.scene=old
        for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.scenes.remove(s)






