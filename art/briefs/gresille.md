# Grésille, paratonnerrière : planche de chara design (3 silhouettes)

Statut : concept à valider par le joueur AVANT toute animation. Aucun asset de jeu, aucune intégration.
Sources : docs/fiches/gresille.md (§2 apparence, §13 questions ouvertes), docs/Lore.md, art/briefs/STYLE.md, STYLE_boss_da.md, STYLE_cel.md, docs/Design_Isometrique.md.

## Contraintes communes
- Femme compacte, 1,35 u, carrée d'épaules, ouvrière des hauteurs ; DA sérieuse (PBR usé, palette sombre désaturée, mat et mouillé, UN seul accent émissif électrique). Jamais cartoon.
- Pièces de la fiche : deux bouteilles de Leyde (verre fumé cerclé de cuivre) sur râtelier de bois ciré dans le dos, câbles gainés vers les gants ; tige de paratonnerre bronze vert-de-gris avec isolateurs de verre ; cape-treillis de mailles de cuivre ; bottes de gutta-percha ; ceinture d'outils ; chignon à épingles de cuivre.
- Palette de base : vert-de-gris #4F6B5E, cuir noir #1F2124, verre fumé #3B4A5C, laine #5A5E66, toile #4A3F33, peau #B89E86.
- Rendu : cel-shadé (STYLE_cel.md), caméra iso du jeu (ortho, élévation 30°, lacet, rig CREA art/tools/iso/iso_rig.py, R = 90,51 px/u, direction se), lumière haut-gauche, fond transparent pour les sprites de planche.

## Les 3 silhouettes (variations d'accessoire/silhouette)
- A « Mât » : la tige de paratonnerre longue (~1,1 u) en bâton tenu main droite, 3 isolateurs empilés ; bouteilles de Leyde dos, silhouette verticale. Accent lilas arc #B9A6FF, cœur #F2EEFF.
- B « Bobines » : pas de grande tige ; deux grosses bobines de cuivre aux avant-bras/gants (gantelets-bobines) reliées par câbles aux bouteilles dorsales plus larges ; silhouette large aux épaules. Accent bleu-blanc arc #D8EEFF (cœur blanc), variante alternative à la question ouverte du lilas.
- C « Câbles » : tige courte au dos, bouteilles basses sur les hanches, gros câbles gainés qui pendent et traînent en boucles autour des bras et au sol, cape-treillis longue. Accent lilas #B9A6FF.

## Question ouverte à noter dans la planche
Accent lilas #B9A6FF de Grésille face au mycélium du Gouffre #C27BFF (risque de confusion en jeu) ; alternative bleu-blanc d'arc (silhouette B), à juger sur la lisibilité. Remarque fiche : le bleu d'arc proche d'Averse (#5FD4E8) et des cristaux des Cryptes (#BFF4FF), d'où un bleu très blanc, désaturé.

## Livrables
- art/blender/characters/gresille_concept.blend, scripts art/tools/gresille/.
- art/renders/gresille/planche_silhouettes.png : par silhouette, rendu sprite 192 px iso (se) à l'échelle du jeu + vue agrandie (rendu Blender plus grand, 3/4), noms A/B/C, palette, question ouverte, option : sprite sur tuile sol à côté d'Ardent pour l'échelle.
- Assemblage Python autorisé (coller, zoom NEAREST de planche) ; aucun dessin ni redimensionnement d'asset en PIL ; textes par Blender.
