"""Check Rictus v2 decoded audio format, timing, peaks, and distinct variants."""
import json
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent))
import numpy as np
from scipy import signal
import audio_common as ac
from gen_impacts import ROOT,decode_exact

def main():
    rows=json.loads(Path(__file__).with_name('rictus_v2_manifest.json').read_text(encoding='utf-8'))
    errors=[]; clips={}
    bounds={'light':(.150,.250),'medium':(.250,.350),'heavy':(.350,.500),'impact':(.150,.300)}
    if len(rows)!=5: errors.append('Expected 5 variants')
    for row in rows:
        path=ROOT/'game/assets/audio'/row['path']; x,info=decode_exact(path)
        duration=len(x)/ac.SR; peak=ac.peak_db(signal.resample_poly(x,4,1,axis=0))
        checks={'rate':int(info['sample_rate'])==44100,'stereo':info['channels']==2,
                'codec':info['codec_name']=='vorbis','finite':bool(np.isfinite(x).all()),
                'duration':bounds[row['level']][0]<=duration<=bounds[row['level']][1],
                'peak':peak<=-1.5,'non_silent':ac.rms_db(x)>-40,
                'manifest_duration':abs(duration-row['duration_s'])<.001,
                'manifest_peak':abs(ac.peak_db(x)-row['peak_dbfs'])<.01}
        failed=[k for k,v in checks.items() if not v]
        if failed: errors.append(f"{row['path']}: {','.join(failed)}")
        clips[row['path']]=x
    groups={'saccade':[k for k in clips if 'saccade' in k],
            'plant':[k for k in clips if 'plant' in k]}
    for group,names in groups.items():
        for i,a in enumerate(names):
            for b in names[:i]:
                n=min(len(clips[a]),len(clips[b]))
                corr=abs(float(np.corrcoef(clips[a][:n].ravel(),clips[b][:n].ravel())[0,1]))
                if corr>.8: errors.append(f'{group}: variants correlated {corr:.3f}')
    print(('FAIL' if errors else 'PASS')+f': {len(rows)} Ogg q5 variants; duration, peak, and distinction')
    for e in errors: print(e)
    if errors: raise SystemExit(1)
if __name__=='__main__': main()
