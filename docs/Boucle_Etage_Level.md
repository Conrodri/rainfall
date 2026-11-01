# Boucle d'étage : casser la routine « piliers → tour des coffres → boss → tour des coffres → partir » (level design v1)

> Statut : **avis de level design** (consultant level-designer, 01/11/2026), sur retour du joueur : « souvent dans les games je dois rush les deux piliers de mini-boss pour générer des golds, je fais un tour de map pour prendre les coffres, je tue le boss, je refais un tour de map pour acheter les coffres et je pars, je fais ça en boucle, je n'ai aucune autre chose à faire ». Aucun fichier de `game/` n'est modifié ; rien n'est implémenté.
> Lu avant d'écrire : `CLAUDE.md` (Décisions), `docs/Propositions_Boucle_Interactions.md` (ateliers retenus : Fondoir + Matrice, Alambic, Enclume, Boussole de rouille, Paratonnerre dévié, Présages ; rejetés : Reposoir, Brasero, Départ vif, Étal des rebuts), `docs/Design_Etages.md`, `docs/Design_Variantes_B.md` (§0-2, §6-12), `game/scripts/core/balance.gd`, `game/scripts/stage/stage_manager.gd`, `pillar.gd`, `game/scripts/loot/chest.gd`, `game/scripts/ui/minimap.gd`, `game/data/maps/foret_brume.json`, sortie de `docs/simulateur_scaling.py moyen`.
> Angle : **la carte, le parcours et le rythme de l'étage**. Les ateliers (objets, build) sont traités ailleurs ; ce document ne les redouble pas, il dit seulement comment chaque idée s'y raccorde.
> Contraintes respectées : gel des boss (aucun boss ni mini-boss nouveau ; une seule créature non hostile proposée, idée 6, à valider), téléporteur activé par « interagir » seulement, télégraphes ≥ 0,8 s, aucun piège invisible ni dégât de terrain, aucun nom ni design repris de Risk of Rain ou de Vampire Survivors. Toute valeur est proposée pour `Balance` ou un JSON de `game/data/`, jamais en dur.
> Unités : 1 u = 64 px ; joueur à 4,0 u/s (`Balance.PLAYER_SPEED_U`) ; **P** = prix d'un petit coffre au début de l'étage (≈ 50 / 112 / 207 / 348 or aux étages 1 à 4 en Moyen, `Propositions_Boucle_Interactions.md` en-tête). Tous les temps marqués « estimé » sont des calculs (distance / vitesse), pas des parties jouées.

---

## 0. Diagnostic : pourquoi la carte se « résout » en deux tours

Cinq causes, toutes dans le code actuel :

1. **Information complète dès la seconde 0.** Les 10 coffres sont posés à `start_stage()` et la minimap les affiche tous, avec leur type, dès l'arrivée (`minimap.gd`, `_chests`). Le joueur connaît tout le marché avant de bouger : il n'y a rien à découvrir, seulement un trajet à optimiser.
2. **Prix figés à l'apparition.** `chest.gd` fige `_price_d` au moment du `setup` (début d'étage). Acheter tôt ou tard coûte pareil ; la stratégie dominante est donc « accumuler d'abord, acheter ensuite », d'où le second tour.
3. **Les piliers sont le seul moteur d'or situé.** Hors pilier, l'or vient des kills diffus (2 × D × coût × 0,235 par kill) et des 10 capsules (≈ 0,4 P chacune). La zone d'un petit pilier multiplie les crédits du director par 1,5 (`ZONE_SPAWN_MULT[&"mini"]`) : c'est l'endroit où l'or coule le plus vite, d'où le « rush des deux piliers ». La prime du mini-boss elle-même est faible (2 × D × 25 × 0,235 ≈ 0,25 P).
4. **Les relâches ne contiennent rien.** Entre deux pics, le joueur traverse ; les cases `E` (3 par carte, une par tiers) sont vides tant que les ateliers ne sont pas codés, et même codés, il n'y en aura qu'un par étage.
5. **Après le boss, la carte ne change pas.** Même géométrie, mêmes menaces, mêmes coffres : le second tour est un trajet à vide de 40 à 70 s (moitié d'un tour complet de 244 à 316 u, `Design_Variantes_B.md` §1.1, estimé) dont le seul coût est la difficulté qui monte (+0,15 / 0,17 / 0,20 / 0,23 de D par minute aux étages 1 à 4 en Moyen, `difficulty()`).

Ce qu'il faut viser, en termes de level design : **ne plus révéler tout le marché d'un coup, donner au moins deux moteurs d'or situés en concurrence avec les piliers, mettre une décision dans chaque relâche, et faire en sorte que la carte d'après le boss soit une autre carte** (même géométrie, autres règles). Les huit idées ci-dessous attaquent chacune une ou deux de ces causes ; aucune ne demande de nouvelle carte.

### 0.1 Règles communes aux huit idées

- **Le chemin critique reste rentable.** Un joueur qui ne fait que S → P → P → G → téléporteur ne perd rien par rapport à aujourd'hui (aucune expiration punitive, aucune hausse de prix ; le refus du Départ vif indique que le joueur ne veut pas qu'on le pousse dehors).
- **Budget d'objets constant à ±1 objet par étage.** Toute récompense nouvelle est payée en retirant ailleurs (capsules, petits coffres) ; l'arbitrage final revient à systems-designer (`economy_test`, `simulateur_scaling.py`).
- **Tout est seedé** par le générateur de l'étage (`FloorPlan`, comme les secrets) et sauvegardé dans `StageManager.to_dict()` ; le défi du jour donne la même carte à tous.
- **Lisibilité mobile** : chaque objet de carte nouveau a une silhouette ≥ 1,2 u, un accent émissif du biome (`_e.png`), une icône de minimap distincte et, s'il est temporaire, une flèche `OffscreenCues`. Plafond proposé : **6 icônes nouvelles au plus** à la fois sur la minimap (à valider avec ux-designer).
- **Perf** : aucune lumière dynamique nouvelle (émissif cuit dans les `_e`), aucun collider complexe (cercles et rectangles), toute apparition de monstres passe par les crédits du director et le plafond `MAX_ENEMIES` = 250.

---

## 1. Les huit idées

### Idée 1 · Les primes de pilier (trois petits piliers, deux suffisent)

**Ce qui change sur la carte.** `draw_rules.small_pillars` passe de 2 à 3 ; une nouvelle clé `small_pillars_required` = 2 déverrouille le gros pilier. Chaque petit pilier affiche **sa prime** avant l'activation : une icône émissive de 1 u flotte au-dessus de lui, lisible de loin et reprise sur la minimap. Trois primes, une par pilier, tirées sans remise :

| Prime | Récompense à la mort du mini-boss | Valeur visée |
|---|---|---|
| **Bourse** | pièces déposées au sol (`PickupManager.drop`) | 1,0 P |
| **Coffre** | un petit coffre gratuit posé au pied du pilier (table `petit`) | ≈ 1 P |
| **Sentier** | ouvre les deux raccourcis de la carte (idée 4) et dépose 0,4 P | ≈ 1 P en temps gagné |

Le mini-boss reste caché jusqu'à l'activation (`Design_Etages.md` §2.2) ; seule la prime est annoncée.

**Décision et route.** « Lesquels deux ? » : le plus proche, la prime qui m'arrange, ou celui qui ouvre le raccourci vers le gros pilier. Le troisième pilier reste activable **après le boss** avec une prime ×1,5 et un mini-boss au D courant : c'est le farm du post-boss, mais avec un but, un lieu et une fin.

**Effet sur le second tour.** Le post-boss devient « je fais le troisième pilier ou pas », un combat de 25 à 35 s (estimé, `simulateur_scaling.py` : 17 à 37 s par mini-boss) au lieu d'un trajet à vide.

**Chiffres.** `small_pillars` 3 (JSON de carte), `small_pillars_required` 2, `Balance.PILLAR_BOUNTY_P := {bourse: 1.0, sentier: 0.4}`, `PILLAR_BOUNTY_LATE_MULT := 1.5` (troisième pilier après le boss), espacement des piliers conservé à ≥ 18 u. Budget : +2 P par étage si deux piliers, +3,5 P si trois ; à compenser par `CAPSULES_PER_STAGE` 10 → 7 (−1,2 P) et par la relance d'or (puits existant).

**Lisibilité mobile.** Trois icônes suffisent (pièce, coffre, sentier) ; même grammaire que les icônes de coffres de la minimap. Invite du pilier : « Activer · Bourse » (≤ 24 caractères).

**Coût.** Code ≈ 1 jour (prime dans `Pillar.setup`, compteur de piliers requis dans `StageManager`, tirage de 3 piliers dans `_roll_pillars`, sauvegarde) ; Codex : 3 icônes 128 px (lot UI `low`). Aucun prop.

**Risques.** Placement : 3 petits piliers + 1 gros à ≥ 18 u les uns des autres sur des cartes qui n'en tolèrent parfois que peu (Terrasses A : 5 tirages valides seulement en 2 P + 1 G) ; repli codé : espacement 14 u pour le troisième, puis 2 piliers si impossible ; `maps_test` à étendre. Durée : un joueur qui fait toujours les trois ajoute ≈ 30 s par étage (≈ 2 min par run) : surveiller la cible 18-20 min.

**Ateliers.** Le Paratonnerre dévié reste sur le gros pilier : aucune collision. Présage possible : « Silence des piliers » (primes doublées, mais les trois piliers sont requis).

---

### Idée 2 · Le marché en trois temps (les coffres s'éveillent le long de la route)

**Ce qui change sur la carte.** Les 10 coffres sont toujours tirés à l'arrivée (même seed, même sauvegarde), mais **répartis en trois lots par distance au départ** :

| Lot | Contenu | Où | Quand il s'éveille |
|---|---|---|---|
| 0 | 4 petits | les 4 candidats les plus proches du départ (≤ 25 u en pratique) | à l'arrivée |
| 1 | 2 petits + 1 grand | les 3 suivants | à la fin du **premier** petit pilier |
| 2 | 2 petits + 1 grand (+ légendaire 25 %) | les plus lointains | à la fin du **deuxième** petit pilier |

Un coffre endormi est posé, scellé (sprite éteint, sans prix), et **absent de la minimap** ; à l'éveil il s'allume (accent émissif qui monte en 0,8 s), un son de serrure retentit, un point apparaît sur la minimap. Le prix reste celui du **D de début d'étage** (`_price_d` gelé à l'arrivée, pas à l'éveil) : attendre ne coûte rien de plus.

**Décision et route.** Le premier tour se réduit à une boucle courte autour du départ (≈ 50 u, 12 s estimé) ; ensuite le marché **avance devant le joueur**, vers les zones qu'il n'a pas encore vues. Les relâches deviennent « je passe par le lot qui vient de s'éveiller ou je vais droit au pilier suivant ».

**Effet sur le second tour.** Il ne disparaît pas tout à fait, mais il se raccourcit : le lot 2 est loin du départ, donc souvent proche du gros pilier et du téléporteur (qui se pose sous le gros pilier, `TELEPORTER_OFFSET`). Associé à l'idée 3, le retour vers les coffres du départ devient un choix explicite.

**Chiffres.** `draw_rules.chest_lots := [4, 3, 3]`, `CHEST_WAKE_FADE_S := 0.8`, aucune valeur d'or nouvelle. Gain estimé : un tour complet de 244 à 316 u devient une boucle de départ (≈ 50 u) plus des détours de 8 à 15 u par lot, soit 20 à 30 s économisées par étage.

**Lisibilité mobile.** Coffre endormi = silhouette visible mais éteinte et sans étiquette de prix : on sait qu'« il y a quelque chose », pas quoi. L'éveil est un événement lumineux et sonore ; une flèche hors écran 4 s pointe vers le coffre éveillé le plus proche.

**Coût.** Code ≈ 0,5 jour (état `sleeping` dans `chest.gd`, `interact_state` « refused » avec le libellé « Scellé », lots dans `_roll_layout`, filtre de la minimap, sauvegarde). Codex : état « scellé » du coffre (1 rendu par type, effort `low`) ; son d'éveil.

**Risques.** Un joueur qui fait ses piliers loin du départ éveille des coffres qu'il a déjà dépassés ; mitigation : le lot 1 prend les candidats les plus proches **du premier pilier terminé** parmi ceux qui restent, au lieu du rang de distance au départ (tirage au moment de l'éveil, seedé par l'index du pilier pour rester déterministe). Variante dure « un lot non acheté s'éteint à l'éveil du suivant » : **déconseillée** (punit le chemin critique, même signal que le refus du Départ vif).

**Ateliers.** La Boussole de rouille garde tout son sens (elle oriente le prochain coffre ouvert, éveillé ou non). La Matrice et le Fondoir sur une case `E` sont visibles dès l'arrivée : ils deviennent le seul repère d'intérêt lointain au début, ce qui renforce leur rôle.

---

### Idée 3 · Le Dernier marché (rapatrier les coffres au téléporteur)

**Ce qui change sur la carte.** Après la mort du boss d'étage, le téléporteur propose une seconde action (« Dernier marché », appui court ; « Partir » reste le maintien de 0,6 s). Un panneau figé liste les **coffres non achetés** de l'étage (petits et grands ; le légendaire est exclu : il faut aller le chercher) avec leur prix majoré. Un coffre rapatrié disparaît de la carte (étincelles qui filent vers le téléporteur) et s'ouvre comme d'habitude, dans `ChestUI`.

**Décision et route.** Le second tour devient un **arbitrage explicite** : marcher 40 à 70 s (estimé) avec D qui monte et la foule autour, ou payer 25 % de plus sans bouger. Le joueur pressé paie, le joueur qui farme marche (et gagne l'or des kills en route).

**Effet sur le second tour.** Il devient **facultatif**. C'est le correctif le plus direct de l'ennui décrit par le joueur.

**Chiffres.** `Balance.TELEPORTER_RECALL_PRICE_MULT := 1.25` (plage sûre 1,15-1,40 ; sous 1,15 personne ne marche plus, au-delà de 1,40 personne ne rapatrie) ; `TELEPORTER_RECALL_KINDS := [&"petit", &"large"]`. Exemple étage 3 : 3 petits restants = 3 × 207 = 621 or à pied, 776 or au téléporteur ; l'écart (155 or ≈ 0,75 P) se gagne en ≈ 60 à 90 s de kills au rythme de l'audit (1,0-1,2 kill/s), soit à peu près le temps du trajet : l'arbitrage est réel, aucune option ne domine.

**Lisibilité mobile.** Le téléporteur a déjà une invite ; elle devient double (« Dernier marché » / « Partir », `interact_priority` : marché d'abord tant qu'il reste un coffre). Panneau : une rangée d'icônes de coffres avec prix et distance (« 32 u ») pour que le joueur juge le trajet.

**Coût.** Code ≈ 1 jour (action secondaire du téléporteur, panneau liste, retrait du coffre de la carte, sauvegarde). Codex : aucun prop ; 1 son de rapatriement.

**Risques.** La carte peut sembler « vide » après le boss si personne ne marche plus : c'est pourquoi l'idée 8 (Front d'averse) est proposée en paire, pour qu'aller sur la carte paie. ux-designer à consulter pour la double action (tactile, manette).

**Ateliers.** L'Enclume (étage 5 et 20 % des étages 1-4) devient la concurrente naturelle du Dernier marché pour l'or de fin d'étage : un rare choisi à l'Enclume ou trois petits rapatriés. Aucun conflit avec le Fondoir ou la Matrice.

---

### Idée 4 · Les passages (raccourcis à ouvrir d'un seul côté)

**Ce qui change sur la carte.** Deux **passages fermés** par carte (vanne, pont-levis, grille ou éboulis selon le biome) sur des goulets qui couperaient une boucle. Le passage s'ouvre **depuis le côté lointain** par « interagir » sur un treuil (portée 1,5 u, comme le levier des secrets), ou d'un coup par la prime Sentier (idée 1). Une fois ouvert, il le reste. Le chemin critique ne passe jamais par un passage fermé.

Exemple chiffré, Rizières hautes (`terrasses_rizieres_hautes`, grille `Design_Variantes_B.md` §2.1) : les deux escaliers de l'axe central (colonnes 11-12, rangées 13 et 26) deviennent des vannes fermées ; on monte par les escaliers latéraux (3-4 / 19-20 en rangée 26, 2-3 / 20-21 en rangée 13), qui font serpenter le joueur. Treuils côté nord : (25 ; 25) et (25 ; 51) u. Une fois ouvertes, le retour T1 → T5 par l'axe gagne ≈ 20 à 40 u par trajet (5 à 10 s, estimé).

**Décision et route.** Le joueur apprend la carte : « si je monte d'abord par l'ouest, j'ouvre la vanne et mon retour vers les coffres du départ est deux fois plus court ». Les boucles à sens unique sont l'outil classique pour transformer un aller-retour en circuit (voir Sources : niveaux reliés par des raccourcis dans Dark Souls).

**Effet sur le second tour.** Il devient plus court et passe par un autre chemin que l'aller ; associé au Dernier marché, il est l'option « marcher » rendue moins coûteuse par la connaissance de la carte.

**Chiffres.** `shortcuts` (nouvelle clé de carte) : `[{"cells": [[11,13],[12,13]], "winch_u": [25,25], "skin": "vanne"}]` ; 2 par carte ; gain visé 15 à 40 u par passage (mesure Dijkstra à ajouter au script de `Design_Variantes_B.md` §1.1). Aucune valeur d'or.

**Lisibilité mobile.** Côté fermé : barreaux et accent émissif éteint, invite « S'ouvre de l'autre côté » si le joueur insiste à 1,5 u ; côté treuil : accent émissif qui pulse. Minimap : trait de porte en couleur de mur tant que fermé, en couleur de sol une fois ouvert.

**Coût.** Code ≈ 1 jour : généraliser la porte `D` des secrets (collision séparée déjà codée) en un caractère `R` « passage », le treuil réutilise `secret_lever.gd` ; **`NavField` et `reach_field()` doivent être recalculés** à l'ouverture (apparitions et capsules). Codex : 1 prop par biome (vanne, pont de racines, grille de fonderie, éboulis de sel), 2 états, ombre cuite `_shadow.png`, effort `low` (4 props, un lot). Level design : 2 passages × 8 cartes à placer à la main.

**Risques.** Confusion avec les secrets : les passages sont **toujours visibles et jamais gardés** (les secrets sont scellés, cachés, gardés) ; teintes différentes. Monstres bloqués d'un côté : une apparition atteignable avant l'ouverture doit l'être aussi après (le test `reachable_spawn_test` devra tourner « fermé » et « ouvert »).

**Ateliers.** Aucun conflit. Un atelier sur une case `E` placée juste derrière un passage devient une petite récompense de connaissance de la carte (règle de placement à appliquer quand les ateliers seront posés).

---

### Idée 5 · Les foyers (nids destructibles qui gardent un coffre enchaîné)

**Ce qui change sur la carte.** Deux **foyers** par étage, posés sur des candidats dédiés (`candidates.nests`, dans des zones ouvertes de 12 u au moins, à ≥ 15 u des piliers et du départ). Un foyer est une structure fixe (habillage par biome : jarre de vase, cocon de mycélium, chaudière fêlée, ossuaire grouillant) qui **s'éveille** quand le joueur entre à 14 u, puis fait sortir un paquet de monstres toutes les 6 s. Chaque sortie est télégraphiée (glyphe au sol, 0,8 s). Une chaîne de bronze le relie à un **petit coffre gratuit** posé à 3 u : détruire le foyer libère le coffre.

Le foyer **mûrit** avec le temps d'étage : à 90 s puis à 180 s, +30 % de PV et +1 monstre par sortie (au plus 2 crans). Le joueur a donc une raison de le faire **tôt**, en concurrence directe avec le rush des piliers.

**Décision et route.** « Je fais le foyer sur la route du pilier A tant qu'il est jeune, ou je file au pilier et je le retrouverai mûr. » Pendant qu'il est éveillé, sa zone donne les crédits d'un petit pilier : c'est un **second moteur d'or situé**, plus court qu'un pilier et sans mini-boss.

**Effet sur le second tour.** Un foyer laissé de côté reste un objectif identifié après le boss (au cran 2), avec son coffre gratuit : le retour sur la carte a une cible de combat, pas seulement des achats.

**Chiffres.** `draw_rules.nests := 2` ; `NEST_HP_MINI_SHARE := 0.25` (PV = 0,25 × `boss_hp(&"mini", D, étage)`, soit ≈ 8 à 10 s de DPS concentré au rythme du simulateur) ; `NEST_WAKE_RADIUS_U := 14.0` ; `NEST_PULSE_S := 6.0` ; `NEST_PULSE_SIZE := [3, 5]` monstres de tier 1 ; `NEST_MATURE_AT_S := [90.0, 180.0]`, `NEST_MATURE_HP_MULT := 1.3`, `NEST_MATURE_PULSE_ADD := 1` ; `ZONE_SPAWN_MULT[&"nest"] := 1.5` (rayon 8 u, comme le petit pilier). Budget : 2 coffres gratuits, compensés par `small_chests` 8 → 7 (net +1 objet, −1 P de dépense par étage).

**Lisibilité mobile.** Silhouette 1,8 u, accent émissif qui bat au rythme des sorties ; la chaîne vers le coffre se lit à 6 pouces (diagonale claire sur sol sombre). Icône de minimap « nid » ; barre de PV au-dessus (`overhead_bars.gd`).

**Coût.** Code ≈ 1,5 jour (classe `Nest` : PV, réveil, sorties via le director, mûrissement, chaîne qui libère le coffre, sauvegarde) ; Codex : 1 modèle de foyer décliné par matière (4 rendus, 3 états : dormant / actif 8 images / détruit), 1 chaîne, ombre cuite, effort `low` ; 2 sons (pulsation, effondrement). Level design : 3 à 4 candidats `nests` par carte.

**Risques.** Perf : un foyer réveillé ne crée pas de monstres hors budget (il **déplace** les crédits du director, plafond 250 inchangé) ; il dort hors des 14 u. Aucune ressemblance avec un mini-boss : pas de sorts, pas de phase, seulement des sorties télégraphiées. Gel des boss respecté.

**Ateliers.** Si l'étage a un Fondoir, un des deux foyers peut garder **1 scorie** au lieu d'un coffre (seule interaction proposée, optionnelle). Présage possible : « Éveil des élites » fait sortir une élite à chaque pulsation du foyer mûr.

---

### Idée 6 · Le Glaneur (porteur de butin qui fuit à travers la carte)

**Ce qui change sur la carte.** Deux fois par étage, une petite créature non hostile (1,2 u, un ballot d'or volé sur le dos) apparaît sur un repère lointain et **court un trajet fixe** de la carte vers un terrier. Moments : 20 s après la fin du premier petit pilier, et 10 s après la mort du boss d'étage. Annonce : cri aigu, point mobile sur la minimap, flèche hors écran ; le terrier d'arrivée est **visible** sur la minimap dès l'apparition, pour qu'on puisse couper la route.

Comportement : 3,0 u/s en course (moins que le joueur, 4,0) ; si le joueur passe à moins de 7 u, sprint à 4,6 u/s pendant 2,5 s puis **essoufflé** 1,5 s (immobile, gouttes de sueur : fenêtre de frappe) ; il disparaît dans le terrier au bout de 40 s s'il n'est pas tué. Chaque coup lui fait perdre quelques pièces ; sa mort lâche le ballot.

**Décision et route.** Poursuivre maintenant (quitter la ligne du pilier B) ou l'intercepter plus loin grâce aux passages ouverts : c'est une **lecture de la carte**, pas un test de DPS. Après le boss, c'est un objectif mobile qui traverse la carte et donne une raison d'y retourner.

**Effet sur le second tour.** Le post-boss commence par une poursuite de 20 à 40 s (estimé) qui emmène le joueur à travers la carte, devant les coffres restants : le second tour devient un trajet **orienté par une cible**.

**Chiffres.** `GLEANER_PER_STAGE := 2`, `GLEANER_SPAWN_AFTER := [{"event": "first_small_pillar", "delay_s": 20}, {"event": "floor_boss_dead", "delay_s": 10}]`, `GLEANER_SPEED_U := 3.0`, `GLEANER_SPRINT_U := 4.6`, `GLEANER_SPRINT_S := 2.5`, `GLEANER_TIRED_S := 1.5`, `GLEANER_FLEE_TRIGGER_U := 7.0`, `GLEANER_LIFETIME_S := 40.0`, `GLEANER_HP := 12 × PV d'un essaim au D courant` (≈ 4 à 6 coups d'un build moyen), `GLEANER_GOLD_P := 1.0` (dont 0,3 P lâchés par coups). Trajet : `fugitive_paths` dans le JSON de carte (3 à 5 points de passage, 35 à 55 u de long, au moins une rive ou un passage). Budget : +2 P par étage, compensé par `CAPSULES_PER_STAGE` (voir §2).

**Lisibilité mobile.** Couleur d'accent du biome très saturée sur le ballot (le seul objet mobile qui luit en or), contour lumineux (règle des pickups). Le Glaneur ne passe jamais sous un occulteur (trajet hors des murs fondus).

**Coût.** Code ≈ 1 jour (IA simple de suivi de chemin, fuite, essoufflement, sortie par le terrier ; réutilise `Enemy` sans attaque) ; Codex : **une créature** (1,2 u, course 8 directions, sprint, essoufflé, mort ; effort `low`) + 1 terrier par biome (ou un seul trou générique) ; 3 sons. C'est l'idée la plus chère en assets.

**Risques.** Gel des boss : ce n'est ni un boss ni un mini-boss (aucun sort, aucune phase, aucune attaque), mais c'est une **créature nouvelle** : à valider par le joueur (§5). Frustration si on le rate : la perte est limitée à 1 P et l'arrivée est annoncée ; un Glaneur raté ne pénalise pas l'étage suivant.

**Ateliers.** Aucun conflit. Présage possible : « Marée » (le Glaneur court sur les rives et laisse une piste de pièces).

---

### Idée 7 · Les sillons de braises (récompenses de parcours en chaîne)

**Ce qui change sur la carte.** Deux **sillons** par étage : des lignes de 10 braises au sol, espacées de 1,5 u (15 u de long), posées sur des chemins **optionnels** : bouts de couloir, rives, contre-allées, abords des passages et des foyers. Ramassées au contact (comme les pièces). Ramasser la braise suivante moins de 2,5 s après la précédente fait monter un multiplicateur (+10 % par braise en chaîne) ; le son monte d'un demi-ton à chaque braise. La fin du sillon pointe toujours vers quelque chose : un coffre, un treuil, un foyer ou une case `E`.

**Décision et route.** Petites lignes directrices visibles de loin (« leading lines ») qui tirent le joueur hors du chemin critique vers ce qui vaut le détour ; une compétence de déplacement (garder la chaîne au milieu de la foule) dans les relâches.

**Effet sur le second tour.** Les sillons sont à usage unique : ils rendent le **premier** passage plus riche et marquent les chemins à reprendre au retour (un sillon ramassé laisse une trace de cendre 60 s, lisible comme « déjà fait »).

**Chiffres.** `draw_rules.trails := 2` ; `TRAIL_EMBERS := 10`, `TRAIL_SPACING_U := 1.5`, `TRAIL_CHAIN_WINDOW_S := 2.5`, `TRAIL_CHAIN_STEP := 0.10`, `TRAIL_FULL_P := 0.8` (valeur d'un sillon parfait : base b = 0,8 P / 14,5 ≈ 0,055 P par braise ; sillon sans chaîne ≈ 0,55 P). Deux sillons parfaits = 1,6 P par étage, compensés par `CAPSULES_PER_STAGE` 10 → 6 (−1,6 P). Polylignes dans `trails` (nouvelle clé de carte, 3 à 4 candidats par carte, 2 tirés).

**Lisibilité mobile.** Braise de 0,4 u, émissive (`_e`), sans lumière dynamique ; la ligne entière se voit d'un écran. Le multiplicateur s'affiche en petit chiffre au-dessus du joueur (« ×1,6 »), 1 s.

**Coût.** Code ≈ 0,5 jour (pickup de chaîne, minuterie, placement, sauvegarde des braises restantes). Codex : 1 sprite de braise (4 images) + trace de cendre (décalque), 1 son modulé en hauteur par le système audio. Level design : 3 à 4 polylignes × 8 cartes.

**Risques.** Les rayons de ramassage élevés (objets d'aimant) rendent la chaîne triviale : c'est acceptable (récompense de build). Un sillon ne traverse jamais une zone de pilier active (sinon la chaîne se casse dans un combat obligé).

**Ateliers.** Aucun conflit. Présage possible : « Nuit sans lanterne » (sillons ×2, capsules ×0).

---

### Idée 8 · Le Front d'averse (après le boss, la carte se retourne)

**Ce qui change sur la carte.** À la mort du boss d'étage, une **averse** naît au point praticable le plus éloigné du téléporteur et s'étend en disque (0,35 u/s) ; elle s'arrête quand son bord arrive à 14 u du téléporteur (la zone de départ reste calme, toujours). Dans l'averse :

- crédits du director ×1,75 (`ZONE_SPAWN_MULT[&"averse"]`) et chance d'élite +5 points ;
- or des kills ×1,5 ;
- coffres non achetés à **−25 %** (« soldes d'averse ») ;
- aucun dégât de terrain, aucun ralentissement : la menace, ce sont les monstres.

**Décision et route.** Avec le Dernier marché (idée 3), le post-boss devient un vrai dilemme à trois branches : **partir** tout de suite ; **rapatrier** les coffres à +25 % sans bouger ; **razzier** l'averse pour acheter à −25 % et gagner l'or ×1,5, au prix du danger et de D qui monte. Le joueur fort part en razzia, le joueur prudent rapatrie, le joueur pressé part : trois profils, aucune option dominante (Sirlin : la difficulté choisie paie, le débutant n'y perd rien).

**Effet sur le second tour.** Il **change de nature** : ce n'est plus un trajet à vide, c'est l'incursion la plus intense de l'étage, en dents de scie après la relâche du boss (relâche de 10 à 15 s le temps que le front avance, puis remontée volontaire).

**Chiffres.** `STORM_FRONT_SPEED_U_S := 0.35` (un front parti à 50 u du téléporteur s'arrête après ≈ 100 s), `STORM_FRONT_STOP_U := 14.0`, `ZONE_SPAWN_MULT[&"averse"] := 1.75` (sous le gros pilier, 2,33), `STORM_GOLD_MULT := 1.5`, `STORM_CHEST_PRICE_MULT := 0.75`, `STORM_ELITE_ADD := 0.05`. Le coffre de boss, gratuit, n'est pas concerné ; le légendaire l'est (c'est la carotte de la razzia).

**Lisibilité mobile.** Bord du front = anneau au sol sur la couche des télégraphes (palette « menace d'ambiance », jamais le rouge des attaques) ; **quand le joueur est dedans**, la pluie globale passe à ×1,6 et l'étalonnage se fonce de 8 % (un seul réglage global commuté selon la position du joueur, pas de lumière ni de calque régional). Les coffres soldés affichent leur prix barré. La minimap teinte la zone d'averse.

**Coût.** Code ≈ 1,5 jour (zone qui grandit dans le `Director`, multiplicateurs, prix soldés dans `chest.gd`, commutation de l'ambiance, sauvegarde du rayon) ; Codex : texture de bord d'averse (bande de pluie au sol, 1 rendu tuilable) et son de rideau de pluie en boucle (lot audio). Aucun prop.

**Risques.** Si les soldes et l'or ×1,5 rendent la razzia toujours rentable, tout le monde la fait (retour au double tour, juste plus dur) : surveiller par télémétrie (`RunLog` : razzia, rapatriement, départ direct ; cible 30-50 % de razzias). Pression cumulée avec Paratonnerre dévié et Glaneur 2 : l'averse naît **après** la mort du boss, jamais pendant. À la Source (étage 5), pas d'averse (étage final, arène unique).

**Ateliers.** Le Paratonnerre dévié (boss affixé) précède l'averse : aucun cumul. Présage possible : « Pluie de cendres » (averse dès la fin du deuxième petit pilier).

---

## 2. Budget d'or et de temps (estimé, à valider par systems-designer)

| Idée | Or ou objets ajoutés par étage | Compensation proposée | Temps d'étage |
|---|---|---|---|
| 1 Primes de pilier | +2 P (2 piliers), +3,5 P (3) | capsules 10 → 7 (−1,2 P) | 0 s, +30 s si troisième pilier |
| 2 Marché en trois temps | 0 | aucune | −20 à −30 s |
| 3 Dernier marché | −0,25 P par coffre rapatrié (puits) | aucune | −40 à −70 s si rapatriement |
| 4 Passages | 0 | aucune | −10 à −20 s |
| 5 Foyers | +1 objet net, +or de zone | petits coffres 8 → 7 | +15 à +25 s |
| 6 Glaneur | +2 P max | capsules (avec l'idée 7) | +10 à +30 s |
| 7 Sillons | +1,6 P max | capsules 10 → 6 | +5 s |
| 8 Front d'averse | or ×1,5, coffres −25 % (si razzia) | aucune (prise de risque) | 0 à +60 s (choix) |

Si les huit idées sont produites, les capsules passent de 10 à 4 (−2,4 P) pour couvrir primes, Glaneur et sillons ; l'or n'est plus semé, il est **placé**. Durée nette par étage : de −40 s (joueur pressé : passages, rapatriement) à +60 s (joueur qui fait tout), autour de la cible de 3,8 à 4,2 min ; la run reste dans 18-20 min pour le profil médian.

---

## 3. Courbe d'intensité proposée (étage type, estimé)

| Temps | Aujourd'hui | Proposé | Intensité proposée |
|---|---|---|---|
| 0:00-0:25 | achats (tour 1, 40 s) | lot 0 autour du départ, premier sillon | basse, montée |
| 0:25-0:55 | pilier A | pilier au choix parmi 3 (prime visible) | **pic 1** |
| 0:55-1:20 | trajet vide | lot 1 éveillé devant, Glaneur 1, foyer jeune à portée | moyenne (décision) |
| 1:20-1:50 | pilier B | second pilier | **pic 2** |
| 1:50-2:15 | trajet vide | lot 2, passage à ouvrir, second foyer ou sillon | moyenne-basse |
| 2:15-3:35 | gros pilier + boss | inchangé (Paratonnerre dévié en option) | **pic 3** |
| 3:35-3:50 | tour 2 (40-70 s, vide) | relâche : coffre de boss, front qui naît | basse |
| 3:50-4:30 | téléporteur | partir, rapatrier, ou razzia dans l'averse + Glaneur 2 + troisième pilier | **pic 4 optionnel** ou départ |

Dents de scie tenues : jamais deux pics sans relâche ; le pic 4 est le seul choisi par le joueur.

---

## 4. Classement et recommandation

| Rang | Idée | Cause attaquée (§0) | Code | Assets Codex | Rapport effet / coût |
|---|---|---|---|---|---|
| **1** | **Idée 1 · Primes de pilier (2 sur 3)** | 3, 4, 5 | 1 j | 3 icônes | très haut : casse le rush, aucun prop |
| **2** | **Idée 3 · Dernier marché + idée 8 · Front d'averse** (en paire) | 2, 5 | 2,5 j | 1 texture, 2 sons | très haut : le second tour devient facultatif ou intense |
| **3** | **Idée 5 · Foyers et coffres enchaînés** | 3, 4 | 1,5 j | 1 prop × 4 matières | haut : second moteur d'or situé, du contenu dans les relâches |
| 4 | Idée 2 · Marché en trois temps | 1, 2 | 0,5 j | état scellé du coffre | haut, mais à jouer avant de juger (perte d'information) |
| 5 | Idée 4 · Passages | 5 | 1 j + 16 placements | 4 props | moyen ; prend toute sa valeur avec 1 et 3 |
| 6 | Idée 7 · Sillons de braises | 4 | 0,5 j + polylignes | 1 sprite | moyen, très bon marché |
| 7 | Idée 6 · Glaneur | 4, 5 | 1 j | 1 créature + terrier | haut en fun, cher, à valider (créature nouvelle) |

**(Recommandé)** : produire d'abord **idée 1 + idée 3**, ensemble (≈ 2 jours de code, 3 icônes, zéro prop), puis jouer 5 runs et lire la télémétrie (`RunLog` : piliers faits, primes choisies, coffres rapatriés, temps du second tour). Ensuite **idée 8** si le post-boss paraît vide, et **idée 5** pour remplir les relâches. Les idées 2, 4, 6 et 7 suivent, dans cet ordre, en fonction du quota Codex.

### 4.1 Ce qu'il ne faut pas faire

1. **Pas de coffre qui expire** sur une minuterie ni de lot qui s'éteint : cela punit le chemin critique (signal du refus du Départ vif).
2. **Pas de prix qui montent après le boss** : même raison ; l'averse donne des soldes, elle ne taxe pas.
3. **Pas d'arène qui se referme** (portes qui piègent le joueur autour d'un foyer ou d'un pilier) : règle « pas de mort instantanée » et lisibilité caméra.
4. **Pas de dégât de terrain** dans l'averse ni dans les foyers : la menace vient des monstres télégraphiés.
5. **Pas plus de 6 icônes nouvelles** simultanées sur la minimap ; pas plus de deux événements mobiles (Glaneur, front) à la fois.
6. **Pas d'idée à la Source** sauf le Dernier marché (si l'Enclume y est, les deux coexistent) : l'étage final reste une arène lisible.

---

## 5. Données, contrats et tests à prévoir (pour l'orchestrateur)

- **Cartes `data/maps/<id>.json`** : `draw_rules.small_pillars` 3 et `small_pillars_required` 2 ; `draw_rules.chest_lots` ; `draw_rules.nests`, `draw_rules.trails` ; `candidates.nests` ; `shortcuts` (cellules `R`, treuil, habillage) ; `trails` (polylignes) ; `fugitive_paths`. `tools/gen_maps.py` doit recopier ces clés (comme `secrets`).
- **`Balance`** : `PILLAR_BOUNTY_P`, `PILLAR_BOUNTY_LATE_MULT`, `CHEST_WAKE_FADE_S`, `TELEPORTER_RECALL_PRICE_MULT`, `TELEPORTER_RECALL_KINDS`, `NEST_*`, `ZONE_SPAWN_MULT[&"nest"]`, `GLEANER_*`, `TRAIL_*`, `STORM_*`, `ZONE_SPAWN_MULT[&"averse"]`, `CAPSULES_PER_STAGE` révisé.
- **`Events`** : `pillar_bounty_granted(kind)`, `chest_lot_woken(lot)`, `chest_recalled(kind, price)`, `shortcut_opened(id)`, `nest_destroyed(stage_time)`, `gleaner_caught(caught: bool)`, `trail_finished(chain)`, `storm_front_started()`.
- **`StageManager.to_dict()`** : prime de chaque pilier, état des lots, passages ouverts, PV et cran des foyers, braises restantes, état du Glaneur, rayon du front.
- **Mode test** (panneau TAB) : forcer une prime, éveiller tous les lots, ouvrir les passages, invoquer un foyer, un Glaneur, lancer le front.
- **Tests** : `maps_test` (3 petits piliers plaçables sur les 8 cartes, candidats `nests`, `trails` et `shortcuts` valides), `reachable_spawn_test` passages fermés **et** ouverts, `stage_test` (piliers requis = 2, troisième activable après le boss, lots éveillés dans l'ordre, sauvegarde aller-retour), `economy_test` (or par étage avec capsules réduites), `boss_pace_test` (durée d'étage avec un troisième pilier).
- **Consultants à croiser** : systems-designer (valeurs en P, compensation des capsules, multiplicateurs de l'averse) ; ux-designer (double action du téléporteur, panneau du Dernier marché, plafond d'icônes de minimap, invite « S'ouvre de l'autre côté ») ; game-designer (le Glaneur au regard du gel des boss, cohérence avec les Présages).

### 5.1 Questions pour le joueur

1. **Trois petits piliers dont deux requis** : d'accord pour changer cette règle d'étage (le troisième devient le farm du post-boss) ?
2. **Le Glaneur** est une créature nouvelle, non hostile, sans sort : le gel des boss l'autorise-t-il ?
3. **Front d'averse** : d'accord pour que la carte devienne plus dangereuse après le boss (sans jamais pousser dehors ni taxer) ?
4. **Dernier marché** : majoration de 25 % par coffre rapatrié, légendaire exclu : d'accord sur le principe ?

---

## Sources

- Raccourcis et boucles qui réduisent les allers-retours : [Game Developer, « Cutting through the fog of Dark Souls »](https://www.gamedeveloper.com/design/cutting-through-the-fog-of-dark-souls-part-one-) ; [Game Wisdom, critique du level design de Dark Souls 2 (raccourcis contre retours en arrière)](https://game-wisdom.com/?p=8698) ; [« Looping paths and directional influence »](https://rpgarticles.blogspot.com/2018/08/looping-paths-and-directional-influence.html) ; [TheGamer, niveaux reliés de Dark Souls](https://www.thegamer.com/dark-souls-1-fromsoftwares-magnum-opus-of-interconnected-level-design/).
- Récompense annoncée avant le choix de route (principe des primes de pilier) : [Shacknews, symboles des portes de Hades](https://shacknews.com/article/122186/door-symbol-meanings-hades) ; [notes sur les salles et chemins de Hades](https://saschb2b.github.io/game-mechanics/games/hades/chamber-and-paths).
- Cadres internes : `docs/Propositions_Boucle_Interactions.md` (§1.3 diagnostic de la méso-boucle, §2.0 règles des ateliers), `docs/Design_Variantes_B.md` §1.1 (longueurs de tour mesurées), `game/scripts/core/balance.gd` (difficulté, or des kills et des boss, `ZONE_SPAWN_MULT`).
