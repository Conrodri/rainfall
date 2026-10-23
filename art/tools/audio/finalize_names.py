"""Renomme les sons deja generes vers les identifiants logiques du systeme audio Godot
(id 'a.b.c' -> a_b_c_NN.ogg) et ecrit MANIFEST.md. Idempotent (ne touche pas aux fichiers deja renommes)."""
import os, re, shutil, subprocess, sys, json
import numpy as np
R = os.path.join(os.path.dirname(__file__), '..', '..', '..', 'game', 'assets', 'audio')
R = os.path.abspath(R)
SOIL = {'stone_wet': 'wet', 'mud_leaves': 'dirt', 'rust_metal': 'metal'}
rules = []  # (folder, src_prefix, dst_prefix, copy)
def r(folder, src, dst, copy=False): rules.append((folder, src, dst, copy))
for lv in ('light', 'medium', 'heavy'):
    r('spells', f'ember_bolt_cast_{lv}', f'spell_eclat_de_braise_cast_{lv}')
    r('spells', f'ember_bolt_impact_{lv}', f'spell_eclat_de_braise_hit_{lv}')
    r('spells', f'ardent_nova_{lv}', f'spell_nova_ardente_cast_{lv}')
    r('spells', f'cinders_loop_{lv}', f'spell_cendres_cast_{lv}')
    r('spells', f'brasier_{lv}', f'spell_brasier_cast_{lv}')
    for n in ('flame_pillar', 'meteor_rain', 'phoenix', 'roaming_embers_loop', 'roaming_embers_start'):
        r('spells', f'{n}_{lv}', f'spell_{n}_{lv}')
r('spells', 'spell_brasier_cast_heavy', 'spell_ultimate', True)
r('impacts', 'hit_normal_light', 'hit_light')
r('impacts', 'hit_crit_heavy', 'hit_heavy', True)
r('impacts', 'hit_crit_heavy', 'hit_crit')
for a, b in (('tier1_light', 't1'), ('tier2_medium', 't2'), ('tier3_heavy', 't3'), ('elite_heavy', 'elite')):
    r('impacts', 'death_' + a, 'death_' + b)
r('impacts', 'player_hurt_medium', 'player_hurt'); r('impacts', 'player_death_heavy', 'player_death'); r('impacts', 'player_heal_none', 'player_heal')
for s, d in (('ardent', 'player'), ('swarm', 'monster_t1'), ('shooter', 'monster_t2'), ('leaper', 'monster_t2'),
             ('brute_light', 'monster_t3'), ('brute_heavy', 'monster_t3'), ('boss', 'boss'), ('miniboss', 'boss')):
    for a, b in SOIL.items():
        r('footsteps', f'step_{s}_{a}', f'step_{d}_{b}')
for d in ('player', 'monster_t1', 'monster_t2', 'monster_t3', 'boss'):
    pass  # stone/water/grass deja nommes par gen_extra
def move_group(folder, src, dst, copy):
    fd = os.path.join(R, folder)
    files = sorted(f for f in os.listdir(fd) if re.fullmatch(re.escape(src) + r'_\d\d\.ogg', f))
    if not files: return 0
    used = [int(m.group(1)) for f in os.listdir(fd) if (m := re.fullmatch(re.escape(dst) + r'_(\d\d)\.ogg', f))]
    n = max(used, default=0)
    for f in files:
        n += 1
        new = f'{dst}_{n:02d}.ogg'
        (shutil.copy2 if copy else shutil.move)(os.path.join(fd, f), os.path.join(fd, new))
        for ext in ('.import',):
            p = os.path.join(fd, f + ext)
            if os.path.exists(p) and not copy: os.remove(p)
    return len(files)
if '--rename' in sys.argv:
    for rule in rules: move_group(*rule)
