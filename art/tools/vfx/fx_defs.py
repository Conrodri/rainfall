"""Definition des effets VFX (voir vfx_lib). EFFECTS[nom] = {size:(w,h px finaux), anims:{anim:{n,fps,loop,build}}}."""
import math, random
from vfx_lib import *

TAU = math.tau
EFFECTS = {}

def eff(name, size, anims, **kw):
    EFFECTS[name] = dict(size=size, anims=anims, **kw)

def A(n, fps, loop, build):
    return dict(n=n, fps=fps, loop=loop, build=build)

def burst_sparks(rng, k, t, r0, speed, grav, col_a=GOLD, col_b=CORE, zlift=0.0, size=(.34, .06), tmax=1.0, ysq=.7):
    """etincelles balistiques (ecran). t in [0,1]."""
    for i in range(k):
        a = rng.uniform(0, TAU); v = speed * rng.uniform(.5, 1.0); up = rng.uniform(.2, 1.0)
        life = rng.uniform(.55, 1.0) * tmax
        if t > life: continue
        tt = t
        x = math.cos(a) * (r0 + v * tt); y = math.sin(a) * (r0 + v * tt) * ysq + up * v * .5 * tt - grav * tt * tt + zlift
        vx = math.cos(a) * v; vy = math.sin(a) * v * ysq + up * v * .5 - 2 * grav * tt
        sz = rng.uniform(size[0] * .6, size[0])
        sprite('spark', x, y, sz, size[1] * (sz / size[0]), color=col_a if i % 3 else col_b, alpha=1 - ss(t / life, .5, 1.0), rot=math.atan2(vy, vx))

# ---------------- 1. ember_shard_impact : 6 frames, 96 px ----------------
def build_impact(f, n):
    t = f / n; rng = random.Random(11)
    # onde au sol
    ground('ring', 0, 0, .35 + 1.15 * ss(t, 0, 1), alpha=(1 - t) ** 1.2 * .9, color=FIRE)
    # fumee (derriere)
    for i in range(3):
        a = rng.uniform(0, TAU); r = .1 + .35 * t
        sprite('smoke', math.cos(a) * r, .12 + math.sin(a) * r * .5 + t * .35, .35 + .35 * t, color=SMOKE, alpha=.55 * ss(t, .15, .4) * (1 - t) ** .8, d=-.3)
    # halo
    sprite('glow', 0, .12, .5 + .9 * (1 - (1 - t) ** 2), alpha=(1 - t) ** 1.3, color=FIRE, d=-.1)
    # langues de feu radiales
    for i in range(8):
        a = TAU * i / 8 + rng.uniform(-.2, .2); r = .12 + .45 * ss(t, 0, .8); h = (.35 + rng.uniform(0, .2)) * math.sin(math.pi * min(1, t * 1.15)) + .05
        sprite('flame', math.cos(a) * r, .1 + math.sin(a) * r * .55 + .06, h * .8, h * 1.1, color=FIRE if i % 2 else GOLD, alpha=1 - ss(t, .6, 1.0), rot=a - math.pi / 2 + (0 if math.sin(a) > 0 else 0) )
    burst_sparks(rng, 12, t, .1, 1.0, .5, size=(.3, .05))
    # coeur
    sprite('glow', 0, .12, .75 * (1 - t) ** 1.6 + .1, color=CORE, alpha=(1 - t) ** 1.2, d=.2)
    if t < .5: sprite('star', 0, .12, .9 * (1 - t * 2) + .1, color=CORE, alpha=1 - t * 2, d=.3)

eff('ember_shard_impact', (96, 96), {'default': A(6, 18, False, build_impact)}, ppu=52)
