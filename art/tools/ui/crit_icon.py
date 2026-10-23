"""Icone de coup critique (etoile d'impact + '!'), 128x128 RGBA, sans normal map.
Lancer : blender.exe --background --python art/tools/ui/crit_icon.py
Sortie : game/assets/sprites/ui/crit_icon.png ; .blend : art/blender/ui/crit_icon.blend
"""
import bpy, bmesh, math, os
from mathutils import Vector

ROOT = r"C:\Users\const\Documents\Rainfall"
OUT = os.path.join(ROOT, "game", "assets", "sprites", "ui", "crit_icon.png")
RAW = os.path.join(ROOT, "art", "renders", "ui", "crit_icon_raw.png")
os.makedirs(os.path.dirname(RAW), exist_ok=True)
BLEND = os.path.join(ROOT, "art", "blender", "ui", "crit_icon.blend")

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

def mat(name, hexcol, emit=0.9):
    c = [int(hexcol[i:i+2], 16) / 255 for i in (1, 3, 5)]
    c = [x ** 2.2 for x in c]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*c, 1)
    b.inputs["Roughness"].default_value = 0.5
    b.inputs["Emission Color"].default_value = (*c, 1)
    b.inputs["Emission Strength"].default_value = emit
    return m

def star(name, n, r_out, r_in, depth, z, m, bevel=0.02, rot=0.0):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = rot + math.pi * i / n
        vs.append(bm.verts.new((r * math.cos(a), r * math.sin(a), 0)))
    f = bm.faces.new(vs)
    r = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [x for x in r["geom"] if isinstance(x, bmesh.types.BMVert)]:
        v.co.z += depth
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
    o.location.z = z
    o.data.materials.append(m)
    bv = o.modifiers.new("bev", 'BEVEL'); bv.width = bevel; bv.segments = 2
    return o

def box(name, size, loc, m, taper=None, bevel=0.03):
    me = bpy.data.meshes.new(name); bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]; v.co.y *= size[1]; v.co.z *= size[2]
        if taper and v.co.y > 0: v.co.x *= taper
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); sc.collection.objects.link(o)
    o.location = loc; o.data.materials.append(m)
    bv = o.modifiers.new("bev", 'BEVEL'); bv.width = bevel; bv.segments = 2
    return o

def ex(prefix, grow, zoff, mw, mk, depth):
    """barre + point du '!' ; grow elargit pour le contour"""
    box(prefix + "_bar", (0.64 + grow, 1.10 + grow, depth), (0, 0.30, zoff), mw, taper=0.62)
    box(prefix + "_dot", (0.46 + grow, 0.40 + grow, depth), (0, -0.66, zoff), mw)

DARK = mat("dark", "#2A0C08", 0.25)
RED = mat("red", "#FF5230", 0.15)
YEL = mat("yel", "#FF9B35", 0.25)
WHT = mat("wht", "#FFFFFF", 0.9)

# etoile : contour sombre, corps rouge-orange, coeur jaune
star("outline", 8, 2.30, 1.12, 0.10, 0.00, DARK, bevel=0.03)
star("body", 8, 2.08, 0.96, 0.22, 0.10, RED, bevel=0.05)
star("core", 8, 1.30, 0.72, 0.18, 0.32, YEL, bevel=0.05, rot=math.pi / 8)
# '!' : contour sombre puis blanc en relief
ex("exo", 0.16, 0.50, DARK, DARK, 0.20)
ex("exw", 0.0, 0.62, WHT, WHT, 0.24)

# lumiere douce pour le relief
sun = bpy.data.lights.new("sun", 'SUN'); sun.energy = 1.4
so = bpy.data.objects.new("sun", sun); sc.collection.objects.link(so)
so.rotation_euler = (math.radians(35), math.radians(-25), math.radians(20))
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (1, 1, 1, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
sc.world = w

cam = bpy.data.cameras.new("cam"); cam.type = 'ORTHO'; cam.ortho_scale = 5.3
co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co)
co.location = (0, 0, 10); sc.camera = co

sc.render.engine = 'BLENDER_EEVEE'
sc.eevee.taa_render_samples = 24
sc.render.resolution_x = sc.render.resolution_y = 256
sc.render.film_transparent = True
sc.view_settings.view_transform = 'Standard'
sc.render.image_settings.file_format = 'PNG'
sc.render.image_settings.color_mode = 'RGBA'
sc.render.filepath = RAW
bpy.ops.render.render(write_still=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=BLEND)

# Reduction Lanczos externe : Pillow est installe dans le Python systeme.
import subprocess
subprocess.run([r'C:\Users\const\AppData\Local\Python\bin\python.exe',
                os.path.join(ROOT, 'art', 'tools', 'ui', 'assemble_r1.py')], check=True)
