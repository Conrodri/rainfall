"""Procedural UX-H lobby, pad, forge, storm and trial UI sounds."""
import json
from pathlib import Path
import numpy as np
import audio_common as ac
import synth_lib as sl

SR = ac.SR
ROOT = Path(__file__).resolve().parents[3]
UI = ROOT / 'game' / 'assets' / 'audio' / 'ui'
TRIAL = ROOT / 'game' / 'assets' / 'audio' / 'epreuves'
M = sl.mtof


def trim_tail(x, floor_db=-52, pad=.12):
    m = np.abs(x).max(1); w = int(.01 * SR)
    env = np.array([m[i:i + w].max() for i in range(0, len(m), w)])
    idx = np.where(env > m.max() * 10 ** (floor_db / 20))[0]
    end = min(len(x), int((idx[-1] + 1) * w + pad * SR))
    y = x[:end].copy(); k = min(len(y) // 2, int(.08 * SR))
    y[-k:] *= np.linspace(1, 0, k)[:, None] ** 1.5
    return y


def mix(parts, total):
    out = np.zeros((int(total * SR), 2))
    for st, x, g, pan in parts:
        sl.put(out, int(st * SR), x, g, pan)
    return out


def wet(x, rng, rt60=.7, amount=.2, bright=.6, tail=None):
    rev = sl.Reverb(rng, rt60=rt60, brightness=bright)
    w = rev.linear(x, tail=tail if tail is not None else int(rt60 * .9 * SR))
    full = np.zeros_like(w); full[:len(x)] += x
    return full + w * amount


def glass(f, dur, rng, tau=.35, vel=.8):
    n = int(dur * SR); t = np.arange(n) / SR; x = np.zeros(n)
    for r, a, d in ((1, 1, 1), (2.32, .45, .7), (4.25, .3, .5), (6.63, .18, .35), (9.38, .1, .25)):
        if f * r < 14000: x += a * np.sin(2*np.pi*f*r*t+rng.uniform(0, 6)) * np.exp(-t/(tau*d))
    x += sl.hp(rng.normal(size=n), 6000, 1) * np.exp(-t/.004) * .18
    return x * vel * np.minimum(1, t/.0008) * .5


def click(rng, f=1700, dur=.045):
    n=int(dur*SR); t=np.arange(n)/SR
    x=sl.bp(rng.normal(size=n), 1000, 8500, 1)*np.exp(-t/.0018)*.8
    x += np.sin(2*np.pi*f*t)*np.exp(-t/.008)*.45
    return x


def sweep(rng, dur=.65):
    n=int(dur*SR); t=np.arange(n)/SR
    f=180+2200*(t/dur)**2; phase=np.cumsum(f)/SR
    return sl.bp(rng.normal(size=n), 500, 9000, 1)*np.sin(np.pi*t/dur)**1.5*.16 + np.sin(2*np.pi*phase)*np.sin(np.pi*t/dur)**1.5*.12


def sound(kind, rng, v):
    d=v*.025
    if kind == 'lobby_join':
        x=mix([(0,glass(M(72+d),.55,rng,.22),.8,-.15),(.08,glass(M(79+d),.62,rng,.3),.75,.15)],.75)
        return wet(x,rng,.45,.13,.75)
    if kind == 'lobby_ready':
        x=mix([(0,glass(M(76+d),.42,rng,.2),.75,-.2),(.12,glass(M(83+d),.48,rng,.22),.8,.2),(.32,click(rng,2600),.5,0)],.56)
        return wet(x,rng,.35,.12,.8)
    if kind == 'lobby_tick':
        n=int(.09*SR); t=np.arange(n)/SR
        x=click(rng, M(91+d),.09)+.35*sl.bp(rng.normal(size=n),180,1500,1)*np.exp(-t/.012)
        return sl.pan(x,0)
    if kind == 'lobby_go':
        chord=sl.pad_chord([M(60+d),M(67+d),M(72+d),M(76+d)],.75,rel=.55,att=.04,cut=5000,rng=rng)
        n=int(.24*SR); t=np.arange(n)/SR; boom=np.sin(2*np.pi*(65-22*t/.24)*t)*np.exp(-t/.11)
        x=mix([(0,chord,.65,0),(.02,sweep(rng,.72),.7,0),(.48,boom,.8,0)],1.13)
        return wet(x,rng,.65,.2,.6)
    if kind == 'pad_lost':
        x=mix([(0,glass(M(76+d),.3,rng,.15,.7),.7,-.1),(.18,glass(M(69+d),.34,rng,.18,.7),.75,.1)],.52)
        return wet(x,rng,.3,.1,.4)
    if kind == 'pad_restored':
        x=mix([(0,glass(M(72+d),.3,rng,.16,.7),.75,-.1),(.14,glass(M(79+d),.38,rng,.2,.75),.8,.1)],.48)
        return wet(x,rng,.32,.12,.7)
    if kind == 'forge_craft':
        n=int(.35*SR); t=np.arange(n)/SR
        hit=sl.resonator(rng.normal(size=n),rng.uniform(500,900),11)*np.exp(-t/.11)+sl.resonator(rng.normal(size=n),rng.uniform(1700,2600),18)*np.exp(-t/.07)
        parts=[(0,hit,.9,0)]
        for i in range(5): parts.append((.13+i*.11,glass(M(84+i*2+d),.42,rng,.12,.65),.38,rng.uniform(-.6,.6)))
        return wet(mix(parts,1.16),rng,.55,.16,.8)
    if kind == 'storm_core_gain':
        n=int(.34*SR); t=np.arange(n)/SR; crack=sl.bp(rng.normal(size=n),1800,10000,1)*np.exp(-t/.045)*np.sin(np.pi*np.minimum(1,t/.34))
        x=mix([(0,crack,.55,0),(.1,glass(M(67+d),.72,rng,.45,.75),.75,-.1),(.28,glass(M(74+d),.62,rng,.35,.65),.5,.15)],.83)
        return wet(x,rng,.6,.17,.8)
    if kind == 'vigie_guet_full':
        x=mix([(0,glass(M(84+d),.55,rng,.3,.38),.38,0),(.01,sl.hp(rng.normal(size=int(.5*SR)),2500)*np.exp(-np.arange(int(.5*SR))/SR/.08),.03,0)],.62)
        return wet(x,rng,.45,.12,.8)
    if kind == 'epreuve_grade_parfait':
        notes=[M(72+d),M(79+d),M(84+d)]
        parts=[(i*.17,glass(f,.55,rng,.28,.9),.75,(-1+i)*.16) for i,f in enumerate(notes)]
        for i in range(8): parts.append((.43+i*.055,glass(M(96+d)+rng.uniform(-20,20),.3,rng,.1,.6),.27,rng.uniform(-.8,.8)))
        return wet(mix(parts,1.42),rng,.65,.2,.9)
    if kind == 'epreuve_grade_bien':
        return wet(mix([(0,glass(M(72+d),.5,rng,.24,.72),.75,-.12),(.2,glass(M(79+d),.55,rng,.27,.75),.75,.12)],1.03),rng,.48,.14,.7)
    # fait: modest single rounded note and click
    n=int(.35*SR); t=np.arange(n)/SR
    note=sl.sine(M(67+d),n)*np.exp(-t/.16)+.22*sl.sine(M(79+d),n)*np.exp(-t/.09)
    return wet(mix([(0,note,.75,0),(.37,click(rng,1500,.035),.35,0)],.68),rng,.25,.08,.4)


SPECS = [('ui/'+k, k, dur, -26 if k == 'vigie_guet_full' else -20) for k,dur in [
    ('lobby_join',.9),('lobby_ready',.75),('lobby_tick',.12),('lobby_go',1.2),('pad_lost',.5),('pad_restored',.45),
    ('forge_craft',1.2),('storm_core_gain',.9),('vigie_guet_full',.7)]] + [('epreuves/'+k,k,dur,-20) for k,dur in [
    ('epreuve_grade_parfait',1.5),('epreuve_grade_bien',1.2),('epreuve_grade_fait',.8)]]


def main():
    items=[]
    for rel,kind,dur,target in SPECS:
        out=ROOT/'game'/'assets'/'audio'/rel.split('/')[0]
        out.mkdir(parents=True,exist_ok=True)
        for v in range(2):
            seed=sum(map(ord,kind))*31+v*977
            rng=np.random.default_rng(seed)
            x=trim_tail(sound(kind,rng,v),pad=.04)
            x=sl.finish_oneshot(x,target,-2.0,1,18)
            p=out/f'{kind}_{v+1:02d}.ogg'; ac.write_ogg(p,x,5)
            items.append({'path':f'{rel.split("/")[0]}/{p.name}','duration_s':round(len(x)/SR,4),'peak_dbfs':round(ac.peak_db(x),2),'rms_dbfs':round(sl.rms_active(x),2)})
    manifest=ROOT/'art'/'tools'/'audio'/'ux_manifest.json'
    manifest.write_text(json.dumps(items,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
    print(f'generated={len(items)} manifest={manifest.relative_to(ROOT)}',flush=True)


if __name__ == '__main__': main()
