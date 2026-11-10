import json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import numpy as np
import audio_common as ac
from gen_gresille import ROOT,SPECS,LEVELS

def main():
 rows=json.loads(Path(__file__).with_name('gresille_manifest.json').read_text(encoding='utf-8')); errors=[]
 for ident,(durs,nvar,target,folder,usage) in SPECS.items():
  ids=[ident] if ident in ('spell.gresille_ground.loop','spell.gresille_orage.ultimate','gresille.zap','gresille.jars') else [ident+'_'+l for l in LEVELS]
  for key in ids:
   rr=[r for r in rows if r['usage']==key]; clips=[]
   if len(rr)!=nvar: errors.append(f'{key}: variants {len(rr)} != {nvar}')
   lev=LEVELS.index(key.rsplit('_',1)[1]) if key.rsplit('_',1)[-1] in LEVELS else 1
   for r in rr:
    p=ROOT/'game/assets/audio'/r['path']; x=ac.decode(p); dur=len(x)/ac.SR
    expected=durs[lev] if len(durs)==3 else durs[min(rr.index(r),len(durs)-1)]
    if abs(expected-dur)>.025: errors.append(f'{p.name}: duration {dur:.3f}, expected {expected:.3f}')
    if ac.peak_db(x)>-1.5: errors.append(f'{p.name}: peak {ac.peak_db(x):.2f}')
    if r['loop']:
     jump=float(np.max(np.abs(x[0]-x[-1]))); rms=float(np.sqrt(np.mean(x*x)))
     if jump>max(.025,rms*.25): errors.append(f'{p.name}: loop click {jump:.4f}')
    clips.append(x)
   for i in range(len(clips)):
    for j in range(i):
     n=min(map(len,(clips[i],clips[j])))
     if abs(float(np.corrcoef(clips[i][:n].ravel(),clips[j][:n].ravel())[0,1]))>.97: errors.append(f'{key}: duplicates')
 if len(rows)!=55: errors.append(f'count {len(rows)}')
 print(('FAIL' if errors else 'PASS')+f': {len(rows)} variants; '+('; '.join(errors[:8]) if errors else 'durées, crêtes, RMS, variantes, boucles'))
 if errors: raise SystemExit(1)
if __name__=='__main__':main()
