"""Cel icon pipeline; Blender background only."""
import sys, math, shutil, subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path[:0]=[str(ROOT/'art/tools/ui'),str(ROOT/'art/tools/cel')]
from ui_lib import *
import cel_style as cel
PY=r'C:\Users\const\AppData\Local\Python\bin\python.exe'
RAW=ROOT/'art/renders/items_v2/raw'
DEST=ROOT/'game/assets/sprites/icons/items'
IDS=['eclair_en_bouteille','de_pipe','moisson','lentille_aiguisee']

def reset(ident):
    s=bpy.data.scenes.new(ident); bpy.context.window.scene=s
    reset_scene(); setup_render(512); cel.setup_scene(samples=16)
    for light in s.objects:
        if light.type=='LIGHT':
            warm='chaud' in light.name
            light.data.color=rgba('#FFC287' if warm else '#80A8D9')[:3]
            light.data.energy=2.5 if warm else .35
            light.data.angle=math.radians(8)
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.15
    return s

def plate(points, depth, material, name, y=0, bevel=.015):
    n=len(points); verts=[(x,y+d,z) for d in (-depth/2,depth/2) for x,z in points]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    import bmesh
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.data.materials.append(material)
    if bevel:
        b=o.modifiers.new('Worn edges','BEVEL');b.width=bevel;b.segments=2
        o.modifiers.new('Weighted facets','WEIGHTED_NORMAL')
    return o

def line(points, material, r=.012, y=-.18, name='Inlay'):
    return curve([(x,y,z) for x,z in points],r,material,name)

def disk(x,z,r,material,y=-.18,depth=.04):
    o=cylinder((x,y,z),r,depth,material);o.rotation_euler.x=math.pi/2;return o

def passes(path):
    s=bpy.context.scene
    tree=bpy.data.node_groups.new('Icon cel ink','CompositorNodeTree');s.compositing_node_group=tree
    tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
    rl=tree.nodes.new('CompositorNodeRLayers');out=tree.nodes.new('NodeGroupOutput')
    tree.links.new(rl.outputs['Image'],out.inputs['Image'])

def deliver(ident):
    objs=[o for o in bpy.context.scene.objects if o.type in {'MESH','CURVE'}]
    # Small global yaw retains the face and reveals construction depth.
    from mathutils import Matrix
    bpy.context.view_layer.update()
    rotation=Matrix.Rotation(math.radians(-9),4,'Z')
    for o in objs:o.matrix_world=rotation@o.matrix_world
    if ident in {'eclair_en_bouteille','moisson'}:
        axis=bpy.context.scene.camera.rotation_euler.to_matrix()@Vector((0,0,1))
        tilt=Matrix.Rotation(math.radians(40 if ident=='moisson' else -40),4,axis)
        for o in objs:o.matrix_world=tilt@o.matrix_world
    frame_object_ortho(objs,margin=.065 if ident in {'eclair_en_bouteille','moisson'} else .09)
    if ident in {'eclair_en_bouteille','moisson'}:
        camera=bpy.context.scene.camera;basis=camera.rotation_euler.to_matrix();inv=basis.transposed()
        graph=bpy.context.evaluated_depsgraph_get();points=[]
        for obj in objs:
            evaluated=obj.evaluated_get(graph);mesh=evaluated.to_mesh()
            points.extend(inv@(obj.matrix_world@v.co) for v in mesh.vertices)
            evaluated.to_mesh_clear()
        lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
        hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
        camera.location=basis@((lo+hi)*.5+Vector((0,0,10)))
        camera.data.ortho_scale=max(hi.x-lo.x,hi.y-lo.y)/.875
    cel.toon_materials('icon');RAW.mkdir(parents=True,exist_ok=True)
    raw=RAW/(ident+'.png');cel.cel_passes(raw,'icon',base_configure=passes,normals=False)
    bpy.context.scene.render.filepath=str(raw);bpy.ops.render.render(write_still=True)
    before=ROOT/'art/renders/items_v2/before';before.mkdir(parents=True,exist_ok=True)
    if not (before/(ident+'.png')).exists():shutil.copy2(DEST/(ident+'.png'),before/(ident+'.png'))
    subprocess.run([PY,str(Path(__file__).with_name('check.py')),'--finalize',ident],check=True)

