# Brief Codex : biome « Le Gouffre luisant » (étage 2, remplace la Forêt-brume)

> Design : `docs/Design_Etage2_Grotte.md` (identité, palette, différence avec les Cryptes). Style : `STYLE.md` (en tête : cel, DA sérieuse, OPTIMISATION ET OMBRES CUITES), `STYLE_boss_da.md`, `STYLE_cel.md` (module `art/tools/cel/cel_style.py`, aucun `_n`). Rigs : `docs/Design_Isometrique.md` §4.1 (`art/tools/iso/iso_rig.py` : MAP, CREA, TOP ; R = 90,51 px/u ; TOP = 128 px/u).
> **Ids techniques conservés** : le biome `foret` garde ses dossiers `terrain/fog_forest/`, `props/fog_forest/`, `props/secret/*_fog_forest_*`, `monsters/*_moss`. `fog_forest` = biome `foret` = Gouffre luisant. Chaque lot **remplace à l'identique** (mêmes noms, tailles, frames, pivots, `props.json` inchangé sauf ajouts listés) : le jeu n'a rien à changer. Avant d'écraser : `cel.archive_folder(<rel>)` (STYLE_cel §8).
> Lancement : `sh art/tools/run_codex.sh art/tools/terrain/_g<lot>.txt art/tools/terrain/_logg<lot>.txt low eco-mini` (créatures et boss : `medium full`). Un lot = une consigne courte sur le gabarit `art/tools/_consigne_gabarit.txt`, préambule `art/tools/_codex_eco.txt`. Lots à périmètres disjoints lançables en parallèle (Blender `--background`).

## 0. Rappels communs à tous les lots

- **Matières** (3 tons cel, teinte = Base Color) : grès ferrugineux `#5A4232` (ombre `#2E221C`, lumière `#7A5D45`) ; schiste sombre `#3A3634` ; argile d'éboulis `#4A3A30` ; argile humide `#3B3A3C` ; calcite beige `#8A7A62` (jamais blanche) ; racines mortes `#2A2420` ; chair de champignon `#6A5A66`. Grain procédural bakeé ou postérisé (profil `tile` : `keep_texture`).
- **Accent émissif unique : mycélium améthyste `#C27BFF`**, cœur `#E6C8FF`, en petites touches (fissures, filaments, chapeaux, veines) ; livré dans `_e` (demi-résolution acceptée). **Aucun cristal lumineux, aucun os, aucun sel, aucune pierre taillée** (réservés à l'étage 4). Aucun vert menthe (`#9CF0C8` est l'ancien accent).
- **Lumière de rendu** : rig STYLE.md (soleil chaud haut-gauche, fill froid) pour que les tons et les ombres cuites soient cohérents avec les autres biomes ; en grotte les ombres cuites sont **plus courtes (×0,6) et plus douces** (lumière de puits, pas de soleil), direction inchangée (vers bas-droite écran).
- **Ombres cuites** : AO et ombre de contact dans le diffus ; props et murs livrent `<f>_shadow.png` rig TOP 128 px/u, 512 × 512 centré sur l'emprise (comme `block_*_shadow.png` de F2), niveaux de gris sur fond transparent, alpha max 0,6.
- **Formes** : tout est naturel : aucune arête droite, aucun angle droit, aucun motif aligné sur les axes du losange ; strates obliques, cassures, éboulis, concrétions trapues. Silhouettes anguleuses (DA sérieuse), pas de blobs.
- **Budget** : aucune planche > 4096 px ; cellules à la taille d'affichage ; `python art/tools/texture_budget.py` puis `res://tests/texture_budget_test.tscn` et `res://tests/sprites_test.tscn` → `RESULT: OK` à la fin de chaque lot.
- **Contrôle** : `cel.check_sheet` sur chaque planche ; une seule planche contact ≤ 1024 px de large par lot, `art/tools/<famille>/_g<lot>_contact.png`, sur le sol réel du biome (`terrain/fog_forest/iso/ground_a.png` une fois G1 livré).

---

## Lot G1 : sol (repli + base tuilable + décalques) — profil `tile` et `vfx`, `eco-mini`

Le rendu du sol est refondu par un architecte (tous biomes). **Son contrat fixe les tailles finales** ; ce lot livre d'abord le repli (mêmes noms qu'aujourd'hui) et prépare les textures du nouveau système avec des tailles provisoires, à ajuster par un paramètre du script de construction.

### G1a : repli, 4 assets (`terrain/fog_forest/iso/`)
| Fichier | Taille | Spec |
|---|---|---|
| `ground_a.png` … `ground_d.png` | 512 × 256 (losange 4 × 4 u, rig MAP, masque rendu dans Blender dilaté de 2 px) | sol d'argile et d'éboulis `#4A3A30`, a : éboulis fin, b : argile lisse avec 2-3 petites flaques, c : plaques de calcite beige, d : fissures à mycélium (`ground_d_e.png` 256 × 128, filaments ≤ 0,15 u de large). **Aucun joint, aucune dalle, aucun motif régulier** ; raccords 3 × 3 identiques à F2 (bords antialiasés : `ISO_GROUND_OVERLAP.foret` = 4 inchangé). Albédo moyen ≥ 0,12 |

### G1b : base tuilable grand format, 4 assets (`terrain/fog_forest/ground/`, nouveau dossier, inerte tant que le système du sol ne le charge pas)
| Fichier | Taille (provisoire) | Spec |
|---|---|---|
| `rock_base_1024.png` | 1024 × 1024, rig TOP 128 px/u (période 8 u), **sans couture** (vérifier 2 × 2) | argile et éboulis neutres, contraste local faible (c'est la base, l'identité vient des décalques) |
| `rock_var_a_1024.png` (éboulis grossier), `rock_var_b_1024.png` (argile humide `#3B3A3C`, albédo 0,10), `rock_var_c_1024.png` (calcite beige en nappes) | 1024 × 1024, même rig, sans couture, **mêmes fréquences** que la base (mélange par zone sans rupture) | |

### G1c : décalques au sol, 8 assets (`terrain/fog_forest/ground/decals/`, rig TOP, fond transparent, jamais pré-écrasés)
| Fichier | Taille | Spec |
|---|---|---|
| `decal_fissure_1.png`, `decal_fissure_2.png`, `decal_fissure_3.png` (+ `_e` chacun) | 256 × 256 (2 u) | fissures obliques à mycélium : diffus sombre, `_e` violet ≤ 0,15 u de large |
| `decal_gour_1.png`, `decal_gour_2.png` | 384 × 384 (3 u) | gours en gradins avec un film d'eau (alpha 0,5 au centre), bord de calcite |
| `decal_scree_1.png`, `decal_scree_2.png` | 256 × 256 | éboulis de grès, ombres cuites |
| `decal_flowstone_1.png` | 512 × 512 (4 u) | coulée de calcite plate, bord irrégulier |

Vérif G1 : tuilabilité (2 × 2 sans couture visible), albédo moyen, aucune ligne droite > 1 u (contrôle visuel sur la planche contact), `_e` non noirs.

---

## Lot G2 : murs, falaises, eau, vide (`terrain/fog_forest/iso/`, rig MAP, profil `tile`, `eco-mini`)

Mêmes 23 noms que F2 (`art/blender/terrain/f2_report.md`), mêmes cadres et pivots. Référence des emprises : Design_Isometrique §4.2.

### G2a : murs et remparts, 7 assets
| Fichier | Taille | Spec |
|---|---|---|
| `block_a.png`, `block_c.png` (+ `_shadow` 512²) | 256 × 256, emprise 256 × 128, hauteur 1,25 u (98 px), centre d'emprise (128, 192) | a : bloc de grès à strates obliques ; c : bloc de schiste sombre fendu. Arêtes jointives sur les diagonales **mais** profil supérieur irrégulier (±6 px) pour casser la ligne de mur |
| `block_b.png` + `block_b_e.png` (128²) + `_shadow` | idem | bloc de grès à **fissure de mycélium** (seul bloc émissif ; poids d'apparition géré par le code, inchangé) |
| `rampart_ne.png`, `rampart_nw.png` (+ `_shadow`) | 256 × 256 | bord arrière : paroi de grès qui monte (1,25 u), concrétions au pied |
| `rampart_corner_n.png` + `rampart_corner_n_e.png` (128²) + `_shadow` | 256 × 256 | coin arrière avec une veine de mycélium |

### G2b : falaises, vide, eau, 8 assets
| Fichier | Taille | Spec |
|---|---|---|
| `cliff_sw.png`, `cliff_se.png`, `cliff_corner_s.png`, `cliff_corner_w.png`, `cliff_corner_e.png` | 256 × 384, dessus 256 × 128 + paroi 2,5 u (196 px), centre d'emprise (128, 64) | falaise de grès à strates obliques qui descend dans l'abîme ; bord supérieur ébréché ; pas de `_shadow` |
| `void_1024.png` | 1024 × 1024, rig TOP, sans raccord | abîme brun-noir `#120E0C` avec brume ocre `#3A2C24` à 20 % (le vide n'est plus bleu) |
| `water_deep.png` | 256 × 128 (2 u), lit | rivière vert-bouteille `#14302C`, fond de galets sombres à peine visible ; reflets gérés par le shader |
| `water_shallow.png` | 256 × 128 | gour `#2A4A42`, fond de calcite beige visible (le jeu l'affiche à alpha 0,4 : rester aussi sombre que `~`) |

Vérif G2 : dimensions, alpha, raccords diagonaux des blocs en 2 × 2, `block_b_e` et `rampart_corner_n_e` non noirs, `foret_iso_test.tscn` → `RESULT: OK`.

---

## Lot G3 : props A (`props/fog_forest/`, rig MAP, profil `prop`, `eco-mini`)

`props.json` inchangé (mêmes `name`, `foot`, `fade`, `shadow_rig`) : les 6 noms gardent leur emprise et leur pivot. Toujours `<f>_shadow.png` 512² rig TOP.

### G3a : 4 props + ombres
| Fichier | Taille | Était | Devient |
|---|---|---|---|
| `stump.png` | 128 × 128, foot (64, 94) | souche | **bloc effondré** de grès, cassure fraîche plus claire |
| `mushrooms.png` + **`mushrooms_e.png`** (64², nouveau) | 128 × 128, foot (64, 94) | champignons | touffe de champignons de grotte, chapeaux mauves à lamelles de mycélium luisant (`_e` : lamelles seulement) |
| `standing_stone.png` | 192 × 192, foot (96, 166) | pierre levée | **stalagmite haute** trapue, anneaux de calcite |
| `root_arch_a.png` | 256 × 256, foot (128, 224) | arche de racines | **arche de roche** naturelle avec racines mortes qui pendent |

### G3b : 4 props + ombres
| Fichier | Taille | Était | Devient |
|---|---|---|---|
| `lantern_shrine_se.png`, `lantern_shrine_sw.png`, `lantern_shrine.png` (+ `_e` 96² chacun, `_shadow`) | 192 × 192, foot (96, 158) | sanctuaire à lanterne | **cairn de mycélium** : pile de pierres plates coiffée d'un chapeau de champignon luisant, 2 orientations rendues (jamais de miroir) ; `_e` = chapeau |
| `cedar_giant.png` (+ `_shadow`) | 384 × 384, foot (192, 340), `fade` true | cèdre géant | **colonne stalagmite-stalactite** géante (jonction au tiers supérieur), veine de mycélium (`cedar_giant_e.png` 192², nouveau, optionnel) |

Optionnel (fichiers présents mais absents de `props.json`) : `root_arch_b.png`, `root_arch_c.png`, `root_arch_corner.png` : re-rendre seulement si un lot ultérieur les branche.

Vérif G3 : `foot` identiques (pixel au sol inchangé), ombres centrées, `_e` non noirs, planche contact sur `ground_a`.

---

## Lot G4 : props propres à la variante B, 3 assets + ombres (`props/fog_forest/`, rig MAP, `eco-mini`)

Nouveaux noms ; à ajouter à `props.json` (poids 1 chacun, en attendant les props par carte : Design_Variantes_B §7). Intégration code par l'agent d'intégration, pas par Codex.

| Fichier | Taille | Spec |
|---|---|---|
| `hanging_roots.png` (+ `_shadow`) | 256 × 320, foot (128, 300), `fade` true | rideau de racines mortes qui pend de la voûte jusqu'au sol, 2-3 filaments de mycélium (`hanging_roots_e.png` 128 × 160) |
| `calcite_cascade.png` (+ `_shadow`) | 192 × 256, foot (96, 236) | coulée de calcite en draperie sur un bloc, beige, film d'eau |
| `mushroom_shelf.png` + `mushroom_shelf_e.png` (96²) | 192 × 192, foot (96, 166) | champignons en étagère sur un rocher, chapeaux luisants (`_e`) |

---

## Lot G5 : concrétions, 4 assets + ombres (`props/fog_forest/`, rig MAP, `eco-mini`)

Nouveaux noms ; ajout à `props.json` (poids : 3, 2, 1, 1). Aucun émissif : **le minéral de la grotte est éteint** (différence avec l'étage 4).

| Fichier | Taille | Spec |
|---|---|---|
| `stalagmite_cluster.png` (+ `_shadow`) | 192 × 192, foot (96, 170) | 3-5 stalagmites trapues de hauteurs différentes, calcite beige sur base de grès |
| `gour_rim.png` | 256 × 128, rig TOP (décalque, pas d'ombre) | bord de gour en gradins, film d'eau au centre (alpha 0,5) |
| `geode_dark.png` (+ `_shadow`) | 128 × 128, foot (64, 100) | géode ouverte de quartz fumé **non lumineux** (`#2E2A30`), facettes mates |
| `boulder_split.png` (+ `_shadow`) | 192 × 192, foot (96, 166) | gros bloc de grès fendu en deux, strates obliques |

---

## Lot G6 : props de secrets, 8 assets (`props/secret/`, rig MAP, profil `prop`, `eco-mini`)

Scripts à reprendre par paramètres : `art/tools/props/secret_lever_build.py`, `art/tools/props/secret_wall_build.py` (biome `fog_forest`). Mêmes noms, mêmes tailles, mêmes nombres d'images.

| Fichier | Taille | Spec |
|---|---|---|
| `lever_fog_forest_off.png`, `lever_fog_forest_on.png` (+ `_e` 64², `_shadow` 128²) | 128 × 128 | **stalagmite-levier** : concrétion fendue qu'on bascule ; `on` : veine de mycélium allumée (`_e` : `off` presque éteint 10 %, `on` plein) |
| `wall_fog_forest_0.png`, `wall_fog_forest_1.png` (+ `_e` 128²), `wall_fog_forest_2.png` (+ `_e` 128²) | 256 × 256 (bloc 1,25 u, même cadre que `block_*`) | paroi de grès lézardée : 0 intacte (fissure fine, sans `_e`), 1 fissures à mycélium, 2 fissures larges et éclats tombés |
| `wall_fog_forest_break.png` (+ `_e` 640 × 128) | 1280 × 256, 5 images de 256 | éclatement : la paroi s'effondre en blocs, poussière d'ocre, mycélium qui s'éteint sur les 5 images |

Spec en réserve (non chargée par le code aujourd'hui : `secret_plate.gd` dessine un placeholder) : `plate_fog_forest_armed.png` / `plate_fog_forest_pressed.png`, 256 × 128 rig TOP, dalle de calcite veinée, veine `_e` violette à l'état `pressed`. À produire seulement quand le code les lit.

Vérif G6 : `secret_lever_contact.png` et `secret_wall_contact.png` régénérés (≤ 1024 px de large), `secrets_test.tscn` → `RESULT: OK`.

---

## Lot G7 : textures d'ambiance, 4 assets (`sprites/ambiance/`, profil `vfx`, `eco-mini`)

Existants réutilisés tels quels : `drop_32` (gouttes), `mote_16` (poussière et spores, teintées par le profil), `fog_puff_512`, `light_soft_256`, `splash_8x64`, `wind_streak_128`, `ripple_8x64`.

| Fichier | Taille | Spec |
|---|---|---|
| `lightshaft_256x1024.png` | 256 × 1024, billboard vertical, additif | rai de lumière de puits : cône doux qui s'élargit vers le bas, bords flous, poussière suggérée par un bruit très léger ; blanc neutre (teinte par le code) |
| `cave_ceiling_2048.png` | 2048 × 2048, rig TOP, sans raccord | calque multiply de voûte : masses d'ombre de stalactites et de racines, contraste doux (remplace `canopy_shadow_2048` dans le profil `foret_brume`) ; ≤ 400 Ko |
| `drip_ring_64.png` | 64 × 64, 4 images (planche 256 × 64), rig TOP | anneau de goutte sur l'argile humide (plus serré que `ripple`) |
| `spore_puff_128.png` | 128 × 128 | bouffée de spores (nuage mou, bords flous), blanc neutre, utilisé additif violet par « Vent de gouffre » |

---

## Lot G8 : foule `_moss` rhabillée, 4 assets (`monsters/{swarm_tier1,shooter_tier2,leaper_tier2,brute_tier3}_moss/`, rig CREA, profil `creature`, `full`, `low`)

Scripts d'origine des variantes de matière par biome (lot « variante de matière », Design_Etages §5.6). Mêmes planches (`run.png`, `charge.png`, anims, 8 directions, frames, pivots, `.tres` inchangés). Matière « mousse » → **grès poudré d'ocre et lichen gris**, yeux en accent violet `#C27BFF` (`_e`), aucun vert. Chroma +10 % (Direction_Lumiere §2.2). Contrôle sur `ground_a` du Gouffre : corps à L\* ≥ 60 sur sol L\* 30-45.

---

## Lot G9 : Cerf-Lanterne, accent et follets (`bosses/etage/cerf/`, profil `boss`, `full`, `medium`)

Scripts d'origine `art/tools/bosses/` (lot C7b/C7d). Aucune géométrie ni frame ne change ; seules les matières et l'émission.

| Fichier | Changement |
|---|---|
| `idle_p1/2/3`, `auto`, `auto_dirs`, `spell_a`, `spell_a_dirs`, `spell_b`, `spell_b_dirs`, `antlers`, `antlers_dirs`, `charge_dirs`, `death`, `reappear` (+ leurs `_e`) | pelage poudré d'ocre, sabots de schiste ; lanternes des bois → **amas de mycélium** : `_e` en `#C27BFF` (mêmes zones d'accent, IoU > 0,97 contre l'archive) |
| `ground_mist`, `ground_wisp_trail`, `wisp_bolt` (+ `_e`) | follets et brume au sol en violet / poussière ocre |

Vérif : `cerf_boss_test.tscn`, `sprites_test.tscn` → `RESULT: OK` ; `art/tools/bosses/_g9_contact.png`.

---

## Lot G10 : mini-boss P2, 3 assets (`bosses/mini/{bramble_queen,mist_wolf,moss_mantis}/` + `mist_wolf_cub`, profil `creature`, `full`, `low`)

Mêmes planches, frames, pivots, `.tres`. `bramble_queen` : ronces → filaments de mycélium et lichen, couronne de chapeaux violets (`_e`). `mist_wolf` et `mist_wolf_cub` : pelage gris-ocre, yeux violets, VFX de brume → poussière ocre. `moss_mantis` : lichen ocre et gris sur grès, lames de schiste. Les autres (`brood_mother`, `lantern_owl`, `weaver`, `hermit_cedar`) restent tels quels en v1 (recoloration `_e` seule, à l'occasion).

---

## Lot G11 : audio (Codex, `art/tools/audio/`, `eco`, `low`)

Mêmes chemins et ids (`music_manifest.json`, `ambience_manifest.json`, `game/data/audio/sounds.json` inchangé sauf surfaces) ; nouveaux prompts.

| Id | Fichier | Était | Devient |
|---|---|---|---|
| `music.foret_brume.base` / `.tension` / `.drive` / `.climax` | `music/music_foret_brume_{base,tension,drive,climax}_01.ogg` | nappes et flûte | **résonance de grotte** : drones graves à longue réverbération, percussions de pierre sèche (claves, gouttes accordées), un motif de flûte de roseau grave (pas d'os : étage 4) ; les couches montent avec D (drive : pulsation de tambour sourd ; climax : chœur de souffles) |
| `music.boss.foret_brume` | `music/music_boss_foret_brume_01.ogg` | boss forêt | même matière, tempo 110, cloche de pierre |
| `amb.foret_brume.decor` | `ambience/amb_foret_brume_decor_01.ogg` | hiboux, lucioles | rivière souterraine lointaine, gouttes sèches à écho court (0,9 s), craquements de concrétions |
| `amb.wind.foret_brume` | `ambience/amb_wind_foret_brume_01.ogg` | vent de canopée | souffle grave de gouffre par bouffées (4-8 s), sifflement de diaclase faible |

Vérif : `art/tools/audio/verify_new.py`, `audio_test` et `audio_director_test` → `RESULT: OK`.

---

## Ordre et dépendances

1. **G1a + G2a + G2b** (sol de repli, murs, falaises, eau) : le biome change de peau d'un coup ; périmètres disjoints → parallèle possible.
2. **G3a + G3b** (props A), **G6** (secrets), **G7** (ambiance) : parallèle, après G1a (planche contact sur le vrai sol).
3. **G1b + G1c** dès que le contrat du sol de l'architecte est connu (tailles à confirmer avant de lancer).
4. **G4**, **G5** (props B, concrétions) : après branchement de `props.json`.
5. **G9** (Cerf), **G8** (foule), **G10** (minis) : `full`, un seul à la fois (créatures).
6. **G11** (audio) : indépendant, à tout moment.

Compte : 11 lots, ≈ 60 fichiers diffus (+ `_e`, `_shadow`), aucun nouveau nom côté code sauf G4/G5 (`props.json`) et G7 (profil d'ambiance).
