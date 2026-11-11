"""VARIANTES_AUDIO: short deterministic spell materials, Vorbis q5."""
import json
from pathlib import Path
import numpy as np
from scipy import signal
import audio_common as ac
import synth_lib as sl

ROOT=Path(__file__).resolve().parents[3]
LEVELS=('light','medium','heavy')
BASE_SEED=3811000
# id: material, cast/hit, AUTO, base material
ITEMS={
'tocsin_vapeur':('steam','both',True,'metal_tac'), 'tocsin_tete_fumigene':('smoke','both',False,'gong'),
'averse_bruine':('spray','both',True,'blade_drop'), 'averse_geyser':('geyser','both',False,'flood'),
'averse_gouttiere':('gutter','both',False,'mirror_puddle'), 'averse_mousson':('monsoon','both',False,'flood'),
'arpenteuse_chaine_lestee':('chain','both',True,'chain_snap'), 'arpenteuse_noeud':('knot','both',False,'chain_snap'),
'arpenteuse_jalons':('stakes','both',False,'chain_snap'), 'arpenteuse_cerceau':('hoop','both',False,'chain_snap'),
'rainette_croassement':('frog','both',True,'tongue'), 'rainette_ricochet':('skips','both',False,'tongue'),
'rainette_bulle':('bubble','both',False,'tongue'), 'rainette_choeur':('chorus','both',False,'tongue'),
'avare_coffre_belier':('ram','both',True,'chest_hit'), 'avare_piece_truquee':('coin','both',False,'chest_hit'),
'avare_saisie':('purse','both',False,'chest_hit'), 'avare_tresor_enterre':('buried','both',False,'chest_hit'),
'bourbe_crachat_de_vase':('spit','both',True,'mud_slap'), 'bourbe_bouture':('root','both',False,'mud_slap'),
'bourbe_eclatement':('clod','both',False,'mud_slap'), 'bourbe_maree_de_vase':('tide','both',False,'mud_slap'),
'rictus_main_du_montreur':('woodhand','both',True,'daggers'), 'rictus_eventail':('fan','both',False,'tied_knife'),
'rictus_toupie':('top','both',False,'jerk'), 'rictus_rideau':('curtain','both',False,'liners'),
'vigie_tir_double':('doublebow','both',True,'arrow'), 'vigie_fanal':('lantern','cast',False,'rocket'),
'vigie_chausse_trapes':('caltrops','both',False,'net'), 'vigie_tir_de_signal':('signal','both',False,'hail'),
'morfil_taille_lente':('slowwood','both',True,'sword'), 'morfil_fendoir':('split','both',False,'scythe'),
'morfil_affutage_en_marche':('sharpen','cast',False,'polish'), 'morfil_trempe':('sapquench','both',False,'twinblades'),
}
RANGES={'cast':((120,180),(160,240),(220,340)),'hit':((70,110),(90,140),(120,190))}
WIDE={'averse_geyser','averse_mousson','bourbe_maree_de_vase'}
AUTO_IDS={k for k,v in ITEMS.items() if v[2]}

def synth(mat,dur,level,rng):
    n=round(dur*ac.SR); t=np.arange(n)/ac.SR; x=np.zeros(n)
    depth=(1-.09*level)*rng.uniform(.92,1.08)
    def add(y,at=0,amp=1):
        k=max(0,round(at*ac.SR)); q=min(len(y),n-k)
        if q>0:x[k:k+q]+=amp*y[:q]
    def noise(at,ln,lo,hi,amp=1,decay=False):
        m=max(8,round(ln*ac.SR)); v=np.arange(m)/ac.SR; z=sl.bp(rng.normal(size=m),lo*depth,hi*depth)
        env=(1-np.exp(-v/.001))*np.exp(-v/(ln*.28)) if decay else np.sin(np.linspace(0,np.pi,m))**1.1
        add(z*env,at,amp)
    def tone(at,f,ln,amp=1,fall=1):
        m=max(8,min(round(ln*ac.SR),n-round(at*ac.SR))); v=np.arange(m)/ac.SR
        add(np.sin(2*np.pi*(f*v-fall*v*v/2))*np.exp(-v/max(ln*.35,.006)),at,amp)
    def tap(at,f,amp=.5,metal=False):
        ln=min(dur-at,.045); m=max(12,round(ln*ac.SR)); v=np.arange(m)/ac.SR
        ratios=(1,2.71,4.13,6.37) if metal else (1,1.49,2.31)
        z=sum(np.sin(2*np.pi*f*depth*r*v)*np.exp(-v/(.015/(1+j*.7)))/(1+j) for j,r in enumerate(ratios))
        add(z*(1-np.exp(-v/.0005)),at,amp)
    def plop(at,f=170,amp=1):
        tone(at,f,dur-at,amp, min(f*1.4,250))
        noise(at,min(.045,dur-at),180,1400,amp*.7,True)
    if mat=='steam': noise(.005,dur*.95,900,8500,.8); noise(.0,dur*.35,1800,11000,.7,True)
    elif mat=='smoke': tap(.002,115,.6); noise(.015,dur*.82,120,1200,.8)
    elif mat=='spray':
        for at in np.linspace(.002,dur*.55,8+level*3): noise(at,min(.035,dur-at),2200,13000,rng.uniform(.3,.7),True)
    elif mat=='geyser': plop(.008,190,.9); noise(dur*.22,dur*.7,500,6500,.9); 
    elif mat=='gutter': noise(.002,dur*.95,450,4200,.7); [tap(a,rng.uniform(900,1600),.18,True) for a in np.linspace(.1*dur,.8*dur,5+level)]
    elif mat=='monsoon': noise(.002,dur*.97,90,1600,1); noise(.05,dur*.87,250,4000,.8)
    elif mat in ('chain','knot','hoop'):
        noise(.005,dur*.75,170,1700,.6,True)
        count=2+level*2 if mat=='chain' else 4+level*3
        for a in np.linspace(.005,dur*.65,count): tap(a,rng.uniform(180,550),.55,True)
        if mat=='knot': noise(dur*.4,dur*.48,500,2400,.45,True)
    elif mat=='stakes':
        for a in np.linspace(.01,dur*.78,3+level*2): tap(a,rng.uniform(250,600),.8,True)
    elif mat in ('frog','chorus'):
        for j,a in enumerate(([.01] if mat=='frog' else np.linspace(.005,dur*.35,3+level))):
            f=rng.uniform(110,190); tone(a,f,min(.13,dur-a),.75,fall=-f*.8); tone(a+.012,f*2,min(.10,max(.008,dur-a-.012)),.2)
    elif mat=='skips':
        for j,a in enumerate(np.linspace(.005,dur*.7,4+level)): plop(a,260-j*28,.65*(1-j/(5+level)))
    elif mat=='bubble': tone(.02,80,dur*.65,.9,-120); plop(dur*.7,140,.75)
    elif mat=='ram': noise(.002,dur*.6,80,700,.9,True); tap(.01,150,.8); [tap(a,rng.uniform(1200,2500),.22,True) for a in np.linspace(.24*dur,.7*dur,3+level)]
    elif mat=='coin': tone(.002,rng.uniform(1200,2100),dur*.85,.8,-400); tap(.02,2400,.3,True)
    elif mat=='purse': noise(.004,dur*.85,550,5000,.65); [tap(a,rng.uniform(900,2200),.22,True) for a in np.linspace(.2*dur,.8*dur,4+level)]
    elif mat=='buried': noise(.002,dur*.83,90,1100,.8); tap(.02,130,.45)
    elif mat in ('spit','clod','tide'):
        plop(.004,95 if mat=='tide' else 145,.9); noise(.025,dur*.85,180,1800,.7)
        if mat=='clod': noise(.05,dur*.48,500,4500,.5)
    elif mat=='root': tap(.005,180,.65); noise(.035,dur*.72,100,900,.7,True)
    elif mat=='woodhand': tap(.005,220,.9); noise(.008,dur*.35,180,900,.45,True)
    elif mat=='fan':
        noise(.002,dur*.55,2200,11500,.4)
        for a in np.linspace(.01,dur*.4,5):tap(a,rng.uniform(1800,3200),.28,True)
    elif mat=='top': tone(.01,330,dur*.85,.5,250); noise(.01,dur*.8,300,1800,.25)
    elif mat=='curtain': noise(.002,dur*.9,300,5000,.6); [tap(a,2600,.13,True) for a in np.linspace(.3*dur,.8*dur,3)]
    elif mat=='doublebow': tap(.005,320,.75); tap(min(.085,dur*.3),rng.uniform(280,390),.75); noise(.02,dur*.6,1200,8500,.3)
    elif mat=='lantern': noise(.003,dur*.7,700,5200,.45,True); tone(.02,180,dur*.45,.22,0)
    elif mat=='caltrops':
        for a in np.linspace(.006,dur*.75,5+level*2):tap(a,rng.uniform(1300,3300),.5,True)
    elif mat=='signal': noise(.002,dur*.78,3000,13000,.5,True); tone(.002,1900,dur*.7,.2,-1500)
    elif mat in ('slowwood','split','sharpen','sapquench'):
        lo,hi={'slowwood':(140,1600),'split':(90,1900),'sharpen':(900,6200),'sapquench':(500,7000)}[mat]
        noise(.002,dur*.9,lo,hi,.8,mat=='sapquench')
        if mat=='slowwood': noise(.02,dur*.65,240,1300,.45)
        elif mat=='split': tap(.005,260,.65)
        elif mat=='sapquench': noise(.12*dur,dur*.6,1800,9000,.35,True)
    side=sl.bp(rng.normal(size=n),600,6000)*np.sqrt(np.maximum(sl.lp(x*x,150),0)+1e-12)*.07
    y=np.column_stack((x+side,x-side)); y-=y.mean(axis=0); y=np.tanh(y/(np.std(y)+1e-12)*.7)
    return ac.fade(y,1.5)

def main():
    out=ROOT/'game/assets/audio/spells'; rows=[]
    for gi,(ident,(mat,forms,auto,base)) in enumerate(ITEMS.items()):
        for form in (('cast','hit') if forms=='both' else ('cast',)):
            for li,(lo,hi) in enumerate(RANGES[form]):
                for vi in range(2):
                    seed=BASE_SEED+gi*1000+(0 if form=='cast' else 500)+li*100+vi
                    rng=np.random.default_rng(seed); dur=(lo+(hi-lo)*rng.uniform(.4,.6))/1000; dur=max(dur,lo/1000+.025)
                    name=f'spell_{ident}_{form}_{LEVELS[li]}_{vi+1:02d}.ogg'; path=out/name
                    target=((-24,-22,-20) if form=='cast' else (-21,-20,-19))[li]-(4 if auto and form=='hit' else 0)
                    y=synth(mat,dur,li,rng); y*=10**((target-ac.rms_db(y))/20)
                    for _ in range(6):
                        ac.write_ogg(path,y,5); dec=ac.decode(path); tp=ac.peak_db(signal.resample_poly(dec,4,1,axis=0)); rms=ac.rms_db(dec)
                        if tp<=-1.5 and abs(rms-target)<=.8: break
                        if tp>-1.5:y=np.tanh(y*2)/2
                        y*=10**((target-rms)/20)
                    else: raise RuntimeError(name+' peak/RMS convergence')
                    rows.append(dict(id=ident,form=form,path='spells/'+name,base=base,auto=auto,level=LEVELS[li],variant=vi+1,seed=seed,duration_s=len(dec)/ac.SR,duration_range_ms=[lo,hi],target_rms_dbfs=target,rms_dbfs=round(rms,3),peak_dbfs=round(ac.peak_db(dec),3),true_peak_dbfs=round(tp,3),bytes=path.stat().st_size,sample_rate=ac.SR,channels=2,quality=5))
    (Path(__file__).with_name('variantes_manifest.json')).write_text(json.dumps(rows,indent=2)+'\n',encoding='utf-8')
    doc=ROOT/'game/assets/audio/MANIFEST.md'; old=doc.read_bytes().split(b'<!-- VARIANTES_AUDIO -->')[0]
    lines=['<!-- VARIANTES_AUDIO -->','## VARIANTES_AUDIO']
    for ident in ITEMS:
        g=[r for r in rows if r['id']==ident]; lines.append(f"- `{ident}` : {len(g)} variantes ; {min(r['duration_s'] for r in g)*1000:.1f}-{max(r['duration_s'] for r in g)*1000:.1f} ms ; crête max {max(r['true_peak_dbfs'] for r in g):.2f} dBFS ; RMS {min(r['rms_dbfs'] for r in g):.2f}-{max(r['rms_dbfs'] for r in g):.2f} dBFS.")
    doc.write_bytes(old+('' if old.endswith(b'\n') else '\n').encode()+('\n'.join(lines)+'\n').encode())
    print(f"PASS: {len(rows)} ogg; {sum(r['bytes'] for r in rows)} bytes")
if __name__=='__main__':main()
