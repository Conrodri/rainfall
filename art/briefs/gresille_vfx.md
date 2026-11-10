# Grésille GR2 : VFX et icônes du kit

Perso électrique, DA sérieuse (art/briefs/STYLE.md en tête, STYLE_cel.md), cel-shading, caméra dimétrique 2:1 (élévation 30°, voir art/tools/averse_vfx/burst_build.py comme modèle de scène Blender : `cel_style`, caméra ortho, soleil haut-gauche). Accent lilas d'arc #B9A6FF, cœur blanc #F2EEFF, jamais bleu (le bleu-blanc est le statut « choc » des monstres). Additif : RVB vif, alpha = intensité, aucun halo sombre. Pas de normal map. Rendu à la taille finale (aucun redimensionnement PIL), un seul PNG par famille, frames en une ligne sauf mention. Fond transparent, marge >= 2 px.
Formes : les arcs sont des lignes brisées (zigzag à angles vifs, 2-4 branches secondaires courtes), jamais de courbes lisses.

## Fichiers (sortie sous game/assets/sprites/vfx/gresille/<nom>/<nom>.png)

| nom | planche | contenu |
|---|---|---|
| arc_tile | 1024x192 | 4 variantes (lignes) x 4 frames (colonnes), cellule 256x48. Un arc horizontal bord à bord (x=0 et x=255 au centre vertical, ancré), qui s'étire entre deux points (même format que vfx/chain_arc/chain_arc.png, version lilas, noyau blanc fin + gaine lilas). Frames distinctes. Sert aussi de texture de sillage. |
| static_crawl | 256x64 | 4 frames 64x64 : petits arcs lilas qui courent sur la silhouette d'un monstre (corps ~1 u), vue billboard. 2-3 filets courts qui sautent d'une frame à l'autre. |
| zap_flash | 288x96 | 3 frames 96x96 : claquement blanc, étoile d'arc à 5-7 branches brisées + éclat central blanc, naît, culmine, se dissipe. |
| discharge_burst | 1152x192 | 6 frames 192x192 : décharge libérée depuis le sol vers l'extérieur, gerbe d'arcs lilas rayonnants (6-9 branches brisées) autour d'un cœur blanc, anneau de choc au sol (ellipse écrasée 2:1), s'éteint en frames 5-6. |
| bolt_strike | 1152x384 | 6 frames 192x384 : colonne de foudre du ciel (haut de la cellule) au point d'impact (bas, centre-bas), zigzag vertical épais ~1,5 u au sol (cercle d'impact de 1,5 u de rayon écrasé 2:1 à la base), flash blanc à l'impact, branches latérales ; frame 1 = trait fin, 2-3 = pleine puissance, 4-6 = déclin. |
| ground_tile | 64x64 | tuile top-down 1 u, répétable sans couture (bords raccordés) : nappe d'eau électrisée, eau sombre ardoise, petits arcs lilas qui rampent en surface, reflets. Vue de dessus pure (carré logique, la caméra l'écrase). |
| ground_field | 1536x1152 | 11 frames 384x384 en grille 4 colonnes x 3 lignes (limite 4096 px), top-down (disque 3 u de rayon, diamètre 384), pour la Mise à la terre à sec : frames 1-8 `default` (boucle) : anneau lilas au sol + rosace de fissures-arcs qui crépitent, centre sombre ; frames 9-11 `end` : s'éteint. Fond transparent hors du disque. |
| gresille_arc, gresille_decharge, gresille_terre, gresille_orage | 128x128 chacun | icônes de sorts, sortie game/assets/sprites/icons/spells/<nom>.png. Même style et cadre que vigie_fusee.png (regarder une icône Vigie/Tocsin existante : fond, bordure, éclairage, lisibilité). Arc : tige de paratonnerre + arc zigzag vers un point ; Décharge : gerbe d'arcs qui part d'un monstre chargé ; Terre : tige plantée au sol, anneau d'arcs au sol ; Orage : colonne de foudre tombant d'un nuage sombre. Accent lilas. |

Masque d'émission `<nom>_e.png` (demi-résolution) seulement pour arc_tile, bolt_strike, ground_field et ground_tile si utile.
Scripts de construction : art/tools/gresille/vfx_build_a.py (arc_tile, static_crawl, zap_flash, discharge_burst, bolt_strike) et vfx_build_b.py (ground_tile, ground_field, icônes) : rendu Blender --background + assemblage Pillow. Pas de .tres (faits ailleurs).
