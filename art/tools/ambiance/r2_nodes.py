"""Bibliotheque commune des textures d'ambiance Rainfall (Blender 5.2 --background, Eevee).
Chaque texture = un graphe de shader nodes proceduraux (emission + transparence) rendu par une camera
orthographique sur un plan, film transparent, PNG RGBA. Aucune image dessinee en Python."""
import bpy, math, sys, json, traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/sprites/ambiance'
RAW = ROOT / 'art/renders/ambiance'
BLEND = ROOT / 'art/blender/ambiance'
for _p in (OUT, RAW, BLEND): _p.mkdir(parents=True, exist_ok=True)
TAU = 2 * math.pi
LOG = []

class C:
    tree = None; sc = None; plane = None; cam = None

# ---------------------------------------------------------------- DSL de noeuds
class V:
    def __init__(s, sock): s.s = sock
    def __add__(a, b): return m('ADD', a, b)
    def __radd__(a, b): return m('ADD', b, a)
    def __sub__(a, b): return m('SUBTRACT', a, b)
    def __rsub__(a, b): return m('SUBTRACT', b, a)
    def __mul__(a, b): return m('MULTIPLY', a, b)
    def __rmul__(a, b): return m('MULTIPLY', b, a)
    def __truediv__(a, b): return m('DIVIDE', a, b)
    def __rtruediv__(a, b): return m('DIVIDE', b, a)
    def __pow__(a, b): return m('POWER', a, b)
    def __rpow__(a, b): return m('POWER', b, a)
    def __neg__(a): return m('MULTIPLY', a, -1.0)

def _set(sock, x):
    if isinstance(x, V): C.tree.links.new(x.s, sock)
    else: sock.default_value = float(x)

def m(op, a, b=None, c=None, clamp=False):
    n = C.tree.nodes.new('ShaderNodeMath'); n.operation = op; n.use_clamp = clamp
    for i, x in enumerate((a, b, c)):
        if x is not None: _set(n.inputs[i], x)
    return V(n.outputs[0])

def sin(a): return m('SINE', a)
def cos(a): return m('COSINE', a)
def absv(a): return m('ABSOLUTE', a)
def sqrt(a): return m('SQRT', a)
def mx(a, b): return m('MAXIMUM', a, b)
def mn(a, b): return m('MINIMUM', a, b)
def clamp01(a): return m('ADD', a, 0.0, clamp=True)
def fract(a): return m('FRACT', a)
def floor(a): return m('FLOOR', a)
def expn(a): return m('EXPONENT', a)
def atan2(y, x): return m('ARCTAN2', y, x)
def lerp(a, b, t): return a + (b - a) * t
def gt(a, b): return m('GREATER_THAN', a, b)
def hyp(x, y): return sqrt(x * x + y * y)
def gauss(a, s): return expn(-(a * a) / (s * s))

def smooth(a, b, x):
    n = C.tree.nodes.new('ShaderNodeMapRange'); n.data_type = 'FLOAT'
    n.interpolation_type = 'SMOOTHSTEP'; n.clamp = True
    _set(n.inputs[0], x); _set(n.inputs[1], a); _set(n.inputs[2], b)
    n.inputs[3].default_value = 0.0; n.inputs[4].default_value = 1.0
    return V(n.outputs[0])

def vec(x, y, z=0.0):
    n = C.tree.nodes.new('ShaderNodeCombineXYZ')
    for i, q in enumerate((x, y, z)): _set(n.inputs[i], q)
    return V(n.outputs[0])

def sep(v):
    n = C.tree.nodes.new('ShaderNodeSeparateXYZ'); C.tree.links.new(v.s, n.inputs[0])
    return V(n.outputs[0]), V(n.outputs[1]), V(n.outputs[2])

def noise(x, y, z=0.0, w=None, scale=1.0, detail=2.0, rough=0.5, dist=0.0, lac=2.0):
    n = C.tree.nodes.new('ShaderNodeTexNoise')
    n.noise_dimensions = '4D' if w is not None else '3D'
    n.normalize = True
    _set(n.inputs['Vector'], vec(x, y, z))
    if w is not None: _set(n.inputs['W'], w)
    _set(n.inputs['Scale'], scale); _set(n.inputs['Detail'], detail)
    _set(n.inputs['Roughness'], rough); _set(n.inputs['Distortion'], dist)
    _set(n.inputs['Lacunarity'], lac)
    return V(n.outputs['Fac'])

def voro(x, y, z=0.0, w=None, scale=1.0, feature='F1', rand=1.0, smoothness=1.0, out='Distance'):
    n = C.tree.nodes.new('ShaderNodeTexVoronoi')
    n.voronoi_dimensions = '4D' if w is not None else '3D'
    n.feature = feature
    _set(n.inputs['Vector'], vec(x, y, z))
    if w is not None: _set(n.inputs['W'], w)
    _set(n.inputs['Scale'], scale); _set(n.inputs['Randomness'], rand)
    if feature == 'SMOOTH_F1': _set(n.inputs['Smoothness'], smoothness)
    return V(n.outputs[out])

def wn(x, y, z=0.0):
    n = C.tree.nodes.new('ShaderNodeTexWhiteNoise'); n.noise_dimensions = '3D'
    _set(n.inputs['Vector'], vec(x, y, z))
    return V(n.outputs['Value'])

def tn(u, v, ra, rb=None, seed=0.0, **kw):
    """bruit 4D periodique en (u,v) (tore) : raccord parfait. ra/rb = frequence en u/v."""
    rb = ra if rb is None else rb
    a = u * TAU; b = v * TAU
    return noise(cos(a) * ra + seed, sin(a) * ra, cos(b) * rb, w=sin(b) * rb + seed * 0.37, **kw)

def tv(u, v, ra, rb=None, seed=0.0, feature='F1', out='Distance', rand=1.0, smoothness=1.0):
    rb = ra if rb is None else rb
    a = u * TAU; b = v * TAU
    return voro(cos(a) * ra + seed, sin(a) * ra, cos(b) * rb, w=sin(b) * rb + seed * 0.37,
                feature=feature, out=out, rand=rand, smoothness=smoothness)

def seg(px, py, ax, ay, bx, by):
    """distance d'un point (px,py) au segment a-b (constantes python pour a,b)."""
    bax, bay = bx - ax, by - ay
    L2 = bax * bax + bay * bay
    h = clamp01(((px - ax) * bax + (py - ay) * bay) / L2)
    return hyp(px - ax - h * bax, py - ay - h * bay)

def srgb(c):
    f = lambda x: x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return tuple(f(x) for x in c)

# ---------------------------------------------------------------- environnement de rendu
class Env:
    def __init__(s, w, h):
        s.w, s.h = w, h; s.asp = w / h
        n = C.tree.nodes.new('ShaderNodeTexCoord')
        s.u, s.v, _ = sep(V(n.outputs['UV']))
        s.x = (s.u * 2.0 - 1.0) * s.asp   # centre, Y in [-1,1]
        s.y = s.v * 2.0 - 1.0
    def atlas(s, n):
        """atlas n images carrees cote a cote : retourne (fi, t, lx, ly)."""
        U = s.u * n; fi = floor(U)
        return fi, fi / (n - 1.0), fract(U) * 2.0 - 1.0, s.y

def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene; C.sc = sc
    try: sc.render.engine = 'BLENDER_EEVEE'
    except Exception: sc.render.engine = 'BLENDER_EEVEE_NEXT'
    try: sc.eevee.taa_render_samples = 16
    except Exception: pass
    r = sc.render
    r.film_transparent = True; r.use_compositing = False; r.use_sequencer = False
    r.resolution_percentage = 100; r.filter_size = 1.0
    r.image_settings.file_format = 'PNG'; r.image_settings.color_mode = 'RGBA'
    r.image_settings.color_depth = '8'; r.image_settings.compression = 20
    sc.view_settings.look = 'None'
    bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 0, 0)); C.plane = bpy.context.object
    bpy.ops.object.camera_add(location=(0, 0, 2)); C.cam = bpy.context.object
    C.cam.data.type = 'ORTHO'; sc.camera = C.cam
    return sc

def render(path, w, h, build, raw=False):
    """build(Env) -> (rgb, alpha). rgb: None (blanc) | float | (r,g,b) de V/float (lineaire)."""
    path = Path(path); path.parent.mkdir(parents=True, exist_ok=True)
    mat = bpy.data.materials.new(path.stem); mat.use_nodes = True
    try: mat.surface_render_method = 'BLENDED'
    except Exception: pass
    t = mat.node_tree; t.nodes.clear(); C.tree = t
    e = Env(w, h)
    rgb, alpha = build(e)
    alpha = clamp01(alpha) if isinstance(alpha, V) else alpha
    em = t.nodes.new('ShaderNodeEmission'); tr = t.nodes.new('ShaderNodeBsdfTransparent')
    mix = t.nodes.new('ShaderNodeMixShader'); out = t.nodes.new('ShaderNodeOutputMaterial')
    cc = t.nodes.new('ShaderNodeCombineColor')
    if rgb is None: rgb = (1.0, 1.0, 1.0)
    if not isinstance(rgb, tuple): rgb = (rgb, rgb, rgb)
    for i in range(3): _set(cc.inputs[i], clamp01(rgb[i]) if isinstance(rgb[i], V) else rgb[i])
    t.links.new(cc.outputs[0], em.inputs['Color']); em.inputs['Strength'].default_value = 1.0
    _set(mix.inputs[0], alpha)
    t.links.new(tr.outputs[0], mix.inputs[1]); t.links.new(em.outputs[0], mix.inputs[2])
    t.links.new(mix.outputs[0], out.inputs[0])
    sc = C.sc
    sc.view_settings.view_transform = 'Raw' if raw else 'Standard'
    sc.render.resolution_x = w; sc.render.resolution_y = h
    mxd = max(w, h)
    C.plane.scale = (w / mxd, h / mxd, 1); C.cam.data.ortho_scale = 1.0
    C.plane.data.materials.clear(); C.plane.data.materials.append(mat)
    sc.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    mat.use_fake_user = True  # R2: conserver tous les graphes dans la source .blend
    return stats(path)

def stats(path):
    import numpy as np
    img = bpy.data.images.load(str(path), check_existing=False)
    w, h = img.size; a = np.empty(w * h * 4, dtype=np.float32); img.pixels.foreach_get(a)
    a = a.reshape(h, w, 4)
    al = a[..., 3]
    try: fname = str(path.relative_to(ROOT)).replace('\\', '/')
    except ValueError: fname = str(path)
    d = dict(file=fname, w=w, h=h, alpha_max=round(float(al.max()), 3),
             alpha_mean=round(float(al.mean()), 3), cover30=round(float((al > 0.3).mean()), 3),
             rgb_mean=[round(float(a[..., i].mean()), 3) for i in range(3)])
    bpy.data.images.remove(img)
    LOG.append(d)
    return d

def run(name, path, w, h, build, raw=False):
    try:
        d = render(path, w, h, build, raw)
        print('OK', d['file'], d['w'], d['h'], 'amax', d['alpha_max'], 'amean', d['alpha_mean'], 'cov', d['cover30'], flush=True)
        return d
    except Exception:
        print('ERR', name, traceback.format_exc(), flush=True)
        LOG.append(dict(file=name, error=True))

def tile2x2(src, dst, size=512):
    """verification : assemblage 2x2 d'un PNG (reduit a `size`) pour juger les raccords."""
    import numpy as np
    img = bpy.data.images.load(str(src)); img.scale(size, size)
    a = np.empty(size * size * 4, dtype=np.float32); img.pixels.foreach_get(a)
    a = a.reshape(size, size, 4)
    big = np.tile(a, (2, 2, 1))
    comp = big.copy(); al = big[..., 3:4]
    comp[..., :3] = big[..., :3] * al + 0.5 * (1 - al); comp[..., 3] = 1
    o = bpy.data.images.new('t2', size * 2, size * 2, alpha=True)
    o.pixels.foreach_set(comp.reshape(-1)); o.filepath_raw = str(dst); o.file_format = 'PNG'; o.save()
    bpy.data.images.remove(o); bpy.data.images.remove(img)

def montage(files, dst, cell=256, cols=6, bg=(0.35, 0.35, 0.37)):
    """verification : planche de contact (alpha composite sur fond gris)."""
    import numpy as np
    rows = (len(files) + cols - 1) // cols
    sheet = np.zeros((rows * cell, cols * cell, 4), np.float32); sheet[...] = (*bg, 1)
    for i, f in enumerate(files):
        img = bpy.data.images.load(str(f)); w, h = img.size
        k = min(cell / w, cell / h)
        if k >= 1: k = max(1, int(k)); nw, nh = w * k, h * k
        else: nw, nh = max(1, int(round(w * k))), max(1, int(round(h * k)))
        img.scale(int(nw), int(nh)); nw, nh = int(nw), int(nh)
        a = np.empty(nw * nh * 4, np.float32); img.pixels.foreach_get(a); a = a.reshape(nh, nw, 4)
        r, c = divmod(i, cols); y0 = (rows - 1 - r) * cell + (cell - nh) // 2; x0 = c * cell + (cell - nw) // 2
        reg = sheet[y0:y0 + nh, x0:x0 + nw]
        al = a[..., 3:4]; reg[..., :3] = a[..., :3] * al + reg[..., :3] * (1 - al)
        bpy.data.images.remove(img)
    o = bpy.data.images.new('mt', cols * cell, rows * cell, alpha=True)
    o.pixels.foreach_set(sheet.reshape(-1)); o.filepath_raw = str(dst); o.file_format = 'PNG'; o.save()
    bpy.data.images.remove(o)
