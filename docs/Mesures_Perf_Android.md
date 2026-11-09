# Mesures de performance sur Android (cartes A et B)

But : vérifier sur un vrai téléphone les risques de performance listés dans `docs/Design_Variantes_B.md` §8 (eau profonde
de la Mangrove et de la Fonderie, occluders de la Fonderie en Haut, durée des étages B), avec le même banc que sur PC.
Le banc ne touche ni au profil ni au réglage de qualité enregistré : il tourne dans le mode test (bac à sable).

Code : `game/scripts/testmode/map_perf_bench.gd` (classe `MapPerfBench`), entrée dans l'onglet **Cartes** du panneau
de test (`test_panel.gd`, section « Banc de perf »), lanceur PC `game/tests/map_perf_bench.tscn`. À retirer ou masquer
avant la sortie, avec le mode test.

## 1. Ce que mesure le banc

Pour chaque carte demandée (les 9 cartes réelles : étages 1-4 en A et B, La Source), chaque palier de qualité (Bas,
Moyen, Haut) et chaque charge de monstres (0, 80, 250) :

- la carte est chargée par le chemin normal de l'onglet Cartes (coffres, piliers, Épreuves, téléporteur posés), le D
  d'ambiance est forcé à **7,5** (Cataclysme : tous les événements d'ambiance actifs, crue comprise) et le D de jeu aussi ;
- le joueur reste immobile au départ, PV illimités, sort 1 automatique ; les monstres sont maintenus au nombre visé
  autour de lui (T1 / T2 / T3, 12 % d'élites), comme le banc historique `tests/perf_bench.gd` ;
- préchauffe non mesurée de 2 s à 250 monstres par carte (compilation des shaders), puis 1,5 s de chauffe et 10 s
  (ou 4 s en mode rapide) de mesure par configuration ;
- relevés par image : temps d'image (moyenne, p95, p99, max), coût physique du Director (monstres), rendu GPU et CPU
  mesurés par le moteur, draw calls et objets rendus ; relevés de scène à la fin de la mesure : nombre de nœuds,
  lumières visibles et ombrées, occluders visibles, calques d'eau peu profonde et profonde (`AmbianceWater` : UN quad
  plein carte par couche, découpé en shader par le masque de la grille, donc 0 ou 1 par couche) et surface d'eau de la
  grille (cases `,` et `~`), effets d'ambiance actifs, mémoire vidéo. Les colonnes « proc^ » et « phys^ » sont les moniteurs de
  Godot (`TIME_PROCESS`, `TIME_PHYSICS_PROCESS`), qui donnent le **pic de la seconde écoulée**, pas la valeur de l'image.

Sortie : `user://perf_bench/bench_<date>.json` (toutes les valeurs) et `bench_<date>.txt` (tableau, résumé, comparaison
B contre A). Sur Android, `user://` est le dossier privé de l'app : passer par le bouton d'export (§2, étape 7).

**Seuils** (p95 du temps d'image à 250 monstres) : Haut ≤ 16,7 ms (60 i/s), Moyen ≤ 22,3 ms (45 i/s), Bas ≤ 33,4 ms
(30 i/s). Le résumé marque « LENT » toute carte au-dessus du seuil de son palier. La section « ALERTES » liste, à
250 monstres, les occluders au-dessus de 40 et les B dont le temps d'image (moyen ou p95) dépasse celui de leur A de
plus de 10 %, ou qui ont plus de cases d'eau profonde que leur A.

## 2. Protocole sur le téléphone

1. **Installer** la version de test : soit par la piste de test interne du Play Console (le fichier `.aab` est
   téléversé par le joueur lui-même, Chrome ne passe pas les gros fichiers), soit en débogage USB avec le bouton
   « Déploiement à distance » de l'éditeur Godot (préréglage Android, APK de débogage).
2. Avant de lancer : téléphone **branché sur secteur**, batterie > 50 %, mode économie d'énergie **coupé**, luminosité
   moyenne, aucune autre app ouverte, téléphone posé à plat et à température ambiante (pas juste après une partie). Noter
   la fréquence de l'écran (60, 90 ou 120 Hz : Réglages > Affichage) : sur Android la vsync ne se coupe pas toujours,
   les temps d'image ne descendent alors pas sous 1 / fréquence.
3. Lancer Rainfall > **Mode test**. Ouvrir le panneau : bouton **TEST** (tactile), Select maintenu 0,5 s (manette).
4. Onglet **Cartes** > section **Banc de perf** :
   - « 9 cartes, rapide (4 s) », environ 8 min : premier passage conseillé ;
   - « 9 cartes, complet (10 s) », environ 17 min : la mesure de référence ;
   - « carte courante (10 s) », environ 2 min : pour refaire une seule carte (la charger d'abord, en haut de l'onglet).
5. Le panneau se ferme et un bandeau affiche la configuration en cours et le temps restant. **Ne rien toucher** et garder
   l'écran allumé. « Arrêter le banc » termine après la mesure en cours (le résultat partiel est gardé).
6. À la fin, une fenêtre résume le nombre de configurations au-dessus du seuil et la ligne de chaque carte et palier.
   Faire une capture d'écran de cette fenêtre.
7. **Exporter le résultat** : feuille de partage Android (courriel, messagerie, Drive…) avec un `.zip` contenant le JSON
   et le tableau texte ; à défaut, le fichier est copié dans `Documents/Rainfall`. Le bouton « Exporter les résultats du
   banc » de l'onglet Cartes exporte tous les bancs faits sur l'appareil.
8. Transmettre le `.zip` avec : modèle du téléphone, fréquence de l'écran, durée de la batterie pendant le banc (% perdu)
   et si le téléphone était chaud au toucher à la fin.

À relever en priorité dans le tableau :

- p95 à 250 monstres en **Bas** pour les 4 cartes B (seuil 33,4 ms) ;
- colonnes « occ » (occluders) en **Haut** sur la Fonderie (`cite_fonderie_canal`) : risque si plus de 40 ;
- colonne « c~ » (cases d'eau profonde) et l'écart de temps d'image B / A de la Mangrove et de la Fonderie (sections
  « VARIANTES B CONTRE A » et « ALERTES » du fichier texte) ;
- la Rizière (`terrasses_rizieres_hautes`) en **Bas** : seule configuration lente sur PC (§4), à confirmer ;
- si le banc semble figé : si le menu pause est affiché (appel, notification, changement d'app), appuyer sur
  « Reprendre » ; sinon, si l'écran reste gelé plus de 30 s, noter la carte, le palier et le nombre de monstres du
  bandeau, puis forcer l'arrêt de l'app (voir §7).
- toute ligne où p99 dépasse 2 fois le p95 (saccades : chargement de texture, compilation de shader, ramasse-miettes).

## 3. Lancement sur PC

```
sh art/tools/vfx_test/godot_locked.sh res://tests/map_perf_bench.tscn -- --maps=cite_rouille,cite_fonderie_canal --seconds=10 --out=C:/temp/bench.json
```

Sans `--headless` (rendu réel, fenêtre 1920 × 1080, vsync coupée) ; sans `--maps`, les 9 cartes. Options : `--tiers=0,1,2`,
`--counts=0,80,250`, `--warmup=<s>`, `--ui` (bandeau et fenêtre de résultat comme sur le téléphone), `--watchdog=<s>`
(défaut 60 : fil de garde qui termine le processus si aucune image n'avance pendant `<s>` s, voir §7) et
`--watchdog-grace=<s>`. En `--headless` (contrôle de non-régression seulement, chiffres de rendu sans valeur) :
`--seconds=0.3`. Sortie : lignes `BENCHROW | {json}` au fil des mesures, tableau texte, puis `RESULT: OK`.
Durée : 9 cartes complètes ≈ 16 min ; une carte ≈ 2 min.

## 4. Résultats PC (09/11/2026)

Machine : Windows 11, NVIDIA RTX 5070 Ti, fenêtre 1920 × 1080, vsync coupée, renderer Mobile (Vulkan), D d'ambiance
7,5, 10 s par mesure, 81 configurations. Mesure bruitée : deux autres Godot tournaient en même temps (dont un figé à
100 % d'un cœur, §7) et un débogueur distant était branché. Les chiffres PC servent de référence relative ; seuls ceux
du téléphone tranchent.

Temps d'image à **250 monstres** (moyenne / p95, ms), occluders visibles en Haut, cases d'eau profonde :

| Carte | Bas | Moyen | Haut | occ (Haut) | cases `~` |
|---|---|---|---|---|---|
| `terrasses_noyees` (1 A) | 3,4 / 5,5 | 3,9 / 6,2 | 6,6 / 10,4 | 25 | 27 |
| `terrasses_rizieres_hautes` (1 B) | **6,2 / 16,5** | 4,3 / 7,4 | 5,0 / 7,3 | 26 | 26 |
| `foret_brume` (2 A) | 4,3 / 7,0 | 5,2 / 7,7 | 4,7 / 6,8 | 23 | 26 |
| `foret_mangrove_lanternes` (2 B) | 5,4 / 9,2 | 3,9 / 6,3 | 6,9 / 10,3 | 16 | 102 |
| `cite_rouille` (3 A) | 3,6 / 5,9 | 2,9 / 4,7 | 5,0 / 7,4 | 19 | 64 |
| `cite_fonderie_canal` (3 B) | 3,1 / 5,1 | 3,0 / 4,9 | 5,2 / 7,6 | **38** | 92 |
| `cryptes_noyees` (4 A) | 3,4 / 5,4 | 3,1 / 5,3 | 3,8 / 5,7 | 17 | 290 |
| `cryptes_ossuaire_pluies` (4 B) | 4,3 / 6,8 | 3,6 / 5,9 | 6,3 / 8,8 | 33 | 16 |
| `la_source` (5) | 2,4 / 4,2 | 3,0 / 5,1 | 3,6 / 5,5 | 12 | 0 |

- **Seuils** : les 27 configurations à 250 monstres passent largement (p95 max 16,5 ms en Bas pour un seuil de 33,4).
- **Rizières en Bas** : seule anomalie, reproduite sur deux passages (p95 10 à 16 ms à 80 et 250 monstres, pic de
  `_process` ≈ 12 ms, contre ≈ 5 ms en Moyen et Haut). Un coût CPU propre au palier Bas sur cette carte, peut-être lié
  à l'événement « La noria repart » (crue visuelle) : à confirmer sur téléphone, où un tel écart pèserait 3 à 5 fois plus.
- **Occluders** : maximum 38 (Fonderie en Haut), sous le plafond de 40 mais au ras ; l'Ossuaire en a 33 (A : 17).
  Aucun en Bas et Moyen (réglage `occluders = none`).
- **Eau** : chaque couche d'eau est un seul quad plein carte (1 calque `,` + 1 calque `~` sur toutes les cartes sauf
  la Source) ; le nombre de cases change la surface visible, pas le nombre de quads. La Mangrove (102 cases contre 26)
  et la Fonderie (92 contre 64) ont plus d'eau profonde que leur A, l'Ossuaire beaucoup moins (16 contre 290). Aucun
  surcoût mesurable sur PC.
- **B contre A** : à ces temps d'image (150 à 700 i/s), les écarts B / A sont du même ordre que le bruit (de ×0,75 à
  ×1,8 selon le palier, dans les deux sens). Signalés par le banc à 250 monstres : Rizières en Bas (+83 %), Mangrove en
  Bas et Haut (+25 % et +48 %), Ossuaire en Bas et Haut (+28 % et +65 %). À recouper sur téléphone.
- **Draw calls** : ≈ 200 à vide, 1 400 à 2 000 à 250 monstres sur toutes les cartes (≈ 6 par monstre) : c'est le premier
  poste à surveiller sur Android, indépendant des variantes.

## 5. Durée d'étage A contre B

Test `game/tests/floor_duration_test.tscn` (headless, ≈ 1 min) :

```
sh art/tools/vfx_test/godot_locked.sh --headless res://tests/floor_duration_test.tscn [-- --seeds=1,2,3,4 --maps=a,b --out=C:/temp/duree.json]
```

Méthode : pour chaque carte réelle et 4 graines, l'étage est posé par le vrai `StageManager` (chemin de l'onglet
Cartes : coffres, piliers, Épreuves, téléporteur tirés comme en run). Le trajet du joueur est mesuré à pied sur la grille
de déplacement de la carte (`NavField`, A* à 8 directions sans couper les coins) : départ, petits objectifs du plus proche
au plus proche, gros pilier, téléporteur, plus 5 coffres insérés au moindre détour. Temps = marche / (4 u/s × 0,8) +
temps fixes : Épreuve = durée cible de son verbe (`Balance.EPREUVE_TARGET_S`), mini-boss classique 35 s, charge du gros
pilier 60 s, boss d'étage 45 s, coffre 3 s. Les temps de combat ne dépendent pas de la carte (mêmes boss, même biome) :
l'écart A / B vient du trajet. Échec si une B dure plus de 45 s de plus que sa A (moyenne des graines).

Résultats (09/11/2026, moyenne de 4 graines, avec 5 coffres) :

| Étage | A | B | Marche A / B (u) | Durée A / B (s) | B − A |
|---|---|---|---|---|---|
| 1 | `terrasses_noyees` | `terrasses_rizieres_hautes` | 137 / 150 | 238 / 242 | +4 s |
| 2 | `foret_brume` | `foret_mangrove_lanternes` | 114 / 138 | 236 / 243 | +8 s |
| 3 | `cite_rouille` | `cite_fonderie_canal` | 162 / 195 | 246 / 256 | +10 s |
| 4 | `cryptes_noyees` | `cryptes_ossuaire_pluies` | 144 / 119 | 245 / 237 | −8 s |
| 5 | `la_source` | — | 117 | 157 | — |

Toutes les B restent à ±10 s de leur A (la Fonderie à +10 s, exactement l'estimation du §8 de Design_Variantes_B) :
aucune B n'allonge sensiblement la run. Les objectifs sont tous accessibles à pied sur les 36 étages posés.

## 6. Boss d'étage et mini-boss contre les obstacles centraux des B

Test `game/tests/boss_obstacle_test.tscn` (headless, ≈ 4 min) :

```
sh art/tools/vfx_test/godot_locked.sh --headless --fixed-fps 60 res://tests/boss_obstacle_test.tscn [-- --maps=cite_fonderie_canal --sim=20 --strict --out=C:/temp/boss.json]
```

Méthode : sur chaque carte B, le gros pilier candidat le plus proche de l'obstacle central (Rizières : noria ; Mangrove :
cèdre ; Fonderie : creusets ; Ossuaire : margelle du puits) fait apparaître, un par un, les boss d'étage et les 5
mini-boss du biome à l'endroit où `Pillar.activate` les pose. Le joueur (invulnérable, sorts coupés, immobile) est placé
3 u derrière l'obstacle. Pendant 20 s de jeu, on suit la distance au joueur et le déplacement du boss. Témoin : le même
boss refait l'essai avec le joueur à la même distance mais à découvert. Un boss est « bloqué par l'obstacle » s'il
n'approche plus (moins de 1 u parcouru sur les 5 dernières secondes) alors qu'il approche à découvert (écart de plus de
3 u). Les boss qui gardent leurs distances (tireurs, lanceurs) s'arrêtent aussi loin dans les deux cas et ne sont pas
comptés. Le test échoue seulement si un boss n'apparaît pas ; `--strict` compte aussi chaque alerte (à activer une fois
la navigation des gros corps corrigée).

Résultats (09/11/2026) :

Résultat identique sur deux passages (simulation déterministe). Rayon du corps : 1,4 u pour les boss d'étage, 1,1 u
pour les mini-boss. Boss identifiés par leur id (`data/floors.json`) :

| Carte (obstacle) | Bloqués derrière l'obstacle | Lents (encore en route après 20 s, atteignent à découvert) | Sans souci |
|---|---|---|---|
| Rizières (noria) | aucun | aucun (`drowned_idol` s'arrête à 6,9 u contre 4,5 à découvert, sous le seuil) | 7 / 9 ; `jar_bearer` garde ses distances dans les deux cas |
| Mangrove (cèdre) | **`bramble_queen`** (11,4 u contre 5,0) | **`cerf`, `hermit_cedar`** (boss d'étage), `brood_mother`, `lantern_owl` : tous arrêtés vers 11,4 u | `weaver`, `mist_wolf`, `moss_mantis` |
| Fonderie (creusets) | **`sonneur`** (8,6 u contre 2,2), **`smelter`** (8,6 contre 3,0) ; `ash_lord` coincé au même point (8,5 contre 7,5) | `crane` (9,4 contre 5,5), `blind_pump` | `rust_archon`, `steam_hound`, `grinder` ; `flood_gunner` garde ses distances |
| Ossuaire (margelle) | aucun | `crystal_mother` (lente dans les deux cas) | 7 / 9 ; **`deep_eel`** finit dans une case bloquée de la margelle (voir ci-dessous) |

Lecture :

- **Fonderie** : deux boss d'étage sur quatre (`sonneur`, `smelter`) et un mini-boss restent plantés derrière les
  creusets, tous au même point (8,5 u du joueur, 8,2 à 8,7 u du centre des creusets) : le contournement échoue pour
  les gros corps. Risque réel de boss qui ne vient jamais si le joueur se place derrière les creusets.
- **Mangrove** : `bramble_queen` est bloquée et 4 autres boss (dont les boss d'étage `cerf` et `hermit_cedar`)
  stagnent au même endroit vers 11,4 u du joueur, mais à 10 à 12 u du cèdre : ils butent plutôt sur un passage de la
  zone (chenal d'eau profonde, pontons) que sur le cèdre lui-même. À regarder dans le mode test (onglet Cartes, repère).
- **`deep_eel`** (Ossuaire) : elle nage, ne poursuit pas à pied (coincée dans les deux essais, c'est son comportement),
  mais elle finit dans une case `,` bloquée par l'emprise de la margelle : vérifier qu'elle n'émerge pas dans le puits,
  hors d'atteinte.
- **Cause probable** : les boss suivent le champ de flux du Director (`path_dir`, `NavField`), calculé pour un corps
  d'une case ; un boss plus large frotte sur les coins des obstacles et glisse sans passer. **Pistes** (hors de ce lot,
  `scripts/director/` et `scripts/enemies/`) : champ de flux « gros corps » calculé sur les obstacles dilatés du rayon du
  boss, ou glissement le long des murs quand le boss n'avance plus ; à défaut, écarter des obstacles centraux les gros
  piliers candidats de la Fonderie et de la Mangrove (`candidates.big_pillars` des cartes).

## 7. Gel observé pendant le banc PC (09/11/2026) : cause établie

Deux « gels » en mode fenêtré (jamais en `--headless`) : fenêtre « ne répond pas », un cœur à 100 %, plus aucune
progression (`foret_brume` Moyen 80 monstres ; `terrasses_rizieres_hautes` Haut 0 monstre).

**Cause** : ce n'était pas un blocage du moteur. Une capture des deux fenêtres figées montre le **menu pause ouvert** :
la fenêtre du jeu avait perdu le focus (autres fenêtres ouvertes pendant le banc), `PauseMenu` ouvre la pause sur
`NOTIFICATION_APPLICATION_FOCUS_OUT`, et le banc prolongeait sa mesure tant que l'arbre était en pause, donc sans fin.
La boucle de jeu tournait toujours (vsync coupée : 100 % d'un cœur, d'où « ne répond pas » côté Windows), et le fil de
garde ne se déclenchait pas puisque les images avançaient. Reproduit en headless avec `--focus-out-at=<s> --keep-pause`.

**Correctif** : le lanceur PC (`tests/map_perf_bench`) reprend automatiquement la partie (`PauseMenu.resume()`) si la
pause s'ouvre pendant le banc, et le fil de garde signale « jeu en pause » au lieu de rester muet. Sur téléphone, la
reprise reste manuelle : le joueur appuie sur « Reprendre ». Au passage, le préchargement des boss
(`EnemyVisual`) est désormais récupéré une seule fois au lieu d'être redemandé sans fin, et `BakedShadows` n'attend plus
aucune tâche sur le fil principal (test `tests/threaded_loads_test`).

Sur téléphone : si le menu pause s'affiche pendant le banc, appuyer sur « Reprendre ». Si l'écran reste réellement figé
plus de 30 s, noter la carte, le palier et le nombre de monstres du bandeau, puis forcer l'arrêt (Réglages >
Applications > Rainfall > Forcer l'arrêt) et le signaler.
