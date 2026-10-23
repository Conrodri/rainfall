"""Verify decoded extra assets, including codec true peaks and loop seams."""
import argparse
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import gen_impacts as impacts
import gen_footsteps as steps

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[3]/'game/assets/audio')
    a=p.parse_args()
    rows=json.loads(Path(__file__).with_name('extra_manifest.json').read_text(encoding='utf-8'))
    failures=[]; durations=[]; peaks=[]; rms={'impacts':[],'footsteps':[]}
    for r in rows:
        path=a.out/r['path']; x,info=impacts.decode_exact(path)
        mono=r['path'].startswith('footsteps/')
        if mono: x=steps.decode_mono(path)[:round(float(info['duration'])*ac.SR)]
        duration=float(info['duration']); durations.append(duration)
        peak=ac.peak_db(signal.resample_poly(x,4,1,axis=0)); peaks.append(peak)
        family=r['path'].split('/')[0]; value=ac.rms_db(x); rms[family].append(value)
        def check(ok,reason):
            if not ok: failures.append(f'{path.name}: {reason}')
        check(int(info['sample_rate'])==44100,'sample rate')
        check(int(info['channels'])==(1 if mono else 2),'channels')
        check(abs(duration-r['duration_s'])<2/ac.SR,'manifest duration')
        check(np.isfinite(x).all(),'nonfinite audio')
        check(peak<=-1.5,'true peak exceeds -1.5 dBTP')
        check(abs(ac.peak_db(x)-r['peak_dbfs'])<.03,'manifest peak')
        check(abs(value-r['rms_dbfs'])<.03,'manifest RMS')
        target=-26 if mono else -20 if path.name.startswith('stage_cleared') else -18
        check(abs(value-target)<1.5,'RMS target')
        if mono: check(.06<=duration<=.25,'footstep duration')
        for prefix,lo,hi in [('death_t4',1.5,2),('boss_spawn',3,4),('boss_defeat',4,5),('stage_cleared',2,3)]:
            if path.name.startswith(prefix): check(lo<=duration<=hi,'event duration')
        if r['loop']:
            diff=np.diff(x,axis=0)
            seam=np.max(np.abs(x[0]-x[-1]))
            check(seam<1e-4,'loop sample discontinuity')
            check(seam<=max(1e-6,4*np.sqrt(np.mean(diff*diff))),'loop derivative')
        else:
            check(max(np.max(np.abs(x[:44])),np.max(np.abs(x[-44:])))<.001,'boundary click risk')
    check_count=len(rows)==126
    if not check_count: failures.append('expected 126 assets')
    report=dict(files=len(rows),total_duration_s=sum(durations),duration_range_s=[min(durations),max(durations)],
                maximum_true_peak_dbfs=max(peaks),rms_ranges_dbfs={k:[min(v),max(v)] for k,v in rms.items()},
                loops=sum(r['loop'] for r in rows),failures=failures)
    Path(__file__).with_name('extra_verification.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))
    if failures: raise SystemExit(1)
if __name__=='__main__': main()
