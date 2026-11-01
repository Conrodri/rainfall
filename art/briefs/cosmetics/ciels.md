# Ciels : heures et saisons des biomes (brief d'assets, 01/11/2026)

Catalogue : `game/data/cosmetics.json` (famille `ciel`, `target` = préfixe de biome : `terrasses`, `foret`, `cite`, `cryptes`). Design : `docs/Boutique_Rubis.md` §3.3. Système : `AmbianceManager.load_profile(map_id)` lit `res://data/ambiance/<map_id>.tres` (classe `AmbianceProfile`) ; les textures passent par `AmbianceTextures` (`res://assets/sprites/ambiance/<nom>.png`, index récursif, variantes `<nom>_2.png`).

## 1. Ce qu'un Ciel contient

| Pièce | Qui | Chemin | Format |
|---|---|---|---|
| Profil d'ambiance par carte du biome (A et B) | game designer (réglages, pas un asset) | `game/data/ambiance/<map_id>_<ciel>.tres` | `AmbianceProfile` : copie du profil de la carte, valeurs §3 ci-dessous changées ; paliers de D inchangés |
| Ciel reflété | Codex, Blender | `game/assets/sprites/ambiance/sky_<ciel>_256x64.png` | 256×64 RGBA, bande horizontale raccordable en X (défile à 0,05 u/s dans `ambiance_water.gd`), même procédé que `sky_dawn_256x64.png` / `sky_storm_256x64.png` / `sky_sunset_256x64.png` (rendu Blender d'un ciel, profil `vfx`, encre 0) |
| Particules nouvelles (0 à 1 par Ciel) | Codex, Blender | `game/assets/sprites/ambiance/<nom>_<taille>.png` | niveaux de gris sur alpha, taille dans le nom, profil `vfx` |
| Aperçu de fiche | Codex, Blender | `game/assets/sprites/cosmetics/previews/<ciel>.png` | 256×256 RGBA, vue iso d'un coin de la carte sous ce Ciel (rendu Blender d'un décor type, pas une capture du jeu) |

Branchement (dev) : `Profile.equipped_cosmetics["ciel:<biome>"]` = id du Ciel ; au `floor_started`, si `res://data/ambiance/<map_id>_<id>.tres` existe, il remplace `<map_id>.tres`, sinon défaut silencieux. Placeholder : aucun fichier = Ciel par défaut ; la boutique affiche l'article `pending`.

## 2. Les 4 Ciels v1

| Id | Biome | Cartes (`map_id`) | Ciel reflété | Particules | Heure |
|---|---|---|---|---|---|
| `nuit_de_lanternes` | terrasses | `terrasses_noyees`, `terrasses_rizieres_hautes` | `sky_nuit_de_lanternes_256x64.png` : nuit bleu-noir, lune basse voilée, reflets froids | `firefly_16.png` (existe), **`lantern_glow_64.png`** (nouveau : halo chaud rond 64×64, niveaux de gris, cœur à 1,0, bord à 0 ; posé par le code sur les lanternes de rizière existantes de la carte via `LightRig`) | 23 h |
| `apres_midi_d_orage` | foret | `foret_brume`, `foret_mangrove_lanternes` | `sky_apres_midi_d_orage_256x64.png` : nuées sombres percées de chaud, horizon ocre | `leaf_cedar_32.png` (existe), `godray_512x1024.png` (existe) | 16 h |
| `canicule_de_cendres` | cite | `cite_rouille`, `cite_fonderie_canal` | `sky_canicule_de_cendres_256x64.png` : midi ocre brûlé, aucun nuage de pluie | `ash_16.png` (existe), **`heat_haze_tile_512.png`** (nouveau : bruit raccordable 512×512 en niveaux de gris, lu par le shader de brume de chaleur du code : aucune image finale dessinée en code) | 12 h |
| `maree_haute` | cryptes | `cryptes_noyees`, `cryptes_ossuaire_pluies` | `sky_maree_haute_256x64.png` : vert d'eau profond, lueur filtrée | `bubble_16.png` (existe) | sans heure |

## 3. Réglages de profil (game designer, par Ciel)

Bornes communes (garde-fous `Boutique_Rubis.md` §2.2 et §3.3) : luminance effective du `CanvasModulate` ≥ 0,42 (`AmbianceProfile.guard_ambient`, clamp existant), contraste des monstres L\* 55 vérifié par capture de validation, brume basse ≤ 0,35 d'opacité sur la zone jouable, couche des télégraphes jamais lue, ombres cuites de la carte inchangées, pluie revenant avec D selon les paliers existants.

| Ciel | `ambient_color` (lin., ≈) | `sun_color` | `sun_energy` | `rain_intensity` (palier 0) | brume | particules |
|---|---|---|---|---|---|---|
| nuit_de_lanternes | (0,30 ; 0,33 ; 0,42) | (0,55 ; 0,62 ; 0,85) lune | 0,6 | 0,15 fine | 0,25, bleutée | firefly ×2 densité, lantern_glow sur les lanternes |
| apres_midi_d_orage | (0,45 ; 0,42 ; 0,36) | (1,0 ; 0,78 ; 0,55) | 1,3 | 0,35 | 0,20, chaude | leaf_cedar lent, godray ×2 |
| canicule_de_cendres | (0,52 ; 0,46 ; 0,36) | (1,0 ; 0,85 ; 0,62) | 1,5 | **0,0** (revient à D ≥ palier 2) | 0,30, brume de chaleur ocre | ash montante |
| maree_haute | (0,34 ; 0,42 ; 0,40) | (0,60 ; 0,78 ; 0,72) | 0,8 | profil actuel | 0,30 | bubble ×2, `water_reflect` +0,15, `sky_reflect` +0,1 |

## 4. Vérifs

- Textures : dimensions exactes, alpha, raccord X du ciel (différence bord gauche/droit < 2/255), PNG optimisés, aucun `_n`, `_e` inutile (pas de `_e` pour ces textures).
- Capture de validation par Ciel (protocole `docs/Direction_Lumiere_Ambiance.md` §2) : monstres L\* ≥ 55 sur le sol, PV du HUD lisible, télégraphe visible ; jointe au rapport (≤ 1024 px).
- `godot --headless --path game --import` sans erreur ; `res://tests/texture_budget_test.tscn` -> RESULT: OK (≈ 0,1 Mo par Ciel).
