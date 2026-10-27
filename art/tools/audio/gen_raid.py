"""Deterministic procedural raid audio. Run with uv run --with numpy --with scipy."""
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl
from gen_impacts import decode_exact
ROOT = Path(__file__).resolve().parents[3]
SPECS = {}
def add(group, entries):
    for entry in entries.split():
        name, level = entry.split(':')
        ident = ('ui.' if name == 'raid_progress' else 'enemy.') + group + name + ('.'+level if level != '-' else '')
        duration = .32 if level == 'light' else .75 if level == 'medium' else 1.4
        SPECS[ident] = dict(duration=duration, count=3, loop=False)
add('', 'raid_progress:- raid_shield_break:heavy raid_shield_up:heavy raid_barrage_warn:heavy raid_soak_fill:light raid_soak_burst:heavy raid_sector_warn:heavy raid_fixate_lock:medium raid_weakpoint_hit:light raid_weakpoint_break:medium raid_add_feed:medium raid_enrage_warn:heavy')
add('idol_', 'palm:medium carillon_warn:heavy carillon:heavy chaplet:light bell_throw:medium bell_ring:medium shield_up:heavy shield_break:heavy dike:medium anchor:heavy death:heavy')
add('gunner_', 'breech:medium rivet_hit:light pylon_plant:medium pylon_crack:medium pylon_break:heavy volley_warn:heavy reload:medium shell_whistle:medium shell:heavy shield_up:heavy vent:heavy stoker_feed:medium stoker_death:medium anchor:heavy death:heavy')
add('salt_king_', 'scepter:medium procession_warn:heavy reflux:medium stele:medium crust:heavy crust_crack:light crust_burst:heavy crown_hit:light crown_break:medium edict:heavy throne:heavy tears:medium death:heavy')
add('salt_', 'shield_up:heavy shield_break:heavy')
for ident, dur in {
 'enemy.shield_hum.loop':2.5, 'enemy.idol_stun.loop':3, 'enemy.idol_noria.loop':4,
 'enemy.gunner_volley.loop':4, 'enemy.gunner_stoker_walk.loop':2,
 'enemy.salt_king_tide.loop':6, 'amb.salt_court':16}.items():
    SPECS[ident] = dict(duration=dur, count=1, loop=True)
for ident, spec in SPECS.items():
    for token, dur in [('barrage_warn',1.5),('volley_warn',1.5),('sector_warn',1.2),
                       ('procession_warn',1.2),('reload',2),('shell_whistle',1.2),
                       ('vent',3),('rivet_hit',.105),('death.heavy',3.2)]:
        if token in ident: spec['duration'] = dur
SPECS['enemy.idol_chaplet.light']['count'] = 5
SPECS['enemy.salt_king_stele.medium']['count'] = 4

def expected():
    for ident,s in SPECS.items():
        suffixes = ['_light','_medium','_heavy'] if ident == 'enemy.gunner_volley.loop' else (
            [''] if s['loop'] else [f'_{i+1:02d}' for i in range(s['count'])])
        for i,suffix in enumerate(suffixes):
            yield ident,s,i,('ambience/' if s['loop'] else 'impacts/')+ident.replace('.','_')+suffix+'.ogg'

def synth(ident, s, variant, rng):
    n = round(s['duration']*ac.SR); t = np.arange(n)/ac.SR
    idol = 'idol_' in ident; iron = 'gunner_' in ident
    salt = 'salt' in ident; loop = s['loop']
    pitch = rng.uniform(.97,1.03)
    f = (185 if idol else 115 if iron else 310 if salt else 155)*pitch
    if any(k in ident for k in ('progress','chaplet','bell_ring')):
        f = (660 if 'progress' in ident else 420)*2**(variant*3/12)
    grain = ac.filt(ac.noise(n,rng), [180 if iron else 700, 7200 if salt else 4200], 'bandpass')
    if loop:
        # Fourier-domain textures and integer-cycle oscillators: circular before encoding.
        grain = sl.loop_noise(n,rng,lambda hz: (hz>80)*(hz<6500)/np.maximum(hz,80)**.65)
        cyc = lambda hz: np.sin(2*np.pi*round(hz*s['duration'])*np.arange(n)/n)
        if 'shield_hum' in ident:
            x = cyc(55)+.32*cyc(110)+.08*grain
        elif 'volley' in ident or 'walk' in ident:
            count = (12+variant*12) if 'volley' in ident else 4
            phase = np.arange(n)/n*count % 1
            env = (1-np.exp(-phase*150))*np.exp(-phase*28)
            x = env*(grain+.8*cyc(85))+.03*grain
        elif 'salt_court' in ident:
            x = .2*grain
            for freq in (98,146.8,196,233):
                x += .22*cyc(freq)*(1+.3*cyc((variant+2)/s['duration']))
            x = ac.filt(np.tile(x,3),[180,1900],'bandpass')[n:2*n]
        else:
            rate = 9 if 'stun' in ident else 6
            env = (.5+.5*cyc(rate/s['duration']))**8
            x = .25*grain*(.6+.4*cyc(1/s['duration']))+env*cyc(430 if idol else 1700)*.35
        # Circular stereo offset preserves the seam.
        y = np.column_stack((x,np.roll(x,137)*.94+np.roll(x,431)*.06))
        y -= y.mean(0)
        return ac.normalize(np.tanh(y), -18 if 'shield_hum' in ident else -24, -2.4)
    env = (1-np.exp(-t/.002))*np.exp(-t/(s['duration']*.22))
    x = grain*.28*env
    ratios = (1,2.76,4.13,5.42) if idol else (1,1.47,2.09,3.31) if iron else (1,1.26,1.5,2.83)
    for j,ratio in enumerate(ratios):
        x += np.sin(2*np.pi*f*ratio*t)*env/(j+1)
    if 'heavy' in ident:
        x += .8*ac.osc(48+90*np.exp(-t/.035))*np.exp(-t/.22)
    if any(k in ident for k in ('break','crack','burst','anchor','death','shell.heavy')):
        for at in rng.uniform(.005,s['duration']*.4,9 if 'death' in ident else 5):
            u = np.maximum(t-at,0)
            x += grain*(t>=at)*np.exp(-u/.032)*.55
    if any(k in ident for k in ('warn','shield_up','crust.heavy')):
        rise = np.sin(np.pi*np.minimum(t/s['duration'],1))**.7
        x = .35*grain*rise+ac.osc(f*(1+t/s['duration']*.8))*(.6+.4*np.sin(2*np.pi*7*t))*rise
        if salt:
            for hz in (98,123.47,146.83):
                x += .25*np.sin(2*np.pi*hz*t+.7*np.sin(2*np.pi*hz*2*t))*rise
    if any(k in ident for k in ('feed','reflux','whistle','throw')):
        x += ac.osc(f*(.4+2*t/s['duration']))*np.sin(np.pi*t/s['duration'])*.8
    if 'vent' in ident: x = grain*ac.adsr(n,.08,.3,.65,.6)
    if 'reload' in ident or 'carillon_warn' in ident:
        for at in np.arange(.02,s['duration']*.8,.12 if iron else .09):
            u=np.maximum(t-at,0)
            x += (t>=at)*np.exp(-u/.018)*(grain+np.sin(2*np.pi*f*3*t))
    if 'tears' in ident or 'soak_fill' in ident:
        x += ac.osc(950+1700*np.exp(-t/.025))*env
    y = ac.stereo(ac.reverb(x,rng,.16 if iron else .32,.13),.18)
    y = sl.finish_oneshot(y,-20,peak_db=-2.3)
    blocks=[y[k:k+882] for k in range(0,n,882)]
    active=np.concatenate([b for b in blocks if ac.rms_db(b)>-35])
    return ac.normalize(y,-20+ac.rms_db(y)-ac.rms_db(active),-2.3)

def main():
    rows=[]
    for index,(ident,s,v,rel) in enumerate(expected()):
        path=ROOT/'game/assets/audio'/rel
        y=synth(ident,s,v,np.random.default_rng(27102026+index))
        # Verify decoded output; compensate codec gain and true peak when necessary.
        for attempt in range(3):
            ac.write_ogg(path,y,quality=5)
            x,info=decode_exact(path)
            peak=ac.peak_db(signal.resample_poly(x,4,1,axis=0))
            if peak<=-1.5: break
            y*=10**((-1.8-peak)/20)
        rows.append(dict(id=ident,path=rel,usage=ident.split('.')[1]+'; '+('boucle circulaire' if s['loop'] else f'variante {v+1}'),
                         duration_s=float(info['duration']),loop=s['loop'],rms_dbfs=round(ac.rms_db(x),3),
                         peak_dbfs=round(peak,3)))
    Path(__file__).with_name('raid_manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS generation: {len(rows)} Ogg q5')
if __name__=='__main__': main()
