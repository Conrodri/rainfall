"""Ardent fire spells. Regenerate: uv run --with numpy --with scipy python art/tools/audio/gen_spells.py"""
import argparse,json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
SR=ac.SR
ROOT=Path(__file__).resolve().parents[3]
LEVELS=('light','medium','heavy')
DURATIONS={'ember_bolt_cast':(.28,.45,.67),'ember_bolt_impact':(.38,.65,.98),'ardent_nova':(.95,1.5,2.18),'brasier':(1.35,2.1,2.95),'roaming_embers_start':(.55,.8,1.15),'flame_pillar':(.9,1.45,2.1),'meteor_rain':(1.7,2.35,3.0),'phoenix':(2.05,2.5,2.95)}

def burst(n,rng,time,decay,amp=1,band=(1000,11000)):
    k=int(time*SR); count=n-k
    if count<=0:return np.zeros(n)
    b=ac.filt(ac.noise(count,rng),band,'bandpass')*ac.exponential(count,decay)*amp
    b=ac.fade(b,2); out=np.zeros(n);out[k:]=b;return out

def oneshot(name,level,rng):
    dur=DURATIONS[name][level]; n=round(dur*SR);t=np.arange(n)/SR; u=t/dur
    pitch=rng.uniform(.94,1.06); weight=level+1
    pink=ac.noise(n,rng,'pink'); white=ac.noise(n,rng)
    roar=ac.filt(pink,(85,2200+level*650),'bandpass')
    air=ac.filt(white,(1600,10500),'bandpass')
    env=np.sin(np.pi*np.minimum(u*1.2,1))**1.3*np.exp(-u*1.8)
    if name=='ember_bolt_cast':env=(1-np.exp(-t/.025))*np.exp(-t/(dur*.19))
    elif name=='ember_bolt_impact':env=(1-np.exp(-t/.004))*np.exp(-t/(dur*.20))
    elif name=='ardent_nova':env=np.where(u<.24,(u/.24)**2,np.exp(-(u-.24)*6))
    elif name=='flame_pillar':env=np.where(u<.13,(u/.13)**.6,np.exp(-(u-.13)*4))
    elif name=='brasier':env=(1-np.exp(-t/.035))*np.exp(-u*2.0)*(1-u)**.6
    elif name=='phoenix':env=ac.adsr(n,.12,.25,.65,.65)
    x=(.65*roar+.22*air)*env
    f=(110-22*level)*pitch*(1+1.5*np.exp(-t/.065))
    sub=ac.osc(f)*np.exp(-t/(.10+.09*level))*(1-np.exp(-t/.006))
    if name not in ('roaming_embers_start','phoenix'):x+=sub*(.18+.18*level)
    for j in range(9+level*10):
        start=rng.uniform(.006,dur*.72);x+=burst(n,rng,start,rng.uniform(.003,.022),rng.uniform(.05,.22))
    if name in ('ember_bolt_impact','flame_pillar','brasier'):
        x+=burst(n,rng,.004,.022,.75,(250,10000))
    if name=='ardent_nova':
        x+=burst(n,rng,dur*.24,.13+.06*level,1.5,(80,6500))
        x+=ac.osc((65-10*level)*pitch,dur)*np.exp(-np.maximum(t-dur*.24,0)/.22)*(t>dur*.24)*.5
    if name=='meteor_rain':
        x*=.35
        for j in range(3+level):
            hit=.30+j*(dur-.65)/(3+level)+rng.uniform(-.025,.025)
            local=np.maximum(t-(hit-.27),0); active=(t>hit-.27)&(t<hit)
            whistle=ac.osc((2300-1800*np.minimum(local/.27,1))*pitch)
            x+=whistle*np.sin(np.pi*np.clip(local/.27,0,1))**2*active*.13
            x+=burst(n,rng,hit,.10+.05*level,.95,(65,5000))
            age=np.maximum(t-hit,0);x+=ac.osc((55-7*level)*(1+np.exp(-age/.025)))*np.exp(-age/.18)*(t>hit)*.45
    if name=='phoenix':
        # A nonverbal rasping cry: harmonic excitation into moving vocal resonances.
        fundamental=(310-35*level)*pitch*(1+.3*np.sin(2*np.pi*u*.8))*(1+.012*np.sin(2*np.pi*32*t))
        voice=ac.osc(fundamental,kind='saw')+.15*white
        cry=sum(ac.biquad(voice,freq,5)*gain for freq,gain in [(750,1),(1550,.65),(2700,.3)])
        x+=cry*env*1.2
        for start in (.22,.53,.89):x+=burst(n,rng,start,.12,.65,(180,7000))
    if name=='roaming_embers_start':x=ac.filt(x,450,'highpass')+ac.fm(650*pitch,37,1.8,dur)*env*.035
    x=ac.saturate(x,1.2+.55*level)
    stereo=ac.stereo(x,.18+.16*level)
    stereo=ac.reverb(stereo,rng,.065+.055*level,.12+.08*level)
    stereo=ac.fade(stereo,4)
    # Codec pre/post-ringing stays inside a short silent guard; duration unchanged.
    guard=round(.006*SR)
    stereo=np.pad(stereo[:-2*guard],((guard,guard),(0,0)))
    stereo[-2*guard:-guard]*=np.linspace(1,0,guard)[:,None]
    return ac.normalize(stereo,-18,-3.2)

def loop(name,level,rng):
    dur=4 if name=='cinders_loop' else 3;n=dur*SR;t=np.arange(n)/SR
    # Every source, filter and spatial offset is periodic on exactly n samples.
    freq=np.fft.rfftfreq(n,1/SR)
    def periodic(low,high):
        spec=np.fft.rfft(rng.normal(size=n));shape=(freq/np.maximum(freq,low))**2/(1+(freq/high)**6)
        shape[0]=0;out=np.fft.irfft(spec*shape,n);return out/(np.std(out)+1e-12)
    body=periodic(90,950+level*450);air=periodic(1300,7500)
    mod=1+.18*np.sin(2*np.pi*(3+level)*t/dur+rng.uniform(0,6))+.09*np.sin(2*np.pi*11*t/dur)
    x=(body*(.16+.07*level)+air*.065)*mod
    for j in range(35+level*20):
        k=int(rng.uniform(0,n));length=int(rng.uniform(.005,.035)*SR)
        b=ac.filt(rng.normal(size=length),(1700,11000),'bandpass')*np.exp(-np.arange(length)/(length*.2))
        b=ac.fade(b,2)*rng.uniform(.08,.4); np.add.at(x,(k+np.arange(length))%n,b)
    if name=='roaming_embers_loop':x=ac.filt(x,550,'highpass')*.8+air*.07
    x=ac.saturate(x,1.1+.4*level)
    y=np.column_stack((x+np.roll(x,383)*(.15+.08*level),x+np.roll(x,-521)*(.15+.08*level)))
    # Short smooth seam guard also suppresses Vorbis boundary ringing.
    seam=int(.018*SR);guard=np.ones(n);guard[:seam]=np.sin(np.linspace(0,np.pi/2,seam))**2;guard[-seam:]=guard[:seam][::-1]
    guard[:round(.006*SR)]=0;guard[-round(.006*SR):]=0
    # Rebuild the transition so the silent guard has zero slope on both sides.
    k=round(.006*SR)
    guard[k:seam]=np.sin(np.linspace(0,np.pi/2,seam-k))**2
    guard[-seam:-k]=guard[k:seam][::-1]
    y*=guard[:,None]
    return ac.normalize(y,-24,-3.2)

def main():
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=ROOT/'game/assets/audio/spells');p.add_argument('--seed',type=int,default=731904);args=p.parse_args()
    entries=[];names=list(DURATIONS)+['cinders_loop','roaming_embers_loop']
    for ni,name in enumerate(names):
        looping=name.endswith('_loop')
        for li,level in enumerate(LEVELS):
            for variant in range(1,3 if looping else 4):
                seed=args.seed+ni*1000+li*100+variant;rng=np.random.default_rng(seed)
                x=loop(name,li,rng) if looping else oneshot(name,li,rng)
                path=args.out/f'{name}_{level}_{variant:02d}.ogg';ac.write_ogg(path,x,5)
                decoded=ac.decode(path)
                # Conservative encoded true-peak guard, including codec overshoot.
                truepeak=ac.peak_db(signal.resample_poly(decoded,4,1))
                if truepeak> -1.5:
                    x*=10**((-1.7-truepeak)/20);ac.write_ogg(path,x,5);decoded=ac.decode(path)
                entries.append(dict(path='spells/'+path.name,duration_s=round(len(decoded)/SR,6),loop=looping,level=level,usage=('Zone de braises continue' if looping else name.replace('_',' ')),gain_db=-3 if looping else -1,peak_dbfs=round(ac.peak_db(decoded),3),rms_dbfs=round(ac.rms_db(decoded),3),seed=seed))
        print(name,flush=True)
    manifest=Path(__file__).with_name('spells_manifest.json');manifest.write_text(json.dumps(entries,indent=2,ensure_ascii=False),encoding='utf-8')
    print(f'{len(entries)} files; {manifest}',flush=True)
if __name__=='__main__':main()
