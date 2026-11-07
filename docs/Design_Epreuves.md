# Les Épreuves généralisées aux biomes 1-4 : plan d'implémentation (v1)

> Statut : **plan d'implémentation ; lots E0-E5 appliqués, bascule `EPREUVES_ENABLED = true` faite le 07/11/2026 (§15)** (Fable, designer-fable, 07/11/2026), sur décision du joueur du 06/11/2026 : *les Épreuves (prototype des Terrasses, `Balance.EPREUVES_ENABLED = false`) sont généralisées aux autres biomes sans campagne de test préalable.*
> Lu avant d'écrire : `docs/Boucle_Etage_Refonte.md` (§1, §5.3, §6), `docs/Boucle_Etage_Design.md`, `docs/Boucle_Etage_Level.md`, `docs/Design_Etages.md`, `docs/Design_Etage2_Grotte.md`, `docs/Ateliers_Chiffres.md` §1, `docs/multi/Design_Coop.md` §1.3, `docs/multi/Scaling_Multi.md` §2.8, `game/scripts/stage/epreuve.gd`, `epreuve_escort.gd`, `epreuve_ritual.gd`, `epreuve_relay.gd`, `stage_manager.gd` (§ Épreuves), `game/scripts/core/balance.gd` (§ Épreuves et constantes coop), `events.gd`, `director/director.gd`, `director/wave_indicator.gd`, `enemies/enemy.gd` (`walk_target`), `stage/secret_lever.gd`, `secret_beacon.gd`, `telemetry/run_log.gd`, `testmode/test_panel.gd`, `testmode/test_loop_tools.gd`, `tests/epreuve_test.gd`, `tools/gen_maps.py`, `data/floors.json`, les 8 JSON de `game/data/maps/`.
> Contraintes : **gel des boss** (aucun boss, mini-boss ni sort de boss nouveau ; les mini-boss du plan de run apparaissent à la fin de l'épreuve, comme dans le prototype) ; télégraphes ≥ 0,8 s ; aucune mort instantanée ; aucun piège de terrain ; trois plateformes (joystick + « interagir », sorts 2-4 en ciblage automatique sur mobile) ; aucun nom ni design repris de Risk of Rain ou de Vampire Survivors ; toute valeur passe par `Balance` ou un JSON de `game/data/`.
> Ce document ne modifie aucun fichier de `game/`. Les coordonnées de carte sont en **u** (1 u = 64 px), repère carte (`coord_u`, origine en haut à gauche, comme `escort_path` et `ritual` des Terrasses) ; une case de grille = 2 u, centre de la case (cx, cy) = (2 cx + 1, 2 cy + 1).
> **Forge et Noyaux d'orage** : aucun `docs/Design_Forge.md` et aucune occurrence de « Noyau d'orage » dans le dépôt au 07/11/2026. Les récompenses ci-dessous restent en or et en rubis (cosmétique) ; si une Forge arrive, la note « parfait » est l'accroche naturelle d'un Noyau (§6.4).

---

## 0. Résumé

| Étage | Biome (`floors.json`) | Cartes A / B | Épreuve 1 | Épreuve 2 | État |
|---|---|---|---|---|---|
| 1 | `terrasses` | `terrasses_noyees` / `terrasses_rizieres_hautes` | **Escorte** (barque de noria) | **Rituel** (vannes de l'écluse) | prototype livré (code, données, tests) ; sprites Codex manquants |
| 2 | `foret` (Le Gouffre luisant) | `foret_brume` / `foret_mangrove_lanternes` | **Poursuite** (follet de mycélium entre 6 bornes) | **Veine** (disque de lumière sur la rivière d'infiltration) | à écrire |
| 3 | `cite` | `cite_rouille` / `cite_fonderie_canal` | **Tenue** (cloche d'alerte à défendre 40 s) | **Rituel** (soupapes de la pompe : réutilisation) | Tenue à écrire, Rituel = rhabillage |
| 4 | `cryptes` | `cryptes_noyees` / `cryptes_ossuaire_pluies` | **Veine** (eau noire) | **Poursuite** (éclat de cristal) | réutilisation des verbes du Gouffre, tracés propres |
| 5 | `source` | `la_source` | aucune | aucune | **non** (§5) |

Cinq verbes, deux par étage, jamais la même paire deux étages de suite ; un run voit 8 épreuves. Les deux épreuves d'un étage sont disponibles dès l'arrivée (ordre libre), remplacent les deux petits piliers (`rules["small_pillars"] = 0`, déjà fait par le prototype), et le gros pilier reste verrouillé tant que les deux mini-boss ne sont pas morts. Les 8 petits coffres et 2 grands sont tirés à ≤ 8 u des tracés (3 + 3), autour de l'arène du boss (3) et au départ (1) ; les 4 capsules : 1 au départ, 3 sur les tracés. Tout cela existe déjà dans `stage_manager.gd` pour les Terrasses : le travail est de **généraliser par biome et par verbe**, d'écrire **trois verbes** (Poursuite, Veine, Tenue), de **poser les tracés** sur 6 cartes, et de commander les assets.

Fréquence par run : **8 épreuves, à chaque run** (remplacement complet des petits piliers aux étages 1-4, et aux étages 6-9 du mode sans fin, §5). Deux molettes de repli sans code : `data/epreuves.json` `"enabled": false` sur un biome (il retrouve ses piliers), et `Balance.EPREUVES_PER_STAGE` 2 → 1 (une épreuve + un petit pilier classique).

---

## 1. Ce que le prototype fournit déjà (réutilisé tel quel)

| Élément | Fichier | Réutilisation |
|---|---|---|
| Classe de base `Epreuve extends Pillar` : états `ready / active / done`, `activate()`, `tick()`, `_resolve(grade)`, délai de sécurité `EPREUVE_BACKSTOP_S`, or versé par `PickupManager.drop` (ou `CoopRules.credit_party_gold` sans PickupManager), `_spawn_mini()` (mini-boss du plan via `Director.spawn_boss(&"mini", …)` + meta `next_boss_id` / `next_mini_id`), zone `&"epreuve"` qui suit `global_position`, `zone_gold_mult()` statique, `to_dict() / from_dict()` (reprise en pleine épreuve ou mini-boss à relancer), `EpreuveOverlay` sur la couche des télégraphes (`AmbianceManager.telegraph_layer`), `forced_grade` (mode test) | `scripts/stage/epreuve.gd` | **inchangée**, sauf : libellés et skins lus dans `data/epreuves.json` (§7.2), `EPREUVE_SHARED_VERBS` à la place du test `verb == &"rituel"` dans `_resolve`, et une méthode statique `geometry_dist(verb, geom, p)` (§7.3) |
| Escorte : polyligne, corde `ESCORT_LEASH_U`, PV `escort_hp`, arrêt 5 s, dégâts de contact échantillonnés toutes les 0,25 s (`_contact_dps`), placeholder `Polygon2D` | `epreuve_escort.gd` | inchangée ; sprite Codex à brancher (§9) |
| Rituel : 3 relais `EpreuveRelay extends SecretLever` (maintien `RITUAL_HOLD_S`, sprites `lever_<skin>_{off,on}` déjà livrés pour `terraces`, `fog_forest`, `rust_city`, `crypts`), cœur qui pulse `[12, 9, 7]` s, télégraphe 1,0 s puis onde, un coup par joueur et par onde, coop | `epreuve_ritual.gd`, `epreuve_relay.gd` | inchangée ; la Cité la réutilise avec `biome = &"rust_city"` sur les relais et les libellés « Réveiller la pompe » / « Fermer la soupape » |
| Étage : `epreuves_on`, `_epreuves_applicable()`, `_load_epreuve_geom()`, `_epreuve_entries()`, `_make_epreuve()`, `_pillar_layout_pos()`, `_dist_to_escort()`, `_dist_to_ritual()`, `_big_clear_of_epreuves()`, `_epreuve_chest_order()`, `_epreuve_capsule_order()`, sauvegarde (`le["epreuve"]`) | `stage_manager.gd` | à **généraliser** (§7.3) : géométrie par verbe, deux épreuves tirées du biome, distances par épreuve |
| Constantes et formules : `EPREUVE_GOLD_P`, `EPREUVE_ZONE_GOLD_MULT`, `EPREUVE_TARGET_S` (déjà 5 verbes), `EPREUVE_GOOD_MULT`, `EPREUVE_BACKSTOP_S`, `EPREUVE_ZONE_RADIUS_U`, `EPREUVE_CHEST_*`, `EPREUVE_BIG_AVOID_U`, `ESCORT_*`, `RITUAL_*`, `epreuve_grade()`, `epreuve_gold()`, `escort_hp()`, `ritual_pulse_s()`, `ritual_ring_damage()`, `epreuve_target_party_mult()`, `EPREUVE_TARGET_PLAYER_SLOPE` | `balance.gd` §1120-1190, §1220, §1303 | inchangées ; constantes nouvelles §8 |
| Signaux `Events.epreuve_started(kind)`, `epreuve_finished(kind, grade, elapsed_s, gold)` | `events.gd` | inchangés |
| Journal : `epreuves_on`, `epreuves [{kind, t0, t1, grade, s, gold}]`, `epreuve_s`, `post_boss_s` | `run_log.gd` | + champs par verbe (§7.6) |
| Mode test : boutons « Épreuve : escorte / rituel », notes forcées, « Terminer l'épreuve en cours », retrait | `test_panel.gd` `_build_loop`, `test_loop_tools.gd` `spawn_epreuve / finish_epreuves / clear_epreuves` | + un bouton par nouveau verbe |
| Données : `escort_path`, `ritual {heart, relays}` dans les 2 JSON des Terrasses, dict `EPREUVES` de `tools/gen_maps.py` recopié dans les JSON | `data/maps/terrasses_*.json`, `tools/gen_maps.py` | même mécanisme pour 6 cartes de plus (§4) |
| Test headless : drapeau désactivé = jeu inchangé, disposition sur les 2 cartes, balayage de graines, mécaniques, flux, sauvegarde, mode test | `tests/epreuve_test.gd` | à rendre générique sur les 8 cartes (§10) |

---

## 2. Règles communes à toutes les épreuves

1. **Déclencheur** : un objet de carte (barque, cœur d'écluse, borne-autel, source de la veine, cloche) avec le libellé d'interaction du biome ; « interagir » seulement, jamais au contact (contrat `interactable`, comme le téléporteur). L'épreuve est un `Pillar` de `Kind.SMALL` : la minimap, le déverrouillage du gros pilier, les rubis et le journal la voient comme un petit pilier.
2. **Durée** : 30-45 s visées, délai de sécurité `EPREUVE_BACKSTOP_S` 75 s : passé ce délai l'épreuve se clôt en « fait » et le mini-boss apparaît quand même. **Jamais bloqué.**
3. **Note** : `parfait` (durée ≤ `EPREUVE_TARGET_S[verbe]` et aucune faute, `clean`), `bien` (≤ seuil × 1,5 ou une faute), `fait` (au-delà, ou délai de sécurité). La Tenue, à durée fixe, se note aux PV de la structure (§3.5). La note est **lisible sans texte** : la couleur de l'onde finale et le son `epreuve_grade_<note>` suffisent ; le libellé (« Parfait », « Bien », « Fait ») s'affiche 2 s au-dessus de l'objet.
4. **Récompense** : or de la note (`EPREUVE_GOLD_P` × P, en pièces au sol, multiplicateur d'or du joueur, coop : même montant à chaque joueur × `COOP_GOLD_MULT[n]`), puis le mini-boss (prime 0,3 P et son comportement inchangés). L'or des kills dans la zone d'une épreuve en cours est × `EPREUVE_ZONE_GOLD_MULT` 0,4 (E5) : l'or vient de l'adresse, pas du farm. Option rubis cosmétiques §6.4.
5. **Échec** : il n'existe pas d'échec bloquant. Les fautes (barque immobilisée, onde reçue, borne ratée, geyser reçu, cloche éteinte) retirent le « parfait » ou abaissent la note ; les dégâts reçus viennent toujours d'un télégraphe ≥ 0,8 s, coefficient d'un coup de mini-boss, plafond de coup du joueur inchangé.
6. **Zone de monstres** `ZONE_SPAWN_MULT[&"epreuve"]` 1,5, rayon `EPREUVE_ZONE_RADIUS_U` 7 u (Rituel : 15 u, Tenue : 12 u), centrée sur `global_position` de l'épreuve, qui **bouge** avec la barque, la lumière ou le disque. Les monstres sont ceux du director : aucune créature nouvelle.
7. **Coop 1-4** (`docs/multi/Design_Coop.md` §1.3) : Escorte, la corde tient si **au moins un** joueur est à ≤ 6 u ; Rituel se partage (relais en parallèle), seuil « parfait » × `epreuve_target_party_mult(n)` ; Poursuite : n'importe qui atteint la borne, seuil « parfait » non multiplié (E5 : Poursuite retirée de `EPREUVE_SHARED_VERBS`) ; Veine, charge au prorata des vivants dans le disque avec le plancher `COOP_CHARGE_FLOOR` (même règle que le gros pilier) ; Tenue, PV de la cloche × (1 + `BOSS_HP_PLAYER_SLOPE[&"mini"]` (n − 1)) puisque les paquets suivent les crédits. Un joueur mort est spectateur, rien à faire de plus.
8. **Mobile** : chaque verbe se joue au joystick (suivre, atteindre, rester dedans, se placer) plus « interagir » (maintien : relais). Flèche de bord d'écran sur l'objet mobile (`WaveIndicator` réutilisé avec l'objet comme centre, ou le système de repères hors écran du HUD). Icône de minimap par verbe. Perf : un seul objet animé par épreuve, télégraphes sur la couche non éclairée, paquets de la Tenue dans le plafond de vivants du director (`spawn_enemy` renvoie `null` quand le pool est vide : pas de dépassement).
9. **Iso 2:1** : les tracés sont alignés sur les axes de la carte (donc en diagonale à l'écran, comme les murs) ; un disque de 6 u = 384 px = 36 % de la hauteur d'écran ; bornes à 9-17 u (576-1 088 px) : au plus deux visibles à la fois, la flèche fait le reste ; tout objet d'épreuve a une emprise ≥ 1,5 u et un accent émissif du biome.
10. **Sauvegarde** : `to_dict() / from_dict()` du prototype ; chaque verbe ajoute ses champs via `_extra_dict() / _extra_restore()`. Pas de montée de `RunSave.VERSION` (clés nouvelles tolérées, le prototype sauvait déjà `le["epreuve"]`). Une run sauvegardée avec épreuves garde ses épreuves même si le drapeau est baissé ensuite (`_epreuves_applicable` suit la disposition sauvée).

---

## 3. Les cinq verbes

### 3.1 Escorte (Terrasses) : livré, rien à changer
Voir `epreuve_escort.gd`, `Balance.ESCORT_*`, `docs/Boucle_Etage_Refonte.md` §1.1. Seul ajout : brancher le sprite Codex de la barque (§9) à la place du `Polygon2D` (nœud `Barque`) ; 8 directions depuis `_heading_at()`.

### 3.2 Rituel (Terrasses, Cité) : livré, rhabillage pour la Cité
`EpreuveRitual.make(heart, relays)` inchangé. Pour la Cité : `relay.biome = &"rust_city"` (sprites `lever_rust_city_{off,on}` déjà livrés), libellés de `data/epreuves.json` (« Réveiller la pompe », « Fermer la soupape »). Le cœur reste le sprite du petit pilier (`pillar_small_*`). Cadence `[12, 9, 7]` s, onde coef 1,0, cible 35 s : inchangés.

### 3.3 Poursuite (Gouffre, Cryptes) : nouveau, `scripts/stage/epreuve_chase.gd`
- **Objets** : `CHASE_POSTS` 6 bornes (`chase_posts` du JSON : champignons-lanternes de mycélium au Gouffre, cristaux éteints aux Cryptes), espacées de 9-17 u le long d'un itinéraire ; la borne 0 est l'autel de départ (sprite `_altar`).
- **Règle** : « interagir » sur la borne 0 (« Réveiller le follet » / « Éveiller l'éclat ») : une lumière se pose dessus. Toutes les `CHASE_JUMP_S` 8 s elle **saute** vers une borne à `[CHASE_JUMP_MIN_U, CHASE_JUMP_MAX_U]` = [9, 17] u de la borne courante, jamais la borne qu'elle vient de quitter si un autre choix existe (sans candidat : la plus proche). Elle **vacille** `CHASE_WARN_S` 1,5 s avant de sauter (lisibilité). Un joueur vivant à ≤ `CHASE_REACH_U` 2 u de la borne allumée **avant le saut** = 1 point (la borne reste allumée en « done », son `_e` fixe). Borne ratée : la lumière saute quand même, `misses += 1`, `clean = false`. `CHASE_POINTS` 5 points → la lumière se fixe sur la borne courante, le mini-boss **sort de terre** dessous (`_spawn_mini()` à `global_position + BOSS_OFFSET`).
- **Position de l'épreuve** : `global_position` = borne allumée (l'`Epreuve` se déplace ; `uses_sprite = false`, les bornes sont des enfants `EpreuveChasePost` fixes). La zone ×1,5 et la flèche hors écran suivent donc la lumière.
- **Durée** : minimum ≈ 5 × 8 s = 40 s moins l'avance sur la dernière borne ; `EPREUVE_TARGET_S[&"poursuite"]` 40 s (E5, était 45 s ; une borne ratée = +8 s) ; « bien » jusqu'à 60 s ; 3 bornes ratées = « bien », 4 = « fait » ; délai de sécurité 75 s.
- **Coop** : n'importe quel joueur compte ; seuil « parfait » non multiplié (E5 : Poursuite retirée de `EPREUVE_SHARED_VERBS`).
- **Habileté** : itinéraire et vitesse sous pression (4 u/s pour 9-17 u = 2,3-4,3 s de course par fenêtre de 8 s, monstres compris) ; renoncer à une borne trop loin pour prendre la suivante.
- **Placeholder** : borne = `Polygon2D` losange 1 u, teinte du biome ; lumière = `draw_circle` 0,6 u + `Line2D` de traînée sur l'`EpreuveOverlay` ; vacillement = alpha qui clignote à 6 Hz.
- **Sauvegarde** : `{"lit": i, "prev": j, "points": k, "misses": m, "jump_left": s, "done_posts": [i…]}`.
- **Données** : `"chase_posts": [[u, u] × 6]` (la première = autel). Validation (`epreuve_test`) : 6 points praticables, chaque borne a ≥ 1 voisine à 9-17 u, ≥ 4 u des plaques et gardiens de secret (`secrets[].plates_u`, `guardians_u`), ≥ 6 u d'au moins deux candidats de gros pilier.

### 3.4 Veine (Gouffre, Cryptes) : nouveau, `scripts/stage/epreuve_vein.gd`
- **Objets** : une « source » (prop interactif, `vein_path[0]`), un **disque** de lumière de rayon `VEIN_RADIUS_U` 6 u qui glisse à `VEIN_SPEED_U` 1,5 u/s le long de `vein_path` (polyligne, `vein_closed` vrai = boucle parcourue en continu ; faux = aller-retour), longueur `VEIN_LOOP_MIN_U`-`VEIN_LOOP_MAX_U` = 40-70 u ; des **geysers** (Gouffre : vapeur et spores ; Cryptes : éclaboussure d'eau noire et sel).
- **Règle** : « Suivre la veine » à la source : le disque part. La **charge** (`VEIN_CHARGE_S` 30 s) n'avance que si au moins un joueur vivant est **dans** le disque (`CoopRules.any_within(global_position, VEIN_RADIUS_U × 64)`), au prorata des vivants dedans avec plancher `COOP_CHARGE_FLOOR` ; elle **ne retombe jamais** (comme `SecretBeacon`). Toutes les `VEIN_GEYSER_EVERY_S` 6 s, un geyser est annoncé **sous un joueur vivant du disque** (`VEIN_GEYSER_ON_PLAYER`, tour à tour, en sautant ceux qui ont un coffre ouvert), décalé de `VEIN_GEYSER_AHEAD_U` 0,75 u dans le sens d'avance ; sans joueur éligible, `VEIN_GEYSER_FALLBACK_AHEAD_U` 3 u devant le centre (ancien placement) : cercle de `VEIN_GEYSER_RADIUS_U` 2 u, télégraphe `VEIN_GEYSER_TELEGRAPH_S` 1,2 s (E5, était 1,0 s), puis éruption 0,4 s : un joueur dedans reçoit un coup de mini-boss × `VEIN_GEYSER_COEF` 1,0 (une fois par geyser et par joueur), `hits += 1`, `clean = false`. Le disque passe sur le geyser : il faut **sortir puis rentrer**. Charge pleine → le mini-boss **émerge au centre du disque**, le disque s'arrête.
- **Position** : `global_position` = centre du disque (l'`Epreuve` se déplace, `uses_sprite = false` ; la source est un enfant fixe `EpreuveVeinSource`).
- **Durée** : 30 s de charge si l'on reste dedans ; chaque geyser coûte ≈ 2-3 s de sortie ; `EPREUVE_TARGET_S[&"veine"]` 40 s ; « bien » 60 s ; délai de sécurité 75 s.
- **Habileté** : sortir et rentrer au bon moment ; ne pas se laisser distancer en combattant (1,5 u/s contre 4 u/s : rattrapable, mais le disque ne vous attend pas).
- **Placeholder** : disque = `draw_circle` rempli alpha 0,18 + anneau 0,3 u sur l'`EpreuveOverlay` (teinte améthyste `#C27BFF` au Gouffre, cristal `#BFF4FF` aux Cryptes, cf. `Design_Etage2_Grotte.md` §2 et `Design_Etages.md` §3) ; geyser = cercle télégraphe rouge puis flash blanc ; source = `Polygon2D` 1 u.
- **Sauvegarde** : `{"dist": s_px, "dir": ±1, "charge": s, "hits": n, "geyser_left": s}`.
- **Données** : `"vein_path": [[u, u] × 4-8]`, `"vein_closed": true|false`. Validation : tous les points et segments échantillonnés tous les 0,5 u praticables (`.` ou `,` ; `,` toléré, `~` interdit), longueur 40-70 u, ≥ 10 u de deux candidats de gros pilier au moins.

### 3.5 Tenue (Cité) : nouveau, `scripts/stage/epreuve_hold.gd`
- **Objets** : la **cloche d'alerte** (prop 2,5 u, 3 états : `off`, `ringing`, `dim`), PV = `HOLD_HP_MINI_SHARE` 0,5 × PV d'un mini-boss (`Balance.hold_hp(D, stage, n_alive)`), posée sur `hold.pos` ; trois **côtés** `hold.sides` (vecteurs unitaires en repère carte) ouverts sur ≥ 10 u de sol.
- **Règle** : « Sonner la cloche » : 40 s (`HOLD_DURATION_S`) commencent. Toutes les `HOLD_WAVE_EVERY_S` 8 s (t = 0, 8, 16, 24, 32 : 5 paquets), un côté est **annoncé** `HOLD_ANNOUNCE_S` 2,0 s à l'avance (chevrons au sol à 4 u de la cloche vers ce côté, sur l'`EpreuveOverlay`, + son `hold_side`), puis `HOLD_PACKET` 4 monstres apparaissent à `HOLD_SPAWN_DIST_U` 10 u dans cette direction (`Director.spawn_enemy(tier, pos)` avec `_pick_tier(D)`, position repliée sur la case praticable la plus proche ; `null` au plafond = paquet plus petit, jamais plus). Les côtés tournent (ordre tiré au lancement, chaque côté au moins une fois). Chaque monstre du paquet reçoit `walk_target = cloche` (champ **déjà existant** d'`Enemy`, utilisé par les adds de raid : marche directe vers la cible) ; un joueur vivant à ≤ `HOLD_LURE_BREAK_U` 3 u d'un monstre leurré lui retire son `walk_target` (il redevient un monstre ordinaire) : **intercepter** avant le contact. Au contact (`HOLD_HIT_RADIUS_U` 1,3 u, échantillon 0,25 s, même code que la barque) la cloche perd des PV. À 0 PV elle **s'éteint** (`dim`) : elle ne casse pas, l'épreuve continue, mais la note sera « fait ». À 40 s le mini-boss **arrive par le dernier côté annoncé** (spawn à 10 u, il marche).
- **Note** (durée fixe, donc aux PV) : `Balance.epreuve_grade_hold(hp_ratio)` : `parfait` si PV ≥ `HOLD_PERFECT_HP_PCT` 0,7, `bien` si > 0, `fait` si éteinte. `EPREUVE_TARGET_S[&"tenue"]` reste à 40 s pour le journal et le mode test.
- **Coop** : PV de la cloche × (1 + 0,3 (n_alive − 1)) ; `HOLD_PACKET` inchangé (les crédits du director scalent déjà le reste).
- **Habileté** : se placer sur le côté annoncé, intercepter ; c'est le verbe le plus proche d'un test de puissance (un build faible perd la cloche) : il **note sans punir** (le mini-boss arrive de toute façon, l'or « fait » est versé) et reste réservé à la Cité.
- **Placeholder** : cloche = `Polygon2D` trapèze 1,5 × 2,5 u + barre de PV `_draw` ; chevrons = 3 triangles.
- **Sauvegarde** : `{"t": s, "hp": pv, "order": [côtés], "next_i": k, "dim": bool, "last_side": [x, y]}` ; les monstres leurrés ne sont pas sauvés (le director les recrée au besoin : à la reprise, le paquet suivant repart normalement).
- **Données** : `"hold": {"pos": [u, u], "sides": [[dx, dy] × 3]}`. Validation : position praticable, pour chaque côté les points à 6 u et 10 u praticables, ≥ 12 u de deux candidats de gros pilier au moins.

---

## 4. Placement par carte (proposition initiale, validée par les tests)

Les coordonnées ci-dessous ont été vérifiées sur les grilles des JSON (praticabilité, distances, dégagement du gros pilier) ; `epreuve_test` les revérifie en jeu (`StageManager.is_reachable_local`), et l'agent ajuste de ± 1 case si un contrôle échoue. Les deux cartes des Terrasses gardent leurs clés actuelles.

| Carte | Verbe | Données (`tools/gen_maps.py` dict `EPREUVES`, recopiées dans `data/maps/<id>.json`) | Lecture |
|---|---|---|---|
| `foret_brume` (Gouffre A, 76 × 68 u, départ (43, 35)) | Poursuite | `chase_posts = [[39, 25], [29, 17], [41, 11], [53, 15], [63, 21], [53, 27]]` | grande salle nord-est sous le puits ; autel à 11 u du départ ; anneau de 6 bornes à 12-14 u |
| | Veine | `vein_path = [[11, 21], [21, 21], [21, 31], [11, 31]]`, `vein_closed = true` | boucle de 40 u autour des gours de l'ouest (le bassin `~` 13-19 × 23-27 est à l'intérieur : le disque passe sur l'eau, le joueur longe la rive) |
| | Gros pilier | candidats restants : (31, 27) à 10 u de la veine (seuil veine 10 u), (31, 53) ; (57, 23) exclu par la borne (53, 27) | |
| `foret_mangrove_lanternes` (Gouffre B, 84 × 64 u, départ (73, 49)) | Veine | `vein_path = [[51, 23], [63, 23], [63, 37], [51, 37]]`, `vein_closed = true` | boucle de 52 u sur l'île entre les deux bras de la rivière ; le rocher (53, 29) est à l'intérieur |
| | Poursuite | `chase_posts = [[67, 45], [55, 51], [41, 45], [29, 49], [43, 55], [75, 33]]` | galerie sud, de l'arrivée vers l'ouest ; la borne (75, 33) n'a qu'une voisine (acceptable) |
| | Gros pilier | (31, 23), (15, 39) ; (53, 35) exclu (dans la boucle) | |
| `cite_rouille` (Cité A, 60 × 92 u, départ (31, 51)) | Tenue | `hold = {"pos": [45, 61], "sides": [[0, -1], [1, 0], [-1, 0]]}` | cour sud-est, 10 u de sol vers le nord, l'est et l'ouest (le canal à 16 u) |
| | Rituel | `ritual = {"heart": [17, 27], "relays": [[17, 15], [11, 37], [27, 35]]}` | quartier nord-ouest, relais à 12,0 / 11,7 / 12,8 u |
| | Gros pilier | (45, 33), (29, 79) ; (15, 33) exclu (5,7 u du cœur) | |
| `cite_fonderie_canal` (Cité B, 76 × 76 u, départ (19, 61)) | Tenue | `hold = {"pos": [39, 35], "sides": [[0, 1], [1, 0], [-1, 0]]}` | cour centrale de la fonderie ; côté nord fermé par le bloc (8 u), les trois autres ouverts |
| | Rituel | `ritual = {"heart": [49, 17], "relays": [[61, 21], [59, 11], [39, 23]]}` | quai nord ; relais à 12,6 / 11,7 / 11,7 u |
| | Gros pilier | (19, 19), (57, 57) ; (39, 39) exclu (4 u de la cloche) | |
| `cryptes_noyees` (Cryptes A, 84 × 72 u, départ (37, 35)) | Veine | `vein_path = [[23, 53], [43, 53], [43, 63], [23, 63]]`, `vein_closed = true` | boucle de 60 u autour du bassin sud (4 échantillons en eau peu profonde `,` : tolérés) |
| | Poursuite | `chase_posts = [[37, 15], [47, 19], [57, 11], [65, 17], [65, 27], [55, 31]]` | rive nord-est du lac ; autel (37, 15) à 20 u du départ |
| | Gros pilier | les trois candidats restent : (37, 27), (11, 39), (63, 39) | |
| `cryptes_ossuaire_pluies` (Cryptes B, 56 × 84 u, départ (15, 75)) | Veine | `vein_path = [[15, 67], [17, 57], [17, 45], [15, 35], [11, 27], [11, 15]]`, `vein_closed = false` | galerie ouest en **aller-retour** (53 u), source au sud près du départ ; la plaque de secret (15, 51) est à 2 u du tracé : la déplacer à (7, 57) dans `gen_maps.py` (`secrets[0].plates_u[0]`) ou accepter l'appui involontaire (une plaque sur deux : sans effet) |
| | Poursuite | `chase_posts = [[47, 53], [41, 41], [41, 29], [43, 17], [29, 15], [29, 25]]` | galerie est puis nef nord ; autel (47, 53) |
| | Gros pilier | (27, 31), (27, 53) ; (37, 43) exclu (4,5 u d'une borne) | |

Règles de placement pour toute retouche : objet d'épreuve ≥ 8 u du départ (sauf la source de la veine et l'autel : ≥ 6 u), ≥ 4 u des `plates_u` / `guardians_u` / cases `:` des secrets, ≥ 3 u d'un mur pour les bornes et la cloche, geysers jamais hors du tracé ; **au moins deux** candidats de gros pilier doivent rester dégagés (sinon le même étage a toujours la même arène).

---

## 5. Étage 5 et mode sans fin

- **La Source : aucune épreuve** (confirmé). Raisons : `draw_rules_override.small_pillars = 0` (pas de petit pilier, pas de mini-boss à invoquer, donc rien à ponctuer) ; l'arène fait 48 × 48 u, un écran et demi, le combat se lit en entier et le rythme voulu est « 60-90 s de libre puis le boss final » (`Design_Etages.md` §4) ; la run vise 18-20 min et une épreuve y ajouterait 40-75 s avant le climax ; le gel des boss interdit de toucher au Semeur de pluie. `_epreuves_applicable` garde `not is_final_floor`.
- **Sans fin (étages 6-9)** : **oui**, derrière `Balance.EPREUVE_IN_ENDLESS` true : retirer `not endless` de `_epreuves_applicable` ; le biome vient du plan de run (`floors.json`, étage n → ((n − 1) % 5) + 1), les verbes et tracés suivent la carte ; les cibles de durée ne dépendent pas de D, les PV de la barque et de la cloche suivent `boss_hp(&"mini", D, stage)`. Étage 10 (Source) : aucune.

---

## 6. Économie et récompenses

### 6.1 Or par étage (bande 8-10,5 P de `Ateliers_Chiffres.md` §1)
Mesuré sans épreuves (modèle champ moyen, Moyen) : étage 1 : 8,1 P ; 2 : 9,3 P ; 3 : 9,0 P ; 4 : 9,1 P. Un petit pilier rapporte ≈ 1,0 P (prime 0,3 + kills en zone 0,7). Une épreuve rapporte la note (mix 25 % parfait / 55 % bien / 20 % fait = 1,03 P) + prime 0,3 P + kills en zone × 0,5 (≈ 0,35-0,55 P selon l'étage) ≈ **1,7-1,9 P**, soit +0,7-0,9 P par épreuve, **+1,4-1,8 P par étage** : étage 1 → 9,5-9,9 P (dans la bande, déjà vérifié par `epreuve_test._check_balance`), étages 2-4 → **10,4-10,9 P : au bord haut**. Les épreuves durent aussi 20-40 s de plus que les piliers (D monte, l'or des kills suit).

Levier si `economy_test` (étendu aux étages 1-4, drapeau activé) sort de la bande : `EPREUVE_GOLD_P` `{parfait: 1.5, bien: 0.9, fait: 0.5}` (bien 1,0 → 0,9 = −0,2 P par étage), puis `EPREUVE_ZONE_GOLD_MULT` 0,5 → 0,4. **Appliqué le 07/11/2026 (lot E5)** : `EPREUVE_GOLD_P` `{parfait: 0.8, bien: 0.5, fait: 0.2}` et `EPREUVE_ZONE_GOLD_MULT` 0,4 (valeurs réelles de `balance.gd`, §15) ; les chiffres du présent §6.1 sont l'estimation d'avant E5. Ne pas toucher aux prix des coffres ni aux capsules (10 → 4 déjà comptées). À confirmer par systems-designer (`/balance-check economie`) une fois les quatre biomes branchés.

### 6.2 Coffres
Aucun coffre nouveau. La répartition 3 / 3 / 3 / 1 (tracé 1, tracé 2, arène, départ) remplace le tour de carte ; le coffre de boss et le légendaire (25 %) sont inchangés. Le marché suit l'action : c'est la récompense structurelle de la refonte, pas un bonus.

### 6.3 Rubis (cosmétique, décision du 01/11/2026)
Option : `Balance.EPREUVE_RUBIES_PARFAIT` 1 rubis par note « parfait », plafond 8 par run (`RunState`, versés avec `run_rubies` à la fin de la run, pas en mode test). 1 rubis ≈ 500 or du barème actuel : négligeable sur l'économie, donne une raison de viser « parfait » au-delà de +0,5 P. **Valeur par défaut proposée : 0** jusqu'à l'avis du joueur (§14 q3).

### 6.4 Noyaux d'orage / Forge
Hors périmètre : pas de Forge dans le dépôt. Si elle arrive : 1 Noyau par « parfait » (mêmes garde-fous que les rubis) serait l'accroche ; prévoir le champ `Events.epreuve_finished(kind, grade, …)` déjà émis comme point de branchement.

---

## 7. Code : ce qui change, ce qui s'ajoute

### 7.1 Fichiers nouveaux
| Fichier | Contenu |
|---|---|
| `game/data/epreuves.json` | verbes par biome, libellés, skin des relais, interrupteur par biome (§7.2) |
| `game/scripts/stage/epreuve_chase.gd` (`EpreuveChase`) + `epreuve_chase_post.gd` (`EpreuveChasePost extends Node2D`, groupe `interactable` pour la borne 0 seulement) | §3.3 |
| `game/scripts/stage/epreuve_vein.gd` (`EpreuveVein`) + `epreuve_vein_source.gd` (`EpreuveVeinSource`, interactable) | §3.4 |
| `game/scripts/stage/epreuve_hold.gd` (`EpreuveHold`) + `epreuve_hold_bell.gd` (`EpreuveHoldBell`, interactable, PV, 3 états) | §3.5 |
| `game/scripts/stage/epreuve_geom.gd` (`EpreuveGeom`, statique) | chargement et validation des clés JSON par verbe, conversion u → repère local (`map.from_map(Vector2(u) * UNIT - half)`, comme `_load_epreuve_geom`), `dist(verb, geom, p)` |
| `game/tests/epreuve_chase_test.{gd,tscn}`, `epreuve_vein_test.{gd,tscn}`, `epreuve_hold_test.{gd,tscn}` | §10 |

### 7.2 `data/epreuves.json`
```json
{
 "_doc": "Épreuves par biome (docs/Design_Epreuves.md). verbs = les deux épreuves qui remplacent les petits piliers (ordre = épreuve 1, 2 ; le mini-boss minis[i] du plan va à l'épreuve i). enabled=false : le biome garde ses piliers. lever_skin = dossier des sprites lever_<skin> (relais du Rituel). labels : libellés d'interaction (<= 24 caractères).",
 "names": {"escorte": "Escorte", "rituel": "Rituel", "poursuite": "Poursuite", "veine": "Veine", "tenue": "Tenue"},
 "biomes": {
  "terrasses": {"enabled": true, "verbs": ["escorte", "rituel"], "lever_skin": "terraces",
   "labels": {"escorte": {"start": "Lancer la barque"}, "rituel": {"start": "Réveiller l'écluse", "relay": "Fermer la vanne"}}},
  "foret": {"enabled": true, "verbs": ["poursuite", "veine"], "lever_skin": "fog_forest",
   "labels": {"poursuite": {"start": "Réveiller le follet"}, "veine": {"start": "Suivre la veine"}}},
  "cite": {"enabled": true, "verbs": ["tenue", "rituel"], "lever_skin": "rust_city",
   "labels": {"tenue": {"start": "Sonner la cloche"}, "rituel": {"start": "Réveiller la pompe", "relay": "Fermer la soupape"}}},
  "cryptes": {"enabled": true, "verbs": ["veine", "poursuite"], "lever_skin": "crypts",
   "labels": {"veine": {"start": "Suivre l'eau noire"}, "poursuite": {"start": "Éveiller l'éclat"}}},
  "source": {"enabled": false, "verbs": []}
 }
}
```
Clés de carte par verbe : `escort_path`, `ritual {heart, relays}` (existantes), `chase_posts`, `vein_path` + `vein_closed`, `hold {pos, sides}` (§3). Une carte dont une clé manque ou est invalide → `epreuves_on = false` pour cet étage (étage classique, comme aujourd'hui), avec `push_warning` : jamais de plantage.

### 7.3 `stage_manager.gd` : généralisation (fonctions à modifier)
- `_epreuves_applicable(layout)` : `Balance.epreuves_enabled() and map_scene == null and not is_final_floor and (not endless or Balance.EPREUVE_IN_ENDLESS) and EpreuveData.enabled(biome)` où `biome = String(map.get_meta(&"biome", entry["biome"]))` ; supprimer `Balance.EPREUVE_STAGE`.
- `_load_epreuve_geom()` → `EpreuveGeom.load(map, map_id, verbs)` : renvoie `{verb: geom}` pour les `EPREUVES_PER_STAGE` premiers verbes du biome ; `{}` si un verbe n'a pas sa clé.
- `_epreuve_entries()` : `[{"kind": SMALL, "epreuve": verbs[0]}, {"kind": SMALL, "epreuve": verbs[1]}]` (ou un seul si `EPREUVES_PER_STAGE` = 1, et alors `rules["small_pillars"] = 1`).
- `_make_epreuve(verb)` : `match` sur les 5 verbes (`EpreuveEscort.make`, `EpreuveRitual.make(heart, relays, skin)`, `EpreuveChase.make(posts)`, `EpreuveVein.make(path, closed)`, `EpreuveHold.make(pos, sides)`).
- `_pillar_layout_pos(p)` : point d'ancrage par verbe (`EpreuveGeom.anchor(verb, geom)` : `escort[0]`, `heart`, `posts[0]`, `path[0]`, `pos`).
- `_dist_to_escort / _dist_to_ritual` → `_dist_to_epreuve(i, p)` = `EpreuveGeom.dist(verb_i, geom_i, p)` ; `_big_clear_of_epreuves(p)` : seuil par verbe `Balance.EPREUVE_BIG_AVOID_U[verb]`.
- `_epreuve_chest_order` : groupes `&"depart"`, `&"arene"`, `&"epreuve_1"`, `&"epreuve_0"` avec `EPREUVE_CHEST_SPLIT = {depart: 1, arene: 3, epreuve: 3}` (3 par épreuve) ; `_epreuve_capsule_order` : `_dist_to_epreuve` sur les deux.
- `to_dict()` : `le["epreuve"] = verb` déjà fait ; `from_dict` : `_make_epreuve(verb)` lit la géométrie de la carte courante (comme aujourd'hui).
- Mini-boss : inchangé (`minis[small_i]`).

### 7.4 `epreuve.gd` (base)
- `static var data: Dictionary` chargé une fois depuis `data/epreuves.json` (`EpreuveData` : `verbs(biome)`, `enabled(biome)`, `label(biome, verb, key)`, `lever_skin(biome)`).
- `interact_label()` lit le libellé du biome (`biome` fixé par `StageManager` avant `add_child`).
- `_resolve` : `if verb in Balance.EPREUVE_SHARED_VERBS` pour le multiplicateur coop.
- `grade_label()` : « Parfait / Bien / Fait » affiché 2 s par l'`EpreuveOverlay` (`draw_string`, police du HUD) ; son `Audio.play("epreuve_grade_<note>")`.
- Flèche hors écran : `WaveIndicator.setup(director, side, along, s)` est centré sur la caméra ; ajouter dans `Epreuve` un `OffscreenArrow` minimal (chevron au bord de l'écran vers `global_position` quand l'objet est hors champ, couche des télégraphes ; 40 lignes) ou brancher le repère hors écran du HUD s'il existe (`scripts/ui/hud.gd` : vérifier `offscreen`).

### 7.5 Fichiers partagés (orchestrateur)
- `scripts/core/balance.gd` : constantes §8, fonctions `hold_hp()`, `epreuve_grade_hold()`, `EPREUVE_BIG_AVOID_U` passé en dictionnaire. `scripts/core/events.gd` : rien. `project.godot` : rien (les classes `class_name` s'enregistrent seules).
- `scripts/enemies/enemy.gd` : **rien** (la Tenue utilise `walk_target`, champ public existant). À signaler si `walk_target` est remis à `null` ailleurs que par le raid (vérifier `raid_*.gd` : il ne doit pas effacer la cible d'un monstre qui n'est pas un add).

### 7.6 UI, journal, mode test
- `scripts/ui/minimap.gd` : icône par verbe `minimap_epreuve_<verb>.png` (dossier `UI_DIR`, repli : icône de pilier teintée par état) ; position = `global_position` de l'épreuve (déjà rafraîchie : les épreuves mobiles bougent sur la minimap).
- `scripts/ui/hud.gd` : barre de progression de l'épreuve en cours (`Epreuve.progress()`), 2 s de libellé à la fin ; maintien sur les relais déjà géré (`interact_state().hold_s`).
- `scripts/telemetry/run_log.gd` : dans chaque entrée `epreuves[]`, ajouter `extra` = `{stalls, leash_wait_s}` (escorte), `{hits, pulses}` (rituel), `{points, misses}` (poursuite), `{hits, out_s}` (veine), `{hp_ratio, packets, intercepted}` (tenue) ; `tools/analyse_runs.py` : note moyenne par verbe, part du temps en épreuve, `post_boss_s`.
- `scripts/testmode/test_loop_tools.gd` `spawn_epreuve(tree, verb)` : géométrie synthétique autour du joueur pour les 3 nouveaux verbes (6 bornes en anneau de 12 u, boucle carrée de 48 u, cloche à 4 u avec 3 côtés) ; `test_panel.gd` `_build_loop` : un bouton par verbe (« Épreuve : poursuite / veine / tenue »), notes forcées et « Terminer » inchangés.

---

## 8. Constantes `Balance` (à ajouter ; existantes rappelées en italique)

| Constante | Valeur | Plage sûre | Sens |
|---|---|---|---|
| `EPREUVES_ENABLED` | `false` → `true` à l'activation (§12) | — | drapeau global (déjà `var`) |
| `EPREUVES_ARG` / **`EPREUVES_OFF_ARG`** | `"--epreuves"` / `"--no-epreuves"` | — | `epreuves_enabled()` = `(EPREUVES_ENABLED or has(ARG)) and not has(OFF_ARG)` |
| **`EPREUVES_PER_STAGE`** | 2 | 0-2 | épreuves par étage (le reste en petits piliers classiques) |
| **`EPREUVE_IN_ENDLESS`** | true | — | épreuves aux étages 6-9 |
| ~~`EPREUVE_STAGE`~~ | supprimée | | remplacée par `data/epreuves.json` |
| **`EPREUVE_SHARED_VERBS`** | `[&"rituel"]` (E5 : Poursuite retirée) | — | cible « parfait » × `epreuve_target_party_mult(n)` |
| **`EPREUVE_BIG_AVOID_U`** | `{escorte: 12, rituel: 12, veine: 10, tenue: 12, poursuite: 6}` | ±2 | dégagement du gros pilier (remplace le scalaire 12) |
| **`EPREUVE_CHEST_SPLIT`** | `{depart: 1, arene: 3, epreuve: 3}` | — | 3 coffres par épreuve (remplace les clés `escorte` / `rituel`) |
| **`EPREUVE_RUBIES_PARFAIT`** / **`EPREUVE_RUBIES_CAP`** | 0 / 8 | 0-1 / 8 | §6.3 |
| *`EPREUVE_GOLD_P`* | `{parfait: 0.8, bien: 0.5, fait: 0.2}` (E5, était 1,5 / 1,0 / 0,5) | plan : bien 0,9-1,0 (repli appliqué, §15) | §6.1, §15 |
| *`EPREUVE_ZONE_GOLD_MULT`* | 0,4 (E5, était 0,5) | 0,4-0,5 | |
| *`EPREUVE_TARGET_S`* | `{escorte: 40, rituel: 35, poursuite: 40, veine: 40, tenue: 40}` (E5, poursuite 45 → 40) | ±10 s | existante |
| *`EPREUVE_GOOD_MULT`* / *`EPREUVE_BACKSTOP_S`* / *`EPREUVE_ZONE_RADIUS_U`* | 1,5 / 75 / 7 | | existantes |
| **`CHASE_POSTS`** / **`CHASE_JUMP_S`** / **`CHASE_POINTS`** | 6 / 8,0 / 5 | 5-6 / 7-10 / 4-6 | §3.3 |
| **`CHASE_JUMP_MIN_U`** / **`CHASE_JUMP_MAX_U`** | 9,0 / 17,0 | 8-10 / 15-18 | portée d'un saut |
| **`CHASE_REACH_U`** / **`CHASE_WARN_S`** | 2,0 / 1,5 | 1,5-2,5 / 1,0-2,0 | rayon de la borne, vacillement avant le saut |
| **`VEIN_RADIUS_U`** / **`VEIN_SPEED_U`** / **`VEIN_CHARGE_S`** | 6,0 / 1,5 / 30 | 5-7 / 1,2-2,0 / 25-35 | §3.4 |
| **`VEIN_LOOP_MIN_U`** / **`VEIN_LOOP_MAX_U`** | 40 / 70 | | validation des tracés |
| **`VEIN_GEYSER_EVERY_S`** / **`VEIN_GEYSER_RADIUS_U`** / **`VEIN_GEYSER_TELEGRAPH_S`** / **`VEIN_GEYSER_COEF`** / **`VEIN_GEYSER_AHEAD_U`** | 6,0 / 2,0 / 1,2 / 1,0 / 0,75 | 5-8 / 1,5-2,5 / ≥ 0,8 / 0,8-1,2 / 0,5-1,0 (E5, ahead était 3,0) | E5 : `VEIN_GEYSER_ON_PLAYER` true ; repli `VEIN_GEYSER_FALLBACK_AHEAD_U` 3,0 |
| **`VEIN_ZONE_RADIUS_U`** | 7,0 | | zone = disque + 1 u |
| **`EPREUVE_CHEST_MIN_U`** | 3,0 | | aucun coffre à < 3 u d'un objet d'épreuve (E5) |
| **`HOLD_HP_MINI_SHARE`** / **`HOLD_DURATION_S`** / **`HOLD_SIDES`** | 0,5 / 40 / 3 | 0,4-0,6 / 35-45 / 3 | §3.5 |
| **`HOLD_WAVE_EVERY_S`** / **`HOLD_PACKET`** / **`HOLD_ANNOUNCE_S`** | 8,0 / 4 / 2,0 | 6-10 / 3-5 / 1,5-2,5 | |
| **`HOLD_SPAWN_DIST_U`** / **`HOLD_LURE_BREAK_U`** / **`HOLD_HIT_RADIUS_U`** | 10 / 3,0 / 1,3 | 8-12 / 2,5-4 / 1,3 | |
| **`HOLD_PERFECT_HP_PCT`** / **`HOLD_ZONE_RADIUS_U`** | 0,7 / 12 | 0,6-0,8 / 10-14 | |
| Fonctions | `hold_hp(D, stage, n_alive) = HOLD_HP_MINI_SHARE × boss_hp(&"mini", D, stage, n_alive)` ; `epreuve_grade_hold(hp_ratio)` ; `vein_geyser_damage(D) = mini_attack_damage(boss_damage(&"mini", D), VEIN_GEYSER_COEF)` | | `test_balance.gd` : valeurs et monotonie |

---

## 9. Assets Codex à commander (placeholders en code autorisés en attendant)

Un lot à la fois (`sh art/tools/run_codex.sh <consigne> <journal> low`), DA `STYLE_boss_da.md` + cel `STYLE_cel.md`, caméra iso 2:1 (`art/tools/iso/iso_rig.py`), ombres cuites `_shadow.png`, émission `_e.png`, **pas de `_n`**. Rendu des props comme le levier de secret : ortho 2,25 u sur 128 px (`SecretLever.RENDER_PX_PER_U`), socle à 80 % de la hauteur. Dossier `game/assets/sprites/props/epreuve/`, VFX dans `game/assets/sprites/vfx/epreuve/`, icônes dans `game/assets/sprites/ui/da/`.

| Lot | Fichiers (noms exacts) | Taille / frames | Biomes |
|---|---|---|---|
| EP-A barque (Escorte) | `escort_boat_terraces_<dir>.png` + `_shadow`, dir ∈ {e, ne, n, nw, w, sw, s, se} | 160 × 112 px, 1 frame par direction (1,5 × 1,0 u), lanterne de proue `_e` | terraces |
| EP-B bornes (Poursuite) | `chase_post_<skin>_{off,lit,done}.png` + `_e` (lit, done) + `_shadow` ; `chase_post_<skin>_altar.png` | 128 × 160 px (prop 1,6 u) | fog_forest (champignon-lanterne, mycélium `#C27BFF`), crypts (cristal `#BFF4FF`) |
| EP-C lumière (Poursuite) | `vfx/epreuve/chase_light_<skin>.png` planche 8 frames | 96 × 96 px par frame, boucle 10 fps, additif | fog_forest, crypts |
| EP-D veine | `vfx/epreuve/vein_disc_<skin>.png` (anneau + remplissage, 4 frames de pulsation) ; `vfx/epreuve/vein_geyser_<skin>.png` (éruption, 6 frames) ; `props/epreuve/vein_source_<skin>_{off,on}.png` + `_e` + `_shadow` | disque 512 × 512 (affiché à 768 px = 6 u de rayon, `scale` 1,5), geyser 128 × 192 par frame, source 128 × 160 | fog_forest, crypts |
| EP-E cloche (Tenue) | `hold_bell_rust_city_{off,ringing,dim}.png` + `_e` (ringing) + `_shadow` ; `ringing` = planche 4 frames (battant) | 160 × 224 px (2,5 u), 4 frames à 8 fps | rust_city |
| EP-F icônes | `ui/da/minimap_epreuve_{escorte,rituel,poursuite,veine,tenue}.png` | 64 × 64 px, même style que `minimap_pillar` | — |
| EP-G sons (`art/tools/audio/`, sortie `game/assets/audio/epreuves/`, entrée dans `MANIFEST.md`) | `epreuve_start.ogg`, `chase_jump.ogg`, `chase_warn.ogg`, `chase_point.ogg`, `chase_miss.ogg`, `vein_tick.ogg` (toutes les 5 s de charge), `vein_geyser_warn.ogg`, `vein_geyser.ogg`, `hold_side.ogg`, `hold_bell_hit.ogg`, `hold_bell_dim.ogg`, `hold_bell_ring.ogg`, `epreuve_grade_parfait.ogg`, `epreuve_grade_bien.ogg`, `epreuve_grade_fait.ogg` | mono 44,1 kHz, ≤ 1,5 s sauf `hold_bell_ring` (3 s) | — |

Les vannes et soupapes du Rituel réutilisent `lever_<skin>_{off,on}` déjà livrés ; un lot dédié `valve_<skin>` est optionnel (P2). Ordre conseillé : EP-B → EP-D → EP-E → EP-A → EP-C → EP-F → EP-G (les verbes sans asset d'abord, la barque a déjà un placeholder lisible).

---

## 10. Tests à écrire (headless, `godot --headless --path game res://tests/<test>.tscn` → `RESULT: OK`)

| Test | Contenu |
|---|---|
| `epreuve_test.gd` (existant, à généraliser) | drapeau désactivé : jeu inchangé sur les 8 cartes (3 piliers ordinaires, 10-11 coffres, 4 capsules, tirage déterministe) ; drapeau activé : pour chaque carte 1-4, `epreuves_on`, 3 piliers = les deux verbes du biome + gros, géométrie praticable (`is_reachable_local` sur bornes, tracé échantillonné à 0,5 u, cœur et relais, cloche et points de côté à 6 et 10 u), gros pilier dégagé (`_big_clear_of_epreuves`), ≥ 3 coffres à ≤ 8 u de chaque épreuve, ≥ 2 à l'arène, 4 capsules dont 1 au départ et ≥ 3 sur les tracés, mini-boss distincts du plan, `to_dict / from_dict` ; balayage de 5 graines par carte ; étage 5 : jamais d'épreuve ; sans fin étage 6 : épreuves du biome 1 ; `data/epreuves.json` : chaque verbe existe, chaque biome 1-4 a 2 verbes distincts, paires différentes entre étages consécutifs ; `enabled: false` sur un biome → piliers classiques ; `EPREUVES_PER_STAGE = 1` → 1 épreuve + 1 petit pilier |
| `epreuve_chase_test.gd` | 6 bornes synthétiques ; lancement ; la lumière saute à 8 s vers une borne à 9-17 u ; vacillement à 6,5 s ; joueur à ≤ 2 u avant le saut = point, borne `done` ; joueur loin = raté, `clean` faux ; 5 points → résolu, mini-boss sous la lumière ; coop : 2 joueurs, seuil non multiplié (E5) ; `global_position` = borne allumée ; sauvegarde en cours ; délai de sécurité |
| `epreuve_vein_test.gd` | boucle carrée 48 u ; disque à 1,5 u/s ; charge seulement avec un joueur dedans, jamais décroissante ; coop : prorata et plancher 0,25 ; geyser toutes les 6 s sous un joueur vivant du disque (repli 3 u devant), décalé de 0,75 u, télégraphe 1,2 s, un coup par joueur, `clean` faux ; aller-retour sur un tracé ouvert ; charge 30 s → mini-boss au centre ; longueur hors 40-70 u refusée par `EpreuveGeom` ; sauvegarde |
| `epreuve_hold_test.gd` | cloche PV = 0,5 × mini ; annonce 2 s puis paquet de 4 à 10 u du côté annoncé avec `walk_target` = cloche ; joueur à ≤ 3 u d'un monstre leurré → `walk_target = null` ; contact → PV baissent ; 0 PV → `dim`, épreuve continue, note « fait » ; 40 s → mini-boss par le dernier côté ; PV ≥ 70 % → « parfait » ; plafond de vivants atteint → paquet réduit sans erreur ; coop : PV × 1,3 à 2 ; sauvegarde |
| `test_balance.gd` | nouvelles constantes (valeurs, télégraphes ≥ 0,8 s, `hold_hp`, `epreuve_grade_hold`, `vein_geyser_damage`, `EPREUVE_BIG_AVOID_U` par verbe) |
| `economy_test.gd` | drapeau activé, étages 1-4 : or gagné dans 8-10,5 P avec notes « bien » forcées ; comparaison avec et sans drapeau (écart ≤ +1,8 P) |
| `stage_test.gd`, `coop_stage_test.gd`, `reachable_spawn_test.gd`, `maps_test.gd` | épreuves actives : étage complet jouable (deux mini-boss → gros pilier déverrouillé), coop 4 (Rituel à 3 relais fermés en parallèle, Poursuite partagée), apparitions atteignables, 8 cartes valides |

---

## 11. Découpage en lots indépendants

| Lot | Agent | Fichiers (exclusifs au lot) | Dépend de |
|---|---|---|---|
| **E0 · socle et données** | orchestrateur (`balance.gd` est un fichier partagé) puis Sonnet | `scripts/core/balance.gd` (§8), `data/epreuves.json`, `scripts/stage/epreuve_geom.gd`, `scripts/stage/epreuve.gd` (§7.4), `scripts/stage/epreuve_ritual.gd` (skin), `scripts/stage/stage_manager.gd` (§7.3), `tools/gen_maps.py` (dict `EPREUVES` : les 6 cartes du §4, plus la plaque des Cryptes B) + régénération des 6 `data/maps/*.json`, `tests/epreuve_test.gd` généralisé, `tests/test_balance.gd` | — ; **E1-E3 peuvent démarrer en parallèle** sur le contrat de ce document (classes `make(...)`, `_begin/_run/_resolve`, `_extra_dict`), tant que E0 ne branche `_make_epreuve` qu'à la fusion |
| **E1 · Poursuite** | Sonnet (worktree) | `scripts/stage/epreuve_chase.gd`, `epreuve_chase_post.gd`, `tests/epreuve_chase_test.{gd,tscn}` | E0 (fusion) |
| **E2 · Veine** | Sonnet (worktree) | `scripts/stage/epreuve_vein.gd`, `epreuve_vein_source.gd`, `tests/epreuve_vein_test.{gd,tscn}` | E0 |
| **E3 · Tenue** | Sonnet (worktree) | `scripts/stage/epreuve_hold.gd`, `epreuve_hold_bell.gd`, `tests/epreuve_hold_test.{gd,tscn}` ; lecture seule de `enemies/enemy.gd` (`walk_target`) | E0 |
| **E4 · UI, journal, mode test** | Sonnet | `scripts/ui/minimap.gd`, `scripts/ui/hud.gd` (barre, libellé de note, flèche hors écran), `scripts/telemetry/run_log.gd`, `tools/analyse_runs.py`, `scripts/testmode/test_loop_tools.gd`, `scripts/testmode/test_panel.gd` | E1-E3 pour les boutons et `extra` (peut commencer par escorte / rituel) |
| **E5 · économie et étage** | systems-designer puis Sonnet | `tests/economy_test.gd`, `stage_test.gd`, `coop_stage_test.gd`, `reachable_spawn_test.gd`, `maps_test.gd` ; recalage éventuel de `EPREUVE_GOLD_P` (orchestrateur) | E0-E3 |
| **E6 · assets Codex** | assets-codex-sonnet (un lot à la fois) | `art/tools/epreuves/_ep_a…g.txt`, `art/briefs/epreuves.md` (specs §9), `art/blender/epreuves/*.blend`, `game/assets/sprites/props/epreuve/`, `vfx/epreuve/`, `ui/da/minimap_epreuve_*`, `game/assets/audio/epreuves/` | aucun (placeholders en jeu) ; branchement des sprites dans E1-E3 et `epreuve_escort.gd` à la livraison |

Fusion : E0 d'abord ; E1, E2, E3 en parallèle (fichiers disjoints, un `match` à compléter dans `_make_epreuve` et `TestLoopTools.spawn_epreuve` à la fusion) ; E4, E5 ensuite ; E6 en continu. Vérification de l'orchestrateur : les 4 tests d'épreuve + `economy_test` + `stage_test` + `save` verts, puis une run complète en `-- --epreuves` sur chaque biome en mode test.

---

## 12. Activer `EPREUVES_ENABLED` : quand et comment

1. **Conditions** : E0-E5 fusionnés ; `epreuve_test`, `epreuve_chase_test`, `epreuve_vein_test`, `epreuve_hold_test`, `test_balance`, `economy_test`, `stage_test`, `coop_stage_test`, `maps_test`, tests de sauvegarde : `RESULT: OK` ; les 8 cartes ont leurs clés ; `RunLog` enregistre `epreuves_on` et les notes.
2. **Vérification du joueur en mode test** (protocole, sans campagne mais obligatoire une fois) : « Mode test » → TAB → « Boucle d'étage » → pour chaque verbe : poser, lancer, viser « parfait », puis « Note : fait » + « Terminer », vérifier que le mini-boss apparaît et que la zone suit l'objet ; puis une run en Moyen avec `-- --epreuves` (Ardent), étages 1-4 : « le verbe se comprend sans texte ? », « j'ai eu autre chose à faire que le tour ? », post-boss ≤ 25 s.
3. **Bascule** (faite le 07/11/2026, lot E5) : dans `balance.gd`, `var EPREUVES_ENABLED := true` (commentaire : date et décision du 06/11/2026) ; `tests/epreuve_test.gd` `_flag_off` force `false` explicitement (déjà le cas) ; `-- --no-epreuves` (`EPREUVES_OFF_ARG`) reste comme interrupteur de comparaison et de secours ; `tools/analyse_runs.py` sépare les runs par `epreuves_on`.
4. **Replis sans code** : `data/epreuves.json` `"enabled": false` sur le biome fautif (piliers classiques pour cet étage, le reste inchangé) ; `Balance.EPREUVES_PER_STAGE` 1 ; drapeau à `false` = jeu strictement identique à aujourd'hui (garanti par `_flag_off`).
5. **Sauvegardes** : aucune migration ; une run en cours garde la disposition tirée.
6. **Avant la sortie** : retirer `EPREUVES_ARG` / `EPREUVES_OFF_ARG` de la liste des options de test si le joueur le souhaite (comme les autres interrupteurs « À RETIRER »), ou les garder (sans effet pour un joueur ordinaire).

---

## 13. Risques

| Risque | Parade |
|---|---|
| Durée d'étage +20-40 s (étages 3-4 déjà à 254-290 s) | mesurer `RunLog` ; levier `PILLAR_CHARGE_S` 60 → 45 quand `epreuves_on`, ou cibles « parfait » −5 s |
| Or des étages 2-4 au bord haut de la bande | §6.1, `economy_test` avant la bascule |
| Tenue = test de puissance | note sans punition, un seul biome, `HOLD_PACKET` 4 et `HOLD_HP_MINI_SHARE` 0,5 réglables ; si trop dure : paquets de 3 |
| Monstres leurrés qui ignorent le joueur (`walk_target`) | `HOLD_LURE_BREAK_U` 3 u ; vérifier qu'aucun code de raid ne remet `walk_target` sur un monstre ordinaire |
| Veine trop facile (disque à 1,5 u/s) | les geysers devant le disque forcent la sortie ; levier `VEIN_SPEED_U` 2,0 et `VEIN_GEYSER_EVERY_S` 5 |
| Poursuite illisible dans le noir des Cryptes | bornes `_e` fixes une fois `done`, lumière additive 0,6 u, vacillement 1,5 s, flèche hors écran |
| Gros pilier toujours au même endroit sur une carte | §4 : au moins deux candidats dégagés par carte ; `EPREUVE_BIG_AVOID_U` par verbe |
| Plaque de secret (15, 51) sur le tracé des Cryptes B | déplacer la plaque ou accepter (sans effet seule) |
| Perf mobile | un objet mobile par épreuve, télégraphes `_draw` sur la couche non éclairée, paquets dans le pool du director, aucune lumière dynamique nouvelle (l'accent émissif est dans le sprite) |
| Coop : Rituel et Poursuite triviaux à 4 | `EPREUVE_TARGET_PLAYER_SLOPE` 0,08 (plage 0,05-0,12), à mesurer |

---

## 14. Décisions du joueur (07/11/2026)

1. **Cryptes** : même paire que le Gouffre (Veine + Poursuite), tracés et habillage propres ; lassitude mesurée dans `RunLog`.
2. **Sans fin** : épreuves aux étages 6-9 (`EPREUVE_IN_ENDLESS = true`).
3. **Rubis** : 1 rubis par épreuve « parfaite », plafond 8 par run.
4. **Tenue en coop** : PV de la cloche × 1,3 / 1,6 / 1,9 à 2 / 3 / 4 joueurs, paquets inchangés.
5. **Bascule** : `EPREUVES_ENABLED = true` dès la fusion d'E0-E5 (placeholders visibles jusqu'aux assets Codex).

---

## 15. Lot E5 appliqué (07/11/2026)

Valeurs relues dans `game/scripts/core/balance.gd` ; elles remplacent celles citées plus haut (passages corrigés en place).

- `EPREUVE_GOLD_P` = `{parfait: 0.8, bien: 0.5, fait: 0.2}` (était 1,5 / 1,0 / 0,5).
- `EPREUVE_ZONE_GOLD_MULT` = 0,4 (était 0,5).
- `EPREUVE_SHARED_VERBS` = `[rituel]` : la Poursuite n'est plus partagée en coop pour le seuil « parfait ».
- `EPREUVE_TARGET_S[poursuite]` = 40 s (était 45) ; « bien » jusqu'à 60 s ; 3 bornes ratées = « bien », 4 = « fait ».
- Veine : le geyser se pose sous un joueur vivant du disque, tour à tour (en sautant ceux qui ont un coffre ouvert) ; `VEIN_GEYSER_AHEAD_U` 0,75 u dans le sens d'avance ; `VEIN_GEYSER_TELEGRAPH_S` 1,2 s (était 1,0) ; `VEIN_GEYSER_ON_PLAYER` = true ; sans joueur éligible, repli `VEIN_GEYSER_FALLBACK_AHEAD_U` 3 u devant le centre.
- Coffres : `EPREUVE_CHEST_MIN_U` = 3,0 u (aucun coffre tiré à moins de 3 u d'un objet d'épreuve). Carte `cite_fonderie_canal` : repère C ajouté en (55 ; 17), 20 coffres.
- `EPREUVES_ENABLED` = true depuis le 07/11/2026. `-- --no-epreuves` reste l'interrupteur de secours.
