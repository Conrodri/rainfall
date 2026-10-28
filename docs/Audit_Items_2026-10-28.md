# Audit d'équilibrage des objets (28/10/2026)

Consultant : systems-designer. Déclencheur : retour du testeur, « certains items paraissent trop forts, on atteint trop vite de lourds dégâts ou de grosses réductions de recharge » ; cités : Chronomètre brisé, Cœur de glace, Œil du prédateur.

Sources lues : `game/data/items.json`, `game/scripts/core/balance.gd`, `game/scripts/items/item_stats.gd`, `game/scripts/items/item_effects.gd`, `game/scripts/spells/spell_caster.gd` (`compute_damage`, `_roll_procs`), `game/scripts/player/player.gd`, `game/scripts/enemies/enemy.gd` (`apply_status`, `is_slowed`), `game/scripts/loot/*`, `docs/Maths_Scaling.md` (§9, §11, §14), `docs/Items_Catalog.md`.

Mesures : `balance_sim_run` (Ardent et Vigie, mini-boss et élite, L6 et L12, objets neutres de la config). Le reste est un **modèle analytique** (DPS mono-cible d'Ardent : sort 1 coef 0,8 / 0,6 s, Nova 2,5 / 6 s, Cendres 10 × 0,5 / 8 s, Brasier 8 / 20 s, soit environ 48 % du DPS au sort 1 et 52 % aux sorts à recharge). Tous les chiffres de valeurs proposées sont **estimés, non mesurés en jeu**.

---

## 1. Formule de dégâts telle que codée

```
dégât = coef × base(L) × (1 + Σadd) × Πmult × (critique ? M : 1)
base(L) = 12 + 2,4 (L − 1)
Σadd = damage_add + (auto_damage_add | cd_damage_add) + zone_damage_add (zones à recharge)
     + elite_boss_damage_add (élite/boss) + low_hp_damage_add (PV ≤ 35 %) + moving_damage_add (en mouvement)
     + slowed_target_damage_add (cible ralentie ou tenue) + bonus du kit
M = 2 + Σ crit_mult_add ; chance de critique c = clamp(0,01 + Σ crit_chance, 0, 1)
recharge = max(base × cooldown_mult, base × 0,25), cooldown_mult = Π (1 + aᵢ)^nᵢ
```

Points structurants :

- Tous les bonus conditionnels (Cœur de glace, Danseur, Marque, Sang chaud) tombent dans **la même somme additive** : leur valeur relative baisse quand la somme grossit, mais **en début de run la somme est petite**, donc +50 % vaut presque ×1,5.
- Le critique est **un multiplicateur à part** : il ne se dilue jamais dans la somme additive.
- La recharge est **multiplicative entre objets et exponentielle par exemplaire** : la cadence (1 / recharge) croît comme 1,33ⁿ pour le Chronomètre, jusqu'au plancher.
- Les procs proportionnels au coup (poison de Fiole 180 % et Venin 300 % × n, brûlure de Cristal 50 %, foudre 80 %) partent du **coup final, critique et bonus de ralenti compris** : Œil et Cœur de glace se répercutent sur ces DoT.

## 2. Les trois objets cités

### 2.1 Chronomètre brisé (rare)

Code : `stats.cooldown_mult = −0,25`, `stack: "E"` → contribution (1 − 0,25)ⁿ, multipliée avec Sablier fêlé (0,92ⁿ, commun) et Horloge arcanique (0,85ⁿ, peu commun) ; plancher `Balance.COOLDOWN_FLOOR` = 0,25. Spécial : chaque élite ou boss tué (`enemy_killed` élite, `boss_killed`) rend `0,5 × n` s à tous les sorts non automatiques.

| Exemplaires | Multiplicateur | Réduction | Cadence | DPS Ardent (seul) | Remise par élite |
|---|---|---|---|---|---|
| 1 | 0,750 | 25 % | ×1,33 | ×1,17 | 0,5 s |
| 3 | 0,422 | 58 % | ×2,37 | ×1,71 | 1,5 s |
| 5 | 0,237 → plancher 0,25 | 75 % | ×4,00 | ×2,56 | 2,5 s |
| 10 | plancher 0,25 | 75 % | ×4,00 | ×2,56 | 5,0 s |

Pourquoi il paraît trop fort :

1. **La cadence est exponentielle** : chaque exemplaire multiplie la cadence par 1,33, et le plancher est atteint dès 5 exemplaires seuls, ou avec **1 Chronomètre + 3 Horloges + 4 Sabliers** (0,75 × 0,614 × 0,716 = 0,33). Ces deux derniers sont des communs et peu communs, donc fréquents : le Chronomètre arrive sur une recharge déjà basse et la pousse au plancher.
2. **Le plancher de 25 % est trop bas** pour un survivor-like à 3 sorts à recharge : ×4 sur 52 % du DPS donne ×2,56 de DPS total, sans compter les zones qui se superposent (Cendres 5 s de durée pour 2 s de recharge au plancher : 2,5 zones actives en même temps).
3. **La remise par élite est linéaire** : avec une Nova à 1,5 s, 3 exemplaires (1,5 s) remettent à zéro tous les sorts à chaque élite.
4. **Bouclier réactif hérite de la recharge sans plancher** (bogue, voir §4) : `_charge_time()` lit `cooldown_mult` brut (0,75⁵ = 0,237, 0,75¹⁰ = 0,056) → une charge toutes les 0,54 s (5 Chronos, 2 Boucliers), 0,13 s (10 Chronos), avec 0,4 s d'invulnérabilité par charge : **invulnérabilité quasi permanente**.

Référence : Alien Head (RoR2, légendaire) a la même formule 0,75ⁿ mais un plancher absolu de 0,5 s, et RoR2 n'offre presque aucune autre réduction de recharge en blanc et vert ([wiki](https://riskofrain2.wiki.gg/wiki/Alien_Head)). Rainfall en offre en commun et peu commun, multiplicatives : c'est la combinaison qui casse.

### 2.2 Cœur de glace (rare)

Code : `stats.slowed_target_damage_add = [0,50, 0,25]` → 0,50 + 0,25 (n − 1), linéaire, **sans plafond**, ajouté à Σadd si `enemy.is_slowed()` (ralenti **ou tenu**). `apply_status(&"slow")` n'exclut pas les boss : **les boss ralentis comptent**.

| Exemplaires | Bonus | DPS (cible ralentie, seul) |
|---|---|---|
| 1 | +50 % | ×1,50 |
| 3 | +100 % | ×2,00 |
| 5 | +150 % | ×2,50 |
| 10 | +275 % | ×3,75 |

Pourquoi il paraît trop fort :

1. **La condition est gratuite** : Givre (peu commun) ralentit à 100 % des coups pendant 2 s, Nova infinie ralentit tout à 6 u, et la plupart des kits ralentissent eux-mêmes (Vigie : Grêle, Chausse-trappes, Filet, Signal sur les boss ; Bourbe : tourbière ; Rainette : glu et bulle ; Averse : trempage ; Tocsin : vapeur et piliers ; Arpenteuse : chaîne). Le temps de présence du ralenti est proche de 100 %, y compris sur les boss.
2. **Premier exemplaire énorme pour un rare** : +50 % en début de run (somme additive encore faible) vaut 5 Pierres à aiguiser.
3. **Linéaire et non plafonné**, puis répercuté sur les poisons et brûlures proportionnels au coup.

Valeur marginale mesurée sur le build moyen de 10 min (voir §3) : **+25 % de DPS** pour 1 exemplaire, le plus haut des trois objets cités.

### 2.3 Œil du prédateur (rare)

Code : `stats.crit_chance = 0,05` en `stat_stack F` (fixe, une fois) et `crit_mult_add = 0,5` linéaire → M = 2 + 0,5 n, **sans plafond**. Facteur de critique moyen = 1 + c (M − 1).

| Exemplaires | M | Seul (c = 6 %) | Avec 3 Lentilles (c = 36 %), gain dû à l'Œil |
|---|---|---|---|
| 1 | ×2,5 | ×1,08 | ×1,17 |
| 3 | ×3,5 | ×1,14 | ×1,45 |
| 5 | ×4,5 | ×1,20 | ×1,72 |
| 10 | ×7,0 | ×1,35 | ×2,41 |

Pourquoi il paraît trop fort :

1. **Il se nourrit de la Lentille aiguisée** (commun, +10 % de chance de critique par exemplaire, linéaire jusqu'à 100 %). Avec 6 Lentilles et 3 Œils : ×2,62 de DPS contre ×1,0 pour 2 Pierres à aiguiser de plus.
2. **Multiplicateur hors de la somme additive** : contrairement aux bonus de dégâts, il ne se dilue jamais.
3. **Il amplifie les procs** : poison (180 à 300 % × n du coup), brûlure du Cristal (50 % du coup) et foudre (80 % du coup) partent du coup critique.

Seul, il est faible (×1,08) : il n'est fort qu'en build critique, ce qui est voulu, mais la pente (+0,5 par exemplaire, sans fin) est trop raide.

### 2.4 Accès : rareté, prix, pitié

- Coffres par étage (`stage_manager.gd`) : 8 petits, 2 grands, 25 % de chance d'un légendaire, plus le coffre du boss. Table d100 : petit 78/20/2, grand 80/18/2, boss 85/15. **Pas de pitié** (`Balance.CHEST_QUALITY_TABLE`, RoR2) ; la Chance (Dé pipé, Faveur du marchand) relance le d100.
- Rares attendus par étage si tout est acheté : 8 × 0,02 + 2 × 0,18 + 0,15 ≈ **0,67**, soit environ 3,3 par run de 5 étages.
- Pool rare au départ : 7 objets débloqués sur 11 ; un coffre propose 2 objets → un rare donné est proposé environ 2 fois sur 7 (pondéré par `OWNED_WEIGHT` 0,6 et `BUILD_TAG_WEIGHT` 1,3).
- Conséquence : en run normale, **1 exemplaire** d'un rare donné est l'issue typique, 2 est chanceux, 3 et plus relève du mode test ou des relances. Le problème ressenti vient donc moins de la fréquence des rares que de **la valeur du premier exemplaire** (Cœur), de **la pente des exemplaires suivants** (les trois) et surtout de **la base commune et peu commune** sur laquelle ils s'appuient (Sabliers et Horloges pour le Chronomètre, Lentilles pour l'Œil, Givre et sorts de kit pour le Cœur).

## 3. Vue d'ensemble

### 3.1 Courbe d'un build moyen (Ardent, mono-cible, modèle)

Hypothèses : ~3,8 min par étage, environ 10 objets achetés par étage + le coffre du boss ; D = coeff de `Balance.difficulty` en temps total ; PV du boss d'étage = `Balance.boss_hp(&"etage", D, étage)`. Le TTK du modèle suppose 100 % de temps sur la cible, sans bouclier ni phase : c'est un plancher.

| Moment | Niveau | Objets (offensifs) | Build offensif | DPS nu | DPS build | Recharge × | Critique | PV boss d'étage | TTK modèle |
|---|---|---|---|---|---|---|---|---|---|
| 5 min (ét. 2) | 9 | ~12 (6) | 2 Pierres, 2 Lentilles, Sablier, Sifflet, Horloge, Lame | 87 | 174 | 0,78 | 21 % | 7 700 | 44 s |
| 10 min (ét. 3) | 13 | ~26 (14) | + Pierre, Lentille, Sablier, Sifflet, Horloge, Rune, Carquois, Danseur | 114 | 474 | 0,61 | 31 % | 15 300 | 32 s |
| 15 min (ét. 4) | 16 | ~38 (22) | + Pierre, Lentille, Sablier, Sifflet, Horloge, Lame, Marque, Chronomètre | 135 | 1 093 | 0,36 | 41 % | 26 400 | 24 s |

Mesure en jeu (balance_sim, objets neutres) : Ardent L12 tue le mini-boss en 10,8 s, Vigie en 14,5 s, pour une cible de 21-30 s (Maths §14). **La courbe joueur dépasse déjà la courbe des boss sans les trois objets cités** : le TTK baisse de 44 à 24 s entre 5 et 15 min alors que la cible est stable (65-75 s pour un boss d'étage). Les objets cités l'aggravent ; les corriger ne suffit pas (voir §6).

### 3.2 Valeur marginale (+1 exemplaire) sur le build de 10 min, contre un boss

| Objet | Rareté | Gain de DPS |
|---|---|---|
| Rafale d'acier | rare | **+36 %** |
| Cœur de glace | rare | **+25 %** |
| Danseur | rare | +20 % |
| Chronomètre brisé | rare | +18 % |
| Œil du prédateur | rare | +18 % |
| Marque du chasseur | peu commun | +15 % (boss et élites) |
| Horloge arcanique | peu commun | +13 % |
| Lentille aiguisée | commun | +8 % |
| Carquois affûté | peu commun | +7 % |
| Lame jumelle | peu commun | +6 % |
| Pierre à aiguiser, Sablier fêlé | commun | +5 % |

### 3.3 Autres objets hors norme

Trop forts :

- **Rafale d'acier** (rare) : +30 % de vitesse d'attaque et un tir triple tous les 4 tirs (+50 % au sort 1) ; meilleur rare de loin dès le premier exemplaire.
- **Venin concentré** (peu commun) : poison de 300 % du coup **+300 % par exemplaire**, 10 % de chance fixe → environ +30 % de DPS par exemplaire, linéaire (+90 % à 3, +150 % à 5), amplifié par critique et Cœur de glace. La limite de 10 cumuls de poison par monstre ne mord pas en mono-cible à cadence normale.
- **Danseur** (rare) : +40 % par exemplaire « en mouvement » ; dans un survivor-like, le joueur bouge 85-95 % du temps, donc bonus quasi inconditionnel et linéaire (même défaut que le Cœur).
- **Bouclier réactif** (rare) : bogue de plancher de recharge (invulnérabilité quasi permanente avec la réduction de recharge, §2.1).
- **Étincelle** (commun) : 10 % de chance par exemplaire (linéaire jusqu'à 100 %) de 240 % du dégât de base ; sur le sort 1 d'Ardent (coef 0,8) cela vaut +30 % du sort 1 par exemplaire, ×2 par Cristal de feu. À surveiller, pas prioritaire (pas de critique ni de bonus additif sur cette brûlure).

Faibles ou inutiles :

- **Givre** au-delà du 1er exemplaire : +2 s de durée inutiles (présence déjà ~100 %).
- **Moisson** (légendaire) : +60 % atteint après 300 kills, environ +25 % marginal, sous la cible légendaire (120 points) et sous Rafale d'acier (rare).
- **Dé pipé** (légendaire) : +1 Chance seulement ; faible pour un légendaire.
- **Sablier fêlé** au-delà de 4 exemplaires et **Antidote** : faible valeur, acceptable pour des communs.

## 4. Incohérences description / code

1. **Bouclier réactif** : « plus vite avec la recharge des sorts » ; le code (`item_effects.gd`, `_charge_time`) applique `cooldown_mult` **sans le plancher** `COOLDOWN_FLOOR`, contrairement à tous les sorts et kits (`Balance.effective_cooldown`). Bogue, à corriger quelle que soit l'option retenue.
2. **Cœur de glace** : « les monstres ralentis » ; le code compte aussi les **boss** et les monstres **tenus** (`_held_left`, Filet, prisons). Le coup qui pose le ralenti n'en profite pas (procs après les dégâts). À écrire dans la description : « monstres et boss ralentis ou immobilisés ».
3. **Nova infinie** : sa brûlure est posée directement par `apply_status` sans `(1 + burn_damage_add)`, alors que Cristal de feu annonce « toutes vos brûlures +100 % ». La brûlure du Phénix d'Ardent l'applique, elle.
4. **Rune de portée** : « +15 % de dégâts aux sorts de zone » sans « par exemplaire », mais le code empile 0,15 × n (linéaire, sans plafond, alors que la taille est plafonnée à +100 %).
5. **Étincelle** : la description ne dit pas que la brûlure est multipliée par le coefficient de proc du sort (Cendres 0,3).
6. **docs/Items_Catalog.md** est périmé pour les trois objets cités (Chronomètre « +70 % L », Cœur « +75 % », Œil « +25 % et ×3 ») et le Dé pipé (« +3 Chance ») ; le JSON fait foi (décision du 26/10), mais l'audit de points du catalogue ne correspond plus au jeu.
7. **docs/Maths_Scaling.md §9** donne encore `Recharge_base / (1 + Σ CDR)` alors que §14 et le code sont multiplicatifs. La recommandation ci-dessous revient à la forme de §9.

## 5. Recommandations

### 5.1 Recharge : passer à la « hâte » additive à rendement décroissant (Recommandé)

Formule : **cooldown_mult = max(1 / (1 + H), COOLDOWN_FLOOR)**, H = Σ hâteᵢ, hâte d'un objet = valeur du JSON (linéaire, ou [premier, suivants]).

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| H | réel | 0 à ~3 (10 Chronos + Horloges + Sabliers) | somme des hâtes |
| COOLDOWN_FLOOR | réel | 0,30-0,40 | recharge minimale (fraction de la base) |
| cooldown_mult | réel | [COOLDOWN_FLOOR, 1] | facteur de recharge, jamais nul ni négatif |

Sortie bornée : H = 0 → 1 ; H → ∞ → plancher. Réduction = 1 − 1/(1 + H), soit exactement la forme hyperbolique 1 − 1/(1 + k·n), mais cumulée **entre tous les objets** (la cadence 1 + H croît linéairement, plus exponentiellement). Exemple : 1 Chronomètre + 3 Horloges + 4 Sabliers → H = 0,35 + 0,45 + 0,40 = 1,20 → 0,455 (au lieu de 0,330).

Mise en œuvre (agents dev) : nouvelle clé `cooldown_haste` dans `items.json` ; `ItemStats.compute` la somme et **produit toujours la clé `cooldown_mult`** (déjà plafonnée), donc aucun consommateur (sorts, Averse, Bourbe, Tocsin, Taliant, Bouclier réactif, HUD) n'a à changer. Retirer `cooldown_mult` de `MULT_KEYS` si plus aucun objet ne l'utilise. Libellé `chest_ui.gd` à ajouter. Les tests `test_balance.gd` qui fixent 0,75ⁿ sont à mettre à jour.

Chronomètre brisé, avant → après :

| Exemplaires | Mult. avant | Mult. après | Réduction avant → après | DPS Ardent avant → après | Remise par élite avant → après |
|---|---|---|---|---|---|
| 1 | 0,750 | 0,741 | 25 % → 26 % | ×1,17 → ×1,18 | 0,5 → 0,5 s |
| 3 | 0,422 | 0,571 | 58 % → 43 % | ×1,71 → ×1,39 | 1,5 → 1,0 s |
| 5 | 0,250 | 0,465 | 75 % → 53 % | ×2,56 → ×1,60 | 2,5 → 1,5 s |
| 10 | 0,250 | 0,350 | 75 % → 65 % | ×2,56 → ×1,96 | 5,0 → 2,75 s |

Sablier fêlé (hâte 0,10) : 0,909 / 0,769 / 0,667 / 0,500 (avant 0,920 / 0,779 / 0,659 / 0,434). Horloge arcanique (hâte 0,15) : 0,870 / 0,690 / 0,571 / 0,400 (avant 0,850 / 0,614 / 0,444 / 0,250).

Le premier exemplaire de chaque objet garde sa valeur actuelle (désirabilité intacte) ; ce sont les cumuls qui ralentissent.

Autres options étudiées :

- **B. Garder le multiplicatif, baisser les valeurs** (Chronomètre −0,18, Horloge −0,10, Sablier −0,06, plancher 0,35) : simple (JSON seul), mais la cadence reste exponentielle jusqu'au plancher ; le plancher devient la seule limite et tout build recharge finit au même point.
- **C. Hyperbolique par objet, multiplicatif entre objets** (`stack: "H"` sur chaque objet) : chaque objet décroît, mais le produit entre objets recompose une cadence exponentielle ; plus confus à expliquer.

### 5.2 Cœur de glace (Recommandé : baisser et plafonner)

`slowed_target_damage_add` [0,50, 0,25] → **[0,35, 0,15]**, plafond **+95 %** (`Balance.ITEM_BONUS_CAPS["slowed_target_damage_add"] = 0,95`, atteint à 5 exemplaires).

| Exemplaires | Avant | Après | DPS (cible ralentie, seul) avant → après |
|---|---|---|---|
| 1 | +50 % | +35 % | ×1,50 → ×1,35 |
| 3 | +100 % | +65 % | ×2,00 → ×1,65 |
| 5 | +150 % | +95 % | ×2,50 → ×1,95 |
| 10 | +275 % | +95 % | ×3,75 → ×1,95 |

Valeur marginale sur le build de 10 min : +25 % → +17 % (au niveau d'Œil et Chronomètre). Option écartée : exclure les boss (illisible, et les kits qui ralentissent les boss perdraient leur synergie annoncée).

### 5.3 Œil du prédateur (Recommandé : premier exemplaire légèrement meilleur seul, pente plus douce, plafond)

`crit_chance` 0,05 → **0,08** (fixe) ; `crit_mult_add` 0,5 linéaire → **[0,40, 0,25]** ; plafond `Balance.ITEM_BONUS_CAPS["crit_mult_add"] = 1,5` (M max ×3,5, atteint à 5 exemplaires).

| Exemplaires | M avant → après | Seul, avant → après | Gain dû à l'Œil avec 3 Lentilles, avant → après |
|---|---|---|---|
| 1 | ×2,5 → ×2,4 | ×1,08 → ×1,11 | ×1,17 → ×1,18 |
| 3 | ×3,5 → ×2,9 | ×1,14 → ×1,16 | ×1,45 → ×1,33 |
| 5 | ×4,5 → ×3,4 | ×1,20 → ×1,20 | ×1,72 → ×1,48 |
| 10 | ×7,0 → ×3,5 | ×1,35 → ×1,21 | ×2,41 → ×1,51 |

Build critique 6 Lentilles + 3 Œils (contre 2 Pierres) : ×2,62 → ×2,29.

### 5.4 Autres objets (Recommandé, priorité moindre)

- **Bouclier réactif** (bogue) : temps de charge = `max(recharge_s × cooldown_mult_plafonné / (1 + 0,5 (n − 1)), recharge_floor_s)` avec `special_data.recharge_floor_s = 1,2`. Avec la hâte, `cooldown_mult` est déjà plafonné ; le plancher absolu protège des cumuls de Boucliers.
- **Rafale d'acier** : `attack_speed` 0,30 → 0,15 et `special_data.every` 4 → 5 (marginal +36 % → +25 %).
- **Venin concentré** : `hit_fraction_stack` 3,0 → 1,5 (1/3/5 exemplaires : +30/+90/+150 % → +30/+60/+90 % de DPS mono-cible, estimé).
- **Danseur** : `moving_damage_add` 0,40 → [0,35, 0,20] (point à trancher avec game-designer : c'est l'objet « kite » de la ligne Givre).
- Faibles (à revaloriser dans un audit suivant, pas ici) : Moisson, Dé pipé, Givre au-delà d'un exemplaire.

### 5.5 Impact estimé sur la courbe

| Moment | DPS build avant → après | TTK modèle boss d'étage avant → après |
|---|---|---|
| 5 min | 174 → 172 (−1 %) | 44 → 45 s |
| 10 min | 474 → 452 (−5 %) | 32 → 34 s |
| 15 min | 1 093 → 921 (−16 %) | 24 → 29 s |

Builds extrêmes : recharge (4 Sabliers, 3 Horloges, 1 Chronomètre) ×2,45 → ×1,91 ; critique (6 Lentilles, 3 Œils) ×2,62 → ×2,29 ; glace (3 Cœurs) ×1,83 → ×1,54 ; combo des trois ×6,6 → ×4,2.

Les changements coupent les pointes (builds spécialisés, empilements) sans toucher le début de run. La courbe moyenne reste au-dessus de la cible des boss : voir §6.

## 6. Risques et points à trancher

- **Courbe globale** : même corrigé, le build moyen de 15 min tue un boss d'étage en ~29 s dans le modèle (cible 65-75 s), et la mesure en jeu donne un mini-boss en 10,8 s au niveau 12 (cible 21-30 s). Les PV de boss baissent par étage (`BOSS_STAGE_K` 0,95) alors que le joueur gagne ~10 objets par étage. À traiter dans un audit dédié (BOSS_STAGE_K, BOSS_BASE_HP), pas par les objets seuls.
- **COOLDOWN_FLOOR 0,25 → 0,35** touche aussi les kits qui l'utilisent via `Balance.effective_cooldown` (Bourbe : mottes, Tocsin, Taliant : durée des Lames jumelles) : vérifier Bourbe et Tocsin au simulateur.
- **Procs sur le coup critique ou bonifié** : poison, brûlure du Cristal et foudre partent du coup final. Option : les calculer sur le coup sans critique. À trancher (le ressenti « gros chiffres de poison » fait partie du plaisir du build).
- **Rafale d'acier** reste le meilleur rare après correction : à surveiller en télémétrie (taux de prise).
- **Perf** : rien de nouveau (aucun proc ajouté) ; la hâte diminue même le nombre de zones simultanées des builds recharge.

## 7. Protocole de vérification en mode test

Réglages communs : mode test (`-- --test-mode`), **Ardent**, **niveau 10** (dégâts de base 33,6), aucun objet au départ, triches « PV illimités » activée, « Recharge 100 % » **désactivée**, D = 1. Poutch de type Normal posé à 2 u du joueur, joueur immobile (sauf test Danseur), « Sorts automatiques » activés. Mesurer le **total du Poutch sur 60 s** divisé par 60 (le DPS 5 s fluctue avec les critiques et la Nova). Référence sans objet (modèle) : **≈ 94 DPS** ; si la mesure diffère, comparer les **rapports** ci-dessous, pas les absolus.

| Changement | Objets à ajouter | Mesure | Attendu avant | Attendu après |
|---|---|---|---|---|
| Hâte, Chronomètre | Chronomètre ×1, puis ×3, ×5, ×10 | Recharge affichée de la Nova (6 s de base) et du Brasier (20 s) ; DPS 60 s | Nova 4,50 / 2,53 / 1,50 / 1,50 s ; Brasier 15,0 / 8,4 / 5,0 / 5,0 s ; DPS ×1,17 / ×1,71 / ×2,56 / ×2,56 | Nova 4,44 / 3,43 / 2,79 / 2,10 s ; Brasier 14,8 / 11,4 / 9,3 / 7,0 s ; DPS ×1,18 / ×1,39 / ×1,60 / ×1,96 |
| Hâte, cumul communs | Sablier ×4 + Horloge ×3 + Chronomètre ×1 | Recharge de la Nova | 1,98 s (×0,33) | 2,73 s (×0,455) |
| Remise par élite | Chronomètre ×3 ; invoquer 5 élites de tier 1, lancer le Brasier puis tuer une élite | Recharge restante du Brasier avant et après le kill | −1,5 s | −1,0 s |
| Bouclier réactif (bogue) | Chronomètre ×5 + Bouclier réactif ×2 ; « PV illimités » désactivé ; 20 monstres de tier 1 autour | Journal des dégâts reçus : intervalle minimal entre deux coups annulés | ≈ 0,54 s (coups presque tous annulés) | ≥ 1,2 s |
| Cœur de glace | Givre ×1 (pour ralentir le Poutch), puis Cœur ×1, ×3, ×5, ×10 | DPS 60 s, rapport au DPS avec Givre seul | ×1,50 / ×2,00 / ×2,50 / ×3,75 | ×1,35 / ×1,65 / ×1,95 / ×1,95 |
| Cœur sur boss | Givre ×1 + Cœur ×1, Poutch de type Boss | Rapport au Poutch Normal | ×1,00 (le bonus s'applique aussi aux boss) | ×1,00 (inchangé, description corrigée) |
| Œil du prédateur | Lentille ×3, puis + Œil ×1, ×3, ×5, ×10 | DPS 60 s, rapport à Lentille ×3 seule | ×1,17 / ×1,45 / ×1,72 / ×2,41 | ×1,18 / ×1,33 / ×1,48 / ×1,51 |
| Œil seul | Œil ×1 (sans Lentille) | Rapport au DPS sans objet | ×1,08 | ×1,11 |
| Rafale d'acier | Rafale ×1 | Rapport au DPS sans objet | ≈ ×1,45 | ≈ ×1,30 |
| Venin concentré | Venin ×3 | Rapport au DPS sans objet | ≈ ×1,90 | ≈ ×1,60 |

Valeurs « attendu » : modèle analytique, non mesurées en jeu ; tolérance ±10 % (variance des critiques et des procs sur 60 s).
