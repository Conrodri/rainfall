"""UI, recompenses, coffres Rainfall (synthese procedurale).
uv run --with numpy --with scipy python art/tools/audio/gen_ui.py [--seed 0] [--only pickup_coin]
Sorties : game/assets/audio/ui/<id>_NN.ogg
"""
import argparse
import json
from pathlib import Path
import numpy as np
import audio_common as ac
import synth_lib as sl

SR = ac.SR
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game' / 'assets' / 'audio' / 'ui'
M = sl.mtof


def trim_tail(x, floor_db=-52, pad=.12):
    """Coupe le silence de queue (reverb) sous floor_db relatif a la crete, fondu final doux."""
    m = np.abs(x).max(1)
    w = int(.01 * SR)
    env = np.array([m[i:i + w].max() for i in range(0, len(m), w)])
    idx = np.where(env > m.max() * 10 ** (floor_db / 20))[0]
    end = min(len(x), int((idx[-1] + 1) * w + pad * SR))
    y = x[:end].copy()
    k = min(len(y) // 2, int(.08 * SR))
    y[-k:] *= np.linspace(1, 0, k)[:, None] ** 1.5
    return y


def mix(parts, total):
    """parts : [(start_s, signal(mono|stereo), gain, pan)] -> stereo (n,2)."""
    out = np.zeros((int(total * SR), 2))
    for st, x, g, pan in parts:
        sl.put(out, int(st * SR), x if x.ndim == 2 else x, g, pan)
    return out


def wet(x, rng, rt60=1.2, amount=.3, bright=.5, tail=None):
    rev = sl.Reverb(rng, rt60=rt60, brightness=bright)
    w = rev.linear(x, tail=tail if tail is not None else int(rt60 * .9 * SR))
    full = np.zeros_like(w)
    full[:len(x)] += x
    return full + w * amount


def glass(f, dur, rng, tau=.6, vel=.8):
    """Note cristalline : partiels inharmoniques de verre."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for r, a, d in ((1, 1, 1), (2.32, .45, .7), (4.25, .3, .5), (6.63, .18, .35), (9.38, .1, .25)):
        if f * r < 14000:
            x += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6)) * np.exp(-t / (tau * d))
    x += sl.hp(rng.normal(size=n), 6000, 1) * np.exp(-t / .004) * .25
    return x * vel * np.minimum(1, t / .0008) * .5


def coin(rng, v):
    f = M(88 + [0, 1, -1, 2][v % 4] * .6 + rng.uniform(-.25, .25))
    n = int(.36 * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / .1)
    x += .5 * np.sin(2 * np.pi * f * 2.0 * t) * np.exp(-t / .09)
    x += .22 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t / .05) + .12 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / .03)
    x += sl.hp(rng.normal(size=n), 5000, 1) * np.exp(-t / .002) * .18
    x *= np.minimum(1, t / .0007)
    st = np.column_stack((x, np.roll(x, 14)))
    return sl.finish_oneshot(wet(st, rng, .5, .12, .8, tail=int(.1 * SR)), -20, -2.0, 1, 40)


def xp(rng, v):
    n = int(.34 * SR)
    t = np.arange(n) / SR
    f0 = M(79 + v * 1.0 + rng.uniform(-.2, .2))
    f = f0 * (1 + .5 * (1 - np.exp(-t / .04)))
    ph = np.cumsum(f) / SR
    x = np.sin(2 * np.pi * ph) * np.exp(-t / .1) + .35 * np.sin(4 * np.pi * ph) * np.exp(-t / .06)
    x += .15 * sl.bp(rng.normal(size=n), 2500, 8000, 1) * np.exp(-t / .02)
    x *= np.minimum(1, t / .002)
    st = sl.pan(x, rng.uniform(-.15, .15))
    return sl.finish_oneshot(wet(st, rng, .6, .18, .6), -21, -2.0, 1, 20)


def ruby(rng, v):
    base = M(84 + [0, 3, 5][v % 3])
    parts = []
    for i, r in enumerate((1, 1.5, 2.0, 3.0)):
        parts.append((i * .045, glass(base * r, 1.4, rng, tau=.55 + .1 * i, vel=.8 - .1 * i), .6, rng.uniform(-.5, .5)))
    parts.append((0, glass(base * .5, 1.5, rng, tau=.9, vel=.5), .4, 0))
    x = mix(parts, 1.6)
    # etincelles aleatoires dans la queue
    for _ in range(9):
        sp = glass(base * rng.choice([2, 3, 4, 5]) * rng.uniform(.98, 1.02), .35, rng, tau=.12, vel=.35)
        sl.put(x, int(rng.uniform(.05, .9) * SR), sp, .35, rng.uniform(-.8, .8))
    return sl.finish_oneshot(wet(x, rng, 1.8, .35, .7), -20, -2.0, 1, 30)


def click(rng, v):
    n = int(.07 * SR)
    t = np.arange(n) / SR
    f = M(96 + [0, 2, -2, 1][v % 4])
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / .006) * .8 + sl.bp(rng.normal(size=n), 1500, 6000, 1) * np.exp(-t / .0015) * .6
    x += .4 * np.sin(2 * np.pi * f * 1.5 * t) * np.exp(-t / .01)
    return sl.finish_oneshot(sl.pan(x, 0), -22, -1.5, 0.5, 5)


def level_up(rng, v):
    root = 62 if v == 0 else 64  # D / E
    notes = [0, 4, 7, 12, 16, 19, 24]
    parts = []
    for i, iv in enumerate(notes):
        st = i * .1
        h = sl.harp(M(root + 12 + iv), 1.6, .8, rng)
        parts.append((st, h, .7, -.5 + i * .16))
        parts.append((st, glass(M(root + 24 + iv), 1.2, rng, tau=.45, vel=.4), .25, -.4 + i * .13))
    chord = sl.pad_chord([M(root + 12), M(root + 16), M(root + 19), M(root + 24)], .9, rel=1.4, att=.35, cut=3500, rng=rng)
    parts.append((.55, chord, .5, 0))
    parts.append((.65, sl.bell(M(root + 24), 3.0, rng=rng, tau=1.5), .3, .2))
    x = mix(parts, 3.2)
    return sl.finish_oneshot(wet(x, rng, 2.0, .38, .55), -19, -2.0, 1, 60)


def spell_ready(rng, v):
    f = M(81 + [0, 2, -2][v % 3])
    parts = [(0, glass(f, .8, rng, tau=.25, vel=.7), .7, -.2), (.09, glass(f * 1.5, .9, rng, tau=.3, vel=.7), .7, .2)]
    n = int(.25 * SR)
    t = np.arange(n) / SR
    sw = sl.bp(rng.normal(size=n), 2000, 9000, 1) * (t / t[-1]) ** 2 * np.exp(-((t - .2) / .08) ** 2) * .3
    parts.append((0, sw, .5, 0))
    x = mix(parts, 1.1)
    return sl.finish_oneshot(wet(x, rng, .9, .3, .7), -21, -2.0, 1, 30)


def dice(rng, v):
    parts = []
    t0 = 0.0
    gap = .085
    k = 0
    while t0 < .75:
        n = int(.05 * SR)
        t = np.arange(n) / SR
        f = rng.uniform(900, 2200)
        s = sl.resonator(rng.normal(size=n), f, 7) * np.exp(-t / .006) + np.sin(2 * np.pi * f * .5 * t) * np.exp(-t / .012) * .4
        s = s / (np.abs(s).max() + 1e-9)
        parts.append((t0, s, (.9 - k * .05) * rng.uniform(.6, 1), rng.uniform(-.5, .5)))
        t0 += gap * rng.uniform(.7, 1.2)
        gap = max(gap * .85, .03)
        k += 1
    n = int(.03 * SR)
    t = np.arange(n) / SR
    parts.append((t0 + .02, np.sin(2 * np.pi * 380 * t) * np.exp(-t / .01), .6, 0))
    x = mix(parts, 1.2)
    return sl.finish_oneshot(wet(x, rng, .5, .2, .4), -20, -2.0, 1, 30)


def item_pick(rng, v):
    base = 69 + [0, 2, -2][v % 3]
    parts = [(0, sl.harp(M(base), 1.2, .8, rng), .8, -.2), (.1, sl.harp(M(base + 7), 1.4, .85, rng), .8, .2),
             (.1, glass(M(base + 19), .9, rng, tau=.3, vel=.4), .3, .3), (.2, sl.pad_chord([M(base + 7), M(base + 12)], .3, rel=.7, att=.1, cut=3000, rng=rng), .35, 0)]
    x = mix(parts, 1.6)
    return sl.finish_oneshot(wet(x, rng, 1.2, .3, .5), -20, -2.0, 1, 40)


def chest_lock(rng, v):
    parts = []
    def clack(f, dur, g):
        n = int(dur * SR)
        t = np.arange(n) / SR
        s = sl.bp(rng.normal(size=n), 1800, 7000, 1) * np.exp(-t / .004) * .8
        s += sum(a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6)) * np.exp(-t / (.05 / r)) for r, a in ((1, 1), (2.7, .5), (5.2, .3)))
        return s * g
    parts.append((0, clack(rng.uniform(900, 1300), .25, .5), .8, -.1))
    parts.append((.075, clack(rng.uniform(1500, 2200), .22, .55), .7, .1))
    parts.append((.2, clack(rng.uniform(380, 520), .4, .8) * 1.0, .9, 0))
    n = int(.4 * SR)
    t = np.arange(n) / SR
    parts.append((.2, np.sin(2 * np.pi * 70 * t) * np.exp(-t / .1) * .8, .8, 0))
    x = mix(parts, .8)
    return sl.finish_oneshot(wet(x, rng, .5, .18, .4), -19, -2.0, 1, 20)


def creak(rng, dur, f0, amp=.5):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + .6 * t / t[-1] + .08 * np.sin(2 * np.pi * 9 * t))
    ph = np.cumsum(f) / SR
    s = sum(np.sin(2 * np.pi * k * ph + rng.uniform(0, 6)) / k for k in range(1, 8))
    s *= (1 + .6 * np.sin(2 * np.pi * rng.uniform(30, 60) * t)) * np.abs(np.sin(np.pi * t / t[-1])) ** 1.2
    return sl.resonator(s, 800, 2) * amp * .5 + s * amp * .3


def chest_open(kind, rng, v):
    if kind == 'petit':
        parts = [(0, creak(rng, .35, 140, .5), .6, -.1), (.3, sl.harp(M(76), 1.2, .8, rng), .8, -.2), (.38, sl.harp(M(83), 1.2, .8, rng), .8, .2),
                 (.3, glass(M(88), .8, rng, tau=.3, vel=.5), .3, 0)]
        x = mix(parts, 1.6)
        return sl.finish_oneshot(wet(x, rng, 1.2, .3, .5), -19, -2.0, 1, 40)
    if kind == 'large':
        parts = [(0, creak(rng, .6, 95, .7), .7, 0)]
        n = int(.4 * SR)
        t = np.arange(n) / SR
        parts.append((.55, np.sin(2 * np.pi * 60 * t) * np.exp(-t / .15) + sl.bp(rng.normal(size=n), 150, 900, 1) * np.exp(-t / .05), .7, 0))
        for i, iv in enumerate((0, 4, 7, 12)):
            parts.append((.6 + i * .07, sl.harp(M(64 + iv), 1.8, .85, rng), .6, -.4 + i * .27))
        parts.append((.65, sl.pad_chord([M(52), M(59), M(64), M(67)], .8, rel=1.2, att=.2, cut=2500, rng=rng), .45, 0))
        parts.append((.7, sl.bell(M(88), 2.5, rng=rng, tau=1.2), .25, .3))
        x = mix(parts, 3.0)
        return sl.finish_oneshot(wet(x, rng, 1.6, .35, .5), -19, -2.0, 1, 50)
    if kind == 'legendaire':
        parts = [(0, creak(rng, .8, 80, .8), .7, 0)]
        n = int(.6 * SR)
        t = np.arange(n) / SR
        parts.append((.75, np.sin(2 * np.pi * 48 * t) * np.exp(-t / .3) * 1.0 + sl.bp(rng.normal(size=n), 120, 800, 1) * np.exp(-t / .07), .9, 0))
        parts.append((.7, sl.choir([M(50), M(57), M(62), M(66), M(69)], 1.3, rel=1.8, att=.5, rng=rng), .7, 0))
        for i, iv in enumerate((0, 4, 7, 12, 16, 19, 24, 28)):
            parts.append((.8 + i * .085, sl.harp(M(62 + iv), 2.0, .9, rng), .55, -.6 + i * .17))
            parts.append((.8 + i * .085, glass(M(86 + iv % 12), 1.0, rng, tau=.4, vel=.35), .25, .5 - i * .12))
        parts.append((.85, sl.bell(M(74), 4.0, rng=rng, tau=2.0), .35, 0))
        x = mix(parts, 4.2)
        return sl.finish_oneshot(wet(x, rng, 2.6, .42, .55), -18.5, -2.0, 1, 80)
    # boss : sombre et lourd
    parts = [(0, creak(rng, .9, 60, .9), .7, 0)]
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    parts.append((.8, np.sin(2 * np.pi * np.cumsum(46 * (1 + .8 * np.exp(-t / .08))) / SR) * np.exp(-t / .45) * 1.1, 1.0, 0))
    parts.append((.8, sl.taiko(1.0, rng, 46, 1.4), .8, 0))
    parts.append((.78, sl.brass(M(38), 1.6, .9, .25), .6, 0))
    parts.append((.85, sl.brass(M(45), 1.5, .9, .25), .5, -.3))
    parts.append((.9, sl.brass(M(50), 1.4, .9, .25), .45, .3))
    parts.append((.8, sl.pad_chord([M(38), M(45), M(50), M(53)], 1.4, rel=2.2, att=.3, cut=1500, rng=rng), .5, 0))
    parts.append((.8, sl.bell(M(50), 4.5, rng=rng, tau=2.4), .3, .1))
    x = mix(parts, 4.6)
    return sl.finish_oneshot(wet(x, rng, 2.8, .45, .35), -18.5, -2.0, 1, 90)


def reveal(rng, v):
    n = int(.9 * SR)
    swell = sl.noise_swell(.9, rng, 800, 9000) * .5
    parts = [(0, swell, .5, 0)]
    base = 74 + v * 2
    for i, iv in enumerate((0, 7, 12, 16, 19)):
        parts.append((.5 + i * .06, glass(M(base + 12 + iv), 1.2, rng, tau=.5, vel=.7 - i * .06), .6, -.5 + i * .25))
    parts.append((.55, sl.harp(M(base), 1.6, .9, rng), .7, 0))
    parts.append((.55, sl.pad_chord([M(base - 12), M(base - 5), M(base)], .6, rel=1.0, att=.1, cut=3000, rng=rng), .4, 0))
    x = mix(parts, 2.2)
    return sl.finish_oneshot(wet(x, rng, 1.7, .35, .65), -19.5, -2.0, 1, 60)


def leg_rise(rng, v):
    dur = 3.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    parts = []
    parts.append((0, sl.noise_swell(dur, rng, 200, 8000) * .8, .55, 0))
    notes = [50, 57, 62, 66, 69] if v == 0 else [50, 57, 62, 65, 69]
    parts.append((0, sl.choir([M(m) for m in notes], dur - .2, rel=.4, att=2.3, rng=rng), .6, 0))
    parts.append((0, sl.choir([M(m + 12) for m in notes[1:]], dur - .2, rel=.4, att=2.6, rng=rng), .35, 0))
    sub = np.sin(2 * np.pi * np.cumsum(M(26) * (1 + .5 * (t / dur))) / SR) * (t / dur) ** 2
    parts.append((0, sub, .6, 0))
    # tintements montants
    for i in range(10):
        st = 1.0 + i * .19
        parts.append((st, glass(M(81 + [0, 4, 7, 12, 16][i % 5] + (i // 5) * 0), .9, rng, tau=.4, vel=.2 + .06 * i), .3, rng.uniform(-.7, .7)))
    x = mix(parts, dur + .3)
    x = wet(x, rng, 2.2, .35, .5, tail=int(.8 * SR))
    x[: int(dur * SR)] *= (np.minimum(1, (np.arange(int(dur * SR)) / SR) / 0.4) ** .8)[:, None] * 0 + 1
    return sl.finish_oneshot(x[: int((dur + .8) * SR)], -19, -2.0, 5, 120)


def leg_impact(rng, v):
    n = int(1.5 * SR)
    t = np.arange(n) / SR
    parts = [(0, np.sin(2 * np.pi * np.cumsum(55 * (1 + 1.5 * np.exp(-t / .06))) / SR) * np.exp(-t / .5) * 1.1, 1.0, 0)]
    parts.append((0, sl.taiko(1.0, rng, 48, 1.3), .8, 0))
    parts.append((0, sl.hp(rng.normal(size=n), 3000, 1) * np.exp(-t / .03) * .5, .6, 0))
    parts.append((0, sl.cymbal(3.0, rng, .8), .7, 0))
    chord = [50, 57, 62, 66, 69, 74]
    parts.append((0, sl.choir([M(m) for m in chord], 1.0, rel=2.4, att=.04, rng=rng), .6, 0))
    for i, m in enumerate((62, 66, 69, 74, 78, 81)):
        parts.append((.02 * i, sl.harp(M(m + 12), 2.4, 1.0, rng), .5, -.7 + i * .28))
    parts.append((0, sl.bell(M(74 + v * 2), 5.0, rng=rng, tau=2.6), .45, 0))
    parts.append((0, sl.bell(M(86 + v * 2), 4.0, rng=rng, tau=1.8), .25, .3))
    x = mix(parts, 5.0)
    return sl.finish_oneshot(wet(x, rng, 3.2, .45, .55), -17.5, -2.0, 1, 100)


SPECS = [
    ('pickup_coin', 'pickup.coin', 4, coin, 'Une note claire et courte', -4),
    ('pickup_xp', 'pickup.xp', 4, xp, 'Orbe d XP doux montant', 0),
    ('pickup_ruby', 'pickup.ruby', 3, ruby, 'Rubis cristallin', 0),
    ('ui_click', 'ui.click', 4, click, 'Clic d interface', -4),
    ('ui_level_up', 'ui.level_up', 2, level_up, 'Montee de niveau : arpege de harpe, cloche, nappe', 0),
    ('ui_spell_ready', 'ui.spell_ready', 3, spell_ready, 'Sort pret : deux notes de verre', 0),
    ('ui_dice', 'ui.dice', 4, dice, 'Roulement de des', 0),
    ('ui_item_pick', 'ui.item_pick', 3, item_pick, 'Choix d objet', 0),
    ('chest_lock', 'chest.lock', 3, chest_lock, 'Serrure de coffre verrouille', 0),
    ('chest_open_petit', 'chest.open.petit', 3, lambda r, v: chest_open('petit', r, v), 'Ouverture petit coffre', 0),
    ('chest_open_large', 'chest.open.large', 3, lambda r, v: chest_open('large', r, v), 'Ouverture grand coffre', 0),
    ('chest_open_legendaire', 'chest.open.legendaire', 2, lambda r, v: chest_open('legendaire', r, v), 'Ouverture coffre legendaire', 0),
    ('chest_open_boss', 'chest.open.boss', 2, lambda r, v: chest_open('boss', r, v), 'Ouverture coffre de boss', 0),
    ('chest_reveal', 'chest.reveal', 3, reveal, 'Revelation du contenu', 0),
    ('chest_legendary_rise', 'chest.legendary.rise', 2, leg_rise, 'Montee du coffre legendaire (3 s)', 0),
    ('chest_legendary_impact', 'chest.legendary.impact', 2, leg_impact, 'Impact du coffre legendaire', 0),
]


def main():
    global OUT
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=str(OUT))
    ap.add_argument('--seed', type=int, default=0)
    ap.add_argument('--only', default='')
    a = ap.parse_args()
    OUT = Path(a.out)
    OUT.mkdir(parents=True, exist_ok=True)
    items = []
    for fname, lid, nv, fn, usage, gain in SPECS:
        if a.only and a.only not in fname:
            continue
        for v in range(nv):
            rng = np.random.default_rng(hash(fname) % 100000 * 0 + sum(map(ord, fname)) * 31 + v * 977 + a.seed * 10007)
            x = trim_tail(fn(rng, v))
            p = OUT / f'{fname}_{v + 1:02d}.ogg'
            ac.write_ogg(p, x, 5)
            items.append(dict(path=f'ui/{p.name}', duration_s=round(len(x) / SR, 3), loop=False, level='none', usage=f'{lid}: {usage}',
                              gain_db=gain, peak_dbfs=round(ac.peak_db(x), 2), rms_dbfs=round(sl.rms_active(x), 2)))
            print(p.name, round(len(x) / SR, 2), round(ac.peak_db(x), 1), round(sl.rms_active(x), 1), flush=True)
    mf = ROOT / 'art' / 'tools' / 'audio' / 'ui_manifest.json'
    old = []
    if a.only and mf.exists():
        old = [o for o in json.load(open(mf, encoding='utf-8')) if o['path'] not in {i['path'] for i in items}]
    json.dump(old + items, open(mf, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)


if __name__ == '__main__':
    main()
