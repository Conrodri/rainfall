"""Verify the actual Vorbis files, not only pre-encoding buffers."""
import argparse
import json
from pathlib import Path
import subprocess
import numpy as np
from scipy import signal
import audio_common as ac
from gen_impacts import ROOT, SPECS, decode_exact


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--out', type=Path, default=ROOT/'game/assets/audio/impacts')
    args = p.parse_args()
    rows = json.loads(Path(__file__).with_name('impacts_manifest.json').read_text(encoding='utf-8'))
    report = []; errors = []
    assert len(rows) == 83, 'Expected 83 variants'
    for row in rows:
        path = args.out/Path(row['path']).name
        x, info = decode_exact(path)
        x = x.astype(np.float64)
        name = next(k for k in SPECS if path.name.startswith(k+'_'))
        duration = len(x)/ac.SR
        true_peak = ac.peak_db(signal.resample_poly(x, 4, 1, axis=0))
        # Useful portion excludes the quiet reverb tail; use 20 ms blocks above -35 dBFS.
        blocks = [x[i:i+882] for i in range(0, len(x), 882)]
        useful = np.concatenate([b for b in blocks if ac.rms_db(b)>-35])
        useful_rms = ac.rms_db(useful)
        edge_peak = float(np.max(np.abs(x[[0, -1]])))
        jump = float(np.max(np.abs(x[0]-x[-1])))
        derivative_rms = float(np.sqrt(np.mean(np.diff(x, axis=0)**2)))
        derivative_seam = float(np.max(np.abs((x[1]-x[0])-(x[-1]-x[-2]))))
        checks = dict(rate=int(info['sample_rate'])==44100, codec=info['codec_name']=='vorbis',
                      finite=bool(np.isfinite(x).all()), duration=abs(duration-SPECS[name][0])<=SPECS[name][0]*.045+.001,
                      true_peak=true_peak<=-1.49, useful_rms=-22<=useful_rms<=-14,
                      faded_edges=edge_peak<.012, manifest=abs(row['rms_dbfs']-ac.rms_db(x))<.01)
        if row['loop']:
            checks['loop_jump'] = jump<.001
            checks['loop_derivative'] = derivative_seam<max(.001, 4*derivative_rms)
        failed = [k for k,v in checks.items() if not v]
        if failed: errors.append(dict(path=row['path'], failed=failed))
        report.append(dict(path=row['path'], duration_s=duration, true_peak_dbfs=true_peak,
                           useful_rms_dbfs=useful_rms, edge_peak=edge_peak, loop=row['loop'],
                           seam_jump=jump, seam_derivative=derivative_seam, checks=checks))
    result = dict(passed=not errors, count=len(report), total_duration_s=sum(r['duration_s'] for r in report),
                  loops_checked=sum(r['loop'] for r in rows), errors=errors, files=report)
    Path(__file__).with_name('impacts_verification.json').write_text(json.dumps(result, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({k:v for k,v in result.items() if k!='files'}, indent=2))
    if errors: raise SystemExit(1)


if __name__=='__main__': main()
