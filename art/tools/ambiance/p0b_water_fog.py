"""P0 (b) : pluie raccordable, eclaboussures, ondulations, normal map, flaques, brumes, ombres de nuages, rayons, aiguilles.
Blender 5.2 --background --python p0b_water_fog.py [only_prefix]"""
import sys, random; from pathlib import Path; sys.path.insert(0, str(Path(__file__).parent))
from amb_lib import *
setup()
O = OUT
ONLY = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
def want(n): return not ONLY or any(n.startswith(o) for o in ONLY)

def rad(e): return hyp(e.x, e.y)

# ------------------------------------------------------------- rain_sheet_512 (raccordable, R/G/B = 3 densites)
def streak_layer(e, N, seed, K, dens, L0, L1, wid):
    col = floor(e.u * N); fx = fract(e.u * N)
    tot = 0.0
    for k in range(K):
        h1 = wn(col, seed + k * 7.0, 1.0); h2 = wn(col, seed + k * 7.0, 2.0)
        h3 = wn(col, seed + k * 7.0, 3.0); h4 = wn(col, seed + k * 7.0, 4.0)
        present = gt(dens, h1)
        xo = 0.28 + 0.44 * h2
        hx = smooth(wid, wid * 0.25, absv(fx - xo))
        L = L0 + (L1 - L0) * h4
        s = fract(e.v - h3)
        prof = clamp01(1.0 - s / L) ** 1.25 * smooth(0.0, 0.006, s)
        a = present * hx * prof * (0.7 + 0.3 * h4)
        tot = a if k == 0 else mx(tot, a)
    return tot
def rain_sheet(cfg):
    def b(e):
        ch = [streak_layer(e, *c) for c in cfg]
        return tuple(ch), mx(mx(ch[0], ch[1]), ch[2])
    return b
if want('rain_sheet'):
    run('rs1', O / 'rain_sheet_512.png', 512, 512, rain_sheet([(112, 3.0, 1, 0.55, 0.10, 0.22, 0.20), (144, 11.0, 2, 0.6, 0.10, 0.26, 0.22), (200, 23.0, 2, 0.7, 0.08, 0.2, 0.25)]), raw=True)
    run('rs2', O / 'rain_sheet_512_2.png', 512, 512, rain_sheet([(64, 5.0, 1, 0.55, 0.28, 0.5, 0.17), (88, 13.0, 2, 0.6, 0.3, 0.55, 0.18), (120, 29.0, 2, 0.7, 0.22, 0.45, 0.2)]), raw=True)
    run('rain_far', O / 'rain_streak_far_512.png', 512, 512,
        lambda e: (None, mx(streak_layer(e, 90, 41.0, 2, 0.6, 0.05, 0.12, 0.4), streak_layer(e, 130, 53.0, 2, 0.6, 0.04, 0.1, 0.4)) * 0.55))

# ------------------------------------------------------------- eclaboussures 8 x 64 (eau, boue, metal)
def splash(r0, rmax, w0, n, dsz, lift, spread, amp, mud=0.0, seed=1, kk=0.58):
    rnd = random.Random(seed)
    drops = [(rnd.uniform(0, TAU), rnd.uniform(0.55, 1.0), rnd.uniform(0.5, 1.0)) for _ in range(n)]
    def b(e):
        fi, t, x, y = e.atlas(8)
        R = r0 + (rmax - r0) * sqrt(t)
        ww = w0 * (1.0 - 0.45 * t)
        fade = (1.0 - t) ** 0.85
        d = hyp(x, y / kk)
        if mud > 0: d = d + mud * (noise(x * 3.0 + fi * 2.3, y * 3.0, fi * 1.1, detail=2) - 0.5)
        th = atan2(y / kk, x)
        crown = 0.6 + 0.4 * noise(cos(th) * 2.2 + fi * 1.9, sin(th) * 2.2, 3.0 + fi, detail=1)
        ring = gauss(d - R, ww) * crown * fade * smooth(0.0, 0.06, t * 1.0 + 0.04)
        cr2 = hyp(x, (y - 0.14 * (1.0 - t)) / kk)
        inner = gauss(cr2 - R * 0.72, ww * 1.4) * 0.55 * (1.0 - t) ** 1.6
        impact = expn(-(hyp(x, y / kk) / (0.1 + 0.05 * t)) ** 2) * (1.0 - smooth(0.0, 0.5, t)) * 1.2
        tot = ring + inner + impact
        for (ang, sp, ht) in drops:
            rr = r0 + sp * spread * sqrt(t)
            X = rr * math.cos(ang)
            Y = kk * rr * math.sin(ang) + lift * ht * 4.0 * t * (1.0 - t) * 1.0
            dd = hyp(x - X, y - Y)
            tot = tot + expn(-(dd / dsz) ** 2) * (1.0 - t) ** 0.6 * smooth(0.02, 0.18, t)
        return None, tot * amp
    return b
if want('splash'):
    run('splash_w', O / 'splash_8x64.png', 512, 64, splash(0.08, 0.62, 0.075, 9, 0.045, 0.42, 0.85, 0.85, 0.0, 3))
    run('splash_m', O / 'splash_8x64_2.png', 512, 64, splash(0.08, 0.5, 0.13, 6, 0.085, 0.22, 0.7, 0.95, 0.16, 5))
    run('splash_x', O / 'splash_8x64_3.png', 512, 64, splash(0.05, 0.36, 0.045, 12, 0.032, 0.6, 0.9, 1.0, 0.0, 9))

# ------------------------------------------------------------- ondulations 8 x 64
def ripple(rings, gap, w, kk=0.6):
    def b(e):
        fi, t, x, y = e.atlas(8)
        d = hyp(x, y / kk); tot = 0.0
        for i in range(rings):
            R = t * 0.92 - i * gap
            tot = tot + gauss(d - R, w * (1.0 + 0.8 * t)) * smooth(0.02, 0.1, R) * (1.0 - t) ** 1.15 * (1.0 - 0.25 * i)
        return None, tot
    return b
if want('ripple_8'):
    run('rip1', O / 'ripple_8x64.png', 512, 64, ripple(2, 0.26, 0.05))
    run('rip2', O / 'ripple_8x64_2.png', 512, 64, ripple(3, 0.2, 0.035))

# ------------------------------------------------------------- normal map raccordable
def nrm(hf, size, amp):
    eps = 1.0 / size
    h0 = hf(0.0, 0.0); hx = hf(eps, 0.0); hy = hf(0.0, eps)
    nx = -(hx - h0) / eps * amp; ny = -(hy - h0) / eps * amp
    n = vec(nx, ny, 1.0)
    vn = C.tree.nodes.new('ShaderNodeVectorMath'); vn.operation = 'NORMALIZE'
    C.tree.links.new(n.s, vn.inputs[0])
    X, Y, Z = sep(V(vn.outputs[0]))
    return (X * 0.5 + 0.5, Y * 0.5 + 0.5, Z * 0.5 + 0.5)
def ripple_normal(ra, seed, amp, det):
    def b(e):
        def hf(du, dv):
            uu = e.u + du; vv = e.v + dv
            w1 = tn(uu, vv, 1.2, seed=seed, detail=1, rough=0.4) - 0.5
            return tn(uu + w1 * 0.15, vv, ra, seed=seed + 3.0, detail=det, rough=0.42) * 0.7 + 0.3 * tn(uu, vv + w1 * 0.1, ra * 2.1, seed=seed + 9.0, detail=0)
        return nrm(hf, 256, amp), 1.0
    return b
if want('ripple_normal'):
    run('rn1', O / 'ripple_normal_256.png', 256, 256, ripple_normal(2.2, 1.0, 0.045, 2), raw=True)
    run('rn2', O / 'ripple_normal_256_2.png', 256, 256, ripple_normal(3.2, 7.0, 0.035, 3), raw=True)

# ------------------------------------------------------------- masque de flaques (R flaque, G profondeur, B bord mouille) + _n
def puddle_fields(e, ra, seed, th, du=0.0, dv=0.0):
    w1 = tn(e.u + du, e.v + dv, 1.4, seed=seed + 4.0, detail=1) - 0.5
    w2 = tn(e.u + du, e.v + dv, 1.4, seed=seed + 8.0, detail=1) - 0.5
    p = tn(e.u + du + w1 * 0.16, e.v + dv + w2 * 0.16, ra, seed=seed, detail=3, rough=0.45)
    n2 = tn(e.u + du, e.v + dv, 9.0, seed=seed + 2.0, detail=2, rough=0.5)
    return p + (n2 - 0.5) * 0.07
def puddle_build(ra, seed, th):
    def b(e):
        q = puddle_fields(e, ra, seed, th)
        R = smooth(th, th + 0.012, q)
        G = smooth(th, th + 0.16, q)
        B = smooth(th - 0.075, th - 0.01, q) * (1.0 - R)
        return (R, G, B), 1.0
    return b
def puddle_n(ra, seed, th):
    def b(e):
        def hf(du, dv):
            q = puddle_fields(e, ra, seed, th, du, dv)
            return smooth(th - 0.05, th + 0.2, q) * 0.7 + 0.3 * smooth(th - 0.12, th, q)
        return nrm(hf, 1024, 0.05), 1.0
    return b
def calibrate(path_tmp, builder, w, target, lo, hi, key='r', iters=7, raw=True):
    for _ in range(iters):
        mid = (lo + hi) / 2
        d = render(path_tmp, w, w, builder(mid), raw)
        cov = d['rgb_mean'][0] if key == 'r' else d['cover30']
        if cov > target: lo = mid
        else: hi = mid
    return (lo + hi) / 2
if want('puddle'):
    P = [(1.5, 11.0, 0.25), (1.9, 23.0, 0.22), (1.3, 37.0, 0.27), (2.3, 51.0, 0.24)]
    for i, (ra, seed, tgt) in enumerate(P):
        try:
            th = calibrate(RAW / 'tmp_cal.png', lambda t: puddle_build(ra, seed, t), 256, tgt, 0.3, 0.8)
            nm = 'puddle_mask_1024' + ('' if i == 0 else f'_{i + 1}')
            run(nm, O / f'{nm}.png', 1024, 1024, puddle_build(ra, seed, th), raw=True)
            run(nm + '_n', O / f'{nm}_n.png', 1024, 1024, puddle_n(ra, seed, th), raw=True)
        except Exception:
            import traceback; traceback.print_exc()

# ------------------------------------------------------------- brume raccordable 1024 (A fin, B grumeleux)
def fog_a(seed):
    def b(e):
        w1 = tn(e.u, e.v, 1.6, seed=seed, detail=2) - 0.5; w2 = tn(e.u, e.v, 1.6, seed=seed + 5.0, detail=2) - 0.5
        uu = e.u + w1 * 0.22; vv = e.v + w2 * 0.22
        base = tn(uu, vv, 1.3, seed=seed + 1.0, detail=4, rough=0.45)
        fil = tn(uu * 1.0, vv, 1.5, 6.0, seed=seed + 2.0, detail=3, rough=0.4)
        f = base * 0.68 + fil * 0.32
        return None, 0.6 * smooth(0.28, 0.78, f)
    return b
def fog_b(seed):
    def b(e):
        w1 = tn(e.u, e.v, 1.8, seed=seed, detail=2) - 0.5; w2 = tn(e.u, e.v, 1.8, seed=seed + 5.0, detail=2) - 0.5
        uu = e.u + w1 * 0.18; vv = e.v + w2 * 0.18
        lump = 1.0 - tv(uu, vv, 2.6, seed=seed + 3.0, feature='SMOOTH_F1', smoothness=0.8)
        base = tn(uu, vv, 2.0, seed=seed + 1.0, detail=3, rough=0.45)
        f = clamp01(lump) * 0.55 + base * 0.45
        return None, 0.6 * smooth(0.3, 0.8, f)
    return b
if want('fog_tile'):
    run('fogA', O / 'fog_tile_1024.png', 1024, 1024, fog_a(3.0))
    run('fogB', O / 'fog_tile_1024_2.png', 1024, 1024, fog_b(8.0))

# ------------------------------------------------------------- ombres de nuages 2048 (raccordable)
def cloud(ra, seed, th):
    def b(e):
        w1 = tn(e.u, e.v, 0.9, seed=seed, detail=1) - 0.5; w2 = tn(e.u, e.v, 0.9, seed=seed + 5.0, detail=1) - 0.5
        p = tn(e.u + w1 * 0.25, e.v + w2 * 0.25, ra, seed=seed + 1.0, detail=2, rough=0.45)
        return 0.0, 0.72 * smooth(th, th + 0.17, p)
    return b
if want('cloud_shadow'):
    for i, (ra, seed, tgt) in enumerate([(0.65, 13.0, 0.36), (0.72, 29.0, 0.30)]):
        th = calibrate(RAW / 'tmp_cal.png', lambda t: cloud(ra, seed, t), 256, tgt, 0.3, 0.8, key='c', raw=False)
        nm = 'cloud_shadow_2048' + ('' if i == 0 else '_2')
        run(nm, O / f'{nm}.png', 2048, 2048, cloud(ra, seed, th))

# ------------------------------------------------------------- rayons 512x1024
def godray(w0, grow, streak, power, base_amp, up=False, seed=1.0):
    def b(e):
        xn = e.x / 0.5; v = e.v
        s = (1.0 - v) if not up else v     # s = 0 a la source
        w = w0 * (1.0 + grow * s)
        edge = smooth(1.0, 0.25, absv(xn) / w)
        n = noise(xn * 7.0, v * 1.4, seed, detail=2, rough=0.5)
        st = (1.0 - streak) + streak * smooth(0.25, 0.8, n)
        fade = (1.0 - s) ** power * smooth(0.0, 0.07, s)
        return None, base_amp * edge * st * fade
    return b
if want('godray'):
    run('gr1', O / 'godray_512x1024.png', 512, 1024, godray(0.55, 0.6, 0.75, 0.8, 0.5, seed=2.0))
    run('gr2', O / 'godray_512x1024_2.png', 512, 1024, godray(0.28, 0.12, 0.35, 0.55, 0.5, seed=5.0))
    run('gr3', O / 'godray_512x1024_3.png', 512, 1024, godray(0.42, -0.45, 0.5, 1.2, 0.5, up=True, seed=9.0))

# ------------------------------------------------------------- aiguilles de pin 32x32
def pine_needles(segs, wid=0.085):
    def b(e):
        d = None
        for (ax, ay, bx, by) in segs:
            dd = seg(e.x, e.y, ax, ay, bx, by)
            d = dd if d is None else mn(d, dd)
        a = smooth(wid, wid * 0.35, d)
        core = smooth(wid * 0.8, 0.0, d)
        c0 = srgb(H('#2F5A35')); c1 = srgb(H('#86B36A'))
        return tuple(lerp(c0[i], c1[i], core * (0.35 + 0.65 * smooth(-1.0, 1.0, e.y))) for i in range(3)), a
    return b
def H(s): return tuple(int(s[i:i + 2], 16) / 255 for i in (1, 3, 5))
def pine_cone(e):
    q = hyp(e.x / 0.5, (e.y - 0.0) / 0.78)
    a = smooth(1.0, 0.85, q) * smooth(1.0, 0.94, e.y * 1.0 + 0.0) if False else smooth(1.0, 0.85, q)
    cells = voro(e.x * 1.0, e.y * 1.0, 0.0, scale=5.5, feature='F1')
    sh = smooth(0.1, 0.55, cells)
    c0 = srgb(H('#8A6038')); c1 = srgb(H('#3E2A18'))
    rim = smooth(0.5, 1.0, q)
    return tuple(lerp(c0[i], c1[i], sh * 0.8 + rim * 0.3) for i in range(3)), a
if want('leaf_pine'):
    run('pine1', O / 'leaf_pine_32.png', 32, 32, pine_needles([(0.0, -0.9, -0.42, 0.85), (0.0, -0.9, 0.0, 0.95), (0.0, -0.9, 0.42, 0.85)]))
    run('pine2', O / 'leaf_pine_32_2.png', 32, 32, pine_needles([(-0.8, -0.7, 0.75, 0.75), (-0.75, 0.55, 0.78, -0.62)], 0.1))
    run('pine3', O / 'leaf_pine_32_3.png', 32, 32, pine_cone)

# ------------------------------------------------------------- controle : 2x2 des raccordables + planche
for nm in ['rain_sheet_512', 'rain_sheet_512_2', 'rain_streak_far_512', 'ripple_normal_256', 'ripple_normal_256_2',
           'puddle_mask_1024', 'puddle_mask_1024_2', 'puddle_mask_1024_3', 'puddle_mask_1024_4', 'puddle_mask_1024_n',
           'fog_tile_1024', 'fog_tile_1024_2', 'cloud_shadow_2048', 'cloud_shadow_2048_2']:
    if (O / f'{nm}.png').exists() and want(nm.split('_')[0] if nm.startswith('rain_sheet') is False else 'rain_sheet'):
        tile2x2(O / f'{nm}.png', RAW / f'tile2x2_{nm}.png', 512)
json.dump(LOG, open(RAW / 'log_p0b.json', 'w'), indent=1)
