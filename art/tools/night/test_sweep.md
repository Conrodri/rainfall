# Balayage complet des tests (22/10/2026, agent de consolidation)

Godot 4.7.2 console, un test à la fois (`--headless`, drapeaux de l'en-tête du test, ex. `--fixed-fps 60`).
Scènes : `res://tests/<nom>.tscn` ; scripts : `--script res://tests/<nom>.gd` (test_balance, enemies_kill, enemies_director).
Non comptés (pas de `RESULT`, outils de capture ou bancs) : ambiance_bench, perf_bench, audio_gen_layout, capture_* (21), *_capture (6), sondes ambiance_probe*.

Bilan final : **76 tests, 74 OK, 2 FAIL** (durée cumulée ~30 min).
- Passe 1 (13h28-14h00) : 60 tests, 57 OK ; échecs dus aux éditions simultanées d'autres agents (recluse_fx, DeepEelBrain/JarBearerBrain/RenderStyle pas encore dans le cache de classes) -> relancés OK.
- Passe 2 (14h14-14h58, 76 tests avec les nouveaux tests de boss/mini-boss/barres) ; relances isolées sur machine calme (0 autre Godot, 15h00) pour enemies_perf, render_perf_test, floor1_boss_test (timeout en passe 2 : enemy_health_bars.gd en cours d'édition), texture_budget_test.

| Test | Résultat | Durée (s) |
|---|---|---|
| test_balance | OK | 0.7 |
| enemies_kill | OK | 2.6 |
| enemies_director | OK | 5.8 |
| action_vfx_test | OK | 2.8 |
| ambiance_test | OK | 2.8 |
| arpenteuse_test | OK | 7.4 |
| audio_director_test | OK | 9.0 |
| audio_test | OK | 9.6 |
| avare_test | OK | 11.0 |
| averse_test | OK | 9.3 |
| balance_sim_run | OK | 199.2 |
| balance_sim_test | OK | 23.7 |
| biome_fauna_test | OK | 3.0 |
| bourbe_test | OK | 2.7 |
| capsule_test | OK | 3.8 |
| cerf_boss_test | OK | 57.0 |
| chest_card_fit_test | OK | 5.8 |
| cite_iso_test | OK | 15.4 |
| crane_boss_test | OK | 65.0 |
| cryptes_iso_test | OK | 9.2 |
| crystal_mother_boss_test | OK | 60.8 |
| deep_eel_boss_test | OK | 66.2 |
| eclusier_boss_test | OK | 62.3 |
| economy_test | OK | 0.6 |
| end_run_test | OK | 2.1 |
| enemies_map_test | OK | 6.2 |
| floor1_boss_test | OK | 8.3 |
| floor2_boss_test | OK | 44.1 |
| floor3_boss_test | OK | 44.6 |
| floor4_boss_test | OK | 33.9 |
| foret_iso_test | OK | 15.0 |
| hermit_cedar_boss_test | OK | 66.2 |
| hp_bars_test | OK | 15.6 |
| hud_overlays_test | OK | 8.9 |
| integration_test | OK | 14.5 |
| jar_bearer_boss_test | OK | 61.8 |
| loot_test | OK | 3.0 |
| loot_ui_test | OK | 8.3 |
| maps_test | OK | 1.1 |
| menu_flow_test | OK | 10.4 |
| minibosses_test | OK | 287.0 |
| minimap_iso_test | OK | 11.3 |
| new_run_layout_test | OK | 2.9 |
| new_run_test | OK | 4.8 |
| objectives_test | OK | 6.1 |
| ox_herder_boss_test | OK | 62.2 |
| pickup_chase_test | OK | 1.8 |
| platform_aim_test | OK | 2.1 |
| platform_input_test | OK | 0.7 |
| platform_layout_test | OK | 11.5 |
| player_hurt_iso_test | OK | 17.8 |
| player_test | OK | 2.9 |
| progress_layout_test | OK | 1.1 |
| rain_sower_boss_test | OK | 66.6 |
| rainette_test | OK | 9.7 |
| recluse_boss_test | OK | 60.8 |
| render_perf_test | **FAIL** | 9.7 |
| render_style_test | OK | 2.2 |
| rictus_test | OK | 13.6 |
| run_flow_test | OK | 9.7 |
| save_test | OK | 9.6 |
| settings_test | OK | 1.1 |
| smelter_boss_test | OK | 66.6 |
| sonneur_boss_test | OK | 64.3 |
| source_arena_test | OK | 5.4 |
| spell_tooltip_test | OK | 4.5 |
| sprites_test | OK | 2.5 |
| stage_test | OK | 8.8 |
| texture_budget_test | **FAIL** | 18.7 |
| title_test | OK | 3.8 |
| tocsin_test | OK | 3.2 |
| touch_layout_test | OK | 3.2 |
| ui_test_hud_pickups | OK | 5.0 |
| ui_theme_test | OK | 0.7 |
| weaver_boss_test | OK | 59.3 |
| enemies_perf | OK | 4.9 |

## Échecs restants (non corrigés ici, à la racine ailleurs)
- **render_perf_test** : `health_bars 0,30-0,31 ms > budget 0,30 ms` sur machine calme (enemies_perf phase C : 0,333 < 0,35 ms, OK de justesse). Régression liée aux barres « riches » / statuts ajoutées aujourd'hui dans `scripts/fx/enemy_health_bars.gd` (édité 14h12 et 14h50 par l'agent Barres de PV, toujours actif) : à optimiser par cet agent, budget non relâché. (Correctif annexe : le test quittait avec le code 0 en échec -> `quit(1)`.)
- **texture_budget_test** : `textures mobiles 207 Mo > 180 Mo` (APK estimé 312 Mo). Toutes les catégories sont sous leur budget propre, c'est le total qui déborde avec les livraisons Codex du jour (Bourbe, Avare, Rainette, boss, faune). Racine = assets : palier 2 « R1 tailles d'affichage » (re-rendus Codex à la taille d'affichage, couches de Tocsin rognées, wave_cone 6144×8192 d'Averse AV3). Budget non relâché. (L'autre échec vu en passe 1, `.import` non conformes de leaper_tier2_moss, était une livraison Codex pas encore importée : conforme à la relance.)

## Corrigé pendant le balayage
- **enemies_perf** (médiane Director B 1,45 ms > 1,3 sous charge) : passe Director — `NavField.steer_walls_many` (flux + drapeau « mur à portée » en une passe) et `Enemy.tick(..., near_wall)` qui saute `NavField.resolve` loin des murs (98 % des monstres sur foret_brume). Machine calme : A 0,93-0,94 / B 1,08-1,09 ms (avant : B 1,45) ; sous charge (10-12 Godot) B ≈ 1,2 ms.
- **cerf_boss_test en capture fenêtrée** (2 échecs : charges ≥ 2, 6 octants) : le mode `-- capture` raccourcissait la phase 1 à 8 × 1,5 s alors que les vérifications supposent 8 × 2,6 s. Durée identique en capture et en headless -> capture fenêtrée `shots=` : RESULT OK (21 images).
- **recluse_boss_test** (angle des rayons parfois instable) : l'écart net début/fin dépendait de l'instant d'échantillonnage (les rayons repartent en arrière à chaque inversion). Remplacé par la rotation cumulée (somme des |pas|), exigée >= 3 s à 20°/s (RAY_TURN × 3 ≈ 1,05 rad, plus strict que l'ancien 0,3 rad).
- **audio_test** écrivait le vrai `user://settings.cfg` : `Audio.settings_path` injectable + garde headless/capture dans `save_settings()` (comme GameSettings) ; le test vérifie que le fichier du joueur est inchangé.
- **rain_sower_boss_test** : seuils 70/35 % vérifiés (Balance + bascule à 69 % et 34,5 % des PV).
