# Catalogue d'items v3 : 50 items audités sur les maths du jeu

> Généré à partir du même modèle que `Items_Catalog.xlsx` (onglets Audit et Modèle). Les valeurs sont des points de départ à calibrer en playtest.

**Plafonds** : vitesse de déplacement des items +10 % au total (aucun item ne ralentit le joueur) ; vitesse d'attaque du sort 1 +200 % (×3) ; vitesse de projectile +100 % (×2) ; recharge minimale 25 % de la base.

**Stacking** : L = linéaire (a × n), H = hyperbolique (1 - 1 / (1 + a × n)), E = exponentiel ((1 + a)^n - 1), F = effet fixe. La valeur de l'audit est celle d'un seul exemplaire.

**Statuts**
- Infligés aux monstres par les items du joueur : Brûlure = 100 % du coup sur 3 s (non cumulable) ; Poison = 20 % du coup par seconde pendant 4 s par cumul (5 max) ; Ralentissement = Flocon -30 % pendant 1,5 s, Givre -40 % pendant 2 s.
- Subis par le joueur (affixes d'élites) : Brûlure = 25 % du coup sur 3 s ; Poison = 8 % du coup par seconde pendant 4 s par cumul (5 max, régénération -50 %) ; Ralentissement = -30 % pendant 1,5 s, puis 2 s d'immunité.
- Les ennemis frappent bien plus souvent que le joueur ne touche chaque cible : d'où des coefficients plus faibles côté joueur.

---

## 1. Méthode d'audit : chaque item doit « valoir » la même chose que sa qualité

Chaque effet est converti en **points de puissance effective** (1 point = +1 % de DPS ou de PV effectifs) avec les formules du jeu, puis comparé à une cible par qualité.

| Qualité | Poids | Cible (points) |
|---|---|---|
| Commun | 1 | 10 |
| Peu commun | 2.2 | 22 |
| Rare | 5 | 50 |
| Légendaire | 12 | 120 |

**Calibrage** : le simulateur v3 (mode Moyen) donne +474 % de puissance avec les 21 items achetés avant 7:30 (≈ 49 poids de qualité), soit ≈ 9,7 points par poids ; on arrondit à 10, donc un Commun vaut 10 points.

**Conversion des effets** (parts de DPS issues des coefficients de sorts : sort 1 ≈ 43 %, sorts à recharge ≈ 57 %, zone ≈ 32 %) :
- Dégâts +x % = x points. Vitesse d'attaque +x % = 0,43 x points (parce que le sort 1 fait 43 % du DPS). Vitesse de recharge +x % = 0,57 x points.
- Critique : gain = (1 + chance × (multiplicateur - 1)) / (1 + 5 % × 1) - 1.
- PV max +x % = x points. Armure A = A points (1 / (1 - A/(A+100)) - 1 = A/100). Réduction de dégâts r = 1/(1 - r) - 1.
- Régénération et soins : points = 100 × PV rendus par seconde / dégâts subis par seconde (4,4 % des PV max/s, soit ≈ 15 PV/s à 5:00).
- Effets de zone : multipliés par ≈ 2,5 (moitié du temps en foule, ≈ 4 ennemis touchés).

**Contrôle du scaling dans le temps** : chaque item est évalué à 2:30, 5:00 et 7:30 avec les PV, les dégâts subis, le DPS et les kills du simulateur v3 (repères à 150 s, 300 s et 450 s de jeu actif). Un item est « stable » si sa valeur à 7:30 reste entre 0,67 et 1,5 fois sa valeur à 2:30. C'est pour cela que les soins et régénérations sont exprimés **en % des PV max** et non en PV fixes (un montant fixe perd la moitié de sa valeur en 5 minutes).

**Résultat : 50 items sur 50 dans la tolérance de ±20 % de leur cible et stables dans le temps.** Trois items dérivent le plus entre 2:30 et 7:30, tous dans la zone acceptée (0,67-1,5) : Épines (+23 %), Chronomètre brisé (+24 %), Bouclier réactif (-19 %).

### Corrections faites suite à l'audit

| Item | Problème | Correction |
|---|---|---|
| Antidote | Réduire la durée des poisons : effet faible et peu lisible | **-40 % des dégâts de brûlure et de poison subis** (réduction de dégâts sur la durée, 11 points) |
| Bague de vigueur | +20 PV : 4 % des PV à 7:30, 0,67 niveau | +10 % de PV max (minimum +15 PV) |
| Cœur de mousse, Tonique vital, Pièce porte-bonheur | Soin en PV fixes : valeur divisée par 2 entre 2:30 et 7:30 | Soin en % des PV max |
| Épines | Renvoi de dégâts de contact : trop faible tard dans la run | Riposte à 70 % des dégâts du sort 1 (suit les items offensifs) |
| Lame jumelle (+15 %), Sablier (-6 %), Sifflet (+6 %) | Valaient 3 à 6 points au lieu de 10 ou 22 | +50 % de dégâts du sort 1 ; +18 % de vitesse de recharge ; +22 % de vitesse d'attaque |
| Étincelle, Cristal de feu, Fiole verte, Venin | Brûlure et poison valaient 1 à 5 points | Brûlure 100 % du coup sur 3 s, poison 20 %/s par cumul ; procs 18 % / 40 % |
| Couronne d'écho | 50 % de répétition = 21 points pour un Légendaire | 3 répétitions à 100 % (130 points) |
| Cœur du chronomancien | Sans délai interne, il se déclenchait en boucle | Délai interne de 2 s (104 points) |
| Moisson | Plafond +60 % atteint en 40 s | +0,2 % par kill jusqu'à +120 % |
| Bourse du pillard | Dépendait du nombre d'élites (valeur ×3,6 entre 2:30 et 7:30) | Remplacée par **Morsure vorace** (soin par kill) |
| Aimant d'âme | Dépendait des élites (×2,5) | Déclenché tous les 25 kills |
| Armure du colosse | Malus de vitesse : interdit | -10 % de dégâts infligés |

---

## 2. Table des taux de drop

| Coffre | Commun | Peu commun | Rare | Légendaire |
|---|---|---|---|---|
| **Petit** (d100) | 60 % | 32 % | 7 % | 1 % |
| **Large** | 0 % | 80 % | 20 % | 0 % |
| **Légendaire** | 0 % | 0 % | 0 % | 100 % |
| **Boss d'étage** (gratuit) | 0 % | 0 % | 90 % | 10 % |

Chance : chaque point relance le d100 et garde le meilleur. Pity (petits coffres) : Rare+ = 8 % + 2 % par petit coffre sans Rare+ de suite.

| Qualité | Taille de table | Chance par item dans la table | Chance par item sur un petit coffre |
|---|---|---|---|
| Commun | 17 | 5,88 % | 3,53 % |
| Peu commun | 16 | 6,25 % | 2,00 % |
| Rare | 11 | 9,09 % | 0,64 % |
| Légendaire | 6 | 16,67 % | 0,17 % |

Répartition attendue d'une run de 3 étages, mode Moyen (28 items : 19 petits coffres, 5 larges, 3 coffres de boss d'étage, 1 légendaire) : ≈ 11,4 Communs, 10,1 Peu communs, 5,0 Rares, 1,5 Légendaire. Les petits et grands coffres sont posés au sol au début de chaque étage (8 petits, 2 larges, 25 % de chance d'un légendaire) et payés en or.

---

## 3. Communs (17)

| # | Item | Effet | Stack | Tags | Valeur 2:30 / 5:00 / 7:30 | Ratio |
|---|---|---|---|---|---|---|
| 1 | Lentille aiguisée | +10 % de chance de critique | L | Crit | 10 / 10 / 10 | 0,95 |
| 2 | Sablier fêlé | +18 % de vitesse de recharge des sorts | L (plancher de recharge 25 %) | Recharge | 10 / 10 / 10 | 1,02 |
| 3 | Antidote | Dégâts de brûlure et de poison subis -40 % | H | Survie | 11 / 11 / 11 | 1,11 |
| 4 | Botte rapiécée | +5 % de vitesse de déplacement (plafond global +10 % pour tous les items) | L plafonné | Mobilité | 10 / 10 / 10 | 1,00 |
| 5 | Pierre à aiguiser | +10 % de dégâts | L | Dégâts | 10 / 10 / 10 | 1,00 |
| 6 | Bague de vigueur | +10 % de PV max (minimum +15 PV) | L | Survie | 10 / 10 / 10 | 1,00 |
| 7 | Amulette de cuir | +10 d'armure (réduction = armure / (armure + 100)) | L | Survie | 10 / 10 / 10 | 1,00 |
| 8 | Aimant de poche | Rayon de ramassage +40 % et XP gagnée +12 % | L | Or, Progression | 10 / 10 / 10 | 1,02 |
| 9 | Sifflet de chasse | +22 % de vitesse d'attaque (sort 1) | L (plafond ×3) | Auto | 10 / 10 / 10 | 0,95 |
| 10 | Étincelle | Proc 18 % : brûlure (100 % du coup sur 3 s) | L (proba) | Feu | 10 / 10 / 10 | 1,01 |
| 11 | Flocon | Proc 22 % : ralentissement de 30 % pendant 1,5 s | L (proba) | Givre | 10 / 10 / 10 | 0,99 |
| 12 | Fiole verte | Proc 18 % : poison (1 cumul : 20 % du coup/s pendant 4 s) | L (proba) | Poison | 10 / 10 / 10 | 1,01 |
| 13 | Pavois fêlé | Dégâts reçus -9 % | H | Survie | 10 / 10 / 10 | 0,99 |
| 14 | Cœur de mousse | Régénération +0,45 % des PV max par seconde | L | Survie | 10 / 10 / 10 | 1,02 |
| 15 | Pièce porte-bonheur | Chaque pièce ramassée soigne 0,05 % des PV max ; or gagné +25 % | L | Or, Survie | 10 / 10 / 10 | 1,01 |
| 16 | Éclat d'expérience | XP gagnée +15 % | L | Progression | 9 / 9 / 9 | 0,90 |
| 17 | Plume d'empenne | +30 % de vitesse de projectile et +12 % de portée du sort 1 | L (plafond ×2) | Auto, Projectile | 10 / 10 / 10 | 0,99 |

## 4. Peu communs (16)

| # | Item | Effet | Stack | Tags | Valeur 2:30 / 5:00 / 7:30 | Ratio |
|---|---|---|---|---|---|---|
| 1 | Cristal de feu | Proc 40 % : brûlure (100 % du coup sur 3 s) | L (proba) | Feu | 22 / 22 / 22 | 1,02 |
| 2 | Givre | Proc 40 % : ralentissement de 40 % pendant 2 s | L (proba) | Givre | 22 / 22 / 22 | 1,02 |
| 3 | Horloge arcanique | +20 % de vitesse de recharge et +18 % de dégâts des sorts à recharge | L | Recharge | 22 / 22 / 22 | 0,98 |
| 4 | Lame jumelle | +50 % de dégâts du sort 1 | L | Auto | 22 / 22 / 22 | 0,98 |
| 5 | Venin concentré | Proc 40 % : poison (cumuls sur la même cible, 20 % du coup/s pendant 4 s) | L (proba) | Poison | 22 / 22 / 22 | 1,02 |
| 6 | Cape de brume | 18 % d'esquive | H | Survie | 22 / 22 / 22 | 1,00 |
| 7 | Épines | Chaque coup subi déclenche une riposte à 70 % des dégâts du sort 1 sur l'attaquant (1 riposte max par 0,5 s) | L | Survie | 20 / 24 / 25 | 1,10 |
| 8 | Éclair en bouteille | Proc 15 % : foudre sur 3 cibles à 50 % des dégâts | L (proba) | Zone | 22 / 22 / 22 | 1,02 |
| 9 | Rune de portée | Zone des sorts +25 % et dégâts des sorts de zone +15 % | L | Zone | 22 / 22 / 22 | 1,01 |
| 10 | Morsure vorace | Chaque monstre tué rend 0,2 % des PV max | L | Survie | 23 / 23 / 23 | 1,03 |
| 11 | Tonique vital | +15 % de PV max et +0,3 % des PV max par seconde | L | Survie | 22 / 22 / 22 | 0,99 |
| 12 | Orbe de veille | Bouclier de 28 % des PV max, se reforme après 5 s sans dégâts | L (taille) | Survie | 22 / 22 / 22 | 1,02 |
| 13 | Sang chaud | +70 % de dégâts sous 50 % de PV | L | Risque | 21 / 21 / 21 | 0,95 |
| 14 | Marque du chasseur | +45 % de dégâts aux élites et aux boss | L | Boss | 22 / 22 / 22 | 1,02 |
| 15 | Carquois affûté | +30 % de vitesse d'attaque (sort 1) et +30 % de vitesse de projectile | L | Auto, Projectile | 20 / 20 / 20 | 0,93 |
| 16 | Pointe perforante | Les projectiles du sort 1 traversent 1 ennemi de plus par exemplaire (70 % des dégâts sur chaque cible suivante) | L | Auto, Zone | 24 / 24 / 24 | 1,10 |

## 5. Rares (11)

| # | Item | Effet | Stack | Tags | Valeur 2:30 / 5:00 / 7:30 | Ratio |
|---|---|---|---|---|---|---|
| 1 | Aimant d'âme | Rayon de ramassage ×2 ; tous les 25 kills, aspire l'or et l'XP de l'écran et donne +80 % de dégâts pendant 3 s | L | Or, Dégâts | 51 / 51 / 51 | 1,02 |
| 2 | Chronomètre brisé | +70 % de vitesse de recharge ; chaque élite tué rend 0,5 s de recharge à tous les sorts | L (plancher de recharge 25 %) | Recharge | 43 / 48 / 54 | 0,96 |
| 3 | Tempête de braises | Un monstre qui meurt en brûlant explose : 30 % de ses PV max à 4 ennemis proches | L | Feu, Zone | 48 / 48 / 48 | 0,96 |
| 4 | Cœur de glace | Les monstres ralentis subissent +75 % de dégâts | L | Givre | 49 / 49 / 49 | 0,97 |
| 5 | Peste vivante | Un monstre empoisonné qui meurt libère un nuage toxique : 25 % de ses PV max à 4 ennemis proches et 1 cumul de poison | F | Poison, Zone | 45 / 45 / 45 | 0,90 |
| 6 | Œil du prédateur | +25 % de critique et coups critiques ×3 au lieu de ×2 | L + F | Crit | 52 / 52 / 52 | 1,05 |
| 7 | Bouclier réactif | 2 charges : chacune annule un coup et se recharge en 3,4 s (affectée par la vitesse de recharge) | H (recharge) | Survie | 53 / 44 / 43 | 0,88 |
| 8 | Faveur du marchand | +1 de Chance, prix des coffres -15 % et première relance à l'or de chaque étage gratuite | H + L | Or, Chance | 59 / 59 / 59 | 1,17 |
| 9 | Danseur | +75 % de dégâts tant que le joueur se déplace | L | Mobilité | 49 / 49 / 49 | 0,97 |
| 10 | Phénix de poche | Ressuscite une fois à 50 % de PV (usage unique, +1 par exemplaire) | L | Survie | 50 / 50 / 50 | 1,00 |
| 11 | Rafale d'acier | +40 % de vitesse d'attaque (sort 1) ; tous les 4 tirs, le sort 1 tire 3 projectiles d'un coup | L + F | Auto, Projectile | 48 / 48 / 48 | 0,95 |

## 6. Légendaires (6)

| # | Item | Effet | Stack | Tags | Valeur 2:30 / 5:00 / 7:30 | Ratio |
|---|---|---|---|---|---|---|
| 1 | Cœur du chronomancien | 10 kills en 3 s : recharge remise à zéro d'un sort aléatoire (délai interne de 2 s) | F | Recharge | 104 / 104 / 104 | 0,87 |
| 2 | Couronne d'écho | Le sort 1 se répète 3 fois à 100 % des dégâts | E (+1 répétition par exemplaire supplémentaire) | Auto | 130 / 130 / 130 | 1,08 |
| 3 | Nova infinie | Toutes les 4 s, nova de 400 % de dégâts qui applique brûlure, ralentissement et poison | L (dégâts) | Feu, Givre, Poison, Zone | 111 / 111 / 111 | 0,93 |
| 4 | Armure du colosse | +60 % de PV max, -25 % de dégâts reçus, -10 % de dégâts infligés | E | Survie | 103 / 103 / 103 | 0,86 |
| 5 | Moisson | Chaque kill donne +0,2 % de dégâts, cumulable jusqu'à +120 % (conservé dans la run) | L (plafond) | Dégâts | 120 / 120 / 120 | 1,00 |
| 6 | Dé pipé | +3 de Chance (relance du d100, on garde le meilleur) et le premier petit coffre de chaque étage est au moins Peu commun | L | Chance | 126 / 126 / 126 | 1,05 |

---

## 7. Synergies principales

- **Feu** : Étincelle -> Cristal de feu -> Tempête de braises -> Nova infinie.
- **Givre** : Flocon -> Givre -> Cœur de glace (ralenti = +75 % de dégâts) -> Danseur pour kiter.
- **Poison** : Fiole verte -> Venin concentré -> Peste vivante (foules denses).
- **Critique** : Lentille aiguisée -> Œil du prédateur -> Sang chaud.
- **Recharge** : Sablier fêlé -> Horloge arcanique -> Chronomètre brisé -> Cœur du chronomancien.
- **Tir rapide (sort 1)** : Sifflet de chasse -> Plume d'empenne -> Carquois affûté -> Rafale d'acier, avec Pointe perforante pour les foules et Épines pour la riposte.
- **Survie** : Bague de vigueur -> Tonique vital -> Morsure vorace -> Armure du colosse -> Phénix de poche ; Antidote contre les élites à brûlure et poison.
- **Chance et or** : Pièce porte-bonheur -> Faveur du marchand -> Dé pipé (plus de Rares et plus de relances).

## 8. Hypothèses à valider en playtest

- Dégâts subis par seconde (4,4 % des PV max/s), part des dégâts venant des brûlures et poisons (25 %), élites tués par seconde, kills par seconde.
- Les items de synergie (Tempête de braises, Peste vivante, Cœur de glace) sont valorisés en supposant des sources de brûlure, de poison ou de ralentissement dans le build.
- Les valeurs de Chance supposent 9 coffres encore à ouvrir (≈ 24 petits et grands coffres sur 3 étages) ; une Chance prise tard vaut moins.
