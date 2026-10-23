"""Props fog_forest / rust_city (Design_Boss_Cartes §5.4). Blender arriere-plan uniquement :
blender.exe --background --python props_biomes.py -- [--only nom ...]
Reutilise les helpers de props.py (camera ortho 55 deg, Sun #FFE2C0 + fill #8FA8C8, normale OpenGL, masque _e).
Rendu 2x dans art/renders/terrain/props_biomes/<biome>/<nom>/00(.png|_n|_e) ; assemble_biome_props.py reduit (LANCZOS).
64 px/u. Frames : cedar_giant 384 (tronc ~384 px de haut), tank_large 320, ticket_booth/bell/tank_small/lantern_shrine/standing_stone/root_arch* 192, catwalk 256, autres 128.
"""
import bpy, math, sys, random, argparse
from pathlib import Path
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parent))
import props as P
ROOT = P.ROOT
RAW = ROOT / 'art/renders/terrain/props_biomes'
rgb = P.rgb; mat = P.mat; box = P.box; sphere = P.sphere; cyl = P.cyl; line = P.line; ring = P.ring


def pal():
    return dict(
        bark=mat('Cedar bark', '4A3C30'), bark2=mat('Dark bark', '30281F'), moss=mat('Moss', '4E6046'), lichen=mat('Lichen', '6E7A62'),
        rim=mat('Pale edge', '9A8C6A'), stone=mat('Wet stone', '5A6460'), stone2=mat('Dark stone', '3E4846'), needles=mat('Cedar canopy', '26382F'),
        cap1=mat('Cap A', 'A89A82'), cap2=mat('Cap B', '7A6A58'), stem=mat('Stem', 'C8C0A8'), wood=mat('Shrine wood', '3A3028'),
        mint=mat('Lantern mint', '9CF0C8', 0, 3),
        steel=mat('Dark steel', '3A4248', .12), rust=mat('Muted rust', '7A5846', .08), iron=mat('Iron', '5C6870', .15),
        conc=mat('Wet concrete', '555B5E'), pale=mat('Pale metal edge', 'B4B9B4', .1), brass=mat('Brass', '8C7A4C', .3),
        plank=mat('Crate wood', '5E5043'), cable=mat('Cable', '23282B'), cable2=mat('Cable red', '5A3A36'), glass=mat('Dark glass', '1C2428', .2),
        lamp=mat('Steam lamp', 'FFC27A', 0, 3), wheel=mat('Valve wheel', '8A5444', .1), grate=mat('Grating', '566066', .15))


# ------------------------------------------------------------------ fog_forest
def cedar_giant(p):
    cyl((0, 0, 2.3), 1.0, 4.6, p['bark'], .72, vertices=24)
    rng = random.Random(3)
    for i in range(16):  # lames d'ecorce
        a = i * math.tau / 16
        cyl((.93 * math.cos(a) * .98, .93 * math.sin(a) * .98, 2.3), .14, 4.5, p['bark2'] if i % 3 == 0 else p['bark'], .09, vertices=8)
    for i in range(7):  # racines evasees
        a = i * math.tau / 7 + .3
        pts = [(.6 * math.cos(a), .6 * math.sin(a), .95), (1.15 * math.cos(a), 1.15 * math.sin(a), .35), (1.85 * math.cos(a + .1), 1.85 * math.sin(a + .1), .06)]
        line(pts, .26, p['bark'])
        sphere((1.0 * math.cos(a), 1.0 * math.sin(a), .55), (.3, .3, .12), p['moss'])
    for x, y, z in [(0, .0, 4.6), (.7, .2, 4.35), (-.7, -.1, 4.3), (.2, .6, 4.9), (-.3, -.5, 4.8)]:
        sphere((x, y, z), (1.05, .95, .55), p['needles'])
    sphere((0, -.6, 1.6), (.5, .3, .6), p['moss'])


def arch(p, kind):
    def tw(pts, r, m=None):
        line(pts, r, m or p['bark'])
    for k, dy in enumerate((-.12, .0, .13)):
        r = .2 - k * .02
        if kind == 'a':   pts = [(-1.5, dy, .05), (-1.1, dy, .35), (-.2, dy + .05, .95), (1.5, dy, 1.25)]
        elif kind == 'b': pts = [(-1.5, dy, 1.25), (-.5, dy + .08, 1.35), (.5, dy - .06, 1.15), (1.5, dy, 1.25)]
        elif kind == 'c': pts = [(-1.5, dy, 1.25), (.2, dy + .05, .95), (1.1, dy, .35), (1.5, dy, .05)]
        else:             pts = [(-1.5, dy, 1.25), (-.3, dy, 1.3), (.3 - dy * 2, -.6, 1.0), (.3 - dy * 2, -1.5, .1)]
        tw(pts, r)
    if kind in 'ac' or kind == 'corner':
        for x in ((-1.45,) if kind in ('a', 'corner') else (1.45,)): sphere((x, 0, .15), (.45, .4, .2), p['moss'])
    sphere((0, .05, 1.28 if kind != 'a' else .95), (.5, .2, .1), p['moss'])
    tw([(-1.3, .1, 1.1), (-.6, .25, 1.35)], .07, p['bark2']) if kind == 'b' else None


def lantern_shrine(p):
    cyl((0, 0, .1), .55, .2, p['stone'], vertices=8); box((0, 0, .3), (.7, .7, .2), p['stone2'])
    for x in (-.3, .3):
        for y in (-.3, .3): box((x, y, .85), (.1, .1, .9), p['wood'])
    box((0, 0, .85), (.34, .34, .46), p['mint'])
    box((0, 0, 1.33), (.78, .78, .08), p['wood'])
    cyl((0, 0, 1.62), .62, .5, p['wood'], .1, vertices=4)
    cyl((0, 0, 1.92), .1, .2, p['rim'], .04, vertices=8)
    box((-.2, -.42, .22), (.4, .1, .06), p['rim'])


def mushrooms(p):
    rng = random.Random(7)
    for i, (x, y, s) in enumerate([(0, 0, 1), (.5, .25, .7), (-.45, .15, .75), (.25, -.4, .55), (-.2, -.45, .5)]):
        cyl((x, y, .22 * s), .09 * s, .44 * s, p['stem'], vertices=10)
        sphere((x, y, .46 * s), (.3 * s, .3 * s, .17 * s), p['cap1'] if i % 2 == 0 else p['cap2'])
    sphere((0, 0, .02), (.75, .55, .04), p['moss'])


def stump(p):
    cyl((0, 0, .32), .62, .64, p['bark'], .55, vertices=16)
    cyl((0, 0, .66), .52, .04, p['rim'], vertices=16)
    ring((0, 0, .685), .3, .018, p['bark2']); ring((0, 0, .685), .16, .014, p['bark2'])
    for i in range(5):
        a = i * math.tau / 5 + .4; line([(.45 * math.cos(a), .45 * math.sin(a), .35), (.9 * math.cos(a), .9 * math.sin(a), .04)], .13, p['bark'])
    sphere((.2, -.3, .67), (.28, .2, .035), p['moss'])


def standing_stone(p):
    box((0, 0, .85), (.7, .45, 1.7), p['stone'], )
    cyl((0, 0, 1.78), .38, .3, p['stone'], .2, vertices=4)
    for z, w in ((.7, .26), (1.0, .18), (1.3, .26)): box((-.02, -.235, z), (w, .02, .035), p['rim'])
    sphere((0, 0, .08), (.62, .45, .12), p['moss']); sphere((.15, -.1, .18), (.34, .25, .12), p['lichen'])


# ------------------------------------------------------------------ rust_city
def steam_lamp(p):
    cyl((0, 0, .06), .3, .12, p['steel'], vertices=8); cyl((0, 0, .9), .07, 1.6, p['iron'], vertices=10)
    line([(0, 0, 1.6), (.2, 0, 1.78), (.42, 0, 1.7)], .06, p['iron'])
    cyl((.45, 0, 1.55), .17, .2, p['steel'], .12, vertices=12); sphere((.45, 0, 1.42), (.13, .13, .13), p['lamp'])
    ring((0, 0, .5), .1, .02, p['pale']); ring((0, 0, 1.05), .1, .02, p['pale'])


def valve(p):
    cyl((0, 0, .32), .17, 1.8, p['iron'], vertices=14).rotation_euler.y = math.pi / 2
    box((0, 0, .17), (.4, .4, .12), p['steel'])
    cyl((0, 0, .4), .08, .5, p['steel'], vertices=10)
    ring((0, 0, .72), .3, .035, p['wheel'])
    for i in range(4):
        a = i * math.pi / 2; line([(0, 0, .72), (.3 * math.cos(a), .3 * math.sin(a), .72)], .028, p['wheel'])
    for x in (-.55, .55): ring((x, 0, .32), .2, .03, p['pale']).rotation_euler.y = math.pi / 2


def ticket_booth(p):
    box((0, 0, .55), (1.5, 1.0, 1.1), p['conc']); box((0, -.52, .75), (.9, .06, .5), p['glass'])
    box((0, -.6, .46), (1.1, .2, .06), p['pale']); box((0, 0, 1.15), (1.75, 1.25, .12), p['steel'])
    box((-.8, -.5, .2), (.06, .08, .4), p['rust']); box((.55, -.52, .3), (.3, .04, .45), p['rust'])
    for x in (-.55, .55): box((x, -.54, .98), (.1, .04, .22), p['pale'])
    box((.5, .5, 1.45), (.3, .3, .35), p['iron'])


def crate(p):
    box((0, 0, .4), (.8, .8, .8), p['plank'])
    for z in (.1, .7): box((0, 0, z), (.84, .84, .1), p['steel'])
    for x in (-.37, .37):
        for y in (-.37, .37): box((x, y, .4), (.1, .1, .84), p['steel'])
    box((0, -.41, .4), (.6, .02, .1), p['pale'], ); box((.05, 0, .82), (.5, .5, .04), p['rim'] if False else p['plank'])


def cables(p):
    rng = random.Random(4)
    for i, c in enumerate((p['cable'], p['cable2'], p['cable'])):
        y = -.25 + i * .22
        line([(-.9, y, .07), (-.35, y + .3, .07), (.1, y - .25, .12), (.5, y + .2, .08), (.9, y - .1, .1)], .07, c)
    box((.0, 0, .18), (.18, .7, .22), p['steel']); box((-.55, 0, .12), (.16, .6, .14), p['steel'])
    box((.8, .1, .3), (.4, .4, .5), p['iron'])


def bell(p):
    for x in (-.8, .8): line([(x, 0, 0), (x * .35, 0, 1.5)], .09, p['iron']); box((x, 0, .05), (.4, .5, .1), p['conc'])
    box((0, 0, 1.55), (1.0, .14, .12), p['iron'])
    cyl((0, 0, .9), .62, .95, p['brass'], .22, vertices=24); sphere((0, 0, 1.35), (.24, .24, .12), p['brass'])
    ring((0, 0, .45), .6, .04, p['brass']); sphere((0, 0, .42), (.1, .1, .1), p['iron'])
    line([(0, 0, 1.55), (0, 0, 1.4)], .03, p['iron'])


def _tank(p, r, h):
    cyl((0, 0, h / 2), r, h, p['iron'], vertices=32)
    cyl((0, 0, h + .05), r * .96, .1, p['steel'], vertices=32)
    for z in (h * .25, h * .6, h * .9): ring((0, 0, z), r * 1.005, .035, p['rust'])
    for i in range(10):
        a = i * math.tau / 10 + .2; cyl((r * math.cos(a) * 1.0, r * math.sin(a), h / 2), .045, h * .96, p['steel'], vertices=6)
    cyl((r * .55, -r * .3, h + .22), r * .16, .3, p['steel'], vertices=12)
    line([(r * .95, 0, h * .3), (r * 1.25, 0, h * .3), (r * 1.25, 0, .05)], .08, p['pale'])
    box((0, -r * .98, h * .35), (r * .5, .06, h * .3), p['rust'])


def tank_small(p): _tank(p, .85, 1.5)
def tank_large(p): _tank(p, 1.5, 2.3)


def catwalk(p):
    box((0, 0, .5), (3.0, 1.3, .1), p['grate'])
    for i in range(-7, 8): box((i * .2, 0, .56), (.05, 1.28, .03), p['pale'])
    for y in (-.62, .62):
        box((0, y, .52), (3.0, .08, .14), p['steel'])
        for x in (-1.4, -.7, 0, .7, 1.4): box((x, y, .82), (.07, .07, .62), p['iron'])
        box((0, y, 1.12), (3.0, .07, .07), p['pale'])
        box((0, y, .85), (3.0, .04, .04), p['iron'])
    for x in (-1.3, 1.3):
        for y in (-.55, .55): box((x, y, .22), (.12, .12, .5), p['steel'])


SPECS = {  # nom -> (biome, fn, frame px, emission?, centre fixe ou None)
    'cedar_giant': ('fog_forest', cedar_giant, 384, False, None),
    'root_arch_a': ('fog_forest', lambda p: arch(p, 'a'), 256, False, .5), 'root_arch_b': ('fog_forest', lambda p: arch(p, 'b'), 256, False, .5),
    'root_arch_c': ('fog_forest', lambda p: arch(p, 'c'), 256, False, .5), 'root_arch_corner': ('fog_forest', lambda p: arch(p, 'corner'), 256, False, .5),
    'lantern_shrine': ('fog_forest', lantern_shrine, 192, True, None), 'mushrooms': ('fog_forest', mushrooms, 128, False, None),
    'stump': ('fog_forest', stump, 128, False, None), 'standing_stone': ('fog_forest', standing_stone, 192, False, None),
    'steam_lamp': ('rust_city', steam_lamp, 128, True, None), 'valve': ('rust_city', valve, 128, False, None),
    'ticket_booth': ('rust_city', ticket_booth, 192, False, None), 'crate': ('rust_city', crate, 128, False, None),
    'cables': ('rust_city', cables, 128, False, None), 'bell': ('rust_city', bell, 192, False, None),
    'tank_small': ('rust_city', tank_small, 192, False, None), 'tank_large': ('rust_city', tank_large, 320, False, None),
    'catwalk': ('rust_city', catwalk, 256, False, .5)}


def build(name):
    biome, fn, size, emit, fixed = SPECS[name]
    s = P.setup(name, size, size / 64.0 * 1.12)
    p = pal(); fn(p)
    from _r6b_detail import enrich
    enrich(P, name, p)
    s.eevee.taa_render_samples = 32
    bpy.context.view_layer.update()
    meshes = [o for o in s.objects if o.type in ('MESH', 'CURVE')]
    inv = s.camera.rotation_euler.to_matrix().transposed()
    if fixed is None:
        pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
        ys = [(inv @ v).y for v in pts]; center = (max(ys) + min(ys)) / 2
    else: center = fixed
    s.camera.location += s.camera.rotation_euler.to_matrix() @ Vector((0, 1, 0)) * center
    folder = RAW / biome / name; folder.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    dest = ROOT / 'art/blender/terrain' / ('props_%s_%s.blend' % (biome, name)); bpy.ops.wm.save_as_mainfile(filepath=str(dest))
    for mode in ('beauty', 'normal', 'mask') if emit else ('beauty', 'normal'):
        for m in bpy.data.materials:
            if not m.use_nodes: continue
            n = m.node_tree.nodes; m.node_tree.links.new(n[mode].outputs[0], n.get('Material Output').inputs['Surface'])
        s.view_settings.view_transform = 'Raw' if mode == 'normal' else 'Standard'
        suf = '' if mode == 'beauty' else '_n' if mode == 'normal' else '_e'
        s.render.filepath = str(folder / ('00' + suf + '.png')); bpy.ops.render.render(write_still=True)


if __name__ == '__main__':
    a = argparse.ArgumentParser(); a.add_argument('--only', nargs='*')
    args = a.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    for n in args.only or SPECS:
        build(n); print('DONE', n, flush=True)
