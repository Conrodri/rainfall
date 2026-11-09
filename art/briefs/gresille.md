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

## RÉVISION 2 (refus de la v1 par le coordinateur, à appliquer à la lettre)
La v1 (corps trapu masculin, épaulières boules, mains moufles, bottes blocs, proportions chibi) est REFUSÉE ; elle remplace la section « Les 3 silhouettes » ci-dessus.
- UN corps unique conforme : **une femme**, ouvrière des hauteurs, réaliste, 6,5-7 têtes, épaules carrées mais carrure féminine (taille marquée sous la veste, hanches, jambes longues), visage fin sans moustache ni nez proéminent, cernes, bouche serrée, chignon à épingles de cuivre, mèches dressées (lueur d'accent lors de l'ultime). Mains à doigts articulés (gants de toile caoutchoutée à manchettes), bottes de gutta-percha noires lisses montant au mollet (pas de blocs). Veste de laine grise usée, ceinture d'outils, cape-treillis de mailles de cuivre sur les épaules. Matières PBR usées, mouillées, silhouettes anguleuses, style ash_lord (art/tools/monsters/ash_lord_build.py) et Vigie/Ardent existants (game/assets/sprites/characters/vigie, ardent) : elle doit sembler du même jeu. Palette sombre désaturée, UN accent émissif.
- 3 variantes qui changent la SILHOUETTE lisible de loin (pas que les accessoires) :
  - A = fiche à la lettre : tige de paratonnerre COURTE 0,9 u tenue main droite en bâton de marche, trois isolateurs de verre bleu empilés sous la pointe, cape-treillis sur les épaules, deux Leyde sur râtelier de bois ciré dans le dos. Accent lilas #B9A6FF.
  - B = bobines/gantelets : grosses bobines de cuivre aux avant-bras, cape-treillis réduite en collerette, une seule grosse Leyde dorsale basse ; silhouette plus large en bas des bras. Accent bleu-blanc #D8EEFF.
  - C = câbles/râtelier haut : râtelier de bouteilles de Leyde dressé au-dessus des épaules (silhouette haute, trois bouteilles), câbles gainés en boucles vers les gants, cape-treillis courte. Accent lilas #B9A6FF.
- Vérifier chaque rendu (sprite 192, vignette jeu, big) : la silhouette doit se lire comme une femme à 192 px. Planche PNG < 2 Mo (quantification PNG sans perte visible ok pour la planche d'aperçu).
