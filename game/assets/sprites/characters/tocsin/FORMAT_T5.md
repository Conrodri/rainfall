# Tocsin : contrat des ressources T5

## Chargement et placement
Lire `layers_order.json` (format_version 2). `layers` contient exactement les sept
modules. `layer_resources[layer].diffuse_normal` est un SpriteFrames ; `emission`
est son SpriteFrames lumineux synchronisé, à multiplier par la couleur/intensité
de surchauffe (1 à 2). `_e` est un masque coloré de braise, pas une normal map.
Chaque frame diffuse est AtlasTexture -> CanvasTexture(diffuse_texture,
normal_texture). CanvasTexture ne possède pas de propriété emission_texture :
afficher la ressource emission dans un sprite superposé avec le matériau du jeu.

Directions en lignes : e, se, s, sw, w, nw, n, ne. Noms exacts : `<anim>_<dir>`.
`resource_animations.json` inventorie chaque animation de chaque .tres ; les VFX
à direction unique utilisent leurs noms existants, sans suffixe ajouté.
Cadence et loop sont ceux des SpriteFrames ; ne pas imposer une cadence globale.
Synchroniser animation, frame et progression de tous les sprites visibles.
`animations[anim]` du manifeste indique les modules autorisés pour cet état.
Les membres absents sont masqués ; neck_steam apparaît seulement sans tête.
`orders[dir]` donne l'ordre arrière vers avant : indice croissant = z_index local.

Toutes les frames logiques font 192 x 192, pivot au sol (96, 136.32), identique
au rig Ardent. Sprite centré : offset = (0, -40.32) pour placer ce pivot à
l'origine du parent ; sprite non centré : position = (-96, -136.32).
Élévation CREA 30 degrés, R = 64*sqrt(2) = 90.51 px/u. Aucun agrandissement
des cellules : conserver l'échelle du rig, sans ajouter de marge de rendu.

## Atlas et conservation du cadre
Les planches contractuelles `<anim>.png`, `_n.png`, `_e.png` restent disponibles
en grille 192 ; les .tres des modules utilisent `layers/<layer>/packed/`.
Le rognage est identique pour diffuse, normal et émission. AtlasTexture.region
est le rectangle physique ; AtlasTexture.margin = (crop_x, crop_y,
192-region_width, 192-region_height) reconstitue le cadre logique complet.
Ne pas appliquer un deuxième décalage de rognage dans le code.
`atlas_manifest.json` : clés `layer/anim`, size, source_size, passes, frames.
Chaque frame donne direction, frame (base zéro), crop (x0,y0,x1,y1), region
(x,y,w,h) et margin (x,y,total_horizontal,total_vertical).
Les frames identiques peuvent partager un rectangle. Taille maximale 4096.

## Événements et assets séparés
Auto attack : 6 frames, impact index 3 = N/2 (base zéro).
throw_arm_l/r et throw_leg_l/r : libération index 2 ; throw_head : index 3.
death et cast/cast_ult sont fournis en huit directions. Utiliser les événements
du gameplay pour masquer les membres ; aucune rotation/pivot de membre à calculer.
fall se joue à l'envers pour se relever. Les membres détachés, head_blast,
head_blast_top et regen_rivets sont des ressources séparées, jamais des modules.
Les ressources tocsin.tres et tocsin_emission.tres sont le repli corps complet ;
ne pas les superposer au rendu modulaire. Les icônes et portraits T4 sont conservés.

## Reconstruction et vérification
`python art/tools/night/t5_build.py` reconstruit les atlas depuis les planches
existantes et les .tres depuis les sauvegardes t_out/t5/source_resources.
Le contrôle reconstruit chaque frame et compare alpha et RGB visibles sur les
trois passes. Les pixels RGB entièrement transparents ne participent pas.
Audit Godot : `--headless --path game --script` suivi du chemin ABSOLU vers
`art/tools/night/t_out/t5/verify_resources.tres` (ce fichier est hors de res://).
Les sept modules sont complets et isolés ; l'occlusion est déterminée par
l'ordre de profondeur des racines du rig, sans découpe holdout dynamique.
