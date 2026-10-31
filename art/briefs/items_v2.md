# Icônes d'items v2 (DA sérieuse, cel)

Remplace les icônes « jouet » de `game/assets/sprites/icons/items/<id>.png` (256x256 RGBA, mêmes noms). Joueur : « très low quali, trop enfantines ».

## Contrat
- 256x256 RGBA, fond transparent, objet centré, marge >= 12 px, silhouette lisible à 48 px (grosses masses, peu de détails fins), PNG optimisé (<= ~45 Ko).
- Pas de texte, pas de cadre (le cadre de rareté est séparé, `frame_<rareté>.png`).
- Caméra ortho 3/4 de face, élévation ~25-30°, objet debout/penché de façon lisible. Soleil chaud #FFC287 haut-gauche (énergie ~2,5, angle faible), fill froid #80A8D9 faible à droite.
- Rendu cel : `art/tools/cel/cel_style.py`, profil `icon` (3 tons par matière, encre brun-noir ~1 px à la taille finale, aucun `_n`). Rendre à 2x (512) puis LANCZOS -> 256.

## DA
- Matières usées et sombres : fer noir #2B2A29, rouille #6B3A22, bronze vert-de-gris #5F8F80, laiton #A8946E, cuir brun, bois sombre, os, pierre. Palette désaturée, valeurs basses, contraste local fort.
- UN seul accent émissif par icône, en petites touches (la couleur de l'effet de l'item : braise #FF7A1F feu, cyan #5FD4E8 givre/foudre/temps, vert #7FA35B poison, or #F2C14E, violet #8A6AB0 arcane, rouge sang).
- Silhouettes crédibles, anguleuses, asymétries, usure (biseaux, rivets, sangles, fissures). Interdit : pastel, formes bulbeuses, gros yeux ronds, brillances de jouet.
- Beaucoup de petites pièces seulement si elles survivent à 48 px.

## Objets (changements de concept)
- eclair_en_bouteille -> « Ukulele » : un ukulélé (corps en huit, manche, cordes, tête à clés) en bois sombre usé, fissures lumineuses cyan électrique (accent), un arc de foudre court sur les cordes.
- de_pipe -> « Trèfle à 5 feuilles » : trèfle vert sombre à 5 feuilles (cinq lobes en cœur, nervures), tige courte ; accent or (nervures/rosée dorée). Pas de dé, pas de pièce.
- moisson -> « Faux » : une vraie faux (long manche de bois courbe avec poignées, grande lame courbe d'acier noirci et ébréchée, collier de fixation), pas de faucille, pas de blé ; accent rouge braise discret sur le fil de la lame.
- Autres : voir `art/briefs/ui_icons.md` (liste id : objet), à rendre en version sérieuse.

## Pipeline
`art/tools/ui/items_v2/iv2_lib.py` (scène, primitives importées de `art/tools/ui/ui_lib.py`, matières PBR -> `cel.toon_materials('icon')`, rendu 512 -> 256 optimisé), `lot_<x>.py` (builders par id, `-- id id` pour un sous-ensemble). .blend dans `art/blender/items_v2/`, rendus bruts `art/renders/items_v2/raw/`, livraison directe vers `game/assets/sprites/icons/items/<id>.png`, avant sauvegardé dans `art/renders/items_v2/before/<id>.png`.
