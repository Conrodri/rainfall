"""Verify decoded raid duration, useful RMS, true peak and circular seams."""
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
from gen_impacts import decode_exact
from gen_raid import ROOT, expected

def main():
    rows=json.loads(Path(__file__).with_name('raid_manifest.json').read_text(encoding='utf-8'))
    wanted={rel:(ident,s) for ident,s,v,rel in expected()}
    errors=[]; report=[]
    if len(rows)!=len(wanted) or {r['path'] for r in rows}!=set(wanted):
        errors.append('manifest coverage')
    for row in rows:
        ident,s=wanted[row['path']]
        x,info=decode_exact(ROOT/'game/assets/audio'/row['path'])
        blocks=[x[k:k+882] for k in range(0,len(x),882)]
        active=np.concatenate([b for b in blocks if ac.rms_db(b)>-35])
        useful=ac.rms_db(active); rms=ac.rms_db(x)
        peak=ac.peak_db(signal.resample_poly(x,4,1,axis=0))
        jump=float(np.max(np.abs(x[0]-x[-1])))
        derivative=float(np.sqrt(np.mean(np.diff(x,axis=0)**2)))
        target=-18 if ident=='enemy.shield_hum.loop' else -24 if s['loop'] else -20
        checks=dict(id=row['id']==ident,codec=info['codec_name']=='vorbis',
                    stereo=int(info['channels'])==2,rate=int(info['sample_rate'])==44100,
                    duration=abs(float(info['duration'])-s['duration'])<.003,
                    finite=bool(np.isfinite(x).all()),peak=peak<=-1.5,
                    rms=abs((rms if s['loop'] else useful)-target)<2,
                    manifest=abs(rms-row['rms_dbfs'])<.01)
        if s['loop']:
            checks['seam']=jump<max(.012,5*derivative)
            # Boundary energy must not collapse (no artificial fade on loops).
            edge=np.concatenate((x[:2205],x[-2205:]))
            checks['seam_energy']=abs(ac.rms_db(edge)-rms)<10
        else:
            checks['edges']=float(np.max(np.abs(x[[0,-1]])))<.015
        failed=[k for k,v in checks.items() if not v]
        if failed: errors.append(dict(path=row['path'],failed=failed))
        report.append(dict(path=row['path'],duration_s=float(info['duration']),
                           rms_dbfs=rms,useful_rms_dbfs=useful,true_peak_dbfs=peak,
                           seam_jump=jump,checks=checks))
    result=dict(passed=not errors,count=len(rows),loops=sum(r['loop'] for r in rows),errors=errors,files=report)
    Path(__file__).with_name('raid_verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(('PASS' if not errors else 'FAIL')+f": {len(rows)} fichiers; {result['loops']} boucles")
    for error in errors[:12]: print(error)
    raise SystemExit(bool(errors))
if __name__=='__main__': main()
