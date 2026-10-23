"""Rainfall impacts: entirely procedural layers, deterministic per-variant seeds.

Run: uv run --with numpy --with scipy python art/tools/audio/gen_impacts.py
"""
import argparse
import json
import subprocess
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac

ROOT = Path(__file__).resolve().parents[3]
SPECS = {
    'hit_normal': (.16, 'light', 'Impact physique courant sur un monstre', -1),
    'hit_crit': (.39, 'heavy', 'Coup critique, fracture et poids grave', -2),
    'status_burn': (.30, 'light', 'Tick de brûlure crépitant', -4),
    'status_poison': (.38, 'light', 'Tick de poison, bulle acide visqueuse', -4),
    'status_frost': (.43, 'light', 'Cristallisation et brisure de givre', -4),
    'lightning_chain': (.56, 'medium', 'Sauts successifs de foudre en chaîne', -3),
    'death_tier1': (.23, 'light', 'Petit éclatement de monstre de tier 1', -2),
    'death_tier2': (.38, 'medium', 'Effondrement de monstre de tier 2', -2),
    'death_tier3': (.61, 'heavy', 'Effondrement massif de monstre de tier 3', -3),
    'death_elite': (.94, 'heavy', 'Mort élite avec résonance sombre', -4),
    'death_boss': (2.65, 'heavy', 'Mort de boss, ruptures puis effondrement grave', -5),
    'enemy_contact': (.18, 'light', 'Contact ou morsure ennemie', -2),
    'enemy_shot': (.26, 'medium', 'Départ de projectile ennemi mat', -3),
    'enemy_brute_cone': (.60, 'heavy', 'Souffle et rugissement large de la brute', -4),
    'enemy_shockwave': (1.02, 'heavy', 'Onde de choc grave et déferlement', -5),
    'telegraph_warn_light': (.78, 'light', 'Alerte de danger léger, tension croissante', -5),
    'telegraph_warn_heavy': (1.10, 'heavy', 'Alerte de danger lourd, tension croissante', -5),
    'telegraph_boss': (1.78, 'heavy', 'Annonce grave de danger de boss', -6),
    'player_hurt': (.30, 'medium', 'Joueur blessé, chair et souffle grave', -1),
    'player_death': (1.50, 'heavy', 'Mort du joueur, souffle et résonance descendante', -3),
    'player_heal': (.70, 'none', 'Soin doux, résonances lumineuses feutrées', -5),
}


def decode_exact(path):
    """Respect the Ogg granule duration; raw ffmpeg output may include packet padding."""
    info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(path)]))['streams'][0]
    count = round(float(info['duration'])*ac.SR)
    x = ac.decode(path)[:count]
    if len(x)<count:
        x = np.pad(x, ((0,count-len(x)),(0,0)))
    return x, info


def synth(name, duration, rng):
    n = round(duration * ac.SR)
    t = np.arange(n) / ac.SR
    pitch = rng.uniform(.94, 1.06)
    def tone(freq, tau, amp=1, fall=0):
        f = pitch * (freq + fall*np.exp(-t/.028))
        return amp * ac.osc(f) * np.exp(-t/tau)
    def grit(lo, hi, tau, amp=1):
        return amp * ac.filt(ac.noise(n, rng), [lo, hi], 'bandpass') * np.exp(-t/tau)
    def burst(at, length, lo, hi, amp=1):
        k = min(n-1, round(at*ac.SR)); m = min(n-k, max(8, round(length*ac.SR)))
        z = ac.filt(ac.noise(m, rng), [lo, hi], 'bandpass')
        z *= np.exp(-np.arange(m)/(max(1, m/4)))
        out = np.zeros(n); out[k:k+m] = ac.fade(z, 2)*amp
        return out
    # Short dull transient, pressure body, and fine upper texture are separate layers.
    x = tone(105, .045, .55, 170) + grit(350, 2400, .025, .7)
    width, wet = .08, .08
    if name in ('hit_normal', 'enemy_contact'):
        x += grit(650, 6200, .018, .55) + tone(220, .025, .2, 290)
        if name == 'enemy_contact':
            x += burst(.017, .055, 600, 3200, .7)
    elif name == 'hit_crit':
        x = tone(53, .13, 1, 90) + tone(135, .06, .35, 240)
        x += grit(1400, 11000, .012, 1.8) + grit(130, 2100, .075, 1)
        x += burst(.021, .05, 2300, 10500, .8)
        wet = .12
    elif name == 'status_burn':
        x = grit(450, 6800, .16, .25)
        for at in sorted(rng.uniform(.005, .23, 13)):
            x += burst(at, rng.uniform(.012, .045), 1100, 10000, rng.uniform(.4, 1))
        width = .22
    elif name == 'status_poison':
        x = grit(180, 1600, .12, .35)
        for at, freq in zip((0, .065, .14), (470, 330, 620)):
            local = np.maximum(t-at, 0)
            env = (t>=at)*np.exp(-local/.055)*(1-np.exp(-local/.003))
            f = freq*pitch*(.4+.6*np.exp(-local/.018))
            x += ac.osc(f)*env*.7
        x += burst(.04, .06, 1300, 4300, .35)
    elif name == 'status_frost':
        x = grit(2100, 10500, .028, .8)
        for freq in (1730, 2693, 4021, 5939):
            x += tone(freq, rng.uniform(.06, .13), .15)* (1-np.exp(-t/.002))
        for at in (.032, .07, .12): x += burst(at, .025, 3000, 12000, .4)
        width, wet = .35, .18
    elif name == 'lightning_chain':
        x = np.zeros(n)
        for i, at in enumerate((0, .095, .21, .34)):
            local = np.maximum(t-at, 0)
            env = (t>=at)*np.exp(-local/.04)*(1-np.exp(-local/.0015))
            carrier = (580, 1320, 740, 1880)[i]*pitch
            phase = 2*np.pi*carrier*t+3*np.sin(2*np.pi*carrier*.73*t)
            x += .45*np.sin(phase)*env + burst(at, .08, 1000, 11000, 1)
        x += tone(67, .13, .4, 80)
        width, wet = .5, .15
    elif name.startswith('death_'):
        tier = {'death_tier1': 1, 'death_tier2': 2, 'death_tier3': 3, 'death_elite': 4, 'death_boss': 6}[name]
        tau = duration*.22
        x = tone(105-tier*9, tau, .8, 120) + grit(90, 3400-tier*260, tau, 1.1)
        x += grit(1400, 9000, .018, .8)
        for at in np.sort(rng.uniform(.03, duration*.57, tier*3)):
            x += burst(at, .05+tier*.015, 180, 4200, rng.uniform(.3, .75))
        if tier >= 4:
            for freq in (47, 83, 139, 227):
                x += tone(freq, duration*.32, .22)*(1-np.exp(-t/.012))
        if tier == 6:
            for at in (.26, .64, 1.08):
                local = np.maximum(t-at, 0)
                x += .65*np.sin(2*np.pi*(38*local+2*(1-np.exp(-local/.05))))*(t>=at)*np.exp(-local/.3)*(1-np.exp(-local/.007))
        width, wet = .18+tier*.04, .12+tier*.025
    elif name == 'enemy_shot':
        x = tone(115, .065, .7, 240) + grit(180, 1800, .05, 1.4)
        x += grit(550, 2800, .085, .3)
    elif name == 'enemy_brute_cone':
        env = (1-np.exp(-t/.028))*np.exp(-t/.17)
        breath = ac.filt(ac.noise(n, rng, 'pink'), [100, 2600], 'bandpass')
        growl = ac.osc(72*pitch+9*np.sin(2*np.pi*29*t), kind='saw')
        x = (breath*1.8+ac.filt(growl, 850)*.6)*env
        x += burst(.018, .08, 300, 2400, .6)
        width, wet = .6, .15
    elif name == 'enemy_shockwave':
        env = (1-np.exp(-t/.012))*np.exp(-t/.23)
        x = tone(39, .31, .85, 85)+grit(45, 800, .3, 1.1)
        x += ac.filt(ac.noise(n, rng, 'pink'), [150, 3800], 'bandpass')*env*(.6+.3*np.sin(2*np.pi*4*t))
        width, wet = .55, .2
    elif name.startswith('telegraph'):
        heavy = name != 'telegraph_warn_light'
        u = t/duration
        base = 48 if name=='telegraph_boss' else (78 if heavy else 155)
        f = pitch*base*(1+.55*u*u)
        env = np.sin(np.pi*np.minimum(u/.97, 1)/2)**1.4 * np.minimum((1-u)/.07, 1)
        x = .4*ac.osc(f)+.22*ac.osc(f*1.043)+.15*ac.osc(f*2.51)
        x += .45*ac.filt(ac.noise(n, rng, 'pink'), [130, 2100], 'bandpass')
        x *= env*(.8+.2*np.sin(2*np.pi*(3*t+4*t*t)))
        width, wet = .4, .17
    elif name == 'player_hurt':
        x = tone(83, .085, .75, 105)+grit(120, 2300, .045, 1.1)
        x += grit(70, 700, .09, .65)+tone(137, .11, .12)
    elif name == 'player_death':
        x = tone(65, .3, .8, 100)+grit(110, 2200, .2, 1)
        f = pitch*(48+110*np.exp(-t/.23))
        x += .4*ac.osc(f)*np.exp(-t/.42)
        x += grit(180, 1200, .4, .5)*(1-np.exp(-t/.04))
        width, wet = .4, .25
    elif name == 'player_heal':
        x = np.zeros(n)
        for i, freq in enumerate((392, 587.33, 783.99, 1174.66)):
            at = i*.045; local = np.maximum(t-at, 0)
            env = (t>=at)*(1-np.exp(-local/.018))*np.exp(-local/.14)
            x += np.sin(2*np.pi*freq*pitch*t)*env*(.4/(1+i*.5))
        x += grit(1000, 4000, .19, .06)*(1-np.exp(-t/.02))
        width, wet = .5, .2
    x = ac.filt(x, 28, 'highpass', order=2)
    x = ac.saturate(x, 1.25)
    x = ac.stereo(x, width)
    x = ac.reverb(x, rng, decay=min(.16, duration*.19), wet=wet)
    x = ac.fade(x, 4)
    # Tame crest factor gently, keeping the transient, for consistent useful RMS.
    for _ in range(3):
        if ac.peak_db(x)-ac.rms_db(x) < 16: break
        x = np.tanh(x/(np.std(x)*3.3+1e-12))
    # Codec guard silence plus a 5 ms fade prevents transform pre/post-ringing
    # from exposing a nonzero sample at an asset boundary.
    start, end = round(.003*ac.SR), n-round(.008*ac.SR)
    x[:start] = 0
    x[end:] = 0
    x[start:end] = ac.fade(x[start:end], 5)
    return ac.normalize(x, target_rms=-18.3, peak=-2.6)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=ROOT/'game/assets/audio/impacts')
    parser.add_argument('--seed', type=int, default=84127)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    rows = []
    for index, (name, (base_duration, level, usage, gain)) in enumerate(SPECS.items()):
        for variant in range(1, (3 if name=='death_boss' else 4)+1):
            variant_seed = np.random.SeedSequence([args.seed, index, variant])
            rng = np.random.default_rng(variant_seed)
            duration = base_duration * (rng.uniform(.96, 1.04) if name not in ('status_burn', 'player_hurt', 'player_death', 'enemy_brute_cone') else 1)
            path = args.out / f'{name}_{level}_{variant:02d}.ogg'
            x = synth(name, duration, rng)
            ac.write_ogg(path, x, quality=6)
            decoded, _ = decode_exact(path)
            # Check encoded true peak; leave additional headroom if codec overshoots.
            true_peak = ac.peak_db(signal.resample_poly(decoded, 4, 1, axis=0))
            if true_peak > -1.5:
                x *= 10**((-1.7-true_peak)/20)
                ac.write_ogg(path, x, quality=6)
                decoded, _ = decode_exact(path)
            rows.append(dict(path=f'impacts/{path.name}', duration_s=round(len(decoded)/ac.SR, 6),
                             loop=False, level=level, usage=usage, gain_db=gain,
                             peak_dbfs=round(ac.peak_db(decoded), 3), rms_dbfs=round(ac.rms_db(decoded), 3)))
        print(f'{name}: {variant} variantes', flush=True)
    manifest = Path(__file__).with_name('impacts_manifest.json')
    manifest.write_text(json.dumps(rows, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print(f'{len(rows)} fichiers; manifeste: {manifest}')


if __name__ == '__main__':
    main()
