# Rainfall : architecture multijoueur coop (1 à 4 joueurs)

Étude du 01/11/2026 (agent architecte). Aucun code modifié par l'étude. Mise à jour du 11/11/2026 : les étapes 1 à 4 du plan (§3, coop locale PC) sont codées ; les étapes 5 à 10 (réseau, EOS) ne le sont pas. Base : état du dépôt au commit `088aa022`.
Objectif du joueur : un mode coopératif 1 à 4 joueurs façon Risk of Rain 2, sur PC (Windows), Android et iOS, sans serveur payant (jeu vendu ~5 €, aucun revenu récurrent).

---

## 1. Audit : tout ce qui suppose un seul joueur

### 1.1 Chiffres globaux (scripts/, 267 fichiers .gd, ~96 600 lignes)

| Motif | Occurrences | Fichiers | Lecture |
|---|---|---|---|
| `get_first_node_in_group(&"player")` | 56 | 39 | « le » joueur cherché à la volée |
| `is_in_group(&"player")` | 12 | 7 | contact joueur (coffres, capsules, téléporteur…) |
| `RunState.` | 515 | 72 | état de run global, dont une grosse part est en réalité par joueur |
| `Events.` (emit + connect) | 283 | 51 | signaux sans identité de joueur |
| `Input.` (lecture directe d'actions) | 56 | 23 | entrées globales, pas par appareil |
| `get_tree().paused = true` | 11 | 8 | coffres, stations, présages, pause : gèle le monde entier |
| `randf()/randi()` hors RNG semé | 49 | ~30 | rend tout déterminisme impossible (voir §2.2) |
| `RandomNumberGenerator.new()` | 71 | — | nombreux flux RNG locaux |
| `Profile.` | 80 | 31 | profil unique sur l'appareil |
| `TestMode.` | 71 | 20 | drapeaux de triche globaux |

Points positifs déjà présents : les cerveaux de monstres reçoivent leur cible en paramètre (`tick(delta, player, ppos, ...)`, 17 cerveaux), la logique de coffre est séparée de son UI (`ChestSession`), les pickups et projectiles ennemis sont des pools, la génération d'étage passe par des RNG semés (aucun `randf()` global dans `scripts/stage`, `scripts/director`, `scripts/loot`, `scripts/stations`).

### 1.2 Points de couplage par zone

| # | Zone | Couplage (chemins:lignes représentatifs) | Ce qu'il faut faire | Effort (j-agent) |
|---|---|---|---|---|
| 1 | **RunState** (autoload) | `run_state.gd:22-49` : `gold`, `xp`, `level`, `items`, `character`, `loadout`, `counters`, `scrap`, `compass` sont globaux. Usages : `RunState.items` 56/18 fichiers, `RunState.level` 34/16, `RunState.gold` 36/14, `RunState.counters` 56/22, `RunState.character` 27/11. `item_effects.gd:253` lit `RunState.level` pour les dégâts. | Scinder en `RunState` (partagé : étage, temps actif, mode, D, graine, présages, boss tués, kills) et `PlayerState` (par joueur : or ?, XP/niveau, items, perso, loadout, compteurs, ferraille, boussole). Garder une façade `RunState.local()` pour limiter la casse. | 4 |
| 2 | **Groupe `player`** | 56 appels dans 39 fichiers : `director.gd:171,343,463`, `pickup_manager.gd:184,220`, `chest_session.gd:142`, `stage_manager.gd:116,164,257,1034,1178`, `pillar.gd:256,491`, `station_state.gd:131`, `gold_capsule.gd:64`, `hud.gd:161`, `audio_manager.gd:271,608`, `damage_numbers.gd:145`, `creature_shadows.gd:62`, `run_log.gd:319`, 7 dans `test_tools.gd`. | Nouvel autoload `Players` (registre) : `all()`, `alive()`, `local_players()`, `nearest(pos)`, `by_id(id)`, `count()`. Remplacer chaque appel par la variante qui a du sens (le plus proche, le joueur local, tous). | 2,5 |
| 3 | **Caméra** | `main.gd:164-166` : la `Camera2D` est enfant du joueur ; `audio_manager.gd:267` écoute depuis la caméra. | Coop local : `SharedCamera` (barycentre des joueurs vivants, dézoom borné, laisse qui retient les joueurs dans l'écran). En ligne : une caméra par client sur son joueur. | 2 |
| 4 | **Entrées** | `player.gd:553-568,783-787`, `slide_dodge.gd:83`, `spell_caster.gd:277,597-599`, `hud.gd:1255-1263` lisent `Input.*` sans appareil ; `input_setup.gd:95` ne retient qu'une `last_pad_device`. | Abstraction `InputSource` par joueur : `KbmSource`, `PadSource(device)`, `TouchSource`, `NetSource` (joueur distant). Le joueur et le SpellCaster lisent leur source, plus jamais `Input` directement. L'interaction maintenue passe du HUD au joueur. | 3 |
| 5 | **SpellCaster / kits** (11 kits, ~15 000 lignes) | `spell_caster.gd:31` un `player`, visée souris/stick globale (`:597-599`) ; kits abonnés à `Events.enemy_killed` / `player_damaged` sans filtre de joueur (`ardent_base_kit.gd:46`, `avare_kit.gd:381-382`, `averse_kit.gd:454`, `morfil_kit.gd:337`, `rictus_kit.gd:349`, `vigie_kit.gd:425`, `ardent_tracker.gd:64`). `avare_kit.gd` : 23 accès `RunState` (or). | Filtrer les signaux sur « mon » joueur (`killer == player`, `victim == player`), lire l'or via `PlayerState`. La recherche d'ennemis (`get_nodes_in_group(&"enemies")` ×65, `intersect_ray` ×12) marche telle quelle. | 4 |
| 6 | **Events** | `events.gd:6` `player_damaged(amount, source)`, `:7` `player_died`, `:8` `pickup_collected(kind, amount)`, `:10` `item_chosen(id)`, `:4` `enemy_killed` sans tueur ; `enemy.gd:206` `take_damage(..., hit)` sans source joueur. 16 abonnés à `enemy_killed`, 8 à `player_damaged`, 13 à `player_died`. | Ajouter le joueur concerné : `player_damaged(player, amount, source)`, `player_died(player)`, `pickup_collected(player, kind, amount)`, `item_chosen(player, id)`, `hit["by"] = player_id` et `enemy_killed(..., killer_id)`. Nouveaux : `player_downed`, `player_revived`, `party_wiped`. **Contrat orchestrateur.** | 2,5 |
| 7 | **Director / NavField / spawns** | `director.gd:338-412` : un `ppos` pour le flux, le spawn (`_spawn_point(ppos)`), le LOD et le recyclage ; `nav_field.gd:215` `update(player_pos)` = BFS à source unique. `director.gd:108` RNG semé (bien). | BFS multi-sources (une cellule par joueur vivant, coût quasi nul) ; spawn autour d'un joueur tiré au hasard ; LOD/recyclage selon la distance au joueur **le plus proche** ; cible par monstre = plus proche (ou aggro) choisie par le director. Mesurer 250 monstres à 4 joueurs. | 3 |
| 8 | **Cerveaux, hazards, projectiles ennemis** | 17 cerveaux `tick(..., player, ...)` (bien) ; mais `floor1_hazards.gd:130`, `miniboss_hazards.gd:220`, `smelter_slag.gd:212`, `sonneur_storm.gd:58`, `weaver_snare.gd:254`, `raid/raid_kit.gd:88` ne touchent qu'un joueur ; `enemy_projectile_pool.gd:72` collisionne contre un seul joueur ; `enemy.gd:1077` `_hit_player`. | Boucler sur `Players.alive()` pour les zones et les projectiles ; cible des boss = plus proche avec inertie (pas de flip-flop). Mécaniques de raid (14 fichiers) à relire : certaines supposent un seul porteur. | 4 |
| 9 | **Coffres, or, items, stations, marchand** | `chest_ui.gd:279,313`, `showcase_ui.gd:78`, `compass_panel.gd:26`, `item_picker.gd:67` mettent le jeu en pause ; `chest_session.gd:51,95,112,140-144` lit/écrit `RunState.items/gold` et cherche « le » joueur ; `station_state.gd` 31 accès RunState. | `ChestSession` reçoit un `PlayerState`. En ligne, plus de pause : UI de choix non bloquante (voir décisions §4). | 3 |
| 10 | **Pickups XP / or** | `pickup_manager.gd:143-197` : aimant vers un seul joueur ; `_mult()` (`:218-222`) lit les multiplicateurs d'un joueur. | Aimant vers le joueur le plus proche, crédit à celui-ci (or) ou à tous (XP partagée façon RoR2). | 1 |
| 11 | **Téléporteur, piliers, secrets, épreuves** | `exit_teleporter.gd:30-31` booléen `_player_on` ; `pillar.gd:256,491` charge si « le » joueur est dedans ; `secret_lever.gd`, `secret_beacon.gd`, `epreuve*.gd`. | Compter les joueurs dans la zone ; téléporteur : interaction d'un joueur lance un vote/compte à rebours (les morts sont emmenés). | 2 |
| 12 | **Mort, fin de run, HUD de fin** | `main.gd:388` `_on_player_died` termine la run ; `main.gd:410-418` rubis et récap d'un joueur. | État « à terre » + réanimation (ou mort jusqu'à l'étage suivant, façon RoR2) ; fin de run quand tous sont morts. | 2 |
| 13 | **HUD** (`hud.gd`, 1 376 lignes) | `hud.gd:26,147-186` un `player` ; plaque joueur, barre d'items, sorts. Aussi `minimap.gd`, `offscreen_cues.gd`, `overhead_bars.gd`, `dodge_button.gd`, `onboarding_hints.gd`. | Coop local : 4 plaques compactes (coins), sorts du joueur sous chaque plaque. En ligne : HUD actuel pour le joueur local + mini-plaques des alliés + marqueurs hors écran. Avis `ux-designer` requis. | 5 |
| 14 | **Balance** | Aucune notion de nombre de joueurs : `balance.gd:627` crédits du director, `:689` PV de boss, `:914` prix des coffres. | `Balance.party_factor(n)` et déclinaisons (crédits, PV boss, nombre de coffres, prix). Chiffres à faire valider par `systems-designer` + simulateur. **Contrat orchestrateur.** | 2 |
| 15 | **Pause** | `pause_menu.gd:540`, `main.gd:264,361,412`, `test_overlay.gd:130,150`. | Local : pause globale conservée. En ligne : menu sans pause (seul l'hôte peut « tout figer » entre deux étages). `RunState.active_time_s` ne s'arrête plus pendant un coffre en ligne. | 1 |
| 16 | **Sauvegarde de run** | `run_save.gd`, `main.gd:497-528` (`_player_dict`). | Local : sauver N `PlayerState`. En ligne : pas de reprise de run v1 (l'hôte seul pourrait sauver, mais les clients doivent revenir) ; à trancher. | 1 |
| 17 | **Profile / rubis** | `main.gd:410-411` rubis calculés sur `RunState.gold` ; `Profile.` 80 appels. | Chaque appareil crédite son propre profil (rubis = cosmétique, pas d'enjeu de triche). En coop local : un seul profil sur la machine, rubis pour ce profil. Skins des autres : seul l'identifiant circule. | 1 |
| 18 | **RunLog** | `run_log.gd:319` lit « le » joueur. | Tableau `players[]` dans le JSON ; journal écrit par l'hôte seulement. | 0,5 |
| 19 | **Mode test** | `TestMode.` 71/20, `test_tools.gd` 7 appels au joueur. | Coop local seulement (outil de dev) : cibler le joueur 1 ou tous. Désactivé en ligne. | 1 |
| 20 | **Audio, ombres, numéros de dégâts** | `audio_manager.gd:271,608`, `creature_shadows.gd:62`, `damage_numbers.gd:145`, `ambiance_manager.gd:891`. | Écoute = caméra ; ombres dynamiques plafonnées par palier : budget à partager entre joueurs. | 1 |
| | **Total refactor « N joueurs local »** | | | **≈ 46 j-agent** (tests compris) |

Le gros du coût n'est pas le nombre d'occurrences mais les **décisions de design** (or partagé ou non, coffres sans pause, réanimation, scaling) : elles conditionnent les zones 1, 9, 10, 12, 14.

---

## 2. Options

### 2.1 (a) Coop local même écran

- Plateforme : PC uniquement (1 clavier-souris + jusqu'à 3 manettes, ou 4 manettes). Mobile exclu (un seul écran tactile, paysage 1920×1080 déjà dense).
- Technique : tout le travail du §1 + écran « appuyez sur A pour rejoindre » + caméra partagée. Aucun réseau, aucun store impacté.
- Perf : PC, aucun souci ; le coût monte surtout côté sorts (4 kits actifs : zones, DoT, projectiles ×4). Plafond de projectiles joueurs à poser.
- Risques : lisibilité de 4 kits très chargés en VFX à l'écran ; dézoom borné par la DA iso (sprites 128-256 px). Visée souris pour un seul joueur, les autres au stick droit.
- Intérêt majeur : c'est **le banc d'essai du refactor** et un livrable jouable en soi.
- Effort : ≈ 46 (§1, dont la caméra partagée) + 1-2 (écran de jonction) ≈ **47 j-agent**.

### 2.2 (b) En ligne hôte-client

**Autorité : hôte autoritaire sur le monde, client autoritaire sur lui-même** (modèle RoR2, adapté au PvE sans enjeu compétitif).

| Élément | Qui décide | Comment c'est synchronisé |
|---|---|---|
| Director, spawns, IA des monstres et boss, loot, coffres, or, XP, étage, D | Hôte | Snapshots + événements fiables |
| Déplacement, esquive, i-frames du joueur | Son client | Le client envoie position/état 30 Hz ; l'hôte borne la vitesse (garde-fou, pas anti-triche) |
| Sorts du joueur | Son client | Le kit tourne chez son propriétaire ; il touche les monstres **tels que le client les voit** et envoie « coup(id, dégâts, crit, élément, statuts) » à l'hôte |
| Dégâts reçus | Son client | L'hôte envoie la résolution d'attaque (zone, dégâts, affixes) ; le client teste contre sa position réelle et ses i-frames, applique, renvoie ses PV. Indispensable pour que les esquives (Design_Esquives) restent justes avec 50-150 ms de latence |
| Sorts des alliés vus par un client | — | Événement « cast(slot, cible/direction, graine) » rejoué en **mode cosmétique** (VFX, sons, sans dégâts) |

**Pourquoi pas le déterminisme (lockstep avec RNG partagé) :** 49 appels `randf()/randi()` non semés, 71 générateurs, physique à virgule flottante (`AnimatableBody2D`, séparation), LOD dépendant de la parité de frame (`director.gd:372`), écarts de flottants x86/ARM, frames variables sur mobile. Un seul écart fait diverger 250 monstres en quelques secondes. Le déterminisme est conservé là où il existe déjà : **génération d'étage par graine** (`RunState.run_seed`, `director.gd:108`) ; on envoie graine + variante + étage, et on vérifie par un hachage de la carte.

**Côté client, les monstres sont des « marionnettes »** : les mêmes nœuds `AnimatableBody2D` du pool, cerveau désactivé, position interpolée (tampon 100 ms). Les kits continuent de les trouver par `get_nodes_in_group(&"enemies")` et les raycasts. Les mutations appelées par les kits sont peu nombreuses (mesuré : `take_damage`, `apply_status`, `push`, `stun`, `imprison/release_imprison`, `add_damage_taken_mod`, + lectures `get(...)`, `is_*`) : en mode marionnette, `enemy.gd` les transforme en messages vers l'hôte (prédiction visuelle locale : flash, chiffres). Les kits n'ont presque pas à changer, c'est le point qui rend l'option réaliste.

**Snapshots des monstres (hôte → chaque client)**
- Enregistrement : emplacement de pool u8, position delta i8×2 (0,25 px, ±32 px par pas, suffisant à 20 Hz pour 3-6 u/s) ou absolue u16×2 toutes les 1 s, état/anim u8, orientation + drapeaux u8, PV u8 seulement s'ils changent → **≈ 5-7 o**.
- Intérêt par client : à l'écran (~60-120 monstres) à 20 Hz, hors écran à 4 Hz.
- Paquets < 1 200 o (pas de fragmentation ENet en non fiable) : snapshot découpé par tranches de pool, chaque tranche autonome, canal `unreliable_ordered`.
- Événements fiables groupés par frame : apparition/mort, dégâts (pour les chiffres), pickups, coffres, états de boss, télégraphes (début, forme, durée : le client les dessine localement).
- Projectiles ennemis : événement d'apparition (origine, direction, vitesse, type) puis simulation locale linéaire ; les projectiles à tête chercheuse passent dans le snapshot.
- Pas de `MultiplayerSynchronizer` par monstre (coût par nœud) : un `PackedByteArray` construit dans les buffers déjà présents du director (`_pos`, `_snap`), envoyé par RPC non fiable.

**Bande passante estimée (4 joueurs, 250 monstres, pic de combat)**

| Flux | Débit par client |
|---|---|
| Monstres à l'écran : 100 × 6 o × 20 Hz | 12 Ko/s |
| Monstres hors écran : 150 × 6 o × 4 Hz | 3,6 Ko/s |
| Joueurs : 4 × ~20 o × 30 Hz | 2,4 Ko/s |
| Événements (dégâts, pickups, télégraphes, casts) | 3-6 Ko/s |
| En-têtes UDP/ENet | ~2 Ko/s |
| **Total descendant par client** | **≈ 23-26 Ko/s (≈ 0,2 Mbit/s)** |
| **Montant de l'hôte (3 clients)** | **≈ 75 Ko/s (≈ 0,6 Mbit/s)** |

Supportable en Wi-Fi et en 4G (montant 4G courant ≥ 5 Mbit/s). Consommation data mobile client ≈ 80-95 Mo/h : à signaler dans le jeu.

**Latence** : jouable jusqu'à ~150 ms aller-retour (PvE, autorité locale sur soi). Au-delà, monstres « en retard » visibles mais coups toujours justes pour le tireur. Les boss à télégraphe court (< 300 ms) sont les plus sensibles : marge de télégraphe +RTT/2 à appliquer côté client.

**Perf mobile**
- Client : moins de travail qu'en solo (pas d'IA, pas de director, pas de NavField) ; + décodage ~0,2 ms/frame ; + 3 kits alliés en cosmétique (VFX à plafonner par palier de qualité).
- Hôte mobile : simulation actuelle + sérialisation (~0,5-1 ms/frame à 250 monstres, à mesurer) + 4 kits. Recommandation : autoriser l'hôte mobile, garder `Balance.MAX_ENEMIES = 250` global (le scaling coop passe par les PV et les crédits, pas par le nombre de monstres) et afficher une alerte si l'hôte est en qualité Bas.

**Transports et relais (cross-play PC/Android/iOS)**

| Transport | Cross-play | NAT / relais | Coût | Verdict |
|---|---|---|---|---|
| ENet direct (Godot natif) | Oui | Aucun : LAN ou redirection de port | 0 | **Oui pour le LAN** (découverte par diffusion UDP) |
| EOS P2P (Epic Online Services) via GDExtension (EOSG de 3ddelano : Windows, Android arm64, iOS arm64 ; ou GD-EOS avec `EOSMultiplayerPeer`) | Oui (Windows, Android, iOS) | Traversée NAT + relais Epic | 0 (SDK gratuit) | **Recommandé en ligne** : connexion anonyme par identifiant d'appareil (pas de compte Epic exigé), lobbies + code d'invitation |
| Steam (GodotSteam, Steam Datagram Relay) | PC seulement | Relais Valve | 0 (+100 $ par app si sortie Steam) | Optionnel plus tard, pour les invitations d'amis Steam ; EOS peut s'authentifier via Steam |
| WebRTC (`WebRTCMultiplayerPeer` + extension webrtc-native) | Oui | STUN gratuit, mais **TURN payant** (~10-20 % des NAT) + serveur de signalisation | Récurrent | Non |
| Google Play Games | — | API temps réel fermée en 2020 | — | Impossible |
| Game Center (GKMatch) | Apple seulement | Relais Apple | 0 | Non (pas de cross-play) |

Le code réseau doit rester agnostique : `multiplayer.multiplayer_peer` = `ENetMultiplayerPeer` (LAN, tests) ou le pair EOS. Toute la logique (RPC, snapshots) est identique.

**Conformité des stores**
- Android : `export_presets.cfg:218` `permissions/internet=false` → `true` ; `access_network_state` (`:157`) et `change_wifi_multicast_state` (`:192`, découverte LAN) → `true`. Formulaire « Sécurité des données » à mettre à jour (identifiant d'appareil/produit transmis à Epic), politique de confidentialité, fiche `docs/Fiche_Play_Store.md`.
- iOS : `NSLocalNetworkUsageDescription` + services Bonjour pour le LAN ; étiquettes de confidentialité App Store ; pas de « Sign in with Apple » exigé tant que la connexion est anonyme. Pas d'ATT (aucun pistage).
- **Pas de chat texte ni vocal** : évite la modération exigée pour le contenu généré par les utilisateurs (Apple 1.2, Google UGC) et la reclassification d'âge. Communication par pings et émotes prédéfinis.
- Epic : accepter le contrat EOS et créer le produit sur le portail développeur (décision du joueur, gratuit).

**Risques (b)**
1. Kits cosmétiques des alliés : 11 kits très riches ; distinguer partout « effet visuel » et « effet de jeu » est le plus gros chantier (risque de désync visuelle, pas de jeu).
2. Boss et mécaniques de raid (17 cerveaux, 14 fichiers de raid) : état visuel à exposer (`net_state()`), ~0,5 j par cerveau.
3. Dégâts sur effets différés (DoT, marques, `add_damage_taken_mod`) : l'hôte doit en être la source unique, sinon double comptage.
4. Départ de l'hôte = fin de run (pas de migration d'hôte en v1).
5. Plugin EOS tiers (maintenance, compatibilité Godot 4.7.2, build iOS de GD-EOS non documenté) : prototype technique obligatoire avant d'engager le reste.
6. Tests réseau : pas de simulateur de latence intégré à Godot ; il faut un pair « avec pertes » maison ou clumsy sous Windows.

Effort (b) en plus du refactor local : ≈ **60 j-agent** (détail §3).

### 2.3 (c) Les deux

Le coop local et le réseau partagent 90 % du travail : `Players`, `PlayerState`, `InputSource` (dont `NetSource`), Events avec joueur, director multi-cibles, scaling. Le local ne coûte que la caméra partagée et l'écran de jonction (~3 j) une fois le refactor fait. Le coop local sur une machine peut aussi se combiner au réseau (2 manettes sur un PC + 1 mobile) : à exclure en v1 (complexité UI).

---

## 3. Recommandation et plan

**Recommandation : (c), dans l'ordre local puis en ligne, avec hôte autoritaire + autorité locale sur soi, ENet pour le LAN et EOS P2P pour Internet. Aucun serveur payant.**
Raisons : le refactor local est obligatoire de toute façon, il livre vite un mode jouable sur PC et sert de banc de test ; EOS est la seule voie gratuite qui couvre Windows + Android + iOS avec relais ; le déterminisme est exclu par le code actuel.

### Étapes, jalons testables, effort

| Étape | Contenu | Jalon testable | j-agent |
|---|---|---|---|
| **0. Décisions** | Le joueur tranche le §4 ; `systems-designer` chiffre le scaling ; `ux-designer` le HUD coop | Fiche de décisions validée | 2 |
| **1. Contrats** (orchestrateur) | Autoload `Players`, classe `PlayerState`, `InputSource`, signaux `Events` enrichis, `Balance.party_factor(n)` | `tests/players_registry_test` : 4 joueurs factices, `nearest()`, `alive()` | 3 |
| **2. Refactor N joueurs** | Zones 1-2, 4-12, 15-20 du §1 | Toute la suite actuelle (238 tests .tscn) passe à 1 joueur ; `tests/coop_local_smoke_test` : 4 joueurs scriptés finissent l'étage 1 sans erreur | 34 |
| **3. Director multi-cibles** | BFS multi-sources, spawn par joueur, LOD au plus proche | `tests/director_multi_perf_test` : 250 monstres, 4 joueurs dispersés, tick director < budget solo + 15 % | 3 |
| **4. Coop local PC** | Jonction manettes, caméra partagée, HUD 4 plaques | Run complète à 2 manettes sur PC ; vérification par le joueur en mode test | 5 |
| **5. Prototype réseau** | `Net` (autoload) sur ENet, lobby LAN, synchro graine + hachage de carte, joueurs seuls (pas de monstres) | 2 instances headless sur localhost : même carte (hachage égal), positions répliquées | 5 |
| **6. Monstres marionnettes + snapshots** | Mode marionnette d'`enemy.gd`, snapshots par tranches, intérêt, événements | `tests/net_snapshot_test` : 250 monstres, débit mesuré < 30 Ko/s par client, erreur de position interpolée < 8 px | 10 |
| **7. Combat réseau** | Coups client → hôte, dégâts reçus côté client, kits alliés cosmétiques, pickups, coffres non bloquants | 2 instances : client tue, reçoit or/XP, ouvre un coffre, meurt, est réanimé ; latence simulée 150 ms + 2 % de pertes | 16 |
| **8. Boss et étages** | `net_state()` des 17 cerveaux et du raid, téléporteur en vote, transitions d'étage, fin de run | Run 1-5 complète à 2 instances, boss final compris | 12 |
| **9. EOS + mobile** | Prototype EOSG d'abord (2 j, go/no-go), puis lobbies, code d'invitation, builds Android/iOS, permissions, confidentialité | Partie Windows ↔ Android ↔ iOS par code d'invitation, hors LAN | 10 |
| **10. Robustesse et polish** | Déconnexions, reconnexion client, alertes réseau, plafonds VFX alliés par palier, data mobile | Coupure d'un client en combat : la partie continue ; hôte mobile en qualité Moyen tient 60 fps à 4 | 8 |
| | **Total** | | **≈ 108 j-agent** (local seul : étapes 0-4 ≈ 47) |

Parallélisable : étape 2 en 3-4 agents sur des dossiers disjoints (joueur/sorts, director/monstres, loot/stage, UI) une fois l'étape 1 posée ; étapes 6 et 9 (prototype EOS) en parallèle.

### Ce que le joueur doit décider

1. **Périmètre** : coop local PC seul, en ligne seul, ou les deux (recommandé : les deux, local d'abord). Le multijoueur passe-t-il avant ou après la sortie 1.0 ?
2. **Or** : partagé (chaque kill crédite tout le monde, façon RoR2) ou individuel ? Recommandé : partagé, coffres achetés individuellement.
3. **XP / niveaux** : XP partagée (chacun reçoit tout) recommandée.
4. **Coffres et stations en ligne** : choix non bloquant (le monde continue, joueur invulnérable 2 s à l'ouverture ?) ou objets posés au sol façon RoR2 ? Relances gratuites : 3 par run et par joueur ?
5. **Mort** : réanimation par un allié (maintenir « interagir » 3 s près du corps) ou retour à l'étage suivant façon RoR2 ?
6. **Scaling** : proposition de départ à valider par `systems-designer` : crédits du director ×(1 + 0,5 (n − 1)), PV de boss ×(1 + 0,3 (n − 1)), nombre de coffres ×(1 + 0,25 (n − 1)), plafond de 250 monstres inchangé.
7. **Hôte mobile** autorisé ? (recommandé oui, avec alerte en qualité Bas)
8. **Epic Online Services** : accepter le contrat et le portail développeur (gratuit) ; Steam plus tard ou jamais.
9. **Pas de chat** (pings et émotes seulement) : à confirmer.
10. **Reprise de run** en ligne : non en v1 (recommandé).

### Contrats nouveaux à prévoir (réservés à l'orchestrateur)

- Autoload `Players` et autoload `Net` (`project.godot`).
- `scripts/core/events.gd` : identité du joueur dans `player_damaged`, `player_died`, `pickup_collected`, `item_chosen`, `enemy_killed` (tueur) ; nouveaux `player_downed`, `player_revived`, `party_wiped`.
- `scripts/core/run_state.gd` : extraction de `PlayerState`, façade `RunState.local()`.
- `scripts/core/balance.gd` : `party_factor(n)` et dérivés ; `game/tests/test_balance.gd` et `docs/simulateur_scaling.py` à étendre.
- `scripts/core/input_setup.gd` : entrées par appareil (actions dupliquées par appareil ou `InputSource`).
- `scenes/main.tscn` / `main.gd` : instanciation de N joueurs, caméra partagée.

## Sources

- [Epic Online Services Godot (EOSG), 3ddelano](https://3ddelano.github.io/epic-online-services-godot) : GDExtension Godot 4.2+, Windows, Linux, macOS, Android, iOS, P2P et lobbies.
- [GD-EOS, Daylily-Zeleen](https://github.com/Daylily-Zeleen/GD-EOS) : `EOSMultiplayerPeer`, build iOS encore à documenter.
