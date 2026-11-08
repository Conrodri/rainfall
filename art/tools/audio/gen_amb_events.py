"""Deterministic cave wind events and circular wooden waterwheel ambience."""
import sys
sys.dont_write_bytecode = True
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl

SR = 44100
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/audio/ambience'


def noise(n, rng, lo, hi):
    return sl.loop_noise(n, rng, lambda f: (1 - np.exp(-(f / lo)**4)) * np.exp(-(f / hi)**4))


def master(x, rms, peak):
    x = x - np.mean(x, axis=0)
    # Smooth saturation only when necessary, preserving the event envelope.
    for _ in range(12):
        x *= 10**((rms - ac.rms_db(x))/20)
        if ac.peak_db(x) <= peak:
            break
        ceiling = 10**(peak/20)
        x = ceiling * np.tanh(x / ceiling)
    return x


def gust(index):
    rng = np.random.default_rng(8100 + index)
    duration = (3.6, 4.0, 4.4)[index-1]
    n = round(duration * SR)
    t = np.arange(n) / SR
    low = noise(n, rng, 40, 175)
    high = noise(n, rng, 65, 400)
    sweep = .5 - .5*np.cos(2*np.pi*t/duration)
    body = low*(1-sweep) + high*sweep
    whistle = noise(n, rng, 1050, 1900)
    mono = body + .035*whistle
    env = np.interp(t, [0, 1, duration/2, duration-1.5, duration], [0, .57, 1, .85, 0])
    env *= .86 + .14*np.sin(2*np.pi*.65*t + index)
    env *= np.minimum(1, t/.08)**2 * np.minimum(1, (duration-t)/.08)**2
    x = np.column_stack((mono, .94*np.roll(mono, 137) + .06*high))*env[:, None]
    x = master(x, -22, -5.5)
    x = ac.fade(x, 20)
    return x


def wrap(buf, event, start, position=0):
    idx = (np.arange(len(event)) + round(start*SR)) % len(buf)
    np.add.at(buf, idx, ac.pan(event, position))


def noria():
    rng = np.random.default_rng(92419)
    n = 8*SR
    t = np.arange(n)/SR
    stream = np.column_stack([noise(n, rng, 2000, 6000) for _ in range(2)])
    x = .065*stream*(.85+.15*np.cos(2*np.pi*t/4))[:, None]
    # Integrated sinusoidal FM: integer carrier cycles over the 8 s period.
    phase = 2*np.pi*445*t + 34*np.sin(2*np.pi*t/4)
    axle = (np.sin(phase)+.3*np.sin(2*phase))*(.16+.13*(.5+.5*np.sin(2*np.pi*t/4))**4)
    x += ac.pan(axle, -.12)
    for start in (.15, 2.15, 4.15, 6.15):
        u = np.arange(round(1.35*SR))/SR
        envelope = (1-np.exp(-u/.025))*np.exp(-u/.24)
        splash = noise(len(u), rng, 500, 5200)*envelope*.65
        creak = sum(np.sin(2*np.pi*f*u + 5*np.sin(2*np.pi*1.6*u))/k for k, f in enumerate((103, 211, 327), 1))
        creak *= (1-np.exp(-u/.012))*np.exp(-u/.34)*.65
        event = splash + creak
        event *= np.minimum(1, (u[-1]-u)/.05)**2
        wrap(x, event, start, rng.uniform(-.45, .45))
    for start in rng.uniform(0, 8, 52):
        u = np.arange(round(.3*SR))/SR
        drop = .09*np.sin(2*np.pi*(rng.uniform(950, 2100)*u + 95*(1-np.exp(-u/.025))))
        drop *= (1-np.exp(-u/.002))*np.exp(-u/.045)
        drop *= np.minimum(1, (u[-1]-u)/.025)**2
        wrap(x, drop, start, rng.uniform(-.8, .8))
    return master(x, -24, -7)


def verify(path, source, loop):
    x = ac.decode(path)
    rms = ac.rms_db(x)
    peak = ac.peak_db(x)
    result = dict(samples=len(x), sample_rate=SR, channels=x.shape[1], seconds=len(x)/SR,
                  bytes=path.stat().st_size, peak_dbfs=round(peak, 3), rms_dbfs=round(rms, 3))
    checks = [len(x)==len(source), x.shape[1]==2, peak < -1, path.stat().st_size < 300000]
    if loop:
        d = np.diff(x, axis=0)
        seam = x[0]-x[-1]
        curvature = np.diff(x, n=2, axis=0)
        seam_curvature = np.stack((seam-d[-1], d[0]-seam))
        drms = np.sqrt(np.mean(d*d, axis=0))
        crms = np.sqrt(np.mean(curvature*curvature, axis=0))
        result.update(seam_abs=np.abs(seam).tolist(), derivative_rms=drms.tolist(),
                      seam_derivative_ratio=(np.abs(seam)/drms).tolist(),
                      seam_curvature_ratio=(np.abs(seam_curvature)/crms).tolist())
        checks += [len(x)==352800, -10 <= peak <= -5, abs(rms+24)<1,
                   np.max(np.abs(seam)/drms)<5, np.max(np.abs(seam_curvature)/crms)<5]
    else:
        active = x[np.max(np.abs(source), axis=1) > np.max(np.abs(source))*.02]
        result['active_rms_dbfs'] = round(ac.rms_db(active), 3)
        result['edge_peak_dbfs'] = round(ac.peak_db(x[[0, -1]]), 3)
        checks += [3.6 <= len(x)/SR <= 4.4, -8 <= peak <= -4,
                   abs(ac.rms_db(active)+22)<2, np.max(np.abs(x[[0, -1]]))<.001]
        assert np.all(source[[0, -1]] == 0)
    result['pass'] = bool(all(checks))
    return result


def main():
    report = {}
    for i in range(1, 5):
        loop = i == 4
        name = 'amb_noria_01' if loop else f'amb_gust_{i:02d}'
        x = noria() if loop else gust(i)
        path = OUT / (name+'.ogg')
        ac.write_ogg(path, x, quality=5)
        report[path.name] = verify(path, x, loop)
    passed = all(v['pass'] for v in report.values())
    Path(__file__).with_name('amb_events_verification.json').write_text(
        json.dumps(dict(passed=passed, files=report), indent=2)+'\n', encoding='utf-8')
    print(('PASS' if passed else 'FAIL') + ': 4 stereo Vorbis assets; amb_events_verification.json')
    if not passed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
