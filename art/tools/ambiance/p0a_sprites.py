"""P0 (a) : lumieres, halos, vignette, ciels, gouttes, etincelles, glint, mote, trainees, impacts.
Blender 5.2 --background --python p0a_sprites.py"""
import sys; from pathlib import Path; sys.path.insert(0, str(Path(__file__).parent))
from amb_lib import *
setup()
O = OUT

def rad(e): return hyp(e.x, e.y)

# ------------------------------------------------------------- lumieres (gris/blanc sur alpha)
run('light_soft', O / 'light_soft_256.png', 256, 256,
    lambda e: (None, expn(-(rad(e) ** 2) * 5.0) * smooth(1.0, 0.8, rad(e))))
run('light_hard', O / 'light_hard_256.png', 256, 256,
    lambda e: (None, smooth(1.0, 0.75, rad(e))))
run('halo_soft', O / 'halo_soft_256.png', 256, 256,
    lambda e: (None, expn(-(rad(e) ** 2) * 2.2) * smooth(1.0, 0.72, rad(e))))

def ring1(e):
    r = rad(e)
    return None, smooth(0.66, 0.78, r) * smooth(1.0, 0.88, r)
run('light_ring', O / 'light_ring_256.png', 256, 256, ring1)

def ring2(e):  # anneau bicolore : moitie haute (180 deg) pleine, moitie basse a 40 %
    r = rad(e); ring = smooth(0.66, 0.74, r) * smooth(1.0, 0.92, r)
    half = smooth(-0.12, 0.12, e.y)
    return None, ring * (0.4 + 0.6 * half)
run('light_ring_2', O / 'light_ring_256_2.png', 256, 256, ring2)

# ------------------------------------------------------------- vignette (noir, alpha = assombrissement)
def vig(e):
    r = rad(e)
    return 0.0, 0.88 * smooth(0.42, 1.38, r) ** 1.35
run('vignette', O / 'vignette_1024.png', 1024, 1024, vig)

# ------------------------------------------------------------- ciels (colores, opaques)
def mix3(c0, c1, t): return tuple(lerp(a, b, t) for a, b in zip(c0, c1))
def grad(t, stops):
    col = srgb(stops[0][1])
    for i in range(1, len(stops)):
        col = mix3(col, srgb(stops[i][1]), smooth(stops[i - 1][0], stops[i][0], t))
    return col
def sky(stops, wob=0.015):
    def b(e):
        t = e.v + wob * sin(e.v * 38.0 + e.u * 2.0) + 0.02 * noise(e.u * 3.0, e.v * 5.0, 1.0, detail=1, rough=0.4) - 0.01
        # t decroit vers le bas : stops donnes du haut (v=1) vers le bas (v=0)
        return grad(1.0 - t, stops), 1.0
    return b
H = lambda s: tuple(int(s[i:i + 2], 16) / 255 for i in (1, 3, 5))
run('sky_sunset', O / 'sky_sunset_256x64.png', 256, 64,
    sky([(0.0, H('#F0B089')), (0.45, H('#F6D79A')), (0.75, H('#C9C79B')), (1.0, H('#87978A'))]))
run('sky_dawn', O / 'sky_dawn_256x64.png', 256, 64,
    sky([(0.0, H('#16233F')), (0.4, H('#2F5877')), (0.75, H('#6FA4A5')), (1.0, H('#A7D2C0'))]))
run('sky_storm', O / 'sky_storm_256x64.png', 256, 64,
    sky([(0.0, H('#1D1E26')), (0.35, H('#3A3050')), (0.7, H('#5A4A78')), (0.86, H('#BDB8D4')), (1.0, H('#4A4560'))], 0.01))

# ------------------------------------------------------------- gouttes 32x32 (retro-eclairees + reflet)
def drop(cy, rx, ry, taper, tilt=0.0):
    def b(e):
        x = e.x - tilt * (e.y + 1.0) * 0.15; y = e.y
        yy = (y - cy) / ry
        hw = mx(rx * sqrt(clamp01(1.0 - yy * yy)) * (1.0 - taper * smooth(-0.25, 1.0, yy)), 0.002)
        d = absv(x) / hw
        inside = (1.0 - smooth(0.86, 1.0, d)) * smooth(1.0, 0.93, absv(yy))
        rim = smooth(0.45, 0.95, d)
        glow = smooth(-0.9, -0.1, yy * -1.0) * 0.25 * (1.0 - d)   # retro-eclairage bas
        hl = expn(-(((x + 0.32 * rx) / (0.20 * rx + 0.04)) ** 2 + ((y - cy - 0.32 * ry) / (0.24 * ry)) ** 2))
        a = inside * (0.38 + 0.4 * rim + glow) + hl * 0.95
        return None, mn(a, 1.0) * (1.0 if True else 1.0)
    return b
for i, (cy, rx, ry, tp, tl) in enumerate([(-0.05, 0.5, 0.78, 0.55, 0.0), (0.0, 0.42, 0.7, 0.8, 0.5),
                                        (-0.1, 0.62, 0.62, 0.35, 0.0), (0.05, 0.34, 0.86, 0.9, -0.5)]):
    run(f'drop{i}', O / f'drop_32{"" if i == 0 else "_" + str(i + 1)}.png', 32, 32, drop(cy, rx, ry, tp, tl))

# ------------------------------------------------------------- etincelles 16x16
def spark(cx, cy, tl, glow):
    def b(e):
        d = hyp(e.x - cx, e.y - cy)
        core = expn(-(d / 0.17) ** 2)
        s = clamp01((cy - e.y) / tl)
        trail = gauss(e.x - cx, 0.13 + 0.05 * (1 - s)) * (1.0 - s) ** 1.6 * smooth(cy + 0.05, cy - 0.1, e.y) * 0.85
        return None, mn(core * 1.2 + trail + glow * expn(-(d / 0.5) ** 2), 1.0)
    return b
run('spark1', O / 'spark_16.png', 16, 16, spark(0.0, 0.45, 1.4, 0.25))
run('spark2', O / 'spark_16_2.png', 16, 16, spark(0.1, 0.35, 0.9, 0.1))

# ------------------------------------------------------------- glint 32x32 : etoile a 4 branches
def glint(diag):
    def b(e):
        r = rad(e)
        cross = mx(gauss(e.y, 0.06) * expn(-absv(e.x) * 2.6), gauss(e.x, 0.06) * expn(-absv(e.y) * 2.6))
        core = expn(-(r / 0.16) ** 2)
        a = cross + core * 0.6
        if diag:
            ru = (e.x + e.y) * 0.7071; rv = (e.x - e.y) * 0.7071
            a = a + 0.45 * mx(gauss(rv, 0.05) * expn(-absv(ru) * 5.0), gauss(ru, 0.05) * expn(-absv(rv) * 5.0))
        return None, mn(a, 1.0) * smooth(1.0, 0.85, r * 0.82)
    return b
run('glint1', O / 'glint_32.png', 32, 32, glint(False))
run('glint2', O / 'glint_32_2.png', 32, 32, glint(True))

# ------------------------------------------------------------- moucherons / spores 16x16
run('mote1', O / 'mote_16.png', 16, 16, lambda e: (None, 0.95 * expn(-(rad(e) / 0.42) ** 2)))
run('mote2', O / 'mote_16_2.png', 16, 16, lambda e: (None, 0.85 * expn(-(rad(e) / 0.22) ** 2) + 0.22 * expn(-(rad(e) / 0.7) ** 2)))

# ------------------------------------------------------------- trainees 64x256 (tete en bas, queue vers le haut)
def trail(wild, wid, pw):
    def b(e):
        s = (e.y + 1.0) * 0.5; xn = e.x / 0.25
        n = noise(xn * 1.6, s * 9.0, wild * 3.0, detail=2, rough=0.5) - 0.5
        w = wid * (1.0 - 0.75 * s) + 0.04
        a = gauss(xn + n * wild * 0.9 * s, w) * (1.0 - s) ** pw
        if wild > 0:
            a = a + 0.35 * smooth(0.72, 0.9, noise(xn * 6.0, s * 40.0, 7.0, detail=0)) * (1 - s) ** 1.2 * gauss(xn, 0.9)
        return None, a * smooth(0.0, 0.02, s)
    return b
run('trail1', O / 'trail_64x256.png', 64, 256, trail(0.0, 0.5, 1.6))
run('trail2', O / 'trail_64x256_2.png', 64, 256, trail(1.0, 0.7, 1.15))

# ------------------------------------------------------------- impacts 8 images 64x64 (512x64)
def impact_fire(e):
    fi, t, x, y = e.atlas(8)
    r = hyp(x, y)
    R = 0.28 + 0.6 * sqrt(t)
    n = noise(x * 2.4 + fi * 1.7, y * 2.4, fi * 0.9, detail=3, rough=0.55)
    rd = r * (0.75 + 0.55 * (1.0 - n))
    body = smooth(R, R * 0.2, rd) * (1.0 - t ** 1.6)
    core = expn(-(r / (0.32 * (1.0 - 0.6 * t) + 0.05)) ** 2) * (1.0 - t) ** 1.4
    # etincelles
    sp = smooth(0.78, 0.95, noise(x * 5.0 + fi * 3.1, y * 5.0, 2.0, detail=0)) * smooth(R * 1.2, R * 0.6, r) * (1.0 - t)
    return None, body * 0.85 + core + sp * 0.5
def impact_gen(e):
    fi, t, x, y = e.atlas(8)
    r = hyp(x, y); th = atan2(y, x)
    R = 0.15 + 0.72 * sqrt(t)
    ring = gauss(r - R, 0.07 + 0.05 * t) * (1.0 - t) ** 1.2
    spokes = absv(cos(th * 4.0 + fi * 0.4)) ** 14.0
    star = spokes * smooth(R * 1.05, R * 0.2, r) * (1.0 - t) ** 1.5 * 0.9
    core = expn(-(r / (0.3 * (1.0 - t) + 0.04)) ** 2) * (1.0 - t) ** 1.2
    return None, mn(ring + star + core, 1.0)
run('impact_fire', O / 'impact_8x64.png', 512, 64, impact_fire)
run('impact_gen', O / 'impact_8x64_2.png', 512, 64, impact_gen)

# ------------------------------------------------------------- controle visuel
files = [O / n for n in ['light_soft_256.png', 'light_hard_256.png', 'light_ring_256.png', 'light_ring_256_2.png', 'halo_soft_256.png',
         'vignette_1024.png', 'sky_sunset_256x64.png', 'sky_dawn_256x64.png', 'sky_storm_256x64.png',
         'drop_32.png', 'drop_32_2.png', 'drop_32_3.png', 'drop_32_4.png', 'spark_16.png', 'spark_16_2.png',
         'glint_32.png', 'glint_32_2.png', 'mote_16.png', 'mote_16_2.png', 'trail_64x256.png', 'trail_64x256_2.png',
         'impact_8x64.png', 'impact_8x64_2.png']]
montage(files, RAW / 'check_p0a.png', cell=256, cols=6)
json.dump(LOG, open(RAW / 'log_p0a.json', 'w'), indent=1)
