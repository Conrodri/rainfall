"""Verifie ambiances, UI et musiques : NaN, crete <= -1 dBFS, durees, raccord de boucle (sur le .ogg decode),
longueur identique des 4 stems d une carte. Code retour 1 si probleme.
uv run --with numpy --with scipy python art/tools/audio/verify_new.py
"""
import json
import re
import sys
from pathlib import Path
import numpy as np
import audio_common as ac

ROOT = Path(__file__).resolve().parents[3] / 'game' / 'assets' / 'audio'
bad = []
rows = {}
CARTES = ('terrasses_noyees', 'foret_brume', 'cite_rouille')


def logical_id(name):
    b = re.sub(r'_\d\d\.ogg$', '', name)
    for c in CARTES:
        if b == f'music_boss_{c}':
            return f'music.boss.{c}'
        if b.startswith(f'music_{c}_'):
            return f'music.{c}.' + b.split(c + '_')[1]
        if b.startswith(f'amb_wind_{c}'):
            return f'amb.wind.{c}'
        if b == f'amb_{c}_decor':
            return f'amb.{c}.decor'
    if b == 'music_menu':
        return 'music.menu'
    if b.startswith('amb_rain_'):
        return 'amb.rain.' + b[9:]
    if b.startswith('amb_thunder_'):
        return 'amb.thunder_' + b[12:]
    if b.startswith(('ui_', 'pickup_')):
        return b.replace('_', '.', 1)
    return b.replace('_', '.')



def seam(x, order=16):
    """Erreur de prediction lineaire (LPC apprise sur le fichier) : max sur 16 echantillons au raccord, compare au
    99e centile des memes fenetres dans les 40000 echantillons autour. Retourne (rapport, erreur absolue)."""
    from scipy import signal as sg
    from scipy.linalg import solve_toeplitz
    m = x.mean(1)
    seg = m[:400000]
    r = sg.fftconvolve(seg, seg[::-1])[len(seg) - 1:len(seg) + order + 1]
    a = solve_toeplitz(r[:order] + 1e-12, r[1:order + 1])
    filt = np.concatenate([[1.0], -a])
    K = 20000
    ctx = np.concatenate([m[-K:], m[:K]])
    e = np.abs(sg.lfilter(filt, [1.0], ctx))[order:]
    w = np.lib.stride_tricks.sliding_window_view(e, 16).max(1)
    c = K - order
    s = w[c - 16:c + 16].max()
    return s / (np.percentile(w, 99) + 1e-12), s, 0, 0


entries = {}
for folder, minlen in (('ambience', None), ('music', 90.0), ('ui', None)):
    for p in sorted((ROOT / folder).glob('*.ogg')):
        x = ac.decode(p)
        d = len(x) / ac.SR
        pk = ac.peak_db(x)
        rms = ac.rms_db(x)
        loop = (folder == 'music') or (folder == 'ambience' and 'thunder' not in p.name)
        flag = []
        if not np.isfinite(x).all():
            flag.append('NaN')
        if pk > -1.0:
            flag.append(f'crete {pk:.1f}')
        if loop and folder == 'ambience' and d < 60:
            flag.append(f'duree {d:.1f}')
        if folder == 'music' and d < 90:
            flag.append(f'duree {d:.1f}')
        s = ''
        if loop:
            r, a, b, local = seam(x)
            s = f'{r:.2f}'
            if r > 4 and a > 0.008:
                flag.append(f'raccord {r:.1f}')
        rows[p.name] = (d, pk, rms, s, len(x))
        entries.setdefault(folder, []).append(dict(path=f'{folder}/{p.name}', id=logical_id(p.name), duration_s=round(d, 3), samples=len(x), loop=bool(loop), peak_dbfs=round(pk, 2), rms_dbfs=round(rms, 2), seam_ratio=s or None))
        print(f'{folder:8s} {p.name:42s} {d:7.2f}s pk {pk:6.1f} rms {rms:6.1f} seam {s:>5s} {" ".join(flag)}')
        if flag:
            bad.append((p.name, flag))

# stems synchronises
for carte in ('terrasses_noyees', 'foret_brume', 'cite_rouille'):
    lens = {st: rows.get(f'music_{carte}_{st}_01.ogg', (0, 0, 0, 0, None))[4] for st in ('base', 'tension', 'drive', 'climax')}
    if len(set(lens.values())) != 1 or None in lens.values():
        bad.append((carte, f'stems de longueurs differentes {lens}'))
    else:
        print('stems', carte, 'OK', lens['base'], 'echantillons')
        # somme des 4 stems : pas de saturation
        mix = sum(ac.decode(ROOT / 'music' / f'music_{carte}_{st}_01.ogg') for st in ('base', 'tension', 'drive', 'climax'))
        print('   somme des 4 stems : crete', round(ac.peak_db(mix), 1), 'dBFS (info, le mixeur applique des dB par palier)')
for fo, es in entries.items():
    json.dump(es, open(Path(__file__).with_name(f'{fo}_manifest.json'), 'w', encoding='utf-8'), indent=1, ensure_ascii=False)
print('PROBLEMES:', bad)
sys.exit(1 if bad else 0)
