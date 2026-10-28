# Audit des PV des boss (28/10/2026)

Consultant : systems-designer (skill `balance-check`, mode « boss » puis vue d'ensemble). Suite de `docs/Audit_Items_2026-10-28.md` §6 : même après la correction des objets, le temps pour tuer (TTK) des boss d'étage baisse d'étage en étage, alors que la cible est stable. Les objets sont pris **après correction** (hâte additive, plancher de recharge 0,35, Cœur de glace [0,35 ; 0,15] plafond 0,95, Œil 0,08 + [0,40 ; 0,25] plafond 1,5, Rafale 0,15 tous les 5 tirs, Venin 1,5, Danseur [0,35 ; 0,20]) : ces valeurs sont déjà dans `game/data/items.json` et `balance.gd` au moment de l'audit.

Aucun fichier du jeu n'est modifié par ce document. Les dégâts des boss ne sont pas touchés.

---

## 0. Sources et données

| Entrée | Statut | Où |
|---|---|---|
| Formule des PV de boss | TROUVÉ | `balance.gd` `boss_hp()` : `BOSS_BASE_HP[kind] × (1 + 0,3 (niv − 1)) × √D × BOSS_STAGE_K^(étage − 1)` |
| Bases et constantes | TROUVÉ | `BOSS_BASE_HP` mini 1000 / étage 3000, `BOSS_STAGE_K` 0,95, `BOSS_HP_MULT` raid 0,9, `BOSS_SHIELDS`, `BOSS_SHIELD_*`, `RAID_*`, `BOSS_PHASE_DAMAGE_TAKEN`, `BOSS_ENRAGE_AFTER_S` 90 |
| Difficulté et modes | TROUVÉ | `difficulty()` : `(1 + min × 0,0506 × d × 1,5) × 1,15^(étage − 1)`, `MODES` Facile 1 / Moyen 2 / Difficile 3 ; niveau ambiant `1 + ⌊(D − 1)/0,33⌋` |
| Boss final | TROUVÉ | `floors.json` `draw_rules_override.final_boss_hp_mult` 2,0 (lu par `StageManager._final_hp_mult`, appliqué par `Pillar.setup_final`) |
| Mécaniques de raid | TROUVÉ | `Design_Boss_Raid.md` §0-2, cerveaux `drowned_idol_brain.gd`, `flood_gunner_brain.gd`, `salt_king_brain.gd`, `raid/boss_shield.gd`, `raid/priority_adds.gd` |
| Défenses des mini-boss | TROUVÉ | `minibosses.json` (`front_guard`, `flat_guard`, `summon_guard`, `far_guard`, `summon_regen`, `dry_vuln`, `dissolve`) |
| Durée de charge du gros pilier | TROUVÉ | `pillar.gd` `CHARGE_TIME` = 90 s (constante dans le script, hors `Balance`) |
| Cibles de TTK | TROUVÉ (partiel) | Maths §14 : mini-boss 21-30 s, boss d'étage 65-75 s ; Design_Boss_Raid règle 5 et §4 : ≈ 75 s, 75-90 s pour les boss à boucliers ; Design_Etages §4 : boss final 75-100 s |
| DPS du joueur par étage | ESTIMÉ | modèle analytique d'Ardent de l'audit des objets, recalé sur `balance_sim` (voir §1.3) |
| Coups reçus par seconde en combat de boss | PARTIEL | `boss_pressure_test` (Design_Boss_Raid §2.1-2.3) mesure des coups par 60 s, coefficients mélangés : utilisé en relatif seulement |
| Durée réelle des étages en jeu | ABSENT | pas de télémétrie ; chronologie reconstituée (§1.2) |

Commandes lancées :
- `balance_sim_run.tscn -- --chars=ardent,vigie,tocsin,averse --scen=miniboss,elite --cfg=L6,L12` (objets corrigés) : `RESULT: OK`.
- Modèle Python ad hoc (scratchpad) : PV par étage, mode et catégorie, TTK, exposition.
- `docs/simulateur_scaling.py moyen` : **non utilisé pour conclure**. Il garde le modèle v3 (3 étages, D en 0,30 × mode, PV en D^1,6) et ne correspond plus à `balance.gd` §14.

## 1. Méthode

### 1.1 Formule en vigueur

```
PV_boss(kind, D, s) = BOSS_BASE_HP[kind] × (1 + 0,3 × (niv(D) − 1)) × √D × BOSS_STAGE_K^(s − 1)
PV_raid = PV_boss(étage) × BOSS_HP_MULT (0,9)
PV_final = PV_boss(étage, D, 5) × final_boss_hp_mult (2,0)
```

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| kind | énum | mini, etage | catégorie |
| D | réel | 1 à ~9 (fin d'étage 5 en Difficile) | coefficient de difficulté |
| niv(D) | entier | 1 à ~25 | niveau ambiant des monstres |
| s | entier | 1 à 5 (sans fin : 6+) | étage |
| BOSS_STAGE_K | réel | actuel 0,95 | facteur par étage |

Sortie : croissante en D, **décroissante en s** (×0,81 à l'étage 5). Bornée inférieurement par la base ; pas de valeur inutilisable.

Le commentaire de `balance.gd` dit que `BOSS_STAGE_K` « compense les ~10 objets par étage » ; avec 0,95 il fait l'inverse : il **retire** 5 % de PV par étage alors que le joueur gagne environ 10 objets par étage. C'est la cause principale de l'écart.

### 1.2 Chronologie retenue (Moyen ; Facile ×0,97, Difficile ×1,06)

Run de 5 étages ≈ 18-20 min (CLAUDE.md), ≈ 3,8 min par étage : début d'étage 0 / 3,8 / 7,6 / 11,4 / 15,2 min ; mini-boss A à +0,75 min, mini-boss B à +1,4 min, boss d'étage à +2,2 min ; boss final à 16,45 min (60-90 s de liberté à la Source).

Niveau du joueur : 6 au boss de l'étage 1, 10 / 13 / 15 aux boss des étages 2-4, 17 au final (Maths §14 : niveau ≈ 7,5 en fin d'étage 1).

### 1.3 DPS du joueur

- **Build moyen** (Ardent, objets offensifs ≈ 55 % des objets) : Pierres, Lentilles, Sabliers, Sifflets, Horloges, Lames, puis Rune, Carquois, Danseur (8 min), Marque (12 min), Chronomètre (13 min), aux rythmes de l'audit des objets.
- **Build fort (75e centile)** : 20 % d'objets offensifs en plus, Rafale d'acier dès l'étage 2, Œil du prédateur dès l'étage 3.
- **Recalage** : le modèle sous-estime `balance_sim` de 10 % en moyenne (Ardent, Vigie, Tocsin, Averse ; L6 et L12) → ×1,1.
- **Temps utile sur la cible** dans un vrai combat (boss qui bouge, esquives, transitions) : ×0,8 (hypothèse, non mesurée).

DPS réel = DPS modèle × 1,1 × 0,8.

Mesure `balance_sim` (mini-boss frost_bear, sans défense ; L6 = Moyen 6 min étage 1, D 1,91 ; L12 = Difficile étage 3 4 min, D 2,53 ; PV 2 212 et 3 156) :

| Personnage | L6 TTK | L6 DPS | L12 TTK | L12 DPS | Dégâts subis L12 |
|---|---|---|---|---|---|
| Ardent | 19,2 s | 115 | 12,1 s | 262 | 130 (25 % PV) |
| Vigie | 19,7 s | 112 | 15,0 s | 210 | 72 |
| Tocsin | 21,7 s | 102 | 12,2 s | 259 | 31 |
| Averse | 21,9 s | 101 | 16,6 s | 190 | 189 |

Écart de DPS entre personnages : −27 % (Averse) à 0 % autour d'Ardent en L12 ; Averse est sous la marge de ±20 % (hors sujet ici, signalé).

### 1.4 PV effectifs : facteurs retenus

| Catégorie | Facteur sur les PV | Temps sans dégâts utiles | Détail |
|---|---|---|---|
| Mini-boss | ×1,02 (étage 1), ×1,17 (2), ×1,03 (3), ×1,06 (4) | 0 | Moyenne des défenses par biome : Colosse `flat_guard` 0,7 (~70 % du temps) ; Chouette `far_guard` 0,7 (distance) ; Mante `front_guard` 0,6 ; Mère-couvée et Porteur d'ossuaire `summon_guard` 0,65 ; Reine des ronces régén 1 %/s avec ses invocations ; Archonte et Crabe `front_guard` retirée en phase 2 ; Crapaud `dry_vuln` 1,3 et Golem de sel `dissolve` 2 %/s (en faveur du joueur) |
| Boss d'étage classique | ×0,97 | 2 s | Phases à +20-25 % de dégâts reçus (Sonneur, Fondeur, Anguille P3, Cèdre P2, Bouvier embourbé) ; Anguille plongée ×0,3 et Tisseuse suspendue ×0 compensent en partie |
| Idole noyée | ×0,9 × 0,942 | +16,7 s | 2 boucliers ORBS (transition 0,9 + mise en place 1,2 + ≈ 7 s de cloches) ; fenêtres 2,5 s × 1,3 (−1,5 s) ; P3 +20 % |
| Canonnier de crue | ×0,9 × 0,942 + soutiers | +4,4 s | Soutiers 2 × 7 % + 3 × 6 % = 32 % des PV du boss, comptés à moitié (zones) ; transitions ; fenêtres 3 s × 1,3 ; P3 +20 % ; soins si un soutier arrive (10 %, plafond 20 %) non comptés |
| Roi de sel | ×0,9 × (0,942 − 0,05) | +12,1 s | 2 boucliers ULTIMATE_HIT (transition + ≈ 5 s d'attente de l'ultime) ; couronne (5 % des PV, ×2 transférés : −5 %) ; fenêtres 3 s × 1,35 ; P3 +20 % |
| Boss final (Semeur) | ×2,0 × 0,942 | 3 s | 2 transitions de 1,5 s ; P3 ancré +20 % |

Soins de raid (garde-fou 45 s : +10 % des PV max ; soutier arrivé : +10 %, plafond 20 % par bouclier) : **non comptés** dans le cas moyen (le joueur actif les évite). Pire cas : +10 à +30 % de PV effectifs sur le Canonnier, +10 % par bouclier raté sur l'Idole et le Roi.

## 2. PV effectifs à l'heure d'arrivée (formule actuelle)

### 2.1 Moyen

| Combat | Arrivée | D | Niv. amb. | PV max | PV effectifs | Temps sans dégâts |
|---|---|---|---|---|---|---|
| Mini E1 (A / B) | 0:45 / 1:24 | 1,11 / 1,21 | 1 | 1 055 / 1 101 | 1 076 / 1 123 | 0 |
| Boss E1 | 2:12 | 1,33 | 2 | 4 504 | 4 369 | 2 s |
| Idole noyée (E1) | 2:12 | 1,33 | 2 | 4 054 | 3 819 | 16,7 s |
| Mini E2 | 4:33 / 5:12 | 1,94 / 2,06 | 3 / 4 | 2 119 / 2 589 | 2 480 / 3 029 | 0 |
| Boss E2 | 6:00 | 2,20 | 4 | 8 027 | 7 786 | 2 s |
| Mini E3 | 8:21 / 9:00 | 3,00 / 3,13 | 7 | 4 376 / 4 470 | 4 507 / 4 604 | 0 |
| Boss E3 | 9:48 | 3,29 | 7 | 13 750 | 13 338 | 2 s |
| Canonnier (E3) | 9:48 | 3,29 | 7 | 12 375 | 13 638 | 4,4 s |
| Mini E4 | 12:09 / 12:48 | 4,33 / 4,48 | 11 | 7 133 / 7 256 | 7 561 / 7 691 | 0 |
| Boss E4 | 13:36 | 4,66 | 12 | 23 877 | 23 161 | 2 s |
| Roi de sel (E4) | 13:36 | 4,66 | 12 | 21 490 | 19 169 | 12,1 s |
| Semeur (final) | 16:27 | 6,12 | 16 | 66 475 | 62 619 | 3 s |

### 2.2 Facile et Difficile (boss d'étage et final)

| Combat | Facile D | Facile PV | Difficile D | Difficile PV |
|---|---|---|---|---|
| Mini E1 / E2 / E3 / E4 (B) | 1,10 / 1,59 / 2,20 / 2,95 | 1 050 / 1 557 / 2 543 / 3 684 | 1,34 / 2,59 / 4,20 / 6,22 | 1 504 / 3 366 / 6 840 / 11 760 |
| Boss E1 | 1,16 | 3 234 | 1,53 | 4 826 |
| Boss E2 | 1,66 | 4 771 | 2,82 | 11 955 |
| Boss E3 | 2,28 | 7 762 | 4,45 | 22 848 |
| Boss E4 | 3,04 | 12 565 | 6,51 | 38 073 |
| Final | 3,87 | 32 676 | 8,69 | 113 832 |

Entre le boss de l'étage 1 et celui de l'étage 4 (Moyen), les PV sont multipliés par **5,3** ; le DPS réel du build moyen par **10,3** (72 → 740). Le joueur double donc l'avance sur les boss en 3 étages.

## 3. TTK actuel contre les cibles

Cibles : Maths §14 (mini-boss 21-30 s, boss d'étage 65-75 s), Design_Boss_Raid (boss à boucliers 75-90 s en Moyen, temps sous bouclier compris), Design_Etages §4 (final 75-100 s). **Proposition** pour le final : **100-130 s** en Moyen (3 phases, climax d'une run de 20 min ; 3 min serait plus long que deux boss d'étage cumulés et expose le joueur à l'enrage pendant 90 s).

TTK = moyen / fort (75e centile), Moyen, formule actuelle :

| Combat | Moyen | Fort | Cible | Écart (build moyen) |
|---|---|---|---|---|
| Mini E1 A / B | 26 / 24 s | 26 / 24 s | 21-30 s | conforme |
| Mini E2 A / B | 21 / 24 s | 21 / 20 s | 21-30 s | conforme (limite) |
| Mini E3 A / B | 15 / 15 s | 10 / 10 s | 21-30 s | **−30 %** |
| Mini E4 A / B | 16 / 13 s | 8 / 8 s | 21-30 s | **−45 %** |
| Boss E1 | 63 s | 50 s | 65-75 s | −3 % |
| Boss E2 | 50 s | 39 s | 65-75 s | **−23 %** |
| Boss E3 | 37 s | 28 s | 65-75 s | **−43 %** |
| Boss E4 | 33 s | 23 s | 65-75 s | **−49 %** |
| Idole (E1) | 70 s | 59 s | 75-90 s | −7 % |
| Canonnier (E3) | 41 s | 31 s | 75-90 s | **−46 %** |
| Roi de sel (E4) | 38 s | 30 s | 75-90 s | **−49 %** |
| Final | 64 s | 38 s | 100-130 s (75-100 doc) | **−36 %** |

Facile : boss d'étage 46 / 30 / 22 / 18 s, final 33 s. Difficile : 67 / 73 / 61 / 49 s, final 107 s.

Conséquence de jeu : la charge du gros pilier dure 90 s (`pillar.gd` `CHARGE_TIME`) ; aux étages 3 et 4, le boss meurt à 33-37 s et le joueur attend ensuite **plus de 50 s** dans la zone sans adversaire principal. La cible de 65-75 s n'est pas arbitraire : c'est le temps de charge moins la marge d'arrivée.

### Verdict : À SURVEILLER (proche de critique)

Pas de stratégie dégénérée ni de mort sans télégraphe, mais la progression des boss est inversée par rapport à l'intention (§11 Maths : ratio puissance/pression ≈ 1,0-1,2 au boss d'étage ; mesuré ≈ 2 au boss de l'étage 4). Corrigeable par réglage.

## 4. Options

### Option A : facteur d'étage croissant (Recommandé)

`BOSS_STAGE_K` 0,95 → **1,20**, `BOSS_BASE_HP[&"etage"]` 3000 → **3300**, `BOSS_BASE_HP[&"mini"]` 1000 inchangé, `final_boss_hp_mult` 2,0 → **1,2**.

Fondement : le joueur gagne ≈ 10 objets par étage **quel que soit le mode** ; le compensateur doit donc dépendre de l'étage, pas de D. Rapport de DPS mesuré par le modèle entre deux boss d'étage consécutifs : ×2,26, ×2,32, ×1,96 ; rapport de PV de la formule actuelle : ×1,78, ×1,71, ×1,74 (dont ×0,95). Le manque par étage vaut ×1,27, ×1,36, ×1,13, soit un facteur géométrique ≈ 1,20 (balayage 1,15-1,25 en §8). Le même facteur convient aux mini-boss (même dérive), donc une seule constante suffit.

Effet TTK (Moyen, build moyen) : boss d'étage 69 / 68 / 64 / 71 s (au lieu de 63 / 50 / 37 / 33) ; mini-boss 23-31 s partout ; raids 75 / 68 / 70 s ; final 105 s.
Durée d'étage : le boss d'étage tient dans la charge de 90 s (pas d'allongement des étages 3-4 ; +8 s à l'étage 2). Mini-boss : +5 à +15 s par combat aux étages 2-4. Run : ≈ +1,7 min en Moyen (dont +41 s au final). Or et XP : primes de boss inchangées (fonction de D seulement) ; quelques kills de plus dans les zones de mini-boss (crédits ×1,5).
Sans fin : K^(s − 1) continue de monter (étage 6 : ×2,49 ; étage 10 : ×5,16). Voulu : le sans fin doit finir la run (ratio < 0,8, Maths §11).

### Option B : exposant de D plus fort (√D → D¹)

`boss_hp` en `D^1,0` et `BOSS_STAGE_K` = 1,0. Moyen correct (73 / 76 / 73 / 81 s), mais l'effet dépend du mode : Facile 49 / 40 / 35 / 36 s (le Facile retombe), Difficile 83 / 127 / 139 / 143 s, final Moyen 236 s, Difficile 410 s. Écarté : D monte plus vite en Difficile alors que les objets arrivent au même rythme ; on amplifierait l'écart entre modes au lieu de suivre le joueur.

### Option C : PV indexés sur le nombre d'objets du joueur

`PV × (1 + c × N_objets)`. Suit le joueur automatiquement (y compris le farm), mais : élastique qui punit la collecte (chaque coffre rend le boss plus solide, Sirlin : le choix du joueur est annulé), invisible et contre-intuitif, et les tests en mode test dépendraient de l'inventaire. RoR2 ne le fait pas (temps et étage seulement). Écarté.

### Option D : table par étage

`BOSS_STAGE_HP_MULT := [1,0 ; 1,26 ; 1,60 ; 2,02 ; 2,42]` (même effet que A aux étages 1-5), lue à la place de `BOSS_STAGE_K^(s − 1)`. Avantage : réglage fin d'un étage sans toucher les autres (utile si la télémétrie montre un étage 3 à part). Inconvénient : une table de plus, et il faut définir le sans fin (dernière valeur × K au-delà). À garder pour un second réglage, pas nécessaire maintenant.

## 5. Recommandation (Recommandé : option A)

| Constante / clé | Actuel | Proposé | Plage sûre | Effet |
|---|---|---|---|---|
| `Balance.BOSS_STAGE_K` | 0,95 | **1,20** | 1,15-1,25 | TTK stable d'un étage à l'autre (boss, raids, mini-boss) |
| `Balance.BOSS_BASE_HP[&"etage"]` | 3000 | **3300** | 3000-3600 | boss E1 63 → 69 s (Moyen) |
| `Balance.BOSS_BASE_HP[&"mini"]` | 1000 | 1000 | 900-1100 | inchangé (mini E1 24-26 s, conforme) |
| `floors.json` `final_boss_hp_mult` | 2,0 | **1,2** | 1,0-1,5 | final 64 → 105 s ; garder 2,0 avec K = 1,2 donnerait 175 s en Moyen et ≈ 5 min en Difficile |
| `Balance.BOSS_HP_MULT` (raids) | 0,9 | 0,9 | 0,85-0,95 | inchangé : les boucliers ajoutent déjà 4-17 s |
| Dégâts (`BOSS_BASE_DMG`, `BOSS_ATTACK_COEF`, `RAID_*_COEF`) | — | inchangés | — | demande du joueur |

### 5.1 PV avant → après, Moyen

| Combat | D | PV avant | PV après | × |
|---|---|---|---|---|
| Mini E1 A / B | 1,11 / 1,21 | 1 055 / 1 101 | 1 055 / 1 101 | 1,00 |
| Boss E1 | 1,33 | 4 504 | 4 955 | 1,10 |
| Idole (E1) | 1,33 | 4 054 | 4 459 | 1,10 |
| Mini E2 A / B | 1,94 / 2,06 | 2 119 / 2 589 | 2 677 / 3 271 | 1,26 |
| Boss E2 | 2,20 | 8 027 | 11 153 | 1,39 |
| Mini E3 A / B | 3,00 / 3,13 | 4 376 / 4 470 | 6 982 / 7 133 | 1,60 |
| Boss E3 | 3,29 | 13 750 | 24 134 | 1,76 |
| Canonnier (E3) | 3,29 | 12 375 | 21 720 | 1,76 |
| Mini E4 A / B | 4,33 / 4,48 | 7 133 / 7 256 | 14 376 / 14 623 | 2,02 |
| Boss E4 | 4,66 | 23 877 | 52 936 | 2,22 |
| Roi de sel (E4) | 4,66 | 21 490 | 47 642 | 2,22 |
| Final | 6,12 | 66 475 | 111 695 | 1,68 |

Facile, boss d'étage 1-4 / final : 3 234 / 4 771 / 7 762 / 12 565 / 32 676 → 3 557 / 6 629 / 13 623 / 27 856 / 54 903.
Difficile : 4 826 / 11 955 / 22 848 / 38 073 / 113 832 → 5 308 / 16 611 / 40 100 / 84 408 / 191 267.

### 5.2 TTK avant → après (build moyen / build fort)

Moyen :

| Combat | Avant | Après | Cible |
|---|---|---|---|
| Mini E1 A / B | 26 / 24 s | 26 / 24 s | 21-30 s |
| Mini E2 A / B | 21 / 24 s (fort 21 / 20) | 26 / 30 s (fort 26 / 25) | 21-30 s |
| Mini E3 A / B | 15 / 15 s (fort 10 / 10) | 23 / 24 s (fort 16 / 17) | 21-30 s |
| Mini E4 A / B | 16 / 13 s (fort 8 / 8) | 31 / 26 s (fort 16 / 16) | 21-30 s |
| Boss E1 | 63 s (fort 50) | 69 s (fort 55) | 65-75 s |
| Boss E2 | 50 s (fort 39) | 68 s (fort 54) | 65-75 s |
| Boss E3 | 37 s (fort 28) | 64 s (fort 48) | 65-75 s |
| Boss E4 | 33 s (fort 23) | 71 s (fort 49) | 65-75 s |
| Idole (E1) | 70 s (fort 59) | 75 s (fort 63) | 75-90 s |
| Canonnier (E3) | 41 s (fort 31) | 68 s (fort 51) | 75-90 s |
| Roi de sel (E4) | 38 s (fort 30) | 70 s (fort 51) | 75-90 s |
| Final | 64 s (fort 38) | 105 s (fort 62) | 100-130 s |

Le build fort tue 20-30 % plus vite que le moyen : la récompense d'un bon build reste visible, sans retomber sous 45 s.

Facile (après) : mini-boss 19-25 s, boss d'étage 50 / 41 / 37 / 39 s, raids 59 / 40 / 42 s, final 53 s.
Difficile (après) : mini-boss 27-41 s, boss d'étage 74 / 101 / 105 / 107 s, raids 80 / 110 / 99 s, final 178 s.

Les raids restent un peu sous 75-90 s aux étages 3-4 (68-70 s) : c'est voulu, la pression de leurs mécaniques est déjà élevée (v2 du 27/10). Si le joueur veut les rallonger, monter `BOSS_HP_MULT` de ces deux boss à 1,0 (+11 %) plutôt que toucher K.

## 6. Mortalité : effet d'un combat plus long

Les dégâts reçus d'un boss sont proportionnels au temps passé contre lui (cadence de coups fixée par `BOSS_PRESSURE` et `BossPace`, dégâts inchangés). Exposition après / avant (Moyen, build moyen) :

| Combat | Exposition | Enrage atteint ? |
|---|---|---|
| Mini-boss E2 / E3 / E4 | ×1,26 / ×1,60 / ×2,02 | sans objet |
| Boss E1 / E2 / E3 / E4 | ×1,10 / ×1,37 / ×1,72 / ×2,14 | non (≤ 75 s) |
| Idole / Canonnier / Roi | ×1,08 / ×1,67 / ×1,83 | non |
| Final | ×1,64 | oui, de 90 à 105 s (+15 % de dégâts en fin de combat) |
| Difficile, boss E2-E4 | ×1,4 à ×2,2 | **oui** (100-107 s : jusqu'à +25 % de dégâts) |

Lecture :
- Les étages 3-4 deviennent aussi exposés que l'étage 1 l'est aujourd'hui en durée. C'est l'intention des réglages de pression v2 (mesurés sur 60 s par phase pour des combats de ≈ 75 s, Design_Boss_Raid règle 5) : aujourd'hui, la pression des boss tardifs n'a pas le temps de jouer.
- Ordre de grandeur (estimé, non mesuré) : à 0,3 coup par seconde pour un joueur qui esquive bien, un boss d'étage de 70 s porte ≈ 21 coups, contre 10 aujourd'hui à l'étage 4. Avec 10 % d'armure et la régénération de base, le joueur moyen doit donc compter sur ses objets défensifs et soins aux étages 3-4, ce qui redonne une valeur à ces objets.
- Le temps passé sous bouclier n'avance pas l'enrage (règle 5) : les raids ne l'atteignent pas en Moyen.

Garde-fous si les playtests montrent trop de morts aux boss (sans toucher aux dégâts) :
1. Déployer K en deux temps : 1,10 (TTK E4 ≈ 55 s), puis 1,20 après un playtest.
2. Pour le Difficile seulement : nouveau `Balance.BOSS_HP_MODE_MULT := {facile 1,0 ; moyen 1,0 ; difficile 0,85}` → boss d'étage 2-4 ≈ 86-91 s (enrage à peine atteint), final ≈ 152 s. Point à trancher : le Difficile doit-il avoir des combats plus longs (logique RoR2) ou seulement plus dangereux ?
3. Final : `final_boss_hp_mult` 1,0 (Moyen ≈ 90 s, Difficile ≈ 150 s) si 105 s pèse trop.

## 7. Protocole de vérification en mode test

Limite du mode test : **l'arène est à l'étage 1** (`RunState.stage` = 1, le panneau l'indique : « Boss : étage de la partie (1) »). `BOSS_STAGE_K` n'y joue donc pas. Deux conséquences :
- en l'état, seuls les combats d'étage 1 (et la base 3300) sont vérifiables directement ;
- **demande aux agents dev** : un sélecteur « Étage 1-5 » dans le panneau de test qui règle `RunState.stage` (aucune écriture au profil). Les valeurs « étage N » ci-dessous supposent ce sélecteur.

Autre écart à corriger avant le test du final : `TestTools.final_hp_mult()` ne lit **pas** `floors.json` ; il calcule `BOSS_BASE_HP[&"final"] / BOSS_BASE_HP[&"etage"]` et retombe sur 2,0 (la clé `final` n'existe pas). Changer `final_boss_hp_mult` dans `floors.json` ne changerait pas le mode test. Proposition : une constante unique `Balance.FINAL_BOSS_HP_MULT` (1,2) lue par `StageManager._final_hp_mult()` (surcharge éventuelle par `floors.json`) et par `TestTools.final_hp_mult()`.

Réglages communs : mode test, **Ardent**, triches « PV illimités » **activée**, « Recharge 0 » et « Portée infinie » **désactivées**, « Sorts automatiques » activés. Niveau et objets par ligne. Deux mesures par ligne :
1. **DPS de référence** : Poutch de type Boss à 2 u, joueur immobile, total sur 60 s / 60. Si le DPS mesuré diffère du DPS attendu, raisonner sur le TTK attendu × (DPS attendu / DPS mesuré).
2. **Combat réel** : invoquer le boss, le combattre normalement (esquives comprises), chronométrer de l'apparition à la mort. Fourchette attendue = temps utile 100 % … 80 %.

Vérifier aussi les PV affichés dans le tableau « PV et dégâts à D » du panneau (sans le ×0,9 des raids, que le panneau n'inclut pas).

| # | Boss (invocation) | D | Étage | Niveau | Objets à ajouter | DPS Poutch attendu | PV avant → après | TTK attendu avant → après |
|---|---|---|---|---|---|---|---|---|
| 1 | Mini-boss : Ours de givre | 1,20 | 1 | 4 | aucun | ≈ 59 | 1 095 → 1 095 | 19-23 s → 19-23 s (témoin) |
| 2 | Boss : L'Éclusier | 1,35 | 1 | 6 | Pierre à aiguiser ×1, Lentille aiguisée ×1 | ≈ 89 | 4 531 → 4 985 | 51-63 s → 56-70 s |
| 3 | Boss : L'Idole noyée (ramasser les cloches) | 1,35 | 1 | 6 | idem 2 | ≈ 89 | 4 078 → 4 486 | 60-70 s → 64-76 s |
| 4 | Mini-boss : Ours de givre | 2,00 | 2 | 9 | Pierre ×1, Lentille ×1, Sablier fêlé ×1, Sifflet de chasse ×1, Horloge arcanique ×1, Lame jumelle ×1 | ≈ 161 | 2 553 → 3 224 | 16-20 s → 20-25 s |
| 5 | Boss : Le Cerf-Lanterne | 2,20 | 2 | 10 | Pierre ×2, Lentille ×2, Sablier ×1, Sifflet ×1, Horloge ×1, Lame ×1 | ≈ 204 | 8 032 → 11 160 | 40-50 s → 55-68 s |
| 6 | Boss : Le Sonneur | 3,30 | 3 | 13 | Pierre ×3, Lentille ×3, Sablier ×2, Sifflet ×2, Horloge ×2, Lame ×1, Rune de portée ×1, Carquois affûté ×1, Danseur ×1 | ≈ 472 | 13 772 → 24 171 | 29-36 s → 50-62 s |
| 7 | Boss : Le Reclus | 4,65 | 4 | 15 | Pierre ×4, Lentille ×4, Sablier ×3, Sifflet ×3, Horloge ×3, Lame ×2, Rune ×1, Carquois ×1, Danseur ×1, Marque du chasseur ×1, Chronomètre brisé ×1 | ≈ 924 | 23 850 → 52 875 | 27-33 s → 57-71 s |
| 8 | Boss : Le Roi de sel (ultime sur la croûte) | 4,65 | 4 | 15 | idem 7 | ≈ 924 | 21 465 → 47 588 | 33-38 s → 58-69 s |
| 9 | Boss final : Le Semeur de pluie | 6,10 | 5 | 17 | Pierre ×5, Lentille ×5, Sablier ×4, Sifflet ×4, Horloge ×4, Lame ×2, Rune ×1, Carquois ×1, Danseur ×1, Marque ×1, Chronomètre ×1 | ≈ 1 290 | 66 386 → 111 544 | 52-64 s → 85-105 s |

Sans le sélecteur d'étage (arène à l'étage 1), les lignes 4-9 donnent : Ours 2 687 PV, 17-21 s avant comme après ; Cerf 8 454 → 9 300 PV, 42-52 → 46-57 s ; Sonneur 15 259 → 16 785 PV, 32-40 → 35-44 s ; Reclus 27 817 → 30 599 PV, 31-38 → 34-42 s ; Roi 25 036 → 27 539 PV, 36-42 → 39-45 s ; Semeur (mode test : ×2,0 tant que `TestTools` n'est pas aligné) 81 504 PV, 63-78 s. Ces lignes ne vérifient que la base 3300, pas le facteur d'étage.

Vérification automatique complémentaire (agents dev) : `balance_sim_run` en configuration L12 est à l'étage 3. Après le changement, PV du mini-boss 3 156 → 5 036 (×1,60) ; TTK attendus Ardent 12,1 → ≈ 19 s, Vigie 15,0 → ≈ 24 s, Tocsin 12,2 → ≈ 20 s, Averse 16,6 → ≈ 27 s (L6, étage 1 : inchangés). Tests à mettre à jour : `test_balance.gd` ligne 29 (boss d'étage, D 1,5, étage 1 : 4 776,5 → 5 254,2) et ligne 30 (mini-boss, D 2, étage 3 : 2 425,0 → 3 869,3). Les tests `floor2/3/4_boss_test` et `rain_sower_boss_test` lisent `Balance` et suivent seuls.

## 8. Balayage de K (Moyen, build moyen, base 3300, final ×1,2)

| K | Boss E1 / E2 / E3 / E4 | Mini E4 A / B | Raids E1 / E3 / E4 |
|---|---|---|---|
| 0,95 (actuel, base 3000, final ×2) | 63 / 50 / 37 / 33 s | 16 / 13 s | 70 / 41 / 38 s |
| 1,15 | 69 / 65 / 59 / 63 s | 29 / 24 s | 75 / 61 / 63 s |
| 1,18 | 69 / 67 / 62 / 68 s | 31 / 26 s | 75 / 64 / 67 s |
| **1,20** | **69 / 68 / 64 / 71 s** | **33 / 27 s** | **75 / 66 / 70 s** |
| 1,22 | 69 / 69 / 66 / 75 s | 35 / 29 s | 75 / 68 / 72 s |
| 1,25 | 69 / 71 / 69 / 80 s | 37 / 31 s | 75 / 71 / 77 s |

(Les chiffres des raids de ce balayage comptent les soutiers du Canonnier au quart ; la table §5.2 les compte à moitié, d'où 66 → 68 s.)

Boss final selon `final_boss_hp_mult` (K 1,20, base 3300) : 1,0 → 88 s ; 1,1 → 97 s ; **1,2 → 105 s** ; 1,5 → 130 s ; 2,0 → 175 s (Moyen). Facile ×0,5, Difficile ×1,7 environ.

## 9. Risques et points à trancher

- **Mortalité aux étages 3-4** : exposition ×1,7 à ×2,1. C'est le retour à la durée de combat prévue, mais les joueurs ont pris l'habitude de boss courts. Surveiller la télémétrie « boss qui tue le plus » ; garde-fous §6.
- **Difficile** : boss d'étage 2-4 à 100-107 s, au-delà de l'enrage (90 s). À trancher : accepter (le Difficile dure et pique) ou `BOSS_HP_MODE_MULT` difficile 0,85.
- **Builds très forts** (au-delà du 75e centile, combo critique + recharge + glace de l'audit des objets) : ×1,9 à ×2,3 le build moyen ; TTK boss E4 ≈ 30-35 s après le changement, contre 15 s aujourd'hui. Acceptable (fantasme de puissance), plus de mort du boss en 15 s.
- **Mini-boss E4** : 26-31 s, haut de la plage ; le Porteur d'ossuaire et le Crabe-sarcophage (gardes) montent vers 33-35 s. Si c'est trop, `BOSS_STAGE_K` 1,18.
- **Deux mini-boss en même temps** (piliers activés ensemble) : 2 × 25-30 s de PV à l'étage 4 avec deux zones ×1,5 ; le risque monte plus que la somme. Rien à changer, mais à surveiller.
- **Sans fin** : PV ×1,26 de plus par étage par rapport à aujourd'hui ; la boucle finit plus vite. Voulu, à vérifier au premier passage à l'étage 6.
- **Personnages sous Ardent** (Averse −27 % de DPS sur le mini-boss en L12) : leurs combats s'allongent d'autant (boss E4 ≈ 95-100 s). Le problème est le kit, pas les PV des boss : à traiter dans un audit du personnage.
- **Constantes hors `Balance`** : `pillar.gd` `CHARGE_TIME` = 90 s (alors que Design_Etages prévoit 60 s aux étages 1-2) ; à déplacer dans `Balance` pour régler charge et TTK ensemble. `final_boss_hp_mult` est dans `floors.json` mais `TestTools` l'ignore (§7).
- **Documentation périmée** : `balance.gd` (commentaire de `BOSS_STAGE_K` : « compense les ~10 objets/étage » avec une valeur < 1), Maths §14 (ligne Boss : « × 0,95^(étage − 1) »), Design_Etages §4 (`BOSS_BASE_HP[&"final"] = 8 600`, absent du code), GDD (« le combat dure 20-40 s », « enrage après 60 s ») : à aligner une fois la valeur retenue.
- **Performance** : aucun effet (pas de nouvelle entité ; les combats plus longs gardent les mêmes plafonds de projectiles et d'invocations).

## 10. Limites

- **Mesuré** : TTK et DPS des mini-boss en `balance_sim` (L6, L12 ; Ardent, Vigie, Tocsin, Averse ; objets corrigés).
- **Estimé, non mesuré en jeu** : DPS par étage (modèle d'Ardent recalé ×1,1), temps utile sur la cible (×0,8), chronologie de la run, composition des builds, facteurs de PV effectifs des mini-boss et des raids, exposition aux coups.
- **Non vérifié** : durée réelle des étages et niveau du joueur en jeu (pas de télémétrie) ; DPS des autres personnages contre les boss d'étage ; effet des soins de raid en cas d'échec.
