# Rainfall - Rendu CEL de référence (décision du joueur, 22/10/2026)

> « Le rendu cel-shadé est top, on va partir là-dessus pour tout le reste des assets. »

Toute production visuelle (nouveaux assets ET re-rendus de l'existant) suit cette fiche. Elle **remplace la partie « shading »** de STYLE.md / STYLE_boss_da.md : les modèles, matières (comme source des teintes), silhouettes anguleuses, palette sombre désaturée, accent émissif unique, caméra iso, tailles et contrats de fichiers de ces fiches restent valables. Ce qui change : le grain PBR et les dégradés deviennent des **aplats encrés**.

> **PLUS DE NORMAL MAPS (décision du joueur, 22/10/2026, budget mobile 180 Mo)** : aucun `<f>_n.png` n'est produit, livré ni référencé (.tres). Le jeu éclaire les sprites à plat (Light2D sans normales) ; le volume vient des 3 tons et de l'encre. Les anciens `_n` sont archivés dans `art/archive_normals/` (hors projet). Les masques d'émission `_e` restent. `cel.install(profil, normals=False)` (la passe Normal de Blender reste calculée pour les plis d'encre, mais aucun fichier `_n` n'est écrit) ; pas de `cel.quantize_normal_files`. `texture_budget.py` et `texture_budget_test` échouent si un `_n` est posé à côté d'un diffus.

- Lot de référence : **CS1** (consigne `art/tools/night/_cs1.txt`, rapport `_logcs1.txt.last.txt`, script `art/tools/night/cs1_build.py`, réglages mesurés `_cs1_render.json`, contrôles `_cs1_verification.json`).
- Référence visuelle : `art/tools/night/_cs1_contact.png`, **moitié droite** (Ardent, swarm_tier1, brute_tier3 sur le sol réel des terrasses).
- **Module partagé obligatoire : `art/tools/cel/cel_style.py`** (factorisé de cs1_build.py, testé). Aucun lot ne recopie les réglages : il importe le module et choisit un profil. Les nombres ci-dessous en sont la documentation.

Esprit : « illustration encrée sombre » (Darkest Dungeon, Hades en plus sobre), jamais Saturday-morning ni pastel. Lisible par la silhouette, la valeur et l'encre, pas par la saturation.

## 1. Tons (rampes)
- Chaque matière non lumineuse devient : diffus gris (albédo 0,72, rugosité 0) -> **Shader to RGB** -> **ColorRamp CONSTANT** -> Emission. La lumière de la scène d'origine (soleil chaud haut-gauche + fill froid, STYLE.md) décide du ton ; rien n'est peint.
- **3 tons par matière** (créatures, boss, props, tuiles, icônes) : ombre / moyen / lumière = base × **0,63 / 1,12 / 1,65**, paliers aux positions **0 / 0,34 / 0,70** de la rampe. **2 tons** (UI, VFX à corps) : 0,63 / 1,65, paliers 0 / 0,34.
- Couleur de base = Base Color de la matière d'origine ; si la matière a une rampe procédurale, base = **30 % du ton sombre + 70 % du ton clair** de cette rampe. Le bruit/grain procédural est abandonné, la teinte jamais.
- **Plancher d'ombre (lisibilité de nuit)** : luminance linéaire de la base relevée à **≥ 0,040** (facteur multiplicatif, teinte conservée), chaque canal plafonné à **0,72**. On **éclaircit les ombres au lieu de noircir** : jamais un corps presque noir sur le sol nocturne.
- Matières de creux (intérieur de bouche, fentes) : gardent leur base sombre relevée au plancher, elles restent « en retrait ».
- Tuiles et grands sols (profil `tile`) : une surface unie en 3 tons serait vide. Les motifs (dalles, joints, fissures, racines, flaques) doivent être de la **géométrie ou des matières distinctes** ; si la matière d'origine est un bruit procédural, le baker en texture image (le module garde alors texture × ton quantifié, `keep_texture`) ou postériser le bruit en 2-3 valeurs. Raccords de tuiles identiques à l'original.

## 2. Encre (contour)
Encre **brun-noir** linéaire (0,009 ; 0,006 ; 0,005) ≈ **#181210**, jamais noir pur ni couleur.
- **Silhouette** : trait intérieur au compositeur (masque alpha érodé vers l'intérieur), pour garder EXACTEMENT la silhouette, l'alpha et le pivot d'origine (IoU > 0,97). Épaisseur **à la taille d'affichage** :

| profil | usage | silhouette (px finaux) | plis intérieurs |
|---|---|---|---|
| `creature` | personnages, monstres, mini-boss, invocations, portraits (cellules 96-256) | **1,5** (érosion 3 px au rendu 2x) | oui |
| `boss` | boss d'étage et final (cellule 256 et plus) | **2** | oui |
| `prop` | props, piliers, coffres, pickups, capsule, projectiles à corps | **1,5** | oui |
| `tile` | tuiles iso (sols, blocs, falaises, eau, vide) | **0** (les tuiles se raccordent : l'encre dessinerait la grille) | oui (sans toucher les bords) |
| `icon` | icônes d'items et de sorts, dés, pictos HUD (≤ 256) | **1** | oui |
| `ui` | cadres, panneaux 9-slice, jauges, barres de PV, police DF1 | **1** (la police garde son liseré de 2 px du brief, à la couleur d'encre) | non |
| `vfx` | VFX et textures d'ambiance | **0** | non |

Aucun profil ne livre de `_n` (22/10/2026).

- **Plis intérieurs** : Sobel des normales lisses de la géométrie (pas des textures : aucune moucheture), seuil **0,72**, opacité **0,70**, ~1 px au rendu 2x (≈ 0,5-1 px final) : plus fins et plus légers que la silhouette.
- **Line Art / Freestyle** : interdits pour les sprites contractuels (ils débordent de la silhouette, changent l'alpha, le pivot et le rognage, et coûtent cher). Tolérés seulement pour un élément d'UI sans contrat de silhouette, en le notant au rapport.

## 3. Normales : SUPPRIMÉES (décision du joueur, 22/10/2026)
- **Aucune normal map** : ni passe `_n` livrée, ni conversion en espace écran, ni quantification. `cel.install(profil, normals=False)` retire la sortie fichier `_n` du compositeur ; la passe Normal de Blender reste activée car l'encre des plis (Sobel) la lit.
- Si un script de rendu d'origine produit encore des `_n` (assemblage, découpe d'atlas, .tres avec `normal_texture`) : ne les copie pas dans `game/` (dossier de travail `art/blender/cel/` seulement) et garde les `.tres` actuels, qui ne référencent plus aucun `_n` (diffus en `ExtResource` direct dans l'AtlasTexture, sans CanvasTexture).
- En jeu : éclairage 2D plat (Light2D, CanvasModulate, ombres cuites) ; le volume est porté par les 3 tons et l'encre, l'accent par `_e`.
- Ancien réglage (archivé) : `_n` quantifiés à 26 directions, voir `art/archive_normals/` et l'historique du lot CS1.

## 4. Émissif
- Matières lumineuses (propriété `rainfall_emissive`, ou émission > 0,01 sans rampe procédurale) : **pas de rampe**, émission continue conservée (le glow HDR du jeu s'en charge).
- `_e` = AOV `CEL_Accent` (couleur × force d'émission de la matière), alpha du diffus : **mêmes zones d'accent que l'original** (IoU > 0,97). Un seul accent par créature/objet (STYLE.md).
- Grille de fichiers identique à l'original, sauf les `_e` : **pas de `_e` noir ou vide** (max alpha × luminance <= 2/255 ; les 73 existants ont été supprimés le 22/10/2026, le jeu n'ajoute rien sans `_e`) ; un `_e` noir relivré est supprimé au passage suivant de `art/tools/halve_emission.py --black --apply`.
- **`_e` livré à demi-résolution** (budget mobile, 22/10/2026) : le jeu accepte un `_e` pleine taille (= diffus) ou à demi-résolution ((w+1)//2 × (h+1)//2) et déduit le rapport des tailles (`NormalMaps.emission_ratio`), régions d'atlas et `.tres` restant en coordonnées du diffus. Livrer pleine taille est toléré : `python art/tools/halve_emission.py --apply` (filtre peak, alpha conservé) les réduit au passage suivant. Toute autre taille fait échouer `texture_budget_test`. `cel.check_sheet` ne compare l'alpha `_e`/diffus qu'en pleine taille.

## 5. Palette et lisibilité de nuit
- Teintes = matières de STYLE.md (rouille #6B3A22, fer noir #2B2A29, vert-de-gris #5F8F80, laiton #A8946E, cuir, os, pierre…) désaturées ; aucune saturation ajoutée. Seuls les accents émissifs et les projectiles du joueur sont vifs.
- Contrôle obligatoire sur **le vrai sol sombre du jeu** (`game/assets/sprites/terrain/terraces/iso/ground_a.png`, ou le sol du biome) : le corps se détache par sa valeur claire et son encre ; ton d'ombre jamais confondu avec le sol.

## 6. Réglages de rendu
Eevee **8 échantillons**, view transform **Standard**, film transparent, dither 0, PNG RGBA 8 bits ; rendu à **2x puis LANCZOS** (iso_rig.render_frame), passes Normal (plis d'encre seulement, aucun fichier `_n`) + Emit + AOV `CEL_Accent`. Caméra, `iso_frame`, ortho_scale, shift, directions (`e, se, s, sw, w, nw, n, ne`), frames et pivots : **ceux du script d'origine, inchangés**.

## 7. Utilisation du module (tout lot visuel)
```python
import sys; from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(ROOT / 'art/tools/cel'), str(ROOT / 'art/tools/iso')]
import cel_style as cel
# 1) python système, AVANT toute écriture dans un dossier existant :
cel.archive_folder('monsters/swarm_tier1')          # -> art/archive_3d/sprites/monsters/swarm_tier1 (une fois)
# 2) Blender --background (après open_mainfile ou construction de la scène, avant les rendus) :
import iso_rig; cel.install('creature', normals=False)   # patch boss_common.configure_passes : toon + encre + _e (aucun _n)
#    ... code de rendu d'ORIGINE inchangé (iso_rig.render_frame, render_still, render_animation, assemblage sans _n) ...
# 3) python système : contrôles et planche
cel.check_sheet('monsters/swarm_tier1/run.png', cell=96, frames=8, rows=8, normals=False)
cel.contact_pair([[('monsters/swarm_tier1/run.png', 96, 0, 2)]], ROOT / 'art/tools/night/_cel_xxx_contact.png')
```
- Ne jamais ouvrir-modifier-enregistrer un .blend d'origine : copie dans `art/blender/cel/` si besoin de sauver.
- Scripts dont le rendu ne passe pas par `boss_common.configure_passes` : appeler `cel.setup_scene()`, `cel.toon_materials(profil)` puis `cel.cel_passes(path, profil, normals=False)` avant chaque rendu.
- Python/PIL seulement pour assembler, rogner et vérifier ; aucun shading en PIL.

## 8. Contrat de sortie des re-rendus (lots `_cel_<famille>`)
- **Écriture DIRECTE dans les dossiers d'origine** (`game/assets/sprites/<cat>/<nom>/`) : mêmes noms, tailles de planche, grilles, nombres de frames, ordre des directions, pivots, découpage d'atlas ; `.tres`, `.json`, `.import` inchangés (ils ne référencent plus de `_n`). Diffus + `_e` (+ `_shadow`) seulement : **aucun `_n`**. Aucune planche > 4096 px.
- **Archive 3D** : avant d'écraser, `cel.archive_folder(<rel>)` copie une fois l'existant dans `art/archive_3d/sprites/<rel>` (hors projet Godot : jamais importé ni exporté ; référence des contrôles et retour arrière). On n'écrit jamais dans une archive existante.
- Sujets déjà rendus par CS1 (`characters/ardent_cel`, `monsters/swarm_tier1_cel`, `monsters/brute_tier3_cel`) : copier ces planches (diffus et `_e`, jamais de `_n`) dans le dossier d'origine (après archive) et ne rendre que ce qui leur manque.
- Contrôles : `cel.check_sheet(..., normals=False)` sur chaque planche (aucun `X_n.png` ; taille, alpha X/X_e, silhouette et accent IoU > 0,97 contre l'archive, cellules non vides et non dupliquées), planche `art/tools/night/_cel_<famille>_contact.png` (archive à gauche, cel à droite, sol réel), `python art/tools/texture_budget.py --apply-policy`, `godot --headless --path game --import` sans erreur, `res://tests/sprites_test.tscn` et `res://tests/texture_budget_test.tscn` -> RESULT: OK.
