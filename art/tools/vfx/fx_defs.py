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

# ---------------- Esquives ----------------
def build_dodge_out(f, n):
    t = f / n; rng = random.Random(140)
    # Silhouette qui se disperse en braises.
    if t < .58:
        q = t / .58
        sprite('glow', 0, .1, .72 * (1-q) + .08, .95 * (1-q) + .08, color=FIRE, alpha=1-q, d=.1)
        for i in range(9):
            a = TAU * i / 9; r = .12 + .32*q
            sprite('flame', math.cos(a)*r, .08 + math.sin(a)*r*.55, .20*(1-q)+.04, .3*(1-q)+.04, color=GOLD if i%2 else FIRE, alpha=1-q, rot=a)
    burst_sparks(rng, 18, t, .12, 1.2, .32, size=(.22,.045), tmax=.92)

def build_dodge_in(f, n):
    t = f / n; rng = random.Random(141)
    # Anneau de braises qui converge au sol.
    r = .18 + 1.0 * (1-t)
    ground('ring', 0, 0, r, alpha=.78*(1-t)+.06, color=FIRE)
    for i in range(10):
        a = TAU*i/10 + .12*math.sin(t*TAU)
        rr = r*(.55 + .08*math.sin(i*7+t*5))
        sprite('flame', math.cos(a)*rr, .05+math.sin(a)*rr*.48, .12+.05*(1-t), .2+.08*(1-t), color=GOLD if i%2 else FIRE, alpha=.35+.55*t, rot=a-math.pi/2)
    if t > .5: sprite('glow', 0, .08, .25+(.6*(t-.5)), color=CORE, alpha=(t-.5)*1.5, d=.2)

def build_dodge_splash(f, n):
    t = f / n; rng = random.Random(142)
    # Gerbe cyan qui retombe et s'étale en film au sol.
    ground('ring', 0, -.05, .42 + .8*t, h=.18+.18*t, color=XPC, alpha=.36*(1-t)+.16)
    for i in range(13):
        a = TAU*i/13; reach=.18+.58*t
        x=math.cos(a)*reach; y=.05+math.sin(a)*reach*.55 + .28*(1-t)
        sprite('spark', x, y, .085, .22*(1-t)+.035, color=XPC, alpha=.9*(1-t)+.08, rot=-a)
    sprite('glow', 0, .08, .34+.3*t, .16+.1*t, color=XPC, alpha=.45*(1-t)+.08)

def build_slide_wake(f, n):
    # Ruban d'eau plat, avec profil transversal doux et bords périodiques.
    sprite('glow', 0, .075, .98, .44, color=(.122, .565, .68, 1), alpha=.98)
    sprite('glow', 0, .075, .98, .30, color=(.22, .72, .82, 1), alpha=.96)
    # Filets fins, sinusoïdaux et raccordés entre les deux bords.
    for phase, y, width in ((0.0, -.025, .010), (2.2, -.10, .007), (4.0, -.055, .006)):
        pts = []
        for i in range(33):
            x = -.98 + 1.96 * i / 32
            yy = y + .022 * math.sin((x + 1.0) * math.pi + phase) + .006 * math.sin((x + 1.0) * 2 * math.pi)
            pts.append((x, yy))
        ribbon('spark', pts, width, color=(1, 1, 1, 1), alpha=.98)

eff('dodge_blink', (128, 128), {'out': A(6, 18, False, build_dodge_out), 'in': A(6, 18, False, build_dodge_in)}, ppu=64, samples=16)
eff('dodge_slide', (128, 96), {'splash': A(6, 18, False, build_dodge_splash), 'wake': A(1, 18, False, build_slide_wake)}, ppu=64, samples=16)
