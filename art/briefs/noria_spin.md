# Noria animée (lot props B, suite)

Besoin : `game/assets/sprites/props/terraces/noria_spin.tres` (SpriteFrames, animation `spin`, boucle, 8 images, 8 fps)
jouée par `fx_prop_anim.gd` pendant l'événement « La noria repart » des Rizières hautes. Elle remplace le sprite
statique `noria.png` : chaque image est donc la noria complète (piles, roue, filets d'eau), seule la roue tourne.

Cadrage identique à `noria.png` : canvas 416x432, pied (208,344), rig MAP (90,51 px/u), éclairage haut-gauche, DA cel
sombre (`cel.install('prop', normals=False)`). Partir de la géométrie de `art/tools/props/b4_build.py` (branche noria).
Roue : 12 rayons, 16 godets, donc symétrie de rotation de 90 degrés. Les 8 images tournent la roue de 0, 11,25, ...,
78,75 degrés autour de l'axe (0, y, 1,92) ; l'image 0 est identique à `noria.png` ; le pas suivant la dernière image (90
degrés) retombe exactement sur l'image 0, boucle parfaite. Sens : les godets du côté du filet d'eau descendent.
Piles, chapeaux de pierre, mousse, poutre de vanne et filets d'eau restent fixes. Ombre `noria_shadow.png` inchangée.
Poids : PNG optimisés, lot <= 600 Ko (palette quantifiée si besoin, sans dégrader le cel).
