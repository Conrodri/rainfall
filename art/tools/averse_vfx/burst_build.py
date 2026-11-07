"""Periodic volumetric rivulet burst. Blender render; system Python --pack/--verify.

Cel setup/compositor adapted from vigie_vfx/rivulet_build.py.
Logical X projects horizontally; camera elevation 30 degrees (dimetric 2:1).
"""
import math
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
WORK = ROOT / 'art/blender/rivulet'
RAW = WORK / 'burst_frames'
OUT = ROOT / 'game/assets/sprites/characters/averse/variants/rivulet_burst'
TAU = math.tau


def render():
    import bpy
    from mathutils import Vector
    sys.path.insert(0, str(ROOT / 'art/tools/cel'))
    sys.path.insert(0, str(ROOT / 'art/tools/bosses'))
    import cel_style as cel
    import boss_common as common
    RAW.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    cel.setup_scene(s, 8)
    s.render.resolution_x = 768
    s.render.resolution_y = 512
    s.render.resolution_percentage = 100
    s.render.fps = 20
    s.frame_start, s.frame_end = 1, 6
    cam = bpy.data.cameras.new('Dimetric 2:1 - 128 pixels per X unit')
    ob = bpy.data.objects.new('Camera', cam)
    s.collection.objects.link(ob)
    target = Vector((0, 0, .50))
    ob.location = target + Vector((0, -10 * math.cos(math.pi / 6), 5))
    ob.rotation_euler = (target - ob.location).to_track_quat('-Z', 'Y').to_euler()
    cam.type = 'ORTHO'
    cam.ortho_scale = 3  # horizontal span: three periods, cropped to central period
    s.camera = ob
    sun = bpy.data.lights.new('Upper left', 'SUN')
    sun.energy = 1.05
    lo = bpy.data.objects.new('Upper left', sun)
    s.collection.objects.link(lo)
    lo.rotation_euler = Vector((3, 4, -7)).to_track_quat('-Z', 'Y').to_euler()
    s.world = bpy.data.worlds.new('Dark ambient')
    s.world.color = (.025, .025, .025)
    water = common.material('Water - slate teal', (.035, .078, .09))
    inner = common.material('Hollow underside', (.018, .036, .043))
    foam = common.material('Foam - desaturated silver', (.25, .30, .30))
    cyan = tuple(((v / 255 + .055) / 1.055) ** 2.4 for v in (95, 212, 232))
    accent = common.material('Crest #5FD4E8', cyan, emission=1)
    mats = [water, inner, foam, accent]

    def compositor(path):
        tree = bpy.data.node_groups.new('Burst cel accent', 'CompositorNodeTree')
        s.compositing_node_group = tree
        tree.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
        rl = tree.nodes.new('CompositorNodeRLayers')
        output = tree.nodes.new('NodeGroupOutput')
        tree.links.new(rl.outputs['Image'], output.inputs['Image'])
        f = tree.nodes.new('CompositorNodeOutputFile')
        f.directory = str(path.parent)
        f.file_name = path.stem + '_e__'
        f.file_output_items.new('RGBA', 'Image')
        f.format.media_type = 'IMAGE'
        f.format.file_format = 'PNG'
        f.format.color_mode = 'RGBA'
        f.format.color_depth = '8'
        tree.links.new(rl.outputs['Image'], f.inputs[0])

    common.configure_passes = compositor
    profile = dict(cel.profile('vfx'), tones=3)
    configure = cel.install(profile, normals=False)

    def mesh(name, verts, faces, indices=None):
        data = bpy.data.meshes.new(name)
        data.from_pydata(verts, [], faces)
        data.update()
        obj = bpy.data.objects.new(name, data)
        s.collection.objects.link(obj)
        for mat in mats:
            data.materials.append(mat)
        for i, poly in enumerate(data.polygons):
            poly.material_index = indices[i] if indices else 0
            poly.use_smooth = True
        return obj

    def tube(name, points, radius, material):
        verts, faces = [], []
        for x, y, z in points:
            for j in range(8):
                a = TAU * j / 8
                verts.append((x, y + radius * math.cos(a), z + radius * math.sin(a)))
        for i in range(len(points) - 1):
            for j in range(8):
                a = i * 8 + j
                b = i * 8 + (j + 1) % 8
                faces.append((a, b, b + 8, a + 8))
        return mesh(name, verts, faces, [material] * len(faces))

    # A closed, thick overturned wave section: convex back, curled lip, concave throat.
    section = [(0, .03), (.16, .09), (.30, .32), (.40, .66), (.53, .92),
               (.70, 1.02), (.87, .94), (.97, .76), (.94, .57), (.85, .56),
               (.84, .74), (.74, .82), (.63, .79), (.56, .62), (.51, .34),
               (.46, .11), (.77, .045), (1, .02), (.90, 0), (0, 0)]
    all_frames = []
    for frame, (width, height) in enumerate(zip((.49, .68, .91, 1., .99, .97),
                                               (.32, .65, .96, .78, .33, .11))):
        before = set(s.objects)
        phase = frame * .71
        def point(x, yz, sign):
            y, z = yz
            swell = math.sin(TAU * x + phase)
            ripple = 1 + .18 * swell + .065 * math.sin(3 * TAU * x - phase)
            bulge = .12 * math.sin(2 * TAU * x + phase) * math.sin(math.pi * y)
            rear = .66 if sign == 1 else 1
            return (x, sign * width * (y + bulge), .018 + rear * height * z * ripple)
        for sign in (-1, 1):
            verts, faces, ids = [], [], []
            steps = 144
            for i in range(steps + 1):
                x = -1.5 + 3 * i / steps
                verts.extend(point(x, p, sign) for p in section)
            n = len(section)
            for i in range(steps):
                for j in range(n):
                    a, b = i * n + j, i * n + (j + 1) % n
                    face = (a, b, b + n, a + n)
                    faces.append(face[::-1] if sign == 1 else face)
                    ids.append(1 if 10 <= j <= 14 else (2 if j == 5 else 0))
            mesh('F%d closed wave %d' % (frame, sign), verts, faces, ids)
            for j, mat, rad in ((6, 2, .033), (6, 3, .012), (8, 0, .030), (12, 0, .018)):
                pts = [point(-1.5 + 3 * i / 192, section[j], sign) for i in range(193)]
                if mat == 3:
                    pts = [(x, y - .022, z + .022) for x, y, z in pts]
                tube('F%d curled crest %d %d' % (frame, sign, j), pts, rad, mat)
            # Raised curved ribs on the falling face; dark sides and lit shoulders.
            for period in range(-2, 3):
                for k in range(3):
                    pts = []
                    for j in range(18):
                        t = j / 17
                        x = period + k / 3 + .045 * math.sin(t * math.pi + phase + k)
                        p = point(x, (.88 - .35 * t, .90 - .70 * t), sign)
                        pts.append((p[0], p[1] + sign * .022, p[2]))
                    tube('F%d water shoulder' % frame, pts, .018 if k % 2 else .025, 0)
        # Deterministic spherical drops, copied every X unit; cast shading reveals volume.
        if frame > 0:
            for period in range(-2, 3):
                for k in range(12):
                    x = period + ((k * .381966) % 1) - .5
                    side = 1 if k % 2 else -1
                    y = side * width * (.62 + .34 * ((k * 7 % 11) / 11))
                    z = height * (.65 + .40 * ((k * 3 % 7) / 7)) + (.13 if frame < 4 else .06)
                    radius = (.025 + .012 * (k % 3)) * (1 if frame < 5 else .72)
                    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=radius, location=(x, y, z))
                    drop = bpy.context.object
                    drop.name = 'F%d shaded spherical drop' % frame
                    drop.scale.z = 1.28 if frame < 4 else 1.6
                    drop.data.materials.append(water if k % 3 else foam)
                    for poly in drop.data.polygons:
                        poly.use_smooth = True
        objects = set(s.objects) - before
        for obj in objects:
            for f in range(1, 7):
                obj.hide_render = f != frame + 1
                obj.hide_viewport = f != frame + 1
                obj.keyframe_insert(data_path='hide_render', frame=f)
                obj.keyframe_insert(data_path='hide_viewport', frame=f)
        all_frames.append(objects)
    for frame in range(6):
        s.frame_set(frame + 1)
        path = RAW / ('f%d.png' % frame)
        configure(path)
        s.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
    s.frame_set(3)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK / 'rivulet_burst.blend'), compress=True)
    cel.uninstall()
    print('BURST RENDER PASS: 6 frames, closed 3D waves, periodic X, no normal maps')


def pack():
    from PIL import Image
    OUT.mkdir(parents=True, exist_ok=True)
    diffuse = Image.new('RGBA', (768, 256))
    emission = Image.new('RGBA', (384, 128))
    for f in range(6):
        for suffix, sheet, size in (('', diffuse, (128, 256)), ('_e', emission, (64, 128))):
            path = RAW / ('f%d.png' % f) if not suffix else next(RAW.glob('f%d_e__*.png' % f))
            with Image.open(path) as src:
                tile = src.convert('RGBA').crop((256, 0, 512, 512)).resize(size, Image.Resampling.LANCZOS)
            # Assemble identical boundary columns, also for the half-resolution accent.
            tile.paste(tile.crop((0, 0, 1, size[1])), (size[0] - 1, 0))
            sheet.paste(tile, (f * size[0], 0))
    diffuse.save(OUT / 'rivulet_burst.png', optimize=True, compress_level=9)
    emission.save(OUT / 'rivulet_burst_e.png', optimize=True, compress_level=9)
    resource = ['[gd_resource type="SpriteFrames" format=3]',
                '[ext_resource type="Texture2D" path="res://assets/sprites/characters/averse/variants/rivulet_burst/rivulet_burst.png" id="0"]']
    for f in range(6):
        resource.append('[sub_resource type="AtlasTexture" id="f%d"]\natlas = ExtResource("0")\nregion = Rect2(%d, 0, 128, 256)' % (f, f * 128))
    frames = ', '.join('{"duration": 1.0, "texture": SubResource("f%d")}' % f for f in range(6))
    resource.append('[resource]\nanimations = [{"frames": [%s], "loop": false, "name": &"default", "speed": 20.0}]' % frames)
    (OUT / 'rivulet_burst.tres').write_text('\n\n'.join(resource) + '\n', encoding='utf-8')
    # Contact: enlarged crops of each crest and six full-width repetitions of the peak.
    contact = Image.new('RGBA', (960, 680), (26, 29, 33, 255))
    for f in range(6):
        tile = diffuse.crop((128 * f, 0, 128 * (f + 1), 256))
        crop = tile.resize((160, 320), Image.Resampling.NEAREST)
        contact.alpha_composite(crop, (160 * f, 0))
    peak = diffuse.crop((256, 0, 384, 256))
    for j in range(6):
        contact.alpha_composite(peak.resize((160, 320), Image.Resampling.NEAREST), (j * 160, 350))
    dest = ROOT / 'art/renders/averse_burst_contact.png'
    dest.parent.mkdir(parents=True, exist_ok=True)
    contact.save(dest, optimize=True)
    verify()


def verify():
    import numpy as np
    from PIL import Image
    hashes, ranges, boxes = [], [], []
    for suffix, size in (('', (768, 256)), ('_e', (384, 128))):
        im = Image.open(OUT / ('rivulet_burst%s.png' % suffix)).convert('RGBA')
        assert im.size == size, im.size
        a = np.array(im)
        w = size[0] // 6
        for f in range(6):
            tile = a[:, f*w:(f+1)*w]
            assert np.array_equal(tile[:, 0], tile[:, -1]), ('seam', suffix, f)
            assert tile[:, :, 3].min() == 0 and tile[:, :, 3].max() == 255
            visible = tile[:, :, 3] > 128
            rgb = tile[:, :, :3][visible]
            assert rgb.max() - rgb.min() > 35, ('contrast', suffix, f)
            if not suffix:
                hashes.append(hash(tile.tobytes()))
                ranges.append(int(rgb.max() - rgb.min()))
                boxes.append(Image.fromarray(tile).getbbox())
            else:
                assert ((tile[:, :, :3].max(axis=2) > 50) & visible).sum() > 10
        assert a[0, :, 3].max() == 0 and a[-1, :, 3].max() == 0, 'vertical clipping'
    assert len(set(hashes)) == 6
    assert not list(OUT.glob('*_n.png'))
    tres = (OUT / 'rivulet_burst.tres').read_text()
    assert tres.count('type="AtlasTexture"') == 6 and '"loop": false' in tres and '"speed": 20.0' in tres
    assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
    print('BURST VERIFY PASS: 768x256 / 384x128; alpha; 6 distinct frames; G/D exact 12/12; contrast %s; bounds %s' % (ranges, boxes))


if __name__ == '__main__':
    if '--pack' in sys.argv:
        pack()
    elif '--verify' in sys.argv:
        verify()
    else:
        render()
