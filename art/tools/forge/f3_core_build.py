"""Storm core replacement: f2 make_core primitives, direct final-size cel renders."""
import sys, math, inspect, subprocess
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT/'art/tools/forge'), str(ROOT/'art/tools/iso')]
from f2_build import setup, sphere, mat, cylinder, curve, plate, aim, cel, bpy, rgba
from mathutils import Vector, Matrix
import iso_rig

ICON = ROOT/'game/assets/sprites/icons/storm_core.png'
PICK = ROOT/'game/assets/sprites/pickups/storm_core.png'


def make_core(pickup=False):
    # Retain f2's core/shell/copper/lightning construction, opening the shell into six claws.
    silver = mat('#D7E3DA', rough=.44, metal=.55)
    copper = mat('#D9803A', rough=.42, metal=.6)
    edge = mat('#F0DFB5', rough=.4, metal=.5)
    glass = mat('#A8D4DD', rough=.25)
    cyan = mat('#5FD4E8', emit_hex='#5FD4E8', emit_strength=1.65)
    cyan['core_accent'] = True
    sphere((0,0,0),(.76,.76,.76),glass,'Translucent storm sphere')
    for i in range(6):
        a=math.radians(i*60)
        profile=[(.23,-.83),(.46,-.68),(.75,-.39),(.85,0),(.75,.39),(.46,.68),(.23,.83)]
        curve([(r*math.cos(a),r*math.sin(a),z) for r,z in profile],.064,silver,'Silver cage claw')
        for z in (-.64,.64):
            sphere((.5*math.cos(a),.5*math.sin(a),z),(.083,.083,.083),copper,'Copper claw rivet')
    for z in (-.82,.82):
        cylinder((0,0,z),.28,.15,copper,6,'Hex copper socket')
        cylinder((0,0,z+(.09 if z>0 else -.09)),.21,.05,edge,6,'Pale socket bevel')
    bolt=[(.06,.57),(-.27,.06),(-.065,.06),(-.16,-.54),(.29,.14),(.065,.14)]
    plate(bolt,.045,cyan,'Enclosed cyan lightning',y=-.60,bevel=.007)
    curve([(-.13,-.57,.23),(-.36,-.49,.32),(-.29,-.46,.04)],.018,cyan,'Lightning branch left')
    curve([(.13,-.57,-.10),(.36,-.48,-.18),(.29,-.45,-.34)],.019,cyan,'Lightning branch right')
    # The same physical core faces the MAP camera in the pickup.
    rot=Matrix.Rotation(math.pi/4 if pickup else 0,4,'Z')
    for ob in list(bpy.context.scene.objects):
        if ob.type in ('MESH','CURVE'):
            ob.matrix_world=Matrix.Translation((0,0,.94 if pickup else 0)) @ rot @ ob.matrix_world
    cel.toon_materials('icon')
    # A transparent surface around the actual bolt, retaining cel lighting on the glass.
    nodes=glass.node_tree.nodes; links=glass.node_tree.links
    out=next(n for n in nodes if n.type=='OUTPUT_MATERIAL')
    source=out.inputs['Surface'].links[0].from_socket
    trans=nodes.new('ShaderNodeBsdfTransparent'); mix=nodes.new('ShaderNodeMixShader')
    mix.inputs[0].default_value=.62
    links.new(trans.outputs[0],mix.inputs[1]); links.new(source,mix.inputs[2]); links.new(mix.outputs[0],out.inputs['Surface'])
    glass.surface_render_method='BLENDED'


def render(path):
    s=bpy.context.scene
    s.render.filepath=str(path); s.render.image_settings.compression=100
    bpy.ops.render.render(write_still=True)


def emission(path):
    restored=[]
    for material in bpy.data.materials:
        if not material.use_nodes or material.get('core_accent'): continue
        for n in material.node_tree.nodes:
            if n.type!='EMISSION': continue
            sock=n.inputs['Color']; incoming=list(sock.links)
            restored.append((material,sock,tuple(sock.default_value),[(l.from_socket,l.to_socket) for l in incoming]))
            for l in incoming: material.node_tree.links.remove(l)
            sock.default_value=(0,0,0,1)
    render(path.with_name('storm_core_e.png'))
    for material,sock,color,links in restored:
        sock.default_value=color
        for start,end in links: material.node_tree.links.new(start,end)


def shadow(path):
    # iso_rig.render_shadow_decal projection; direct 96px, no supersampling/resize.
    s=bpy.context.scene
    originals=[o for o in s.objects if o.type in ('MESH','CURVE')]
    ray=Vector((.04,.18,-1))
    black=bpy.data.materials.new('Shadow decal grayscale'); black.use_nodes=True
    n=black.node_tree.nodes; n.clear(); out=n.new('ShaderNodeOutputMaterial'); em=n.new('ShaderNodeEmission')
    em.inputs[0].default_value=(.025,.025,.025,1); black.node_tree.links.new(em.outputs[0],out.inputs[0])
    transparent=n.new('ShaderNodeBsdfTransparent'); mix=n.new('ShaderNodeMixShader'); mix.inputs[0].default_value=.43
    black.node_tree.links.new(transparent.outputs[0],mix.inputs[1]); black.node_tree.links.new(em.outputs[0],mix.inputs[2]); black.node_tree.links.new(mix.outputs[0],out.inputs[0])
    black.surface_render_method='BLENDED'
    deps=bpy.context.evaluated_depsgraph_get(); projections=[]
    for ob in originals:
        ev=ob.evaluated_get(deps); mesh=ev.to_mesh(); verts=[]
        for v in mesh.vertices:
            w=ob.matrix_world@v.co; w-=ray*(w.z/ray.z); verts.append(tuple(w))
        data=bpy.data.meshes.new('Projected cage'); data.from_pydata(verts,[],[tuple(p.vertices) for p in mesh.polygons]); ev.to_mesh_clear()
        sh=bpy.data.objects.new('Projected cage',data); s.collection.objects.link(sh); sh.data.materials.append(black); projections.append(sh)
    for ob in originals: ob.hide_render=True
    render(path.with_name('storm_core_shadow.png'))
    for ob in originals: ob.hide_render=False
    for ob in projections: bpy.data.objects.remove(ob,do_unlink=True)


def build(pickup):
    size=96 if pickup else 256
    s=setup('Storm core pickup' if pickup else 'Storm core icon',size)
    s.view_layers[0].use_pass_normal=False
    make_core(pickup)
    if pickup:
        iso_rig.create_rig('MAP',(96,96),target=(0,0,.94),reset=False)
        # create_rig defaults to 2x: override to contractual DIRECT final pixels.
        s.render.resolution_x=s.render.resolution_y=96
        s.camera.data.ortho_scale=2.55
    else:
        s.camera.location=(0,-7,0); aim(s.camera,(0,0,0)); s.camera.data.ortho_scale=2.32
    cel.setup_scene(samples=16); s.view_layers[0].use_pass_normal=False
    path=PICK if pickup else ICON
    render(path); emission(path)
    if pickup: shadow(path)


def contact():
    # Pillow only assembles and measures; all delivered sprites rendered at final dimensions.
    sys.path.insert(0,str(ROOT/'art/tools/vendor'))
    from PIL import Image
    ICON=ROOT/'game/assets/sprites/icons/storm_core.png'
    PICK=ROOT/'game/assets/sprites/pickups/storm_core.png'
    board=Image.new('RGB',(512,288),'#30201C')
    icon=Image.open(ICON).convert('RGBA'); board.paste(icon,(16,16),icon)
    ground=Image.new('RGBA',(208,288),'#24201E')
    shadow_im=Image.open(PICK.with_name('storm_core_shadow.png')).convert('RGBA')
    ground.alpha_composite(shadow_im,(56,96)); ground.alpha_composite(Image.open(PICK).convert('RGBA'),(56,96))
    board.paste(ground.convert('RGB'),(304,0))
    (ROOT/'art/renders/forge').mkdir(parents=True,exist_ok=True)
    board.save(ROOT/'art/renders/forge/f3_core_contact.png',optimize=True)


if __name__=='__main__':
    build(False); build(True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/blender/forge/f3_core.blend'))
    code='import sys\nfrom pathlib import Path\nROOT=Path('+repr(str(ROOT))+')\n'+inspect.getsource(contact)+'\ncontact()'
    subprocess.run([str(Path.home()/'AppData/Local/Python/bin/python.exe'),'-c',code],check=True)
    print('PASS f3_core: 256 icon, 96 MAP pickup, emission, shadow; direct Eevee 16 samples',flush=True)
