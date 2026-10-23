# Rainfall - Guide de style des assets

## RENDU CEL (décision du joueur, 22/10/2026) — PRIORITAIRE, voir art/briefs/STYLE_cel.md
« Le rendu cel-shadé est top, on va partir là-dessus pour tout le reste des assets. » Tout asset (nouveau ou re-rendu) est rendu en **cel** avec le module partagé `art/tools/cel/cel_style.py` (réglages du lot CS1 : 3 tons par matière en rampe constante, encre brun-noir intérieure ~1,5 px à la taille d'affichage, émissif conservé, ombres relevées pour la nuit). **Plus de normal maps** (décision du joueur, 22/10/2026, budget mobile 180 Mo) : aucun `<f>_n.png` produit ni livré, `cel.install(profil, normals=False)` ; anciens `_n` archivés dans `art/archive_normals/`. Toute mention de `_n` / « normal map » plus bas est historique. Le cel remplace le **shading** décrit plus bas (grain PBR, dégradés, « surfaces lisses » bannies) ; les modèles, matières (source des teintes), palette, accent émissif, caméra iso, tailles, nommage et règles d'optimisation ci-dessous restent valables. Les sections suivantes sont l'historique de la DA, conservé tel quel.

## DA OFFICIELLE (décision du joueur, 21/10/2026) : style « sérieux » des boss d'étage, pour TOUT
Référence absolue : les 3 boss d'étage de Codex (game/assets/sprites/bosses/etage/{cerf,sonneur,eclusier}/idle_p1.png ; recettes dans art/tools/bosses/sonneur.py, boss_common.py). Fiche détaillée : art/briefs/STYLE_boss_da.md. S'applique aux personnages, monstres, mini-boss, terrains, props, pickups, coffres, VFX et UI. Le style « jouet » (pastel, bulles, blocs arrondis, gros yeux ronds, aplats lisses) est banni.
- Matières PBR nommées et usées : rouille #6B3A22 / rouille sombre #3E2419, fer noir #2B2A29 (métal 0,6, rugosité 0,5), bronze vert-de-gris #5F8F80, bronze clair #8DBBA8, laiton/rivets #A8946E, cuir, pierre taillée, bois sombre, os, cendre ; grain de bruit dans chaque matière, saleté dans les creux, biseaux « arêtes usées » sur les arêtes, beaucoup de petites pièces (rivets, sangles, câbles, cannelures).
- Lumière de studio sombre : monde ~18 % de gris, soleil chaud orangé haut-gauche (#FFC287, énergie ~2,5, angle 0,15 = ombres nettes), fill froid bleuté (#80A8D9) faible à droite ; ombres internes profondes, valeurs globales basses, contraste local fort.
- Un seul accent émissif par créature/objet, en petites touches (yeux, braises, lanternes, fissures), livré dans _e pour que le jeu pilote la lumière.
- Silhouettes crédibles et anguleuses, asymétries, éléments qui débordent ; proportions réalistes (pas de grosse tête), lisibilité par la silhouette et le contraste, pas par la couleur saturée.
- Terrains et props : mêmes matières usées et même lumière ; sols sombres et texturés (pierre mouillée, terre, métal rouillé), flaques réfléchissantes ; rien de propre ni de saturé.
- En jeu (code Godot) : éclairage profond et marqué — ambiance sombre, flaques de lumière franches autour des sources (feu, lanternes, piliers, sorts), ombres portées longues, glow HDR sur les émissions, contraste fort entre zones éclairées et zones sombres.

## OPTIMISATION ET OMBRES CUITES (demande du joueur, 21/10/2026) — s'applique à tout nouveau rendu
- Modèles Blender : polycount juste nécessaire à la silhouette à la taille finale (décimer/retopo ce qui est sous le pixel, pas de subdivision invisible, instances liées pour les pièces répétées) ; matériaux procéduraux bakés en textures si le rendu est lent ; Eevee à échantillons modestes.
- Ombres et lumière CUITES dans les sprites : occlusion ambiante, ombres internes, cavités et ombre de contact sont dans le diffus (bake AO/ombres Blender), pour que le jeu n'ait pas besoin d'ombres dynamiques sur les objets. Les props et murs livrent en plus un `<f>_shadow.png` : leur ombre portée au sol (soleil DA haut-gauche → ombre vers bas-droite écran), en niveaux de gris/alpha sur fond transparent, même cadrage, pour que Godot l'affiche comme décalque bon marché à la place d'une LightOccluder2D. Créatures : ombre de contact commune `shadow_blob_256` (pas d'ombre par frame).
- Sprites légers : frames rognées au plus juste (marges 4-8 px), atlas compacts, pas de frame dupliquée ; résolution = celle du doc, jamais plus ; PNG optimisés (compression maximale, sans métadonnées). Aucune normal map (22/10/2026) ; masques _e seulement là où ils servent (pas de _e entièrement noir : ne pas le livrer, le noter dans le manifeste).
- **RÈGLE DURE TEXTURES (budget mobile, 22/10/2026)** : aucune planche > 4096 px de côté ; découper en plusieurs atlases ; cellules à la taille d'affichage réelle (la cellule fait la taille à laquelle la frame est affichée en jeu au zoom par défaut, au px/u du jeu — 64 px/u — ; un VFX de rayon r u tient dans une cellule d'environ 2r × 64 px + 8 px de marge, jamais 2-3× plus grand). `_e` est découpé exactement comme le diffus (aucun `_n`), et le .tres pointe chaque frame vers son atlas. Contrôle avant livraison : `python art/tools/texture_budget.py` (aucune ligne « > 4096 », budgets de catégorie respectés) et `game/tests/texture_budget_test.tscn` → RESULT: OK.

## Rendu
- **CAMÉRA ISOMÉTRIQUE (21/10/2026, remplace les règles de caméra ci-dessous en cas de conflit)** : orthographique dimétrique 2:1 façon Dofus, élévation 30° (rotation X = 60° depuis la verticale), lacet 45° par rapport aux axes du monde (le sol carré devient un losange 2:1 ; tuiles en losange). Détails et tailles : docs/Design_Isometrique.md (à venir). Les créatures restent rendues en tournant le MODÈLE (8 directions écran), seule l'élévation passe de 35° à 30°.
- HD lisse pre-rendu Blender, Eevee, PNG RGBA fond transparent (film transparent, Standard view transform, pas de Filmic/AgX qui delave).
- Camera orthographique, vue de dessus 3/4 : elevation 35 deg au-dessus de l'horizon (rotation X = 55 deg depuis la verticale ; MISE A JOUR 21/10/2026 : l'ancien 55 deg etait trop haut, personnages illisibles ; viser le visage, le torse et les jambes visibles, tete un peu plus grande), azimut fixe, regardant vers le nord (le haut de l'ecran). Les 8 directions sont obtenues en tournant le MODELE autour de Z, jamais la camera.
- Lumiere principale (Sun) en haut a gauche de l'ecran, tiede (#FFE2C0), energie moyenne ; lumiere de remplissage froide faible (#8FA8C8) en haut a droite/arriere ; ombre douce courte vers bas-droite. Pas d'ombre portee projetee au sol dans le PNG (le jeu ajoute la sienne) : plan d'ombre desactive.
- (Ancien, remplacé par la DA officielle ci-dessus en cas de conflit) Contour leger optionnel (Freestyle ou coque inversee), 1-2 px, couleur sombre teintee (#1a1620), jamais noir pur.
- Anti-aliasing actif, rendu a 2x puis reduit (LANCZOS) a la taille finale.

## Palette
Univers pluvieux, melancolique : sol sombre bleu-gris, personnages lisibles dessus, braises chaudes en contraste.
- Gris pluie : #2B3340, #4A5565, #7C8898 ; ardoise froide : #5E7390.
- Braise / feu : #FF7A1F (vif), #FFB347 (clair), #C23B12 (profond), coeur #FFE9A8.
- Or : #F2C14E / ombre #A8741A. XP : bleu cyan #5FD4E8 / #2A8FB0. 
- Cuir/bois : #6B4A32, #3F2B1E. Chair : #D9A98A. Tissu Ardent : brun-rouille #7A3B24 + capuche #3A2A2A.
- Monstres : tons sourds (vert-gris #5B6B4F, violet fane #5A4A63) avec yeux/accents rouges ; les projectiles joueur restent plus vifs que tout ennemi.
- Saturation moderee sauf sources de lumiere/feu.

## Tailles (cote du carre de la frame, px, PNG final)
| Asset | Frame | Directions | Frames |
|---|---|---|---|
| Ardent idle / run | 192 | 8 | 8 |
| Monstre tier 1 run | 96 | 8 | 8 |
| Piece d'or | 48 | 1 | 8 (rotation) |
| Gemme d'XP | 48 | 1 | 8 (scintillement) |
| Coffres (petit/grand/legendaire) | 128 | 1 | 1 ferme + 1 ouvert |
| Eclat de braise | 48 | 1 (pointe vers e) | 4 |
Pied du personnage centre horizontalement, a ~ 70 % de la hauteur de la frame (pivot au sol), marges transparentes >= 4 px.

## Directions et nommage
- Ordre : `e, se, s, sw, w, nw, n, ne` (sens horaire depuis la droite de l'ecran). `s` = face a la camera (vers le bas de l'ecran), `n` = de dos.
- Sprite sheet : une ligne par direction (dans l'ordre ci-dessus), une colonne par frame. Fichier `<anim>.png` (ex: `run.png`), taille = (frames*cote) x (8*cote). Assets sans direction : une seule ligne.
- Dossiers : `game/assets/sprites/<categorie>/<nom>/` ; categories : `characters`, `monsters`, `pickups`, `chests`, `projectiles`. Noms en snake_case anglais (`ardent`, `swarm_tier1`, `gold_coin`, `xp_gem`, `chest_small`, `chest_large`, `chest_legendary`, `ember_shard`).
- Rendus bruts : `art/renders/<nom>/<anim>/<dir>_<frame:02d>.png` ; sources : `art/blender/<nom>.blend` ; scripts : `art/tools/`.
- SpriteFrames : `<nom>.tres`, animations `idle_<dir>`, `run_<dir>` (AtlasTexture par frame, 12 fps idle / 14 fps run, loop). Assets simples : `default`, `closed`, `open`.
