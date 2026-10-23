"""Bibliothèque de volumes UI. À importer dans Blender en mode background."""
import bpy, math, os, sys, subprocess
from mathutils import Vector
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]

def rgba(h):
    h=h.lstrip('#')
    rgb=[int(h[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb)+(1,)

def mat(color_hex='#7C8898', rough=.45, metal=0, emit_hex=None, emit_strength=0):
    m=bpy.data.materials.new(color_hex); m.diffuse_color=rgba(color_hex); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=rgba(color_hex)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    if emit_hex:
        p.inputs['Emission Color'].default_value=rgba(emit_hex)
        p.inputs['Emission Strength'].default_value=emit_strength
    return m

def reset_scene():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for group in (bpy.data.meshes,bpy.data.curves,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
        for block in list(group):
            if block.users==0: group.remove(block)

def aim(obj, target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

def setup_render(res=512):
    s=bpy.context.scene; s.render.engine='BLENDER_EEVEE'
    s.render.resolution_x=s.render.resolution_y=res; s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG'; s.render.image_settings.color_mode='RGBA'
    s.render.film_transparent=True; s.view_settings.view_transform='Standard'
    s.view_settings.look='None'
    s.view_settings.exposure=0; s.view_settings.gamma=1
    if hasattr(s,'eevee'): s.eevee.taa_render_samples=128
    s.world=bpy.data.worlds.new('Ambiance douce'); s.world.use_nodes=True
    s.world.node_tree.nodes['Background'].inputs[0].default_value=rgba('#8FA8C8')
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.35
    bpy.ops.object.camera_add(location=(0,-9,4.785)); c=bpy.context.object
    c.name='Camera_UI_28deg'; c.data.type='ORTHO'; c.data.ortho_scale=4; aim(c,(0,0,0)); s.camera=c
    for name,loc,color,power in [('Sun chaud',(-4,-5,7),'#FFE2C0',2.2),('Fill froid',(4,-2,5),'#8FA8C8',.85)]:
        d=bpy.data.lights.new(name,'SUN'); d.energy=power; d.color=rgba(color)[:3]; d.angle=math.radians(18)
        o=bpy.data.objects.new(name,d); s.collection.objects.link(o); o.location=loc; aim(o,(0,0,0))
    return c

def finish_obj(o, material, name):
    o.name=name
    if material: o.data.materials.append(material)
    return o

def bevelled_box(loc=(0,0,0), scale=(1,1,1), material=None, bevel=.08, name='Boite'):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object
    o.scale=scale; bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    b=o.modifiers.new('Biseaux','BEVEL'); b.width=bevel; b.segments=3
    o.modifiers.new('Normales','WEIGHTED_NORMAL')
    return finish_obj(o,material,name)

def sphere(loc=(0,0,0), scale=(1,1,1), material=None, name='Sphere'):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=loc)
    o=bpy.context.object; o.scale=scale
    for p in o.data.polygons: p.use_smooth=True
    return finish_obj(o,material,name)

def cylinder(loc=(0,0,0), radius=.5, depth=.2, material=None, vertices=32, name='Cylindre'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bpy.context.object
    b=o.modifiers.new('Bord doux','BEVEL'); b.width=.025; b.segments=2
    o.modifiers.new('Normales','WEIGHTED_NORMAL')
    return finish_obj(o,material,name)

def torus(loc=(0,0,0), major=.6, minor=.12, material=None, name='Anneau'):
    bpy.ops.mesh.primitive_torus_add(major_segments=48,minor_segments=12,location=loc,major_radius=major,minor_radius=minor,rotation=(math.pi/2,0,0))
    o=bpy.context.object
    for p in o.data.polygons:p.use_smooth=True
    return finish_obj(o,material,name)

def cone(loc=(0,0,0), radius=.5, depth=1, material=None, vertices=8, radius2=0, name='Cone'):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius2,depth=depth,location=loc)
    return finish_obj(bpy.context.object,material,name)

def crystal(loc=(0,0,0), radius=.4, height=1.5, material=None, name='Cristal'):
    n=6; verts=[(0,0,-height*.5)]
    for z,r in [(-height*.2,radius*.8),(height*.2,radius)]:
        verts += [(r*math.cos(i*math.tau/n),r*math.sin(i*math.tau/n),z) for i in range(n)]
    verts.append((radius*.16,0,height*.5)); faces=[]
    for i in range(n):
        j=(i+1)%n; faces += [(0,1+j,1+i),(1+i,1+j,7+j,7+i),(7+i,7+j,13)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); o.location=loc
    return finish_obj(o,material,name)

def curve(points, radius=.06, material=None, name='Courbe', cyclic=False):
    d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.resolution_u=16; d.bevel_depth=radius; d.bevel_resolution=3
    sp=d.splines.new('POLY'); sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points):p.co=(*co,1)
    sp.use_cyclic_u=cyclic
    o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o)
    return finish_obj(o,material,name)

def lathe(profile, loc=(0,0,0), material=None, segments=40, name='Lathe'):
    verts=[(r*math.cos(i*math.tau/segments),r*math.sin(i*math.tau/segments),z) for r,z in profile for i in range(segments)]
    faces=[]
    for j in range(len(profile)-1):
        for i in range(segments):
            k=j*segments+i; ni=j*segments+(i+1)%segments
            faces.append((k,ni,ni+segments,k+segments))
    faces += [tuple(reversed(range(segments))),tuple(range((len(profile)-1)*segments,len(profile)*segments))]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); o.location=loc
    for p in mesh.polygons:p.use_smooth=True
    return finish_obj(o,material,name)

def outline(objs, thickness=.018):
    dark=mat('#1a1620',1); dark.use_backface_culling=True
    for o in objs:
        if o.type not in {'MESH','CURVE'}:continue
        bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
        shell=o.copy(); shell.data=o.data.copy(); bpy.context.collection.objects.link(shell); shell.name=o.name+'_contour'
        bpy.ops.object.select_all(action='DESELECT'); shell.select_set(True); bpy.context.view_layer.objects.active=shell
        bpy.ops.object.convert(target='MESH'); shell=bpy.context.object
        # Coque élargie le long des normales, faces inversées, dos masqués.
        for mod in list(shell.modifiers):shell.modifiers.remove(mod)
        import bmesh
        bm=bmesh.new(); bm.from_mesh(shell.data); bm.normal_update()
        for v in bm.verts:v.co += v.normal*thickness
        bmesh.ops.reverse_faces(bm,faces=list(bm.faces)); bm.to_mesh(shell.data); bm.free()
        shell.data.materials.clear(); shell.data.materials.append(dark)

def frame_object_ortho(objs, margin=.12):
    bpy.context.view_layer.update(); c=bpy.context.scene.camera
    inv=c.rotation_euler.to_matrix().transposed()
    pts=[inv@(o.matrix_world@Vector(p)) for o in objs if o.type in {'MESH','CURVE'} for p in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3))); hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)))
    center=c.rotation_euler.to_matrix()@((lo+hi)*.5)
    c.location=center+c.rotation_euler.to_matrix()@Vector((0,0,10))
    c.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)*(1+margin*2)

def render_to(path):
    Path(path).parent.mkdir(parents=True,exist_ok=True)
    bpy.context.scene.render.filepath=str(path); bpy.ops.render.render(write_still=True)

def finalize(path512, path256):
    """Pillow s'exécute hors Blender; -I ignore PYTHONPATH, le script ajoute vendor."""
    subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe','-I',str(Path(__file__).with_name('finalize.py')),str(path512),str(path256)],check=True)
