"""PASS/FAIL checks for the 12 EP-G Epreuves cues."""
import json
from pathlib import Path

import numpy as np
from scipy import signal

import audio_common as ac
from gen_epg_codex import SPECS

ROOT=Path(__file__).resolve().parents[3]
MANIFEST=Path(__file__).with_name('epg_manifest.json')


def fail(message):
    raise SystemExit('FAIL: '+message)


def main():
    rows=json.loads(MANIFEST.read_text(encoding='utf-8'))
    if len(rows)!=12: fail(f'manifest count {len(rows)}')
    by={r['id']:r for r in rows}
    if set(by)!={s[0] for s in SPECS}: fail('manifest ids')
    for name,duration,target in SPECS:
        r=by[name]; p=ROOT/'game/assets/audio/epreuves'/f'{name}.ogg'
        if not p.is_file(): fail('missing '+p.name)
        y=ac.decode(p,channels=1)
        if y.ndim!=2 or y.shape[1]!=1 or len(y)==0: fail('format '+p.name)
        dur=len(y)/ac.SR
        if abs(dur-duration)>.025: fail(f'duration {p.name} {dur:.4f}')
        tp=ac.peak_db(signal.resample_poly(y[:,0],4,1))
        rms=ac.rms_db(y[:,0])
        if tp>-1.5: fail(f'true peak {p.name} {tp:.2f} dBFS')
        if not -24<=rms<=-18: fail(f'RMS {p.name} {rms:.2f} dBFS')
        if np.max(np.abs(y))<1e-5 or np.std(y)<1e-5: fail('silent '+p.name)
        # Boundary samples and first/last 5 ms must not contain a discontinuity/pop.
        edge=max(1,round(.005*ac.SR)); dy=np.abs(np.diff(y[:,0]))
        if abs(float(y[0,0]))>.02 or abs(float(y[-1,0]))>.02: fail('nonzero edge '+p.name)
        if np.max(dy[:edge])>.12 or np.max(dy[-edge:])>.12: fail('edge click '+p.name)
        r['measured_duration_s']=round(dur,6); r['measured_true_peak_dbfs']=round(tp,3)
        r['measured_rms_dbfs']=round(rms,3)
    extras=list((ROOT/'game/assets/audio/epreuves').glob('*.ogg'))
    epg={p.name for p in extras if p.stem in by}
    if len(epg)!=12: fail(f'ogg count {len(epg)}')
    MANIFEST.write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    print('PASS: 12 mono 44.1 kHz Vorbis q5; durations, peak, RMS, silence, edges')


if __name__=='__main__': main()
