# Refonte de la structure d'étage : quatre boucles d'étage contrastées (design v1)

> Statut : **proposition de game design** (Fable, designer-fable, 01/11/2026), sur retour du joueur : « souvent dans les games je dois rush les deux piliers de mini-boss pour générer des golds, je fais un tour de map pour prendre les coffres, je tue le boss, je refais un tour de map pour acheter les coffres et je pars, je fais ça en boucle, je n'ai aucune autre chose à faire ». Réponses du joueur aux premières propositions : primes de pilier et duo de piliers ne convainquent pas ; « il faudrait peut-être revoir le fonctionnement de la boucle » ; marée post-boss rejetée (« le swarm en fin de pilier serait trop fort ») ; revente des coffres au téléporteur pas comprise.
> Ce document ne propose **aucun bonus** : il repense ce que le joueur **fait** entre l'arrivée et le départ. Les ateliers (Fondoir, Matrice, Alambic, Enclume, Boussole, Paratonnerre dévié), les Présages, les coffres à vitrine et les capsules 10 → 4 sont acquis et compatibles avec les quatre refontes (§6).
> Lu avant d'écrire : `CLAUDE.md`, `docs/GDD.md`, `docs/Design_Etages.md`, `docs/Design_Etage2_Grotte.md`, `docs/Boucle_Etage_Level.md`, `docs/Boucle_Etage_Design.md`, `docs/Ateliers_Chiffres.md`, `docs/Design_Variantes_B.md` §1.1, `docs/Design_Boss_Raid.md` §0, `game/scripts/core/balance.gd`, `game/scripts/stage/pillar.gd`, `stage_manager.gd`, `game/scripts/director/director.gd`, `game/data/maps/foret_brume.json`, `game/data/floors.json`.
> Contraintes : gel des boss (aucun boss ni mini-boss nouveau, aucun sort de boss nouveau ; les mini-boss existants sont réutilisés tels quels), télégraphes ≥ 0,8 s, aucune mort instantanée, aucun piège de terrain, trois plateformes (joystick + sort 1 automatique + sorts 2-4 en ciblage automatique sur mobile ; toute interaction par « interagir »), téléporteur activé par « interagir » seulement, aucun nom ni design repris de Risk of Rain ou de Vampire Survivors. Aucun fichier de `game/` n'est modifié.
> Unités : 1 u = 64 px ; joueur à 4,0 u/s (`Balance.PLAYER_SPEED_U`) ; **P** = prix d'un petit coffre au début de l'étage (≈ 50 / 108 / 195 / 349 or aux étages 1-4 en Moyen, journaux du 31/10/2026). Les durées sont des budgets (distance ÷ vitesse, durées mesurées des combats), pas des parties jouées.

---

## 0. Pourquoi la boucle actuelle se résout toujours de la même façon

Les deux avis précédents (`Boucle_Etage_Level.md` §0, `Boucle_Etage_Design.md` §1) ont mesuré la routine. Trois faits suffisent ici :

1. **Le pilier est un robinet, pas une rencontre.** Les mini-boss meurent en 3-30 s (journaux) ; ce que le pilier apporte, c'est la zone ×1,5 de monstres, donc de l'or. Activer un pilier est un geste de 1 s suivi d'un combat court. Il n'y a rien à **faire** au pilier.
2. **Le marché est connu dès la seconde 0 et ne bouge jamais.** Dix coffres posés, prix figés, minimap complète. La seule question est le trajet.
3. **Rien ne distingue un étage d'un autre dans les gestes.** Les biomes changent le décor et les monstres, pas ce que le pouce fait.

Les quatre refontes ci-dessous changent chacune **un axe** de la structure, pour pouvoir les comparer :

| Refonte | Axe changé | Ce qui remplace « rush piliers → tour → boss → tour » | Habileté ou décision demandée |
|---|---|---|---|
| **A · Les Épreuves** | les **verbes** : les deux petits piliers deviennent deux épreuves à mécanique propre au biome | escorter, fermer des vannes, suivre une lumière, tenir un point, suivre une veine | mouvement sous pression, ordre des relais, lecture du tracé |
| **B · La Roue des marées** | l'**espace** : la carte se transforme au fil de l'étage (quartiers qui se noient et s'assèchent) | un circuit en trois quartiers dans l'ordre choisi par le joueur, jamais deux fois le même quartier | ordre des quartiers, acheter avant la crue ou plus tard |
| **C · Le Tableau de chasse** | l'**économie** : l'or vient de marques mobiles à abattre, plus des zones ni des capsules | une chasse continue qui traverse la carte ; les mini-boss sont des trophées dans leur tanière | route vers une cible mobile, chaîne de marques, choix de la cible |
| **D · La Descente** | l'**ordre** : l'étage devient trois salles franchies par des portes | un parcours en avant, marché local à chaque salle, sortie dans la dernière | dépenser maintenant ou garder pour la salle suivante |

Toutes gardent le **gros pilier** (zone de charge 60 s, boss d'étage, coffre de boss, Paratonnerre dévié) : c'est le pic de l'étage, il n'est pas en cause.

---

## 1. Refonte A · Les Épreuves (piliers à mécanique propre au biome)

### 1.1 Principe

Les deux petits piliers d'un étage deviennent deux **épreuves** : un objet de carte (barque, vanne, lanterne, cloche, veine) qui demande **30-40 s d'adresse** avant que le mini-boss existant n'apparaisse. L'épreuve est le contenu ; le mini-boss reste la ponctuation (inchangé, gel respecté). La zone de monstres ×1,5 (`ZONE_SPAWN_MULT[&"mini"]`) suit l'épreuve (elle **bouge** avec la barque, la lumière ou la veine). L'épreuve est **notée** (parfait / bien / fait) et c'est elle qui verse l'or, pas la zone.

Cinq verbes au total, deux par biome (donc **deux épreuves différentes à chaque étage, et jamais les mêmes d'un étage à l'autre**) :

| Verbe | Ce que fait le joueur | Biomes (habillage) | Habileté |
|---|---|---|---|
| **Escorte** | Interagir sur un chariot/une barque ; elle suit un tracé fixe à 2,5 u/s et **s'arrête** si le joueur s'éloigne à plus de 6 u (corde visible) ; les monstres la frappent au contact (PV = 0,3 × PV d'un mini-boss) ; à 0 PV elle s'immobilise 5 s et repart (jamais détruite). À l'arrivée, le mini-boss surgit. | Terrasses (barque de noria sur le canal), Cité (wagonnet sur rails) | rester au contact tout en nettoyant devant ; choisir quand ouvrir un coffre du tracé |
| **Rituel** | Trois **relais** (vannes, soupapes) à 10-14 u autour d'un cœur qui **pulse** : tous les 12 s, un anneau télégraphié 1,0 s (coef 1,0, plafond de coup inchangé). Fermer un relais = maintenir « interagir » 1,2 s à 1,5 u (annulé si le joueur s'éloigne, jamais par un dégât). Trois relais fermés → le cœur s'ouvre, le mini-boss apparaît. | Terrasses (vannes de l'écluse), Cité (soupapes de la pompe) | ordre des relais (le cœur pulse plus vite à chaque relais fermé : 12 → 9 → 7 s), fenêtre entre deux pulsations |
| **Poursuite** | Une lumière (follet de mycélium, éclat de cristal) **saute** entre 5-6 lampadaires de la carte toutes les 8 s ; atteindre le lampadaire allumé avant le saut = 1 point ; 5 points → la lumière se fixe, le mini-boss sort de terre dessous. Aucune créature : un VFX et des props. | Gouffre (mycélium), Cryptes (cristal) | itinéraire et vitesse sous pression (la zone ×1,5 suit la lumière) ; sauter un lampadaire trop loin |
| **Veine** | Un disque de 6 u (`,` lumineux) glisse le long d'une boucle de 60 u à 1,5 u/s ; la charge (30 s) n'avance que dedans ; sur la boucle, des geysers télégraphiés 1,0 s obligent à sortir puis rentrer. Charge pleine → le mini-boss émerge au centre du disque. | Gouffre (rivière d'infiltration), Cryptes (eau noire) | sortir et rentrer au bon moment ; ne pas se laisser distancer |
| **Tenue** | Une structure (cloche d'alerte, chaudière) à PV = 0,5 × PV d'un mini-boss ; pendant 40 s, trois **côtés annoncés** (flèches `wave_indicator` existantes, 2 s d'avance) envoient des paquets qui visent la structure (contact seulement) ; à 40 s, le mini-boss arrive par le dernier côté. La structure à 0 PV ne casse pas : elle « s'éteint » (note fait). | Cité (cloche), Terrasses (noria de secours) | se placer sur le côté annoncé, intercepter avant le contact |

Attribution : Terrasses = Escorte + Rituel ; Gouffre = Poursuite + Veine ; Cité = Tenue + Rituel (soupapes) ; Cryptes = Veine + Poursuite (ordre inversé, tracés différents). Variantes A/B d'un biome : mêmes verbes, tracés et relais différents (c'est ce qui fait la variante). Un run voit donc 8 épreuves, 5 verbes, et l'ordre des deux épreuves d'un étage est libre.

**Le marché suit les épreuves.** Les 8 petits coffres et 2 grands sont tirés parmi les candidats à **≤ 8 u du tracé** d'une épreuve (3 + 3), **autour de l'arène du boss** (3) et **au départ** (1). Le « tour » n'existe plus : les coffres sont sur le chemin de ce que le joueur fait. Après le boss, il reste les coffres de l'arène : on achète, on part.

### 1.2 Un étage minute par minute (Terrasses, Escorte puis Rituel)

| Temps | Ce qui se passe | Intensité |
|---|---|---|
| 0:00-0:15 | Arrivée. Un coffre et une capsule au départ. Deux icônes sur la minimap : barque, écluse. Le joueur choisit par laquelle commencer. | basse |
| 0:15-0:50 | **Escorte** : interagir sur la barque au ponton ; elle descend le canal (≈ 75 u, 30 s si jamais arrêtée). Zone ×1,5 autour d'elle. Trois coffres sur les rives : ouvrir l'un d'eux arrête la barque (corde tendue) : ça coûte 5-8 s. Parfait si la barque arrive en ≤ 40 s sans s'être immobilisée. | montée, pic 1 |
| 0:50-1:10 | Le mini-boss surgit au ponton d'arrivée (Héron de fer, Crapaud-cuve… tirage normal). Combat ordinaire. | pic 1 |
| 1:10-1:25 | Trajet vers l'écluse (≈ 40-60 u). Capsules, atelier sur la case `E` si c'est sa route. | basse |
| 1:25-2:00 | **Rituel** : le cœur de l'écluse pulse ; trois vannes à fermer (1,2 s chacune), le cœur accélère. Trois coffres autour des vannes. Parfait si les trois vannes sont fermées en ≤ 35 s sans toucher un anneau. | pic 2 |
| 2:00-2:20 | Mini-boss au centre de l'écluse. | pic 2 |
| 2:20-2:35 | Trajet vers le gros pilier. | basse |
| 2:35-3:50 | Gros pilier, charge 60 s, boss d'étage (inchangé ; Paratonnerre dévié possible). Trois coffres au bord de l'arène. | pic 3 |
| 3:50-4:05 | Coffre de boss, coffres de l'arène, téléporteur. | basse, sortie |

Durée visée **3:50-4:10** en Moyen, à comparer aux 3:25-4:50 mesurés (boss mort + sortie). Levier si trop long : `PILLAR_CHARGE_S` 60 → 45 quand les épreuves sont actives, ou cible « parfait » des épreuves à 30 s.

### 1.3 Chiffres

| Constante (`Balance`) | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `EPREUVE_GOLD_P` | `{parfait: 2.0, bien: 1.4, fait: 0.8}` | 1,5-2,5 / 1,0-1,6 / 0,5-1,0 | or versé à la fin de l'épreuve (pièces au sol), en P ; remplace la fonction « robinet » de la zone |
| `EPREUVE_TARGET_S` | `{escorte: 40, rituel: 35, poursuite: 45, veine: 40, tenue: 40}` | ±10 s | seuil « parfait » ; « bien » = seuil × 1,5 ; « fait » au-delà ou sur échec partiel |
| `EPREUVE_BACKSTOP_S` | 75 | 60-90 | passé ce délai, l'épreuve se termine d'elle-même en « fait » (le mini-boss apparaît) : jamais bloqué |
| `ESCORT_SPEED_U` / `ESCORT_LEASH_U` | 2,5 / 6,0 | 2,0-3,0 / 5-8 | vitesse du chariot, corde |
| `ESCORT_HP_MINI_SHARE` / `ESCORT_STALL_S` | 0,3 / 5,0 | 0,2-0,4 / 4-6 | PV du chariot, arrêt à 0 PV |
| `RITUAL_RELAYS` / `RITUAL_HOLD_S` / `RITUAL_PULSE_S` | 3 / 1,2 / `[12, 9, 7]` | 3 / 1,0-1,5 / 8-14 | relais, maintien, cadence du cœur |
| `CHASE_POSTS` / `CHASE_JUMP_S` / `CHASE_POINTS` | 6 / 8,0 / 5 | 5-6 / 7-10 / 4-6 | lampadaires, cadence des sauts, points requis |
| `VEIN_RADIUS_U` / `VEIN_SPEED_U` / `VEIN_CHARGE_S` | 6,0 / 1,5 / 30 | 5-7 / 1,2-2,0 / 25-35 | disque, vitesse, charge |
| `HOLD_HP_MINI_SHARE` / `HOLD_DURATION_S` / `HOLD_SIDES` | 0,5 / 40 / 3 | 0,4-0,6 / 35-45 / 3 | structure, durée, côtés annoncés |
| `ZONE_SPAWN_MULT[&"epreuve"]` | 1,5 | 1,3-1,6 | la zone suit l'objet mobile de l'épreuve |

Budget d'or (estimé) : aujourd'hui un petit pilier rapporte ≈ 0,3 P de prime + 0,5-0,9 P de kills en zone. Une épreuve rapporte 0,8-2,0 P + ses kills en zone (durée plus longue : ≈ 0,8-1,2 P) + la prime du mini-boss (0,3 P). Net : **+0,6 à +2 P par épreuve** selon la note. Compensation : capsules 10 → 4 (déjà validé, −2,4 P) et **or des kills en zone d'épreuve ×0,5** (`EPREUVE_ZONE_GOLD_MULT`, l'or vient de la note, pas du farm). Reste à caler par systems-designer avec `economy_test` (cible : or par étage dans la bande 8-10,5 P mesurée).

### 1.4 Mobile, gel, coût, risques

- **Mobile** : chaque verbe se joue au joystick seul (suivre, atteindre, rester dedans, se placer) ; les interactions sont « interagir » (relais : maintien, comme le téléporteur à 0,6 s). Les sorts 2-4 en ciblage automatique suffisent (les cibles sont les monstres ordinaires). Icônes de minimap : une par verbe (5) ; flèche `OffscreenCues` sur l'objet mobile.
- **Gel des boss** : respecté intégralement. Les mini-boss sont tirés et instanciés comme aujourd'hui (`Director.spawn_boss`), à la fin de l'épreuve au lieu de l'activation. Aucun comportement de mini-boss modifié.
- **Coût** : code ≈ **10-12 jours** (classe `Epreuve` + sauvegarde + minimap + notes : 2 j ; cinq verbes : 1-1,5 j chacun ; tracés, relais et lampadaires dans les 8 JSON de carte : 2 j ; tests : 1 j). Codex : ≈ 8 lots `low` (barque et wagonnet 8 directions ; vanne et soupape 2 états ; lampadaire éteint/allumé ×2 biomes ; cloche et noria de secours 3 états ; disque de veine et geyser ; 5 icônes ; ≈ 8 sons). **Le plus cher des quatre**, mais prototypable sans aucun asset (§5).
- **Risques** : durée d'étage (+20-40 s si les épreuves ne remplacent pas le tour : à mesurer) ; la Tenue est le verbe le plus proche d'un test de puissance (un build faible perd la structure) : elle note sans punir et reste réservée à la Cité ; corde de l'escorte frustrante si les monstres bloquent le passage (la barque **pousse** les monstres sur son tracé, pas le joueur) ; lisibilité du disque de veine dans l'eau des Cryptes (accent cristal, bord 0,3 u).

---

## 2. Refonte B · La Roue des marées (la carte se transforme)

### 2.1 Principe

Chaque carte est découpée (level design, grille existante) en un **moyeu** (gros pilier, départ, jamais noyé) et **trois quartiers** Q1, Q2, Q3. À tout moment, **un quartier est noyé** : ses cases de sol deviennent de l'eau peu profonde `,` (praticable, −20 % de vitesse, zone ×1,5 de monstres « de crue »), ses coffres et capsules sont **submergés** (silhouette sous l'eau, inaccessibles, prix inchangé), son pilier est éteint. À l'arrivée, Q3 est noyé ; Q1 et Q2 ont chacun un petit pilier.

La **roue tourne à chaque pilier terminé** : à la mort du mini-boss de Q1, un compte de 20 s démarre (anneau d'eau qui monte sur les bords du quartier, bruit de vanne, bandeau « Q1 se noie ») ; à 0, Q1 se noie et **Q3 s'assèche** (ses coffres remontent, son pilier s'allume). Le joueur a 20 s pour acheter ce qu'il veut encore dans Q1. Le second pilier (dans Q2 ou Q3) fait tourner la roue une seconde fois. Après le boss (moyeu), la roue s'arrête : **tout s'assèche** et le téléporteur apparaît dans le quartier **le moins visité** (celui qui a passé le plus de temps noyé). Le trajet de sortie traverse donc le dernier quartier, pas la carte entière.

Rien ne piège : l'eau est praticable, aucun dégât, aucune porte ; ce qui se ferme, c'est le **marché** du quartier, et il rouvre une rotation plus tard.

### 2.2 Un étage minute par minute (Terrasses, Q1 d'abord)

| Temps | Ce qui se passe | Décision |
|---|---|---|
| 0:00-0:15 | Arrivée au moyeu. Minimap : Q3 bleu (noyé), Q1 et Q2 à sec avec leurs 3 coffres chacun et leur pilier. | « Q1 ou Q2 d'abord ? » (le quartier fait en premier sera noyé en deuxième : ses coffres non achetés attendront la fin) |
| 0:15-0:55 | Q1 : coffres sur le chemin, capsules, pilier, mini-boss (combat ordinaire). | « j'achète maintenant ou je garde mon or pour Q3 que je n'ai pas vu ? » |
| 0:55-1:15 | Compte de 20 s : Q1 se noie, Q3 s'assèche. Dernier achat dans Q1, puis trajet. | « un dernier coffre ici, ou je pars vers Q3 ? » |
| 1:15-1:55 | Q3 (sec pour la première fois) ou Q2 : pilier, mini-boss. Le quartier non choisi reste à sec. | « lequel des deux ? celui que je laisse sera noyé pendant le boss » |
| 1:55-2:15 | Seconde rotation : le quartier fait se noie, celui qui était noyé s'assèche. | |
| 2:15-3:30 | Moyeu : gros pilier, charge, boss (inchangé). | |
| 3:30-4:00 | Tout s'assèche. Téléporteur dans le quartier le moins visité : trajet de 20-30 s avec ses coffres restants sur la route, départ. | « j'achète ce qui reste sur ma route ou pas » |

Durée visée **3:45-4:00**. Le « second tour » devient un **trajet de sortie orienté** de 20-30 s à travers un seul quartier.

### 2.3 Chiffres

| Constante | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `TIDE_WHEEL_QUARTERS` | 3 | 3 | quartiers hors moyeu |
| `TIDE_WHEEL_FLOOD_DELAY_S` | 20 | 15-30 | délai entre la mort du mini-boss et la crue du quartier |
| `TIDE_WHEEL_FLOODED_SLOW` | 0,20 | 0,15-0,25 | ralentissement dans un quartier noyé (jamais de blocage) |
| `ZONE_SPAWN_MULT[&"flooded"]` | 1,5 | 1,3-1,6 | monstres de crue dans le quartier noyé |
| `TIDE_WHEEL_EXIT_RULE` | `&"least_visited"` | — | placement du téléporteur après le boss |
| Clé de carte `quarters` | `[{"id": "Q1", "cells": [...], "pillar": [x, y], "chests": 3}]` | — | découpe par quartier ; `hub` pour le moyeu |

Budget d'or : aucun or nouveau (pas de prime, pas de bonus) ; même nombre de coffres (3 + 3 + 3 + 1 au moyeu). Les prix restent figés au D d'entrée : attendre qu'un quartier s'assèche ne coûte que D.

### 2.4 Mobile, gel, coût, risques

- **Mobile** : la roue se lit sur la minimap (quartier bleu) et au sol (anneau d'eau qui monte, 20 s) ; aucune interaction nouvelle. Bandeau de 2 s à chaque rotation.
- **Gel** : respecté ; piliers et mini-boss inchangés ; le boss d'étage inchangé.
- **Coût** : code ≈ **4-5 jours** (état de la roue dans `StageManager`, bascule des cellules sol ↔ `,` à l'exécution avec recalcul de `NavField` et `reach_field()`, coffres et capsules submergés dans `chest.gd` / `gold_capsule.gd`, placement du téléporteur, minimap, sauvegarde). Level design : découper les 8 cartes en moyeu + 3 quartiers (≈ 0,5 j par carte : 4 j). Codex : 1 lot (eau qui monte : bande de bord tuilable, état « submergé » des coffres et capsules, 2 sons).
- **Risques** : le rendu du sol est en refonte (`Design_Etage2_Grotte.md`) : la bascule sol ↔ `,` à l'exécution dépend du nouveau système ; les cartes à peu d'eau (Cité, Cryptes B) demandent un habillage de crue crédible (vapeur, sel ?) ; un joueur qui ignore la roue fait un étage presque identique à aujourd'hui (la refonte est **douce**) ; monstres de crue : perf identique (même plafond).

---

## 3. Refonte C · Le Tableau de chasse (l'or vient des actions)

### 3.1 Principe

**Plus de capsules, plus d'or aux kills ordinaires** (XP inchangée). L'or vient de **marques** : toutes les 6 s, le director marque un monstre vivant (tier 2-3 de préférence, toute élite est marquée à l'apparition) d'un halo du biome et d'un jeton flottant. Tuer une marque fait tomber `MARK_GOLD_P` 0,15 P. Si la marque n'est pas tuée en 12 s, **le jeton s'envole** vers un autre monstre, plus loin du joueur (vol visible 1 s, flèche hors écran). Tuer une marque **moins de 5 s** après la précédente allonge une **chaîne** : +25 % par maillon, plafond ×2 ; le chiffre « ×1,75 » s'affiche au-dessus du joueur. Le director place les marques de préférence **vers les coffres non achetés** (biais de 60 % sur le secteur de la carte où reste le plus de coffres) : la chasse conduit au marché.

Les petits piliers disparaissent. Les deux mini-boss de l'étage sont des **trophées** : chacun dort dans une **tanière** (repère de minimap visible dès l'arrivée) et s'éveille quand le joueur approche à 10 u (`LAIR_WAKE_U`) ; comportement de combat inchangé. Un trophée vaut `TROPHY_GOLD_P` 1,5 P. Le gros pilier s'allume quand **les deux trophées sont pris** (ou, garde-fou, quand le tableau atteint `HUNT_QUOTA` 20 marques : jamais bloqué). Le boss d'étage est la grande marque (`BOSS_MARK_P` 3 P, remplace `boss_gold`).

Après le boss, la chasse continue tant que le joueur reste : pas de vague, pas de marée, le même flux, seulement des marques à aller chercher. Rester est une **activité**, partir est un choix.

### 3.2 Un étage minute par minute

| Temps | Ce qui se passe | Décision / habileté |
|---|---|---|
| 0:00-0:20 | Arrivée. Deux tanières et dix coffres sur la minimap. Premières marques dans le flux. | « quel trophée d'abord ? par quels coffres ? » |
| 0:20-1:00 | Chasse vers la tanière 1 : marques tuées en chemin (5-7), chaînes de 2-3. Le jeton qui s'envole oblige à choisir : suivre ou laisser. | route vers une cible mobile, chaîne |
| 1:00-1:20 | Trophée 1 (mini-boss ordinaire). | |
| 1:20-2:00 | Chasse vers la tanière 2, biaisée vers le secteur des coffres restants. Achats au passage. | |
| 2:00-2:20 | Trophée 2. Le gros pilier s'allume. | |
| 2:20-3:35 | Gros pilier, charge, boss (inchangé, grande marque). | |
| 3:35-4:00 | Chasse de sortie : 2-3 marques sur la route du dernier coffre voulu, téléporteur. | « je continue à chasser ou je pars » |

Durée visée **3:50-4:05**.

### 3.3 Chiffres

Cible : l'or par étage reste dans la bande mesurée (8-10,5 P). Hypothèse : 1 marque toutes les 6 s = 10 par minute ; le joueur en tue ≈ 60 % (6/min) à 0,15 P = 0,9 P/min, chaîne moyenne ×1,3 → ≈ 1,2 P/min sur 3,5 min = 4,2 P ; + 2 trophées 3 P ; + boss 3 P (dont une part remplace `boss_gold`) ; total ≈ 9-10 P. **Estimé, à caler sur `economy_test`.**

| Constante | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `MARK_INTERVAL_S` | 6,0 | 5-8 | cadence de marquage |
| `MARK_GOLD_P` | 0,15 | 0,10-0,20 | or par marque |
| `MARK_FLY_AFTER_S` | 12 | 10-15 | le jeton s'envole |
| `MARK_CHAIN_WINDOW_S` / `MARK_CHAIN_STEP` / `MARK_CHAIN_CAP` | 5,0 / 0,25 / 2,0 | 4-6 / 0,2-0,3 / 1,75-2,5 | chaîne |
| `MARK_CHEST_BIAS` | 0,6 | 0,4-0,7 | part des marques dirigées vers le secteur des coffres restants |
| `KILL_GOLD_MULT_HUNT` / `CAPSULES_PER_STAGE` | 0 / 0 | 0-0,2 / 0 | plus d'or diffus |
| `TROPHY_GOLD_P` / `BOSS_MARK_P` | 1,5 / 3,0 | 1,0-2,0 / 2,5-3,5 | trophées |
| `LAIR_WAKE_U` | 10 | 8-12 | éveil du trophée |
| `HUNT_QUOTA` | 20 | 15-25 | garde-fou d'ouverture du gros pilier |

### 3.4 Mobile, gel, coût, risques

- **Mobile** : la chasse est un jeu de déplacement ; le sort 1 et le ciblage automatique des sorts 2-4 font le reste. Petit ajout : `SpellCaster._nearest_enemy` préfère une marque à portée (`MARK_AIM_PRIORITY`), sinon le joueur mobile ne peut pas « viser » la marque. Halo ≥ 0,3 u d'épaisseur, jeton 0,6 u émissif, flèche de bord d'écran.
- **Gel** : mini-boss inchangés dans leur combat ; seul ajout, un **rayon d'éveil** avant le premier contact (un drapeau `dormant` dans `Director.spawn_boss`, pas une mécanique de boss). À valider comme compatible avec le gel.
- **Coût** : code ≈ **4 jours** (`HuntDirector` : marquage, vol du jeton, chaîne, biais ; tanières et éveil ; ouverture du gros pilier ; priorité de ciblage ; HUD « tableau » ; minimap ; sauvegarde ; retrait des capsules et de l'or diffus derrière un drapeau). Codex : 2 lots `low` (halo `_e` teinté en code, jeton, 4 tanières, icônes, 3 sons).
- **Risques** : c'est la refonte la plus **sensible à l'équilibrage** (toute l'économie passe par une seule source) ; un build à grande zone tue les marques sans les chercher (la chasse devient passive : levier `MARK_FLY_AFTER_S` plus court, marques placées hors de la portée du build) ; le rythme de D monte si le joueur chasse longtemps après le boss (coût voulu, pas de mur) ; lisibilité : au plus **une marque active à la fois** (le jeton vole, il ne se duplique pas) ; la routine « tour des coffres » reste possible si le biais vers les coffres est trop fort (viser 60 %, mesurer par `RunLog`).

---

## 4. Refonte D · La Descente (trois salles, un sens)

### 4.1 Principe

La carte est redécoupée en **trois salles** reliées par deux **portes** (réutilisation de la porte `D` des zones secrètes, caractère `R`, deux états). Salle 1 (arrivée, ≈ 30 % de la carte, ouverte), Salle 2 (≈ 40 %, couloirs et boucles), Salle 3 (≈ 30 %, arène du boss et sortie). La porte 1 → 2 s'ouvre à la mort du mini-boss du pilier de la Salle 1 ; la porte 2 → 3 à celle du pilier de la Salle 2. Une porte ouverte le reste (revenir en arrière est permis, mais long : les portes sont aux extrémités). Chaque porte affiche **ce qui attend derrière** (« Salle 2 : 3 petits, 1 grand, un atelier ») : le joueur sait ce qu'il garde son or pour. Coffres : 3 / 4 / 3 ; le coffre légendaire (25 %) est toujours en Salle 3. L'atelier est en Salle 2. La minimap ne montre que les salles ouvertes.

La routine tombe par construction : il n'y a **pas de tour** (le marché est local), **pas de rush** (le pilier suivant n'existe pas encore), **pas de second tour** (la sortie est dans la salle du boss). Ce que l'étage demande, c'est de **doser** : dépenser 3 P maintenant sur les petits coffres de la Salle 1, ou garder pour le grand coffre annoncé de la Salle 2.

Pour que l'ordre ne soit pas toujours le même, chaque carte définit **trois découpes** (laquelle des trois zones est la salle d'arrivée) : la même grille se joue dans trois sens.

### 4.2 Un étage minute par minute

| Temps | Ce qui se passe | Décision |
|---|---|---|
| 0:00-0:50 | Salle 1 : 3 coffres, capsules, pilier, mini-boss. La porte affiche la Salle 2. | « 1, 2 ou 3 coffres ici ? » |
| 0:50-1:00 | Franchir la porte (pas de retour prévu). | |
| 1:00-2:00 | Salle 2 : 4 coffres dont 1 grand, l'atelier, pilier, mini-boss. La porte affiche la Salle 3 (légendaire ou non). | « grand coffre ou atelier ? garder pour le légendaire ? » |
| 2:00-2:10 | Porte. | |
| 2:10-3:25 | Salle 3 : gros pilier, charge, boss ; 3 coffres au bord de l'arène. | |
| 3:25-3:45 | Coffre de boss, derniers achats sur place, téléporteur à 10 u. | |

Durée visée **3:35-3:50** (la plus courte des quatre : plus aucun trajet à vide).

### 4.3 Chiffres

| Constante | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `DESCENT_ROOMS` | 3 | 3 | salles |
| `DESCENT_CHESTS` | `[3, 4, 3]` | somme 10 | répartition (le grand en Salle 2 et 3, le légendaire en Salle 3) |
| `DESCENT_GATE_SIGN` | true | — | la porte annonce le contenu de la salle suivante |
| `DESCENT_BACKTRACK` | true | true | une porte ouverte ne se referme jamais |
| Clé de carte `rooms` | `[{"cells": [...], "gate_to_next": [[x, y], [x, y]], "pillar": [x, y]}]` × 3 découpes | — | découpe et portes |

Budget d'or : inchangé (mêmes sources, mêmes coffres). Ce qui change, c'est **quand** on peut dépenser.

### 4.4 Mobile, gel, coût, risques

- **Mobile** : rien de nouveau ; la porte s'ouvre seule ; le panneau de porte est un libellé de 24 caractères.
- **Gel** : respecté, rien ne change pour aucun boss.
- **Coût** : code ≈ **2-3 jours** (portes `R` sur la base de `secret_wall.gd`, état des salles, répartition des coffres et de l'atelier, panneau de porte, minimap par salle, `reach_field()` recalculé à l'ouverture, test `reachable_spawn_test` portes fermées et ouvertes, sauvegarde). Level design : 3 découpes × 8 cartes (≈ 4 j). Codex : 1 lot (porte par biome : vanne, éboulis, grille, herse de sel ; 2 états ; panneau).
- **Risques** : c'est la refonte la plus **efficace contre la routine** et la moins **riche en gestes** : le pilier reste un péage et le mini-boss une formalité tant que le gel dure ; une salle linéaire se lit vite (les boucles internes et les trois découpes sont indispensables) ; les monstres qui apparaissent dans une salle fermée doivent être bloqués par la porte (apparitions filtrées par salle ouverte) ; sensation de couloir sur mobile si la Salle 2 est trop étroite (≥ 40 % de sol praticable).

---

## 5. Recommandation et prototype

### 5.1 Comparaison

| Critère | A · Épreuves | B · Roue | C · Chasse | D · Descente |
|---|---|---|---|---|
| Le pouce fait autre chose que « aller, activer, tuer » | **oui, 5 verbes** | non (mêmes gestes, autre carte) | oui (poursuite de cibles) | non |
| Change d'un étage à l'autre | **oui (2 verbes propres au biome)** | peu | non (même chasse partout) | peu (découpe) |
| Supprime le rush des piliers | oui (une épreuve dure 30-40 s et se joue) | partiellement (Q3 inaccessible au départ) | oui (plus de piliers) | oui (un seul pilier atteignable à la fois) |
| Supprime le premier tour | oui (coffres sur les tracés) | partiellement | oui (la chasse mène aux coffres) | **oui** |
| Supprime le second tour | oui (coffres de l'arène seulement) | partiellement (trajet de sortie 20-30 s) | oui (rester = chasser) | **oui** |
| Habileté ou décision, pas puissance | habileté (mouvement, timing) | décision (ordre, achat) | habileté (route, chaîne) | décision (dosage) |
| Sensibilité à l'équilibrage de l'or | moyenne | nulle | **forte** | nulle |
| Dépendance à la refonte du sol | faible | **forte** | nulle | faible |
| Code / level / Codex | 10-12 j / 2 j / 8 lots | 4-5 j / 4 j / 1 lot | 4 j / 0 / 2 lots | 2-3 j / 4 j / 1 lot |

### 5.2 Recommandation

**Refonte A (Les Épreuves)**, parce qu'elle est la seule qui répond mot pour mot à la demande : ce que le joueur **fait** change à chaque étage et demande de l'adresse, pas de la puissance ; le marché suit l'action, donc les deux tours disparaissent sans timer ni taxe ; les mini-boss et les boss ne bougent pas. Son coût est le plus élevé, mais il se paie verbe par verbe : **deux verbes suffisent à juger** et un verbe réussi se décline à deux biomes.

Repli si A ne plaît pas après prototype : **D (La Descente)**, 2-3 jours de code, aucune dépendance, et le gain le plus sûr contre la routine ; A et D sont d'ailleurs cumulables (des épreuves dans des salles). **C** vaut comme mutateur de défi hebdomadaire (« Chasse ouverte ») plutôt que comme boucle de base, à cause de sa fragilité d'équilibrage. **B** attend la refonte du sol.

### 5.3 Prototype minimal : Terrasses noyées (étage 1), Escorte + Rituel

L'étage 1 est vu à chaque run et ses deux variantes de carte ont un canal et une écluse : c'est le terrain naturel des deux verbes les moins chers à prototyper.

**Périmètre (3 jours de code, zéro asset Codex)** :
1. `scripts/stage/epreuve.gd` (classe de base : état `ready / active / done`, note, `backstop`, or versé via `PickupManager.drop`, `to_dict()` / `from_dict()`, repère minimap, événements `Events.epreuve_started(kind)`, `epreuve_finished(kind, grade, elapsed_s)`) ; `epreuve_escort.gd` (suivi d'une polyligne `escort_path` du JSON de carte, corde, PV, arrêt ; **placeholder** : rectangle `Polygon2D` 1,5 × 1,0 u, à remplacer par la barque Codex) ; `epreuve_ritual.gd` (trois relais réutilisant `secret_lever.gd` avec maintien 1,2 s, cœur avec anneau télégraphié sur la couche des télégraphes, cadence `[12, 9, 7]`).
2. `StageManager` : derrière un drapeau `Balance.EPREUVES_ENABLED` (ou `-- --epreuves`), les deux petits piliers de l'étage 1 sont remplacés par les deux épreuves ; le mini-boss du plan de run (`FloorPlan`) est instancié par l'épreuve à sa fin (`Director.spawn_boss`) ; le gros pilier se déverrouille aux deux épreuves faites ; tirage des coffres restreint aux candidats à ≤ 8 u des tracés et de l'arène (`_roll_layout`).
3. `data/maps/terrasses_noyees.json` et `terrasses_rizieres_hautes.json` : clés `escort_path` (4-6 points, 60-80 u, le long du canal, un ponton à chaque bout) et `ritual` (`heart`, `relays` ×3 à 10-14 u) ; `tools/gen_maps.py` recopie ces clés.
4. Mode test (panneau TAB) : lancer une épreuve, la terminer, forcer une note ; `RunLog` : note, durée, or versé, achats avant et après le boss, durée du post-boss.
5. Test headless `epreuve_test.tscn` : escorte qui s'arrête hors corde et repart, PV à 0 → arrêt 5 s, arrivée → mini-boss ; rituel : trois relais, cadence, backstop à 75 s ; sauvegarde aller-retour en pleine épreuve.

**Protocole de vérification (joueur, mode test puis 5 runs en Moyen)** : étage 1 avec et sans `--epreuves`, même personnage (Ardent). Mesures `RunLog` : durée de l'étage (cible 3:50-4:10), part du temps en épreuve (cible ≥ 35 %), **durée du post-boss (cible ≤ 25 s, contre 4-96 s mesurés)**, or de l'étage (bande 8-10,5 P), note moyenne (cible : « bien » majoritaire, « parfait » à 20-30 %). Verdict du joueur : « j'ai eu autre chose à faire ? », « le verbe se comprend sans texte ? ».

**Suite si concluant** : Poursuite + Veine au Gouffre (lampadaires et disque : 2 j), puis Tenue à la Cité, puis les tracés des Cryptes ; lots Codex dans l'ordre barque → vannes → lampadaires → disque → cloche. Les épreuves d'un biome entrent en jeu dès que ses deux verbes existent ; un biome sans verbes garde ses piliers (les deux systèmes coexistent derrière `FloorPlan`).

---

## 6. Compatibilité avec ce qui est validé

| Élément validé | A | B | C | D |
|---|---|---|---|---|
| Ateliers (une case `E` par étage) | sur un tracé ou au départ | dans le moyeu ou le quartier sec à l'arrivée | inchangé | en Salle 2 |
| Paratonnerre dévié (gros pilier) | inchangé | inchangé | inchangé | inchangé |
| Présages | « Marée » = zone d'épreuve ×1,25 ; nouveau présage possible « Épreuve double » (note ×1,5, backstop 50 s) | « Marée » = crue plus rapide (10 s) | « Chasse ouverte » = marques toutes les 4 s | « Usure » = pas de panneau de porte |
| Coffres à vitrine et de catégorie | tirés parmi les coffres de tracé | tirés dans les quartiers | inchangé | annoncés sur la porte |
| Capsules 10 → 4 | 1 au départ, 3 sur les tracés | 1 par quartier + moyeu | **0** (remplacées par les marques) | 1-2 par salle |
| Zones secrètes (1 run sur 3) | hors tracé, inchangées | dans un quartier, accessibles quand il est sec | inchangées | dans la salle de leur déclencheur |
| Étage 5 (La Source) | aucune épreuve (gros pilier unique) | pas de roue | chasse sans trophée, gros pilier ouvert d'emblée | une seule salle |

Aucune des quatre refontes ne touche `balance.gd` autrement que par des constantes nouvelles ; aucune ne modifie un boss, un mini-boss ni un sort.
