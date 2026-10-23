# Brief : boss d'etage (3) - source : docs/Design_Boss_Cartes.md §3 et §5.3 ; style : STYLE.md

Regles : Blender 5.2 en ARRIERE-PLAN uniquement (`blender.exe --background --python art/tools/bosses/<script>.py`), jamais la fenetre interactive. Tout est modelise (primitives, courbes, booleens, modificateurs) et rendu dans Blender (Eevee, film transparent, Standard). Python hors Blender = assemblage/rognage PIL seulement (art/tools/bosses/pack_boss.py).
Camera/lumiere/ombre : exactement STYLE.md (ortho, elevation 35 deg (MISE A JOUR 21/10/2026, cf. monsters.md ; ex-55), Sun haut-gauche chaud, fill froid, pas d'ombre au sol, rendu 2x puis LANCZOS). Les directions = rotation du MODELE autour de Z.

## Frames
- Boss : frame carree 256 px (rendu 512). Pied/centre de masse au sol a ~70 % de la hauteur de frame, marges >= 4 px. Silhouette monumentale, lisible a distance.
- Directions de marche : 4 (`e, s, w, n`). Idle, attaques, transitions, mort : une seule direction `s` (face camera) sauf mention.
- Sheets : `<anim>.png` ; lignes = directions, colonnes = frames. Noms SpriteFrames `<anim>_<dir>` ; anims sans direction : suffixe `_s`.
- Rendus bruts : art/renders/bosses/<boss>/<anim>/<dir>_<ff>.png ; .blend : art/blender/bosses/<boss>.blend ; sortie : game/assets/sprites/bosses/etage/<boss>/ (PNG sheets + <boss>.tres SpriteFrames texte, AtlasTexture, 12 fps idle / 14 fps walk / 12 fps autres, loop uniquement idle/walk/props en boucle).

## Phases (doivent se VOIR sur le sprite : variantes de modele, pas seulement de la couleur)
Chaque modele a un parametre `phase` (1,2,3). Rendre `idle` et `walk` pour les 3 phases : `idle_p1/idle_p2/idle_p3`, `walk_p1/p2/p3` (p1 = base). Les attaques/sorts/transitions/mort se rendent avec la phase indiquee dans le tableau.

## Animations communes par boss
| anim | frames | phase du modele |
|---|---|---|
| idle_p1, idle_p2, idle_p3 | 6 | 1,2,3 |
| walk_p1, walk_p2, walk_p3 (e,s,w,n) | 8 | 1,2,3 |
| auto (prepa lisible : membre en arriere puis frappe) | 6 | 1 |
| spell_a | 8 | 1 |
| spell_b | 8 | 1 |
| trans_p2 (passage 70 %) | 8 | 1->2 |
| trans_p3 (passage 35 %) | 8 | 2->3 |
| death | 10 | 3 |

## Couleurs d'accent (hors palette de telegraphes rouge/orange/bleu givre/vert poison reservee au sol)
Corps sombres et sourds ; accents lumineux seulement sur les sources de lumiere.

## Boss
### eclusier (3.5 u) - extras : wheel (roue de vanne) en boucle 8 frames ; wave (vague de ligne) 8 frames ; geyser 12 frames boucle ; pose `anchored` (phase 3, 1 frame + deja dans idle_p3)
Corps de bois noir (#2a2018) cercle de bronze (#8a6a3a), roue de vanne dans le dos (grande, rayons, lisible), bras-portes (planches massives). p2 : eau peu profonde autour des pieds/ruisseaux, vanne entrouverte qui fuit, algues. p3 : roue gonflee/tournante, planches fendues, jets d'eau, ancre au sol (jambes ecartees, corps bas).
### cerf (3.2 u) - extras : antlers (couche emissive SEULE sur fond transparent, pour pulser en code) ; wisp 6 frames + wisp_explode 8 ; vanish 8 + reappear 8 ; brume : rien
Cervide sombre aux longues pattes, bois en lanternes allumees (#9CF0C8). p2 : toutes les lanternes plus grandes/allumees, brume au sol autour des pattes. p3 : lanternes eteintes (bois gris pale, braise faible), silhouette fantomatique plus translucide aux bords.
### sonneur (3.8 u) - extras : bell_ring 6 frames (cloche qui vibre) ; lightning x4 variantes (2 u x 12 u) ; bolt (boulon 32 px) ; steam_vent (jet de vapeur 1u x 6u, 8 frames boucle) ; layer `boiler_open` (couche chaudiere ouverte)
Tete-cloche bronze vert-de-gris (#5f8f80), corps de chaudiere rivetee rouille, bras-marteaux, paratonnerre sur la cloche. p2 : paratonnerre qui crepite (arcs bleu-blanc), rivets brillants. p3 : chaudiere ouverte (fissure/panneau arrache, lueur orange interne + vapeur).

## Traces au sol (sprites separes, fond transparent, 1 u = 64 px)
- eclusier : `ground_geyser` (cercle 2 u = 128 px, base de geyser fixe 12 frames boucle, fontaine vue de dessus 3/4), `ground_water` (flaque/eau peu profonde tileable 128 px, 4 frames), `ground_wave` (4 u x 18 u en 128x576 par frame, 8 frames).
- cerf : `ground_mist` (nappe de brume 256 px, 6 frames boucle, translucide #B8C8C0), `ground_wisp_trail` (feu follet fixe 64 px, 6 frames).
- sonneur : `ground_lightning` (cercle 2 u impact au sol + eclair 4 variantes), `ground_scorch` (marque brulee 128 px, 4 variantes), `ground_steam` (jet de vapeur 64x384, 8 frames boucle).

## Eclairage 2D dynamique : cartes de normales et masques d'emission (OBLIGATOIRE)
Pour CHAQUE sheet/sprite livre `<f>.png`, livrer aussi `<f>_n.png` (normal map en espace ecran, meme decoupage/taille, pass Normal Blender convertie : R=x droite, G=y haut ecran, B=z vers camera, encodee 0..255 ; fond transparent -> (128,128,255,0)) et `<f>_e.png` (masque d'emission : couleur emissive seule sur noir/transparent, pour lanternes du Cerf, cloche/foudre/paratonnerre/vapeur chaude du Sonneur, eau lumineuse/reflets de l'Eclusier, braises de la chaudiere). Rendu dans Blender par passes (Normal pass + materiaux emissifs isoles), PIL seulement pour l'assemblage/encodage. Le .tres reste base sur `<f>.png`; ajouter dans chaque dossier un fichier `lighting.md` ou commentaire du .tres decrivant la convention `_n`/`_e`.
