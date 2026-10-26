# Skins « trophée de Difficile » (décision du joueur, 26/10/2026)

Un skin par personnage jouable, débloqué par **une victoire en mode Difficile avec ce personnage**. Le skin est un trophée visible : il ne change ni les sorts, ni les stats, ni la lecture du gameplay. Données : `art/tools/night/skins.json` (lu par l'agent code pour remplir `game/data/characters.json`). Consignes Codex : `art/tools/night/_skin_<perso>.txt`, lots 47-51 de `art/tools/night/queue.txt`, scripts `art/tools/night/skin_<perso>_build.py`.

## Intention
- **Même silhouette, mêmes animations, même gabarit** : le joueur et les 250 monstres doivent lire le personnage exactement comme avant (IoU alpha > 0,95 contre la planche par défaut, cellule par cellule ; accessoires jamais au-delà de 2 px hors de la silhouette d'origine).
- **Accent émissif conservé** (teinte et zones, IoU accent > 0,90) : c'est la couleur de lecture des sorts et de la lumière du joueur (`LightRig`). Rien d'autre n'émet.
- **Tenue, matière et palette nettement différentes et prestigieuses**, toujours dans la DA (sombre, usée, désaturée, cel 3 tons + encre ; `art/briefs/STYLE.md`, `STYLE_cel.md`, `STYLE_boss_da.md`). Fil rouge du lore : ce que le personnage est devenu après avoir traversé la Source (étage 5) en Difficile : matières refondues, blanchies, vernies, cuites, argentées ; plus de rouille ni de mousse, mais toujours trempé.
- Aucun nom ni visuel repris de Risk of Rain ou de Vampire Survivors.

## Les 10 skins

| Personnage (id) | Skin (id) | Idée | Accent conservé |
|---|---|---|---|
| Ardent (`ardent`) | **Scorie** (`ardent_skin1`) | Robe de cuir vitrifié, plaques d'obsidienne, capuche de fer noir, cendre au bas de la robe | braise #FF8C33 |
| Rictus (`rictus`) | **Gala noir** (`rictus_skin1`) | Pantin relaqué noir, velours prune, dentelle d'argent, porcelaine recollée à l'or ; le sourire reste | argent spectral #9FC8C0 |
| Tocsin (`tocsin`) | **Carillon** (`tocsin_skin1`) | Refondu en bronze de cloche poli, cerclages de cuivre rouge, inscriptions gravées, fer bleui, plus de rouille | orange foyer #FF7A1F |
| Averse (`averse`) | **Céladon** (`averse_skin1`) | Ciré de cuir noir verni, amphore de céladon craquelé cerclée d'argent, même fenêtre d'eau | eau #5FD4E8 |
| Arpenteuse (`arpenteuse`) | **Cadastre** (`arpenteuse_skin1`) | Redingote de laine ardoise à boutons de laiton, trépied poli, touret rechaussé de cuir, insigne de la Cité | cuivre #FF7A1F (sur la chaîne, asset partagé) |
| Rainette (`rainette`) | **Écailles noires** (`rainette_skin1`) | Peau bleu-noir marbrée de gris, écailles de bronze noirci, lance ferrée d'argent | sac vocal #8DBBA8 |
| Avare (`avare`) | **Créancier** (`avare_skin1`) | Velours bordeaux à col de fourrure trempée, coffre-fort de fer bleui à ferrures d'argent | or #F2C14E |
| Bourbe (`bourbe`) | **Grès noir** (`bourbe_skin1`) | Grès cuit vernissé, craquelures claires, bandes de bronze doré, lichen blanc ; mottes inchangées | feu follet #8DDBA8 |
| Vigie (`vigie`) | **Cormoran** (`vigie_skin1`) | Pèlerine de plumes huilées, capote cirée noire, arc de frêne pâle cerclé d'argent, carquois d'argent noirci | rouge de fusée #FF3A4F |
| Taliant (`morfil`) | **Bois flotté** (`morfil_skin1`) | Écorce blanchie, hakama noir, dō de laque noire aux lacets d'or, chapeau de jonc brûlé | fil de sève #CDEB6E |

Noms et descriptions d'une phrase : `art/tools/night/skins.json` (`name`, `desc`, `unlock_text`).

## Contrat de sortie (assets)
- Dossier : `game/assets/sprites/characters/<perso>/skins/<perso>_skin1/`.
- **Exactement les mêmes fichiers que le dossier par défaut** `game/assets/sprites/characters/<perso>/` (celui référencé par `sprite_frames` dans `characters.json` ; les dossiers `ardent_cel`, `averse_cel`, `vigie_cel` sont des restes, pas des références) : mêmes noms, mêmes tailles de planche, mêmes grilles, mêmes nombres de frames, même ordre des directions (e, se, s, sw, w, nw, n, ne), mêmes pivots ; masques `_e` à demi-résolution avec les mêmes zones ; aucun `_n` ; `portrait.png` 256×256 (plus `portrait_e.png` 128×128 là où le défaut en a un). Pour Rictus et Taliant, le portrait par défaut vit dans `ui/portraits/<id>.png` : le skin livre le sien dans son dossier.
- `<perso>_skin1.tres` : copie du SpriteFrames par défaut avec les chemins substitués (mêmes animations, régions, cadences, boucles).
- Effets, projectiles, VFX, variantes de sorts et invocations (Montreur, mottes, chaîne, flèches) restent partagés : rien dans `effects/`, `variants/` ni les sous-dossiers de VFX.
- **Tocsin** (rendu modulaire, `FORMAT_T5.md`) : en plus des planches de corps, les membres détachés (`arm_clamp`, `arm_fly`, `arm_ground`, `leg_fly`, `leg_ground`, `head_fly`), `portrait_headless.png`, `layers_order.json`, `atlas_manifest.json`, `layers/<calque>/packed/` (jamais les planches intermédiaires non rognées) et les `.tres` de modules et de membres avec les nouveaux chemins. `head_blast*`, `regen_rivets`, `head_ring`, `rivet` restent partagés.
- Procédé : copie du `.blend` du héros dans `art/blender/cel/skins/`, seuls les matériaux et accessoires de surface changent ; même rig, mêmes poses, même caméra `iso_rig`, rendu cel `cel.install('creature', normals=False)`, graine fixe, script relançable.

## Contrat de branchement (agent code, hors de ce document)
- `characters.json` : par personnage, une liste `skins` à partir de `skins.json` (`id`, `name`, `desc`, `unlock_text`, `unlock_key` = `skin:<id>`, `unlock_rule` = `{"type": "win_with", "character": <id>, "mode": "difficile"}`, `sprite_frames`, `portrait`). Le mode Difficile existe déjà (`profile.gd`, `UNLOCK_ON_VICTORY`) ; `record_run_result` reçoit `mode` et `character` : il suffit d'y ajouter la règle.
- Chargement : `CharacterData.sprite_frames_path` pointe sur le `.tres` du skin choisi ; portrait du HUD et des menus : chemin du skin avant `ui/portraits/<id>.png` puis `characters/<id>/portrait.png`.
- Tocsin : `TocsinLayers.attach(_visual, dir)` reçoit le dossier du skin au lieu de `ASSET_DIR` (`tocsin_kit.gd`) ; les membres détachés et `tocsin_parts` suivent le même dossier.
- Choix du skin : écran de sélection du personnage (un bouton « Tenue » par défaut / trophée), mémorisé dans le profil (`last_skin` par personnage). Un skin verrouillé reste visible, grisé, avec son `unlock_text`.

## Budget (estimation avant production)
Mesure `python art/tools/texture_budget.py` du 26/10/2026 : textures mobiles **219 Mo pour 180 Mo** (cible 95 Mo), catégorie `bosses` à 104 Mo pour 45. Chaque skin duplique les planches de corps de son personnage. Estimation (ratio mobile/raw mesuré par catégorie, `_e` demi-résolution comprises) :

| Skin | PNG ajoutés | PNG (Mo) | Mobile estimé (Mo) |
|---|---|---|---|
| ardent_skin1 | 12 | 5,2 | 2,7 |
| rictus_skin1 | 20 | 4,6 | 2,2 |
| tocsin_skin1 | ≈ 202 (dont 149 packed) | 24,9 | 8,2 |
| averse_skin1 | 19 | 6,4 | 1,2 |
| arpenteuse_skin1 | 10 | 4,1 | 2,4 |
| rainette_skin1 | 30 | 6,0 | 2,8 |
| avare_skin1 | 21 | 6,0 | 3,4 |
| bourbe_skin1 | 24 | 8,2 | 4,1 |
| vigie_skin1 | 20 | 4,6 | 2,3 |
| morfil_skin1 | 30 | 16,6 | 6,8 |
| **Total** | ≈ 388 | **86,6** | **≈ 36** |

Conséquence : +36 Mo mobile sur un budget déjà dépassé de 39 Mo. Chaque consigne demande à Codex de rapporter la taille réellement ajoutée. Options pour l'orchestrateur, par ordre de préférence :
1. **Produire les skins après le palier 2** (re-rendus à la taille d'affichage, `art/tools/night/ANDROID.md`) : les dossiers par défaut rétrécis rétrécissent les skins d'autant (le contrat « mêmes tailles » suit le défaut du moment).
2. **Pack optionnel sur mobile** : skins dans un `.pck` séparé (asset pack Play / ressource à la demande iOS), chargé par `ProjectSettings.load_resource_pack` ; PC les embarque. Contrat code à prévoir si retenu.
3. Sinon, restreindre la v1 aux cinq skins les moins chers (Averse, Rictus, Vigie, Arpenteuse, Ardent : ≈ 11 Mo).

Les lots de la file restent exécutables tels quels : la décision de budget se prend avant de lancer les groupes 47-51.
