# DA des boss (référence : boss d'étage cerf, sonneur, éclusier — validés par le joueur)

> **22/10/2026 : rendu CEL obligatoire (art/briefs/STYLE_cel.md, module art/tools/cel/cel_style.py).** Les matières, silhouettes, palette et accent ci-dessous restent la référence ; « shaders procéduraux multi-couches, pas d'aplats » est remplacé par 3 aplats encrés par matière.
Le joueur adore la DA des 3 boss d'étage et trouve les mini-boss et les monstres « enfantins ». DÉCISION : cette DA s'applique à TOUS les assets du jeu (créatures, personnages, terrains, props, VFX, UI), avec des jeux de lumière profonds et marqués.

Références à regarder (première frame de chaque) : game/assets/sprites/bosses/etage/{cerf,sonneur,eclusier}/idle_p1.png ; conventions dans etage/cerf/lighting.md.

## Ce qui fait la DA des boss d'étage
- Matières crédibles et usées : métal patiné (vert-de-gris, bronze, cuivre oxydé), fer rouillé, cuir, pierre taillée, bois sombre, os ; rugosité variée, micro-détails (rivets, sangles, cannelures, rayures, coulures). Shaders procéduraux multi-couches (bruit + saleté dans les creux + usure sur les arêtes), pas d'aplats.
- Palette sombre et désaturée, valeurs moyennes à basses ; une seule couleur d'accent émissive par créature, en petites touches (yeux, braises, lanternes, fissures). Jamais de pastel, jamais de couleurs bonbon.
- Proportions crédibles et menaçantes : silhouette anguleuse, asymétries, éléments qui débordent (cornes, armes, chaînes, lambeaux) ; pas de têtes énormes, pas de formes en bulles/blocs arrondis, pas d'yeux ronds « kawaii ».
- Volumes construits (modélisation détaillée, biseaux, subdivision où il faut), pas de primitives brutes juxtaposées.
- Lumière STYLE.md (soleil chaud haut-gauche + fill froid), ombres internes marquées (AO), contraste local fort mais global sombre.

## Ce qu'il faut bannir (constaté sur les mini-boss actuels)
Couleurs pastel (bleu ciel, rose saumon, jaune citron), formes boudinées, bulles, cubes empilés, gros yeux ronds, contours propres « jouet », surfaces lisses uniformes.
