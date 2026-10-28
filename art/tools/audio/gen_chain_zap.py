"""Deterministic procedural chain discharges; no samples or reverb."""
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl
from gen_impacts import ROOT, decode_exact

SPECS = {
    'lightning.zap.light': ((.118, .129, .142, .155, .167), -18., 'light', 'Rebond de foudre en chaine'),
    'lightning.chain_start.medium': ((.238, .278), -17., 'medium', 'Depart de la chaine de foudre'),
}


def useful_rms(x):
    blocks = [x[i:i+882] for i in range(0, len(x), 882)]
    active = [b for b in blocks if ac.rms_db(b) > -35]
    return ac.rms_db(np.concatenate(active)) if active else -120.


def synth(duration, heavy, rng):
    n = round(duration*ac.SR)
    t = np.arange(n)/ac.SR
    carrier = rng.uniform(1500, 3000)
    body = rng.uniform(.030, .060)
    env = np.exp(-t/(body/2.8)) * np.minimum(t/.0003, 1)
    arc = np.sin(2*np.pi*carrier*t + (3.8*np.exp(-t/.028)+.6)*
                 np.sin(2*np.pi*carrier*rng.uniform(.65, 1.4)*t))
    noise = sl.bp(rng.normal(size=n), 2000, 11000)
    x = .6*arc*env + .48*noise*np.exp(-t/(.025 if heavy else .017))
    # Broadband discharge starts immediately; random sparks keep the tail granular.
    x += .85*rng.normal(size=n)*np.exp(-t/.00065)
    sparks = np.zeros((n, 2))
    for at in np.sort(rng.uniform(.002, duration*.76, 29 if heavy else 16)):
        k = round(at*ac.SR)
        m = min(n-k, round(rng.uniform(.0006, .0028)*ac.SR))
        z = sl.bp(rng.normal(size=m), 2400, 11000)
        z *= np.exp(-np.arange(m)/(m/4))*rng.uniform(.25, .8)*np.exp(-at/(duration*.27))
        sparks[k:k+m] += ac.pan(z, rng.uniform(-.5, .5))
    tail = sl.bp(rng.normal(size=n), 3800, 11000)
    x += .11*tail*np.exp(-t/(duration*.20))*(.25+.75*np.sin(2*np.pi*330*t)**8)
    # Hard 20 ms support prevents bass buildup between 40 ms rebounds.
    bass_env = np.maximum(1-t/.020, 0)**2
    x += (.65 if heavy else .16)*np.sin(2*np.pi*rng.uniform(60, 90)*t)*bass_env
    if heavy:
        x += .6*sl.bp(rng.normal(size=n), 450, 8500)*np.exp(-t/.009)
    y = np.column_stack((x, x)) + sparks
    y = np.tanh(y*1.15)
    y[:9] *= np.linspace(0, 1, 9)[:, None]
    y[-353:] *= np.linspace(1, 0, 353)[:, None]
    # One millisecond codec guard; discharge still reaches its peak before 2 ms.
    y = np.vstack((np.zeros((44, 2)), y[:-44]))
    return y


def main():
    out = ROOT/'game/assets/audio/impacts'
    out.mkdir(parents=True, exist_ok=True)
    rows = []
    for group, (ident, (durations, target, level, usage)) in enumerate(SPECS.items()):
        for variant, duration in enumerate(durations, 1):
            rng = np.random.default_rng(np.random.SeedSequence([731409, group, variant]))
            x = synth(duration, group == 1, rng)
            x *= 10**((target-useful_rms(x))/20)
            path = out/f'{ident.replace(".", "_")}_{variant:02d}.ogg'
            for attempt in range(4):
                ac.write_ogg(path, x, quality=5)
                decoded, _ = decode_exact(path)
                peak = ac.peak_db(signal.resample_poly(decoded, 4, 1, axis=0))
                if peak <= -1.5:
                    break
                x *= 10**((-1.8-peak)/20)
            else:
                raise RuntimeError(f'Encoded peak: {path}')
            rows.append(dict(path=f'impacts/{path.name}', duration_s=round(len(decoded)/ac.SR, 6),
                             loop=False, level=level, usage=usage, gain_db=0,
                             peak_dbfs=round(ac.peak_db(decoded), 3), rms_dbfs=round(ac.rms_db(decoded), 3)))
    Path(__file__).with_name('chain_zap_manifest.json').write_text(
        json.dumps(rows, indent=2, ensure_ascii=False)+'\n', encoding='utf-8')
    print('PASS: 7 Ogg Vorbis q5')


if __name__ == '__main__':
    main()
