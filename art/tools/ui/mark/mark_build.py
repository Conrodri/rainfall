import sys, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[4]
sys.path[:0]=[str(ROOT/'art/tools/ui'),str(ROOT/'art/tools/cel')]
import bpy
from mathutils import Vector
from ui_lib import reset_scene, setup_render, rgba, mat, frame_object_ortho
import cel_style as cel

OUT=ROOT/'art/renders/ui_mark'

def plate(name, pts, y, depth, material):
    n=len(pts); verts=[(x,yy,z) for yy in (y-depth/2,y+depth/2) for x,z in pts]
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    import bmesh
    bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces)); bm.to_mesh(mesh); bm.free()
    o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); o.data.materials.append(material)
    b=o.modifiers.new('Arêtes taillées','BEVEL'); b.width=.018; b.segments=1
    o.modifiers.new('Normales pondérées','WEIGHTED_NORMAL')
    return o

def render():
    reset_scene(); setup_render(192); cel.setup_scene(samples=16)
    s=bpy.context.scene; s.render.resolution_x=s.render.resolution_y=192
    s.world.node_tree.nodes['Background'].inputs[1].default_value=.15
    white=mat('#F2F2F2',rough=.55); light=mat('#D8D8D8',rough=.6); dark=mat('#30343A',rough=.7)
    # Massive notched diamond seal with a hollow, recessed center.
    outer=[(0,1),(.21,.69),(.57,.84),(.68,.48),(1,0),(.68,-.48),(.57,-.84),(.21,-.69),(0,-1),(-.21,-.69),(-.57,-.84),(-.68,-.48),(-1,0),(-.68,.48),(-.57,.84),(-.21,.69)]
    inner=[(0,.49),(.13,.24),(.39,0),(.13,-.24),(0,-.49),(-.13,-.24),(-.39,0),(-.13,.24)]
    # Backing and raised inset ring; front face center stays open.
    backing=plate('Sceau',outer,0,.22,white)
    ring=plate('Contour intérieur',inner,-.145,.035,light)
    # Cut a central octagonal aperture through the seal using a boolean.
    cutter=plate('Ouverture',[(x*.48,z*.48) for x,z in inner],0,.5,dark)
    mod=backing.modifiers.new('Centre évidé','BOOLEAN'); mod.object=cutter
    bpy.context.view_layer.objects.active=backing; bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    # Dark hairline rune inside the cavity and four clipped notch marks.
    def stroke(name, pts, radius=.018):
        d=bpy.data.curves.new(name,'CURVE'); d.dimensions='3D'; d.bevel_depth=radius; d.bevel_resolution=2
        sp=d.splines.new('POLY'); sp.points.add(len(pts)-1)
        for p,(x,z) in zip(sp.points,pts): p.co=(x,-.185,z,1)
        ob=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(ob); ob.data.materials.append(dark)
    stroke('Rune',[(0,.25),(-.1,.08),(0,0),(.1,-.08),(0,-.25)])
    for sgn in (-1,1):
        stroke('Entaille',[(sgn*.7,.20),(sgn*.51,.31)],.022)
        stroke('Entaille',[(sgn*.7,-.20),(sgn*.51,-.31)],.022)
    objs=[o for o in s.objects if o.type in {'MESH','CURVE'}]
    frame_object_ortho(objs,margin=.10)
    cel.toon_materials('icon')
    def passes(path):
        tree=bpy.data.node_groups.new('Mark cel','CompositorNodeTree'); s.compositing_node_group=tree
        tree.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
        rl=tree.nodes.new('CompositorNodeRLayers'); out=tree.nodes.new('NodeGroupOutput'); tree.links.new(rl.outputs['Image'],out.inputs['Image'])
    cel.cel_passes(OUT/'raw'/'mark.png','icon',base_configure=passes,normals=False)
    s.render.filepath=str(OUT/'raw'/'mark.png'); bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/ui/mark.blend'))

if __name__=='__main__': render()
