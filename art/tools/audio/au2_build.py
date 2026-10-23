"""AU2 procedural material synthesis. Run with uv run --with numpy --with scipy python art/tools/audio/au2_build.py."""
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
from gen_spells import burst
ROOT=Path(__file__).resolve().parents[3]
LEVELS=('light','medium','heavy')
SPECS={'arpenteuse_chaine':(.13,.19,.27),'arpenteuse_boucle':(.52,.83,1.18),'arpenteuse_piquet':(.45,.73,1.04),'arpenteuse_tendeur':(1.05,1.60,2.20),'rainette_langue':(.20,.30,.43),'rainette_grand_saut':(.65,1.04,1.48),'rainette_gluant':(.46,.74,1.06),'rainette_chant_de_crue':(1.40,2.10,2.80)}
AUTO={'arpenteuse_chaine','rainette_langue'}

def synth(name,level,hit,rng):
    dur=(.13,.19,.27)[level] if name=='arpenteuse_chaine' else ((.12,.18,.26)[level] if hit else SPECS[name][level])
    n=round(dur*ac.SR);t=np.arange(n)/ac.SR;u=t/dur
    pitch=rng.uniform(.96,1.04)/(1+.30*level)
    x=np.zeros(n)
    def env(at,tail,attack=.003):
        age=np.maximum(t-at,0)
        return (t>=at)*(1-np.exp(-age/attack))*np.exp(-age/tail)
    def metal(at,base,amp,tail):
        age=np.maximum(t-at,0);y=np.zeros(n)
        for ratio,gain in ((1,1),(1.43,.61),(2.17,.39),(3.76,.19),(5.19,.08)):
            y+=gain*np.sin(2*np.pi*base*pitch*ratio*age)*env(at,tail/ratio**.6)
        return amp*y
    def splash(at,tail,amp):
        y=burst(n,rng,at,tail,amp,(110,4300))
        for j in range(5+level*4):
            a=at+rng.uniform(.006,tail*2);age=np.maximum(t-a,0)
            f=rng.uniform(380,1050)*pitch
            y+=np.sin(2*np.pi*(f*age+12*np.log1p(age/.012)))*env(a,.018+.008*level)*amp*.16
        return y
    if name.startswith('arpenteuse'):
        if name=='arpenteuse_chaine':
            for j in range(3+2*level):
                at=.009+j*dur*.48/(3+2*level)
                x+=metal(at,rng.uniform(950,1900),.12,.018+.008*level)
                x+=burst(n,rng,at,.012,.22,(2100,10000))
        elif name=='arpenteuse_boucle':
            whip=np.sin(np.pi*np.clip(u/.38,0,1))**2
            x+=ac.filt(ac.noise(n,rng),(500,6500),'bandpass')*whip*.23
            x+=metal(dur*.34,510,.32,dur*.13)
            x+=burst(n,rng,dur*.35,dur*.20,.8,(90,4800))
            for j in range(6+level*4):x+=burst(n,rng,rng.uniform(dur*.37,dur*.76),.009,.10,(2000,11000))
        elif name=='arpenteuse_piquet':
            x+=burst(n,rng,.018,.045,.85,(60,2100))+metal(.022,240,.5,dur*.13)
            x+=metal(dur*.24,700,.22,dur*.25)*(1+.12*np.sin(2*np.pi*29*t))
            for j in range(4+level*2):x+=metal(.06+j*.024,1100,.08,.035)
        else:
            strike=dur*.14
            x+=metal(strike,190,.7,dur*.20)+burst(n,rng,strike,.10+.045*level,1,(45,5800))
            count=14+level*10
            for j in range(count):
                at=dur*(.27+.52*(j/count)**.78)
                x+=metal(at,rng.uniform(650,1100),.12,dur*.025)
                x+=burst(n,rng,at,.009,.24,(700,6500))
            x+=ac.filt(ac.noise(n,rng),(180,2100),'bandpass')*env(dur*.25,dur*.25,.04)*.18
    elif name=='rainette_langue':
        x+=splash(.012,.026+.012*level,.65 if hit else .38)
        x+=ac.osc((520*pitch)*(1+2*np.exp(-t/.013)))*env(.009,dur*.12)*.25
        if not hit:x+=burst(n,rng,.008,.013,.4,(900,6300))
    elif name=='rainette_grand_saut':
        x+=ac.filt(ac.noise(n,rng),(100,1400),'bandpass')*env(.015,dur*.10,.02)*.25
        x+=burst(n,rng,dur*.20,dur*.09,.35,(500,6500))
        x+=splash(dur*.48,dur*.12,.9)
        age=np.maximum(t-dur*.48,0)
        x+=ac.osc((92-16*level)*(1+np.exp(-age/.025)))*env(dur*.48,dur*.12)*.65
    elif name=='rainette_gluant':
        x+=splash(.016,.025,.32)+burst(n,rng,.045,.035,.23,(170,2600))
        x+=splash(dur*.31,dur*.16,.8)
        x+=ac.filt(ac.noise(n,rng),(80,900),'bandpass')*env(dur*.33,dur*.20)*.25
    else:
        # Breath through reeds, swelling vocal sac, rough resonant croak, flood.
        inflation=(1-np.exp(-t/.12))*np.exp(-u*7)
        x+=ac.filt(ac.noise(n,rng),(160,1800),'bandpass')*inflation*.28
        f=(112-22*level)*pitch*(1+.12*np.sin(2*np.pi*u*1.4))
        voice=ac.osc(f,kind='saw')+.16*ac.noise(n,rng)
        throat=sum(ac.biquad(voice,hz,3.5)*gain for hz,gain in ((310,1),(730,.7),(1450,.23)))
        croak=env(dur*.20,dur*.24,.065)*( .72+.28*np.sin(2*np.pi*(24-3*level)*t))
        x+=throat*croak*2.3
        x+=ac.filt(ac.noise(n,rng,'brown'),(38,1400),'bandpass')*env(dur*.39,dur*.22,.10)*(.5+.18*level)
        for j in range(8+level*6):x+=splash(rng.uniform(dur*.46,dur*.78),.025,.055)
    # Heavier gestures carry more low material and less bright surface fizz.
    x=ac.filt(x,10500/(1+.32*level))
    x=ac.saturate(x,1.05+.25*level)
    y=ac.reverb(ac.stereo(x,.12+.10*level),rng,.035+.025*level,.08+.04*level)
    guard=round(.008*ac.SR)
    y=np.pad(ac.fade(y[guard:-guard],14),((guard,guard),(0,0)))
    return ac.normalize(y,-21+level,-3.5)

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
            for kind in (('hit',) if name=='arpenteuse_chaine' else (('cast','hit') if name in AUTO else ('cast',))):
                files=[]
                for v in range(1,4 if name in AUTO else 3):
                    seed=22102680+idx*100+li*10+v+(10000 if kind=='hit' else 0)
                    path=ROOT/f'game/assets/audio/spells/spell_{name}_{kind}_{level}_{v:02}.ogg'
                    ac.write_ogg(path,synth(name,li,kind=='hit',np.random.default_rng(seed)))
                    decoded=ac.decode(path)
                    peak=ac.peak_db(signal.resample_poly(decoded,4,1))
                    if peak> -1:
                        ac.write_ogg(path,decoded*10**((-1.8-peak)/20));decoded=ac.decode(path)
                    e=dict(path='spells/'+path.name,duration_s=round(len(decoded)/ac.SR,6),loop=False,level=level,usage=f'AU2 {name} {kind}',gain_db=-1,peak_dbfs=round(ac.peak_db(decoded),3),rms_dbfs=round(ac.rms_db(decoded),3),seed=seed)
                    entries.append(e);delivered.append(e);files.append(e['path'])
                if kind=='cast':registry[f'spell.{name}.cast_{level}']={'files':files}
    mp.write_text(json.dumps(entries,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    sp.write_text(json.dumps(sounds,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    doc=ROOT/'game/assets/audio/MANIFEST.md';old=doc.read_text(encoding='utf-8'); start=old.find('\n<!-- AU2 -->'); old=old[:start] if start>=0 else old
    rows=['','<!-- AU2 -->','## AU2 — Arpenteuse et Rainette','Synthèse numpy/scipy, graine fixe 22102680 ; Vorbis q5, 44100 Hz stéréo. Cuivre chauffé, maillons usés et cliquet de touret ; langue humide, roseaux, vase et crue ; puissance croissante, registre descendant. Relance : art/tools/audio/au2_build.py.','']
    for name in SPECS:
        group=[e for e in delivered if e['usage'].split()[1]==name]
        rows.append(f"- {name} : {len(group)} fichiers"+(" (cast + hit)" if name=='rainette_langue' else (' (hit seul)' if name=='arpenteuse_chaine' else ' (cast)'))+f", light/medium/heavy ; {min(e['duration_s'] for e in group):.2f}–{max(e['duration_s'] for e in group):.2f} s ; crête {max(e['peak_dbfs'] for e in group):.2f} dBFS ; RMS {min(e['rms_dbfs'] for e in group):.2f}–{max(e['rms_dbfs'] for e in group):.2f} dBFS.")
    doc.write_text(old+'\n'.join(rows)+'\n',encoding='utf-8')
    print(f'PASS AU2: {len(delivered)} Ogg generated')
if __name__=='__main__':main()
