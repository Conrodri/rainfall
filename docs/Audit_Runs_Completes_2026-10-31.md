# Audit d'équilibrage sur runs complètes simulées (31/10/2026)

Question du joueur : la difficulté et l'équilibrage (monstres, scaling, objets, boss) tiennent-ils sur une run COMPLÈTE, avec un nombre d'objets cohérent avec le temps écoulé ? Mesurer les dégâts moyens et le temps pour tuer (TTK) des monstres simples, élites, brutes, mini-boss, boss d'étage et boss final.

## 1. Méthode

Nouvel outil : `game/tests/balance_sim/full_run_sim.gd`, lancé par `game/tests/balance_sim_fullrun.tscn` (un personnage et une graine par processus, en parallèle) :

```
godot --headless --fixed-fps 60 --path game res://tests/balance_sim_fullrun.tscn -- --char=ardent --seeds=0 --out=<f.json>
```

`--fixed-fps 60` : une frame = 1/60 s de jeu sans attente réelle (une run de 35 min tourne en 3 à 6 min). Ce qui est réel et ce qui est modélisé :

| Élément | Réel (code du jeu) | Modélisé |
|---|---|---|
| Joueur, kit, sorts, procs d'objets | `player.tscn` + vrai kit, lancer automatique (règle `auto_cast_ok`), sorts 2-4 visant le plus proche (comme sur mobile) | piloté par `BotPilot` (kite à la portée du sort 1, esquive les télégraphes avec 0,25 s de réaction et une part d'oublis) |
| Monstres | vrai `Director` : flux continu + vagues, rampe, plafond de vivants, élites, affixes, coûts | arène vide sans murs (poursuite directe) |
| Difficulté D | `RunState.difficulty()` qui monte avec le temps actif, `K_STAGE` par étage | — |
| Or, XP, niveau | `Balance.monster_gold / monster_xp` par kill (coût du tier, élite), `boss_gold / boss_xp`, `RunState.add_xp` (courbe réelle), conversion de l'or en XP au changement d'étage | 100 % de l'or ramassé ; 6 capsules d'argent sur 10 par étage |
| Coffres | prix `Balance.chest_price` (D figé de l'étage), qualité `LootRoller.roll_quality`, paire `LootRoller.pick_pair` (poids et tags réels), coffre de boss gratuit après chaque boss d'étage | le bot achète dès qu'il peut, au plus un coffre toutes les 20 s et 14 par étage, 25 % de grands coffres si l'or le permet ; il garde un des deux objets au hasard ; la Chance et les réductions de prix ne sont pas lues |
| Boss | vrais cerveaux (mini-boss par données, boss d'étage, Semeur de pluie final × `FINAL_BOSS_HP_MULT`), plan d'étage tiré dans `data/floors.json` | rythme fixe : mini-boss à 60 s et 130 s (zone de crédits « mini »), boss d'étage à 180 s (zone « etage » pendant la charge de 60 s), sortie 15 s après ; boss final à 30 s de l'étage 5 ; abandon après 150 s (mini), 300 s (étage), 420 s (final) |
| Mort | — | le bot est relevé avec 2 s d'invulnérabilité ; la mort est comptée |

Mesures : par étage (durée, D, niveau, objets, kills, or, DPS, dégâts subis, morts), par minute (D, niveau, objets, DPS, dégâts subis/s, PV, vivants), par boss (TTK, PV, morts, part des dégâts portés au boss) et TTK de chaque monstre tué (du premier coup reçu à la mort), avec le nombre de coups et la part tuée en 2 coups ou moins. 6 personnages × 5 graines.

Recalage sur le seul journal réel complet d'étage 1 (Tocsin, 29/10, `run_logs/run_20261029-213629`) : étage 1 en 401 s, 805 or gagnés, 11 coffres, niveau 8, D 2,01 en sortie, mini-boss tués en 23 s et 46 s, boss d'étage en ≈ 100 s (pilier actif → fini). Simulation Ardent étage 1 : 373 s, 624 or, 12,4 objets, niveau 7,4, D 1,93. L'économie et la courbe de niveau sont fidèles ; le bot est **plus lent qu'un humain sur les boss** (environ 1,0 à 1,5 × le temps de Tocsin) et prend beaucoup plus de dégâts (1 925 contre 248 à l'étage 1).

Rencontres ciblées (scénarios rapides, utilisés pour les essais et la calibration) : la même scène avec `--inject=<f.json>` ({stage, t, level, items, boss, kind}) joue un seul combat de mini-boss, de boss d'étage ou du boss final, avec le flux de monstres et la zone de charge, au **rythme visé de 19 min** : boss d'étage à 150 s de l'étage N (t = 240 (N-1) + 150 s), mini-boss à 60 s, boss final à 990 s ; D = `Balance.difficulty(t, N)` (1,39 / 2,30 / 3,45 / 4,89 / 6,15), niveau et nombre d'objets moyens mesurés à cette minute dans les runs complètes (niveau 4 / 8 / 10 / 11 / 12 ; 5 / 13 / 21 / 29 / 33 objets), inventaire d'une vraie run du même personnage ramené à ce nombre. 6 personnages, un boss différent par personnage à chaque étage (pool de `data/floors.json`).

## 2. Constats sur les runs complètes (avant modification, 6 personnages × 5 graines, Moyen)

### 2.1 Durée, difficulté, progression

| Perso | Run (min) | Morts | D finale | Niveau final | Étage 1 (s) | Étage 2 | Étage 3 | Étage 4 | Étage 5 |
|---|---|---|---|---|---|---|---|---|---|
| ardent | 35,1 | 22,8 | 11,01 | 15,8 | 373 | 383 | 399 | 502 | 450 |
| arpenteuse | 39,5 | 25,4 | 12,13 | 16,4 | 420 | 467 | 492 | 540 | 450 |
| averse | 32,4 | 20,8 | 10,28 | 15,6 | 366 | 337 | 330 | 482 | 429 |
| bourbe | 33,5 | 12,4 | 10,58 | 15,6 | 331 | 349 | 355 | 523 | 450 |
| morfil | 32,5 | 10,0 | 10,32 | 15,6 | 335 | 330 | 348 | 498 | 441 |
| rictus | 35,5 | 11,2 | 11,14 | 16,2 | 355 | 381 | 437 | 517 | 442 |

Moyennes des 30 runs par étage :

| Étage | D entrée → sortie | Niveau sortie | Objets sortie | Kills | Or gagné | DPS total | Dégâts subis | Morts |
|---|---|---|---|---|---|---|---|---|
| 1 | 1,00 → 1,91 | 7,0 | 11,8 | 374 | 596 | 53 | 1805 | 3,9 |
| 2 | 2,20 → 3,28 | 10,2 | 24,3 | 454 | 1757 | 176 | 1486 | 0,9 |
| 3 | 3,77 → 5,08 | 12,3 | 36,9 | 370 | 3632 | 388 | 3164 | 3,0 |
| 4 | 5,84 → 7,79 | 14,4 | 51,2 | 478 | 8563 | 725 | 3880 | 2,4 |
| 5 | 8,96 → 10,91 | 15,9 | 51,2 | 301 | 10410 | 1107 | 7289 | 6,8 |

- **Runs de 32 à 40 min au lieu de 18-20** : les étages durent 330-540 s parce que les boss sont longs (§2.3). Conséquence en cascade : D atteint 7,8 en fin d'étage 4 et ≈ 11 en fin de run (visé ≈ 6,9 à 19,5 min), ce qui alourdit encore les étages 4-5.
- **Économie et niveau fidèles au jeu réel** : étage 1 en 373 s, 600 or, 12 objets, niveau 7 (journal réel : 401 s, 805 or, 11 coffres, niveau 8). Objets : ≈ 10-13 par étage, 51 en fin d'étage 4 ; par run 37 communs, 13 peu communs, 1,3 rare, 0 légendaire. À 870 s (14,5 min) le bot a ≈ 29 objets et le niveau 11, comme le prévoyait la config `L12m` (≈ 30 objets).
- **Pas d'explosion des objets** : le TTK des monstres reste plat d'un étage à l'autre (§2.2) alors que le DPS est multiplié par 21 (53 → 1 107) : le joueur suit D sans la distancer, et D ne le distance pas non plus. Objets les plus empilés : Bague de vigueur (8 au plus), Sifflet de chasse (7), Étincelle (6), Pierre à aiguiser (6).
- **Densité** : 8-10 monstres vivants en moyenne, 60-65 au plus ; 1,0-1,2 kill/s.
- **Morts** : 10 à 25 par run pour le bot, surtout à l'étage 1 (Idole noyée) et au boss final. Le bot encaisse ≈ 6 fois plus de dégâts qu'un humain (1 800 contre 248 à l'étage 1) : ses morts ne mesurent pas la difficulté réelle.

### 2.2 Monstres (tous personnages)

TTK médian (du premier coup reçu à la mort) / coups médians / part tuée en 2 coups ou moins / PV moyens :

| Étage | Essaim | Tireur | Brute | Essaim élite | Tireur élite | Brute élite |
|---|---|---|---|---|---|---|
| 1 | 0,3 s / 2 / 86 % / 24 | 4,0 s / 6 / 6 % / 134 | 10,2 s / 26 / 0 % / 720 | 1,8 s / 5 / 18 % / 102 | - | - |
| 2 | 0,3 s / 2 / 82 % / 45 | 4,2 s / 7 / 5 % / 247 | 11,6 s / 29 / 0 % / 1 074 | 1,8 s / 5 / 14 % / 190 | 23,3 s / 29 / 0 % / 1 035 | 48,4 s / 120 / 0 % / 4 416 |
| 3 | 0,4 s / 2 / 72 % / 77 | 3,7 s / 8 / 4 % / 413 | 12,1 s / 37 / 0 % / 1 798 | 1,6 s / 6 / 13 % / 309 | 15,7 s / 30 / 0 % / 1 664 | 37,2 s / 115 / 0 % / 7 808 |
| 4 | 0,3 s / 2 / 69 % / 117 | 4,5 s / 10 / 3 % / 649 | 12,2 s / 41 / 0 % / 2 778 | 1,7 s / 6 / 9 % / 477 | 13,7 s / 35 / 0 % / 2 598 | 37,5 s / 144 / 0 % / 11 216 |
| 5 | 0,5 s / 2 / 52 % / 176 | 5,9 s / 13 / 2 % / 951 | 14,4 s / 52 / 0 % / 4 163 | 2,1 s / 8 / 6 % / 702 | 16,0 s / 43 / 0 % / 3 809 | 44,1 s / 178 / 0 % / 16 927 |

Lecture : l'essaim est fauché en 1-2 coups au début (86 %) et le reste en majorité jusqu'à l'étage 4 ; tireurs et brutes ne sont pas triviaux (6-13 et 26-52 coups) ; l'étage 5 se durcit seulement parce que D y est gonflée par la longueur de la run. **Conforme aux cibles (recommandation R du 29/10 validée) : aucune modification des monstres.**

### 2.3 Boss (problème principal)

| Boss (étage, type) | n | TTK moyen (non tués = plafond) | Tués | PV moyens | Niveau | D | Part des dégâts sur le boss | Morts / combat |
|---|---|---|---|---|---|---|---|---|
| 1 etage | 30 | 164 s | 28/30 | 4983 | 4,2 | 1,46 | 0,41 | 3,6 |
| 1 mini | 60 | 42 s | 60/60 | 1119 | 2,0 | 1,24 | 0,64 | 0,2 |
| 2 etage | 30 | 158 s | 28/30 | 16395 | 8,8 | 2,80 | 0,40 | 0,7 |
| 2 mini | 60 | 65 s | 58/60 | 4214 | 8,0 | 2,49 | 0,46 | 0,0 |
| 3 etage | 30 | 170 s | 29/30 | 40112 | 11,3 | 4,47 | 0,45 | 2,8 |
| 3 mini | 60 | 66 s | 58/60 | 10787 | 10,7 | 4,11 | 0,49 | 0,1 |
| 4 etage | 30 | 269 s | 13/30 | 90928 | 13,5 | 6,85 | 0,20 | 1,6 |
| 4 mini | 60 | 99 s | 52/60 | 24475 | 12,8 | 6,27 | 0,37 | 0,1 |
| 5 final | 30 | 414 s | 4/30 | 263020 | 14,5 | 9,10 | 0,35 | 6,8 |

Cibles (`Maths_Scaling.md`, décision du 28/10) : mini-boss 21-30 s, boss d'étage 65-75 s, boss final 120-150 s. Mesuré : **2 à 3 fois trop long** ; boss d'étage de l'étage 4 tué une fois sur deux en 300 s, boss final 4 fois sur 30 en 420 s.

Diagnostic :
- Les PV des boss sont calibrés pour 100 % du DPS sur le boss : PV / DPS total = 53-73 s aux étages 1-3, pile dans la cible. Mais **seuls 36-50 % des dégâts touchent le boss** (colonne « part ») : monstres de la charge plus proches, sorts automatiques au plus proche, zones et procs qui frappent les adds.
- Couper la zone de charge (×2,33 → ×1,5) ne remonte la part qu'à 0,47 (essai `exp3`) : les adds de la charge ne sont pas seuls en cause.
- Le rapport PV / DPS monte avec l'étage (`BOSS_STAGE_K` 1,20 par étage, plus vite que les objets) : 108-200 s à l'étage 4, 224 s au boss final (× `FINAL_BOSS_HP_MULT` 1,55).
- Boss à part : l'Idole noyée (étage 1, raid à 2 boucliers, garde-fou de 45 s) 214 s et 6,4 morts par combat contre 117 s pour l'Éclusier ; l'Anguille des profondeurs (étage 4) 3 tuées sur 12, DPS total 207 (elle nage dans un lac que l'arène vide n'a pas : mesure non fiable) ; la Grue (étage 3) PV / DPS pur 101 s.

### 2.4 Personnages

Le DPS de zone est plafonné par le flux de monstres (tous à 0,95-1,08 de la moyenne). L'écart utile est le TTK de boss (mono-cible), rapport « moyenne des personnages / personnage » sur les étages 1-3 :

| Perso | Mini-boss | Boss d'étage | Lecture |
|---|---|---|---|
| Ardent | 0,95 | 0,96 | référence |
| Averse | 1,14 | 1,21 | limite haute |
| Arpenteuse | 0,73 | 0,72 | **sous 0,85** : biais connu du bot (ne trace pas la chaîne) |
| Rictus | 0,92 | 0,99 | dans la fourchette ; brutes de l'étage 4 en 21 s (2 × les autres) : mono-cible tardif faible |
| Bourbe | 1,26 | 1,14 | **au-dessus de 1,20 sur les mini-boss** (pas « faible » en bot) |
| Taliant (`morfil`) | 1,30 | 1,20 | **au-dessus de 1,20**, et le moins de morts (10 par run) |

## 3. Essais (avant de toucher Balance)

PV des boss rééchelonnés dans la simulation seulement (`--boss_k`, `--final_mult`, `--etage_hp`, `--mini_hp`, `--charge_zone`, `--boss_aim`) :

| Essai | Effet mesuré |
|---|---|
| `exp1`, runs complètes : `BOSS_STAGE_K` 1,12 + final 1,35 | run −1,4 à −3,2 min sur 3 persos sur 4 (Rictus +1 min, bruit) ; boss final tué 5 fois sur 5 pour Averse |
| `exp2`, runs complètes : + PV des boss et mini-boss × 0,8 | run −4 min (30,8 / 27,3 / 30,9 min ; Arpenteuse 36,6) |
| `exp3`, runs complètes : zone de charge ×1,5 au lieu de ×2,33 | part des dégâts sur le boss 0,41 → 0,47, TTK presque inchangé |
| Rencontres étage 3 et final : priorité de visée automatique des boss 2,0 | TTK −10 à −25 % (étage 3 : 142 → 124 s pour Ardent, 121 → 104 s pour Averse) |
| Rencontres au rythme visé : PV d'étage × 0,45 / mini × 0,5 (`pA`), × 0,62 / × 0,65 (`pB`), puis `BOSS_STAGE_K` 1,05 et 1,0 (`pW`) | interpolation retenue : PV d'étage × 0,5, mini × 0,55, `BOSS_STAGE_K` 1,0 |

## 4. Modifications appliquées

| Constante / code | Fichier | Avant | Après | Raison |
|---|---|---|---|---|
| `BOSS_STAGE_K` | `scripts/core/balance.gd` | 1,20 | **1,0** (gardée comme levier) | le rapport PV / DPS montait de 70 s à 110-200 s entre l'étage 1 et l'étage 4 ; niveau ambiant et √coeff suivent déjà les objets |
| `FINAL_BOSS_HP_MULT` | `balance.gd` | 1,55 | **1,35** | boss final 4 tués sur 30 en 420 s |
| `BOSS_FOCUS_HP_MULT` (nouvelle, appliquée dans `boss_hp`) | `balance.gd` | — (1,0) | **mini 0,55, étage 0,5** | 36-50 % seulement du DPS touche le boss ; calibré sur la médiane des 6 persos, adds compris |
| `BOSS_AIM_PRIORITY` (nouvelle) | `balance.gd`, appliquée dans `Enemy.activate_boss` (`scripts/enemies/enemy.gd`) | 1,0 | **2,0** | visée AUTO seulement (`SpellCaster._nearest_enemy` divise la distance par `aim_priority`) : sort 1, sorts 2-4 sur mobile ou « Sorts automatiques », repli manette au repos ; curseur PC et stick inchangés |
| `BOSS_HP_MULT[drowned_idol]` | `balance.gd` | 0,9 | **0,7** | Idole noyée 2,1 × le TTK médian de l'étage 1 (garde-fou de bouclier de 45 s compris) |
| Bogue `enemy.gd:808` | `scripts/enemies/enemy.gd` | `if brain.owns_motion():` | `if brain != null and brain.owns_motion():` | « Nonexistent function 'owns_motion' in base 'Nil' » quand le tick du cerveau finit le boss |

Effet sur les PV (Moyen) : boss d'étage de l'étage 1 à D 1,5 : 5 254 → 2 627. Le DPS du joueur ne change pas : ce sont les PV calibrés « 100 % de focus » qui étaient irréalistes.

### 4.1 Rencontres ciblées au rythme visé, avant / après (médiane et moyenne des 6 personnages, adds compris)

| Rencontre | Cible | Avant (médiane / moyenne) | Après (médiane / moyenne) |
|---|---|---|---|
| Mini-boss ét. 1 | 21-30 s | 46 s / 43 s | 21 s / 19 s |
| Boss d'étage ét. 1 | 65-75 s | 206 s / 209 s | 75 s / 87 s |
| Mini-boss ét. 2 | 21-30 s | 84 s / 79 s | 23 s / 27 s |
| Boss d'étage ét. 2 | 65-75 s | 208 s / 213 s | 62 s / 78 s |
| Mini-boss ét. 3 | 21-30 s | 81 s / 94 s | 24 s / 21 s |
| Boss d'étage ét. 3 | 65-75 s | 286 s / 259 s | 63 s / 87 s |
| Mini-boss ét. 4 | 21-30 s | 142 s / 128 s | 23 s / 29 s |
| Boss d'étage ét. 4 | 65-75 s | 259 s / 247 s | 73 s / 127 s |
| Boss final ét. 5 | 120-150 s | 420 s / 411 s | 122 s / 135 s |

« Avant » = valeurs d'origine (K 1,20, final 1,55, sans facteur de focus, sans priorité de visée). Réserve : ce lot « avant » a injecté un inventaire plus petit (arrondi corrigé ensuite : 0 / 7 / 15 / 35 objets au lieu de 5 / 13 / 21 / 29) ; l'essai `pB` (même inventaire que « après », PV × 0,62 / 0,65 et K 1,12) donnait déjà 93 / 80 / 110 / 167 s pour les boss d'étage, ce qui borne l'effet de cet écart.

Toutes les médianes sont dans la cible ou à sa lisière (étage 2 : 62 s). Les moyennes restent tirées vers le haut par les boss de raid (Idole noyée 134 s, Canonnier de crue 214 s, Roi de sel 189 s : le bot ne ramasse pas les cloches et attend les garde-fous de bouclier), par l'Anguille (297 s, mesure non fiable sans lac) et par Arpenteuse (biais du bot). Idole noyée seule, 6 persos, après la baisse à 0,7 : 152 s de médiane (Éclusier 28-76 s).

### 4.2 Durée de run estimée

Étages 1-4 : ≈ 150 s jusqu'au boss (deux mini-boss de ≈ 23 s compris) + max(charge 60 s, boss ≈ 70 s) + ≈ 15 s de sortie ≈ 235-240 s, soit ≈ 16 min ; puis 30 s + boss final ≈ 125 s : **≈ 18,5-19 min**, dans la cible 18-20 min (32-40 min avant). D en fin de run ≈ 6,5-7 au lieu de 10-12.

## 5. Proposé, non appliqué

1. **Boss de raid** (Idole noyée, Canonnier de crue, Roi de sel) : le garde-fou de bouclier (`shield_backstop_s` 45 s pour l'Idole, `BOSS_SHIELD_BACKSTOP_S` 25 s) domine le TTK quand le joueur ne ramasse pas les cloches. À mesurer à la main en mode test d'abord : si un humain dépasse 100 s à l'étage 1, passer `BOSS_SHIELDS[drowned_idol]` 2 → 1 (le test `drowned_idol_boss_test` suit alors une seule transition, à réécrire) ou `shield_backstop_s` 45 → 30.
2. **Anguille des profondeurs** : à mesurer sur sa vraie carte (lac) ; si elle reste à plus de 2 × la médiane, `EEL_SUBMERGED_DAMAGE_TAKEN` 0,3 → 0,5.
3. **Bourbe et Taliant** au-dessus de 1,20 sur les mini-boss : −5 à −8 % sur leur dégât mono-cible principal, après vérification manuelle (le bot les avantage peut-être : mêlée au contact).
4. **Arpenteuse** 0,72 : biais du bot (chaîne non tracée) ; mesurer à la main avant toute hausse.
5. **Rictus** : brutes de l'étage 4 en 21 s (2 × les autres) ; à suivre, pas de changement sur une seule mesure.
6. **Priorité de visée et raids** : les points faibles et les adds prioritaires des raids ont aussi `aim_priority` 2,0 ; à égalité, le plus proche gagne. Si les joueurs ne visent plus les cloches ou les adds de raid, monter ces derniers à 3,0 (`priority_adds.gd`, `weak_point.gd`).

## 6. Protocole de vérification en mode test

1. Mode test, Moyen, Ardent, D 1,4, niveau 4, 5 objets communs : invoquer l'Éclusier avec le flux de monstres actif : il doit tomber en 60-80 s ; un mini-boss (Ours de givre) à D 1,15, niveau 1 : 18-28 s.
2. D 4,9, niveau 11, ≈ 29 objets : Mère-Cristal ou Reclus en 60-85 s ; un mini-boss de l'étage 4 en 20-30 s.
3. D 6,2, niveau 12, ≈ 33 objets : Semeur de pluie (final) en 110-150 s, les trois phases visibles.
4. Sur mobile (ou « Sorts automatiques »), boss entouré d'adds : les sorts automatiques visent le boss tant qu'il est à moins de 2 × la distance de l'add le plus proche ; sur PC, les sorts 2-4 suivent toujours le curseur.
5. Idole noyée à D 1,4, niveau 4 : noter le temps en ramassant les cloches (cible ≤ 100 s).
6. Une run complète en Moyen avec `RunLog` : durée totale 18-20 min, étage 1 en ≈ 4 min.

## 7. Limites et risques

- Le bot est plus lent qu'un humain sur les boss (≈ 1,0-1,5 × le temps de Tocsin à l'étage 1) et ne joue pas les mécaniques de raid : calibrés sur lui, les boss d'étage peuvent tomber en 45-55 s pour un bon joueur PC qui vise. C'est le risque principal ; le levier de retour est `BOSS_FOCUS_HP_MULT` (étage 0,5 → 0,6 = +20 % de PV).
- Arène vide (ni murs, ni lac, ni pièges d'étage) : les boss liés au terrain sont mal mesurés (Anguille).
- Le bot achète tous les coffres possibles et garde un objet au hasard ; Chance et réductions de prix ignorées.
- `BOSS_STAGE_K` touche aussi les mini-boss ; les primes ne bougent pas (`boss_gold` ne dépend pas des PV).
- Durée de run estimée à partir des rencontres ciblées, pas d'une nouvelle run complète (consigne de l'orchestrateur : plus de runs complètes) : à confirmer par une run réelle journalisée.

## 8. Outils

- `game/tests/balance_sim/full_run_sim.gd` : run complète ou rencontre ciblée (`inject`), mesures par étage, minute, boss et monstre.
- `game/tests/balance_sim_fullrun.tscn` (+ `.gd`) : lanceur ; options `--char`, `--seeds`, `--inject`, `--boss_k`, `--final_mult`, `--etage_hp`, `--mini_hp`, `--charge_zone`, `--boss_aim`, `--out`.
- `game/tests/balance_sim/bot_pilot.gd` : garde ajoutée (`_danger` plantait sur les nœuds du groupe `enemies` qui ne sont pas des `Enemy`, jarres et points faibles : 2 236 erreurs « Nonexistent 'int' constructor » sur 30 runs).
