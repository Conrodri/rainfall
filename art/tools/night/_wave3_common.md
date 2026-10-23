# Contrat commun vague 3 (22/10/2026 soir, retours de partie du joueur)

Projet Godot 4.7.2 « Rainfall » : C:\Users\const\Documents\Rainfall\game. Lis d'abord CLAUDE.md (racine), game/CONTRACTS.md, art/tools/night/PLAN_SUITE.md (fin).
Godot console : C:\Users\const\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe. Tests : `--headless --path game res://tests/X.tscn` -> RESULT: OK. `--import` après un nouveau class_name. ~12 agents tournent en parallèle : RAM limitée, un seul Godot à la fois par agent, pas de boucle de tests inutile.

## Décisions du joueur à connaître
- DA : le rendu CEL-SHADÉ (lot CS1, dossiers `_cel`, interrupteur RenderStyle / F7) est validé : TOUS les assets passent en cel. Tout nouvel asset demandé à Codex est en cel (voir art/briefs/STYLE_cel.md quand il existe, sinon le brief art/tools/night/_cs1.txt et son rapport _logcs1.txt.last.txt).
- Ramassage : or et XP sont récupérés AUTOMATIQUEMENT quand ils tombent (portée infinie), sauf ressources propres aux personnages (pièces de l'Avare, bras/jambes de Tocsin, etc.).
- Averse : plus de temps de recharge sauf Flaque miroir ; l'eau est le seul garde-fou.

## Règles
- Fichiers partagés (player.gd, hud.gd, spell_caster.gd, spell_button.gd, enemy.gd, main.gd, characters.json, profile.gd…) : d'autres agents les éditent EN MÊME TEMPS. Outil Edit par remplacement exact, relis juste avant, ajouts génériques minimaux, jamais de réécriture complète. characters.json : petit script Python lecture-modif-écriture immédiate, uniquement ton entrée.
- Interdit : .blend, assets livrés (lecture seule), user://run_save.json réel, settings.cfg réel, CLAUDE.md, lancer Codex (écris les briefs ; l'orchestrateur les met en file).
- Visuels finaux = Codex dans Blender (cel). En code : replis simples seulement.
- Briefs Codex : format des consignes art/tools/night/_c8a.txt / _n1c.txt (paragraphe « LOT XX », « DA OBLIGATOIRE » cel, « Vérification »), planches ≤ 4096 px, cellules à la taille d'affichage.
- Vérifie tes changements : test dédié + non-régression des tests touchés + integration_test. Capture et regarde les images pour tout changement visuel (`--write-movie <scratchpad>/x.png`).
- Rapport final court en français : fait, fichiers partagés touchés, tests, captures, briefs Codex, points ouverts.
