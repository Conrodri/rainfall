"""Priorite 4 : variantes B (braises errantes, pilier de flamme, meteore + impact, phenix)."""
from fx_defs import *
from fx_p1 import embers_rise, flame_ring

def build_wander(f, n):
    t = f / n; ph = TAU * t; rng = random.Random(31); R = 1.0
    ground('halo', 0, 0, 2.6, 2.6 * .82, color=FIRE, alpha=.2 + .05 * math.sin(ph * 2))
    ground('ring_thin', 0, 0, R * 2.0, R * 2.0 * .82, color=DEEP, alpha=.35)
    for k in range(3):
        a0 = ph + TAU * k / 3
        for j in range(14, 0, -1):          # traine
            a = a0 - j * .085; u = 1 - j / 14
            sprite('glow', math.cos(a) * R, math.sin(a) * R * .82 + .25, .12 + .34 * u * u, color=FIRE if j > 6 else GOLD, alpha=.75 * u ** 1.5, d=-.1)
        x = math.cos(a0) * R; y = math.sin(a0) * R * .82 + .25
        sprite('halo', x, y, .85, color=FIRE, alpha=.5, d=-.2)
        sprite('flame', x, y + .12, .42, .62, color=FIRE, alpha=1, rot=-math.sin(a0) * .5 + .15 * math.sin(ph * 3 + k), d=0)
        sprite('flame', x, y + .1, .26, .42, color=CORE, alpha=1, rot=.1 * math.sin(ph * 2 + k), d=.1)
        sprite('glow', x, y + .02, .3, color=CORE, alpha=1, d=.2)
    embers_rise(rng, 18, t, True, area=(R, R * .6), h=.8, size=.06, y0=.15)

eff('ember_orbs', (192, 192), {'default': A(8, 12, True, build_wander)}, ppu=56)

def build_pillar(f, n):
    t = f / n; rng = random.Random(44)
    amp = ss(t, 0, .22) * (1 - ss(t, .72, 1.0)); H = 2.1 * ss(t, 0, .3) + .2
    ground('halo', 0, 0, 2.2 * (.4 + .6 * ss(t, 0, .3)), 2.2 * (.4 + .6 * ss(t, 0, .3)) * .82, color=FIRE, alpha=.55 * (1 - ss(t, .7, 1.0)))
    ground('ring_thick', 0, 0, .6 + 1.7 * ss(t, 0, .35), (.6 + 1.7 * ss(t, 0, .35)) * .82, color=FIRE, alpha=.8 * (1 - ss(t, .3, .9)))
    ground('ring', 0, 0, .5 + 1.2 * ss(t, 0, .5), (.5 + 1.2 * ss(t, 0, .5)) * .82, color=GOLD, alpha=.8 * amp)
    for i in range(6):
        sprite('smoke', rng.uniform(-.4, .4), H * .9 + rng.uniform(-.2, .2), 1.0 + .5 * t, color=SMOKE, alpha=.45 * ss(t, .2, .5) * (1 - ss(t, .6, 1.0)), d=-.5)
    for k, (dx, wd, col, hh) in enumerate(((0, 1.0, FIRE, 1.15), (-.16, .75, DEEP, 1.0), (.16, .75, GOLD, 1.05), (0, .62, GOLD, .85), (.05, .4, CORE, .7))):
        x = dx + math.sin(t * 9 + k * 1.3) * .07; hgt = H * hh
        sprite('flame', x, hgt * .5 + .05, wd * amp + .05, hgt, color=col, alpha=min(1, amp * 1.5) * (amp > .06), rot=math.sin(t * 7 + k) * .06, d=.05 * k)
    for k in range(5):
        u = (k + .5) / 5; y = H * u * .75; x = math.sin(t * 8 + k * 2.1) * .2 * u
        sprite('flame', x, y + .35, .5 * amp * (1 - .4 * u) + .03, .9, color=FIRE if k % 2 else GOLD, alpha=min(1, amp * 1.4) * (amp > .06), rot=x * 1.5 + math.sin(t * 6 + k) * .1, d=.25)
    flame_ring(rng, .85 * (.3 + .7 * ss(t, 0, .4)), 12, .8 * amp, .4, min(1, amp * 1.4), lean=.2)
    sprite('glow', 0, .5, 1.6 * amp + .1, color=CORE, alpha=.7 * amp, d=.3)
    if t < .3: sprite('star', 0, .3, 2.4 * (1 - t * 3.2) + .2, color=CORE, alpha=1 - t * 3.3, d=.4)
    burst_sparks(rng, 26, t, .3, 1.8, .9, size=(.3, .05), zlift=.3, ysq=.9)
    embers_rise(rng, 28, t, False, area=(.6, .4), h=2.0 * t + .4, size=.08)

eff('flame_pillar', (256, 256), {'default': A(12, 14, False, build_pillar)}, tz=1.4, ppu=50)

def meteor_head(rng, t, loop, scale=1.0):
    ph = TAU * t
    x0 = .72
    for i in range(6):
        L = (.95 + .2 * (i % 3)) * scale; wob = .06 * math.sin(ph + i)
        sprite('flame', x0 - L * .5 - .05, wob + (i - 2.5) * .03, .3 * scale * (1 - i * .05), L, color=(DEEP, FIRE, GOLD)[i % 3], alpha=.95, rot=math.pi / 2)
    for i in range(5):
        u = rng.random(); life = (t + u) % 1
        sprite('smoke', x0 - .3 - life * 1.0, rng.uniform(-.12, .12) + .06 * life, .3 + .3 * life, color=SMOKE, alpha=.55 * fade(life, .15, .5), d=-.3)
    sprite('halo', x0, 0, .95 * scale, color=FIRE, alpha=.75, d=-.1)
    sprite('disc', x0, 0, .34 * scale, color=hexc('2a1208'), alpha=1, d=0)
    for i in range(7):
        a = TAU * i / 7 + .4; sprite('glow', x0 + math.cos(a) * .1 * scale, math.sin(a) * .1 * scale, .12 * scale, color=GOLD, alpha=.9, d=.1)
    sprite('glow', x0 + .1, 0, .42 * scale, color=CORE, alpha=.9, d=.2)
    for i in range(10):
        u = rng.random(); life = (t + u) % 1
        sprite('spark', x0 - .35 - life * 1.0, rng.uniform(-.2, .2) + (life) * .1, .22, .035, color=GOLD if i % 2 else CORE, alpha=fade(life, .05, .5), rot=math.pi + rng.uniform(-.3, .3))

def build_meteor(f, n):
    meteor_head(random.Random(52), f / n, True)

eff('meteor', (128, 128), {'default': A(6, 14, True, build_meteor)}, ppu=50)

def build_meteor_impact(f, n):
    t = f / n; rng = random.Random(66); R = 1.5 * ss(t, 0, .45) + .2
    die = 1 - ss(t, .55, 1.0); amp = ss(t, 0, .15) * die
    ground('halo', 0, 0, 3.2 * (1 - .4 * t), 3.2 * (1 - .4 * t) * .82, color=FIRE, alpha=.7 * (1 - ss(t, .1, .8)))
    ground('disc_edge', 0, 0, .9 + .5 * t, (.9 + .5 * t) * .82, color=hexc('1a0d08'), alpha=.7 * (1 - ss(t, .6, 1.0)) * ss(t, 0, .1))
    ground('ring_thick', 0, 0, R * 2.1, R * 2.1 * .82, color=FIRE, alpha=.7 * (1 - ss(t, .2, .9)))
    ground('ring', 0, 0, R * 1.95, R * 1.95 * .82, color=CORE, alpha=.9 * (1 - ss(t, .1, .7)))
    for i in range(7):
        a = TAU * i / 7 + rng.uniform(-.3, .3); r = rng.uniform(.2, .8) * R
        sprite('smoke', math.cos(a) * r, math.sin(a) * r * .5 + .3 + t * 1.2 * rng.uniform(.6, 1.2), (.8 + .9 * t) * rng.uniform(.8, 1.2), color=SMOKE, alpha=.6 * ss(t, .1, .4) * (1 - ss(t, .6, 1.0)), d=-.6)
    for i in range(14):
        a = TAU * i / 14 + rng.uniform(-.15, .15); r = R * .65 * rng.uniform(.5, 1.0)
        h = (1.0 + rng.uniform(0, .6)) * amp
        sprite('flame', math.cos(a) * r, math.sin(a) * r * .8 + h * .38, h * .85, h, color=(FIRE, GOLD, DEEP)[i % 3], alpha=min(1, amp * 1.6), rot=-math.cos(a) * .3)
    for i in range(5):
        sprite('flame', rng.uniform(-.2, .2), .2 + 1.2 * amp * .5, .8 * amp + .1, 1.5 * amp + .1, color=CORE if i % 2 else GOLD, alpha=min(1, amp * 1.5), d=.1)
    if t < .35:
        sprite('glow', 0, .3, 2.6 * (1 - t * 2.6) + .3, color=CORE, alpha=1 - t * 2.8, d=.4)
        sprite('star', 0, .3, 3.2 * (1 - t * 2.6) + .3, color=WHITE, alpha=1 - t * 2.8, d=.5)
    burst_sparks(rng, 40, t, .3, 2.0, 1.1, size=(.4, .06), ysq=.8)
    embers_rise(rng, 14, t, False, area=(R * .8, R * .5), h=1.4 * t + .2, size=.08)

eff('meteor_impact', (256, 256), {'default': A(10, 16, False, build_meteor_impact)}, tz=.4, ppu=50)

def build_phoenix(f, n):
    t = f / n; ph = TAU * t; rng = random.Random(81)
    flap = math.sin(ph); cy = .15 + .06 * math.sin(ph * 2)
    sprite('halo', 0, cy + .3, 3.0, color=FIRE, alpha=.28, d=-.5)
    ground('halo', 0, -.9, 1.6, 1.0, color=FIRE, alpha=.18)
    for side in (-1, 1):
        for j in range(9):
            phi = math.radians(100 - 12 * j * .0 + (-18 + 10 * j) - 0) + flap * math.radians(26) * (.5 + j * .06)
            L = 1.15 + .12 * math.sin(j * .9) - j * .03; ang = math.radians(25 + j * 11) + flap * math.radians(30)
            dx = side * math.sin(ang); dy = math.cos(ang) * .8 - .1
            sx, sy = side * .14, cy + .28
            cx, cyy = sx + dx * L * .5, sy + dy * L * .5
            rot = math.atan2(dy, dx) - math.pi / 2
            sprite('flame', cx, cyy, .34 - j * .008, L, color=(FIRE, GOLD, DEEP)[j % 3], alpha=.95, rot=rot)
        sprite('glow', side * .5, cy + .45 + .2 * flap, .55, color=GOLD, alpha=.5, d=.1)
    for j in range(5):
        ang = math.radians(-20 + 10 * j - 20) + .12 * math.sin(ph + j)
        L = .9 + .1 * (j % 2)
        dx = math.sin(ang); dy = -math.cos(ang)
        sprite('flame', dx * L * .5, cy - .05 + dy * L * .5, .3, L, color=(FIRE, GOLD)[j % 2], alpha=.95, rot=math.atan2(dy, dx) - math.pi / 2)
    sprite('flame', 0, cy + .12, .55, 1.0, color=GOLD, alpha=1, rot=.05 * math.sin(ph), d=.1)
    sprite('flame', 0, cy + .1, .34, .72, color=CORE, alpha=1, d=.2)
    sprite('glow', 0, cy + .45, .45, color=CORE, alpha=1, d=.3)
    sprite('flame', 0, cy + .66, .2, .3, color=GOLD, alpha=1, rot=-.15, d=.3)
    sprite('glow', .04, cy + .5, .07, color=WHITE, alpha=1, d=.4)
    embers_rise(rng, 22, t, True, area=(.9, .2), h=1.0, size=.07, y0=cy - .3)

eff('phoenix', (256, 256), {'default': A(8, 12, True, build_phoenix)}, tz=.2)
