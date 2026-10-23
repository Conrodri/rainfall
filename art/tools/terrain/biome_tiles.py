"""Tuiles de sol seamless des biomes fog_forest / rust_city + corrections terraces.
Tout est rendu par Blender (Eevee, arriere-plan) : motifs = maths periodiques (sin/cos) dans les shaders,
geometrie dupliquee a +-8 u aux bords. Vue ortho verticale 12 u / 768 px (3 periodes de 8 u) ;
check_tiles.py reduit puis recadre le centre 256 px (aucune couture, PIL = assemblage seulement).
Lancer : blender.exe --background --python biome_tiles.py -- --biome fog_forest [--only ground_moss ...]
Normales : espace monde remappe (OpenGL, Y+ = haut ecran, sol plat = 128,128,255).
"""
import bpy, math, random, sys, argparse
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
T = math.tau
P = 8.0  # periode de motif en unites


def lin(h):
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v <= .04045 else ((v + .055) / 1.055) ** 2.4 for v in c) + (1,)


def mk_mat(name, stops, terms, warp=None, mode='plain', bump=.4, dist=.1, flat=None):
    """stops: [(pos,'hex'),...] ; terms: [(kx,ky,phase,amp)] ; warp=(kx,ky,amp)."""
    m = bpy.data.materials.new(name); m.use_nodes = True
    ns = m.node_tree.nodes; ls = m.node_tree.links; ns.clear()

    def op(t, a, b=0.0, clamp=False):
        n = ns.new('ShaderNodeMath'); n.operation = t; n.use_clamp = clamp
        for i, v in enumerate((a, b)):
            if isinstance(v, (int, float)): n.inputs[i].default_value = v
            else: ls.new(v, n.inputs[i])
        return n.outputs[0]
    geo = ns.new('ShaderNodeNewGeometry')
    sep = ns.new('ShaderNodeSeparateXYZ'); ls.new(geo.outputs['Position'], sep.inputs[0])
    x, y = sep.outputs['X'], sep.outputs['Y']
    w = None
    if warp:
        wk = op('ADD', op('MULTIPLY', x, warp[0] * T / P), op('MULTIPLY', y, warp[1] * T / P))
        w = op('MULTIPLY', op('SINE', wk), warp[2])
    acc = None; tot = sum(abs(t[3]) for t in terms) or 1
    for kx, ky, ph, amp in terms:
        a = op('ADD', op('MULTIPLY', x, kx * T / P), op('MULTIPLY', y, ky * T / P))
        a = op('ADD', a, ph)
        if w is not None: a = op('ADD', a, w)
        s = op('MULTIPLY', op('SINE', a), amp / tot)
        acc = s if acc is None else op('ADD', acc, s)
    h = op('ADD', op('MULTIPLY', acc, .5), .5, True)
    # Seamless organic structure: 4D noise on a torus, all evaluated in Blender.
    def torus_noise(scale, detail):
        comb = ns.new('ShaderNodeCombineXYZ')
        ax = op('MULTIPLY', x, T / P); ay = op('MULTIPLY', y, T / P)
        for socket, value in zip(comb.inputs, (op('SINE', ax), op('COSINE', ax), op('SINE', ay))):
            ls.new(value, socket)
        noise = ns.new('ShaderNodeTexNoise'); noise.noise_dimensions = '4D'
        ls.new(comb.outputs[0], noise.inputs['Vector']); ls.new(op('COSINE', ay), noise.inputs['W'])
        noise.inputs['Scale'].default_value = scale
        noise.inputs['Detail'].default_value = detail
        noise.inputs['Roughness'].default_value = .65
        return noise.outputs['Fac']
    periodic = h
    broad = torus_noise(2.8, 3.0)
    grain = torus_noise(11.0, 2.0)
    h = op('ADD', op('MULTIPLY', h, .15), op('ADD', op('MULTIPLY', broad, .65), op('MULTIPLY', grain, .20)))
    h = op('ADD', .5, op('MULTIPLY', op('SUBTRACT', h, .5), 1.8))
    if name in ('deep', 'shallow'):
        h = op('ADD', op('MULTIPLY', periodic, .75), op('MULTIPLY', torus_noise(.9, 1.0), .25))
    if mode == 'ridge':
        h = op('POWER', op('SUBTRACT', 1.0, op('ABSOLUTE', op('MULTIPLY', op('SUBTRACT', h, .5), 2.0))), 3.0, True)
    ramp = ns.new('ShaderNodeValToRGB'); ls.new(h, ramp.inputs[0])
    els = ramp.color_ramp.elements
    while len(els) < len(stops): els.new(.5)
    for e, (pos, hx) in zip(els, stops): e.position = pos; e.color = lin(hx)
    beauty = ns.new('ShaderNodeEmission'); beauty.name = 'beauty'; ls.new(ramp.outputs[0], beauty.inputs[0])
    out = ns.new('ShaderNodeOutputMaterial'); out.name = 'out'; ls.new(beauty.outputs[0], out.inputs['Surface'])
    bp = ns.new('ShaderNodeBump'); bp.inputs['Strength'].default_value = bump; bp.inputs['Distance'].default_value = dist
    ls.new(h, bp.inputs['Height'])
    mul = ns.new('ShaderNodeVectorMath'); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = (.5, .5, .5)
    ls.new(bp.outputs['Normal'], mul.inputs[0])
    add = ns.new('ShaderNodeVectorMath'); add.operation = 'ADD'; add.inputs[1].default_value = (.5, .5, .5)
    ls.new(mul.outputs[0], add.inputs[0])
    nm = ns.new('ShaderNodeEmission'); nm.name = 'normal'; ls.new(add.outputs[0], nm.inputs[0])
    return m


def set_mode(mode):
    for m in bpy.data.materials:
        if not m.use_nodes: continue
        ns = m.node_tree.nodes
        if 'normal' in ns:
            m.node_tree.links.new(ns['normal' if mode == 'normal' else 'beauty'].outputs[0], ns['out'].inputs['Surface'])


COLL = lambda: bpy.context.scene.collection


def link(o):
    COLL().objects.link(o); return o


def plane_big(mat, z=0.0, size=26):
    me = bpy.data.meshes.new('plane'); h = size / 2
    me.from_pydata([(-h, -h, z), (h, -h, z), (h, h, z), (-h, h, z)], [], [(0, 1, 2, 3)]); me.update()
    o = bpy.data.objects.new('plane', me); link(o); me.materials.append(mat); return o


def prim(kind, x, y, z, sx, sy, sz, mat, rot=0.0, bevel=0.0, smooth=True):
    if kind == 'sphere': bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, location=(x, y, z))
    else: bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
    o = bpy.context.object; o.scale = (sx, sy, sz); o.rotation_euler.z = rot
    o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if kind == 'sphere' and smooth:
        for f in o.data.polygons: f.use_smooth = True
    if bevel:
        md = o.modifiers.new('bevel', 'BEVEL'); md.width = bevel; md.segments = 3
    return o


def tube(pts, r, mat, z=0.0):
    c = bpy.data.curves.new('tube', 'CURVE'); c.dimensions = '3D'; c.bevel_depth = r; c.bevel_resolution = 4; c.resolution_u = 3
    sp = c.splines.new('POLY'); sp.points.add(len(pts) - 1)
    for p, v in zip(sp.points, pts): p.co = (v[0], v[1], v[2] if len(v) > 2 else z, 1)
    o = bpy.data.objects.new('tube', c); link(o); c.materials.append(mat); return o


def dup(objs, offs=(-P, 0, P)):
    """Duplique chaque objet sur la grille 3x3 (liens de donnees partages)."""
    for o in list(objs):
        for dx in offs:
            for dy in offs:
                if dx == 0 and dy == 0: continue
                c = o.copy(); c.location = (o.location.x + dx, o.location.y + dy, o.location.z); link(c)


def setup_scene(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene; s.name = name
    s.render.engine = 'BLENDER_EEVEE'
    try: s.eevee.taa_render_samples = 16
    except Exception: pass
    s.render.resolution_x = 768; s.render.resolution_y = 768; s.render.resolution_percentage = 100
    s.render.image_settings.file_format = 'PNG'; s.render.image_settings.color_mode = 'RGBA'
    s.render.film_transparent = False
    s.view_settings.view_transform = 'Standard'; s.view_settings.look = 'None'
    s.render.dither_intensity = 0
    w = bpy.data.worlds.new('w'); s.world = w
    bpy.ops.object.camera_add(location=(0, 0, 20)); cam = bpy.context.object
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 12; s.camera = cam
    return s


# ---------------------------------------------------------------- falaise
def cliff(cols, cname):
    """cols = dict(top,rim,face,foot,low) -> (stops list). Falaise vue de dessus, seamless en x."""
    mats = [mk_mat(cname + '_top', cols['top'], [(1, 0, 0, .5), (0, 1, 1.4, .4), (2, 1, .3, .3)], (1, 1, .8), bump=.25),
            mk_mat(cname + '_rim', cols['rim'], [(2, 0, 0, .5), (3, 1, 1.2, .3)], bump=.3),
            mk_mat(cname + '_face', cols['face'], [(5, 0, 0, .5), (3, 1, 1.9, .35), (8, 0, .7, .2)], (1, 0, 1.0), bump=.9, dist=.2),
            mk_mat(cname + '_foot', cols['foot'], [(2, 0, 0, .5), (1, 1, 1, .4)], bump=.3),
            mk_mat(cname + '_low', cols['low'], [(1, 1, 2, .5), (0, 2, .4, .4)], (2, 1, .5), bump=.25)]
    ys = [9, 1.3, .95, .55, -1.5, -2.0, -3.1, -3.7, -9]
    zs = [0, 0, .14, .12, -1.5, -1.55, -1.55, 0, 0]
    mi = [0, 1, 1, 2, 3, 4]
    nx = 96; xs = [-13 + i * 26 / nx for i in range(nx + 1)]
    verts = []; faces = []
    for j, (y, z) in enumerate(zip(ys, zs)):
        for x in xs:
            jit = .05 * math.sin(T * (x + 1.0) * 2 / P) * (1 if 0 < j < 6 and j != 1 else 0)
            verts.append((x, y + (.12 * math.sin(T * x * 1 / P) if j in (3, 4) else 0), z + jit))
    mids = []
    for j in range(len(ys) - 1):
        for i in range(nx):
            a = j * (nx + 1) + i; faces.append((a, a + nx + 1, a + nx + 2, a + 1)); mids.append(j)
    # materiaux : j=0 top, j=1 rise->rim, j=2 rim flat, j=3 face, j=4 foot, j=5 low
    mat_for = {0: 0, 1: 1, 2: 1, 3: 2, 4: 3, 5: 4, 6: 3, 7: 0}
    me = bpy.data.meshes.new('cliff'); me.from_pydata(verts, [], faces); me.update()
    for m in mats: me.materials.append(m)
    for p, j in zip(me.polygons, mids): p.material_index = mat_for[j]; p.use_smooth = False
    o = bpy.data.objects.new('cliff', me); link(o)


# ---------------------------------------------------------------- tuiles
def t_fog_moss():
    base = mk_mat('moss', [(0, '3E4A3F'), (.5, '485743'), (1, '55634E')],
                  [(1, 0, 0, .5), (0, 1, 1.3, .5), (2, 1, .4, .35), (1, 3, 2.1, .3), (3, 2, .9, .2)], (1, 1, .8), bump=.3)
    plane_big(base)


def t_fog_roots():
    plane_big(mk_mat('soil', [(0, '46433A'), (1, '55513F')], [(2, 1, 0, .5), (1, 2, 1.1, .4), (3, 3, .5, .25)], (1, 2, .7), bump=.25))
    rt = mk_mat('root', [(0, '45392F'), (1, '5A4C3C')], [(8, 1, 0, .5), (6, 0, 1, .3)], bump=.7, dist=.15)
    objs = []
    for y0, amp, cyc, ph, r in [(-2.6, .8, 1, 0, .15), (.2, .9, 1, 2.0, .12), (2.1, .7, 2, 1.0, .14)]:
        pts = [(x, y0 + amp * math.sin(T * cyc * x / P + ph), .0) for x in [-13 + i * .5 for i in range(53)]]
        objs.append(tube(pts, r, rt, z=0.0))
        # petite racine secondaire
        bx = -2 + ph
        side = [(bx + t * 1.6, y0 + amp * math.sin(T * cyc * bx / P + ph) + t * 1.2 * (1 if ph > 1 else -1) * (1 + .3 * t), 0) for t in [i * .1 for i in range(11)]]
        objs.append(tube(side, r * .55, rt))
    dup(objs, (-P, 0, P))


def t_fog_needles():
    plane_big(mk_mat('litter', [(0, '4B4A38'), (1, '5A5740')], [(1, 5, 0, .5), (2, 7, 1, .4), (1, 3, 2, .3)], (3, 1, 1.2), bump=.35))
    lite = mk_mat('needle_l', [(0, '6A6548'), (1, '7A7352')], [(1, 1, 0, .5)], bump=.2)
    dark = mk_mat('needle_d', [(0, '3A382A'), (1, '46432F')], [(1, 1, 0, .5)], bump=.2)
    rng = random.Random(8); objs = []
    for i in range(80):
        x, y = rng.uniform(-4, 4), rng.uniform(-4, 4); a0 = rng.uniform(0, math.pi); m = lite if i % 3 else dark
        for k in range(3):
            objs.append(prim('box', x + rng.uniform(-.1, .1), y + rng.uniform(-.1, .1), .02, rng.uniform(.35, .7), .065, .025,
                              m, a0 + (k - 1) * .35, bevel=.03))
    dup(objs)


def t_fog_mud():
    plane_big(mk_mat('mud', [(0, '43463B'), (.5, '4C4E43'), (1, '555549')],
                     [(1, 1, 0, .5), (2, 0, 1, .4), (0, 2, 2, .4), (2, 3, .6, .3)], (1, 2, 1.0), bump=.35))
    sheen = mk_mat('sheen', [(0, '3E4A4C'), (1, '52625F')], [(1, 1, 0, .5), (2, 1, 1, .3)], bump=.2)
    peb = mk_mat('pebble', [(0, '55554A'), (1, '66665A')], [(2, 3, 0, .5)], bump=.4)
    rng = random.Random(14); objs = []
    for x, y in [(-2.3, 1.4), (1.8, -2.2), (2.6, 2.6)]:
        objs.append(prim('sphere', x, y, -.03, rng.uniform(.9, 1.3), rng.uniform(.5, .8), .05, sheen, rng.uniform(0, 3)))
    for i in range(10):
        r = rng.uniform(.12, .2); objs.append(prim('sphere', rng.uniform(-4, 4), rng.uniform(-4, 4), -.03, r, r * .85, r * .6, peb, rng.uniform(0, 3)))
    dup(objs)


def t_water_deep(c0, c1):
    plane_big(mk_mat('deep', [(0, c0), (1, c1)], [(2, 1, 0, .5), (1, 3, 1.3, .4), (3, 2, .6, .3)], (1, 1, .9), bump=.18))


def t_water_shallow(c0, c1, flow=False):
    terms = [(1, 6, 0, .5), (2, 9, 1.2, .4), (1, 4, 2.0, .3)] if flow else [(3, 2, 0, .5), (2, 5, 1.2, .4), (5, 1, 2.1, .3)]
    plane_big(mk_mat('shallow', [(0, c0), (.55, c0), (1, c1)], terms, (3, 1, 1.4) if not flow else (1, 1, 1.2), mode='plain', bump=.24, dist=.07))


def t_rust_concrete():
    plane_big(mk_mat('concrete', [(0, '444850'), (.5, '4D525A'), (1, '565B62')],
                     [(1, 2, 0, .5), (2, 1, 1.3, .4), (3, 3, .4, .2), (0, 2, 2.2, .3)], (1, 1, .7), bump=.3))
    gr = mk_mat('groove', [(0, '2A2E33'), (1, '34383D')], [(1, 1, 0, .5)], bump=.2)
    objs = []
    for v in (-4, 0, 4):
        objs.append(prim('box', v, 0, .02, .14, 26, .05, gr, bevel=.04))
        objs.append(prim('box', 0, v, .02, 26, .14, .05, gr, bevel=.04))


def t_rust_rust():
    plane_big(mk_mat('seam', [(0, '2C2927'), (1, '34312E')], [(1, 1, 0, .5)], bump=.1))
    objs = []
    rng = random.Random(21)
    tints = [[(0, '4A4540'), (.6, '554C45'), (1, '72523D')], [(0, '47423E'), (.6, '50483F'), (1, '6B4E3D')],
             [(0, '4C4843'), (.6, '57504A'), (1, '745843')], [(0, '454140'), (.6, '4E4A47'), (1, '575350')]]
    cs = [(-2, -2), (2, -2), (-2, 2), (2, 2)]
    riv = mk_mat('rivet', [(0, '5C5750'), (1, '6E6860')], [(1, 1, 0, .5)], bump=.2)
    for k, (cx, cy) in enumerate(cs):
        pm = mk_mat('plate%d' % k, tints[k], [(1, 2, k, .5), (2, 1, 1.3 + k, .4), (3, 0, .6, .25)], (1, 1, .7 + k * .3), bump=.35)
        objs.append(prim('box', cx, cy, .03, 3.85, 3.85, .08, pm, bevel=.05))
        for s in range(5):
            t = -1.5 + s * .75
            for pos in ((t, -1.65), (t, 1.65), (-1.65, t), (1.65, t)):
                objs.append(prim('sphere', cx + pos[0], cy + pos[1], .075, .1, .1, .06, riv))
    dup(objs)


def t_rust_grate():
    plane_big(mk_mat('hole', [(0, '2A3136'), (1, '343B41')], [(1, 1, 0, .5)], bump=.05), z=-.25)
    bar = mk_mat('bar', [(0, '5A6368'), (1, '6C757A')], [(3, 1, 0, .5), (1, 2, 1, .4)], bump=.3)
    cross = mk_mat('cross', [(0, '4E575C'), (1, '5E686D')], [(1, 3, 0, .5)], bump=.3)
    objs = []
    for i in range(-6, 6):
        objs.append(prim('box', 0, i + .5, .0, 26, .22, .2, bar, bevel=.04))
        objs.append(prim('box', i + .5, 0, -.07, .15, 26, .1, cross, bevel=.03))


def t_rust_bridge():
    plane_big(mk_mat('gap', [(0, '1C2125'), (1, '252B30')], [(1, 1, 0, .5)], bump=.05), z=-.15)
    woods = [mk_mat('wood%d' % k, [(0, c0), (1, c1)], [(1, 12, k, .5), (2, 10, 1 + k, .4), (1, 3, 2 + k, .3)], (2, 1, .6), bump=.5, dist=.1)
             for k, (c0, c1) in enumerate([('564E45', '675F51'), ('504A42', '5F584C'), ('5A5248', '6A6254'), ('4C463F', '5C564B')])]
    bolt = mk_mat('bolt', [(0, '3E4246'), (1, '50565A')], [(1, 1, 0, .5)], bump=.2)
    rng = random.Random(33)
    for r in range(8):
        y = -3.5 + r
        o1 = rng.uniform(0, 4)
        for k in range(-4, 4):
            x0 = o1 + 4 * k
            prim('box', x0 + 1.94, y, .0, 3.88, .88, .16, woods[(r + k) % 4], bevel=.04)
            for dx in (.25, 3.63):
                for dy in (-.25, .25): prim('sphere', x0 + dx, y + dy, .09, .1, .1, .06, bolt)


COLORS_FOG = dict(top=[(0, '3E4A3F'), (1, '4C5A48')], rim=[(0, '8A7F62'), (1, '9A8C6A')],
                  face=[(0, '2A2420'), (1, '40362C')], foot=[(0, '2C2B25'), (1, '3A382E')], low=[(0, '36392F'), (1, '44463A')])
COLORS_RUST = dict(top=[(0, '3B3F46'), (1, '4A4F55')], rim=[(0, '767A7C'), (1, '8E9290')],
                   face=[(0, '24272B'), (1, '363A3F')], foot=[(0, '2A2D30'), (1, '383B3F')], low=[(0, '33363B'), (1, '41454A')])
COLORS_TERR = dict(top=[(0, '4A5B50'), (1, '56675A')], rim=[(0, '657772'), (1, '8AA09A')],
                   face=[(0, '263234'), (1, '37474A')], foot=[(0, '3A4748'), (1, '4A5858')], low=[(0, '3E4F4A'), (1, '4A5B52')])


def t_terr_grass():
    # herbe : olive jaune-vert desature, brins verticaux (streaks) distincts de la mousse bleutee
    plane_big(mk_mat('grass', [(0, '525A3F'), (.5, '626A47'), (1, '737B50')],
                     [(9, 1, 0, .5), (13, 2, 1.0, .35), (2, 3, 2.0, .3), (6, 1, .5, .3)], (1, 3, 1.1), bump=.45))
    tuft = mk_mat('tuft', [(0, '6B7451'), (1, '7E8760')], [(10, 1, 0, .5)], bump=.5, dist=.12)
    rng = random.Random(61); objs = []
    for i in range(42):
        x, y = rng.uniform(-4, 4), rng.uniform(-4, 4)
        for k in range(3):
            objs.append(prim('sphere', x + rng.uniform(-.15, .15), y + rng.uniform(-.2, .2), -.03, .09, rng.uniform(.28, .45), .07, tuft, rng.uniform(-.25, .25) + math.pi / 2 * 0))
    dup(objs)



def t_terr_stone():
    plane_big(mk_mat('wet_mortar', [(0,'3C494A'),(1,'4A5858')], [(1,2,0,1)], bump=.25))
    stone = mk_mat('slate', [(0,'4A575B'),(.5,'566366'),(1,'65716F')], [(2,1,1,1)], bump=.55, dist=.12)
    rng=random.Random(79); objs=[]
    for row in range(4):
        for col in range(4):
            x=-3+col*2+(row%2)*.8; y=-3+row*2
            objs.append(prim('box',x,y,.01,rng.uniform(1.65,1.87),rng.uniform(1.7,1.88),.08,stone,rng.uniform(-.035,.035),bevel=.12))
    dup(objs)

def t_terr_mud():
    plane_big(mk_mat('terrace_silt', [(0,'404D49'),(.5,'4C5952'),(1,'59645A')], [(1,3,0,1),(2,1,1,.4)], bump=.4))

SPECS = {
    'fog_forest': {
        'ground_moss': t_fog_moss, 'ground_roots': t_fog_roots, 'ground_needles': t_fog_needles, 'ground_mud': t_fog_mud,
        'water_deep': lambda: t_water_deep('17262B', '223439'), 'water_shallow': lambda: t_water_shallow('3C5257', '5E7A80'),
        'cliff_edge': lambda: cliff(COLORS_FOG, 'fogcliff')},
    'rust_city': {
        'ground_concrete': t_rust_concrete, 'ground_rust': t_rust_rust, 'ground_grate': t_rust_grate, 'ground_bridge': t_rust_bridge,
        'water_deep': lambda: t_water_deep('141B22', '1E2A32'), 'water_shallow': lambda: t_water_shallow('3A4953', '566670', True),
        'cliff_edge': lambda: cliff(COLORS_RUST, 'rustcliff')},
    'terraces': {'ground_moss': t_fog_moss, 'ground_stone': t_terr_stone, 'ground_mud': t_terr_mud, 'water_deep': lambda: t_water_deep('1F3139','293D43'), 'water_shallow': lambda: t_water_shallow('485F65','607B80'), 'ground_grass': t_terr_grass, 'cliff_edge': lambda: cliff(COLORS_TERR, 'terrcliff')},
}


def run():
    a = argparse.ArgumentParser(); a.add_argument('--biome', required=True); a.add_argument('--only', nargs='*')
    args = a.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    raw = ROOT / 'art/renders/terrain' / args.biome; raw.mkdir(parents=True, exist_ok=True)
    bl = ROOT / 'art/blender/terrain'; bl.mkdir(parents=True, exist_ok=True)
    for name, fn in SPECS[args.biome].items():
        if args.only and name not in args.only: continue
        s = setup_scene(name); fn()
        for mode, suf, vt in (('beauty', '', 'Standard'), ('normal', '_n', 'Raw')):
            set_mode(mode); s.view_settings.view_transform = vt
            s.render.filepath = str(raw / (name + suf + '.png')); bpy.ops.render.render(write_still=True)
        set_mode('beauty'); s.view_settings.view_transform = 'Standard'
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=str(bl / ('tile_%s_%s.blend' % (args.biome, name))))
        print('DONE', args.biome, name, flush=True)


run()
