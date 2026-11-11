"""VMR_AUDIO: deterministic dry material synthesis, Vorbis q5, no registry edits."""
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl

ROOT = Path(__file__).resolve().parents[3]
LEVELS = ('light', 'medium', 'heavy')
BASE_SEED = 3711000
# id: (duration ranges in ms, variants per level, material, RMS attenuation)
SPECS = {
 'vigie_trait_cast': ([(70,100),(90,130),(110,160)],3,'bow',4),
 'vigie_trait_hit': ([(60,90),(80,110),(100,140)],3,'arrow',4),
 'vigie_fusee_cast': ([(250,350),(330,450),(420,580)],2,'rocket',0),
 'vigie_fusee_hit': ([(120,180),(150,220),(200,300)],2,'magnesium',0),
 'vigie_filet_cast': ([(220,320),(300,420),(380,520)],2,'net_throw',0),
 'vigie_filet_hit': ([(100,160),(130,200),(170,260)],2,'net_land',0),
 'vigie_filet_burst_hit': ([(120,180)],2,'net_open',0),
 'vigie_grele_cast': ([(300,420),(400,550),(500,700)],2,'volley',0),
 'vigie_grele_hit': ([(60,100),(70,120),(90,140)],3,'arrow',4),
 'vigie_pointes_cast': ([(200,300),(260,380),(320,460)],2,'caltrops',0),
 'vigie_pointes_hit': ([(70,110)],2,'metal_tip',0),
 'vigie_repli': ([(140,220)],3,'dodge',0),
 'taille_estoc_cast': ([(100,150),(130,190),(160,240)],3,'wood_swish',4),
 'taille_estoc_hit': ([(70,110),(90,140),(110,170)],3,'fiber_cut',4),
 'fauche_lune_cast': ([(250,350),(330,450),(420,600)],2,'wide_swish',0),
 'fauche_lune_hit': ([(100,150),(130,200),(170,250)],2,'dense_cut',0),
 'aiguisage_cast': ([(250,350),(350,480),(450,620)],2,'polish',0),
 'morfil_aiguisage': ([(200,320)],3,'scrape',0),
 'lames_jumelles_cast': ([(220,320),(300,420),(380,540)],2,'double_draw',0),
 'lames_jumelles_hit': ([(90,140),(110,170),(140,210)],2,'double_cut',0),
 'iai_hit': ([(80,120),(100,150),(130,200)],3,'iai',0),
 'morfil_iai_clic': ([(80,140)],3,'scabbard',0),
 'dagues_demi_lune_cast': ([(90,130),(110,160),(140,210)],3,'fan',4),
 'dagues_demi_lune_hit': ([(60,90),(80,120),(100,150)],3,'dagger',4),
 'couteau_ficele_cast': ([(160,230),(200,290),(250,360)],2,'string_throw',0),
 'couteau_ficele_hit': ([(80,120),(100,150),(130,190)],2,'string_bite',0),
 'doublures_cast': ([(350,500),(450,650),(550,800)],2,'puppet',0),
 'doublures_hit': ([(150,220),(200,300),(260,400)],2,'plaster',0),
}

def target_rms(ident, level):
    if ident in ('vigie_repli','morfil_aiguisage','morfil_iai_clic'):
        return -24
    return ((-21,-20,-19) if ident.endswith('_hit') else (-24,-22,-20))[level] - SPECS[ident][3]

def synth(material, duration, level, rng):
    n = round(duration * ac.SR)
    t = np.arange(n) / ac.SR
    x = np.zeros(n)
    depth = (1-.09*level) * rng.uniform(.92,1.08)
    def add(y, at=0, amp=1):
        k = max(0,round(at*ac.SR)); length = min(len(y),n-k)
        if length > 0: x[k:k+length] += amp*y[:length]
    def air(at, length, lo, hi, amp=1, decay=False):
        m = max(8,round(length*ac.SR)); v = np.arange(m)/ac.SR
        y = sl.bp(rng.normal(size=m),lo*depth,hi*depth)
        env = (1-np.exp(-v/.001))*np.exp(-v/(length*.23)) if decay else np.sin(np.linspace(0,np.pi,m))**rng.uniform(.7,1.8)
        add(y*env,at,amp)
    def tap(at, freq=600, amp=1, tau=.022, metal=False):
        m = max(10,round(min(duration-at,tau*6)*ac.SR)); v=np.arange(m)/ac.SR
        y=np.zeros(m)
        ratios=(1,2.71,4.13,6.37) if metal else (1,1.49,2.31,3.62)
        for j,ratio in enumerate(ratios):
            f=freq*depth*ratio*rng.uniform(.96,1.04)
            y += np.sin(2*np.pi*f*v)*np.exp(-v/(tau/(1+j*.8)))/(1+j)
        y *= 1-np.exp(-v/.0005)
        add(y,at,amp)
        air(at,min(.018,duration-at),1000,9500,amp*.35,True)
    def fibers(at=0, amp=1):
        for _ in range(4+level):
            q=at+rng.uniform(0,.025)
            air(q,min(.035,duration-q),450,6500,amp*rng.uniform(.35,.7),True)
        tap(at,320,amp*.6,.018)
    def weights(start, stop, count, amp=.35):
        for at in np.linspace(start,stop,count)+rng.uniform(-.004,.004,count):
            tap(max(0,at),rng.uniform(900,1650),amp*rng.uniform(.6,1),.008,True)
    if material in ('bow','volley'):
        count=1 if material=='bow' else 4+level
        for at in np.linspace(.003,duration*.55,count):
            tap(at,rng.uniform(240,410),.8,.009)
            air(at+.008,duration*(.65 if count==1 else .32),2200,11500,.65)
    elif material=='arrow':
        tap(.002,rng.uniform(500,850),1,.009+level*.003)
        air(.004,duration*.55,1000,4800,.4,True)
    elif material=='rocket':
        raw=sl.bp(rng.normal(size=n),700,11000)
        low=sl.lp(raw,1500)
        u=t/duration
        add((low*(1-u)+raw*u)*np.sin(np.pi*u)**.7)
        for at in rng.uniform(.015,duration*.88,9+level*4):
            air(at,.014,4000,14500,.65,True)
    elif material=='magnesium':
        air(.001,duration*.95,1700,14000,1,True)
        for at in rng.uniform(.008,duration*.5,6+level*2):
            air(at,.016,2800,12500,.65,True)
    elif material in ('net_throw','net_land','net_open'):
        air(.006,duration*.87,500,6500,.9)
        if material=='net_throw': tap(.002,280,.8,.014)
        weights(duration*.2,duration*.79,4+level,.42)
        if material=='net_land': tap(.004,180,.6,.015)
    elif material in ('caltrops','metal_tip'):
        weights(.002,duration*(.72 if material=='caltrops' else .02),6+level if material=='caltrops' else 1,.9)
        if material=='caltrops': air(.01,duration*.85,1500,7000,.25)
    elif material=='dodge':
        tap(.004,145,.7,.02)
        air(.014,duration*.82,350,5000,.9)
        air(duration*.3,duration*.65,700,2400,.55)
    elif material in ('wood_swish','wide_swish','double_draw','iai'):
        starts=[.003,rng.uniform(.060,.090)] if material=='double_draw' else [.003]
        for at in starts:
            length=duration*.63 if len(starts)>1 else duration*.9
            air(at,length,180 if material=='wide_swish' else 500,4100,.9)
            air(at+.006,length*.7,1800,7600,.22)
            tap(at,310,.18,.012)
        if material=='iai': fibers(.018,.8)
    elif material in ('fiber_cut','dense_cut','double_cut'):
        fibers(.002,1.3 if material=='dense_cut' else 1)
        if material=='dense_cut': tap(.004,170,1,.028)
        if material=='double_cut': fibers(duration*.34,.7)
    elif material in ('polish','scrape'):
        air(.002,duration*.94,1300,6200,.8)
        # Broad wood formant: heavily damped fiber zing, no metal partials.
        fr=sl.bp(rng.normal(size=n),2100,3300)
        fr*= (.65+.35*np.sin(2*np.pi*rng.uniform(29,47)*t))*np.sin(np.pi*t/duration)**.8
        add(fr,amp=.7)
        if material=='polish': tap(duration*.6,1050,.13,.013)
    elif material=='scabbard':
        tap(.003,rng.uniform(700,1100),1,.006)
        tap(.003,340,.3,.004)
    elif material in ('fan','dagger'):
        air(.002,duration*.75,2200,10500,.65,material=='dagger')
        if material=='fan':
            for at in (.003,duration*.16,duration*.29): tap(at,rng.uniform(2100,3100),.2,.011,True)
        else: tap(.003,1200,.4,.009,True)
    elif material in ('string_throw','string_bite'):
        air(.002,duration*.85,1200,8500,.8,material=='string_bite')
        tap(.004 if material=='string_bite' else .02,rng.uniform(340,560),.55,.022)
        if material=='string_bite': fibers(.002,.6)
    elif material in ('puppet','plaster'):
        air(.003,duration*.9,250 if material=='puppet' else 600,6500,.85,material=='plaster')
        for at in rng.uniform(.006,duration*.6,4+level):
            tap(at,rng.uniform(200,650),.4,.015)
        bell_times=[duration*.27,duration*.52,duration*.7] if material=='puppet' else [duration*.19]
        for at in bell_times: tap(at,rng.uniform(2300,3400),.11,.023,True)
    else:
        raise ValueError(material)
    # Small stereo decorrelation, without a reverberation tail.
    side=sl.bp(rng.normal(size=n),600,6000)*np.sqrt(np.maximum(sl.lp(x*x,150),0)+1e-12)*.07
    y=np.column_stack((x+side,x-side))
    y-=y.mean(axis=0)
    y=np.tanh(y/(np.std(y)+1e-12)*.7)
    return ac.fade(y,1.5)

def main():
    out=ROOT/'game/assets/audio/spells'; rows=[]
    for gi,(ident,(ranges,count,material,_)) in enumerate(SPECS.items()):
        for li,(lo,hi) in enumerate(ranges):
            for vi in range(count):
                seed=BASE_SEED+gi*1000+li*100+vi
                rng=np.random.default_rng(seed)
                duration=(lo+(hi-lo)*rng.uniform(.4,.6))/1000
                level=LEVELS[li] if len(ranges)==3 else None
                name=f'spell_{ident}'+(f'_{level}' if level else '')+f'_{vi+1:02d}.ogg'
                path=out/name; target=target_rms(ident,li)
                y=synth(material,duration,li,rng)
                y*=10**((target-ac.rms_db(y))/20)
                for attempt in range(6):
                    ac.write_ogg(path,y,5); dec=ac.decode(path)
                    tp=ac.peak_db(signal.resample_poly(dec,4,1,axis=0))
                    rms=ac.rms_db(dec)
                    if tp<=-1.5 and abs(rms-target)<=.8: break
                    if tp>-1.5:
                        y=np.tanh(y*2)/2
                    y*=10**((target-rms)/20)
                else: raise RuntimeError(f'{name}: peak/RMS convergence')
                rows.append(dict(id=ident,path='spells/'+name,level=level,variant=vi+1,
                    seed=seed,duration_s=round(round(duration*ac.SR)/ac.SR,6),duration_range_ms=[lo,hi],
                    target_rms_dbfs=target,rms_dbfs=round(rms,3),peak_dbfs=round(ac.peak_db(dec),3),
                    true_peak_dbfs=round(tp,3),bytes=path.stat().st_size,
                    sample_rate=ac.SR,channels=2,quality=5))
    (Path(__file__).with_name('vmr_manifest.json')).write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    doc=ROOT/'game/assets/audio/MANIFEST.md'
    old=doc.read_bytes().split(b'<!-- VMR_AUDIO -->')[0]
    lines=['<!-- VMR_AUDIO -->','## VMR_AUDIO']
    for ident in SPECS:
        group=[r for r in rows if r['id']==ident]
        lines.append(f"- `{ident}` : {len(group)} variantes ; {min(r['duration_s'] for r in group)*1000:.1f}-{max(r['duration_s'] for r in group)*1000:.1f} ms ; crête max {max(r['true_peak_dbfs'] for r in group):.2f} dBFS ; RMS {min(r['rms_dbfs'] for r in group):.2f}-{max(r['rms_dbfs'] for r in group):.2f} dBFS.")
    doc.write_bytes(old+('' if old.endswith(b'\n') else '\n').encode()+('\n'.join(lines)+'\n').encode('utf-8'))
    print(f"PASS: {len(rows)} ogg; {sum(r['bytes'] for r in rows)} bytes")

if __name__=='__main__': main()
