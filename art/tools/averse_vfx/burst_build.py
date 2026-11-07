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
    cel.setup_scene(s, 12)
    for layer in s.view_layers:
        layer.use_pass_normal = False
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
    sun.energy = 3.6
    lo = bpy.data.objects.new('Upper left', sun)
    s.collection.objects.link(lo)
    lo.rotation_euler = Vector((3, 4, -7)).to_track_quat('-Z', 'Y').to_euler()
    s.world = bpy.data.worlds.new('Dark ambient')
    s.world.color = (.025, .025, .025)
    water = common.material('Water - slate teal', (.052, .115, .124))
    inner = common.material('Hollow underside', (.018, .036, .043))
    foam = common.material('Foam - desaturated silver', (.24, .32, .33))
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
    profile = dict(cel.profile('vfx'), tones=3, creases=False)
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
            poly.use_smooth = False
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

    # Closed breaker cross-section: broad shoulder, overhanging nose, hollow throat.
    # Both surfaces and the thick lip are geometry; foam occupies short crest patches.
    section = [(0, .035), (.10, .18), (.18, .48), (.24, .77),
               (.34, 1.00), (.49, 1.12), (.65, 1.10), (.77, .96),
               (.79, .77), (.71, .65), (.61, .68), (.61, .82),
               (.55, .90), (.45, .88), (.40, .72), (.39, .44),
               (.44, .18), (.62, .07), (.98, .025), (.98, 0), (0, 0)]
    all_frames = []
    widths = (.20, .48, .77, 1.00, .95, .63)
    heights = (.27, .65, .94, .78, .25, .035)
    for frame, (width, height) in enumerate(zip(widths, heights)):
        before = set(s.objects)
        phase = frame * .30
        def point(x, yz, sign):
            y, z = yz
            # One sculpted dome per period; X=integer boundaries carry the trough.
            swell = .68 + .32 * math.cos(TAU * (x - phase * .12))
            crest_weight = min(1, z / .6)
            transverse = .055 * math.sin(TAU * x + phase) * math.sin(math.pi * y)
            rear = .78 if sign == 1 else 1
            return (x, sign * width * (y + transverse),
                    .015 + rear * height * z * (1 - crest_weight + crest_weight * swell))
        for sign in (-1, 1):
            if frame == 5:
                continue
            verts, faces, ids = [], [], []
            steps = 120
            for i in range(steps + 1):
                x = -1.5 + 3 * i / steps
                verts.extend(point(x, p, sign) for p in section)
            n = len(section)
            for i in range(steps):
                for j in range(n):
                    a, b = i * n + j, i * n + (j + 1) % n
                    face = (a, b, b + n, a + n)
                    faces.append(face[::-1] if sign == 1 else face)
                    ids.append(1 if 10 <= j <= 15 else 0)
            obj = mesh('F%d thick hollow breaker %d' % (frame, sign), verts, faces, ids)
            import bmesh
            bm = bmesh.new(); bm.from_mesh(obj.data)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bm.to_mesh(obj.data); bm.free()
            # Foam and cyan only on the crown, never a horizontal continuous band.
            for period in range(-2, 3):
                for k, (start, length) in enumerate(((-.30, .19), (.015, .12), (.23, .10))):
                    pts = []
                    for j in range(17):
                        x = period + start + length * j / 16 + phase * .12
                        p = point(x, (.49 + .025 * math.sin(j * .34), 1.125), sign)
                        pts.append((p[0], p[1], p[2] + .006))
                    tube('F%d crest foam patch' % frame, pts, .017 if frame < 4 else .009, 2)
                    pts = [(x, y - .006, z + .012) for x, y, z in pts[2:-2]]
                    tube('F%d thin cyan crest' % frame, pts, .006, 3)
        # Ballistic droplets, identical period copies; sphere shading gives round volume.
        if frame > 0:
            t = (frame - 1) / 4
            for period in range(-2, 3):
                for k in range(9):
                    x = period + ((k * .381966) % 1) - .5
                    side = 1 if k % 2 else -1
                    y = side * (.15 + t * (.65 + .10 * (k % 3)))
                    z = max(.045, .13 + (.95 + .12 * (k % 4)) * t - 1.25 * t*t)
                    if frame == 1:
                        z += .16 + .06 * (k % 3)
                    radius = (.021 + .009 * (k % 3)) * (1 if frame < 5 else .68)
                    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=radius, location=(x, y, z))
                    drop = bpy.context.object
                    drop.name = 'F%d ballistic sphere' % frame
                    drop.scale.z = 1.13
                    drop.data.materials.append(water if k % 4 else foam)
                    for poly in drop.data.polygons:
                        poly.use_smooth = True
        # Falling water hits the ground: low hollow crowns, spreading and shrinking.
        if frame >= 4:
            for period in range(-2, 3):
                for side in (-1, 1):
                    verts, faces, ids = [], [], []
                    radius = .21 if frame == 4 else .31
                    for j in range(49):
                        a = TAU * j / 48
                        spike = (.5 + .5 * math.cos(7*a)) ** 5
                        top = (.09 + .13 * spike) * (1 if frame == 4 else .24)
                        for r, z in ((radius*.70, .015), (radius, top), (radius+.025, top*.7), (radius*1.14, .012)):
                            verts.append((period + .12 + r * math.cos(a), side*.70 + r*.64*math.sin(a), z))
                    for j in range(48):
                        for k in range(3):
                            q = j*4+k
                            faces.append((q,q+4,q+5,q+1)); ids.append(2 if k == 1 and j%7 < 2 else 0)
                    mesh('F%d hollow impact crown' % frame, verts, faces, ids)
                    if frame == 5:
                        for start in (.3, 2.3, 4.3):
                            pts = []
                            for j in range(13):
                                a = start + .55*j/12
                                z = (.09 + .13*(.5+.5*math.cos(7*a))**5)*.24
                                pts.append((period+.12+radius*math.cos(a), side*.70+radius*.64*math.sin(a), z+.009))
                            tube('F5 fading cyan impact rim', pts, .012, 3)
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


def optimize_png(path):
    # Lossless recompression: preserve all RGBA samples, including seam columns.
    import struct, zlib
    import zopfli.zlib
    data = path.read_bytes(); chunks = []; offset = 8
    while offset < len(data):
        n = struct.unpack('>I', data[offset:offset+4])[0]
        chunks.append((data[offset+4:offset+8], data[offset+8:offset+8+n]))
        offset += n+12
    compressed = zopfli.zlib.compress(zlib.decompress(b''.join(v for k,v in chunks if k == b'IDAT')), numiterations=5)
    result = bytearray(data[:8]); written = False
    for kind, value in chunks:
        if kind == b'IDAT':
            if written: continue
            value = compressed; written = True
        result.extend(struct.pack('>I',len(value)) + kind + value + struct.pack('>I',zlib.crc32(kind+value)))
    if len(result) < len(data): path.write_bytes(result)


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
    for name in ('rivulet_burst.png', 'rivulet_burst_e.png'):
        optimize_png(OUT / name)
    # Pillow only crops/assembles/resizes the rendered images.
    contact = Image.new('RGBA', (768, 1280), (30, 32, 36, 255))
    for f in range(6):
        tile = diffuse.crop((128*f, 0, 128*(f+1), 256))
        contact.alpha_composite(tile.resize((256,512), Image.Resampling.NEAREST), ((f%3)*256, (f//3)*512))
    peak = diffuse.crop((256, 0, 384, 256))
    for j in range(6):
        contact.alpha_composite(peak, (j*128, 1024))
    dest = ROOT / 'art/renders/averse_burst_v3_contact.png'
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
    assert (OUT / 'rivulet_burst.png').stat().st_size <= 74464
    assert (OUT / 'rivulet_burst_e.png').stat().st_size <= 15948
    assert not list(OUT.glob('*_n.png'))
    tres = (OUT / 'rivulet_burst.tres').read_text()
    assert tres.count('type="AtlasTexture"') == 6 and '"loop": false' in tres and '"speed": 20.0' in tres
    assert all(('region = Rect2(%d, 0, 128, 256)' % (f*128)) in tres for f in range(6))
    assert 'CanvasTexture' not in tres and 'normal_texture' not in tres
    print('BURST VERIFY PASS: 768x256 / 384x128; alpha; 6 distinct frames; G/D exact 12/12; contrast %s; bounds %s' % (ranges, boxes))


if __name__ == '__main__':
    if '--pack' in sys.argv:
        pack()
    elif '--verify' in sys.argv:
        verify()
    else:
        render()
