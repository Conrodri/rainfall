"""AU1: deterministic worn metal and water synthesis; uv run --with numpy --with scipy python art/tools/audio/au1_build.py."""
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
from gen_spells import burst
ROOT=Path(__file__).resolve().parents[3]
LEVELS=('light','medium','heavy')
SPECS={
'tocsin_rivets_rougis':(.30,.44,.60),
'tocsin_bras_grappins':(.55,.80,1.15),
'tocsin_coups_de_botte':(.48,.72,1.05),
'tocsin_tete_cloche':(1.15,1.80,2.50),
'goutte_lame':(.30,.44,.60),
'vague':(.70,1.15,1.70),
'flaque_miroir':(.65,1.00,1.45),
'crue':(1.35,2.05,2.80)}
AUTO={'tocsin_rivets_rougis','goutte_lame'}
def synth(name,level,hit,rng):
    dur=SPECS[name][level] if not hit else (.17,.24,.34)[level]
    n=round(dur*ac.SR);t=np.arange(n)/ac.SR;u=t/dur
    pitch=rng.uniform(.96,1.04)/(1+.27*level)
    x=np.zeros(n)
    def metal(start,base,amp,tail):
        age=np.maximum(t-start,0);gate=(t>=start)*(1-np.exp(-age/.003))
        y=np.zeros(n)
        for ratio,gain in [(1,1),(1.47,.52),(2.09,.35),(2.73,.22),(3.91,.12)]:
            y+=gain*np.sin(2*np.pi*base*pitch*ratio*age+.018*np.sin(2*np.pi*19*age))*np.exp(-age/(tail/(ratio**.5)))
        return y*gate*amp
    metal_kit=name.startswith('tocsin')
    if metal_kit:
        if name=='tocsin_rivets_rougis':
            x+=burst(n,rng,.009,.035,.32,(1800,10500))
            x+=ac.osc((2700-1700*np.minimum(u*3,1))*pitch)*np.sin(np.pi*np.clip(u*2,0,1))**2*.035*(not hit)
            x+=metal(.015 if hit else .065,710,.35,dur*.25)
        elif name=='tocsin_bras_grappins':
            for j in range(5+level*3):
                at=.025+j*dur*.55/(5+level*3)+rng.uniform(0,.012)
                x+=metal(at,rng.uniform(650,1450),.13,dur*.09)
                x+=burst(n,rng,at,.012,.17,(900,9000))
            x+=metal(dur*.62,240,.55,dur*.16)
            x+=burst(n,rng,dur*.62,.035,.5,(120,5500))
        elif name=='tocsin_coups_de_botte':
            x+=metal(.035,145,.65,dur*.23)
            for j in range(3+level):
                x+=metal(.09+j*.057,330+j*105,.18,dur*.12)
            x+=burst(n,rng,.025,.055,.8,(60,1900))
        else:
            strike=dur*.22
            x+=burst(n,rng,.01,dur*.08,.28,(250,4000))
            x+=metal(strike,175,.9,dur*.29)+metal(strike+.012,181,.3,dur*.25)
            x+=burst(n,rng,strike,.16+.065*level,.65,(45,3500))
    else:
        water=ac.filt(ac.noise(n,rng,'pink'),(100,4800),'bandpass')
        air=ac.filt(ac.noise(n,rng),(2200,11000),'bandpass')
        if name=='goutte_lame':
            env=(1-np.exp(-t/.008))*np.exp(-t/(dur*.18))
            x+=(water*.42+air*.17)*env
            x+=metal(.012,1350,.12,dur*.15)
            if hit:x+=burst(n,rng,.008,.033,.5,(350,8500))
        else:
            attack=.04 if name=='flaque_miroir' else dur*.14
            env=(1-np.exp(-t/attack))*np.exp(-u*3.3)*(1-u)**.7
            x+=(water*(.6+.18*level)+air*.10)*env
            if name=='flaque_miroir':
                x+=metal(.045,1050,.10,dur*.21)
            if name=='crue':
                x+=metal(.025,285,.20,dur*.15)
                x+=ac.filt(ac.noise(n,rng,'brown'),(38,320),'bandpass')*env*(.8+.3*level)
            for j in range(9+level*7):
                at=rng.uniform(.03,dur*.85);age=np.maximum(t-at,0)
                drop=np.sin(2*np.pi*(rng.uniform(650,1500)*pitch*age+22*np.log1p(age/.012)))
                x+=drop*(t>=at)*(1-np.exp(-age/.002))*np.exp(-age/.022)*rng.uniform(.025,.075)
                x+=burst(n,rng,at,.012,.06,(800,6500))
    if level:
        x+=ac.osc((100-20*level)*(1+np.exp(-t/.03)),None)*(1-np.exp(-t/.006))*np.exp(-t/(dur*.14))*.12*level
    x=ac.saturate(x,1.05+.25*level)
    y=ac.reverb(ac.stereo(x,.12+.10*level),rng,.04+.025*level,.09+.04*level)
    y=ac.fade(y,12)
    guard=round(.008*ac.SR);y[:guard]=0;y[-guard:]=0
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
            for kind in (('cast','hit') if name in AUTO else ('cast',)):
                files=[]
                for v in range(1,4 if name in AUTO else 3):
                    seed=22102600+idx*100+li*10+v+(10000 if kind=='hit' else 0)
                    path=ROOT/f'game/assets/audio/spells/spell_{name}_{kind}_{level}_{v:02}.ogg'
                    ac.write_ogg(path,synth(name,li,kind=='hit',np.random.default_rng(seed)))
                    decoded=ac.decode(path)
                    peak=ac.peak_db(signal.resample_poly(decoded,4,1))
                    if peak> -1:
                        ac.write_ogg(path,decoded*10**((-1.8-peak)/20));decoded=ac.decode(path)
                    e=dict(path='spells/'+path.name,duration_s=round(len(decoded)/ac.SR,6),loop=False,level=level,usage=f'AU1 {name} {kind}',gain_db=-1,peak_dbfs=round(ac.peak_db(decoded),3),rms_dbfs=round(ac.rms_db(decoded),3),seed=seed)
                    entries.append(e);delivered.append(e);files.append(e['path'])
                if kind=='cast':registry[f'spell.{name}.cast_{level}']={'files':files}
    mp.write_text(json.dumps(entries,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    sp.write_text(json.dumps(sounds,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    doc=ROOT/'game/assets/audio/MANIFEST.md';old=doc.read_text(encoding='utf-8').split('\n<!-- AU1 -->')[0]
    rows=['','<!-- AU1 -->','## AU1 — Tocsin et Averse','Synthèse numpy/scipy, graine fixe 22102600 ; Vorbis q5, 44100 Hz stéréo. Métal usé, cloche fêlée, eau et cuivre ; puissance croissante, registre descendant. Relance : art/tools/audio/au1_build.py.','']
    for name in SPECS:
        group=[e for e in delivered if e['usage'].split()[1]==name]
        rows.append(f"- {name} : {len(group)} fichiers cast"+(" + hit" if name in AUTO else "")+f", light/medium/heavy ; {min(e['duration_s'] for e in group):.2f}–{max(e['duration_s'] for e in group):.2f} s ; crête {max(e['peak_dbfs'] for e in group):.2f} dBFS ; RMS {min(e['rms_dbfs'] for e in group):.2f}–{max(e['rms_dbfs'] for e in group):.2f} dBFS.")
    doc.write_text(old+'\n'.join(rows)+'\n',encoding='utf-8')
    print(f'PASS AU1: {len(delivered)} Ogg generated')
if __name__=='__main__':main()
