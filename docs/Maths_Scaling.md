# Maths & Scaling v3 : Survivor-like 2D mobile (étages, piliers et zones de charge)

> Tout est calibré avec `simulateur_scaling.py` (modèle « champ moyen »). Ce sont des **points de départ** à valider en playtest.
> Notation : t = minutes de **jeu actif** (la pause, les écrans de coffre et les pubs ne comptent pas), s = numéro d'étage (1, 2, 3, puis sans fin), d = vitesse de scaling du mode, D = coefficient de difficulté, L = niveau du joueur.

---

## 1. Structure d'une run (étages, cartes, piliers)

**3 cartes dessinées à la main** (pas de génération 100 % procédurale). Chaque carte a une grille de **points d'apparition** pour les coffres et les piliers : à chaque étage, la partie tire au hasard les positions parmi ces points (seed sauvegardée). Les 3 cartes tournent dans l'ordre aléatoire d'une run.

### Contenu d'un étage
| Élément | Nombre | Règle |
|---|---|---|
| Petit pilier | 2 | Activation → **mini-boss aléatoire** + **zone de combat** autour du pilier (pas de jauge de charge) |
| Gros pilier | 1 | Activable seulement quand les **deux petits sont terminés**. Activation → **boss d'étage** + **zone de charge (90 s)** |
| Petit coffre | 8 | Posés au sol dès le début de l'étage, payants |
| Grand coffre | 2 | Idem, 2× le prix d'un petit |
| Coffre légendaire | 0-1 (25 % des étages) | 8× le prix d'un petit |
| Coffre du boss d'étage | 1 | Gratuit, apparaît à la mort du boss, qualité Rare ou mieux |

### Règles des piliers
1. **Petits piliers : pas de jauge.** Activer un petit pilier fait apparaître son mini-boss et ouvre une **zone de combat** (la zone reste affichée au sol, avec ×1,5 de monstres dedans). Le pilier est **terminé à la mort du mini-boss**. Si le joueur sort de la zone, les monstres en surplus s'arrêtent d'apparaître mais le boss reste actif.
2. Les deux petits piliers peuvent être activés **en même temps** : deux mini-boss, deux zones (la pression s'additionne). Il faut tuer les deux boss pour débloquer le gros pilier.
3. **Gros pilier : jauge de charge de 90 s**, qui n'avance **que tant que le joueur est dans la zone**. Il est **terminé** quand la zone est chargée **ET** que le boss d'étage est mort.
4. Pilier de boss d'étage terminé : le joueur choisit **rester** (farmer l'or restant pour acheter les coffres encore présents) ou **partir** vers l'étage suivant, où coffres et piliers sont replacés au hasard.
5. **À l'étage 3**, au pilier de boss terminé, nouveau choix : **terminer la partie** (écran de victoire, récompenses) ou **continuer en mode sans fin** (étages 4, 5... avec scaling accéléré, section 2).
6. Il n'y a **plus de boss à heure fixe ni de Fureur** : la pression de fin de partie vient uniquement de la difficulté qui monte avec le temps.

### Durée d'une run (mode Moyen, aucun farm)
| Étages | **Petits sans charge, gros 90 s (retenu)** | Petits 30 s | Petits 45 s | Tous 90 s |
|---|---|---|---|---|
| 2 | **6:53** | 7:17 | 8:10 | 11:10 |
| 3 | **10:04** | 10:52 | 12:15 | 16:45 |

Un étage dure **3:10 à 3:40** : 30 s d'exploration, deux combats de mini-boss (≈ 17-37 s chacun), 2 trajets de 15 s, 90 s pour le gros pilier, 5 s de sortie. Une run en 3 étages dure donc **≈ 10:00** sans farmer (9:35 en Facile, 10:47 en Difficile). Chaque minute passée à farmer s'ajoute. La cible de 7-10 min est atteinte.

## 2. Difficulté progressive (inspirée de RoR2) et modes

> **Remplacé (21/10/2026) par §14 Alignement RoR2** pour les formules de cette section ; le texte ci-dessous est conservé pour l'historique.

```
D(t, s) = (1 + 0.30 × d × t) × 1.15^(s-1)        t = minutes de jeu actif (la pause, les écrans de coffre et les pubs ne comptent pas)
```

Le multiplicateur d'étage s'applique **dès l'entrée dans l'étage** (sinon on retrouve des sauts brusques). La difficulté ne s'arrête jamais de monter.

### Modes de jeu = vitesse de scaling
| Mode | d | D aux 3 boss d'étage (1 / 2 / 3) | D en fin d'étage 3 |
|---|---|---|---|
| Facile | 0.7 | 1.39 / 2.35 / 3.54 | ≈ 4.0 |
| **Moyen** | **1.0** | **1.61 / 2.98 / 4.69** | **≈ 5.3** |
| Difficile | 1.5 | 2.00 / 4.12 / 6.80 | ≈ 7.7 |

Les récompenses en rubis sont multipliées par le mode (×0.8 / ×1 / ×1.3). Les modes plus durs se débloquent en terminant le précédent.

### Mode sans fin (après l'étage 3)
> **Remplacé (§14)** : plus d'accélération sans fin, RoR2 n'en a pas.
Aucune Fureur : le scaling **s'accélère** simplement. À partir de l'étage 4 : pente de temps ×1.5 (`0.45 × d`) et multiplicateur d'étage ×1.25 au lieu de ×1.15. Le joueur ne gagne pas assez vite en puissance et la run se termine naturellement.

### Jauge de difficulté visible (comme RoR2)
| Seuil de D | Nom | Effet audio/visuel |
|---|---|---|
| < 1.5 | Calme | Musique légère |
| 1.5 - 2.5 | Tendu | Percussions |
| 2.5 - 4 | Hostile | Teinte rouge discrète |
| 4 - 6 | Furieux | Ciel sombre, musique intense |
| > 6 | Cataclysme | Écran vibrant, élites plus fréquents |

Chaque monstre affiche un **niveau cosmétique** : `Niv = 1 + floor((D-1) / 0.33)`.

## 3. Director de spawn

> **Remplacé (21/10/2026) par §14 Alignement RoR2** pour les formules de cette section ; le texte ci-dessous est conservé pour l'historique.

```
crédits/s = 4 + 2.5 × D
coût moyen d'un monstre ≈ 1 + 0.5 × (D - 1)
kills/s estimés ≈ crédits/s ÷ coût moyen × 0.85
```
Coûts : tier 1 = 1, tier 2 = 4, tier 3 = 12, élite = 4× le coût de son tier, boss = hors budget.
Apparition des tiers : tier 1 dès 0:00, tier 2 dès D ≥ 1.2 (~0:45), tier 3 dès D ≥ 2 (~3:00).
**Dans une zone de charge active, les crédits du director sont ×1.5** (la zone doit être un moment de pression et de gains).
**Plafond : 250 monstres à l'écran** (mobile milieu de gamme), les crédits excédentaires sont reportés.

Résultat attendu (Moyen) : ≈ 5-7 kills/s ; ≈ 4 000 kills sur une run complète de 10 minutes.

---

## 4. Monstres

> **Remplacé (21/10/2026) par §14 Alignement RoR2** pour les formules de cette section ; le texte ci-dessous est conservé pour l'historique.

### Statistiques
```
PV_monstre     = PV_base × D^1.15
Dégâts_monstre = Dég_base × (1 + 0.30 × (D - 1))
Vitesse        = Vit_base × min(1.30, 1 + 0.02 × (D - 1))
XP_monstre     = XP_base(0.16 pour un tier 1) × D^0.80 × mult_tier
Or_monstre     = 1 × D^1.25 × mult_tier             (arrondi à l'affichage, avec sacs de pièces)
```
Dégâts maximums par coup : 25 % des PV max du joueur (monstre), 40 % (boss). Pas de mort instantanée.

### Archétypes : toujours une attaque automatique + 1 sort OU 1 passif

| Tier | PV base | Dég base | Mult or/XP | Attaque auto | Sort ou passif |
|---|---|---|---|---|---|
| 1 Essaim | 20 | 8 | ×1 | Contact (1 coup/s) | Passif : **Meute** (+15 % vitesse si ≥ 5 alliés à 3 m) ou **Explosion** à la mort (zone télégraphiée) |
| 2 Tireur / Bondisseur | 80 | 12 | ×3 | Projectile (toutes les 2 s) | Sort : **Salve** de 3 projectiles (8 s) ou **Charge** télégraphiée (10 s) |
| 3 Brute | 300 | 30 | ×8 | Coup lourd en cône | Passif : **Carapace** (-40 % dégâts frontaux) ou sort **Onde de choc** (12 s) |

Règle de lisibilité : tout sort à zone est **télégraphié ≥ 0,8 s** (zone rouge au sol), recharge ≥ 8 s.

### Élites et buffs
```
P_élite = clamp(0.05 × (D - 1), 0, 0.25)     // 0 % au départ, ≈ 16 % à D=4.3, plafond 25 %
PV ×3.5   Dégâts ×1.5   Or/XP ×2.5   Coût director ×4
Affixes : 1 affixe ; 2 affixes si D ≥ 4
```

| Affixe | Aura | Effet sur le joueur à chaque coup touché | Contre |
|---|---|---|---|
| **Brûlure** | Orange | DoT = 25 % du coup sur 3 s (tick 0,5 s), se rafraîchit, ne se cumule pas | Items de résistance au feu, bouclier |
| **Ralentissement** | Bleue | -30 % de vitesse pendant 1,5 s, plancher -50 % total, immunité 2 s ensuite (pas de stun-lock) | Bottes, passifs de mobilité |
| **Poison** | Verte | Cumulable jusqu'à 5 : chaque cumul = 8 % du coup/s pendant 4 s, et -50 % de régénération | Antidote (réduit les dégâts de brûlure et de poison subis), soin |

Ces trois statuts existent aussi côté joueur : des items et variantes de sorts peuvent brûler, ralentir ou empoisonner les monstres, ce qui crée des synergies lisibles. Les coefficients diffèrent selon le sens, car les ennemis frappent bien plus souvent que le joueur ne touche chaque cible :

| Statut | Subi par le joueur (élites) | Infligé aux monstres (items) |
|---|---|---|
| Brûlure | 25 % du coup sur 3 s | 100 % du coup sur 3 s, non cumulable |
| Poison | 8 % du coup/s pendant 4 s par cumul (5 max) | 20 % du coup/s pendant 4 s par cumul (5 max) |
| Ralentissement | -30 % pendant 1,5 s, puis 2 s d'immunité | Flocon -30 % pendant 1,5 s ; Givre -40 % pendant 2 s |

---

## 5. Boss

> **Remplacé (21/10/2026) par §14 Alignement RoR2** pour les formules de cette section ; le texte ci-dessous est conservé pour l'historique.

```
PV_boss = base × D^1.6        bases : mini-boss 1 300 / boss d'étage 2 200
```
L'exposant est plus fort que celui des monstres (1.15), car la puissance du joueur (DPS) monte plus vite que D. Dégâts maximums par coup : 40 % des PV max du joueur. Le boss reste une cible mobile : le DPS réel est inférieur à l'estimation ci-dessous, donc le combat dure un peu plus.

### Réserve de mini-boss et boss d'étage
- **Mini-boss** (tirage aléatoire parmi 6 au lancement) : Colosse de pierre, Reine des ronces, Seigneur des cendres, Ours de givre, Essaim-mère, Archonte rouillé.
- **Boss d'étage** (1 par carte, spécifique) : 3 au lancement.
- Structure : attaque auto + 2 sorts + passif de phase (à valider). Phases à 70 % et 35 % pour les boss d'étage. **Enrage** au-delà de 60 s de combat : +1,5 %/s de dégâts (ce n'est pas la Fureur : elle ne concerne que le boss en combat).

### Combats simulés (Moyen)
| Étage | Pilier | Activation | D | PV | DPS joueur | Combat |
|---|---|---|---|---|---|---|
| 1 | Mini A | 0:30 | 1.15 | 1 626 | 44 | 37 s |
| 1 | Mini B | 1:22 | 1.41 | 2 253 | 88 | 26 s |
| 1 | Boss d'étage | 2:03 | 1.61 | 4 737 | 122 | 39 s |
| 2 | Mini A | 4:08 | 2.58 | 5 908 | 297 | 20 s |
| 2 | Mini B | 4:43 | 2.78 | 6 664 | 343 | 19 s |
| 2 | Boss d'étage | 5:18 | 2.98 | 12 613 | 422 | 30 s |
| 3 | Mini A | 7:23 | 4.25 | 13 172 | 724 | 18 s |
| 3 | Mini B | 7:57 | 4.48 | 14 304 | 849 | 17 s |
| 3 | Boss d'étage | 8:29 | 4.69 | 26 064 | 939 | 28 s |

Les combats de boss durent 17 à 39 s en Moyen (jusqu'à 49 s en Difficile), toujours moins que les 90 s de charge du gros pilier. Pour le boss d'étage, le joueur doit **tenir la zone** contre les vagues (×1.5 crédits) après la mort du boss ; pour un mini-boss, la pression vient de la zone active pendant le combat.

**Récompenses** : mini-boss = primes d'or (100 × D^1.25) et d'XP (équivalent 40 kills tier 1). Boss d'étage = prime (250 or, 100 XP) + **coffre gratuit Rare+** (90 % Rare / 10 % Légendaire).

## 6. Joueur

```
PV_max(L)        = 100 + 30 × (L - 1)
Dégât_base(L)    = 12 + 2.4 × (L - 1)
Régénération(L)  = 0.5 + 0.1 × (L - 1) PV/s
Armure           : réduction = Armure / (Armure + 100)
XP_niveau_suivant(L) = 10 + 8L + 0.5 L²
```

| L | XP requis | XP cumulé |
|---|---|---|
| 1 | 18.5 | 18.5 |
| 5 | 62.5 | ≈ 198 |
| 10 | 140 | ≈ 733 |
| 15 | 242.5 | ≈ 1 730 |
| 20 | 370 | ≈ 3 315 |

**Niveaux visés (Moyen)** : 6 à 2:30, 10 à 5:00, 14 à 7:30, 19 à 10:00, ≈ 19 à 10:04. Chaque montée de niveau donne les stats automatiquement (les choix de build viennent des coffres).

### Vitesses (déplacement, attaque, projectile)

```
Vitesse de déplacement : base 4.0 u/s (1 u = taille du joueur) ; bonus total des items plafonné à +10 % (≈ 4.4 u/s)
Vitesse d'attaque (sort 1) : Intervalle = Intervalle_base / (1 + Σ vitesse d'attaque)   Σ plafonnée à +200 % (×3 : 0.6 s -> 0.2 s)
Vitesse de projectile  : base 12 u/s ; bonus cumulé plafonné à +100 % (×2, soit 24 u/s)
```

- **Courir à fond sans problème** : un monstre de tier 1 va à 2.5 u/s, au maximum 3.25 u/s à force de D (×1.30). Le joueur à 4.0 u/s n'est donc jamais rattrapé par la foule normale. Les items ne donnent que +10 % de vitesse au total et **aucun item ne ralentit le joueur** (l'Armure du colosse n'a plus de malus de vitesse). Seuls restent les ralentissements des élites (-30 % pendant 1,5 s, immunité 2 s ensuite).
- **Vitesse d'attaque** : le sort 1 pèse ≈ 43 % du DPS mono-cible (coef 0.8 toutes les 0.6 s = 1.33 sur 3.08). +12 % de vitesse d'attaque = ≈ +5 % de DPS total, plus +12 % de chances de déclencher brûlure, ralentissement et poison, qui se déclenchent à chaque coup.
- **Vitesse de projectile** : n'ajoute pas de dégâts bruts, mais augmente le taux de touche sur les monstres rapides et réduit le délai de réaction. D'où des valeurs modestes et un plafond ×2 pour que le tir reste lisible.

### Que vaut +20 PV ? (verdict : trop faible et ça se déprécie)

| Moment | Niveau | PV max | +20 PV en % | Coups de contact tier 1 absorbés |
|---|---|---|---|---|
| 1:00 | 3 | 160 | 12,5 % | 2,3 |
| 2:30 | 5 | 220 | 9,1 % | 2,0 |
| 5:00 | 9 | 340 | 5,9 % | 1,6 |
| 7:30 | 13 | 460 | 4,3 % | 1,3 |
| 9:00 | 15 | 520 | 3,8 % | 1,2 |

- +20 PV équivaut à **0,67 niveau** (un niveau donne +30 PV) : à mi-run, c'est un item qu'on ne remarque pas.
- Les dégâts des monstres montent (coup de contact tier 1 : 8 au départ, ≈ 16 à 7:30), donc un montant fixe de PV perd de la valeur.
- Comparaison : une régénération de +0,4 PV/s rend 24 PV par minute, soit plus qu'une Bague de +20 PV sur le reste de la run.
- **Décision** : tous les items de survie passent en pourcentage (PV max, dégâts reçus) ou en armure pour suivre le scaling. Un Commun vaut ≈ 10 points de puissance effective (voir section 9, audit des items) :

| Item | Avant | Après | Gain en PV effectifs |
|---|---|---|---|
| Bague de vigueur | +20 PV max | **+10 % PV max (minimum +15)** | ≈ +22 PV à L5, +46 à L13 (10 % à tout moment) |
| Amulette de cuir | +5 armure (≈ 5 %) | **+10 armure** | ≈ 10 % |
| Pavois fêlé | -3 % dégâts reçus (≈ 3,1 %) | **-9 %** | ≈ 9,9 % |
| Cœur de mousse | +0,4 PV/s (valeur divisée par 2 entre 2:30 et 7:30) | **+0,45 % des PV max par seconde** | ≈ 10 points à tout moment |
| Antidote | Durée des poisons subis -20 % | **Dégâts de brûlure et de poison subis -40 %** | ≈ 11 points (en supposant 25 % des dégâts subis venant de ces statuts) |

### Dégâts d'un sort
```
Dégâts = Coef_sort × Dégât_base(L) × (1 + Σ bonus_additifs) × Π (1 + bonus_multiplicatifs) × Crit
Crit   : 5 % de chance de base, ×2
```

---

## 7. Économie

> **Remplacé (21/10/2026) par §14 Alignement RoR2** pour les formules de cette section ; le texte ci-dessous est conservé pour l'historique.

### Or (monnaie de run)
Les coffres sont posés au début de l'étage avec un **prix évalué à l'achat** (donc le prix monte tant qu'on attend) :

```
Prix = Base × D^1.25 × (1 + 0.30 × (D - 1)) × 1.05^(s-1)
```
Les deux premiers facteurs suivent exactement l'or gagné par kill, donc un petit coffre vaut toujours le même nombre de kills ; le dernier facteur ajoute un petit surcoût par étage (+5 %).

| Coffre | Base | Par étage | Contenu |
|---|---|---|---|
| Petit | **150** | 8 | Table petit coffre |
| Large | **300** (2×) | 2 | 80 % Peu commun / 20 % Rare |
| Légendaire | **1 200** (8×) | 0-1 (25 %) | 100 % Légendaire |
| Boss d'étage | gratuit | 1 | Rare+ (90 % / 10 %) |

**Simulation (Moyen, chemin direct sans farmer)** : premier achat vers 0:30 ; **9 / 8 / 8 coffres sur 10** par étage. Farmer 45 s après le boss d'étage permet d'en acheter 1 de plus aux étages 1 et 2 (10 et 9 sur 10) et ajoute 2:15 à la run : un vrai choix.
Items par run (3 étages, sans farm) : **≈ 28** (25 petits/grands coffres, 3 coffres de boss), 30 avec farm.

### Or excédentaire
Selon le mode, il reste 300 à 6 800 d'or en fin d'étage (surtout aux étages 2 et 3 en Difficile). Débouchés :
- **Relance de coffre à l'or** : `0.6 × prix du coffre × 1.5^n`
- **Sanctuaire de risque**, **marchand de l'ombre**
- **Fin de run** : 1 rubis par 500 or (max 20)
- **Budget d'or des monstres (jeu, retour joueur « 2 700 or en trop en fin d'étage »)** : les coffres du jeu coûtent le tiers du doc (prix figé au début de l'étage) alors que le director garde les crédits du doc ; après la rampe de début, l'or des kills déborde. Réserve par étage, en prix P d'un petit coffre de l'étage : pleine à 4 P au début, +1,75 P par minute de jeu actif ; l'or d'un kill est pris dans la réserve, au-delà seulement 5 %. Primes de boss : 100 / 250 × D^1.25 × 0.25. Étage 1 de 5:00 (`tests/economy_test.gd`) : or des monstres 68 / 282 / 454 / 574 / 712 à 1-5 min (sans budget : 68 / 282 / 710 / 1 453 / 2 547), reliquat ≈ 600 après les 10 coffres au lieu de ≈ 3 300 (`Balance.MONSTER_GOLD_BUDGET_*`, `BOSS_GOLD_MULT`).
- **Changement d'étage** (comme Risk of Rain) : l'or restant, bourse **et** pièces non ramassées au sol, est converti en XP puis remis à 0 : `XP = 0.5 × or × XP_monstre(D, 1) / Or_monstre(D, 1) = 0.5 × or × XP_BASE × D^-0.45` (D de l'étage qui se termine), soit la moitié de l'XP des kills qui ont rapporté cet or. Fin d'étage 1 du simulateur (470 or, D 2.09) : ≈ 27 XP avec XP_BASE 0.16 (≈ ¼ de niveau), ≈ 108 XP avec l'XP_BASE du jeu (0.64, ≈ 1 niveau). La moitié seulement : acheter des coffres reste plus rentable que garder son or (`Balance.GOLD_TO_XP_SHARE`).

### Rubis (méta-monnaie, jamais vendue contre de l'argent réel)
```
Rubis_fin_de_run = floor(1.2 × minutes × multiplicateur_mode) + 8 par pilier terminé + 25 si victoire + bonus_or_restant
```
Une run terminée à 3 étages en Moyen ≈ 12 + 72 + 25 + 15 ≈ **125 rubis**. Raccourci de déblocage : ≈ 400 rubis (3 runs). À recalibrer vu la durée de run.

## 8. Loot par dés

### Étape 1 : dé de qualité (d100) pour un petit coffre

| d100 | Qualité | Probabilité |
|---|---|---|
| 1-60 | Commun | 60 % |
| 61-92 | Peu commun | 32 % |
| 93-99 | Rare | 7 % |
| 100 | Légendaire | 1 % |

Chance (Luck) : chaque point relance le d100 et garde le meilleur résultat.

### Étape 2 : deux items distincts
```
Item_A = tirage uniforme dans Table[qualité]
Item_B = tirage uniforme dans Table[qualité] \ {Item_A}
```
Un item déjà possédé pèse ×0.6, un item qui complète un tag du build ×1.3 (tags visibles sur les cartes).

### Relance : même qualité, nouveaux items
Le dé de qualité n'est **jamais relancé** : seule la sélection des 2 items change.
```
Relance = 2 nouveaux items tirés dans Table[qualité déjà obtenue] \ {items déjà montrés pour ce coffre}
(si la table restante contient moins de 2 items, on autorise les doublons)
```
- **Relance par pub** : 1 par coffre, **3 par run maximum**. Elle est offerte sans pub aux joueurs ayant acheté « Sans pub » (même plafond).
- **Relance à l'or** : voir section 7 (indépendante du compteur de pubs).
- Effet : pour un item précis voulu dans une table de 10 (Rare), la probabilité de le voir passe de 20 % (2 cartes) à 40 % (4 cartes).

### Protection contre la malchance (pity)
> **Remplacé (§14.1, alignement RoR2)** : le pity est supprimé, la Chance (relances du d100) est le seul levier.
```
Poids Rare+ (petit coffre) = 8 % + 2 % × compteur_pity ; le compteur se remet à 0 à chaque Rare+
```
Probabilité d'au moins un Rare+ sur les 9 premiers petits coffres : **≈ 53 %** sans pity, **≈ 79 %** avec pity. Les 3 boss d'étage garantissent 3 items Rare+, donc le pity sert surtout à éviter les débuts de run vides.

**Répartition attendue d'une run** (≈ 28 items) : ≈ 11 Communs, ≈ 10 Peu communs, ≈ 5 Rares, ≈ 1-2 Légendaires.

### Taille des tables au lancement

| Qualité | Items | Puissance cible relative |
|---|---|---|
| Commun | 17 | 1 |
| Peu commun | 16 | ≈ 2.2 |
| Rare | 11 | ≈ 5 |
| Légendaire | 6 | ≈ 12 |

Total : **50 items** (46 + 4 items de vitesse d'attaque et de projectile).

---

## 9. Empilement des items et recharges

| Type | Formule (n exemplaires) | Exemple |
|---|---|---|
| Linéaire | a × n | +10 % dégâts par exemplaire |
| Hyperbolique | 1 - 1 / (1 + a × n) | Esquive, réduction de dégâts reçus, réduction des dégâts de brûlure et de poison |
| Exponentiel (Rare/Légendaire) | (1 + a)^n - 1 | ×1.15 dégâts par exemplaire |

```
Recharge_effective = Recharge_base / (1 + Σ CDR)       plancher : 25 % de la recharge de base
Intervalle_auto    = Intervalle_base / (1 + Σ vitesse d'attaque)   Σ plafonnée à +200 % (intervalle ≥ 0.2 s pour 0.6 s de base)
Vitesse_projectile = Vitesse_base × (1 + Σ bonus)               Σ plafonnée à +100 %
Vitesse_déplacement = Base × (1 + Σ bonus)                      Σ plafonnée à +10 % (tous items confondus)
```
Pas de mana : seules les recharges limitent les sorts.

### Audit de valeur des items (le scaling de chaque item)

Chaque item est converti en **points de puissance effective** (1 point = +1 % de DPS ou de PV effectifs) avec les formules du jeu, puis comparé à une cible par qualité :

| Qualité | Poids | Cible (points) |
|---|---|---|
| Commun | 1 | 10 |
| Peu commun | 2,2 | 22 |
| Rare | 5 | 50 |
| Légendaire | 12 | 120 |

- **Calibrage** : le simulateur donne +208 % de puissance avec les 11 items achetés avant 7:30, soit ≈ 9,7 points par poids de qualité.
- **Parts de DPS** (section 10) : sort 1 ≈ 43 %, sorts à recharge ≈ 57 %, sorts de zone ≈ 32 %. Donc +x % de vitesse d'attaque = 0,43 x points, +x % de vitesse de recharge = 0,57 x points, +x % de dégâts = x points.
- **Défense** : PV max +x % = x points ; armure A = A points ; réduction de dégâts r = 1/(1 - r) - 1 ; soins = 100 × PV/s rendus / dégâts subis par seconde (4,4 % des PV max/s).
- **Zone** : les effets de zone sont multipliés par ≈ 2,5 (moitié du temps en foule, ≈ 4 ennemis touchés).
- **Stabilité dans le temps** : chaque item est évalué à 2:30, 5:00 et 7:30. Les soins sont donc exprimés en % des PV max et les dégâts d'items en % du coup (ils suivent le scaling) ; un montant fixe perdrait la moitié de sa valeur entre 2:30 et 7:30.
- **Résultat** : 50 items sur 50 à ±20 % de leur cible et stables (valeur à 7:30 entre 0,67 et 1,5 fois celle à 2:30). Détail et formules : `Items_Catalog.xlsx` (onglets Audit et Modèle) et `Items_Catalog.md`.

Quelques corrections faites par l'audit : Lame jumelle +50 % de dégâts du sort 1 (au lieu de +15 %), Sablier +18 % de vitesse de recharge, Sifflet +22 % de vitesse d'attaque, brûlure à 100 % du coup sur 3 s et poison à 20 %/s côté monstres, Couronne d'écho à 3 répétitions, Cœur du chronomancien avec délai interne de 2 s, Moisson jusqu'à +120 %, Bourse du pillard remplacée par Morsure vorace, Armure du colosse sans malus de vitesse.

---

## 10. Sorts, variantes et emplacements

| Slot | Type | Règle |
|---|---|---|
| 1 | Sort automatique | Verrouillé |
| 2 | Sort à recharge | Verrouillé |
| 3 | Sort à recharge ou passif | Selon le personnage |
| 4 | Sort à recharge ou passif | Selon le personnage |

Configurations : 4 sorts / 0 passif, 3 sorts + 1 passif, 2 sorts + 2 passifs. **2 variantes par emplacement, soit 8 options maximum par personnage.**

| Type de sort | Coef | Recharge de base | Rôle |
|---|---|---|---|
| Auto projectile | 0.8 | 0.6 s | Dégâts continus |
| Auto zone | 0.5 / tick | 0.5 s | Nettoyage de foule |
| CD zone | 3.0 | 6 s | Burst de zone |
| CD mono-cible | 6.0 | 8 s | Boss, élites |
| CD mobilité / défense | 1.0 + effet | 7 s | Esquive, bouclier |
| Ultime (slot 4) | 10.0 | 20 s | Moment fort |

Le DPS mono-cible du simulateur suppose : `3.08 × Dégât_base(L) × (1 + 0.12 × items) × (1 + 0.03 × items)`.

---

## 11. Courbe de puissance cible (ratio puissance joueur / pression ennemie)

| Moment | Ratio cible | Sensation |
|---|---|---|
| Étage 1, avant le 1er pilier | 0.6-0.8 | Prudence, premier coffre à ≈ 0:40 |
| Étage 1, zones et boss | 1.0 | Les zones sont difficiles à tenir |
| Début d'étage 2 et 3 | 0.9 | Le saut ×1.15 de D rappelle au joueur de se renforcer |
| Fin d'étage 2 et 3 | 1.3-1.8 | Power fantasy |
| Boss d'étage | 1.0-1.2 | Tension maximale |
| Sans fin | < 0.8 | Fin naturelle après 2-4 étages |

## 12. Résultats du simulateur (Moyen)

| t | D | Kills cumulés | Niveau | Items | DPS mono estimé |
|---|---|---|---|---|---|
| 2:30 | 1.74 | 1 039 | 6 | 6 | 150 |
| 5:00 | 2.87 | 2 046 | 10 | 13 | 368 |
| 7:30 | 4.29 | 3 013 | 14 | 21 | 763 |
| 10:00 | 5.28 | 3 996 | 19 | 28 | 1 364 |

Selon le mode (3 étages, farm 0) : Facile 9:35, niveau 16, 28 items ; Moyen 10:04, niveau 19, 28 items ; Difficile 10:47, niveau 23, 28 items.

Note : les repères intègrent les sauts ×1.15 d'entrée d'étage (à 3:38 et 6:53).

À relancer : `python3 simulateur_scaling.py facile|moyen|difficile`.

## 13. Plan de calibration

1. Valider d'abord les **exposants** (D^1.15 / 0.80 / 1.25 / boss 1.6), puis la pente 0.30 et la durée de charge, puis les coefficients de sorts et les tables d'items.
2. Playtests : temps de survie médian par mode. Cible : **≈ 70 % de victoires en Facile, ≈ 50 % en Moyen, ≈ 25 % en Difficile**.
3. Télémétrie : étage et pilier de la mort, boss qui tue le plus, taux de farm après boss, items jamais choisis, usage des relances (pub et or), part des joueurs qui continuent en sans fin.
4. Test de performance : 250 monstres + 15 projectiles + 2 zones de charge à l'écran sur Android d'entrée de gamme (60 FPS, minimum 40).

## Points à trancher
- **Durée de run** : retenu petits piliers sans charge + gros pilier 90 s, ≈ 3:10-3:40 par étage, ≈ 10:00 pour 3 étages sans farm.
- La charge n'avance-t-elle que dans la zone (hypothèse retenue) ?
- Récompense des mini-boss (or/XP seulement) et coffre gratuit du boss d'étage (ajout de ma part).

## 14. Alignement RoR2 (phase 2, validée par le joueur le 21/10/2026)
Sources (wiki Risk of Rain 2) : [Difficulty](https://riskofrain2.wiki.gg/wiki/Difficulty), [Directors](https://riskofrain2.wiki.gg/wiki/Directors), [Level](https://riskofrain2.wiki.gg/wiki/Level), [Armor](https://riskofrain2.wiki.gg/wiki/Armor), [Lemurian](https://riskofrain2.wiki.gg/wiki/Lemurian) (croissance par niveau), [Chests](https://riskofrain2.wiki.gg/wiki/Chests), [Teleporter](https://riskofrain2.wiki.gg/wiki/Teleporter).
Calibration : simulation `sim_ror2.py` / `phase2_calib.py` (director actuel : rampe 240 s, vivants 8→150 en 480 s). Code : `game/scripts/core/balance.gd`, tests `test_balance.gd` et `economy_test.gd`.
Hors périmètre (migration isométrique, docs/Design_Isometrique.md) : vitesses ×3,5, paquets de 3-8, plafond de 60 vivants, intervalles de vagues.

| Grandeur | Formule appliquée | Remplace |
|---|---|---|
| Coeff de difficulté | (1 + min × 0,0506 × diff × 1,5) × 1,15^(étage-1) ; diff Facile 1 / Moyen 2 / Difficile 3 ; ×1,5 = étage de 5 min ≈ étage RoR2 de 7,5 min | 1 + 0,30 × mode × min, modes 0,7/1/1,5, accélération sans fin dès l'étage 4 |
| Niveau ambiant | 1 + ⌊(coeff - 1) / 0,33⌋ | — |
| PV / dégâts des monstres | base × (1 + 0,30 (niv-1)) / base × (1 + 0,20 (niv-1)) ; bases 18/5, 80/10, 300/24 | D^1,15 ; 1 + 0,3 (D-1) ; bases 20/6, 80/12, 300/30 |
| Élites | PV ×4, dégâts ×2, coût ×6 (prime ∝ coût) | ×3,5 / ×1,5 / coût ×4 / prime ×2,5 |
| Crédits du director | 0,894 × (1 + 0,4 coeff) ; zone de mini-boss ×1,5, charge du téléporteur ×2,33 | 4 + 2,5 D, zone ×1,5 |
| Coût moyen visé | 1 + 0,4 (coeff - 1) (rythme de kills décroissant, comme RoR2) | pente 1,0 |
| Prime d'un kill | or = 2 × coeff × coût × 0,235 ; XP = coeff × coût × 0,235 (RoR2 : R = 0,2) | D^1,25 × reward + réserve d'or par étage (supprimée) |
| Boss | PV = base (mini 1000, étage 3300) × facteur de focus (mini 0,55, étage 0,5) × (1 + 0,3 (niv-1)) × √coeff × BOSS_STAGE_K^(étage-1) avec BOSS_STAGE_K = 1,0 (était 0,95, puis 1,20) ; boss final = PV du boss d'étage 5 × 1,35 (était 1,55) ; Idole noyée × 0,7 (était 0,9) ;  dégâts 20/28 × (1 + 0,2 (niv-1)) ; enrage après 90 s | 1300/2200 × D^1,6 ; 25/35 ; enrage 60 s |
| Prime de boss | or = 2 × coeff × valeur (mini 25, étage 60) × 0,235 ; XP = ½ or | 100/250 kills × 0,25 × D^1,25 ; XP 40/100 kills |
| Coffres | base × coeff^1,25 × 1,04^(étage-1) ; 50 / 100 / 400 (légendaire ×8, arbitrage joueur) | × (1 + 0,3 (D-1)) en plus, 1,05/étage |
| Capsules | 20 × coeff^1,25 chacune (10 = 200 or à coeff 1) | 0,4 × petit coffre |
| Or → XP (fin d'étage) | 0,25 XP par or | 0,5 × ratio XP/or des kills |
| Niveau du joueur | niveau = 1 + log1,55(1 + 0,076 × XP) ; XP du niveau L = 0,55 / 0,076 × 1,55^(L-1) (RoR2 : 0,0275) | 10 + 8 L + 0,5 L² |
| Joueur | PV 100 + 30/niv, dégâts 12 + 2,4/niv, régén 1 + 0,2/niv (déjà RoR2, inchangés) | — |

Résultats visés (simulation, Moyen) : reliquat de fin d'étage 1 ≈ +30 or, niveau ≈ 7,5, boss d'étage 65-75 s, mini-boss 21-30 s, kills 1,2/s → 0,66/s sur 5 étages. `economy_test` (modèle simplifié, sans plafond de vivants) : reliquat +13, niveau 7.

### 14.0 Facteur de focus des boss (audit du 31/10/2026)
Les PV de base des boss (mini 1000, étage 3300) visaient 65-75 s de combat en supposant que 100 % des dégâts du joueur touchent le boss. Les runs complètes simulées (docs/Audit_Runs_Completes_2026-10-31.md) montrent qu'en jeu seuls 36 à 50 % des dégâts l'atteignent : les monstres de la charge, plus proches, absorbent la visée automatique et les zones et procs se dispersent. Le facteur de focus `BOSS_FOCUS_HP_MULT` (mini 0,55, étage 0,5) corrige ce biais dans `Balance.boss_hp` pour retrouver les durées visées : mini-boss 21-30 s, boss d'étage 65-75 s, boss final 120-150 s (médiane de six personnages, rencontres ciblées). Réglages liés : `BOSS_STAGE_K` 1,20 → 1,0 (le rapport PV / DPS ne dérive plus aux étages 4-5), `FINAL_BOSS_HP_MULT` 1,55 → 1,35, `BOSS_HP_MULT` de l'Idole noyée 0,9 → 0,7, et `BOSS_AIM_PRIORITY` 2,0 (la visée automatique préfère les boss, ce qui réduit le TTK de 10 à 25 %). Formule : `PV = base × focus × (1 + 0,30 (niv-1)) × √D × BOSS_STAGE_K^(étage-1)`.

### 14.1 Items (alignement RoR2)
Sources : [Item Stacking](https://riskofrain2.wiki.gg/wiki/Item_Stacking), [Proc Coefficient](https://riskofrain2.wiki.gg/wiki/Proc_Coefficient), [Items](https://riskofrain2.wiki.gg/wiki/Items) et pages par objet (Tri-Tip Dagger, Tougher Times, Alien Head, Ukulele, Ignition Tank, Razorwire, Bison Steak…). Valeurs par objet : `game/data/items.json` ; code : `game/scripts/items/item_stats.gd`, `spell_caster.gd` (`_roll_procs`), `enemy.gd` (`apply_status`), `player.gd`.

| Règle | Appliqué | Remplace |
|---|---|---|
| Hyperbolique (H) | 1 − 1/(1 + a·n), a = coefficient RoR2 (Pavois 0,15 → 13 % à 1 exemplaire) | a converti en v/(1 − v) |
| Exponentiel (E) | (1 + a)ⁿ − 1, réservé à la recharge (a < 0) et aux malus (Colosse ×0,9ⁿ) | aussi sur des bonus (Colosse PV 1,6ⁿ) |
| Stacking par stat | `stat_stack` {clé: type} ; stat [premier, suivants] = premier + suivants × (n − 1) | un seul type par item |
| Recharge | multiplicative : cd = base × Π(1 + aᵢ)ⁿⁱ (Sablier ×0,92ⁿ, Horloge ×0,85ⁿ, Chronomètre ×0,75ⁿ), plancher 25 % de la base | base / (1 + Σ cdr) |
| Critique | base 1 % ; multiplicateur 2 + Σ `crit_mult_add` (Œil : +0,5 par exemplaire, +5 % de crit une fois) | base 5 % ; Œil ×3 en remplacement |
| Procs | un proc par item (plus de fusion), chance L min(1, c·n) / H / F fixe, × proc coefficient du sort (Cendres 0,3, autres 1) | 1 − (1 − c)ⁿ, fusion des procs identiques |
| Brûlure | cumulable (Tri-Tip) : total = 240 % du dégât de base × PC (Étincelle) ou 50 % du coup (Cristal), × (1 + 100 % par Cristal) (Ignition Tank), sur 3 s | non cumulable, 100 % du coup |
| Poison | cumulable, total = 180 % du coup (Fiole), 300 % × n (Venin), sur 4 s ; 10 cumuls max par monstre | 20 % du coup/s, 5 cumuls |
| Ralentissement | Flocon H 0,15 × PC, −30 % 1,5 s ; Givre à chaque coup, −40 % 2 s (+2 s/exemplaire) | clés `slow_fraction` ignorées (bug) |
| Foudre | Ukulele : 25 % × PC, 80 % du coup sur 3 + 2(n − 1) cibles | 3 cibles × 50 % |
| Épines | Razorwire : 160 % du dégât de base sur 5 + 2(n − 1) ennemis à 6 u, 1 fois / 0,5 s | 70 % du sort 1 sur l'attaquant |
| PV / régén | PV plats (Bague +25, Tonique +40) ; régén plate × (1 + 0,2 (niv − 1)) (Cœur de mousse +1, Tonique +1,6) | % des PV max |
| Plafonds | déplacement +35 %, vitesse d'attaque +200 %, projectile +100 %, zone +100 %, XP +100 %, portée +50 %, ramassage +200 %, traversées 5, blocage 75 % | déplacement +10 %, pas d'autres plafonds |
| Coffres (d100) | petit 78/20/2 (C/PC/R) ; grand 80/18/2 (PC/R/L) ; boss 85/15 (PC/R) ; légendaire 100 L. Pas de pity, la Chance (relances) est le seul levier | 60/32/7/1 + pity 8 % + 2 %/coffre ; 80/20 ; 90/10 R/L |

Bugs corrigés : Faveur du marchand (H avec a = 1 → Chance 0,99 tronquée à 0 ; désormais +1 par exemplaire), ralentissements qui ignoraient les valeurs des items, brûlure et poison qui ignoraient `hit_fraction`/`duration`, Sang chaud (texte « sous 50 % » aligné sur le code : 35 %, +40 %), fusion des chances des procs identiques.
Non implémentés (inchangés, à reprendre avec leur `special`) : Orbe de veille, Bouclier réactif, Phénix, Tempête de braises, Peste vivante, Aimant d'âme (aspiration), Rafale d'acier (tir triple), Couronne d'écho, Nova infinie, Moisson, Cœur du chronomancien, Pièce (soin), Pointe perforante (70 % sur les cibles suivantes), plafond de soin de Morsure vorace (1 %/s proposé).

