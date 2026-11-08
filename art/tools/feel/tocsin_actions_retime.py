"""Tocsin : recale les durées des anims d'action (impact plus tôt, règles feel_sorts_da.md) dans tous les .tres,
et retire des .tres composites du skin les anims throw_* (jamais jouées en composite, planches exclues d'Android).
Édition de texte seulement. Lancer : python art/tools/feel/tocsin_actions_retime.py"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2].parent
GAME = ROOT / 'game/assets/sprites/characters/tocsin'
SPEED = 12.0
F60 = {
    'attack': [3, 3, 2, 12, 14, 22],            # impact index 3 à 8 images
    'cast': [4, 4, 4, 14, 16, 26],               # impact index 3 à 12 images
    'cast_ult': [4, 4, 4, 14, 16, 26],
    'throw_arm_l': [6, 6, 6, 24],                # libération index 2 à 12 images
    'throw_arm_r': [6, 6, 6, 24],
    'throw_head': [8, 8, 8, 10, 16, 28],         # libération index 3 à 24 images
}
DIRS = ['e', 'se', 's', 'sw', 'w', 'nw', 'n', 'ne']
NAME = re.compile(r'"name": &"(%s)_(%s)"' % ('|'.join(sorted(F60, key=len, reverse=True)), '|'.join(DIRS)))
DUR = re.compile(r'"duration": [0-9.]+')


def retime(text):
    out, n = [], 0
    for line in text.split('\n'):
        m = NAME.search(line)
        if m and line.startswith('{"frames"'):
            f = F60[m.group(1)]
            parts = DUR.findall(line)
            if len(parts) == len(f):
                it = iter(f)
                line = DUR.sub(lambda _: '"duration": %s' % repr(round(next(it) * SPEED / 60.0, 6)).rstrip('0').rstrip('.'), line)
                n += 1
        out.append(line)
    return '\n'.join(out), n


def strip_throw(text):
    lines = text.split('\n')
    out, skip = [], False
    for line in lines:
        if line.startswith('[ext_resource') and 'action_throw_' in line:
            continue
        if line.startswith('[sub_resource'):
            skip = 'action_throw_' in line
            if skip:
                continue
        if skip:
            if line.strip() == '':
                skip = False
            continue
        if line.startswith('{"frames"') and ('action_throw_' in line or re.search(r'"name": &"throw_', line)):
            continue
        out.append(line)
    return '\n'.join(out)


def main():
    changed = 0
    for p in sorted(GAME.rglob('*.tres')):
        raw = p.read_bytes()
        text = raw.decode('utf-8')
        crlf = '\r\n' in text
        t = text.replace('\r\n', '\n')
        if p.name in ('tocsin_skin1.tres', 'tocsin_emission.tres', 'tocsin.tres'):
            t = strip_throw(t)
        t, n = retime(t)
        if crlf:
            t = t.replace('\n', '\r\n')
        if t != text:
            p.write_bytes(t.encode('utf-8'))
            changed += 1
            print(p.relative_to(GAME), n)
    print('changed', changed)


main()
