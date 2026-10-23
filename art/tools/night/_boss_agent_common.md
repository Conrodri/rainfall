# Contrat commun des agents « boss » (22/10/2026, après-midi)

Projet Godot 4.7.2 « Rainfall » : C:\Users\const\Documents\Rainfall\game. Lis d'abord CLAUDE.md (racine), game/CONTRACTS.md, docs/Design_Etages.md (ton biome), docs/Design_Boss_Cartes.md, art/briefs/bosses_etage.md, game/data/floors.json et game/data/fauna.json.
Godot console : C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe. Tests : `--headless --path game res://tests/X.tscn` -> RESULT: OK. `--import` après un nouveau class_name.

## Modèle à suivre exactement
- Boss d'étage : cerf_brain.gd, sonneur_brain.gd (+ sonneur_storm.gd), recluse_brain.gd, rain_sower_brain.gd ; branchement par `brain` dans enemy.gd ; Balance.BOSS_ATTACK_COEF / boss_attack_coef() / BOSS_PHASE_DAMAGE_TAKEN ; helpers EnemyVisual (play_special, current_anim, current_frame, body_sprite) ; formes provisoires recluse_fx.gd ; dégâts à la frame d'impact ; télégraphes lisibles orientés vers le joueur ; 3 phases (seuils du design, sinon 66/33) avec mise en scène ; lumières pensées pour la nuit (leçon du sonneur : jamais un corps presque noir).
- Tests modèles : cerf_boss_test, sonneur_boss_test, recluse_boss_test, rain_sower_boss_test, floor2_boss_test, floor3_boss_test.
- Art absent : replis propres et chemins/anims attendus enregistrés dans fauna.json `boss_sprites` (l'art se branche seul). Briefs Codex au format de art/tools/night/requests_bosses45.md (règles communes + un lot par boss : planches ≤ 4096 px, cellules à la taille d'affichage réelle, boss lisible la nuit), écrits dans le fichier indiqué par ta mission. Ne lance PAS Codex.

## Périmètre et concurrence
- À toi : game/scripts/enemies/<id>_brain.gd et <id>_*.gd, tests <id>_boss_test, tes entrées dans Balance (ajouts), tes entrées fauna.json/floors.json (ajouts), ton fichier de briefs.
- Partagés (enemy.gd, enemy_visual.gd, balance.gd, fauna.json, director.gd) : d'autres agents les éditent EN MÊME TEMPS (3 autres agents boss, un agent mini-boss, un agent de nettoyage qui ajoute SpellCaster.silence et remplace des accès privés). Ajouts seulement, outil Edit avec remplacement exact, relis le fichier juste avant. Pour un nouvel effet joueur (silence, etc.), utilise l'API publique si elle existe, sinon signale le besoin.
- Interdit : kits de personnages, cartes/stage_map, .blend, user://run_save.json, settings.cfg, CLAUDE.md.
- RAM limitée : un seul Godot à la fois.

## Vérification
Tes tests + cerf_boss_test, sonneur_boss_test, recluse_boss_test, rain_sower_boss_test, le test de boss de ton étage (floorN_boss_test, crée-le s'il manque), run_flow_test, sprites_test, biome_fauna_test, integration_test -> RESULT: OK. Capture chaque combat, regarde les images, corrige la lisibilité.

## Rapport final (court, en français)
Attaques et phases de chaque boss, fichiers partagés touchés, tests, captures, chemin des briefs Codex, points ouverts.
