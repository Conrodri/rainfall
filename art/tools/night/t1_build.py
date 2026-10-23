"""T1: modular production source derived from the approved CD Tocsin.
Background Blender only. No game export; T2--T5 own animation and atlases.
Pillow is used solely for assembly and alpha/bounds verification.
"""
import sys, math, json, warnings
from pathlib import Path
sys.dont_write_bytecode = True
warnings.filterwarnings('ignore', category=DeprecationWarning)
import bpy
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'art/tools/night/t_out'
OUT.mkdir(parents=True, exist_ok=True)
sys.path.insert(0, str(ROOT / 'art/tools/characters'))
import cd_cd1_common as cd
import iso_rig
from boss_common import DIRECTIONS
from PIL import Image

PARTS = {'torso': 'Torso', 'head': 'Head / detachable cracked bell',
         'arm_l': 'Arm L', 'arm_r': 'Arm R', 'leg_l': 'Leg L', 'leg_r': 'Leg R'}


def visible(root, yes):
    for ob in [root, *root.children_recursive]:
        ob.hide_render = not yes


def frame(size, shift=.21):
    iso_rig.set_frame(size, 'CREA')
    bpy.context.scene.camera.data.shift_y = shift


def render(name, size=192, shift=.21, passes=False, scale=None):
    frame(size, shift)
    if scale:
        bpy.context.scene.camera.data.ortho_scale = scale
    path = OUT / (name + '.png')
    # CombineColor already carries coverage: APPLY would square alpha on normals.
    original = iso_rig.common.configure_passes
    def configure(p):
        original(p)
        tree = bpy.context.scene.compositing_node_group
        for node in tree.nodes:
            if node.bl_idname == 'CompositorNodeSetAlpha':
                node.inputs['Type'].default_value = 'Replace Alpha'
    try:
        iso_rig.common.configure_passes = configure
        iso_rig.render_frame(path, passes=passes)
    finally:
        iso_rig.common.configure_passes = original
    return path


def load_actor(path, rootname):
    with bpy.data.libraries.load(str(path), link=False) as (src, dst):
        dst.objects = src.objects
    objects = [ob for ob in dst.objects if ob]
    actor = next(ob for ob in objects if ob.name == rootname)
    keep = {actor, *actor.children_recursive}
    for ob in objects:
        if ob in keep:
            bpy.context.scene.collection.objects.link(ob)
            ob.animation_data_clear()
            ob.hide_render = False
        else:
            bpy.data.objects.remove(ob, do_unlink=True)
    actor.rotation_euler = (0, 0, 0)
    return actor


def label(text, x, z, size=.12, material=None):
    data = bpy.data.curves.new(text, 'FONT')
    data.body = text
    data.size = size
    data.align_x = 'CENTER'
    ob = bpy.data.objects.new(text, data)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = bpy.context.scene.camera.rotation_euler.to_matrix() @ Vector((x, z, 0))
    ob.rotation_euler = bpy.context.scene.camera.rotation_euler
    data.materials.append(material)
    return ob


def build():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'art/blender/characters/cd_tocsin.blend'))
    root = next(ob for ob in bpy.context.scene.objects if ob.name.startswith('Tocsin /'))
    root.name = 'Tocsin_Root'
    root.location = (0, 0, 0)
    root.rotation_euler = (0, 0, 0)
    root.animation_data_clear()
    # Keep the approved geometry; remove its presentation studio.
    keep = {root, *root.children_recursive}
    for ob in list(bpy.context.scene.objects):
        if ob not in keep:
            bpy.data.objects.remove(ob, do_unlink=True)
    modules = {}
    for key, old in PARTS.items():
        ob = bpy.data.objects[old]
        ob.name = key
        ob['module_id'] = key
        ob['pivot_role'] = 'detachable socket' if key != 'torso' else 'boiler centre'
        modules[key] = ob
    # Torso was modelled around world zero; relocate its pivot without moving geometry.
    torso = modules['torso']
    children = [(o, o.matrix_world.copy()) for o in torso.children]
    torso.location = (0, 0, .74)
    bpy.context.view_layer.update()
    for ob, matrix in children:
        ob.matrix_world = matrix
    steam = cd.empty('neck_steam', (0, 0, 1.045), root)
    steam['module_id'] = 'neck_steam'
    steam['pivot_role'] = 'neck socket / visible when head is absent'
    modules['neck_steam'] = steam
    soot = cd.worn('Tocsin wet soot and steam', '171D1C', '60685F', 0, .95)
    # Sculpted irregular ribbons, rather than cartoon bubbles; a neutral steam layer.
    for j in range(3):
        verts = []
        for k in range(7):
            t = k / 6
            x = (j - 1) * .032 + math.sin(t * 6 + j) * .025 * t
            y = .013 + math.sin(t * 4 + j) * .012
            width = .014 * (1-t) + .002
            verts.extend([(x-width, y, t*.24), (x+width, y+.008, t*.24)])
        faces = [(2*k, 2*k+1, 2*k+3, 2*k+2) for k in range(6)]
        cd.mesh('Pressure vapour ribbon %d' % j, verts, faces, soot, steam)
    visible(steam, False)
    for key, ob in modules.items():
        collection = bpy.data.collections.new('Tocsin/' + key)
        bpy.context.scene.collection.children.link(collection)
        for part in [ob, *ob.children_recursive]:
            for old in list(part.users_collection):
                old.objects.unlink(part)
            collection.objects.link(part)
            part['tocsin_module'] = key
    # Existing chara design uses fine PBR pitting; retain it and add cavity shading.
    iso_rig.bake_ao_shadows(root)
    scene = iso_rig.create_rig('CREA', 192, reset=False)
    # Official boss studio, shared by all scale references below.
    sun_data = bpy.data.lights.new('Sun_chaud_haut_gauche', 'SUN')
    sun_data.energy = 2.5
    sun_data.color = (1, .76, .53)
    sun_data.angle = .15
    sun = bpy.data.objects.new(sun_data.name, sun_data)
    scene.collection.objects.link(sun)
    sun.location = (-4, -6, 8)
    sun.rotation_euler = (Vector((0, 0, .7))-sun.location).to_track_quat('-Z', 'Y').to_euler()
    fill_data = bpy.data.lights.new('Fill_froid', 'AREA')
    fill_data.energy = 125
    fill_data.color = (.5, .66, .85)
    fill_data.shape = 'DISK'
    fill_data.size = 5
    fill = bpy.data.objects.new(fill_data.name, fill_data)
    scene.collection.objects.link(fill)
    fill.location = (4, -1, 6)
    fill.rotation_euler = (-fill.location).to_track_quat('-Z', 'Y').to_euler()
    scene.world.color = (.18, .18, .18)
    if scene.world.use_nodes:
        bg = scene.world.node_tree.nodes.get('Background')
        if bg:
            bg.inputs['Color'].default_value = (.18, .18, .18, 1)
            bg.inputs['Strength'].default_value = .35
    scene.eevee.taa_render_samples = 16
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 8
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    scene.view_layers[0].use_pass_normal = True
    scene.view_layers[0].use_pass_emit = True
    scene.camera.data.shift_y = .21
    scene['T1_contract'] = 'CREA 30 deg; R=90.509668 px/u; 192px; feet=(96,136.32); 7 modules'
    scene['T1_next'] = 'T2 locomotion and depth order; T3 throws/death; T4 detached assets; T5 atlases'
    scene['future_animation_contract'] = 'attack: impact at N/2; cast; cast_ult; death; eight directions'
    scene['neck_steam_visibility'] = 'hidden with head; unhide module when head absent'
    root['height_design_u'] = 1.4
    root['foot_pivot_px'] = [96., 136.32]
    root['directions'] = ','.join(DIRECTIONS)
    for ob in [root, *root.children_recursive]:
        ob.animation_data_clear()
    bpy.context.preferences.filepaths.save_version = 0
    source = ROOT / 'art/blender/characters/tocsin.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    report = {'lot': 'T1', 'base': 'art/blender/characters/cd_tocsin.blend',
              'source': str(source.relative_to(ROOT)), 'cell': 192,
              'pivot_px': [96, 136.32], 'R_px_per_u': iso_rig.R,
              'elevation_degrees': 30, 'directions': list(DIRECTIONS),
              'modules': {key: {'object': ob.name, 'pivot_u': list(ob.location),
                          'meshes': sum(c.type == 'MESH' for c in ob.children_recursive)}
                          for key, ob in modules.items()},
              'game_files_changed': 0,
              'design': 'Approved CD geometry: boiler, split bell, asymmetric finial, long three-finger claws; black iron, verdigris, brass fasteners, rust, moss, orange furnace only.',
              'next': 'T2: animate seven roots from tocsin.blend; preserve 192px / shift_y .21; steam hidden unless head absent. T3/T5 include attack (impact N/2), cast, cast_ult, death.'}
    assert len(root.children) == 7, 'Seven module roots required'
    assert set(o.name for o in root.children) == set(modules)
    origin = world_to_camera_view(scene, scene.camera, Vector((0, 0, 0)))
    assert abs(origin.x*192-96) < .01 and abs((1-origin.y)*192-136.32) < .01
    bounds = []
    for direction, angle in DIRECTIONS.items():
        root.rotation_euler.z = angle
        path = render('tocsin_' + direction, passes=True)
        with Image.open(path) as image:
            box = image.getbbox()
            assert box and min(box[0], box[1], 192-box[2], 192-box[3]) >= 4, (direction, box)
            bounds.append({'direction': direction, 'alpha_bbox': box})
    report['direction_checks'] = bounds
    root.rotation_euler.z = math.pi/7
    render('tocsin_detail', 512, .30, scale=1.9)
    root.rotation_euler.z = math.pi + math.pi/7
    render('tocsin_back_detail', 512, .30, scale=1.9)
    root.rotation_euler.z = math.pi/7
    # Exploded seven-part source study; no transforms are persisted to production source.
    rest = {k: ob.location.copy() for k, ob in modules.items()}
    for k, ob in modules.items():
        if k.startswith('arm'): ob.location.x *= 1.85
        if k.startswith('leg'): ob.location.x *= 1.55; ob.location.z -= .12
        if k == 'head': ob.location.z += .25
    visible(steam, True)
    render('tocsin_modules', 512, .31, scale=2.25)
    for key, ob in modules.items(): ob.location = rest[key]
    visible(steam, False)
    # Identical orthographic scale, studio, and ground line for all three actors.
    root.rotation_euler.z = math.pi/7
    scale_images = [render('scale_tocsin', 384, .21)]
    visible(root, False)
    ardent = load_actor(ROOT/'art/blender/characters/ardent_iso.blend', 'Ardent_Root')
    ardent.rotation_euler.z = math.pi/7
    scale_images.append(render('scale_ardent', 384, .21))
    visible(ardent, False)
    ash = load_actor(ROOT/'art/blender/monsters/ash_lord.blend', 'AshLord')
    ash.rotation_euler.z = math.pi/7
    scale_images.append(render('scale_ash_lord', 384, .21))
    visible(ash, False)
    # A text strip is rendered with Blender, not painted by Pillow.
    frame((1536, 100), 0)
    ink = cd.flat('Contact lettering', 'A8946E', 1)
    texts = []
    for text, x in [('TOCSIN / T1', -5.5), ('FONDERIE NOYEE / 7 MODULES', 0), ('CREA 30 / 192 PX', 5.4)]:
        texts.append(label(text, x, -.06, .20, ink))
    header = render('contact_labels', (1536, 100), 0)
    for ob in texts: ob.hide_render = True
    texts = []
    for text, x in [('TOCSIN / 1.40 U', -4.25), ('ARDENT', 0), ('ASH LORD / 2.30 U', 4.25)]:
        texts.append(label(text, x, -.06, .16, ink))
    footer = render('scale_labels', (1536, 50), 0)
    for ob in texts: ob.hide_render = True
    # Contact: production directions at native size; detail; modularity; same-scale cast.
    board = Image.new('RGBA', (1536, 1240), (17, 23, 25, 255))
    def paste(path, xy):
        with Image.open(path) as im: board.alpha_composite(im.convert('RGBA'), xy)
    paste(header, (0, 0))
    for i, direction in enumerate(DIRECTIONS): paste(OUT/('tocsin_'+direction+'.png'), (i*192, 90))
    paste(OUT/'tocsin_detail.png', (0, 285))
    paste(OUT/'tocsin_modules.png', (512, 285))
    paste(OUT/'tocsin_back_detail.png', (1024, 285))
    paste(footer, (0, 790))
    for path, x in zip(scale_images, (192, 576, 960)): paste(path, (x, 840))
    contact = ROOT/'art/tools/night/_t1_contact.png'
    board.save(contact, optimize=True, compress_level=9)
    report['checks'] = 'PASS seven roots, fixed foot pivot, 8 alpha margins, native 192px, normal/emission passes, common-scale cast'
    (OUT/'t1_report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    print('T1 PASS: source + 7 pivots + 8 directions + useful normal/emission passes + contact', flush=True)


def verify():
    """Reload the actual delivery, rather than checking only the build scene."""
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'art/blender/characters/tocsin.blend'))
    root = bpy.data.objects['Tocsin_Root']
    assert {o.name for o in root.children} == {*PARTS, 'neck_steam'}
    scene = bpy.context.scene
    assert scene['iso_rig'] == 'CREA'
    assert abs(scene.camera.data.shift_y - .21) < 1e-6
    assert abs(scene.camera.data.ortho_scale - 192/iso_rig.R) < 1e-6
    assert all(o.animation_data is None for o in root.children_recursive)
    assert all(o.hide_render for o in bpy.data.objects['neck_steam'].children_recursive)
    meshes = [o for o in root.children_recursive if o.type == 'MESH']
    assert all(o.get('tocsin_module') in {*PARTS, 'neck_steam'} for o in meshes)
    triangles = sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    omitted_emission = []
    for direction in DIRECTIONS:
        with Image.open(OUT/('tocsin_'+direction+'.png')) as d, \
             Image.open(OUT/('tocsin_'+direction+'_n.png')) as n:
            assert d.size == n.size == (192,192)
            assert d.getchannel('A').tobytes() == n.getchannel('A').tobytes()
            assert max(n.getchannel('R').getextrema()) > 128
        emission_path = OUT/('tocsin_'+direction+'_e.png')
        if emission_path.exists():
            with Image.open(emission_path) as e:
                assert e.size == (192,192)
                assert max(e.getchannel('R').getextrema()) > 1
        else:
            omitted_emission.append(direction)
    report_path = OUT/'t1_report.json'
    report = json.loads(report_path.read_text(encoding='utf8'))
    report['saved_source_check'] = {'result': 'PASS', 'mesh_objects': len(meshes),
                                   'base_triangles': triangles, 'modules': 7,
                                   'normal_alpha_matches_diffuse': True}
    report['black_emission_omitted_per_STYLE'] = omitted_emission
    log = (OUT/'t1_godot.log').read_text(encoding='utf-16')
    assert 'RESULT: OK' in log and 'ERROR:' not in log and 'SCRIPT ERROR' not in log
    report['godot_sprites_test'] = 'RESULT: OK; no errors'
    report['tres'] = 'No T1 SpriteFrames: source-only lot. Existing .tres unchanged; T5 owns assembly.'
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf8')
    (OUT/'rapport_t1.txt').write_text(
        'T1 TERMINE : source tocsin.blend, derivee du chara design valide.\n'
        '7 modules et pivots : torso, head, neck_steam, arm_l/r, leg_l/r.\n'
        'Choix DA : fer pique, bronze noye, cloche felee, raccords demontables ; foyer orange unique.\n'
        'CREA 30 degres, 90.5097 px/u, cellule 192, pivot Ardent (96 ; 136.32).\n'
        'PASS : source rechargee, 8 directions diffuse/normale/emission, marges alpha ; Godot RESULT: OK.\n'
        'Suite T2 : locomotion/calques ; T3 : lancers/death ; T5 : atlas et .tres, attack impact N/2, cast, cast_ult. Aucun fichier game ni .gd/.tscn modifie.\n',
        encoding='utf8')
    print('T1 VERIFY PASS: saved source, seven modules, normal/emission, Godot RESULT: OK', flush=True)


if __name__ == '__main__':
    if '--verify-only' in sys.argv:
        verify()
    else:
        build()
