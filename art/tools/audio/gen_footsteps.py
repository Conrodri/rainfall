"""Procedural mono footsteps. Run: uv run --with numpy --with scipy python art/tools/audio/gen_footsteps.py"""
import argparse
import json
import subprocess
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac

ROOT = Path(__file__).resolve().parents[3]
PROFILES = { # duration, weight, tonal pitch
    'ardent': (.112, .65, 1.12), 'swarm': (.085, .16, 1.9),
    'shooter': (.105, .85, 1.0), 'leaper': (.192, 1.15, .9),
    'brute_light': (.174, 1.6, .78), 'brute_heavy': (.205, 2.2, .65),
    'miniboss': (.208, 2.8, .57), 'boss': (.215, 3.8, .48),
}
def decode_mono(path):
    data=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar',str(ac.SR),'-'])
    return np.frombuffer(data,dtype='<f4')

SOILS = ('stone_wet', 'mud_leaves', 'rust_metal')

def synthesize(subject, soil, rng):
    duration, weight, pitch = PROFILES[subject]
    duration = np.clip(duration * rng.uniform(.97, 1.015), .06, .25)
    n = round(duration * ac.SR)
    t = np.arange(n)/ac.SR
    pitch *= rng.uniform(.94, 1.06)
    white = ac.noise(n, rng)
    pink = ac.noise(n, rng, 'pink')
    attack = 1-np.exp(-t/.0007)
    # A boot's compressed sole and heel: broadband transient, pitched falling body.
    body = ac.osc((55+85/weight**.3)*pitch*(1+.5*np.exp(-t/.012)))
    body *= np.exp(-t/(.014+.005*weight))
    heel = ac.filt(white, [650*pitch, min(14000, 7000*pitch)], 'bandpass')*np.exp(-t/.004)
    x = .36*body + .25*heel
    if soil == 'stone_wet':
        # Hard sole strike, followed by irregular small droplets and a water sheet.
        x += .22*ac.filt(white, 1900, 'highpass')*np.exp(-t/.009)
        water = ac.filt(pink, [650, 10500], 'bandpass')
        x += .4*water*(1-np.exp(-t/.004))*np.exp(-t/.025)
        for _ in range(7):
            start = rng.uniform(.009, min(duration*.65,.075))
            u = np.maximum(t-start,0)
            env = (t>=start)*(1-np.exp(-u/.0006))*np.exp(-u/.003)
            x += rng.uniform(.04,.12)*np.sin(2*np.pi*rng.uniform(1700,4700)*pitch*u)*env
    elif soil == 'mud_leaves':
        suction = ac.osc((85+130*np.exp(-t/.012))*pitch)
        x = .25*x + .45*suction*np.exp(-t/.023)
        x += .5*ac.filt(pink, 1100)*np.exp(-t/.025)
        rustle = ac.filt(white, [1400,8500], 'bandpass')
        flutter = .4+.6*np.sin(2*np.pi*(80*t+180*t*t)+rng.uniform(0,6))**2
        x += .19*rustle*flutter*(1-np.exp(-t/.004))*np.exp(-t/.036)
    else:
        x += .22*ac.filt(white,[1000,10000],'bandpass')*np.exp(-t/.006)
        # Inharmonic plate modes, with weak modulated high modes for rusty friction.
        for frequency, strength in [(310,.22),(691,.16),(1147,.11),(1933,.07),(3217,.035)]:
            phase = rng.uniform(0,2*np.pi)
            mode = np.sin(2*np.pi*frequency*pitch*t + .07*np.sin(2*np.pi*37*t)+phase)
            x += strength*mode*np.exp(-t/(.024+.012*weight))
        x += .09*ac.filt(white,[2600,5800],'bandpass')*(1-np.exp(-t/.008))*np.exp(-t/.04)
    if subject == 'swarm':
        source=x.copy(); x *= .45
        for offset in (.009,.022,.038,.052):
            k=round((offset+rng.uniform(-.002,.002))*ac.SR)
            x[k:] += source[:-k]*rng.uniform(.25,.55)
        x=ac.filt(x,650,'highpass')
    if subject == 'leaper':
        # Initial toe purchase followed by the fuller landing inside one short event.
        k=round(.047*ac.SR); source=x.copy()
        x *= .3; x[k:] += source[:-k]*.9
    if weight >= 1.6:
        x += (.13+.025*weight)*ac.osc((43+22*np.exp(-t/.016))*pitch/.65)*np.exp(-t/(.025+.006*weight))
    x=ac.saturate(x*attack,1.3)
    x=ac.reverb(x,rng,decay=.012+weight*.003,wet=.035)
    x=ac.fade(x,5)
    x=np.pad(x,(round(.006*ac.SR),round(.006*ac.SR)))
    return ac.normalize(x,target_rms=-26,peak=-2)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=ROOT/'game/assets/audio/footsteps')
    parser.add_argument('--seed',type=int,default=73421)
    args=parser.parse_args(); args.out.mkdir(parents=True,exist_ok=True)
    manifest=[]
    for si,subject in enumerate(PROFILES):
        for gi,soil in enumerate(SOILS):
            for variant in range(1,6):
                seed=np.random.SeedSequence([args.seed,si,gi,variant])
                x=synthesize(subject,soil,np.random.default_rng(seed))
                name=f'step_{subject}_{soil}_{variant:02d}.ogg'
                path=args.out/name; ac.write_ogg(path,x,quality=6)
                decoded=decode_mono(path)
                # Compensate codec padding and quantization using measured mono RMS.
                if abs(ac.rms_db(decoded)+26)>.15:
                    x *= 10**((-26-ac.rms_db(decoded))/20)
                    ac.write_ogg(path,x,quality=6)
                    decoded=decode_mono(path)
                level=('light' if subject in ('ardent','swarm','brute_light') else 'heavy' if subject in ('brute_heavy','miniboss','boss') else 'medium')
                manifest.append(dict(path=f'footsteps/{name}',duration_s=len(decoded)/ac.SR,loop=False,level=level,
                    usage=f'Pas {subject} sur {soil}; alterner aléatoirement les cinq variantes.',gain_db=0,
                    peak_dbfs=ac.peak_db(decoded),rms_dbfs=ac.rms_db(decoded)))
    (Path(__file__).parent/'footsteps_manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(f'Generated {len(manifest)} mono footsteps in {args.out}')

if __name__=='__main__': main()
