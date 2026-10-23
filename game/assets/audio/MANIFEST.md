# MANIFEST audio Rainfall

Fichiers produits par synthese procedurale (scripts Codex dans `art/tools/audio/`, regenerables). Convention : id logique `a.b.c` -> `a_b_c_NN.ogg` (NN = variantes, tirage aleatoire par le systeme audio).
Format : .ogg Vorbis 44,1 kHz. Crete max mesuree <= -1 dBFS. Volume conseille = gain en dB a appliquer sur le bus (0 = tel quel).

| id logique (prefixe fichier) | dossier | variantes | duree (s) | boucle | niveau | crete dBFS | RMS dBFS | saut de boucle (x dev. moy.) | volume conseille |
|---|---|---|---|---|---|---|---|---|---|
| `amb_cite_rouille_decor` | ambience | 1 | 64.00-64.00 | oui | - | -5.8 | -26.5 | 0.5 | 0 dB |
| `amb_foret_brume_decor` | ambience | 1 | 64.00-64.00 | oui | - | -11.0 | -27.5 | 1.5 | 0 dB |
| `amb_rain` | ambience | 1 | 64.00-64.00 | oui | - | -8.6 | -24.3 | 0.4 | 0 dB |
| `amb_rain_heavy` | ambience | 1 | 64.00-64.00 | oui | heavy | -7.7 | -22.8 | 2.6 | 0 dB |
| `amb_rain_light` | ambience | 1 | 64.00-64.00 | oui | light | -10.3 | -25.7 | 0.4 | 0 dB |
| `amb_rain_medium` | ambience | 1 | 64.00-64.00 | oui | medium | -8.6 | -24.3 | 0.4 | 0 dB |
| `amb_terrasses_noyees_decor` | ambience | 1 | 64.00-64.00 | oui | - | -10.0 | -27.7 | 0.6 | 0 dB |
| `amb_thunder_close` | ambience | 4 | 4.99-5.12 | non | - | -6.3 | -19.6 | - | 0 dB |
| `amb_thunder_far` | ambience | 4 | 6.12-6.83 | non | - | -8.6 | -23.2 | - | 0 dB |
| `amb_wind` | ambience | 1 | 64.00-64.00 | oui | - | -8.4 | -24.0 | 0.9 | 0 dB |
| `amb_wind_cite_rouille` | ambience | 1 | 64.00-64.00 | oui | - | -5.3 | -23.6 | 0.4 | 0 dB |
| `amb_wind_foret_brume` | ambience | 1 | 64.00-64.00 | oui | - | -8.0 | -26.1 | 0.8 | 0 dB |
| `amb_wind_terrasses_noyees` | ambience | 1 | 64.00-64.00 | oui | - | -6.1 | -24.1 | 1.4 | 0 dB |
| `step_boss_dirt` | footsteps | 10 | 0.21-0.24 | non | - | -12.5 | -29.0 | - | -6 dB |
| `step_boss_grass` | footsteps | 5 | 0.22-0.24 | non | - | -13.8 | -29.1 | - | -6 dB |
| `step_boss_metal` | footsteps | 10 | 0.21-0.23 | non | - | -13.4 | -28.9 | - | -6 dB |
| `step_boss_stone` | footsteps | 5 | 0.21-0.22 | non | - | -16.4 | -29.0 | - | -6 dB |
| `step_boss_water` | footsteps | 5 | 0.22-0.24 | non | - | -15.3 | -29.2 | - | -6 dB |
| `step_boss_wet` | footsteps | 10 | 0.21-0.23 | non | - | -11.4 | -29.0 | - | -6 dB |
| `step_monster_t1_dirt` | footsteps | 5 | 0.09-0.09 | non | - | -16.6 | -29.0 | - | -6 dB |
| `step_monster_t1_grass` | footsteps | 5 | 0.09-0.12 | non | - | -16.2 | -29.2 | - | -6 dB |
| `step_monster_t1_metal` | footsteps | 5 | 0.09-0.09 | non | - | -13.4 | -28.9 | - | -6 dB |
| `step_monster_t1_stone` | footsteps | 5 | 0.09-0.12 | non | - | -16.0 | -29.7 | - | -6 dB |
| `step_monster_t1_water` | footsteps | 5 | 0.09-0.09 | non | - | -14.6 | -29.0 | - | -6 dB |
| `step_monster_t1_wet` | footsteps | 5 | 0.09-0.09 | non | - | -15.6 | -29.1 | - | -6 dB |
| `step_monster_t2_dirt` | footsteps | 10 | 0.11-0.20 | non | - | -11.9 | -28.9 | - | -6 dB |
| `step_monster_t2_grass` | footsteps | 5 | 0.11-0.20 | non | - | -14.5 | -29.0 | - | -6 dB |
| `step_monster_t2_metal` | footsteps | 10 | 0.11-0.20 | non | - | -9.9 | -29.0 | - | -6 dB |
| `step_monster_t2_stone` | footsteps | 5 | 0.11-0.23 | non | - | -16.8 | -29.1 | - | -6 dB |
| `step_monster_t2_water` | footsteps | 5 | 0.11-0.20 | non | - | -16.4 | -29.0 | - | -6 dB |
| `step_monster_t2_wet` | footsteps | 10 | 0.11-0.20 | non | - | -10.9 | -29.0 | - | -6 dB |
| `step_monster_t3_dirt` | footsteps | 10 | 0.18-0.24 | non | - | -13.2 | -29.0 | - | -6 dB |
| `step_monster_t3_grass` | footsteps | 5 | 0.21-0.22 | non | - | -14.2 | -29.0 | - | -6 dB |
| `step_monster_t3_metal` | footsteps | 10 | 0.18-0.22 | non | - | -12.5 | -28.9 | - | -6 dB |
| `step_monster_t3_stone` | footsteps | 5 | 0.21-0.22 | non | - | -15.8 | -29.0 | - | -6 dB |
| `step_monster_t3_water` | footsteps | 5 | 0.21-0.24 | non | - | -15.5 | -29.1 | - | -6 dB |
| `step_monster_t3_wet` | footsteps | 10 | 0.18-0.23 | non | - | -11.3 | -29.0 | - | -6 dB |
| `step_player_dirt` | footsteps | 5 | 0.12-0.15 | non | - | -13.8 | -28.9 | - | -6 dB |
| `step_player_grass` | footsteps | 5 | 0.12-0.14 | non | - | -14.3 | -29.3 | - | -6 dB |
| `step_player_metal` | footsteps | 5 | 0.12-0.12 | non | - | -13.1 | -28.9 | - | -6 dB |
| `step_player_stone` | footsteps | 5 | 0.12-0.12 | non | - | -16.3 | -29.0 | - | -6 dB |
| `step_player_water` | footsteps | 5 | 0.12-0.14 | non | - | -16.5 | -29.2 | - | -6 dB |
| `step_player_wet` | footsteps | 5 | 0.12-0.12 | non | - | -12.7 | -29.0 | - | -6 dB |
| `boss_defeat` | impacts | 3 | 4.57-4.63 | non | - | -6.9 | -18.0 | - | 0 dB |
| `boss_spawn` | impacts | 3 | 3.63-3.64 | non | - | -7.2 | -18.0 | - | 0 dB |
| `death_boss_heavy` | impacts | 3 | 2.58-2.75 | non | heavy | -4.3 | -18.3 | - | 0 dB |
| `death_elite` | impacts | 4 | 0.92-0.96 | non | - | -3.6 | -18.3 | - | 0 dB |
| `death_t1` | impacts | 4 | 0.22-0.25 | non | - | -4.4 | -18.4 | - | 0 dB |
| `death_t2` | impacts | 4 | 0.37-0.41 | non | - | -3.4 | -18.4 | - | 0 dB |
| `death_t3` | impacts | 4 | 0.61-0.63 | non | - | -3.7 | -18.3 | - | 0 dB |
| `death_t4` | impacts | 3 | 1.76-1.81 | non | - | -3.0 | -18.0 | - | 0 dB |
| `enemy_brute_cone_heavy` | impacts | 4 | 0.60-0.60 | non | heavy | -4.7 | -18.4 | - | 0 dB |
| `enemy_contact_light` | impacts | 4 | 0.17-0.21 | non | light | -3.2 | -18.4 | - | 0 dB |
| `enemy_shockwave_heavy` | impacts | 4 | 0.98-1.05 | non | heavy | -3.1 | -18.3 | - | 0 dB |
| `enemy_shot_medium` | impacts | 4 | 0.25-0.26 | non | medium | -4.2 | -18.3 | - | 0 dB |
| `hit_crit` | impacts | 4 | 0.37-0.40 | non | - | -6.4 | -18.3 | - | 0 dB |
| `hit_fire_heavy` | impacts | 3 | 0.71-0.72 | non | heavy | -5.5 | -18.0 | - | 0 dB |
| `hit_fire_light` | impacts | 3 | 0.31-0.32 | non | light | -2.5 | -18.0 | - | 0 dB |
| `hit_fire_medium` | impacts | 3 | 0.47-0.49 | non | medium | -2.5 | -18.0 | - | 0 dB |
| `hit_heavy` | impacts | 4 | 0.37-0.40 | non | heavy | -6.4 | -18.3 | - | 0 dB |
| `hit_ice_heavy` | impacts | 3 | 0.71-0.72 | non | heavy | -4.9 | -18.0 | - | 0 dB |
| `hit_ice_light` | impacts | 3 | 0.31-0.32 | non | light | -4.5 | -18.0 | - | 0 dB |
| `hit_ice_medium` | impacts | 3 | 0.47-0.49 | non | medium | -5.0 | -18.0 | - | 0 dB |
| `hit_light` | impacts | 4 | 0.16-0.16 | non | light | -3.7 | -18.2 | - | 0 dB |
| `hit_lightning_heavy` | impacts | 3 | 0.73-0.73 | non | heavy | -3.1 | -18.0 | - | 0 dB |
| `hit_lightning_light` | impacts | 3 | 0.31-0.32 | non | light | -4.9 | -18.0 | - | 0 dB |
| `hit_lightning_medium` | impacts | 3 | 0.48-0.49 | non | medium | -5.2 | -18.0 | - | 0 dB |
| `hit_medium` | impacts | 3 | 0.26-0.27 | non | medium | -3.6 | -18.0 | - | 0 dB |
| `hit_poison_heavy` | impacts | 3 | 0.71-0.74 | non | heavy | -3.3 | -18.1 | - | 0 dB |
| `hit_poison_light` | impacts | 3 | 0.31-0.32 | non | light | -5.9 | -18.0 | - | 0 dB |
| `hit_poison_medium` | impacts | 3 | 0.47-0.48 | non | medium | -2.7 | -18.0 | - | 0 dB |
| `lightning_chain_medium` | impacts | 4 | 0.55-0.58 | non | medium | -3.1 | -18.4 | - | 0 dB |
| `player_death` | impacts | 4 | 1.50-1.50 | non | - | -3.0 | -18.3 | - | 0 dB |
| `player_heal` | impacts | 4 | 0.67-0.71 | non | - | -4.9 | -18.2 | - | 0 dB |
| `player_hurt` | impacts | 4 | 0.30-0.30 | non | - | -5.4 | -18.3 | - | 0 dB |
| `stage_cleared` | impacts | 3 | 2.57-2.61 | non | - | -9.2 | -20.0 | - | 0 dB |
| `status_burn_light` | impacts | 4 | 0.30-0.30 | non | light | -3.0 | -18.4 | - | 0 dB |
| `status_frost_light` | impacts | 4 | 0.42-0.46 | non | light | -3.9 | -18.5 | - | 0 dB |
| `status_poison_light` | impacts | 4 | 0.37-0.39 | non | light | -7.7 | -18.2 | - | 0 dB |
| `telegraph_boss_heavy` | impacts | 4 | 1.72-1.76 | non | heavy | -3.2 | -18.3 | - | 0 dB |
| `telegraph_warn_heavy_heavy` | impacts | 4 | 1.07-1.11 | non | heavy | -5.3 | -18.3 | - | 0 dB |
| `telegraph_warn_light_light` | impacts | 4 | 0.76-0.83 | non | light | -3.2 | -18.3 | - | 0 dB |
| `music_boss_cite_rouille` | music | 1 | 106.67-106.67 | oui | - | -2.9 | -17.0 | 4.4 | 0 dB |
| `music_boss_foret_brume` | music | 1 | 112.00-112.00 | oui | - | -3.3 | -17.0 | 9.5 | 0 dB |
| `music_boss_terrasses_noyees` | music | 1 | 102.86-102.86 | oui | - | -2.5 | -17.0 | 3.2 | 0 dB |
| `music_cite_rouille_base` | music | 1 | 102.86-102.86 | oui | - | -8.4 | -23.0 | 0.4 | 0 dB |
| `music_cite_rouille_climax` | music | 1 | 102.86-102.86 | oui | - | -8.8 | -24.0 | 15.3 | 0 dB |
| `music_cite_rouille_drive` | music | 1 | 102.86-102.86 | oui | - | -11.2 | -25.0 | 0.6 | 0 dB |
| `music_cite_rouille_tension` | music | 1 | 102.86-102.86 | oui | - | -9.9 | -25.5 | 0.5 | 0 dB |
| `music_foret_brume_base` | music | 1 | 120.00-120.00 | oui | - | -8.9 | -23.0 | 0.2 | 0 dB |
| `music_foret_brume_climax` | music | 1 | 120.00-120.00 | oui | - | -8.7 | -24.0 | 0.4 | 0 dB |
| `music_foret_brume_drive` | music | 1 | 120.00-120.00 | oui | - | -9.4 | -25.0 | 0.9 | 0 dB |
| `music_foret_brume_tension` | music | 1 | 120.00-120.00 | oui | - | -8.3 | -25.5 | 0.4 | 0 dB |
| `music_menu` | music | 1 | 96.00-96.00 | oui | - | -4.2 | -22.0 | 0.0 | 0 dB |
| `music_terrasses_noyees_base` | music | 1 | 106.67-106.67 | oui | - | -8.8 | -23.0 | 0.3 | 0 dB |
| `music_terrasses_noyees_climax` | music | 1 | 106.67-106.67 | oui | - | -9.4 | -24.0 | 0.2 | 0 dB |
| `music_terrasses_noyees_drive` | music | 1 | 106.67-106.67 | oui | - | -9.9 | -25.0 | 0.7 | 0 dB |
| `music_terrasses_noyees_tension` | music | 1 | 106.67-106.67 | oui | - | -9.2 | -25.5 | 0.1 | 0 dB |
| `spell_brasier_cast_heavy` | spells | 3 | 2.95-2.95 | non | heavy | -3.0 | -18.3 | - | 0 dB |
| `spell_brasier_cast_light` | spells | 3 | 1.35-1.35 | non | light | -2.8 | -18.1 | - | 0 dB |
| `spell_brasier_cast_medium` | spells | 3 | 2.10-2.10 | non | medium | -3.0 | -18.1 | - | 0 dB |
| `spell_cendres_cast_heavy` | spells | 2 | 4.00-4.00 | oui | heavy | -14.5 | -24.2 | 0.0 | 0 dB |
| `spell_cendres_cast_light` | spells | 2 | 4.00-4.00 | oui | light | -12.0 | -24.1 | 0.0 | 0 dB |
| `spell_cendres_cast_medium` | spells | 2 | 4.00-4.00 | oui | medium | -13.7 | -24.1 | 0.0 | 0 dB |
| `spell_eclat_de_braise_cast_heavy` | spells | 3 | 0.67-0.67 | non | heavy | -3.8 | -18.0 | - | 0 dB |
| `spell_eclat_de_braise_cast_light` | spells | 3 | 0.28-0.28 | non | light | -2.7 | -18.1 | - | 0 dB |
| `spell_eclat_de_braise_cast_medium` | spells | 3 | 0.45-0.45 | non | medium | -4.0 | -18.0 | - | 0 dB |
| `spell_eclat_de_braise_hit_heavy` | spells | 3 | 0.98-0.98 | non | heavy | -3.3 | -18.1 | - | 0 dB |
| `spell_eclat_de_braise_hit_light` | spells | 3 | 0.38-0.38 | non | light | -2.7 | -19.1 | - | 0 dB |
| `spell_eclat_de_braise_hit_medium` | spells | 3 | 0.65-0.65 | non | medium | -3.0 | -18.1 | - | 0 dB |
| `spell_flame_pillar_heavy` | spells | 3 | 2.10-2.10 | non | heavy | -3.1 | -18.3 | - | 0 dB |
| `spell_flame_pillar_light` | spells | 3 | 0.90-0.90 | non | light | -3.4 | -18.1 | - | 0 dB |
| `spell_flame_pillar_medium` | spells | 3 | 1.45-1.45 | non | medium | -3.6 | -18.1 | - | 0 dB |
| `spell_meteor_rain_heavy` | spells | 3 | 3.00-3.00 | non | heavy | -3.4 | -18.2 | - | 0 dB |
| `spell_meteor_rain_light` | spells | 3 | 1.70-1.70 | non | light | -2.8 | -18.1 | - | 0 dB |
| `spell_meteor_rain_medium` | spells | 3 | 2.35-2.35 | non | medium | -3.0 | -18.2 | - | 0 dB |
| `spell_nova_ardente_cast_heavy` | spells | 3 | 2.18-2.18 | non | heavy | -2.7 | -18.4 | - | 0 dB |
| `spell_nova_ardente_cast_light` | spells | 3 | 0.95-0.97 | non | light | -3.2 | -18.2 | - | 0 dB |
| `spell_nova_ardente_cast_medium` | spells | 3 | 1.50-1.50 | non | medium | -2.6 | -18.2 | - | 0 dB |
| `spell_phoenix_heavy` | spells | 3 | 2.95-2.95 | non | heavy | -5.2 | -18.1 | - | 0 dB |
| `spell_phoenix_light` | spells | 3 | 2.05-2.05 | non | light | -5.4 | -18.1 | - | 0 dB |
| `spell_phoenix_medium` | spells | 3 | 2.50-2.50 | non | medium | -6.0 | -18.1 | - | 0 dB |
| `spell_roaming_embers_loop_heavy` | spells | 2 | 3.00-3.00 | oui | heavy | -13.6 | -24.2 | 0.0 | 0 dB |
| `spell_roaming_embers_loop_light` | spells | 2 | 3.00-3.00 | oui | light | -11.3 | -24.2 | 0.0 | 0 dB |
| `spell_roaming_embers_loop_medium` | spells | 2 | 3.00-3.00 | oui | medium | -12.7 | -24.2 | 0.0 | 0 dB |
| `spell_roaming_embers_start_heavy` | spells | 3 | 1.15-1.15 | non | heavy | -3.4 | -18.3 | - | 0 dB |
| `spell_roaming_embers_start_light` | spells | 3 | 0.55-0.55 | non | light | -3.3 | -18.3 | - | 0 dB |
| `spell_roaming_embers_start_medium` | spells | 3 | 0.80-0.80 | non | medium | -2.6 | -18.2 | - | 0 dB |
| `spell_ultimate` | spells | 3 | 2.95-2.95 | non | - | -3.0 | -18.3 | - | 0 dB |
| `chest_legendary_impact` | ui | 2 | 6.56-6.79 | non | - | -1.5 | -17.2 | - | 0 dB |
| `chest_legendary_rise` | ui | 2 | 3.80-3.80 | non | - | -1.6 | -17.5 | - | 0 dB |
| `chest_lock` | ui | 3 | 0.98-1.03 | non | - | -2.0 | -20.0 | - | 0 dB |
| `chest_open_boss` | ui | 2 | 6.25-6.38 | non | - | -1.9 | -17.2 | - | 0 dB |
| `chest_open_large` | ui | 3 | 4.33-4.44 | non | - | -2.6 | -18.7 | - | 0 dB |
| `chest_open_legendaire` | ui | 2 | 5.95-6.04 | non | - | -2.0 | -17.8 | - | 0 dB |
| `chest_open_petit` | ui | 3 | 2.68-2.68 | non | - | -2.8 | -19.3 | - | 0 dB |
| `chest_reveal` | ui | 3 | 3.49-3.54 | non | - | -2.3 | -19.8 | - | 0 dB |
| `pickup_coin` | ui | 4 | 0.46-0.46 | non | - | -1.5 | -14.2 | - | 0 dB |
| `pickup_ruby` | ui | 3 | 2.46-2.65 | non | - | -3.4 | -20.8 | - | 0 dB |
| `pickup_xp` | ui | 4 | 0.66-0.69 | non | - | -6.8 | -23.5 | - | 0 dB |
| `ui_click` | ui | 4 | 0.09-0.09 | non | - | -4.1 | -24.5 | - | 0 dB |
| `ui_dice` | ui | 4 | 1.44-1.65 | non | - | -2.1 | -20.8 | - | 0 dB |
| `ui_item_pick` | ui | 3 | 2.68-2.68 | non | - | -4.6 | -19.6 | - | 0 dB |
| `ui_level_up` | ui | 2 | 3.96-4.14 | non | - | -2.7 | -19.3 | - | 0 dB |
| `ui_spell_ready` | ui | 3 | 1.30-1.34 | non | - | -4.0 | -21.9 | - | 0 dB |

## Usage prevu
- spells : `spell_eclat_de_braise_cast/hit_*` (id `spell.eclat_de_braise.cast`, `.hit_light|medium|heavy`), `spell_nova_ardente_cast_*`, `spell_cendres_cast_*` (BOUCLE 4 s, zone), `spell_brasier_cast_*`, `spell_ultimate`; variantes B : `spell_flame_pillar`, `spell_meteor_rain`, `spell_phoenix`, `spell_roaming_embers_start/loop` (boucle 3 s). Le jeu choisit light/medium/heavy selon les degats puis module hauteur (jusqu a +-12 %) et volume.
- impacts : `hit_light/medium/heavy`, `hit_crit` (crack), `hit_<fire|ice|poison|lightning>_<niveau>`, `status_*`, `lightning_chain_medium`, `death_t1..t4`, `death_elite`, `death_boss_heavy`, `enemy_*` (contact, tir, cone de la brute, onde de choc), `telegraph_*` (montees d alerte), `player_hurt/death/heal`, `boss_spawn`, `boss_defeat`, `stage_cleared` (ids `boss.spawn`, `boss.defeat`, `stage.cleared` : deja livres, non regeneres).
- footsteps : `step_<player|monster_t1|monster_t2|monster_t3|boss>_<stone|wet|water|dirt|grass|metal>` ; plus fichiers par sujet detailles (`step_ardent`, `step_swarm`, etc. deja fusionnes dans les ids ci-dessus).

## Lot 2 : ambiances, UI/coffres, musiques (synthese Claude, intérim Codex)
Scripts : `art/tools/audio/synth_lib.py` (DSP : oscillateurs a table d ondes, piano/harpe/cloche/flute/cordes/cuivres/choeur/percussions, reverberation a convolution synthetique circulaire), `gen_ambience.py`, `gen_ui.py`, `gen_music.py` (partitions ecrites dans le dict `CFG`/`BOSS`/`MENU`), `verify_new.py` (controle numerique), `build_manifest.py` (ce fichier). Tout est reproductible (`--seed`, `--only`). Remplacable a l identique par Codex (memes noms).

**Ambiances** (dossier `ambience/`, ogg q4, stereo, boucles de 64 s a raccord circulaire ; RMS cible -22,5 a -27,5 dBFS) :

| id logique | fichier(s) | note |
|---|---|---|
| `amb.rain` | `amb_rain_01` (= moyenne) | pluie par defaut |
| `amb.rain.light/medium/heavy` | `amb_rain_light_01`, `amb_rain_medium_01`, `amb_rain_heavy_01` | 3 intensites (a router par palier de difficulte ; le dict `maps` actuel n utilise que `amb.rain`) |
| `amb.wind` | `amb_wind_01` | vent intermediaire generique |
| `amb.wind.cite_rouille` | `amb_wind_cite_rouille_01` | tres venteux, sifflements metalliques, grincements |
| `amb.wind.foret_brume` | `amb_wind_foret_brume_01` | calme, bruissements de feuillage |
| `amb.wind.terrasses_noyees` | `amb_wind_terrasses_noyees_01` | ouvert, creux, ruissellement leger |
| `amb.<carte>.decor` | `amb_terrasses_noyees_decor_01`, `amb_foret_brume_decor_01`, `amb_cite_rouille_decor_01` | decors par carte |
| `amb.thunder_close` / `amb.thunder_far` | `amb_thunder_close_01..04`, `amb_thunder_far_01..04` | one-shots (non boucle) |

Contrat a noter pour l orchestrateur : `sounds.json` reference `amb.wind` pour la Cite et les Terrasses et rien pour la Foret ; pour le vent propre a chaque carte, utiliser les ids `amb.wind.cite_rouille`, `amb.wind.terrasses_noyees`, `amb.wind.foret_brume` (le fichier `amb_wind_cite_rouille_01.ogg` est trouve par la regle `.` -> `_`), et `amb.rain.light|medium|heavy` pour router la pluie par palier.

**UI / recompenses / coffres** (dossier `ui/`, ogg q5, stereo, RMS utile ~ -20 dBFS, crete <= -1,5 dBFS) : `pickup_coin` (4), `pickup_xp` (4), `pickup_ruby` (3), `ui_click` (4), `ui_level_up` (2), `ui_spell_ready` (3), `ui_dice` (4), `ui_item_pick` (3), `chest_lock` (3), `chest_open_petit|large|legendaire|boss` (3/3/2/2), `chest_reveal` (3), `chest_legendary_rise` (2, ~3,8 s), `chest_legendary_impact` (2). Ids : `pickup.coin`, `chest.open.petit`, `chest.legendary.rise`, etc. (`.` -> `_`). `boss.spawn`, `boss.defeat`, `stage.cleared` : voir dossier `impacts/` (lot 1).

**Musiques** (dossier `music/`, ogg q4, stereo, boucles) :

| id logique | fichier | tempo / tonalite | duree |
|---|---|---|---|
| `music.terrasses_noyees.base/tension/drive/climax` | `music_terrasses_noyees_<stem>_01` | 72 BPM, re eolien (piano, harpe, cloches) | 32 mesures = 106,67 s |
| `music.foret_brume.base/tension/drive/climax` | `music_foret_brume_<stem>_01` | 64 BPM, mi dorien (flute, cordes pincees, pads) | 32 mesures = 120,00 s |
| `music.cite_rouille.base/tension/drive/climax` | `music_cite_rouille_<stem>_01` | 84 BPM, do phrygien (cordes graves, metal, drones) | 36 mesures = 102,86 s |
| `music.boss.terrasses_noyees` | `music_boss_terrasses_noyees_01` | 112 BPM, re mineur (cuivres, eau, tambours) | 48 mesures |
| `music.boss.foret_brume` | `music_boss_foret_brume_01` | 120 BPM, mi dorien/phrygien (bois, tambours de troncs) | 56 mesures |
| `music.boss.cite_rouille` | `music_boss_cite_rouille_01` | 126 BPM, do phrygien (cloches dissonantes, choeur grave) | 56 mesures |
| `music.menu` | `music_menu_01` | 60 BPM, la mineur, feu de camp, pluie lointaine | 24 mesures = 96 s |

Les 4 stems d une carte ont exactement le meme nombre d echantillons et demarrent ensemble (verifie par `verify_new.py`). Le raccord est circulaire (queues de reverb repliees sur le debut).

Niveaux des stems : RMS base -23, tension -25,5, drive -25, climax -24 dBFS (crete <= -8,3 dBFS). Somme au palier 4 du `sounds.json` (-3/-4/-1/0 dB) : crete -1,3 dBFS (Terrasses, Foret) et -2,2 dBFS (Cite) ; sans gain de palier, la somme brute des 4 stems peut depasser 0 dBFS (bus Music a laisser avec limiteur ou -2 dB).
Boucles : encodees en Vorbis q6 (les q inferieures laissent un petit ecart de codec au raccord du fichier) ; verification LPC du raccord sur le .ogg decode (`verify_new.py`).
Remplacement des ids lot 1 : `boss.spawn`, `boss.defeat`, `stage.cleared` existent deja dans `impacts/`.

<!-- AU1 -->
## AU1 — Tocsin et Averse
Synthèse numpy/scipy, graine fixe 22102600 ; Vorbis q5, 44100 Hz stéréo. Cuivre chauffé, maillons usés et cliquet de touret ; langue humide, roseaux, vase et crue ; puissance croissante, registre descendant. Relance : art/tools/audio/au1_build.py.

- tocsin_rivets_rougis : 18 fichiers cast + hit, light/medium/heavy ; 0.17–0.60 s ; crête -3.70 dBFS ; RMS -21.05–-18.95 dBFS.
- tocsin_bras_grappins : 6 fichiers cast, light/medium/heavy ; 0.55–1.15 s ; crête -3.38 dBFS ; RMS -21.01–-19.00 dBFS.
- tocsin_coups_de_botte : 6 fichiers cast, light/medium/heavy ; 0.48–1.05 s ; crête -4.51 dBFS ; RMS -20.96–-19.00 dBFS.
- tocsin_tete_cloche : 6 fichiers cast, light/medium/heavy ; 1.15–2.50 s ; crête -6.37 dBFS ; RMS -20.98–-18.99 dBFS.
- goutte_lame : 18 fichiers cast + hit, light/medium/heavy ; 0.17–0.60 s ; crête -2.55 dBFS ; RMS -21.45–-19.65 dBFS.
- vague : 6 fichiers cast, light/medium/heavy ; 0.70–1.70 s ; crête -3.25 dBFS ; RMS -21.16–-19.14 dBFS.
- flaque_miroir : 6 fichiers cast, light/medium/heavy ; 0.65–1.45 s ; crête -3.98 dBFS ; RMS -21.13–-19.12 dBFS.
- crue : 6 fichiers cast, light/medium/heavy ; 1.35–2.80 s ; crête -4.18 dBFS ; RMS -21.10–-19.07 dBFS.

<!-- AU2 -->
## AU2 — Arpenteuse et Rainette
Synthèse numpy/scipy, graine fixe 22102680 ; Vorbis q5, 44100 Hz stéréo. Cuivre chauffé, maillons usés et cliquet de touret ; langue humide, roseaux, vase et crue ; puissance croissante, registre descendant. Relance : art/tools/audio/au2_build.py.

- arpenteuse_chaine : 9 fichiers (hit seul), light/medium/heavy ; 0.13–0.27 s ; crête -4.13 dBFS ; RMS -22.01–-18.98 dBFS.
- arpenteuse_boucle : 6 fichiers (cast), light/medium/heavy ; 0.52–1.18 s ; crête -2.98 dBFS ; RMS -21.38–-19.43 dBFS.
- arpenteuse_piquet : 6 fichiers (cast), light/medium/heavy ; 0.45–1.04 s ; crête -3.30 dBFS ; RMS -20.97–-18.98 dBFS.
- arpenteuse_tendeur : 6 fichiers (cast), light/medium/heavy ; 1.05–2.20 s ; crête -3.26 dBFS ; RMS -21.05–-19.03 dBFS.
- rainette_langue : 18 fichiers (cast + hit), light/medium/heavy ; 0.12–0.43 s ; crête -3.26 dBFS ; RMS -22.39–-19.08 dBFS.
- rainette_grand_saut : 6 fichiers (cast), light/medium/heavy ; 0.65–1.48 s ; crête -3.17 dBFS ; RMS -21.09–-19.59 dBFS.
- rainette_gluant : 6 fichiers (cast), light/medium/heavy ; 0.46–1.06 s ; crête -2.82 dBFS ; RMS -21.60–-20.30 dBFS.
- rainette_chant_de_crue : 6 fichiers (cast), light/medium/heavy ; 1.40–2.80 s ; crête -3.48 dBFS ; RMS -21.02–-19.55 dBFS.

<!-- AU3 -->
## AU3 - Avare et Bourbe
Synthese procedurale numpy/scipy, graine fixe 22102690 ; Ogg Vorbis q5, 44100 Hz stereo. Bois cercle de fer, chaines et or use ; vase, racines et bronze etouffe. Trois puissances plus longues, graves et denses. Relance : art/tools/audio/au3_build.py.

- avare_coup_de_coffre : 18 fichiers (cast + hit) ; 0.14 - 0.72 s ; crete -3.23 dBFS ; RMS -22.46 - -18.99 dBFS.
- avare_poignee_de_pieces : 6 fichiers (cast) ; 0.30 - 0.76 s ; crete -5.37 dBFS ; RMS -21.11 - -19.15 dBFS.
- avare_rancon : 6 fichiers (cast) ; 0.58 - 1.35 s ; crete -3.23 dBFS ; RMS -21.49 - -20.79 dBFS.
- avare_faillite : 6 fichiers (cast) ; 1.25 - 2.60 s ; crete -1.52 dBFS ; RMS -22.09 - -21.55 dBFS.
- gifle_de_vase : 18 fichiers (cast + hit) ; 0.14 - 0.53 s ; crete -3.37 dBFS ; RMS -22.26 - -19.04 dBFS.
- detacher : 6 fichiers (cast) ; 0.19 - 0.79 s ; crete -3.09 dBFS ; RMS -24.11 - -20.31 dBFS.
- rappel : 6 fichiers (cast) ; 0.48 - 1.15 s ; crete -4.50 dBFS ; RMS -21.16 - -19.11 dBFS.
- bourbier : 6 fichiers (cast) ; 1.30 - 2.80 s ; crete -5.29 dBFS ; RMS -21.06 - -19.04 dBFS.
