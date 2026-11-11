# Audit d'équilibrage du roster et des objets (11/11/2026)

> Audit **en lecture seule** des valeurs de jeu (rôle `systems-designer`) : aucune constante de `balance.gd`, des kits ni des
> JSON n'a été modifiée. Seuls les outils de mesure ont changé (scénario « boss d'étage », configurations L18 et E1-E5,
> rencontres injectées, script `tools/roster_balance.py`, correctif du pilote pour Tocsin).
> Préalable à la **revue des boss** (gel des boss : aucun nouveau boss proposé ici ; §8 ne fait que fournir les mesures).
> Personnages : Ardent (référence), Rictus, Tocsin, Averse, Arpenteuse, Rainette, Avare, Bourbe, Vigie, Taliant (`morfil`),
> Grésille. Remplace la partie « mesures » de `docs/Equilibrage_Personnages.md` (23/10/2026), dont le §6 renvoie ici.

## 0. Méthode, outils et commandes

### 0.1 Ce qui est mesuré

Toutes les valeurs viennent du simulateur de combat `game/tests/balance_sim/` (bot qui joue le vrai kit, vrais monstres,
vraies formules de `Balance`, images fixes à 60 i/s, bot à 25 % d'esquives ratées), sauf mention « estimé ».

| Configuration | Niveau | Étage | Temps | D (Moyen) | Objets |
|---|---|---|---|---|---|
| L1 | 1 | 1 | 0 s | 1,0 | aucun |
| L6 | 6 | 1 | 6 min | ≈ 1,9 | 6 communs neutres |
| L12m | 12 | 4 | 14:30 | ≈ 4,9 | 30 neutres (pierre 5, sifflet 3, bague 5, amulette 3, sablier 3, lentille 4, rune 2, horloge 2, tonique 3) |
| L18 (nouvelle) | 18 | 5 | 20 min | ≈ 7,1 | 45 neutres (même famille, + botte 2, cœur de mousse 2) |
| E1 à E5 (nouvelles) | 4 / 8 / 10 / 11 / 12 | 1 à 5 | 2:30 / 6:30 / 10:30 / 14:30 / 16:30 | 1,38 / 2,28 / 3,43 / 4,87 / 6,13 | 5 / 13 / 21 / 29 / 33 objets « moyens réalistes » (communs, procs Étincelle, Flocon, Fiole, Éclair en bouteille ; Marque du chasseur, Lame jumelle, Œil du prédateur dès E4) |

Les configurations E reprennent le rythme visé de 19 min et les niveaux et nombres d'objets moyens mesurés dans les runs
complètes du 31/10 (`docs/Audit_Runs_Completes_2026-10-31.md`). L'inventaire est le même pour tous les personnages.

| Scénario | Contenu |
|---|---|
| `swarm` (essaim) | vagues de T1 ; dominé par la vitesse d'approche des monstres, gardé à part |
| `mixed` (zone) | paquets de 3-6 et tireurs : mesure de **zone** |
| `elite` | une élite T3 « brûlure » : mesure **mono** |
| `miniboss` | `frost_bear` : mesure **mono** |
| `floorboss` (nouveau) | duel contre un boss d'étage de l'étage de la configuration, plafond 300 s ; boss du pool de `data/floors.json` choisi par graine (graine 0 = premier du pool), hors raids et Anguille (`DUEL_EXCLUDED` : `drowned_idol`, `flood_gunner`, `salt_king`, `deep_eel`) ; étage 5 = boss final `rain_sower` (PV × `FINAL_BOSS_HP_MULT`) |

« Mono » = moyenne géométrique élite + mini-boss ; « zone » = scénario mixte. Les **rencontres avec monstres** (flux du
director, zone de charge, boss réel de l'étage, raids compris) passent par `balance_sim_fullrun --inject_cfg=E<n>`.

### 0.2 Commandes (reproductibles)

```sh
PY="C:/Users/const/AppData/Local/Python/bin/python.exe"
# DPS par niveau (L1, L6, L12m, L18 ; 4 scénarios ; 2 graines ; ≈ 5 min)
$PY tools/roster_balance.py run --out <dossier> --set levels --seeds 2
# TTK aux moments des boss (E1-E5 ; élite, mini-boss, boss d'étage en duel ; ≈ 5 min)
$PY tools/roster_balance.py run --out <dossier> --set bosses --seeds 2
# Rencontres de boss avec monstres (E1, E3, E5 ; 1 graine ; ≈ 7 min)
$PY tools/roster_balance.py run --out <dossier> --set encounters --cfg E1,E3,E5 --seeds 1
# Sonde d'objets (tout le roster en un processus) et ablation d'un sort
$PY tools/roster_balance.py run --out <dossier> --set probe --batch --cfg L12m --scen mixed,elite,miniboss --seeds 1 --items couronne_d_echo:2 --tag echo2
$PY tools/roster_balance.py run --out <dossier> --set probe --chars rictus --cfg L6,L12m --scen mixed,elite,miniboss --seeds 1 --noslot 4 --tag abl4
# Rapport Markdown (tableaux de ce document)
$PY tools/roster_balance.py report <dossier> -o <dossier>/rapport.md
```

`roster_balance.py` lance un processus Godot par personnage via `art/tools/vfx_test/godot_locked.sh` (verrou partagé) et
saute les JSON déjà présents (`--force` pour relancer). En direct : `balance_sim_run.tscn -- --chars=... --scen=floorboss
--cfg=E3 --items=id:n,...` et `balance_sim_fullrun.tscn -- --inject_cfg=E3 [--boss=<id>]`. Le test de fumée
`res://tests/balance_sim_test.tscn` reste vert.

### 0.3 Correctif du pilote (Tocsin) et conséquences

Le bot gardait la distance de tir calculée au début du combat. Tocsin sans tête voit ses Rivets passer de 8 à 5 u
(`RIVET_RANGE_HEADLESS_U`) : le bot restait à 5,6 u et **tirait dans le vide** pendant toute la recharge de la Tête-cloche.
`bot_pilot.gd:_pref_now()` relit maintenant la portée du sort 1 (seul Tocsin change de portée en combat ; les autres kits
fixent leurs portées à la création, leurs mesures ne bougent pas). **Tocsin passe de « le plus faible en mono » à « le plus
fort »** : les mesures de Tocsin des audits précédents (dont `Equilibrage_Personnages.md` §2 et §3) sous-estimaient son DPS.

### 0.4 Limites

- Bot : pas de ramassage de membres (Tocsin), chaîne d'Arpenteuse tracée au plus court, pas de mécanique de raid
  (cloches de l'Idole noyée non ramassées), 25 % d'esquives ratées. Les morts sont comptées, le combat continue.
- Une à deux graines par cellule : écart typique ±5-8 % entre graines (lire les ratios à ±0,08 près).
- Sondes : 1 graine, comparées à la référence **à graine égale**.
- Taliant reporte tous ses coups en emplacement 1 (parts par sort non lisibles pour lui).
- Les duels de boss d'étage ne couvrent que les 2 premiers boss du pool de chaque étage (`--seeds 4` pour tous).

## 1. Verdict : **À CORRIGER** (un bug d'objet, un personnage hors bande), le reste dans ±20 %

- **Tocsin** est hors bande en mono (×1,58 la médiane après L6, ×1,79 sur les mini-boss, ×1,22 sur les boss d'étage) :
  burst d'ouverture Tête-cloche sur électrisé + pilier qui sonne.
- **Bug** : la Couronne d'écho double les dégâts d'Averse (×2,02 contre ×1,26 pour Ardent) parce que le kit réécrit le
  coefficient des échos (§6.2).
- **Rictus** reste au-dessus en mono (×1,21 la médiane, ×1,29 mini-boss, ×1,19 boss d'étage), sans gain en zone.
- **Rafale d'acier** vaut +21 à +30 % pour les sorts 1 « de kit » contre +3 % pour un sort 1 projectile (Ardent) et
  −10 % pour Arpenteuse : option dominante pour 4 personnages, piège pour 1.
- Bas de bande (à surveiller, pas de changement) : Vigie (×0,87 global, ×0,80 en mono à L18), Taliant et Grésille (×0,86
  en mono), Arpenteuse en zone (×0,76, biais connu du bot) et en survie (§4).
- Monstres de base : tous les personnages tuent un T1 en 2 sorts 1 au plus jusqu'au boss final (Ardent à la limite :
  1,99 coup à E5). **Cible tenue.**
- Boss : les duels sont non mortels pour l'élite et le mini-boss, très mortels pour 4 boss d'étage ; en rencontre, le
  Sonneur (étage 3) meurt en 31-61 s et le boss final en 59-153 s (médiane 86 s), sous les cibles 65-75 s et 120-150 s (§8).

## 2. DPS par niveau (mono et zone, L1 / L6 / L12m / L18)

DPS effectif mesuré (sans overkill), moyenne des graines.

| Perso | L1 mono | L1 zone | L1 essaim | L6 mono | L6 zone | L6 essaim | L12m mono | L12m zone | L12m essaim | L18 mono | L18 zone | L18 essaim |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Ardent | 34 | 43 | 121 | 88 | 92 | 187 | 362 | 362 | 522 | 876 | 599 | 818 |
| Rictus | 52 | 42 | 96 | 155 | 95 | 199 | 473 | 346 | 556 | 1045 | 556 | 846 |
| Tocsin | 73 | 48 | 102 | 247 | 100 | 194 | 543 | 397 | 565 | 1350 | 639 | 846 |
| Averse | 37 | 45 | 115 | 103 | 105 | 196 | 373 | 354 | 752 | 826 | 592 | 1145 |
| Arpenteuse | 35 | 32 | 96 | 165 | 62 | 180 | 487 | 295 | 517 | 997 | 550 | 834 |
| Rainette | 44 | 51 | 127 | 122 | 110 | 196 | 452 | 409 | 538 | 1056 | 650 | 840 |
| Avare | 41 | 46 | 104 | 118 | 100 | 195 | 443 | 361 | 599 | 1046 | 609 | 919 |
| Bourbe | 39 | 43 | 89 | 111 | 93 | 180 | 425 | 358 | 576 | 846 | 630 | 887 |
| Vigie | 39 | 51 | 103 | 96 | 98 | 184 | 356 | 339 | 771 | 735 | 519 | 1111 |
| Taliant | 37 | 47 | 114 | 97 | 108 | 177 | 373 | 408 | 600 | 744 | 644 | 1090 |
| Grésille | 33 | 42 | 80 | 100 | 102 | 142 | 360 | 409 | 635 | 774 | 640 | 1053 |

### 2.1 Ratios de vitesse contre Ardent

Durée de la référence / durée du personnage (> 1 = plus rapide). En gras : hors ±20 %.

| Perso | L1 mono | L1 zone | L6 mono | L6 zone | L12m mono | L12m zone | L18 mono | L18 zone | Global L6+ | Mono L6+ | Zone L6+ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ardent | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 | 1,00 |
| Rictus | **1,53** | 1,02 | **1,75** | 1,03 | **1,31** | 0,96 | 1,19 | 0,93 | **1,24** | **1,40** | 0,97 |
| Tocsin | **2,13** | 1,13 | **2,74** | 1,08 | **1,47** | 1,09 | **1,50** | 1,07 | **1,53** | **1,82** | 1,08 |
| Averse | 1,08 | 1,10 | 1,17 | 1,14 | 1,03 | 0,98 | 0,95 | 0,99 | 1,04 | 1,05 | 1,03 |
| Arpenteuse | 1,02 | **0,78** | **1,55** | **0,65** | **1,34** | 0,81 | 1,14 | 0,92 | 1,12 | **1,33** | **0,79** |
| Rainette | **1,28** | **1,25** | **1,38** | 1,20 | **1,24** | 1,13 | **1,21** | 1,09 | **1,23** | **1,28** | 1,14 |
| Avare | **1,20** | 1,13 | **1,33** | 1,09 | **1,21** | 0,98 | 1,19 | 1,02 | 1,17 | **1,24** | 1,03 |
| Bourbe | 1,15 | 1,04 | **1,26** | 1,01 | 1,17 | 0,98 | 0,97 | 1,05 | 1,09 | 1,13 | 1,01 |
| Vigie | 1,14 | **1,25** | 1,09 | 1,06 | 0,98 | 0,94 | 0,84 | 0,87 | 0,96 | 0,97 | 0,95 |
| Taliant | 1,07 | 1,14 | 1,11 | 1,17 | 1,03 | 1,13 | 0,85 | 1,08 | 1,03 | 0,99 | 1,13 |
| Grésille | 0,97 | 1,02 | 1,13 | 1,11 | 1,00 | 1,13 | 0,88 | 1,07 | 1,03 | 1,00 | 1,10 |

### 2.2 Ratios de vitesse contre la médiane du roster

| Perso | L1 mono | L1 zone | L6 mono | L6 zone | L12m mono | L12m zone | L18 mono | L18 zone | Global L6+ | Mono L6+ | Zone L6+ |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Ardent | 0,91 | 0,91 | **0,77** | 0,92 | 0,89 | 1,02 | 0,95 | 0,98 | 0,90 | 0,87 | 0,97 |
| Rictus | **1,38** | 0,93 | **1,35** | 0,95 | 1,16 | 0,97 | 1,13 | 0,91 | 1,11 | **1,21** | 0,94 |
| Tocsin | **1,93** | 1,03 | **2,11** | 1,00 | **1,30** | 1,11 | **1,43** | 1,05 | **1,38** | **1,58** | 1,05 |
| Averse | 0,98 | 1,00 | 0,90 | 1,05 | 0,91 | 0,99 | 0,90 | 0,97 | 0,94 | 0,91 | 1,00 |
| Arpenteuse | 0,92 | **0,71** | 1,20 | **0,60** | 1,19 | 0,82 | 1,08 | 0,90 | 1,01 | 1,15 | **0,76** |
| Rainette | 1,16 | 1,14 | 1,06 | 1,11 | 1,10 | 1,15 | 1,15 | 1,07 | 1,11 | 1,10 | 1,11 |
| Avare | 1,09 | 1,03 | 1,03 | 1,00 | 1,07 | 1,00 | 1,13 | 1,00 | 1,05 | 1,08 | 1,00 |
| Bourbe | 1,04 | 0,95 | 0,97 | 0,93 | 1,04 | 1,00 | 0,92 | 1,04 | 0,98 | 0,97 | 0,99 |
| Vigie | 1,03 | 1,14 | 0,84 | 0,98 | 0,87 | 0,95 | 0,80 | 0,85 | 0,87 | 0,84 | 0,93 |
| Taliant | 0,97 | 1,04 | 0,85 | 1,08 | 0,91 | 1,15 | 0,81 | 1,06 | 0,93 | 0,86 | 1,10 |
| Grésille | 0,88 | 0,93 | 0,87 | 1,02 | 0,88 | 1,15 | 0,84 | 1,05 | 0,93 | 0,86 | 1,07 |

Lecture : Ardent, la référence historique, est **sous la médiane** (×0,90) ; la bande ±20 % se juge contre la médiane.

## 3. Temps pour tuer (TTK)

### 3.1 Monstres de base (analytique, formules de `Balance`)

| Moment | D | Niveau des monstres | PV T1 | PV T2 | PV T3 | PV élite T3 | PV mini-boss | PV boss d'étage (duel) |
|---|---|---|---|---|---|---|---|---|
| E1 | 1,38 | 2 | 24 | 122 | 504 | 2 016 | 840 | 2 519 |
| E2 | 2,28 | 4 | 36 | 187 | 792 | 3 168 | 1 580 | 4 739 |
| E3 | 3,43 | 8 | 60 | 317 | 1 368 | 5 472 | 3 158 | 9 474 |
| E4 | 4,87 | 12 | 83 | 446 | 1 944 | 7 776 | 5 218 | 15 655 |
| E5 | 6,13 | 16 | 107 | 576 | 2 520 | 10 080 | 7 489 | 30 332 (final) |
| L18 | 7,06 | 19 | 125 | 673 | 2 952 | 11 808 | 9 352 | 37 876 (final) |

Coups de sort 1 pour tuer un T1 (crit moyen compris) : 1,0 à 1,99 pour tous les personnages et tous les moments ; le plus
juste est Ardent (et les kits au même coef : Rictus, Tocsin, Vigie, Grésille) à E5 : **1,99**. La cible « 1-2 coups » tient
jusqu'au boss final, pas au-delà (L18 : 1,74 avec 45 objets, donc tenue en sans fin tant que les objets suivent).

### 3.2 Élite, mini-boss, boss d'étage (duels sans monstres)

TTK en secondes ; « Ratio méd. » = moyenne géométrique de (médiane / perso), > 1 = plus rapide ; « Subis » = dégâts subis
moyens ; « Morts » = total sur les 10 duels (5 moments × 2 graines).

#### Élite T3 (brûlure)

| Perso | E1 | E2 | E3 | E4 | E5 | Ratio méd. (géo) | Subis (moy.) | Morts |
|---|---|---|---|---|---|---|---|---|
| Ardent | 29,8 | 27,9 | 27,9 | 17,5 | 22,6 | 0,91 | 0 | 0 |
| Rictus | 22,2 | 18,7 | 19,6 | 17,4 | 18,8 | 1,16 | 66 | 0 |
| Tocsin | 22,3 | 18,7 | 17,9 | 16,3 | 18,8 | 1,20 | 0 | 0 |
| Averse | 26,1 | 22,0 | 23,4 | 18,7 | 21,8 | 1,01 | 0 | 0 |
| Arpenteuse | 27,8 | 21,8 | 23,3 | 21,2 | 25,8 | 0,94 | 0 | 0 |
| Rainette | 24,2 | 20,7 | 23,2 | 17,2 | 19,5 | 1,08 | 0 | 0 |
| Avare | 26,3 | 21,9 | 24,0 | 21,0 | 23,6 | 0,96 | 37 | 0 |
| Bourbe | 28,8 | 21,8 | 24,5 | 21,0 | 23,5 | 0,94 | 49 | 0 |
| Vigie | 26,4 | 21,6 | 24,5 | 18,4 | 21,7 | 1,00 | 0 | 0 |
| Taliant | 28,1 | 24,9 | 27,4 | 19,8 | 23,3 | 0,91 | 64 | 0 |
| Grésille | 26,8 | 22,6 | 26,5 | 20,1 | 21,6 | 0,96 | 0 | 0 |
| **Médiane** | 26,4 | 21,8 | 24,0 | 18,7 | 21,8 | | | |

#### Mini-boss (frost_bear)

| Perso | E1 | E2 | E3 | E4 | E5 | Ratio méd. (géo) | Subis (moy.) | Morts |
|---|---|---|---|---|---|---|---|---|
| Ardent | 8,8 | 16,6 | 15,1 | 10,9 | 11,6 | 0,92 | 78 | 0 |
| Rictus | 4,9 | 7,6 | 11,3 | 11,0 | 11,0 | **1,29** | 59 | 0 |
| Tocsin | 1,9 | 6,5 | 8,2 | 9,9 | 10,1 | **1,79** | 57 | 0 |
| Averse | 8,9 | 15,3 | 13,4 | 11,6 | 13,4 | 0,92 | 81 | 0 |
| Arpenteuse | 8,5 | 13,3 | 15,5 | 15,7 | 15,7 | 0,84 | 123 | 0 |
| Rainette | 8,0 | 11,6 | 12,6 | 10,2 | 10,0 | 1,09 | 32 | 0 |
| Avare | 6,9 | 8,1 | 11,3 | 11,3 | 11,2 | 1,18 | 54 | 0 |
| Bourbe | 7,3 | 10,2 | 11,6 | 11,2 | 12,8 | 1,08 | 62 | 0 |
| Vigie | 8,2 | 17,2 | 15,4 | 14,1 | 14,1 | 0,84 | 81 | 0 |
| Taliant | 9,7 | 10,8 | 14,5 | 13,3 | 14,4 | 0,91 | 45 | 0 |
| Grésille | 8,6 | 19,6 | 18,1 | 13,4 | 15,4 | **0,78** | 63 | 0 |
| **Médiane** | 8,2 | 11,6 | 13,4 | 11,3 | 12,8 | | | |

#### Boss d'étage (duel)

| Perso | E1 | E2 | E3 | E4 | E5 | Ratio méd. (géo) | Subis (moy.) | Morts |
|---|---|---|---|---|---|---|---|---|
| Ardent | 38,9 | 48,8 | 44,5 | 38,3 | 67,1 | 0,92 | 830 | 7 |
| Rictus | 30,2 | 30,4 | 34,6 | 33,2 | 55,1 | 1,19 | 704 | 5 |
| Tocsin | 32,9 | 32,0 | 32,4 | 29,9 | 50,6 | **1,22** | 635 | 3 |
| Averse | 35,9 | 39,7 | 42,3 | 37,7 | 62,2 | 1,00 | 668 | 3 |
| Arpenteuse | 46,3 | 41,3 | 48,7 | 50,2 | 95,6 | **0,79** | 1125 | 11 |
| Rainette | 36,0 | 40,6 | 35,2 | 32,0 | 52,2 | 1,11 | 568 | 2 |
| Avare | 31,9 | 34,6 | 33,8 | 35,6 | 56,0 | 1,14 | 519 | 1 |
| Bourbe | 34,9 | 33,7 | 37,8 | 37,1 | 78,4 | 1,02 | 866 | 4 |
| Vigie | 37,3 | 43,9 | 44,6 | 39,5 | 68,0 | 0,94 | 797 | 8 |
| Taliant | 37,4 | 38,7 | 43,3 | 39,3 | 58,3 | 1,00 | 534 | 1 |
| Grésille | 40,3 | 44,8 | 45,1 | 42,0 | 70,8 | 0,90 | 811 | 6 |
| **Médiane** | 36,0 | 39,7 | 42,3 | 37,7 | 62,2 | | | |
| Boss | eclusier, ox_herder | cerf, weaver | crane, sonneur | crystal_mother, recluse | rain_sower | | | |
| PV (méd.) | 2519 | 4739 | 9474 | 15655 | 30332 | | | |

### 3.3 Rencontres de boss avec monstres (TTK en jeu)

| Perso | E1 TTK / part | E3 TTK / part | E5 TTK / part |
|---|---|---|---|
| Ardent | 140 / 0,26 (drowned_idol) | 60 / 0,45 (sonneur) | 90 / 0,60 (rain_sower) |
| Rictus | 141 / 0,27 (drowned_idol) | 31 / 0,60 (sonneur) | 59 / 0,80 (rain_sower) |
| Tocsin | 132 / 0,29 (drowned_idol) | 41 / 0,55 (sonneur) | 63 / 0,67 (rain_sower) |
| Averse | 141 / 0,28 (drowned_idol) | 47 / 0,46 (sonneur) | 75 / 0,60 (rain_sower) |
| Arpenteuse | 164 / 0,24 (drowned_idol) | 47 / 0,46 (sonneur) | 153 / 0,38 (rain_sower) |
| Rainette | 130 / 0,29 (drowned_idol) | 35 / 0,57 (sonneur) | 68 / 0,65 (rain_sower) |
| Avare | 133 / 0,29 (drowned_idol) | 36 / 0,57 (sonneur) | 90 / 0,57 (rain_sower) |
| Bourbe | 126 / 0,30 (drowned_idol) | 38 / 0,57 (sonneur) | 90 / 0,55 (rain_sower) |
| Vigie | 131 / 0,28 (drowned_idol) | 47 / 0,46 (sonneur) | 92 / 0,55 (rain_sower) |
| Taliant | 124 / 0,30 (drowned_idol) | 44 / 0,55 (sonneur) | 81 / 0,60 (rain_sower) |
| Grésille | 132 / 0,29 (drowned_idol) | 61 / 0,45 (sonneur) | 86 / 0,60 (rain_sower) |

Calibration duel → rencontre (même boss, même personnage) : **×1,21** (médiane E3) et **×1,30** (E5). L'ancienne règle
« TTK en jeu ≈ duel / 0,5 » (`BOSS_FOCUS_HP_MULT`) surestime d'un facteur 1,6 : les PV ×0,5 compensent déjà la part
des dégâts qui part dans les monstres. E1 = Idole noyée (raid, cloches non ramassées par le bot) : non représentatif.

### 3.4 Contre les cibles

| Rencontre | Cible | Mesuré (médiane du roster) | Écart |
|---|---|---|---|
| Monstre de base T1 | 1-2 coups | 1,0-1,99 coup | tenue |
| Élite T3 (duel) | 8-40 s (« mini-événement ») | 18,7-26,4 s | tenue |
| Mini-boss | 21-30 s avec monstres | 8,2-13,4 s en duel, ≈ 10-17 s estimé avec monstres | **−40 à −55 %** |
| Boss d'étage 1-4 | 65-75 s avec monstres | 36-42 s en duel ; 44 s en rencontre (Sonneur, E3) | **−30 à −40 %** |
| Boss final | 120-150 s avec monstres | 62 s en duel ; 86 s en rencontre | **−30 à −40 %** |

Ces écarts concernent les **boss**, pas le roster : ils vont à la revue des boss (§8).

## 4. Survie

PV effectifs = PV × (100 + armure) / 100 (pas de plafond d'armure dans le calcul affiché ; réductions de kit à part).

| Perso | L1 PV / armure / PV eff. | L6 PV / armure / PV eff. | L12m PV / armure / PV eff. | L18 PV / armure / PV eff. | Subis mixte L6/L12m/L18 | Subis mini-boss L6/L12m/L18 | Morts (tous combats) |
|---|---|---|---|---|---|---|---|
| Ardent | 100 / 0 / 100 | 275 / 10 / 302 | 675 / 30 / 878 | 945 / 40 / 1323 | 57 / 12 / 0 | 47 / 25 / 94 | 0 |
| Rictus | 95 / 10 / 104 | 260 / 20 / 312 | 648 / 40 / 907 | 906 / 50 / 1359 | 65 / 50 / 41 | 14 / 8 / 125 | 0 |
| Tocsin | 130 / 20 / 156 | 335 / 30 / 436 | 771 / 50 / 1156 | 1077 / 60 / 1723 | 54 / 11 / 0 | 0 / 85 / 0 | 0 |
| Averse | 90 / 0 / 90 | 250 / 10 / 275 | 632 / 30 / 822 | 884 / 40 / 1238 | 45 / 37 / 49 | 47 / 37 / 184 | 0 |
| Arpenteuse | 85 / 0 / 85 | 235 / 10 / 258 | 605 / 30 / 786 | 845 / 40 / 1183 | 95 / 80 / 49 | 55 / 25 / 141 | 2 |
| Rainette | 90 / 10 / 99 | 250 / 20 / 300 | 632 / 40 / 885 | 884 / 50 / 1326 | 12 / 11 / 0 | 0 / 23 / 0 | 0 |
| Avare | 120 / 30 / 156 | 325 / 40 / 455 | 761 / 60 / 1218 | 1067 / 70 / 1814 | 54 / 40 / 7 | 28 / 51 / 60 | 0 |
| Bourbe | 116 / 10 / 128 | 340 / 20 / 408 | 690 / 40 / 966 | 1250 / 50 / 1875 | 25 / 0 / 11 | 42 / 0 / 130 | 0 |
| Vigie | 90 / 0 / 90 | 250 / 10 / 275 | 632 / 30 / 822 | 884 / 40 / 1238 | 45 / 37 / 33 | 51 / 37 / 94 | 0 |
| Taliant | 115 / 25 / 144 | 315 / 35 / 425 | 745 / 55 / 1155 | 1045 / 65 / 1724 | 48 / 44 / 23 | 40 / 0 / 103 | 0 |
| Grésille | 95 / 5 / 100 | 260 / 15 / 299 | 648 / 35 / 875 | 906 / 45 / 1314 | 18 / 47 / 0 | 54 / 59 / 124 | 0 |

Défenses de kit (lues dans le code) : Rictus garde ×0,7 pendant 0,3 s par coup (`GUARD_S`) ; Avare ×0,55 pendant 0,4 s
(0,6 s sur un marqué) ; Taliant ×0,55 pendant 0,6 s par auto (0,7 s), soit 86-100 % du temps avec de la vitesse
d'attaque ; Bourbe −30 % à 0 motte ; Rainette ignore les contacts en l'air ; Averse intouchable en glissade ; Grésille
×0,5 contre les flaques électrisées. Plafonds communs : `MITIGATION_CAP` 0,9, `DODGE_CAP` 0,75, `INVULN_AFTER_HIT` 0,4 s.
Esquives : roulade de 3 u toutes les 3 s pour la plupart ; Ardent clignement ; Avare 2,5 u ; Rainette bond arrière 3,5 u ;
Vigie 3 charges de 1,6 u ; Grésille Court-circuit 3 u.

Dégâts subis en duel de boss d'étage (moyenne sur 10 duels) : Avare 519, Taliant 534, Rainette 568 (les trois mieux
protégés) ; Arpenteuse **1 125** et 11 morts (la pire), pour les PV effectifs les plus bas du roster (786 à L12m).

## 5. Écarts à la médiane (synthèse)

| Perso | Global L6+ | Mono L6+ | Zone L6+ | Élite | Mini-boss | Boss d'étage | Survie | Verdict |
|---|---|---|---|---|---|---|---|---|
| Ardent | 0,90 | 0,87 | 0,97 | 0,91 | 0,92 | 0,92 | moyenne | dans la bande (sous la médiane) |
| Rictus | 1,11 | **1,21** | 0,94 | 1,16 | **1,29** | 1,19 | moyenne | mono trop fort (R4, R5) |
| Tocsin | **1,38** | **1,58** | 1,05 | 1,20 | **1,79** | **1,22** | haute (1 156 PV eff.) | hors bande (R2, R3) |
| Averse | 0,94 | 0,91 | 1,00 | 1,01 | 0,92 | 1,00 | basse | dans la bande ; bug d'écho (R1) |
| Arpenteuse | 1,01 | 1,15 | **0,76** | 0,94 | 0,84 | **0,79** | la plus basse | zone = biais du bot ; survie (R7) |
| Rainette | 1,11 | 1,10 | 1,11 | 1,08 | 1,09 | 1,11 | haute (peu touchée) | haut de bande, à surveiller |
| Avare | 1,05 | 1,08 | 1,00 | 0,96 | 1,18 | 1,14 | haute | dans la bande ; hâte (R8) |
| Bourbe | 0,98 | 0,97 | 0,99 | 0,94 | 1,08 | 1,02 | moyenne | dans la bande |
| Vigie | 0,87 | 0,84 | 0,93 | 1,00 | 0,84 | 0,94 | basse | bas de bande (L18 mono 0,80), à surveiller |
| Taliant | 0,93 | 0,86 | 1,10 | 0,91 | 0,91 | 1,00 | haute | dans la bande |
| Grésille | 0,93 | 0,86 | 1,07 | 0,96 | **0,78** | 0,90 | moyenne | bas sur mini-boss, à surveiller |

Ablations (sort retiré, ratio de durée ; < 1 = plus lent sans le sort) : Rictus sans Couteau ficelé ×0,41-0,62, sans
Saccade ×0,57-0,71, sans Doublures ×0,63-0,74 (le combo ficelé porte tout le mono) ; Avare sans Poignée ×0,47-0,51 en
mono ; Bourbe sans sort 2 ×0,43-0,53 ; Rainette sans Grand saut ×0,73 (élite L12m), sans ultime ×0,74 ; **Tocsin sans
Tête-cloche ×0,27** sur le mini-boss L6 et ×0,61-0,69 sur l'élite, sans Bras-pilier ×0,41-0,70.

Part des dégâts par sort (L12m, élite + mini-boss) :

| Perso | Sort 1 | Sort 2 | Sort 3 | Sort 4 |
|---|---|---|---|---|
| Ardent | 35 % | 18 % | 21 % | 27 % |
| Rictus | 27 % | 24 % | 17 % | 32 % |
| Tocsin | 27 % | 43 % | 12 % | 18 % |
| Averse | 49 % | 18 % | 22 % | 11 % |
| Arpenteuse | 10 % | 23 % | 28 % | 39 % |
| Rainette | 39 % | 18 % | 16 % | 27 % |
| Avare | 21 % | 54 % | 11 % | 14 % |
| Bourbe | 12 % | 48 % | 16 % | 25 % |
| Vigie | 41 % | 10 % | 17 % | 32 % |
| Taliant | 100 % | 0 % | 0 % | 0 % |
| Grésille | 38 % | 22 % | 21 % | 20 % |

## 6. Objets × personnages et stratégies dégénérées

### 6.1 Sondes (L12m, ratio de vitesse contre le même personnage sans l'objet, graines égales)

| Perso | Couronne d'écho ×2 | Rafale d'acier ×2 | Cœur de glace ×5 | Éclair en bouteille ×3 | Venin concentré ×3 | Sifflet ×6 + Carquois ×2 | Sablier ×4 + Horloge ×2 + Chronomètre ×1 |
|---|---|---|---|---|---|---|---|
| Ardent | 1,26 | 1,03 | 1,00 | 0,99 | 1,15 | 1,18 | 1,28 |
| Rictus | 1,19 | 1,13 | 1,00 | 1,08 | 1,18 | 1,16 | 1,22 |
| Tocsin | 1,28 | 1,10 | 1,34 | 1,04 | 1,19 | 1,12 | 1,24 |
| Averse | 2,02 | 1,30 | 1,34 | 1,00 | 1,25 | 1,45 | 1,08 |
| Arpenteuse | 1,00 | 0,90 | 1,05 | 1,01 | 1,03 | 1,02 | 1,36 |
| Rainette | 1,21 | 1,13 | 1,10 | 1,10 | 1,26 | 1,29 | 1,17 |
| Avare | 1,29 | 1,21 | 1,00 | 1,18 | 1,28 | 1,23 | 1,49 |
| Bourbe | 1,12 | 1,10 | 1,13 | 1,10 | 1,34 | 1,13 | 1,27 |
| Vigie | 1,31 | 1,25 | 1,16 | 1,03 | 1,25 | 1,27 | 1,31 |
| Taliant | 1,36 | 1,14 | 1,00 | 1,07 | 1,29 | 1,26 | 1,10 |
| Grésille | 1,32 | 1,22 | 1,30 | 1,04 | 1,21 | 1,21 | 1,17 |

Attendu « neutre » : Couronne ×2 ≈ +27 % (écho 45 % puis 31,5 % sur la part du sort 1), Rafale ×2 ≈ +15-25 %.

### 6.2 Bug : les échos d'Averse partent à pleine puissance (dégénéré)

`SpellCaster._cast` applique le multiplicateur d'écho sur une copie du sort (`s.coef *= _repeat_mult`,
`spell_caster.gd` l. 415-417). Le kit d'Averse **réécrit** ce coefficient au tir :

- `averse_kit.gd` l. 963 (Goutte-lame) : `shot.coef = GOUTTE_COEF_MIN + GOUTTE_COEF_WATER * water_ratio()` ;
- `averse_kit.gd` l. 1318 (variante Bruine) : `shot.coef = BRUINE_COEF_MIN + BRUINE_COEF_WATER * water_ratio()`.

Chaque écho de la Couronne vaut donc un tir plein (avec le bonus d'eau) au lieu de 45 % puis 31,5 % : Averse gagne ×2,02
contre ×1,26 pour Ardent. Même motif, moins grave, pour la ligne de la Langue de Rainette (`rainette_kit.gd` l. 801,
`_line_sd.coef = TONGUE_LINE_COEF` : les monstres de la ligne prennent l'écho à pleine puissance ; le cache est en plus
invalidé à chaque écho, une allocation de `SpellData` par écho). Les autres réécritures relevées sont saines : la Saccade de Rictus (`rictus_kit.gd` l. 825/849/912), Bourbe (l. 463),
Taliant (l. 374) et Grésille gardent le rapport `s.coef / coef de base` ; la Flambée d'Ardent, la Toupie et le vol de
Rictus, la remontée de Bourbe sont des sorts 2-4 que les échos ne rejouent pas.

### 6.3 Rafale d'acier : dominante pour les sorts 1 de kit

`item_effects.gd:_rafale_on_cast` (l. 486-498) : pour un sort 1 projectile, 2 tirs latéraux à ±14° (qui ratent une cible
unique) ; pour un sort 1 de kit (Averse, Vigie, Grésille, Avare...), **2 rejeux à pleine puissance** tous les 5 lancers
(+40 % de lancers, sans le multiplicateur que la Couronne applique). Mesure : +21 à +30 % pour ces kits, +3 % pour Ardent,
**−10 % pour Arpenteuse** (le rejeu de la chaîne gêne son tracé : objet-piège pour elle).

### 6.4 Autres lectures

- **Cœur de glace ×5** : +30-34 % pour Averse (trempé = ralenti), Tocsin (pilier qui engourdit) et Grésille, 0 % sans
  source de ralentissement. Conditionnel par design, plafond +95 % tenu : sain, à garder en tête pour Averse (qui cumule
  écho et glace).
- **Hâte (Sablier ×4, Horloge ×2, Chronomètre ×1)** : Avare +49 %, Arpenteuse +36 %, Vigie +31 %, contre +8-10 % pour
  Averse et Taliant (dégâts portés par le sort 1). Le plancher de recharge (−65 %) borne l'empilement ; l'écart vient de
  la Poignée d'Avare (54 % de ses dégâts sur un sort à recharge).
- **Venin ×3** : Bourbe +34 %, Taliant +29 % (beaucoup de coups) ; **Éclair ×3** : 0-18 % (sain).
- **Vitesse d'attaque (Sifflet ×6 + Carquois ×2)** : Averse +45 % (le sort 1 porte 49 % de ses dégâts) ; dans l'ordre
  attendu pour un perso « auto ».
- Aucun empilement sans plafond trouvé : plafonds de mitigation, d'esquive, de hâte, de Cœur de glace et de Faux tenus.
  Le plafond de 25 % des PV max par coup n'a pas été pris en défaut dans les duels.

## 7. Recommandations (par priorité)

Valeurs **estimées** à partir des parts de dégâts et des ablations mesurées (non mesurées avec la valeur proposée) :
à remesurer avec les commandes du §0.2 après application.

| # | Prio | Fichier : constante ou clé | Actuel | Proposé | Plage sûre | Effet attendu (estimé) |
|---|---|---|---|---|---|---|
| R1 | P1 | `game/scripts/spells/averse_kit.gd` l. 963 et l. 1318 : coef du tir | `GOUTTE_COEF_MIN + GOUTTE_COEF_WATER × eau` (idem Bruine) | même formule **× `s.coef / GOUTTE_COEF_MIN`** (resp. `/ BRUINE_COEF_MIN`) ; `rainette_kit.gd` l. 801 : `TONGUE_LINE_COEF × s.coef / TONGUE_COEF`, cache par valeur de coef | correctif, pas de plage | Averse + Couronne ×2 : ×2,02 → ≈ ×1,27 ; aucun effet sans écho |
| R2 | P1 | `tocsin_kit.gd` : `HEAD_CHARGE_ADD` | 0,5 | 0,3 | 0,25-0,35 | Tête-cloche sur boss électrisé ×1,8 → ×1,6 ; burst d'ouverture −5 % |
| R3 | P1 | `tocsin_kit.gd` : `PILLAR_RING_CAP` | 5,0 | 3,0 | 2,5-3,5 | pilier qui sonne 10 → 6 coef par Tête-cloche ; avec R2 : burst −17 %, DPS soutenu −7 % ; mono L6+ ×1,58 → ≈ ×1,35, mini-boss ×1,79 → ≈ ×1,5, boss d'étage ×1,22 → ≈ ×1,13 |
| R4 | P2 | `rictus_kit.gd` : `DECOY_FICELE_MULT` | 1,3 | 1,1 | 1,0-1,2 | Doublures (32 % des dégâts mono) −15 % sur ficelé : mono −5 % ; zone intacte |
| R5 | P2 | `rictus_kit.gd` : `SACCADE_TOUR_ADD` | 0,25 | 0,15 | 0,10-0,20 | Saccade à 3 tours ×1,75 → ×1,45 : −3 % ; avec R4 : mono ×1,21 → ≈ ×1,12, boss d'étage ×1,19 → ≈ ×1,10, mini-boss ×1,29 → ≈ ×1,19 |
| R6 | P2 | `game/data/items.json` `rafale_d_acier.special_data.kit_replay_mult` (nouvelle clé, lue par `item_effects.gd:_rafale_on_cast` l. 496 : `"mult": kit_replay_mult` dans `_echo_queue`) | absente (= 1,0) | 0,5 | 0,4-0,6 | sorts 1 de kit : +21-30 % → ≈ +10-15 % (proche d'un projectile en zone) ; aucun effet sur les sorts projectiles |
| R7 | P3 | `arpenteuse_kit.gd` : `HP_BASE` / `HP_PER_LEVEL` | 85 / 25 | 90 / 27 | 88-95 / 26-28 | PV eff. L12m 786 → ≈ 825 (= Averse, Vigie) ; vise les 11 morts en duel de boss (à confirmer en mode test, une partie vient du bot) |
| R8 | P3 | `avare_kit.gd` : `COIN_MARKED_COEF` | 1,8 | 1,6 (levier déjà noté dans le code) | 1,5-1,7 | Poignée (54 % des dégâts) −11 % sur marqué : mini-boss ×1,18 → ≈ ×1,11, boss d'étage ×1,14 → ≈ ×1,08, sonde hâte +49 % → ≈ +43 % |

Non recommandé : toucher Arpenteuse en zone (×0,76 = chaîne tracée au plus court par le bot ; l'audit précédent mesurait
la même chose et la théorie donne l'inverse) ; Vigie, Taliant et Grésille (bas de bande mais boss d'étage ×0,90-1,00) ;
Rainette (haut de bande sur tout, ×1,11, sans pic). R2-R3 avant R4-R5 : la médiane bouge avec Tocsin.

Ordre d'application conseillé : R1 (bug), puis R2-R3, remesure `--set levels` et `--set bosses` (10 min), puis R4-R5,
R6 et R8, enfin R7 après vérification en mode test. Si Tocsin reste au-dessus de ×1,25 en mono après R2-R3 :
`HEAD_COEF` 9 → 8 (plage 7,5-8,5).

### Risques

- R1 rend Averse plus faible avec la Couronne qu'aujourd'hui : c'est l'alignement attendu (+27 %), pas un nerf du kit.
- R2-R3 touchent aussi le Tocsin humain qui ramasse ses membres ; le bot ne ramasse pas, donc le Tocsin réel est plus fort
  que mesuré : la réduction proposée est prudente.
- R6 demande 3 lignes de code dans `item_effects.gd` (dossier `scripts/items`, pas `scripts/core`) et une clé JSON.
- Rafale d'acier × Arpenteuse (−10 %) : à vérifier en mode test ; si confirmé, exclure le sort 1 d'Arpenteuse des rejeux
  (comportement spécial du kit) plutôt que de toucher l'objet.

## 8. Préparation de la revue des boss (mesures seulement, gel des boss)

### 8.1 Létalité en duel (bot à 25 % d'esquives ratées ; 11 duels par boss, 22 pour le final)

| Étage | Boss | Morts / duels | Dégâts subis moyens | PV max moyens du joueur | Subis / PV max |
|---|---|---|---|---|---|
| 1 | `eclusier` | 5 / 11 | 253 | 216 | 1,2 |
| 1 | `ox_herder` | 8 / 11 | 330 | 224 | 1,5 |
| 2 | `cerf` | 0 / 11 | 227 | 367 | 0,6 |
| 2 | `weaver` | 3 / 11 | 393 | 360 | 1,1 |
| 3 | `crane` | 1 / 11 | 557 | 451 | 1,2 |
| 3 | `sonneur` | 6 / 11 | 763 | 477 | 1,6 |
| 4 | `crystal_mother` | 0 / 11 | 487 | 533 | 0,9 |
| 4 | `recluse` | 8 / 11 | 999 | 533 | 1,9 |
| 5 | `rain_sower` (final) | **20 / 22** | 1 725 | 618 | **2,8** |

En rencontre avec monstres (le bot récupère des soins, les coups se partagent) : 0-2 morts contre le Sonneur, 1-5 contre le
Semeur de pluie (Arpenteuse 5), 2-7 contre l'Idole noyée (Rictus 7).

### 8.2 Durées

- Boss d'étage en rencontre : Sonneur 31-61 s (médiane 44 s) pour une cible de 65-75 s.
- Boss final en rencontre : 59-153 s (médiane 86 s ; Rictus 59 s, Arpenteuse 153 s) pour une cible de 120-150 s.
  Avec `FINAL_BOSS_HP_MULT` 1,35, la cible demanderait ≈ ×1,5 de PV (estimé) ; or c'est déjà le boss le plus mortel
  (§8.1) : la revue devra choisir entre durée et pression (PV plus hauts **et** dégâts plus bas).
- Mini-boss : 8-13 s en duel, ≈ 10-17 s estimé avec monstres, pour 21-30 s visés. Des PV de mini-boss plus hauts
  dilueraient aussi le burst d'ouverture de Tocsin (R2-R3).
- Idole noyée (raid) : 124-164 s, part des dégâts sur le boss 0,24-0,30, parce que le bot ne ramasse pas les cloches.
  **À mesurer en mode test** (non représentatif ici).
- Non mesurés en duel : `jar_bearer`, `hermit_cedar`, `smelter` (relancer `--set bosses --seeds 4`) et les raids
  `flood_gunner`, `salt_king`, `deep_eel` (rencontres seulement).

## 9. Protocole de vérification en mode test

1. Mode test (bouton du titre ou `-- --test-mode`), panneau F1, difficulté D réglée sur la valeur du moment (E3 : 3,4).
2. **R1** : Averse, ajouter 2 Couronnes d'écho, frapper un mini-boss invoqué : les deux échos doivent afficher environ
   45 % puis 31 % du chiffre du coup principal (aujourd'hui : le même chiffre).
3. **R2-R3** : Tocsin niveau 6, invoquer un mini-boss, poser les 2 piliers, Coup de tocsin, Tête-cloche : chronométrer
   le mini-boss (aujourd'hui ≈ 3 s, attendu ≈ 4-5 s) ; puis un boss d'étage de l'étage 3 avec 21 objets (≈ 32 s en
   duel aujourd'hui, attendu ≈ 36 s).
4. **R4-R5** : Rictus, ficeler une élite, poser les Doublures, Saccade à 3 tours : comparer les chiffres d'explosion.
5. **R6** : Averse ou Vigie avec 2 Rafales d'acier : les 2 rejeux tous les 5 tirs doivent afficher la moitié du coup.
6. **Rafale × Arpenteuse** et **Idole noyée** : vérifier à la main (limites du bot).

## 10. Non évalué

| Point | Ce qui manque |
|---|---|
| Jeu humain optimisé | Ramassage des membres de Tocsin, chaîne d'Arpenteuse tracée à travers les paquets, cloches des raids |
| Variantes de sorts | Seuls les kits de base sont mesurés (Bruine lue dans le code, pas simulée) |
| Coop 1-4 | PV des boss × (1 + 0,4 (n−1)) non simulés |
| Forge | Objets fabriqués non sondés |
| Run complète de 19 min par personnage | Seuls les moments E1, E3, E5 sont injectés ; pas de durée de run ni de flux d'or par personnage |
| Boss non couverts | `jar_bearer`, `hermit_cedar`, `smelter` en duel ; raids hors Idole en rencontre |
