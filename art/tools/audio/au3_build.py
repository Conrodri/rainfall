"""AU3 deterministic worn-material synthesis; delivery logic adapted from au2_build.py."""
import json, subprocess
from scipy.io import wavfile
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
from gen_spells import burst
ROOT=Path(__file__).resolve().parents[3]
LEVELS=('light','medium','heavy')
SPECS={'avare_coup_de_coffre':(.32,.49,.72),'avare_poignee_de_pieces':(.30,.49,.74),'avare_rancon':(.58,.94,1.35),'avare_faillite':(1.25,1.92,2.60),'gifle_de_vase':(.23,.36,.53),'detacher':(.19,.48,.79),'rappel':(.48,.78,1.15),'bourbier':(1.30,2.05,2.80)}
AUTO={'avare_coup_de_coffre','gifle_de_vase'}

def synth(name,level,hit,rng):
    dur=(.14,.22,.32)[level] if hit else SPECS[name][level]
    n=round(dur*ac.SR);t=np.arange(n)/ac.SR;u=t/dur
    pitch=rng.uniform(.96,1.04)/(1+.30*level);x=np.zeros(n)
    def env(at,tail,attack=.004):
        age=np.maximum(t-at,0)
        return (t>=at)*(-np.expm1(-age/attack))*np.exp(-age/tail)
    def metal(at,base,amp,tail):
        age=np.maximum(t-at,0);y=np.zeros(n)
        for ratio,gain in ((1,1),(1.47,.52),(2.31,.26),(3.91,.12)):
            y+=gain*np.sin(2*np.pi*base*pitch*ratio*age)*env(at,tail/ratio**.7)
        return amp*y
    def coins(start,end,count,amp):
        y=np.zeros(n)
        for j in range(count):
            at=start+(end-start)*(j+rng.uniform(.1,.9))/count
            y+=metal(at,rng.uniform(1600,3500),amp*rng.uniform(.5,1),.028+.008*level)
            y+=burst(n,rng,at,.004,amp*.6,(1900,9000))
        return y
    def mud(at,tail,amp):
        y=burst(n,rng,at,tail,amp,(65,2800))
        for j in range(5+level*5):
            a=at+rng.uniform(.005,tail*2);age=np.maximum(t-a,0)
            f=rng.uniform(130,480)*pitch
            y+=np.sin(2*np.pi*(f*age+5*np.log1p(age/.018)))*env(a,.023+.008*level)*amp*.22
        return y
    if name.startswith('avare'):
        if name=='avare_coup_de_coffre':
            strike=.015 if hit else dur*.30
            if not hit:
                x+=ac.filt(ac.noise(n,rng),(180,2300),'bandpass')*np.sin(np.pi*np.clip(u/.34,0,1))**2*.22
                x+=coins(.012,strike,3+level*2,.08)
            x+=burst(n,rng,strike,.022+.014*level,.85,(85,1900))
            x+=metal(strike,155,.34,.045+.02*level)+metal(strike,520,.10,.035)
            x+=coins(strike+.012,dur*.68,4+level*3,.055)
        elif name=='avare_poignee_de_pieces':
            x+=burst(n,rng,.012,.018,.16,(800,5500))
            x+=coins(.02,dur*.70,8+level*9,.11)
        elif name=='avare_rancon':
            at=dur*.13
            x+=burst(n,rng,at,.07+.035*level,.95,(45,1600))
            x+=metal(at,92,.42,dur*.12)+metal(at,330,.15,.08)
            x+=coins(at+.04,dur*.73,10+level*9,.085)
        else:
            at=dur*.12
            x+=burst(n,rng,at,.10+.06*level,1,(55,5800))+metal(at,110,.48,.15)
            x+=coins(at+.025,dur*.85,35+level*30,.10)
            x+=ac.filt(ac.noise(n,rng),(350,3600),'bandpass')*env(at,dur*.22,.02)*.13
    else:
        if name=='gifle_de_vase':
            at=.014 if hit else dur*.20
            x+=mud(at,.023+.015*level,.85 if hit else .58)
            if not hit:x+=burst(n,rng,.01,.02,.20,(130,1700))
        elif name=='detacher':
            x+=ac.filt(ac.noise(n,rng),(110,2300),'bandpass')*env(.012,dur*.19,.015)*(.18+.06*level)
            x+=metal(.016,170,.07,dur*.16)*(1+.35*np.sin(2*np.pi*43*t))
            x+=mud(dur*.43,dur*.085,.45)
        elif name=='rappel':
            suction=np.sin(np.pi*np.clip(u/.48,0,1))**2
            x+=ac.filt(ac.noise(n,rng),(80,1900),'bandpass')*suction*.35
            x+=metal(.02,210,.065,dur*.2)
            for j in range(3+level*2):x+=mud(dur*(.40+.32*j/(3+level*2)),.03+.012*level,.35)
        else:
            x+=ac.filt(ac.noise(n,rng,'brown'),(35,1150),'bandpass')*env(.02,dur*.30,.13)*(.65+.18*level)
            for j in range(12+level*12):x+=mud(rng.uniform(.08,dur*.77),.035+.012*level,.10)
            x+=metal(dur*.10,125,.12,dur*.22)
            x+=mud(dur*.66,dur*.07,.5)
    x=ac.saturate(ac.filt(x,9500/(1+.35*level)),1.05+.25*level)
    y=ac.reverb(ac.stereo(x,.12+.1*level),rng,.03+.025*level,.07+.035*level)
    guard=round(.008*ac.SR)
    y=np.pad(ac.fade(y[guard:-guard],14),((guard,guard),(0,0)))
    return ac.normalize(y,(-24 if name=='detacher' and level==0 else -21+level),-3.5)

def write_ogg(path,x):
    # Bitexact muxing fixes Vorbis serial numbers as well as the procedural seed.
    wav=path.with_suffix('.wav')
    wavfile.write(wav,ac.SR,(np.clip(x,-1,1)*32767).astype(np.int16))
    try:
        subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(wav),'-c:a','libvorbis','-q:a','5','-fflags','+bitexact',str(path)],check=True)
    finally:wav.unlink(missing_ok=True)

def main():
    mp=Path(__file__).with_name('spells_manifest.json')
    entries=json.loads(mp.read_text(encoding='utf-8'))
    prefixes=tuple('spells/spell_'+name+'_' for name in SPECS)
    entries=[e for e in entries if not e['path'].startswith(prefixes)]
    sp=ROOT/'game/data/audio/sounds.json';sounds=json.loads(sp.read_text(encoding='utf-8'))
    # Preserve the existing registry container and every unrelated entry.
    registry=sounds['sounds'] if 'sounds' in sounds else sounds
    delivered=[]
    for idx,name in enumerate(SPECS):
        for li,level in enumerate(LEVELS):
            for kind in (('cast','hit') if name in AUTO else ('cast',)):
                files=[]
                for v in range(1,4 if name in AUTO else 3):
                    seed=22102690+idx*100+li*10+v+(10000 if kind=='hit' else 0)
                    path=ROOT/f'game/assets/audio/spells/spell_{name}_{kind}_{level}_{v:02}.ogg'
                    write_ogg(path,synth(name,li,kind=='hit',np.random.default_rng(seed)))
                    decoded=ac.decode(path)
                    peak=ac.peak_db(signal.resample_poly(decoded,4,1))
                    if peak> -1:
                        write_ogg(path,decoded*10**((-1.8-peak)/20));decoded=ac.decode(path)
                    e=dict(path='spells/'+path.name,duration_s=round(len(decoded)/ac.SR,6),loop=False,level=level,usage=f'AU3 {name} {kind}',gain_db=-1,peak_dbfs=round(ac.peak_db(decoded),3),rms_dbfs=round(ac.rms_db(decoded),3),seed=seed)
                    entries.append(e);delivered.append(e);files.append(e['path'])
                if kind=='cast':registry[f'spell.{name}.cast_{level}']={'files':files}
    mp.write_text(json.dumps(entries,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    sp.write_text(json.dumps(sounds,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    doc=ROOT/'game/assets/audio/MANIFEST.md';old=doc.read_text(encoding='utf-8'); start=old.find('\n<!-- AU3 -->'); old=old[:start] if start>=0 else old
    rows=['','<!-- AU3 -->','## AU3 - Avare et Bourbe','Synthese procedurale numpy/scipy, graine fixe 22102690 ; Ogg Vorbis q5, 44100 Hz stereo. Bois cercle de fer, chaines et or use ; vase, racines et bronze etouffe. Trois puissances plus longues, graves et denses. Relance : art/tools/audio/au3_build.py.','']
    for name in SPECS:
        group=[e for e in delivered if e['usage'].split()[1]==name]
        rows.append(f"- {name} : {len(group)} fichiers ({'cast + hit' if name in AUTO else 'cast'}) ; {min(e['duration_s'] for e in group):.2f} - {max(e['duration_s'] for e in group):.2f} s ; crete {max(e['peak_dbfs'] for e in group):.2f} dBFS ; RMS {min(e['rms_dbfs'] for e in group):.2f} - {max(e['rms_dbfs'] for e in group):.2f} dBFS.")
    doc.write_text(old+'\n'.join(rows)+'\n',encoding='utf-8')
    print(f'PASS AU3: {len(delivered)} Ogg generated')
if __name__=='__main__':main()
