# Multijoueur 1 à 4 joueurs : scaling façon Risk of Rain 2

> Statut : **étude de systems design** (systems-designer, 01/11/2026), sur demande de l'orchestrateur, à partir de la demande du joueur : « un mode multijoueur 1 à 4 joueurs avec tous les scalings prévus comme sur Risk of Rain 2 ». Aucun fichier de `game/` n'est modifié. Les constantes et fonctions citées « à créer » sont des propositions pour les agents dev (`Balance` est réservé à l'orchestrateur).
>
> Lu avant d'écrire : `CLAUDE.md` (Décisions), `docs/Maths_Scaling.md` (§14 en priorité), `docs/GDD.md`, `game/scripts/core/balance.gd`, `game/scripts/core/run_state.gd`, `game/scripts/director/director.gd`, `docs/simulateur_scaling.py`, `game/data/items.json`, `floors.json`, `maps/terrasses_noyees.json` (`draw_rules`), `docs/Ateliers_Chiffres.md`, `docs/Boucle_Etage_Refonte.md`, `docs/Boutique_Rubis.md`.
>
> Hors périmètre : réseau (hôte, latence, reconnexion), caméra et écran partagé, interface (ux-designer), cartes (level-designer). Ce document dit **ce qui scale et de combien**.

## 0. Résumé

- **On reprend la structure RoR2 telle quelle** pour la difficulté (facteur joueur 1 + 0,3 (n − 1), pente de temps × n^0,2), les crédits du director (× (n + 1)/2), les coffres (+50 % par joueur en plus), l'or des kills partagé à parts égales, l'XP entière pour chacun, un coffre de boss par joueur, la charge du gros pilier au prorata des joueurs présents et la réanimation à l'étage suivant.
- **Une seule valeur RoR2 est corrigée : les PV des boss.** RoR2 les multiplie par le nombre de joueurs vivants. Transposé tel quel à Rainfall (boss d'étage calés à 65-75 s, enrage à 90 s), la simulation donne à 4 joueurs des boss d'étage de 119-194 s, un boss final de 400 s et une run de 33 min au lieu de 18 : c'est impossible, à cause de l'enrage et d'une boucle (combats longs, donc D plus haut, donc combats plus longs). Recommandé : PV × (1 + 0,4 (n − 1)) pour les boss d'étage, × (1 + 0,3 (n − 1)) pour les mini-boss, × (1 + 0,35 (n − 1)) pour le boss final.
- **Deux ajouts propres à Rainfall** : les joueurs commencent au niveau ambiant du départ (1 / 1 / 2 / 3), pour garder « l'essaim tombe en 1-2 coups » dès la première seconde ; et un joueur inactif (AFK) sort du compte des joueurs pour le director et les boss, sinon la run devient deux à trois fois plus longue.
- **Résultat (estimé, non mesuré en jeu)** à 4 joueurs : run 18,0 min (solo 17,7), boss d'étage 70-81 s (solo 70), boss final 139 s (cible 120-150), mini-boss 23-24 s, chaque joueur finit avec ≈ 24 objets (solo 37) mais 3 niveaux de plus. Ni trivial ni impossible : la pression de foule est plus forte pour l'équipe (+32 %), la menace par joueur est voisine du solo.
- **Économie** : bourses individuelles, coffre à celui qui le paie, pas de transfert d'or ni d'objet. Les rubis restent ceux du solo par joueur (même rythme par heure), avec un garde-fou de participation : le multijoueur ne doit pas devenir une ferme à rubis.

---

## 1. Rappel : comment RoR2 scale avec le nombre de joueurs

Sources (wiki Risk of Rain 2, consultées le 01/11/2026) : [Difficulty](https://riskofrain2.wiki.gg/wiki/Difficulty), [Directors](https://riskofrain2.wiki.gg/wiki/Directors), [Gold](https://riskofrain2.wiki.gg/wiki/Gold), [Level](https://riskofrain2.wiki.gg/wiki/Level), [Teleporter](https://riskofrain2.wiki.gg/wiki/Teleporter), [Lunar Coin](https://riskofrain2.wiki.gg/wiki/Lunar_Coin), [Dio's Best Friend](https://riskofrain2.wiki.gg/wiki/Dio%27s_Best_Friend). Compléments communautaires (moins sûrs, signalés) : [discussion Steam sur le partage de l'or](https://steamcommunity.com/app/632360/discussions/0/1648792158816727509), [mod Money and XP Multiplier](https://thunderstore.io/c/riskofrain2/p/OffTheClock/Money_and_XP_Multiplier/) (passe par les fonctions d'équipe du jeu, « l'or reste partagé entre joueurs »), [mod LunarCoinShareOnPickup](https://thunderstore.io/package/dan8991iel/LunarCoinShareOnPickup/) (le partage des pièces lunaires est un mod, donc absent du jeu de base), [Co-Optimus, accès anticipé](https://co-optimus.com/article/15996/risk-of-rain-2-stream-recap-and-early-access-impressions.html) (les morts reviennent quand un survivant atteint le monde suivant).

| Grandeur | Règle RoR2 (n = joueurs) | Source |
|---|---|---|
| Coefficient de difficulté | `coeff = (playerFactor + minutes × timeFactor) × 1,15^étages` ; `playerFactor = 1 + 0,3 (n − 1)` ; `timeFactor = 0,0506 × difficulté × n^0,2`. n compte aussi les joueurs déconnectés. Départ entre 1 et 1,9. | Difficulty |
| Crédits du director de combat | `crédits/s = multiplicateur × (1 + 0,4 coeff) × (n + 1) / 2` | Directors |
| PV et dégâts des monstres | aucun terme en n : ils suivent le niveau ambiant, donc le coeff (qui contient le facteur joueur) | Directors, Difficulty |
| Crédits de monstres du director de scène | non augmentés par le nombre de joueurs | Directors |
| Boss du téléporteur | crédits `600 × √coeff × (1 + piles de Shrine of the Mountain)`, sans terme en n ; **PV multipliés par le nombre de joueurs vivants** à l'apparition | Directors |
| Charge du téléporteur | au prorata des joueurs vivants dans le rayon (2 sur 4 = 50 % de vitesse) | Teleporter |
| Objets du boss | un objet par joueur, morts compris | Teleporter |
| Coffres et objets de carte | crédits d'interactables +50 % par joueur en plus (400 / 600 / 800 / 1000 sur Abyssal Depths) ; à deux, chacun obtient ≈ 75 % des objets du solo | Directors |
| Coût des coffres | même formule qu'en solo (`base × coeff^1,25`) : le facteur joueur le relève de lui-même | Directors, Chests |
| Or des kills et des tonneaux | partagé entre les joueurs (divisé à parts égales selon la communauté) ; prime = `2 × coeff × valeur × R`, sans terme en n. Sanctuaire de sang, couronne, tome et rouleau de pièces : non partagés | Gold, Steam, Thunderstore |
| XP | l'XP d'un kill est reçue en entier par chaque joueur ; l'or restant devient de l'XP au changement d'étage (pour chaque joueur, `⌈or/8⌉` par jaillissement, XP donnée à tout le monde) | Level, Gold |
| Pièces lunaires (méta) | 0,5 % de chance par kill, divisée par deux à chaque pièce tombée dans la run ; ramassée par un joueur (le partage est un mod) | Lunar Coin, Thunderstore |
| Shrine of the Mountain | +1 boss et +1 objet de boss par pile, au téléporteur | Directors |
| Mort | le joueur mort regarde (spectateur) ; il revient à l'étage suivant ; l'objet du boss tombe aussi pour lui | Teleporter, Co-Optimus |
| Résurrection | Dio's Best Friend : revient à la vie avec 3 s d'invulnérabilité, consommé | Dio's Best Friend |

Lecture : RoR2 ne gonfle **jamais** les PV d'un monstre ordinaire par joueur. Il ajoute des **monstres** (crédits × (n + 1)/2), les rend **plus forts** (facteur joueur dans le coeff, donc niveau ambiant plus haut) et **dilue le butin** (+50 % de coffres pour n joueurs, soit 75 % / 67 % / 62,5 % par joueur à 2 / 3 / 4). Seul le boss du téléporteur reçoit un multiplicateur direct de PV.

---

## 2. Transposition à Rainfall

### 2.1 Les choix de fond

| Question | Choix recommandé | Alternative écartée | Pourquoi |
|---|---|---|---|
| Or | **bourse individuelle** ; l'or des kills, des capsules et des primes va à un pot d'équipe aussitôt **divisé à parts égales** entre tous les joueurs de la partie, morts compris | pot commun dépensé par tous | Comme RoR2. Pas de vol de kill, pas de « qui a ramassé ». Un pot commun crée des disputes et laisse un joueur vider la caisse. Les morts touchent leur part : aucune spirale de mort, et aucun intérêt à « laisser mourir » un coéquipier. |
| Objets | **le coffre va à celui qui le paie** (son écran de choix, son objet) ; coffre de boss, reliquaire et coffre du Paratonnerre : **un par joueur**, morts compris | objets au sol à ramasser (RoR2) | Le choix entre 2 objets est le cœur de Rainfall : il reste personnel. Les coffres posés suivent RoR2 (+50 % par joueur) et restent « premier arrivé, premier servi ». |
| Transfert d'or ou d'objets | **aucun** (v1) | « donner » un objet | Sans transfert, on ne peut pas tout verser à un seul joueur (piles de Phénix, de Trèfle) : voir §4. |
| XP | **entière pour chaque joueur** (XP d'un kill et d'un boss inchangées) ; niveaux individuels (l'Éclat d'expérience reste personnel) | niveau d'équipe | Comme RoR2 pour la quantité ; le niveau individuel garde la valeur des objets d'XP. |
| Or restant en fin d'étage | converti en XP **pour son propriétaire seulement** (0,25 XP par or, inchangé) | XP donnée à tous (RoR2) | Écart de 0-2 P par étage (Ateliers_Chiffres §1.3) : négligeable ; le garder individuel évite qu'un joueur thésaurise pour les autres. |
| Mort | **spectateur**, puis **réanimé à la fin du prochain pilier terminé** par l'équipe (petit ou gros), à 50 % des PV max avec 2 s d'invulnérabilité, au pied du pilier ; à défaut, au début de l'étage suivant ; toute l'équipe morte = fin de run | RoR2 pur (attendre l'étage suivant, jusqu'à 4 min) ; réanimation par un coéquipier (maintenir « interagir ») | Un étage dure 3,5-4 min : attendre l'étage suivant, c'est jusqu'à 4 min de spectateur sur mobile. Les piliers (3 par étage) donnent une attente de 60-90 s et une raison de plus de finir les piliers. La réanimation manuelle est une option v2 (risque de boucle de réanimation au contact du boss). |
| Phénix de poche | **personnel** (ne relève que son porteur) | relever un coéquipier | Sinon il devient l'objet obligatoire de l'équipe. |
| Présages | **un présage pour l'équipe**, au vote (majorité ; égalité : tirage seedé) ; rubis du présage pour chacun | un présage par joueur | Les présages touchent le director, les prix et les boss : ils ne peuvent pas être individuels. |
| Défi du jour | **solo seulement** | défi en équipe | La comparabilité vient de la graine commune ; une équipe de 4 fausse le classement. |

### 2.2 Notations communes

| Symbole | Type | Plage | Sens |
|---|---|---|---|
| n | entier | 1-4 | joueurs **actifs** de la partie (connectés et non AFK), recalculé au début de chaque étage |
| n_v | entier | 1-n | joueurs actifs **vivants** au moment considéré |
| g(n) | réel | 1-2,5 | multiplicateur RoR2 d'interactables et de crédits : `g(n) = 1 + 0,5 (n − 1) = (n + 1) / 2` |
| pf(n) | réel | 1-1,9 | facteur joueur RoR2 : `pf(n) = 1 + 0,3 (n − 1)` |
| D | réel | ≥ 1 | coefficient de difficulté (`Balance.difficulty`) |
| s | entier | 1-5 (puis sans fin) | étage |
| P | or | ≥ 50 | prix d'un petit coffre de l'étage (D figé au début de l'étage) |

Valeurs de base :

| n | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| pf(n) | 1,00 | 1,30 | 1,60 | 1,90 |
| n^0,2 | 1,000 | 1,149 | 1,246 | 1,320 |
| g(n) | 1,0 | 1,5 | 2,0 | 2,5 |
| part d'un joueur g(n)/n | 100 % | 75 % | 67 % | 62,5 % |

### 2.3 Difficulté D(t, s, n)

`difficulty(t_s, stage, d, n) = (pf(n) + t_s / 60 × TIME_SLOPE × d × TIME_COMPRESSION × n^PLAYER_TIME_EXP) × K_STAGE^(stage − 1)`

| Variable | Type | Plage | Sens |
|---|---|---|---|
| t_s | s | ≥ 0 | temps actif de la run (en multi, il ne s'arrête plus pendant l'écran de coffre d'un joueur, voir §5) |
| d | réel | 1 / 2 / 3 | Facile / Moyen / Difficile (`MODES`) |
| `TIME_SLOPE`, `TIME_COMPRESSION`, `K_STAGE` | constantes | 0,0506 ; 1,5 ; 1,15 | inchangées |
| `PLAYER_FACTOR_SLOPE` (à créer) | réel | 0,3 | pente du facteur joueur, RoR2 |
| `PLAYER_TIME_EXP` (à créer) | réel | 0,2 | exposant du nombre de joueurs sur la pente de temps, RoR2 |

Sortie : D ≥ 1, non plafonné (comme en solo) ; jamais de valeur inutilisable (n ≥ 1). Minimum 1,0 (solo, t = 0) ; départ à 1,3 / 1,6 / 1,9 pour 2 / 3 / 4 joueurs.

| n | D à l'entrée des étages 1 / 2 / 3 / 4 / 5 (t = 0, sans le temps) | Pente par minute (Moyen) | D(10 min, étage 3) |
|---|---|---|---|
| 1 | 1,00 / 1,15 / 1,32 / 1,52 / 1,75 | 0,152 | 3,33 |
| 2 | 1,30 / 1,49 / 1,72 / 1,98 / 2,27 | 0,174 | 4,03 |
| 3 | 1,60 / 1,84 / 2,12 / 2,43 / 2,80 | 0,189 | 4,62 |
| 4 | 1,90 / 2,18 / 2,51 / 2,89 / 3,32 | 0,200 | 5,16 |

Exemple : 4 joueurs, Moyen, 10 min, étage 3 : (1,9 + 10 × 0,0506 × 2 × 1,5 × 1,320) × 1,15² = (1,9 + 2,004) × 1,3225 = **5,16** (niveau ambiant 13, contre 3,33 et niveau 8 en solo).

Effets en chaîne, sans autre formule : PV et dégâts des monstres (`monster_hp`, `monster_damage` via `monster_level`), chance d'élite (`elite_chance`), prix des coffres et des ateliers (`chest_price`, `station_price_p`), or et XP par kill (`monster_gold`, `monster_xp`), capsules (`capsule_gold`), primes de boss. Le palier de la jauge (`DIFFICULTY_TIERS`) monte aussi : à 4 joueurs on démarre « Hostile » (1,9 ≥ 1,6). C'est voulu et visible, comme RoR2.

### 2.4 Niveau de départ des joueurs (ajout Rainfall)

`start_level(n) = monster_level(pf(n)) = 1 + floor((pf(n) − 1) / 0,33)` → **1 / 1 / 2 / 3** ; le joueur reçoit au départ l'XP cumulée de ce niveau.

Pourquoi : à 4 joueurs, D = 1,9 dès la première seconde, donc des essaims de niveau 3 (18 × 1,66 = 30 PV) contre un tir de sort 1 de niveau 1 (0,8 × 12 = 9,6) : **3,1 coups** au lieu de 1,9 en solo, contraire à la décision « monstres de base fauchés en 1-2 coups ». Avec le niveau 3 : 30 / (0,8 × 16,8) = **2,2 coups** (2,1 à 3 joueurs). L'XP partagée rattrape de toute façon cet écart en 30-45 s ; cet ajout ne change presque rien à la fin de run (niveau final 15,5 contre 15,5 sans lui) mais efface les 30 premières secondes ratées. Plage sûre : `start_level` entre 1 et `monster_level(pf(n))` ; jamais au-dessus.

### 2.5 Director : crédits et plafond de vivants

`director_credits_per_s(D, zone, n) = CREDIT_K × (1 + 0,4 D) × ZONE_SPAWN_MULT[zone] × g(n)` (× `director_ramp(t)` et présage Marée, inchangés)

| Variable | Type | Plage | Sens |
|---|---|---|---|
| `PLAYER_CREDIT_SLOPE` (à créer) | réel | 0,5 | g(n) = 1 + 0,5 (n − 1), RoR2 |
| zone | clé | `""`, `mini`, `etage`, `epreuve` | la zone compte si **au moins un** joueur vivant y est (aujourd'hui `_player_zone(ppos)` d'un seul joueur) |

Sortie : > 0, plafonnée de fait par le plafond de vivants et la banque de crédits `CREDIT_BANK_MAX`. Exemple : D = 5,16, hors zone, 4 joueurs : 0,894 × 3,064 × 2,5 = **6,85 crédits/s** (solo à D = 3,33 : 2,08).

`director_alive_cap(t_s, n) = min(lerp(RAMP_ALIVE_MIN, RAMP_ALIVE_MAX, t_s / RAMP_TIME_S) × (1 + PLAYER_ALIVE_SLOPE (n − 1)), MAX_ENEMIES)`

| n | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| plafond de vivants (pleine rampe) | 150 | 180 | 210 | 240 |

`PLAYER_ALIVE_SLOPE` (à créer) = 0,2, plage 0-0,25 ; `MAX_ENEMIES` 250 inchangé. Estimé : le plafond ne mord pas au rythme visé (pic ≈ 23 monstres par joueur, ≈ 92 pour l'équipe), mais sans lui les crédits × 2,5 s'entasseraient dans la banque pendant la charge (× 2,33) et l'or ralentirait. **Mobile, qualité Basse** : garder 150 quel que soit n (la perte d'or est alors faible et le budget de 250 monstres est tenu avec 4 joueurs, leurs projectiles et leurs procs).

Points de spawn : chaque paquet ou vague choisit **un joueur vivant au hasard** comme ancre (RoR2) ; un joueur seul à l'écart ne reçoit donc qu'≈ 1/n des monstres.

### 2.6 Monstres ordinaires et élites

**Aucun changement de formule.** PV, dégâts, vitesse et élites suivent D (donc pf(n)) : c'est exactement le modèle RoR2. Les gardiens des salles secrètes (brutes élites) aussi.

### 2.7 Boss : PV et dégâts

`boss_hp(kind, D, stage, n_v) = BOSS_BASE_HP[kind] × BOSS_FOCUS_HP_MULT[kind] × (1 + 0,3 (niv − 1)) × √D × BOSS_STAGE_K^(stage − 1) × (1 + BOSS_HP_PLAYER_SLOPE[kind] × (n_v − 1))`

| Variable | Type | Plage | Sens |
|---|---|---|---|
| n_v | entier | 1-4 | joueurs actifs **vivants à l'apparition** du boss (RoR2) ; figé ensuite (une réanimation pendant le combat ne change rien) |
| `BOSS_HP_PLAYER_SLOPE` (à créer) | dictionnaire | `{mini: 0.3, etage: 0.4, final: 0.35}` | supplément de PV par joueur vivant en plus |
| dégâts des boss | - | - | inchangés (`boss_damage` suit D) ; plafond de coup 40 % des PV max du joueur touché, inchangé |
| enrage | - | 90 s | inchangé (`BOSS_ENRAGE_AFTER_S`) |

Sortie : PV > 0, multiplicateur 1,0-2,2 (boss d'étage), 1,0-1,9 (mini), 1,0-2,05 (final). Le boss final garde `FINAL_BOSS_HP_MULT` 1,35 et les raids `BOSS_HP_MULT` ; `BOSS_HP_MODE_MULT` et le Paratonnerre dévié se multiplient par-dessus.

| n_v | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| boss d'étage (RoR2 : × n) | × 1,0 | × 1,4 | × 1,8 | × 2,2 |
| mini-boss | × 1,0 | × 1,3 | × 1,6 | × 1,9 |
| boss final | × 1,0 | × 1,35 | × 1,7 | × 2,05 |

Exemple : boss d'étage, étage 3, D = 5,16 (niveau 13), 4 joueurs vivants : 3 300 × 0,5 × (1 + 0,3 × 12) × √5,16 × 2,2 = **37 900 PV** (solo à D = 3,33 : 9 330). Le rapport ≈ 4,1 vient pour moitié de D (niveau et √D) et pour moitié du multiplicateur de joueurs ; l'équipe a 4 fois les sorts, 3 niveaux de plus par joueur et ≈ 34 % d'objets en moins par joueur.

**Pourquoi pas × n comme RoR2** (simulation §3, variante `ror2`) : à 4 joueurs, boss d'étage 119 / 159 / 181 / 194 s (étages 1-4), au-delà de l'enrage de 90 s, boss final 401 s, run 33 min. RoR2 l'absorbe parce que ses boss n'ont pas d'enrage et que ses étages ne sont pas compressés (`TIME_COMPRESSION` 1,5). Avec × (n + 1)/2 partout (variante `boss_demi`) : 78-96 s et 188 s, encore à la limite de l'enrage aux étages 2-4.

### 2.8 Gros pilier, petits piliers, épreuves

| Élément | Règle multi | Constante / clé | Valeur |
|---|---|---|---|
| Charge du gros pilier | vitesse × (joueurs vivants dans la zone) / (joueurs vivants), comme le téléporteur RoR2 ; 60 s si toute l'équipe y est | `PILLAR_CHARGE_S` | 60 (inchangé) |
| Zones de spawn (`mini`, `etage`, `epreuve`) | actives si au moins un joueur vivant est dedans ; × g(n) via les crédits (§2.5) | `ZONE_SPAWN_MULT` | inchangé |
| Petits piliers | aucune règle nouvelle ; deux joueurs peuvent ouvrir les deux en même temps (déjà permis en solo) : étage ≈ 25 s plus court, voulu (coordination) | - | - |
| Épreuves (prototype `--epreuves`) | Escorte : la barque avance si **un** joueur est à moins de `ESCORT_LEASH_U` ; PV de la barque = `ESCORT_HP_MINI_SHARE` × PV du mini-boss **multi** (ils suivent n) | `ESCORT_HP_MINI_SHARE` | 0,3 (inchangé) |
| | Rituel et Poursuite, qui se partagent à plusieurs (3 relais fermés en parallèle) : seuil « parfait » plus court | `EPREUVE_TARGET_PLAYER_SLOPE` (à créer) | 0,08 : cible × (1 − 0,08 (n − 1)), soit × 0,76 à 4 ; plage 0,05-0,12 |
| | Veine, Tenue, Escorte : rien (un seul objet à suivre ou défendre) | - | - |
| | Or de la note : pot d'équipe `EPREUVE_GOLD_P × P × g(n)`, divisé entre les joueurs | `EPREUVE_GOLD_P` | inchangé |

### 2.9 Coffres, capsules, primes : nombre, prix, or par joueur

**Prix** : `chest_price(kind, D, stage)` **inchangé**. Il monte de lui-même avec pf(n) : P de l'étage 1 = 50 / 69 / 90 / 112 or pour 1 / 2 / 3 / 4 joueurs. Relance à l'or (`gold_reroll_price`), Enclume, Marchand : inchangés (multiples de P). Relances gratuites (1 par coffre, 3 par run) : **par joueur**.

**Nombre de coffres posés** (`draw_rules` des cartes, multipliés par `interactable_mult(n) = 1 + PLAYER_INTERACTABLE_SLOPE (n − 1)`, à créer, 0,5) :

| n | petits | grands | chance de légendaire | dont vitrines | part d'un joueur |
|---|---|---|---|---|---|
| 1 | 8 | 2 | 25 % | 2 | 100 % |
| 2 | 12 | 3 | 37,5 % | 3 | 75 % |
| 3 | 16 | 4 | 50 % | 4 | 67 % |
| 4 | 20 | 5 | 62,5 % | 5 | 62,5 % |

Arrondi : `roundi(base × mult)` ; chance de légendaire `min(1, 0,25 × mult)` ; `CHEST_SPECIAL_MAX_PER_STAGE` 2 → `roundi(2 × mult)`. Les cartes doivent offrir assez de points `C` (20 petits + 5 grands à 4 joueurs) : à vérifier par level-designer ; à défaut, tirer les surplus parmi les cases `.`.

**Or** (tous les flux d'équipe, divisés par n joueurs de la partie, morts compris) :

| Source | Pot d'équipe | Reçu par chaque joueur |
|---|---|---|
| Kill | `monster_gold(D, coût)` (inchangé) | ÷ n |
| Capsule d'argent | `capsule_gold(D) × interactable_mult(n)` ; **nombre inchangé** (4, décision du 01/11 contre le « tour de map ») | ÷ n |
| Prime de mini-boss / boss | `boss_gold(kind, D) × interactable_mult(n)` | ÷ n |
| Note d'épreuve | `EPREUVE_GOLD_P × P × interactable_mult(n)` | ÷ n |
| Gardien de salle secrète | `guardian_bonus_gold` (inchangé : il suit D) | ÷ n |

Exemple : capsule à D = 5,16, 4 joueurs : 40 × 5,16^1,25 × 2,5 = 782 or, soit **195 or par joueur** (solo à D = 3,33 : 180). Les bonus d'or des objets (Pièce porte-bonheur `gold_mult`) s'appliquent à **la part** de leur porteur.

**XP** : chaque joueur reçoit `monster_xp(D, coût)` et `boss_xp(kind, D)` en entier, sans le facteur `interactable_mult` (XP d'un boss inchangée). Multiplicateurs d'XP des objets : personnels.

**Coffres de boss, reliquaires, Paratonnerre** : un par joueur, morts compris (l'objet attend le joueur mort et s'ouvre à sa réanimation). Coffre du Paratonnerre dévié : un de plus par joueur. Reliquaires de salle secrète : un par joueur.

Bilan par joueur (estimé, Moyen, tableau §3.2) : ≈ 8 / 6,1 / 5,5 / 5,2 objets par étage pour 1 / 2 / 3 / 4 joueurs, soit 37 / 28 / 26 / 24 objets par run. C'est la dilution voulue par RoR2 : le pouvoir passe du sac d'objets à l'équipe et aux niveaux (+1,2 / +2,3 / +3,1).

### 2.10 Ateliers, marchand, Boussole, présages

| Élément | Règle multi | Pourquoi |
|---|---|---|
| Fondoir, Matrice, Alambic, Enclume | **un atelier pour tous, usages par joueur** (Fondoir 2, Matrice 3, Alambic 2, Enclume 3 chacun) ; prix en P inchangés ; `ENCLUME_PRICE_GROWTH` compté par joueur | L'atelier convertit les objets **de celui qui l'utilise** : des usages partagés créent une course. Les prix en P suivent déjà pf(n). |
| Scories (`SCRAP_CAP` 3) | par joueur | inventaire personnel |
| Boussole de rouille | 2 charges par joueur, tag choisi par chacun | idem |
| Marchand de l'étage 3 | **un étal par joueur** (1 objet par rareté chacun, prix `MERCHANT_PRICE_MULT` × P) | sinon le premier arrivé prend le légendaire ; le marchand est un puits d'or limité par la bourse, il ne dilue pas l'économie (or par joueur déjà ÷ n) |
| Présages | un pour l'équipe, au vote ; `OMEN_RUBIES` pour chacun ; Offrande : un reliquaire par joueur ; Usure : retire le coffre de boss de **chacun** et baisse tous les prix ; Marée : × 1,15-1,25 par-dessus g(n) | les effets portent sur le director et les prix communs |
| Paratonnerre dévié | décidé par le joueur qui active le gros pilier (comme en solo), affiché à toute l'équipe ; PV × table × multiplicateur joueurs | une seule activation par pilier |

### 2.11 Réanimation (constantes à créer)

| Constante | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `MULTI_REVIVE_ON_PILLAR` | true | - | un pilier terminé (petit ou gros) relève tous les joueurs morts |
| `MULTI_REVIVE_HP_PCT` | 0,5 | 0,3-0,5 | PV à la réanimation (= Phénix) |
| `MULTI_REVIVE_INVULN_S` | 2,0 | 1,5-3 | invulnérabilité (Phénix 2 s, Dio 3 s) |
| `MULTI_AFK_S` | 45 | 30-60 | sans entrée ni dégât infligé pendant ce temps : joueur « absent », retiré de n au prochain recalcul (début d'étage) et de n_v à la prochaine apparition de boss |

Attente moyenne d'un mort (estimé) : 60-90 s (un pilier toutes les ≈ 70 s), au pire ≈ 2 min si l'équipe meurt pendant la charge du gros pilier puis réanime au pilier suivant… qui est à l'étage suivant.

### 2.12 Rubis de fin de run (économie cosmétique)

`run_rubies_multi = floor(participation × (floor(1,2 × minutes × mult_mode) + 8 × piliers + 25 × victoire + min(or_restant / (500 × pf(n)^1,25), 20)))`, puis `+ omen_rubies(présages)`.

| Variable | Type | Plage | Sens |
|---|---|---|---|
| minutes, piliers, victoire | - | - | ceux de l'équipe (un joueur mort qui regarde touche les piliers terminés : il n'a aucun intérêt à quitter) |
| or_restant | or | ≥ 0 | sa bourse ; divisé par pf(n)^1,25 = 1 / 1,39 / 1,80 / 2,23 parce que les prix (donc l'or en circulation) sont plus hauts de ce facteur |
| participation (à créer : `MULTI_RUBY_PARTICIPATION_MIN` 0,25) | réel | 0-1 | `clamp(dégâts infligés par le joueur / (dégâts de l'équipe / n) / 0,25, 0, 1)` : vaut 1 dès qu'il fait 25 % de la moyenne ; un AFK touche 0 |

Sortie : 0 à ≈ 200 rubis par run, comme en solo ; jamais négatif. Exemple : victoire en Moyen, 18 min, 13 piliers, 3 000 or restant à 4 joueurs, participation 1 : 21 + 104 + 25 + floor(3 000 / 1 115) = **152** (+ présages) ; même run en solo avec 1 800 or : 21 + 104 + 25 + 3 = 153.

La run multi dure le même temps (17-18 min) et termine les mêmes 13 piliers : **les rubis par heure sont ceux du solo** (300-550/h, Boutique_Rubis §0). Aucun bonus « multi » : il serait une raison de jouer en groupe pour le gain, ce qui est le début d'une ferme. Défi du jour : solo seulement.

### 2.13 Tableau des constantes et fonctions (récapitulatif)

| Constante / fonction (`Balance`, à créer sauf mention) | Actuel | Proposé | Plage sûre |
|---|---|---|---|
| `MULTI_MAX_PLAYERS` | - | 4 | 4 |
| `PLAYER_FACTOR_SLOPE` | (solo : 0) | 0,3 | 0,2-0,3 |
| `PLAYER_TIME_EXP` | (solo : 0) | 0,2 | 0-0,2 |
| `PLAYER_CREDIT_SLOPE` | - | 0,5 | 0,4-0,5 |
| `PLAYER_INTERACTABLE_SLOPE` | - | 0,5 | 0,5-0,75 |
| `PLAYER_ALIVE_SLOPE` | - | 0,2 (0 en qualité Basse) | 0-0,25 |
| `BOSS_HP_PLAYER_SLOPE` | - | `{mini: 0.3, etage: 0.4, final: 0.35}` | mini 0,25-0,4 ; étage 0,35-0,5 ; final 0,3-0,45 |
| `EPREUVE_TARGET_PLAYER_SLOPE` | - | 0,08 | 0,05-0,12 |
| `MULTI_REVIVE_HP_PCT` / `MULTI_REVIVE_INVULN_S` | - | 0,5 / 2,0 | 0,3-0,5 / 1,5-3 |
| `MULTI_AFK_S` | - | 45 | 30-60 |
| `MULTI_RUBY_PARTICIPATION_MIN` | - | 0,25 | 0,15-0,35 |
| `difficulty(t_s, stage, d, n := 1)` | sans n | `pf(n)` et `n^PLAYER_TIME_EXP` | - |
| `director_credits_per_s(D, zone, n := 1)` | sans n | × `1 + PLAYER_CREDIT_SLOPE (n − 1)` | - |
| `director_alive_cap(t_s, n := 1)` | sans n | × `1 + PLAYER_ALIVE_SLOPE (n − 1)`, ≤ `MAX_ENEMIES` | - |
| `boss_hp(kind, D, stage, n_alive := 1)` | sans n | × `1 + BOSS_HP_PLAYER_SLOPE[kind] (n_alive − 1)` | - |
| `interactable_mult(n)` | - | `1 + PLAYER_INTERACTABLE_SLOPE (n − 1)` | - |
| `player_start_level(n)` | - | `monster_level(pf(n))` | 1 à `monster_level(pf(n))` |
| `run_rubies(..., n := 1, participation := 1.0)` | sans n | §2.12 | - |

Avec n = 1, chaque fonction rend exactement la valeur solo actuelle : les tests existants (`test_balance.gd`, `economy_test`) ne bougent pas. Côté `RunState` (à créer, contrat à signaler) : `player_count` (n, recalculé au début d'étage), `players_alive()`, bourse et XP **par joueur** (aujourd'hui un seul `gold` / `xp` / `items`) ; c'est le plus gros chantier, hors de ce document.

---

## 3. Simulation (estimée, non mesurée en jeu)

Script : `docs/multi/sim_multi.py` (`python docs/multi/sim_multi.py [ror2|boss_demi|boss_demi_pf02|boss_04|reco|sens]`). Il ne touche pas `docs/simulateur_scaling.py` (modèle v3 historique, dont les constantes divergent de `balance.gd` : pente 0,30, coffres à 150 or, crédits 4 + 2,5 D ; il n'a pas servi).

### 3.1 Modèle

- Constantes recopiées de `balance.gd` (01/11/2026) : difficulté, director (rampe 480 s, zones × 1,5 / × 2,33), coût moyen, élites, prime `REWARD_MULT` 0,235, boss (`BOSS_FOCUS_HP_MULT`, √D, niveau ambiant, final × 1,35), coffres (50 / 100, × 1,04 par étage), 4 capsules à 40 × D^1,25, courbe de niveau (0,076 ; 1,55), or restant → 0,25 XP.
- Rythme : celui de `Ateliers_Chiffres.md` §0 (étages 1-4 : exploration 15 s, mini A, trajet 30 s, mini B, trajet 25 s, gros pilier = max(charge 60 s, combat), sortie 30 s ; étage 5 : 45 s puis boss final). Les combats durent leur TTK simulé : un boss lent allonge l'étage et fait monter D.
- **« Objets moyens réalistes »** : le DPS mono-cible solo est calibré, combat par combat, pour retrouver les TTK visés en solo (mini 25 s, boss d'étage 70 s, final 135 s : `Maths_Scaling` §14.0). Ce DPS encode donc le build moyen mesuré en jeu. En multi, chaque joueur garde ce DPS, corrigé par son niveau (dégât de base 12 + 2,4/niv) et par ses points d'objets (60 % des points vont au DPS ; grille `Items_Catalog` §1 : petit 13,2, grand 29, boss 26,2).
- Or et XP : crédits dépensés × prime, 95 % des monstres tués tant que l'équipe suit (au-delà, en proportion de la pression) ; or ÷ n, XP entière ; achats en espérance (petits puis grands) dans la limite de la part du joueur.
- Indicateurs : **rho** = PV de monstres apparus par seconde ÷ capacité de nettoyage de l'équipe (DPS de zone ≈ 2 × mono), rapporté au solo ; **gravité** = coup de contact d'essaim ÷ PV max du joueur, rapporté au solo ; **coups d'essaim** = PV d'un essaim ÷ tir de sort 1 (cible 1-2) ; **vivants par joueur** au pic.
- Vérification du modèle en solo : 36,8 objets par run (journaux réels : 40-42, Ateliers §1.1), P = 50 / 108 / 195 / 324 / 509 (mesurés : 50 / 105-111 / 191-198 / 345-353 / 555-564), niveau final 12,4 (mesuré 13-14), run 17,7 min (visée 18-19). Écart de 5-10 % : acceptable pour comparer n = 1 à n = 4, pas pour fixer des valeurs absolues.

Limites : pas de réseau, pas de synergie entre joueurs (soins, contrôle), part du DPS qui touche le boss supposée identique en multi, temps passé dans les écrans de coffre ignoré (§5), réanimations non modélisées, coffres partagés équitablement (pas de course).

### 3.2 Résultats (Moyen)

| Variante | n | Run (min) | D fin | Niv. fin | Objets / joueur | TTK mini é1/é3 (s) | TTK boss d'étage é1/é2/é3/é4 (s) | Final (s) | rho / solo | Gravité / solo | Coups d'essaim |
|---|---|---|---|---|---|---|---|---|---|---|---|
| (solo) | 1 | 17,7 | 6,44 | 12,4 | 36,8 | 25 / 25 | 70 / 70 / 70 / 70 | 135 | 1,00 | 1,00 | 0,84 |
| `ror2` (boss × n) | 2 | 23,4 | 9,40 | 14,6 | 30,8 | 38 / 38 | 89 / 101 / 114 / 118 | 233 | 1,40 | 1,21 | 1,13 |
| | 3 | 28,0 | 12,07 | 16,1 | 29,0 | 50 / 51 | 104 / 130 / 148 / 159 | 310 | 1,83 | 1,35 | 1,34 |
| | 4 | 32,9 | 14,84 | 17,3 | 28,0 | 62 / 63 | 119 / 159 / 181 / 194 | 401 | 2,34 | 1,49 | 1,53 |
| `boss_demi` (boss × (n+1)/2) | 4 | 21,0 | 10,67 | 16,0 | 25,5 | 39 / 33 | 78 / 93 / 96 / 95 | 188 | 1,52 | 1,39 | 1,39 |
| `boss_demi_pf02` (+ pf 0,2) | 4 | 18,9 | 9,42 | 15,5 | 25,2 | 31 / 28 | 67 / 75 / 82 / 84 | 157 | 1,21 | 1,29 | 1,26 |
| **`reco`** | 2 | 17,0 | 7,46 | 13,6 | 28,2 | 24 / 23 | 65 / 64 / 69 / 71 | 127 | 1,03 | 1,17 | 1,07 |
| | 3 | 17,4 | 8,55 | 14,7 | 25,5 | 23 / 24 | 66 / 73 / 74 / 73 | 131 | 1,15 | 1,26 | 1,22 |
| | 4 | 18,0 | 9,64 | 15,5 | 24,2 | 23 / 24 | 70 / 76 / 81 / 81 | 139 | 1,32 | 1,34 | 1,35 |

Prix d'un petit coffre (P) par étage, variante `reco` : 1 joueur 50 / 108 / 195 / 324 / 509 ; 2 joueurs 69 / 140 / 243 / 398 / 618 ; 3 joueurs 90 / 174 / 299 / 481 / 740 ; 4 joueurs 112 / 210 / 354 / 564 / 863. Objets cumulés par joueur à la fin des étages 1-5 (4 joueurs) : 5,1 / 10,5 / 15,8 / 21,1 / 24,3 (solo : 8 / 16 / 23,9 / 31,7 / 36,8).

Coups pour tuer un essaim, par étage (4 joueurs, `reco` avec niveau de départ 3) : 1,56 / 1,26 / 1,23 / 1,28 / 1,40 (solo : 1,04 / 0,78 / 0,76 / 0,78 / 0,85) ; au tout premier coup de la run : 2,2 (solo 1,9). La règle « 1-2 coups » tient.

### 3.3 Lecture : n = 4 n'est ni trivial ni impossible

- **Boss** : 70-81 s contre 70 s en solo, sous l'enrage de 90 s (marge 9 s aux étages 3-4) ; final 139 s dans la cible 120-150 s ; mini-boss 23-24 s (cible 21-30). Le combat dure autant, avec 4 fois plus de sorts à l'écran : c'est le spectacle voulu.
- **Foule** : rho × 1,32 : l'équipe doit nettoyer 32 % de PV de plus par unité de DPS qu'un joueur seul (plus de monstres, de plus haut niveau). Chaque coup reçu pèse 34 % de plus face aux PV max, mais chaque joueur ne voit qu'≈ 23 monstres au pic contre 36 en solo (ancres de spawn réparties, crédits × 2,5 pour 4 joueurs) : la **menace par joueur est voisine du solo** (≈ 1,34 × 23/36 ≈ 0,86, estimé), plus la réanimation. Le multi est donc un peu plus indulgent pour la survie et aussi long sur les boss : c'est aussi le ressenti courant de RoR2.
- **Durée** : 17,0-18,0 min contre 17,7 : la run garde son format.
- **Robustesse** (`sim_multi.py sens`, 4 joueurs) : part de zone du DPS 1,5-2,5 → boss 77-78 s ; part de DPS des objets 45-75 % → boss 75-79 s, final 136-147 s. Les modes : Facile 4 joueurs → boss × 1,17 du solo, Difficile × 1,04 (le facteur joueur pèse plus quand la pente de temps est faible). Levier si le Facile multi est jugé dur : `BOSS_HP_PLAYER_SLOPE` par mode (0,35 en Facile).
- **Coffres plus généreux** (`PLAYER_INTERACTABLE_SLOPE` 0,75, part par joueur 81 % à 4) : boss 71 s, final 127 s, rho 1,18, 27,7 objets par joueur. Possible si le joueur trouve la dilution frustrante ; à 1,0 (100 % par joueur), boss 66 s et final 113 s : trop facile.

---

## 4. Stratégies dégénérées et garde-fous

| Stratégie | Risque (chiffré) | Garde-fou | Résidu |
|---|---|---|---|
| **Joueur AFK compté dans n** | sans garde-fou, à 4 dont 1 AFK : boss 116 s (enrage), final 237 s, run 24 min ; à 2 dont 1 AFK : boss 193 s, run 37 min (sim `sens`) | `MULTI_AFK_S` 45 s : retiré de n et de n_v ; rubis × participation (0 pour un AFK) | un AFK compté jusqu'au début d'étage suivant (≤ 4 min) : boss du gros pilier compté sans lui car n_v est relu à l'apparition |
| **Ferme à rubis à plusieurs appareils** (un humain, 3 appareils inactifs) | 4 profils payés pour une run | participation ≥ 25 % de la moyenne des dégâts ; pas de bonus multi | une personne qui joue vraiment 4 appareils à la fois : rubis/heure du solo par appareil, sans intérêt |
| **Se laisser mourir avant le boss** pour baisser ses PV | PV × 1,4 au lieu de 2,2 si 2 morts sur 4 | n_v à l'apparition, mais les morts ne reviennent qu'au pilier **terminé** : l'équipe se prive de la moitié de son DPS pour tout le combat ; perte nette | aucun |
| **Réanimer en plein combat** | DPS plein contre des PV comptés pour n_v réduit | réanimation seulement à la fin d'un pilier (jamais pendant le combat qui le termine) | aucun |
| **Course aux coffres** (un joueur rapide achète tout) | les autres perdent leur part ; leur or devient de l'XP à 0,25 par or (moitié moins rentable) | règle sociale (RoR2) ; option v2 : un coffre se réserve 3 s au premier qui interagit, et « coffres marqués » au ping | inégalité possible, pas d'abus de puissance (l'équipe ne gagne rien) |
| **Tout donner à un porteur** (Phénix ×8, Trèfle ×8) | invulnérabilité de fait | aucun transfert d'or ni d'objet ; Phénix personnel ; Matrice et Enclume excluent déjà le Phénix | aucun |
| **Farm prolongé à 4** | or par minute plus haut en absolu | prix ∝ D^1,25 avec le même pf(n) ; pente de temps × n^0,2 (le multi vieillit plus vite que le solo : +32 % de D par minute à 4) | aucun gain relatif au solo |
| **Charger le gros pilier seul** pendant que les autres achètent | charge à 1/n de vitesse | prorata RoR2 | voulu : choix de l'équipe |
| **Deux mini-boss en parallèle** | étage plus court de ≈ 25 s | déjà permis en solo ; zones distinctes | voulu (coordination) |
| **Rituel à plusieurs** | « parfait » trivial (3 relais en parallèle) | `EPREUVE_TARGET_PLAYER_SLOPE` 0,08 | à mesurer au prototype |
| **Quitter / revenir** pour baisser D | pf(n) baisse de 0,3 au début d'étage suivant | n relu seulement au début d'étage ; prix figés au début d'étage ; le partant perd son tour | gain ≤ 0,3 × 1,15^(s−1) de D pendant un étage, au prix d'un joueur absent : perte nette |
| **Vote de présage saboté** | présage subi | majorité ; « Ciel clair » reste proposé hors Difficile | aucun |
| **Procs à 4 joueurs (perf mobile)** | 4 × chaînes d'éclair, épines, projectiles | plafonds existants par joueur (`CHAIN_LIGHTNING_MAX_TARGETS` 8, `TELEGRAPH_*_MAX`) ; **à ajouter** : plafond global de projectiles joueurs actifs (proposé 120, plage 80-160) et recharge interne de 0,1 s par monstre pour les procs d'un autre joueur sur la même cible | à mesurer (250 monstres + 4 joueurs sur Android d'entrée de gamme) |

Boucles de rétroaction : la boucle renforçante « combat long → D plus haut → combat plus long » est la raison du rejet de « boss × n ». La boucle équilibrante « prix ∝ D^1,25 » tient l'économie quel que soit n. La dilution des objets (62,5 % par joueur à 4) est une boucle équilibrante voulue : elle laisse la place à l'équipe et aux niveaux.

---

## 5. Points à trancher (joueur)

1. **Boss : × n (RoR2 pur) ou × (1 + 0,4 (n − 1)) (recommandé)**. Le premier est fidèle mais injouable avec l'enrage à 90 s ; le second garde les TTK du solo.
2. **Réanimation** : à la fin d'un pilier (recommandé) ou RoR2 pur (étage suivant).
3. **Coffres** : +50 % par joueur (RoR2, 62,5 % par joueur à 4) ou +75 % (81 %), si la dilution déplaît.
4. **Écran de coffre en multi** : le temps ne peut plus s'arrêter pour un seul joueur. Proposition : le monde continue (pas d'invulnérabilité, sinon le menu devient une esquive), révélation « instant » par défaut (`CHEST_REVEAL_MODES`), et le temps actif de la run avance (D monte un peu plus vite qu'en solo : ≈ +2-3 % de D en fin de run, estimé, non simulé). À voir avec ux-designer.
5. **Plafond de vivants sur mobile** : 240 à 4 joueurs (PC) contre 150 en qualité Basse.
6. Hors économie, signalé au passage : l'objet `eclair_en_bouteille` porte le nom affiché « Ukulele » dans `game/data/items.json`, nom d'un objet de Risk of Rain 2, contraire à la règle « aucune reprise de noms ».

## 6. Tests à prévoir (pour les agents dev)

- `test_balance.gd` : chaque fonction avec n = 1 rend la valeur solo actuelle au centième ; tableaux §2.3, §2.7, §2.9 recalculés.
- `economy_test` multi : or par joueur et par étage dans la bande `sim_multi.py reco` ± 15 % pour n = 2 et 4.
- `boss_pace_test` : PV × table §2.7 ; n_v figé à l'apparition.
- Télémétrie `RunLog` (par joueur) : n, morts et attente avant réanimation, part des dégâts, objets par étage, TTK des boss par n. Seuils : boss d'étage > 85 s à 4 joueurs → `BOSS_HP_PLAYER_SLOPE[&"etage"]` 0,4 → 0,35 ; < 60 s → 0,45.
