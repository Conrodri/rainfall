# Forge : objets exclusifs fabriqués

Décisions du 06/11/2026. Code : `game/scripts/items/forge.gd` (logique pure), `craft_effects.gd` (effets), `game/scripts/ui/forge_panel.gd` (écran), `game/data/recipes.json` (recettes). Test : `game/tests/forge_test`.

## Accès
- Run réelle : TAB (clavier), Select/Back (manette), bouton « +N » de la barre d'objets (tactile) ouvrent l'**inventaire** ; l'onglet **Forge** y est à côté de l'onglet Objets (LB/RB changent d'onglet).
- Mode test : le panneau passe à **F1** (clavier) et **Select maintenu 0,5 s** (manette) ; le bouton « TEST » tactile est inchangé.
- Solo : l'écran met le jeu en pause. Coop : jamais de pause globale (superposition non bloquante, `ChestSession.is_blocking`).
- Hors run : aucun effet.

## Noyau d'orage (catalyseur)
- 1 par boss d'étage (étages 1 à 4) donné à **chaque** joueur, +1 du reliquaire `guardian` de la zone secrète. Pas de noyau au mini-boss ni au boss final.
- 2 au plus portés (`Balance.CRAFT_CATALYST_CAP`), compteur par joueur, non achetable, non copiable.
- Une forge coûte 1 noyau.
- **Pickup au sol** (`scripts/pickups/storm_core_pickup.gd`, sprite `pickups/storm_core.png`) : le noyau tombe à la mort du boss d'étage et près du reliquaire secret, ramassé au contact (petit aimant). Coop : un pickup par joueur **vivant**, ramassable seulement par lui, teinté de sa couleur d'équipe ; un joueur mort (spectateur) est crédité directement (il peut forger). Pas de pickup si porté + au sol atteint déjà le plafond. Un noyau resté au sol est crédité au départ de l'étage (`PlayerState.pending_catalysts`, aussi compté à la sauvegarde). Toast « Noyau d'orage +1 » au ramassage.

## Recettes (par tags)
- Rang I : clé A (tag, commun+) + clé B (tag, commun+) + 1 objet commun quelconque.
- Rang II : clé A (peu commun+) + clé B (commun+) + 1 peu commun + 1 commun.
- Une qualité supérieure remplace la qualité demandée. Un objet = un rôle. Les légendaires ne sont jamais consommés ; le Phénix seulement s'il n'a pas servi (`StationState.spendable_stacks`) ; un objet forgé n'est jamais ingrédient.
- Pas de rang III. 2 exemplaires d'un même objet forgé au plus (`CRAFT_MAX_STACKS`).

| Objet | Rang | Clés | Effet (1er exemplaire / 2e) |
|---|---|---|---|
| Mèche-silex | I | Feu + Crit | +4 % critique ; un critique brûle 150 % du dégât de base sur 3 s, sans jet / +75 % |
| Rosée figée | I | Survie + Givre | +5 armure ; toucher une cible ralentie soigne 0,3 % PV max, 1 %/s au plus / +0,5 %/s, +5 armure |
| Rouage de traque | I | Auto + Recharge | chaque touche du sort 1 retire 0,08 s aux recharges 2-4, 0,4 s/s au plus, jamais sous `COOLDOWN_FLOOR` / +0,15 s/s |
| Sève rampante | II | Poison + Zone | un monstre empoisonné qui meurt passe ses cumuls (5 max) à 2 voisins à 3 u ; une génération par mort, 8 propagations/s au plus / 3 voisins |
| Écorce de pluie | II | Survie + (Survie ou Givre) | +15 armure ; un coup d'au moins 10 % PV max donne une barrière de 10 % PV max pendant 4 s (recharge interne 6 s) / barrière 15 %, +10 armure |
| Prisme de grêle | II | Givre + Zone | +20 % de zone ; les zones des sorts 2-4 ralentissent de 30 % pendant 1,5 s / +10 % de zone |

Aucun ne touche l'or ni la chance.

## Garde-fous
- Les objets `craft_only` sont exclus de `LootRoller`, des coffres, de `ids_of_quality`, de la Matrice, de l'Alambic, de l'Enclume, du Fondoir et du marchand.
- Barrières totales plafonnées à 25 % des PV max (`BARRIER_CAP_PCT`) ; brûlure à 10 cumuls (`BURN_MAX_STACKS`) ; propagations de Sève à 8/s (`CRAFT_SPREAD_MAX_PER_S`).
- Coop : noyaux, forges et objets par joueur, aucun échange ; un joueur mort (spectateur) peut forger.

## Écran
Choix de recette (la réalisable est en tête, toutes sont visibles) puis sélecteur d'objets (`ItemPicker`) pré-rempli avec les objets les moins utiles, puis confirmation en deux temps (« Vous perdez » en rouge, « Vous gagnez » en vert). Souris : clic ; manette : LB/RB, A, B ; tactile : un appui. La pastille « Forge possible » apparaît sur le bouton « +N » de la barre d'objets quand une recette est réalisable et qu'un noyau est porté. Cadre « forgé » cuivré (`Palette.FORGE_COLOR`), distinct des raretés.

## Télémétrie
`RunLog` : événement `craft` (joueur, objet, ingrédients, étage) ; rien en mode test.

## Mode test
Le panneau (onglet Objets) donne les noyaux (−1 / +1 / Plein) et les 6 objets forgés (section « Forgés »).

## Assets à produire par Codex (placeholders de code aujourd'hui)
- 6 icônes d'objets 128 px (Mèche-silex, Rosée figée, Rouage de traque, Sève rampante, Écorce de pluie, Prisme de grêle).
- Icône du noyau d'orage pour le HUD et son pickup au sol (faits : `icons/storm_core.png`, `pickups/storm_core.png`).
- Cadre « forgé » cuivré pour les cartes et la barre d'objets.
- Pastille « Forge possible » (aujourd'hui un point cuivré en code).
