# Propositions : boucle de gameplay et interactions de carte (design v1)

> Statut : **avis de game design** (Fable, game-designer, 01/11/2026), sur demande du joueur : « imagine une manière d'améliorer la boucle de gameplay, et les ajouts possibles d'interactions (sur RoR2 nous avons par exemple les scrappers qui permettent de scrap un item d'une rareté pour ensuite utiliser ce scrap sur une imprimante) ». Aucun fichier de `game/` n'est modifié ; rien n'est implémenté.
> Lu avant d'écrire : `CLAUDE.md` (Décisions), `docs/GDD.md`, `docs/Maths_Scaling.md` (§1-2, §7-9, §11, §14), `docs/Items_Catalog.md`, `docs/Design_Etages.md`, `docs/Design_Variantes_B.md` (§9-12 secrets), `docs/Design_Zones_Secretes.md` (§2 catalogue), `docs/Design_Boss_Cartes.md` §4.4 (événements de carte), `docs/Design_Combos.md`, `docs/Audit_Runs_Completes_2026-10-31.md`, `game/scripts/core/balance.gd`, `run_state.gd`, `loot/chest.gd`, `loot/loot_roller.gd`, `stage/pillar.gd`, `stage/exit_teleporter.gd`, `stage/stage_manager.gd`, `data/items.json`, `data/floors.json`, `data/maps/*.json`.
> Contraintes respectées : gel des boss (aucun nouveau boss ; une proposition touche seulement l'**affixe** du boss d'étage existant), PC + Android + iOS (toute interaction par l'action « interagir », jamais au contact, télégraphes ≥ 0,8 s), aucune monétisation agressive (aucune pub ni achat dans ce document), aucun nom ni design repris de Risk of Rain ou de Vampire Survivors. Toute valeur chiffrée est proposée pour `Balance` (`game/scripts/core/balance.gd`) ou un JSON de `game/data/` : constante nommée à créer, jamais en dur.
> Unités : 1 u = 64 px ; **P** = prix courant d'un petit coffre, `Balance.chest_price(&"petit", D, étage)` (D figée à l'apparition), ≈ 50 / 112 / 207 / 348 / 549 or aux débuts des étages 1 à 5 au rythme visé de 19 min en Moyen (calcul à partir de `CHEST_BASE`, `difficulty()` et `CHEST_PRICE_STAGE` ; estimation, non mesurée en jeu).

Sommaire : 1. Diagnostic de la boucle actuelle · 2. Neuf interactions et objets de carte · 3. Trois améliorations structurelles · 4. Classement, ordre de production, ce qu'il ne faut pas faire · 5. Contrats et tests à prévoir.

---

## 1. Diagnostic de la boucle actuelle

### 1.1 Ce qui existe en jeu (code) et ce qui n'existe qu'en design

| Interaction | État | Source |
|---|---|---|
| Coffres payants (8 petits, 2 grands, légendaire 25 %), d100 en roue de rareté, 2 cartes, relance (or ou pub/pass, 1 par coffre) | **codé** | `loot/chest.gd`, `chest_session.gd`, `ui/chest/chest_ui.gd`, `CHEST_QUALITY_TABLE` |
| Coffre de boss gratuit (table `boss`), reliquaires de secret (table `guardian`) | codé | `balance.gd` |
| Capsules d'argent (10 par étage, 20 or × D^1,25, action interagir) | codé | `loot/gold_capsule.gd` |
| Petits piliers (mini-boss) et gros pilier (boss + charge 60 s), paratonnerre-mère de la Source | codé | `stage/pillar.gd` |
| Téléporteur par maintien de 0,6 s (`UI_EXIT_HOLD_S`), or restant converti en XP à 0,25 XP par or (`GOLD_TO_XP_SHARE`) | codé | `stage/exit_teleporter.gd`, `stage_manager.gd` |
| Secrets (1 run sur 3, étage 1-4, 4 déclencheurs : plaques, levier, mur fissuré, pilier éteint ; 2 gardiens ; 2 reliquaires) | codé | `stage/secret_*.gd`, `SECRET_*` |
| Défi du jour, succès, rubis de fin de run (`rubies_for_run`), déblocages de personnages et de variantes | codé | `meta/*.gd`, `save/profile.gd` |
| **Événements de carte** (Autel de fortune, Sanctuaire de risque, Marchand de l'ombre, Coffre piégé) : 3 cases `E` par carte, `events.chance` 0,6, habillages par biome | **design seulement**, aucun script ne lit `E` ni `events` | `Design_Boss_Cartes.md` §4.4, `data/maps/*.json` |
| Catalogue des secrets (écluse, veillée des lanternes, treuil, porte-clé, stèle de défi, coffre-horloge, autel de la pluie) | design seulement (sauf la porte scellée) | `Design_Zones_Secretes.md` §2 |
| Combos de kits (préparer → encaisser) | design, en cours | `Design_Combos.md` |

Constat de base : **toutes les interactions codées sont des interactions « ouvrir » ou « activer »**. Aucune ne demande au joueur d'arbitrer entre deux objets qu'il possède, aucune ne retire, ne convertit ni ne cible un objet. L'inventaire ne se lit que dans un sens : il grossit.

### 1.2 Micro-boucle (30 s) : saine, pas de temps mort, mais une seule décision

Mesures de `Audit_Runs_Completes_2026-10-31.md` §2.2 : essaim fauché en ≤ 2 coups à 86 % (étage 1) et 69 % (étage 4) ; tireur 6-10 coups ; brute 26-41 coups ; 8-10 monstres vivants en moyenne, 1,0-1,2 kill/s. Le rythme visé (paquets de 3-8, déplacement rapide) est tenu. Sur mobile le sort 1 est automatique et les sorts 2-4 visent seuls : la décision de la micro-boucle est **où je me place**, et bientôt **quand j'encaisse** (combos). Rien à changer ici ; les propositions ci-dessous ne doivent **pas** ajouter de bouton ni de canalisation immobile.

### 1.3 Méso-boucle (un étage, ≈ 4 min) : deux creux et un faux choix

Rythme estimé (`Design_Variantes_B.md` §2.4, `Audit` §4.2) : 0:00-0:40 achats · 0:40-1:10 pilier A (pic) · 1:10-1:35 relâche · 1:35-2:05 pilier B (pic) · 2:05-2:30 relâche · 2:30-3:50 gros pilier 60 s + boss ≈ 70 s (pic) · ensuite farm libre, téléporteur.

- **Creux 1 et 2 (relâches de 25 s)** : trajet vers le pilier suivant, deux ou trois coffres en route. Le joueur n'y prend aucune décision : il traverse. Les cases `E` sont posées précisément là (une par tiers de carte), mais vides.
- **Phase post-boss** : « rester farmer ou partir » est un faux choix (Deci et Ryan : un choix dominé n'alimente pas l'autonomie). Rester est presque toujours bon : les prix sont figés, l'or coule, la seule contrepartie est D qui monte de ≈ +0,15 par minute (`TIME_SLOPE × TIME_COMPRESSION × MODES`). Partir ne donne rien de plus que « moins de D », et l'or restant n'est converti qu'à 0,25 XP par or. Il manque une **raison de partir vite** et une **raison de rester qui soit un pari**.
- **Or excédentaire en fin de run** : l'audit mesure 3 632 / 8 563 / 10 410 or gagnés aux étages 3 / 4 / 5 (runs longues de 32-40 min, donc surévalué ; au rythme de 19 min, comptez le tiers). Même divisé par trois, 10-11 coffres à ≈ 12 P par étage ne consomment pas tout : après les coffres, **l'or n'a plus de puits** sauf la relance (0,6 P × 1,5^n) et la conversion en XP.

### 1.4 Macro-boucle (la run, 18-20 min) : un build qu'on subit

- Répartition mesurée (audit §2.1, bot qui achète dès qu'il peut) : **51 objets** en fin d'étage 4, dont ≈ 37 communs, 13 peu communs, 1,3 rare, 0 légendaire. Les tables RoR2 (`petit` 78/20/2, `large` 80/18/2) font du build une pile de communs ; l'audit de valeur fixe 1 commun = 10 points, 1 peu commun = 22, 1 rare = 50, 1 légendaire = 120. Autrement dit, 70 % des objets apportent 10 points chacun, et le joueur ne choisit que « A ou B » entre deux cartes.
- Leviers d'agentivité existants : poids ×0,6 pour un objet déjà possédé, ×1,3 pour un tag du build (`LootRoller.OWNED_WEIGHT`, `BUILD_TAG_WEIGHT`), Chance (Faveur du marchand, Trèfle à 5 feuilles : relances du d100). Tous **passifs** : le joueur ne décide jamais « je veux davantage de Sifflet » ou « je n'ai que faire de cette Fiole verte ».
- Conséquence sur le pilier 2 du GDD (« builds lisibles : le joueur comprend pourquoi il est fort ») : il comprend, mais il n'y est pour rien. Esthétique MDA manquante : **Expression** (le build comme signature) ; esthétique bien servie : Sensation et Défi.

### 1.5 Méta : des raisons de revenir, pas des raisons de rejouer la run

Rubis, déblocages de personnages et de variantes, défi du jour, succès : la rétention est pensée (GDD §11). Mais rien **dans** la run ne crée une histoire à raconter (« j'ai tout fondu pour empiler des Lames jumelles », « j'ai pris le pari du boss affixé et je l'ai eu »). Les propositions 2.1-2.4 et 3.1-3.2 visent cela.

### 1.6 Résumé du diagnostic

| Boucle | Manque | Propositions |
|---|---|---|
| 30 s | rien (ne pas toucher) | aucune |
| Étage | deux relâches vides ; post-boss sans dilemme ; cases `E` inutilisées | 2.8 Brasero, 2.9 Paratonnerre dévié, 3.3 Départ vif, ateliers sur les `E` |
| Run | aucune action sur le build ; or sans puits tardif ; 0 légendaire | 2.1 Fondoir, 2.2 Matrice, 2.3 Alambic, 2.4 Enclume, 2.5 Reposoir, 2.6 Étal des rebuts, 2.7 Boussole |
| Méta / variété | runs qui se ressemblent | 3.1 Présages, 3.2 Serments |

---

## 2. Neuf interactions et objets de carte

### 2.0 Règles communes aux « ateliers »

- **Emplacement** : les cases `E` existantes (3 candidates par carte, `Design_Variantes_B.md` §1). Un étage 1-4 reçoit **exactement un atelier** (tirage seedé dans `FloorPlan`, comme le secret), tiré par poids dans `data/stations.json` ; l'étage 5 reçoit toujours l'Enclume (2.4), seul puits d'or utile au dernier étage. Le couple Fondoir + Matrice compte pour un atelier (deux props à ≤ 4 u). Constantes : `Balance.STATION_PER_STAGE := 1`, `STATION_WEIGHTS` (ou le JSON). Les 4 événements de carte de `Design_Boss_Cartes.md` §4.4, s'ils sont codés un jour, partagent le même tirage (un seul « événement d'étage », recommandation déjà faite dans `Design_Zones_Secretes.md` §5 q3).
- **Interaction** : groupe `interactable` (couche 7), `can_interact()` / `interact_label()` / `interact_state()` / `interact_priority()` comme le coffre (`game/CONTRACTS.md`). Jamais au contact. Tout choix d'objet s'ouvre dans un **panneau plein écran qui fige le temps** (comme l'écran de coffre : le temps actif ne compte pas, `GDD` §4), avec les mêmes cartes d'objet que `ChestUI` (icône, nom, tags, « vous en avez X »). Un seul nouveau panneau à produire : **« Choisir un objet possédé »** (grille de cartes, 2 rangées, défilement horizontal, tactile et manette), partagé par 2.1, 2.3, 2.4 et 2.5.
- **Lisibilité mobile** : prop ≥ 1,5 u de haut, un **accent émissif** du biome (`_e.png`) qui pulse quand l'atelier est utilisable et s'éteint quand il est épuisé ; l'objet proposé (Matrice, Étal) flotte en icône de 0,8 u à 1,2 u au-dessus du prop, lisible à 6 pouces ; repère sur la minimap (même pictogramme que les coffres, autre couleur) ; flèche `OffscreenCues` optionnelle. Libellés d'invite ≤ 24 caractères (« Fondre un objet », « Forger : 1 scorie »).
- **DA** : bronze noirci et pierre usée, un seul modèle par atelier, teinte de l'accent émissif prise sur le biome par modulation en code (pas 4 rendus par atelier). Brief Codex : silhouette anguleuse reconnaissable de loin, 3 états (prêt / en cours 8 images / épuisé), ombre cuite `_shadow.png`, rig iso MAP, effort `low`.
- **Télémétrie** : chaque usage écrit un compteur `RunLog` (`station_<id>_uses`, objet donné, objet reçu) pour calibrer par les données.
- **Sauvegarde** : état de l'atelier (usages restants, objet affiché, graine) dans `StageManager.to_dict()` ; scorie, dépôt du Reposoir, présage et serment dans `RunState.to_dict()`.

### 2.1 Le Fondoir (broyeur : objet → scorie + or)

- **DA** : cuve de bronze fendue sur un trépied, braises mortes au fond ; l'accent émissif est la coulée qui luit entre les fissures quand on y jette un objet.
- **Fonctionnement** : « Fondre un objet » ouvre le panneau « Choisir un objet possédé » (communs, peu communs, rares ; légendaires exclus). L'objet est retiré (`RunState.remove_item`), le joueur reçoit **1 scorie de la qualité fondue** (`RunState.scrap[quality] += 1`) et un **remboursement en or** immédiat sous forme de pièces déposées (`PickupManager.drop`, comme la capsule). 2 usages par Fondoir.
- **Décision créée** : « cet objet ne sert pas mon build, je le transforme en droit de tirage ciblé » ; et « je fonds maintenant pour de l'or, ou je garde l'objet au cas où une Matrice apparaît à l'étage suivant ».
- **Coût / fréquence** : gratuit ; 2 usages ; présent avec la Matrice (un seul tirage d'atelier pour le couple) à un poids 35 % des étages 1-4.
- **Chiffres** : `FONDOIR_USES := 2` ; remboursement `FONDOIR_REFUND_P := {commun: 0.3, peu_commun: 0.6, rare: 1.2}` en multiples de P (plage sûre 0,2-0,4 / 0,5-0,8 / 1,0-1,5 : toujours sous le prix d'acquisition pour qu'aucune boucle or → coffre → fonte → or ne soit rentable) ; `SCRAP_CAP := 3` scories portées au total (la 4e est refusée : le bouton l'écrit en toutes lettres). La scorie **survit au changement d'étage** (c'est son intérêt).
- **Interaction avec les objets existants** : fondre un objet retire ses effets immédiatement (`ItemStats` recalculé) ; Faux (`moisson`, compteur de kills) et Chronomètre brisé (remise) : leur état interne est perdu, à écrire dans la description de la carte (« effet perdu à la fonte »). Fondre un objet d'un tag retire le poids ×1,3 de ce tag dans les tirages suivants : c'est voulu (le build se resserre).
- **Abus et garde-fous** : fonte en chaîne pour de l'or (bloquée par le remboursement < prix et les 2 usages) ; fondre tous les objets de survie pour tout mettre en dégâts (c'est une vraie option, pas un abus : le joueur paie en morts) ; plafond de 3 scories pour que la Matrice reste un choix et pas une rente.
- **Lisibilité mobile** : panneau plein écran figé ; confirmation en un seul appui sur la carte, avec « Fondre : +N or, +1 scorie » écrit sur le bouton ; pas de maintien.
- **Coût de production** : code = classe de base `Station` (interactable, usages, état sauvé) + panneau « Choisir un objet possédé » (le gros du lot, réutilisé 4 fois) + `RunState.scrap` + HUD : 3 pastilles de scorie à côté de l'or (ux-designer) ; assets Codex = 1 prop (3 états, `_e`), 1 icône de scorie ×3 teintes (blanc/vert/rouge, comme les qualités), 2 sons (chute dans la cuve, coulée). Effort global : 2-3 jours Sonnet + 1 lot Codex `low`.
- **Priorité** : **P0** (avec 2.2).

### 2.2 La Matrice (imprimante : 1 objet affiché, payé en objet ou en scorie de même qualité)

- **DA** : presse de fonderie à l'arrêt, moule ouvert ; l'objet proposé est gravé dans le moule et flotte en icône émissive au-dessus. Teinte de l'accent = qualité de l'objet (blanc / vert / rouge) pour qu'on lise la qualité de loin.
- **Fonctionnement** : au début de l'étage la Matrice tire (seedé) **une qualité** puis **un objet** de cette qualité, visible de loin. « Forger » demande **1 objet de la même qualité** (panneau de choix, l'objet donné est retiré) **ou 1 scorie** de cette qualité (sans panneau : appui direct). Le joueur reçoit l'objet affiché (`RunState.add_item`). 3 usages, le même objet à chaque fois : c'est l'outil pour **empiler**.
- **Décision créée** : « 3 Sifflets de chasse de plus en échange de trois communs que je n'aime pas : oui ou non ? », et en amont « je garde mes scories pour une Matrice rare ».
- **Coût / fréquence** : gratuit ; 3 usages ; couplée au Fondoir (poids 35 %). Peut aussi sortir **seule** (poids 10 %) : le joueur paie alors en objets.
- **Chiffres** : `MATRICE_USES := 3` ; `MATRICE_QUALITY_TABLE := {commun: 60, peu_commun: 35, rare: 5}` (jamais légendaire : 120 points ×3 casserait la courbe §11) ; **pitié de sélection** `MATRICE_MAX_OWNED := 5` (jamais un objet dont le joueur a déjà ≥ 5 exemplaires, sinon re-tirage) ; poids ×1,3 pour les tags du build (réutiliser `BUILD_TAG_WEIGHT`) ; exclus de l'affichage : objets `special` non implémentés listés dans `Maths_Scaling.md` §14.1 (Orbe de veille, Phénix, Couronne d'écho, etc.) tant qu'ils ne le sont pas.
- **Interaction avec les objets** : respecte les plafonds de `Balance` (vitesse d'attaque +200 %, déplacement +35 %, `COOLDOWN_FLOOR` 0,35) : si l'objet affiché est déjà plafonné dans le build, la carte l'écrit (« plafond atteint »). Chance : aucune (pas de d100, c'est le principe : tirage visible, pas de hasard à l'achat).
- **Abus et garde-fous** : 3 Matrices sur 3 étages = +9 exemplaires d'un commun : c'est 90 points, l'équivalent d'un peu plus d'un légendaire sur une run, réparti : acceptable, et ça coûte 9 objets ou scories. Si la télémétrie montre > 70 % de « forge complète » dès la première semaine, baisser `MATRICE_USES` à 2. Matrice rare à 5 % : 150 points potentiels pour 3 rares ou 3 scories rouges (qu'il faut avoir fondu des rares pour obtenir) : équitable.
- **Lisibilité mobile** : l'icône flottante est la seule information nécessaire avant d'approcher ; le prompt dit « Forger : 1 scorie verte » ou « Forger : donner 1 peu commun » ; la roue de rareté n'est pas utilisée (pas de hasard).
- **Coût de production** : code = 1 jour (Station + tirage dans `LootRoller`, réutilisation du panneau de 2.1) ; Codex = 1 prop (3 états, moule + icône flottante gérée en code avec les icônes d'objets existantes), 1 son de presse.
- **Priorité** : **P0** (le cœur de la demande).

### 2.3 L'Alambic (3 objets d'une qualité → 1 objet de la qualité au-dessus, guidé par les tags)

- **DA** : alambic de cuivre vert-de-gris sur un foyer éteint, trois fioles vides accrochées ; l'accent émissif est la vapeur dans le serpentin.
- **Fonctionnement** : « Distiller » ouvre le panneau de choix **trois fois** (ou une sélection multiple de 3 cartes de même qualité) ; les 3 objets sont retirés et le joueur reçoit **1 objet de la qualité supérieure**, tiré parmi ceux qui **partagent au moins un tag** avec un des trois objets donnés (sinon tirage uniforme). 1 usage. Communs → peu commun ; peu communs → rare ; rares → légendaire **interdit** (plage sûre : l'autoriser seulement en Difficile si la télémétrie montre 0 légendaire par run).
- **Décision créée** : concentration volontaire : 30 points dispersés (3 communs) contre 22 points ciblés (1 peu commun). C'est **perdant en valeur brute, gagnant en cohérence** ; le joueur choisit l'Expression contre la puissance (MDA), et la perte évite que l'Alambic domine le Fondoir (Sirlin).
- **Coût / fréquence** : gratuit ; 1 usage ; poids 20 % des étages 1-4.
- **Chiffres** : `ALAMBIC_INPUT := 3`, `ALAMBIC_USES := 1`, `ALAMBIC_TAG_GUIDED := true`, `ALAMBIC_ALLOW_LEGENDARY := false`.
- **Interaction avec les objets** : avec `Nova infinie` (tags Feu, Givre, Poison, Zone) hors d'atteinte, l'Alambic de 3 peu communs à tag Feu (Cristal de feu ×3) donne Tempête de braises à coup sûr (seul rare Feu) : lisible et désirable ; rien à corriger, c'est le « pourquoi je suis fort » du GDD.
- **Abus et garde-fous** : donner 3 copies du même objet est permis (c'est souvent le cas d'usage) ; le résultat ne peut pas être un objet déjà plafonné ; aucun or ni scorie en jeu, donc pas de boucle.
- **Lisibilité mobile** : sélection multiple = les cartes choisies se soulèvent et un compteur « 2/3 » s'affiche ; bouton « Distiller » grisé tant que les 3 ne sont pas de la même qualité, avec la raison écrite.
- **Coût de production** : code = 0,5 jour (sélection multiple dans le panneau de 2.1, filtre de tags dans `LootRoller`) ; Codex = 1 prop, 1 son de bouillonnement.
- **Priorité** : P1.

### 2.4 L'Enclume de bronze (+1 exemplaire d'un objet possédé, contre de l'or)

- **DA** : enclume massive sur une souche pétrifiée, marteau planté ; l'accent émissif est le fer rouge posé dessus, qui refroidit quand l'enclume est épuisée.
- **Fonctionnement** : « Forger un exemplaire » ouvre le panneau de choix (communs, peu communs, rares ; légendaires exclus) ; le prix est écrit sur chaque carte ; à l'achat, +1 exemplaire de l'objet choisi. 3 usages, prix ×1,5 à chaque usage. **Toujours présente à l'étage 5** (en plus des coffres), tirée à 20 % aux étages 1-4.
- **Décision créée** : le vrai **puits d'or tardif** et la seule interaction où l'or achète un choix sans dé : « je mets 3 P dans un 4e Chronomètre brisé, ou je garde l'or pour le dernier grand coffre ? »
- **Coût / fréquence** : `ENCLUME_PRICE_P := {commun: 1.2, peu_commun: 2.5, rare: 6.0}` (en P ; plage sûre 1,0-1,5 / 2,0-3,0 / 5-8), `ENCLUME_PRICE_GROWTH := 1.5`, `ENCLUME_USES := 3`. Repère : un petit coffre à 1 P donne un commun aléatoire à 78 % ; un commun **choisi** à 1,2 P est juste au-dessus, comme il se doit (coût ↔ puissance, équilibre transitif). Un rare choisi à 6 P contre un grand coffre à 2 P qui en donne un à 18 % : 6 P est le prix d'un tirage sûr, pas une aubaine.
- **Interaction avec les objets** : Faveur du marchand (`chest_price_mult`) s'applique aussi à l'Enclume (cohérent avec son nom) ; Pièce porte-bonheur (+10 % d'or) rend l'Enclume plus accessible : synergie Or lisible.
- **Abus et garde-fous** : empiler un objet plafonné (refusé, carte grisée) ; dépenser 10 P pour 3 exemplaires d'un rare à l'étage 5 : c'est le but (or qui n'a plus d'autre usage). Risque réel : rendre la relance à l'or inutile (0,6 P) : non, elle agit sur la qualité tirée, pas sur un objet choisi ; les deux coexistent.
- **Lisibilité mobile** : le prix est **sur la carte**, refus écrit (« Il manque 120 or »), même grammaire que le coffre (`interact_state` « refused »).
- **Coût de production** : code = 0,5 jour (panneau de 2.1 + prix) ; Codex = 1 prop (3 états), 2 sons (marteau, trempe). L'Enclume est l'atelier au **meilleur rapport valeur / coût** après le panneau commun.
- **Priorité** : **P0** (seconde, car elle résout l'or excédentaire).

### 2.5 Le Reposoir (investissement différé : déposer 1 objet, le retrouver doublé à l'étage suivant)

- **DA** : niche de pierre avec une jarre scellée de cire ; l'accent émissif est le sceau, qui luit tant que la jarre contient quelque chose et se brise à l'étage suivant.
- **Fonctionnement** : « Déposer un objet » (commun ou peu commun uniquement) retire l'objet ; **au début de l'étage suivant**, le joueur reçoit : commun → **2 exemplaires** ; peu commun → **1 exemplaire + 1 commun aléatoire du même tag**. Rien si la run s'arrête avant (la mort n'est pas une pénalité supplémentaire : la run est finie de toute façon). 1 usage ; étages 1-3 seulement (le retour tombe aux étages 2-4 ; aucun Reposoir à l'étage 4, le retour à la Source n'aurait pas le temps de servir).
- **Décision créée** : **se priver maintenant pour plus tard**, le seul arbitrage temporel de la run ; au début de l'étage 1, déposer son unique Sifflet de chasse rend le pilier A plus dur et l'étage 2 plus doux.
- **Coût / fréquence** : gratuit ; poids 10 % des étages 1-3 ; `REPOSOIR_USES := 1`, `REPOSOIR_RETURN := {commun: 2, peu_commun: 1}`, `REPOSOIR_BONUS_COMMON_SAME_TAG := true`, `REPOSOIR_MAX_FLOOR := 3`.
- **Interaction avec les objets** : équivaut à +10 points (commun) ou +10 points (peu commun + commun) différés : moins qu'un coffre, mais gratuit ; l'objet rendu est **choisi**, donc comparable à un usage d'Enclume payé en temps plutôt qu'en or. Pas de scorie ni d'or : zéro boucle.
- **Abus et garde-fous** : aucun gain possible avant l'étage suivant ; refus si le joueur n'a qu'un exemplaire d'un objet de survie ? Non : c'est son choix (autonomie) ; la carte affiche juste « vous n'en avez qu'un ».
- **Lisibilité mobile** : à l'étage suivant, un toast « Reposoir : +2 Sifflet de chasse » au moment de l'arrivée (hors combat, 1,5 s après le fondu), même emplacement que les toasts de succès.
- **Coût de production** : code = 0,5 jour (`RunState.reposoir := {id, quality}` sauvé, restitution dans `StageManager.start_stage`) ; Codex = 1 prop (jarre scellée / vide), 1 son de sceau.
- **Priorité** : P2 (charmant, peu coûteux, mais effet discret ; à produire après P0-P1 si la télémétrie montre que les joueurs s'engagent dans les ateliers).

### 2.6 L'Étal des rebuts (racheter un objet refusé à un coffre de cet étage)

- **DA** : table de pierre sous un auvent de tôle, trois objets posés sous des cloches de verre fêlées ; accent émissif = la lampe à huile de l'auvent.
- **Fonctionnement** : chaque fois que le joueur choisit la carte A d'un coffre, la carte B est **mémorisée** (`ChestSession` connaît déjà les deux). L'Étal expose **3 objets parmi les refusés de l'étage** (les 3 derniers ; s'il y en a moins de 3, il en montre moins) au **prix plein de leur qualité** et vend **un seul** objet. Apparaît toujours à ≥ 20 u du départ (il faut qu'il y ait eu des coffres avant).
- **Décision créée** : rend le choix A / B **moins définitif sans le vider** (on peut revenir sur un regret, une fois, en payant) ; crée la tension « je prends le Sablier maintenant et, si l'Étal sort, je rachète la Bague ».
- **Coût / fréquence** : `REBUTS_SHOWN := 3`, `REBUTS_PRICE_P := {commun: 1.0, peu_commun: 1.8, rare: 4.0, legendaire: 8.0}` (en P ; = coût d'un coffre « sûr » de cette qualité, pas de remise : la remise ferait de l'Étal un marchand dominant), `REBUTS_BUYS := 1` ; poids 20 % des étages 1-4.
- **Interaction avec les objets** : aucune règle spéciale ; la relance à l'or ou par pub remplace les deux cartes, donc les cartes relancées sont aussi mémorisées (jusqu'à 4 rebuts par coffre : seuls les 3 derniers de l'étage sont montrés).
- **Abus et garde-fous** : « ouvrir, regarder, refuser, racheter » n'apporte rien (prix plein, un seul achat) ; un rebut légendaire à 8 P reste exceptionnel (il faut un coffre légendaire puis un Étal).
- **Lisibilité mobile** : les 3 objets flottent en icônes au-dessus de l'étal (on sait de loin si ça vaut le détour) ; le panneau est l'écran de coffre à 3 cartes sans roue de rareté, prix sur chaque carte.
- **Coût de production** : code = 0,5 jour (mémoire des refus dans `RunState.refused: Array`, par étage ; variante du panneau de coffre) ; Codex = 1 prop, 1 son de cloche de verre.
- **Priorité** : P1 (le moins cher de tous, et il nourrit directement le pilier « builds lisibles »).

### 2.7 La Boussole de rouille (orienter le prochain coffre vers un tag)

- **DA** : cadran de bronze sur un pied, aiguille rouillée qui tourne ; accent émissif = la rose des vents gravée, qui s'allume sur le tag choisi.
- **Fonctionnement** : « Orienter » ouvre une liste courte de tags (les 4 tags les plus présents dans le build + 2 tirés parmi les autres) ; contre 0,6 P, **le prochain coffre ouvert** garantit que **sa carte A porte ce tag** (qualité inchangée, tirage normal pour la carte B). 1 usage.
- **Décision créée** : petite agentivité à bas coût, l'équivalent d'une « relance orientée » ; utile juste avant un grand coffre.
- **Coût / fréquence** : `BOUSSOLE_PRICE_P := 0.6` (= prix de la première relance à l'or, pour ne pas la dominer), `BOUSSOLE_USES := 1`, `BOUSSOLE_TAGS_SHOWN := 6` ; poids 10 % des étages 1-4.
- **Interaction avec les objets** : si la table de la qualité tirée n'a aucun objet du tag (ex. tag Boss en légendaire), la garantie se reporte sur la carte B d'un objet du tag le plus proche dans le build ; la carte l'indique (« tag indisponible à cette qualité : remboursé »).
- **Abus et garde-fous** : un seul usage et un seul coffre ; ne touche pas le d100 (la Chance reste le seul levier de qualité, `Maths_Scaling.md` §14.1).
- **Lisibilité mobile** : liste de 6 boutons-tags (icône + nom), un appui ; le HUD montre une petite boussole à côté de l'or tant que la garantie est active.
- **Coût de production** : code = 0,5 jour (`LootRoller.pick_pair` avec contrainte de tag, drapeau `RunState.next_chest_tag`) ; Codex = 1 prop, 1 son de cadran.
- **Priorité** : P2 (recouvre en partie la Matrice et l'Alambic ; à garder si l'on veut un atelier « léger » sans panneau d'objets).

### 2.8 Le Brasero (point de ralliement payant : une zone de farm choisie, 90 s)

- **DA** : vasque de fer sur trois pieds, cendres froides ; l'accent émissif est le feu une fois allumé, qui décroît visiblement sur 90 s (jauge lisible sans HUD).
- **Fonctionnement** : « Allumer » coûte 0,5 P ; pendant 90 s, dans un rayon de 6 u : **or des kills ×1,25**, **régénération +1,5 PV/s × (1 + 0,2 (niv − 1))** (barème des régénérations plates de `Maths_Scaling.md` §14.1), et le director concentre ses apparitions vers le cercle (`ZONE_SPAWN_MULT` nouveau genre `&"brasero"` = ×1,25, moins qu'un pilier de mini-boss). Jamais activable à < 20 u d'un pilier actif. 1 usage.
- **Décision créée** : donne un **lieu et un sens** aux relâches et à la phase post-boss : « je farme ici, maintenant, 90 s, puis je pars » ; rend le farm **borné** et **situé** au lieu de diffus.
- **Coût / fréquence** : `BRASERO_PRICE_P := 0.5`, `BRASERO_DURATION_S := 90.0`, `BRASERO_RADIUS_U := 6.0`, `BRASERO_GOLD_MULT := 1.25`, `BRASERO_REGEN := 1.5`, `ZONE_SPAWN_MULT[&"brasero"] := 1.25`, `BRASERO_MIN_PILLAR_DIST_U := 20.0` ; poids 15 % des étages 1-4.
- **Interaction avec les objets** : Pièce porte-bonheur et Faveur du marchand (Or) se cumulent (multiplicatif, ×1,25 × 1,10) ; l'Autel de fortune ou le Sanctuaire de risque (design §4.4) seraient redondants : si le Brasero entre, **retirer le Sanctuaire de risque** du design (déjà recommandé dans `Design_Zones_Secretes.md` §5 q2).
- **Abus et garde-fous** : rester 90 s coûte ≈ +0,23 de D (en Moyen) pour ≈ +25 % d'or sur 90 s : rentable mais pas gratuit ; 1 usage ; pas de cumul avec une zone de pilier.
- **Lisibilité mobile** : cercle au sol dans la palette des télégraphes « utile » (cyan / accent du biome, jamais rouge), feu qui baisse = temps restant.
- **Coût de production** : code = 1 jour (zone à crédits dans `Director`, régén locale dans `player.gd` via un modificateur temporaire) ; Codex = 1 prop (éteint / 8 images de feu / braises), 1 texture de flamme, 2 sons (allumage, crépitement en boucle).
- **Priorité** : P2 (le plus coûteux en perf et en code parmi les ateliers : 1 lumière dynamique de plus, à compter dans les plafonds par palier de `Direction_Lumiere_Ambiance`).

### 2.9 Le Paratonnerre dévié (option sur le gros pilier : boss d'étage affixé contre un 2e coffre de boss)

- **DA** : pas de nouveau prop : sur le gros pilier, une **chaîne de bronze** à tirer (action distincte « Dévier la foudre », affichée seulement avant l'activation) ; l'accent émissif du pilier passe de l'accent du biome à la couleur de l'affixe tiré (orange brûlure, bleu ralentissement, vert poison : codes déjà connus des élites).
- **Fonctionnement** : avant d'activer le gros pilier, le joueur peut le « dévier » : le boss d'étage apparaît **élite** (1 affixe existant parmi `Brûlure`, `Ralentissement`, `Poison`, choisi par le tirage seedé et **annoncé** sur le pilier avant d'accepter) avec **+40 % de PV** et l'aura élite ; à sa mort, **2 coffres de boss** (table `boss`) au lieu d'un. Gel des boss respecté : aucun nouveau boss, aucun nouveau sort ; seulement l'affixe et les PV, via `Enemy.apply_affix` (élites existantes) et `BOSS_HP_MULT`.
- **Décision créée** : **risque / récompense volontaire au moment du pic**, le choix qui manque à la phase du gros pilier ; c'est aussi un marqueur de maîtrise (Sirlin : le joueur fort choisit une difficulté plus haute et en est payé, le débutant n'y perd rien).
- **Coût / fréquence** : disponible sur **tous** les gros piliers des étages 1-4 (pas à la Source) ; `PILLAR_DEVIATED_BOSS_HP_MULT := 1.4` (plage sûre 1,3-1,6 ; au-delà, le combat dépasse 100 s et la zone de charge de 60 s ne compte plus), `PILLAR_DEVIATED_AFFIXES := [&"burn", &"slow", &"poison"]`, `PILLAR_DEVIATED_CHESTS := 2`. Boss de raid (Idole noyée, Canonnier de crue, Roi de sel) : **exclus en v1** (leurs boucliers allongent déjà le combat, `Audit` §5.1).
- **Interaction avec les objets** : Antidote (−40 % brûlure et poison subis), Botte rapiécée (ralentissement) et Marque du chasseur (tag Boss) deviennent des achats qui **préparent** un pari : le jeu récompense la lecture de l'affixe annoncé.
- **Abus et garde-fous** : toujours dévier = +1 objet peu commun / rare par étage contre +40 % de temps de combat et un affixe : ≈ +25 s d'étage (donc +0,06 de D) et un vrai risque de mort ; c'est la bonne pente pour un joueur fort, pas une domination. Plafond de dégâts d'un coup de boss inchangé (40 % des PV max) ; l'affixe élite Brûlure sur un boss = 25 % du coup sur 3 s (barème joueur), jamais une mort instantanée.
- **Lisibilité mobile** : second libellé sur le pilier (« Dévier : boss Brûlure, 2 coffres ») avant « Activer » ; `interact_priority` : Dévier d'abord tant que non activé ; aura élite et icône d'affixe sur la barre de boss (`BossBars`).
- **Coût de production** : code = 1 jour (état `deviated` sur `Pillar`, sauvegardé ; spawn du boss avec affixe ; 2e coffre à la mort) ; Codex = 0 prop (chaîne = sous-sprite du pilier existant, 1 lot `low` ou dessin dans le `_e`) ; 1 son de chaîne. **Aucun asset bloquant**.
- **Priorité** : **P0 bis** (le moins cher des P0 et le seul qui agisse sur le pic de l'étage).

---

## 3. Trois améliorations structurelles de la boucle

### 3.1 Les Présages (choix d'un mutateur d'étage à l'arrivée, étages 2-5)

- **Principe** : en arrivant à un étage (après le fondu, temps figé), le joueur choisit **un présage parmi deux** (cartes, même grammaire que les coffres). Un présage = une **contrainte** lisible + une **compensation** lisible, valables jusqu'au téléporteur. Exemples dans `data/omens.json` (12 au lancement, 2 tirés seedés par étage, jamais le même deux fois par run) :
  - « Brume épaisse » : tireurs ×2 dans le director, or +25 % ;
  - « Marée » : essaims +50 %, capsules d'argent ×2 (20 → 40 or de base) ;
  - « Nuit sans lanterne » : rayon de ramassage −30 %, prix des coffres −15 % ;
  - « Éveil des élites » : élites ×2, coffre de boss à table `guardian` (jamais commun) ;
  - « Pluie de cendres » : brûlure subie +50 %, dégâts infligés +15 % ;
  - « Silence » : pas de présage (toujours proposé comme carte B une fois par run : l'option « neutre » existe, Deci et Ryan).
- **Décision créée** : **autonomie au début de l'étage**, là où il n'y a aujourd'hui aucune décision ; chaque run diverge dès l'étage 2 ; les présages racontent le biome (Marée en Forêt, Cendres en Cité).
- **Chiffres** : `OMEN_FROM_FLOOR := 2`, `OMEN_CHOICES := 2`, `OMEN_BUDGET_POINTS := 0` (contrainte et compensation évaluées avec la même grille de points que l'audit des objets : un présage vaut **0 ± 5 points** net, pour qu'aucun ne soit dominant ; systems-designer à valider sur la grille de `Items_Catalog.md` §1).
- **Risques** : lisibilité (deux cartes, une phrase chacune, icône) ; perf : les présages ne créent ni projectile ni effet par monstre, ils modulent des constantes du director et de `ItemStats` ; collision avec le défi du jour : présages **imposés** par la graine du jour (même choix pour tous : la carte A est forcée) ; collision avec les Serments (3.2) : un seul écran à l'arrivée, présage à gauche, serment à droite.
- **Coût de production** : code = 2 jours (données, application dans `Director` et `ItemStats`, écran d'arrivée, sauvegarde `RunState.omen`) ; Codex = 12 icônes 128 px (1 lot), 1 son d'écran.
- **Priorité** : **P1** (structurel le plus rentable : variété de run et autonomie sans nouvel asset de carte).

### 3.2 Les Serments (objectif optionnel d'étage, récompensé en rubis et en or)

- **Principe** : à l'arrivée, **un serment** tiré parmi 10 (`data/oaths.json`) est proposé ; l'accepter n'a aucun coût ; le tenir jusqu'au téléporteur paie. Exemples : « Finir l'étage en moins de 3:30 », « Ne pas être touché par le boss d'étage », « Activer les deux petits piliers à moins de 20 s d'écart », « Ouvrir les 10 coffres », « Ne pas descendre sous 50 % de PV », « Tuer 150 monstres dans l'eau peu profonde ». Les compteurs existent déjà dans `RunLog` et `MetaTracker` (kills, dégâts subis, piliers, coffres, temps d'étage).
- **Décision créée** : donne un **but à la méso-boucle** autre que « finir », et surtout un but **à la phase post-boss** (« ouvrir les 10 coffres » rend le farm finalisé ; « moins de 3:30 » le rend interdit). Compétence (Deci et Ryan) : le joueur sait pourquoi il a réussi.
- **Chiffres** : `OATH_RUBIES := 6` (comparer : 8 rubis par pilier terminé dans `rubies_for_run`), `OATH_GOLD_P := 1.0` (1 P d'or au moment du téléporteur, donc converti en XP ou dépensé à l'Enclume de l'étage suivant ; plage 0,5-1,5 P), `OATH_FROM_FLOOR := 1`, un seul serment par étage, jamais le même deux fois par run. Ligne d'objectif dans le panneau OBJECTIFS existant (secrets) : « Serment : 7/10 coffres ».
- **Risques** : un serment impossible pour un kit (Bourbe et « ne pas être touché ») : les serments portent un filtre de tags de personnage dans le JSON ; serment « vitesse » contre serment « complétion » : ne jamais tirer deux contraintes opposées sur deux étages consécutifs (poids ×0,5 sur la famille du serment précédent) ; pas de rubis en mode test (`Profile.begin_sandbox()` déjà en place).
- **Coût de production** : code = 1,5 jour (données, évaluation par signaux `Events`, ligne d'objectif, récompense au téléporteur, sauvegarde) ; Codex = 10 icônes (1 lot). Aucun prop.
- **Priorité** : P1.

### 3.3 Le Départ vif (le dilemme post-boss : partir vite paie, rester est un pari)

- **Principe** : pendant `QUICK_EXIT_S := 45.0` s après la mort du boss d'étage, le téléporteur affiche « Départ vif » : l'or restant est converti à **0,5 XP par or** (`GOLD_TO_XP_SHARE_QUICK := 1.0`, soit le double du `GOLD_TO_XP_SHARE` 0,5 → 0,25 XP/or actuel) et le joueur reçoit un **bonus de 0,5 P d'or à l'arrivée** de l'étage suivant (`QUICK_EXIT_GOLD_P := 0.5`, pour le premier coffre). Passé 45 s, règles actuelles. Compte à rebours sur l'invite du téléporteur et dans la ligne d'objectif.
- **Décision créée** : transforme le faux choix de §1.3 en dilemme : « 45 s pour ramasser ce qui traîne et partir avec un bonus, ou rester, allumer le Brasero et acheter les 3 coffres restants en acceptant +0,3 de D ». Difficulté en dents de scie (Flow) : la relâche post-boss devient une **décision courte** plutôt qu'un plateau.
- **Risques** : si le bonus est trop fort, personne ne farme (la phase post-boss disparaît) ; à 0,5 XP/or et 0,5 P, un étage avec 3 coffres non achetés (≈ 3 P d'or) donne au départ vif ≈ 1,5 P d'or en XP + 0,5 P contre, en restant, 3 objets (30 points) : rester reste supérieur en puissance, partir est supérieur en **temps** (D) : c'est un vrai arbitrage, pas une domination. Télémétrie : part des départs vifs visée 40-60 %.
- **Coût de production** : code = 0,5 jour (minuteur dans `StageManager._on_pillar_finished`, libellé du téléporteur, constantes) ; aucun asset ; 1 son (carillon de départ). **Le moins cher de tout le document.**
- **Priorité** : **P0 ter** (à faire avec 2.9 : les deux ne coûtent que du code).

---

## 4. Classement final

### 4.1 Top 5 recommandé, dans l'ordre de production

| # | Proposition | Pourquoi d'abord | Lot code | Lot Codex |
|---|---|---|---|---|
| 1 | **2.1 + 2.2 Fondoir + Matrice** | la demande du joueur ; seule vraie agentivité sur le build ; le panneau « Choisir un objet possédé » qu'elles exigent sert ensuite à 2.3, 2.4, 2.5 | classe `Station`, panneau d'objets, `RunState.scrap`, HUD scorie, sauvegarde, `station_test` | 2 props (3 états, `_e`), 3 icônes de scorie, 3 sons |
| 2 | **2.4 Enclume de bronze** | puits d'or tardif, étage 5 garanti ; 0,5 jour une fois le panneau fait | prix sur cartes, Enclume à l'étage 5 | 1 prop, 2 sons |
| 3 | **2.9 Paratonnerre dévié + 3.3 Départ vif** | les deux agissent sur le pic et la relâche de l'étage ; **zéro asset bloquant** ; gel des boss respecté | état `deviated` du pilier, 2e coffre, minuteur du téléporteur | 1 son chacun |
| 4 | **3.1 Présages** | variété de run et autonomie à l'arrivée ; pas de prop de carte | données, écran d'arrivée, application director / stats | 12 icônes |
| 5 | **2.6 Étal des rebuts** | le moins cher des ateliers, nourrit « builds lisibles » ; une 2e famille d'atelier pour que les `E` ne proposent pas toujours la même chose | mémoire des refus, panneau de coffre à 3 cartes | 1 prop, 1 son |

Puis, si la télémétrie des ateliers est bonne (usage > 50 % des ateliers rencontrés) : 3.2 Serments, 2.3 Alambic, 2.8 Brasero, 2.5 Reposoir, 2.7 Boussole.

Budget d'objets attendu (à valider par systems-designer sur `simulateur_scaling.py` et `economy_test`) : avec 1 atelier par étage 1-4 et l'Enclume à l'étage 5, l'espérance est ≈ **+2 à +4 objets choisis par run** et ≈ −2 objets subis (fondus), pour ≈ +40 s de temps actif (≈ +0,1 de D en fin de run) : l'enveloppe de la courbe §11 de `Maths_Scaling.md` (power fantasy en fin d'étage 2-4) n'est pas dépassée ; la **qualité** du build monte plus que sa quantité, ce qui est le but.

### 4.2 Ce qu'il ne faut pas faire

1. **Pas de 5e bouton** (objet actif à la RoR2 « équipement ») : le HUD tactile a déjà sorts 2-4 + roulade + interagir ; tout ce qui précède passe par « interagir » et un panneau figé.
2. **Pas de seconde monnaie persistante** dans la run au-delà de la scorie plafonnée à 3 ; aucun « cristal », aucune monnaie convertible en rubis en cours de run ; rubis jamais dépensés dans la run (ils restent la méta).
3. **Pas de station qui retire sans rendre** (malédictions, objets « ternis » à purifier, perte d'objet à la mort) : les 50 objets sont tous positifs, l'audit de valeur repose dessus ; une famille d'objets négatifs est un chantier à part (LiveOps).
4. **Pas plus d'un atelier par étage** et aucun atelier à la Source sauf l'Enclume : un étage de 4 min à 3 ateliers devient un menu, pas un combat.
5. **Pas de remise ni de pub** sur les ateliers : la relance par pub reste la seule pub de la boucle d'objets (GDD §10), et une remise sur l'Étal ou l'Enclume les rendrait dominants face aux coffres.
6. **Pas de nouveau boss ni de nouveau sort de boss** pour le Paratonnerre dévié : affixe élite existant, PV ×1,4, rien d'autre ; boss de raid exclus tant qu'ils ne sont pas calibrés à la main.
7. **Pas d'interaction au contact ni de canalisation immobile** (règles des secrets) ; pas de minuteur réel qui court pendant un panneau (le temps actif est figé, comme au coffre).
8. **Ne pas coder les 4 événements de carte de `Design_Boss_Cartes.md` §4.4 tels quels avant les ateliers** : l'Autel de fortune (d100 contre or) et le Sanctuaire de risque (vague contre or) sont des coffres déguisés ; le Marchand de l'ombre est rendu caduc par l'Étal et l'Enclume ; seul le Coffre piégé garde un intérêt (à fusionner dans le tirage d'atelier à 10 %).

---

## 5. Contrats et tests à prévoir (pour l'orchestrateur)

- **`Balance`** (orchestrateur, `scripts/core/`) : `STATION_PER_STAGE`, `STATION_WEIGHTS` (ou `data/stations.json`), `FONDOIR_USES`, `FONDOIR_REFUND_P`, `SCRAP_CAP`, `MATRICE_USES`, `MATRICE_QUALITY_TABLE`, `MATRICE_MAX_OWNED`, `ALAMBIC_INPUT`, `ALAMBIC_USES`, `ALAMBIC_ALLOW_LEGENDARY`, `ENCLUME_PRICE_P`, `ENCLUME_PRICE_GROWTH`, `ENCLUME_USES`, `REPOSOIR_USES`, `REPOSOIR_RETURN`, `REPOSOIR_MAX_FLOOR`, `REBUTS_SHOWN`, `REBUTS_PRICE_P`, `REBUTS_BUYS`, `BOUSSOLE_PRICE_P`, `BOUSSOLE_USES`, `BRASERO_*`, `ZONE_SPAWN_MULT[&"brasero"]`, `PILLAR_DEVIATED_BOSS_HP_MULT`, `PILLAR_DEVIATED_AFFIXES`, `PILLAR_DEVIATED_CHESTS`, `OMEN_FROM_FLOOR`, `OMEN_CHOICES`, `OATH_RUBIES`, `OATH_GOLD_P`, `QUICK_EXIT_S`, `GOLD_TO_XP_SHARE_QUICK`, `QUICK_EXIT_GOLD_P`.
- **`RunState`** : `scrap: Dictionary` (qualité → n), `refused: Array` (par étage), `reposoir: Dictionary`, `omen: StringName`, `oath: Dictionary` (id, progression), `next_chest_tag: StringName` ; tout dans `to_dict()` / `from_dict()` avec montée de `RunSave.VERSION`.
- **`Events`** : `station_used(id, kind, given, received)`, `pillar_deviated(affix)`, `omen_chosen(id)`, `oath_accepted(id)`, `oath_completed(id, success)`, `quick_exit(taken: bool)`.
- **`FloorPlan`** : tirage seedé de l'atelier par étage (générateur propre `hash([seed, "station_run"])`, comme le secret) ; `-- --force-station=<id>` pour les tests et le mode test.
- **Mode test** : panneau TAB : invoquer un atelier au choix, donner des scories, forcer un présage.
- **Tests** : `station_test` (usages, sauvegarde aller-retour, refus écrits, plafonds respectés, remboursement < prix), `pillar_deviated_test` (affixe annoncé = affixe appliqué, 2 coffres, exclusion des raids), `omen_test` (jamais deux fois le même, défi du jour forcé), `oath_test` (chaque serment évaluable par les signaux existants), `economy_test` étendu (objets choisis par run, or excédentaire à l'étage 5 avec l'Enclume).
- **Consultants à croiser** : systems-designer (grille de points des présages, prix en P, budget d'objets sur 5 étages), ux-designer (panneau « Choisir un objet possédé » tactile et manette, pastilles de scorie, écran d'arrivée présage + serment), level-designer (vérifier que les 3 cases `E` de chaque carte sont à ≥ 20 u du départ pour l'Étal et à ≥ 20 u des piliers pour le Brasero).
