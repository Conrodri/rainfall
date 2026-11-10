# Balance check : Grésille (10/11/2026)

Audit d'équilibrage en lecture seule du personnage **Grésille** (`gresille`), fait par le consultant systems-designer à la demande de l'orchestrateur. Aucun fichier du jeu n'a été modifié : les variantes testées l'ont été par des scripts temporaires hors dépôt (sous-classes du kit et du simulateur), et leurs résultats sont des **mesures en jeu sur variante**, pas des valeurs en vigueur.

## Sources

| Entrée | Statut |
|---|---|
| `docs/fiches/gresille.md` (fiche complète, §4 sorts, §5 Statique, §6 eau, §8 statistiques) | TROUVÉ |
| `game/scripts/spells/gresille_kit.gd`, `gresille_static.gd`, `gresille_ground_field.gd` | TROUVÉ |
| `game/data/characters.json` (entrée `gresille`), `game/data/items.json` | TROUVÉ |
| `game/scripts/core/balance.gd` (`player_base_damage`, `TIER_STATS`, `MONSTER_HP_GROWTH`, `COOLDOWN_FLOOR`, `ATTACK_SPEED_BONUS_CAP`, `PIERCE_CAP`, `CHAIN_LIGHTNING_*`) | TROUVÉ |
| `game/scripts/spells/spell_caster.gd` (`deal_damage`, `_roll_procs`, `_lightning`), `game/scripts/enemies/enemy.gd` (`stun`, `apply_status slow`, `is_wet`, `mark_wet`) | TROUVÉ |
| `game/scripts/stage/stage_map.gd` (`is_water_at`, `water_patch_at`, `water_override`) | TROUVÉ |
| `docs/Equilibrage_Personnages.md` (cibles, méthode des ratios, TTK de boss d'Ardent du 23/10) | TROUVÉ |
| `docs/Maths_Scaling.md` §14 (cibles RoR2), `docs/Design_Combos.md` | TROUVÉ (consultés pour les cibles) |
| `game/tests/balance_sim/*` et `balance_sim_run.tscn` | TROUVÉ |
| Simulation coop (deux joueurs) | ABSENT : le simulateur est solo ; la coop avec Averse est bornée par le scénario « tout mouillé » |
| Cartes réelles (Terrasses, Cité, Gouffre, Cryptes) dans le simulateur | ABSENT : arène plate ; l'eau est simulée par `StageMap.water_override` (tout en eau, ou bassin de 12 × 12 u centré) |

Commandes lancées (sorties dans le scratchpad de session, rien dans le dépôt) :
- `godot --headless --path game --script res://tests/test_balance.gd` : `RESULT: OK (0 echec(s))`.
- `godot --headless --path game res://tests/gresille_test.tscn` : `RESULT: OK`.
- `godot --headless --path game res://tests/balance_sim_run.tscn -- --chars=<id> --scen=swarm,mixed,elite,miniboss --cfg=L1,L6,L12,L12m --seeds=2` pour Ardent, Grésille, Tocsin, Averse, Vigie.
- Même simulateur relancé par un lanceur temporaire hors dépôt pour : eau sur toute l'arène, bassin central, Orage sans suspension du sort 1, Mise à la terre automatique au contact d'une élite ou d'un boss, coefficients modifiés (Arc 0,9, Décharge 3,2/3,3, Orage 1,5, Mise à la terre 0,55), rayons modifiés (Orage 2,0 u, Mise à la terre 3,5 u), immunité de foudroiement 2,5 s, objets ajoutés (Cœur de glace ×1 et ×5, Éclair en bouteille ×3, Pointe perforante ×1).
- `python docs/simulateur_scaling.py moyen` : le modèle v3 historique donne une run de 10 min sur 3 étages et le niveau 19 à 10 min ; il **diverge** de `balance.gd` et de la cible de 18-20 min. Il n'est pas utilisé pour les conclusions de cet audit.

Méthode : « ratio vs Ardent » = durée du combat d'Ardent / durée du combat de Grésille (> 1 : plus rapide qu'Ardent), comme dans `Equilibrage_Personnages.md`. Moyenne géométrique sur L6, L12 et L12m ; « mono » = élite + mini-boss, « zone » = essaim + mixte. Bande cible : [0,85 ; 1,20] en mono (fiche, `Equilibrage_Personnages.md`), ±20 % ailleurs.

## Verdict : À SURVEILLER

Grésille est **trop faible en mono-cible** dans sa version actuelle (0,76 × Ardent sur élite et mini-boss, sous le plancher de 0,85), et la cause n'est pas un coefficient : ce sont **deux règles du kit**. L'Orage suspend le sort 1 pendant 3 s, ce qui coûte autant de dégâts qu'il en rapporte dès que la vitesse d'attaque monte ; et la Mise à la terre n'est jamais lancée par le ciblage automatique face à une cible seule. Corriger ces deux règles, sans toucher un seul chiffre, ramène le mono à 1,00 et le global à 0,97 (sec) / 1,10 (eau), dans la bande. Aucune stratégie dégénérée qui domine tout n'a été trouvée en solo ; l'étourdissement en chaîne des élites est fort en solo (jusqu'à 31 % du temps) et devient un verrou en coop à plusieurs Grésille. L'essaim dispersé du début de run reste sous la bande (0,65-0,74), de façon structurelle.

## TTK

Monstre de base (coups d'Arc pour tuer, calcul à partir de `TIER_STATS` et `MONSTER_HP_GROWTH`, Pierres à aiguiser des configurations comprises) :

| Config | D | Niveau monstre | Arc (dégâts) | T1 | T2 | T3 | Élite T3 (×4 PV) | Cible doc |
|---|---|---|---|---|---|---|---|---|
| L1 | 1,00 | 1 | 9,6 | 18 PV : **2 Arcs** | 90 PV : 10 | 360 PV : 38 | 1 440 PV | base en 1-2 coups : conforme |
| L6 | 1,91 | 3 | 21,1 | 30 PV : **2 Arcs** | 155 PV : 8 | 648 PV : 31 | 2 592 PV | conforme |
| L12 | 2,53 | 5 | 36,9 | 42 PV : **2 Arcs** | 220 PV : 6 | 936 PV : 26 | 3 744 PV | conforme |
| L12m | 4,87 | 12 | 46,1 | 83 PV : **2 Arcs** | 446 PV : 10 | 1 944 PV : 43 | 7 776 PV | conforme |

Le rebond (0,45) tue un T1 en 3-4 coups : il entame, il ne fauche pas.

Élite T3 et mini-boss (mesuré, durée du combat / dégâts subis, moyenne de 2 graines) :

| Perso | Combat | L1 | L6 | L12 | L12m |
|---|---|---|---|---|---|
| Ardent | élite | 46,9 s / 0 PV | 33,0 s / 0 PV | 18,0 s / 0 PV | 22,7 s / 0 PV |
| Ardent | mini-boss | 16,2 s / 97 PV | 11,7 s / 53 PV | 7,9 s / 76 PV | 13,6 s / 25 PV |
| **Grésille actuelle (sec)** | élite | 58,4 s / 23 PV | 39,1 s / 57 PV | 25,0 s / 76 PV | 31,5 s / 60 PV |
| **Grésille actuelle (sec)** | mini-boss | 16,9 s / 92 PV | 11,7 s / 113 PV | 12,7 s / 63 PV | 19,0 s / 71 PV |
| Grésille R1+R2 (sec) | élite | 46,9 s / 0 PV | 29,1 s / 0 PV | 18,1 s / 0 PV | 20,8 s / 0 PV |
| Grésille R1+R2 (sec) | mini-boss | 15,2 s / 66 PV | 10,7 s / 54 PV | 10,5 s / 33 PV | 14,0 s / 24 PV |
| Grésille R1+R2 (eau) | élite | 45,0 s / 0 PV | 28,0 s / 0 PV | 18,2 s / 0 PV | 21,1 s / 0 PV |
| Grésille R1+R2 (eau) | mini-boss | 11,2 s / 65 PV | 8,0 s / 0 PV | 7,6 s / 0 PV | 13,7 s / 47 PV |
| Tocsin | élite | 69,0 s / 0 PV | 44,2 s / 0 PV | 18,8 s / 0 PV | 22,7 s / 0 PV |
| Averse | élite | 48,0 s / 0 PV | 27,0 s / 0 PV | 16,2 s / 0 PV | 20,4 s / 0 PV |
| Vigie | élite | 43,5 s / 0 PV | 28,8 s / 0 PV | 17,0 s / 0 PV | 21,9 s / 0 PV |

« R1+R2 » = recommandations 1 et 2 ci-dessous (Orage sans suspension du sort 1, Mise à la terre automatique au contact d'une élite ou d'un boss), aucun coefficient changé.

Boss d'étage (**estimé**, TTK d'Ardent du tableau §3 de `Equilibrage_Personnages.md` du 23/10, divisé par le ratio mini-boss de Grésille ; les serviteurs, qui nourrissent les arcs de Décharge, et le +10 % de Foudroiement sont déjà dans le ratio mini-boss mais pas les mécaniques de phase) :

| | Ét. 1 | Ét. 2 | Ét. 3 | Ét. 4 | Final | Cible |
|---|---|---|---|---|---|---|
| Ardent (réf. 23/10) | 42 s | 51 s | 65 s | 73 s | 157 s | 65-75 s par boss d'étage ; 75-100 s pour le final |
| Grésille actuelle | 42 s | 65 s | **105 s** | **101 s** | **218 s** | hors cible dès l'étage 3 |
| Grésille R1+R2 (sec) | 39 s | 57 s | 87 s | 75 s | 162 s | comme Ardent, à 10-20 % près |
| Grésille R1+R2 (eau) | 29 s | 42 s | 63 s | 74 s | 159 s | |

## DPS par niveau et scénario

DPS effectif mesuré (ratio vs Ardent entre parenthèses) ; dernière colonne = moyenne géométrique des ratios L6, L12, L12m.

| Perso | Scénario | L1 | L6 | L12 | L12m | Ratio L6+ |
|---|---|---|---|---|---|---|
| Ardent | essaim | 122 (1,00) | 198 (1,00) | 311 (1,00) | 513 (1,00) | 1,00 |
| Ardent | mixte | 44 (1,00) | 108 (1,00) | 211 (1,00) | 369 (1,00) | 1,00 |
| Ardent | élite | 31 (1,00) | 79 (1,00) | 210 (1,00) | 343 (1,00) | 1,00 |
| Ardent | mini-boss | 34 (1,00) | 106 (1,00) | 248 (1,00) | 383 (1,00) | 1,00 |
| Tocsin | essaim | 140 (1,15) | 203 (1,03) | 275 (0,88) | 533 (1,04) | 0,98 |
| Tocsin | mixte | 47 (1,08) | 89 (0,82) | 177 (0,83) | 329 (0,88) | 0,84 |
| Tocsin | élite | 21 (0,68) | 59 (0,75) | 200 (0,96) | 343 (1,00) | 0,89 |
| Tocsin | mini-boss | 56 (1,65) | 399 (2,38) | 663 (1,92) | 475 (1,19) | **1,76** |
| Averse | essaim | 108 (0,88) | 198 (1,00) | 339 (1,09) | 759 (1,48) | 1,17 |
| Averse | mixte | 46 (1,06) | 111 (1,03) | 196 (0,93) | 353 (0,96) | 0,97 |
| Averse | élite | 30 (0,98) | 96 (1,22) | 232 (1,11) | 383 (1,12) | 1,15 |
| Averse | mini-boss | 41 (1,21) | 115 (1,10) | 209 (0,85) | 366 (0,95) | 0,96 |
| Vigie | essaim | 103 (0,84) | 184 (0,93) | 295 (0,95) | 720 (1,40) | 1,07 |
| Vigie | mixte | 47 (1,05) | 101 (0,95) | 185 (0,87) | 353 (0,95) | 0,92 |
| Vigie | élite | 33 (1,08) | 90 (1,15) | 221 (1,06) | 355 (1,04) | 1,08 |
| Vigie | mini-boss | 45 (1,33) | 102 (0,98) | 233 (0,95) | 350 (0,91) | 0,95 |
| **Grésille actuelle (sec)** | essaim | 80 (0,65) | 148 (0,74) | 268 (0,86) | 629 (1,23) | 0,92 |
| **Grésille actuelle (sec)** | mixte | 41 (0,94) | 99 (0,92) | 190 (0,90) | 386 (1,04) | 0,95 |
| **Grésille actuelle (sec)** | élite | 25 (0,80) | 66 (0,84) | 150 (0,72) | 247 (0,72) | **0,76** |
| **Grésille actuelle (sec)** | mini-boss | 33 (0,96) | 104 (1,00) | 152 (0,62) | 275 (0,72) | **0,76** |
| Grésille actuelle (eau partout) | essaim | 85 (0,70) | 166 (0,84) | 408 (1,31) | 751 (1,44) | 1,17 |
| Grésille actuelle (eau partout) | mixte | 47 (1,07) | 101 (0,95) | 191 (0,91) | 394 (1,06) | 0,97 |
| Grésille actuelle (eau partout) | élite | 26 (0,85) | 69 (0,88) | 163 (0,78) | 245 (0,72) | 0,79 |
| Grésille actuelle (eau partout) | mini-boss | 35 (1,03) | 104 (1,00) | 170 (0,69) | 280 (0,73) | 0,80 |
| Grésille R1+R2 (sec) | essaim | 81 (0,66) | 140 (0,71) | 262 (0,84) | 630 (1,23) | 0,90 |
| Grésille R1+R2 (sec) | mixte | 39 (0,90) | 102 (0,96) | 187 (0,88) | 408 (1,11) | 0,98 |
| Grésille R1+R2 (sec) | élite | 31 (1,00) | 89 (1,13) | 207 (0,99) | 374 (1,09) | 1,07 |
| Grésille R1+R2 (sec) | mini-boss | 36 (1,07) | 114 (1,09) | 184 (0,75) | 373 (0,97) | 0,93 |
| Grésille R1+R2 (bassin 12 × 12 u) | essaim | 83 (0,68) | 167 (0,84) | 348 (1,12) | 628 (1,22) | 1,05 |
| Grésille R1+R2 (bassin 12 × 12 u) | mixte | 46 (1,05) | 104 (0,98) | 190 (0,90) | 414 (1,12) | 1,00 |
| Grésille R1+R2 (bassin 12 × 12 u) | élite | 32 (1,03) | 89 (1,13) | 203 (0,98) | 386 (1,13) | 1,07 |
| Grésille R1+R2 (bassin 12 × 12 u) | mini-boss | 53 (1,55) | 151 (1,45) | 250 (1,02) | 387 (1,00) | 1,14 |
| Grésille R1+R2 (eau partout) | essaim | 85 (0,70) | 182 (0,91) | 374 (1,19) | 784 (1,52) | 1,18 |
| Grésille R1+R2 (eau partout) | mixte | 44 (1,01) | 107 (1,00) | 190 (0,90) | 417 (1,13) | 1,01 |
| Grésille R1+R2 (eau partout) | élite | 32 (1,04) | 93 (1,18) | 205 (0,99) | 370 (1,08) | 1,08 |
| Grésille R1+R2 (eau partout) | mini-boss | 49 (1,44) | 151 (1,45) | 253 (1,03) | 382 (0,99) | 1,14 |

Synthèse (L6+, moyenne géométrique) :

| Version | Global | Mono | Zone |
|---|---|---|---|
| Grésille actuelle, sec (Cité, Gouffre) | 0,84 | **0,76** | 0,94 |
| Grésille actuelle, eau partout (Cryptes, Source ; borne haute de la coop avec Averse) | 0,92 | 0,79 | 1,06 |
| Orage sans suspension (R1 seule), sec | 0,90 | 0,85 | 0,95 |
| Mise à la terre auto au contact (R2 seule), sec | 0,90 | 0,88 | 0,92 |
| **R1+R2, sec** | **0,97** | **1,00** | **0,94** |
| R1+R2, 3 graines, sec (contrôle de bruit) | 0,95 | 0,97 | 0,92 |
| **R1+R2, bassin** | 1,06 | 1,11 | 1,02 |
| **R1+R2, eau partout** | 1,10 | 1,11 | 1,09 |
| R1+R2 + immunité 2,5 s (R3), sec | 0,97 | 1,00 | 0,93 |
| R1+R2+R3, eau partout | 1,11 | 1,12 | 1,10 |

Variantes chiffrées écartées (mesurées) :

| Variante | Global | Mono | Zone | Lecture |
|---|---|---|---|---|
| Arc 0,8 → 0,9 seul | 0,87 | 0,81 | 0,93 | ne suffit pas sans R1+R2 |
| Décharge 2,8 → 3,3 seule | 0,86 | 0,80 | 0,93 | idem |
| R1 + Arc 0,9 | 0,93 | 0,91 | 0,95 | dans la bande, mais gonfle le début de run (mini-boss L1-L6 1,22-1,29) |
| R1 + R2 + Décharge 3,2 | 0,99 | 1,03 | 0,95 | élite à 1,18-1,19 en L6 et L12m, 1,15 en eau : au bord |
| R1 + R2 + Orage 1,5 (+R3) | 0,99 | 1,05 | 0,94 | n'améliore pas l'essaim (0,63-0,84) |
| R1 + R2 + Mise à la terre 0,55 (+R3) | 1,00 | 1,04 | 0,96 | idem |
| R1 + Arc 0,9 + cercle d'Orage 2,0 u | 0,93 | 0,91 | 0,95 | rayon sans effet mesurable sur l'essaim |
| R1 + Arc 0,9 + Mise à la terre 3,5 u | 0,93 | 0,91 | 0,95 | idem |

## Écarts entre personnages

- **Grésille actuelle** : mono 0,76, hors bande. Élite L12/L12m à 0,72, mini-boss L12 à 0,62 : les boss d'étage 3-5 seraient 35 à 40 % plus longs qu'avec Ardent.
- **Essaim T1 dispersé en début de run** : 0,65 (L1) et 0,74 (L6) à sec, 0,70 et 0,84-0,91 dans l'eau. Aucun levier chiffré testé (Arc, Orage 1,5, Mise à la terre 0,55, rayons +0,5 u, un rebond de plus) ne bouge ce chiffre de plus de 2 points : c'est structurel. Grésille n'a aucun sort qui fauche un paquet d'un coup à bas niveau (Orage 1,3 × 12 = 15,6 contre 18 PV de T1 ; Mise à la terre en 4 ticks), et sa Mise à la terre est bridée par la recharge (2 lancers par combat). L'écart se referme avec les objets de zone (L12m : 1,23 à sec, 1,52 dans l'eau). Le scénario mixte, plus proche des paquets de 3-8 visés, reste à 0,90-1,05.
- **Dépendance à l'eau** : après R1+R2, global 0,97 à sec contre 1,10 dans l'eau, soit +13 %. Grésille reste **viable dans la Cité et le Gouffre** ; l'asymétrie est du même ordre que celle d'Averse. L'eau ne change presque rien au mono contre une élite (1,07 → 1,08) : elle agit par la portée des arcs et la nappe de Mise à la terre, comme le veut la fiche (§6, pas de bonus direct sur mouillé).
- **Mini-boss dans l'eau en début de run** : 1,44-1,55 en L1-L6 (sec : 1,07-1,09). La cause est mesurée : sur l'eau, la nappe de Mise à la terre (113 cases, rayon 6 u) garde le mini-boss dedans pendant 5 s (13-17 % des dégâts) et le ralentit, alors que le disque de 3 u à sec ne le tient jamais (0 %). Elle ne prend alors **aucun dégât** (L6, L12). C'est hors bande, mais seulement quand le combat a lieu dans un bassin ; à surveiller avec le journal de run.
- **Hors périmètre, relevé au passage** : Tocsin contre le mini-boss à 1,76 × Ardent (2,38 en L6). À traiter dans un audit Tocsin.

## Valeurs aberrantes

| Constante / règle | Plage cible | Actuel | Problème |
|---|---|---|---|
| `GresilleKit.blocks_slot(1)` pendant l'Orage | l'ultime doit rester un gain net | sort 1 suspendu 3 s | Valeur nette de l'Orage en mono = 7,8 − 3 × Arc/s. Elle vaut +3,8 coef sans objet, +2,0 avec 3 Sifflets (+45 % de vitesse d'attaque), ≈ 0 à +95 %, **−4,2 au plafond de +200 %**, et pire avec la Lame jumelle (−7,2 avec +25 % au sort 1). En paquet, avec le rebond, l'Orage coûte 6,2 à 28 coef de sort 1. Les objets du sort 1 rendent l'ultime négatif : c'est une option piège (Sirlin). |
| `GresilleKit.auto_cast_ok(3)` | le mode « sorts automatiques » (mobile) doit jouer tout le kit | lancé seulement si ≥ 3 monstres à 3 u | Jamais lancé contre une élite ou un boss seul : 0 % des dégâts en mono, alors qu'Ardent tire 12-28 % de son sort 3. |
| Foudroiement d'une élite (`ZAP_IMMUNE_S` 1,5) | contrôle de roster : Grand saut de Rainette 7-14 %, Rançon d'Avare ≈ 6 % | 15 % (sec, sans objet) à **31 %** (eau, Mise à la terre ou vitesse d'attaque) du temps étourdie | Le contrôle le plus fort du roster sur les élites, sans retour de diminution côté `Enemy`. |

## Stratégies dégénérées

- **Étourdissement en chaîne des élites** : en solo, le cycle « 5 cumuls → foudroyée 0,5 s → immunité 1,5 s » plafonne à 31 % d'étourdissement (période 1,6 s dès que les cumuls se reconstruisent plus vite que l'immunité : eau, Mise à la terre ou Arc à 0,2 s). L'élite T3 mesurée ne lui inflige plus aucun dégât après R1+R2. Fort mais non absolu en solo. Les **mini-boss et boss ne sont jamais étourdis** (`Enemy.stun` ignore `is_boss`, qui est vrai pour les mini-boss) : pas de verrou de boss.
- **Coop à plusieurs Grésille** : chaque kit a son propre registre (`GresilleStatic`) et sa propre immunité, et `Enemy.stun` n'a aucune immunité partagée. Deux Grésille donnent jusqu'à environ 60 % d'étourdissement sur une élite, quatre la verrouillent presque en permanence (estimé). Même cumul avec la Rançon d'Avare ou le Grand saut de Rainette. **Contre-jeu absent.**
- **Orage + mouillé** : pas de dérive. Dans l'eau, l'Orage dépose 2 cumuls par coup, mais l'immunité limite à 2 foudroiements par monstre et par Orage, et le bonus de coefficient plafonne à +25 %. Essaim L12m dans l'eau : 1,44-1,52, comme Averse (1,48) et Vigie (1,40) à sec.
- **Éclair en bouteille ×N qui foudroie en boucle** : **impossible dans le code actuel**. La foudre en chaîne passe par `take_damage` direct (`SpellCaster._lightning`), pas par `deal_damage` : elle ne déclenche ni `on_spell_hit` (donc aucune Statique, aucun Foudroiement), ni de nouveau proc. Gain mesuré de 3 Éclairs : +3 % pour Grésille, contre +6 % pour Ardent (sa Nova à proc 1,0 touche plus de monstres). Contre une cible seule, la chaîne n'a personne à toucher. L'objet « de lore » de Grésille est donc un objet moyen pour elle : le ressenti risque de décevoir, mais il n'y a pas de dérive.
- **Pointe perforante** : un rebond de plus par exemplaire (plafond 5 via `PIERCE_CAP`) ; gain mesuré +1 % avec un exemplaire. Au plafond, un Arc fait 0,8 + 6 × 0,45 = 3,5 coef sur 7 monstres, comparable au Trait perforant de Vigie : pas de dérive.
- **Cœur de glace** : « crispé » (≥ 3 cumuls) et la Mise à la terre comptent comme ralentis, y compris sur les boss (`apply_status slow` ne filtre pas `is_boss`). Gain mesuré avec un exemplaire : mono +18 à +31 % (moyenne +12 % tous scénarios) ; avec cinq : +40 à +53 % en mono. C'est du même ordre qu'Averse (+22 %) et Vigie (+15 %) avec un exemplaire. Ardent n'y gagne rien (0 %) : le problème est l'objet (mort pour les kits sans ralentissement), pas Grésille.
- **Horloge arcanique / Sablier au plancher** (`COOLDOWN_FLOOR` 0,35) : Décharge à 2,45 s, Orage à 7,7 s. Avec la suspension actuelle, Grésille passerait 39 % du temps sans sort 1 : la hâte se retournerait contre elle. Après R1, plus de perte.

## Recommandations chiffrées

| Priorité | Constante `Balance` / kit / clé | Actuel → proposé | Plage sûre | Effet attendu (mesuré sauf mention) |
|---|---|---|---|---|
| **R1** (Recommandé) | `GresilleKit.blocks_slot(1)` pendant la canalisation de l'Orage | vrai → **faux** (garder `blocks_slot(4)` et `STORM_SPEED_U` 2,9) | — (règle) | Mono 0,76 → 0,85 ; global 0,84 → 0,90. L'Orage redevient un gain net quelle que soit la vitesse d'attaque ; la Lame jumelle et le Sifflet ne le pénalisent plus. Mettre à jour la fiche §4.4 (« la tige levée » devient un état d'animation, plus une suspension). |
| **R2** (Recommandé) | `GresilleKit.auto_cast_ok(3)` | « ≥ 3 monstres à 3 u » → « ≥ 3 monstres à 3 u **ou** une élite ou un boss à ≤ `GROUND_RADIUS_U` » | — (règle) | Avec R1 : mono 1,00, global 0,97 à sec ; boss d'étage 3-4 estimés à 75-87 s au lieu de 101-105 s. Concerne le mode « sorts automatiques » (mobile, accessibilité) et le simulateur ; en jeu manuel, le joueur pouvait déjà la lancer. |
| **R3** (Recommandé) | `GresilleStatic.ZAP_IMMUNE_S` | 1,5 → **2,5** s | 2,0-3,0 | Pire cas d'étourdissement d'une élite 31 % → 19 % ; cycle sec sans objet (15 %) inchangé. DPS mesuré neutre (global 0,97 → 0,97 ; 1,10 → 1,11 dans l'eau). L'Orage foudroie alors au plus 2 fois un monstre (coups 1 et 6). |
| **R4** (contrat, orchestrateur) | nouvelle constante `Balance.ELITE_STUN_REARM_S`, lue par `Enemy.stun` | absent → **1,5** s : une élite (non boss) qui sort d'un étourdissement ignore tout nouvel étourdissement pendant 1,5 s, toutes sources confondues | 1,0-2,5 | Empêche le verrou à plusieurs Grésille en coop, ainsi que les cumuls Grésille + Avare + Rainette : au plus environ 25 % d'étourdissement sur une élite, quel que soit le nombre de sources (estimé). Aucun effet en solo avec R3. |
| **R5** (perf mobile) | `GresilleKit._nearest_neighbor`, `_tick_wake`, `_refresh_crisp` | — | — | (a) Calculer la distance d'abord et n'appeler `is_wet` que si `BOUNCE_U` < d ≤ `BOUNCE_U` + `WET_BONUS_U` : aujourd'hui, chaque arc peut appeler `is_wet` (donc `StageMap.water_context`, qui fait un `get_first_node_in_group` et une inversion de transform) sur jusqu'à 250 monstres, et ce jusqu'à 6 rebonds et 5 arcs de Décharge par lancer, soit jusqu'à environ 7 500 appels par seconde au plafond de vitesse d'attaque (estimé). (b) Sillage : échantillonner la traînée toutes les 0,05 s (nouvelle constante `WAKE_SAMPLE_S` 0,05) au lieu de chaque image, soit environ 250 × 30 tests de distance par image pendant 0,5 s. (c) Plafonner les `StatusFx.shock` du crispé (pool de 60 prévu par la fiche §11). |
| R6 (à surveiller, ne pas appliquer tout de suite) | `GresilleKit.GROUND_WATER_CELLS_MAX` | 113 (rayon 6 u) → **80** (rayon ≈ 5 u) **si** le journal de run montre des mini-boss tués en moins de 0,8 × la durée d'Ardent sur les Terrasses et aux Cryptes | 80-113 | Mini-boss L1-L6 dans l'eau 1,44-1,55 × Ardent mesuré sur une arène entièrement en eau, ce qui est une borne haute. Une nappe plus petite le tiendrait moins longtemps (estimé : vers 1,25-1,30). |

Valeurs à **ne pas** toucher, d'après les mesures : `ARC_COEF` 0,8, `BOUNCE_COEF` 0,45, `DISCHARGE_COEF` 2,8, `STORM_COEF` 1,3, `GROUND_COEF` 0,45. Après R1+R2, chacun des relèvements testés pousse l'élite ou le mini-boss du début de run au bord de 1,20 sans corriger l'essaim.

## Valeurs sans plage cible (non jugées)

- `STATIC_S` 6 s, `CRISP_AT` 3, `CRISP_SLOW` 0,2, `WET_STACKS` 2, `WET_BONUS_U` 2.
- `ZAP_BOSS_MULT` 1,1 pendant 2 s : environ 55 % de temps actif à sec et 80 % dans l'eau sur un boss, soit +5 à +8 % ; aucune cible écrite.
- `ISOLEE_MULT` 0,5 : la fiche (§6) promet aussi « aucun ralentissement » dans les flaques électrisées des mini-boss ; le kit ne le fait pas (commentaire : pas de contrat côté joueur). Écart entre la fiche et le code, à trancher, sans effet mesurable dans le simulateur.
- PV 95 + 28/niv, armure 5, vitesse 4,1 u/s : dégâts subis mesurés du même ordre qu'Ardent (mixte L1 : 68 contre 60 ; mini-boss L1 : 92 contre 97, une mort chacun).

## Limites (mesuré / estimé / non vérifié)

- **Mesuré** : tous les tableaux de DPS, de durées et de dégâts subis (simulateur `balance_sim`, bot en lancer automatique, arène plate, 2 graines, 3 pour le contrôle R1+R2). Les variantes R1, R2, R3 et les coefficients modifiés sont mesurés en jeu sur des sous-classes temporaires du kit, hors dépôt.
- **Estimé** : TTK des boss d'étage (table d'Ardent du 23/10, antérieure à plusieurs réglages) ; cycles d'étourdissement (calcul) ; coop à plusieurs Grésille et avec Averse (le simulateur est solo ; « eau partout » sert de borne haute pour la coop avec Averse, qui trempe rarement tout le paquet) ; coût CPU de `is_wet`.
- **Non vérifié** : vraies cartes (proportion d'eau réelle des Terrasses et des Cryptes, nappes coupées par les murs) ; jeu manuel (visée de la Décharge au curseur, Court-circuit à travers le paquet, Orage lancé depuis la Mise à la terre) ; boss d'étage réels et leurs phases ; mobile réel (banc de perf).
- Le bot garde ses distances et lance tout à la recharge : il sous-estime la Mise à la terre en jeu manuel et ne fait jamais le combo GR-2 volontairement.
- Le simulateur v3 (`docs/simulateur_scaling.py`) diverge de `balance.gd` (run de 10 min, niveau 19 à 10 min) : il n'a pas servi.

## Protocole de vérification en mode test (après application)

1. Mode test, Grésille, D réglée à environ 2,5, objets : 3 Sifflets de chasse et 1 Lame jumelle. Invoquer une élite T3. Lancer l'Orage : les Arcs doivent continuer pendant les 3 s de canalisation (R1).
2. « Sorts automatiques » activé, laisser l'élite venir au contact : la Mise à la terre doit partir seule (R2).
3. Compter les étoiles d'étourdissement sur l'élite dans l'eau (onglet Cartes, Terrasses ou Cryptes, nappe sous Grésille) : pas plus d'un étourdissement toutes les 3 s environ (R3).
4. Banc de perf, Terrasses, palier Haut, 250 monstres, Grésille avec 5 Pointes perforantes et 3 Sifflets : comparer le temps d'image avant et après R5.
