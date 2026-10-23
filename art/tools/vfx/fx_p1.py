"""Priorite 1 : nova, cendres, brasier."""
from fx_defs import *

def embers_rise(rng, k, t, loop, area=(1.0, .5), h=1.2, size=.07, y0=0.0, cols=(GOLD, FIRE, CORE), sway=.12):
    """braises montantes. Si loop, t=f/n et chaque braise a un decalage de phase (boucle parfaite)."""
    for i in range(k):
        u = rng.random(); x0 = rng.uniform(-area[0], area[0]); yy = rng.uniform(-area[1], area[1]); ph = rng.uniform(0, TAU)
        life = (t + u) % 1.0 if loop else t
        a = fade(life, .12, .4) if loop else 1 - ss(t, .5, 1)
        x = x0 + math.sin(TAU * life * 1.0 + ph) * sway; y = y0 + yy * .6 + life * h
        s = size * rng.uniform(.6, 1.3) * (1 - .5 * life)
        sprite('glow', x, y, s, s, color=cols[i % len(cols)], alpha=a, d=.2)

def flame_ring(rng, R, count, hmax, wmax, alpha, squash=.82, cols=(FIRE, GOLD), lean=.2, jit=.12, prof=1.0, y0=0.0, a0=0.0):
    for i in range(count):
        a = a0 + TAU * i / count + rng.uniform(-jit, jit)
        r = R * rng.uniform(.93, 1.07)
        x = math.cos(a) * r; y = math.sin(a) * r * squash + y0
        h = hmax * rng.uniform(.6, 1.15) * prof; w = wmax * rng.uniform(.8, 1.2)
        sprite('flame', x, y + h * .35, w, h, color=cols[i % len(cols)], alpha=alpha, rot=-math.cos(a) * lean + rng.uniform(-.15, .15))

# ---------------- ardent_nova : 14 frames, 512 px ----------------
def build_nova(f, n):
    t = f / n; rng = random.Random(5)
    R = .3 + 2.95 * (1 - (1 - min(1, t * 1.25)) ** 2.2) if t < .8 else 3.25 + .06 * (t - .8)
    life = 1 - ss(t, .3, .85)
    ground('disc_edge', 0, 0, R * 2.1, R * 2.1 * .82, color=DEEP, alpha=.35 * (1 - ss(t, .1, .95)))
    ground('halo', 0, 0, R * 2.6, R * 2.6 * .82, color=FIRE, alpha=.5 * (1 - ss(t, .05, .6)))
    for i in range(10):
        a = TAU * i / 10 + rng.uniform(-.2, .2); r = R * rng.uniform(.55, .95) * min(1, t * 2 + .2)
        sprite('smoke', math.cos(a) * r, math.sin(a) * r * .82 + .35 + t * .9 * rng.uniform(.6, 1.4), 1.0 + t * .8, color=SMOKE, alpha=.62 * ss(t, .12, .45) * (1 - ss(t, .6, 1.0)), d=-.6)
    ground('ring_thick', 0, 0, R * 2.15, R * 2.15 * .82, color=FIRE, alpha=min(1, life * 1.4) * .55)
    ground('ring', 0, 0, R * 2.05 * .93, R * 2.05 * .93 * .82, color=GOLD, alpha=life * .8)
    ground('ring_thin', 0, 0, max(.2, R * 2.15 * .72), max(.2, R * 2.15 * .72) * .82, color=CORE, alpha=life * .6 * (t < .7))
    env = math.sin(math.pi * min(1, t * 1.0)) ** .7 * (1 - ss(t, .55, 1.0))
    if env > .02:
        flame_ring(rng, R, 40, 1.45, .8, min(1, env * 1.6), prof=env, lean=.35)
        flame_ring(rng, R * .88, 28, 1.1, .65, min(1, env * 1.4), prof=env, cols=(GOLD, CORE), lean=.25, a0=.07)
    if t < .45:
        sprite('glow', 0, .25, 2.4 * (1 - t * 1.6) + .4, color=CORE, alpha=1 - t * 2, d=.3)
        sprite('star', 0, .25, 3.2 * (1 - t * 2.2) + .3, color=CORE, alpha=max(0, 1 - t * 2.4), d=.4)
    burst_sparks(rng, 70, t, R * .6, 3.4, 1.4, size=(.42, .06), tmax=1.0, ysq=.82)
    embers_rise(rng, 26, t, False, area=(R, R * .8), h=1.6 * t + .2, size=.09)

eff('ardent_nova', (512, 512), {'default': A(14, 20, False, build_nova)}, ppu=56)

# ---------------- ardent_ashes : 8 frames boucle, 384 px ----------------
def build_ashes(f, n):
    t = f / n; rng = random.Random(21); R = 2.55
    ph = TAU * t
    ground('disc_edge', 0, 0, R * 2.1, R * 2.1 * .82, color=hexc('1a0d08'), alpha=.62)
    ground('halo', 0, 0, R * 2.0, R * 2.0 * .82, color=DEEP, alpha=.35 + .08 * math.sin(ph))
    ground('ring', 0, 0, R * 2.0, R * 2.0 * .82, color=FIRE, alpha=.55 + .15 * math.sin(ph + 1))
    ground('ring_thin', 0, 0, R * 1.78, R * 1.78 * .82, color=DEEP, alpha=.5)
    for c in range(9):
        a = TAU * c / 9 + rng.uniform(-.2, .2); r = rng.uniform(.3, 1.0) * R * .7
        x, y = math.cos(a) * r, math.sin(a) * r * .82; ang = rng.uniform(0, TAU)
        for s in range(4):
            L = rng.uniform(.25, .55); pul = .55 + .45 * math.sin(ph + c * 1.3 + s)
            ground('solid', x, y, L, .075, color=GOLD if s % 2 else FIRE, alpha=pul, rot=ang)
            x += math.cos(ang) * L * .9; y += math.sin(ang) * L * .9; ang += rng.uniform(-.8, .8)
    for i in range(46):
        a = rng.uniform(0, TAU); r = R * math.sqrt(rng.uniform(0, .85)); q = rng.uniform(0, TAU)
        s = rng.uniform(.06, .17)
        ground('halo', math.cos(a) * r, math.sin(a) * r * .82, s * 1.6, s, color=FIRE if i % 3 else GOLD, alpha=.35 + .65 * (.5 + .5 * math.sin(ph + q)))
    for i in range(16):
        a = TAU * i / 16 + rng.uniform(-.2, .2); r = R * rng.uniform(.15, .88); q = rng.uniform(0, TAU)
        hh = .28 + .2 * math.sin(ph + q) ** 2 + rng.uniform(0, .12)
        sprite('flame', math.cos(a) * r, math.sin(a) * r * .82 + hh * .3, hh * .55, hh, color=FIRE if i % 2 else GOLD, alpha=.75 + .25 * math.sin(ph + q), rot=.15 * math.sin(ph + q))
    for i in range(7):
        u = rng.random(); x0 = rng.uniform(-R * .7, R * .7); y0 = rng.uniform(-R * .5, R * .5); life = (t + u) % 1
        sprite('smoke', x0 + math.sin(TAU * life + i) * .12, y0 + .15 + life * 1.1, .55 + life * .6, color=SMOKE, alpha=.5 * fade(life, .2, .5), d=-.4)
    embers_rise(rng, 34, t, True, area=(R * .8, R * .7), h=1.3, size=.075, y0=.05)

eff('ardent_ashes', (384, 384), {'default': A(8, 10, True, build_ashes)})

# ---------------- ardent_brasier : 18 frames, 640 px ----------------
def build_brasier(f, n):
    t = f / n; rng = random.Random(77)
    grow = ss(t, 0, .3); die = 1 - ss(t, .78, 1.0)
    R = 3.3 * (.25 + .75 * (1 - (1 - min(1, t * 2.2)) ** 2)) * (1 + .03 * math.sin(t * 20))
    amp = grow * die
    ph = t * TAU * 3
    ground('disc_edge', 0, 0, R * 2.2, R * 2.2 * .82, color=DEEP, alpha=.5 * die)
    ground('halo', 0, 0, R * 2.8, R * 2.8 * .82, color=FIRE, alpha=.55 * die)
    ground('ring_thick', 0, 0, R * 2.1, R * 2.1 * .82, color=FIRE, alpha=min(1, amp * 1.2) * .9)
    ground('ring', 0, 0, R * 1.7, R * 1.7 * .82, color=GOLD, alpha=amp * .7)
    for i in range(14):
        a = rng.uniform(0, TAU); r = rng.uniform(.2, .9) * R; u = rng.random()
        yy = 1.0 + 2.2 * ss(t, .1, 1.0) * (.5 + u)
        sprite('smoke', math.cos(a) * r * .7, math.sin(a) * r * .5 + yy, 1.1 + .9 * t, color=SMOKE, alpha=.55 * ss(t, .1, .35) * die * (.6 + .4 * u), d=-1.0)
    for k, (rf, hm, wm, cols) in enumerate(((1.0, 2.0, .8, (FIRE, DEEP)), (.78, 1.8, .7, (FIRE, GOLD)), (.55, 1.6, .6, (GOLD, CORE)))):
        flame_ring(rng, R * rf, 26 - k * 4, hm * amp, wm * 1.5, min(1, amp * 1.5), prof=1.0, cols=cols, lean=.4, a0=k * .1 + t * (.4 if k % 2 else -.4))
    ch = 3.4 * amp + .2
    for i in range(9):
        a = TAU * i / 9 + ph * .3
        sprite('flame', math.cos(a) * .35 * amp, .15 + math.sin(a) * .2 + ch * .5, .9 * amp + .1, ch, color=GOLD if i % 2 else FIRE, alpha=min(1, amp * 1.4), rot=math.sin(a + ph) * .1)
    sprite('flame', 0, ch * .5, .8 * amp + .1, ch * .9, color=CORE, alpha=min(1, amp * 1.4), d=.2)
    sprite('glow', 0, 1.0, 3.0 * amp + .3, color=CORE, alpha=.8 * amp, d=.3)
    if t < .35:
        sprite('glow', 0, .4, 5.0 * (1 - t * 2.4) + .5, color=CORE, alpha=1 - t * 2.7, d=.5)
        sprite('star', 0, .5, 6.0 * (1 - t * 2.6) + .4, color=CORE, alpha=max(0, 1 - t * 2.9), d=.6)
    for i in range(80):
        u = rng.random(); a0 = rng.uniform(0, TAU); rad = rng.uniform(.3, 1.0) * R * .95; sp = rng.uniform(.8, 1.6)
        a = a0 + t * TAU * sp; hh = (u * 3.0 * amp + t * .6) % 3.0
        s = rng.uniform(.06, .14)
        sprite('glow', math.cos(a) * rad, math.sin(a) * rad * .82 + hh, s, s, color=(GOLD, FIRE, CORE)[i % 3], alpha=amp * (1 - hh / 4.0), d=.3)
    burst_sparks(rng, 60, t, R * .5, 3.0, 1.0, size=(.4, .06), tmax=1.0, ysq=.82, zlift=.3)

eff('ardent_brasier', (640, 640), {'default': A(18, 16, False, build_brasier)}, tz=1.9, ppu=54)
