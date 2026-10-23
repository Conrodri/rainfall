"""Bibliotheque VFX Blender (Eevee, arriere-plan). Sprites orientes camera a shaders procedurels
(bruit, degrades), rubans, secteurs au sol. Les particules sont simulees de facon deterministe
(graine) et bouclable. Rien n'est dessine hors de Blender ; PIL ne sert qu'a l'assemblage."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT = Path(__file__).resolve().parents[3]
TILT = math.radians(35); CT, ST = math.cos(TILT), math.sin(TILT)
PPU = 64.0
G = {'mats': {}, 'objs': [], 'plane': None, 'cs': [], 'tz': 0.0, 'n': 0}

def lin(c):
    return tuple((x ** 2.2) for x in c[:3])
def hexc(h):
    h = h.lstrip('#'); return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
FIRE = hexc('FF7A1F'); GOLD = hexc('FFB347'); DEEP = hexc('C23B12'); CORE = hexc('FFE9A8')
POIS = hexc('7FD65A'); POIS2 = hexc('3E8F3A'); FROST = hexc('8FD8F0'); FROST2 = hexc('5E7390')
BOLT = hexc('CFE8FF'); BOLT2 = hexc('7AB8FF'); TELE = hexc('D83A2A'); XPC = hexc('5FD4E8'); GOLDC = hexc('F2C14E')
SMOKE = hexc('2B3340'); WHITE = (1, 1, 1)

# ---------- materiaux ----------
def _build_mat(kind):
    m = bpy.data.materials.new('vfx_' + kind); m.use_nodes = True
    try: m.surface_render_method = 'BLENDED'
    except Exception: pass
    try: m.use_backface_culling = False
    except Exception: pass
    ns = m.node_tree.nodes; ls = m.node_tree.links; ns.clear()
    def link(v, inp):
        if v is None: return
        if hasattr(v, 'node'): ls.new(v, inp)
        else: inp.default_value = v
    def M(op, a, b=None, c=None, clamp=False):
        n = ns.new('ShaderNodeMath'); n.operation = op; n.use_clamp = clamp
        for i, v in enumerate((a, b, c)): link(v, n.inputs[i])
        return n.outputs[0]
    def SS(x, a, b):
        n = ns.new('ShaderNodeMapRange'); n.interpolation_type = 'SMOOTHSTEP'; n.clamp = True
        link(x, n.inputs[0]); link(a, n.inputs[1]); link(b, n.inputs[2]); n.inputs[3].default_value = 0; n.inputs[4].default_value = 1
        return n.outputs[0]
    def MIX(f, a, b):
        n = ns.new('ShaderNodeMix'); n.data_type = 'RGBA'; n.clamp_factor = True
        link(f, n.inputs[0]); link(a, n.inputs[6]); link(b, n.inputs[7]); return n.outputs[2]
    def COMB(x, y, z=0.0):
        n = ns.new('ShaderNodeCombineXYZ'); link(x, n.inputs[0]); link(y, n.inputs[1]); link(z, n.inputs[2]); return n.outputs[0]
    def SEP(v):
        n = ns.new('ShaderNodeSeparateXYZ'); link(v, n.inputs[0]); return n.outputs
    def NOISE(vec, scale, detail=4, rough=.6, dist=0.0):
        n = ns.new('ShaderNodeTexNoise'); n.noise_dimensions = '3D'; link(vec, n.inputs['Vector'])
        n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = detail; n.inputs['Roughness'].default_value = rough
        n.inputs['Distortion'].default_value = dist; return n.outputs['Fac']
    BLK = (0, 0, 0, 1); WH = (1, 1, 1, 1); hot = (1.0, .84, .45, 1)
    uv = ns.new('ShaderNodeTexCoord').outputs['UV']
    oi = ns.new('ShaderNodeObjectInfo'); tint = oi.outputs['Color']; oalpha = oi.outputs['Alpha']; rnd = oi.outputs['Random']
    cs = ns.new('ShaderNodeValue'); cs.name = 'CS'; sn = ns.new('ShaderNodeValue'); sn.name = 'SN'
    sp = SEP(uv); ux, uy = sp[0], sp[1]
    px = M('SUBTRACT', ux, .5); py = M('SUBTRACT', uy, .5)
    seed = M('MULTIPLY', rnd, 40.0)
    off = COMB(M('ADD', M('MULTIPLY', cs.outputs[0], 1.7), seed), M('ADD', M('MULTIPLY', sn.outputs[0], 1.7), M('MULTIPLY', seed, .7)), seed)
    uvo = ns.new('ShaderNodeVectorMath'); uvo.operation = 'ADD'; ls.new(uv, uvo.inputs[0]); ls.new(off, uvo.inputs[1])
    emissive = True
    rr = M('MULTIPLY', M('POWER', M('ADD', M('MULTIPLY', px, px), M('MULTIPLY', py, py)), .5), 2.0)
    strength = 1.4
    if kind == 'glow':
        d = M('POWER', M('SUBTRACT', 1.0, rr, clamp=True), 1.7); alpha = SS(d, 0.0, .5)
        col = MIX(SS(d, .25, 1.0), tint, hot)
    elif kind == 'flame':
        n1 = NOISE(uvo.outputs[0], 3.2, 5, .62, .25); n2 = NOISE(uvo.outputs[0], 7.0, 3, .5)
        y = uy
        wob = M('MULTIPLY', M('SUBTRACT', n1, .5), M('MULTIPLY', M('POWER', y, 1.0), 3.4))
        x = M('ADD', M('MULTIPLY', px, 2.0), wob)
        w = M('MULTIPLY', M('MULTIPLY', M('POWER', M('SUBTRACT', 1.0, y, clamp=True), .55), .95), M('ADD', .5, M('MULTIPLY', n2, 1.0)))
        body = M('SUBTRACT', 1.0, M('DIVIDE', M('ABSOLUTE', x), M('ADD', w, .001)), clamp=True)
        body = M('MULTIPLY', body, SS(uy, 0.0, .14))
        body = M('SUBTRACT', body, M('MULTIPLY', M('MULTIPLY', n2, M('POWER', y, 1.3)), .55), clamp=True)
        d = M('POWER', body, .85); alpha = SS(d, 0.0, .3)
        heat = M('MULTIPLY', d, M('ADD', M('SUBTRACT', 1.0, M('MULTIPLY', y, .55)), M('MULTIPLY', n1, .3)))
        c0 = MIX(.5, BLK, tint)
        col = MIX(SS(heat, .15, .55), c0, tint); col = MIX(SS(heat, .5, .95), col, hot); strength = 1.5
    elif kind == 'smoke':
        emissive = False
        n1 = NOISE(uvo.outputs[0], 3.0, 5, .6, .3)
        d = M('SUBTRACT', M('MULTIPLY', M('SUBTRACT', 1.0, rr, clamp=True), 1.5), M('MULTIPLY', n1, .75), clamp=True)
        alpha = SS(d, 0.0, .6); col = MIX(SS(n1, .3, .7), MIX(.55, BLK, tint), tint); strength = 1.0
    elif kind in ('ring', 'ring_thin', 'ring_thick'):
        half = {'ring': .12, 'ring_thin': .045, 'ring_thick': .26}[kind]; c = {'ring': .86, 'ring_thin': .92, 'ring_thick': .74}[kind]
        band = M('SUBTRACT', 1.0, M('DIVIDE', M('ABSOLUTE', M('SUBTRACT', rr, c)), half), clamp=True)
        ax = M('DIVIDE', px, M('ADD', rr, .0001)); ay = M('DIVIDE', py, M('ADD', rr, .0001))
        nn = NOISE(COMB(M('ADD', M('MULTIPLY', ax, .8), M('MULTIPLY', cs.outputs[0], .6)), M('ADD', M('MULTIPLY', ay, .8), M('MULTIPLY', sn.outputs[0], .6)), seed), 2.6, 4, .6)
        mod = M('ADD', .35, M('MULTIPLY', nn, 1.3))
        d = M('POWER', M('MULTIPLY', band, mod, clamp=True), 1.1); alpha = SS(d, 0.0, .4)
        col = MIX(SS(d, .6, 1.5), tint, hot); strength = 1.5
    elif kind == 'spark':
        ex = M('MULTIPLY', px, 2.0); ey = M('MULTIPLY', py, 2.0)
        w = M('ADD', M('MULTIPLY', SS(ex, -1.0, .75), .9), .02)
        body = M('SUBTRACT', 1.0, M('DIVIDE', M('ABSOLUTE', ey), w), clamp=True)
        body = M('MULTIPLY', body, M('MULTIPLY', SS(ex, -1.0, -.6), M('SUBTRACT', 1.0, SS(ex, .8, 1.0))))
        hx = M('SUBTRACT', ex, .55)
        hd = M('SUBTRACT', 1.0, M('POWER', M('ADD', M('MULTIPLY', hx, hx), M('MULTIPLY', ey, ey)), .5), clamp=True)
        d = M('MAXIMUM', body, M('POWER', M('MULTIPLY', hd, 1.6, clamp=True), 1.4)); alpha = SS(d, 0.0, .35)
        col = MIX(SS(d, .4, 1.0), tint, hot); strength = 1.6
    elif kind in ('disc', 'disc_edge'):
        edge = SS(M('SUBTRACT', 1.0, rr), 0.0, .06)
        if kind == 'disc': alpha = edge
        else: alpha = M('MULTIPLY', edge, M('ADD', .45, M('MULTIPLY', SS(rr, .35, 1.0), .55)))
        col = tint; strength = 1.0
    elif kind == 'solid':
        v = M('SUBTRACT', 1.0, M('ABSOLUTE', M('MULTIPLY', py, 2.0)), clamp=True)
        d = M('POWER', v, 1.3); alpha = SS(d, 0.0, .5); col = MIX(SS(d, .45, 1.0), tint, hot); strength = 1.8
    elif kind == 'halo':
        d = M('POWER', M('SUBTRACT', 1.0, rr, clamp=True), 1.5); alpha = SS(d, 0.0, .6); col = tint; strength = 1.2
    elif kind == 'outline':
        band = M('SUBTRACT', 1.0, M('DIVIDE', M('ABSOLUTE', M('SUBTRACT', rr, .965)), .035), clamp=True)
        alpha = SS(band, 0.0, .5); col = tint; strength = 1.3
    elif kind == 'flat':
        alpha = 1.0; col = tint; strength = 1.0
    elif kind == 'shard':
        ex = M('ABSOLUTE', M('MULTIPLY', px, 2.0)); ey = M('MULTIPLY', py, 2.0)
        t = M('ADD', M('MULTIPLY', ex, 2.4), M('ABSOLUTE', ey))
        body = M('SUBTRACT', 1.0, t, clamp=True)
        facet = M('ADD', .55, M('MULTIPLY', M('SUBTRACT', ey, M('MULTIPLY', px, 1.3)), .9))
        alpha = SS(body, 0.0, .05)
        col = MIX(SS(facet, .3, 1.0), MIX(.45, BLK, tint), MIX(.6, tint, WH)); strength = 1.25
    elif kind == 'bubble':
        band = M('SUBTRACT', 1.0, M('DIVIDE', M('ABSOLUTE', M('SUBTRACT', rr, .82)), .16), clamp=True)
        fill = M('MULTIPLY', M('SUBTRACT', 1.0, rr, clamp=True), .35)
        hx = M('SUBTRACT', px, -.17); hy = M('SUBTRACT', py, .17)
        hl = M('SUBTRACT', 1.0, M('MULTIPLY', M('POWER', M('ADD', M('MULTIPLY', hx, hx), M('MULTIPLY', hy, hy)), .5), 9.0), clamp=True)
        d = M('MAXIMUM', M('MAXIMUM', M('MULTIPLY', band, .95), fill), M('MULTIPLY', hl, 1.1)); alpha = SS(d, 0.0, .3)
        col = MIX(SS(M('MAXIMUM', hl, M('MULTIPLY', band, .9)), .3, .95), MIX(.55, BLK, tint), WH); strength = 1.2
    elif kind == 'star':
        ex = M('ABSOLUTE', M('MULTIPLY', px, 2.0)); ey = M('ABSOLUTE', M('MULTIPLY', py, 2.0))
        a = M('SUBTRACT', 1.0, M('ADD', ex, M('MULTIPLY', ey, 9.0)), clamp=True)
        b = M('SUBTRACT', 1.0, M('ADD', M('MULTIPLY', ex, 9.0), ey), clamp=True)
        c = M('SUBTRACT', 1.0, rr, clamp=True)
        d = M('MAXIMUM', M('MAXIMUM', M('POWER', a, 1.5), M('POWER', b, 1.5)), M('POWER', c, 2.2)); alpha = SS(d, 0.0, .3)
        col = MIX(SS(d, .3, 1.0), tint, WH); strength = 1.6
    elif kind == 'drop':
        ey = M('MULTIPLY', py, 2.0); ex = M('MULTIPLY', px, 2.0)
        w = M('MULTIPLY', M('POWER', M('SUBTRACT', 1.0, M('MULTIPLY', M('ADD', ey, 1.0), .5), clamp=True), .6), .9)
        body = M('SUBTRACT', 1.0, M('DIVIDE', M('ABSOLUTE', ex), M('ADD', w, .001)), clamp=True)
        body = M('MULTIPLY', body, SS(ey, -1.0, -.7)); d = M('POWER', body, .7); alpha = SS(d, 0.0, .3)
        col = MIX(SS(d, .3, 1.0), tint, hot); strength = 1.5
    else:
        raise ValueError(kind)
    em = ns.new('ShaderNodeEmission'); em.inputs[1].default_value = strength; link(col, em.inputs[0])
    tr = ns.new('ShaderNodeBsdfTransparent'); mix = ns.new('ShaderNodeMixShader')
    fac = M('MULTIPLY', alpha, oalpha, clamp=True)
    ls.new(fac, mix.inputs[0]); ls.new(tr.outputs[0], mix.inputs[1]); ls.new(em.outputs[0], mix.inputs[2])
    out = ns.new('ShaderNodeOutputMaterial'); ls.new(mix.outputs[0], out.inputs[0])
    m['emissive'] = emissive
    G['cs'].append((cs, sn))
    return m

def mat(kind):
    if kind not in G['mats']: G['mats'][kind] = _build_mat(kind)
    return G['mats'][kind]

def _plane(kind):
    key = 'plane_' + kind
    if key not in bpy.data.meshes:
        me = bpy.data.meshes.new(key)
        me.from_pydata([(-.5, -.5, 0), (.5, -.5, 0), (.5, .5, 0), (-.5, .5, 0)], [], [(0, 1, 2, 3)]); me.update()
        uv = me.uv_layers.new(name='UV')
        for i, c in enumerate([(0, 0), (1, 0), (1, 1), (0, 1)]): uv.data[i].uv = c
        me.materials.append(mat(kind))
    return bpy.data.meshes[key]

def _add(o, kind, color, alpha):
    bpy.context.collection.objects.link(o)
    o.color = (*lin(color), max(0.0, min(1.0, alpha)))
    o['k'] = kind; G['objs'].append(o); return o

def S(x, y, d=0.0):
    """coordonnees ecran (x droite, y haut, d profondeur) -> monde."""
    return Vector((x, y * CT + d * ST, y * ST - d * CT))

def sprite(kind, x, y, w, h=None, color=FIRE, alpha=1.0, rot=0.0, d=0.0):
    """plan oriente camera. w,h en unites (1 u = 64 px), rot autour de l'axe de vue (rad)."""
    if alpha <= 0.003: return None
    h = w if h is None else h
    G['n'] += 1
    o = bpy.data.objects.new('s%d' % G['n'], _plane(kind))
    o.rotation_mode = 'ZYX'; o.rotation_euler = (TILT, 0, rot)
    o.location = S(x, y, d); o.scale = (w, h, 1)
    return _add(o, kind, color, alpha)

def ground(kind, x, y, w, h=None, color=FIRE, alpha=1.0, rot=0.0, z=0.0):
    if alpha <= 0.003: return None
    h = w if h is None else h
    G['n'] += 1
    o = bpy.data.objects.new('g%d' % G['n'], _plane(kind))
    o.rotation_euler = (0, 0, rot); o.location = (x, y, z); o.scale = (w, h, 1)
    return _add(o, kind, color, alpha)

def ribbon(kind, pts, width, color=BOLT, alpha=1.0, wfun=None):
    """ruban en coordonnees ecran (x,y[,d])."""
    if alpha <= 0.003 or len(pts) < 2: return None
    n = len(pts); verts = []; faces = []
    for i in range(n):
        a = pts[max(i - 1, 0)]; b = pts[min(i + 1, n - 1)]
        tx = b[0] - a[0]; ty = b[1] - a[1]; L = math.hypot(tx, ty) or 1
        nx, ny = -ty / L, tx / L
        wv = width * (wfun(i / (n - 1)) if wfun else 1.0) * .5
        p = pts[i]; d = p[2] if len(p) > 2 else 0
        verts += [tuple(S(p[0] + nx * wv, p[1] + ny * wv, d)), tuple(S(p[0] - nx * wv, p[1] - ny * wv, d))]
    for i in range(n - 1): faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    me = bpy.data.meshes.new('rib'); me.from_pydata(verts, [], faces); me.update()
    uv = me.uv_layers.new(name='UV')
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index; uv.data[li].uv = ((vi // 2) / (n - 1), 0.0 if vi % 2 else 1.0)
    me.materials.append(mat(kind))
    G['n'] += 1
    return _add(bpy.data.objects.new('r%d' % G['n'], me), kind, color, alpha)

def fan(kind, ang, radius, color, alpha, rot=0.0, x=0.0, y=0.0, scale=1.0, seg=28, z=0.0):
    """secteur au sol (apex = origine objet), ouvert de -ang/2 a +ang/2 autour de +X."""
    if alpha <= 0.003 or scale <= 0.001: return None
    verts = [(0, 0, 0)]; faces = []
    for i in range(seg + 1):
        a = -ang / 2 + ang * i / seg; verts.append((math.cos(a) * radius, math.sin(a) * radius, 0))
    for i in range(seg): faces.append((0, i + 1, i + 2))
    me = bpy.data.meshes.new('fan'); me.from_pydata(verts, [], faces); me.update()
    uv = me.uv_layers.new(name='UV')
    for poly in me.polygons:
        for li in poly.loop_indices: uv.data[li].uv = (.5, .5)
    me.materials.append(mat(kind))
    G['n'] += 1
    o = bpy.data.objects.new('f%d' % G['n'], me); o.rotation_euler = (0, 0, rot); o.location = (x, y, z); o.scale = (scale, scale, 1)
    return _add(o, kind, color, alpha)

def clear():
    for o in G['objs']: bpy.data.objects.remove(o, do_unlink=True)
    G['objs'] = []
    for me in list(bpy.data.meshes):
        if me.users == 0: bpy.data.meshes.remove(me)

# ---------- scene / rendu ----------
def setup(wpx, hpx, tz=0.0, ty=0.0, ppu=PPU, samples=24):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    G.update({'mats': {}, 'objs': [], 'cs': [], 'tz': tz, 'n': 0})
    s = bpy.context.scene; s.render.engine = 'BLENDER_EEVEE'
    try: s.eevee.taa_render_samples = samples
    except Exception: pass
    s.render.resolution_x = wpx * 2; s.render.resolution_y = hpx * 2; s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.image_settings.file_format = 'PNG'; s.render.image_settings.color_mode = 'RGBA'; s.render.image_settings.color_depth = '8'
    s.view_settings.view_transform = 'Standard'; s.view_settings.look = 'None'
    s.render.filter_size = 1.2
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); bpy.context.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = max(wpx, hpx) / ppu
    cam.location = Vector((0, ty, tz)) + Vector((0, -10 * math.sin(TILT), 10 * math.cos(TILT))); cam.rotation_euler = (TILT, 0, 0)
    cam.data.clip_start = .1; cam.data.clip_end = 100
    s.camera = cam
    return s

def set_phase(phi):
    for cs, sn in G['cs']:
        cs.outputs[0].default_value = math.cos(phi); sn.outputs[0].default_value = math.sin(phi)

def render(name, anim, idx, phi=0.0):
    s = bpy.context.scene; set_phase(phi)
    base = ROOT / 'art/renders/vfx' / name
    for suffix, emis in (('', False), ('_e', True)):
        hid = []
        if emis:
            for o in G['objs']:
                if o['k'] == 'smoke' or o.get('noem'):
                    o.hide_render = True; hid.append(o)
        dest = base / (anim + suffix); dest.mkdir(parents=True, exist_ok=True)
        s.render.filepath = str(dest / ('x_%02d.png' % idx)); bpy.ops.render.render(write_still=True)
        for o in hid: o.hide_render = False

def lp(f, n, u): return (f / n + u) % 1.0
def fade(life, a=.15, b=.35):
    return max(0.0, min(1.0, life / a, (1 - life) / b))
def ss(x, a, b):
    t = max(0.0, min(1.0, (x - a) / (b - a))); return t * t * (3 - 2 * t)
