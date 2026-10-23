"""Verify encoded footsteps, including true peaks and silent one-shot boundaries."""
import argparse
import json
import subprocess
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
from gen_footsteps import decode_mono
ROOT=Path(__file__).resolve().parents[3]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out',type=Path,default=ROOT/'game/assets/audio/footsteps')
    p.add_argument('--seed',type=int,default=73421,help='Reserved for reproducible CLI compatibility')
    args=p.parse_args()
    manifest=json.loads((Path(__file__).parent/'footsteps_manifest.json').read_text(encoding='utf-8'))
    results=[]; failures=[]
    for item in manifest:
        path=args.out/Path(item['path']).name
        info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(path)]))['streams'][0]
        x=decode_mono(path); duration=len(x)/ac.SR
        true_peak=ac.peak_db(signal.resample_poly(x,4,1))
        edge=float(max(abs(x[0]),abs(x[-1])))
        errors=[]
        if info['sample_rate']!='44100' or info['channels']!=1: errors.append('format')
        if not .06<=duration<=.25: errors.append('duration')
        if true_peak > -1: errors.append('true_peak')
        if abs(ac.rms_db(x)+26)>.8: errors.append('rms')
        if edge>.002: errors.append('boundary_click')
        if abs(duration-item['duration_s'])>1/ac.SR: errors.append('manifest_duration')
        if item['loop']:
            difference=abs(x[0]-x[-1]); slope=abs(x[0]-x[-1])
            if difference>1e-4 or slope>4*np.sqrt(np.mean(np.diff(x)**2)): errors.append('loop_seam')
        results.append(dict(path=item['path'],duration_s=duration,true_peak_dbfs=true_peak,rms_dbfs=ac.rms_db(x),boundary_amplitude=edge,loop_check='not_applicable_one_shot',errors=errors))
        if errors: failures.append((path.name,errors))
    assert len(manifest)==120, 'Expected 120 files'
    report=dict(passed=not failures,count=len(results),total_duration_s=sum(r['duration_s'] for r in results),results=results)
    (Path(__file__).parent/'footsteps_verification.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(dict(passed=not failures,count=len(results),duration_range_s=[min(r['duration_s'] for r in results),max(r['duration_s'] for r in results)],total_duration_s=report['total_duration_s'],failures=failures),indent=2))
    if failures: raise SystemExit(1)
if __name__=='__main__': main()
