# Design isométrique (dimétrique 2:1) — plan de migration

Statut : **fait autorité** pour la caméra, les repères, les assets et l'ordre des travaux (décision du joueur, 21/10/2026). Remplace les règles de caméra de art/briefs/STYLE.md, terrain_brief.md, monsters.md, vfx.md en cas de conflit.

Résumé : **le gameplay reste dans un plan de sol carré, 1 u = 64 px dans toutes les directions ; seul l'affichage est projeté.** Les axes de ce plan de sol (« repère logique ») sont alignés sur l'écran ; la caméra écrase la hauteur de moitié (zoom non uniforme) ; la grille de la carte (tuiles, murs) est tournée de 45° dans ce repère. Physique, distances, `Balance` et tri en profondeur restent exacts.

---

## §1 Spécification caméra

### 1.1 Géométrie
| Grandeur | Valeur |
|---|---|
| Projection | orthographique, dimétrique 2:1 |
| Élévation | **30°** au-dessus de l'horizon ; écrasement du sol = sin 30° = **0,5** → losanges exactement 2:1 (arête à 26,57° à l'écran) |
| Lacet | **45°** entre la grille de carte et l'écran : une cellule devient un losange, les rangées de « # » des diagonales |
| Hauteurs verticales | un objet de h u mesure h × cos 30° = **0,866 h** de son équivalent au sol horizontal |
| Sens de la grille | carte +x → bas-droite de l'écran ; carte +y → bas-gauche. La rangée nord des grilles ASCII = arête haut-droite du losange (`TILE_LAYOUT_DIAMOND_DOWN`) |

### 1.2 Trois repères
1. **Carte (M)** : grilles ASCII et .tscn générés ; cellule = 2 u = 128 px ; origine au centre. Collisions des murs, marqueurs, NavField, minimap, eau.
2. **Logique (L)** : le repère du jeu. Plan de sol orthonormé, **64 px/u partout**, x = droite écran, y = bas écran (profondeur). `L = Rot(+45°) · M`. Physique, `distance_to`, `Balance`, Director, sorts, télégraphes, lumières, souris (`get_global_mouse_position()` est déjà en L).
3. **Écran (S)** : `S = Zoom · (L − caméra)`, `Zoom = (Z, Z/2)`.

### 1.3 Échelle et zoom (`Iso.SCREEN_PX_PER_U` = s)
| s | `Camera2D.zoom` | Vue en u (1920×1080) | Aire de sol | Taille persos | Demi-étendue mini |
|---|---|---|---|---|---|
| avant (vue de dessus) | (1, 1) | 30 × 16,9 | 506 u² | ×1 | 8,4 u |
| 64 | (1,0, 0,5) | 30 × 33,8 | +100 % | ×1 | 15 u |
| **72 (recommandé)** | **(1,125, 0,5625)** | **26,7 × 30** | **+58 %** | **×1,125** | **13,3 u** |
| 80 | (1,25, 0,625) | 24 × 27 | +28 % | ×1,25 | 12 u |

s = 80 respecte « +20-30 % » au sens strict mais grossit les persos de 25 % et réduit la largeur de 20 %, l'inverse d'un recul. **s = 72 recommandé ; choix final au portail de la phase 0 (64/72/80 comparés sur téléphone).** Multiplicateur joueur 0,9-1,1 exposable plus tard dans les options.

### 1.4 Pixels par u (s = 72)
| Direction | px écran / u |
|---|---|
| sol, horizontale écran (x logique) | 72 |
| sol, verticale écran (y logique) | 36 |
| sol, axes iso de la carte (26,57°) | 56,9 (50,9 × 25,5) |
| hauteur verticale (murs, persos) | 62,4 |
| repère logique (physique, Balance) | 64 partout (inchangé) |

### 1.5 Tuiles et densité de rendu
- **Densité Blender unique pour tout asset iso : R = 64·√2 = 90,51 px/u** (image finale, après rendu 2× + LANCZOS).
- **Tuile de sol = bloc 4 × 4 u = losange 512 × 256 px** ; cellule 2 × 2 u = losange 256 × 128 px.
- Affichage : échelle s / R = **0,795** à s = 72 (tuile 4 u = 407 × 204 px écran ; cellule 204 × 102 px). Léger sur-échantillonnage : net, zoom avant possible jusqu'à ×1,25.

### 1.6 Contrat de code `Iso` (nouveau, `scripts/core/iso.gd`, orchestrateur)
```gdscript
class_name Iso
const ELEVATION_DEG := 30.0
const MAP_YAW_DEG := 45.0
const SQUASH := 0.5                  # sin 30°
const HEIGHT_K := 0.8660254          # cos 30°
const SCREEN_PX_PER_U := 72.0        # figé au portail de la phase 0
const RENDER_PX_PER_U := 90.50967    # 64·√2
const UNSQUASH := Vector2(1.0, 2.0)  # espace « billboard » : échelle nette uniforme = Z
const SPRITE_K := 0.70710678         # 64 / RENDER_PX_PER_U
static func camera_zoom(mult := 1.0) -> Vector2          # (s/64, s/128) × mult
static func map_xform() -> Transform2D                   # Rot(+45°) : carte -> logique
static func to_screen_dir(v: Vector2) -> Vector2          # (v.x, v.y × 0,5)
static func screen_to_logical_dir(v: Vector2) -> Vector2  # (v.x, v.y × 2), normalisé
static func screen_angle(v_logical: Vector2) -> float     # angle affiché d'une direction au sol
static func lift_px(h_u: float) -> float                  # hauteur en espace billboard : −h × 55,43
static func lift_logical(h_u: float) -> float             # hauteur en y logique : −h × 110,85
```
**Règle « billboard »** : tout visuel non plat au sol (personnages, monstres, props, murs, coffres, piliers, projectiles, texte, barres, particules volumiques) vit sous un nœud d'échelle `Iso.UNSQUASH`. Dedans : unités = px logiques horizontaux ; sprite rendu à R → échelle `SPRITE_K` × taille ; sprite ancien (64 px/u) → échelle 1.
**Tout ce qui est plat au sol** (télégraphes, zones, auras, cercles de pilier, eau, nuages, brume basse, décalques) se dessine directement en repère logique : la caméra en fait des ellipses 2:1.

---

## §2 Architecture

### 2.1 Options comparées
| | **A. Sol logique aligné écran + zoom caméra non uniforme (RETENU)** | B. Monde en espace écran | C. Sol aligné grille + projection `canvas_transform` |
|---|---|---|---|
| Physique | inchangée (cercles, `move_and_slide`, `Area2D`) | collisions en losanges, pas d'ellipse native | OK via `canvas_transform` |
| Distances / équilibrage | exactes, `Balance` intact | métrique elliptique partout : très invasif | exactes |
| Tri en profondeur | natif (y logique) | natif | **cassé** (profondeur = x + y) |
| Souris, sorts, télégraphes | automatiques | à réécrire | automatiques |
| Coût | billboards, murs en rectangles tournés, conversion de repère dans NavField | réécriture de tous les systèmes | contre-transformations, tri manuel |

**Recommandation : A.**

### 2.2 Rendu de la carte
- **Sol et eau plate** : `TileMapLayer` `TILE_SHAPE_ISOMETRIC`, `TILE_LAYOUT_DIAMOND_DOWN`, en espace billboard (`scale = SPRITE_K × UNSQUASH = (0,707, 1,414)`). `Visual/Ground` tuiles 512×256 (4 u) ; `Visual/Decor` 256×128 (2 u). Test d'alignement : centre de cellule `map → logique` = `Ground.to_global(map_to_local(cell))`.
- **Murs et props : sur mesure**, un nœud par cellule « # » visible (≥ 1 voisin praticable), Sprite2D billboard, conteneur trié : fondu par cellule (§2.4), variantes, falaises de bord.
- **Pas de physique ni de navigation dans le TileSet** : collisions = rectangles générés par `tools/gen_maps.py` en repère carte ; NavField reste sur mesure.
- **Phase 0 uniquement** : tuiles carrées actuelles (256 px) posées en repère carte tourné de 45° ; la caméra les écrase en losanges, sans nouvel asset.

### 2.3 Arbre de scène et tri
```
Main
├─ World (Node2D, y_sort_enabled)              ← nouveau
│  ├─ StageMap (y_sort_enabled)
│  │  ├─ Visual (z −20)       sol iso, contours en repère carte, fond d'abîme (z −21)
│  │  ├─ Blocks (y_sort)      murs, falaises, props : 1 Node2D par cellule + Sprite2D billboard
│  │  ├─ Obstacles (transform = Iso.map_xform())   StaticBody2D, rectangles repère carte
│  │  ├─ Markers   (transform = Iso.map_xform())   Marker2D repère carte
│  │  └─ coffres, piliers, téléporteur, capsules (positions logiques)
│  ├─ Player
│  └─ Director/Container (y_sort_enabled, plus top_level)
├─ AmbianceManager, HUD… (inchangés)
```
- Tri imbriqué entre nœuds `y_sort_enabled` sur la position en repère racine. **À vérifier en phase 0** ; repli : coffres, piliers, blocs enfants directs de `World`.
- Projectiles (z 10) et HitFx au-dessus de tout (lisibilité). Télégraphes sur le CanvasLayer 5.

### 2.4 Murs et occlusion
- Hauteur des obstacles intérieurs plafonnée à **1,25 u** (< personnage ~1,4 u).
- **Fondu** : un bloc ou prop haut « devant » le joueur ou un boss (y logique plus grand, rectangles qui se chevauchent) passe à alpha 0,4 ; test sur les ~6 cellules voisines par image.
- **Bord de carte** : plateau en losange au-dessus d'un abîme brumeux. Arêtes avant (bas-gauche, bas-droite) : **falaise qui descend** (pas d'occlusion) ; arêtes arrière : remparts/rochers.
- Limites caméra = boîte englobante du losange ; les coins montrent l'abîme.

### 2.5 Entrées
- **Déplacement (ZQSD, stick gauche, joystick) : axes ÉCRAN = axes logiques**, sans conversion. Diagonale clavier = axe de grille (26,57° à l'écran) → longe les murs. Vitesse isotrope en u/s (verticale 2× plus lente en px écran, compensée par la profondeur visible). Option `Iso.MOVE_SCREEN_FAITHFUL` testée en phase 0, désactivée par défaut.
- **Visée stick droit** : `screen_to_logical_dir(stick)`. **Souris** : exacte, inchangée. **Ciblage auto** : inchangé.

### 2.6 Créatures, directions, normal maps
- 8 directions écran inchangées (`e, se, s, sw, w, nw, n, ne`) ; **mapping direction → anim valide** (angle logique `facing.angle()`). Ne jamais utiliser `screen_angle()` pour choisir une anim (seulement pour tourner un sprite : projectiles, flèches).
- **Normal maps** : billboards à échelle nette uniforme → convention écran inchangée (R +X, G +Y haut, B vers caméra) ; le sol iso est rendu à la vraie caméra, donc aussi en espace écran.

### 2.7 Lumières et ombres
- PointLight2D en repère logique → flaques elliptiques 2:1 (correct). `offset_u` d'un préréglage devient la **hauteur** de la lumière (`height`), la flaque reste au pied.
- Soleil : `sun_rotation_deg` devient un **angle écran**, converti en logique (lumière du haut-gauche, ombres vers bas-droite). Ombres ≤ 2,5 u. `SUN_SHADOW_CULL_PX` 1400 → 1700 (demi-diagonale logique de la vue ≈ 1284 px à s = 72).
- LightOccluder2D : rectangles au sol en repère carte (sous un nœud `map_xform`) → losanges, ombres au sol (masque 8). Billboards de murs au masque 1 (fill), sans auto-ombre.

---

## §3 Code, fichier par fichier
(**P0** = prototype, **L1-L5** = lots §5 ; « auto » = correct sans changement.)

**Orchestrateur**
- `scripts/core/iso.gd` (nouveau, P0) : §1.6.
- `scripts/game/main.gd` (P0) : `World` trié (carte via StageManager, joueur, conteneur du Director) ; `_apply_camera_limits()` sur la boîte englobante ; secousse `offset.y × 2`.
- `scenes/player/player.tscn` (P0) : `Camera2D.zoom = Iso.camera_zoom()` (posé dans `player.gd._ready`) ; `Visual.scale` (0,65, 0,65) → (0,65, 1,3) tant que le sprite ancien reste.
- `CONTRACTS.md`, `CLAUDE.md` : repères, règle billboard, `World`.

**Carte, navigation, Director (L1, Opus)**
- `tools/gen_maps.py` : `transform = Rot45` sur `Obstacles` et `Markers` ; `y_sort_enabled` sur StageMap ; métadonnée et champ JSON `projection = "iso45"`. Grilles, positions et rectangles inchangés (`maps_test` reste valide).
- `scenes/stage/maps/*.tscn`, `data/maps/*.json` : régénérés. `stage_map_test.tscn` reste plat (couvre les deux cas).
- `scripts/stage/stage_map.gd` : `map_xform()`, `to_map(p)`, `from_map(p)` selon `projection` ; `_build_ground()` (G1 rotation 45° en P0, tuiles iso ensuite) ; `_build_blocks()` (cellules visibles, variantes, falaises, fondu) ; fond d'abîme ; `_build_outlines` en repère carte ; `get_bounds()` = boîte englobante logique + `get_map_rect()` ; `get_walkable_ratio()` et `_gather_rects()` en repère carte.
- `scripts/stage/stage_manager.gd` : carte sous `World` (paramètre `world_root`) ; `_capsule_candidates()` via `from_map` ; reste auto.
- `scripts/save/run_save.gd` : **montée de version** (positions sauvegardées changent de repère : runs d'avant la migration abandonnées proprement ; profil intact).
- `scripts/director/nav_field.gd` : grille en repère carte ; entrées converties en carte, sorties reconverties par `basis_xform` ; identité pour une carte plate.
- `scripts/director/director.gd` : conteneur trié sous `World` (sans `top_level`) ; marge d'apparition et de LOD côté bas + `Iso.lift_logical(hauteur max du sprite)` (≈ +3,5 u brute, plus pour un boss) ; `_spawn_half_extent()` auto.

**Entités, effets, sorts (L2, Sonnet)**
- `enemies/enemy_visual.gd` : sprite en billboard (× (1, 2) pour un sprite ancien, `SPRITE_K` pour un rendu iso ; facteur lu dans `SPRITES`/`BOSS_SPRITES`) ; offsets pieds en px de frame inchangés ; mapping directions inchangé.
- `enemies/enemy_projectile_pool.gd`, `spells/projectile.gd`, `scenes/spells/projectile.tscn` : racine non tournée ; `Billboard/Visual` avec `rotation = Iso.screen_angle(dir)` et hauteur `lift_px(0,5)` ; forme de collision non circulaire tournée à part.
- `spells/spell_caster.gd` : visée stick via `screen_to_logical_dir` ; souris auto.
- `spells/zone_effect.gd`, `enemies/enemy_telegraph.gd`, `enemies/enemy_aura.gd` : auto.
- `fx/hit_fx.gd` : conteneur `UNSQUASH`, positions (x, y/2), directions `to_screen_dir`, gravité verticale écran.
- `fx/damage_numbers.gd`, `fx/enemy_health_bars.gd` : `draw_set_transform(…, Vector2(1, 2))`, ancrage aux pieds, hauteurs en px billboard.
- `pickups/pickup_manager.gd` : un `draw_set_transform_matrix(scale(1, 2))`, positions (x, y/2) ; toujours un seul `_draw`.
- `loot/chest.gd`, `loot/gold_capsule.gd`, `stage/pillar.gd`, `stage/exit_teleporter.gd` : sprites billboard ; cercles au sol auto.
- `director/wave_indicator.gd` : flèche en billboard.
- `player/player.gd` : billboard du `Visual` ; indicateur de visée au sol auto ; `_dir_name()` inchangé.

**Ambiance (L3, Sonnet ; relecture Opus)**
- `ambiance/occluder_builder.gd` : polygones en repère carte (parent `map_xform`) ; `_is_water` en repère carte ; occluders dynamiques auto.
- `ambiance/ambiance_water.gd` : bandes d'eau sous `map_xform` ; vérifier que le miroir (Haut) reste vertical à l'écran.
- `ambiance/ambiance_manager.gd` : angle soleil écran → logique ; `pos_u` des lumières de carte via `from_map` ; `SUN_SHADOW_CULL_PX` ; `view_rect()` auto.
- `ambiance/ambiance_fog.gd` : nuages et brume basse au sol (auto) ; brume haute, rayons, `spawn_event_rays` sous `UNSQUASH`.
- `ambiance/ambiance_weather.gd` : pluie, gouttes, particules sous `UNSQUASH` ; éclaboussures au sol auto.
- `ambiance/ambiance_lightning.gd` : éclair en billboard.
- `ambiance/light_rig.gd` : `offset_u` = hauteur ; `_view_rect` auto.
- `ambiance/ambiance_profile.gd`, `data/ambiance/*.tres` : angle écran du soleil documenté, `sun_rotation_deg` ressaisi.
- `menu/menu_background.gd` : `Iso.camera_zoom(CAMERA_ZOOM)` ; points de caméra en logique.
- Inchangés : `normal_maps.gd`, `quality.gd`, shaders d'étalonnage et vignette.

**Interface (L4, Sonnet)**
- `ui/minimap.gd` : image en repère carte (inchangée, garde le test de pixels) ; affichage par `draw_set_transform_matrix` (rotation 45° puis écrasement 0,5) ; marqueurs logique → carte → 0..1 → matrice ; flèche du joueur par `screen_angle` ; cadre compact 2:1.
- `ui/hud.gd` : taille du cadre de minimap ; réticule auto. Joystick, boutons, menus inchangés.

**Tests et docs (L5)** : §6.3 ; mise à jour de `art/briefs/STYLE.md`, `terrain_brief.md`, `monsters.md`, `vfx.md`, `docs/Direction_Lumiere_Ambiance.md` (angle soleil, splash vu de dessus).

---

## §4 Assets à refaire (Codex, Blender ; UI non concernée)

### 4.1 Rigs communs (lot C0 : `art/tools/iso/iso_rig.py`, `art/blender/iso_rig.blend`)
Base : 1 m = 1 u ; Eevee à échantillons modestes ; Standard ; film transparent ; rendu 2× + LANCZOS ; lumière DA officielle (STYLE.md : soleil chaud haut-gauche écran, fill froid) ; normale espace écran (OpenGL, Y haut) en `<f>_n.png`, émission en `<f>_e.png`.

| Rig | Usage | Caméra |
|---|---|---|
| **MAP** | aligné grille : sol, eau, murs, falaises, props, coffres, piliers, téléporteur, capsule | ortho, Euler XYZ **(60°, 0°, 45°)**, position = cible + d·(0,612, −0,612, 0,5) ; `sensor_fit = HORIZONTAL`, `ortho_scale = largeur_px / 90,51`. Carte (mx, my) ↔ Blender (mx, −my) ; Blender +X → bas-droite écran |
| **CREA** | personnages, monstres, boss, pickups, projectiles, VFX volumiques | ortho, Euler **(60°, 0°, 0°)**, position = cible + d·(0, −0,866, 0,5), même `ortho_scale`/R. On tourne le **modèle** : e = +X, se = (1, −1), s = −Y (face caméra), sw, w, nw, n = +Y, ne |
| **TOP** | décalques au sol, nuages, flaques, masques | ortho vertical (0°, 0°, 0°), **128 px/u** ; Godot les affiche à 0,5 en repère logique et la caméra les écrase. **Ne jamais pré-écraser un décalque.** |

Calibrage C0 : damier 4 × 4 m → 512 × 256 ; cube 2 × 2 × 1,25 m → 256 × 256 ; poteau 1 m → 78,4 px de haut. Contrôle dans Godot par un agent Claude.

### 4.2 Terrain par biome (terrasses, forêt, cité) — lots C1, C2, C3
| Fichier (`assets/sprites/terrain/<biome>/iso/`) | Spec |
|---|---|
| `ground_<a-d>.png` | losange 512 × 256 (4 × 4 u), rig MAP, matière périodique sur 4 m ; rendre un 3 × 3 et garder le losange central via un masque **rendu dans Blender** (index/cryptomatte, dilaté de 2 px). 4 variantes. Albédo ≥ 0,12 pour que les flaques de lumière ressortent ; `_n` obligatoire (branché au sol via CanvasTexture). |
| `water_shallow.png`, `water_deep.png` | losange 256 × 128 (2 u), lit ; reflets au shader |
| `block_<a-c>.png` | mur/obstacle d'une cellule : emprise 256 × 128, hauteur **1,25 u** (98 px) ; cadre 256 × 256, centre de l'emprise au px (128, 192) → offset Godot (0, −64) ; 3 variantes ; arêtes jointives sur les diagonales |
| `cliff_sw`, `cliff_se`, `cliff_corner_s`, `cliff_corner_w`, `cliff_corner_e` | bords avant : dessus 256 × 128 + paroi descendante 2,5 u (196 px), cadre 256 × 384, centre de l'emprise à (128, 64) |
| `rampart_ne`, `rampart_nw`, `rampart_corner_n` | bords arrière (bloc 1,25 u en rempart/rocher/racines) |
| `void_1024.png` | abîme brumeux sans raccord, rig TOP |
| `<biome>_iso.tres` | TileSet iso (`TILE_SHAPE_ISOMETRIC`, `DIAMOND_DOWN`) fait par un agent Claude après livraison |

### 4.3 Props, coffres, piliers (rig MAP, lacet 45°) — lots C8, C9
- `props/*` (reprendre `art/briefs/terrain_props_inventory.json`) ; pivot au centre de l'emprise ; props hauts (arbres) avec fondu. Halos de lampes NON cuits dans le sprite (émission dans `_e`, lumière pilotée par le jeu).
- `chests/chest_*`, `props/pillar_{small,large}_{off,active,done}` (actifs : 8 colonnes), `props/teleporter_*`, `props/gold_capsule/*`.
- **Orientés selon la grille, pas face caméra (joueur, 21/10/2026)** : modèle posé sur les axes de la carte (arêtes parallèles aux diagonales des losanges, un coin vers la caméra). Objets asymétriques (coffres, téléporteur, props à face) : **2 rendus** `_se` (face vers le bas-droite) et `_sw` (bas-gauche), jamais un miroir `flip_h` (la lumière haut-gauche serait inversée). Le placement (JSON de carte) choisit l'orientation ; défaut `_se`. Symétriques (piliers carrés, capsule) : 1 rendu.

### 4.4 Créatures (rig CREA, élévation 30°) — lots C4-C7
- Ardent, `swarm_tier1`, `shooter_tier2`, `leaper_tier2`, `brute_tier3`, 6 mini-boss, boss d'étage cerf/sonneur/éclusier (effort `medium`). DA officielle (STYLE_boss_da.md).
- Conservés : noms, anims, nombre de frames, ordre des directions, `_n`/`_e`, `.tres`.
- Cadre = silhouette + 8 px, arrondi à 32. Indicatif à R = 90,51 : joueur 192², tier 1 128², tier 2 160², tier 3 192², mini-boss 320², boss d'étage 448².
- Le code lit `render_px_per_u` par asset (64 ancien, 90,51 iso) : remplacer un fichier ne touche qu'une constante.

### 4.5 Pickups et projectiles (rig CREA) — lot C10
`pickups/*` (pièce, sac, gemmes) ; `projectiles/ember_shard` pointe vers +X écran (le jeu le tourne).

### 4.6 VFX — lot C11
- **Au sol, rig TOP** : `ardent_nova`, `charge_ring`, `pillar_zone_ring`, auras d'élite (`fx/elites`, `ambiance/aura_ring_128`), `splash_8x64` (vu à 90°), **ombre de contact** `shadow_blob_256` (nouvelle, sous chaque créature).
- **Volumiques, rig CREA** : `flame_pillar`, `meteor` + `meteor_impact` (cratère TOP + gerbe CREA), `phoenix`, `lightning_arc`, `level_up`, `monster_death`, `status_*`, `ember_orbs`, `chest_open`, particules (`vfx/particles`).
- Un effet mixte = un calque au sol + un calque volumique.

### 4.7 Ambiance
Pluie, `godray`, `fog_tile`, nuages, canopée, masque de flaques : textures écran ou vues de dessus, **gardées** (contrôle visuel en phase 0). `fog_puff` vérifiés en phase 0.

### 4.8 Hors sujet
Icônes, cadres, kit d'UI, invites de touches. La flèche de vague reste un sprite d'UI.

---

## §5 Lots, ordre, dépendances

### Phase 0 — prototype (portail de décision, ~1 jour d'agents, sans nouvel asset)
- **P0-a (orchestrateur)** : `iso.gd`, `World` dans `main.gd`, zoom caméra, billboard du joueur.
- **P0-b (Opus)** : `gen_maps.py` (drapeau iso) sur **terrasses_noyees** seule ; `stage_map` en G1 (tuiles carrées tournées de 45°, blocs « # » en prismes `Polygon2D` de 1,25 u, substitut temporaire autorisé) ; `nav_field`, `director` (marges), `occluder_builder`, `stage_manager`.
- **P0-c (Sonnet, en parallèle après P0-a)** : billboards de `enemy_visual`, coffre, pilier, pickups, chiffres de dégâts, barres de vie, projectile, `hit_fx`.
- **Validation** : tests §6.3 sur la carte iso ; `enemies_perf`, `ambiance_bench` ; capture PC ; **export Android** sur le téléphone de référence (250 monstres, Moyen, ≥ 60 i/s) ; contrôles visuels (tri devant/derrière un bloc, ombres et normal maps sous zoom non uniforme).
- **Portail joueur** : s (64/72/80), déplacement direct vs fidèle écran, hauteur des murs et fondu, ressenti de la vitesse verticale → fige `Iso.*` avant toute production d'assets.
- **En parallèle** : Codex **C0** (rigs et calibrage), sans dépendance au code.
- **Immédiatement** : **geler les lots Codex R qui re-rendent créatures, terrain, boss et props à 35°** (remplacés par C1-C9). Les lots R d'UI, d'audio et de textures d'ambiance continuent.

### Phase 1 — code (agents Claude en parallèle, dossiers séparés ; après P0)
| Lot | Agent | Dossiers | Dépend de |
|---|---|---|---|
| L1 Carte, nav, Director, sauvegarde | Opus | `scripts/stage`, `scripts/director`, `scripts/save`, `tools/`, `scenes/stage`, `data/maps` | P0 |
| L2 Entités, effets, sorts | Sonnet | `scripts/enemies`, `scripts/spells`, `scenes/spells`, `scripts/fx`, `scripts/pickups`, `scripts/loot` | P0 |
| L3 Ambiance, fond de menu | Sonnet (relecture Opus) | `scripts/ambiance`, `data/ambiance`, `scripts/menu/menu_background.gd` | P0 |
| L4 Minimap, HUD | Sonnet | `scripts/ui` | P0 |
| L5 Tests et docs | Haiku → Sonnet | `tests/`, `art/briefs`, docs (proposés à l'orchestrateur) | L1-L4 |

Le transverse (`player.gd`/`.tscn`, `main.gd`, `CONTRACTS.md`) revient à l'orchestrateur. L1 livre les 3 cartes en G1 : le jeu reste jouable avant les assets. Les paquets de 3-8 monstres et les vitesses du rythme visé (docs/Maths_Scaling.md, alignement RoR2) sont introduits dans L1/L2.

### Phase 2 — assets (Codex, un lot à la fois via `run_codex.sh`, effort `low` sauf boss)
Ordre : **C1** terrain terrasses (juge le rendu final) → **C4** Ardent → **C5** monstres T1-T3 → **C8** coffres, piliers, téléporteur, capsule → **C2** forêt → **C3** cité → **C11a** décalques au sol + ombre de contact → **C6** mini-boss → **C7** boss d'étage (`medium`) → **C9** props de biome → **C10** pickups et projectiles → **C11b** VFX volumiques.
Après chaque lot, un agent Sonnet intègre (TileSet `.tres`, `render_px_per_u`, offsets), lance `sprites_test` et une capture. Bascule G1 → G2 biome par biome.

---

## §6 Risques et tests

### 6.1 Technique et performance (mobile)
| Risque | Mesure / repli |
|---|---|
| Éclairage 2D, ombres, particules sous `zoom` non uniforme | vérifié en P0 (`capture_lighting`, `ambiance_probe_normals`) ; repli : `viewport.canvas_transform` posé à la main |
| Tri imbriqué StageMap/Blocks/Director | test P0 ; repli : enfants directs de `World` |
| Surcoût de dessin des losanges (coins transparents, sol ~2×) | `ambiance_bench` en P0 et C1 ; repli G1 (mipmaps, `LINEAR_WITH_MIPMAPS_ANISOTROPIC`) |
| Mémoire vidéo (90,5 px/u ≈ ×2 d'aire) | compression VRAM ; repli créatures à 64 px/u (affichées ×1,125), choisi au lot C4 |
| ~1000 éléments triés | blocs de bord seulement ; mesuré par `enemies_perf` |
| Sauvegardes de run d'avant migration | montée de version de `run_save`, abandon propre |

### 6.2 Lisibilité et ressenti
- Vitesse verticale 2× plus faible en px écran : compensée par la profondeur visible ; tranché au portail P0.
- Télégraphes verticaux 2× plus courts : liserés ≥ 2 px, remplissage montant, calque 5 au-dessus des murs.
- Occlusion par les murs : 1,25 u, fondu, projectiles au-dessus.
- Monstres qui apparaissent par le bas : marge `lift_logical`.
- Motifs de boss liés aux rangées de grille → diagonales (relecture game design, non bloquante).

### 6.3 Tests concernés (`game/tests`)
| Test | Impact |
|---|---|
| `maps_test` | chemins `Obstacles`/`Markers` et repère carte inchangés ; + métadonnée `projection` |
| `stage_test` | `get_walkable_ratio`, `get_bounds` (boîte englobante) ; carte de test plate ; + aller-retour `to_map`/`from_map` |
| `capsule_test` | `_grid_cell()` via `map.to_map()` |
| `enemies_map_test`, `enemies_perf` | NavField en repère carte ; `_penetration` et « dans un mur » via `to_map` |
| `enemies_director` | demi-étendue (nouvelles valeurs), marge du bas |
| `integration_test` | limites caméra = boîte englobante ; zoom = `Iso.camera_zoom()` |
| `ambiance_test`, `capture_lighting`, `ambiance_bench` | occluders en repère carte, z de `Visual/Ground`, nombre de `shadow_rects` |
| `hud_overlays_test`, `objectives_test`, `capture_hud` | image de minimap inchangée ; cadre 2:1, marqueurs |
| `sprites_test` | `scale.x` joueur/monstres (billboard), visuel du projectile |
| `player_test` | projectile non tourné, `Billboard/Visual` |
| `platform_aim_test` | visée stick convertie |
| `capture_hit_feel` | `cam.zoom = Iso.camera_zoom(1.6)` |
| `title_test`, `capture_title`, `menu_flow_test` | caméra du fond de menu |
| `loot_test`, `economy_test` | à relancer |
| `test_balance.gd` | aucun impact |

Nouveaux : `iso_test` (constantes, `camera_zoom`, aller-retour des directions, `lift`, alignement Ground ↔ `from_map`) ; tri devant/derrière un bloc ; fondu d'un bloc devant le joueur.

---

## §7 Ce qui ne change pas
- `Balance` et toutes les valeurs en u ; **1 u = 64 px logiques** ; portées, rayons, aimant, séparation, meutes, apparitions 2-4 u derrière le bord (les vitesses changent seulement via l'alignement RoR2).
- Couches physiques, groupes, `Events`, `RunState`, `Platform`, actions `InputSetup`, objets, loot, sauvegarde du profil.
- Grilles ASCII, tailles de carte, marqueurs, `draw_rules`, BFS de NavField, pools et LOD du Director.
- Architecture d'ambiance (calques 4/5/6, z du monde, paliers de qualité, `LightRig`, `_n`/`_e`, glow, `CanvasModulate`).
- HUD, menus, UI, joystick, boutons, audio.
- Ordre des 8 directions et mapping direction → anim (angle logique).
- Règle absolue : tout asset final est rendu par Codex dans Blender ; prismes et G1 de la phase 0 sont des substituts temporaires.
