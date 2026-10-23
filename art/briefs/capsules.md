# Capsules d'or (fut d'argent gratuit)

Demande du joueur (inspiree de Risk of Rain) : des capsules d'argent gratuites dispersees sur la carte, qui donnent de l'or.
Livre par Claude en interim (quota Codex epuise) : Codex peut refaire a l'identique, memes noms et memes dossiers.

## Fichiers
- Script : `art/tools/props/capsule.py` (reconstruit tout de zero) ; lancer `blender.exe --background --python art/tools/props/capsule.py` (une seule instance Blender).
- Source : `art/blender/props/gold_capsule.blend` ; rendus : `art/renders/gold_capsule/<pose>[_n|_e]/x_00.png`.
- Assemblage : `python art/tools/pack.py props gold_capsule 128 closed:1:noloop open:1:noloop`.
- Sortie jeu : `game/assets/sprites/props/gold_capsule/` : `closed.png`, `open.png`, `closed_n.png`, `open_n.png`, `closed_e.png`, `open_e.png`, `gold_capsule.tres` (SpriteFrames `closed` et `open`, 1 frame chacune, sans boucle).

## Spec
- Frame 128 x 128 px, 1 direction, rendu a 2x (256) puis Lanczos. Pied du fut a 22 % de la hauteur depuis le bas, marges >= 4 px. Dans la scene : `Visual.offset = (0, -36)`, echelle 1,8.
- Camera orthographique, elevation 35 deg, azimut fixe (voir STYLE.md), lumieres du STYLE.md (soleil tiede haut-gauche, remplissage froid, rim #9FB8D8). Eevee, 24 echantillons, Standard, fond transparent, contour sombre 1 px (#1A1620) au compositeur.
- Modele (z haut, face vers -Y) : socle ardoise #2B3340 r 0,56 ; corps cylindre argent #C9D1DC (metal 0,9, rugosite 0,30) r 0,50 h 0,94 ; 2 cerceaux acier #4A5565 (z 0,26 et 0,90) avec 8 rivets ; collier superieur ; **anneau lumineux dore** #F2C14E autour du col (emission 2,2) ; **embleme piece** sur la face (anneau acier + disque dore + barre #FFE9A8, emission 2,8) ; stries de brosse fines.
- Couvercle a charniere arriere (z 1,10, y +0,46) : plaque argent, rebord acier, poignee, bouton dore, fente lumineuse ; doublure sombre #1A1620.
- Etat `closed` : couvercle ferme, parties dorees emissives (tag `rainfall_emissive`). Etat `open` : couvercle tourne de -138 deg autour de X, interieur sombre vide, **plus de lueur** (emission 0, dorures grisees #7C8898, tag false).
- Normales : `passes.render_normal_pass` + renormalisation ; masque d'emission `_e` : seules les dorures de l'etat ferme brillent (l'etat ouvert est noir).
- Piege connu : `passes.emission_material` met en cache par nom, supprimer les materiaux `_Rainfall*` entre deux poses.

## Usage en jeu
Lumiere `chest_petit` tant que fermee, flash `chest_open` a l'ouverture, ouverture par l'action `interact` seulement (`game/scripts/loot/gold_capsule.gd`).
