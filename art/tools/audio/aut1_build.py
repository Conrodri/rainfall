"""AUT1: deterministic worn bell iron, bronze, steam and restrained electrical arcs."""
import json, subprocess
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl
from gen_spells import burst
from au3_build import write_ogg
ROOT=Path(__file__).resolve().parents[3]
LEVELS=('light','medium','heavy')

def synth(event,level,variant):
    rng=np.random.default_rng(23102600+event*100+level*10+variant)
    duration=((.48,.72,.98)[level] if event==0 else (.70 if event==1 else ((.14,.20,.26)[level] if event==2 else (.64 if event==3 else (.56,.84,1.18)[level]))))
    duration+=rng.uniform(-.008,.008)
    n=round(duration*ac.SR);t=np.arange(n)/ac.SR;u=t/duration
    pitch=rng.uniform(.95,1.05);x=np.zeros(n)
    def metal(f,tau,amp=1,fall=0):
        y=np.zeros(n)
        for i,r in enumerate((1,1.483,2.071,2.731,3.917,5.113)):
            freq=f*r*pitch*(1+fall*np.exp(-t/.13))
            y+=ac.osc(freq)*np.exp(-t/(tau/(1+i*.29)))*amp/(1+i*.8)
        return y
    def arcs(rate,amp,decay=.007):
        y=burst(n,rng,.018,decay,amp,(2100,11000))
        for at in np.arange(.025,duration-.025,1/rate):
            y+=burst(n,rng,float(at+rng.uniform(-.008,.008)),decay,amp*rng.uniform(.15,.65),(1700,10000))
        return y
    if event==0:
        x=metal(470-level*85,.065,.3)
        for at in (.018,.052,.094):x+=burst(n,rng,at,.012,.25,(1200,8000))
        air=ac.filt(ac.noise(n,rng),(360,5800),'bandpass')
        x+=air*(.16+.06*level)*np.sin(np.pi*u)**1.1*(.65+.35*np.cos(2*np.pi*(7-level)*t))
        x+=metal(160-level*24,.16,.15)*np.exp(-t/.2)
    elif event==1:
        x=metal(135,.28,.7)+metal(381,.16,.23)
        x+=burst(n,rng,0,.055,.65,(70,2100))
        x+=ac.filt(ac.noise(n,rng,'pink'),(40,260),'bandpass')*np.exp(-t/.15)*.4
        x+=arcs(26,.13)*(.25+.75*u)+metal(710,.42,.08)*(1-np.exp(-t/.06))
    elif event==2:
        x=arcs(18+level*9,.35+level*.07,.004+level*.002)*np.exp(-t/(.045+level*.025))
        x+=metal(860-level*140,.023+level*.012,.10+level*.03)
        if level==2:x+=ac.osc(np.full(n,285.))*np.exp(-t/.022)*.13
        x=ac.filt(x,430,'highpass')
    elif event==3:
        x=arcs(24,.21)*np.exp(-t/.15)
        x+=ac.filt(ac.noise(n,rng),(2400,10000),'bandpass')*.18*np.exp(-t/.19)
        x+=metal(630,.17,.12)
        for at in (.16,.31,.45):x+=burst(n,rng,at,.009,.035,(1800,7000))
    else:
        x=metal(194-level*39,.28+level*.18,.6, .22 if level==2 else .025)
        x+=burst(n,rng,0,.035,.3,(90,1800))
        x+=ac.osc((64-level*10)*(1+.25*np.exp(-t/.03)))*np.exp(-t/(.065+level*.035))*(.18+level*.08)
        x+=ac.filt(ac.noise(n,rng),(550,4200),'bandpass')*.035*np.exp(-t/.14)
    x=ac.stereo(x,.13 if event==2 else .27)
    x=ac.reverb(x,rng,.035 if event==2 else .09,.055 if event==2 else .12)
    target=(-21+level*1.5) if event==2 else (-23+level*1.4 if event in (0,4) else -24)
    y=ac.fade(sl.finish_oneshot(x,target,peak_db=-2.5,fade_in_ms=30,fade_out_ms=35),30)
    y[:441]*=np.linspace(0,1,441)[:,None]**2
    return ac.normalize(y,(-26+level*1.5) if event==2 else target,peak=-3.5)

def main():
    mp=Path(__file__).with_name('spells_manifest.json');entries=json.loads(mp.read_text(encoding='utf-8'))
    sp=ROOT/'game/data/audio/sounds.json';sounds=json.loads(sp.read_text(encoding='utf-8'));registry=sounds.get('sounds',sounds)
    delivered=[];keys=[]
    for event,kind in enumerate(('cast','impact','hit','end','cast')):
        name='tocsin_coup_de_tocsin' if event==4 else 'tocsin_bras_pilier'
        for level in (range(3) if event in (0,2,4) else (0,)):
            suffix=kind+'_'+LEVELS[level] if event in (0,2,4) else kind
            key=f'spell.{name}.{suffix}';files=[]
            for variant in range(1,3 if kind=='cast' else 4):
                path=ROOT/f'game/assets/audio/spells/spell_{name}_{suffix}_{variant:02}.ogg'
                x=synth(event,level,variant);write_ogg(path,x);decoded=ac.decode(path)
                peak=ac.peak_db(signal.resample_poly(decoded,4,1))
                if peak> -1:
                    write_ogg(path,x*10**((-1.8-peak)/20));decoded=ac.decode(path)
                entry=dict(path='spells/'+path.name,duration_s=round(len(decoded)/ac.SR,6),loop=False,level=LEVELS[level] if event in (0,2,4) else 'single',usage=f'AUT1 {name} {suffix}',gain_db=-1,peak_dbfs=round(ac.peak_db(decoded),3),rms_dbfs=round(ac.rms_db(decoded),3),seed=23102600+event*100+level*10+variant)
                delivered.append(entry);files.append(entry['path'])
            registry[key]={'files':files};keys.append(key)
    paths={e['path'] for e in delivered};entries=[e for e in entries if e['path'] not in paths]+delivered
    mp.write_text(json.dumps(entries,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    sp.write_text(json.dumps(sounds,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    doc=ROOT/'game/assets/audio/MANIFEST.md';old=doc.read_text(encoding='utf-8')
    import re
    old=re.sub(r'\n<!-- AUT1 -->.*?<!-- /AUT1 -->\n?','\n',old,flags=re.S)
    rows=['','<!-- AUT1 -->','## AUT1 - Tocsin','Synthese procedurale ; graine 23102600 ; Vorbis q5, 44100 Hz stereo. Fer use, bronze inharmonique, vapeur ; arcs discrets sans laser. Relance : art/tools/audio/aut1_build.py.','Impact et end : cles disponibles, cablage Audio.play requis.']
    rows += [f"- `{e['path']}` : {e['duration_s']:.6f} s." for e in delivered]
    rows+=['<!-- /AUT1 -->',''];doc.write_text(old+'\n'.join(rows),encoding='utf-8')
    print(f'PASS AUT1 files={len(delivered)} keys={len(keys)}')
if __name__=='__main__':main()

