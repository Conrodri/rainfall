"""Capsule d'argent (fut metallique) : etats closed / open, diffus + normales + emission.
Blender 5.2, Eevee, 24 echantillons. Lancer en arriere-plan (une seule instance a la fois) :
  "C:\\Program Files\\Blender Foundation\\Blender 5.2\\blender.exe" --background --python art/tools/props/capsule.py
Sorties : art/blender/props/gold_capsule.blend ; art/renders/gold_capsule/<pose>[_n|_e]/x_00.png
Assemblage : art/tools/pack.py props gold_capsule 128 closed:1:noloop open:1:noloop  (voir art/briefs/capsules.md)
Le modele est reconstruit de zero a chaque lancement (le .blend est un resultat, pas une source).
"""
import bpy, math, sys, json
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view

BASE = Path(r'C:\Users\const\Documents\Rainfall\art')
BLEND = BASE / 'blender/props/gold_capsule.blend'
NAME = 'gold_capsule'
SIZE = 128            # cote final de la frame (px)
FOOT = 0.22           # le pied du fut est a 22 % de la hauteur depuis le bas de la frame
SAMPLES = 24
sys.path.insert(0, str(BASE / 'tools'))


def srgb(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in c]


def mat(n, h, e=0.0, metal=0.0, rough=.5, emissive=False):
    c = srgb(h)
    m = bpy.data.materials.new(n)
    m.diffuse_color = (*c, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    for k, v in [('Base Color', (*c, 1)), ('Roughness', rough), ('Metallic', metal),
                 ('Emission Color', (*c, 1)), ('Emission Strength', e)]:
        p.inputs[k].default_value = v
    m['rainfall_emissive'] = bool(emissive)
    return m


def empty(n, loc=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(n, None)
    bpy.context.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    return o


def cyl(n, loc, r, dep, m, parent=None, bev=.02, rot=(0, 0, 0), verts=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=dep)
    o = bpy.context.object
    o.name = n
    o.parent = parent
    o.location = loc
    o.rotation_euler = rot
    o.data.materials.append(m)
    if bev:
        b = o.modifiers.new('Rounded rim', 'BEVEL')
        b.width = bev
        b.segments = 3
    o.modifiers.new('Normals', 'WEIGHTED_NORMAL')
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cube(n, loc, dim, m, parent=None, bev=.02):
    bpy.ops.mesh.primitive_cube_add()
    o = bpy.context.object
    o.name = n
    o.dimensions = dim
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.parent = parent
    o.location = loc
    o.data.materials.append(m)
    if bev:
        b = o.modifiers.new('Soft edges', 'BEVEL')
        b.width = bev
        b.segments = 3
        o.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return o


def tube(name, outer, inner, bottom, top, material, parent):
    verts=[]
    for z,r in ((bottom,outer),(top,outer),(top,inner),(bottom,inner)):
        verts.extend((r*math.cos(i*math.tau/64),r*math.sin(i*math.tau/64),z) for i in range(64))
    faces=[]
    for ring in range(4):
        for i in range(64):
            j=(i+1)%64; nxt=(ring+1)%4
            faces.append((ring*64+i,ring*64+j,nxt*64+j,nxt*64+i))
    me=bpy.data.meshes.new(name); me.from_pydata(verts,[],faces); me.update()
    o=bpy.data.objects.new(name,me); bpy.context.collection.objects.link(o)
    o.parent=parent; me.materials.append(material)
    for f in me.polygons: f.use_smooth=True
    b=o.modifiers.new('Machined lip','BEVEL'); b.width=.008; b.segments=3
    o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o


def setup_scene():
    s = bpy.context.scene
    ids = [v.identifier for v in s.render.bl_rna.properties['engine'].enum_items]
    s.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in ids else 'BLENDER_EEVEE'
    if hasattr(s, 'eevee'):
        s.eevee.taa_render_samples = SAMPLES
    s.render.film_transparent = True
    s.render.image_settings.file_format = 'PNG'
    s.render.image_settings.color_mode = 'RGBA'
    s.view_settings.view_transform = 'Standard'
    s.view_settings.look = 'None'
    s.view_settings.exposure = 0
    s.view_settings.gamma = 1
    s.world = bpy.data.worlds.new('Rainfall ambient')
    s.world.use_nodes = True
    bg = s.world.node_tree.nodes['Background']
    bg.inputs[0].default_value = (.30, .36, .46, 1)   # ciel froid : le metal y puise ses reflets
    bg.inputs[1].default_value = 1.0
    # Eclairage du STYLE.md : soleil tiede haut-gauche, remplissage froid, rim froid.
    for name, loc, power, color, kind, size, target in [
            ('Warm upper left', (-3, -4, 6), 3.0, (1, .886, .753), 'SUN', .15, .55),
            ('Cool fill', (3, -2, 4), 220, (.56, .66, .78), 'AREA', 4, .5),
            ('Cold rim #9FB8D8', (2, 3, 4), 330, (.624, .722, .847), 'AREA', 2.5, .55)]:
        d = bpy.data.lights.new(name, kind)
        d.energy = power
        d.color = color
        if kind == 'SUN':
            d.angle = size
        else:
            d.shape = 'DISK'
            d.size = size
        o = bpy.data.objects.new(name, d)
        s.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = (Vector((0, 0, target)) - o.location).to_track_quat('-Z', 'Y').to_euler()
    # Camera orthographique, elevation 35 deg (STYLE.md), azimut fixe, regarde vers +Y (haut de l'ecran).
    el = math.radians(35)
    d = bpy.data.cameras.new('Fixed orthographic 35deg')
    cam = bpy.data.objects.new('Camera', d)
    s.collection.objects.link(cam)
    t = Vector((0, 0, .55))
    cam.location = t + Vector((0, -6 * math.cos(el), 6 * math.sin(el)))
    cam.rotation_euler = (t - cam.location).to_track_quat('-Z', 'Y').to_euler()
    d.type = 'ORTHO'
    d.clip_end = 50
    s.camera = cam
    s.render.resolution_percentage = 100
    # Contour sombre 1 px, genere par le compositeur Blender.
    nt = bpy.data.node_groups.new('Capsule contour compositor', 'CompositorNodeTree')
    s.compositing_node_group = nt
    rl = nt.nodes.new('CompositorNodeRLayers')
    dil = nt.nodes.new('CompositorNodeDilateErode')
    dil.inputs['Size'].default_value = 1
    nt.links.new(rl.outputs['Alpha'], dil.inputs[0])
    rgba = nt.nodes.new('CompositorNodeRGB')
    rgba.outputs[0].default_value = (.0103, .008, .0144, 1)
    sa = nt.nodes.new('CompositorNodeSetAlpha')
    nt.links.new(rgba.outputs[0], sa.inputs[0])
    nt.links.new(dil.outputs[0], sa.inputs[1])
    over = nt.nodes.new('CompositorNodeAlphaOver')
    nt.links.new(sa.outputs[0], over.inputs['Background'])
    nt.links.new(rl.outputs['Image'], over.inputs['Foreground'])
    nt.interface.new_socket(name='Image', in_out='OUTPUT', socket_type='NodeSocketColor')
    out = nt.nodes.new('NodeGroupOutput')
    nt.links.new(over.outputs[0], out.inputs[0])
    return s


GLOW = []   # (materiau, couleur vive, force vive)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = setup_scene()
    silver = mat('Silver #C9D1DC', 'C9D1DC', 0, .9, .30)
    steel = mat('Dark steel #4A5565', '4A5565', 0, .8, .38)
    slate = mat('Slate #2B3340', '2B3340', 0, .6, .5)
    dark = mat('Cavity #1A1620', '1A1620', 0, 0, .9)
    gold = mat('Core gold glow #F2C14E', 'F2C14E', 2.2, .3, .3, emissive=True)
    gold_hi = mat('Core gold core #FFE9A8', 'FFE9A8', 2.8, .0, .4, emissive=True)
    GLOW.extend([(gold, 2.2), (gold_hi, 2.8)])

    root = empty(NAME)
    # Socle et corps du fut
    cyl('Plinth', (0, 0, .06), .56, .12, slate, root, .025)
    tube('Barrel body', .50, .445, .11, 1.05, silver, root)
    for z in (.26, .90):
        cyl('Steel hoop', (0, 0, z), .535, .09, steel, root, .02)
    for z in (.26, .90):   # rivets sur les cerceaux
        for k in range(8):
            a = k * math.tau / 8 + .2
            cyl('Rivet', (.535 * math.cos(a), .535 * math.sin(a), z), .025, .03, silver, root, .006, rot=(math.pi/2, 0, a-math.pi/2), verts=16)
    tube('Top collar', .52, .435, 1.035, 1.085, steel, root)
    # Anneau lumineux dore autour du col (la "lueur") et pastille frontale
    tube('Glow ring', .515, .445, 1.0025, 1.0375, gold, root)
    cyl('Cavity floor', (0, 0, .30), .443, .02, dark, root, .0, verts=48)
    face = cyl('Coin emblem rim', (0, -.505, .58), .22, .05, steel, root, .012, rot=(math.pi / 2, 0, 0), verts=48)
    cyl('Coin emblem glow', (0, -.532, .58), .17, .03, gold, root, .01, rot=(math.pi / 2, 0, 0), verts=48)
    cube('Coin emblem bar', (0, -.552, .58), (.07, .02, .20), gold_hi, root, .006)
    # Couvercle a charniere arriere
    hinge = empty('Lid hinge', (0, .46, 1.10), root)
    # Fixed knuckles and moving leaves share the exact same pivot axis.
    for x in (-.34, .34):
        cube('Fixed hinge bracket', (x, .46, .96), (.13, .15, .28), steel, root, .018)
        cyl('Fixed hinge knuckle', (x, .46, 1.10), .085, .16, silver, root, .012, rot=(0, math.pi/2, 0))
        cube('Moving lid hinge leaf', (x, -.10, .025), (.115, .26, .07), steel, hinge, .012)
    cyl('Continuous hinge axle', (0, .46, 1.10), .045, .87, steel, root, .009, rot=(0, math.pi/2, 0))
    for x in (-.445, .445):
        cyl('Hinge axle cap', (x, .46, 1.10), .066, .035, silver, root, .008, rot=(0, math.pi/2, 0))
    cyl('Lid plate', (0, -.46, .03), .49, .07, silver, hinge, .03)
    cyl('Lid rim', (0, -.46, .005), .515, .045, steel, hinge, .015)
    cube('Lid handle', (0, -.82, .10), (.30, .09, .075), steel, hinge, .02)
    for x in (-.17, .17):
        cube('Handle post', (x, -.82, .06), (.05, .09, .08), steel, hinge, .01)
    cyl('Lid gold boss', (0, -.46, .085), .12, .03, gold, hinge, .012, verts=32)
    cube('Hinge barrel', (0, .03, .015), (.34, .07, .07), steel, hinge, .015)
    # Fente de pieces lumineuse sur le couvercle (visible fermee)
    cube('Lid slot glow', (0, -.46, .072), (.30, .05, .02), gold_hi, hinge, .004)
    # Interieur du couvercle (visible ouvert) : doublure sombre
    cyl('Lid lining', (0, -.46, -.015), .43, .02, dark, hinge, 0, verts=48)
    # Quelques rayures de brosse : lignes sombres fines sur le fut
    for k in range(6):
        a = math.radians(-70 + k * 28)
        cyl('Brush line', (.505 * math.sin(a), -.505 * math.cos(a), .58), .006, .80, steel, root, 0, verts=8)

    # Pas de rotation du modele : un seul angle, la camera est fixe.
    s['asset_name'] = NAME
    return s, root, hinge


def set_pose(s, hinge, pose):
    hinge.rotation_euler.x = math.radians(-138) if pose == 'open' else 0
    for m, strength in GLOW:
        p = m.node_tree.nodes['Principled BSDF']
        if pose == 'open':    # fut vide : plus de lueur
            p.inputs['Emission Strength'].default_value = 0.0
            p.inputs['Base Color'].default_value = (*srgb('7C8898'), 1)
            m['rainfall_emissive'] = False
        else:
            p.inputs['Emission Strength'].default_value = strength
            c = srgb('F2C14E' if 'gold glow' in m.name else 'FFE9A8')
            p.inputs['Base Color'].default_value = (*c, 1)
            m['rainfall_emissive'] = True
    bpy.context.view_layer.update()


def descendants(r):
    return [r] + list(r.children_recursive)


def fit(s, root, hinge):
    """Ortho scale et shift_y communs aux deux poses : pied a FOOT du bas, marges >= 4 px."""
    cam = s.camera
    cam.data.ortho_scale = 4
    cam.data.shift_y = 0
    bpy.context.view_layer.update()
    y0 = world_to_camera_view(s, cam, Vector((0, 0, 0))).y
    cam.data.shift_y = y0 - FOOT
    need = 0.0
    for pose in ('closed', 'open'):
        set_pose(s, hinge, pose)
        for o in descendants(root):
            if o.type != 'MESH':
                continue
            for v in o.data.vertices:
                q = world_to_camera_view(s, cam, o.matrix_world @ v.co)
                need = max(need, 4 * abs(q.x - .5) / (.5 - .045),
                           4 * (q.y - FOOT) / (1 - .03 - FOOT),
                           4 * (FOOT - q.y) / max(FOOT - .035, .01))
    cam.data.ortho_scale = need
    bpy.context.view_layer.update()
    y0 = world_to_camera_view(s, cam, Vector((0, 0, 0))).y
    cam.data.shift_y = y0 - FOOT
    root['ortho_scale'] = need
    return need


def downsample_lanczos(im, size):
    import numpy as np
    a = np.array(im.pixels[:], dtype=np.float32).reshape(size * 2, size * 2, 4)
    a[:, :, :3] *= a[:, :, 3:4]
    pos = (np.arange(size) + .5) * 2 - .5
    ix = np.floor(pos[:, None]).astype(int) + np.arange(-5, 7)[None, :]
    delta = (pos[:, None] - ix) / 2
    w = np.sinc(delta) * np.sinc(delta / 3)
    w[np.abs(delta) >= 3] = 0
    w /= w.sum(axis=1, keepdims=True)
    ix = ix.clip(0, size * 2 - 1)
    a = (a[:, ix, :] * w[None, :, :, None]).sum(axis=2)
    a = (a[ix, :, :] * w[:, :, None, None]).sum(axis=1)
    a[:, :, 3] = a[:, :, 3].clip(0, 1)
    a[:, :, :3] /= np.maximum(a[:, :, 3:4], 1e-7)
    a = a.clip(0, 1)
    a[a[:, :, 3] < .02] = 0
    a[:, :, 3][a[:, :, 3] > .98] = 1
    out = bpy.data.images.new('Lanczos final', width=size, height=size, alpha=True, float_buffer=False)
    out.pixels.foreach_set(a.astype(np.float32).ravel())
    out.file_format = 'PNG'
    out.update()
    bpy.data.images.remove(im)
    return out


def render_diffuse(s, hinge, pose):
    set_pose(s, hinge, pose)
    s.render.resolution_x = s.render.resolution_y = SIZE * 2
    raw = BASE / 'renders/gold_capsule/_raw' / pose / 'x_00.png'
    final = BASE / 'renders' / NAME / pose / 'x_00.png'
    for p in (raw, final):
        p.parent.mkdir(parents=True, exist_ok=True)
    s.render.filepath = str(raw)
    bpy.ops.render.render(write_still=True)
    im = bpy.data.images.load(str(raw), check_existing=False)
    im.pixels[:]
    im = downsample_lanczos(im, SIZE)
    im.filepath_raw = str(final)
    im.save()
    bpy.data.images.remove(im)
    return final


def render_aux(s, hinge, pose, emission):
    import numpy as np
    import passes
    for m in [m for m in bpy.data.materials if m.name.startswith('_Rainfall')]:
        bpy.data.materials.remove(m)   # sinon le cache d'emission de la pose precedente est reutilise
    set_pose(s, hinge, pose)
    s.render.resolution_x = s.render.resolution_y = SIZE
    diffuse = BASE / 'renders' / NAME / pose / 'x_00.png'
    target = BASE / 'renders' / NAME / (pose + ('_e' if emission else '_n')) / 'x_00.png'
    (passes.render_emission_pass if emission else passes.render_normal_pass)(target, diffuse, s)
    if not emission:   # renormalisation + remplissage neutre du fond
        im = bpy.data.images.load(str(target), check_existing=False)
        im.colorspace_settings.name = 'Non-Color'
        im.alpha_mode = 'STRAIGHT'
        a = np.array(im.pixels[:], dtype=np.float32).reshape(-1, 4)
        v = a[:, :3] * 2 - 1
        v /= np.maximum(np.linalg.norm(v, axis=1, keepdims=True), 1e-8)
        a[:, :3] = v * .5 + .5
        a[a[:, 3] == 0, :3] = (128 / 255, 128 / 255, 1)
        im.pixels.foreach_set(a.ravel())
        im.filepath_raw = str(target)
        im.save()
        bpy.data.images.remove(im)


def main():
    s, root, hinge = build()
    scale = fit(s, root, hinge)
    print('ortho_scale', scale)
    set_pose(s, hinge, 'closed')
    BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    for pose in ('closed', 'open'):
        render_diffuse(s, hinge, pose)
    for pose in ('closed', 'open'):
        render_aux(s, hinge, pose, False)
        render_aux(s, hinge, pose, True)
    set_pose(s, hinge, 'closed')
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    import shutil
    dest=BASE.parent/'game/assets/sprites/props/gold_capsule'
    for pose in ('closed','open'):
        for suffix in ('','_n','_e'):
            shutil.copyfile(BASE/'renders'/NAME/(pose+suffix)/'x_00.png',dest/(pose+suffix+'.png'))
    print('OK', json.dumps({'size': SIZE, 'poses': ['closed', 'open']}))


main()
