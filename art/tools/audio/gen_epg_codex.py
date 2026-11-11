"""Deterministic richer EP-G cues for the Epreuves audio set."""
import json
from pathlib import Path

import numpy as np
from scipy import signal

import audio_common as ac
import synth_lib as sl

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'game/assets/audio/epreuves'
SR = ac.SR
SEED = 261022
SPECS = [
    ('epreuve_start', 1.20, -20.0), ('chase_jump', .45, -20.5),
    ('chase_warn', .55, -21.0), ('chase_point', .75, -20.0),
    ('chase_miss', .65, -21.0), ('vein_tick', .28, -22.0),
    ('vein_geyser_warn', 1.00, -21.0), ('vein_geyser', 1.30, -20.0),
    ('hold_side', .85, -21.0), ('hold_bell_hit', .60, -20.0),
    ('hold_bell_dim', 1.45, -21.0), ('hold_bell_ring', 3.00, -21.0),
]


def env(n, attack=.008, decay=.3, tail=0):
    t = np.arange(n) / SR
    return (1 - np.exp(-t / attack)) * np.exp(-t / decay) + tail


def tone(freq, n, harmonics=(1, .25, .08), decay=.3, attack=.006, phase=0):
    f = np.broadcast_to(np.asarray(freq, dtype=float), (n,))
    ph = 2 * np.pi * np.cumsum(f) / SR + phase
    y = sum(a * np.sin(k * ph) for k, a in enumerate(harmonics, 1))
    return y * env(n, attack, decay)


def bell(base, n, decay, rng, inharmonic=True):
    t = np.arange(n) / SR
    partials = ((1, 1., 1.), (2.01, .55, .72), (2.73, .42, .55),
                (4.08, .26, .34), (5.42, .16, .25), (6.8, .10, .18))
    y = np.zeros(n)
    for ratio, amp, damp in partials:
        f = base * ratio * (rng.uniform(.998, 1.002) if inharmonic else 1)
        y += amp * np.sin(2*np.pi*f*t + rng.uniform(-.02, .02)) * np.exp(-t/(decay*damp))
    strike = sl.bp(rng.normal(size=n), 1700, 9000) * np.exp(-t/.004)
    return (y + .18 * strike) * np.minimum(1, t/.0015)


def make(name, n, rng):
    t = np.arange(n)/SR
    if name == 'epreuve_start':
        f = 82 + 92*np.minimum(t/1.2, 1)**1.15
        y = sl.lp(sl.wosc(f, n, 'saw'), 1050) + .32*tone(f*1.5, n, (1,.2), .8, .12)
        y += .16*tone(f*2, n, (1,.15), .5, .16)
        return y * (1-np.exp(-t/.11)) * (.72+.28*np.sin(np.pi*t/2.4))
    if name == 'chase_jump':
        noise = sl.bp(rng.normal(size=n), 600, 9000) * (1-np.exp(-t/.035))*np.exp(-t/.20)
        f = 460*np.exp(t*3.5)
        return .55*noise + .8*tone(f,n,(1,.42,.12),.18,.002)
    if name == 'chase_warn':
        y = np.zeros(n)
        for i, at in enumerate((0,.09,.17,.25,.33,.40,.46)):
            k=round(at*SR); m=n-k; sway=1+.035*np.sin(2*np.pi*(5+i*.3)*np.arange(m)/SR)
            y[k:] += (.43+.07*(i%3))*bell(1120+95*(i%3),m,.12,rng)*sway
        return y
    if name == 'chase_point':
        y=np.zeros(n)
        for at, f in ((0,659.25),(.16,987.77)):
            k=round(at*SR); y[k:] += .85*bell(f,n-k,.34,rng,False)
        return y
    if name == 'chase_miss':
        f=255*np.exp(-t*1.75)
        body=tone(f,n,(1,.54,.2),.31,.005)
        disson=tone(f*1.47,n,(1,.26),.16,.012,phase=.8)
        thud=sl.lp(sl.bp(rng.normal(size=n),45,650),480)*np.exp(-t/.075)
        return body+.52*disson+.28*thud
    if name == 'vein_tick':
        pulse=np.exp(-t/.09)*(1-np.exp(-t/.002))
        return pulse*(tone(58+9*np.exp(-t*22),n,(1,.45,.12),.12,.002)+.18*sl.lp(rng.normal(size=n),180))
    if name == 'vein_geyser_warn':
        rise=t**1.7
        rumble=sl.lp(sl.bp(rng.normal(size=n),35,1350),1100)*(.16+.92*rise)
        f=39+45*np.minimum(t,1)**1.5
        return .72*rumble+.58*tone(f,n,(1,.6,.25),1.5,.08)*( .18+.82*rise)
    if name == 'vein_geyser':
        boom=sl.lp(sl.bp(rng.normal(size=n),35,800),650)*np.exp(-t/.29)
        boom += tone(54*np.exp(-t*2)+27,n,(1,.32),.4,.002)
        jet=sl.bp(rng.normal(size=n),500,10500)*(1-np.exp(-t/.012))*np.exp(-t/.31)
        return .85*boom+.65*jet
    if name == 'hold_side':
        f=174+5*np.sin(2*np.pi*2.2*t)+8*np.minimum(t/.18,1)
        horn=sl.lp(sl.wosc(f,n,'saw'),1700)+.42*sl.lp(sl.wosc(f*1.498,n,'saw'),1200)
        breath=sl.bp(rng.normal(size=n),350,2600)*.08
        return (horn+breath)*(1-np.exp(-t/.055))*np.exp(-np.maximum(t-.42,0)/.24)
    if name == 'hold_bell_hit':
        return bell(294,n,.48,rng)+.25*sl.bp(rng.normal(size=n),900,7000)*np.exp(-t/.009)
    if name == 'hold_bell_dim':
        y=np.zeros(n); f=330*np.exp(-t*.34)
        for r,a,d in ((1,1,.62),(2.01,.45,.48),(2.73,.32,.36),(4.08,.17,.25)):
            y += a*np.sin(2*np.pi*np.cumsum(f*r)/SR)*np.exp(-t/d)
        return sl.lp(y,3400)+.12*bell(520,n,.22,rng)*np.exp(-t/.45)
    if name == 'hold_bell_ring':
        dry=bell(262,n,2.1,rng)
        # Deterministic multi-tap metallic tail, clipped to the requested cue duration.
        tail=dry.copy()
        for delay,gain in ((.071,.19),(.113,.14),(.167,.10),(.239,.075)):
            k=round(delay*SR); tail[k:] += dry[:-k]*gain
        return tail
    raise KeyError(name)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rows=[]
    for i,(name,duration,target) in enumerate(SPECS):
        seed=SEED+i; rng=np.random.default_rng(seed); n=round(duration*SR)
        x=np.nan_to_num(make(name,n,rng)); x=sl.hp(x,28)
        # Whole-file RMS normalization, then peak-safe gain; edge fades avoid codec clicks.
        x=ac.fade(ac.normalize(x,target,-2.8),12)
        edge=round(.012*SR); x[:edge]*=np.linspace(0,1,edge); x[-edge:]*=np.linspace(1,0,edge)
        path=OUT/f'{name}.ogg'; ac.write_ogg(path,x,5); y=ac.decode(path,channels=1)
        tp=ac.peak_db(signal.resample_poly(y[:,0],4,1))
        rms=ac.rms_db(y[:,0]); dur=len(y)/SR
        rows.append(dict(id=name,path=f'epreuves/{name}.ogg',seed=seed,duration_s=round(dur,6),
                         target_rms_dbfs=target,rms_dbfs=round(rms,3),peak_dbfs=round(ac.peak_db(y),3),
                         true_peak_dbfs=round(tp,3),sample_rate=SR,channels=1,quality=5,bytes=path.stat().st_size))
    Path(__file__).with_name('epg_manifest.json').write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    print(f'PASS: generated {len(rows)} mono Vorbis q5 cues')


if __name__ == '__main__':
    main()
