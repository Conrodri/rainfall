# TOCP2 ? c?blage Claude

`game/assets/sprites/characters/tocsin/` ; nouveaux `tocsin_pillar_{impact,zone,arc,end}.tres` et ressources `_emission.tres` associ?es. Aucun .gd/.tscn modifi? par TOCP2.

| Ressource | Cellule | Pivot local | AnimatedSprite2D.offset | Lecture |
|---|---|---|---|---|
| tocsin_pillar_impact.tres | [296, 156] | [148, 78] | [0.0, 0.0] | 8 frames, 20 fps, loop=False |
| tocsin_pillar_zone.tres | [298, 158] | [149, 79] | [0.0, 0.0] | 12 frames, 24 fps, loop=True |
| tocsin_pillar_arc.tres | [300, 117] | [167, 48] | [-17.0, 10.5] | 6 frames, 24 fps, loop=False |
| tocsin_pillar_end.tres | [123, 94] | [56, 82] | [5.5, -35.0] | 6 frames, 15 fps, loop=False |

TOP : scale = Vector2(1, 1), 64 px/u ; rayon zone et impact = 140.8 px = 2.2 u. Ancienne cellule 1032 ? 128 px/u remplac?e par rendu natif 64 px/u puis rognage commun +4 px sur chaque bord.

Arc : pillar_arc_top_0..3 et pillar_arc_crea_0..3, 6 frames chacune ; choisir la m?me variante pour les deux rendus. TOP scale=(1,1), CREA scale=(0.70710678,1.4142136), g?om?trie CREA pr?compens?e ; origine du pilier au pivot. Longueurs : 1.2, 1.55, 1.9, 2.2 u.

Zone : pillar_zone, boucle 12 frames / 24 fps = 2 Hz ; alpha 0.35 pendant vol, 1.0 pendant d?charge. Impact : pillar_impact, sans boucle. Fin : pillar_end, sans boucle.

Emission : PNG demi-r?solution ; appliquer metadata/overlay_scale, metadata/pivot et metadata/offset de la ressource correspondante. Diffus : metadata/offset, sprite centered=true ; positions monde au pivot. Donn?es d?taill?es : tocp2_manifest.json.

Timing code conserv? : vol 0.6 s ; d?charge 5 s, tick toutes les 0.5 s ; 10 ticks dont premier ? la pose. Aucun raccordement du placeholder _draw effectu? : r?serv? ? Claude.

texture_budget.py : mobile 218.765 ? 219.661 Mo ; 3 ? 3 violations globales. Mesure globale incluant les modifications concurrentes TOCP1. Lot seul : PNG 897522 bytes ; RGBA 13442940 bytes.

Validation : import Godot PASS ; res://tests/sprites_test.tscn RESULT: OK ; contrat Python PASS (74 frames, 8 PNG, 8 ressources, _e demi-r?solution, aucun _n). Planche unique : tocp2_contact.png.
