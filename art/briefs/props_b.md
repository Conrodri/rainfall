# Props propres aux variantes B (11 assets, 4 lots)

> Décision du joueur (06/11/2026) : props fixes des variantes B produits avant la sortie. Le placement (JSON de carte) est fait par un autre agent ; ce brief ne touche ni `props.json` ni le code. Style : `STYLE.md` (DA sérieuse, cel, ombres cuites), `STYLE_cel.md`, profil cel `prop`, aucun `_n`. Gabarit de build : `art/tools/props/g_g4_build.py` (rig MAP, R = 90,51 px/u, ombre `_shadow` rig TOP 512 x 512 alpha <= 0,6, courte x0,6 en grotte seulement).

## Contrat de noms (ne pas changer)

Fichiers `game/assets/sprites/props/<dossier>/<nom>.png` + `<nom>_shadow.png` (+ `<nom>_e.png` si accent émissif, demi-résolution `(w+1)//2 x (h+1)//2`). 1 case = 2 u. Empreinte donnée en cases (x par y, x = axe bas-droite de l'écran). **Une seule orientation par prop** (grand axe le long de +x, soit la diagonale vers le bas-droite de l'écran), jamais de miroir.

| Dossier | Nom | Empreinte | Hauteur | Description | `_e` |
|---|---|---|---|---|---|
| rust_city | `crucible` | 2 x 2 cases (4 x 4 u, objet ~3 u de diamètre) | ~2,6 u | creuset de fonderie : cuve de fer noir riveté sur piétement de fonte, bec de coulée, métal en fusion visible à l'ouverture | oui (métal orange `#FF7A1F`, cœur `#FFB347`) |
| rust_city | `rails` | 1 x 2 cases (2 x 4 u) | ~0,15 u (au sol) | tronçon de 2 rails de fer rouillé sur traverses de bois sombre, gravier | non |
| rust_city | `minecart` | 1 x 1 case (2 x 2 u) | ~1,2 u | wagonnet de mine en tôle rouillée rivetée, posé sur un court tronçon de rails (axe +x), chargé de ferraille | non |
| crypts | `well_rim` | 2 x 2 cases (4 x 4 u) | ~0,6 u | margelle octogonale de pierre usée autour d'un puits de lumière ; eau noire et lueur froide au centre ; mousse/suintements | oui (lueur froide d'eau/cristal, couleur du biome) |
| crypts | `crypt_stairs` | 1 x 2 cases (2 x 4 u) | 1,2 u au haut | escalier de pierre usée de 4-5 marches, montée vers le haut-gauche de l'écran, contremarches visibles (bas-droite) | non |
| fog_forest | `pontoon` | 1 x 2 cases (2 x 4 u) | ~0,5 u | ponton de planches de bois sombre gorgées d'eau sur pilotis, corde, quelques planches manquantes | non |
| fog_forest | `firefly_cage` | 1 x 1 case (2 x 2 u, objet ~1 u) | ~1,8 u | cage de fer fin sur un piquet court, lucioles/spores qui luisent, une lanterne-cage | oui (mycélium `#C27BFF`, cœur `#E6C8FF`) |
| fog_forest | `fallen_altar` | 2 x 1 cases (4 x 2 u) | ~1,1 u | autel de grès grossièrement équarri, effondré en deux blocs et une dalle cassée, éboulis, racines | non |
| terraces | `noria` | 2 x 2 cases (4 x 4 u) | ~3,6 u | roue à aubes en bois sombre usé, cerclée de fer, sur deux piles de pierre moussue, godets, filet d'eau | non |
| terraces | `scarecrow` | 1 x 1 case (2 x 2 u, objet ~1 u) | ~2,2 u | épouvantail de rizière : croix de bambou/bois, paille et tissu usé, chapeau conique abîmé, en berne | non |
| terraces | `stone_stairs` | 1 x 2 cases (2 x 4 u) | 1,2 u au haut | escalier de pierre moussue de rizière, montée vers le haut-gauche, contremarches visibles | non |

## Palettes (celles des biomes ; une seule touche émissive par prop)

- Fonderie (rust_city) : rouille `#6B3A22`/`#3E2419`, fer noir `#2B2A29`, béton mouillé ; accent orange braise.
- Ossuaire (crypts) : pierre taillée usée gris-bleu sombre, sel, os ; accent cristal/eau froide du biome (reprendre la teinte de `crystal_lantern_e.png`).
- Mangrove (fog_forest, = Gouffre luisant) : grès `#5A4232`, schiste `#3A3634`, racines `#2A2420`, bois sombre `#44352B` ; accent mycélium `#C27BFF`.
- Rizières (terraces) : sol `#4A5B5A`, pierre moussue `#2F3A3C` liseré `#8AA09A`, bronze `#8C7A4C`, bois/bambou sombre ; pas d'accent émissif.

## Échelle et ancrage

- Rig MAP, canvas multiple de 8, marges >= 6 px, tout le sprite dans le canvas. `foot` = pixel du centre de l'empreinte au sol (origine du modèle) ; il est assert dans le build comme `g_g4_build.py` et rapporté ci-dessous.
- Même échelle que les props du dossier (`px_per_u` 90,51) : rails/escaliers/pontons plats ne dépassent pas leur empreinte au sol.
- Lisibles sur le sol du biome ; plus sombres que jouet ; pas de saturation hors accent.

## Résultats livrés

(rempli après chaque lot)
