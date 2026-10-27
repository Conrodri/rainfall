"""Verify delivered Vorbis streams, measured peaks, durations and loop seams."""
import argparse,json,subprocess
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac

def main():
    p=argparse.ArgumentParser();p.add_argument('--aut1',action='store_true');p.add_argument('--au1',action='store_true');p.add_argument('--au2',action='store_true');p.add_argument('--au3',action='store_true');p.add_argument('--out',type=Path,default=Path(__file__).resolve().parents[3]/'game/assets/audio/spells');args=p.parse_args()
    entries=json.loads(Path(__file__).with_name('spells_manifest.json').read_text(encoding='utf-8')); failures=[];results=[]
    if args.au1:entries=[e for e in entries if e.get('usage','').startswith('AU1 ')]
    if args.au1 and len(entries)!=72:raise SystemExit('FAIL AU1 expected 72 files')
    if args.au2:entries=[e for e in entries if e.get('usage','').startswith('AU2 ')]
    if args.au2 and len(entries)!=63:raise SystemExit('FAIL AU2 expected 63 files')
    if args.au3:entries=[e for e in entries if e.get('usage','').startswith('AU3 ')]
    if args.au3 and len(entries)!=72:raise SystemExit('FAIL AU3 expected 72 files')
    if args.aut1:entries=[e for e in entries if e.get('usage','').startswith('AUT1 ')]
    if args.aut1 and len(entries)!=27:raise SystemExit('FAIL AUT1 expected 27 files')
    for e in entries:
        path=args.out/Path(e['path']).name;x=ac.decode(path)
        probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-of','json',str(path)]))['streams'][0]
        peak=ac.peak_db(signal.resample_poly(x,4,1));rms=ac.rms_db(x)
        errors=[]
        if probe['codec_name']!='vorbis' or int(probe['sample_rate'])!=44100 or int(probe['channels'])!=2:errors.append('format')
        if not np.all(np.isfinite(x)):errors.append('nonfinite')
        if peak> -1.0:errors.append('true peak')
        if abs(len(x)/ac.SR-e['duration_s'])>.001:errors.append('duration')
        if not -29<rms< -16:errors.append('loudness')
        if args.aut1:
            active=np.flatnonzero(np.max(np.abs(x),axis=1)>10**(-60/20))
            if not len(active) or active[0]/ac.SR>=.010:errors.append('leading silence')
            if np.max(np.abs(x))>=1:errors.append('clipping')
            kind=e['usage'].split()[-1].split('_')[0]
            lo,hi={'cast':(.45,1.2) if 'coup_de_tocsin' in e['path'] else (.45,1.0),'impact':(.6,.9),'hit':(.12,.3),'end':(.5,.8)}[kind]
            if not lo<=len(x)/ac.SR<=hi:errors.append('AUT1 duration range')
        seam=0.;ratio=0.
        if e['loop']:
            expected=4 if path.name.startswith('cinders') else 3
            if len(x)!=expected*ac.SR:errors.append('loop length')
            seam=float(np.max(np.abs(x[0]-x[-1])))
            difference=np.diff(x,axis=0);derivative_rms=float(np.sqrt(np.mean(difference**2)))
            ratio=seam/max(derivative_rms,1e-10)
            if seam>.003 or ratio>.5:errors.append('loop seam')
            # Slopes on either side must remain inside ordinary derivative range.
            if np.max(np.abs(difference[[0,-1]]))>np.quantile(np.abs(difference),.999):errors.append('seam derivative')
        else:
            if np.max(np.abs(x[[0,-1]]))>.004:errors.append('one-shot boundary')
            edge=round(.004*ac.SR)
            if np.max(np.abs(np.diff(x[:edge],axis=0)))>.004 or np.max(np.abs(np.diff(x[-edge:],axis=0)))>.004:errors.append('boundary click')
            if np.max(np.abs(np.diff(x,axis=0)))>.65:errors.append('internal discontinuity')
        if errors:failures.append((path.name,errors))
        results.append(dict(path=e['path'],true_peak_dbfs=round(peak,3),rms_dbfs=round(rms,3),seam_delta=seam,seam_derivative_ratio=ratio,errors=errors))
    report=dict(files=len(entries),total_duration_s=sum(e['duration_s'] for e in entries),size_bytes=sum(p.stat().st_size for p in args.out.glob('*.ogg')),failures=failures,measurements=results)
    Path(__file__).with_name(('aut1_verification.json' if args.aut1 else 'au3_verification.json' if args.au3 else ('au2_verification.json' if args.au2 else ('au1_verification.json' if args.au1 else 'spells_verification.json')))).write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(('FAIL' if failures else 'PASS')+f' files={len(entries)} failures={len(failures)} peak={max(r["true_peak_dbfs"] for r in results):.3f} RMS={min(r["rms_dbfs"] for r in results):.2f}..{max(r["rms_dbfs"] for r in results):.2f}');print(str(failures[:8]) if failures else 'PASS boundaries and discontinuities')
    if failures:raise SystemExit(1)
if __name__=='__main__':main()
