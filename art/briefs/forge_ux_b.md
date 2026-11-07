# Lot UX-B : icônes Forge v3 et noyau d'orage v3

Décision du joueur (07/11/2026) : refaire les 6 icônes d'objets de Forge et le noyau d'orage (icône + pickup au sol). Sources de l'audit : contraste médian des icônes v2 de 1,1 à 2,4:1 sur le fond de la Forge (#30201C, cible >= 3:1), Rosée figée et Prisme de grêle de même silhouette (cristal), Mèche lue comme une bobine, noyau sombre, décentré, lu comme une montre, pickup à 1,4:1 sur sol sombre.

DA : art/briefs/STYLE.md (en tête), STYLE_cel.md, STYLE_boss_da.md. Matières usées, palette désaturée, un seul accent émissif par objet, silhouettes anguleuses, cel (module art/tools/cel/cel_style.py). Aucun `_n`. Soleil chaud #FFC287 haut-gauche.

## Règles de valeur (nouvelles, bloquantes)
- Le fond d'affichage est sombre (#30201C, luminance 0,017). Les matières du corps sont de valeur MOYENNE à CLAIRE (acier patiné, bois délavé, laiton, pierre pâle, givre), pas de noir ni de brun-noir en grande surface. Les noirs sont réservés à de petits creux et au trait d'encre.
- Chaque icône a un LISERÉ D'ARÊTE clair (arête éclairée haut-gauche, chanfrein ou bande de matière claire) sur tout son contour : le contour extérieur est plus clair que l'intérieur.
- Mesure : contraste WCAG médian du corps >= 3:1 ET du liseré (bande de 3 px du bord) >= 3:1 sur #30201C (`art/tools/forge/f1b_check.py`).
- Silhouettes : 6 formes nettement distinctes à 48 px, lisibles en noir plein. IoU des masques à 48 px entre deux icônes <= 0,72 (viser <= 0,60).

## Les 6 icônes (256x256 RGBA, marge >= 14 px, rendues directement à 256 dans Blender, centrées, PNG <= 60 Ko)
Chemin : game/assets/sprites/icons/items/<id>.png ; `_e.png` (masque d'émission, même cadrage) pour meche_silex, rosee_figee, prisme_grele.
1. `meche_silex` Mèche-silex (Feu + Crit : crit +4 %, chaque critique enflamme). Silhouette : ÉCLAT de silex triangulaire en diagonale (pointe en haut à droite, éclat tranchant, arête vive) avec une courte mèche tressée qui sort de la base et un point de braise orange #FF7A1F à son extrémité. Plus de bobine.
2. `rosee_figee` Rosée figée (Survie + Givre : armure, soin sur cible ralentie). Silhouette : GOUTTE (rond en bas, pointe en haut) enchâssée dans un cerclage de fer clair ; goutte de givre pâle, reflet, accent cyan #5FD4E8 émissif. Aucun cristal anguleux.
3. `rouage_traque` Rouage de traque (Auto + Recharge : chaque touche du sort 1 réduit les recharges). Silhouette : ROUAGE à dents franches (silhouette dentelée ronde) avec un crochet de traque qui dépasse sur un côté. Laiton clair, accent cuivre.
4. `seve_rampante` Sève rampante (Poison + Zone : le poison saute aux voisins). Même sujet que la retouche récente (art/blender/forge/f1_seve.blend : racine noueuse, vrille rampante, goutte de sève vert #7FA35B/#A5E65B), mais silhouette ouverte en S, valeurs de racine plus claires (bois délavé), liseré clair. Pas d'`_e` demandé (la sève est déjà vive) : n'en créer que si le coût est nul.
5. `ecorce_pluie` Écorce de pluie (Survie + Givre : armure, barrière sur gros coup). Silhouette : ÉCU / bouclier en écorce (haut plat, pointe en bas), plaques d'écorce claires, perles de pluie cyan en relief, cerclage laiton vert-de-gris. Pas d'`_e`.
6. `prisme_grele` Prisme de grêle (Givre + Zone : zone +20 %, ralentit). Silhouette : PRISME HEXAGONAL HAUT et étroit couché en biais, OU grappe de 3 cristaux pointus en éventail ; jamais une goutte ni un seul cristal vertical. Verre fumé clair, facettes froides, accent cyan émissif.

## Noyau d'orage
- Icône : game/assets/sprites/icons/storm_core.png 256x256 + `storm_core_e.png`. CŒUR D'ÉNERGIE orageuse enchâssé : cage / griffes de métal clair (cerclage cuivre #D9803A) tenant une sphère translucide qui contient un éclair cyan #5FD4E8 (seul émissif, fort). Silhouette ronde-hexagonale CENTRÉE (centre de l'alpha à 0,50 +-0,02), plus de montre (pas de cadran, pas de bracelet, pas d'anneau unique). Valeurs claires pour contraste >= 3:1 sur #30201C.
- Pickup : game/assets/sprites/pickups/storm_core.png 96x96 + `storm_core_e.png` 96x96 + `storm_core_shadow.png`. Même noyau, caméra iso du jeu (rig art/tools/iso/iso_rig.py, create_rig/render_frame, dimétrique 2:1, élévation 30 degrés, lacet 45 degrés), posé au sol, valeur claire + liseré clair pour se détacher d'un sol sombre (contraste médian et liseré >= 3:1 sur #24201E aussi). Pas de halo codé : l'éclat vient de `_e`. `storm_core_shadow.png` = décalque d'ombre cuite (iso_rig.render_shadow_decal ou rendu équivalent depuis le dessus : niveaux de gris/alpha, fond transparent, ombre portée vers le bas-droite écran, taille <= 96x96, PNG <= 4 Ko).

## Pipeline et interdits
Blender `--background`, scripts dans art/tools/forge/ (f3_icons_build.py, f3_core_build.py), .blend dans art/blender/forge/ (f3_icons.blend, f3_core.blend ; jamais écraser f1.blend, f1_seve.blend, f2.blend). Rendu direct à la taille finale (aucun redimensionnement PIL/LANCZOS, aucune forme dessinée en PIL). Seul PIL admis : assembler des planches, mesurer. Les bibliothèques à réutiliser : art/tools/ui/items_v2/iv2_lib.py, art/tools/cel/cel_style.py, art/tools/forge/f1_build.py (fonctions d'origine), f2_build.py (make_core).
