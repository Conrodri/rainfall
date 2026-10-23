# Sonneur C7C

New 3.8 u foundry colossus: hollow verdigris funeral bell, asymmetric chimney organ, worn iron firebox, brass hydraulic hammer arms. Phase 2: live induction crown; phase 3: torn door, exposed furnace and dirty pressure steam. One pale amber accent unifies electricity and furnace.

Source: art/blender/monsters/sonneur_iso.blend; generator: art/tools/night/c7c_build.py.

| Sheet | Cell | Frames | Rows |
|---|---|---:|---|
| idle_p1 | 256x256 | 6 | s |
| idle_p2 | 256x256 | 6 | s |
| idle_p3 | 256x256 | 6 | s |
| walk_p1 | 256x256 | 8 | e,s,w,n |
| walk_p2 | 256x256 | 8 | e,s,w,n |
| walk_p3 | 256x256 | 8 | e,s,w,n |
| auto | 256x256 | 6 | s |
| spell_a | 256x256 | 8 | s |
| spell_b | 256x256 | 8 | s |
| trans_p2 | 256x256 | 8 | s |
| trans_p3 | 256x256 | 8 | s |
| death | 256x256 | 10 | s |
| bell_ring | 256x256 | 6 | s |
| boiler_open | 256x256 | 6 | s |
| auto_dirs | 256x256 | 6 | e,w,n |
| spell_a_dirs | 256x256 | 8 | e,w,n |
| spell_b_dirs | 256x256 | 8 | e,w,n |
| bolt | 32x32 | 6 | s |
| ground_lightning | 128x128 | 6 | s |
| ground_scorch | 128x128 | 4 | s |
| ground_steam | 64x384 | 8 | s |
| lightning | 128x768 | 4 | s |
| steam_vent | 64x384 | 8 | s |

Original 60 PNG dimensions and 29 animation definitions retained; 9 directional animations appended, 69 PNG total. Each sheet has real Blender normal/emission passes. Inventory and checks: art/tools/night/_c7c_inventory.json, _c7c_verify.json. Contact columns: idle, anticipation, impact, Ardent, Ash Lord (same physical scale); lower rows: phases, bell, furnace layer, extras and validated DA reference boards.

## C7E — 22/10/2026
Corps C7c et pivots conservés, 240 frames re-rendues : fonte/laiton éclaircis, rim froid haut-gauche, foyer et joints ambre. Recette : art/tools/night/c7e_build.py ; source sonneur_iso.blend actualisée.
Nouveaux glas_wave (8x256x256, non bouclé) et steam_jet (8x384x64, bouclé, origine gauche, émission noire). lightning : 4x128x768 utiles pleine hauteur ; bolt : 6x64x64 avec traînées aux frames 1/4. Chaque diffus conserve ses passes _n et _e alignées. Plus grand atlas : 3072 px ; 75 PNG, 40 animations.
Rapport et contrôles : art/tools/night/_c7e_report.md, _c7e_verify.json ; comparaison : _c7e_contact.png.
