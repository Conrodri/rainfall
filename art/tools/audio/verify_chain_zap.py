"""Verify decoded assets and seven semitone-stepped, 40 ms spaced hits."""
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from scipy import signal
import audio_common as ac
from gen_impacts import ROOT, decode_exact
from gen_chain_zap import SPECS, useful_rms


def main():
    rows = json.loads(Path(__file__).with_name('chain_zap_manifest.json').read_text(encoding='utf-8'))
    errors, report, groups = [], [], {}
    if len(rows) != 7:
        errors.append('Expected 7 variants')
    for ident, (durations, target, level, _) in SPECS.items():
        clips = []
        expected = [f'impacts/{ident.replace(".", "_")}_{i:02d}.ogg' for i in range(1, len(durations)+1)]
        selected = [r for r in rows if r['path'] in expected]
        if sorted(r['path'] for r in selected) != expected:
            errors.append(f'{ident}: missing/duplicate variants')
        for row in selected:
            x, info = decode_exact(ROOT/'game/assets/audio'/row['path'])
            duration = len(x)/ac.SR
            peak = ac.peak_db(signal.resample_poly(x, 4, 1, axis=0))
            rms = useful_rms(x)
            bounds = (.110, .170) if level == 'light' else (.220, .300)
            onset = np.flatnonzero(np.max(np.abs(x), axis=1) > np.max(np.abs(x))*.2)
            checks = dict(rate=int(info['sample_rate']) == 44100, stereo=info['channels'] == 2,
                          codec=info['codec_name'] == 'vorbis', finite=bool(np.isfinite(x).all()),
                          duration=bounds[0] <= duration <= bounds[1], true_peak=peak <= -1.5,
                          useful_rms=abs(rms-target) <= 1.5, attack=bool(len(onset) and onset[0]/ac.SR < .002),
                          manifest=abs(ac.rms_db(x)-row['rms_dbfs']) < .01,
                          tail_edge=float(np.max(np.abs(x[-1]))) < .012)
            failed = [k for k, v in checks.items() if not v]
            if failed:
                errors.append(dict(path=row['path'], failed=failed))
            report.append(dict(path=row['path'], duration_s=duration, true_peak_dbfs=peak,
                               useful_rms_dbfs=rms, checks=checks))
            clips.append(x)
        for a in range(len(clips)):
            for b in range(a):
                n = min(len(clips[a]), len(clips[b]))
                corr = abs(float(np.corrcoef(clips[a][:n].ravel(), clips[b][:n].ravel())[0, 1]))
                if corr > .8:
                    errors.append(f'{ident}: variants correlated {corr:.3f}')
        groups[ident] = clips
    clips = groups['lightning.zap.light']
    stack = np.zeros((ac.SR, 2))
    for i in range(7):
        x = clips[i % len(clips)]
        speed = 2**(i/12)
        position = np.arange(0, len(x)-1, speed)
        shifted = np.column_stack([np.interp(position, np.arange(len(x)), x[:, c]) for c in range(2)])
        k = round(i*.04*ac.SR)
        stack[k:k+len(shifted)] += shifted
    stack_peak = ac.peak_db(signal.resample_poly(stack, 4, 1, axis=0))
    if stack_peak > -1.5:
        errors.append(f'Seven-hit stack peak {stack_peak:.3f}')
    result = dict(passed=not errors, count=len(rows), stack_true_peak_dbfs=stack_peak, errors=errors, files=report)
    Path(__file__).with_name('chain_zap_verification.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(('FAIL' if errors else 'PASS')+f': {len(rows)} variants; stack {stack_peak:.2f} dBTP')
    for error in errors:
        print(error)
    if errors:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
