# Veillées : thèmes de l'écran titre (brief d'assets, 01/11/2026)

Catalogue : `game/data/cosmetics.json` (famille `veillee`, `target` `""`). Design : `docs/Boutique_Rubis.md` §3.4. Système : `MenuBackground` (`game/scripts/menu/menu_background.gd`) charge une vraie carte (`map_id`), place le feu de camp sur le marqueur `menu_campfire` de la carte (sinon le départ du joueur), caméra lente autour. Dev : `map_id` et le feu deviennent lus depuis l'article équipé ; une liste de props `{fichier, décalage en u depuis le feu, z}` par Veillée (valeurs §2) ; aucune collision, aucun gameplay.

## 1. Convention de chemins

`game/assets/sprites/props/menu/<id>/` :

| Fichier | Format | Rôle |
|---|---|---|
| `fire.png` | 12 frames de 256×256 sur une ligne : 3072×256 RGBA (même structure que `props/menu/campfire/burn.png`, qui fait 12 × 320) | le feu de la Veillée (brasero, cierges, seau) |
| `fire_e.png` | 1536×128 (demi-résolution) | accent du feu, seul émissif animé |
| `fire.tres` | `SpriteFrames`, animation `burn` 12 frames, 10 fps, loop (copie de `campfire.tres` à chemins et cellule substitués) | lu par `MenuBackground._build_campfire` à la place de `campfire.tres` |
| `<prop>.png` | cellule iso 128×128 ou 256×256 selon la taille (64 px/u, caméra `iso_rig` : dimétrique 2:1, élévation 30°), pivot au sol à 70 % de la hauteur, marges 4-8 px | prop statique |
| `<prop>_shadow.png` | même cadrage que le prop, niveaux de gris sur alpha, ombre portée vers bas-droite écran (STYLE.md « ombres cuites ») | décalque d'ombre |
| `<prop>_e.png` | demi-résolution, seulement si le prop émet (lanternes, cierges) | accent |
| `<anim>.png` | boucle : N frames sur une ligne, cellule 96 ou 128 | petit animé (chat) |

Profil cel `prop` (3 tons, encre 1,5 px). Aucun `_n`. Aperçu de fiche : `game/assets/sprites/cosmetics/previews/<id>.png` 256×256 (le coin de carte avec le feu et les props, rendu Blender).

Placeholder dev : dossier absent = « Feu de camp » par défaut sur la carte du jour ; l'article reste `pending`.

## 2. Les 4 Veillées v1

Décalages en u depuis le point du feu (x vers la droite écran, y vers le bas écran), z relatif au feu.

| Id | Nom | Carte (`map_id`) | Feu (`fire.png`) | Props (fichier : cellule, décalage, z) |
|---|---|---|---|---|
| `bivouac_des_cedres` | Bivouac des cèdres | `foret_brume` | feu de camp sous une bâche : bûches, flammes basses, fumée | `tent.png` : 256, (-2,5 ; -1,0), z -1 (tente de toile cirée ocre #6E5A32, piquets, cordes) + `tent_shadow.png` ; `lantern_hanging.png` : 128, (-1,6 ; -1,4), z +1 (lanterne de cuivre pendue à une branche) + `lantern_hanging_e.png` (flamme ambre #D9A24A) ; `pack.png` : 128, (1,4 ; 0,6), z -1 (sac de toile, gourde) + `pack_shadow.png` |
| `quai_de_la_cite` | Quai de la Cité | `cite_rouille` | brasero dans un bidon rouillé percé, braises par les trous | `barrel.png` : 128, (0 ; 0), z 0 (le bidon lui-même, sous le feu : le feu se dessine au-dessus) + `barrel_shadow.png` ; `cat.png` : 96 × 8 frames (768×96), (1,2 ; 0,4), z +1 (chat de gouttière gris couché, boucle respiration/oreille 8 frames à 6 fps, aucun regard rouge) ; `crate.png` : 128, (-1,8 ; 0,8), z -1 (caisse de bois mouillé) + `crate_shadow.png` |
| `crypte_veilleuse` | Crypte veilleuse | `cryptes_noyees` | cierges groupés sur une dalle : 7 flammes qui vacillent | `candles.png` : 128, (0 ; 0), z 0 (les cierges et leur cire coulée, sous les flammes) + `candles_e.png` ; `wreath.png` : 128, (-1,4 ; 0,5), z -1 (couronne de fleurs de papier blanc #CFC8BA, ruban de crêpe) + `wreath_shadow.png` |
| `lanternes_de_riziere` | Lanternes de rizière | `terrasses_rizieres_hautes` | feu dans un vieux seau de fer cabossé | `lantern_post.png` : 256, (-2,2 ; -0,8), z -1 (poteau de bambou à 3 lanternes de papier) + `lantern_post_e.png` (papier éclairé ambre) + `lantern_post_shadow.png` ; `boat.png` : 256, (2,4 ; 0,9), z -1 (barque de rizière tirée au sec, rame) + `boat_shadow.png` |

Lumière : le code garde `LightRig.attach_at(<feu>, &"ember", …)` (`EMBER_ENERGY`, `EMBER_RADIUS_U`) ; une lanterne ou les cierges ajoutent au plus une `PointLight2D` chacune (preset `lantern`, rayon 4 u). Musique : `music_menu_01` ; `Boutique_Rubis.md` §3.8 si une Partition de menu est possédée.

« Après la Source » (Source apaisée, pluie d'or) : **hors boutique** (trophée gratuit à la première victoire, même logique que les skins trophée) ; non produit en v1.

## 3. Procédé Codex et vérifs

Un lot par Veillée (profil `eco-mini`) : scène `art/blender/cel/cosmetics/veillee_<id>.blend`, props modélisés dans la DA (matières usées STYLE.md, cel `prop`), caméra `iso_rig`, feu rendu en 12 frames (Eevee 8 échantillons) ; `fire.tres` par substitution depuis `campfire.tres`. Vérif par script : dimensions exactes, frames non vides et distinctes, `_e` demi-résolution non noirs, ombres en niveaux de gris ; planche contact ≤ 1024 px (props + 3 frames de feu sur le sol de la carte) ; `godot --headless --path game --import` ; `res://tests/texture_budget_test.tscn`. ≈ 0,5-1 Mo par Veillée.
