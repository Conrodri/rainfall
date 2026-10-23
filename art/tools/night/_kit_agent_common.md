# Contrat commun des agents « nouveau personnage jouable » (22/10/2026)

Projet Godot 4.7.2 « Rainfall » : C:\Users\const\Documents\Rainfall\game. Lis d'abord CLAUDE.md (racine), docs/Design_Personnages.md (la section de TON personnage + §2.6 Rictus comme modèle complet + §3), puis le code modèle : game/scripts/spells/rictus_kit.gd, game/scripts/spells/character_data.gd, game/scripts/spells/spell_data.gd, game/scripts/spells/spell_caster.gd, game/scripts/player/player.gd, game/tests/rictus_test.gd.
Godot console : C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe. Tests : `--headless --path game res://tests/X.tscn` doit afficher RESULT: OK. Après un nouveau class_name : `--headless --path game --import`.

## Enregistrement (déjà fait par l'orchestrateur)
- CharacterData.for_id(id) charge automatiquement `res://scripts/spells/<id>_kit.gd` et appelle sa `static func character() -> CharacterData`. Crée ce fichier : il active ton personnage.
- data/characters.json contient déjà ton entrée (unlocked true, hidden false, playable true, `spells: []`). Remplis SEULEMENT le tableau `spells` de TON entrée (format de l'entrée rictus : id, name, slot auto/cd/ultime, desc ; variants facultatives) avec un petit script Python qui relit le fichier juste avant d'écrire (lecture-modification-écriture immédiate, ensure_ascii=False, indent=2) : 6 agents éditent ce fichier en parallèle, ne touche jamais aux autres entrées.

## Périmètre
- À toi : game/scripts/spells/<id>_kit.gd, tout nouveau script préfixé par ton id (game/scripts/spells/<id>_*.gd, game/scripts/fx/<id>_*.gd), game/tests/<id>_test.gd/.tscn, ton entrée de characters.json (spells).
- Fichiers partagés (player.gd, spell_caster.gd, spell_data.gd, projectile.gd, zone_effect, hud.gd, light_presets.json…) : d'autres agents les modifient EN MÊME TEMPS. Préfère les hooks existants du kit (comme Rictus : blocks_slot, cast_spell, speed_mult, inertia_s, can_dodge, visual_anim…). Si un ajout partagé est indispensable : petit ajout générique et rétrocompatible avec l'outil Edit (remplacement exact, relis le fichier juste avant), jamais de réécriture complète, jamais de logique propre à ton personnage dans un fichier partagé. Un preset de lumière : ajoute une ligne `"<id>_...": {...}` dans light_presets.json par Edit.
- Interdit : .blend, assets (lecture seule : game/assets/sprites/characters/<id>/ livrés par Codex), user://run_save.json, settings.cfg réel, CLAUDE.md (l'orchestrateur le met à jour).

## Contenu attendu
- Les 4 sorts de la fiche (auto + 2 sorts à recharge + ultime), la ressource/mécanique propre, les stats de base (CharacterData : PV, vitesse, hitbox…) ; chaque valeur d'équilibrage en constante nommée du kit, cohérente avec Balance (rythme visé : monstres de base fauchés en 1-2 coups, comparable à Ardent et Rictus).
- Visuels : branche ce que Codex a livré (lis les rapports art/tools/night/_log<lot>.txt.last.txt de ton personnage et les planches _<lot>_contact.png ; inspecte game/assets/sprites/characters/<id>/ : .tres, anims, VFX, projectiles, icônes, portrait). Anims d'action via Player.play_action / action_impact_frames (frame d'impact = départ de l'effet). Lumière de sort par SpellData.light_preset (accent émissif du personnage, jamais la braise d'Ardent sauf si c'est son accent). Si un asset manque : repli propre (comme Rictus : sprite d'Ardent teinté `placeholder_tint`, contour dessiné de ZoneEffect) et liste-le dans ton rapport comme demande Codex précise (fichier, taille, frames, anims).
- Plateformes : PC (sorts 2-4 visent la souris), manette, mobile (ciblage auto) : rien de spécifique à coder si tu passes par SpellCaster / les hooks.
- Test game/tests/<id>_test.gd : chaque sort lancé, dégâts infligés, mécanique propre, ressource, anim d'action et frame d'impact, lumière, pas d'erreur de script. Puis non-régression : rictus_test, player_test, action_vfx_test, sprites_test, platform_aim_test, integration_test, save_test -> RESULT: OK (enemies_perf échoue déjà, ignore ; new_run_test est réparé par un autre agent en parallèle). Si un test échoue à cause d'un fichier en cours d'édition par un autre agent (erreur de parse hors de ton périmètre), attends un peu et relance.
- Capture en jeu (modèle : game/tests/capture_spell_fx.gd) : lance les 4 sorts, regarde les images, corrige l'échelle et la lisibilité dans la DA (sombre, PBR usé, un seul accent émissif).
- Le joueur n'est pas là pour valider : décide toi-même dans l'esprit de la fiche et surprends-le par le ressenti (impact, feedback, lisibilité).

## Rapport final (court, en français)
Ce qui marche, fichiers partagés touchés (lignes exactes), tests et résultats, chemins des captures, demandes Codex (assets manquants), points ouverts.
