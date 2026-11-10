# Rainfall

Survivor-like 2D en vue isométrique, inspiré de Vampire Survivors et de Risk of Rain : on traverse cinq étages, on empile des objets et on affronte des boss, en paysage, sur PC et sur mobile.

**Statut : en développement.** Le jeu n'est pas encore publié ; les valeurs d'équilibrage, les personnages et certains contenus peuvent changer.

## Plateformes et entrées

- PC Windows (distribution prévue sur Steam), Android et iOS.
- Paysage uniquement : base logique 1920×1080 (`keep_height`), fenêtre redimensionnable sur PC, capteur paysage sur téléphone.
- Clavier et souris, manette, écran tactile. Les contrôles tactiles sont masqués sur PC sauf écran tactile.
- Jeu payant (environ 5 €), sans publicité, sans achat intégré et sans pay-to-win. Les rubis ne servent qu'à des éléments cosmétiques.

## Principes de jeu

**Structure d'une run (façon Risk of Rain 2).**

| Étage | Biome | Cartes |
|---|---|---|
| 1 | Terrasses noyées | 2 variantes |
| 2 | Le Gouffre luisant | 2 variantes |
| 3 | Cité de rouille | 2 variantes |
| 4 | Cryptes noyées | 2 variantes |
| 5 | La Source | arène unique |

- Un étage a toujours le même biome ; la variante de carte (A ou B) est tirée.
- Chaque étage 1 à 4 propose plusieurs boss d'étage possibles (un est tiré) et un lot de mini-boss.
- L'étage 5 est l'étage du boss final, « Le Semeur de pluie », en plusieurs phases.
- Après le boss final, on peut terminer la run ou continuer en mode sans fin (les biomes reviennent avec la variante opposée).

**Combat.**

- Sort 1 automatique, vers l'ennemi le plus proche.
- Sorts 2 à 4 : deux sorts à recharge puis l'ultime. Sur PC ils visent le curseur de la souris, à la manette le stick droit, sur mobile le ciblage est automatique.
- Esquive (roulade) propre à chaque personnage.
- Chaque sort a des variantes à débloquer.
- Le temps fait monter la difficulté, comme dans Risk of Rain : voir `docs/Maths_Scaling.md`.

**Objets, coffres, or.**

- 48 objets à trouver plus 6 objets de Forge (`game/data/items.json`), qui s'empilent, avec raretés, synergies et relance de coffre.
- Or, expérience et niveaux au fil de la run ; téléporteur de sortie d'étage activé uniquement par l'action « interagir ».

**Épreuves.** Cinq verbes d'objectifs optionnels dans l'étage : escorte, rituel, poursuite, veine, tenue (`docs/Design_Epreuves.md`).

**Forge.** Objets exclusifs fabriqués pendant la run à partir de recettes par étiquettes (six objets, deux rangs), avec des noyaux d'orage lâchés par les boss d'étage (`docs/Design_Forge.md`). L'inventaire s'ouvre avec Tab, Select (manette) ou le bouton tactile.

**Zones secrètes.** Au plus un secret par run, derrière un déclencheur tiré au hasard (plaques de pression, levier, mur fissuré, pilier éteint), gardé par une brute élite et un reliquaire à la clé (`docs/Design_Zones_Secretes.md`).

**Coop locale 1 à 4 joueurs sur PC.** Scaling façon Risk of Rain 2 ; un joueur mort devient spectateur et revient à l'étage suivant. La coop en ligne est prévue dans une mise à jour après la 1.0 (`docs/Design_Multijoueur.md`).

## Personnages

Onze personnages jouables, chacun avec quatre sorts (auto, deux à recharge, ultime). Source : `game/data/characters.json`, détails dans `docs/Design_Personnages.md`.

| Nom | Idée |
|---|---|
| Ardent | Mage de feu, zone, prise en main simple |
| Rictus | Pantin de la barge noyée : mêlée rapide, fil, leurres |
| Tocsin | Automate de crue : tank, cloche, contrôle |
| Averse | Porteuse de pluie : distance et zone, gestion de l'eau |
| Arpenteuse | Géomètre de la Cité : zone et pièges, chaîne au sol |
| Rainette | Chevalière des roseaux : mobilité et burst |
| Avare | Usurier des Terrasses : mêlée, tank, or |
| Bourbe | Mère-vase de la Mangrove : invocations et mêlée |
| Vigie | Guetteuse de la digue : archère, filet et pièges, jauge de Guet |
| Taliant | Rōnin d'écorce : mêlée lourde, gestion du tranchant |

## Technique

- Moteur : Godot 4.7.2, GDScript typé, renderer Mobile.
- Affichage : base 1920×1080, `canvas_items`, `keep_height`, orientation paysage.
- Art : les assets visuels sont modélisés et rendus dans Blender (sprites pré-rendus, éclairage cohérent, rendu cel-shadé), la lumière et l'ambiance étant gérées en code dans Godot.
- Son : les sons sont synthétisés de façon procédurale ; rien n'est téléchargé, à l'exception de polices libres SIL OFL.

**Arborescence.**

```
docs/            guides de conception et d'équilibrage
art/             sources Blender, briefs, outils de rendu
game/            projet Godot (res://)
  scripts/       code GDScript (core, player, enemies, stage, spells, ui, ...)
  data/          données JSON (personnages, objets, étages, recettes, ...)
  assets/        sprites, audio, polices
  tests/         tests headless
tools/           scripts Python d'analyse et de génération
```

**Autoloads principaux** (`game/project.godot`).

- `Events` : bus de signaux entre systèmes (ennemi tué, dégâts, coffre ouvert, boss, étage).
- `Balance` : formules pures d'équilibrage (difficulté, director, monstres, boss, joueur, empilement, coffres).
- `RunState` : état de la run (temps actif, étage, or, expérience, niveau, objets, tirages).
- `Players` : gestion des joueurs (coop locale).
- `InputSetup` : actions d'entrée clavier, manette et souris.
- `Platform` : plateforme et mode d'entrée courant.
- `Profile` : sauvegarde du profil (déblocages, compteurs, rubis).
- `Audio`, `Quality`, `Accessibility` : audio, niveau de qualité graphique, options d'accessibilité.
- `TestMode`, `RunLog` : mode test (arène d'essai) et journal de run local.

Règles de code : toute valeur d'équilibrage vient de `Balance`, l'état de run de `RunState`, la communication entre systèmes passe par `Events`. 1 unité de jeu = 64 px.

## Lancer le projet et les tests

1. Installer Godot 4.7.2.
2. Ouvrir le dossier `game/` dans Godot (ou `godot --path game`).

Tests headless (sortie `RESULT: OK` en cas de réussite) :

```
godot --headless --path game res://tests/<test>.tscn
godot --headless --path game --script res://tests/test_balance.gd
```

Exemples de scènes de test : `forge_test`, `test_mode_test`. Le test `test_balance.gd` se lance avec `--script` (sans autoload) ; les autres sont des scènes.

Simulateur de scaling (référence des formules testées par `test_balance.gd`) :

```
python docs/simulateur_scaling.py moyen
```

Options de lancement (après `--`) :

- `-- --test-mode` : ouvre l'arène de test (invocation de monstres et de boss, ajout d'objets, changement de personnage) ; elle n'écrit rien dans le profil.
- `-- --no-epreuves` : désactive les Épreuves.

## Documentation

Les guides sont dans `docs/` et font foi.

- `GDD.md` : document de game design général.
- `Maths_Scaling.md` : formules de difficulté, de monstres, de boss et de joueur.
- `Items_Catalog.md` (et `.xlsx`) : catalogue des objets.
- `simulateur_scaling.py` : simulateur de référence des formules.
- `Design_Personnages.md`, `Equilibrage_Personnages.md` : roster et équilibrage des personnages.
- `Design_Etages.md`, `Boucle_Etage_Design.md`, `Boucle_Etage_Refonte.md` : structure et boucle d'un étage.
- `Design_Isometrique.md` : caméra et projection isométriques.
- `Design_Epreuves.md` : les cinq Épreuves.
- `Design_Forge.md` : forge et noyaux d'orage.
- `Design_Zones_Secretes.md`, `Design_Variantes_B.md` : secrets et cartes de variante B.
- `Design_Multijoueur.md` et `multi/` : coop locale puis en ligne.
- `Variantes_Sorts.md`, `Design_Feel_Sorts.md`, `Design_Esquives.md` : variantes de sorts, ressenti, esquives.
- `Direction_Lumiere_Ambiance.md` : direction de la lumière et de l'ambiance.
- `Design_Menus.md`, `ux/` : menus et UX.
- `Skins.md`, `Boutique_Rubis.md` : cosmétiques et rubis.

## Licence

Tous droits réservés : le dépôt ne contient pas de fichier de licence.

Les polices Alegreya Sans et Cinzel sont sous licence SIL Open Font License ; les licences sont dans `game/assets/fonts/`.
