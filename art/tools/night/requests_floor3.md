# Demandes d'art — étage 3 (Cité rouillée)

## Sonneur (boss d'étage, intégré le 22/10/2026 : `game/scripts/enemies/sonneur_brain.gd`)
Lot à lancer plus tard (Codex, méthode C7c, `art/tools/night/c7c_build.py`, source `art/blender/monsters/sonneur_iso.blend`).
Dossier : `game/assets/sprites/bosses/etage/sonneur/`. Chaque sheet avec `_n` et `_e`, ajoutée à `sonneur.tres` (anims ajoutées, rien de renommé).
Les noms ci-dessous sont lus par le code s'ils existent (sinon repli actuel).

1. **Lisibilité du corps (prioritaire)** : en jeu, sous l'éclairage de nuit de la Cité, le Sonneur reste presque noir
   (albédo moyen ~40/255 sur `idle_p1.png`), même avec une lumière de boss à forte énergie. Le code compense par
   `self_modulate` ×1,7 (`SonneurBrain.BODY_GAIN`), à retirer après correction. Demande : re-rendre toutes les sheets
   du corps avec un albédo relevé (fer rouillé 70-90/255, laiton plus clair), un liseré de lumière froide haut-gauche
   (rim) et l'accent ambre du foyer plus large (porte, rivets, joints de la cloche) dans `_e`. Mêmes cellules, mêmes
   frames, même pivot (128 ; 166,4).
2. **`glas_wave`** (anneau de choc du Glas) : sprite de sol vu de dessus, anneau d'onde sonore/électrique ambre pâle,
   256×256 par frame, 8 frames non bouclées (anneau fin qui s'élargit et s'efface), fond transparent, 1 u = 64 px.
   Le code l'étirera de 1 u à 8 u de rayon en 0,8 s (aujourd'hui : 26 copies de `ground_lightning` en cercle).
3. **`lightning`** : la colonne utile ne fait que 131 px dans une cellule 128×768 (y 319-450) ; le code l'étire ×4,6
   en hauteur. Demande : éclair occupant toute la cellule 128×768 (~12 u à l'échelle des extras), pied au bas de
   la cellule, 4 variantes, ramifications, cœur blanc-ambre ; `_e` complet.
4. **`steam_jet`** (vapeur de la phase 3) : jet horizontal au ras du sol, vu en iso, 1 u × 6 u (64×384 dans le sens
   de la longueur, origine au bout côté boss), 8 frames en boucle, vapeur sale gris-brun, `_e` noir. Aujourd'hui :
   4 panaches verticaux `steam_vent` par jet, trop fins (60 px utiles sur 384) et pâles.
5. **`bolt`** : boulon 32 px trop petit à l'écran (0,7 u) ; le passer en 64×64, 6 frames (rotation), laiton usé, avec
   un trait de chute (motion blur) dans 2 frames.
6. **Son (Codex audio, `art/tools/audio/`)** : `enemy.bell_toll.heavy` (glas : coup de cloche fêlée grave + traîne
   métallique 1,5 s), `enemy.bolt_rain.medium` (pluie de boulons : cliquetis métalliques + impacts), `enemy.steam_jet`
   (sifflement de vapeur en boucle). Le code utilise aujourd'hui `enemy.shockwave.heavy`, `telegraph.boss.heavy` et
   `amb.thunder_close`.
