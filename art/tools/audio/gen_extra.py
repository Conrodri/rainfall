"""Additional Rainfall audio, entirely procedural. --out is the audio root.
uv run --with numpy --with scipy python art/tools/audio/gen_extra.py
"""
import argparse
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import gen_impacts as impacts
import gen_footsteps as steps

ROOT = Path(__file__).resolve().parents[3]
LEVELS = ('light', 'medium', 'heavy')
SUBJECTS = ('player', 'monster_t1', 'monster_t2', 'monster_t3', 'boss')
SOILS = ('stone', 'water', 'grass')
SPECS = {'hit_medium': (.27, 'medium', 'Coup physique de poids intermédiaire', -1)}
for element in ('fire', 'ice', 'poison', 'lightning'):
    for i, level in enumerate(LEVELS):
        SPECS[f'hit_{element}_{level}'] = ((.32, .48, .72)[i], level, f'Impact {element}, intensité {level}', -2)
SPECS.update({
    'death_t4': (1.8, 'heavy', 'Effondrement de gros monstre ou mini-boss avec sub', -4),
    'boss_spawn': (3.6, 'heavy', 'Apparition de boss : grondement, cloche distante et montée', -6),
    'boss_defeat': (4.6, 'heavy', 'Effondrement de boss puis résolution apaisée', -5),
    'stage_cleared': (2.6, 'none', 'Étage terminé : cordes et cloches soulagées', -5),
})


def pulse(t, at, tau, attack=.002):
    u = np.maximum(t-at, 0)
    return (t >= at)*(1-np.exp(-u/attack))*np.exp(-u/tau)


def impact(name, duration, rng):
    n = round(duration*ac.SR)
    t = np.arange(n)/ac.SR
    p = rng.uniform(.96, 1.04)
    def grain(lo, hi):
        return ac.filt(ac.noise(n, rng), [lo, hi], 'bandpass')
    def thud(f, tau, at=0, strength=1):
        u = np.maximum(t-at, 0)
        return strength*ac.osc(p*(f+f*1.8*np.exp(-u/.018)))*pulse(t, at, tau)
    if name == 'hit_medium':
        # Blend the existing physical vocabularies at an intermediate weight.
        x = .6*impacts.synth('hit_normal', duration, rng)+.4*impacts.synth('hit_crit', duration, rng)
        return finish(x, rng, -18, .06)
    if name.startswith('hit_'):
        _, element, level = name.split('_')
        weight = LEVELS.index(level)
        x = thud(105-24*weight, .035+.025*weight, strength=.6)
        x += .55*grain(700, 9000)*pulse(t, 0, .009)
        if element == 'fire':
            x += grain(170, 5600)*pulse(t, .009, .065+.045*weight, .006)
            for at in rng.uniform(.008, duration*.55, 8+weight*6):
                x += .32*grain(1700, 11500)*pulse(t, at, rng.uniform(.003,.012), .0008)
        elif element == 'ice':
            x += .7*grain(2600, 14000)*pulse(t, 0, .018)
            for f in (1371, 2183, 3397, 4951, 7117):
                x += .12*np.sin(2*np.pi*f*p*t)*pulse(t, rng.uniform(0,.018), .055+.035*weight)
            for at in rng.uniform(.02, duration*.48, 4+weight*4):
                x += .4*grain(1800-450*weight, 11500)*pulse(t, at, .009+.004*weight)
            x += .25*grain(250,1600)*pulse(t,.016,.04+.03*weight)
        elif element == 'poison':
            x *= .45
            x += .8*grain(180, 2600)*pulse(t, .003, .045+.035*weight)
            for at in rng.uniform(.005, duration*.55, 5+weight*3):
                u = np.maximum(t-at, 0)
                f = rng.uniform(330,1100)*p*(.38+.62*np.exp(-u/.012))
                x += .24*ac.osc(f)*pulse(t, at, .022+.012*weight)
            x += .3*grain(2100,6500)*pulse(t,.014,.045+.02*weight)
        else:
            x += .9*grain(1600,14000)*pulse(t,0,.007)
            for at in rng.uniform(.008,.12+.05*weight,4+3*weight):
                arc = ac.fm(rng.uniform(700,1800)*p, rng.uniform(900,2100), 4, duration)
                x += (.2*arc+.6*grain(1300,12000))*pulse(t,at,.008,.0006)
            if weight == 2:
                x += 1.1*grain(45,650)*pulse(t,.035,.13,.003)+thud(38,.18,.025,.8)
    elif name == 'death_t4':
        x = impacts.synth('death_elite', duration, rng).mean(axis=1)*2
        x += thud(35,.36,strength=.45)
        for at in (.13,.34,.61,.89):
            x += grain(90,2200)*pulse(t,at,.1)*.45+thud(48,.13,at,.3)
    elif name == 'boss_spawn':
        u=t/duration
        x = (.35*ac.osc(p*(34+7*u))+.25*grain(40,480))*(np.sin(np.pi*u)**.7)
        x += .25*grain(180,3300)*(u**2)*np.minimum((1-u)/.08,1)
        for f in (103,147.3,217.1,308.9,451.7):
            x += .15*np.sin(2*np.pi*f*p*t)*pulse(t,.35,1.1,.035)
        x += thud(32,.22,duration-.45,.4)
    else:
        x = np.zeros(n)
        at = 1.05 if name == 'boss_defeat' else .05
        if name == 'boss_defeat':
            x += thud(35,.32,strength=.8)+grain(70,2100)*pulse(t,0,.28)*.7
            for hit in (.14,.36,.63):
                x += grain(160,3600)*pulse(t,hit,.09)*.25
        # Suspended D chord resolving gently, with bowed harmonic texture.
        for j,f in enumerate((146.832,220,293.665,369.994,440)):
            start=at+j*.035+rng.uniform(0,.012)
            env=pulse(t,start,.65 if name=='stage_cleared' else 1.05,.12)
            bowed=sum(np.sin(2*np.pi*f*k*t+.012*k*np.sin(2*np.pi*4.7*t))/k**1.7 for k in range(1,9))
            x += .19*bowed*env
            x += .06*(np.sin(2*np.pi*f*2*t)+.25*np.sin(2*np.pi*f*5.43*t))*pulse(t,start,.45,.008)
        x += .025*grain(900,3600)*pulse(t,at,.65,.15)
    x = ac.filt(ac.saturate(x,1.15),25,'highpass',2)
    return finish(ac.stereo(x,.23),rng,-20 if name=='stage_cleared' else -18,.14 if duration<1 else .24)


def finish(x, rng, target, wet):
    x=ac.reverb(x,rng,decay=.09 if len(x)<ac.SR else .24,wet=wet)
    # Smooth compression limits sparse transient crest factors without hard clipping.
    if ac.peak_db(x)-ac.rms_db(x)>15:
        x=np.tanh(x/(np.std(x)*2.8+1e-12))
    k=round(.006*ac.SR)
    x[:k]=0; x[-k:]=0
    x[k:-k]=ac.fade(x[k:-k],4)
    return ac.normalize(x,target_rms=target,peak=-3)


def footstep(subject,soil,variant,rng):
    profile={'player':'ardent','monster_t1':'swarm','monster_t2':'shooter' if variant%2 else 'leaper',
             'monster_t3':'brute_heavy','boss':'miniboss' if variant%2 else 'boss'}[subject]
    # Reuse existing anatomy, weight, heel and subject articulation.
    source=steps.synthesize(profile,'mud_leaves' if soil=='grass' else 'stone_wet',rng)
    n=len(source); t=np.arange(n)/ac.SR
    weight=steps.PROFILES[profile][1]
    noise=ac.noise(n,rng)
    if soil=='stone':
        x=.35*ac.filt(source,1500,'lowpass')
        x+=.15*ac.filt(noise,[700,8500],'bandpass')*pulse(t,.006,.005)
        for f in (430,1127,2671):
            x+=.025*ac.osc(f*rng.uniform(.95,1.05),n/ac.SR)*pulse(t,.007,.011+.002*weight)
    elif soil=='water':
        x=source*.65
        x+=.18*ac.filt(noise,[450,7800],'bandpass')*pulse(t,.01,.02+.003*weight,.002)
        for at in rng.uniform(.015,min(n/ac.SR-.018,.10),9):
            u=np.maximum(t-at,0)
            x+=.04*ac.osc(rng.uniform(650,2200)*(1+.6*np.exp(-u/.003)))*pulse(t,at,.004)
    else:
        x=ac.filt(source,2300)*.9
        rustle=ac.filt(noise,[1100,6200],'bandpass')
        x+=.06*rustle*(.3+.7*np.sin(2*np.pi*87*t)**2)*pulse(t,.009,.023)
    if profile=='swarm':
        x=ac.filt(x,600,'highpass')
    if profile=='leaper':
        k=round(.043*ac.SR); texture=x.copy(); x[k:]+=.4*texture[:-k]
    return finish(x,rng,-26,0)


def emit(path,x,level,usage,gain):
    ac.write_ogg(path,x,quality=6)
    for _ in range(3):
        decoded,info=impacts.decode_exact(path)
        measured=steps.decode_mono(path)[:round(float(info['duration'])*ac.SR)] if x.ndim==1 else decoded
        peak=ac.peak_db(signal.resample_poly(measured,4,1,axis=0))
        target=-26 if x.ndim==1 else (-20 if path.name.startswith('stage_cleared') else -18)
        adjustment=target-ac.rms_db(measured)
        adjustment=min(adjustment,-1.7-peak)
        if abs(adjustment)<.08: break
        x=x*10**(adjustment/20)
        ac.write_ogg(path,x,quality=6)
    decoded,info=impacts.decode_exact(path)
    measured=steps.decode_mono(path)[:round(float(info['duration'])*ac.SR)] if x.ndim==1 else decoded
    return dict(path=f'{path.parent.name}/{path.name}',duration_s=round(float(info['duration']),6),loop=False,
                level=level,usage=usage,gain_db=gain,peak_dbfs=round(ac.peak_db(measured),3),rms_dbfs=round(ac.rms_db(measured),3))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,default=ROOT/'game/assets/audio')
    parser.add_argument('--seed',type=int,default=982451)
    args=parser.parse_args(); rows=[]
    for i,(name,(duration,level,usage,gain)) in enumerate(SPECS.items()):
        for v in range(1,4):
            rng=np.random.default_rng(np.random.SeedSequence([args.seed,0,i,v]))
            x=impact(name,duration*rng.uniform(.98,1.02),rng)
            rows.append(emit(args.out/'impacts'/f'{name}_{v:02d}.ogg',x,level,usage,gain))
        print(f'{name}: 3 variantes',flush=True)
    for si,subject in enumerate(SUBJECTS):
        for gi,soil in enumerate(SOILS):
            for v in range(1,6):
                rng=np.random.default_rng(np.random.SeedSequence([args.seed,1,si,gi,v]))
                x=footstep(subject,soil,v,rng)
                usage=f'Pas {subject} sur {soil}; alterner les cinq variantes'
                if subject=='monster_t2': usage+='; impair tireur, pair bondisseur'
                if subject=='boss': usage+='; impair mini-boss, pair boss'
                level='light' if si<2 else 'medium' if si==2 else 'heavy'
                rows.append(emit(args.out/'footsteps'/f'step_{subject}_{soil}_{v:02d}.ogg',x,level,usage,0))
        print(f'{subject}: 15 pas mono',flush=True)
    Path(__file__).with_name('extra_manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'{len(rows)} fichiers générés',flush=True)

if __name__=='__main__': main()

