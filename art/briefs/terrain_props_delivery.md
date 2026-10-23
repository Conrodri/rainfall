# Livraison props — étape 2

Rendus Blender Eevee 2x, caméra orthographique 55°, Standard ; aucun plan recevant une ombre. Normales OpenGL en espace caméra (Y+ écran). Masques émissifs rendus séparément.

Animations : piliers actifs 8 colonnes (boucle, 12 fps suggérés), splash 4 colonnes, splash8 8 colonnes. Une frame carrée par colonne.

| Fichier | Dimensions | Octets |
|---|---:|---:|
| game/assets/sprites/props/boat.png | 256 × 256 | 19401 |
| game/assets/sprites/props/boat_n.png | 256 × 256 | 24467 |
| game/assets/sprites/props/rain/grass_a.png | 128 × 128 | 6788 |
| game/assets/sprites/props/rain/grass_a_n.png | 128 × 128 | 8250 |
| game/assets/sprites/props/rain/grass_b.png | 128 × 128 | 8797 |
| game/assets/sprites/props/rain/grass_b_n.png | 128 × 128 | 10802 |
| game/assets/sprites/props/rain/grass_c.png | 128 × 128 | 8631 |
| game/assets/sprites/props/rain/grass_c_n.png | 128 × 128 | 10482 |
| game/assets/sprites/props/jar.png | 128 × 128 | 9205 |
| game/assets/sprites/props/jar_n.png | 128 × 128 | 11535 |
| game/assets/sprites/props/pillar_large_active.png | 2048 × 256 | 88338 |
| game/assets/sprites/props/pillar_large_active_n.png | 2048 × 256 | 78078 |
| game/assets/sprites/props/pillar_large_active_e.png | 2048 × 256 | 49952 |
| game/assets/sprites/props/pillar_large_done.png | 256 × 256 | 24937 |
| game/assets/sprites/props/pillar_large_done_n.png | 256 × 256 | 29136 |
| game/assets/sprites/props/pillar_large_done_e.png | 256 × 256 | 9340 |
| game/assets/sprites/props/pillar_large_off.png | 256 × 256 | 24006 |
| game/assets/sprites/props/pillar_large_off_n.png | 256 × 256 | 27548 |
| game/assets/sprites/props/pillar_small_active.png | 1024 × 128 | 35722 |
| game/assets/sprites/props/pillar_small_active_n.png | 1024 × 128 | 32816 |
| game/assets/sprites/props/pillar_small_active_e.png | 1024 × 128 | 22980 |
| game/assets/sprites/props/pillar_small_done.png | 128 × 128 | 10495 |
| game/assets/sprites/props/pillar_small_done_n.png | 128 × 128 | 11968 |
| game/assets/sprites/props/pillar_small_done_e.png | 128 × 128 | 4728 |
| game/assets/sprites/props/pillar_small_off.png | 128 × 128 | 10130 |
| game/assets/sprites/props/pillar_small_off_n.png | 128 × 128 | 11656 |
| game/assets/sprites/props/rain/puddle_a.png | 192 × 192 | 10022 |
| game/assets/sprites/props/rain/puddle_a_n.png | 192 × 192 | 11063 |
| game/assets/sprites/props/rain/puddle_b.png | 192 × 192 | 9789 |
| game/assets/sprites/props/rain/puddle_b_n.png | 192 × 192 | 11022 |
| game/assets/sprites/props/rain/puddle_c.png | 192 × 192 | 9688 |
| game/assets/sprites/props/rain/puddle_c_n.png | 192 × 192 | 10921 |
| game/assets/sprites/props/rock.png | 128 × 128 | 7247 |
| game/assets/sprites/props/rock_n.png | 128 × 128 | 10055 |
| game/assets/sprites/props/rain/splash.png | 512 × 128 | 32293 |
| game/assets/sprites/props/rain/splash_n.png | 512 × 128 | 36154 |
| game/assets/sprites/props/rain/splash8.png | 1024 × 128 | 64253 |
| game/assets/sprites/props/rain/splash8_n.png | 1024 × 128 | 71507 |
| game/assets/sprites/props/stele.png | 192 × 192 | 8344 |
| game/assets/sprites/props/stele_n.png | 192 × 192 | 8882 |
| game/assets/sprites/props/stone_lantern.png | 192 × 192 | 11778 |
| game/assets/sprites/props/stone_lantern_n.png | 192 × 192 | 13315 |
| game/assets/sprites/props/stone_lantern_e.png | 192 × 192 | 3093 |
| game/assets/sprites/props/stone_wall_corner.png | 384 × 384 | 23059 |
| game/assets/sprites/props/stone_wall_corner_n.png | 384 × 384 | 24446 |
| game/assets/sprites/props/stone_wall_gap_stairs.png | 256 × 256 | 16244 |
| game/assets/sprites/props/stone_wall_gap_stairs_n.png | 256 × 256 | 16951 |
| game/assets/sprites/props/stone_wall_straight.png | 256 × 256 | 14088 |
| game/assets/sprites/props/stone_wall_straight_n.png | 256 × 256 | 15112 |
| game/assets/sprites/props/teleporter_active.png | 256 × 256 | 43634 |
| game/assets/sprites/props/teleporter_active_n.png | 256 × 256 | 47747 |
| game/assets/sprites/props/teleporter_active_e.png | 256 × 256 | 23184 |
| game/assets/sprites/props/teleporter_idle.png | 256 × 256 | 35026 |
| game/assets/sprites/props/teleporter_idle_n.png | 256 × 256 | 38672 |
| game/assets/sprites/props/teleporter_idle_e.png | 256 × 256 | 17093 |
| game/assets/sprites/props/twisted_pine.png | 256 × 256 | 21825 |
| game/assets/sprites/props/twisted_pine_n.png | 256 × 256 | 27868 |

Contrôles : 57 PNG RGBA ; marges transparentes >= 4 px dans chaque frame ; aucune frame animée dupliquée ; alpha couleur/normal identique ; cadrage émission identique ; normale plane orientée Y+ écran et Z+ vers le spectateur. Inspection visuelle des planches couleur/normal/émission et des sheets.

Inventaire exhaustif (sources, rendus bruts et livraisons, octets et dimensions PNG) : art/briefs/terrain_props_inventory.json.

## Sources Blender et scripts

| Fichier | Octets |
|---|---:|
| art/blender/terrain/props_boat.blend | 100377 |
| art/blender/terrain/props_grass_a.blend | 96600 |
| art/blender/terrain/props_grass_b.blend | 97219 |
| art/blender/terrain/props_grass_c.blend | 97690 |
| art/blender/terrain/props_jar.blend | 121711 |
| art/blender/terrain/props_pillar_large_active.blend | 139010 |
| art/blender/terrain/props_pillar_large_done.blend | 136042 |
| art/blender/terrain/props_pillar_large_off.blend | 120818 |
| art/blender/terrain/props_pillar_small_active.blend | 138529 |
| art/blender/terrain/props_pillar_small_done.blend | 136670 |
| art/blender/terrain/props_pillar_small_off.blend | 119576 |
| art/blender/terrain/props_puddle_a.blend | 99136 |
| art/blender/terrain/props_puddle_b.blend | 99180 |
| art/blender/terrain/props_puddle_c.blend | 99118 |
| art/blender/terrain/props_rock.blend | 110652 |
| art/blender/terrain/props_splash.blend | 134172 |
| art/blender/terrain/props_splash8.blend | 133479 |
| art/blender/terrain/props_stele.blend | 100878 |
| art/blender/terrain/props_stone_lantern.blend | 104874 |
| art/blender/terrain/props_stone_wall_corner.blend | 120924 |
| art/blender/terrain/props_stone_wall_gap_stairs.blend | 113729 |
| art/blender/terrain/props_stone_wall_straight.blend | 115076 |
| art/blender/terrain/props_teleporter_active.blend | 127449 |
| art/blender/terrain/props_teleporter_idle.blend | 125907 |
| art/blender/terrain/props_twisted_pine.blend | 134494 |
| art/tools/terrain/assemble_props.py | 2669 |
| art/tools/terrain/check_props.py | 2673 |
| art/tools/terrain/props.py | 14677 |