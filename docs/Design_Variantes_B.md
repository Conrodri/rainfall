# Variantes B des quatre biomes (étages 1-4)

> Statut : **plan de level design** suite à la décision du joueur du 28/10/2026 (faire les variantes B des 4 biomes ; étage 5 « La Source » sans variante ; aucun nouveau boss). Cohérent avec `docs/Design_Etages.md` §2.3-§2.4 et §3, `docs/Design_Isometrique.md`, `docs/Design_Zones_Secretes.md` §3-§4.
> Les quatre cartes sont écrites au format exact des variantes A (`game/data/maps/<id>.json`). **Aucun GDScript, aucune scène, ni `floors.json` / `fauna.json` n'ont été modifiés** : l'intégration est décrite au §6.
> Tous les temps marqués « estimé » viennent d'un calcul de chemin sur la grille (Dijkstra, cases de 2 u, joueur à 4,0 u/s `Balance.PLAYER_SPEED_U`), pas d'une partie jouée.

## 0. Ce que le format de carte permet (et ne permet pas)

Lu dans `tools/gen_maps.py`, `scripts/stage/stage_map.gd`, `stage_manager.gd`, `floor_plan.gd`, `ambiance_water.gd`, `occluder_builder.gd` :

| Caractère | Effet | Collision | Apparitions / capsules |
|---|---|---|---|
| `#` | mur / falaise (tuile `block_*` du biome, 1,25 u, fondu devant le joueur) | oui (rectangles fusionnés) | non |
| `~` | eau profonde (bande `ColorRect`, rive dessinée) | oui | non |
| `,` | eau peu profonde (film translucide) | non | oui |
| `.` | sol | non | oui (props de biome tirés à 5 %) |
| `C P G E S` | coffre, petit pilier, gros pilier, événement, départ : case praticable, repère déduit (`2 × case + 1` u) | non | non |

- Une poche de `.` entourée de `#` est exclue des apparitions et des capsules (`NavField`, `is_reachable_local`) : c'est ainsi que les **salles secrètes** sont posées ici, porte comprise en `#`, en attendant le code des secrets.
- Le téléporteur se pose sous le gros pilier tiré (`TELEPORTER_OFFSET` = (0, 300) px logiques ≈ +3,3 u / +3,3 u en repère carte) : chaque `G` des B a cette case libre.
- Les props sont **par biome** (`props/<biome>/props.json`), jamais par carte ; les « props fixes » (`fixed`) s'appliqueraient à toutes les variantes du biome. **Besoin de code** si l'on veut un jour des props propres à B (§7).
- Les clés `secrets` et `hour_shift_min` ajoutées aux JSON B ne sont lues par aucun code aujourd'hui (données pour les lots secrets et ambiance) ; `ambient_event` et `events.types` ne sont, eux non plus, lus par aucun script (texte de design, comme dans les A).

## 1. Règles communes aux quatre B (identiques aux A)

- `draw_rules` **copiées des A** : 8 petits coffres, 2 grands, légendaire 25 %, 2 petits piliers + 1 gros, piliers à ≥ 18 u entre eux, gros pilier à ≥ 20 u du départ, disque praticable ≥ 70 % (7 u petit, 9 u gros), dégagement 3 u, légendaire à ≥ 24 u, coffre piégé à ≥ 12 u. `events` : 60 %, 1 par étage, mêmes 4 types (habillage B). `monster_spawn` identique.
- **Même nombre de candidats que la A du biome** (les tests `maps_test` peuvent reprendre les mêmes attentes) :

| Biome | Coffres C | Petits piliers P | Gros piliers G | Événements E |
|---|---|---|---|---|
| Terrasses (A et B) | 18 | 7 | 3 | 3 |
| Forêt (A et B) | 17 | 6 | 3 | 3 |
| Cité (A et B) | 17 | 8 | 3 | 3 |
| Cryptes (A et B) | 20 | 6 | 3 | 3 |

- **Tous** les candidats piliers des B sont éligibles (disque ≥ 70 %, dégagement 3 u entièrement libre, gros pilier ≥ 20 u du départ) ; les A en écartent 1 à 3 (terrasses A : 1 seul gros éligible). Tirages valides (2 P + 1 G) : Rizières 40, Mangrove 25, Fonderie 70, Ossuaire 27 (A : 5 / 5 / 57 / 34).
- **Départ excentré** (Design_Etages §2.4) sur un coin du losange à l'écran : la lecture « je monte dans la carte » remplace le départ central des A.
- **Secret majeur = porte scellée** (deux plaques au passage, définitives, deux gardiens nommés, Design_Zones_Secretes §3), placée dans la grille de chaque B. La porte est toujours sur une face tournée vers la caméra (+x = bas-droite ou +y = bas-gauche à l'écran), donc les barreaux et les gardiens endormis se lisent depuis la salle voisine.
- Repère d'écran (Design_Isometrique §1.2) : case (x, y) de la grille → écran ≈ (x − y, (x + y) / 2). La rangée 0 / colonne 0 est la **pointe haute** du losange, (max x, max y) la **pointe basse**, (0, max y) la pointe gauche, (max x, 0) la pointe droite. Un muret « rangée pleine » se lit comme une diagonale ↘.

### 1.1 Mesures A / B (script de vérification, estimé)

| Carte | Taille (u) | Sol praticable | Rect. collision | Murs (≈ occluders) | Cases `~` / bandes | Cases `,` / bandes | Tour S → P → P → G | Tour complet (10 coffres + piliers) |
|---|---|---|---|---|---|---|---|---|
| Terrasses A | 56 × 64 | 76 % | 36 | 24 | 36 / 15 | 12 / 4 | 117 u | 264 u ≈ 66 s |
| **Rizières hautes** | 48 × 72 | 74 % | 26 | 23 | 26 / 8 | 82 / 34 | 106 u | 288 u ≈ 72 s |
| Forêt A | 64 × 56 | 76 % | 32 | 23 | 26 / 9 | 6 / 2 | 108 u | 262 u ≈ 65 s |
| **Mangrove des lanternes** | 72 × 48 | 73 % | 39 | 10 | 102 / 45 | 24 / 12 | 108 u | 277 u ≈ 69 s |
| Cité A | 48 × 80 | 76 % | 19 | 15 | 64 / 16 | 31 / 9 | 108 u | 277 u ≈ 69 s |
| **Fonderie du canal** | 64 × 64 | 72 % | 63 | 31 | 92 / 40 | 16 / 8 | 117 u | 316 u ≈ 79 s |
| Cryptes A | 60 × 60 | 70 % | 45 | 40 | 68 / 6 | 46 / 16 | 90 u | 244 u ≈ 61 s |
| **Ossuaire des pluies** | 48 × 76 | 78 % | 30 | 29 | 16 / 4 | 36 / 16 | 117 u | 247 u ≈ 62 s |

Surfaces dans la tolérance « même taille ± 15 % » (3 456 à 4 096 u² contre 3 584 à 3 840 pour les A). Le déplacement pur des B coûte **+1 à +10 s par étage** (estimé) : sur un étage de ≈ 3,8 min (2 mini-boss ≈ 25 s chacun, charge 60 s, boss ≈ 45 s, achats), la durée cible reste tenue à ± 5 %. La Fonderie est la plus longue (+10 s) : levier au §4.6.

---

## 2. Étage 1 · Terrasses — B « Rizières hautes » (`terrasses_rizieres_hautes`)

**Concept** : on gravit, depuis la pointe gauche de l'écran, un escalier de rizières étroites jusqu'à la crête où dort la citerne de la noria.

### 2.1 Plan (24 × 36 cases, 48 × 72 u)

```
        000000000011111111112222
        012345678901234567890123
  0     ########################
  1     #...#......C.....,,,,,C#     T1 « la crête » (rangées 1-8) : arène du sommet
  2     #...#............,~~~,.#     citerne scellée (secret) : intérieur 1-3 x 1-3,
  3     #...#..P.........,~~~,.#     porte = cases (4,2)-(4,3) face +x
  4     #####............,,,,,.#     bassin d'irrigation (17-21 x 1-4)
  5     #...........G..........#     G sommet (25;11)
  6     #..................P...#
  7     #C...E.........C.......#
  8     #......................#
  9     #######..######..#######     muret + escaliers (7-8, 15-16)
 10     #...,,,...C.......,,,..#     T2 rizière étroite (6 u)
 11     #C..,,,.....#.....,,,..#     stèle centrale = 2 voies
 12     #...,,,...........,,,.C#
 13     ##..#######..#######..##     escaliers (2-3, 11-12, 20-21)
 14     #C..............E......#     T3 « la noria » (rangées 14-21)
 15     #......C.,,,,,,.......C#
 16     #........,~~~~,........#     bassin de la noria (10-13 x 16-19)
 17     #...G....,~~~~,....P...#     G ouest (9;35)
 18     #........,~~~~,.P......#
 19     #....P...,~~~~,........#
 20     #........,,,,,,.......C#
 21     #...........C..........#
 22     ######..########..######     escaliers (6-7, 16-17)
 23     #.......,,,...,,,......#     T4 rizière étroite (6 u)
 24     #C......,,,.C.,,,.....C#
 25     #.......,,,...,,,......#
 26     ###..######..######..###     escaliers (3-4, 11-12, 19-20)
 27     #.................C....#     T5 « les rizières basses » (rangées 27-34)
 28     #....................E.#
 29     #.........P............#
 30     #.....P......,,,,..G...#     G bas (39;61)
 31     #.S..........,~~,......#     départ (5;63), pointe gauche du losange
 32     #.......#....,~~,......#     muret de rizière (8 x 32-34)
 33     #.......#..C.,,,,.....C#
 34     #.......#..............#
 35     ########################
```

### 2.2 Circulation et différences avec la A
- **A** = la plus ouverte (grandes terrasses, départ central). **B** = trois paliers ouverts (T1, T3, T5 : 44 × 16 u) reliés par deux **rizières étroites** (T2, T4 : 44 × 6 u). Les murets sont des diagonales ↘ à l'écran ; leurs escaliers sont **décalés d'un muret à l'autre** (zigzag), sauf l'axe central (11-12) qui ne traverse que deux murets : le chemin critique serpente, le joueur pressé coupe par le centre puis contourne la noria.
- **Goulots** : 10 escaliers de 4 u de large ; chacun débouche sur 6 u au moins de sol libre dans les deux sens (≥ portée de roulade). Les rizières étroites sont le lieu où **peigner les hordes** (le flux arrive par les escaliers, un seul front) ; les paliers ouverts sont les zones de pilier.
- **Zones ouvertes pour les hordes** : T5 (départ), T3 autour du bassin (anneau de 4 u de rive praticable `,`), T1 (sommet, ≈ 44 × 16 u). Le bassin de la noria est un **obstacle central** (8 × 8 u) pour l'arène du G ouest et des P de T3 : on tourne autour, la foule s'y coince.
- **Repères visibles de loin** : bassin de la noria au centre (reflets, éclaboussures quand l'événement ambiant démarre), bassin d'irrigation et citerne au sommet, escaliers (rupture du muret). Loi du moindre effort : chaque escalier pointe vers le suivant par la diagonale.

### 2.3 Placements (u)
| Élément | Positions | Notes |
|---|---|---|
| Départ | (5;63) | pointe gauche ; un coffre à 5 u et un à 18 u pour le premier achat |
| Gros piliers | (25;11) sommet, (9;35) noria ouest, (39;61) rizières basses | 34 à 56 u du départ, tous éligibles ; le sommet est le « final naturel » (téléporteur au sommet) |
| Petits piliers | (15;7), (39;13), (39;35), (33;37), (11;39), (21;59), (13;61) | 2 au sommet, 3 sur T3, 2 sur T5 ; aucun dans les rizières étroites (disque < 70 %) |
| Coffres | 18 : 6 dans les rizières étroites (bouts de couloir = détours récompensés), 4 au sommet, 5 sur T3, 3 sur T5 | 16 à ≥ 24 u (légendaire possible partout sauf T5) |
| Événements | (11;15) sommet ouest, (33;29) T3 nord, (43;57) T5 est | |
| **Secret** « citerne de la noria » | porte (4,2)-(4,3) ; salle 6 × 6 u ; dalles de vanne (5;21) bout ouest de T2 et (43;39) T3 est ; gardiens Orme et Aulne | dalle a à 16 u de la porte, dalle b à 48 u : la b se prend en passant vers le P (39;35) |

### 2.4 Rythme (estimé)
| Temps | Phase | Lieu | Intensité |
|---|---|---|---|
| 0:00-0:40 | exploration, 2-3 achats | T5 | basse, montée |
| 0:40-1:10 | pilier A (mini-boss) | T5 ou T3 | **pic 1** |
| 1:10-1:35 | relâche : rizière étroite T4, coffres de bout de couloir | T4 | moyenne (horde en file) |
| 1:35-2:05 | pilier B | T3 | **pic 2** (plus haut) |
| 2:05-2:30 | relâche : T2, dalle a, coffres du sommet | T2 / T1 | basse |
| 2:30-3:50 | gros pilier 60 s + boss | T1 (ou T3 / T5 selon le tirage) | **pic 3** |
| ensuite | farm optionnel, secret, téléporteur (Interagir) | | |

### 2.5 Ambiance (même DA, profil `terrasses`, `hour_shift_min` = +30)
18 h 10 au lieu de 17 h 40 : soleil plus rasant qui **éclaire les escaliers de biais** et allonge les ombres des murets (repère de lecture du relief). Valeurs relatives au profil livré `data/ambiance/terrasses_noyees.tres` : `sun_rotation_deg` 310 → 305, `sun_height` 0,15 → 0,11, `sun_energy` 0,50 → 0,45, `sun_shadow_length_u` 3,2 → 3,7, `sun_color` un cran plus orangé (`#FFC890`), `rays_count` +1 (rayons entre les murets), `fog_low_opacity` 0,08 → 0,10 (brume de rizière dans les paliers bas). Pluie, palette, accent émissif, `light_rules` et paliers de difficulté **inchangés** (mêmes plafonds de lumières : 8 reflets + 10 lanternes). Événement ambiant B : « La noria repart » à Hostile (son de roue, éclaboussures sur le bassin central, cases `,` élargies d'1 u).

### 2.6 Props manquants
**Zéro.** Le biome terrasses n'a pas de dossier `props/` (la A non plus) ; noria, épouvantails et escaliers de pierre (Design_Etages §2.4) restent un **bonus** non bloquant, à n'envisager qu'avec le besoin de code « props fixes par carte » (§7).

---

## 3. Étage 2 · Forêt — B « Mangrove des lanternes » (`foret_mangrove_lanternes`)

**Concept** : un chenal d'eau noire serpente d'est en ouest et coupe la mangrove en deux rives qu'on franchit par deux îlots-gués et deux pontons.

### 3.1 Plan (36 × 24 cases, 72 × 48 u)

```
        000000000011111111112222222222333333
        012345678901234567890123456789012345
  0     ####################################
  1     #C.......C.#...#.....C............C#    berge haute (rangées 1-3) : couloir de 6 u
  2     #..........#...#............C......#    sanctuaire scellé (secret) : intérieur 12-14 x 1-3,
  3     #..........#...#.P.................#    porte = case (13,4) face +y
  4     #...P......#####......~~,,~~~..P...#    ponton nord-est (24-25 x 4-5)
  5     #.......E............~~~,,~~~......#
  6     #....................~~.....~~.....#
  7     #~~,,~~..........C..~~......~~.....#    îlot-gué ouest (2-5 x 9-10), pontons (3-4)
  8     #~~,,~~.....G.......~~E......~~..C.#    G lobe nord (25;17)
  9     #~.C..~............~~....P...~~....#
 10     #~....~~C..........~~.........~~...#
 11     #~~,,~~~~.........~~...#......~~...#    cèdre (23,11) : obstacle de l'arène sud
 12     #~~,,~~~~~........~~...........~~..#
 13     #.......~~~~~,,~~~~.........C..~~..#    îlot-gué central (12-15 x 15-16), pontons (13-14)
 14     #C.......~~~~,,~~~~....G........~~.#    G lobe sud (47;29)
 15     #.........~~....~~..............~,,#    ponton est (33-34 x 15-16)
 16     #...G......~..C.~~..C............,,#    G ouest (9;33)
 17     #..........~~,,~~..................#
 18     #..........~~,,~~..............P...#
 19     #.........................C........#    rive sud : couloir 6-10 u
 20     #.....###....P..............###....#    racines en arche (murets courts)
 21     #.........C................E.....S.#    départ (67;43), pointe basse du losange
 22     #C................C................#
 23     ####################################
```

### 3.2 Circulation et différences avec la A
- **A** = moyeu central et rayons (départ au centre, tout à ≤ 40 u). **B** = un **méandre** : la rive nord (berge haute + lobe nord + lobe nord-est) et la rive sud (rive basse + lobe sud) ne se touchent qu'en **4 franchissements** : îlot-gué ouest, îlot-gué central, ponton nord-est, ponton est (4 u de large chacun, espacés de ≈ 20 u). Le joueur choisit sa traversée ; la foule, elle, s'agglutine aux pontons.
- **Goulots** : les 4 franchissements et la berge haute (6 u). Dégagement ≥ 6 u de rive libre à chaque tête de ponton.
- **Zones ouvertes** : lobe nord (≈ 20 × 18 u), lobe sud (≈ 24 × 24 u, avec le **cèdre central** comme obstacle de contre-jeu à 6 u du G), rive ouest (≈ 18 × 20 u).
- **Deux îles** (Design_Etages §3) : îlots-gués de 8 × 4 u au milieu du chenal, avec coffre ; l'îlot ouest porte aussi la **première pierre à rune** du secret.
- **Repères** : le chenal noir (bord d'écume clair) se lit comme un fleuve en S ; les lanternes de rive (règle de lumière, §3.5) jalonnent les berges ; le sanctuaire scellé au fond du lobe nord est visible depuis le G nord.

### 3.3 Placements (u)
| Élément | Positions | Notes |
|---|---|---|
| Départ | (67;43) | pointe basse ; ponton est à 10 u (choix immédiat : traverser ou longer la rive sud) |
| Gros piliers | (25;17) lobe nord, (47;29) lobe sud (cèdre), (9;33) rive ouest | 24 à 59 u du départ |
| Petits piliers | (9;9), (35;7), (63;9), (51;19), (63;37), (27;41) | 3 sur la rive nord, 3 sur la rive sud |
| Coffres | 17 : 2 sur les îlots, 8 sur la rive nord (berge haute, lobes nord et nord-est), 7 sur la rive sud et le lobe sud | 15 à ≥ 24 u |
| Événements | (17;11) rive nord-ouest, (45;17) tête de ponton du lobe sud, (55;43) rive sud | |
| **Secret** « sanctuaire des racines » | porte (13,4) ; salle 6 × 6 u ; pierres à rune (11;21) sur l'îlot ouest et (67;13) lobe nord-est ; gardiens Lierre et Houx | porte à 20 u de la pierre a, 40 u de la b ; entrée d'une case : les gardiens sortent l'un après l'autre (comme la A) |

### 3.4 Rythme (estimé)
Départ sud-est → pilier A sur la rive sud ou le lobe nord-est (0:40-1:10, pic 1) → traversée par un ponton (relâche, coffre d'îlot) → pilier B sur l'autre rive (1:35-2:05, pic 2) → retour par l'autre gué (relâche) → gros pilier (pic 3). Le méandre impose **au moins deux traversées** par étage : chacune est une petite respiration (la foule se resserre derrière, le joueur la peigne au débouché).

### 3.5 Ambiance (profil `foret`, `hour_shift_min` = −30)
4 h 40 au lieu de 5 h 10 : **avant l'aube**, plus bleu, les lanternes deviennent le guide. Relatif à `foret_brume.tres` : `ambient_color` −5 % de luminance (le garde-fou de lisibilité de l'AmbianceManager reste actif), `sun_energy` 0,42 → 0,36, `map_lights_energy` 1,0 → 1,15, `fog_low_opacity` 0,10 → 0,12 (brume au ras du chenal). **Règle de lumière** : la A pose ses `shrine_lantern` sur les bords de `#` (16 u, 8 max) ; la B a peu de murs (10 rectangles) → même préréglage sur les bords de `~` (`"char": "~"`, `spacing_u` 12, **`max` 8 inchangé**) : lanternes sur pilotis le long du chenal, même coût. Événement ambiant B : « Marée montante » à Furieux (cases `,` des pontons et rives élargies d'1 u, lucioles éteintes, brume 15 %).

### 3.6 Props manquants
**Zéro.** Les 6 props livrés (`stump`, `mushrooms`, `standing_stone`, `root_arch_a`, `lantern_shrine_se`, `cedar_giant`) suffisent ; les pontons sont des cases `,` (tuile d'eau peu profonde). Pontons de bois, cages à lucioles et autel effondré = bonus non bloquant.

---

## 4. Étage 3 · Cité — B « Fonderie du canal » (`cite_fonderie_canal`)

**Concept** : une cour de coulée ronde, ceinte d'un mur et d'un canal circulaire, qu'on rejoint par deux anneaux de passerelles depuis quatre ateliers d'angle.

### 4.1 Plan (32 × 32 cases, 64 × 64 u)

```
        00000000001111111111222222222233
        01234567890123456789012345678901
  0     ################################
  1     #C.......#...............#.....#    atelier NO | chambre forte (secret) NE :
  2     #.....C..#.C........C....#.....#    intérieur 26-30 x 1-3, porte = (27,4)-(28,4) face +y
  3     #........#......P........#.....#
  4     #........................#######
  5     #....G...E...~~,,~~............#    G atelier NO (11;11) ; pont nord (15-16 x 5-6)
  6     #.C.......~~~~~,,~~~~~........C#
  7     #........~~~........~~~....P...#    canal circulaire (r 19-22 u)
  8     #.......~~......C.....~~.......#    anneau 1 (entre mur et canal, 5 u)
  9     ####...~~....######....~~...####
 10     #.....~~....##....##....~~.....#    mur de la cour (r 12-14 u), 4 portes en diagonale
 11     #.....~~................~~.....#
 12     #C....~...#.....#....#...~.....#    creusets (16,12), (12,15), (19,16), (15,19)
 13     #....~~..##..C.......##..~~...C#
 14     #....~~..#............#..~~....#
 15     #....,,.C#..#.........#..,,....#    ponts ouest et est
 16     #..P.,,..#......G..#..#C.,,.P..#    G cour (33;33)
 17     #....~~..#...P........#..~~....#
 18     #....~~..##..E....C..##..~~....#
 19     #.....~...#....#.....#...~.....#
 20     #.....~~................~~.....#
 21     #.....~~....##....##....~~.....#
 22     ####...~~....######....~~...####
 23     #.......~~......C.....~~.......#
 24     #........~~~........~~~........#
 25     #....P....~~~~~,,~~~~~...G.....#    pont sud ; G atelier SE (51;51)
 26     #............~~,,~~......E.....#
 27     #..S...........................#    départ (7;55), pointe gauche
 28     #........#......P.....#.....P..#
 29     #........#............#........#    anneau 2 = sol entre canal et ateliers
 30     #........#...C........#.C.....C#
 31     ################################
```

### 4.2 Circulation et différences avec la A
- **A** = canal vertical et 3 ponts, deux berges longues (48 × 80 u, couloir N-S). **B** = **plan concentrique** : 4 ateliers d'angle (zones ouvertes ≈ 16 × 16 u) → anneau 2 (sol extérieur) → **4 ponts** sur les axes → anneau 1 (passerelle de 5 u entre le canal et le mur) → **4 portes** en diagonale → cour (rayon 12 u). Ponts et portes sont **décalés de 45°** : on fait toujours un quart d'anneau entre un pont et une porte, ce qui fait tourner la foule autour de la cour (goulot circulaire, jamais de cul-de-sac).
- **Goulots** : ponts (4 u), portes (≈ 4 u), anneau 1 (5 u). **Zones ouvertes** : cour, 4 ateliers.
- **Arène à obstacle central** (Design_Etages §2.4, pour la Grue / le Fondeur) : la cour, avec les **4 creusets** (blocs de 2 × 2 u à 6-8 u du G) : contre-jeu en tournant autour, sans masquer la caméra (blocs de 1,25 u).
- **Repères** : la cour au centre de l'écran (lueur orange des creusets), les ponts sur les axes, la chambre forte à la pointe droite.

### 4.3 Placements (u)
| Élément | Positions | Notes |
|---|---|---|
| Départ | (7;55) | atelier SO |
| Gros piliers | (33;33) cour, (11;11) atelier NO, (51;51) atelier SE | 34 à 44 u du départ ; la cour est l'arène « signature » |
| Petits piliers | (33;7) N, (55;15) NE, (7;33) O, (57;33) E, (27;35) cour, (11;51) SO, (33;57) S, (57;57) SE | un par secteur ; sur les anneaux extérieurs ils tiennent la tête de pont |
| Coffres | 17 : 4 sur l'anneau 1 (sur le chemin), 2 dans la cour, 11 dans les ateliers et sur l'anneau 2 | 16 à ≥ 24 u |
| Événements | (19;11) atelier NO, (27;37) cour, (51;53) atelier SE | |
| **Secret** « chambre forte » | porte (27,4)-(28,4) ; salle 10 × 6 u ; plaques rivetées (5;33) près du pont ouest et (33;59) près du pont sud ; gardiens Rivet et Soudure | plaques sur l'anneau 2, au débouché de deux ponts : elles se prennent en route vers les piliers O / S |

### 4.4 Rythme (estimé)
Atelier SO (achats) → pilier A dans un secteur extérieur (pic 1) → quart d'anneau, coffres de l'anneau 1 (relâche) → pilier B dans un autre secteur (pic 2) → gros pilier : cour (pic 3, la plus forte pression : la foule arrive par 4 portes) ou atelier d'angle.

### 4.5 Ambiance (profil `cite`, `hour_shift_min` = +30)
20 h 00 : nuit tombée, la **fonderie éclaire** à la place du ciel. Relatif à `cite_rouille.tres` : `ambient_color` −4 % de luminance, `sun_energy` 0,40 → 0,34, `sun_shadow_length_u` 1,8 → 1,4. Lumières : règle `steam_lamp` sur les bords de `~` gardée (8 u) mais **`max` 24 → 20**, plus 4 `point_lights` aux creusets (préréglage `steam_lamp`, orange, énergie ×1,3) : 24 lumières au plus, comme la A (24 + cloche). La cloche d'alerte (`alarm_bell`) passe au centre de la cour (32;32). Événement ambiant B : « Coulée » (creusets qui pulsent orange ; orage à Furieux ; canal qui monte à Cataclysme).

### 4.6 Props manquants et réglage
**Zéro** prop requis (caisses, tonneaux, vannes, cuves livrés ; les creusets sont des cases `#` avec les blocs du biome). Creuset, rails et wagonnets = bonus non bloquant. **Levier de durée** si les tests montrent un étage trop long (+10 s estimé) : passer les coffres (13;5) et (49;61) sur l'anneau 1, ou réduire la carte à 60 × 60 u (même plan, cour inchangée).

---

## 5. Étage 4 · Cryptes — B « Ossuaire des pluies » (`cryptes_ossuaire_pluies`)

**Concept** : trois galeries parallèles d'ossuaire, reliées par des escaliers, se rejoignent sous un puits de lumière où la pluie de la ville tombe dans un bassin noir.

### 5.1 Plan (24 × 38 cases, 48 × 76 u)

```
        000000000011111111112222
        012345678901234567890123
  0     ########################
  1     #C....C#...C....#......#    ossuaire scellé (secret) : intérieur 17-22 x 1-2,
  2     #......#........#......#    porte = (19,3)-(20,3) face +y
  3     #......#........########
  4     #..P...#..#..#..#......#    nef centrale (8-15) : piliers de nef 1 case
  5     #................C.....#    traverse 1 (rangées 5-6)
  6     #...........P..........#
  7     #......#C.......#...P..#
  8     #.,,...#........#......#
  9     #.,,...#..#..#..#.....C#
 10     #......#........#......#
 11     #C.....................#    traverse 2 (rangées 11-12)
 12     #..............C...,,,.#
 13     #......#...G....#..,,,.#    G nef nord (23;27)
 14     #..P...#........#......#
 15     #......#........#......#
 16     #........,,,,,,.......E#    salle du puits (rangées 16-21, toute la largeur)
 17     #........,~~~~,........#    bassin noir sous le puits (10-13 x 17-20)
 18     #...E....,~~~~,....G...#    G salle est (39;37)
 19     #C.......,~~~~,........#
 20     #........,~~~~,........#
 21     #....C...,,,,,,.......C#
 22     #......#........#......#
 23     #.,,,..#.......C#......#
 24     #.,,,..#...G....#......#    G nef sud (23;49)
 25     #......#C.......#.....C#
 26     #......................#    traverse 4 (rangées 26-27)
 27     #...................P..#
 28     #......#..#..#..#......#
 29     #C.....#........#......#    niches d'ossuaire (culs-de-sac à coffre)
 30     ####...#........#...####
 31     #.....C#....P...#.....C#
 32     #......................#    traverse 5 (rangées 32-33)
 33     #.........#..#.........#
 34     #......#.......E#......#
 35     #..S...#........#......#    départ (7;71), pointe gauche
 36     #C.....#...C....#C.....#
 37     ########################
```

### 5.2 Circulation et différences avec la A
- **A** = nef centrale + 4 chapelles + grand lac au sud (60 × 60 u). **B** = **trois galeries** nord-sud (12 u, 16 u, 12 u), diagonales ↙ à l'écran, séparées par deux murs percés de **5 traverses** (escaliers de 4 u, et la salle du puits de 12 u) : on remonte une galerie en ligne droite et l'on change de galerie aux traverses.
- **Goulots** : les traverses de 4 u ; la nef porte des piliers d'1 case qui coupent les lignes de vue sans fermer le passage. **Zones ouvertes** : la salle du puits (44 × 12 u avec bassin central), la nef (16 u).
- **Lac pour l'Anguille des profondeurs** (`deep_eel_brain`, rive à ≤ 9 + 7 u du pilier) : les **trois** gros piliers sont à 7-11 u du bassin du puits (A : seul le pilier sud était près du lac).
- **Repères** : la colonne de lumière froide du puits (centre de la carte, visible depuis chaque traverse), les veines de cristal sur les murs de galerie (règle `crystal_vein`), l'ossuaire scellé au fond de la galerie est.

### 5.3 Placements (u)
| Élément | Positions | Notes |
|---|---|---|
| Départ | (7;71) | bas de la galerie ouest |
| Gros piliers | (23;27) nef nord, (39;37) salle est, (23;49) nef sud | 27 à 47 u du départ ; tous près du bassin |
| Petits piliers | (7;9), (25;13), (41;15), (7;29), (41;55), (25;63) | répartis sur les trois galeries, nord et sud |
| Coffres | 20 : 2 dans les niches d'ossuaire, 6 en bout de galerie, 12 le long des galeries | 15 à ≥ 24 u |
| Événements | (45;33) salle est, (9;37) salle ouest, (31;69) nef sud | |
| **Secret** « ossuaire scellé » | porte (19,3)-(20,3) ; salle 12 × 4 u ; dalles d'os à glyphe de sel (3;47) galerie ouest et (45;29) galerie est ; gardiens Sel et Suie | la dalle a est sur le chemin du départ vers le puits ; la b à 23 u de la porte |

### 5.4 Rythme (estimé)
Galerie ouest (achats, dalle a) → pilier A dans une galerie (pic 1) → traverse, niche à coffre (relâche) → pilier B (pic 2) → salle du puits ou nef (pic 3, la crue monte). Galeries = respiration en ligne droite ; traverses et puits = pression.

### 5.5 Ambiance (profil `cryptes`, `hour_shift_min` = 0)
Pas de soleil, donc pas de décalage horaire : la nuance de B est le **puits de lumière**. Relatif à `cryptes_noyees.tres` : 1 `point_light` au centre du puits (24;37), préréglage `crystal_vein` en énergie ×1,6 (colonne froide, la seule « lumière du jour » de l'étage) ; `light_rules` inchangées (36 veines sur les murs + 8 sur l'eau, mêmes plafonds) ; `rain_intensity` 0 → 0,15 et `drops_amount` +30 % pour la pluie qui tombe du puits (globale tant qu'une zone de pluie locale n'existe pas, §7). Événement ambiant B : « Pluie du puits » (le bassin déborde, cases `,` élargies ; Furieux : cristaux qui s'éteignent par vagues, comme la A).

### 5.6 Props manquants
**Zéro.** Les 8 props livrés (`bone_pile`, `ossuary_niche`, `salt_crust`, `crystal_cluster`, `stalagmite`, `broken_column`, `crystal_lantern`, `sarcophagus_lid`) couvrent galeries et niches. Puits de lumière (margelle) et escaliers = bonus non bloquant.

---

## 6. Intégration (à faire par l'orchestrateur, après tests)

**Ordre impératif** : générer les scènes **avant** de lister les cartes dans `floors.json`. Aujourd'hui `StageManager._load_catalog()` charge tout `data/maps/*.json` et appelle `load(scene)` : sans les `.tscn`, chaque chargement du catalogue écrit 8 lignes `ERROR: Cannot open file 'res://scenes/stage/maps/<id_B>.tscn'` (constaté avec `stage_test`, qui reste `RESULT: OK`).

1. **`tools/gen_maps.py`** : ajouter les 4 grilles (copier `grid` des JSON B) à `NEW_MAPS` avec `variant="B"`, les ids au jeu `ISO`, puis `python tools/gen_maps.py terrasses_rizieres_hautes foret_mangrove_lanternes cite_fonderie_canal cryptes_ossuaire_pluies`. **Besoin de code** : `gen_maps.py` doit recopier `secrets` et `hour_shift_min` (sinon la régénération les efface) ; `events.types` et `ambient_event` sont dans les JSON B (reprendre leurs valeurs dans `ambient=` / `event_names=`).
2. **`data/floors.json`** : remplacer les ids provisoires (qui ne correspondent à aucun fichier) :
   ```
   "maps": ["terrasses_noyees", "terrasses_rizieres_hautes"]
   "maps": ["foret_brume", "foret_mangrove_lanternes"]
   "maps": ["cite_rouille", "cite_fonderie_canal"]
   "maps": ["cryptes_noyees", "cryptes_ossuaire_pluies"]
   ```
   L'ordre A puis B compte (`FloorPlan` : indice 0 = « A », 1 = « B », sans fin = variante opposée).
3. **`data/fauna.json`** : `"maps"` de chaque biome = les deux ids (`["terrasses_noyees", "terrasses_rizieres_hautes"]`, etc.). Pas bloquant (repli sur la clé `biome` du JSON), mais à garder cohérent.
4. **`data/ambiance/<id_B>.tres`** : un profil par B = copie du profil A + deltas des §2.5, 3.5, 4.5, 5.5 (via `scripts/ambiance/tools/build_profiles.gd`). En attendant : `metadata/ambiance_id = "<id_A>"` dans la scène B (méta déjà lue par `AmbianceManager.bind_map`), sinon avertissement « pas de profil » et ambiance neutre.
5. **`data/audio/sounds.json`** (`maps`) : une entrée par id B (copie de l'entrée A : musique, nappes, surfaces de pas), sinon repli sur `default`.
6. **Tests** : `maps_test.gd` (`MAPS` : ajouter les 4 ids avec les attentes du tableau §1), puis `maps_test`, `reachable_spawn_test`, `stage_test`, `foret_iso_test`, `cite_iso_test`, `cryptes_iso_test`, `boss_pace_test`. Optionnel : `menu_background.gd` (`DAILY_MAPS`) peut accueillir les B.

## 7. Besoins de code (le format ne permet pas encore)

| Besoin | Pourquoi | Où |
|---|---|---|
| Caractères `D` (porte scellée, collision séparée) et `:` (sol scellé) | les salles secrètes sont fermées en `#` ; la porte est décrite dans `secrets.door_cells` | Design_Zones_Secretes §4.1, `gen_maps.py`, `StageMap` |
| Recopie de `secrets` / `hour_shift_min` | régénération sans perte | `gen_maps.py` |
| Props fixes **par carte** (noria, creusets, margelle du puits) | `props.json` est par biome : un `fixed` toucherait A et B | `StageMap._build_fixed_props` (clé `props_fixed` du JSON de carte) |
| Pluie locale (colonne sous le puits de l'Ossuaire) | la pluie est un calque global | `AmbianceManager` |
| Événement ambiant par carte | `ambient_event` n'est lu par aucun script (A comprises) | AmbianceManager / Audio |

## 8. Risques

- **Scènes manquantes** tant que le §6.1 n'est pas fait (erreurs au chargement du catalogue, aucune variante tirée car `floors.json` ne les liste pas encore).
- **Eau** : la Mangrove (45 bandes `~`) et la Fonderie (40) ont 2,5 à 3 fois plus de bandes d'eau profonde que la pire A (16). Ce sont des `ColorRect` à matériau partagé, posés une fois et hors écran la plupart du temps : coût jugé faible, **à mesurer** sur Android (profil Bas). Si besoin : chenal de la Mangrove à 1 case de large dans les virages raides, canal de la Fonderie octogonal.
- **Collisions de la Fonderie** : 63 rectangles (A max 45) à cause des arcs ; statiques, sans coût sensible, mais `occluder_builder` en tirera ≈ 31 occluders (plafond actuel constaté 40) : à vérifier en Haut.
- **Lisibilité mobile** : les murets des Rizières sont de longues diagonales ↘ ; leurs escaliers doivent rester lisibles à 6 pouces (contour de mur `_build_outlines` présent ; la minimap doit les montrer, à confirmer avec ux-designer).
- **Durée** : Fonderie +10 s estimé ; à valider en partie réelle (`balance_sim_test`, partie chronométrée).
- **Boss** : aucun nouveau boss ; les boss d'étage et mini-boss des biomes apparaissent au gros pilier tiré comme dans les A. Le Cèdre-Ermite ou la Grue n'ont pas été testés contre les obstacles centraux (cèdre, creusets) : vérifier qu'ils ne s'y coincent pas.
- **À trancher par le joueur** : (1) départ excentré sur les 4 B (proposé) ou départ central comme les A ; (2) Terrasses B : porte scellée (proposée, mécanique déjà validée) ou « écluse » (vanne qui vide un bassin, Design_Zones_Secretes §2.1) que Design_Etages §2.4 associait aux Rizières ; (3) props propres aux B (noria, creusets, pontons…) : bonus ou à produire avant la sortie.
