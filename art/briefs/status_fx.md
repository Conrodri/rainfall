# Rainfall - Brief : particules d'état sur les monstres (lot STATUS_FX)

Demande du joueur (08/11/2026) : voir sur les monstres les états qui les touchent. Le système Godot est écrit
(`game/scripts/enemies/status_fx.gd`, docs/Design_Etats_Visuels.md) ; il tourne aujourd'hui sur des textures de
repli existantes. Ce lot les remplace par des particules dédiées, rendues dans Blender par Codex.

## Règles communes
- Tout est modélisé et rendu dans Blender (`--background`), DA officielle « sérieuse » cel-shadée (STYLE.md en tête,
  STYLE_cel.md) : 2-3 aplats de valeur, contour sombre fin là où la particule n'est pas additive, palette sombre
  désaturée, un seul accent lumineux. Aucun dessin PIL, aucune texture téléchargée. PIL seulement pour réduire et rogner.
- Sortie : `game/assets/sprites/vfx/status/<nom>_NN.png` (NN = 01, 02…), PNG RGBA, fond transparent, marge transparente
  >= 2 px, rendu à 2x puis réduit (LANCZOS). Pas de masque `_e`, pas de normal map. PNG optimisés (budget mobile).
- Le jeu charge automatiquement `<nom>_01..04.png` dès qu'ils existent (sinon il garde le repli) : respecter les noms.
- Pivot = centre de l'image. Le jeu met à l'échelle (0,25 à 1,5 selon la sorte et la taille du monstre) ; dessiner la
  forme pour qu'elle se lise à la taille AFFICHÉE indiquée, sur un monstre de 1 u (64 px) vu sur un téléphone de 6 pouces.
- Lisibilité daltonisme : chaque état se reconnaît à sa FORME, pas seulement à sa couleur (rond / flamme pointue +
  paillette / goutte / zigzag / étoile). Ne pas faire converger les silhouettes.
- Additif = prévu pour un mélange ADD dans Godot : RGB vif sur noir, alpha = intensité, aucun halo sombre.
  Non additif = alpha réel, couleurs déjà justes (le jeu module peu).

## Fichiers

| Fichier | Taille | Variantes | Mélange | Affiché | Forme exacte |
|---|---|---|---|---|---|
| `poison_bubble_NN.png` | 32x32 | 4 | normal | 14-22 px | Bulle RONDE de poison : sphère translucide vert sombre (#3E8F3A au cœur, 50-70 % d'opacité), anneau de bord plus clair (#7FD65A), un reflet spéculaire net en haut à gauche, contour sombre fin. Variantes : tailles du reflet, une avec une micro-bulle accolée, une légèrement ovale (tension de surface), une plus opaque. Doit se lire « bulle » et pas « boule lumineuse ». |
| `burn_flame_NN.png` | 32x48 | 4 | additif | 18-30 px de haut | Flammèche POINTUE qui lèche le corps, pointe vers le HAUT, base arrondie au tiers bas : cœur #FFE9A8, corps #FFB347 -> #FF7A1F, pointe #C23B12 qui s'éteint. Variantes : droite, penchée gauche, penchée droite, double pointe. |
| `burn_ember_NN.png` | 16x16 | 2 | additif | 4-7 px | Braise : point orange-jaune (#FFB347, cœur #FFE9A8) avec halo court. Une variante légèrement étirée (trace de mouvement verticale). |
| `burn_ash_NN.png` | 24x24 | 4 | normal | 16-30 px | Paillette de cendre : flocon plat irrégulier gris anthracite (#3A3634 -> #5A5450), bords déchiquetés, une face un peu plus claire (cel-shading 2 tons) ; sur 2 variantes un liseré rougeoyant fin (#C23B12) sur un bord. Le jeu la fait tournoyer. |
| `wet_drip_NN.png` | 16x32 | 4 | normal | 14-19 px de haut | GOUTTE qui tombe : bas arrondi, pointe vers le HAUT (forme de larme), eau claire bleutée (#CFE8FF au reflet, #6F8FA8 dans l'ombre), reflet blanc en haut à gauche, contour sombre fin (lisible sur sol clair ET sombre). Variantes : plus fine, plus ronde, petite traînée, goutte double. |
| `shock_arc_NN.png` | 64x64 | 4 | additif | 30-45 px | Arc électrique bref en ZIGZAG anguleux, 2-3 branches courtes, cœur blanc #FFFFFF, halo #7AB8FF puis #CFE8FF ; aucune boule aux extrémités (les arcs sont posés sur le corps, pas tendus entre deux points). Variantes : arc horizontal, diagonal, en fourche, en « Y ». |
| `stun_star_NN.png` | 32x32 | 2 | additif | 14-18 px | Étoile d'étourdissement à 4 branches fines (#FFE9A8, cœur blanc, halo jaune pâle). Une variante à 5 branches. Le jeu en fait tourner 3 au-dessus de la tête. |

## Replis actuels (à remplacer, mêmes usages)
- poison_bubble -> `vfx/particles/poison_bubble_01..04.png` (convient déjà : rond, vert) ;
- burn_flame -> `vfx/particles/fire_drop_01..04.png` ; burn_ember -> `vfx/particles/ember_01, ember_03.png` ;
- burn_ash -> `ambiance/ash_16.png, ash_16_2.png` (trop petites et beiges) ;
- wet_drip -> `ambiance/drop_32.png, drop_32_2.png, drop_32_4.png` (gouttes de pluie, un peu grosses et grises) ;
- shock_arc -> `vfx/particles/arc_fragment_01..04.png` (boules aux extrémités : à éviter) ;
- stun_star -> `vfx/particles/ember_01, ember_03.png` (simples lueurs rondes : pas lisible comme « étourdi »).

## Hors lot (rien à produire)
- La teinte « vêtements mouillés » des monstres trempés est une modulation de couleur du sprite en code (système).
- Les pictogrammes d'état des barres de PV existent déjà (`assets/sprites/ui/`).
