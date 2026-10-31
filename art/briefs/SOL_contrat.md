# Contrat des textures de sol v2 (tous biomes)

Statut : contrat technique de l'architecte, 31/10/2026. Système : `game/scripts/stage/ground_splat.gd`
(sol) et `game/scripts/stage/ground_decals.gd` (décalques), shaders `game/shaders/ground_splat*.gdshader*`,
réglages `game/data/maps/ground/biomes.json`. Demande du joueur : « le sol fait très tiles rectangulaires ».

## 1. Pourquoi l'ancien sol se lisait en grille

Le sol était une TileMapLayer de losanges 512 × 256 (un bloc de 4 u × 4 u), tirés parmi 4 variantes
`ground_a..d`. Chaque variante portait des **motifs uniques** (canaux d'eau des terrasses, grille d'égout et
plaque de rouille de la cité, cercles gravés de la Source), des **valeurs différentes** (a/c clairs, b/d
sombres aux terrasses) et un **joint sombre** sur son arête. Résultat : un réseau de 4 u parfaitement régulier
sur toute la carte, renforcé par des dalles alignées sur les axes du losange.

## 2. Le nouveau système (ce que le jeu fait déjà)

- Un seul quad par carte, en repère carte (vue de dessus, tourné de 45° puis écrasé par la caméra iso).
- **4 matières vues de dessus et tuilables** mélangées par pixel : 0 sol principal, 1 variante en grandes
  taches, 2 sol humide (près de l'eau et en flaques), 3 pied des murs (gravats, poussière, mousse).
- Le mélange est piloté par un masque cuit depuis la grille de la carte (vide, eau, murs, eau peu profonde,
  lissé : aucun bord de case) et par un bruit basse fréquence (taches de plusieurs u, variation de valeur et
  de teinte). Les bords de taches sont découpés par la **luminance** des textures (mélange « par hauteur ») :
  les éléments clairs et saillants d'une matière (cailloux, touffes, arêtes) gagnent sur l'autre.
- **Décalques** semés au chargement (un MultiMesh, une passe), tirage stable par carte, jamais sur les murs,
  l'eau profonde, le vide ni à moins d'une case des repères (départ, coffres, piliers, événements).
- Eau peu profonde `,` : film d'eau aux bords lissés dans le shader du sol (plus de losanges d'eau).
- Paliers : Bas = matières 0 et 1 ; Moyen = 4 matières ; Haut = 4 matières + anti-répétition des matières 2-3.

## 3. Fichiers à livrer par biome

Dossier : `game/assets/sprites/terrain/<dossier>/sol/` (mêmes dossiers que les tuiles iso actuelles).

| Biome (étage) | `<dossier>` | Id de biome |
|---|---|---|
| Terrasses noyées (1) | `terraces` | `terrasses` |
| Gouffre luisant, grotte (2, ex-Forêt-brume) | `fog_forest` | `foret` |
| Cité de rouille (3) | `rust_city` | `cite` |
| Cryptes noyées (4) | `crypts` | `cryptes` |
| La Source (5) | `source` | `source` |

| Fichier | Taille | Tuilable | Contenu |
|---|---|---|---|
| `base_0.png` | 1024 × 1024, RGB | oui, 4 bords, raccord exact | sol principal (≈ 55 % de la surface) |
| `base_1.png` | 1024 × 1024, RGB | oui | variante de la même famille, en grandes taches (≈ 45 %) |
| `base_2.png` | 1024 × 1024, RGB | oui | sol humide : plus sombre, plus lisse, petites flaques (bords d'eau) |
| `base_3.png` | 1024 × 1024, RGB | oui | pied des murs : gravats, poussière, mousse, éboulis |
| `decals.png` | 1024 × 1024, RGBA | non (atlas) | 16 décalques, grille 4 × 4 de cellules 256 px |
| `decals_e.png` (facultatif) | 1024 × 1024, RGBA | non | masque d'émission des décalques, même grille (grotte : mycélium) |

Aucun autre fichier. Pas de normal map (décision du 22/10/2026). Les matières de base n'ont pas de `_e`.

### Prise de vue (Blender)

- **Rig TOP** orthographique, vue de dessus stricte (pas la caméra iso) ; 1 u = 1 m ; `ortho_scale` = 8 m
  pour une matière (1024 px = **8 u**, 128 px/u), 2 m par cellule de décalque (256 px = **2 u**).
- Tuilable : plan à matériau procédural en coordonnées raccordables (ou rendu d'un plan 3 × 3 répliqué dont on
  garde la case centrale) ; vérifier en accolant 2 × 2 copies : aucune couture.
- Éclairage plat et neutre venant du haut-gauche, AO douce cuite, cel-shading léger (STYLE_cel.md) ; **pas
  d'ombre portée longue** : la lumière de scène vient du jeu (soleil, PointLight2D, ombres cuites).
- Décalques : fond transparent (alpha droit, non prémultiplié), bords fondus sur 8-16 px, centrés dans leur
  cellule, marge transparente ≥ 16 px.

### Règles de dessin (les plus importantes)

1. **Aucun motif de grille** : pas de dalles alignées en rangées régulières, pas de joints rectilignes
   continus, aucun élément parallèle aux bords de la texture (ils deviennent les diagonales du losange à
   l'écran). Pierre : opus incertum (dalles irrégulières de tailles variées, joints brisés), pavés usés et
   recouverts, ou sol continu (argile, éboulis, terre battue).
2. **Aucun élément unique reconnaissable** (plaque, grille d'égout, cercle, canal, gros cailloux isolés) :
   ils trahiraient la période de 8 u. Ces éléments vont dans les **décalques**.
3. **Contraste local modéré** (pas de tache très claire de plus de 1 u), valeur moyenne proche de la cible
   du biome (tableau §4) : la variation macro (± 16-20 %) est ajoutée par le jeu.
4. Les 4 matières d'un biome partagent palette et éclairage ; leurs détails saillants sont **plus clairs**
   que leur fond (le mélange par hauteur s'en sert pour découper des bords organiques).
5. Lisibilité des télégraphes : aucune fissure émissive plus large que 0,15 u ; les décalques émissifs sont
   de petites touches.

## 4. Cibles par biome

| Biome | Valeur moyenne sRGB (base_0) | Matières | Décalques (16, zones : wet / wall / open / any) |
|---|---|---|---|
| Terrasses | `#4A5B5A` → `#5C6E68` | 0 pierre de rizière usée en opus incertum, 1 limon sec et mousse rase, 2 limon gorgé d'eau, 3 éboulis de muret | flaques, touffes de riz couchées, fissures, galets, mousse, débris de bambou, feuilles |
| Grotte (étage 2) | argile `#4A3A30` (docs/Design_Etage2_Grotte.md §2) | 0 argile et éboulis fins, 1 argile lisse, 2 argile grise humide `#3B3A3C`, 3 calcite et éboulis `#8A7A62` | fissures à mycélium (avec `_e`, `pulse_hz` 0,12), gours, coulées de calcite, flaques d'argile, spores, éboulis |
| Cité de rouille | `#3B3F46` → `#4E4A44` | 0 béton coulé fissuré (pas de dalles carrées), 1 béton taché de rouille, 2 asphalte mouillé, 3 suie et gravats | flaques irisées, coulures de rouille, boulons, plaques tordues, câbles, grilles (petites) |
| Cryptes | `#2E3238` → `#3C3A33` | 0 pierre humide irrégulière, 1 sel et poussière d'os, 2 pierre noyée sombre, 3 éboulis d'ossuaire | os épars, crânes, cristaux éteints, flaques noires, salpêtre, fissures |
| La Source | pierre claire bleutée (Design_Etages §3) | 0 pierre lisse polie par l'eau, 1 calcaire veiné, 2 pierre ruisselante, 3 sédiments | rigoles, éclats de cristal, cercles d'eau (petits), mousse pâle |

`decals.json` n'existe pas : l'ordre des 16 cellules et leurs zones sont déclarés dans
`game/data/maps/ground/biomes.json` (`decals.zones`, 16 valeurs, lecture ligne par ligne) ; Codex indique la
zone de chaque cellule dans son rapport de lot.

## 5. Budget

- Une seule matière de biome chargée à la fois (celle de la carte courante).
- 4 × 1024² en VRAM compressée (ASTC 4×4 / ETC2 ≈ 1 o/px) avec mipmaps ≈ 5,6 Mo + décalques ≈ 1,4 Mo
  (+ 1,4 Mo avec `decals_e`) ≈ **7 à 8,4 Mo par biome** chargé, contre ≈ 0,5 Mo pour les 4 losanges actuels :
  à valider avec l'agent du budget textures (180 Mo). Repli possible sans retouche de code : 512 × 512 pour
  8 u (64 px/u, ≈ 1,9 Mo par biome), en changeant seulement le fichier.
- Import Godot : `compress/mode=2` (VRAM compressée), **`mipmaps/generate=true`** pour les `base_*`
  (le sol est vu à ~0,56 de sa densité : sans mipmaps, scintillement au déplacement).
- Rendu : 1 draw call pour le sol, 1 pour les décalques (+ 1 émission). Coût fragment : 3 à 9 lectures de
  texture selon le palier, sur la surface de sol seulement.

## 6. Provisoire en place (à remplacer sous les mêmes noms)

- `base_0` / `base_1` : rééchantillonnage géométrique des tuiles iso actuelles (`tools/sol_v2_reproject.py`,
  fenêtre calée sur le pas des dalles, sans motif unique ; aucun dessin). Les dalles régulières y restent :
  c'est la limite du provisoire, que seules les nouvelles textures lèvent.
- `base_2` / `base_3` : anciennes textures plates (`ground_mud`, `ground_moss`, `ground_roots`) teintées par
  `tint` dans `biomes.json` (pas de fichier copié). À la livraison : remettre les `tint` à `[1, 1, 1]`.
- Pas de décalques tant que `decals.png` n'est pas livré.
- Quand un biome a ses 4 `base_*`, rien d'autre à changer : `GroundSplat.layer_path()` prend le fichier livré
  avant le repli.
