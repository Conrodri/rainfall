"""Priorite 3 : particules reutilisables (4 variantes par type). 32 px (spark, ember, fire_drop, frost_flake, poison_bubble), 64 px (smoke, arc_fragment)."""
from fx_defs import *
from fx_p2 import jag

def p_spark(f, n):
    rng = random.Random(500 + f)
    L = [.42, .36, .46, .3][f]; W = [.09, .12, .08, .14][f]
    sprite('spark', -.02, 0, L, W, color=[GOLD, FIRE, CORE, GOLD][f], alpha=1, rot=[0, .12, -.1, 0][f])
    if f >= 2: sprite('star', L * .22, 0, .3, color=CORE, alpha=.8, rot=0.4, d=.1)
    if f == 1: sprite('glow', L * .25, 0, .2, color=FIRE, alpha=.6, d=-.1)

def p_ember(f, n):
    s = [.3, .24, .34, .2][f]
    sprite('glow', 0, 0, s * 1.6, color=[FIRE, DEEP, FIRE, GOLD][f], alpha=.55, d=-.1)
    sprite('glow', 0, 0, s, color=[GOLD, FIRE, GOLD, CORE][f], alpha=1)
    sprite('glow', .01 * f, .01, s * .45, color=CORE, alpha=1, d=.1)
    if f in (1, 3): sprite('spark', -.12, -.05, .2, .045, color=FIRE, alpha=.8, rot=3.6, d=.1)

def p_fire_drop(f, n):
    if f < 2:
        sprite('glow', 0, 0, .42, color=FIRE, alpha=.45, d=-.1)
        sprite('drop', 0, 0, [.2, .26][f], [.36, .42][f], color=[FIRE, GOLD][f], alpha=1)
        sprite('glow', 0, -.06, .12, color=CORE, alpha=.9, d=.1)
    else:
        sprite('flame', 0, .02, [.22, .3][f - 2], [.4, .44][f - 2], color=[FIRE, GOLD][f - 2], alpha=1, rot=[.12, -.1][f - 2])
        sprite('glow', 0, -.1, .16, color=CORE, alpha=.8, d=.1)

def p_frost_flake(f, n):
    if f < 2:
        sprite('star', 0, 0, [.5, .42][f], color=FROST, alpha=1, rot=0)
        sprite('star', 0, 0, [.34, .3][f], color=hexc('DFF6FF'), alpha=.9, rot=math.pi / 4)
    else:
        sprite('shard', 0, 0, [.2, .24][f - 2], [.44, .4][f - 2], color=[FROST, hexc('C6EEFF')][f - 2], alpha=1, rot=[.3, -.35][f - 2])
        sprite('glow', 0, 0, .3, color=FROST, alpha=.3, d=-.1)

def p_poison_bubble(f, n):
    s = [.36, .3, .4, .26][f]
    sprite('bubble', 0, 0, s, color=[POIS, hexc('B4F08C'), POIS, POIS2][f], alpha=1)
    sprite('bubble', s * .45, -s * .35, s * .32, color=POIS, alpha=.9, d=.1)
    if f >= 2: sprite('bubble', -s * .4, s * .38, s * .22, color=hexc('B4F08C'), alpha=.9, d=.1)

eff('particles_s', (32, 32), {'spark': A(4, 1, False, p_spark), 'ember': A(4, 1, False, p_ember), 'fire_drop': A(4, 1, False, p_fire_drop),
                              'frost_flake': A(4, 1, False, p_frost_flake), 'poison_bubble': A(4, 1, False, p_poison_bubble)}, samples=32)

def p_smoke(f, n):
    rng = random.Random(600 + f)
    for i in range(3):
        sprite('smoke', rng.uniform(-.12, .12), rng.uniform(-.1, .1), rng.uniform(.5, .75), color=hexc('3A4352') if i else hexc('2B3340'), alpha=rng.uniform(.55, .85), rot=rng.uniform(0, TAU))
    if f % 2:
        for i in range(2): sprite('glow', rng.uniform(-.15, .15), rng.uniform(-.1, .1), .1, color=FIRE, alpha=.8, d=.2)

def p_arc(f, n):
    rng = random.Random(700 + f)
    pts = jag(rng, -.4, rng.uniform(-.08, .08), .4, rng.uniform(-.12, .12), 6 + f, .12)
    ribbon('solid', pts, .2, BOLT2, .5); ribbon('solid', pts, .09, BOLT, 1.0); ribbon('solid', pts, .035, WHITE, 1.0)
    bx, by = pts[3]; br = jag(rng, bx, by, bx + rng.uniform(-.1, .2), by + rng.choice((-.25, .25)), 4, .05)
    ribbon('solid', br, .05, BOLT, .9)
    sprite('glow', pts[0][0], pts[0][1], .22, color=BOLT, alpha=.7); sprite('glow', pts[-1][0], pts[-1][1], .22, color=BOLT, alpha=.7)

eff('particles_l', (64, 64), {'smoke': A(4, 1, False, p_smoke), 'arc_fragment': A(4, 1, False, p_arc)}, samples=32)
