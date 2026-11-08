# Épreuves : télégraphes, chevrons, arcs, trajet, liaisons et jauges (lot EP-II)

Remplace les derniers tracés en code (`draw_polyline`, `draw_arc`, `draw_circle`, `draw_line`, `draw_rect`, `draw_colored_polygon`) des Épreuves. Tous les éléments sont des textures **neutres blanc chaud / or clair**, teintées en jeu (`modulate`), fond transparent, DA sombre cel-shadée avec un seul accent émissif, éclairage haut-gauche. Les éléments au sol sont en **vue strictement verticale** (le rig iso les écrase, comme `ring_zone.png`).

Fichiers dans `game/assets/sprites/vfx/epreuve/` :

- `ep2_geyser_tele.png` : 256 x 256, télégraphe du geyser (Veine) : anneau fin à 96 % du bord, hachures runiques radiales, disque intérieur très translucide (le jeu fait varier l'alpha et la teinte rouge).
- `ep2_geyser_flash.png` : 256 x 256, flash d'éruption : halo blanc chaud, centre dense qui s'éteint en bord doux.
- `ep2_chevron.png` : 128 x 128, chevron de Tenue pointant vers +x, au sol, arête épaisse biseautée, pointe à 90 % du cadre.
- `ep2_progress_ring.png` : 256 x 256, anneau de progression plein, épaisseur ~9 % du rayon, bord extérieur à 96 %, graduations fines ; le jeu l'affiche en secteur (fan de polygone à UV) de -90° au pourcentage voulu ; une teinte sombre fait le rail.
- `ep2_path_tile.png` : 64 x 32, tuile répétable le long de l'axe x (traits de piste, pastilles runiques, bord doux en y) du trajet d'Escorte, au sol ; raccord x gauche/droite sans couture.
- `ep2_pad_start.png` / `ep2_pad_end.png` : 128 x 128, pontons de départ (disque plat à cercle double, motif d'embarquement) et d'arrivée (anneau avec repère de fanion/point d'ancrage), au sol.
- `ep2_rope.png` : 64 x 16, tuile répétable de corde torsadée (axe x), neutre clair.
- `ep2_link.png` : 64 x 24, tuile répétable de liaison d'énergie entre relais et cœur du Rituel (filaments, noyau clair, bord doux).
- `ep2_bar_frame.png` / `ep2_bar_fill.png` : 192 x 24, cadre de jauge de PV (bord métal sombre usé, creux translucide) et remplissage (dégradé blanc chaud, nervures), même cadrage ; le jeu rogne le remplissage en largeur.

Formes conformes à docs/Design_Epreuves.md. Pas de normal map. Lot <= 1,5 Mo au total. Script `art/tools/epreuve/ep2_build.py`, .blend `art/blender/props/ep2_fx.blend`.
