# Ateliers, Paratonnerre dévié et Présages : chiffres à coder

> Statut : **avis de systems design** (systems-designer, 01/11/2026), sur demande de l'orchestrateur. Il fixe les chiffres de l'ensemble retenu par le joueur dans `docs/Propositions_Boucle_Interactions.md` : Fondoir + Matrice (§2.1-2.2), Alambic (§2.3), Enclume de bronze (§2.4), Boussole de rouille (§2.7), Paratonnerre dévié (§2.9), Présages (§3.1, obligatoires en Difficile, optionnels en Facile et Moyen). Rejetés et absents d'ici : Reposoir, Brasero, Départ vif, Étal des rebuts. Aucun fichier de `game/` n'est modifié : les constantes et clés ci-dessous sont **à créer** par les agents dev (`Balance` est réservé à l'orchestrateur).
>
> Lu avant d'écrire : `CLAUDE.md` (Décisions), `game/CONTRACTS.md`, `docs/Maths_Scaling.md` (§11, §14), `game/scripts/core/balance.gd`, `run_state.gd`, `loot/loot_roller.gd`, `items/item_effects.gd`, `stage/stage_manager.gd`, `director/director.gd`, `data/items.json`, `data/floors.json`, `data/maps/*.json`, `docs/Items_Catalog.md` §1, `docs/Audit_Runs_Completes_2026-10-31.md`.

## 0. Méthode et conventions

**Mesures (rapides, sans simulation image par image)** :

1. **Journaux de run réels** (`user://run_logs/`, export `RunLog`) : deux runs complètes en Moyen au rythme visé (Ardent 18:34, Taliant 17:40, deux victoires) et une run partielle (Vigie, 3 étages). Ce sont les seules mesures d'or « réel » disponibles ; elles remplacent l'estimation de `Propositions_Boucle_Interactions.md`.
2. **Modèle champ moyen 5 étages**, écrit pour cette étude avec les constantes de `balance.gd` du 01/11/2026 : difficulté `Balance.difficulty`, crédits `director_credits_per_s` × `director_ramp` × zone (mini ×1,5 et charge ×2,33), prime `monster_gold` / `monster_xp` (or ∝ crédits dépensés, élites comprises), primes de mini-boss et de boss, 8 capsules sur 10 ouvertes, prix `chest_price` au D figé de l'étage, conversion de l'or restant à 0,25 XP par or, courbe de niveau `xp_required`. Rythme : étages 1-4 de 225 s (piliers A 15-40 s, B 70-95 s, gros pilier 120-195 s), étage 5 de 130 s (45 s avant le boss final, combat 85 s). 95 % des monstres apparus tués. Il reproduit `economy_test` (613 or en 300 s à l'étage 1) et les journaux réels à ±15 % près (tableau 1.2).
3. `docs/simulateur_scaling.py` **n'a pas servi** : c'est le modèle v3 historique (pente 0,30 par minute, coffres à 150 or, crédits 4 + 2,5 D), qui diverge de `balance.gd` et de Maths §14 sur toutes les grandeurs économiques.

Tout chiffre issu du modèle et non des journaux est marqué « estimé, non mesuré en jeu ».

**Conventions** :

| Symbole | Sens |
|---|---|
| P | prix courant d'un petit coffre de l'étage : `Balance.chest_price(&"petit", RunState.floor_start_d, RunState.stage)` (D figé au début de l'étage, sans la Faveur du marchand). Tous les prix d'atelier sont exprimés en P. |
| point | grille d'audit des objets (`Items_Catalog.md` §1) : 1 point = +1 % de DPS ou de PV effectifs ; commun 10, peu commun 22, rare 50, légendaire 120. Valeur moyenne d'un petit coffre 13,2 points, d'un grand 29,0, d'un coffre de boss 26,2, d'un reliquaire `guardian` 25,4. |
| point d'étage | unité des Présages : 1 point d'étage = 1 % de puissance effective (DPS × PV effectifs ÷ pression) pendant **un** étage. Un gain permanent (objet, niveau) acquis à l'étage N compte pour tous les étages restants, rapporté à la puissance du build à ce moment-là (voir §9.1). |

## 1. Or réel par étage

### 1.1 Journaux réels (Moyen, deux runs complètes de 18-19 min)

| Étage | Durée (s) | D d'entrée | P mesuré | Or gagné | Or gagné (P) | Or dépensé (P) | Or converti en XP (P) | Objets obtenus |
|---|---|---|---|---|---|---|---|---|
| 1 | 205-233 | 1,00 | 50 | 400-439 | 8,0-8,8 | 8,0 | 0-0,8 | 8-9 |
| 2 | 191-243 | 1,75-1,83 | 105-111 | 881-1 026 | 8,0-9,8 | 7,7-9,0 | 0,3-0,8 | 8-9 |
| 3 | 288-290 | 2,74-2,82 | 191-198 | 2 010-2 054 | 10,4-10,5 | 8,5-10,0 | 0,4-2,0 | 9 |
| 4 | 254-258 | 4,27-4,35 | 345-353 | 3 376-3 726 | 9,8-10,6 | 9,4-10,0 | 0,4-0,5 | 9-10 |
| 5 | 70-141 | 6,05-6,13 | 555-564 | 2 620-4 210 | 4,6-7,6 | 3,0-4,3 | perdu à la victoire | 4-6 |

Run complète : 40-42 objets (dont 4 coffres de boss), 9 833-10 916 or gagnés, niveau 13-14. Les P estimés par le document de propositions (50 / 112 / 207 / 348 / 549) sont confirmés à ±5 %.

### 1.2 Modèle champ moyen (estimé, non mesuré en jeu)

| Étage | P | Or gagné Moyen (P) | dont kills | Reste après achats (P) | Facile (P) | Difficile (P) | Étages de 300 s (P) | +60 s de farm après le boss (P) |
|---|---|---|---|---|---|---|---|---|
| 1 | 50 | 8,1 | 44 % | 0,1 | 7,3 | 9,0 | 9,8 | 9,4 |
| 2 | 109 | 9,3 | 56 % | 1,3 | 8,6 | 9,9 | 10,6 | 10,4 |
| 3 | 198 | 9,0 | 58 % | 1,1 | 8,4 | 9,7 | 10,5 | 10,2 |
| 4 | 330 | 9,1 | 61 % | 1,1 | 8,2 | 9,9 | 10,8 | 10,4 |
| 5 (avant le boss) | 519 | 3,4 | - | 0,4 | 3,1 | 3,3 | 3,6 | 3,6 |
| 5 (pendant le boss) | 519 | 3,6 perdus | - | - | 3,0 | 4,1 | 3,8 | 3,7 |

Le reste de l'or vient des capsules (≈ 31-33 % aux étages 2-4, 2,7 P à l'étage 5) et des primes de boss. Le modèle donne 39 objets et 567 points par run (journaux : 40-42 objets).

### 1.3 Constats qui changent le cadrage des ateliers

1. **L'or est la contrainte liante aux étages 1-4.** Un étage rapporte 8-10,5 P ; l'offre de coffres est de 12 P (8 petits + 2 grands) plus 8 P de coffre légendaire une fois sur quatre. Les joueurs n'achètent jamais tout (2-3 coffres restent fermés) et ne convertissent que 0-2 P en XP. Il n'y a **pas d'or excédentaire** au rythme visé ; l'excédent de l'audit du 31/10 venait de runs de bot de 32-40 min. Conséquence : tout atelier payant **concurrence les coffres** ; son prix doit se lire en « coffres qu'on renonce à ouvrir ».
2. **L'étage 5 n'a pas de surplus utilisable.** L'or perdu à la victoire (930-1 850 or mesurés, ≈ 3,6 P estimés) est gagné **pendant** le combat final, après lequel la run s'arrête. Avant le boss, le joueur dispose de 3-4,3 P (dont 2,7 P de capsules) pour 18 P d'offre (6 petits, 2 grands, 1 légendaire). L'Enclume de l'étage 5 reste utile comme **choix ciblé**, mais elle n'est pas le « puits d'or tardif » annoncé. L'or restant est déjà payé en rubis (`run_rubies`, 1 rubis par 500 or, 20 au plus).
3. **La relance à l'or et la conversion en XP ne sont pas des puits significatifs** (0-2 P par étage) : aucune correction de l'économie n'est nécessaire avant les ateliers.

## 2. Règles communes et apparition des ateliers

### 2.1 Tirage

Un atelier par étage 1-4, exactement ; l'Enclume, toujours, à l'étage 5. Tirage seedé par `FloorPlan` (générateur propre `hash([seed, "station_run"])`, comme le secret), parmi les poids de `data/stations.json`. Le couple Fondoir + Matrice compte pour un atelier (deux props à 4 u au plus l'un de l'autre, sur la même case `E`). Un atelier dont la **famille** est déjà sortie dans la run voit son poids multiplié par `STATION_REPEAT_WEIGHT` (la Matrice seule et le couple sont de la même famille). Les cases `E` : 3 par carte aux étages 1-4, 2 à la Source ; l'Enclume de la Source se place sur la case `E` la plus proche du départ, pour qu'elle serve **avant** le boss final.

### 2.2 Tableau d'apparition par étage

Poids de `data/stations.json` (somme 100 par étage) et fréquence réelle après la règle de répétition (Monte-Carlo, 300 000 runs, estimé) :

| Étage | Fondoir + Matrice | Matrice seule | Alambic | Enclume | Boussole | Pourquoi |
|---|---|---|---|---|---|---|
| 1 | 0 | 0 | 0 | 50 (50 %) | 50 (50 %) | 0-9 objets en main : rien à fondre ni à distiller |
| 2 | 50 (55 %) | 0 | 25 (28 %) | 15 (10 %) | 10 (7 %) | le cœur de la demande arrive tôt |
| 3 | 45 (38 %) | 5 (4 %) | 30 (39 %) | 15 (13 %) | 5 (5 %) | inventaire assez gros pour payer la Matrice en objets |
| 4 | 35 (28 %) | 5 (4 %) | 25 (29 %) | 30 (32 %) | 5 (8 %) | l'Enclume monte : stack final avant la Source |
| 5 | - | - | - | 100 % | - | décision du joueur (§2.4 des propositions) |

Par run (étages 1-4) : Fondoir + Matrice 1,21 ; Matrice seule 0,08 ; Alambic 0,96 ; Enclume 1,06 (+1 à l'étage 5) ; Boussole 0,69. Familles « Matrice » par run : 0 dans 4,9 % des runs, 1 dans 63,4 %, 2 dans 29,5 %, 3 dans 2,3 %.

| Constante (`Balance`) | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `STATION_PER_STAGE` | 1 | 1 | ateliers par étage 1-4 |
| `STATION_FINAL` | `&"enclume"` | - | atelier fixe de l'étage 5 |
| `STATION_REPEAT_WEIGHT` | 0,25 | 0-0,5 | poids d'une famille déjà sortie dans la run |
| `STATION_FAMILY` | `{fondoir_matrice: matrice, matrice: matrice, alambic: alambic, enclume: enclume, boussole: boussole}` | - | familles pour la règle de répétition |
| `STATION_COPY_EXCLUDED` | `[&"phenix_de_poche"]` | - | jamais copié par la Matrice ni l'Enclume (vies empilées) |

```json
// game/data/stations.json
{
  "_doc": "Poids de tirage des ateliers par étage (docs/Ateliers_Chiffres.md §2.2). Somme 100 par étage ; l'étage 5 reçoit toujours Balance.STATION_FINAL.",
  "weights": {
    "1": {"enclume": 50, "boussole": 50},
    "2": {"fondoir_matrice": 50, "alambic": 25, "enclume": 15, "boussole": 10},
    "3": {"fondoir_matrice": 45, "matrice": 5, "alambic": 30, "enclume": 15, "boussole": 5},
    "4": {"fondoir_matrice": 35, "matrice": 5, "alambic": 25, "enclume": 30, "boussole": 5}
  }
}
```

Interface commune (rappel des propositions §2.0) : groupe `interactable`, action « interagir » seulement, panneau plein écran qui fige le temps actif, télémétrie `station_<id>_uses`, état sauvegardé (`StageManager.to_dict()` pour l'atelier, `RunState.to_dict()` pour la scorie et la Boussole). Un atelier ajoute ≈ 7 s de temps actif par étage (détour), soit ≈ +0,1 de D en fin de run (+1,5 %).

## 3. Fondoir

**Formule : remboursement de fonte**

`remboursement(q) = FONDOIR_REFUND_P[q] × Balance.chest_price(&"petit", floor_start_d, stage)`

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| q | qualité | commun, peu commun, rare | qualité de l'objet fondu (légendaires refusés) |
| `FONDOIR_REFUND_P[q]` | réel | 0,3 / 0,6 / 1,2 | part de P rendue |
| floor_start_d, stage | réel, entier | 1,75-4,4 ; 2-4 | D figé et étage (pas de Fondoir aux étages 1 et 5) |

Sortie bornée, toujours positive : de 32 or (commun à l'étage 2) à 419 or (rare à l'étage 4). Ni la Faveur du marchand ni un Présage de prix ne la modifient (prix brut). Exemple : à l'étage 3 (P = 195), fondre un peu commun rend 117 or et 1 scorie verte.

| Constante | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `FONDOIR_USES` | - | 2 | 1-3 |
| `FONDOIR_REFUND_P` | - | `{commun: 0.3, peu_commun: 0.6, rare: 1.2}` | 0,2-0,4 / 0,5-0,8 / 1,0-1,5 |
| `SCRAP_CAP` | - | 3 (toutes qualités confondues) | 2-4 |

Remboursements en or (P mesurés) : étage 2 : 32 / 65 / 130 ; étage 3 : 59 / 117 / 234 ; étage 4 : 105 / 209 / 419 (commun / peu commun / rare).

Pourquoi c'est sûr : acheter un commun coûte 1 P (petit coffre, 78 %) et le fondre rend 0,3 P ; un peu commun coûte ≈ 2,5 P (grand coffre), un rare ≈ 11 P : le remboursement reste à 12-30 % du prix d'acquisition, aucune boucle or → coffre → fonte → or n'est rentable. L'objet d'un coffre de boss (gratuit) fondu rend 0,6 P : c'est un revenu voulu, borné à 2 usages.

Règles d'objets : **Phénix** : seuls les exemplaires non consommés se fondent (`stacks - phenix_used > 0`) ; un exemplaire consommé ne se fond pas (sinon on recyclerait une vie déjà utilisée en scorie rouge). **Chronomètre brisé** : état interne perdu (écrit sur la carte). **Faveur du marchand** fondue : le prix des coffres remonte immédiatement (coffres déjà ouverts non concernés). La scorie survit au changement d'étage (`RunState.scrap`, sauvegardée).

## 4. Matrice

| Constante | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `MATRICE_USES` | - | 3 | 2-3 (2 si la télémétrie montre > 70 % de forges complètes) |
| `MATRICE_QUALITY_TABLE` | - | `{2: {commun: 70, peu_commun: 30}, 3: {commun: 55, peu_commun: 40, rare: 5}, 4: {commun: 45, peu_commun: 45, rare: 10}}` | rare 0-10 % |
| `MATRICE_MAX_OWNED` | - | 5 | 4-6 |
| `MATRICE_TAG_WEIGHT` | - | réutiliser `LootRoller.BUILD_TAG_WEIGHT` (1,3) | 1,0-1,5 |

Changement par rapport aux propositions : la table de qualité **dépend de l'étage**. À l'étage 2, le joueur tient ≈ 7 communs et 2 peu communs (journaux) : une Matrice rare (5 %) y serait inutilisable. La part de peu communs monte avec les coffres de boss et les grands coffres ; le rare n'apparaît qu'aux étages 3-4.

Tirage de l'objet affiché : au début de l'étage, seedé, qualité puis objet ; jamais légendaire, jamais un objet de `STATION_COPY_EXCLUDED`, jamais un objet que le joueur possède à `MATRICE_MAX_OWNED` exemplaires ou plus (re-tirage). Si l'objet affiché atteint un plafond de `Balance.ITEM_BONUS_CAPS` en cours d'étage, la carte l'écrit (« plafond atteint ») mais la forge reste permise (choix du joueur).

Paiement : 1 scorie de la qualité (appui direct) **ou** 1 objet de la même qualité (panneau). Valeur estimée d'une Matrice couplée au Fondoir (2 fontes de rebuts, 3 forges, objet ciblé valant ×1,3, rebut valant ×0,5) : **+40 points, 0 objet net** ; Matrice seule (payée en objets) : +29 points.

## 5. Alambic

| Constante | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `ALAMBIC_INPUT` | - | 3 | 3 |
| `ALAMBIC_USES` | - | **2** (propositions : 1) | 1-2 |
| `ALAMBIC_TAG_GUIDED` | - | true | - |
| `ALAMBIC_ALLOW_LEGENDARY` | - | false | false (true seulement en Difficile si la télémétrie montre 0 légendaire par run) |

Bilan d'un usage : 3 communs → 1 peu commun : 30 points bruts → 22 (−8) ; si les 3 communs sont des rebuts (×0,5) et le résultat ciblé (×1,3) : **+14 points, −2 objets**. 3 peu communs → 1 rare : +32 points dans les mêmes hypothèses. Avec un seul usage, l'Alambic valait ≈ +19 points contre +40 pour Fondoir + Matrice et donnait l'impression d'un tirage raté ; avec 2 usages (le second utilisé une fois sur deux environ) : ≈ **+29 points, −3 objets**. Le résultat ne peut pas être un objet déjà plafonné ; il peut être un Phénix (un seul, il n'est pas copié).

## 6. Enclume de bronze

**Formule : prix d'un exemplaire forgé**

`prix(q, k, id) = ENCLUME_PRICE_P[q] × ENCLUME_PRICE_GROWTH^k × P × ItemEffects.chest_price_mult() × présage.chest_price_mult × ENCLUME_TAG_PRICE_MULT[tag(id)]`

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| q | qualité | commun, peu commun, rare | qualité de l'objet copié (légendaires refusés) |
| k | entier | 0-2 | usages déjà faits sur cette Enclume |
| P | or | 50-564 | prix d'un petit coffre de l'étage |
| `chest_price_mult()` | réel | 0,4-1 | Faveur du marchand (0,85 par exemplaire, plancher 0,4) |
| présage | réel | 0,8-1,3 | Usure ×0,8, Marché noir ×1,3, sinon 1 |
| `ENCLUME_TAG_PRICE_MULT` | réel | 1 ou 1,5 | ×1,5 pour un objet du tag Or (Faveur, Pièce), 1 sinon |

Sortie bornée, jamais nulle (plancher Faveur 0,4) : de 25 or (commun, étage 1, Faveur au plancher) à ≈ 7 700 or (rare, 3e usage, étage 5, Marché noir).

| Constante | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `ENCLUME_PRICE_P` | - | `{commun: 1.25, peu_commun: 2.75, rare: 6.0}` (propositions : 1,2 / 2,5 / 6,0) | 1,0-1,5 / 2,3-3,2 / 5-8 |
| `ENCLUME_PRICE_GROWTH` | - | 1,4 (propositions : 1,5) | 1,3-1,6 |
| `ENCLUME_USES` | - | 3 | 2-3 |
| `ENCLUME_TAG_PRICE_MULT` | - | `{"Or": 1.5}` | 1,25-2,0 |

Prix du premier exemplaire aux P mesurés (×1,4 puis ×1,96 pour les 2e et 3e) :

| Étage | P | Commun | Peu commun | Rare |
|---|---|---|---|---|
| 1 | 50 | 62 | 138 | 300 |
| 2 | 108 | 135 | 297 | 648 |
| 3 | 195 | 244 | 536 | 1 170 |
| 4 | 349 | 436 | 960 | 2 094 |
| 5 | 560 | 700 | 1 540 | 3 360 |

Justification (équilibre transitif) : comme l'or est liant (§1.3), un usage d'Enclume se paie en coffres non ouverts. Un petit coffre rapporte 13,2 points par P ; un exemplaire ciblé vaut ≈ 1,3 × sa qualité, soit 13 / 28,6 / 65 points : à 1,25 / 2,75 / 6,0 P, l'Enclume rend ≈ 0,8 × le rendement d'un coffre (10,4-10,8 points par P). Elle n'est donc rentable que pour un objet qui vaut **plus** que la moyenne pour ce build (le Sifflet d'un build Auto, la 3e Lame jumelle) : c'est un choix, pas un défaut (Sirlin). Les 2e et 3e usages tombent à 0,57 et 0,41 du rendement d'un coffre : réservés aux joueurs qui farment ou aux étages où un Présage a fait baisser les prix. Gain estimé : +4 points par Enclume des étages 1-4, +3 à l'étage 5 (budget de 3-4 P avant le boss : un peu commun ou un à deux communs, un rare n'y est pas abordable).

Tag Or ×1,5 : copier la Faveur du marchand (rare, ×0,85 sur tous les prix suivants) à l'étage 2 se rembourse en ≈ 1,5 étage puis rapporte ≈ +1,6 P par étage : boucle renforçante non voulue au prix normal. Le surcoût la garde possible (9 P à l'étage 2 au lieu de 6 P) sans en faire l'achat évident.

## 7. Boussole de rouille

| Constante | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `BOUSSOLE_PRICE_P` | - | **0** (propositions : 0,6) | 0-0,3 |
| `BOUSSOLE_CHARGES` | - | **2** (propositions : 1 usage) | 1-3 |
| `BOUSSOLE_TAGS_SHOWN` | - | 6 (4 tags les plus présents du build + 2 tirés parmi les autres) | 4-6 |
| `BOUSSOLE_CHEST_KINDS` | - | `[&"petit", &"large"]` | ne jamais ajouter légendaire, boss, guardian |

Pourquoi gratuite : une garantie de tag sur la carte A rapporte ≈ +3 points sur un petit coffre et ≈ +6 sur un grand (le joueur choisissait déjà la meilleure des deux cartes). À 0,6 P (≈ 7,9 points de coffre renoncé), l'usage était perdant en espérance ; or la Boussole **occupe la case d'atelier de l'étage** : payante, elle ferait un tirage raté. Gratuite à 2 charges : ≈ +6 points par Boussole. Règles : le tag est choisi une fois ; chaque charge s'applique au prochain petit ou grand coffre ouvert, à son **premier tirage** seulement (une relance tire normalement) ; les charges survivent au changement d'étage (`RunState.compass = {tag, charges}`) ; si la qualité tirée n'a aucun objet du tag, la charge n'est **pas** consommée et la carte l'écrit.

## 8. Paratonnerre dévié

| Constante | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `PILLAR_DEVIATED_MIN_FLOOR` | - | **2** (propositions : 1) | 2 |
| `PILLAR_DEVIATED_BOSS_HP_MULT` | - | `{2: 1.4, 3: 1.4, 4: 1.3}` (propositions : 1,4 partout) | 1,3-1,6 ; 1,2-1,4 à l'étage 4 |
| `PILLAR_DEVIATED_ENRAGE_DELAY_MULT` | - | même table que les PV | = PV |
| `PILLAR_DEVIATED_AFFIXES` | - | `[&"burn", &"slow", &"poison"]` (les trois affixes du `Director`) | - |
| `PILLAR_DEVIATED_CHESTS` | - | 2 (table `boss`) | 2 |
| `PILLAR_DEVIATED_EXCLUDED` | - | `[&"drowned_idol", &"flood_gunner", &"salt_king", &"rain_sower"]` | raids et boss final exclus en v1 |

Effet sur le combat (TTK de boss d'étage du rythme visé, mesurés 48-107 s dans les journaux, cible 65-75 s) :

| Étage | TTK normal | TTK dévié | Rallonge | Or gagné en plus (zone de charge) | D en plus | Enrage |
|---|---|---|---|---|---|---|
| 2 | 65 s | 91 s | +26 s | +109 or (1,0 P) | +0,08 (+3 %) | après 126 s |
| 3 | 62 s | 87 s | +25 s | +188 or (1,0 P) | +0,08 (+2 %) | après 126 s |
| 4 | 95 s | 124 s (×1,3) | +29 s | ≈ +380 or (1,1 P) | +0,11 (+2 %) | après 117 s |

L'enrage (`BOSS_ENRAGE_AFTER_S` 90 s) est décalé du même facteur que les PV : sans cela, le Reclus dévié (107 s mesurés × 1,4 = 150 s) passerait 60 s enragé (+90 % de dégâts), ce qui transforme un pari en piège. `BOSS_HP_MODE_MULT` (Difficile 0,85) s'applique en plus.

Bilan en points d'étage (Moyen, estimé) : gain permanent (2e coffre de boss + or de la rallonge) +27 / +17 / +9 aux étages 2 / 3 / 4 ; coût temporaire (boss 40 % plus long sur la part « boss » du défi, 0,4, et affixe) ≈ −14 / −14 / −12. Net **+13 / +3 / −3** : un pari payant tôt pour qui survit, neutre ensuite. À l'étage 1 le net serait ≈ +26 : la déviation y deviendrait le choix par défaut de tout joueur à l'aise, d'où `PILLAR_DEVIATED_MIN_FLOOR := 2` (l'étage 1 reste aussi celui de la découverte du premier boss). Plafonds inchangés : coup de boss ≤ 40 % des PV max, brûlure élite = 25 % du coup sur 3 s, aucune mort instantanée.

Règle avec le Présage Usure (« pas de coffre de boss ») : Usure retire le coffre de base, le coffre du Paratonnerre tombe quand même (1 coffre au total).

## 9. Présages

### 9.1 Formule de valeur d'un présage

`valeur(présage, N) = 100 × Σ_{n=N..5} (Π'_n / Π_n − 1) + temporaire`

`Π_n = (100 + S_n) / 100 × (1 + LEVEL_PI)^(niveau_n − 1)`

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| N | entier | 2-5 | étage du présage |
| S_n | points | 67 / 208 / 355 / 501 / 596 (milieu des étages 1-5, Moyen) | points d'objets du build |
| niveau_n | réel | 6-13 | niveau du joueur (fractionnaire) en fin d'étage |
| `LEVEL_PI` | réel | 0,12 | +12 % de puissance par niveau (dégâts de base 12 + 2,4/niv, PV 100 + 30/niv, objets compris) |
| temporaire | points d'étage | ±25 | effet limité à l'étage : dégâts infligés +x % = +x ; dégâts subis ×(1 + a) = −100 a / (1 + a) ; pression des monstres hors boss ×(1 + p) = −100 × 0,6 × p / (1 + p) (0,6 = part du défi due aux monstres hors boss) |

Π' est calculé dans le modèle champ moyen avec le présage appliqué (or, prix, coffres, XP), Π sans. Sortie : un nombre de points d'étage ; cible **0 ± 5** (`OMEN_BUDGET_TOLERANCE`). Un gain d'objet vaut beaucoup plus tôt que tard (+1 petit coffre = +15 points d'étage à l'étage 2, +3,5 à l'étage 4) : les présages « de butin » ont donc des valeurs par étage, ou sont bornés en étages.

### 9.2 Liste (8 présages + « Ciel clair »)

L'écran d'arrivée montre **un présage de combat** (groupe `combat`) et **un présage de butin** (groupe `butin`), tirés seedés parmi ceux permis à cet étage et jamais choisis plus tôt dans la run.

| Id | Nom | Groupe | Étages | Contrainte | Compensation | Valeur nette (Moyen) | Facile / Difficile |
|---|---|---|---|---|---|---|---|
| `pluie_de_cendres` | Pluie de cendres | combat | 2-5 | dégâts des monstres et des boss ×1,25 | vos dégâts ×1,25 | 0 (jusqu'à +2 : le plafond de 25 % / 40 % des PV par coup bride le malus) | idem |
| `carapaces` | Carapaces | combat | 2-5 | PV des tireurs, bondisseurs, brutes et élites ×1,35 (essaim, mini-boss et boss inchangés) | vos PV max ×1,15 | +3,3 | idem |
| `fievre` | Fièvre | combat | 2-5 | dégâts subis ×1,20 | recharges des sorts ×0,77 (le plancher `COOLDOWN_FLOOR` reste appliqué) | +0,4 ; −16,7 si la recharge est déjà au plancher (la carte l'écrit) | idem |
| `eveil_des_elites` | Éveil des élites | combat | 2-4 | chance d'élite ×2 (plafond 0,40), meneurs de vague compris | +15 % de dégâts contre élites, mini-boss et boss | ≈ +3, **incertain ±8** (le coût réel des affixes n'est pas mesurable sans télémétrie) | idem |
| `marche_noir` | Marché noir | butin | 2-5 | prix des coffres, des relances et de l'Enclume ×1,30 | or des capsules ×2 | +2,0 / +1,0 / +0,3 / +1,2 (étages 2-5) | +3,6…+0,9 / +0,8…−0,3 |
| `offrande` | Offrande | butin | 2-5 | or des monstres ×0,65 | un reliquaire (table `guardian`) posé à l'arrivée | +1,0 / +0,5 / 0 / +1,6 | +3,2…+1,0 / −0,8…+1,5 |
| `usure` | Usure | butin | 2-4 | pas de coffre de boss à cet étage | prix des coffres, des relances et de l'Enclume ×0,80 | +3,1 / +1,5 / +0,9 | +1,7…+0,2 / +4,2…+1,4 |
| `maree` | Marée | butin | 2-4 | crédits du director ×1,15 (étage 2), ×1,25 (étages 3-4) : plus de monstres | l'or et l'XP de ces monstres en plus (aucune autre récompense) | +3,0 / +0,6 / −3,0 | +2,7 / −0,5 / −4,4 ; +4,4 / +1,9 / −2,4 |
| `ciel_clair` | Ciel clair | - | 2-5 | aucun | aucun | 0 | Facile et Moyen seulement |

Toutes les valeurs sont estimées (modèle §0), sauf Pluie de cendres, Carapaces et Fièvre, qui sont exactes par construction (deux multiplicateurs de la même étendue temporelle). Présages écartés en chemin : « Lune noire » (pas d'XP des monstres contre de l'or) : l'XP vaut trop selon l'étage (−14 à +4) ; « Nuit sans lanterne » des propositions : le rayon de ramassage n'a plus d'effet depuis le ramassage automatique du 22/10 ; l'ancien « Éveil des élites » donnait un coffre de boss en table `guardian`, qui est **moins bon** que la table `boss` (88/12 contre 85/15) : récompense remplacée.

Plafonds et perf : aucun présage ne crée de projectile, d'effet par monstre ni de calcul par image ; les multiplicateurs se lisent à l'apparition des monstres (PV, dégâts), dans le `Director` (crédits, élites) et dans le calcul des stats du joueur. Marée reste sous `RAMP_ALIVE_MAX` (150 vivants) ; Éveil des élites fait **moins** de corps par crédit (élite = coût ×6). Le plafond de 25 % (40 % boss) des PV max par coup s'applique après le multiplicateur de Pluie de cendres et de Fièvre.

### 9.3 Normal et Difficile

| Règle | Facile et Moyen | Difficile |
|---|---|---|
| Étages | 2-5 | 2-5 |
| Cartes | présage de combat, présage de butin, **Ciel clair** | présage de combat, présage de butin ; **choix obligatoire** |
| Présages par run | 0-4, au choix | 4 |
| Valeurs | table 9.2 | table 9.2 (mêmes nombres) |
| Rubis | +`OMEN_RUBIES` par présage accepté | idem (+8 par run) |
| Effet sur la puissance | nul en moyenne (le joueur prend ce qui l'arrange) | espérance ≈ +2 points d'étage par étage (meilleure de deux cartes à 0 ± 5), variance plus forte : le joueur doit s'adapter à un tirage qu'il ne peut pas refuser |

Les nombres sont identiques dans les deux modes : la difficulté du Difficile vient de l'obligation (pas de refus quand les deux cartes vont contre le build), pas d'une amplitude plus grande. Option écartée : amplitude ×1,25 en Difficile (même espérance, variance plus forte, deux tables à maintenir). Défi du jour (mode Moyen) : mêmes cartes pour tous (graine du jour), choix libre et refus permis ; la comparabilité vient de la graine commune.

| Constante | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `OMEN_FROM_FLOOR` | - | 2 | 2 |
| `OMEN_CHOICES` | - | 2 (+ Ciel clair hors Difficile) | 2 |
| `OMEN_MANDATORY_MODES` | - | `[&"difficile"]` | - |
| `OMEN_RUBIES` | - | 2 | 0-3 (+8 au plus, ≈ 5 % des ≈ 150 rubis d'une victoire en Moyen) |
| `OMEN_BUDGET_TOLERANCE` | - | 5.0 | 5 (contrôle de test, pas de jeu) |
| `OMEN_ELITE_CHANCE_CAP` | - | 0,40 | 0,35-0,45 (`ELITE_CHANCE_MAX` reste 0,25 hors présage) |

```json
// game/data/omens.json
{
  "_doc": "Présages d'étage (docs/Ateliers_Chiffres.md §9). effects_by_floor surcharge effects pour un étage. Clés d'effets : voir §9.4.",
  "omens": [
    {"id": "pluie_de_cendres", "name": "Pluie de cendres", "group": "combat", "floors": [2, 3, 4, 5],
     "text": "Les monstres frappent 25 % plus fort. Vous aussi.",
     "effects": {"monster_damage_mult": 1.25, "player_damage_mult": 1.25}},
    {"id": "carapaces", "name": "Carapaces", "group": "combat", "floors": [2, 3, 4, 5],
     "text": "Tireurs, bondisseurs, brutes et élites : +35 % de PV. Vos PV max : +15 %.",
     "effects": {"monster_hp_mult": 1.35, "monster_hp_tiers": [2, 3], "monster_hp_elites": true, "player_max_hp_mult": 1.15}},
    {"id": "fievre", "name": "Fièvre", "group": "combat", "floors": [2, 3, 4, 5],
     "text": "Vous subissez 20 % de dégâts en plus. Vos recharges sont 23 % plus courtes.",
     "effects": {"player_damage_taken_mult": 1.2, "cooldown_mult": 0.77}},
    {"id": "eveil_des_elites", "name": "Éveil des élites", "group": "combat", "floors": [2, 3, 4],
     "text": "Deux fois plus d'élites. +15 % de dégâts contre les élites et les boss.",
     "effects": {"elite_chance_mult": 2.0, "elite_boss_damage_mult": 1.15}},
    {"id": "marche_noir", "name": "Marché noir", "group": "butin", "floors": [2, 3, 4, 5],
     "text": "Coffres et forge 30 % plus chers. Les capsules d'argent valent double.",
     "effects": {"chest_price_mult": 1.3, "capsule_gold_mult": 2.0}},
    {"id": "offrande", "name": "Offrande", "group": "butin", "floors": [2, 3, 4, 5],
     "text": "Les monstres rapportent 35 % d'or en moins. Un reliquaire vous attend à l'arrivée.",
     "effects": {"kill_gold_mult": 0.65, "arrival_chest": "guardian"}},
    {"id": "usure", "name": "Usure", "group": "butin", "floors": [2, 3, 4],
     "text": "Pas de coffre de boss à cet étage. Coffres et forge 20 % moins chers.",
     "effects": {"boss_chest": false, "chest_price_mult": 0.8}},
    {"id": "maree", "name": "Marée", "group": "butin", "floors": [2, 3, 4],
     "text": "+25 % de monstres (+15 % à l'étage 2), donc plus d'or et d'XP.",
     "effects": {"director_credit_mult": 1.25},
     "effects_by_floor": {"2": {"director_credit_mult": 1.15}}}
  ],
  "clear": {"id": "ciel_clair", "name": "Ciel clair", "text": "Aucun présage à cet étage."}
}
```

### 9.4 Clés d'effets (contrat à créer)

| Clé | Lue par | Sens |
|---|---|---|
| `monster_damage_mult` | `Enemy` à l'apparition (monstres, élites, mini-boss, boss) | × dégâts, avant le plafond de coup |
| `player_damage_mult` | dégâts du joueur (multiplicatif, distinct des bonus additifs d'objets) | × dégâts infligés |
| `monster_hp_mult`, `monster_hp_tiers`, `monster_hp_elites` | `Enemy` à l'apparition | × PV des tiers listés et des élites ; jamais boss ni mini-boss |
| `player_max_hp_mult` | stats du joueur | × PV max (après objets) |
| `player_damage_taken_mult` | `Player.take_damage` | × dégâts subis, avant le plafond |
| `cooldown_mult` | `ItemStats` / `effective_cooldown` | × recharge, plancher `COOLDOWN_FLOOR` conservé |
| `elite_chance_mult` | `Director` (`elite_chance`, meneurs de vague) | × chance, plafond `OMEN_ELITE_CHANCE_CAP` |
| `elite_boss_damage_mult` | dégâts du joueur contre élites, mini-boss, boss | × dégâts |
| `chest_price_mult` | prix de coffre, relance à l'or, Enclume (pas le remboursement du Fondoir) | × prix |
| `capsule_gold_mult` | `GoldCapsule` | × or |
| `kill_gold_mult` | `PickupManager` (primes des monstres, pas des boss) | × or |
| `arrival_chest` | `StageManager` | coffre gratuit posé près du départ |
| `boss_chest` | `Pillar` | false = pas de coffre de boss de base |
| `director_credit_mult` | `Director` | × crédits par seconde |

Le présage choisi vit dans `RunState.omen` (id, sauvegardé) et cesse au téléporteur.

## 10. Budget d'objets net par run

Moyen, rythme visé, estimé (hypothèses d'usage : rebut fondu ou donné = ×0,5, objet ciblé = ×1,3 ; Paratonnerre pris sur la moitié des gros piliers 2-4) :

| Source | Objets | Points | Temps actif |
|---|---|---|---|
| Base sans ateliers (modèle ; journaux : 40-42 objets) | 39 | 567 | 1 030 s |
| Fondoir + Matrice (1,21 par run) | 0 | +48 | +12 s |
| Matrice seule (0,08) | 0 | +2 | +0,5 s |
| Alambic (0,96, 2 usages) | −2,9 | +28 | +8 s |
| Enclume étages 1-4 (1,06) + étage 5 | −0,8 | +7 | +10 s |
| Boussole (0,69) | 0 | +4 | +2 s |
| **Ateliers seuls** | **−3,1** | **+87 (puissance de fin de run ×1,13)** | **+33 s (+0,1 de D)** |
| Paratonnerre dévié (1,5 par run) | +3,2 | +59 | +40 s |
| **Total** | **≈ 39** | **≈ 713 (×1,22)** | **≈ +73 s** |

Lecture : le nombre d'objets ne bouge presque pas (l'Alambic en consomme, le Paratonnerre en ajoute) ; la **qualité** du build monte, ce qui est le but des propositions. +13 % de puissance en fin de run par les ateliers seuls réduit le TTK du boss final d'≈ 11 % (135 s → ≈ 120 s, encore dans la cible 120-150 s) et celui des boss d'étage de 65-75 s à ≈ 58-67 s. **Aucune correction immédiate** des PV de boss ; levier si la télémétrie montre des boss d'étage sous 55 s : `BOSS_FOCUS_HP_MULT[&"etage"]` 0,5 → 0,55 (plage 0,5-0,6). Le joueur qui dévie choisit lui-même des boss plus longs : sa marge n'appelle pas de correction.

## 11. Garde-fous anti-abus (matrice d'interactions)

| Combinaison | Risque | Mesure (chiffrée) | Résidu |
|---|---|---|---|
| Fondoir ↔ Matrice | boucle fonte → forge → fonte | bornée par les usages (2 fontes, 3 forges) ; refonte d'un objet forgé : +0,3 P par cycle, 2 cycles au plus = +0,6 P | négligeable |
| Fondoir + coffre | acheter pour fondre | remboursement 0,3 / 0,6 / 1,2 P ≤ 30 % du prix d'acquisition | aucun |
| Fondoir + Phénix | recycler une vie déjà consommée | exemplaires consommés non fondables | aucun |
| Matrice / Enclume + Phénix | vies empilées (invulnérabilité de fait) | `STATION_COPY_EXCLUDED` ; l'Alambic peut en donner **un** | un Phénix de plus au pire |
| Matrice ×3 dans une run | +9 exemplaires d'un même objet | `STATION_REPEAT_WEIGHT` 0,25 : 3 familles Matrice dans 2,3 % des runs ; `MATRICE_MAX_OWNED` 5 coupe l'objet déjà empilé | 90 points dans 2 % des runs : accepté |
| Alambic + Enclume | acheter 3 communs pour distiller | 1,25 + 1,75 + 2,45 = 5,45 P pour un peu commun ciblé (28,6 points) = 5,2 points par P, 40 % du rendement d'un coffre ; jamais au même étage (1 atelier par étage) | aucun |
| Alambic + Matrice | 3 copies forgées → distillées en peu commun du même tag | légal, chaîne perdante en points bruts | voulu (Expression) |
| Boussole + coffre légendaire | 0 P pour cibler un légendaire | `BOUSSOLE_CHEST_KINDS` = petit, grand | aucun |
| Boussole + relances | relances « verrouillées » sur un tag | garantie au premier tirage seulement | aucun |
| Boussole + Matrice | orienter l'objet affiché | la Matrice est tirée au début de l'étage, la Boussole n'agit que sur les coffres | aucun |
| Enclume + Faveur du marchand | copier la Faveur : boucle de prix | `ENCLUME_TAG_PRICE_MULT` Or ×1,5 ; plancher Faveur 0,4 conservé | boucle possible mais payée 9 P à l'étage 2 |
| Fondoir + Faveur / présage de prix | remboursement gonflé ou rogné | remboursement en P brut | aucun |
| Farm après le boss + Enclume | puits d'or infini | 3 usages, ×1,4 par usage ; D monte de ≈ +0,15 par minute en Moyen | borné |
| Paratonnerre + Pluie de cendres / Fièvre | boss affixé qui tue d'un coup | plafond de coup de boss 40 % des PV max appliqué après les multiplicateurs ; enrage décalé | aucun coup mortel isolé ; risque cumulé voulu |
| Paratonnerre + Usure | 0 ou 2 coffres ? | Usure retire le coffre de base seulement | 1 coffre |
| Présages + Défi du jour | inégalité entre joueurs | mêmes cartes pour tous (graine) | aucun |
| Éveil des élites + perf mobile | plus d'auras d'élite | moins de corps par crédit (coût ×6) ; plafond de chance 0,40 | à mesurer |

## 12. Tests et télémétrie à prévoir

- `station_test` : usages et refus écrits ; remboursement < prix d'acquisition à chaque étage ; plafond de scorie ; Phénix consommé non fondable ; exclusions de copie ; prix de l'Enclume (formule §6) au centime près ; Boussole non consommée sur une qualité sans le tag ; sauvegarde aller-retour.
- `station_plan_test` : 10 000 graines : fréquences du §2.2 à ±1 point, jamais d'atelier en double au même étage, Enclume toujours à l'étage 5.
- `omen_test` : valeurs de la table 9.2 recalculées avec le modèle (`OMEN_BUDGET_TOLERANCE`), jamais deux fois le même présage choisi, Ciel clair absent en Difficile, cartes identiques au défi du jour.
- `pillar_deviated_test` : affixe annoncé = affixe appliqué, PV × table, enrage décalé, 2 coffres, refus sur les raids, le final et l'étage 1.
- `economy_test` étendu à 5 étages : or par étage dans les bandes du §1.2 (±15 %).
- `RunLog` : `station_<id>_uses`, objets donnés et reçus, or dépensé à l'Enclume, présage proposé / choisi / refusé, déviation et TTK du boss dévié. Seuils de recalibrage : forges complètes > 70 % → `MATRICE_USES` 2 ; Enclume utilisée < 15 % des fois → `ENCLUME_PRICE_P` −0,25 P ; un présage choisi > 75 % ou < 15 % des fois quand il est proposé → revoir sa valeur ; boss d'étage < 55 s → levier du §10.

## 13. Points à trancher

1. **Enclume à l'étage 5** : la garder comme choix ciblé (recommandé, coût nul) en sachant qu'elle ne récupère pas l'or perdu à la victoire ; ou la retirer de l'étage 5 et l'ajouter aux poids des étages 1-4.
2. **`OMEN_RUBIES`** (méta-économie) : 2 par présage accepté, ou 0 (les présages ne valent alors que pour la variété en Facile et Moyen).
3. **Paratonnerre à l'étage 1** : exclu ici pour éviter un choix par défaut ; le réintroduire avec `PILLAR_DEVIATED_BOSS_HP_MULT[1] := 1.6` si le joueur veut un pari dès le premier boss.
