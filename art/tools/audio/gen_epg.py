"""EPREUVES_EPG (PROVISOIRE, écrit par Claude) : 12 sons des verbes d'Épreuve, mono 44,1 kHz Vorbis q5.

Sortie : game/assets/audio/epreuves/<id>.ogg ; manifeste : art/tools/audio/epg_manifest.json.
Déterministe (graines fixes). À remplacer par un lot Codex si le quota le permet (mêmes noms de fichiers).
Lancer : python gen_epg.py   (depuis art/tools/audio/).
"""
import json
from pathlib import Path
import numpy as np
import audio_common as ac
import synth_lib as sl

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/audio/epreuves'
SR = ac.SR
SEED = 4206100


def env_ad(n, a, tau):
    t = np.arange(n) / SR
    return (1 - np.exp(-t / max(a, 1e-4))) * np.exp(-t / tau)


def tone(f, n, partials=((1, 1.0),), tau=.3, a=.004):
    f = np.broadcast_to(np.asarray(f, dtype=float), (n,))
    ph = np.cumsum(f) / SR
    y = np.zeros(n)
    for r, amp in partials:
        y += amp * np.sin(2 * np.pi * ph * r)
    return y * env_ad(n, a, tau)


def bell_partials(base, n, tau, rng):
    y = np.zeros(n)
    for r, amp, d in ((1, 1, 1), (2.0, .6, .8), (2.76, .5, .7), (4.07, .35, .5), (5.4, .25, .4), (6.8, .15, .3)):
        y += tone(base * r * rng.uniform(.995, 1.005), n, ((1, amp),), tau * d, .002)
    return y


def noise_band(n, lo, hi, rng):
    return sl.bp(rng.normal(size=n), lo, hi)


def make(name, rng):
    if name == 'epreuve_start':
        n = int(1.2 * SR); t = np.arange(n) / SR
        sw = np.sin(np.pi * np.minimum(t / 1.2, 1)) ** 1.4
        y = sum(sl.lp(sl.wosc(f, n, 'saw'), 1100) * a for f, a in ((110, 1), (164.8, .7), (220, .5)))
        y = y * sw
        y += tone(880 * (1 + .02 * t), n, ((1, .3), (2, .1)), .5, .1) * .5
        return y
    if name == 'chase_jump':
        n = int(.45 * SR); t = np.arange(n) / SR
        w = noise_band(n, 800, 7000, rng) * np.sin(np.pi * t / .45) ** 1.5 * .8
        f = 500 * np.exp(t * 4.2)
        return w + tone(f, n, ((1, 1), (2, .25)), .22, .003) * .7
    if name == 'chase_warn':
        n = int(.55 * SR); y = np.zeros(n)
        for i, at in enumerate((0, .12, .22, .30, .37, .43)):
            k = int(at * SR); m = n - k
            y[k:] += tone(1560 * (1 - .05 * i), m, ((1, 1), (2.76, .3)), .05, .001) * (1 - .1 * i)
        return y
    if name == 'chase_point':
        n = int(.75 * SR); y = np.zeros(n)
        for at, f in ((0, 784), (.09, 1175)):
            k = int(at * SR)
            y[k:] += tone(f, n - k, ((1, 1), (2, .3), (3.01, .15)), .28, .002)
        return y
    if name == 'chase_miss':
        n = int(.65 * SR); t = np.arange(n) / SR
        f = 220 * np.exp(-t * 1.6)
        return tone(f, n, ((1, 1), (1.5, .5), (2.1, .3)), .22, .004) + noise_band(n, 150, 900, rng) * env_ad(n, .003, .06) * .6
    if name == 'vein_tick':
        n = int(.28 * SR); t = np.arange(n) / SR
        return tone(70 * np.exp(-t * 6) + 40, n, ((1, 1), (2, .3)), .09, .002) * 1.2 + noise_band(n, 200, 1200, rng) * env_ad(n, .002, .02) * .3
    if name == 'vein_geyser_warn':
        n = int(1.0 * SR); t = np.arange(n) / SR
        u = t / 1.0
        rumble = noise_band(n, 50, 1300, rng) * (.2 + .8 * u ** 1.5)
        rumble = sl.lp(rumble, 200 + 1800 * 0.6)
        return rumble * 1.4 + tone(55 + 40 * u, n, ((1, 1), (2, .4)), 5, .05) * (.3 + .7 * u)
    if name == 'vein_geyser':
        n = int(1.3 * SR); t = np.arange(n) / SR
        boom = tone(60 * np.exp(-t * 2.5) + 25, n, ((1, 1), (2, .3)), .35, .003)
        hiss = noise_band(n, 400, 9000, rng) * env_ad(n, .01, .22)
        return boom * 1.2 + hiss * .9
    if name == 'hold_side':
        n = int(.85 * SR); t = np.arange(n) / SR
        f = 196 * (1 + .06 * np.minimum(t / .12, 1))
        horn = sl.lp(sl.wosc(f, n, 'saw'), 1400) + .5 * sl.lp(sl.wosc(f * 1.5, n, 'saw'), 1000)
        return horn * np.minimum(t / .06, 1) * np.exp(-np.maximum(t - .4, 0) / .18)
    if name == 'hold_bell_hit':
        n = int(.6 * SR)
        return bell_partials(330, n, .25, rng) + noise_band(n, 1500, 8000, rng) * env_ad(n, .001, .012) * .5
    if name == 'hold_bell_dim':
        n = int(1.45 * SR); t = np.arange(n) / SR
        f = 262 * np.exp(-t * .38)
        y = np.zeros(n)
        for r, amp, d in ((1, 1, 1), (2.0, .5, .8), (2.76, .4, .6), (4.07, .2, .4)):
            y += tone(f * r, n, ((1, amp),), .6 * d, .003)
        return sl.lp(y, 2500)
    if name == 'hold_bell_ring':
        n = int(3.0 * SR)
        y = bell_partials(262, n, 1.1, rng) + noise_band(n, 1200, 9000, rng) * env_ad(n, .001, .015) * .5
        return ac.reverb(y, rng, .35, .25)
    raise KeyError(name)


NAMES = ['epreuve_start', 'chase_jump', 'chase_warn', 'chase_point', 'chase_miss', 'vein_tick',
         'vein_geyser_warn', 'vein_geyser', 'hold_side', 'hold_bell_hit', 'hold_bell_dim', 'hold_bell_ring']
MAXDUR = {n: 1.5 for n in NAMES}
MAXDUR['hold_bell_ring'] = 3.0
RMS = {'vein_tick': -26, 'hold_bell_ring': -22, 'epreuve_start': -20}


def main():
    rows = []
    for i, name in enumerate(NAMES):
        rng = np.random.default_rng(SEED + i)
        x = np.nan_to_num(make(name, rng))
        x = x[:int(MAXDUR[name] * SR)]
        x = sl.hp(x, 30)
        x = ac.fade(ac.normalize(x, RMS.get(name, -21), -2.5), 4)
        ac.write_ogg(OUT / f'{name}.ogg', x)
        rows.append({'id': name, 'path': f'epreuves/{name}.ogg', 'seed': SEED + i, 'duration_s': round(len(x) / SR, 3),
                     'peak_dbfs': round(ac.peak_db(x), 2), 'rms_dbfs': round(ac.rms_db(x), 2)})
        print(rows[-1])
    Path(__file__).with_name('epg_manifest.json').write_text(json.dumps(rows, indent=1), encoding='utf-8')


if __name__ == '__main__':
    main()
