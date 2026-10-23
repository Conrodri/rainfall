"""Verifie les sons livres (duree, crete, RMS, clic de boucle) et ecrit game/assets/audio/MANIFEST.md."""
import os, re, subprocess, collections
import numpy as np
R = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..', 'game', 'assets', 'audio'))
def load(p):
    raw = subprocess.run(['ffmpeg','-v','error','-i',p,'-f','f32le','-ac','2','-ar','44100','-'],capture_output=True).stdout
    return np.frombuffer(raw, np.float32).reshape(-1, 2)
groups = collections.OrderedDict(); bad = []
for folder in sorted(os.listdir(R)):
    fd = os.path.join(R, folder)
    if not os.path.isdir(fd): continue
    for f in sorted(os.listdir(fd)):
        if not f.endswith('.ogg'): continue
        x = load(os.path.join(fd, f)); d = len(x)/44100
        pk = 20*np.log10(np.abs(x).max()+1e-9); rms = 20*np.log10(np.sqrt((x**2).mean())+1e-9)
        loop = ('loop' in f) or 'cendres' in f or (f.startswith('amb_') and 'thunder' not in f) or f.startswith('music_')
        click = ''
        if loop:
            m = x.mean(1); jump = abs(m[0]-m[-1]); sd = np.abs(np.diff(m)).mean()
            click = f'{jump/(sd+1e-9):.1f}'
            if jump > 25*sd + 0.02: bad.append((f, 'clic boucle', jump))
        if pk > -1.0: bad.append((f, 'crete', pk))
        key = re.sub(r'_\d\d\.ogg$', '', f)
        groups.setdefault((folder, key), []).append((f, d, pk, rms, click))
ID = lambda k: k.replace('_', '.', 1) if False else k
def level(k):
    for l in ('light','medium','heavy'):
        if k.endswith('_'+l) or '_'+l+'_' in k: return l
    return '-'
vol = {'spells':0,'impacts':0,'footsteps':-6,'ambience':0,'music':0,'ui':0}
lines = ['# MANIFEST audio Rainfall','',
 'Fichiers produits par synthese procedurale (scripts Codex dans `art/tools/audio/`, regenerables). Convention : id logique `a.b.c` -> `a_b_c_NN.ogg` (NN = variantes, tirage aleatoire par le systeme audio).',
 'Format : .ogg Vorbis 44,1 kHz. Crete max mesuree <= -1 dBFS. Volume conseille = gain en dB a appliquer sur le bus (0 = tel quel).','',
 '| id logique (prefixe fichier) | dossier | variantes | duree (s) | boucle | niveau | crete dBFS | RMS dBFS | saut de boucle (x dev. moy.) | volume conseille |','|---|---|---|---|---|---|---|---|---|---|']
for (folder, key), v in groups.items():
    ds = [a[1] for a in v]; loop = ('loop' in key) or 'cendres' in key or (key.startswith('amb_') and 'thunder' not in key) or key.startswith('music_')
    lines.append(f"| `{key}` | {folder} | {len(v)} | {min(ds):.2f}-{max(ds):.2f} | {'oui' if loop else 'non'} | {level(key)} | {max(a[2] for a in v):.1f} | {np.mean([a[3] for a in v]):.1f} | {v[0][4] or '-'} | {vol.get(folder,0)} dB |")
extra = open(os.path.join(os.path.dirname(__file__), 'manifest_extra.md'), encoding='utf-8').read() if os.path.exists(os.path.join(os.path.dirname(__file__), 'manifest_extra.md')) else ''
lines += ['', extra]
open(os.path.join(R,'MANIFEST.md'),'w',encoding='utf-8').write(chr(10).join(lines))
print(len(groups),'groupes', sum(len(v) for v in groups.values()),'fichiers'); print('PROBLEMES:', bad)
