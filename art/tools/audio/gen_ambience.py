"""Ambiances Rainfall : pluie (3 intensites), vent (generique + par carte), decors par carte, tonnerre.
Tout est synthetise ; boucles de 64 s parfaitement circulaires (bruit periodique, evenements repliés).
uv run --with numpy --with scipy python art/tools/audio/gen_ambience.py [--only nom] [--seed 7]
Sorties : game/assets/audio/ambience/<id>_NN.ogg  (id a.b.c -> a_b_c_NN.ogg)
"""
import argparse
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl

SR = ac.SR
LOOP_S = 64
N = LOOP_S * SR
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game' / 'assets' / 'audio' / 'ambience'
Q = 6


# ---------------------------------------------------------------- briques ----
def stereo_noise(rng, shape):
    return np.column_stack([sl.loop_noise(N, rng, shape), sl.loop_noise(N, rng, shape)])


def sweep_resonator(x, fc, q, blk=1024):
    """Resonateur dont la frequence centrale varie par blocs (x : signal triple, fc : par echantillon)."""
    out = np.zeros_like(x)
    zi = np.zeros(2)
    for i in range(0, len(x), blk):
        f = float(np.clip(fc[i], 60, SR * .45))
        b, a = signal.iirpeak(f, q, fs=SR)
        y, zi = signal.lfilter(b, a, x[i:i + blk], zi=zi)
        out[i:i + blk] = y
    return out


def tiled_resonator(x, fc_periodic, q):
    t3 = np.concatenate([x, x, x])
    fc3 = np.concatenate([fc_periodic] * 3)
    return sweep_resonator(t3, fc3, q)[N:2 * N]


def tick_bank(rng, k=40):
    bank = []
    for _ in range(k):
        L = int(rng.uniform(.002, .007) * SR)
        t = np.arange(L) / SR
        f = rng.uniform(2500, 9000)
        s = sl.bp(rng.normal(size=L + 64), f * .6, min(f * 1.6, 20000), 1)[64:] * np.exp(-t / rng.uniform(.0007, .002))
        bank.append(s / (np.abs(s).max() + 1e-9))
    return bank


def plop_bank(rng, k=24):
    bank = []
    for _ in range(k):
        L = int(rng.uniform(.03, .09) * SR)
        t = np.arange(L) / SR
        f0 = rng.uniform(350, 1400)
        ph = np.cumsum(f0 * (1 + 1.4 * t / t[-1] * 2)) / SR
        s = np.sin(2 * np.pi * ph) * np.exp(-t / rng.uniform(.012, .03)) * np.minimum(1, t / .0008)
        s += sl.bp(rng.normal(size=L + 64), 1200, 6000, 1)[64:] * np.exp(-t / .002) * .5
        bank.append(s / (np.abs(s).max() + 1e-9))
    return bank


def scatter(buf, rng, rate, bank, amp_lo, amp_hi, env=None, power=2.0):
    cnt = int(rate * LOOP_S)
    starts = rng.integers(0, N, cnt)
    for s in starts:
        a = (rng.uniform(amp_lo, amp_hi)) ** power
        if env is not None:
            a *= env[s]
        sl.put(buf, s, bank[rng.integers(len(bank))], a, rng.uniform(-.9, .9))


def finish_loop(x, rms_target, peak=-3.0, name=''):
    x = x - x.mean(0)
    g = 10 ** ((rms_target - ac.rms_db(x)) / 10 / 2 * 1.0 * 1)
    # rms_db est en 10*log10(mean(x^2)) => dB reels ; g lineaire = 10**(delta/20)
    g = 10 ** ((rms_target - ac.rms_db(x)) / 20)
    x = x * g
    pk = ac.peak_db(x)
    if pk > peak:
        x = sl.soft_limit(x, peak - 6, peak - .3)
    return x


# ---------------------------------------------------------------- pluie ----
RAIN = {
    'light': dict(wash=.5, tick=130, plop=1.5, bright=.8, roof=.0, rms=-25.5, seed=1),
    'medium': dict(wash=.8, tick=380, plop=5, bright=1.0, roof=.25, rms=-24, seed=2),
    'heavy': dict(wash=1.2, tick=900, plop=11, bright=1.15, roof=.6, rms=-22.5, seed=3),
}


def gen_rain(level, seed0):
    p = RAIN[level]
    rng = np.random.default_rng(p['seed'] + seed0 * 100)

    def shape(f):
        # nappe : rose entre 600 Hz et 9 kHz, plus de souffle haut selon l intensite
        s = np.where(f < 600, (f / 600) ** 1.5, 1.0) * (1.0 / np.sqrt(np.maximum(f, 600) / 600))
        s *= np.where(f > 9000, (9000 / np.maximum(f, 1)) ** 2.5 * p['bright'], 1)
        s += .25 * p['bright'] * np.exp(-((f - 6500) / 2500) ** 2)
        return s
    wash = stereo_noise(rng, shape) * p['wash']
    # variation lente (periodique)
    slow = sl.smooth_rand_env(N, rng, 5, .12)
    wash *= slow[:, None]
    buf = np.zeros((N, 2))
    scatter(buf, rng, p['tick'], tick_bank(rng), .25, 1.0, power=2.2)
    scatter(buf, rng, p['plop'], plop_bank(rng), .15, .7, power=2.5)
    mix = wash * .9 + buf * 1.3
    if p['roof']:
        # goutte sur tole/toit : grondement sourd resonant
        rumble = stereo_noise(rng, lambda f: np.exp(-((f - 240) / 120) ** 2) + .3 * np.exp(-((f - 90) / 50) ** 2))
        mix += rumble * p['roof'] * .35 * slow[:, None]
    # leger air : filtre doux tout en bas
    mix = sl.loop_filter(mix, lambda t: sl.hp(t, 80, 1))
    return finish_loop(mix, p['rms'])


# ---------------------------------------------------------------- vent ----
def gust_env(rng, depth, cycles=7):
    e = sl.smooth_rand_env(N, rng, cycles, depth)
    return np.clip(e, .1, None)


def creak_events(buf, rng, count, f_lo, f_hi, dur_lo, dur_hi, amp, harmonics=5):
    for _ in range(count):
        L = int(rng.uniform(dur_lo, dur_hi) * SR)
        t = np.arange(L) / SR
        f0 = rng.uniform(f_lo, f_hi)
        glide = f0 * (1 + rng.uniform(-.25, .25) * np.sin(np.pi * t / t[-1]) + rng.uniform(-.1, .1) * t / t[-1])
        jitter = 1 + .02 * sl.smooth_rand_env(L, rng, 12, 1)[:L] - .02
        ph = np.cumsum(glide * jitter) / SR
        s = np.zeros(L)
        for k in range(1, harmonics + 1):
            s += np.sin(2 * np.pi * k * ph + rng.uniform(0, 6)) / k ** rng.uniform(.8, 1.4)
        s *= np.abs(np.sin(np.pi * t / t[-1])) ** 1.5
        s *= 1 + .5 * np.sin(2 * np.pi * rng.uniform(25, 70) * t)  # frottement saccade
        s = sl.resonator(s, rng.uniform(900, 2500), 3) * .6 + s * .4
        sl.put(buf, int(rng.uniform(0, N)), s, amp * rng.uniform(.5, 1), rng.uniform(-.8, .8))


def gen_wind(kind, seed0):
    rng = np.random.default_rng({'cite_rouille': 11, 'foret_brume': 12, 'terrasses_noyees': 13, 'generic': 14}[kind] + seed0 * 100)
    gust = gust_env(rng, {'cite_rouille': .75, 'foret_brume': .3, 'terrasses_noyees': .5, 'generic': .5}[kind])
    gust2 = gust_env(rng, .5, 11)
    if kind == 'cite_rouille':
        body = stereo_noise(rng, lambda f: (1 / np.sqrt(np.maximum(f, 40) / 40)) * np.exp(-(f / 1400) ** 2)) * 1.0
        body *= (gust ** 1.6)[:, None]
        # sifflements metalliques : 3 resonateurs etroits balayant des plages, modules par les rafales
        whistle = np.zeros((N, 2))
        for i, (lo, hi, q, cyc, amp) in enumerate(((1300, 2300, 45, 3, 1.0), (2200, 3600, 60, 5, .7), (700, 1100, 35, 2, .8))):
            for c in (0, 1):
                n0 = rng.normal(size=N)
                fc = (lo + hi) / 2 + (hi - lo) / 2 * (sl.loop_lfo(N, cyc, rng.uniform()) * .7 + sl.loop_lfo(N, cyc * 3 + 1, rng.uniform()) * .3)
                w = tiled_resonator(n0, fc, q)
                w /= np.std(w) + 1e-9
                whistle[:, c] += w * amp * (np.clip(gust - .75, 0, None) * 2.6 + .12) * 1.2
        # resonances de tuyaux / toles : grondements mediums
        pipes = np.zeros((N, 2))
        for c in (0, 1):
            n0 = rng.normal(size=N)
            fc = 190 + 60 * sl.loop_lfo(N, 2, rng.uniform()) + 40 * sl.loop_lfo(N, 7, rng.uniform())
            w = tiled_resonator(n0, fc, 14)
            pipes[:, c] = w / (np.std(w) + 1e-9) * (gust2 ** 2) * .5
        creaks = np.zeros((N, 2))
        creak_events(creaks, rng, 7, 180, 520, .6, 1.8, .05)
        gusty = np.zeros((N, 2))
        mix = body * 1.0 + whistle * .55 + pipes * .45 + creaks
        rms = -23.5
    elif kind == 'foret_brume':
        body = stereo_noise(rng, lambda f: (1 / np.sqrt(np.maximum(f, 60) / 60)) * np.exp(-(f / 700) ** 2)) * (gust ** 1.2)[:, None]
        rustle = np.zeros((N, 2))
        for c in (0, 1):
            nz = sl.loop_noise(N, rng, lambda f: np.where((f > 1800) & (f < 8500), 1.0, 0.05) * (1800 / np.maximum(f, 1800)) ** .3)
            fast = sl.smooth_rand_env(N, rng, 60, 1.0)  # bruissement : modulation rapide sans periode evidente
            fast = np.clip(fast, 0, None) ** 2
            rustle[:, c] = nz * fast * np.clip(gust - .55, 0, None) * 1.6
        # souffle aigu tres doux
        air = stereo_noise(rng, lambda f: np.exp(-((f - 450) / 220) ** 2)) * (gust2 ** 2)[:, None] * .35
        mix = body * 1.0 + rustle * .55 + air
        rms = -26
    else:
        deep = 1 if kind == 'terrasses_noyees' else 0
        body = stereo_noise(rng, lambda f: (1 / np.sqrt(np.maximum(f, 50) / 50)) * np.exp(-(f / 1100) ** 2)) * (gust ** 1.4)[:, None]
        hollow = np.zeros((N, 2))
        for c in (0, 1):
            n0 = rng.normal(size=N)
            fc = 330 + 90 * sl.loop_lfo(N, 3, rng.uniform()) + 40 * sl.loop_lfo(N, 8, rng.uniform())
            w = tiled_resonator(n0, fc, 6)
            hollow[:, c] = w / (np.std(w) + 1e-9) * (gust2 ** 1.5) * .9
        whistle = np.zeros((N, 2))
        for c in (0, 1):
            n0 = rng.normal(size=N)
            fc = 1100 + 300 * sl.loop_lfo(N, 4, rng.uniform())
            w = tiled_resonator(n0, fc, 22)
            whistle[:, c] = w / (np.std(w) + 1e-9) * np.clip(gust - .7, 0, None) * 1.3
        trickle = np.zeros((N, 2))
        if deep:
            for c in (0, 1):
                nz = sl.loop_noise(N, rng, lambda f: np.where((f > 1500) & (f < 7000), 1.0, 0.03))
                bub = np.clip(sl.smooth_rand_env(N, rng, 400, 1.0), 0, None) ** 3
                trickle[:, c] = nz * bub * .25
        mix = body + hollow * .55 + whistle * .3 + trickle
        rms = -24
    mix = sl.loop_filter(mix, lambda t: sl.hp(t, 25, 1))
    return finish_loop(mix, rms)


# ---------------------------------------------------------------- decors ----
def flow_water(rng, level=1.0, bright=1.0):
    out = np.zeros((N, 2))
    for c in (0, 1):
        nz = sl.loop_noise(N, rng, lambda f: np.where((f > 250) & (f < 4500), 1.0, .05) * (400 / np.maximum(f, 400)) ** .4)
        bub = np.clip(sl.smooth_rand_env(N, rng, 700, 1.0), 0, None) ** 1.5
        out[:, c] = nz * (.4 + .6 * bub)
    chirps = np.zeros((N, 2))
    for _ in range(int(14 * LOOP_S * level)):
        L = int(rng.uniform(.02, .07) * SR)
        t = np.arange(L) / SR
        f0 = rng.uniform(500, 1500) * bright
        s = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 2.2 * t / t[-1])) / SR) * np.exp(-t / rng.uniform(.01, .03))
        sl.put(chirps, rng.integers(0, N), s, rng.uniform(.03, .22), rng.uniform(-.8, .8))
    return out + chirps


def drip_event(rng, f=None, tau=.25, metallic=False):
    L = int(rng.uniform(.25, .6) * SR)
    t = np.arange(L) / SR
    f = f or rng.uniform(600, 1500)
    s = np.sin(2 * np.pi * np.cumsum(f * (1 + 1.2 * np.exp(-t / .015))) / SR) * np.exp(-t / tau) * np.minimum(1, t / .0005)
    if metallic:
        for r, a in ((2.3, .5), (3.7, .35), (5.1, .2)):
            s += a * np.sin(2 * np.pi * f * r * t) * np.exp(-t / (tau * .6))
    return s


def gen_decor(carte, seed0):
    rng = np.random.default_rng({'terrasses_noyees': 21, 'foret_brume': 22, 'cite_rouille': 23}[carte] + seed0 * 100)
    dry = np.zeros((N, 2))
    wet = np.zeros((N, 2))
    if carte == 'terrasses_noyees':
        # eau qui coule de terrasse en terrasse
        water = flow_water(rng, 1.0)
        water = sl.loop_filter(water, lambda t: sl.hp(t, 150, 1))
        dry += water * .8
        wet += water * .25
        # gouttes resonantes (grosses, dans de l eau) + clapotis
        for _ in range(55):
            s = drip_event(rng, tau=rng.uniform(.18, .4))
            sl.put(wet, rng.integers(0, N), s, rng.uniform(.15, .6), rng.uniform(-.9, .9))
        for _ in range(180):
            s = drip_event(rng, f=rng.uniform(1200, 3200), tau=.07)
            sl.put(dry, rng.integers(0, N), s, rng.uniform(.04, .2), rng.uniform(-.9, .9))
        # cloche lointaine assourdie, tres espacee (2 coups)
        for at, f in ((13.7, 196), (44.1, 164.8)):
            b = sl.bell(f, 7.0, rng=rng, tau=3.2)
            b = sl.lp(b, 1100, 2)
            sl.put(wet, int(at * SR), b, .35, rng.uniform(-.5, .5))
        rev = sl.Reverb(rng, rt60=3.2, brightness=.25)
        x = dry + rev.circular(wet) * 1.4
        rms = -27.5
    elif carte == 'foret_brume':
        for c in range(2):
            nz = sl.loop_noise(N, rng, lambda f: np.exp(-(f / 500) ** 2) / np.sqrt(np.maximum(f, 40) / 40))
            dry[:, c] += nz * sl.smooth_rand_env(N, rng, 4, .4) * .5
        # gouttes sur les feuilles (souples, mates) : plus nombreuses
        for _ in range(130):
            s = drip_event(rng, f=rng.uniform(700, 2200), tau=rng.uniform(.04, .1))
            s = sl.lp(s, 3500, 1)
            sl.put(wet, rng.integers(0, N), s, rng.uniform(.1, .5), rng.uniform(-.9, .9))
        for _ in range(240):
            L = int(.004 * SR)
            t = np.arange(L) / SR
            s = sl.bp(rng.normal(size=L + 32), 1500, 6000, 1)[32:] * np.exp(-t / .0012)
            sl.put(dry, rng.integers(0, N), s, rng.uniform(.03, .15), rng.uniform(-.9, .9))
        # craquements de bois
        creak_events(wet, rng, 9, 90, 260, .35, 1.1, .12, harmonics=7)
        for _ in range(30):
            L = int(.02 * SR)
            t = np.arange(L) / SR
            s = (sl.resonator(rng.normal(size=L), rng.uniform(250, 700), 8)) * np.exp(-t / .004)
            sl.put(wet, rng.integers(0, N), s / (np.abs(s).max() + 1e-9), rng.uniform(.04, .2), rng.uniform(-.8, .8))
        # insectes humides, tres discrets : trilles courtes et rares
        for _ in range(14):
            L = int(rng.uniform(.5, 1.6) * SR)
            t = np.arange(L) / SR
            f0 = rng.uniform(3200, 5200)
            pulse = (np.sin(2 * np.pi * rng.uniform(18, 32) * t) > 0).astype(float)
            pulse = sl.lp(pulse, 120, 1)
            s = np.sin(2 * np.pi * np.cumsum(f0 * (1 + .02 * np.sin(2 * np.pi * 3 * t))) / SR) * pulse * np.sin(np.pi * t / t[-1])
            sl.put(dry, rng.integers(0, N), s, rng.uniform(.02, .05), rng.uniform(-.9, .9))
        rev = sl.Reverb(rng, rt60=2.2, brightness=.2)
        x = dry + rev.circular(wet) * 1.5
        rms = -27.5
    else:  # cite_rouille
        # drone industriel grave, tres discret
        t = np.arange(N) / SR
        drone = (np.sin(2 * np.pi * 55 * t) + .4 * np.sin(2 * np.pi * 110 * t + 1) + .15 * np.sin(2 * np.pi * 165.5 * t)) * (1 + .15 * sl.loop_lfo(N, 4))
        drone = np.round(55 * LOOP_S) / (55 * LOOP_S) * drone  # frequences entieres sur la boucle (55*64 = 3520 cycles)
        dry += np.column_stack([drone, np.roll(drone, 4000)]) * .1
        # grincements de metal
        creak_events(wet, rng, 10, 220, 900, .5, 2.0, .09, harmonics=8)
        # chaines : grappes de petits chocs metalliques de moins en moins espaces
        for _ in range(7):
            at = rng.integers(0, N)
            gap = rng.uniform(.12, .3)
            pos = 0.0
            n_hits = rng.integers(5, 12)
            pan = rng.uniform(-.8, .8)
            for k in range(n_hits):
                m = sl.metal_hit(rng.uniform(1800, 4200), rng.uniform(.3, .9), rng, dur=.35)
                m = sl.hp(m, 900, 1)
                sl.put(wet, at + int(pos * SR), m, .06, pan)
                pos += gap * rng.uniform(.5, 1.2) * (1 - .06 * k)
        # vapeur qui siffle
        for _ in range(5):
            L = int(rng.uniform(1.5, 3.5) * SR)
            t = np.arange(L) / SR
            env = np.sin(np.pi * t / t[-1]) ** 2
            h = sl.hp(rng.normal(size=L), rng.uniform(3000, 5000), 2) * env * (1 + .3 * np.sin(2 * np.pi * rng.uniform(3, 8) * t))
            h += sl.resonator(rng.normal(size=L), rng.uniform(5000, 8000), 12) * env * .8
            sl.put(wet, rng.integers(0, N), h, .045, rng.uniform(-.7, .7))
        # goutte-a-goutte dans les tuyaux
        for _ in range(70):
            s = drip_event(rng, f=rng.uniform(450, 1600), tau=rng.uniform(.12, .35), metallic=True)
            sl.put(wet, rng.integers(0, N), s, rng.uniform(.08, .35), rng.uniform(-.9, .9))
        # cloche rouillee lointaine (2 coups, sourde, legerement desaccordee)
        for at, f in ((19.4, 233.1), (50.2, 185.0)):
            b = sl.bell(f, 6.5, rng=rng, tau=2.2,
                        ratios=[(.5, .5, 1.2), (1, 1, 1.0), (1.18, .7, .9), (1.47, .6, .6), (2.09, .5, .45), (2.76, .35, .35), (4.2, .2, .2)])
            sl.put(wet, int(at * SR), sl.lp(b, 1500, 2), .35, rng.uniform(-.5, .5))
        # souffle de ville tres bas
        for c in range(2):
            dry[:, c] += sl.loop_noise(N, rng, lambda f: np.exp(-(f / 450) ** 2) / np.sqrt(np.maximum(f, 40) / 40)) * .25
        rev = sl.Reverb(rng, rt60=2.8, brightness=.35)
        x = dry + rev.circular(wet) * 1.4
        rms = -26.5
    x = sl.loop_filter(x, lambda t: sl.hp(t, 28, 1))
    return finish_loop(x, rms)


# ---------------------------------------------------------------- tonnerre ----
def thunder(kind, idx, seed0):
    rng = np.random.default_rng((31 if kind == 'close' else 41) + idx * 7 + seed0 * 100)
    if kind == 'close':
        dur = rng.uniform(3.6, 4.6)
    else:
        dur = rng.uniform(4.6, 6.2)
    n = int(dur * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for c in (0, 1):
        brown = rng.normal(size=n)
        brown = np.cumsum(brown)
        brown -= sl.hp(brown, 20, 1) * 0 + np.linspace(brown[0], brown[-1], n)
        brown = brown / (np.std(brown) + 1e-9)
        # grondement : plusieurs ondes roulantes decroissantes
        env = np.zeros(n)
        k = rng.integers(5, 9) if kind == 'close' else rng.integers(4, 7)
        starts = np.sort(rng.uniform(0, .5 * dur, k))
        for s0 in starts:
            u = np.maximum(t - s0, 0)
            a = rng.uniform(.3, 1.0) * np.exp(-u / (rng.uniform(.5, 1.3) if kind == 'close' else rng.uniform(1.0, 2.0)))
            a *= (t >= s0) * np.minimum(1, (t - s0) / (.03 if kind == 'close' else .6))
            env += a
        env += (np.exp(-t / (1.3 if kind == 'close' else 2.4))) * .8
        cut = 650 if kind == 'close' else 230
        rumble = sl.lp(brown, cut, 3) * env
        sub = np.sin(2 * np.pi * np.cumsum(rng.uniform(38, 58) * (1 + .3 * np.exp(-t / .6))) / SR) * np.exp(-t / (1.5 if kind == 'close' else 2.5)) * (1 - np.exp(-t / (.02 if kind == 'close' else .5)))
        sig = rumble * 1.0 + sub * .7
        if kind == 'close':
            crack = sl.hp(rng.normal(size=n), 1800, 2) * np.exp(-t / .012) * 1.6
            crack += sl.bp(rng.normal(size=n), 300, 3000, 1) * np.exp(-t / .12) * .7
            # craquements secondaires (dechirure du ciel)
            for _ in range(rng.integers(3, 7)):
                a0 = rng.uniform(.02, .35)
                crack += sl.hp(rng.normal(size=n), 1200, 1) * np.exp(-np.maximum(t - a0, 0) / .02) * (t >= a0) * rng.uniform(.1, .4)
            sig = sig + crack * 1.0
        out[:, c] = sig
    out = out - out.mean(0)
    # espace : reverb a convolution lineaire, plus grande pour le lointain
    rev = sl.Reverb(rng, rt60=2.2 if kind == 'close' else 4.0, brightness=.15)
    wet = rev.linear(out, tail=int(1.5 * SR))
    full = np.zeros((len(wet), 2))
    full[:n] += out
    full += wet * (.55 if kind == 'close' else .75)
    if kind == 'far':
        full = sl.lp(full, 420, 3)
    full = full[: int((dur + .9) * SR)]
    # fin en fondu long
    k = int(1.0 * SR)
    full[-k:] *= np.linspace(1, 0, k)[:, None] ** 1.5
    y = sl.finish_oneshot(full, -22 if kind == 'close' else -26, peak_db=-3.0, fade_in_ms=2 if kind == 'close' else 40, fade_out_ms=20)
    return y


# ---------------------------------------------------------------- main ----
def write(name, x, loop, items, usage, gain, level='none'):
    path = OUT / f'{name}_01.ogg'
    ac.write_ogg(path, x, Q)
    items.append(dict(path=f'ambience/{path.name}', duration_s=round(len(x) / SR, 3), loop=loop, level=level, usage=usage,
                      gain_db=gain, peak_dbfs=round(ac.peak_db(x), 2), rms_dbfs=round(ac.rms_db(x), 2)))
    print(name, len(x) / SR, 'pk', round(ac.peak_db(x), 1), 'rms', round(ac.rms_db(x), 1),
          'seam', round(sl.loop_seam_stats(x), 2) if loop else '-', flush=True)


def write_n(name, nn, x, items, usage, gain):
    path = OUT / f'{name}_{nn:02d}.ogg'
    ac.write_ogg(path, x, Q)
    items.append(dict(path=f'ambience/{path.name}', duration_s=round(len(x) / SR, 3), loop=False, level='none', usage=usage,
                      gain_db=gain, peak_dbfs=round(ac.peak_db(x), 2), rms_dbfs=round(ac.rms_db(x), 2)))
    print(name, nn, len(x) / SR, 'pk', round(ac.peak_db(x), 1), flush=True)


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
    want = lambda k: not a.only or a.only in k
    for lv in ('light', 'medium', 'heavy'):
        if want('rain_' + lv):
            x = gen_rain(lv, a.seed)
            write('amb_rain_' + lv, x, True, items, f'amb.rain.{lv} (boucle 64 s, pluie {lv})', 0)
            if lv == 'medium':
                write('amb_rain', x, True, items, 'amb.rain (defaut = intensite moyenne)', 0)
    for k, label in (('cite_rouille', 'Cite de rouille : tres venteux, sifflements metalliques'), ('foret_brume', 'Foret-brume : calme, bruissements'),
                     ('terrasses_noyees', 'Terrasses noyees : intermediaire, creux, humide'), ('generic', 'vent generique intermediaire')):
        if want('wind_' + k):
            x = gen_wind(k, a.seed)
            name = 'amb_wind' if k == 'generic' else f'amb_wind_{k}'
            write(name, x, True, items, f'amb.wind{"" if k == "generic" else "." + k}: {label}', 0)
    for k in ('terrasses_noyees', 'foret_brume', 'cite_rouille'):
        if want('decor_' + k):
            x = gen_decor(k, a.seed)
            write(f'amb_{k}_decor', x, True, items, f'amb.{k}.decor (boucle 64 s)', 0)
    for kind in ('close', 'far'):
        if want('thunder_' + kind):
            for i in range(1, 5):
                write_n(f'amb_thunder_{kind}', i, thunder(kind, i, a.seed), items, f'amb.thunder_{kind} (one-shot)', 0)
    mf = ROOT / 'art' / 'tools' / 'audio' / 'ambience_manifest.json'
    old = []
    if a.only and mf.exists():
        old = [o for o in json.load(open(mf, encoding='utf-8')) if o['path'] not in {i['path'] for i in items}]
    json.dump(old + items, open(mf, 'w', encoding='utf-8'), indent=1, ensure_ascii=False)


if __name__ == '__main__':
    main()
