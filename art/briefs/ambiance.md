# Textures d'ambiance : brief et chemins (pilote assets ambiance)

Source de vérité des besoins : `docs/Direction_Lumiere_Ambiance.md` §6 (noms/tailles du DA). Les livrables ci-dessous suivent la mission initiale ; un alignement de nommage (`rain_sheet_512`, `splash_8x64`, etc.) reste à faire (voir « À faire »).
Toutes en PNG RGBA blanc/gris + alpha (à teinter via `modulate`). Scripts : `art/tools/ambiance/`. Sources : `art/blender/ambiance/`. Rendus 2x : `art/renders/ambiance/`.

## Livré (dossier `game/assets/sprites/ambiance/rain/`)
| Fichier | Taille | Usage |
|---|---|---|
| drop_00..drop_07.png | 16x64, 18x72, 20x80, 22x88, 24x96, 26x104, 30x116, 32x128 | traînées de pluie, inclinées ~12° (haut-gauche vers bas-droite), alpha max 1 : réduire l'opacité en code (≤ 12 % de calque) |
| splash_a/b/c.png | 384x64 (6 frames de 64x64, horizontal) | éclaboussures au sol, vue de dessus 3/4, frame 0 quasi vide (impact) |
| ripple.png | 512x64 (8 frames de 64x64) | ondes de flaque, anneaux elliptiques |
| ripple_n.png | 512x64 | normal map correspondante (fond 128,128,255) |
Aperçu : `art/renders/ambiance/rain_preview.png`. Script : `art/tools/ambiance/rain.py`.

## NON livré (Codex bloqué : quota d'usage atteint jusqu'à 16h41)
Prompts prêts : `art/tools/ambiance/_PREAMBLE.txt` (règles communes) + `_p2.txt` (brumes/ombres de nuages). Relancer avec
`codex exec --dangerously-bypass-approvals-and-sandbox -C "C:\Users\const\Documents\Rainfall" - < art/tools/ambiance/_p2.txt`
- P2 brumes : fog_light/medium/dense 512 raccordables, cloud_shadow 1024 (x2).
- P3 : god rays (3), halos, lens glow, éclairs (4 + flash).
- P4 : particules par carte (lucioles, cendres, feuilles, gouttes en suspension), 4 variantes x 32-64 px.
- P5 : gradients de ciel 256x256 (sunset, aube brumeuse, orage).
- Alignement DA §6 : splash 8 frames x 3 matières (eau/boue/métal), `rain_sheet_512` raccordable, `light_soft/hard/ring_256`, `puddle_mask_1024`, `fog_tile_1024`, `cloud_shadow_2048`, `godray_512x1024`, `vignette_1024`, etc.

## Livraison Claude (intérim, 21/10/2026) : textures nommées selon docs/Direction_Lumiere_Ambiance.md §6
Rendues en Eevee `--background` (nœuds de shader procéduraux, film transparent, PNG RGBA 8 bits), à plat dans `game/assets/sprites/ambiance/<nom>.png`, variantes `<nom>_2.png`, `_3`… Lib : `art/tools/ambiance/amb_lib.py` ; scripts `p0a_sprites.py`, `p0b_water_fog.py`, `p1p2_rest.py` ; contrôles 2×2 `art/renders/ambiance/tile2x2_*.png`, logs `log_*.json`. La pluie d'origine (`rain/`) est conservée.
Convention : atlas = images carrées côte à côte ; trainée `trail_64x256` : tête en bas ; rayon `godray` : source en haut (variante 3 : coffre, source en bas) ; données (`rain_sheet` R/G/B = 3 densités, alpha = max ; `puddle_mask` R flaque / G profondeur / B bord mouillé, alpha 1, couverture ≈ 22-27 % ; normales `_n`) en vue Raw ; le reste Standard.
| Nom du doc | Fichiers | Taille |
|---|---|---|
| light_soft/hard_256, halo_soft_256 | `.png` | 256² |
| light_ring_256 | `.png` (fin), `_2` (180° pleins / 40 %) | 256² |
| rain_sheet_512 | `.png` bruine, `_2` rideau (raccordables) ; `rain_streak_far_512.png` | 512² |
| drop_32 | `.png`, `_2`–`_4` | 32² |
| splash_8x64 | `.png` eau, `_2` boue, `_3` métal | 512×64 |
| ripple_8x64 | `.png`, `_2` | 512×64 |
| ripple_normal_256 | `.png`, `_2` | 256² |
| puddle_mask_1024 (+ `_n`) | `.png`…`_4` | 1024² |
| fog_tile_1024 | `.png` (A fin), `_2` (B grumeleux) | 1024² |
| fog_volume_tile_1024 | `.png`, `_2` | 1024² |
| vignette_1024 | `.png` | 1024² |
| sky_sunset / dawn / storm_256x64 | `.png` | 256×64 |
| godray_512x1024 | `.png` soleil, `_2` pilier, `_3` coffre | 512×1024 |
| spark_16, mote_16, firefly_16, ash_16, ember_16, frost_crystal_16, bubble_16 | `.png`, `_2`(, `_3`) | 16² |
| glint_32 | `.png`, `_2` | 32² |
| trail_64x256 | `.png`, `_2` | 64×256 |
| impact_8x64 | `.png` feu, `_2` générique | 512×64 |
| cloud_shadow_2048 / canopy_shadow_2048 | `.png`, `_2` (raccordables) | 2048² |
| leaf_pine_32 / leaf_cedar_32 | `.png`, `_2`, `_3` | 32² |
| fog_puff_512 (+ `_n`) | `.png`, `_2`…`_6` | 512² |
| steam_puff_64 | `.png`…`_4` | 64² |
| lightcone_256x512 | `.png`, `_2` | 256×512 |
| lightning_bolt_256x1024 (+ `_e`) | `.png`…`_4` | 256×1024 |
| horizon_glow_1024x256 | `.png`, `_2` | 1024×256 |
| wind_streak_128 | `.png`…`_3` | 128×32 |
| arc_8x64 | `.png`…`_3` | 512×64 |
| aura_ring_128 | `.png` | 128² |
| water_caustics_512 | `.png`, `_2` (raccordables) | 512² |
| drop_window_64 (+ `_n`) | `.png`…`_6` | 64² |
| lantern_flare_128 | `.png`, `_2` | 128² |
Non livré : `fog_height_mask_<carte>` (nécessite les schémas ASCII et les ids de cartes). Aliases rain/ devenus inutiles (le doc a la priorité).
