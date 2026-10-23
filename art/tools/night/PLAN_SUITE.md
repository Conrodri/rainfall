# Plan de la suite (validé par le joueur le 22/10/2026 vers 11h30)

Ordre conseillé, parallèle quand les contraintes le permettent.

| # | Chantier | État | Contrainte |
|---|---|---|---|
| 0 | 6 kits de personnages, menu (roster 13 cartes), Sonneur, cité rouillée iso | en cours (9 agents) | — |
| 1 | Performance director / ennemis (enemies_perf) | FAIT (−30 %, tests OK) ; passe rendu (HDR 2D, ombres) en cours | — |
| 2 | Simulateur d'équilibrage des personnages | FAIT (8 persos simulés) ; réglages EN ATTENTE du socle commun | réglages après la fin des 6 kits |
| 3 | Faune par biome (EnemyVisual data-driven, demandes Codex) | en cours | — |
| 4 | Étages 4-5 (Cryptes noyées, La Source, boss final 3 phases) avec replis | FAIT (cartes, run 1-5, sans fin) ; IA boss 4 + final EN COURS | après l'agent cité rouillée (stage_map / gen_maps partagés) |
| 5 | Build mobile Android réel | EN COURS (inventaire outils + export) | après 1 (perf) ; vérifier SDK/outils présents, aucune clé dans export_presets |
| 6 | Run complète automatique (étage 1 -> boss final) | FAIT (run_flow_test 1->5) | après 4 |

Codex : file de nuit en pause quota jusqu'à ~13h08 (groupes 7-11 : T5, RA2, AA2, Bourbe BO1-3, mini-boss forêt N2a-e, props F2p, cerf C7d).
Après chaque lot Codex de personnage : relancer l'agent du personnage concerné pour brancher l'art.

## Après les 6 kits (un agent « socle commun », puis un lot Codex audio)
- **Socle commun FAIT (22/10, agent Opus)** : API ressource unique (KitResource) + jauge HUD PC/tactile, pastilles de charges, roulade/lumière/bond arrière/affixes par hooks, statut `imprisoned` d'Enemy (Tocsin + Arpenteuse), état du kit dans la sauvegarde (Averse, Tocsin), portrait unique, étalonnage d'ultime à l'accent, « triangulation failed » (camembert < 1 px de spell_button), Avare garde 50 % de sa bourse, bug Tocsin `limbs` libérés. Détails : game/CONTRACTS.md « Kits de personnage ». Restent : fusion Design_Personnages, lot audio, déblocages cachés, T6, trapèze rouge, poussée des boss.
- Jauge de ressource générique au HUD (kits : `resource_ratio()` / `resource_label()`), PC + mobile.
- Ressource du kit sauvegardée dans la run (eau d'Averse, etc.).
- Hook générique de distance de roulade dans player.gd (Averse lit `_dodge_left`).
- Blanchissement « ultime » de l'étalonnage par personnage (accent propre).
- Fusion des ajouts de design des rapports d'agents dans docs/Design_Personnages.md §2.x.
- Lot Codex audio : sons de sorts de chaque nouveau personnage (Averse : goutte_lame cast/hit, vague, flaque_miroir, crue, trébuchement…).
- Unifier l'API de ressource des kits (Averse `resource_ratio()/resource_label()`, Avare `resource_gauge()`, …) avant la jauge HUD.
- `CharacterData.dodge_distance_u` générique (Averse et Avare écrivent `player._dodge_left`).
- Avare : l'or est converti en XP à chaque étage -> sa puissance repart de 0 à chaque étage et la Poignée est grisée en début d'étage. À trancher (garder une part de l'or, ou plancher de puissance) ; lancer economy_test.
- Déblocages cachés des nouveaux personnages (profile.gd) avant la sortie.
- Rainette : affixes d'élite au contact appliqués en l'air (apply_status sans source) ; kit touche `_light` et `_dodge_dir` privés -> hooks génériques (couleur de lumière du joueur par CharacterData, bond arrière).
- Erreur « Invalid polygon data, triangulation failed » à chaque lancement de sort (probablement le camembert de recharge de spell_button.gd).
- Portraits : le HUD cherche seulement ui/portraits/<id>.png, le menu cherche aussi characters/<id>/portrait.png -> une seule fonction de recherche partagée.
- Tocsin : pastilles de charges (bras) au HUD, état des membres sauvegardé, `extra_charges`, relevé après chute, lisibilité (paraît petit et sombre). Boss jamais poussés (Enemy.push) : voulu ?
- Vérifier le trapèze rouge vu près du joueur sur la capture de Tocsin (télégraphe de monstre ?).
- [x] FAIT (22/10 soir) Brancher T6 (rivet, head_ring, head_blast_top, sockets.json) dans tocsin_kit à la livraison. `BLAST_TOP_RING_PX` 59 -> 512 ; rivet petit à l'écran (cellule 56 px), non jugé en capture.
- Statut `imprisoned` dans Enemy (Arpenteuse l'applique ; repli ralenti 85 % 1 s). Tocsin a ses propres prisonniers : unifier.
- Vérifier que le correctif spell_button (clamp 0,999, agent Tocsin) supprime bien toute erreur « triangulation failed ».
- [~] Boss trop sombres sous l'éclairage de nuit. Sonneur FAIT (C7E lisible, BODY_GAIN retiré). Cerf TRANCHÉ : C7D n'a pas éclairci le corps -> palliatif BODY_GAIN ×1,85 + lumière [2,3;2,6;2,0] dans cerf_brain, vraie correction au re-rendu cel (consigne albédo ~90-100/255 ajoutée à `_cel_bosses_f23.txt`), puis retirer le gain. Tisseuse et Cèdre-Ermite aussi sombres de nuit (accent menthe seul lisible) : à traiter au re-rendu cel.
- [x] FAIT (22/10 soir) Sonneur : télégraphe rouge dessiné par-dessus le boss (`EnemyTelegraph.set_in_world`, z -1 sous les corps) ; boulons échelle 1,0, éclair pleine hauteur, anneau glas_wave, steam_jet (C7e). Reste général : les télégraphes des autres grands boss (racines/fils Tisseuse et Cèdre) couvrent encore les corps -> `set_in_world(true)` au cas par cas.
- Audio : AU1 en groupe 11 ; AU2/AU3 en groupes 12-13 (sounds.json partagé -> séquentiel) : la file en cours ne connaît que les groupes 1-11, RELANCER night_queue.sh après « FILE TERMINÉE ». Rictus n'a pas de sons propres non plus (lot à faire).
- ÉQUILIBRAGE (après le socle commun) : rapport balance_report.md + balance_recommandations.md. Décision orchestrateur : garder le ressenti d'Ardent (débutant, kite) mais le ramener un peu (Brasier/Nova légèrement) ET remonter le DPS cible unique des 6 nouveaux (+25-35 %) ; réduire la punition de la mêlée (dégâts subis ×2-5) par armure/réduction pendant les actions de mêlée ou meilleurs outils défensifs ; Tocsin : auto-cast des bottes bloqué par les deux bras ; Averse : économie d'eau (ultime jamais lancé) ; Avare : plancher à 0 or ; Bourbe : familiers qui provoquent les boss. Revalider par balance_sim.py, cible ±20 % d'Ardent.
- Brancher le lot U1 (jauge de ressource) dans resource_gauge.gd à la livraison.
- Équilibrage : agent lancé après le socle commun.
- Passe rendu FAITE (Moyen sans HDR : image 4,57 -> 2,95 ms terrasses). enemies_perf FAIT (passe Director : resolve sauté loin des murs ; machine calme B 1,45 -> 1,09 ms).
- Lisibilité LDR (Moyen) : remplissages translucides des télégraphes plus sombres, vide hors carte des terrasses sombre en LDR (stage_map).
- Budget textures FAIT : APK estimé 389 -> 274 Mo, GPU 5,9 -> 1,5 Go ; importer_defaults ajouté à project.godot. Palier 2 (APK ≤ 200 Mo) : re-rendus Codex à la taille d'affichage (crue_ring ~800 px, puddle_mirror ~416 px, couches de Tocsin rognées par membre ; brasier/nova d'Ardent à re-rendre PLUS grands, 64 px/u) + recompression audio (67 Mo). Lot à écrire : « R1 tailles d'affichage ».
- Avant la relance de la file (groupes 12-13) : ajouter `python art/tools/texture_budget.py --apply-policy` avant le `--import` de night_queue.sh (ne PAS éditer le script pendant qu'il tourne).
- IA Reclus + Semeur FAITES. Contrats FAITS (consolidation 22/10) : `SpellCaster.silence(s)`, `AmbianceManager.map_lights()`, seuils 70/35 du Semeur par `Balance.boss_phase`, test d'angle des rayons déterministe ; APIs publiques dans game/CONTRACTS.md. Reste : tocsin_kit `SpellCaster._remaining` -> `cooldown_remaining` FAIT (agent API boss, `has_slot`). Balayage : art/tools/night/test_sweep.md.
- Mémoire des boss ×0,5 (profil) non implémentée.

## Vague 2 (22/10 ~13h30) : contenu boss complet
- En cours : IA des 8 boss d'étage manquants (étage 1 ox_herder, jar_bearer + vrai cerveau de l'Éclusier + mémoire des boss ; étage 2 weaver, hermit_cedar ; étage 3 crane, smelter ; étage 4 crystal_mother, deep_eel) ; bibliothèque data-driven des 19 mini-boss.
- En cours : branchement T5/RA2/AA2 ; nettoyage des contrats + passage de tous les tests.
- Briefs Codex à mettre en file à leur retour : requests_bosses1..4.md, requests_minis.md ; plus un lot audio Rictus.

## 22/10 après-midi
- Chiffres de dégâts restylés (petits, condensés, os chaud mat, contour fin) ; police finale Codex DF1 en groupe 12.
- night_queue.sh : `wait_quota` peut produire un `sleep` négatif (heure non parsée -> target 0). À la relance : borner `target - now` à ≥ 60 s (en plus d'apply-policy avant --import).
- Bulles de description des sorts (survol PC / clic long mobile) : agent en cours.
- Question joueur : test 2D animé (Ardent + monstres) pour comparer le ressenti avec le rendu 3D.
- Si le joueur préfère le cel : passage de TOUT le jeu en cel (personnages, monstres, boss, décors ?). Rappel : le jeu est déjà en sprites 2D pré-rendus ; le gain mobile viendrait de l'abandon des normal maps/éclairage 2D et de textures plus légères, pas du passage 3D->2D.
- Budget textures mobile 207 Mo > 180 (après T5/RA2/AA2, Averse, Bourbe, boss). Pistes : lot R1 (groupe 12), exclure de l'export les planches tocsin/layers/<calque>/*.png hors packed/ (~18 Mo, export_presets exclude_filter + texture_budget_test à aligner).
- Étage 2 : IA Tisseuse + Cèdre-Ermite FAITES (weaver_brain, hermit_cedar_brain). Briefs requests_bosses2.md à mettre en file. ~~FloorPlan ne tire que les boss avec sprites -> invisibles en jeu tant que l'art manque.~~ FAIT : N2C/N2D livrés et branchés (fauna.json taille/pieds recalés ; `lay_s` absent -> repli spell_a ; `ground_silk` non lu ; cocon rendu vu de dessus, à refaire en cel). floor2_boss_test + integration_test rouges à cause de MiniBossBrain (agent mini-boss).
- Étage 3 : IA Grue + Fondeur FAITES. Briefs requests_bosses3.md (C9a, C9b) à mettre en file. Ouverts : ~~obstacles dynamiques dans nav_field~~ FAIT (NavField.add_obstacle, CraneYard), étincelles du Fondeur (rayon 0,6 u, sodium), vapeur peu visible, arène à obstacle central pour la Grue.
- Étage 1 : IA Éclusier/Bouvier/Porteuse + mémoire des boss ×0,5 FAITES. Briefs requests_bosses1.md (N1c, N1d) à mettre en file. Ouverts : ~~API de poussée/ralentissement paramétré côté joueur, jarre-mère non bloquante~~ FAIT (Player.push / apply_slow, sillon -20 %, jarre-mère = StaticBody2D + obstacle NavField).
- Étage 4 : IA Mère-Cristal + Anguille FAITES. Briefs requests_bosses4.md (C8c, C8d). 
- [x] FAIT (22/10) agent « API publiques boss » : Player.push / move_swept / apply_slow (Tisseuse -40 %, Bouvier -20 %), EnemyProjectilePool.kill_in_circle / kill_in_segment, Enemy.add_damage_taken_mod (lampes), obstacles dynamiques NavField (conteneurs, blocs de cristal, cocons, souches, jarre-mère) + find_path, retour de l'Anguille qui contourne les murs (find_path), lac de l'Anguille sur le vrai lac (cryptes : pilier central -> vrai lac ; piliers latéraux -> lac près du pilier, rive trop loin), Semeur (noyade) et Grue (éjection) en déplacement balayé, tocsin_kit sans `_remaining`. Contrats : game/CONTRACTS.md « APIs publiques des boss ». Test : tests/boss_api_test.tscn.
- Mini-boss : 20 IA data-driven FAITES (miniboss_brain.gd, miniboss_patterns.gd, minibosses.json). Ouverts : disques du Rémouleur qui rebondissent, brouillage minimap (Nuée), effets d'eau, obstacles réels, brèches de chaînes, statuts sur projectiles, sprite mist_wolf_cub, corps empruntés sombres (héron, loup, chouette), sons. Lots minis -> groupe 15.
- Barres de PV optimisées : 0,247-0,257 ms (budget 0,30). À REFAIRE machine calme (aucun agent actif) : enemies_perf (A 1,195 / B 1,301 ms sous charge) + render_perf_test.
- Or/XP en collecte auto FAIT (pickup_manager, gold_carry, aimants retirés + migration). Ouverts : stat pickup_radius_mult sans effet sur or/XP (items qui la donnent encore ? nettoyer), capture de l'effet de vol à faire, avare_test 2 échecs en attente de l'agent Avare.

## MIGRATION CEL (décision du joueur 22/10/2026 soir : « le rendu cel-shadé est top, on part là-dessus pour tout »)
- Règle : art/briefs/STYLE_cel.md (réglages exacts de CS1) ; module partagé art/tools/cel/cel_style.py (install / toon_materials / cel_passes / quantize_normal_files / archive_folder / check_sheet / contact_pair ; testé en Blender 5.2 --background sur swarm_tier1 : encre, 3 tons, ≤ 13 normales, accent). STYLE.md porte l'en-tête « rendu CEL ».
- Code FAIT : `RenderStyle.DEFAULT = cel` (réglage absent ou réinitialisé -> cel ; libellés Réglages « Cel-shadé » / « 3D (ancien) » ; F7 toujours actif) ; le repli sur l'original reste automatique tant qu'un dossier `_cel` manque. Un joueur qui avait sauvé « 3d » explicitement le garde (F7 ou Réglages).
- Consignes EN ATTENTE mises au cel (ligne « RENDU CEL OBLIGATOIRE » + profil) : groupe 12 R1, F4, F4P, C8A, DF1 (décision : police en profil 'ui', liseré à l'encre cel) ; groupe 13 F5, F5P, F5V, C8B ; groupe 14 HB1 (profil 'ui'), N1C, N1D, N2F, N2G (re-rendent AUSSI en cel les planches N2c/N2d du même boss pour ne pas mélanger), C9A, C9B, C8C, C8D ; groupe 15 M1A, M3A (+ anim `disc` du Rémouleur), M4A (+ anim `bone_pile`), M4B, M5FX, **M6FX** (nouveau : obstacles ice_block/rock dans les .tres de frost_bear/stone_colossus, textures zone_water/zone_bubbles/chain_link ; branchement MiniFx WATER/CHAIN à coder). Audio AU2/AU3 inchangés. Les lots du groupe 11 en cours (C7d, C7e, N2c, N2d, N3e, F3p, T6, AV3, P1, U1) sortent encore en 3D : repris par les lots CEL ci-dessous.
- **Re-rendu de l'existant : 18 lots `_cel_<famille>` en groupes 16-20 de queue.txt** (écriture DIRECTE dans les dossiers d'origine, contrat identique, archive 3D une fois dans `art/archive_3d/sprites/` hors projet Godot) :
  - 16 : heroes_a (Ardent depuis ardent_cel + portrait, Rictus + effets + portrait), monsters_f1 (4 monstres de base, dont 2 copiés de CS1), terrain_f1 (terraces/iso), props_core (coffres, pickups, capsule, piliers, téléporteur, éclat de braise) ;
  - 17 : heroes_tocsin (planches + calques/packed), heroes_c (Averse, Arpenteuse), heroes_d (Avare, Rainette), heroes_e (Bourbe, Montreur) ;
  - 18 : minis_a (frost_bear, stone_colossus, bramble_queen, brood_mother), minis_b (mist_wolf(+cub), lantern_owl, moss_mantis, ash_lord, rust_archon), bosses_f1 (Éclusier), monsters_f23 (_moss, _rust), terrain_f23 (fog_forest/iso, rust_city/iso) ;
  - 19 : bosses_f23 (Cerf C7b+C7d, Sonneur C7c+C7e), props_biomes (fog_forest, rust_city), icons (items, sorts, cadres de rareté, dés, pictos HUD) ;
  - 20 : ui (kit DA, cartes, menus, invites, jauge), vfx (corps solides seulement).
  - Laissés tels quels (décision) : ambiance/* (pluie, brume, lumière, particules : le cel n'apporte rien), VFX de lumière pure, fx/elites, tilesets plats 256² (repli), props 55° et props/rain non référencés (à supprimer plutôt qu'à re-rendre ; à confirmer), montreur/string_tile, ombres de contact.
  - **RELANCER night_queue.sh après « FILE TERMINÉE »** : la file en cours a lu sa liste de groupes au démarrage (16-20 inconnus). Avant la relance : `python art/tools/texture_budget.py --apply-policy` avant le `--import` et borne de `wait_quota` (voir plus haut).
- Estimation Codex : 25 lots visuels en attente (groupes 12-15, dont M6FX) + 18 lots CEL = 43 lots ; la nuit du 22/10 a passé ~40 lots par fenêtre de quota (~5 h) avant épuisement ; les lots CEL sont plus lourds (re-rendus complets, Tocsin surtout). Prévoir **2 fenêtres de quota (≈ 1 nuit) pour 12-15 et ≈ 1 à 1,5 nuit pour 16-20**, soit ~2 nuits au total.
- **Bascule finale** (quand les 18 lots CEL sont livrés et vérifiés) : (1) supprimer `characters/ardent_cel`, `monsters/swarm_tier1_cel`, `monsters/brute_tier3_cel` (et tout autre `*_cel`) ; (2) retirer l'interrupteur : `RenderStyle` (resolve devient l'identité, puis suppression de la classe et des appels dans EnemyVisual / EmissiveOverlay / Player), F7, l'entrée « Style de rendu » des Réglages, `[graphics] render_style` de GameSettings, la section « Style de rendu 3D / cel » de game/CONTRACTS.md, render_style_test ; (3) garder `art/archive_3d/` hors export (il est hors de game/, rien à faire) ou l'effacer après une semaine sans retour arrière ; (4) texture_budget.py + texture_budget_test, sprites_test, integration_test.
- **Gain mobile mesuré (texture_budget.py, 22/10 soir)** : textures mobiles 214 Mo (APK estimé 322 Mo) dont diffus 98,1 / `_n` 82,8 / `_e` 25,9 Mo ; VRAM estimée 1,89 Go dont `_n` 0,59 Go. Sur le trio CS1 (même contenu), cel vs 3D : `_n` quantifiés **−38 %** (3,55 -> 2,21 Mo), diffus −5 % (3,58 -> 3,41), `_e` −3 %.
  - Migration cel avec `_n` quantifiés (plan actuel) : `_n` des familles re-rendues 79,7 Mo × 0,62 et diffus 84,5 × 0,95 -> **≈ −35 Mo** ; + suppression des 3 dossiers `_cel` (7 Mo) -> textures ≈ 172 Mo (sous le budget 180), APK ≈ 280 Mo.
  - Option « cel sans normales » : en cel les lumières 2D éclairent déjà en aplats ; `NormalMaps` ignore un `_n` absent sans erreur et la qualité Bas les coupe déjà (`normal_maps`). Exclure `*_n.png` de l'export mobile retirerait **82,8 Mo** de textures mobiles (et ~0,59 Go de VRAM estimée) : textures ≈ 120 Mo, APK ≈ 230 Mo. À trancher par le joueur après un A/B en jeu (Réglages > qualité Bas = sans `_n`, sur les sujets déjà en cel) ; les lots continuent de livrer des `_n` quantifiés (les retirer plus tard ne demande aucun re-rendu).
  - **TRANCHÉ ET FAIT (joueur, 22/10/2026)** : plus aucune normal map. 932 `_n.png` (230,6 Mo de PNG) déplacés vers `art/archive_normals/` (outil `art/tools/archive_normals.py`), 96 `.tres` réécrits (AtlasTexture directement sur le diffus), `NormalMaps` réduit à l'émission, réglage Quality `normal_maps` retiré, briefs 15-22 / `_cel_*` et `_codex_eco.txt` mis à jour (`cel.install(profil, normals=False)`). Textures mobiles mesurées ensuite : 181 Mo (lots du groupe 14 en cours).
- Averse refonte eau FAITE. _av4 (cel Crue/Flaque) en groupe 21 (après R1) : RELANCER night_queue.sh après la fin de la file en cours (elle ne lit queue.txt qu'au démarrage) ; y ajouter aussi _ic1, _sa1, _ar1 à leur livraison.
- Menus vague 3 FAITS. À brancher à la livraison MN1 : feu de camp (menu_background.gd) + pastilles de difficulté (character_card/sheet). Icônes Taliant/Vigie : dans _vg2 / lot Taliant.

## Groupe 11 branché (22/10 soir)
- [x] C7D Cerf, C7E Sonneur, N2C Tisseuse, N2D Cèdre-Ermite, T6 Tocsin, N3E monstres `_rust` (chargés par fauna.json, biome_fauna_test OK), F3P props Cité (props.json posé ; réverbères `steam_lamp_se/sw` posés au pied de chaque lumière `steam_lamp` du canal : `StageMap.add_light_prop` appelé par `AmbianceManager._build_map_lights`), P1 portrait Ardent (pris automatiquement par CharacterCard/HUD), AU1 (audio_test OK). Non branchés ici : AV3 (agent Averse), U1 (agent HUD).
- Budget : texture_budget_test FAIL (1) textures mobiles 236 Mo > 180 (bosses 58/45 Mio, monstres 16,1/12) : attendu, résorbé par la migration cel + R1.

## Après chaque groupe Codex (22/10/2026 soir, orchestrateur)
- `python art/tools/archive_normals.py --apply` (les lots lancés avant la décision livrent encore des `_n`), puis `python art/tools/halve_emission.py --apply` (filtre `peak` par défaut), puis `--import`.
- Après le groupe 14 : passer `normals=False` par défaut dans `art/tools/cel/cel_style.py`.
- Lots coupés par le quota, `.tres` allégés en attendant : C8c (crystal_mother), C8d (crane), C9b (smelter). Ils regénèrent leurs `.tres` complets à la reprise.
- Émission du cerf et du weaver ternie par une réduction Lanczos sans copie : le re-rendu cel (groupes 18-19) la rétablit.
