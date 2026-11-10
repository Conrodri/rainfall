# Grésille, VFX des variantes Paratonnerre et Bouteille de Leyde

Remplacent les placeholders dessinés en code de `gresille_rod.gd` et `gresille_lob.gd` (fiche docs/fiches/gresille.md §12.2).
Échelle : 1 u = 64 px (1 unité Blender = 64 px en largeur). Caméra de `art/tools/gresille/vfx_build_a.py` (dimétrique 2:1, orthographique, soleil haut-gauche), cel-shading `cel_style` profil `vfx`, aucune normal map. Accent lilas #B9A6FF, coeur #F2EEFF. DA sérieuse : bronze patiné vert-de-gris, verre fumé, formes anguleuses. Fond transparent, marge >= 2 px.

| Dossier / fichier | Cellule | Grille | Frames | Contenu |
|---|---|---|---|---|
| `rod_planted/rod_planted.png` (+ `_e.png` masque d'émission, moitié de taille) | 128x192 | 5 colonnes x 2 lignes | 10 : frames 0-3 apparition (la tige jaillit du sol, éclats de terre), 4-9 boucle idle | Tige de paratonnerre plantée, ~1,5 u de haut (≈ 100 px de tige visible), pied au centre-bas de la cellule (point au sol = bas de la cellule moins 8 px), 3 isolateurs en céramique sombre empilés, pointe lilas qui pulse (rayon et intensité varient sur la boucle), petit arc lilas qui danse à la pointe. Bronze vert-de-gris, base en bloc de pierre. |
| `jar_fly/jar_fly.png` | 64x64 | 4 colonnes x 2 lignes | 8 | Bouteille de Leyde (verre fumé, deux cerclages de cuivre, bouchon, arc lilas à l'intérieur), 8 poses d'une rotation complète sur elle-même (dans le plan de l'image), centrée. Taille ~ 0,7 u (≈ 48 px). |
| `jar_burst/jar_burst.png` | 512x320 | 3 colonnes x 2 lignes | 6 | Éclat à l'impact, rayon 4 u en iso : la bouteille éclate (éclats de verre fumé en l'air), étoile d'arcs lilas (6-8 branches anguleuses) à plat sur le sol (ellipse iso, demi-largeur 256 px à la frame de pleine extension), coeur blanc-lilas. Frames : 0 flash central, 1-2 expansion, 3 plein rayon, 4-5 retombée et fondu. Centre au sol = centre horizontal, 100 px au-dessus du bas de la cellule. |

Lecture en jeu : additive (le noir ne compte pas ; alpha = intensité des arcs).
Poids : chaque PNG <= 500 Ko (quantification de palette autorisée via PIL `quantize`, jamais de redimensionnement).
