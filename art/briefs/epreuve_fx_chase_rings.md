# Épreuves : lumière de Poursuite et anneaux au sol (lot EP-I)

Remplace les derniers tracés en code (`draw_circle` / `draw_arc`) des Épreuves.

- `vfx/epreuve/chase_light_<skin>.png`, skins fog_forest (accent #C27BFF, follet de mycélium) et crypts (accent #BFF4FF, éclat de cristal) : planche 8 frames de 96 x 96 (768 x 96), billboard iso (volume lumineux lisible : noyau blanc chaud, halo additif, quelques volutes ou éclats en orbite), boucle 10 fps, fond transparent.
- `vfx/epreuve/ring_zone.png` : anneau de portée au sol, vue strictement verticale (le jeu l'écrase en iso), 256 x 256, neutre doré clair (teinté en jeu), anneau fin presque au bord (96 %) avec graduations runiques, remplissage quasi nul.
- `vfx/epreuve/ring_wave.png` : anneau d'onde épais au sol, vue verticale, 256 x 256, blanc chaud à bord doux (teinté en jeu en rouge), anneau centré à 90 % du rayon, épaisseur environ 12 % du rayon.
