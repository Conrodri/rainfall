# F2 — Forêt de brume

Lot complet : 18 diffus, 18 normales MAP/TOP, 3 ombres TOP 512² et 2 masques émissifs verts ; sortie `game/assets/sprites/terrain/fog_forest/iso/`.

DA : cèdre noir détrempé, souche à contreforts et cernes visibles, voûte de racines suspendant une lanterne en fer patiné, rocher moussu ; palissades liées par des racines, berges de tourbe arrachées et radicelles pendantes. Mousse/terre multicouches, aiguilles fines, poches d'eau noire, lentilles d'eau et rides froides. Accent unique #9CF0C8 sur `block_b` et `rampart_corner_n`, sans masque vide.

Réemploi des matériaux PBR usés d'`ash_lord_build.py`, des utilitaires C1 et d'`iso_rig.py`. Eevee, 16 échantillons, rendu 2× puis réduction ; caméra MAP R=90,5097 px/u, TOP 128 px/u. Substrats périodiques sur 4 m, eau sur 2 m, brume sur 8 m ; éclairage directionnel des surfaces répétées pour supprimer les gradients locaux entre tuiles. Détails des quatre sols confinés à l'intérieur, phase commune aux frontières.

PASS : inventaire de 41 PNG, tailles, alphas en losange, pivots des 18 sources, emprises jointives et hauteur maximale 1,25 u des obstacles ; parois des falaises exactement 2,5 u. Audit `f2_geometry.json`, mesures dans `f2_*_check.json`, validation `f2_validation.json`.

Godot : `res://tests/sprites_test.tscn` → **RESULT: OK** ; chargeur existant `i3_verify.tres` réutilisé en lecture seule → **65 ressources .tres chargées, 0 erreur**. Journaux `f2_godot.log` et `f2_resources.log`.

Planche : `art/tools/night/_f2_contact.png`, montage aux pivots contractuels et références C1/Ardent/Rictus. Sources `art/blender/terrain/f2_*.blend`, script `art/tools/night/f2_build.py` (`--only <nom>` pour reprendre, `--audit` pour la géométrie, `--verify` pour les images et la planche). Aucun .gd/.tscn/.tres modifié.
