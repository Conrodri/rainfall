# Boucle d'étage : sortir de la routine « piliers, tour, boss, tour, sortie » (design v1)

> Statut : **avis de game design** (Fable, game-designer, 01/11/2026), angle systèmes, récompenses, décisions et économie de l'or. Le level-designer traite en parallèle l'angle carte et parcours. Aucun fichier de `game/` n'est modifié ; rien n'est implémenté.
> Retour du joueur (verbatim) : « souvent dans les games je dois rush les deux piliers de mini-boss pour générer des golds, je fais un tour de map pour prendre les coffres, je tue le boss, je refais un tour de map pour acheter les coffres et je pars, je fais ça en boucle, je n'ai aucune autre chose à faire, c'est le problème, j'aimerais améliorer ceci, soit en proposant des alternatives, soit en rendant le contenu plus fun ».
> Lu avant d'écrire : `CLAUDE.md` (Décisions), `docs/GDD.md`, `docs/Maths_Scaling.md` (§1-2, §7, §11, §14), `docs/Propositions_Boucle_Interactions.md` (retenus par le joueur : Fondoir + Matrice, Alambic, Enclume, Boussole de rouille, Paratonnerre dévié, Présages ; rejetés : Reposoir, Brasero, Départ vif, Étal des rebuts), `docs/Design_Etages.md`, `docs/Design_Boss_Cartes.md` §4.4, `docs/Audit_Runs_Completes_2026-10-31.md`, `game/scripts/core/balance.gd`, `loot/chest.gd`, `loot/gold_capsule.gd`, `stage/pillar.gd`, `stage/stage_manager.gd`, `director/director.gd`, `data/items.json`, et les **trois journaux de runs réelles du joueur** du 31/10/2026 (`user://run_logs/`, Ardent victoire 18:34, Taliant victoire 17:40, Vigie mort au Sonneur 9:20).
> Contraintes respectées : gel des boss (aucun nouveau boss, aucun nouveau sort de boss ; les PV des mini-boss ne sont pas touchés ici, seulement signalés), trois plateformes (toute interaction par « interagir », jamais au contact), télégraphes ≥ 0,8 s, aucune mort instantanée, aucune pub ni achat, aucun nom ni design repris de Risk of Rain ou de Vampire Survivors. Toute valeur chiffrée vise une constante de `Balance` ou une clé JSON de `game/data/`, jamais une valeur en dur.
> Unités : 1 u = 64 px ; **P** = prix d'un petit coffre figé au début de l'étage, `Balance.chest_price(&"petit", D_entrée, étage)` ≈ **50 / 107 / 194 / 348 / 560 or** aux étages 1 à 5 (D d'entrée mesurées dans les runs réelles : 1,00 / 1,78 / 2,78 / 4,30 / 6,10).

Sommaire : 1. Diagnostic : pourquoi la routine est optimale et unique · 2. Huit changements (a : alternatives, b : routine plus fun) · 3. Budget d'or et compatibilité avec les propositions déjà retenues · 4. Classement, ordre de production, ce qu'il ne faut pas faire · 5. Contrats, tests et télémétrie.

---

## 1. Diagnostic : pourquoi la routine est optimale et unique

### 1.1 Ce que font les runs réelles du joueur (journaux du 31/10/2026, Moyen)

| Étage | Durée jusqu'au boss mort → sortie | Mini-boss A / B (durée du combat) | Boss d'étage | Or gagné / dépensé / converti | Coffres achetés | Achats dans la 1re minute | Achats après le boss |
|---|---|---|---|---|---|---|---|
| 1 (Ardent) | 196 s → 233 s | 14 s / 26 s | 74 s | 439 / 400 / 40 | 9 (8 payés + boss) | 4 | 2 |
| 1 (Taliant) | 184 s → 205 s | 12 s / 11 s | 61 s | 407 / 400 / 8 | 9 | 4 | 3 |
| 1 (Vigie) | 191 s → 206 s | 7 s / 14 s | 68 s | 400 / 400 / 0 | 8 | 3 | 2 |
| 2 (Ardent) | 147 s → 191 s | 16 s / 26 s | 71 s | 881 / 851 / 31 | 8 | 2 | 2 |
| 2 (Taliant) | 185 s → 243 s | 8 s / 5 s | 62 s | 1 026 / 939 / 87 | 9 | 3 | 4 |
| 3 (Ardent) | 195 s → 291 s | 22 s / 28 s | 61 s | 2 010 / 1 622 / 388 | 9 | 1 | 4 |
| 3 (Taliant) | 193 s → 288 s | 3 s / 3 s | 120 s | 2 054 / 1 976 / 78 | 9 | 3 | 5 |
| 4 (Ardent) | 240 s → 257 s | 30 s / 19 s | 109 s | 3 376 / 3 229 / 148 | 10 | 3 | 3 |
| 4 (Taliant) | 230 s → 254 s | 4 s / 6 s | 119 s | 3 726 / 3 535 / 192 | 9 | 3 | 3 |
| 5 (Ardent) | 130 s → 142 s | — | 84 s | 4 210 / 2 359 / **0** (1 851 or perdus) | 6 | 3 | 1 |
| 5 (Taliant) | 66 s → 70 s | — | 27 s | 2 620 / 1 692 / **0** (928 or perdus) | 4 | 3 | 1 |

Lecture :
- La routine décrite par le joueur est **exactement** ce que les journaux montrent : 3-4 coffres achetés dans la première minute (payés par les capsules), les deux petits piliers activés entre 14 s et 100 s, le gros pilier vers 120 s, le boss mort vers 190 s, 2-5 coffres achetés dans la minute qui suit, sortie. L'or est dépensé à **95-100 %** aux étages 1-2, à 80-95 % ensuite.
- Les **mini-boss meurent en 3 à 30 s** (cible `Maths_Scaling.md` §14.0 : 21-30 s) : pour Taliant, 3 à 12 s. Un petit pilier n'est pas un combat, c'est un **péage** sur le chemin : on l'active en passant.
- La phase post-boss dure **4 à 96 s** et ne contient qu'une chose : acheter ce qui reste. À l'étage 5, l'or n'a plus aucun débouché (1 851 or perdus pour Ardent : 3,3 P).

### 1.2 Pourquoi la routine est optimale : trois sources d'or, une seule rentable par geste

Taux d'or par minute à l'étage 1 (D ≈ 1,5, P = 50 ; formules `balance.gd` : or d'un kill = 2 × D × coût × `REWARD_MULT` 0,235 ; crédits = `CREDIT_K` 0,894 × (1 + 0,4 D) × zone) :

| Source | Règle | Or par minute (étage 1) | En P/min | Part de l'or de l'étage 1 (mesuré) | Décision demandée |
|---|---|---|---|---|---|
| **Capsules d'argent** | 10 par étage, `CAPSULE_GOLD` 20 × D^1,25, gratuites, « interagir » | ≈ 200 or en ≈ 50 s de tour | **≈ 4 P/min** | **45 %** (200 / 440) | aucune : elles sont sur le chemin |
| Kills hors zone | flux du director, rampe `RAMP_TIME_S` 480 s (crédits à 40 % à 60 s, 100 % à 240 s) | ≈ 40-60 or | 0,8-1,2 P/min | 37 % | aucune : se déplacer suffit |
| Kills en zone de petit pilier | `ZONE_SPAWN_MULT[&"mini"]` 1,5 | ≈ 60-90 or | 1,2-1,8 P/min | (compris ci-dessus) | aucune : la zone est là où l'on est |
| Kills en zone de charge | `ZONE_SPAWN_MULT[&"etage"]` 2,33 | ≈ 100-140 or | 2-2,8 P/min | (compris ci-dessus) | aucune : la charge impose d'y rester 60 s |
| Primes de mini-boss | `boss_gold(&"mini")` = 2 × D × 25 × 0,235 ≈ **12 D or** | ≈ 15-20 or par mini-boss | 0,3-0,4 P par pilier | 8 % | aucune |
| Prime de boss d'étage | 2 × D × 60 × 0,235 ≈ 28 D or | ≈ 45 or | 0,9 P | 10 % | aucune |

Trois constats chiffrés :
1. **La capsule est la meilleure source d'or du jeu au mètre parcouru** (4 P/min contre 1 P/min en farmant), gratuite et sans risque : le « tour de map » n'est pas un choix, c'est l'économie elle-même. Aux étages 3-4 les capsules pèsent encore ≈ 35 % de l'or (10 × 20 × 4,3^1,25 ≈ 1 240 or sur 3 550).
2. **Les zones de pilier sont les seuls multiplicateurs de densité** (×1,5 et ×2,33) : « rush les piliers » est le moyen le plus rapide de faire tomber l'or des kills, et les primes de mini-boss (12 D or : 0,3 P) ne comptent pas. Le pilier est donc un **robinet à monstres**, pas une rencontre.
3. **Les prix sont figés au début de l'étage** (`chest.gd` : `_price_d = RunState.difficulty()` à `setup`), alors que l'or d'un kill croît avec D : attendre ne coûte rien en or, seulement +0,15 de D par minute. Rien ne pousse à partir, rien ne récompense le fait de partir, et rien n'apparaît de nouveau après le boss : la seule chose à faire est d'acheter ce qui reste.

### 1.3 Pourquoi la routine est unique : un seul verbe, un seul puits

- **Un seul verbe** : coffres, capsules, piliers et téléporteur se « activent ». Aucune interaction ne demande de choisir **où**, **quand** ou **à quel risque** ; les propositions déjà retenues (Fondoir, Matrice, Alambic, Enclume, Boussole) ajoutent « choisir **quoi** » sur le build, mais ne touchent pas au parcours de l'étage.
- **Un seul puits** : 10 coffres identiques (même geste, même d100), 12 P de puits pour ≈ 9-10 P de revenus aux étages 1-2 et ≈ 10,5 P aux étages 3-4 : l'économie est **juste tendue** (on achète 8-9 coffres sur 10), ce qui fait que « tout acheter puis partir » est à la fois faisable et optimal. Il n'y a ni objet à acheter ailleurs, ni pari, ni surenchère.
- **Un seul rythme** : les deux creux (trajets entre piliers) et la phase post-boss ne contiennent aucun événement ; les cases `E` des cartes (3 par carte, `Design_Boss_Cartes.md` §4.4) ne sont lues par aucun script.
- **Un seul coût d'échec** : rester farmer n'a qu'un coût invisible (D), ce qui vide le choix « rester / partir » (Deci et Ryan : un choix dominé n'alimente pas l'autonomie). Le « Départ vif » proposé plus tôt corrigeait cela par un bonus au départ, et le joueur ne l'a pas compris : la correction doit être **visible dans le monde** (quelque chose qui monte, qui arrive, qui ferme), pas un taux de conversion.

Esthétique MDA visée par les huit changements : **Défi** (choisir un risque) et **Découverte** (quelque chose de neuf à chaque étage), en gardant la **Sensation** de la micro-boucle intacte (aucune canalisation, aucun bouton de plus).

### 1.4 Hors périmètre, à signaler

- **Mini-boss trop fragiles** (3-30 s contre 21-30 s visés, 3-12 s pour Taliant) : c'est le levier `BOSS_FOCUS_HP_MULT[&"mini"]` 0,55 (ou `BOSS_BASE_HP[&"mini"]`) ; gel des boss, donc **à revoir après le rééquilibrage des personnages et des objets**, comme décidé le 28/10. Tant que les mini-boss tombent en 5 s, toute récompense attachée à « vaincre le mini-boss » est une récompense attachée à « marcher jusqu'au pilier » : les propositions 3 et 4 ci-dessous en tiennent compte (elles récompensent le **pari** ou le **chronométrage**, pas le kill).
- `docs/simulateur_scaling.py` est toujours le modèle v3 (3 étages, coffres à 150, D = 1 + 0,30 t) et ne reflète plus `balance.gd` §14 : ses durées et ses reliquats ne servent plus qu'à l'ordre de grandeur. `economy_test` (étage 1 de 5 min : 200 capsules + 80 primes + 333 kills = 613 or, 10 coffres = 600, reliquat 13) est la référence alignée ; les runs réelles (étage 1 de 3,5 min, 400-440 or) sont en dessous parce que l'étage est plus court et la rampe du director n'est pas finie.

---

## 2. Huit changements

Règles communes : interaction par « interagir » (groupe `interactable`, couche 7, `can_interact()` / `interact_label()` / `interact_state()` comme le coffre, `game/CONTRACTS.md`) ; tout nouvel élément a un repère minimap et une flèche `OffscreenCues` ; les libellés d'invite font ≤ 24 caractères ; chaque usage écrit un compteur `RunLog` ; tout état est sauvé dans `StageManager.to_dict()` ou `RunState.to_dict()`. Les props sont des **briefs Codex** (cel-shadé, sans normal map, masque `_e.png` pour l'accent émissif, ombre cuite `_shadow.png`, rig iso 2:1), effort `low`.

### (a) Alternatives à la routine : d'autres façons rentables de jouer un étage

#### 2.1 Les Primes de chasse (une élite marquée qui erre, à rattraper)

- **Mécanique** : deux fois par étage (1-4), un monstre **élite existant** (tier 2 ou 3, affixe tiré normalement) apparaît **marqué** à ≥ 15 u du joueur, hors écran : halo du biome, icône de cible sur la minimap, flèche `OffscreenCues`, bandeau court « Prime : Brute de brûlure, 60 s ». Il **ne poursuit pas** le joueur : il se déplace en patrouille entre deux points d'apparition de la carte (1,2 u/s, `HUNT_ROAM_SPEED_U`) et riposte s'il est attaqué (comportement d'élite normal). Le joueur a `HUNT_TIMEOUT_S` 60 s pour le tuer ; passé le délai, il s'enfuit (disparaît avec un son de fuite et le bandeau « Prime perdue »). Récompense à la mort : la prime d'élite normale **plus** `HUNT_BOUNTY_P` 0,8 P d'or (pièces en jaillissement, comme une capsule) et **1 carte d'objet gratuite de table `petit`** une fois sur deux (`HUNT_CHEST_CHANCE` 0,5, un seul objet, pas de paire, pas de relance). Première prime entre `HUNT_FIRST_WINDOW_S` 40 et 80 s de l'étage (pendant le trajet entre les petits piliers) ; seconde **à la mort du boss d'étage** + 5 s, à ≥ 20 u du gros pilier.
- **Décision créée** : « je quitte mon chemin pour aller la chercher, ou je continue vers le pilier ? » pendant le creux 1 ; et après le boss, « je la chasse (60 s, de l'or et peut-être un objet) ou je pars » : la phase post-boss reçoit un **but** qui n'est pas « acheter ce qui reste ».
- **Chiffres** : `HUNT_PER_STAGE := 2`, `HUNT_BOUNTY_P := 0.8` (plage sûre 0,5-1,0 : en dessous d'un coffre pour que la chasse ne remplace pas le farm, au-dessus de la prime d'un mini-boss, 0,3 P, pour qu'elle vaille le détour), `HUNT_TIMEOUT_S := 60.0` (plage 45-90), `HUNT_ROAM_SPEED_U := 1.2`, `HUNT_MIN_DIST_U := 15.0`, `HUNT_CHEST_CHANCE := 0.5`, `HUNT_ELITE_HP_MULT := 1.0` (l'élite n'est pas renforcée : c'est le détour qui coûte, pas le combat ; plage 1,0-1,5 si la télémétrie montre > 90 % de primes prises). Revenu attendu : ≈ +1,2 P par étage si les deux primes sont prises (+10-12 % d'or), soit de quoi acheter les **grands coffres** que les joueurs laissent aujourd'hui à l'étage 1 (400 or dépensés = 8 petits, 0 grand).
- **Effet sur la routine** : ne la casse pas, l'**interrompt** : deux détours par étage, et une raison de rester 30-60 s après le boss qui n'est pas du farm diffus. Si le joueur ignore la prime, rien ne change pour lui.
- **Coût de production** : code 1-1,5 jour (`HuntDirector` dans `scripts/director/` : tirage seedé, patrouille entre `spawn_points`, bandeau, minuterie, récompense via `PickupManager.drop` et `ChestUI` en mode « une carte ») ; Codex : 1 anneau marqueur au sol (`_e.png`, teinte par biome en code), 1 icône minimap, 2 sons (apparition, fuite) ; **aucun nouveau monstre**.
- **Risques** : lisibilité mobile (le marqueur doit se voir à 6 pouces : halo ≥ 0,3 u d'épaisseur, flèche de bord d'écran obligatoire) ; perf nulle (1 monstre) ; abus « laisser courir le chrono et tuer à 59 s » : aucun gain ; collision avec le Paratonnerre dévié : la seconde prime apparaît après la mort du boss, jamais pendant ; en Difficile, l'élite a 2 affixes à D ≥ 4 (règle existante) : c'est voulu.

#### 2.2 Les Coffres gardés (un paquet endormi autour d'un coffre à prix réduit)

- **Mécanique** : parmi les 8 petits coffres, `CHEST_GUARDED_PER_STAGE` 2 sont **gardés** : un paquet de monstres **endormis** (anim `idle` existante, teinte sombre, un « z » émissif au-dessus) est posé en anneau à 3 u autour du coffre dès l'arrivée ; le coffre affiche son prix **barré** et son prix réduit (`CHEST_GUARDED_DISCOUNT` 0,35 : −35 %) avec un cadenas de chaînes. S'approcher à moins de 5 u (`CHEST_GUARDED_WAKE_U`) réveille le paquet (télégraphe : les monstres se redressent sur 0,8 s, son de chaînes) ; le coffre reste **verrouillé** tant qu'un membre du paquet vit (libellé « Gardé : 4 restants »). Taille du paquet : crédits = `CHEST_GUARDED_CREDITS_P` 0,6 × l'or d'un P converti en crédits à la D courante (≈ 6 tier 1 + 2 tier 2 + 1 élite à l'étage 1 ; tirage par le director, donc même tiers et mêmes élites que le flux). Jamais à moins de 12 u du spawn ni à moins de 10 u d'un pilier.
- **Décision créée** : pendant le tour, « ce coffre coûte un tiers de moins mais il faut livrer un combat de 10-15 s sur place » ; le joueur **lit** sa carte au lieu de la ramasser. Deux coffres gardés par étage = deux choix, pas un menu.
- **Chiffres** : `CHEST_GUARDED_PER_STAGE := 2` (plage 1-3), `CHEST_GUARDED_DISCOUNT := 0.35` (plage 0,25-0,45 : à 0,5 le gardé domine toujours ; à 0,2 il n'est jamais pris), `CHEST_GUARDED_WAKE_U := 5.0`, `CHEST_GUARDED_CREDITS_P := 0.6`, `CHEST_GUARDED_RING_U := 3.0`. Le paquet rapporte son or de kills normal (≈ 0,15 P) : gain total ≈ 0,5 P par coffre gardé pour ≈ 12 s de combat, soit 2,5 P/min, plus que le farm (1 P/min) mais avec un risque et un lieu imposés ; équilibre transitif coût ↔ puissance.
- **Effet sur la routine** : le tour n'est plus linéaire : on peut sauter un gardé, y revenir après un pilier (plus fort), ou le réveiller en passant pour combiner avec une zone de pilier voisine (à interdire à < 10 u : sinon la zone ×1,5 et le paquet se superposent).
- **Coût de production** : code 1 jour (`chest.gd` : état `guarded`, compte des gardiens ; `Director.spawn_group(dormant = true)` ; réveil ; libellé) ; Codex : 1 variante de prop (chaînes sur le coffre existant, 1 état), 1 icône « z » émissive, 2 sons ; **aucun nouveau monstre ni anim** (`idle` existante).
- **Risques** : perf : les gardiens comptent dans le plafond de vivants (≤ 20 par étage, négligeable) ; sur mobile le prix barré doit rester lisible (deux lignes : « 32 or » en gros, « 50 » barré en petit) ; lisibilité des monstres endormis la nuit (étage 4) : le « z » émissif est obligatoire ; abus « réveiller de loin et fuir » : le paquet se rendort après 20 s sans contact (`CHEST_GUARDED_SLEEP_AGAIN_S`) et retrouve ses PV ; collision avec les Présages (retenus) : un présage « Veilleurs » pourrait rendre tous les coffres gardés (idée LiveOps, pas v1).

#### 2.3 Le Duo de piliers (activer les deux petits piliers à moins de N secondes d'écart)

- **Mécanique** : la règle existe déjà (GDD §2 : « on peut activer les deux petits piliers en même temps : plus risqué, mais plus rapide ») mais n'est **pas récompensée**. Quand le second petit pilier est activé moins de `PILLAR_DUO_WINDOW_S` 25 s après le premier, les deux piliers s'allument en « Duo » (accent émissif doublé, bandeau « Duo ! ») : les deux zones ×1,5 s'additionnent (déjà le cas), et à la mort du **second** mini-boss : les primes des deux mini-boss sont versées une seconde fois (`PILLAR_DUO_BOUNTY_MULT` 2,0) et un **petit coffre gratuit** apparaît au pied du dernier pilier (`PILLAR_DUO_CHEST := &"petit"`). Le compte à rebours s'affiche sur le premier pilier activé et dans la ligne d'objectif.
- **Décision créée** : transforme « rush les deux piliers » en **plan** : « j'active A, je cours vers B en 25 s avec le mini-boss A sur les talons, je me bats contre les deux dans les zones additionnées ». C'est un pari de temps, pas d'or ; un joueur prudent les fait l'un après l'autre et ne perd rien.
- **Chiffres** : `PILLAR_DUO_WINDOW_S := 25.0` (mesuré dans les runs réelles : écart A → B de 5 à 43 s, médiane ≈ 30 s ; à 25 s il faut **choisir** le trajet direct ; plage sûre 20-40 selon la distance entre piliers de chaque carte, à vérifier avec le level-designer), `PILLAR_DUO_BOUNTY_MULT := 2.0` (≈ +0,6 P), `PILLAR_DUO_CHEST := &"petit"` (≈ 1 P de valeur). Gain total ≈ 1,6 P pour un risque réel (deux mini-boss et deux zones, ≈ 2× la pression pendant 20-40 s).
- **Effet sur la routine** : la rend **sous-optimale si elle est faite calmement** et **plus intense si elle est faite en duo** ; la même action a enfin deux façons d'être jouée. Avec des mini-boss à 5 s (§1.4), le duo est trop facile pour Taliant ; une fois les mini-boss remis à 21-30 s, il devient le vrai pic de l'étage.
- **Coût de production** : code 0,5 jour (`stage_manager.gd` : horodatage des activations, drapeau `duo`, versement, coffre ; libellé et compte à rebours) ; Codex : rien (accent émissif doublé en code) ; 1 son de « Duo ». **Le moins cher du document.**
- **Risques** : stratégie dominante pour les personnages forts (Taliant, Bourbe) : levier `PILLAR_DUO_WINDOW_S` à baisser à 20 s et, surtout, les PV des mini-boss après le gel ; si la carte place les piliers à plus de 40 u l'un de l'autre, le duo est impossible : à transmettre au level-designer (distance A-B visée 15-30 u) ; perf : deux zones ×1,5 = ×3 pendant 20-40 s, déjà prévu par le GDD.

#### 2.4 Le Tribut du pilier (miser de l'or sur un petit pilier)

- **Mécanique** : avant d'activer un petit pilier, une seconde action « Tribut : 1 P » (affichée seulement si le joueur a l'or, sinon « Tribut : il manque 30 or ») : l'or est versé **dans le pilier** (la jauge se remplit de pièces, accent émissif doré), le mini-boss apparaît **élite** (un affixe existant via `Enemy.apply_affix`, annoncé sur le pilier avant le tribut : « Tribut : Ours de givre, Poison »), PV × `PILLAR_TRIBUTE_HP_MULT` 1,3, zone ×2,0 (`ZONE_SPAWN_MULT[&"mini_tribute"]`). À sa mort, le pilier **rend** `PILLAR_TRIBUTE_RETURN_P` 1,5 P et lâche un **petit coffre gratuit**. Si le joueur meurt, la run est finie de toute façon : aucune pénalité supplémentaire. Gel des boss respecté : aucun nouveau mini-boss, aucun nouveau sort ; seulement l'affixe et les PV, comme le Paratonnerre dévié (retenu) sur le gros pilier.
- **Décision créée** : le premier **pari en or** de la run, à l'endroit même où le joueur « rush » aujourd'hui : « je mets le prix d'un coffre dans ce pilier, et si je gagne j'en ressors avec un coffre et demi de plus ». Aussi la première raison de **ne pas acheter** un coffre tout de suite (garder 1 P pour le tribut du pilier B).
- **Chiffres** : `PILLAR_TRIBUTE_P := 1.0` (plage 0,8-1,5), `PILLAR_TRIBUTE_RETURN_P := 1.5` (plage 1,2-2,0 : net +0,5 P d'or + 1 coffre ≈ 1 P, pour +30 % de PV, un affixe et une zone ×2 ; à 2,0 le tribut domine, à 1,0 personne ne le prend), `PILLAR_TRIBUTE_HP_MULT := 1.3`, `ZONE_SPAWN_MULT[&"mini_tribute"] := 2.0`, `PILLAR_TRIBUTE_AFFIXES := [&"burn", &"slow", &"poison"]`, `PILLAR_TRIBUTE_CHEST := &"petit"`. Un seul tribut par pilier ; les deux piliers peuvent l'être ; **Duo + Tribut** cumulables (c'est le « run à raconter »).
- **Effet sur la routine** : « rush les piliers pour l'or » devient « choisir quel pilier mérite une mise » ; et comme la mise exige d'avoir 1 P en poche **avant** le pilier, le premier tour des coffres n'est plus « tout acheter en passant ».
- **Coût de production** : code 1 jour (état `tribute` sur `Pillar`, sauvegardé ; `interact_priority` : Tribut avant Activer tant que non activé ; spawn élite ; remboursement et coffre à la mort) ; Codex : 0 prop (jauge de pièces = `_e.png` du pilier existant en 3 niveaux ou modulation en code) ; 1 son de pièces versées. **Aucun asset bloquant.**
- **Risques** : avec des mini-boss à 5 s, le tribut est de l'argent gratuit pour Taliant : **ne pas l'activer avant la revue des mini-boss** (ou `PILLAR_TRIBUTE_HP_MULT` 1,6 en attendant) ; « menu » : trois piliers avec chacun une option (Tribut ×2 + Paratonnerre dévié) : c'est le plafond, aucune autre option de pilier ne doit s'ajouter ; mobile : deux actions sur le même prop = `interact_priority` et libellé clair, comme prévu pour le Paratonnerre ; élite Brûlure sur mini-boss : 25 % du coup sur 3 s, plafond d'un coup 25 % des PV max inchangé.

### (b) Rendre la routine elle-même plus fun

#### 2.5 Les Coffres à vitrine et de catégorie (des coffres qui se lisent de loin)

- **Mécanique** : deux variantes qui remplacent, par étage, 2 des 8 petits coffres (tirage seedé dans `FloorPlan`) :
  - **Coffre à vitrine** : trois objets **visibles** flottent au-dessus (icônes 0,8 u, qualité tirée une fois : table `petit`), prix `CHEST_SHOWCASE_PRICE_P` 1,2 ; « Ouvrir » affiche les trois cartes, le joueur en **choisit une**, sans d100 ni relance. Hasard déplacé **avant** l'achat : on sait ce qu'on achète.
  - **Coffre de catégorie** : coffre marqué d'un **tag** (icône du tag : Feu, Givre, Poison, Survie, Recharge, Or, Critique, Zone ; tiré parmi les tags des objets possédés avec poids ×2, sinon uniforme), prix 1 P, d100 normal, mais les deux cartes portent ce tag. Un coffre qu'on achète **pour son build**.
- **Décision créée** : le tour de map devient une **lecture** : « la vitrine propose un Sifflet, je garde 1,2 P pour elle et je saute le coffre ordinaire d'à côté » ; « coffre Survie à 1 P : pas pour moi, je passe ». Deux fois par étage, le joueur **renonce** à un coffre ; aujourd'hui il n'en saute aucun.
- **Chiffres** : `CHEST_VARIANT_PER_STAGE := {&"showcase": 1, &"category": 1}` (plage 0-2 chacune ; jamais plus de 2 variantes par étage, sinon le coffre ordinaire devient le mauvais choix), `CHEST_SHOWCASE_PRICE_P := 1.2` (plage 1,1-1,4 : un choix parmi trois vaut un peu plus qu'un parmi deux au hasard ; cohérent avec l'Enclume retenue à 1,2 P pour un commun choisi), `CHEST_SHOWCASE_COUNT := 3`, `CHEST_CATEGORY_BUILD_WEIGHT := 2.0`. Budget d'objets inchangé (toujours 10 coffres).
- **Effet sur la routine** : ne la casse pas, la **densifie** : chaque coffre devient une question, pas un péage ; et la Boussole de rouille (retenue) a moins de raison d'être : si les deux entrent, garder la Boussole pour les grands coffres seulement.
- **Coût de production** : code 1 jour (`LootRoller.pick_n` avec filtre de tag ; `ChestUI` à 3 cartes sans roue ; `chest.gd` : variantes ; icônes flottantes = icônes d'objets existantes) ; Codex : 2 variantes de prop (vitrine à cloche, coffre à cartouche de tag), 8 icônes de tag 64 px (les tags existent déjà en texte), 1 son.
- **Risques** : lisibilité mobile des trois icônes flottantes (0,8 u chacune, en éventail, jamais superposées) ; stratégie : la vitrine à 1,2 P avec 3 choix pourrait dominer si elle offrait un rare : non, qualité tirée normalement (78/20/2) ; économie : prix total des 8 petits coffres 8,2 P au lieu de 8 (négligeable).

#### 2.6 Le Coffre de crue (un grand coffre dont le prix baisse, et qui coule à la mort du boss)

- **Mécanique** : un par étage 1-4, posé **dans l'eau peu profonde** (cases `,` des cartes : à vérifier avec le level-designer) : un grand coffre (table `large`) dont le prix **décroît** avec le temps actif de l'étage, de `CHEST_TIDE_START_P` 3,0 P à `CHEST_TIDE_FLOOR_P` 0,8 P atteint à `CHEST_TIDE_FLOOR_S` 240 s (linéaire, le prix est affiché et une jauge d'eau monte sur le coffre), et qui **coule** définitivement à la mort du boss d'étage (bulles, son, repère minimap retiré). Un grand coffre ordinaire de l'étage est retiré en échange (toujours 2 grands coffres au total).
- **Décision créée** : la première décision qui lie **le moment où l'on déclenche le boss** à une récompense : « j'attends 4 minutes pour l'avoir à 0,8 P, mais D monte de +0,6 ; ou je le paie 2 P maintenant et je lance le gros pilier ». Et pendant le combat de boss, « je sors de la zone de charge pour aller le payer avant la mort du boss ? » : un vrai dilemme au pic (Flow : tension qui monte, choix court).
- **Chiffres** : `CHEST_TIDE_START_P := 3.0`, `CHEST_TIDE_FLOOR_P := 0.8` (plage 0,6-1,0 : sous le prix d'un grand coffre à 2 P pour que l'attente paie, jamais gratuit), `CHEST_TIDE_FLOOR_S := 240.0` (plage 200-300 : ≈ la durée visée d'un étage sans farm ; à 180 s tout le monde attend, à 300 s personne), `CHEST_TIDE_SINK_ON_BOSS := true`. Puits d'or : entre 0,8 et 3 P selon le choix, à la place des 2 P fixes d'un grand coffre : espérance ≈ égale, variance choisie par le joueur.
- **Effet sur la routine** : « rush les piliers → boss » n'est plus gratuit : lancer le boss tôt **ferme** le coffre de crue ; le joueur qui farme l'or avant le boss a maintenant une raison lisible (le prix qui baisse) et un coût lisible (D qui monte sur la jauge).
- **Coût de production** : code 0,5 jour (`chest.gd` : variante `tide`, prix fonction du temps actif de l'étage, écoute de `Events.boss_killed`) ; Codex : 1 variante de prop (grand coffre avec jauge d'eau `_e.png` en 4 niveaux, anim « coule » 8 images), 2 sons (bulles, submersion).
- **Risques** : « attendre toujours » : coût D (+0,15/min) et le coffre reste à 0,8 P minimum, donc ≈ 3 min d'attente pour économiser 1,2 P : rentable seulement si le joueur farme réellement pendant ce temps (et alors il paie en D) : pente saine, à vérifier par télémétrie (part d'achats du coffre de crue visée 50-70 %, prix moyen payé ≈ 1,5 P) ; lisibilité : le prix changeant doit s'afficher sur le coffre **et** sur la minimap ; cartes sans eau peu profonde (Source) : pas de coffre de crue (étages 1-4 seulement).

#### 2.7 La Marée post-boss (la pression monte visiblement après la mort du boss)

- **Mécanique** : à la mort du boss d'étage, une **marée** commence : après `TIDE_GRACE_S` 30 s de calme (ramasser, acheter), les crédits du director montent linéairement jusqu'à `TIDE_CREDIT_MULT_MAX` 2,0 à `TIDE_RAMP_S` 90 s après le boss, et **l'or des kills ×1,5** (`TIDE_GOLD_MULT`) pendant la marée ; visuel : l'eau monte sur la carte (cases `,` qui s'élargissent, comme l'événement ambiant « Hostile » des Cryptes de `Design_Etages.md` §3), musique qui monte d'un cran, bandeau « La marée monte ». Les coffres restants **ne coulent pas** et leurs prix restent figés (le joueur garde le droit de farmer, décision CLAUDE.md : le téléporteur ne s'active que par « interagir »). Le téléporteur affiche « Partir (marée : ×1,6) » pour rendre la montée lisible.
- **Décision créée** : remplace le « Départ vif » (rejeté : pas compris) par un dilemme **visible dans le monde** : rester = plus d'or par kill (×1,5) et beaucoup plus de monstres (×2 à 90 s), partir = sécurité. Le farm post-boss devient un **pari situé et borné** au lieu d'un plateau : à 2 min de marée, l'étage est franchement dangereux pour un build moyen, et très rentable pour un build fort (Sirlin : le joueur fort choisit sa difficulté et en est payé).
- **Chiffres** : `TIDE_GRACE_S := 30.0` (plage 20-45 : le temps d'acheter 2-3 coffres au pas de course), `TIDE_RAMP_S := 90.0` (plage 60-120), `TIDE_CREDIT_MULT_MAX := 2.0` (plage 1,5-2,5 ; au-delà, le plafond de 150 vivants et les 250 monstres mobiles sont atteints trop vite), `TIDE_GOLD_MULT := 1.5` (plage 1,25-1,75 : doit rester sous le ×2 de la densité pour que l'or par unité de danger **baisse** en marée ; sinon rester domine), `TIDE_ELITE_MULT := 1.5` (part d'élites, lisibilité de la menace). Étage 5 : pas de marée (le boss final clôt la run).
- **Effet sur la routine** : « je refais un tour pour acheter les coffres et je pars » reste possible **dans les 30 s de grâce** ; au-delà, chaque coffre acheté coûte un cran de danger. Le second tour devient une course ou un pari, plus jamais une formalité.
- **Coût de production** : code 1 jour (`Director` : multiplicateur temporel de crédits et d'or, `StageManager` : état `tide` sauvé, HUD : bandeau et libellé du téléporteur) ; Codex : rien de nouveau si la montée d'eau réutilise les tuiles d'eau et le calque d'ambiance existants (à confirmer avec le level-designer et l'ambiance) ; 1 son de marée (nappe).
- **Risques** : **perf** : ×2 de crédits à D 5 = 60-100 vivants en marée tardive : plafond `RAMP_ALIVE_MAX` 150 respecté, mais à mesurer sur Android bas de gamme ; **mort** : la marée ne tue pas (plafonds de coup inchangés), mais un joueur lent qui s'obstine meurt : télémétrie « morts en marée » visée < 10 % des morts ; **collision** avec la seconde Prime de chasse (2.1), qui apparaît à la mort du boss : elle doit être rattrapable dans les 30 s de grâce + 30 s de marée douce (`HUNT_TIMEOUT_S` 60 s : cohérent) ; **mode Facile** : `TIDE_CREDIT_MULT_MAX` × `MODES` ? Non : même marée, elle est déjà plus douce parce que D l'est.

#### 2.8 La Zone chaude (la zone d'un petit pilier reste active après le mini-boss, en décroissant)

- **Mécanique** : à la mort d'un mini-boss, sa zone ×1,5 ne s'éteint plus d'un coup : elle reste **chaude** pendant `PILLAR_AFTERGLOW_S` 30 s avec l'or des kills ×1,5 (`PILLAR_AFTERGLOW_GOLD_MULT`), et sa densité **décroît** linéairement de ×1,5 à ×1,0 sur les 30 s (visuel : le cercle au sol pâlit, l'accent émissif du pilier s'éteint progressivement ; aucun HUD nécessaire, la jauge est le cercle).
- **Décision créée** : un micro-choix à chaque pilier : « je reste 10-15 s pour l'or chaud, ou je pars tout de suite vers le pilier B (et le Duo, 2.3) ? ». Ce choix est **opposé** au Duo : rester pour la zone chaude fait rater la fenêtre du duo ; deux bonnes façons de jouer le même pilier.
- **Chiffres** : `PILLAR_AFTERGLOW_S := 30.0` (plage 20-45), `PILLAR_AFTERGLOW_GOLD_MULT := 1.5` (plage 1,25-1,5), densité de ×1,5 → ×1,0 (`ZONE_SPAWN_MULT[&"mini_afterglow"]` interpolé). Or attendu si le joueur reste les 30 s : ≈ 0,5-0,7 P à l'étage 1 (≈ +6 % de l'or de l'étage), contre ≈ 0,3 P en marchant vers B.
- **Effet sur la routine** : « rush les deux piliers » gagne une **alternative à l'intérieur même du rush** : s'attarder. Rend l'étage un peu plus lent (+0-30 s) pour les joueurs qui restent : acceptable dans la cible 18-20 min (les runs réelles sont à 17:40 et 18:34).
- **Coût de production** : code 0,25 jour (`pillar.gd` : minuterie après `_on_boss_killed`, `_send_zone` avec un genre `mini_afterglow` et un facteur ; `Director.set_zone` accepte déjà un genre) ; Codex : rien ; 0 son (le crépitement de la zone existante baisse de volume).
- **Risques** : stratégie « rester 30 s à chaque pilier » devient une nouvelle routine si le ×1,5 d'or est trop fort : la décroissance de densité fait tomber le gain sous le farm ordinaire après ≈ 15 s, donc le point d'équilibre est à mi-chemin ; perf nulle ; lisibilité : le cercle qui pâlit doit rester dans la palette « utile » (cyan / accent du biome), jamais rouge.

---

## 3. Budget d'or et compatibilité avec les propositions déjà retenues

### 3.1 Sources et puits par étage (étage 1-4, en P, joueur qui prend tout)

| Élément | Source (+P) | Puits (−P) | Note |
|---|---|---|---|
| Existant : capsules, kills, primes | +9 à +10,5 | | mesuré §1.1 |
| Existant : 8 petits + 2 grands (+ légendaire 25 %) | | −12 (−20) | |
| 2.1 Primes de chasse (2 prises) | +1,6 (+0,5 en objet) | | |
| 2.2 Coffres gardés (2 pris) | +0,3 (kills du paquet) | +0,7 (remise) → le puits baisse | |
| 2.3 Duo | +0,6 (+1 en coffre) | | |
| 2.4 Tribut (×2) | +3,0 (+2 en coffres) | −2,0 | net +1 P + 2 coffres |
| 2.5 Vitrine | | +0,2 | |
| 2.6 Coffre de crue | | −0,8 à −3,0 (à la place de −2) | |
| 2.7 Marée (60 s restées) | +1 à +1,5 | | |
| 2.8 Zone chaude (×2) | +0,6 | | |
| **Total si tout est pris** | **+6 à +7 P** (+3,5 coffres) | **−0,5 à +1,5** | |

Si **tout** entre et que le joueur prend tout, le revenu d'un étage monte de ≈ 10 P à ≈ 16 P pour un puits de 12-13 P : l'or déborde. C'est pour cela que ce document **ne recommande pas d'implémenter les huit** (voir §4) et que les propositions retenues plus tôt comptent :
- **L'Enclume** (retenue) est le puits qui absorbe tout surplus (+1 exemplaire choisi à 1,2 / 2,5 / 6 P, 3 usages, toujours à l'étage 5 où 928-1 851 or sont aujourd'hui perdus).
- **Le Fondoir** rembourse moins que le prix (0,3 / 0,6 / 1,2 P) : aucune boucle avec 2.1-2.8.
- **Le Paratonnerre dévié** et **le Tribut** (2.4) sont la même grammaire sur deux piliers différents : lisible (« les piliers acceptent un pari »), mais à **ne pas** compléter par une troisième option de pilier.
- **Les Présages** (retenus) peuvent moduler les constantes de ce document (présage « Marée haute » : `TIDE_GRACE_S` 10 s, or ×2 ; présage « Chasse ouverte » : 4 primes de chasse) : à faire **après** que les mécaniques de base existent, sinon le joueur ne comprend pas ce que le présage modifie.

### 3.2 Ensemble recommandé (sélection qui tient dans l'enveloppe)

Primes de chasse (2.1) + Coffres gardés (2.2) + Duo (2.3) + Marée (2.7) + Enclume (retenue) : revenu ≈ +3 à +4 P par étage, puits ≈ +3 à +7 P (Enclume) : **équilibre tenu**, et chacune des quatre phases de la routine reçoit une décision : tour (gardés), piliers (duo), post-boss (prime et marée), or excédentaire (Enclume). Tribut (2.4), Vitrine (2.5), Coffre de crue (2.6) et Zone chaude (2.8) en seconde vague, selon la télémétrie.

---

## 4. Classement, ordre de production, ce qu'il ne faut pas faire

### 4.1 Top 3 (dans l'ordre)

| # | Proposition | Pourquoi d'abord | Lot code | Lot Codex |
|---|---|---|---|---|
| 1 | **2.1 Primes de chasse** | la seule qui donne un **autre but** que les coffres, avant et après le boss ; aucun nouveau monstre ; répond mot pour mot à « je n'ai aucune autre chose à faire » | `HuntDirector`, bandeau, récompense (1-1,5 j) | 1 marqueur `_e`, 1 icône, 2 sons |
| 2 | **2.3 Duo de piliers** | le moins cher (0,5 j, zéro asset) ; transforme le « rush » que le joueur décrit en un pari de temps ; existe déjà dans le GDD sans récompense | horodatage, versement, coffre | 1 son |
| 3 | **2.7 Marée post-boss** | corrige le faux choix « rester / partir » **dans le monde**, là où le Départ vif a échoué ; rend le second tour tendu | director (multiplicateur), état `tide`, HUD (1 j) | 1 nappe sonore ; eau montante = tuiles existantes |

Puis : 2.2 Coffres gardés (1 j, 1 variante de prop), 2.5 Vitrine et catégorie (1 j), 2.6 Coffre de crue (0,5 j), 2.8 Zone chaude (0,25 j), 2.4 Tribut **après la revue des mini-boss**.

### 4.2 Ce qu'il ne faut pas faire

1. **Ne pas retirer les capsules** ni les réduire brutalement : elles financent les 3-4 premiers coffres et la rampe du director rend le début d'étage pauvre ; si l'on veut moins de « tour », passer `CAPSULES_PER_STAGE` 10 → 8 et `CAPSULE_GOLD` 20 → 25 (même or, moins de points à visiter), pas plus.
2. **Pas plus d'une option par pilier** (Tribut sur les petits, Paratonnerre sur le gros) et **pas plus de 2 coffres spéciaux** par étage (gardés, vitrine, catégorie, crue confondus : tirage exclusif dans `FloorPlan`) : au-delà, l'étage devient un menu.
3. **Pas de coffre qui disparaît sans prévenir** : le coffre de crue annonce sa règle (jauge d'eau, « coule à la mort du boss » dans son libellé) ; les coffres ordinaires ne coulent jamais.
4. **Pas de marée qui ferme le téléporteur ni qui tue** : elle monte, elle ne piège pas ; plafonds de coup inchangés ; départ toujours possible.
5. **Pas de mini-boss renforcé en douce** pour rendre le Duo ou le Tribut « durs » : la revue des mini-boss est un chantier à part (gel), à mener avec les données ; en attendant, ne pas activer le Tribut.
6. **Pas de récompense attachée au seul kill d'un mini-boss** (prime ×3, coffre à chaque mini-boss) : tant que les mini-boss tombent en 5 s, ce serait de l'or gratuit sur le chemin, c'est-à-dire une capsule de plus.
7. **Pas de monnaie nouvelle** : tout se paie et se rend en or et en coffres existants.

---

## 5. Contrats, tests et télémétrie (pour l'orchestrateur)

- **`Balance`** (orchestrateur, `scripts/core/`) : `HUNT_PER_STAGE`, `HUNT_BOUNTY_P`, `HUNT_TIMEOUT_S`, `HUNT_ROAM_SPEED_U`, `HUNT_MIN_DIST_U`, `HUNT_CHEST_CHANCE`, `HUNT_ELITE_HP_MULT`, `HUNT_FIRST_WINDOW_S` ; `CHEST_GUARDED_PER_STAGE`, `CHEST_GUARDED_DISCOUNT`, `CHEST_GUARDED_WAKE_U`, `CHEST_GUARDED_CREDITS_P`, `CHEST_GUARDED_RING_U`, `CHEST_GUARDED_SLEEP_AGAIN_S` ; `PILLAR_DUO_WINDOW_S`, `PILLAR_DUO_BOUNTY_MULT`, `PILLAR_DUO_CHEST` ; `PILLAR_TRIBUTE_P`, `PILLAR_TRIBUTE_RETURN_P`, `PILLAR_TRIBUTE_HP_MULT`, `PILLAR_TRIBUTE_AFFIXES`, `PILLAR_TRIBUTE_CHEST`, `ZONE_SPAWN_MULT[&"mini_tribute"]` ; `CHEST_VARIANT_PER_STAGE`, `CHEST_SHOWCASE_PRICE_P`, `CHEST_SHOWCASE_COUNT`, `CHEST_CATEGORY_BUILD_WEIGHT` ; `CHEST_TIDE_START_P`, `CHEST_TIDE_FLOOR_P`, `CHEST_TIDE_FLOOR_S`, `CHEST_TIDE_SINK_ON_BOSS` ; `TIDE_GRACE_S`, `TIDE_RAMP_S`, `TIDE_CREDIT_MULT_MAX`, `TIDE_GOLD_MULT`, `TIDE_ELITE_MULT` ; `PILLAR_AFTERGLOW_S`, `PILLAR_AFTERGLOW_GOLD_MULT`, `ZONE_SPAWN_MULT[&"mini_afterglow"]`.
- **`Events`** : `hunt_started(elite, timeout_s)`, `hunt_ended(success: bool)`, `chest_guard_woken(chest)`, `chest_guard_cleared(chest)`, `pillar_duo(pillars)`, `pillar_tribute(pillar, affix)`, `tide_started(stage)`, `tide_level(mult)`.
- **`FloorPlan`** : tirage seedé des coffres spéciaux (exclusif), de la prime de chasse (points de patrouille) ; options `-- --force-hunt`, `-- --force-guarded=<n>`, `-- --force-tide` pour le mode test ; panneau TAB : lancer une prime, réveiller un paquet, démarrer la marée.
- **Tests** : `hunt_test` (apparition hors écran, patrouille, délai, récompense, sauvegarde aller-retour), `guarded_chest_test` (verrouillage tant qu'un gardien vit, remise, rendormissement), `pillar_duo_test` (fenêtre, versement une seule fois, coffre), `tide_test` (grâce, rampe, plafond de vivants, téléporteur toujours actif), `economy_test` étendu (revenu par étage avec 2.1 + 2.3 + 2.7 dans [+2,5 P ; +4,5 P]).
- **Télémétrie `RunLog`** (pour trancher les plages) : primes proposées / prises / réussies ; coffres gardés réveillés / achetés ; duos tentés / réussis et écart A → B ; temps passé en marée et or gagné en marée, morts en marée ; prix payé pour le coffre de crue ; or perdu à la fin de l'étage 5 (cible : < 1 P avec l'Enclume).
- **Consultants à croiser** : level-designer (distance entre petits piliers 15-30 u pour le Duo ; cases `,` pour le coffre de crue ; points de patrouille de la prime ; montée d'eau de la marée) ; ux-designer (bandeaux, prix barré, compte à rebours du duo, libellé du téléporteur en marée, vitrine à 3 cartes tactile et manette) ; systems-designer (plages des constantes sur `economy_test`, grille de points des objets gratuits de 2.1 et 2.3).
