"""PASS/FAIL validator for VARIANTES_AUDIO exports."""
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
from gen_variantes import ITEMS, LEVELS, RANGES, AUTO_IDS
ROOT=Path(__file__).resolve().parents[3]
def fail(msg): raise SystemExit('FAIL: '+msg)
def main():
 rows=json.loads(Path(__file__).with_name('variantes_manifest.json').read_text(encoding='utf-8')); out=ROOT/'game/assets/audio/spells'; expected=[]
 for ident,(_,forms,_,base) in ITEMS.items():
  for form in (('cast','hit') if forms=='both' else ('cast',)):
   for level in LEVELS:
    for vi in (1,2): expected.append((ident,form,level,vi,base))
 if len(rows)!=len(expected):fail(f'count {len(rows)} != {len(expected)}')
 by={}; nbytes=0
 for ident,form,level,vi,base in expected:
  r=next((q for q in rows if q['id']==ident and q['form']==form and q['level']==level and q['variant']==vi),None)
  if not r:fail(f'missing {ident}/{form}/{level}/{vi}')
  p=out/Path(r['path']).name
  if not p.is_file():fail('missing file '+p.name)
  if p.stat().st_size>=5_000_000:fail('file >= 5 MB '+p.name)
  nbytes+=p.stat().st_size; y=ac.decode(p)
  if y.ndim!=2 or y.shape[1]!=2 or len(y)==0:fail('format '+p.name)
  dur=len(y)/ac.SR; lo,hi=RANGES[form][LEVELS.index(level)]
  if not lo/1000-0.025<=dur<=hi/1000+0.025:fail(f'duration {p.name} {dur}')
  tp=ac.peak_db(signal.resample_poly(y,4,1,axis=0)); rms=ac.rms_db(y); target=r['target_rms_dbfs']
  if tp>-1.5:fail(f'peak {p.name} {tp:.2f}')
  if abs(rms-target)>1.5:fail(f'RMS {p.name} {rms:.2f} target {target}')
  if not (np.std(y)>1e-5 and np.max(np.abs(y))>1e-5):fail('silent '+p.name)
  r['measured_duration_s']=dur; r['measured_true_peak_dbfs']=tp; r['measured_rms_dbfs']=rms
  by.setdefault((ident,form,level),[]).append(y)
 # Distinct waveforms pairwise, including nominal two versions per level.
 for key,ys in by.items():
  if len(ys)>1 and np.linalg.norm(ys[0][:min(map(len,ys))]-ys[1][:min(map(len,ys))])<.01:fail(f'duplicate variants {key}')
 # Level durations strictly increase for each form/id.
 for ident in ITEMS:
  forms=('cast','hit') if ITEMS[ident][1]=='both' else ('cast',)
  for form in forms:
   ds=[np.mean([RANGES[form][i][0]/1000+0.012 for r in rows if r['id']==ident and r['form']==form and r['level']==lev]) for i,lev in enumerate(LEVELS)]
   if not ds[0]<ds[1]<ds[2]:fail(f'level durations {ident}/{form}: {ds}')
 # Compare normalized spectrum against the base spell family named by VMR ids.
 base_ids={'metal_tac':['tocsin_rivets_rougis'],'gong':['tocsin_tete_cloche'],'blade_drop':['goutte_lame'],'mirror_puddle':['flaque_miroir'],'flood':['vague'],'chain_snap':['arpenteuse_chaine_lestee'],'tongue':['rainette_langue'],'chest_hit':['avare_coup_de_coffre'],'mud_slap':['gifle_de_vase'],'daggers':['dagues_demi_lune'],'tied_knife':['couteau_ficele'],'jerk':['rictus_saccade'],'liners':['doublures'],'arrow':['vigie_trait'],'rocket':['vigie_fusee'],'net':['vigie_filet'],'hail':['vigie_grele'],'sword':['taille_estoc'],'scythe':['fauche_lune'],'polish':['aiguisage'],'twinblades':['lames_jumelles']}
 existing=list(out.glob('spell_*.ogg'))
 def spec(y):
  mono=y.mean(axis=1); f,p=signal.welch(mono,ac.SR,nperseg=min(4096,len(mono))); bands=np.array([p[(f>=a)&(f<b)].sum() for a,b in zip([0,120,350,900,2200,5000],[120,350,900,2200,5000,22050])]); return bands/(bands.sum()+1e-30)
 for ident,(mat,forms,auto,base) in ITEMS.items():
  candidates=[p for p in existing if any(p.name.startswith('spell_'+b+'_') for b in base_ids.get(base,[]))]
  if not candidates:fail(f'base spell missing for {ident}: {base}')
  bspec=spec(ac.decode(candidates[0])); r=next(q for q in rows if q['id']==ident)
  y=ac.decode(out/Path(r['path']).name); dist=float(np.linalg.norm(spec(y)-bspec))
  if dist<.035:fail(f'spectrum too similar {ident} vs {candidates[0].name}: {dist:.4f}')
 print(f'PASS: {len(rows)} ogg; {nbytes} bytes')
if __name__=='__main__':main()
