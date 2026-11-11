"""Independent decoded-file validation for VMR_AUDIO."""
import json
import subprocess
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
from gen_vmr import ROOT,SPECS,LEVELS,BASE_SEED,target_rms

def main():
    rows=json.loads(Path(__file__).with_name('vmr_manifest.json').read_text(encoding='utf-8'))
    errors=[]; expected=set(); seen=set(); seeds=set(); durations={}; clips={}
    for gi,(ident,(ranges,count,_,attenuation)) in enumerate(SPECS.items()):
        for li,(lo,hi) in enumerate(ranges):
            level=LEVELS[li] if len(ranges)==3 else None
            group=[]; ds=[]
            for vi in range(count):
                name=f'spell_{ident}'+(f'_{level}' if level else '')+f'_{vi+1:02d}.ogg'
                relative='spells/'+name; expected.add(relative)
                rr=[r for r in rows if r['path']==relative]
                if len(rr)!=1:
                    errors.append(f'{name}: manifest count {len(rr)}'); continue
                r=rr[0]; p=ROOT/'game/assets/audio'/relative
                if not p.is_file(): errors.append(f'{name}: missing'); continue
                seen.add(relative)
                if r['seed']!=BASE_SEED+gi*1000+li*100+vi or r['seed'] in seeds:
                    errors.append(f'{name}: seed')
                seeds.add(r['seed'])
                probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=codec_name,sample_rate,channels,duration','-of','json',str(p)]))['streams']
                if len(probe)!=1 or {k:probe[0][k] for k in ('codec_name','sample_rate','channels')}!={'codec_name':'vorbis','sample_rate':'44100','channels':2}:
                    errors.append(f'{name}: format {probe}')
                x=ac.decode(p); duration=float(probe[0]['duration']); ds.append(duration)
                if not lo/1000<=duration<=hi/1000: errors.append(f'{name}: duration {duration}')
                tp=ac.peak_db(signal.resample_poly(x,4,1,axis=0)); rms=ac.rms_db(x)
                if not np.isfinite(x).all() or tp>-1.5: errors.append(f'{name}: true peak {tp:.3f}')
                if abs(rms-target_rms(ident,li))>1.5: errors.append(f'{name}: RMS {rms:.3f}')
                if p.stat().st_size>5_000_000: errors.append(f'{name}: >5 Mo')
                if p.stat().st_size!=r['bytes'] or abs(duration-r['duration_s'])>1/ac.SR:
                    errors.append(f'{name}: metadata')
                if abs(tp-r['true_peak_dbfs'])>.002 or abs(rms-r['rms_dbfs'])>.002:
                    errors.append(f'{name}: measured metadata')
                # End fades must avoid a hard codec boundary click.
                if np.max(np.abs(x[[0,-1]]))>.02: errors.append(f'{name}: endpoint')
                group.append(x)
            for i in range(len(group)):
                for j in range(i):
                    n=min(len(group[i]),len(group[j]))
                    corr=abs(float(np.corrcoef(group[i][:n].ravel(),group[j][:n].ravel())[0,1]))
                    if not np.isfinite(corr) or corr>.97: errors.append(f'{ident}/{level}: duplicate variants')
            durations[(ident,li)]=ds
        if len(ranges)==3:
            for li in range(2):
                a=durations[(ident,li)]; b=durations[(ident,li+1)]
                if a and b and max(a)>=min(b): errors.append(f'{ident}: level durations')
    if len(rows)!=len(expected) or seen!=expected or {r['path'] for r in rows}!=expected:
        errors.append('file/manifest count')
    total=sum((ROOT/'game/assets/audio'/r['path']).stat().st_size for r in rows)
    print(('FAIL' if errors else 'PASS')+f': {len(rows)} ogg; {total} bytes; '+('; '.join(errors[:8]) if errors else 'durations, true peaks, RMS, variants, levels, format, size'))
    if errors: raise SystemExit(1)

if __name__=='__main__': main()
