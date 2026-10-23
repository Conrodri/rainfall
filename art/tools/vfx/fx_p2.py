"""Priorite 2 : statuts, foudre, telegraphes, morts, niveau, coffres, anneaux de pilier/charge."""
from fx_defs import *
from fx_p1 import embers_rise

def sway(ph, q, a=1.0): return math.sin(ph + q) * a

# ---------------- statuts sur monstre : 96 px, 8 frames, boucle ----------------
def build_burn(f, n):
    t = f / n; rng = random.Random(3); ph = TAU * t
    sprite('halo', 0, .02, 1.25, color=FIRE, alpha=.28 + .08 * math.sin(ph), d=-.3)
    for i in range(3):
        u = rng.random(); life = (t + u) % 1
        sprite('smoke', rng.uniform(-.2, .2) + math.sin(TAU * life + i) * .08, .25 + life * .5, .3 + .25 * life, color=SMOKE, alpha=.5 * fade(life, .25, .5), d=-.4)
    for i in range(8):
        a = TAU * i / 8 + .3; q = rng.uniform(0, TAU)
        x = math.cos(a) * .36; y = -.18 + math.sin(a) * .16
        h = .5 + .14 * math.sin(ph + q) + rng.uniform(0, .12)
        sprite('flame', x, y + h * .4, h * .62, h, color=FIRE if i % 2 else GOLD, alpha=.92, rot=-math.cos(a) * .25 + .12 * math.sin(ph + q))
    sprite('glow', 0, -.05, .45, color=CORE, alpha=.35 + .15 * math.sin(ph + 1), d=.2)
    embers_rise(rng, 9, t, True, area=(.35, .15), h=.85, size=.055, y0=-.05, sway=.07)

def build_poison(f, n):
    t = f / n; rng = random.Random(8); ph = TAU * t
    sprite('halo', 0, .02, 1.2, color=POIS2, alpha=.3 + .06 * math.sin(ph), d=-.3)
    for i in range(5):
        u = rng.random(); life = (t + u) % 1
        sprite('smoke', rng.uniform(-.3, .3) + math.sin(TAU * life + i) * .08, -.15 + life * .6, .32 + .3 * life, color=POIS2, alpha=.55 * fade(life, .25, .45), d=-.4)
    for i in range(10):
        u = rng.random(); life = (t + u) % 1; x0 = rng.uniform(-.35, .35)
        s = rng.uniform(.1, .2) * (.6 + .6 * life)
        sprite('bubble', x0 + math.sin(TAU * life * 1.0 + i) * .06, -.2 + life * .8, s, color=POIS if i % 2 else hexc('B4F08C'), alpha=fade(life, .1, .3), d=.2)
    for i in range(4):
        u = rng.random(); life = (t + u) % 1; x0 = rng.uniform(-.3, .3)
        sprite('drop', x0, .3 - life * .55, .08, .14, color=POIS, alpha=fade(life, .1, .25), d=.1)
    for i in range(6):
        a = TAU * i / 6 + .2; q = rng.uniform(0, TAU)
        sprite('glow', math.cos(a) * .3, -.12 + math.sin(a) * .13, .2 + .05 * math.sin(ph + q), color=POIS, alpha=.35 + .15 * math.sin(ph + q), d=.1)

def build_frost(f, n):
    t = f / n; rng = random.Random(13); ph = TAU * t
    sprite('halo', 0, .02, 1.25, color=FROST, alpha=.26 + .06 * math.sin(ph), d=-.3)
    for i in range(4):
        u = rng.random(); life = (t + u) % 1
        sprite('smoke', rng.uniform(-.3, .3) + math.sin(TAU * life + i) * .1, -.2 + life * .35, .4 + .2 * life, color=hexc('9FB6CC'), alpha=.45 * fade(life, .25, .5), d=-.4)
    for i in range(9):
        a = TAU * i / 9 + .15; q = rng.uniform(0, TAU)
        x = math.cos(a) * .4; y = -.08 + math.sin(a) * .2
        h = rng.uniform(.28, .45); w = h * .42
        sprite('shard', x, y + h * .42, w, h, color=FROST if i % 2 else hexc('C6EEFF'), alpha=.9 + .1 * math.sin(ph + q), rot=-math.cos(a) * .45 + rng.uniform(-.12, .12))
    for i in range(8):
        u = rng.random(); life = (t + u) % 1; x0 = rng.uniform(-.38, .38)
        sprite('star', x0 + math.sin(TAU * life + i) * .05, .55 - life * .7, .13 + .05 * math.sin(TAU * life * 2 + i), color=hexc('DFF6FF'), alpha=fade(life, .1, .2), rot=life * 3.0, d=.2)
    sprite('star', rng.uniform(-.2, .2), .1 + .12 * math.sin(ph), .22, color=WHITE, alpha=.5 + .5 * math.sin(ph * 2) ** 2, d=.3)

eff('status_burn', (96, 96), {'default': A(8, 10, True, build_burn)}, ppu=48)
eff('status_poison', (96, 96), {'default': A(8, 10, True, build_poison)}, ppu=58)
eff('status_frost', (96, 96), {'default': A(8, 10, True, build_frost)})

# ---------------- arc de foudre en chaine : 256x64, 4 frames ----------------
def jag(rng, x0, y0, x1, y1, segs, amp):
    pts = [(x0, y0)]
    for i in range(1, segs):
        u = i / segs; pts.append((x0 + (x1 - x0) * u + rng.uniform(-.06, .06), y0 + (y1 - y0) * u + rng.uniform(-amp, amp) * math.sin(math.pi * u) ** .5))
    pts.append((x1, y1)); return pts

def build_arc(f, n):
    rng = random.Random(100 + f * 7); X = 1.5
    main = jag(rng, -X, 0, X, 0, 14, .17)
    ribbon('solid', main, .26, BOLT2, .45, wfun=lambda u: .55 + .45 * math.sin(math.pi * u))
    ribbon('solid', main, .12, BOLT, .95, wfun=lambda u: .5 + .5 * math.sin(math.pi * u))
    ribbon('solid', main, .045, WHITE, 1.0, wfun=lambda u: .7 + .3 * math.sin(math.pi * u))
    for b in range(3):
        k = rng.randint(3, 10); bx, by = main[k]; dirx = rng.choice((-1, 1)) * rng.uniform(.25, .5); diry = rng.choice((-1, 1)) * rng.uniform(.2, .3)
        br = jag(rng, bx, by, bx + dirx, by + diry, 5, .06)
        ribbon('solid', br, .06, BOLT, .8, wfun=lambda u: 1 - u * .8)
    for sx in (-X, X):
        sprite('glow', sx, 0, .55, color=BOLT, alpha=.9); sprite('star', sx, 0, .6, color=WHITE, alpha=.8, rot=rng.uniform(0, 1), d=.1)
    for i in range(7):
        x = rng.uniform(-X, X); y = rng.uniform(-.2, .2)
        sprite('spark', x, y, rng.uniform(.14, .26), .035, color=BOLT, alpha=rng.uniform(.6, 1), rot=rng.uniform(0, TAU))

eff('lightning_arc', (256, 64), {'default': A(4, 20, True, build_arc)})

# ---------------- telegraphes rouges (remplissage 8 frames) ----------------
def build_tele_circle(f, n):
    p = (f + 1) / n; R = 1.8
    ground('disc', 0, 0, R * 2, R * 2 * .82, color=TELE, alpha=.18)
    ground('disc', 0, 0, R * 2 * p, R * 2 * p * .82, color=TELE, alpha=.42)
    ground('outline', 0, 0, R * 2 * p, R * 2 * p * .82, color=hexc('FF8A70'), alpha=.55 * (p < .999))
    ground('outline', 0, 0, R * 2, R * 2 * .82, color=hexc('FFC7B8'), alpha=.95)

def cone_edges(R, ang, rot, apex, alpha, color):
    ax, ay = apex
    for s in (-1, 1):
        a = rot + s * ang / 2
        ground('flat', ax + math.cos(a) * R / 2, ay + math.sin(a) * R / 2, R, .05, color=color, alpha=alpha, rot=a)
    segs = 14
    for i in range(segs):
        a0 = rot - ang / 2 + ang * i / segs; a1 = rot - ang / 2 + ang * (i + 1) / segs; am = (a0 + a1) / 2
        ground('flat', ax + math.cos(am) * R, ay + math.sin(am) * R, .05, R * ang / segs * 1.15, color=color, alpha=alpha, rot=am)

def build_tele_cone(f, n):
    p = (f + 1) / n; R = 3.5; ang = math.radians(60); ap = (-1.75, 0)
    fan('flat', ang, R, TELE, .18, x=ap[0], y=ap[1])
    fan('flat', ang, R, TELE, .42, x=ap[0], y=ap[1], scale=p)
    cone_edges(R, ang, 0, ap, .95, hexc('FFC7B8'))
    if p < .999:
        segs = 10
        for i in range(segs):
            a0 = -ang / 2 + ang * i / segs; a1 = -ang / 2 + ang * (i + 1) / segs; am = (a0 + a1) / 2
            ground('flat', ap[0] + math.cos(am) * R * p, ap[1] + math.sin(am) * R * p, .035, R * ang / segs * p * 1.15, color=hexc('FF8A70'), alpha=.6, rot=am)

eff('telegraph_circle', (256, 256), {'default': A(8, 8, False, build_tele_circle)})
eff('telegraph_cone', (256, 256), {'default': A(8, 8, False, build_tele_cone)})

# ---------------- mort de monstre par tier : 160 px, 6 frames ----------------
TIERS = {
    'tier1': dict(c=hexc('A9BC93'), c2=hexc('6F8560'), sparks=0, flames=0, smoke=3, ring=.6, size=.8),
    'tier2': dict(c=hexc('C09AE0'), c2=hexc('7C5A96'), sparks=6, flames=0, smoke=5, ring=.8, size=1.0),
    'tier3': dict(c=hexc('FF9A3C'), c2=hexc('B03A1C'), sparks=12, flames=5, smoke=6, ring=1.0, size=1.25),
    'tier4': dict(c=hexc('FF5A3C'), c2=hexc('8A1C18'), sparks=20, flames=8, smoke=8, ring=1.25, size=1.5),
}
def make_death(key):
    P = TIERS[key]
    def build(f, n):
        t = f / n * .95 + .02; rng = random.Random(40 + sum(map(ord, key))); S_ = P['size'] * 1.3
        if t < .4:
            sprite('glow', 0, .15, (1.6 - t * 2.4) * S_ * .9, color=P['c'], alpha=1 - t * 2.3, d=.3)
        ground('ring', 0, 0, (.4 + P['ring'] * 2.0 * ss(t, 0, 1)) * 1.0, (.4 + P['ring'] * 2.0 * ss(t, 0, 1)) * .82, color=P['c'], alpha=(1 - t) * .7)
        for i in range(P['smoke']):
            a = TAU * i / P['smoke'] + rng.uniform(-.3, .3); r = .1 + .55 * S_ * ss(t, 0, .7)
            sprite('smoke', math.cos(a) * r, .1 + math.sin(a) * r * .5 + t * .4, (.35 + .4 * t) * S_, color=P['c2'], alpha=.55 * (1 - ss(t, .5, 1.0)) * ss(t, 0, .2), d=-.3)
        for i in range(P['flames']):
            a = TAU * i / P['flames'] + rng.uniform(-.3, .3); r = .15 + .5 * ss(t, 0, .6) * S_
            h = (.35 + rng.uniform(0, .25)) * S_ * math.sin(math.pi * min(1, t * 1.1))
            sprite('flame', math.cos(a) * r, math.sin(a) * r * .6 + h * .4, h * .7, h, color=P['c'] if i % 2 else FIRE, alpha=1 - ss(t, .55, 1.0))
        burst_sparks(rng, P['sparks'] + 8, t, .15, .9 * S_, .6, col_a=P['c'], col_b=CORE, size=(.22, .04), ysq=.6)
        # esprit/ame qui s'echappe (volutes ascendantes)
        for i in range(3 + P['sparks'] // 6):
            x = rng.uniform(-.25, .25) * S_; life = ss(t, .1, 1.0)
            sprite('glow', x + math.sin(t * 6 + i) * .05, .1 + life * (.6 + .5 * rng.random()) * S_, .12 + .06 * rng.random(), color=P['c'], alpha=(1 - ss(t, .5, 1.0)), d=.2)
    return build

eff('monster_death', (160, 160), {k: A(6, 14, False, make_death(k)) for k in TIERS}, ppu=46, tz=.6)

# ---------------- montee de niveau : 192 px, 12 frames ----------------
def build_levelup(f, n):
    t = f / n; rng = random.Random(61); amp = ss(t, 0, .25) * (1 - ss(t, .65, 1.0))
    ground('halo', 0, 0, 1.8 * amp + .2, 1.8 * amp * .82 + .1, color=GOLDC, alpha=.5 * amp)
    ground('ring_thick', 0, 0, .5 + 1.9 * ss(t, 0, .8), (.5 + 1.9 * ss(t, 0, .8)) * .82, color=GOLDC, alpha=.8 * (1 - ss(t, .5, 1.0)))
    ground('ring', 0, 0, .35 + 2.2 * ss(t, .1, 1.0), (.35 + 2.2 * ss(t, .1, 1.0)) * .82, color=XPC, alpha=.8 * (1 - ss(t, .4, 1.0)))
    sprite('glow', 0, .9 * amp + .2, .8 * amp + .1, 2.4 * amp + .2, color=hexc('FFE9A8'), alpha=.75 * amp, d=-.1)
    sprite('glow', 0, .6 * amp + .2, .22 * amp + .05, 2.0 * amp + .1, color=WHITE, alpha=.7 * amp, d=0)
    if t < .35:
        sprite('glow', 0, .3, 1.6 * (1 - t * 2.5) + .3, color=WHITE, alpha=1 - t * 2.8, d=.3)
        sprite('star', 0, .3, 2.2 * (1 - t * 2.5) + .2, color=WHITE, alpha=1 - t * 2.8, d=.4)
    for i in range(18):
        a = rng.uniform(0, TAU); r = rng.uniform(.2, 1.0) * (.4 + t); u = rng.uniform(0, .4)
        tt = max(0, t - u); x = math.cos(a) * r * .7; y = .1 + math.sin(a) * r * .3 + tt * rng.uniform(1.2, 2.4)
        sprite('star', x, y, rng.uniform(.14, .3) * (1 - tt * .5), color=GOLDC if i % 2 else XPC, alpha=(1 - ss(t, .5 + u * .5, 1.0)) * (t > u) * (.6 + .4 * math.sin(t * 20 + i) ** 2), rot=rng.uniform(0, 1) + t, d=.3)

eff('level_up', (192, 192), {'default': A(12, 14, False, build_levelup)}, ppu=52, tz=1.3)

# ---------------- ouverture de coffre par qualite : 128 px, 10 frames ----------------
QUAL = {'common': (WHITE, 7, 0), 'uncommon': (hexc('6FE08A'), 11, 0), 'rare': (hexc('B06CFF'), 15, 1), 'legendary': (GOLDC, 22, 2)}
def make_chest(key):
    col, k, tier = QUAL[key]
    def build(f, n):
        t = f / n; rng = random.Random(90 + k); amp = ss(t, 0, .2) * (1 - ss(t, .55, 1.0))
        ground('halo', 0, -.05, 1.2 * amp + .2, .9 * amp + .1, color=col, alpha=.5 * amp)
        ground('ring', 0, -.05, .4 + 1.4 * ss(t, 0, .9), (.4 + 1.4 * ss(t, 0, .9)) * .82, color=col, alpha=.7 * (1 - ss(t, .3, 1.0)))
        sprite('halo', 0, .35, 1.3 * amp + .15, color=col, alpha=.8 * amp, d=-.1)
        nr = 8 + tier * 4
        for i in range(nr):
            a = TAU * i / nr + rng.uniform(-.1, .1) + t * .4 * (tier > 0); L = (.4 + .35 * rng.random() + tier * .12) * ss(t, 0, .35)
            sprite('spark', math.cos(a) * L * .5, .35 + math.sin(a) * L * .5, L, .1 + .04 * tier, color=col, alpha=amp * .95, rot=a + math.pi, d=.1)
        if tier >= 2:
            sprite('solid', 0, .35 + .6 * amp, 1.5 * amp + .1, .14, color=WHITE, alpha=.7 * amp, rot=math.pi / 2)
            sprite('glow', 0, .35 + .5 * amp, .5 * amp + .1, 1.3 * amp + .2, color=col, alpha=.5 * amp, d=-.1)
        if t < .4:
            sprite('glow', 0, .35, 1.0 * (1 - t * 2.4) + .2, color=WHITE, alpha=1 - t * 2.4, d=.3)
            sprite('star', 0, .35, (1.4 + tier * .3) * (1 - t * 2.4) + .2, color=WHITE, alpha=1 - t * 2.4, d=.4)
        for i in range(k):
            a = rng.uniform(0, TAU); u = rng.uniform(0, .35); tt = max(0, t - u)
            sprite('star', math.cos(a) * rng.uniform(.1, .5) * (.4 + tt), .3 + tt * rng.uniform(.8, 1.7), rng.uniform(.1, .2) * (1 - tt * .6), color=col if i % 3 else WHITE, alpha=(t > u) * (1 - ss(t, .6 + u * .3, 1.0)) * (.6 + .4 * math.sin(t * 22 + i * 2) ** 2), rot=i + t, d=.3)
    return build

eff('chest_open', (128, 128), {k: A(10, 16, False, make_chest(k)) for k in QUAL}, ppu=48, tz=1.1)

# ---------------- anneau de zone de pilier : 512 px, boucle 8 ; anneau de charge : 256 px, boucle 8 ----------------
def zig(rng, x0, y0, x1, y1, segs, amp):
    return jag(rng, x0, y0, x1, y1, segs, amp)

def build_pillar_ring(f, n):
    t = f / n; ph = TAU * t; rng = random.Random(17); R = 3.45
    ground('disc_edge', 0, 0, R * 2, R * 2 * .82, color=BOLT2, alpha=.06)
    ground('ring_thick', 0, 0, R * 2.06, R * 2.06 * .82, color=BOLT2, alpha=.22 + .05 * math.sin(ph))
    ground('ring_thin', 0, 0, R * 2.0, R * 2.0 * .82, color=BOLT, alpha=.95)
    ground('ring_thin', 0, 0, R * 2.0, R * 2.0 * .82, color=BOLT2, alpha=.8)
    ground('outline', 0, 0, R * 2.0, R * 2.0 * .82, color=WHITE, alpha=.9)
    for i in range(30):
        a = TAU * i / 30 + ph * 1.0 * (1 if i % 2 else 1); jit = .06 * math.sin(ph * 3 + i)
        x = math.cos(a) * R; y = math.sin(a) * R * .82
        sprite('glow', x, y + .06, .2 + .1 * math.sin(ph * 2 + i * 1.7) ** 2, color=BOLT if i % 3 else WHITE, alpha=.5 + .5 * math.sin(ph * 2 + i) ** 2, d=.1)
    rr = random.Random(200 + f % 4)
    for i in range(11):
        a = rr.uniform(0, TAU); x = math.cos(a) * R; y = math.sin(a) * R * .82; h = rr.uniform(.35, .75)
        pts = zig(rr, x, y, x + rr.uniform(-.25, .25), y + h, 6, .09)
        ribbon('solid', pts, .1, BOLT2, .5); ribbon('solid', pts, .04, BOLT, .95); ribbon('solid', pts, .018, WHITE, 1.0)
    for i in range(24):
        u = rng.random(); life = (t + u) % 1; a = rng.uniform(0, TAU); x = math.cos(a) * R; y = math.sin(a) * R * .82
        sprite('spark', x + .1 * math.cos(a) * life, y + life * .9, .2, .03, color=BOLT, alpha=fade(life, .1, .3), rot=math.pi / 2)

eff('pillar_zone_ring', (512, 512), {'default': A(8, 12, True, build_pillar_ring)})

def build_charge_ring(f, n):
    t = f / n; ph = TAU * t; rng = random.Random(23); R = 1.6
    ground('halo', 0, 0, R * 2.1, R * 2.1 * .82, color=BOLT2, alpha=.18)
    ground('ring_thick', 0, 0, R * 2.05, R * 2.05 * .82, color=BOLT2, alpha=.2)
    ground('ring_thin', 0, 0, R * 2.0, R * 2.0 * .82, color=BOLT, alpha=.95)
    ground('outline', 0, 0, R * 2.0, R * 2.0 * .82, color=WHITE, alpha=.85)
    for i in range(16):
        a = TAU * i / 16; w = .5 + .5 * math.sin(ph * 1.0 - a * 1.0)
        sprite('glow', math.cos(a) * R, math.sin(a) * R * .82 + .05, .24, color=BOLT, alpha=.25 + .75 * w ** 3, d=.1)
        sprite('star', math.cos(a) * R, math.sin(a) * R * .82 + .05, .2 + .18 * w ** 3, color=WHITE, alpha=w ** 4, d=.2)
    for i in range(6):
        a = TAU * i / 6 + ph; x = math.cos(a) * R; y = math.sin(a) * R * .82
        rr = random.Random(300 + f * 6 + i); pts = jag(rr, x, y, x, y + .35, 5, .06)
        ribbon('solid', pts, .05, BOLT, .9)

eff('charge_ring', (256, 256), {'default': A(8, 12, True, build_charge_ring)})
