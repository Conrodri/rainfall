"""Pipeline Blender des boss. Axe avant = -Y, Z vertical, 1 u = 1 m."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[3]
DIRECTIONS = {'e': math.pi/2, 'se': math.pi/4, 's': 0, 'sw': -math.pi/4,
              'w': -math.pi/2, 'nw': -3*math.pi/4, 'n': math.pi, 'ne': 3*math.pi/4}

def material(name, color, metallic=0, roughness=.5, emission=0, grain=False):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    n=m.node_tree.nodes; p=n.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Metallic'].default_value=metallic; p.inputs['Roughness'].default_value=roughness
    p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    if grain:
        tex=n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=7
        tex.inputs['Detail'].default_value=3
        coord=n.new('ShaderNodeTexCoord'); mapping=n.new('ShaderNodeVectorMath'); mapping.operation='MULTIPLY'; mapping.inputs[1].default_value=(5,5,.4)
        m.node_tree.links.new(coord.outputs['Generated'],mapping.inputs[0]); m.node_tree.links.new(mapping.outputs[0],tex.inputs['Vector'])
        bump=n.new('ShaderNodeBump'); bump.inputs['Strength'].default_value=.23; bump.inputs['Distance'].default_value=.045
        m.node_tree.links.new(tex.outputs['Fac'],bump.inputs['Height']); m.node_tree.links.new(bump.outputs[0],p.inputs['Normal'])
    return m

def empty(name, loc=(0,0,0), parent=None):
    ob=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(ob); ob.location=loc; ob.parent=parent; return ob

def finish(ob,name,mat,parent=None,bevel=0):
    ob.name=name; ob.parent=parent
    if mat: ob.data.materials.append(mat)
    if bevel:
        mod=ob.modifiers.new('Aretes usees','BEVEL'); mod.width=bevel; mod.segments=3
        mod=ob.modifiers.new('Normales ponderees','WEIGHTED_NORMAL')
    return ob

def box(name,loc,size,mat,parent=None,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); ob=bpy.context.object
    ob.dimensions=size; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    return finish(ob,name,mat,parent,bevel)

def sphere(name,loc,scale,mat,parent=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=loc); ob=bpy.context.object; ob.scale=scale
    for p in ob.data.polygons:p.use_smooth=True
    return finish(ob,name,mat,parent)

def rod(name,a,b,r,mat,parent=None):
    a,b=Vector(a),Vector(b); bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=r,depth=(b-a).length,location=(a+b)/2)
    ob=bpy.context.object; ob.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish(ob,name,mat,parent,.012)

def tube(name,points,r,mat,parent=None):
    c=bpy.data.curves.new(name,'CURVE'); c.dimensions='3D'; c.bevel_depth=r; c.bevel_resolution=3
    s=c.splines.new('BEZIER'); s.bezier_points.add(len(points)-1)
    for bp,pt in zip(s.bezier_points,points):bp.co=pt; bp.handle_left_type='AUTO'; bp.handle_right_type='AUTO'
    ob=bpy.data.objects.new(name,c); bpy.context.collection.objects.link(ob); ob.parent=parent; ob.data.materials.append(mat); return ob

def ring(name,loc,r,thick,mat,parent=None,rotation=(math.pi/2,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=64,minor_segments=12,location=loc,major_radius=r,minor_radius=thick,rotation=rotation)
    ob=bpy.context.object
    for p in ob.data.polygons:p.use_smooth=True
    return finish(ob,name,mat,parent)

def setup_scene(scale=5.0):
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    s=bpy.context.scene; s.render.engine='CYCLES' if False else 'BLENDER_EEVEE'
    s.render.resolution_x=s.render.resolution_y=512; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'; s.render.film_transparent=True
    s.view_settings.view_transform='Standard'; s.view_settings.look='None'; s.view_settings.exposure=0; s.view_settings.gamma=1
    s.world.color=(.18,.18,.18)
    bpy.ops.object.camera_add(location=(0,-10*math.cos(math.radians(55)),10*math.sin(math.radians(55))))
    cam=bpy.context.object; cam.name='Camera_ortho_55'; cam.rotation_euler=(math.radians(35),0,0); cam.data.type='ORTHO';cam.data.ortho_scale=scale
    # Fixed ground origin at 62%; front edge of the deep feet sits near 70%.
    cam.location += cam.rotation_euler.to_matrix() @ Vector((0,scale*.12,0)); s.camera=cam
    bpy.ops.object.light_add(type='SUN',location=(-4,-6,8)); sun=bpy.context.object
    sun.name='Sun_chaud_haut_gauche';sun.data.energy=2.5;sun.data.color=(1,.76,.53);sun.data.angle=.15
    sun.rotation_euler=(Vector((0,0,1))-sun.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.light_add(type='AREA',location=(4,1,6)); fill=bpy.context.object;fill.name='Fill_froid';fill.data.energy=450;fill.data.color=(.5,.66,.85);fill.data.shape='DISK';fill.data.size=5
    fill.rotation_euler=(-fill.location).to_track_quat('-Z','Y').to_euler()
    s.render.image_settings.color_depth='8'
    s.view_layers[0].use_pass_normal=True; s.view_layers[0].use_pass_emit=True
    return s

def configure_passes(path):
    """Normal Blender WORLD -> ecran (droite, haut, vers camera), encodage lineaire."""
    s=bpy.context.scene
    if hasattr(s,'use_nodes'): s.use_nodes=True
    tree=getattr(s,'node_tree',None)
    if tree is None:
        tree=bpy.data.node_groups.new('Boss_passes','CompositorNodeTree'); s.compositing_node_group=tree
    tree.nodes.clear(); n=tree.nodes; links=tree.links
    rl=n.new('CompositorNodeRLayers')
    if not any(x.name=='Image' and x.in_out=='OUTPUT' for x in tree.interface.items_tree):
        tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    out=n.new('NodeGroupOutput');links.new(rl.outputs['Image'],out.inputs['Image'])
    # Dot products explicitly use the fixed camera basis, never the rotating model.
    basis=s.camera.matrix_world.to_3x3(); channels=[]
    for i in range(3):
        dot=n.new('ShaderNodeVectorMath');dot.operation='DOT_PRODUCT';dot.inputs[1].default_value=basis.col[i]
        links.new(rl.outputs['Normal'],dot.inputs[0])
        mul=n.new('ShaderNodeMath');mul.operation='MULTIPLY_ADD';mul.inputs[1].default_value=.5;mul.inputs[2].default_value=.5
        links.new(dot.outputs['Value'],mul.inputs[0]);channels.append(mul.outputs[0])
    combine=n.new('CompositorNodeCombineColor')
    for i,ch in enumerate(channels): links.new(ch,combine.inputs[i])
    links.new(rl.outputs['Alpha'],combine.inputs[3])
    for suffix,socket in [('_n',combine.outputs[0]),('_e',rl.outputs['Emission'])]:
        alpha=n.new('CompositorNodeSetAlpha');links.new(socket,alpha.inputs['Image']);links.new(rl.outputs['Alpha'],alpha.inputs['Alpha'])
        f=n.new('CompositorNodeOutputFile')
        if hasattr(f,'base_path'):
            f.base_path=str(path.parent);f.file_slots[0].path=path.stem+suffix+'__'
            f.format.media_type='IMAGE';f.format.file_format='PNG';f.format.color_mode='RGBA';f.format.color_depth='8'
            if suffix=='_n': f.format.color_management='OVERRIDE';f.format.view_settings.view_transform='Raw'
            links.new(alpha.outputs[0],f.inputs[0])
        else:
            f.directory=str(path.parent); f.file_name=path.stem+suffix+'__'
            f.file_output_items.new('RGBA','Image')
            f.format.media_type='IMAGE';f.format.file_format='PNG';f.format.color_mode='RGBA';f.format.color_depth='8'
            if suffix=='_n':f.format.color_management='OVERRIDE';f.format.view_settings.view_transform='Raw'
            links.new(alpha.outputs[0],f.inputs[0])

def render_still(root,pose,path,t=0,direction='s'):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    pose(t);root.rotation_euler.z=DIRECTIONS[direction];bpy.context.view_layer.update()
    configure_passes(path);bpy.context.scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
    for suffix in ('_n','_e'):
        for f in path.parent.glob(path.stem+suffix+'__*.png'):f.replace(path.with_name(path.stem+suffix+'.png'))

def render_animation(root,pose,output,frames,directions=('s',)):
    """pose(t), t dans [0,1[, doit etre absolue et deterministe."""
    for direction in directions:
        for i in range(frames):render_still(root,pose,Path(output)/f'{direction}_{i:02d}.png',i/frames,direction)






