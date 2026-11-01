"""Deterministic procedural Rictus v2 sounds; no samples or reverb."""
import json
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl
from gen_impacts import ROOT, decode_exact

SPECS = {
    'spell_rictus_saccade_cast_light_01': (.205, 'light', -18., 'snap of taut cord, returning blade whistle, and wood handle slap'),
    'spell_rictus_saccade_cast_medium_01': (.302, 'medium', -17., 'snapping cord, blade whistle, and resonant wooden handle'),
    'spell_rictus_saccade_cast_heavy_01': (.425, 'heavy', -16., 'heavy cord snap, descending blade whistle, and low impact'),
    'impact_rictus_knife_plant_01': (.218, 'impact', -18., 'dry knife plant and short metallic vibration'),
    'impact_rictus_knife_plant_02': (.267, 'impact', -18., 'stone knife plant and short metallic vibration'),
}

def synth(duration, level, seed):
    rng = np.random.default_rng(seed)
    n = round(duration*ac.SR); t = np.arange(n)/ac.SR
    # Tight broadband transient with a resonant, slightly detuned wooden body.
    x = sl.bp(rng.normal(size=n), 450, 10000)*np.exp(-t/.0035)
    x += .55*sl.bp(rng.normal(size=n), 1100, 6400)*np.exp(-t/.020)
    if level == 'impact':
        x += .72*np.sin(2*np.pi*rng.uniform(1750,2450)*t)*np.exp(-t/rng.uniform(.025,.039))
        x += .38*np.sin(2*np.pi*rng.uniform(420,780)*t)*np.exp(-t/.018)
        # Secondary metal tick, delayed a few milliseconds from the plant.
        k=round(rng.uniform(.008,.014)*ac.SR); m=n-k
        x[k:] += .28*sl.bp(rng.normal(size=m), 2800, 10000)*np.exp(-np.arange(m)/(.009*ac.SR))
    else:
        # Vibrating cord harmonics decay quickly; blade return sweeps upward.
        f0=rng.uniform(145,215)
        x += .52*np.sin(2*np.pi*f0*t + 3*np.exp(-t/.025))*np.exp(-t/.075)
        sweep=sl.sine(np.linspace(rng.uniform(900,1400),rng.uniform(2100,3100),n),n)
        x += .32*sweep*np.exp(-t/(duration*.23))
        # Short slap on a wooden handle; heavy carries a low thump.
        x += .68*sl.bp(rng.normal(size=n), 180, 1300)*np.exp(-t/.011)
        if level == 'heavy':
            x += .70*np.sin(2*np.pi*rng.uniform(58,78)*t)*np.exp(-t/.065)
            x += .35*sl.bp(rng.normal(size=n), 55, 240)*np.exp(-t/.045)
    y=ac.pan(x, rng.uniform(-.2,.2))
    y=ac.saturate(y, 1.4)
    y=ac.fade(y, 2)
    return y

def main():
    rows=[]
    for i,(name,(duration,level,target,usage)) in enumerate(SPECS.items()):
        folder='spells' if name.startswith('spell_') else 'impacts'
        path=ROOT/'game/assets/audio'/folder/f'{name}.ogg'
        x=synth(duration,level,914272+i)
        x*=10**((target-ac.rms_db(x))/20)
        for _ in range(6):
            ac.write_ogg(path,x,quality=5)
            decoded,_=decode_exact(path)
            peak=ac.peak_db(signal.resample_poly(decoded,4,1,axis=0))
            if peak <= -1.5: break
            x*=10**((-1.8-peak)/20)
        else: raise RuntimeError(f'Encoded peak: {path}')
        rows.append(dict(path=f'{folder}/{path.name}',duration_s=round(len(decoded)/ac.SR,6),loop=False,
                         level=level,usage=usage,gain_db=0,peak_dbfs=round(ac.peak_db(decoded),3),
                         rms_dbfs=round(ac.rms_db(decoded),3)))
    Path(__file__).with_name('rictus_v2_manifest.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print('PASS: 5 Ogg Vorbis q5')

if __name__ == '__main__': main()
