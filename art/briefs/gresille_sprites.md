# Grésille : sprites de jeu (lot GR1)

Choix du joueur : silhouette C « râtelier haut » (3 bouteilles de Leyde dressées au-dessus des épaules, câbles gainés vers les gants, cape-treillis courte), corps v2 de `art/blender/characters/gresille_concept.blend`, accent lilas #B9A6FF seul émissif. À cela s'ajoute la tige courte 0,9 u de la variante A (bâton de bronze vert-de-gris, 3 isolateurs de verre bleu avec anneau lilas, pointe polie), tenue main droite ; l'épaissir un peu (rayon ~0,010 u, isolateurs ~0,045 u) pour qu'elle se lise à 192 px.

Sources de géométrie et de matières : `art/tools/gresille/gresille_build.py` (`materials`, `build_body`, `build_variant`, `surface_finish`, helpers de `art/tools/characters/cd_cd3_common.py`). Modèle de pipeline d'animation : `art/tools/night/vg1_build.py` (Vigie : rig articulé en empties, solveur deux os des bras, CREA, passes CEL + AOV d'émission, reprise sur frames déjà rendues, `finish`/`verify`). Convention : mêmes directions, cellule et nommage que Vigie.

## Contrat de sortie (identique à Vigie)
- Dossier `game/assets/sprites/characters/gresille/` : une planche `<anim>.png` par animation (colonnes = frames, 8 lignes = directions dans l'ordre e, se, s, sw, w, nw, n, ne ; cellule 192x192, pivot [96, 136.32]), `<anim>_e.png` = masque d'émission à demi-résolution (96 par cellule), `gresille.tres` (SpriteFrames : noms `<anim>_<dir>`, atlas par AtlasTexture, `"duration": 1.0`, vitesse = fps), `gresille_manifest.json`, `portrait.png` 256x256 et `portrait_e.png` 128x128.
- Caméra CREA (iso_rig.create_rig('CREA', 192), shift_y .21), 30 degrés, 1 u = 90,51 px, hauteur 1,35 u, lumière haut-gauche, fond transparent, cel-shading (STYLE_cel.md, `cel.install('creature', normals=False)`), AUCUNE normal map, aucun `_n.png`, aucune CanvasTexture dans le .tres.
- Rendu Blender directement à 192x192 (résolution_x = 192) : aucun redimensionnement PIL du diffus. Seul le masque d'émission peut être réduit de moitié (comme Vigie).
- Animations (frames, fps, boucle, impact base 0 -> numéro 1-based de la fiche) :
  - idle 8, 10 fps, boucle (respiration, tige plantée comme un bâton de marche, mèches immobiles)
  - run 8, 10 fps, boucle (tige portée à la main, bouteilles qui ballottent peu)
  - attack 4, 12 fps, impact 2 : elle tend la tige vers l'avant, bras droit tendu, pointe qui luit
  - cast 5, 12 fps, impact 3 (Décharge) : bras gauche tendu paume ouverte vers l'avant, tige en arrière
  - ground 6, 12 fps, impact 3 : elle plante la tige à ses pieds à deux mains (anneau lilas au sol géré hors sprite)
  - call 8, 12 fps, impact 2, BOUCLE à partir de la frame 3 : lève la tige à deux mains, cheveux dressés lumineux (lilas), 3 bouteilles à pleine charge ; frames 3-8 = canalisation bouclable
  - death 6, 12 fps, sans boucle : s'effondre à genoux puis sur le côté, tige lâchée au sol, bouteilles ternes (accent éteint a la dernière frame)
  - alias SpriteFrames : `cast_ult` = `call`.
- Masque `_e` : bouteilles (arcs et charges), anneaux des isolateurs, mèches chargées. Le code module les bouteilles (recharge de la Décharge), donc les arcs des 3 bouteilles doivent être dans le masque a pleine énergie. Jamais noir ni vide.

## Vérifications obligatoires
Pieds alignés d'une frame à l'autre (même pivot, aucun glissement en idle), aucun rognage (marge >= 3 px), 8 directions toutes différentes, silhouette de femme lisible a 192 px, accent lilas seul émissif, poids total des PNG visé <= 2,5 Mo (quantification sans perte visible acceptable, art/tools/ardent_pngquant).
