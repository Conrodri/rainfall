"""Bibliotheque de synthese Rainfall (ambiances, UI, musique). Complete audio_common sans le modifier.
Tout est procedural : oscillateurs a table d ondes limitee en bande, modeles additifs (piano, harpe, cloche),
bruits filtres, reverberation a convolution synthetique (circulaire pour les boucles)."""
import numpy as np
from scipy import signal
import audio_common as ac

SR = ac.SR
N_TAB = 4096
_TABS = {}


def _tables():
    if _TABS:
        return _TABS
    ph = np.arange(N_TAB) / N_TAB
    for kind in ('saw', 'square', 'tri'):
        for H in (3, 6, 12, 24, 48, 96):
            k = np.arange(1, H + 1)
            if kind == 'square':
                k = k[k % 2 == 1]
            s = np.sin(2 * np.pi * k[:, None] * ph[None, :])
            if kind == 'saw':
                w = (s / k[:, None]).sum(0)
            elif kind == 'square':
                w = (s / k[:, None]).sum(0)
            else:
                sign = np.where(((k - 1) // 2) % 2 == 0, 1.0, -1.0)
                w = (s * (sign / k ** 2)[:, None]).sum(0)
            _TABS[(kind, H)] = w / np.max(np.abs(w))
    return _TABS


def wosc(freq, n=None, kind='saw', phase0=0.0):
    """Oscillateur a table (limite en bande). freq scalaire ou tableau."""
    f = np.asarray(freq, dtype=float)
    if f.ndim == 0:
        f = np.full(n, float(f))
    fmax = max(float(f.max()), 1.0)
    H = 3
    for h in (3, 6, 12, 24, 48, 96):
        H = h
        if h * fmax > 19000:
            H = max(3, h // 2) if h > 3 else 3
            break
    if H * fmax > 19000 and H > 3:
        H = {96: 48, 48: 24, 24: 12, 12: 6, 6: 3}.get(H, 3)
    tab = _tables()[(kind, H)]
    ph = phase0 + np.cumsum(f) / SR
    idx = (ph % 1.0) * N_TAB
    i0 = idx.astype(np.int64) % N_TAB
    fr = idx - np.floor(idx)
    return tab[i0] * (1 - fr) + tab[(i0 + 1) % N_TAB] * fr


def sine(freq, n, phase0=0.0):
    f = np.asarray(freq, dtype=float)
    if f.ndim == 0:
        f = np.full(n, float(f))
    return np.sin(2 * np.pi * (phase0 + np.cumsum(f) / SR))


def mtof(m):
    return 440.0 * 2.0 ** ((np.asarray(m, dtype=float) - 69) / 12)


def lp(x, fc, order=2):
    fc = min(fc, SR * .45)
    return signal.sosfilt(signal.butter(order, fc, 'lowpass', fs=SR, output='sos'), x, axis=0)


def hp(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, 'highpass', fs=SR, output='sos'), x, axis=0)


def bp(x, lo, hi, order=2):
    hi = min(hi, SR * .45)
    return signal.sosfilt(signal.butter(order, [lo, hi], 'bandpass', fs=SR, output='sos'), x, axis=0)


def resonator(x, f, q):
    """Pic resonant (formant / tuyau / tole)."""
    f = min(f, SR * .45)
    b, a = signal.iirpeak(f, q, fs=SR)
    return signal.lfilter(b, a, x, axis=0)


def tail_env(n, tau):
    return np.exp(-np.arange(n) / (SR * tau))


def ar(n, a, r, shape=1.0):
    """Enveloppe attaque/relache (secondes), n echantillons."""
    na = max(1, min(n // 2, int(a * SR)))
    nr = max(1, min(n - na, int(r * SR)))
    e = np.ones(n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) ** shape
    e[n - nr:] *= np.linspace(1, 0, nr) ** shape
    return e


def soft_limit(x, thr_db=-8.0, ceiling_db=-1.5):
    thr = 10 ** (thr_db / 20)
    ceil = 10 ** (ceiling_db / 20)
    a = np.abs(x)
    over = a > thr
    y = x.copy()
    y[over] = np.sign(x[over]) * (thr + (ceil - thr) * np.tanh((a[over] - thr) / (ceil - thr)))
    return y


def rms_active(x, floor_db=-45):
    """RMS (dB) sur les echantillons au-dessus d un plancher relatif, pour les one-shots."""
    m = x if x.ndim == 1 else x.mean(1)
    e = m ** 2
    w = int(.02 * SR)
    env = np.sqrt(np.convolve(e, np.ones(w) / w, 'same'))
    thr = env.max() * 10 ** (floor_db / 20)
    sel = env > max(thr, 1e-9)
    return float(10 * np.log10(np.mean(e[sel]) + 1e-24))


def finish_oneshot(x, target_rms, peak_db=-1.5, fade_in_ms=2, fade_out_ms=8):
    """Normalise sur la RMS utile, limite doucement, vise une crete <= peak_db, fondus anti-clic."""
    x = x - x.mean(0) if x.ndim == 2 else x - x.mean()
    g = 10 ** ((target_rms - rms_active(x)) / 20)
    y = soft_limit(x * g, thr_db=peak_db - 5, ceiling_db=peak_db - .2)
    pk = ac.peak_db(y)
    if pk > peak_db:
        y *= 10 ** ((peak_db - pk) / 20)
    n = len(y)
    k1 = int(fade_in_ms * SR / 1000)
    k2 = int(fade_out_ms * SR / 1000)
    r1 = np.linspace(0, 1, k1)
    r2 = np.linspace(1, 0, k2)
    if y.ndim == 2:
        r1 = r1[:, None]
        r2 = r2[:, None]
    y[:k1] *= r1
    y[n - k2:] *= r2
    return y


# ---------------------------------------------------------------- reverberation ----
def make_ir(rng, rt60=2.5, brightness=.5, predelay=.012, width=1.0, early=True):
    """Reponse impulsionnelle stereo synthetique : bruit a decroissance exponentielle dont les aigus
    meurent plus vite que les graves, plus quelques premieres reflexions."""
    n = int(rt60 * 1.15 * SR)
    t = np.arange(n) / SR
    chans = []
    base = rng.normal(size=(n, 2))
    for c in range(2):
        low = lp(base[:, c], 700) * 10 ** (-3 * t / (rt60 * 1.25))
        mid = bp(base[:, c], 700, 3500) * 10 ** (-3 * t / rt60)
        high = hp(base[:, c], 3500) * 10 ** (-3 * t / (rt60 * (.28 + .5 * brightness)))
        h = low * 1.6 + mid + high * brightness * 1.4
        h *= np.minimum(1, t / .02)
        pd = int(predelay * SR * (1 + .15 * c))
        h = np.concatenate([np.zeros(pd), h])[:n]
        if early:
            for _ in range(7):
                p = int(rng.uniform(.004, .06) * SR)
                h[p] += rng.uniform(-.8, .8) * (1 if c == 0 else .8) * 6
        chans.append(h)
    ir = np.column_stack(chans)
    if width < 1:
        m = ir.mean(1, keepdims=True)
        ir = m + (ir - m) * width
    ir /= np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True)) + 1e-12
    return ir


def _fold(ir, N):
    """Replie une IR plus longue que la boucle (convolution circulaire)."""
    if len(ir) <= N:
        return np.concatenate([ir, np.zeros((N - len(ir), ir.shape[1]))])
    out = np.zeros((N, ir.shape[1]))
    for s in range(0, len(ir), N):
        seg = ir[s:s + N]
        out[:len(seg)] += seg
    return out


class Reverb:
    def __init__(self, rng, rt60=2.5, brightness=.5, predelay=.012, width=1.0):
        self.ir = make_ir(rng, rt60, brightness, predelay, width)
        self._cache = {}

    def _spec(self, N):
        if N not in self._cache:
            self._cache = {N: np.fft.rfft(_fold(self.ir, N), axis=0)}
        return self._cache[N]

    def circular(self, x):
        """x : (N,) ou (N,2) -> (N,2). Convolution circulaire = queue qui boucle sur le debut."""
        N = len(x)
        X = np.fft.rfft(x, axis=0)
        H = self._spec(N)
        if x.ndim == 1:
            Y = X[:, None] * H
        else:
            Y = np.empty_like(H)
            Y[:, 0] = X[:, 0] * H[:, 0]
            Y[:, 1] = X[:, 1] * H[:, 1]
            # melange stereo : chaque canal excite aussi l autre (largeur de salle)
            Y[:, 0] += .35 * X[:, 1] * H[:, 0]
            Y[:, 1] += .35 * X[:, 0] * H[:, 1]
        return np.fft.irfft(Y, n=N, axis=0)

    def linear(self, x, tail=None):
        """Convolution lineaire (one-shots). Allonge la sortie de la queue."""
        L = len(x) + (tail if tail is not None else len(self.ir))
        X = np.fft.rfft(x, n=L, axis=0)
        H = np.fft.rfft(self.ir, n=L, axis=0)
        if x.ndim == 1:
            Y = X[:, None] * H
        else:
            Y = np.stack([X[:, 0] * H[:, 0], X[:, 1] * H[:, 1]], 1)
        return np.fft.irfft(Y, n=L, axis=0)


# ---------------------------------------------------------------- bruit en boucle ----
def loop_noise(N, rng, shape):
    """Bruit parfaitement periodique de N echantillons dont le spectre est shape(freqs)."""
    spec = rng.normal(size=N // 2 + 1) + 1j * rng.normal(size=N // 2 + 1)
    f = np.fft.rfftfreq(N, 1 / SR)
    spec *= shape(f)
    spec[0] = 0
    x = np.fft.irfft(spec, n=N)
    return x / (np.std(x) + 1e-12)


def loop_filter(x, sos_fn):
    """Filtre quasi-circulaire : triple le signal, filtre, garde la copie centrale."""
    N = len(x)
    t = np.concatenate([x, x, x]) if x.ndim == 1 else np.concatenate([x, x, x], axis=0)
    y = sos_fn(t)
    return y[N:2 * N]


def loop_lfo(N, cycles, phase=0.0):
    return np.sin(2 * np.pi * (cycles * np.arange(N) / N + phase))


def smooth_rand_env(N, rng, cycles=6, depth=.4):
    """Enveloppe lente aleatoire, periodique (somme de sinus a cycles entiers)."""
    e = np.zeros(N)
    for c in range(1, cycles + 1):
        e += rng.uniform(.3, 1) / c * loop_lfo(N, c, rng.uniform())
    e /= np.max(np.abs(e)) + 1e-12
    return 1 + depth * e


def put(buf, start, x, g=1.0, pan=0.0):
    """Ajoute x (mono ou stereo) dans buf (N,2) a start avec repli circulaire."""
    n = len(buf)
    if x.ndim == 1:
        gl = np.sqrt((1 - pan) / 2) * g
        gr = np.sqrt((1 + pan) / 2) * g
        x = np.column_stack((x * gl, x * gr))
    else:
        x = x * g
    L = len(x)
    if L > n:
        x = x[:n]
        L = n
    s = int(start) % n
    e = min(L, n - s)
    buf[s:s + e] += x[:e]
    if L > e:
        buf[:L - e] += x[e:]


def loop_seam_stats(x):
    """(saut au raccord) / (variation moyenne par echantillon) sur le mono ; ~1 = parfait."""
    m = x if x.ndim == 1 else x.mean(1)
    sd = np.abs(np.diff(m)).mean() + 1e-12
    return abs(m[0] - m[-1]) / sd


# ---------------------------------------------------------------- instruments (mono) ----
def piano(f, dur, vel=.7, rng=None, tail=4.0):
    rng = rng or np.random.default_rng(int(f * 10) % 9973)
    d = min(dur + 1.5, tail) + .1
    n = int(d * SR)
    t = np.arange(n) / SR
    B = 3e-4 * (1 + (200 / max(f, 60)) ** 1.0)
    tau0 = 4.0 * (260 / max(f, 60)) ** .45
    x = np.zeros(n)
    for k in range(1, 15):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > 12000:
            break
        a = (1.0 / k ** (1.15 - .35 * vel)) * (1 if k < 9 else .6)
        tau = tau0 / (1 + .55 * (k - 1))
        for det in (-.25, .25):
            x += .5 * a * np.sin(2 * np.pi * (fk + det * k ** .3) * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    hammer = bp(rng.normal(size=n), 900, 4500) * np.exp(-t / .006) * (.25 + .5 * vel)
    x += hammer * .5
    rel = min(dur, d - .1)
    g = np.ones(n)
    k = int(.35 * SR)
    s0 = int(rel * SR)
    if s0 < n:
        seg = n - s0
        g[s0:] = np.exp(-np.arange(seg) / (SR * .22))
    x *= g * np.minimum(1, t / .002)
    return lp(x, 2500 + 5500 * vel, 1) * .5


def harp(f, dur=2.0, vel=.7, rng=None):
    rng = rng or np.random.default_rng(int(f * 7) % 9973)
    d = min(dur + .8, 3.2)
    n = int(d * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    tau0 = 1.9 * (330 / max(f, 80)) ** .3
    for k in range(1, 11):
        fk = f * k * (1 + 1.5e-4 * k * k)
        if fk > 11000:
            break
        a = 1 / k ** (1.35 - .3 * vel)
        x += a * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t / (tau0 / (1 + .6 * (k - 1))))
    x += bp(rng.normal(size=n), 1500, 6000) * np.exp(-t / .004) * .35 * vel
    x *= np.minimum(1, t / .0015) * ar(n, .0, .12 if dur + .8 < 3.2 else .3)
    return x * .6


def pluck(f, dur=.5, rng=None, tau=.35, bright=.6):
    """Corde pincee courte (pizzicato / guitare nylon)."""
    rng = rng or np.random.default_rng(int(f * 3) % 9973)
    n = int(max(dur, tau * 4) * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * (1 + 1e-4 * k * k)
        if fk > 9000:
            break
        x += (1 / k ** (1.2 - .5 * bright)) * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t / (tau / (1 + .5 * (k - 1))))
    x += bp(rng.normal(size=n), 800, 4000) * np.exp(-t / .003) * .25
    return x * np.minimum(1, t / .001) * .7


def bell(f, dur=4.0, vel=.7, rng=None, ratios=None, tau=3.0, strike=1.0):
    rng = rng or np.random.default_rng(int(f) % 9973)
    ratios = ratios or [(.5, .5, 1.4), (1, 1, 1.0), (1.19, .6, .8), (1.56, .45, .7), (2.0, .5, .6), (2.51, .35, .45), (3.0, .3, .4), (4.07, .2, .3), (5.43, .15, .22)]
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for r, a, dm in ratios:
        fk = f * r
        if fk > 12000:
            continue
        x += a * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t / (tau * dm)) * (1 + .15 * np.sin(2 * np.pi * rng.uniform(.5, 3) * t))
    x += strike * bp(rng.normal(size=n), 1500, 7000) * np.exp(-t / .008) * .3
    return x * np.minimum(1, t / .001) * ar(n, 0, .5) * .5


def flute(f, dur, vel=.6, rng=None):
    rng = rng or np.random.default_rng(int(f) % 9973)
    n = int((dur + .25) * SR)
    t = np.arange(n) / SR
    vib = 1 + .005 * np.sin(2 * np.pi * 5.1 * t) * np.minimum(1, np.maximum(0, t - .25) / .4)
    ph = np.cumsum(f * vib) / SR
    x = np.sin(2 * np.pi * ph) + .22 * np.sin(4 * np.pi * ph) + .08 * np.sin(6 * np.pi * ph)
    br = bp(rng.normal(size=n), f * 1.5, f * 5 + 800) * (.12 + .1 * vel)
    e = ar(n, .09, .22, 1.3)
    return (x + br) * e * (.35 + .4 * vel)


def reed(f, dur, vel=.6, rng=None):
    """Bois grave rond (clarinette basse / basson) : carre filtre avec vibrato lent."""
    n = int((dur + .2) * SR)
    t = np.arange(n) / SR
    fv = f * (1 + .004 * np.sin(2 * np.pi * 4.6 * t))
    x = wosc(fv, n, 'square') * .6 + wosc(fv * 1.003, n, 'saw') * .3
    x = lp(x, 900 + 1400 * vel, 2)
    return x * ar(n, .06, .18, 1.2) * .5


def cello(f, dur, vel=.7, rng=None, att=.12):
    n = int((dur + .3) * SR)
    t = np.arange(n) / SR
    fv = f * (1 + .0045 * np.sin(2 * np.pi * 5.0 * t) * np.minimum(1, t / .5))
    x = wosc(fv, n, 'saw') + .8 * wosc(fv * 1.004, n, 'saw', .3)
    x = lp(x, 700 + 2200 * vel, 2)
    return x * ar(n, att, .25, 1.2) * .45


def string_stacc(f, dur=.18, vel=.8, rng=None):
    n = int((dur + .1) * SR)
    t = np.arange(n) / SR
    x = wosc(f, n, 'saw') + wosc(f * 1.006, n, 'saw', .2) + wosc(f * .994, n, 'saw', .6)
    x = lp(x, 1500 + 2000 * vel, 2)
    return x * np.exp(-t / (dur * .55)) * np.minimum(1, t / .006) * .3


def bass_saw(f, dur, cut=600, vel=.8):
    n = int((dur + .05) * SR)
    t = np.arange(n) / SR
    x = wosc(f, n, 'saw') + .7 * wosc(f * .5, n, 'square') * 0 + .6 * sine(f * .5, n)
    lo = lp(x, cut * .5, 2)
    hi = lp(x, cut * 2.2, 2)
    mix = np.exp(-t / .09)
    y = lo * (1 - mix) + hi * mix
    return y * ar(n, .004, .05) * .5


def bass_sine(f, dur, vel=.8):
    n = int((dur + .3) * SR)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * f * t) + .35 * np.sin(4 * np.pi * f * t) + .12 * np.sin(6 * np.pi * f * t)
    return x * ar(n, .03, .3, 1.2) * .5


def brass(f, dur, vel=.8, att=.12):
    n = int((dur + .25) * SR)
    t = np.arange(n) / SR
    fv = f * (1 + .003 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t / .6))
    x = wosc(fv, n, 'saw') + .6 * wosc(fv * 1.005, n, 'saw', .4)
    a = lp(x, 500 + 200 * vel, 2)
    b = lp(x, 2500 + 1800 * vel, 2)
    e = np.minimum(1, t / (att * 1.6)) ** 1.5
    y = a * (1 - e) + b * e
    return y * ar(n, att, .22, 1.2) * .4


def pad_chord(freqs, dur, rel=2.0, att=1.2, cut=1800, rng=None, spread=7.0):
    """Nappe stereo : saws desaccordees (gauche/droite differentes) + filtre lent. Retourne (n,2)."""
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    for i, f in enumerate(freqs):
        for c, sgn in ((0, 1), (1, -1)):
            for d in (-1, 0, 1):
                fc = f * 2 ** ((d * spread * (1 + .3 * i % 3) + sgn * 2.5) / 1200)
                lfo = 1 + .0015 * np.sin(2 * np.pi * (.15 + .07 * i) * t + i + c)
                out[:, c] += wosc(fc * lfo, n, 'saw', rng.uniform() if rng is not None else 0) * (.34 if d == 0 else .22)
    out = lp(out, cut, 2)
    e = ar(n, att, rel, 1.4)
    return out * e[:, None] * (.9 / max(1, len(freqs)) ** .6) * .5


def choir(freqs, dur, rel=2.0, att=1.5, rng=None):
    """Choeur 'ah' : saws + formants parallèles. (n,2)"""
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    out = np.zeros((n, 2))
    rng = rng or np.random.default_rng(1)
    for i, f in enumerate(freqs):
        for c in (0, 1):
            vib = 1 + .006 * np.sin(2 * np.pi * (4.8 + .3 * i) * t + rng.uniform(0, 6))
            out[:, c] += wosc(f * vib * (1 + (c * 2 - 1) * .0035), n, 'saw', rng.uniform())
    form = (resonator(out, 700, 5) * 1.0 + resonator(out, 1150, 6) * .7 + resonator(out, 2600, 8) * .35 + lp(out, 500, 1) * .4)
    e = ar(n, att, rel, 1.4)
    return form * e[:, None] * (.8 / max(1, len(freqs)) ** .5)


def taiko(vel=.9, rng=None, f0=52, size=1.0):
    rng = rng or np.random.default_rng(3)
    n = int(1.6 * size * SR)
    t = np.arange(n) / SR
    sweep = f0 * (1 + 1.6 * np.exp(-t / .05))
    ph = np.cumsum(sweep) / SR
    body = np.sin(2 * np.pi * ph) * np.exp(-t / (.28 * size)) + .35 * np.sin(2 * np.pi * ph * 1.5) * np.exp(-t / .1)
    skin = bp(rng.normal(size=n), 150, 1200) * np.exp(-t / .045) * .55
    click = bp(rng.normal(size=n), 2500, 9000) * np.exp(-t / .006) * .22
    return (body + skin + click) * vel * np.minimum(1, t / .001) * .8


def tom(f=110, vel=.8, rng=None):
    rng = rng or np.random.default_rng(5)
    n = int(.7 * SR)
    t = np.arange(n) / SR
    ph = np.cumsum(f * (1 + .8 * np.exp(-t / .03))) / SR
    return (np.sin(2 * np.pi * ph) * np.exp(-t / .16) + bp(rng.normal(size=n), 300, 2200) * np.exp(-t / .03) * .5) * vel * .8


def shaker(vel=.5, rng=None, dur=.09, lo=5500):
    rng = rng or np.random.default_rng(7)
    n = int(dur * SR)
    t = np.arange(n) / SR
    return hp(rng.normal(size=n), lo, 2) * np.exp(-t / (dur * .35)) * np.minimum(1, t / .004) * vel * .25


def metal_hit(f=300, vel=.8, rng=None, dur=1.6):
    rng = rng or np.random.default_rng(int(f) % 997)
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for r, a, tau in ((1, 1, .9), (1.47, .8, .6), (2.09, .7, .5), (2.56, .6, .35), (3.41, .5, .25), (4.2, .4, .18), (5.3, .3, .12)):
        x += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6)) * np.exp(-t / (tau * dur / 1.6))
    x += bp(rng.normal(size=n), 1200, 9000) * np.exp(-t / .012) * .6
    return x * vel * .35 * np.minimum(1, t / .0008)


def noise_swell(dur, rng, lo=300, hi=7000, rise=True):
    """Montee de bruit filtre (riser) : coupure croissante, volume croissant."""
    n = int(dur * SR)
    x = rng.normal(size=n)
    blk = 2048
    zi = None
    out = np.zeros(n)
    for i in range(0, n, blk):
        frac = i / n
        fc = lo * (hi / lo) ** (frac if rise else 1 - frac)
        sos = signal.butter(2, [max(fc * .6, 40), min(fc * 1.6, SR * .45)], 'bandpass', fs=SR, output='sos')
        seg = x[i:i + blk]
        if zi is None:
            zi = np.zeros((sos.shape[0], 2))
        y, zi = signal.sosfilt(sos, seg, zi=zi)
        out[i:i + blk] = y
    env = (np.arange(n) / n) ** 2 if rise else np.exp(-np.arange(n) / (n * .25))
    return out * env


def cymbal(dur=2.5, rng=None, vel=.7):
    rng = rng or np.random.default_rng(11)
    n = int(dur * SR)
    t = np.arange(n) / SR
    x = hp(rng.normal(size=n), 4500, 2) + .6 * bp(rng.normal(size=n), 2500, 5200) * np.exp(-t / .5)
    return x * np.exp(-t / (dur * .3)) * np.minimum(1, t / .01) * vel * .12


def crackle_fire(N, rng, rate=14.0, loud=1.0):
    """Crepitements de feu : petites impulsions filtrees + grésillement. (N,) aleatoire, periodique via put circulaire."""
    buf = np.zeros(N)
    cnt = int(rate * N / SR)
    for _ in range(cnt):
        s = int(rng.uniform(0, N))
        L = int(rng.uniform(.002, .02) * SR)
        tt = np.arange(L) / SR
        f = rng.uniform(800, 5000)
        a = rng.uniform(.1, 1) ** 2 * loud
        seg = np.sin(2 * np.pi * f * tt + rng.uniform(0, 6)) * np.exp(-tt / rng.uniform(.0015, .006))
        seg += rng.normal(size=L) * np.exp(-tt / .003) * .6
        e = min(L, N - s)
        buf[s:s + e] += seg[:e] * a
        if L > e:
            buf[:L - e] += seg[e:] * a
    return buf

pan = ac.pan
