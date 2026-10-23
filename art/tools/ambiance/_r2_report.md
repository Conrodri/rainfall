# R2 ambiance — rapport

121/121 PNG provisoires remplaces. Aucun fichier du lot non remplace.

Rendus Eevee 8 echantillons, 2x puis reduction Blender. Sources : art/blender/ambiance/r2_<famille>.blend ; graphes conserves. Le DSL de noeuds est derive de amb_lib.py ; les graphes de textures sont reecrits dans r2_render.py.

Controles : noms, tailles, RGBA, alpha non vide, nombre de frames, empreintes differentes des provisoires, compagnons _n/_e, canaux de donnees, raccords periodiques et apercus 2x2. Familles publiees apres validation complete. Inventaire avant remplacement : _r2_inventory.json. Resultats detailles : art/renders/ambiance/r2/*/validation.json et final_validation.json.

Non remplaces hors lot : rain/ (livraison Codex anterieure conservee). fog_height_mask_<carte> absent du lot initial : non cree, cartes non fournies.

Limites restantes : aspect non valide en situation dans Godot ; repetition du motif perceptible a grande echelle ; particules 16 px volontairement simples. Aucun changement de code/scene/ressource Godot.

## Liste exacte des fichiers remplaces

- game/assets/sprites/ambiance/arc_8x64.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/arc_8x64_2.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/arc_8x64_3.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/ash_16.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/ash_16_2.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/aura_ring_128.png — 128 x 128 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/bubble_16.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/bubble_16_2.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/canopy_shadow_2048.png — 2048 x 2048 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/canopy_shadow_2048_2.png — 2048 x 2048 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/cloud_shadow_2048.png — 2048 x 2048 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/cloud_shadow_2048_2.png — 2048 x 2048 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_32.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_32_2.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_32_3.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_32_4.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_window_64.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_window_64_2.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_window_64_2_n.png — 64 x 64 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/drop_window_64_3.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_window_64_3_n.png — 64 x 64 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/drop_window_64_4.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_window_64_4_n.png — 64 x 64 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/drop_window_64_5.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_window_64_5_n.png — 64 x 64 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/drop_window_64_6.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/drop_window_64_6_n.png — 64 x 64 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/drop_window_64_n.png — 64 x 64 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/ember_16.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/ember_16_2.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/ember_16_3.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/firefly_16.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/firefly_16_2.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_puff_512.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_puff_512_2.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_puff_512_2_n.png — 512 x 512 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/fog_puff_512_3.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_puff_512_3_n.png — 512 x 512 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/fog_puff_512_4.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_puff_512_4_n.png — 512 x 512 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/fog_puff_512_5.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_puff_512_5_n.png — 512 x 512 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/fog_puff_512_6.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_puff_512_6_n.png — 512 x 512 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/fog_puff_512_n.png — 512 x 512 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/fog_tile_1024.png — 1024 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_tile_1024_2.png — 1024 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_volume_tile_1024.png — 1024 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/fog_volume_tile_1024_2.png — 1024 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/frost_crystal_16.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/frost_crystal_16_2.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/frost_crystal_16_3.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/glint_32.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/glint_32_2.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/godray_512x1024.png — 512 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/godray_512x1024_2.png — 512 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/godray_512x1024_3.png — 512 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/halo_soft_256.png — 256 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/horizon_glow_1024x256.png — 1024 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/horizon_glow_1024x256_2.png — 1024 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/impact_8x64.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/impact_8x64_2.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lantern_flare_128.png — 128 x 128 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lantern_flare_128_2.png — 128 x 128 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/leaf_cedar_32.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/leaf_cedar_32_2.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/leaf_cedar_32_3.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/leaf_pine_32.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/leaf_pine_32_2.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/leaf_pine_32_3.png — 32 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/light_hard_256.png — 256 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/light_ring_256.png — 256 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/light_ring_256_2.png — 256 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/light_soft_256.png — 256 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lightcone_256x512.png — 256 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lightcone_256x512_2.png — 256 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lightning_bolt_256x1024.png — 256 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lightning_bolt_256x1024_2.png — 256 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lightning_bolt_256x1024_2_e.png — 256 x 1024 px ; 1 frame(s) ; emission
- game/assets/sprites/ambiance/lightning_bolt_256x1024_3.png — 256 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lightning_bolt_256x1024_3_e.png — 256 x 1024 px ; 1 frame(s) ; emission
- game/assets/sprites/ambiance/lightning_bolt_256x1024_4.png — 256 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/lightning_bolt_256x1024_4_e.png — 256 x 1024 px ; 1 frame(s) ; emission
- game/assets/sprites/ambiance/lightning_bolt_256x1024_e.png — 256 x 1024 px ; 1 frame(s) ; emission
- game/assets/sprites/ambiance/mote_16.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/mote_16_2.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/puddle_mask_1024.png — 1024 x 1024 px ; 1 frame(s) ; puddle_rgb
- game/assets/sprites/ambiance/puddle_mask_1024_2.png — 1024 x 1024 px ; 1 frame(s) ; puddle_rgb
- game/assets/sprites/ambiance/puddle_mask_1024_2_n.png — 1024 x 1024 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/puddle_mask_1024_3.png — 1024 x 1024 px ; 1 frame(s) ; puddle_rgb
- game/assets/sprites/ambiance/puddle_mask_1024_3_n.png — 1024 x 1024 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/puddle_mask_1024_4.png — 1024 x 1024 px ; 1 frame(s) ; puddle_rgb
- game/assets/sprites/ambiance/puddle_mask_1024_4_n.png — 1024 x 1024 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/puddle_mask_1024_n.png — 1024 x 1024 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/rain_sheet_512.png — 512 x 512 px ; 1 frame(s) ; rain_rgb
- game/assets/sprites/ambiance/rain_sheet_512_2.png — 512 x 512 px ; 1 frame(s) ; rain_rgb
- game/assets/sprites/ambiance/rain_streak_far_512.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/ripple_8x64.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/ripple_8x64_2.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/ripple_normal_256.png — 256 x 256 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/ripple_normal_256_2.png — 256 x 256 px ; 1 frame(s) ; normal
- game/assets/sprites/ambiance/sky_dawn_256x64.png — 256 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/sky_storm_256x64.png — 256 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/sky_sunset_256x64.png — 256 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/spark_16.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/spark_16_2.png — 16 x 16 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/splash_8x64.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/splash_8x64_2.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/splash_8x64_3.png — 512 x 64 px ; 8 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/steam_puff_64.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/steam_puff_64_2.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/steam_puff_64_3.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/steam_puff_64_4.png — 64 x 64 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/trail_64x256.png — 64 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/trail_64x256_2.png — 64 x 256 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/vignette_1024.png — 1024 x 1024 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/water_caustics_512.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/water_caustics_512_2.png — 512 x 512 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/wind_streak_128.png — 128 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/wind_streak_128_2.png — 128 x 32 px ; 1 frame(s) ; diffuse_alpha
- game/assets/sprites/ambiance/wind_streak_128_3.png — 128 x 32 px ; 1 frame(s) ; diffuse_alpha
