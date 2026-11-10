# Coopération à 1-4 joueurs (étude de game design, v1)

> Statut : **étude**, aucun code, aucune donnée modifiée (Fable, game-designer, 01/11/2026). Demande du joueur : un mode coopératif 1 à 4 joueurs « façon Risk of Rain 2 ».
> Lu avant d'écrire : `CLAUDE.md` (Décisions), `docs/GDD.md`, `docs/Boucle_Etage_Refonte.md`, `docs/Boucle_Etage_Design.md`, `docs/Design_Combos.md` §5, `game/data/characters.json`, `game/scripts/spells/*_kit.gd` (hooks publics), `game/CONTRACTS.md`, `game/scripts/core/balance.gd` (`difficulty`, `run_rubies`, `PILLAR_CHARGE_S`, `RAMP_ALIVE_MAX`, `MAX_ENEMIES`), `game/scripts/ui/chest/chest_ui.gd` (pause de l'arbre), `game/scripts/ui/offscreen_cues.gd`.
> Contraintes tenues : gel des boss (aucun boss, mini-boss ni sort de boss nouveau : seulement des multiplicateurs numériques et une règle de cible générique), télégraphes ≥ 0,8 s, aucune mort instantanée (plafonds 25 % / 40 % inchangés), trois plateformes (tactile, clavier-souris, manette), paysage, 250 monstres au plafond mobile, jeu payant sans achat ni méta-progression, aucun nom ni design repris de Risk of Rain ni de Vampire Survivors (les règles sont comparées, jamais copiées).
> Unités : 1 u = 64 px ; **n** = nombre de joueurs de la partie (1-4) ; **P** = prix d'un petit coffre au début de l'étage. Toute valeur proposée vise une constante `Balance` préfixée `COOP_` (à créer) ou une clé JSON ; rien en dur.

Sommaire : 0. Cadrage et esthétique visée · 1. Boucle coop (lobby → boss) · 2. Partage (or, XP, objets, coffres sans pause) · 3. Mort, réanimation, fin de run · 4. Lisibilité à 4 sur un téléphone · 5. Kits en coop : synergies, rôles, ce qui casse · 6. Parcours UX (lobby, invitation, reconnexion, pause, entrées, mode test) · 7. Coût, ordre de production, points à trancher · Sources.

---

## 0. Cadrage et esthétique visée

### 0.1 Ce que la coop doit faire ressentir (MDA)

| Esthétique | En solo aujourd'hui | Ce que la coop ajoute | Ce qu'elle ne doit pas casser |
|---|---|---|---|
| **Sensation** (micro-boucle 30 s : bouger, esquiver, faucher) | intacte, référence du projet | voir les coups des alliés tomber sur « son » paquet | la lisibilité : 4 kits + 250 monstres sur 6 pouces |
| **Appartenance** (Deci et Ryan) | nulle (jeu solo) | **la raison d'être du mode** : relever un ami, tenir la zone ensemble, « partons ? » | aucune mécanique qui fait regretter l'ami (vol de coffre, téléportation forcée) |
| **Défi** | la jauge D qui monte | la pression monte avec n, les boss tiennent plus longtemps | le coût d'un échec doit rester proportionnel (un joueur au sol ≠ la run perdue) |
| **Expression** | le build | les rôles émergents (celui qui cloue, celui qui éclate) | aucun rôle obligatoire : un lobby de 4 Ardent doit marcher |

Principe directeur, repris de la structure de RoR2 sans en copier les règles mot à mot : **tout ce qui se partage se partage sans friction (or, niveau, zone), tout ce qui se choisit reste personnel (objets, variantes, relances)**. La coop n'invente aucune monnaie, aucun écran bloquant, aucun boss.

### 0.2 Deux produits différents : en ligne et en local

| | **En ligne** (PC ↔ Android ↔ iOS) | **En local** (un PC, 1 clavier-souris + 3 manettes) |
|---|---|---|
| Caméra | une par joueur (comme en solo) | une caméra commune (§4.5) |
| Pause | impossible (§6.4) | pause globale, comme en solo |
| Écran de coffre | non bloquant (§2.4) | non bloquant aussi (même code) |
| Mobile | oui | **non** (un téléphone = un joueur) |
| Coût | réseau : le plus gros chantier du projet (§7) | moyen : 3-4 semaines après le socle « n joueurs » |

Les règles de jeu de ce document (§1-5) sont **identiques** dans les deux cas : le socle « plusieurs nœuds `Player` dans la scène » est commun, le réseau vient par-dessus. Ordre conseillé : socle n joueurs (testable en local sans réseau) → local PC → en ligne.

### 0.3 Ce qui, dans le code actuel, suppose un seul joueur (à signaler à l'orchestrateur, architecture = Opus)

- `get_first_node_in_group("player")` : **129 occurrences** dans les kits de sorts seuls, plus `stage_manager.gd` (5), `director.gd` (3), `pillar.gd`, `pickup_manager.gd`, `audio_manager.gd`, `hud.gd`, `minimap.gd`, `run_log.gd`, `test_tools.gd` (7)… Chaque site doit devenir « le joueur **propriétaire** du sort » (kits) ou « le joueur **le plus proche** » (monstres, director, pickups).
- `ChestUI` et `CompassPanel` posent `get_tree().paused = true` : incompatible avec tout autre joueur en jeu (§2.4).
- `RunState` est un singleton d'**une** run : or, XP, niveau, objets, pity, relances. En coop : niveau partagé (§2.2) mais or, objets, pity et relances **par joueur** (`RunState.players[id]`, à concevoir).
- `Main.end_run` sur `Events.player_died` : la mort d'un joueur ne termine plus la run (§3).
- `RunLog` : un journal par run, enrichi d'un bloc par joueur ; aucun réseau pour la télémétrie (décision du 28/10 inchangée : le journal reste local à chaque appareil).

---

## 1. Boucle coop : une run à 4, du lobby au boss

### 1.1 Lobby

- **Créer** ou **rejoindre** (§6.1). 1 à 4 joueurs ; une partie à 1 joueur créée « à plusieurs » est strictement identique au solo (n = 1 partout : aucune règle ne change, comme dans RoR2).
- **Choix des personnages, doublons autorisés.** Interdire les doublons punirait le groupe pour un déblocage manquant (Rictus caché, Rainette cachée) et contredirait « aucun rôle obligatoire ». Deux Ardent se distinguent par : la **teinte d'équipe** (§4.1), le skin (le second prend automatiquement un skin possédé différent s'il en a un, sinon le même skin teinté), et les variantes de sorts (chacun les siennes). Chaque joueur joue avec **ses** déblocages (personnages, variantes, skins) : rien n'est prêté, rien n'est bloqué par les autres.
- **Mode (Facile / Moyen / Difficile) et Présages : l'hôte choisit, tout le monde voit.** Le mode Difficile n'est proposé que si **tous** les joueurs l'ont débloqué (sinon grisé, libellé « Nadia n'a pas débloqué Difficile ») : la progression personnelle garde son sens. Le présage obligatoire en Difficile (`OMEN_MANDATORY_MODES`) reste à l'hôte.
- **Départ** : chaque joueur se met « Prêt » ; l'hôte lance ; compte de 3 s. La graine est celle de l'hôte, partagée (une run coop a une graine comme une run solo : rejouable en défi).

### 1.2 Pression ennemie : comment D et les boss suivent n

Référence RoR2 (wiki, voir Sources) : `coeff = (playerFactor + t × timeFactor) × stageFactor` avec `playerFactor = 1 + 0,3 (n − 1)` et `timeFactor = 0,0506 × difficultyValue × n^0,2` ; les boss spéciaux ont `PV × (1 + coeff/2,5) × joueurs vivants`. `Balance.difficulty()` est déjà aligné sur RoR2 (`TIME_SLOPE` 0,0506, `MODES` 1/2/3, `K_STAGE`) : l'extension est naturelle.

| Constante | Valeur proposée | Plage sûre | Sens |
|---|---|---|---|
| `COOP_PLAYER_FACTOR` | 0,30 | 0,20-0,35 | D de départ = `1 + COOP_PLAYER_FACTOR × (n − 1)` : à 4, D part à 1,9 (le jeu commence « Tendu ») |
| `COOP_TIME_EXP` | 0,20 | 0,15-0,25 | la pente de temps est multipliée par `n^COOP_TIME_EXP` (×1,32 à 4) |
| `COOP_BOSS_HP_PER_PLAYER` | 0,50 | 0,40-0,60 | PV des boss d'étage et mini-boss × `(1 + COOP_BOSS_HP_PER_PLAYER × (vivants − 1))` : ×2,5 à 4 vivants, recalculé à l'apparition seulement (jamais en plein combat, sinon illisible) |
| `COOP_BOSS_DMG_MULT` | 1,0 | 1,0 | les dégâts des boss **ne montent pas** avec n (plafonds 25 % / 40 % inchangés ; la menace vient des PV et de la densité) |
| `RAMP_ALIVE_MAX` / `MAX_ENEMIES` | 150 / 250 **inchangés** | — | plafond de perf mobile : la densité par joueur baisse si le groupe s'étale, ce qui pousse à rester groupé (dynamique voulue, comme dans RoR2) |
| `COOP_SPAWN_SPREAD` | `&"round_robin"` | — | le director fait apparaître ses paquets autour des joueurs **à tour de rôle**, pondéré par la distance au centre du groupe : un joueur isolé n'est ni abandonné ni ciblé plus que les autres |

Monstres ordinaires : **aucun multiplicateur de PV par joueur** (comme RoR2) ; ils restent fauchés en 1-2 coups, c'est la micro-boucle. Les crédits suivent D, donc à 4 joueurs il y a ≈ 1,9× plus de monstres au départ et le plafond de 150 vivants est atteint plus tôt dans la rampe (`RAMP_TIME_S` 480 s). À vérifier sur Android bas de gamme : 4 joueurs = 4 kits de VFX en plus des 250 monstres (§4.3).

Cible de ressenti : **TTK d'un mini-boss à 4 joueurs ≈ TTK solo** (≈ 21-30 s visés), TTK du boss d'étage ≈ 75 s comme en solo ; si les mesures (`boss_pace_test` étendu à n joueurs) sortent de ±25 %, le bouton est `COOP_BOSS_HP_PER_PLAYER`.

### 1.3 Étage : coffres, capsules, piliers, épreuves, ateliers, marchand

| Élément | Règle solo | Règle coop proposée | Constante |
|---|---|---|---|
| Petits coffres | 8 | `8 + 3 × (n − 1)` (17 à 4) | `COOP_CHEST_SMALL_PER_EXTRA` 3 (plage 2-4) |
| Grands coffres | 2 | `2 + (n − 1)` (5 à 4) | `COOP_CHEST_LARGE_PER_EXTRA` 1 |
| Légendaire | 25 % | inchangé (un seul, pour que ce soit un **événement de groupe** : §2.3) | — |
| Capsules | 4 (`CAPSULES_PER_STAGE`) | `4 + 2 × (n − 1)` (10 à 4) | `COOP_CAPSULE_PER_EXTRA` 2 |
| Prix | `chest_price(kind, D, étage)` | **inchangé** ; D de départ plus haute (§1.2) rend tout ≈ ×2,2 plus cher à 4 : c'est ce qui absorbe l'or reçu par tous (§2.1) | — |
| Petits piliers | activés par « interagir », zone ×1,5, mini-boss | **n'importe qui** active ; une seule zone ; mini-boss à PV × (§1.2) ; les deux piliers restent activables en même temps (deux groupes de 2 : le « Duo » devient une tactique naturelle à 4) | — |
| Gros pilier | zone de charge 60 s, n'avance que si le joueur est dedans | la charge avance au rythme `max(COOP_CHARGE_FLOOR, dans la zone / vivants)` : 4/4 = 60 s, 2/4 = 120 s, 1/4 = 25 % du rythme (240 s). Les joueurs au sol et les morts ne comptent pas dans « vivants » | `COOP_CHARGE_FLOOR` 0,25 (plage 0,2-0,5 ; à 0,5 l'un peut charger seul pendant que les autres farment : trop permissif) |
| Boss d'étage | ponctue le pilier ; coffre gratuit Rare+ | **un coffre gratuit par joueur**, y compris les joueurs morts (ils reviennent à l'étage suivant avec quelque chose ; §3.4) ; enrage à `BOSS_ENRAGE_AFTER_S` 90 s inchangé | `COOP_BOSS_CHEST_PER_PLAYER` true |
| Épreuves (prototype A, `EPREUVES_ENABLED`) | une barque, trois relais… | Escorte : la corde vaut « **au moins un** joueur à ≤ 6 u » ; Rituel : les trois relais peuvent être fermés **par trois joueurs en même temps** (c'est le premier vrai verbe coop du jeu, gratuit) ; Veine : même règle de rythme que le gros pilier ; Poursuite : n'importe qui atteint le lampadaire ; Tenue : inchangée | aucune nouvelle |
| Ateliers (Fondoir, Matrice, Alambic, Enclume) et Boussole | quotas par étage | **quotas par joueur** (chacun a son Enclume à 3 usages, etc.) : aucun vol possible, aucun arbitrage | `COOP_STATION_QUOTA_PER_PLAYER` true |
| Marchand de l'ombre, Autel, Sanctuaire | 1 événement par étage | l'étal est **par joueur** (même stock tiré par la graine, chacun achète le sien) ; Autel et Sanctuaire : chacun paie son propre risque | — |
| Zones secrètes (1 run sur 3) | plaques qui restent enfoncées | inchangé (deux joueurs sur deux plaques = plus rapide, c'est tout) ; reliquaire `guardian` : un coffre par joueur comme le boss | — |
| Paratonnerre dévié | option du gros pilier | l'hôte **ou** n'importe qui l'enclenche ; bandeau à tous | — |

Capacité des cartes : 17 petits + 5 grands + 1 légendaire = 23 coffres à 4 joueurs. **À vérifier par le level-designer** : nombre de candidats de coffre par carte (`data/maps/*.json`) ; si une carte n'en a pas assez, plafonner par carte (`chest_candidates`) plutôt que d'empiler deux coffres sur un point.

### 1.4 Téléporteur : activation et règle « tous dans la zone »

Décision existante (CLAUDE.md) : le téléporteur ne s'active **que** par « interagir », jamais au contact, pour pouvoir rester farmer. En coop, la question devient : qui décide de partir ?

| Option | Principe | Avantages | Inconvénients |
|---|---|---|---|
| A · Le premier qui interagit part avec tout le monde (règle de RoR2) | n'importe qui, départ immédiat | zéro friction, aucun écran | un joueur presse par erreur sur mobile (maintien 0,6 s `UI_EXIT_HOLD_S` déjà exigé, mais pas assez) ; un coffre en cours d'achat est perdu ; source n° 1 de rancœur en coop |
| B · Tous les vivants dans un rayon de 8 u | consensus physique | lisible au sol, aucun menu | otage : un joueur qui farme bloque tout le monde indéfiniment |
| C · **Compte à rebours avec droit de veto borné (Recommandé)** | « interagir » lance un compte de `COOP_TELEPORT_COUNTDOWN_S` 15 s visible de tous (anneau sur le téléporteur, bandeau « Départ dans 15 s », flèche hors écran) ; chaque joueur peut presser « Attendez ! » **une fois** : +15 s (plafond `COOP_TELEPORT_WAIT_MAX` 2 vetos par étage, donc 45 s au plus) ; à 0, tout le monde part, où qu'il soit ; un second « interagir » d'un autre joueur **confirme** et saute le compte si tous les vivants ont confirmé | personne ne peut ni forcer ni retenir ; le temps d'acheter 2-3 coffres au pas de course (comparable aux 30 s de grâce de la Marée de `Boucle_Etage_Design.md` §2.7) ; sans menu : deux actions contextuelles (« Partir » / « Attendez ! ») sur le même bouton | 15-45 s de plus par étage dans le pire cas (+1-3 min par run) |

Les joueurs au sol au moment du départ **sont relevés** à l'arrivée (§3.2) : partir est aussi une façon de sauver quelqu'un. Les morts reviennent à l'étage suivant. Étage 5 : le choix « terminer / sans fin » suit la même règle C.

### 1.5 Un étage à 4, minute par minute (Terrasses, Moyen)

| Temps | Ce qui se passe | Ce que la coop change |
|---|---|---|
| 0:00-0:20 | arrivée groupée, D = 1,9 ; 23 coffres et 10 capsules sur la minimap | « on se sépare en deux ? » : la première décision est une décision de groupe |
| 0:20-1:10 | deux duos : un par petit pilier, activés à 10-20 s d'écart ; deux mini-boss ×2,5 PV | le Duo du GDD devient le cas normal ; la zone ×1,5 de chaque pilier tient un duo occupé |
| 1:10-1:40 | achats sur le chemin, pings de coffres (§4.4), un joueur au sol relevé en 3 s | la micro-boucle garde sa place : on relève **en** fauchant |
| 1:40-3:00 | gros pilier : 4/4 dans la zone = 60 s ; boss d'étage ×2,5 PV, cible le plus proche, change de cible toutes les 6 s | la zone impose le regroupement : pic de l'étage, tension maximale, c'est là que les rôles se voient |
| 3:00-3:30 | 4 coffres de boss, achats, « Partir » → compte de 15 s, un « Attendez ! » | sortie négociée, pas forcée |

Durée visée **3:30-4:00** par étage, run ≈ 19-21 min (≈ +1-2 min sur le solo, à cause des vetos et des réanimations). Si la mesure dépasse 4:15, le bouton est `COOP_TELEPORT_COUNTDOWN_S` 15 → 10.

---

## 2. Règles de partage

### 2.1 Or

| Option | Principe | Avantages | Inconvénients |
|---|---|---|---|
| A · **Chaque joueur reçoit l'or entier de chaque kill, quel que soit le tueur (Recommandé)** | bourses individuelles, pas de course au pickup | aucune dispute, aucun « kill steal », l'Avare garde sa BOURSE ; économie calibrée par le nombre de coffres (§1.3) et les prix (D de départ) | l'or total en jeu est ×n : c'est voulu, les coffres sont ×2,2 |
| B · L'or d'un kill est partagé entre les joueurs à ≤ 12 u | « récompense de proximité » | pousse à rester groupé | punit celui qui va chercher une capsule ; incompréhensible sans HUD |
| C · Bourse commune | une seule somme, tout le monde dépense dedans | simple à lire | le premier arrivé dépense l'or de tous : la friction la plus connue de la coop |

Capsules : **la capsule donne son or à tous** (`COOP_CAPSULE_SHARED` true) ; sinon le « tour de map » devient une course entre amis. Primes de mini-boss et de boss : à tous. Or en poche à la fin de la run : **individuel**, il compte dans les rubis de chacun (§3.4).

Avare : la Rançon (+50 % d'or sur un marqué tué) et la Faillite ne profitent **qu'à la bourse d'Avare** (`COOP_KIT_GOLD_BONUS_SELF_ONLY` true) : sinon un Avare dans chaque lobby devient obligatoire (stratégie dominante, Sirlin). Même règle pour `piece_porte_bonheur` et tout objet « +% d'or » : ils s'appliquent à la bourse de leur propriétaire sur tous les kills.

### 2.2 XP et niveau

| Option | Principe | Avantages | Inconvénients |
|---|---|---|---|
| A · **Niveau d'équipe commun (Recommandé)** | toute l'XP (kills, capsules converties, `GOLD_TO_XP_SHARE`) entre dans une seule jauge ; tout le monde a le même niveau | un joueur mort ou plus faible ne décroche jamais (Flow : pas de « boulet ») ; un seul jingle, une seule barre | les objets « +XP » doivent être redéfinis |
| B · Niveau individuel sur ses propres kills | comme en solo | lisible | le joueur de soutien (Vigie, Bourbe) finit 3 niveaux en dessous : rôle puni |

Chiffres : courbe `LEVEL_K` / `LEVEL_GROWTH` inchangée ; l'XP d'un kill n'est comptée **qu'une fois** (pas ×n). Comme il y a ≈ 1,9× plus de monstres à 4, l'équipe monte un peu plus vite que le solo : accepter jusqu'à +2 niveaux en fin de run ; au-delà, `COOP_XP_MULT` = `n^-0,25` (0,71 à 4). Objets « +XP » (`eclat_d_experience`) : le bonus du propriétaire s'applique à l'XP des kills **qu'il a faits** (comptés par `Events.enemy_killed` avec l'attaquant) ; levier simple, zéro redistribution.

### 2.3 Objets, coffres, pings, anti-vol

- **Un coffre se paie avec sa propre bourse et l'objet va à celui qui a payé.** C'est la seule règle anti-vol nécessaire : il n'y a rien à voler, puisqu'il n'y a pas de pickup au sol. Le coffre reste ouvert aux autres tant qu'il n'est pas payé.
- **Pas de réservation mécanique.** Une réservation (coffre verrouillé 20 s pour le joueur qui l'a pingé) crée des otages et des malentendus. À la place, un **ping « coffre »** (§4.4) pose une marque sociale 15 s sur le coffre et la minimap (« Nadia veut ce coffre ») : conventionnelle, jamais contraignante.
- **Le coffre légendaire (1 par étage, 25 %) est l'événement de groupe** : son prix (1 200 de base × D^1,25) dépasse une bourse individuelle en début de run ; proposer la **cagnotte** : « interagir » sur le légendaire ouvre une contribution (« Mettre 200 or », curseur par pas de 50) ; quand la cagnotte atteint le prix, **le plus gros contributeur choisit** (égalité : le premier contributeur) et obtient l'objet. Le seul coffre où l'on dépense **pour** quelqu'un : c'est ce qui fait un souvenir de run. Constante `COOP_LEGENDARY_POOL` true. Si refusé par le joueur : le légendaire reste à paiement individuel, sans changement.
- **Partage d'objets** : aucun échange d'objets en v1 (RoR2 n'en a pas non plus) ; le Fondoir pourrait, plus tard, permettre de **donner** l'exemplaire refondu à un allié à portée (`COOP_FONDOIR_GIFT`, v2). Un objet pris est définitif.
- **Pity et relances** : **par joueur** (`pity`, 1 relance gratuite par coffre, 3 par run, puis à l'or) : un joueur ne consomme jamais les relances d'un autre.
- **Objets du boss et du reliquaire** : un par joueur, chacun choisit le sien.

### 2.4 Choisir un objet sans bloquer les autres (jamais de pause en ligne)

Aujourd'hui `ChestUI` met l'arbre en pause (`get_tree().paused = true`, `chest_ui.gd` l. 279) et le GDD exclut le temps d'écran de coffre du temps actif. En coop, le temps actif continue pour tout le monde. Trois options :

| Option | Principe | Avantages | Inconvénients |
|---|---|---|---|
| A · Pas de choix : le coffre donne un objet tiré (règle de RoR2) | ouverture instantanée | zéro écran | perd le d100 animé, les deux cartes et la relance : l'identité du jeu (GDD §6 et §13 : « identité : coffres RoR, relance ») |
| B · Choix immédiat non bloquant | les deux cartes s'affichent en overlay compact ; le joueur continue de bouger (joystick), le sort 1 et les sorts 2-4 passent en ciblage automatique, l'esquive reste ; délai sans limite | garde l'identité ; le joueur choisit **en jouant** | sur PC, la souris sert aux cartes et aux sorts 2-4 : conflit (résolu par le passage automatique des sorts pendant l'overlay) ; un choix pris sous pression est moins lu |
| C · **Sacoche : le coffre donne un jeton, le choix se fait quand on veut (Recommandé)** | « interagir » sur un coffre payé = d100 et deux cartes tirées **tout de suite** (graine, pity, qualité figées), rangées dans une **sacoche** (pastille sur le HUD, « 2 choix en attente ») ; le joueur ouvre la sacoche quand il est au calme (bouton dédié, ou automatiquement s'il n'y a aucun monstre à 8 u pendant 2 s, réglage) ; l'overlay est celui de B (non bloquant, sorts automatiques, mouvement libre) ; relance disponible dans la sacoche | garde tout (d100, cartes, relance, « vous en avez déjà X ») ; aucune pause ; le joueur **décide du moment** (autonomie) ; en solo, la sacoche peut rester fermée et l'écran actuel inchangé (ou devenir l'option « choix différé » pour tous : à trancher) | un joueur qui oublie sa sacoche joue sans ses objets : rappel visuel (pastille qui pulse, « 3 choix en attente » à chaque bandeau d'étage) ; à la fin d'un étage, les jetons **restent** (jamais choisis à la place du joueur) |

Chiffres : `COOP_SATCHEL_AUTO_OPEN_S` 2,0 (calme requis avant ouverture automatique ; 0 = manuel seulement), `COOP_SATCHEL_SAFE_RADIUS_U` 8, `COOP_CHOICE_TIMEOUT_S` 0 (aucune expiration : un choix forcé serait une perte d'autonomie). Pendant l'overlay ouvert, le joueur **n'est pas invulnérable** (sinon la sacoche devient un bouton d'esquive gratuit) ; l'overlay se **réduit** automatiquement (sans se fermer) si le joueur prend un coup ≥ 10 % de ses PV, et revient quand le calme est retrouvé. À passer à l'ux-designer : disposition de l'overlay à droite du HUD (zone du pouce droit libre), cartes à ≥ 48 dp, manette : stick droit = carte gauche/droite, A = prendre.

Épreuves, vitrine (`showcase_ui.gd`), Boussole (`compass_panel.gd`), ateliers : même mécanisme (sacoche ou overlay non bloquant), jamais `get_tree().paused`.

---

## 3. Mort, réanimation, fin de run

### 3.1 Options

| Option | Principe | Avantages | Inconvénients |
|---|---|---|---|
| A · Mort jusqu'à l'étage suivant, spectateur (règle de RoR2) | aucune réanimation | simple, lisible, zéro nouvelle interaction | sur un étage de 4 min, 2-3 min à regarder ; sur mobile, c'est quitter l'app ; le coût d'un échec n'est pas proportionnel (Flow) |
| B · **Au sol, puis réanimation par un allié (Recommandé)** | à 0 PV, le joueur tombe **au sol** (`downed`) : invulnérable, intangible pour les monstres (ils l'ignorent, sinon ils campent), immobile, chrono de `COOP_DOWN_BLEED_S` 30 s ; un allié **maintient « interagir » 3 s à ≤ 1,5 u** (même geste que le téléporteur et les relais du Rituel) : relevé à 40 % de ses PV ; chrono à 0 : mort jusqu'à l'étage suivant (règle A) | la micro-boucle continue pendant la réanimation (on relève en fauchant, le réanimateur reste vulnérable et interrompu s'il esquive) ; appartenance : le geste le plus coopératif du jeu ; coût proportionnel | une nouvelle interaction, un état de plus par joueur, des VFX (brief Codex : anneau de réanimation, jauge de maintien) ; risque d'abus « tomber au sol = invulnérabilité » (§3.2) |
| C · Réapparition sur chrono (30-60 s) sans allié | respawn au gros pilier | aucune dépendance aux alliés | la mort devient un simple temps mort : plus aucune tension |

### 3.2 Règles de B

| Constante | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `COOP_DOWN_BLEED_S` | 30 | 20-40 | temps au sol avant la mort |
| `COOP_DOWN_BLEED_DECAY` | 0,66 | 0,5-0,75 | chaque nouvelle chute **du même étage** divise le temps : 30 → 20 → 13 s ; la 4e chute de l'étage est une mort directe (`COOP_DOWN_MAX_PER_STAGE` 3). Remis à zéro à chaque étage |
| `COOP_REVIVE_HOLD_S` | 3,0 | 2,5-4,0 | maintien de « interagir » ; interrompu si le réanimateur s'éloigne à > 1,5 u, esquive ou tombe ; **jamais** interrompu par un dégât (comme les relais du Rituel) |
| `COOP_REVIVE_RANGE_U` | 1,5 | 1,2-2,0 | distance du maintien |
| `COOP_REVIVE_HP_PCT` | 0,40 | 0,30-0,50 | PV au relevé ; + `COOP_REVIVE_GRACE_S` 1,5 s d'invulnérabilité (même valeur que la reprise après pause) |
| `COOP_DOWNED_INVULN` | true | — | au sol : aucun dégât, les monstres le retirent de leurs cibles, les zones persistantes ennemies ne le touchent pas |
| `COOP_WIPE_ON_ALL_DOWN` | true | — | tous les vivants au sol en même temps = run terminée (pas d'attente de 30 s pour rien) |
| `COOP_TELEPORT_REVIVES_DOWNED` | true | — | partir par le téléporteur relève les joueurs au sol à l'arrivée (40 % PV) |
| `COOP_DEAD_GOLD_SHARE` | 0,5 | 0,25-0,75 | un joueur **mort** (pas au sol) reçoit la moitié de l'or des kills jusqu'à l'étage suivant : il revient avec de quoi acheter, mais mourir n'est pas gratuit. (Règle RoR2 non vérifiée sur ce point.) |

Au sol, le joueur garde : le ping (auto-ping « À l'aide ! » à la chute, §4.4), la vue sur son HUD, la sacoche fermée. Ses effets persistants propres (mottes de Bourbe, doublures de Rictus, piliers de Tocsin, chaîne d'Arpenteuse) **disparaissent** à la chute (sinon un Bourbe au sol continue de tanker). `phenix_de_poche` (objet) se déclenche **avant** la chute, par propriétaire, comme en solo.

Garde-fous contre « tomber au sol pour être invulnérable » : décroissance du chrono (3 chutes au plus), 40 % de PV au relevé, aucun gain d'or au sol (`COOP_DOWNED_GOLD_SHARE` 0), le boss et son enrage continuent (le temps de combat ne s'arrête pas). Garde-fou contre le « troll » qui ne relève pas : aucun ; c'est social, et le téléporteur relève.

### 3.3 Spectateur (mort jusqu'à l'étage suivant)

Caméra sur un allié (changer avec gauche/droite, stick droit, glissement sur mobile), HUD réduit (barre d'équipe, minimap, jauge D), ping autorisé (limité à 1 toutes les 4 s), bandeau « Retour à l'étage suivant ». À l'arrivée de l'étage suivant : 100 % de PV, tous ses objets, niveau d'équipe, son coffre de boss (§1.3). En local : la part d'écran reste (caméra commune, §4.5).

### 3.4 Fin de run, récap, rubis

- **Victoire** : le boss final meurt avec ≥ 1 vivant (ou au sol : il est relevé pour l'écran de fin). **Défaite** : tous au sol ou morts. **Abandon** : vote identique au téléporteur (§1.4) ; un joueur seul qui quitte devient « absent » (§6.3), la run continue pour les autres.
- **Récap par joueur** (écran à 4 colonnes, ou 4 pages sur mobile) : kills, dégâts infligés (part du total), dégâts subis, or gagné / dépensé, objets, **réanimations faites et reçues**, chutes, temps au sol, meilleur combo. Aucun classement ni « MVP » (ce serait du compétitif dans un mode d'appartenance) ; une seule ligne d'équipe : « 4 étages, 2 réanimations, 19:40 ».
- **Rubis par joueur** : `Balance.run_rubies(active_minutes, mode, pillars_done, victory, gold_left_du_joueur)` avec `pillars_done` et `victory` **communs**, `gold_left` **individuel** ; `COOP_RUBY_MULT` 1,0 (aucun bonus : les rubis sont cosmétiques, mais un bonus ferait de la coop le mode « rentable » et viderait le solo). Les minutes actives d'un joueur absent (§6.3) ne comptent pas pour lui.
- **Déblocages** : les objectifs (« tuer 200 monstres à moins de 2 u », « finir un étage sans contact ») se comptent **par joueur sur ses propres actions** ; les objectifs d'équipe (« gagner une run ») valent pour tous les présents à la fin. « Gagner une run en Difficile avec X » (skins) reste valable en coop : l'hôte a choisi Difficile pour tous.
- **Mode sans fin** après l'étage 5 : vote téléporteur ; D continue avec le facteur de joueurs.
- **Sauvegarde de run** : **aucune en coop** v1 (une run coop ne se reprend pas ; RoR2 non plus) ; une interruption (hôte parti, §6.3) convertit la run en rubis pour chacun, règle du GDD §4 (« jamais perdue sans compensation »).

---

## 4. Lisibilité : 4 joueurs et 250 monstres en iso sur un téléphone

### 4.1 Identité visuelle par joueur

- **Quatre teintes d'équipe** (`COOP_PLAYER_COLORS`, à placer dans `palette.gd`) : blanc-ivoire, ambre, cyan, magenta-rose. Choisies pour ne pas se confondre avec le rouge-orangé des boss (`COL_BOSS`), le crème des télégraphes (`#FFE2C8`), l'ambre des élites (`COL_ELITE`, proche de « ambre » : prendre un ambre plus **saturé et plus chaud** pour le joueur ou passer le joueur 2 au vert-eau ; à trancher avec l'ux-designer sur maquette), ni avec les accents émissifs des biomes.
- Où la teinte apparaît, toujours la même : **contour** du sprite (2 px PC, 4 px mobile, cel-shadé : un masque de contour par Codex, pas de shader de remplacement en final), **chevron** au-dessus de la tête (12-16 px, initiale du prénom de lobby ou icône du personnage) hors écran de soi, **barre de PV** alliée (`overhead_bars.gd`), **point** de minimap, **flèche** hors écran, **pings**, **colonne** du récap. Le joueur local a toujours un **anneau au sol** blanc en plus (il se retrouve en 0,2 s dans la foule : le premier problème de tout jeu à 4).
- Doublons : deux Ardent ont deux contours différents et, si possible, deux skins ; le chevron porte le prénom.

### 4.2 VFX alliés atténués, retours réservés à soi

| Réglage | Valeur | Sens |
|---|---|---|
| `COOP_ALLY_VFX_ALPHA` | 0,55 (bas : 0,35) | opacité des sorts alliés (projectiles, novas, zones) ; les **bords** des zones persistantes alliées (Cendres, Flaque, chaîne, Gluant) restent à 100 % pour qu'on sache où marcher |
| `COOP_ALLY_DAMAGE_NUMBERS` | false | chiffres de dégâts des alliés masqués par défaut (réglage) ; les siens inchangés |
| hit-stop, secousse, flash | **seulement les siens** | `Main.shake`, `hitstop_enabled()`, `LightRig.flash` (plafond 3/s global inchangé) : un allié qui crit ne secoue pas mon écran |
| télégraphes ennemis | **jamais atténués** | règle ≥ 0,8 s inchangée ; un télégraphe sous un allié hors écran = flèche hors écran de type télégraphe (existe) |
| sons alliés | −6 dB, voix limitées | « le son suit la puissance du coup » (décision audio) : les coups lourds alliés restent audibles, les légers sont coupés au-delà de 12 u |

### 4.3 Performance

- Plafond 250 monstres **global** (pas ×n). 4 kits = jusqu'à 4 × (projectiles, zones, familiers) : Bourbe ×4 = 16 mottes, Rictus ×4 = 24 doublures, Tocsin ×4 = 8 piliers : acceptable face à 250 monstres mais **à mesurer** (test de fumée `balance_sim_test` à 4 kits simultanés). Palier Bas : `COOP_ALLY_VFX_ALPHA` 0,35 et particules alliées ÷2.
- En ligne : la **synchronisation de 250 monstres** est le problème d'architecture (Opus) : l'hôte simule, les clients interpolent ; les projectiles de sorts sont visuels côté client. Hors périmètre du design, signalé.

### 4.4 Indicateurs hors écran et pings

- `OffscreenCues` : ajouter `Kind.ALLY` (chevron de la teinte, après boss et télégraphe, avant élite), `Kind.ALLY_DOWN` (chevron qui pulse, **priorité au-dessus du boss**, avec le chrono au sol en chiffres), `Kind.PING` (pastille de la teinte du pingueur, 6 s). `MAX_CUES` 6 → 8 en coop (`COOP_MAX_CUES`).
- **Un bouton de ping**, contextuel : sur un coffre = « coffre » ; sur un monstre, une élite, un boss = « cible » (le ciblage automatique des alliés mobiles **préfère** une cible pingée 4 s, `COOP_PING_AIM_WEIGHT` 1,5 comme `AIM_MARKED_WEIGHT`) ; sur le sol = « ici » ; sur soi = « à l'aide » (automatique à la chute) ; sur le téléporteur = « partons ». PC : touche T ou clic molette ; manette : clic du stick droit ; mobile : petit bouton à côté de la minimap, ou **appui long sur la minimap** au point voulu. Cadence `COOP_PING_COOLDOWN_S` 2,0 ; 4 pings simultanés au plus par joueur.
- **Aucun chat texte** (13 ans et plus, mobile, modération impossible pour un jeu à 5 €) ; une roue de 4 messages (« Ici », « Coffre », « Attendez », « Partons ») suffit avec les pings.

### 4.5 Caméra

- **En ligne** : une caméra par joueur, exactement comme en solo (iso 2:1, `keep_height`, même recul). Rien à concevoir.
- **En local (PC)** :

| Option | Principe | Avantages | Inconvénients |
|---|---|---|---|
| A · Écran partagé (2-4 fenêtres) | un viewport par joueur | liberté totale | iso 2:1 sur un demi ou un quart d'écran 1080p : le joueur fait 32 px, les télégraphes deviennent illisibles ; 2-4 rendus de la scène = perf ×2-4 : **rejeté** |
| B · **Caméra commune avec laisse (Recommandé)** | la caméra cadre le **barycentre** des joueurs vivants et dézoome jusqu'à `COOP_LOCAL_CAM_ZOOM_MAX` 1,4 pour les contenir ; un joueur ne peut pas sortir du cadre : il est retenu par un **mur doux** à `COOP_LOCAL_LEASH_U` 14 u du barycentre (il glisse le long, jamais bloqué net) | un seul rendu ; les 4 restent ensemble (dynamique coop voulue) ; iso lisible | moins de liberté ; un joueur qui veut aller chercher un coffre à 20 u doit emmener le groupe : **c'est la coop locale** (même parti pris que les beat'em up) |

Le zoom ×1,4 rend les monstres 30 % plus petits : garder les contours cel et le flash blanc des touches ; à vérifier sur un écran 1080p à 2 m (canapé). **Mobile local : exclu** (un téléphone = un joueur ; pas de manettes multiples prévues).

---

## 5. Kits en coop : synergies, rôles, ce qui casse

### 5.1 La couche publique, seule base des synergies croisées

Les combos de `Design_Combos.md` sont **internes** à un kit (marques, trempé, électrisé lus par `is_marked(e)` du kit propriétaire). Entre deux joueurs, seule la **couche publique** de `CONTRACTS.md` circule : `Enemy.add_damage_taken_mod(id, mult, duration)` (produit, lisible par tous), l'étiquette sans effet (`mult` 1,0, `has_damage_taken_mod(id)`), `is_stunned()`, `is_imprisoned()`, `Player.apply_slow` (le plus fort l'emporte), les attractions et reculs. Recommandation v1 : **aucune règle croisée nouvelle** ; les synergies naissent de ce qui est déjà public. Tableau de ce que chaque kit offre et reçoit par cette couche :

| Personnage | Offre à l'équipe (public, sans code nouveau) | Reçoit de l'équipe | Rôle émergent |
|---|---|---|---|
| **Vigie** | Fusée : +20 % de dégâts subis dans la lumière (si codée en `add_damage_taken_mod`, à vérifier dans `vigie_kit.gd`) : **le buff d'équipe du jeu** ; Filet : `imprisoned` 1,5 s ; Grêle : ralentissement | des cloués tenus pour l'Allonge (Gluant, Halage, Tendeur) | éclaireuse : expose, cloue |
| **Tocsin** | Bras-pilier : étiquette `&"tocsin_charge"` + ralentissement + Tête-cloche de 4 u ; Coup de tocsin : recul 3 u | paquets déjà groupés (Halage, Gluant, doublures) | tank-contrôle, « posez le pilier ici » |
| **Arpenteuse** | Chaîne : brûlure + ralentissement sur 14 u ; Halage : attraction contre la chaîne ; Tendeur : étourdis et emprisonnés | tout dégât de zone sur sa ligne (Cendres, Nova, Crue) | géomètre : elle dessine où le combat a lieu |
| **Rainette** | Gluant : −40 % et paquet collé ; Grand saut : étourdit 0,5-1,0 s | zones alliées sur la flaque | pose et écrase |
| **Averse** | Vague / Crue : recul et trempé (ralentissement) ; Flaque : zone | des monstres déjà groupés | contrôle à distance ; **recul = friction avec les mêlées** (§5.3) |
| **Ardent** | Cendres, Nova, Brasier : la zone brute | des paquets tenus (collés, cloués, halés) | artilleur : le dégât de zone de l'équipe |
| **Rictus** | Doublures : **attirent** les monstres 3 s (sauf boss) ; Rideau : encaisse | des explosions alliées sur le paquet attiré | leurre : il décide où la foule va |
| **Bourbe** | Mottes : provoquent à 4 u 10 s (`lures`) : **tanks d'équipe** ; Bourbier : −vitesse 5 u | tout sur le paquet provoqué | mère-tank ; la seule qui protège activement un allié |
| **Avare** | Rançon : étourdit 0,5 s ; Saisie : ramène un paquet | des kills sur ses marqués (son or seulement, §2.1) | mêlée-tank ; il « tient » le pilier |
| **Taliant** | rien de public (pure mêlée) | des étourdis / collés pour frapper sans usure | le finisseur ; dépend le plus des autres |
| **Grésille** | Foudroiement : `Enemy.stun` 0,5 s (monstres ordinaires et élites, jamais boss ni mini-boss) ; **crispé** (3 cumuls) et Mise à la terre : ralentissement 20 % (`apply_status` `slow`) ; boss à 5 cumuls : `add_damage_taken_mod(&"gresille_foudre", 1,1, 2,0)` = **+10 % de dégâts subis pour toute l'équipe pendant 2 s** ; nappe d'eau électrisée : tout ce qui y est devient mouillé (`Enemy.mark_wet`) | **mouillé** (`Enemy.is_wet()`, partagé) : la trempe d'Averse et l'eau de la carte doublent ses cumuls et allongent ses arcs de 2 u ; des paquets déjà groupés | électricienne : charge, ralentit et étourdit un paquet, propage son dégât ; **la Statique est locale à son kit** (`GresilleStatic`, un registre par Grésille : deux Grésille ne partagent ni cumuls ni immunité de Foudroiement) |

Duos naturels, sans code : **Rainette + Ardent** (Gluant → Cendres sur les collés), **Arpenteuse + Tocsin** (Halage contre la chaîne → pilier dessus → Tête-cloche), **Bourbe + Taliant** (mottes qui provoquent → lame sans risque), **Vigie + n'importe qui** (+20 %), **Rictus + Averse** (doublures qui attirent → Crue sur le paquet), **Grésille + Averse** (la Vague ou la Flaque-miroir trempe le paquet ; l'Arc de Grésille y saute à 4,5 u au lieu de 2,5 u et dépose 2 cumuls par coup, la Décharge y propage jusqu'à 5 arcs à 5 u ; les deux accents, cyan et lilas, sur le même paquet : combo d'équipe lisible sans texte, `docs/fiches/gresille.md` §6). Borne haute du simulateur solo « eau partout » : global 1,10 × Ardent (`docs/audits/gresille_equilibrage.md`) ; le duo réel à deux joueurs n'a **pas** été simulé (le simulateur est solo). Un lobby de 4 Taliant est le plus pauvre (aucun contrôle) : viable mais plat ; c'est le prix de la liberté des doublons, à documenter dans l'écran de lobby par une ligne « Rôles : 4 finisseurs, 0 contrôle » (aide, jamais contrainte).

**v2 possible** (après mesure) : 3-4 « duos écrits » lisibles (« Nova ardente sur un électrisé de Tocsin : +30 % »), avec le même protocole que `Design_Combos.md` (compensation de base, chiffres dans `Balance`). Pas avant que les combos solo soient livrés.

### 5.2 Boss en coop sans toucher aux boss (gel)

Ce qui change et qui n'est **pas** un comportement de boss : les PV à l'apparition (§1.2, numérique, même nature que `BOSS_HP_MODE_MULT`), la **règle de cible** générique de `Enemy` (le plus proche ; pour les boss et mini-boss, changement de cible toutes les `COOP_BOSS_RETARGET_S` 6 s vers le **joueur vivant le plus proche**, avec un bonus de menace pour celui qui vient de frapper : évite le « tank parking » où un joueur promène le boss pendant que trois le frappent sans risque : stratégie dégénérée n° 1 de la coop), et le **coffre par joueur**. Aucun sort de boss nouveau, aucune phase nouvelle, aucun multiplicateur de dégâts. La variante « horde » (2 mini-boss à la place du boss) reste LiveOps.

Plafonds de coup inchangés : 25 % des PV max par coup, 40 % pour un boss. Avec 4 cibles, la pression par joueur **baisse** (le boss ne frappe qu'un joueur à la fois) : c'est l'enrage (`BOSS_ENRAGE_PER_S` 0,015 après 90 s) et les PV ×2,5 qui tiennent la tension, pas des dégâts.

### 5.3 Ce qui casse en coop (et la parade)

| Problème | Pourquoi | Parade proposée |
|---|---|---|
| **Empilement des contrôles** : 4 joueurs avec étourdissements (Rainette, Avare, Arpenteuse, Vigie, Grésille) enchaînés = boss ou élite jamais libre | chaque stun est court (0,5-1,5 s) mais 4 sources les enchaînent | rendements décroissants **sur les élites, mini-boss et boss seulement** : après un stun ou un emprisonnement, immunité `COOP_CC_DR_S` 2,0 s (plage 1,5-3,0) ; les monstres ordinaires restent stun-lockables (ils meurent en 1-2 coups de toute façon). Ralentissements : déjà « le plus fort l'emporte, jamais de produit » (`apply_slow`) : rien à faire. **Déjà livré (audit Grésille, 10/11/2026)** : `Balance.ELITE_STUN_REARM_S` 1,5 s, lue par `Enemy.stun` : une élite (non boss) qui sort d'un étourdissement ignore tout nouvel étourdissement pendant 1,5 s, **toutes sources confondues** (Foudroiement de Grésille, Rançon d'Avare, Grand saut de Rainette) ; c'est une version minimale, sans tag de source, de la règle ci-dessus, qui reste à étendre aux emprisonnements (`imprisoned`) si la mesure le demande (boss et mini-boss ne sont jamais étourdis par `Enemy.stun`). Pire cas estimé par l'audit avec ce plafond : environ 25 % d'étourdissement sur une élite, quel que soit le nombre de sources (estimé, non simulé à plusieurs) |
| **Attractions qui se contredisent** (Halage, Saisie, Langue, Tendeur, Rappel) : les monstres font le yo-yo | chaque attraction est correcte seule | aucune règle : c'est du ressenti, pas un exploit ; les boss sont déjà exclus des tractions (Saccade, Langue). Si le yo-yo est trop visible, `COOP_PULL_MULT` 0,7 (plage 0,5-1,0) sur les tractions quand un allié a tiré le même monstre il y a < 0,5 s |
| **Reculs contre mêlées** : Averse (Vague, Crue), Tocsin (Coup), Avare (Faillite, Bélier) repoussent le paquet que Taliant ou Rictus frappent | friction classique des coop à mêlée | accepter en v1 (c'est aussi ce qui sauve un mêlée encerclé) ; levier `COOP_KNOCKBACK_MULT` 0,7 si la télémétrie montre que les mêlées font < 80 % du DPS des distances en coop |
| **Objets à proc sur « le joueur »** : `epines` (épines au contact), `bouclier_reactif`, `orbe_de_veille`, `phenix_de_poche`, `tonique_vital`, `coeur_de_mousse`, `cape_de_brume`… | codés sur le `Player` unique | tous **par propriétaire** (ils lisent leur `Player`), aucun proc sur allié en v1 : un objet qui soigne ou protège l'équipe serait le premier objet « obligatoire » (dominant) ; un ou deux objets d'équipe (aura de régénération partagée à 6 u) sont une bonne idée de **LiveOps**, pas de lancement. Liste complète à faire passer au systems-designer avec `items.json` |
| **Objets sur l'or et les coffres** : `piece_porte_bonheur`, `faveur_du_marchand` (remise), `de_pipe`, `sablier_fele`, `chronometre_brise` | | bourse et prix **par joueur** : la remise de Nadia ne vaut que pour les coffres que Nadia paie ; rien à redistribuer |
| **Kits qui lisent « le joueur » pour viser** (129 sites) | `densest_point`, `_nearest_enemy`, `is_marked` | chaque kit vise depuis **son** propriétaire ; `is_marked` reste propre au kit (la Nova d'Ardent A ne consomme pas les Cendres d'Ardent B : deux Ardent = deux économies de marques, c'est voulu) |
| **Familiers et leurres partagés** : `decoy.gd` sert Rictus et Bourbe | | `Decoy.owner` ; les monstres attirés par un leurre le sont quel que soit le joueur proche (public) |
| **Averse / Bourbe : ressources de PV ou d'eau** | internes | aucun changement ; la masse de Bourbe au sol disparaît (§3.2) |
| **Tank parking** (un joueur kite le boss, trois frappent) | cible = le plus proche, fixe | `COOP_BOSS_RETARGET_S` 6 s + menace sur le dernier frappeur (§5.2) |
| **Un joueur reste au téléporteur pendant que les autres farment** | la charge suit « dans la zone / vivants » | plancher 0,25 et le vote de départ : pas de solo-charge rentable ; et farmer à 4 fait monter D pour tous |
| **Trois joueurs restent à l'écart d'un mini-boss pour laisser Taliant le tuer en 5 s** | mini-boss trop fragiles (`Boucle_Etage_Design.md` §1.4) | hors périmètre : la revue des mini-boss après le gel ; à 4 joueurs, ×2,5 PV ramène un mini-boss Taliant de 5 s à ≈ 12 s |

---

## 6. Parcours UX

### 6.1 Lobby et invitation

1. Titre → **Jouer** → « Seul » / « À plusieurs » (deux boutons, le second avec une icône de 4 silhouettes).
2. « À plusieurs » → **Créer une partie** (code de 6 lettres affiché en grand, bouton « Copier le lien » `rainfall://join/ABCDEF`, bouton « Inviter » qui ouvre la feuille de partage du système sur mobile ou la liste d'amis de la plateforme sur PC quand elle existe) / **Rejoindre** (saisie du code, clavier à l'écran sur mobile, ou lien).
3. **Écran de lobby** : 4 cartes de joueur en ligne (prénom de lobby, personnage, variantes, skin, pastille de plateforme, « Prêt ») ; carte de l'hôte avec mode et présage ; bouton « Prêt » en bas à droite (zone du pouce), « Lancer » pour l'hôte quand tous sont prêts ; « Quitter » en haut à gauche. Chaque joueur règle son personnage **dans sa carte** (le même écran de sélection que le solo, ouvert en surcouche) ; aperçu animé conservé.
4. **Entrée en cours de run** : non (comme RoR2) ; une place libre ne se remplit pas après le lancement. **Reconnexion** : oui (§6.3).
5. Cross-play PC / Android / iOS : **oui**, même version exigée (numéro de build affiché dans le lobby ; version différente = « Mettre à jour »).

### 6.2 Entrées (tactile, manette, clavier-souris)

Identiques au solo pour chaque joueur : joystick flottant + sort 1 automatique + sorts 2-4 en ciblage automatique sur mobile ; curseur sur PC ; stick droit à la manette. Ajouts coop, **un seul bouton nouveau** : le ping (§4.4) ; « interagir » absorbe la réanimation, le téléporteur et le veto (libellés contextuels ≤ 24 caractères : « Relever Nadia », « Partir », « Attendez ! »). En local PC : joueur 1 clavier-souris, joueurs 2-4 manettes (attribution par « appuyer sur Start ») ; les sorts 2-4 des manettes visent au stick droit, sinon le plus proche (règle existante).

### 6.3 Reconnexion, absence, hôte

- **Déconnexion ou app en arrière-plan** (appel, verrouillage) : le personnage devient **absent** : invulnérable, intangible, immobile, grisé, chevron « absent » ; aucun gain pour lui ; `COOP_ABSENT_GRACE_S` 120 s pour revenir (bouton « Reprendre » au retour de l'app) ; passé le délai, il est traité comme **mort** (retour à l'étage suivant s'il revient, sinon sa place reste vide jusqu'à la fin). Un absent ne bloque ni la charge (il n'est pas « vivant ») ni le téléporteur.
- **Hôte parti** : v1, la run s'interrompt pour tous (compensation en rubis, §3.4) ; **migration d'hôte** en v2. À annoncer clairement dans le lobby (« L'hôte porte la partie »).
- **Pause en ligne** : aucune (le temps actif de tous continue) ; « Menu » ouvre un overlay (réglages, quitter) sans arrêter le personnage ; un joueur qui ouvre le menu est **absent** s'il y reste > 10 s (protégé, sans gain). En local : pause globale, inchangée.
- **Temps actif** de la run (D) : compte dès qu'au moins un joueur est actif.

### 6.4 Mode test en multi

- Panneau TAB côté hôte seulement ; mêmes triches (PV illimités, recharge 0, or infini, D) appliquées **à tous** (une run de test est une run de test).
- **Allié fantôme** : `TestTools.spawn_dummy_ally(character_id)` : un second `Player` piloté par un script simple (suit le joueur à 3 u, sorts automatiques, peut être mis « au sol » ou « mort » d'un bouton) pour tester la réanimation, la charge proportionnelle, le vote du téléporteur, la sacoche et la lisibilité **sans deuxième humain ni réseau**. C'est aussi le socle des tests headless.
- Options : `-- --test-mode --coop=<n>` (n fantômes), `-- --coop-local` (manettes sur un PC), `-- --coop-host` / `-- --coop-join=<code>` (deux instances PC sur la même machine, boucle locale).
- Tests headless à prévoir : `coop_rules_test.tscn` (or à tous, niveau commun, coffre payé = objet au payeur, charge 2/4 = ×0,5, compte de 15 s + veto, chute/relevé/décroissance, wipe), `coop_perf_test.tscn` (4 kits + 250 monstres, temps d'image sur le palier Bas), `coop_ui_test` (sacoche non bloquante : aucun `get_tree().paused`).

---

## 7. Coût, ordre de production, points à trancher

### 7.1 Estimation (ordre de grandeur, à affiner par Opus)

| Lot | Contenu | Coût |
|---|---|---|
| 0 · Socle « n joueurs » | `Player` multiples, `RunState.players`, 129 sites `get_first_node_in_group("player")` → propriétaire / plus proche, director `round_robin`, pickups, HUD d'équipe, minimap, `OffscreenCues` alliés, teintes | 3-4 semaines (Opus + Sonnet) |
| 1 · Règles coop | or à tous, niveau commun, coffres ×, charge proportionnelle, vote du téléporteur, sacoche non bloquante, au sol / relevé / spectateur, récap par joueur, rubis, fantôme de test, tests | 2-3 semaines |
| 2 · Local PC | caméra commune avec laisse, attribution des manettes, pause globale | 1 semaine |
| 3 · En ligne | hôte autoritaire, snapshots de 250 monstres interpolés, entrées clients, lobby, codes, reconnexion, relais pour mobile (NAT) | **6-10 semaines**, plus un **coût récurrent** de relais si le pair-à-pair échoue sur mobile (fréquent) : incompatible avec « jeu à 5 € sans revenu récurrent » tant que ce coût n'est pas chiffré |
| Codex | anneau de réanimation, jauge de maintien, chevrons ×4 teintes, icônes de ping ×5, pastille de sacoche, écran de lobby, 6-8 sons (ping, chute, relevé, compte, veto, cagnotte) | 3-4 lots `low` |

### 7.2 Ordre conseillé

Lot 0 → lot 1 avec le **fantôme** (tout se teste seul) → lot 2 (local PC : premier mode jouable avec des humains, zéro réseau) → mesure du ressenti et de la perf → lot 3 seulement si le local convainc et si le coût de relais est accepté.

### 7.3 Points à trancher par le joueur

1. **Local PC d'abord, ou en ligne d'abord ?** Le document recommande local d'abord (il contient 100 % des règles et 0 % du risque réseau).
2. **Coût de relais** pour le mobile en ligne : acceptable pour un jeu à 5 € sans achat ? (Opus à consulter pour le chiffrage ; sans relais, l'en ligne mobile ne marchera pas chez tout le monde.)
3. **Doublons de personnages** : autorisés (recommandé) ou interdits ?
4. **Sacoche** (choix différé, §2.4) : réservée à la coop, ou nouvelle règle pour le solo aussi (cohérence, un seul code d'écran de coffre) ?
5. **Cagnotte du légendaire** (§2.3) : oui / non.
6. **Réanimation au sol** (§3) contre « mort jusqu'à l'étage suivant » : le document recommande la réanimation.
7. **Rubis coop** : ×1,0 (recommandé) ou petit bonus (×1,1) pour inviter à jouer à plusieurs ?
8. **Mode Difficile en coop** : exigé pour tous (recommandé) ou pour l'hôte seul ?

### 7.4 Consultants à croiser

- **systems-designer** : `economy_test` à n joueurs (cible : chaque joueur achète 8-9 coffres sur ses 23/n par étage, comme en solo) ; `COOP_PLAYER_FACTOR`, `COOP_BOSS_HP_PER_PLAYER` sur `boss_pace_test` ; liste des objets par propriétaire ; `COOP_XP_MULT`.
- **level-designer** : candidats de coffres par carte (23 à 4 joueurs), points d'apparition « round robin », rayon de la zone du gros pilier avec 4 joueurs dedans, laisse de 14 u sur les cartes étroites (Cité).
- **ux-designer** : lobby, cartes de joueur, overlay de sacoche non bloquant (tactile et manette), bouton de ping mobile, récap à 4 colonnes, teintes d'équipe contre les couleurs existantes, libellés « Relever », « Attendez ! ».
- **Opus** : architecture n joueurs, réseau, synchronisation des 250 monstres, migration d'hôte.

---

## Sources

- Risk of Rain 2 wiki, « Difficulty » (formules `playerFactor`, `timeFactor`, PV des boss par joueurs vivants, prix des interactables) : https://riskofrain2.wiki.gg/wiki/Difficulty
- Risk of Rain 2 wiki, « Teleporter » (charge proportionnelle au nombre de joueurs dans la zone, départ commun à l'interaction, objet pour les joueurs morts) : https://riskofrain2.wiki.gg/wiki/Teleporter
- Godot Rollback Netcode (prédiction client et réconciliation serveur, transports ENet / WebSocket / WebRTC) : https://github.com/SnoringCatGames/godot-rollback-netcode
- Post-mortem Tumblefire (Godot 4.5, autorité de l'hôte, ENet puis relais Steam, coop à 4 coupée) : https://lostrabbitdigital.pages.dev/blog/tumblefire-multiplayer-host-authority.html
- Cadres : MDA (Hunicke, LeBlanc, Zubek 2004) ; Deci et Ryan (autodétermination : autonomie, compétence, appartenance) ; Csikszentmihalyi (Flow, coût d'un échec proportionnel) ; Sirlin, « Playing to Win » (option dominante = bug de design).
