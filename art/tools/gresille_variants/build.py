"""Grésille variants. Blender background render; system Python --pack."""
import math
import random
import sys
from pathlib import Path

ROOT = Path('C:/Users/const/Documents/Rainfall/.claude/worktrees/agent-ae540a3fb5bec2c4e')
RAW = ROOT / 'art/renders/gresille_variants'
OUT = ROOT / 'game/assets/sprites/vfx/gresille'
SPECS = {'rod_planted': (128, 192, 5, 2), 'jar_fly': (64, 64, 4, 2),
         'jar_burst': (512, 320, 3, 2)}


def render():
    import bpy
    from mathutils import Vector
    sys.path.insert(0, str(ROOT / 'art/tools/cel'))
    import cel_style as cel
    RAW.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    cel.setup_scene(s, 16)
    cel.install('vfx', normals=False)
    for layer in s.view_layers:
        layer.use_pass_normal = False
        layer.use_pass_emit = False
    s.render.threads_mode = 'FIXED'
    s.render.threads = 8
    s.render.resolution_percentage = 100
    s.render.image_settings.compression = 100
    s.world = bpy.data.worlds.new('Transparent ambient')
    cam = bpy.data.objects.new('Dimetric 2:1', bpy.data.cameras.new('Dimetric 2:1'))
    s.collection.objects.link(cam)
    cam.location = (0, -10 * math.cos(math.pi / 6), 5)
    cam.rotation_euler = (-cam.location).to_track_quat('-Z', 'Y').to_euler()
    cam.data.type = 'ORTHO'
    s.camera = cam
    right = Vector((1, 0, 0))
    up = Vector((0, .5, math.sqrt(3) / 2))
    front = cam.location.normalized()
    sun = bpy.data.objects.new('Upper left', bpy.data.lights.new('Upper left', 'SUN'))
    sun.data.energy = 3.6
    sun.rotation_euler = Vector((3, 4, -7)).to_track_quat('-Z', 'Y').to_euler()
    s.collection.objects.link(sun)
    mats = {}
    made, dark = [], []

    def material(rgb, alpha=1, lit=False):
        key = (rgb, round(alpha, 3), lit)
        if key in mats:
            return mats[key]
        m = bpy.data.materials.new(str(key))
        m.use_nodes = True
        m.surface_render_method = 'DITHERED'
        nodes, links = m.node_tree.nodes, m.node_tree.links
        nodes.clear()
        output = nodes.new('ShaderNodeOutputMaterial')
        color = tuple(((v / 255 + .055) / 1.055) ** 2.4 if v > 10 else v / 3294.6 for v in rgb) + (1,)
        emission = nodes.new('ShaderNodeEmission')
        emission.inputs['Color'].default_value = color
        if lit:
            diffuse = nodes.new('ShaderNodeBsdfDiffuse')
            shader = nodes.new('ShaderNodeShaderToRGB')
            ramp = nodes.new('ShaderNodeValToRGB')
            ramp.color_ramp.interpolation = 'CONSTANT'
            ramp.color_ramp.elements[0].position = .18
            ramp.color_ramp.elements[0].color = tuple(v * .38 for v in color[:3]) + (1,)
            ramp.color_ramp.elements[1].position = .7
            ramp.color_ramp.elements[1].color = color
            mid = ramp.color_ramp.elements.new(.4)
            mid.color = tuple(v * .72 for v in color[:3]) + (1,)
            links.new(diffuse.outputs[0], shader.inputs[0])
            links.new(shader.outputs[0], ramp.inputs[0])
            links.new(ramp.outputs[0], emission.inputs[0])
        if alpha < 1:
            trans = nodes.new('ShaderNodeBsdfTransparent')
            mix = nodes.new('ShaderNodeMixShader')
            mix.inputs[0].default_value = alpha
            links.new(trans.outputs[0], mix.inputs[1])
            links.new(emission.outputs[0], mix.inputs[2])
            links.new(mix.outputs[0], output.inputs[0])
        else:
            links.new(emission.outputs[0], output.inputs[0])
        m['cel_done'] = True
        mats[key] = m
        return m

    def mesh(points, faces, rgb, alpha=1, depth=0, glow=False, world=False, lit=False):
        verts = points if world else [tuple(right * ((x - w / 2) / 64) + up * ((h / 2 - y) / 64) + front * depth) for x, y in points]
        data = bpy.data.meshes.new('Angular geometry')
        data.from_pydata(verts, [], faces)
        data.materials.append(material(rgb, alpha, lit))
        obj = bpy.data.objects.new('Glow' if glow else 'Solid', data)
        s.collection.objects.link(obj)
        made.append(obj)
        if not glow:
            dark.append(obj)
        return obj

    def poly(points, rgb, depth=.02, alpha=1, glow=False):
        return mesh(points, [tuple(range(len(points)))], rgb, alpha, depth, glow)

    def ribbon(points, width, rgb, alpha=1, depth=.1):
        verts = []
        for i, (x, y) in enumerate(points):
            a, b = points[max(i - 1, 0)], points[min(i + 1, len(points) - 1)]
            dx, dy = b[0] - a[0], b[1] - a[1]
            length = max(.001, math.hypot(dx, dy))
            r = width * (.5 if i < len(points) - 1 else .18)
            verts.extend([(x - dy / length * r, y + dx / length * r), (x + dy / length * r, y - dx / length * r)])
        mesh(verts, [(2*i, 2*i+1, 2*i+3, 2*i+2) for i in range(len(points)-1)], rgb, alpha, depth, True)

    def arc(points, width=3, alpha=1):
        ribbon(points, width, (185, 166, 255), alpha, .15)
        ribbon(points, max(.7, width * .29), (242, 238, 255), alpha, .17)

    def cylinder(center, radius, height, rgb, vertices=8):
        x, y, z = center
        points = [(x + radius * math.cos(i * math.tau / vertices), y + radius * math.sin(i * math.tau / vertices), z + level * height) for level in (0, 1) for i in range(vertices)]
        faces = [tuple(range(vertices - 1, -1, -1)), tuple(range(vertices, 2 * vertices))]
        faces += [(i, (i+1) % vertices, (i+1) % vertices + vertices, i + vertices) for i in range(vertices)]
        return mesh(points, faces, rgb, world=True, lit=True)

    for name, (w, h, cols, rows) in SPECS.items():
        cam.data.ortho_scale = max(w, h) / 64
        s.render.resolution_x, s.render.resolution_y = w, h
        for f in range(cols * rows):
            for obj in made:
                bpy.data.objects.remove(obj, do_unlink=True)
            made, dark = [], []
            rng = random.Random(914 + f)
            if name == 'rod_planted':
                ground = up * ((h / 2 - 176) / 64)
                rise = [.2, .5, .79, 1][min(f, 3)]
                base = cylinder(ground, .24, .14, (100, 104, 92), 4)
                cylinder(ground + Vector((0, 0, .14)), .075, 1.71 * rise, (93, 141, 119))
                cylinder(ground + Vector((-.018, -.02, .16)), .023, 1.68 * rise, (168, 144, 92), 6)
                for z in (.53, .77, 1.01):
                    if z < 1.7 * rise:
                        cylinder(ground + Vector((0, 0, z - .05)), .145, .10, (50, 57, 66))
                        cylinder(ground + Vector((0, 0, z + .05)), .10, .065, (84, 94, 101))
                tip_y = 176 - 1.85 * rise * 64 * math.sqrt(3) / 2
                phase = (f - 4) * math.tau / 6 + (.31 if f < 4 else 0)
                radius = 2.7 + 1.2 * math.sin(phase)
                poly([(64, tip_y-7-radius), (64+radius, tip_y-2), (64, tip_y+4), (64-radius, tip_y-2)], (185,166,255), .20, glow=True)
                arc([(64,tip_y-5), (59+3*math.sin(phase),tip_y-13), (68,tip_y-18), (65+4*math.cos(phase),tip_y-25)], 1.8, .8 + .2 * math.cos(phase))
                if f < 4:
                    for i in range(7):
                        angle = i * math.tau / 7
                        x = 64 + math.cos(angle) * (10 + f * 6)
                        y = 177 - abs(math.sin(angle)) * (8 + f * 9)
                        poly([(x-2,y), (x,y-3), (x+3,y+1), (x,y+2)], (109,96,73), .05)
            elif name == 'jar_fly':
                angle = f * math.tau / 8
                def rotate(points):
                    return [(32 + x*math.cos(angle)-y*math.sin(angle), 32+x*math.sin(angle)+y*math.cos(angle)) for x,y in points]
                def jarpoly(points, color, depth=.02, glow=False):
                    poly(rotate(points), color, depth, glow=glow)
                jarpoly([(-8,-14),(-6,-18),(6,-18),(8,-14),(11,-10),(11,17),(7,21),(-7,21),(-11,17),(-11,-10)], (38,48,53))
                jarpoly([(-6,-12),(5,-12),(8,-8),(8,15),(5,18),(-6,18),(-8,14),(-8,-8)], (69,88,86), .03)
                jarpoly([(3,-10),(8,-8),(8,14),(4,17)], (48,64,65), .04)
                for y in (-8, 12):
                    jarpoly([(-11,y-2),(-7,y-3),(8,y-3),(11,y-1),(11,y+2),(-11,y+2)], (144,114,70), .06)
                    jarpoly([(-10,y-2),(-6,y-3),(-6,y+1),(-10,y+1)], (186,158,100), .07)
                jarpoly([(-7,-20),(7,-20),(7,-15),(-7,-15)], (111,92,66), .06)
                arc(rotate([(0,-13),(-3,-3),(4,0),(-3,7),(1,13)]), 2.3)
                jarpoly([(-7,-7),(-5,-7),(-5,9),(-7,9)], (144,167,157), .19)
            else:
                cx, cy = 256, 220
                extent = [.10, .42, .74, 1, .90, .72][f]
                fade = [1,1,1,1,.56,.20][f]
                for branch in range(8):
                    angle = branch * math.tau / 8
                    points = [(cx,cy)]
                    for j in range(1,6):
                        r = 249 * extent * j / 5
                        x = cx + math.cos(angle)*r
                        y = cy + math.sin(angle)*r * (.34 if math.sin(angle)>0 else .5)
                        if j < 5:
                            x += rng.uniform(-9,9)*extent
                            y += rng.uniform(-14,14)*extent
                        points.append((x,y))
                    arc(points, [9,7,5,4,3,2][f], fade)
                    if f > 0:
                        start = points[3]
                        end = (start[0]+math.cos(angle+.6)*extent*58, start[1]+math.sin(angle+.6)*extent*24-8)
                        arc([start, ((start[0]+end[0])/2+8,(start[1]+end[1])/2-7), end], 1.8, fade*.75)
                radius = [23,17,12,9,6,3][f]
                poly([(cx+math.cos(i*math.pi/4)*radius*(1 if i%2==0 else .45),cy+math.sin(i*math.pi/4)*radius*.7) for i in range(8)], (242,238,255), .2, fade, True)
                for i in range(13):
                    angle = i*2.399
                    travel = [9,40,77,110,136,153][f] * (.5+(i%4)/6)
                    x = cx + math.cos(angle)*travel
                    y = cy + math.sin(angle)*travel*.35 - [8,35,56,65,44,17][f]*(.5+(i%3)/4)
                    size = [4,5,6,5,4,3][f]
                    poly([(x-size,y+size), (x-size*.3,y-size*1.8), (x+size,y), (x+size*.4,y+size*.6)], (100,128,133), .25, fade)
                    ribbon([(x-size*.3,y-size*1.8),(x+size,y)], 1.1, (184,193,212), fade, .27)
            s.render.filepath = str(RAW / f'{name}_{f:02d}.png')
            bpy.ops.render.render(write_still=True)
            if name == 'rod_planted':
                for obj in dark:
                    obj.hide_render = True
                s.render.resolution_x, s.render.resolution_y = w//2, h//2
                s.render.filepath = str(RAW / f'{name}_{f:02d}_e.png')
                bpy.ops.render.render(write_still=True)
                s.render.resolution_x, s.render.resolution_y = w,h
        # Objects are discarded before the next frame, including the hidden emission occluders.
    cel.uninstall()
    print('PASS render: 24 diffuse frames; 10 half-resolution emission frames; Eevee 16')


def pack():
    import hashlib
    import numpy as np
    from PIL import Image
    RAW.mkdir(parents=True, exist_ok=True)
    contact = Image.new('RGBA', (1024, 960), (27,25,35,255))
    total = 0
    for name, (w,h,cols,rows) in SPECS.items():
        target = OUT/name
        target.mkdir(parents=True,exist_ok=True)
        for suffix in ('','_e') if name=='rod_planted' else ('',):
            tw,th = (w//2,h//2) if suffix else (w,h)
            sheet = Image.new('RGBA',(tw*cols,th*rows))
            hashes = set()
            for f in range(cols*rows):
                with Image.open(RAW/f'{name}_{f:02d}{suffix}.png') as src:
                    tile = src.convert('RGBA')
                assert tile.size==(tw,th),(name,f,tile.size)
                a = np.asarray(tile)
                assert a[:,:,3].min()==0 and a[:,:,3].max()>35,(name,f,'alpha')
                visible=a[a[:,:,3]>35,:3]
                assert visible.size and int(visible.max())-int(visible.min())>8,(name,f,'contrast')
                box=tile.getbbox()
                if not suffix:
                    assert box[0]>=2 and box[1]>=2 and box[2]<=w-2 and box[3]<=h-2,(name,f,box)
                    if name=='rod_planted':
                        assert 176<=box[3]<=185,(name,f,'ground',box)
                    if name=='jar_fly':
                        assert 40<=max(box[2]-box[0],box[3]-box[1])<=60,(name,f,box)
                hashes.add(hashlib.sha256(tile.tobytes()).digest())
                sheet.paste(tile,((f%cols)*tw,(f//cols)*th))
                if not suffix:
                    if name=='rod_planted': pos=(f*128,0) if f<8 else ((f-8)*128,192)
                    elif name=='jar_fly': pos=(256+f*64,224)
                    else: pos=((f%2)*512,320+(f//2)*320)
                    if name=='rod_planted' or name=='jar_fly': contact.alpha_composite(tile,pos)
                    elif f in (0,3,4,5):
                        idx=(0,3,4,5).index(f)
                        contact.alpha_composite(tile,((idx%2)*512,320+(idx//2)*320))
            assert len(hashes)==cols*rows,(name,suffix,'duplicate frames')
            path=target/f'{name}{suffix}.png'
            sheet.save(path,optimize=True,compress_level=9)
            assert path.stat().st_size<=500000,(path,path.stat().st_size)
            assert not list(target.glob('*_n.png'))
            total+=path.stat().st_size
    contact.save(RAW/'controle.png',optimize=True)
    print(f'PASS dimensions alpha contrast margins distinct frames: 24; PNG: 4; bytes: {total}; control: 1024x960')


if __name__=='__main__':
    pack() if '--pack' in sys.argv else render()
