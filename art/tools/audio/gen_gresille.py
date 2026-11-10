import json, sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import numpy as np
from scipy import signal
import audio_common as ac
ROOT=Path(__file__).resolve().parents[3]
LEVELS=('light','medium','heavy')
SPECS={
'spell.gresille_arc.cast':([.11,.135,.17],3,-24,'spells','Arc court, cast'),
'spell.gresille_arc.hit':([.09,.115,.14],3,-23,'spells','Arc court, impact'),
'spell.gresille_decharge.cast':([.33,.44,.57],2,-21.5,'spells','Décharge, cast'),
'spell.gresille_decharge.hit':([.125,.16,.20],2,-22,'spells','Décharge, arcs voisins'),
'spell.gresille_terre.cast':([.36,.48,.60],2,-22,'spells','Terre, tige'),
'spell.gresille_ground.loop':([2.1,2.3],2,-28,'spells','Boucle de sol'),
'spell.gresille_storm.cast':([.55,.8,1.1],3,-21,'spells','Orage, foudre'),
'spell.gresille_orage.ultimate':([1.6],1,-21,'spells','Orage ultime, charge'),
'gresille.zap':([.115]*4,4,-19,'impacts','Claquement blanc'),
'gresille.jars':([.35]*3,3,-26,'impacts','Bouteilles de Leyde')}

def synth(ident,dur,lev,rng):
 n=round(dur*ac.SR); t=np.arange(n)/ac.SR; u=t/dur; x=np.zeros(n); level=lev
 def ring(at,f,amp,tau,inh=.2):
  age=np.maximum(t-at,0); gate=(t>=at)*(1-np.exp(-age/.0015)); y=np.zeros(n)
  for ratio,g in [(1,1),(1.414,.48),(2.13,.3),(2.77,.18),(3.61,.10)]:
   y+=g*np.sin(2*np.pi*f*ratio*age+inh*np.sin(2*np.pi*13*age))*np.exp(-age/(tau/(ratio**.35)))
  return amp*y*gate
 impact='hit' in ident or ident=='gresille.zap'
 storm='storm' in ident or 'orage' in ident
 earth='terre' in ident
 loop='loop' in ident
 jars='jars' in ident
 peakfreq=rng.uniform(2100,3700)*(1-.10*level)
 if loop:
  # periodic in phase so endpoints join; sparse sparks with wrapped envelopes
  x=.14*np.sin(2*np.pi*180*t)+.07*np.sin(2*np.pi*100*t)+.05*np.sin(2*np.pi*310*t)
  x+=.075*ac.filt(rng.normal(size=n),(500,3400),'bandpass')
  for _ in range(34):
   at=rng.uniform(0,dur); age=(t-at)%dur; x+=.20*rng.normal(size=n)*np.exp(-age/.0011)*(age<.012)
 elif jars:
  for j in range(4):
   at=.04+j*.072+rng.uniform(-.012,.012); x+=ring(at,rng.uniform(1250,3900),rng.uniform(.06,.14),rng.uniform(.12,.22))
  x+=.04*np.sin(2*np.pi*185*t)*np.exp(-t/.18)
 else:
  # opening broadband crack and glass/arc resonances
  crack=rng.normal(size=n)*np.exp(-t/rng.uniform(.00045,.0011))
  x+= (1.4 if impact else .8)*crack
  x+=ring(.001,peakfreq,rng.uniform(.23,.42),rng.uniform(.055,.15))
  if earth:
   x+=.75*np.sin(2*np.pi*rng.uniform(75,105)*t)*np.exp(-t/.055)
   x+=ring(.018,720,rng.uniform(.25,.42),dur*.42)
  if storm:
   # short dry thunder with no long reverberant tail
   th=ac.filt(rng.normal(size=n),(90,650),'bandpass')*np.exp(-np.maximum(t-.035,0)/.12)*(t>.035)
   x+=th*(.55+.7*level)
  if 'ultimate' in ident:
   x+=.17*np.sin(2*np.pi*(220+1200*u**2)*t)*u
   x+=.11*np.sin(2*np.pi*185*t)*u
  count=(3+level*3) if ('decharge' in ident or 'cast' in ident) else 2+level
  if storm: count+=5
  for _ in range(count):
   at=rng.uniform(.008,dur*.78); age=np.maximum(t-at,0); gate=(t>=at)
   env=np.exp(-age/rng.uniform(.001,.004))*gate
   x+=rng.normal(size=n)*env*rng.uniform(.04,.16)
  if 'decharge' in ident or 'cast' in ident:
   x+=ac.filt(rng.normal(size=n),(2400,10500),'bandpass')*np.exp(-t/(dur*.22))*.09
 # smooth loop boundary only via periodic construction; one-shots have short fades
 if not loop:
  k=max(1,round(ac.SR*.002)); x[:k]*=np.linspace(0,1,k); x[-k:]*=np.linspace(1,0,k)
 y=np.column_stack([x, np.roll(x,rng.integers(2,120))*.96])
 if not loop: y[:2]=0; y[-2:]=0
 target=-28 if loop else (-26 if jars else (-19 if impact else (-24+level*1.2)))
 if storm: target=-22+level*.5
 if earth: target=-23+level*.7
 y*=10**((target-ac.rms_db(y))/20)
 y=np.tanh(y*1.5)/1.5
 return y

def main():
 out=ROOT/'game/assets/audio'; rows=[]; registry=json.loads((ROOT/'game/data/audio/sounds.json').read_text(encoding='utf-8')); sounds=registry['sounds']
 for gi,(ident,(durs,nvar,target,folder,usage)) in enumerate(SPECS.items()):
  levels=[None] if ident in ('spell.gresille_ground.loop','spell.gresille_orage.ultimate','gresille.zap','gresille.jars') else list(LEVELS)
  for li,levname in enumerate(levels):
   key=ident if levname is None else ident+'_'+levname
   files=[]
   for vi in range(nvar):
    lev=li if levname is not None else min(vi,2)
    dur=durs[lev] if len(durs)==3 else durs[min(vi,len(durs)-1)]
    rng=np.random.default_rng(2261022+gi*997+li*31+vi)
    y=synth(ident,dur,lev,rng)
    name=key.replace('.','_')+f'_{vi+1:02d}.ogg'; path=out/folder/name
    for _ in range(4):
     ac.write_ogg(path,y,5); dec=ac.decode(path); tp=ac.peak_db(signal.resample_poly(dec,4,1,axis=0))
     if tp<=-1.5: break
     y*=10**((-1.8-tp)/20)
    else: raise RuntimeError('peak '+name)
    files.append(f'{folder}/{name}')
    rows.append(dict(path=f'{folder}/{name}',duration_s=round(len(dec)/ac.SR,6),loop=ident.endswith('.loop'),level=levname or 'medium',usage=key,gain_db=0,peak_dbfs=round(ac.peak_db(dec),3),rms_dbfs=round(ac.rms_db(dec),3),seed=2261022+gi*997+li*31+vi))
   entry={'files':files}
   if ident in ('gresille.zap','gresille.jars'): entry['family']='impacts'
   if ident=='spell.gresille_ground.loop': entry['max_instances']=3
   sounds[key]=entry
 (ROOT/'art/tools/audio/gresille_manifest.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
 (ROOT/'game/data/audio/sounds.json').write_text(json.dumps(registry,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
 doc=ROOT/'game/assets/audio/MANIFEST.md'; old=doc.read_text(encoding='utf-8').split('\n<!-- GRESILLE_AUDIO -->')[0]
 lines=['','<!-- GRESILLE_AUDIO -->','## GRESILLE_AUDIO','Synthèse numpy/scipy déterministe ; Vorbis q5, 44,1 kHz stéréo.']
 for ident in SPECS:
  group=[r for r in rows if r['usage']==ident or r['usage'].startswith(ident+'_')]
  lines.append(f"- `{ident}` : {len(group)} variantes, {min(r['duration_s'] for r in group):.2f}–{max(r['duration_s'] for r in group):.2f} s ; crête max {max(r['peak_dbfs'] for r in group):.2f} dBFS ; RMS {min(r['rms_dbfs'] for r in group):.2f}–{max(r['rms_dbfs'] for r in group):.2f} dBFS.")
 doc.write_text(old+'\n'.join(lines)+'\n',encoding='utf-8')
 print(f'PASS: {len(rows)} Ogg')
if __name__=='__main__': main()
