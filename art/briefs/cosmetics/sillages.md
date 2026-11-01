# Sillages : traces de pas et traînées d'esquive (brief d'assets, 01/11/2026)

Catalogue : `game/data/cosmetics.json` (famille `sillage`, `target` `""`). Design : `docs/Boutique_Rubis.md` §3.6. Système (dev) : un émetteur unique `CosmeticTrail` sous `Player` (z sous les créatures), cadencé par les pas déjà joués par `audio_manager` ; traînée d'esquive déclenchée par `slide_dodge` (0,3 s), au même endroit que `vfx/dodge_slide/`. Budget commun : ≤ 8 particules vivantes par Sillage dans le pool de 24, coupé en qualité Bas, moitié au-dessus de 150 monstres vivants.

## 1. Convention de chemins

`game/assets/sprites/cosmetics/sillages/<id>/` :

| Fichier | Format | Rôle |
|---|---|---|
| `particle_32.png` | 128×128 RGBA, grille 4×4 de cellules 32×32, 16 frames, ligne par ligne (naissance → extinction) | la particule émise par pas |
| `step_64.png` | 64×64 RGBA, 1 frame | le décalque posé sous le pied (empreinte, rond, tache), fondu par le code en ≤ 0,8 s |
| `<id>.tres` | `SpriteFrames` : animation `particle` (16 frames 32×32 `AtlasTexture` sur `particle_32.png`, 24 fps, loop false), animation `step` (1 frame) | lu par `CosmeticTrail` |

Traînées d'esquive (`esquive_*`) : `game/assets/sprites/cosmetics/sillages/<id>/` :

| Fichier | Format | Rôle |
|---|---|---|
| `wake.png` | 64×32 RGBA, 1 frame (même format que `vfx/dodge_slide/slide_wake.png`) | le sillage étiré derrière la glissade |
| `burst.png` | 768×96 RGBA, 8 frames de 96×96 sur une ligne (même format que `vfx/dodge_slide/splash.png`) | la gerbe au départ de l'esquive |
| `<id>.tres` | `SpriteFrames` : `wake` (1 frame), `burst` (8 frames, 24 fps, loop false) | lu par le VFX d'esquive à la place de `dodge_slide.tres` |

Aucun `_e` (règle : **aucune émission additive**, ne rivalise pas avec les capsules d'or), aucun `_n`. Profil cel `vfx` (encre 0). Aperçu de fiche : `game/assets/sprites/cosmetics/previews/<id>.png` 256×256 (le personnage Ardent par défaut marchant sur le sol des Terrasses avec le Sillage, rendu Blender).

Placeholder dev : `.tres` absent = Sillage par défaut (« Ronds d'eau », déjà dans le jeu, gratuit, pas un article).

## 2. Règles de lisibilité (toutes)

Alpha ≤ 0,5 ; taille d'une particule à l'écran ≤ 0,15 u (≤ 10 px) ; rayon total du Sillage ≤ 0,4 u autour du joueur ; disparition ≤ 0,8 s ; **jamais de rouge ni d'orange saturé** (palette des télégraphes) ; aucune couleur de pickup (doré #F2C14E, vert XP) ; z sous les créatures ; aucune ombre, aucune lumière.

## 3. Les 8 articles v1

| Id | Particule (16 frames) | Décalque `step_64` | Couleurs (3 tons cel, désaturées) |
|---|---|---|---|
| `braises` | étincelle qui monte de 6 px puis s'éteint (frames 10-16 presque transparentes) | petit rond de cendre | ambre sombre #B8742A → #4A2E14, alpha 0,4 |
| `petales` | pétale de cerisier qui tombe en tournant, se pose à plat | pétale posé | rose éteint #B98C8E → #6E4F52 |
| `givre` | cristal qui pousse puis fond (frames 12-16 fondues) | empreinte de pied blanche | blanc froid #D8DEE6 → #7F8A96 |
| `feu_follet` | spore ronde qui flotte en zigzag et s'éteint | rond de mousse | vert pâle #8DB89C → #3F5A48 (pas le vert XP : plus gris, plus sombre) |
| `encre` | goutte d'encre qui s'étale dans l'eau | tache d'encre en étoile | brun-noir #2A2420 → #141110, alpha 0,45 |
| `rouille` | paillette de rouille qui coule | éclat de rouille | rouille #6B3A22 → #3E2419 (STYLE.md), jamais orange vif |
| `esquive_fumee` | `burst` : volute grise qui se dissipe en 8 frames ; `wake` : fumée étirée | — | gris #6E6E6E → #3A3A3A, alpha 0,4 |
| `esquive_gouttelettes` | `burst` : gerbe de gouttes claires ; `wake` : traînée d'eau | — | eau claire #A9C4CC → #5B7A84, alpha 0,5 |

## 4. Procédé Codex et vérifs

Un lot par Sillage (micro-lot, profil `eco-mini`) : scène Blender `art/blender/cel/cosmetics/sillage_<id>.blend` (particule modélisée, 16 poses rendues en caméra `iso_rig`, profil `vfx`), assemblage PIL en 4×4 ; vérif par script : dimensions exactes, 16 cellules non vides et distinctes, alpha max ≤ 0,5 × 255 sur `particle_32.png` et `step_64.png`, aucun pixel avec teinte dans [0°, 40°] et saturation > 0,5 ; planche contact ≤ 512 px ; `godot --headless --path game --import` ; `res://tests/texture_budget_test.tscn`. ≈ 50 Ko par Sillage.
