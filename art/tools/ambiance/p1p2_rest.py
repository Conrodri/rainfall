"""P1 + P2 : brumes, canopee, particules, eclairs, horizon, vent, arcs, caustiques, gouttes de fenetre, braises, etc.
Blender 5.2 --background --python p1p2_rest.py [-- prefix ...]"""
import sys, random; from pathlib import Path; sys.path.insert(0, str(Path(__file__).parent))
from amb_lib import *
setup()
O = OUT
ONLY = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
def want(n): return not ONLY or any(n.startswith(o) for o in ONLY)
def rad(e): return hyp(e.x, e.y)
def H(s): return tuple(int(s[i:i + 2], 16) / 255 for i in (1, 3, 5))
def L(s): return srgb(H(s))
def mixc(c0, c1, t): return tuple(lerp(a, b, t) for a, b in zip(c0, c1))
def nrm(hf, size, amp):
    eps = 1.0 / size
    h0 = hf(0.0, 0.0); hx = hf(eps, 0.0); hy = hf(0.0, eps)
    n = vec(-(hx - h0) / eps * amp, -(hy - h0) / eps * amp, 1.0)
    vn = C.tree.nodes.new('ShaderNodeVectorMath'); vn.operation = 'NORMALIZE'
    C.tree.links.new(n.s, vn.inputs[0])
    X, Y, Z = sep(V(vn.outputs[0]))
    return (X * 0.5 + 0.5, Y * 0.5 + 0.5, Z * 0.5 + 0.5)

# ------------------------------------------------------------- fog_puff_512 x6 (+ _n)
def puff_field(e, seed, sx, sy, dx=0.0, dy=0.0):
    x = e.x + dx; y = e.y + dy
    n = noise(x * 1.7 + seed, y * 1.7, seed * 0.7, detail=4, rough=0.5)
    n2 = noise(x * 4.0 + seed, y * 4.0, seed + 3.0, detail=2, rough=0.5)
    r = hyp(x / sx, y / sy) + (0.5 - n) * 0.85
    return smooth(1.0, 0.1, r) * (0.55 + 0.45 * n2)
if want('fog_puff'):
    for i in range(6):
        sd = 3.0 + i * 7.3; sx = [1.0, 0.85, 1.0, 0.7, 0.9, 0.8][i]; sy = [1.0, 0.95, 0.75, 0.9, 0.8, 1.0][i]
        nm = 'fog_puff_512' + ('' if i == 0 else f'_{i + 1}')
        run(nm, O / f'{nm}.png', 512, 512, lambda e: (None, 0.7 * puff_field(e, sd, sx, sy)))
        run(nm + '_n', O / f'{nm}_n.png', 512, 512,
            lambda e: (nrm(lambda du, dv: puff_field(e, sd, sx, sy, du * 2.0, dv * 2.0), 512, 0.012), smooth(0.0, 0.1, puff_field(e, sd, sx, sy))), raw=True)

# ------------------------------------------------------------- brume haute raccordable (fine)
def fogv(ra, seed):
    def b(e):
        w1 = tn(e.u, e.v, 2.0, seed=seed, detail=2) - 0.5; w2 = tn(e.u, e.v, 2.0, seed=seed + 5.0, detail=2) - 0.5
        uu = e.u + w1 * 0.1; vv = e.v + w2 * 0.1
        f = tn(uu, vv, ra, seed=seed + 1.0, detail=4, rough=0.5) * 0.7 + tn(uu, vv, ra * 0.5, ra * 2.0, seed=seed + 2.0, detail=2) * 0.3
        return None, 0.4 * smooth(0.32, 0.74, f)
    return b
if want('fog_volume'):
    run('fv1', O / 'fog_volume_tile_1024.png', 1024, 1024, fogv(3.2, 4.0))
    run('fv2', O / 'fog_volume_tile_1024_2.png', 1024, 1024, fogv(4.6, 17.0))

# ------------------------------------------------------------- ombres de canopee raccordables
def canopy(seed, th, cl):
    def b(e):
        w1 = tn(e.u, e.v, 1.2, seed=seed, detail=1) - 0.5; w2 = tn(e.u, e.v, 1.2, seed=seed + 5.0, detail=1) - 0.5
        uu = e.u + w1 * 0.2; vv = e.v + w2 * 0.2
        lo = tn(uu, vv, 1.1, seed=seed + 1.0, detail=2, rough=0.45)
        cl_ = 1.0 - tv(uu, vv, cl, seed=seed + 2.0)
        hf = tn(uu, vv, 26.0, 9.0, seed=seed + 3.0, detail=1, rough=0.4)
        hf2 = tn(uu, vv, 9.0, 26.0, seed=seed + 4.0, detail=1, rough=0.4)
        leaf = mx(smooth(0.5, 0.62, hf), smooth(0.5, 0.62, hf2))
        m_ = smooth(th, th + 0.1, lo * 0.7 + clamp01(cl_) * 0.3)
        return 0.0, 0.78 * m_ * (0.45 + 0.55 * leaf)
    return b
if want('canopy'):
    run('can1', O / 'canopy_shadow_2048.png', 2048, 2048, canopy(5.0, 0.4, 5.5))
    run('can2', O / 'canopy_shadow_2048_2.png', 2048, 2048, canopy(21.0, 0.38, 7.0))

# ------------------------------------------------------------- caustiques raccordables
def caustic(seed, ra):
    def b(e):
        w1 = tn(e.u, e.v, 1.6, seed=seed, detail=1) - 0.5; w2 = tn(e.u, e.v, 1.6, seed=seed + 5.0, detail=1) - 0.5
        uu = e.u + w1 * 0.12; vv = e.v + w2 * 0.12
        d1 = tv(uu, vv, ra, seed=seed + 1.0, feature='DISTANCE_TO_EDGE')
        d2 = tv(uu, vv, ra * 1.7, seed=seed + 2.0, feature='DISTANCE_TO_EDGE')
        c = (1.0 - smooth(0.0, 0.1, d1)) ** 1.4 + 0.55 * (1.0 - smooth(0.0, 0.08, d2)) ** 1.4
        return None, 0.85 * clamp01(c)
    return b
if want('water_caustics'):
    run('wc1', O / 'water_caustics_512.png', 512, 512, caustic(2.0, 3.0))
    run('wc2', O / 'water_caustics_512_2.png', 512, 512, caustic(11.0, 4.0))

# ------------------------------------------------------------- ciel / horizon
def horizon(seed, c_lo, c_hi, patch):
    def b(e):
        n = noise(e.u * 7.0 + seed, e.v * 2.5, seed, detail=3, rough=0.55)
        n2 = noise(e.u * 22.0, e.v * 6.0, seed + 4.0, detail=1)
        a = (1.0 - smooth(0.0, 0.85, e.v)) ** 1.6 * (1.0 - patch + patch * 1.5 * smooth(0.25, 0.75, n)) * (0.85 + 0.3 * n2)
        return mixc(L(c_lo), L(c_hi), smooth(0.0, 0.6, e.v)), 0.9 * a
    return b
if want('horizon_glow'):
    run('hz1', O / 'horizon_glow_1024x256.png', 1024, 256, horizon(1.0, '#E6EEFF', '#6C8CCB', 0.7))
    run('hz2', O / 'horizon_glow_1024x256_2.png', 1024, 256, horizon(9.0, '#F0E6FF', '#7E78C8', 0.9))

# ------------------------------------------------------------- eclairs 256x1024 (+ _e : lueur)
def jag(v, seed, N, amp):
    i = floor(v * N); f = fract(v * N)
    f = f * f * (3.0 - 2.0 * f) * 0.0 + f
    return (lerp(wn(i, seed, 0.0), wn(i + 1.0, seed, 0.0), f) - 0.5) * amp
def bolt(seed, nbr, glow):
    rnd = random.Random(int(seed * 10))
    def b(e):
        xn = e.x / 0.25; v = e.v
        def xc_of(vv): return (jag(vv, seed, 11, 1.1) + jag(vv, seed + 3.0, 33, 0.28)) * smooth(0.0, 0.08, vv) * smooth(1.0, 0.92, vv)
        xc = xc_of(v)
        wc = 0.032; wg = 0.2
        tot = gauss(xn - xc, wc) if not glow else gauss(xn - xc, wg) * 0.9
        for k in range(nbr):
            v0 = rnd.uniform(0.25, 0.85); sl = rnd.choice([-1, 1]) * rnd.uniform(0.6, 1.2); ln = rnd.uniform(0.18, 0.35)
            x0 = xc_of(v0)
            bx = x0 + sl * (v0 - v) * 0.8 + jag(v, seed + 10.0 + k, 17, 0.35)
            gate = smooth(v0 + 0.01, v0 - 0.02, v) * smooth(v0 - ln, v0 - ln + 0.08, v)
            tot = tot + (gauss(xn - bx, wc * 0.7) * 0.8 if not glow else gauss(xn - bx, wg * 0.6) * 0.45) * gate
        if not glow: tot = tot + 0.35 * gauss(xn - xc, wg) * 0.0
        return None, mn(tot, 1.0) * smooth(0.0, 0.02, v) * smooth(1.0, 0.98, v)
    return b
if want('lightning'):
    for i, (sd, nb) in enumerate([(2.0, 3), (7.0, 2), (13.0, 4), (19.0, 1)]):
        nm = 'lightning_bolt_256x1024' + ('' if i == 0 else f'_{i + 1}')
        run(nm, O / f'{nm}.png', 256, 1024, bolt(sd, nb, False))
        run(nm + '_e', O / f'{nm}_e.png', 256, 1024, bolt(sd, nb, True))

# ------------------------------------------------------------- traits de vent 128x32
def wind(kind):
    def b(e):
        s = e.u; env = (sin(s * math.pi)) ** 1.6
        if kind == 0: a = gauss(e.y, 0.09) * env
        elif kind == 1: a = (gauss(e.y - 0.38, 0.06) * smooth(0.05, 0.4, s) * smooth(1.0, 0.55, s) + gauss(e.y + 0.3, 0.07) * env * 0.8)
        else: a = gauss(e.y - 0.3 * sin(s * 9.0), 0.08) * env
        return None, a * 0.8
    return b
if want('wind_streak'):
    for i in range(3): run('wind', O / ('wind_streak_128' + ('' if i == 0 else f'_{i + 1}') + '.png'), 128, 32, wind(i))

# ------------------------------------------------------------- arcs electriques 8 x 64
def arc(N, amp, fork):
    def b(e):
        fi, t, x, y = e.atlas(8)
        s = (x + 1.0) * 0.5
        pin = sin(s * math.pi)
        yc = (jag(s, fi * 5.0 + 1.0, N, amp) + jag(s, fi * 5.0 + 2.0, N * 2.6, amp * 0.3)) * pin
        a = gauss(y - yc, 0.07) + 0.3 * gauss(y - yc, 0.26)
        if fork:
            y2 = yc + (s - 0.5) * 0.9 + jag(s, fi * 5.0 + 4.0, 11, 0.5)
            a = a + 0.55 * gauss(y - y2, 0.055) * smooth(0.45, 0.55, s)
        return None, mn(a, 1.0) * smooth(-1.0, -0.8, x) * smooth(1.0, 0.8, x)
    return b
if want('arc_8'):
    run('arc1', O / 'arc_8x64.png', 512, 64, arc(8, 1.6, False))
    run('arc2', O / 'arc_8x64_2.png', 512, 64, arc(12, 1.2, False))
    run('arc3', O / 'arc_8x64_3.png', 512, 64, arc(7, 1.4, True))

# ------------------------------------------------------------- particules colorees / grises
if want('aura_ring'):
    run('aura', O / 'aura_ring_128.png', 128, 128, lambda e: (None, 0.9 * gauss(rad(e) - 0.74, 0.12) * smooth(1.0, 0.9, rad(e)) + 0.12 * expn(-(rad(e) / 0.8) ** 2)))
if want('firefly'):
    for i, (c, hs) in enumerate([('#D4FF72', 0.55), ('#9CFFC4', 0.65)]):
        run('ff', O / ('firefly_16' + ('' if i == 0 else '_2') + '.png'), 16, 16,
            lambda e: (mixc(L('#6BE06A'), L(c), expn(-(rad(e) / 0.25) ** 2)), mn(expn(-(rad(e) / 0.2) ** 2) + 0.55 * expn(-(rad(e) / hs) ** 2), 1.0)))
def seg_shape(segs, wid, c0, c1, tilt=0.0):
    def b(e):
        d = None
        for (ax, ay, bx, by) in segs:
            dd = seg(e.x, e.y, ax, ay, bx, by); d = dd if d is None else mn(d, dd)
        a = smooth(wid, wid * 0.3, d); core = smooth(wid * 0.9, 0.0, d)
        return mixc(L(c0), L(c1), core * (0.3 + 0.7 * smooth(-1.0, 1.0, e.y))), a
    return b
def cedar(pairs, curve, ln0, flip=1.0):
    segs = []
    for k in range(pairs):
        y = -0.82 + k * (1.55 / (pairs - 1)); ln = ln0 * (1.0 - 0.7 * k / pairs)
        cx = curve * y * y
        for sd in (-1, 1): segs.append((cx, y, cx + sd * ln, y + 0.28 * flip))
    segs.append((curve * 0.67, -0.9, curve * 0.67, 0.95))
    return segs
if want('leaf_cedar'):
    run('lc1', O / 'leaf_cedar_32.png', 32, 32, seg_shape(cedar(6, 0.0, 0.62), 0.085, '#2F5A3A', '#8DBB74'))
    run('lc2', O / 'leaf_cedar_32_2.png', 32, 32, seg_shape(cedar(6, 0.3, 0.55), 0.085, '#3A6A44', '#A2C97E'))
    run('lc3', O / 'leaf_cedar_32_3.png', 32, 32, seg_shape(cedar(4, -0.2, 0.7), 0.1, '#2A4F35', '#7FA86A'))
def ash(c, seed, spk):
    def b(e):
        n = noise(e.x * 2.2 + seed, e.y * 2.2, seed, detail=2, rough=0.6)
        r = hyp(e.x / 0.75, e.y / 0.55) * (0.75 + 0.7 * (1.0 - n))
        a = smooth(0.9, 0.55, r)
        sp = smooth(0.62, 0.75, noise(e.x * 5.0, e.y * 5.0, seed + 4.0, detail=0)) * spk
        return mixc(mixc(L(c), L('#C85A24'), sp), L('#2C2724'), smooth(0.0, 0.6, r) * 0.0), a
    return b
if want('ash'):
    run('ash1', O / 'ash_16.png', 16, 16, ash('#7A6B60', 1.0, 0.0))
    run('ash2', O / 'ash_16_2.png', 16, 16, ash('#8A5A3A', 6.0, 0.8))
def steam(seed, k):
    def b(e):
        n = noise(e.x * 2.2 + seed, e.y * 2.2, seed, detail=4, rough=0.55)
        r = hyp(e.x, e.y) + (0.5 - n) * k
        return None, 0.62 * smooth(0.95, 0.15, r) * (0.7 + 0.3 * n)
    return b
if want('steam_puff'):
    for i in range(4): run('st', O / ('steam_puff_64' + ('' if i == 0 else f'_{i + 1}') + '.png'), 64, 64, steam(2.0 + i * 5.1, 0.7 + 0.12 * i))
def lightcone(top, bot, dust, seed):
    def b(e):
        xn = e.x / 0.5; s = 1.0 - e.v
        w = top + (bot - top) * s
        edge = smooth(1.0, 0.3, absv(xn) / w)
        n = noise(xn * 3.0, e.v * 3.0, seed, detail=2)
        d = (1.0 - dust) + dust * smooth(0.3, 0.75, n)
        return None, 0.8 * edge * d * (1.0 - s) ** 0.5 * (1.0 - smooth(0.7, 1.0, s)) * smooth(0.0, 0.05, s) * 1.0 + 0.0
    return b
if want('lightcone'):
    run('lcn1', O / 'lightcone_256x512.png', 256, 512, lightcone(0.08, 0.95, 0.0, 1.0))
    run('lcn2', O / 'lightcone_256x512_2.png', 256, 512, lightcone(0.12, 0.8, 0.55, 4.0))

# ------------------------------------------------------------- P2
def window_drop(cy, rx, ry, trail, nmode=False):
    def b(e):
        yy = (e.y - cy) / ry; xx = e.x / rx
        q = hyp(xx, yy)
        body = smooth(1.0, 0.9, q)
        tr = gauss(e.x, rx * 0.35) * smooth(cy - ry * 0.6, cy - ry * 1.05, e.y) * smooth(-1.0, cy - ry, e.y) * trail if trail > 0 else 0.0
        if nmode:
            k = 0.9
            nx = xx * k * body; ny = yy * k * body
            n = vec(nx, ny, sqrt(clamp01(1.0 - (nx * nx + ny * ny) * 0.8)) + 0.2)
            vn = C.tree.nodes.new('ShaderNodeVectorMath'); vn.operation = 'NORMALIZE'; C.tree.links.new(n.s, vn.inputs[0])
            X, Y, Z = sep(V(vn.outputs[0]))
            return (X * 0.5 + 0.5, Y * 0.5 + 0.5, Z * 0.5 + 0.5), mx(body, tr * 0.5)
        rim = smooth(0.55, 0.95, q)
        hl = expn(-(((e.x + 0.3 * rx) / (0.22 * rx)) ** 2 + ((e.y - cy - 0.35 * ry) / (0.2 * ry)) ** 2))
        return None, mx(body * (0.35 + 0.4 * rim) + hl * 0.6, tr * 0.4)
    return b
if want('drop_window'):
    cfgs = [(0.0, 0.5, 0.5, 0), (0.0, 0.34, 0.34, 0), (-0.05, 0.4, 0.6, 0), (0.45, 0.4, 0.4, 1.0), (0.35, 0.3, 0.42, 1.0), (0.1, 0.22, 0.22, 0)]
    for i, c in enumerate(cfgs):
        nm = 'drop_window_64' + ('' if i == 0 else f'_{i + 1}')
        run(nm, O / f'{nm}.png', 64, 64, window_drop(*c))
        run(nm + '_n', O / f'{nm}_n.png', 64, 64, window_drop(*c, nmode=True), raw=True)
def ember(tl, c0, c1, wid):
    def b(e):
        d = hyp(e.x, e.y - 0.4); s = clamp01((0.4 - e.y) / tl)
        core = expn(-(d / 0.2) ** 2)
        trail = gauss(e.x, wid * (1.0 - 0.5 * s)) * (1.0 - s) ** 1.4 * smooth(0.45, 0.2, e.y)
        a = mn(core * 1.1 + trail * 0.8, 1.0)
        return mixc(L(c0), L(c1), clamp01(s * 1.4 + (1.0 - core) * 0.5)), a
    return b
if want('ember'):
    run('em1', O / 'ember_16.png', 16, 16, ember(1.3, '#FFE08A', '#E8541C', 0.2))
    run('em2', O / 'ember_16_2.png', 16, 16, ember(0.9, '#FFC060', '#C73A12', 0.16))
    run('em3', O / 'ember_16_3.png', 16, 16, ember(1.5, '#FFF0B0', '#F07A1E', 0.24))
def frost(kind, arms):
    def b(e):
        r = rad(e); th = atan2(e.y, e.x)
        arm = absv(cos(th * arms * 0.5)) ** (kind)
        a = smooth(1.0, 0.6, r / (0.3 + 0.7 * arm))
        return mixc(L('#9FD8F5'), L('#F2FBFF'), smooth(0.8, 0.0, r)), a
    return b
if want('frost'):
    run('fr1', O / 'frost_crystal_16.png', 16, 16, frost(6.0, 6))
    run('fr2', O / 'frost_crystal_16_2.png', 16, 16, frost(1.5, 6))
    run('fr3', O / 'frost_crystal_16_3.png', 16, 16, frost(3.0, 4))
def bubble(hx):
    def b(e):
        r = rad(e)
        ring = gauss(r - 0.72, 0.13) * 0.85
        hl = expn(-(((e.x + hx * 0.35) / 0.2) ** 2 + ((e.y - 0.35) / 0.14) ** 2))
        return None, mn(ring + 0.12 * smooth(0.8, 0.0, r) + hl * 0.9, 1.0) * smooth(1.0, 0.9, r)
    return b
if want('bubble'):
    run('bu1', O / 'bubble_16.png', 16, 16, bubble(1.0)); run('bu2', O / 'bubble_16_2.png', 16, 16, bubble(-0.4))
def flare(wy, tl, ring):
    def b(e):
        a = gauss(e.y, wy) * expn(-absv(e.x / 1.0) * tl) + 0.55 * expn(-(rad(e) / 0.16) ** 2) + 0.12 * gauss(e.x, 0.04) * expn(-absv(e.y) * 3.0)
        if ring: a = a + 0.3 * gauss(rad(e) - 0.55, 0.05) * 0.5
        return mixc(L('#FFC070'), L('#FFF4DC'), expn(-(rad(e) / 0.22) ** 2)), mn(a, 1.0) * smooth(1.0, 0.8, absv(e.x))
    return b
if want('lantern_flare'):
    run('lf1', O / 'lantern_flare_128.png', 128, 128, flare(0.045, 2.2, False))
    run('lf2', O / 'lantern_flare_128_2.png', 128, 128, flare(0.07, 1.7, True))

json.dump(LOG, open(RAW / 'log_p1p2.json', 'w'), indent=1)
