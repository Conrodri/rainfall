# Lot UX-A : invites et appareils

Source : docs/Audit_UX_Ajouts_2026-11-07.md §8. Dossier : game/assets/sprites/ui/prompts/, 64 x 64 px, même style que pad_lb/pad_rb (métal sombre #2B3340/#3A4458, repère ambre, liseré sombre 2 px), face caméra, fond transparent.
Script : art/tools/ui/prompts.py (ajouter 7 entrées à ITEMS, fonctions dédiées ; relancer avec `-- pad_start pad_select ...`).

| Fichier | Description |
|---|---|
| pad_start.png | disque métal, trois traits (menu) en ambre |
| pad_select.png | disque métal, deux rectangles superposés (vue) en ambre |
| pad_dpad_lr.png | croix directionnelle, branches gauche et droite en ambre, haut/bas gris |
| pad_dpad_ud.png | idem, branches haut et bas en ambre |
| device_keyboard.png | silhouette clavier + souris, métal sombre, touches claires |
| device_gamepad.png | silhouette manette, métal sombre, deux sticks, croix, quatre boutons |
| device_gamepad_off.png | même manette, plus sombre, barrée d'une diagonale ambre-rouge épaisse |

PNG optimisés (budget mobile). Aucun texte. Les formes se distinguent sans la couleur.
