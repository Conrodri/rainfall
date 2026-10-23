# Zones secrètes et mécaniques de déblocage (design v1, planification)

> Statut : **proposition de game design**, à implémenter **après la phase 0 iso** (docs/Design_Isometrique.md §5). Aucun code dans ce document.
> Cohérent avec `Design_Boss_Cartes.md` (§4 grilles, §4.4 événements), `Maths_Scaling.md` + `game/scripts/core/balance.gd` (alignement RoR2 : coeff, coffres en coeff^1,25, or des kills ∝ coût director), `Items_Catalog.md` (tables de qualité) et `game/CONTRACTS.md` (groupe `interactable`, action `interact`, panneau OBJECTIFS).
> Règles héritées : **toute interaction passe par l'action « interagir »** (jamais au contact, comme le téléporteur) ; télégraphe ≥ 0,8 s ; jamais de mort instantanée ; aucun nom ni design emprunté à RoR2.
> Unité : 1 u = 64 px ; 1 caractère de grille = 2 u × 2 u.

---

## 0. Résumé

Rainfall n'a aujourd'hui que des interactions « posées » (coffres, capsules, piliers, 4 événements de carte). Ce document ajoute une couche de **secrets à mériter** : des endroits de la carte fermés au départ, qu'on ouvre par une petite énigme spatiale (deux plaques, une vanne, des lanternes), une clé, un sort ou un sacrifice, et qui donnent des objets ou de l'or au-dessus du rythme normal, contre du temps (la difficulté monte de ≈ +0,15 de coeff par minute en Moyen) et du risque.

Principes retenus :
1. **Lisible depuis le départ** : le secret se voit (porte, vanne, cadran), c'est son *contenu* qui est caché. Sur mobile, cacher l'existence d'un secret = personne ne le trouve.
2. **Jamais de contact** : vannes, lanternes, leviers, autels, coffres sont des `interactable` (couche 7) avec `can_interact()` / `interact_label()`, bouton Interagir contextuel du HUD. **Seule exception, décidée par le joueur (21/10/2026) : les plaques de pression de la porte scellée s'enfoncent au passage** (marcher dessus suffit) et **restent enfoncées définitivement** ; il n'y a rien à appuyer, aucune fenêtre de temps.
3. **Rythme survivor-like** : 20 à 60 s par secret, résolvable en se déplaçant (le joueur à 4,0 u/s est plus rapide que tout), jamais de canalisation immobile > 1 s.
4. **Budget par étage : au plus 1 secret « majeur » + 1 « mineur »** (tirage seedé, intégré au tirage des événements de carte §4.4), pour ne pas diluer un étage de 4-5 min.
5. **Équilibrage en « P »** (prix courant d'un petit coffre, `Balance.chest_price(&"petit", coeff, étage)`) : toute récompense est exprimée en fractions de P, donc elle suit automatiquement coeff^1,25.

---

## 1. Référence : déblocages et secrets dans Risk of Rain

Pages consultées (riskofrain2.wiki.gg, 21/10/2026) : [Abandoned Aqueduct](https://riskofrain2.wiki.gg/wiki/Abandoned_Aqueduct), [Timed Security Chest](https://riskofrain2.wiki.gg/wiki/Timed_Security_Chest), [Rallypoint Delta](https://riskofrain2.wiki.gg/wiki/Rallypoint_Delta), [Shrines](https://riskofrain2.wiki.gg/wiki/Shrines), [Newt Altar](https://riskofrain2.wiki.gg/wiki/Newt_Altar), [Gilded Coast](https://riskofrain2.wiki.gg/wiki/Gilded_Coast), [Void Fields](https://riskofrain2.wiki.gg/wiki/Void_Fields), [Void Cradle](https://riskofrain2.wiki.gg/wiki/Void_Cradle), [Siren's Call](https://riskofrain2.wiki.gg/wiki/Siren%27s_Call). Pour Returns, pas de page wiki officielle trouvée : guides tiers ([Destructoid](https://www.destructoid.com/how-to-get-environmental-logs-in-risk-of-rain-returns/), [Exputer](https://exputer.com/guides/risk-of-rain-returns-artifacts-location/), [Prima](https://primagames.com/tips/unlock-robomando-risk-of-rain-returns)).

| Mécanique RoR | Boucle de jeu (une ligne) | Ce qu'on en retient pour Rainfall |
|---|---|---|
| **Plaques de pression** (Abandoned Aqueduct) | 2 plaques parmi 8 emplacements, à maintenir **en même temps** (joueurs ou objets lourds) → porte antique → 2 Lemuriens aînés élites uniques, nommés (3 000 % PV, pas de scaling ambiant) → 1 anneau chacun ; le wiki conseille de le faire après le téléporteur | Le modèle de la mécanique demandée. En solo mobile, « simultané » devient « les deux enfoncées, définitivement » (décision du joueur) ; gardiens **nommés** |
| **Timed Security Chest** (Rallypoint Delta, 3 emplacements signalés par des lampes rouges) | Gratuit, se verrouille à **10:00 du chrono de run** ; contient toujours un équipement légendaire | Un coffre gratuit visible qui se ferme à une heure connue : dilemme « y courir faible ou le laisser » |
| « **Frozen Wall** » | Ce n'est pas un secret : c'est le nom de développement de Rallypoint Delta (section Trivia). Aucun mur gelé/cassable sur cette carte | Néant (idée du mur cassable reprise ailleurs, §2.8) |
| **Sanctuaire de combat** (Shrine of Combat) | Gratuit : fait apparaître des monstres (élites) tout de suite ; récompense = l'or/XP de ces monstres | Vague forcée contre or ; proche de notre Sanctuaire de risque §4.4 |
| **Sanctuaire de la montagne** | Gratuit avant le téléporteur : le boss du téléporteur est doublé, +1 objet de boss | Rendre le boss d'étage plus dur contre un coffre de boss en plus (option §5) |
| **Sanctuaire de sang** | Coûte **50 % des PV** → or (3 usages, montant croissant) | Autel de sang §2.9 |
| **Sanctuaire de l'ordre** | 1 pièce lunaire : tous les objets d'une rareté sont fusionnés en un seul type | Trop chaotique pour un jeu à 50 objets ; différé |
| **Sanctuaire de la chance** | 17 or (croissant), d100 : objet ou rien | = notre Autel de fortune existant |
| **Autel de Newt / Bazar** | 1 pièce lunaire → portail bleu après la charge → boutique cachée (objets lunaires, chaudrons d'échange) | Portail post-téléporteur = idée différée (une 4e « carte » d'échange) |
| **Autel d'or / Gilded Coast** | Payer l'autel → portail doré après le téléporteur → 7 balises à acheter (25 or chacune, croissant) → au 4e, Aurelionite apparaît, invulnérable tant qu'une balise est éteinte ; il éteint tout après un délai | « Allumer N balises dans un délai, sinon tout s'éteint » = Veillée des lanternes §2.2 |
| **Void Fields / cellules** | 9 cellules (rayon 20 m, 1 min chacune, n'avancent que joueur dedans) ; le brouillard du Vide blesse hors cellule ; 4 Communs, 4 Peu communs, 1 Légendaire | La charge « seulement dedans » est déjà notre gros pilier ; brouillard qui blesse = trop punitif pour 4 min d'étage |
| **Void Cradle** | 50 % des PV → 1 objet du Vide (60/30/10) | Coffre payé en PV : variante de l'Autel de sang §2.9 |
| **Œufs de vautour** (Siren's Call) | Détruire 6 nids → avertissement au 5e → boss unique → 1 Légendaire par joueur | « Casser N objets de décor → gardien → gros lot » (option §5, Forêt) |
| **Returns : Boar Beach, lianes, passages cachés** | Zones secrètes derrière des passages non évidents, journaux et éclats d'artefacts dans des couloirs cachés selon la variante de carte | La joie de découverte ; chez nous, les passages sont « fissurés » (visibles) §2.8 |

---

## 2. Catalogue des mécaniques pour Rainfall

### 2.0 Repères d'équilibrage (Moyen, `balance.gd` actuel)

`coeff = (1 + 0,1518 × t_min) × 1,15^(étage − 1)` ; P = 50 × coeff^1,25 × 1,04^(étage − 1) ; or/s de farm hors zone ≈ crédits/s × 2 × coeff × 0,235 × 0,85 (85 % des crédits finissent en kills), après la rampe de 4 min.

| Moment | coeff | P (petit coffre) | or/s farm | **s de farm pour 1 P** |
|---|---|---|---|---|
| 2:00, étage 1 | 1,30 | 69 | 0,71 | 98 |
| 5:00, fin étage 1 | 1,76 | 102 | 1,07 | 95 |
| 10:00, fin étage 2 | 2,90 | 197 | 2,24 | 88 |
| 15:00, fin étage 3 | 4,30 | 335 | 4,18 | 80 |

**Règle d'or : 1 P ≈ 90 s de farm** (×1,5 à ×2,3 plus vite en zone de pilier). Un secret qui coûte T secondes doit rapporter **1,5 à 3 × (T / 90) P** (le surplus paie le risque et la rareté) : 20 s → 0,3-0,7 P ; 40 s → 0,7-1,3 P ; 60 s → 1-2 P.

Valeur d'un objet en P : petit coffre = 1 P (1,77 « poids de qualité » : 0,6 + 0,32 × 2,2 + 0,07 × 5 + 0,01 × 12) ; grand coffre = 2 P (2,76 poids) ; capsule = 0,4 P ; **table « gardien »** (petit coffre + 1 Chance, voir §3) = 36 / 49 / 13 / 2 = 2,33 poids ≈ **1,5 P**.

Rappels director (`balance.gd`) : élite tier 3 = coût 72 → or d'un kill = 2 × coeff × 72 × 0,235 ≈ 34 × coeff (≈ 0,6 P !) : un gardien élite **doit avoir une prime d'or surchargée** (§3), sinon ses pièces valent déjà un coffre. Vague du Director : `trigger_wave()` existe, 3-50 monstres, élite en tête selon `wave_leader_chance`.

### 2.1 Terrasses noyées : « L'écluse » (vanne qui vide un bassin)

| | |
|---|---|
| **Déclencheur** | Une **roue de vanne** (prop 1,5 u, bronze vert-de-gris, accent émissif cyan quand armée) posée au bord d'un bassin d'eau profonde (`~`). Action « Tourner la vanne ». |
| **Effet** | Le bassin se vide en **12 s** (shader : niveau qui baisse, reflets, puis boue brillante) : ses cellules `~` deviennent `,` (franchissables) **pour le reste de l'étage**. Au fond : un **coffre englouti** (grand coffre, prix **−40 %**, couvert de vase, chaîne intacte = pas un piégé) et **1 capsule**. |
| **Coût / risque** | Pendant la vidange, « ce qui dormait dans l'eau » sort : une **vague de 25-35 monstres** (tier 1-2, 1 élite Ralentissement en tête à 60 %) apparaît sur le bord du bassin, annoncée par la flèche de vague + son grave 1,5 s. Le joueur est au bord d'une eau qu'on ne peut pas encore traverser : il doit tenir ou décrocher. |
| **Récompense** | Économie 0,8 P sur le grand coffre + 0,4 P de capsule + or de la vague (≈ 0,25 P) ≈ **1,4 P** ; plus un **raccourci / refuge** (le bassin vidé est un sol `,` sans spawn pendant 30 s). |
| **Director** | Vague via `trigger_wave(side, count, leader := true)` avec coût prélevé sur `wave_credits` (pas de crédits gratuits : la vague consomme la réserve, le flux continu baisse 20 s). |
| **Lisibilité** | Roue de vanne visible sur la minimap (icône engrenage) ; eau profonde qui « clapote » autour de la vanne ; OBJECTIFS : ligne optionnelle « Vidange du bassin  0:08 » pendant la vidange. Son : grincement de roue, chute d'eau, puis silence. |
| **Téléporteur / pilier** | Utilisable à tout moment ; la vague n'est pas déclenchée si un pilier est actif à < 20 u (la vanne affiche « Trop de bruit… » et refuse : même garde-fou que le Sanctuaire de risque). |
| **Fréquence** | 1 emplacement par étage tiré parmi 3 bassins candidats (`w` dans la grille, §4) : bassin ouest (lignes 14-16, colonnes 3-6, à 10 u du spawn : le plus lisible), lac nord-ouest (lignes 1-3), étang sud-est (lignes 15-18, colonnes 22-26). Secret **majeur**, 50 % des étages sur cette carte. |
| **Chiffres** | T ≈ 12 s de vidange + 20 s de vague + 10 s de trajet ≈ 40 s → cible 0,7-1,3 P ; livré 1,4 P : à la limite haute, justifié par le fait qu'il faut **encore payer** 1,2 P pour le coffre (la récompense est une remise, pas un don). |

### 2.2 Forêt-brume : « La veillée des lanternes »

| | |
|---|---|
| **Déclencheur** | **4 lanternes de pierre** éteintes (props 1,5 u existants des sanctuaires), réparties sur 3 clairières ; « Allumer la lanterne » (0,3 s, braise du joueur). La première allumée ouvre une **fenêtre de 60 s** pour allumer les 3 autres ; une lanterne allumée **s'éteint après 45 s** si la veillée n'est pas complète (comme les balises de Gilded Coast). |
| **Effet** | Chaque lanterne allumée attire **4 feux follets** (tier 1 rapides 3,2 u/s, 30 % PV, explosent à la mort : cercle 1,5 u télégraphié 0,8 s, coef 0,8 : ceux du Cerf-Lanterne, réutilisés). À la 4e : la **brume se lève** dans 12 u autour de la lanterne-mère (clairière centrale), et la lanterne-mère s'ouvre : **coffre gratuit, table grand coffre** (80 % Peu commun / 20 % Rare). |
| **Coût / risque** | Course chronométrée de 60-80 u (≈ 15-20 s de déplacement pur) à travers 3 clairières avec les follets aux trousses, pendant que le director continue. |
| **Récompense** | 2 P (coffre) + or des 16 follets (≈ 0,1 P) ; bonus de confort : brume levée = lisibilité (utile à Furieux où la brume monte à 15 %). |
| **Director** | Follets = `spawn_pack(&"follet", 4, pos)` hors budget (comme les invocations de boss) ; aucune vague. |
| **Lisibilité** | Lanternes vertes `#9CF0C8` sur la minimap, éteintes = contour, allumées = pleines, avec un **anneau de temps** qui se vide (45 s). OBJECTIFS : « Lanternes 2/4  0:37 ». Son : chaque lanterne monte d'une tierce (gamme pentatonique, comme les pièces). |
| **Téléporteur / pilier** | Compatible avec la charge si la lanterne-mère est la clairière centrale et le gros pilier `G` (25;21) ou (25;47) : au moins 2 lanternes seront hors zone, donc la charge s'arrête : c'est le prix. |
| **Fréquence** | Positions fixes des 4 lanternes (sanctuaires) ; secret **majeur**, 50 % des étages de cette carte. Candidats : lanterne-mère (27;25) (centre, cellule (13,12) libre), lanternes (9;9) clairière NO, (9;45) clairière S, (55;9) terrasse E. Distances mère → lanternes : 24 / 27 / 32 u. |
| **Chiffres** | T ≈ 50-60 s → cible 1-2 P ; livré 2 P (haut de fourchette, mais l'échec est fréquent : une lanterne éteinte = tout à refaire, sans pénalité autre que le temps). Réglage possible : table petit coffre + 1 Chance (1,5 P). |

### 2.3 Cité de rouille : « Le treuil du canal »

| | |
|---|---|
| **Déclencheur** | Un **treuil** (prop 2 u, chaîne et contrepoids) au bord d'une berge, face à une passerelle **relevée** au-dessus du canal (un 4e pont, entre les ponts existants). « Abaisser la passerelle — N or » (**N = 0,5 P**). |
| **Effet** | La passerelle descend en 3 s (anim 8 images) : nouvelles cellules `,` sur le canal (**raccourci permanent** de 18 u entre les berges) ; au milieu de la passerelle, une **caisse rivetée** descend par la grue : coffre gratuit, **table gardien** (1,5 P). |
| **Coût / risque** | Or (0,5 P) et bruit : le treuil **sonne l'alerte** : pendant 20 s, crédits du director ×1,5 et la vague suivante arrive immédiatement (élite en tête garantie). Le joueur est sur un pont de 4 u de large : couloir idéal pour peigner la foule, mais sans fuite latérale. |
| **Récompense** | 1,5 P − 0,5 P = **1 P net** + raccourci (vaut ≈ 5 s par traversée, donc plusieurs P sur un étage de farm) + or de la vague. |
| **Director** | `trigger_wave()` forcée + multiplicateur temporaire `set_credit_mult(1.5, 20 s)` (nouveau). |
| **Lisibilité** | Passerelle relevée visible (silhouette verticale 2,5 u, lampe rouge clignotante) ; treuil sur la minimap (icône ancre) ; OBJECTIFS : « Alerte  0:17 » pendant la vague. Son : sirène de crue étouffée (le thème du Sonneur), chaîne qui file. |
| **Téléporteur / pilier** | Toujours disponible ; utile surtout **avant** d'activer un `G` de berge ((9;27) ou (39;27)) : la passerelle élargit le terrain de la zone de 9 u. |
| **Fréquence** | 2 passerelles candidates (lignes 17-18 et 25-26, cellules de canal `~` colonnes 10-13) ; 1 armée par étage (secret **mineur**, 60 % des étages de cette carte). |
| **Chiffres** | T ≈ 25 s → cible 0,4-0,8 P ; livré 1 P net + raccourci : généreux parce que c'est de l'**or déjà gagné** qui est converti (même logique que les coffres), et parce que le pont est un lieu dangereux. |

### 2.4 Générique : « La porte scellée » (2 plaques → porte → 2 gardiens → 1 objet chacun)

La mécanique demandée ; design détaillé en §3. **Décisions du joueur (21/10/2026)** : les deux plaques s'enfoncent **au passage** et **restent enfoncées** (pas de fenêtre, pas de rebloquage, pas de pénalité : il suffit d'avoir marché sur les deux, dans n'importe quel ordre, à n'importe quel intervalle) ; les gardiens sont des **brutes élites rhabillées et nommées** (v1). Habillages : Terrasses = **deux dalles de vanne** et la **grille d'une citerne** ; Forêt = **deux pierres plates à rune** et un **rideau de racines** ; Cité = **deux plaques de pression industrielles** et une **porte blindée**. Secret **majeur**, 50 % des étages.

### 2.5 Générique : « Le porte-clé » (clé portée par un élite)

| | |
|---|---|
| **Déclencheur** | Un **coffre verrouillé** (cadenas lumineux, 1,3 u) est posé dès l'arrivée, gratuit mais fermé. Entre 0:45 et 1:30 d'étage, le director fait apparaître **un élite « porte-clé »** (tier 2 bondisseur, affixe aléatoire, aura dorée + icône de clé au-dessus, **fuit le joueur** à 3,6 u/s au lieu de l'attaquer, saute par-dessus la foule). Annonce : son de clé + flèche de vague dorée. |
| **Effet** | Sa mort lâche une **clé** (pickup aimanté, ramassage normal). « Ouvrir — clé » sur le coffre : **table gardien** (1,5 P). Si le porte-clé n'est pas tué en **60 s**, il s'enfouit (cercle télégraphié 1,0 s) et la clé est perdue pour l'étage. |
| **Coût / risque** | Chasse de 15-30 s à travers la foule (le joueur est plus rapide : 4,0 contre 3,6 u/s, mais le bondisseur saute les obstacles) ; détour vers le coffre. Les builds mono-cible et projectiles rapides (Plume, Carquois) brillent. |
| **Récompense** | 1,5 P + or de l'élite (prime surchargée : valeur 8 → ≈ 3,8 × coeff or, négligeable). |
| **Director** | `spawn_elite(&"leaper", affix, pos, {"behavior": &"flee", "value": 8, "tag": &"keybearer"})` hors budget, apparition 2-4 u hors champ côté opposé au coffre (pour que la chasse traverse la carte). |
| **Lisibilité** | Coffre verrouillé sur la minimap (cadenas) ; porte-clé toujours affiché sur la minimap tant qu'il vit (point doré) ; OBJECTIFS : « Porte-clé  0:48 ». |
| **Téléporteur / pilier** | Le porte-clé n'apparaît pas pendant une zone active (il attend la fin) ; la clé reste valable après `floor_cleared` (farm). |
| **Fréquence** | Le coffre verrouillé est tiré parmi les candidats `C` non utilisés (comme le légendaire, ≥ 20 u du spawn) ; secret **mineur**, 40 % des étages, toutes cartes. |
| **Chiffres** | T ≈ 30-40 s → cible 0,5-1,3 P ; livré 1,5 P : haut, car ≈ 30 % d'échecs attendus (porte-clé perdu dans la foule). |

### 2.6 Générique : « La stèle de défi » (sanctuaire de combat)

| | |
|---|---|
| **Déclencheur** | Stèle de 2 u gravée, « Accepter le défi » (gratuit). |
| **Effet** | **25 s** : une vague de **30-40 monstres** avec **2 élites** en tête arrive immédiatement d'un bord, crédits ×2 pendant la durée, **or ×2** sur tout ce qui meurt à < 12 u de la stèle. À la fin, si le joueur est encore à < 12 u : la stèle crache **une capsule « lourde »** (3 × capsule = 1,2 P). |
| **Coût / risque** | 25 s de pression maximale, à côté d'une stèle qu'il ne faut pas quitter. |
| **Récompense** | Or ≈ 4 × le farm normal sur 25 s (≈ 1,1 P) + 1,2 P de capsule ≈ **2,3 P** ; aucun objet garanti. |
| **Director** | `trigger_wave(count 30-40, leaders 2)` + `set_credit_mult(2.0, 25 s)` + `set_gold_mult_zone(center, 12 u, 2.0, 25 s)`. |
| **Lisibilité** | Anneau blanc bleuté de 12 u (palette des zones §0) ; OBJECTIFS : « Défi  0:19 ». |
| **Téléporteur / pilier** | Refusée si un pilier est actif à < 20 u (comme le Sanctuaire de risque). |
| **Fréquence** | Remplace ou fusionne avec le **Sanctuaire de risque** de §4.4 (45 s, ×1,5, petit coffre) : garder un seul « défi » par carte (question §5). Secret **mineur**, tiré avec les événements de carte. |
| **Chiffres** | T = 25 s → cible 0,4-0,8 P ; livré ≈ 2,3 P : volontairement au-dessus, parce que c'est **la** mécanique de prise de risque pure (à tempérer en Difficile : capsule lourde seulement si ≥ 60 % des PV à la fin ?). À valider en playtest. |

### 2.7 Générique : « Le coffre-horloge » (coffre scellé à minuteur)

| | |
|---|---|
| **Déclencheur** | Un **grand coffre gratuit** à cadran (1,3 u, aiguille visible) posé ≥ 24 u du spawn (règle du légendaire), **se verrouille à 2:00 de temps actif d'étage**. « Ouvrir » tant que le cadran tourne. |
| **Effet** | Table grand coffre (2 P). Après 2:00 : cadenas tombé, aiguille rouge, plus jamais ouvrable. |
| **Coût / risque** | Aucun combat imposé : le coût est le **tempo** : aller le chercher dans les 2 premières minutes (le joueur est faible, l'or est rare, les petits piliers attendent) au lieu de suivre le chemin optimal spawn → coffres proches → piliers. |
| **Récompense** | 2 P gratuits pour un détour de ≈ 15-25 s. |
| **Director** | Aucun lien. |
| **Lisibilité** | Icône horloge sur la minimap avec le temps restant ; OBJECTIFS : « Coffre-horloge  1:12 » tant qu'il n'est ni ouvert ni verrouillé ; tic-tac audible à < 10 u, qui accélère dans les 20 dernières secondes. |
| **Téléporteur / pilier** | Le minuteur est en temps actif (pause et écrans de coffre ne comptent pas) ; il **continue pendant une zone** : activer un petit pilier avant est un vrai choix. |
| **Fréquence** | Tiré parmi les `C` ≥ 24 u du spawn ; secret **mineur**, 35 % des étages. Jamais en même temps qu'un coffre légendaire (même budget de candidats éloignés). |
| **Chiffres** | T ≈ 20 s → cible 0,3-0,7 P ; livré 2 P : c'est un **coffre gratuit de plus** 1 étage sur 3, soit +0,7 P par étage en moyenne, ≈ +3 % d'objets par run : acceptable, et le détour précoce coûte de l'ordre d'un coffre en or non farmé. |

### 2.8 Générique : « Le mur fissuré » (passage révélé par un sort)

| | |
|---|---|
| **Déclencheur** | Une cellule de mur `X` avec une **fissure lumineuse** (liseré émissif, 2 px, même palette que les murets) ; c'est une cible **destructible** (groupe `breakable`, couche 3 côté dégâts, **PV = 8 × Dégât_base(L)** ≈ 10 coups de sort 1 ou 2 sorts à recharge, 2-4 s). Sur PC on la vise ; sur mobile/manette, le ciblage automatique la choisit **seulement si aucun monstre n'est à < 3 u** (priorité basse) : s'approcher du mur suffit. |
| **Effet** | Le mur s'effondre (débris 1 s, poussière) : la cellule devient `.` **pour le reste de l'étage** : ouvre une **niche** (1-3 cellules) contenant **2 capsules** ou un **raccourci** entre deux arènes (ex. Terrasses : à travers le muret de la ligne 8 ou 19 ; Cité : à travers le mur central de la cour haute, colonnes 12-13). |
| **Coût / risque** | 5-15 s ; le joueur tape un mur dos à la foule. |
| **Récompense** | 0,8 P (niche) ou un raccourci (≈ 3-6 s par traversée). |
| **Director** | Aucun ; NavField et occluders doivent être **recalculés localement** (nouveau contrat `map_cells_changed`). |
| **Lisibilité** | Fissure visible à 10 u, minimap : petit trait clair sur le mur ; pas de ligne OBJECTIFS (c'est le « petit secret » qu'on remarque). Son : pierre qui craque à chaque coup, éboulement à la fin. |
| **Téléporteur / pilier** | Sans interaction. |
| **Fréquence** | 2-4 candidats `X` par carte, 1 armé par étage (70 % des étages) ; non armé = mur normal. Compte comme **mineur** seulement s'il donne des capsules (un raccourci seul ne compte pas dans le budget). |
| **Chiffres** | T ≈ 10 s → cible 0,15-0,35 P ; livré 0,8 P : volontaire, c'est la récompense de l'**attention** (on peut passer un étage sans le voir). |

### 2.9 Générique : « L'autel de la pluie » (consomme des PV ou de l'or)

| | |
|---|---|
| **Déclencheur** | Autel de 2 u à deux vasques. Deux offrandes, chacune 3 usages max par étage : **Sang** : « Offrir 50 % des PV actuels » (jamais sous 10 % des PV max) ; **Or** : « Offrir N or » (N = 0,6 P). |
| **Effet** | **Sang → or** : rend 0,5 P × 1,3^n (n = usages déjà faits : 0,5 / 0,65 / 0,85 P). **Or → soin et protection** : soigne 40 % des PV max et donne un bouclier de 30 % des PV max pendant 20 s (le pendant de Sang : on achète la survie avant un pilier). |
| **Coût / risque** | Sang : perdre la moitié de sa vie au milieu d'une foule ; Or : 0,6 P. |
| **Récompense** | Sang : jusqu'à 2 P sur 3 usages pour 3 × 50 % de PV (≈ 20 s de régénération par usage avec Cœur de mousse) ; Or : un « plein » avant le boss d'étage. |
| **Director** | Aucun. |
| **Lisibilité** | Les deux vasques s'allument (rouge sang / or) selon ce qui est disponible ; le bouton Interagir alterne les deux offrandes avec un appui long (ou deux boutons empilés sur mobile : à valider UI). |
| **Téléporteur / pilier** | Utilisable pendant la charge (c'est son intérêt : se soigner sans quitter la zone si l'autel est dedans). |
| **Fréquence** | Tiré parmi les `E` (il rejoint la famille des événements de carte, mineur, 1 par étage au plus). |
| **Chiffres** | Sang : T ≈ 5 s mais le vrai coût est le risque ; 0,5 P par usage = 45 s de farm économisées pour 50 % de PV : juste. Or → soin : 0,6 P pour +70 % de PV effectifs pendant 20 s : cher mais ciblé (juste avant un boss). |

### 2.10 Vue d'ensemble

| # | Mécanique | Carte | Type | T (s) | Récompense | Ratio vs farm |
|---|---|---|---|---|---|---|
| 2.1 | Écluse | Terrasses | majeur | 40 | 1,4 P (remise + capsule) + refuge | ×3 |
| 2.2 | Veillée des lanternes | Forêt | majeur | 55 | 2 P (coffre grand) | ×3 |
| 2.3 | Treuil du canal | Cité | mineur | 25 | 1 P net + raccourci | ×3,5 |
| 2.4 | Porte scellée | toutes | majeur | 60 | 2 × 1,5 P (gardiens) | ×4,5 (50 % des étages) |
| 2.5 | Porte-clé | toutes | mineur | 35 | 1,5 P | ×4 (30 % d'échec) |
| 2.6 | Stèle de défi | toutes | mineur | 25 | ≈ 2,3 P en or | ×8 (risque pur, à tempérer) |
| 2.7 | Coffre-horloge | toutes | mineur | 20 | 2 P | ×9 mais 35 % des étages, coût de tempo |
| 2.8 | Mur fissuré | toutes | (mineur) | 10 | 0,8 P ou raccourci | ×7 (attention) |
| 2.9 | Autel de la pluie | toutes | mineur | 5 | 0,5-2 P / soin | ×1 (échange) |

Budget d'objets : avec 1 majeur (50 %) + 1 mineur (≈ 60 %) par étage, l'espérance est ≈ +1,3 P d'objets par étage (+0,9 P d'or), soit ≈ **+3 objets par run de 3 étages** (28 → 31) pour ≈ +1:30 de temps actif (≈ +0,25 de coeff en fin de run). Cohérent avec la courbe cible §11 de Maths (power fantasy en fin d'étage 2-3).

---

## 3. Design détaillé : « La porte scellée » (2 plaques → porte → 2 gardiens → 1 objet chacun)

### 3.1 Habillage par biome

| Carte | Plaques (au passage, définitives) | Porte | Gardiens (élites tier 3 « brute » rhabillés) | Affixes |
|---|---|---|---|---|
| Terrasses noyées | 2 **dalles de vanne** (pierre moussue cerclée de bronze, s'enfonce de 0,2 u, un filet d'eau jaillit) | **grille de citerne** (2 cellules, barreaux, eau qui suinte) | **Les Noyés** : *Orme* et *Aulne*, brutes couvertes de vase, lanterne de pierre sur l'épaule | Ralentissement + Poison |
| Forêt-brume | 2 **pierres plates à rune** (la rune s'allume vert pâle) | **rideau de racines** qui s'écarte | **Les Veilleurs** : *Lierre* et *Houx*, brutes à ramure de bois mort | Poison + Brûlure (follets) |
| Cité de rouille | 2 **plaques de pression** rivetées (voyant qui passe au rouge, déclic) | **porte blindée** à volant | **Les Chaudronniers** : *Rivet* et *Soudure*, brutes en plaques de chaudière | Brûlure + Ralentissement |

**Plaque** : `Area2D` au sol (1 cellule, 2 × 2 u, masque joueur), **déclenchée par le simple passage du joueur** (décision du joueur : exception à la règle « jamais au contact »), état `pressed` **définitif** pour l'étage ; aucune interaction, aucun bouton. Les monstres ne la déclenchent pas (masque 2 seulement). Son : « clac » sourd + mécanisme, le glyphe de la porte s'allume d'un cran.

Les gardiens sont **nommés** (barre de vie nommée, comme les boss) : c'est ce qui rend le secret mémorable (RoR2 : Kjaro et Runald). **Validé par le joueur (21/10/2026)** : en v1 ils réutilisent le squelette, les anims et le gabarit de la brute tier 3 ; seul le sprite change (variante Codex, §4.6).

### 3.2 Emplacement de référence : Terrasses noyées, la citerne de la ruine centrale

La grille actuelle contient déjà une **poche murée de 2 × 4 cellules (4 × 8 u) inaccessible** à l'intérieur de la ruine centrale (lignes 19-24, colonnes 16-19). Elle devient la citerne. Extrait annoté (colonnes en haut ; y = ligne × 2 u ; les lettres nouvelles sont expliquées dessous) :

```
         colonne: 0         1         2
                  0123456789012345678901234567
ligne 17 (y 34)   #..........G..........P.~~.#
ligne 18 (y 36)   #....C......a..........b~..#    a = dalle de vanne 1, centre (25;37)   b = dalle 2, centre (47;37)
ligne 19 (y 38)   #..######.......#DD#.......#    DD = grille de la citerne (porte, 2 cellules), centre (36;39)
ligne 20 (y 40)   #..#...C........#g:#...C...#    g = gardien Orme, (35;41)
ligne 21 (y 42)   #..#............#::#.......#    : = sol scellé (eau peu profonde, ni capsule ni apparition tant que fermé)
ligne 22 (y 44)   #..####.........#:g#..####.#    g = gardien Aulne, (37;45)
ligne 23 (y 46)   #...............#::#.......#
ligne 24 (y 48)   #..C.....P......####...P...#
```

- **Porte** : les deux cellules `##` de la ligne 19, colonnes 17-18, deviennent `DD` (solides tant que fermées ; une fois ouvertes, `.`). Elle donne sur l'**arène B** (grande terrasse centrale, celle du spawn (31;31), à 9 u) : le joueur la voit dans les 10 premières secondes de l'étage.
- **Plaques** : `a` (25;37) et `b` (47;37), sur la ligne 18, **22 u l'une de l'autre** (5,5 s de course), chacune à **11 u de la porte**. Les cellules sont du sol libre aujourd'hui ; les candidats de coffre voisins (21;31), (47;41) et de pilier (45;35) ne bougent pas. Comme elles se déclenchent au passage et pour de bon, l'écart entre les deux n'est plus une contrainte de temps : c'est seulement un **détour** (≈ 11 s aller-retour depuis la porte) que le joueur fait quand il veut, par exemple en allant d'un coffre à un pilier.
- **Citerne** : cellules (17-18, 20-23) marquées `:` : sol praticable **seulement une fois la porte ouverte**. Aujourd'hui ces cellules sont `.` : `StageManager._capsule_candidates()` et le spawn des monstres peuvent donc **déjà y tirer des positions injoignables** (à corriger en même temps, §4.1).
- **Taille** : 4 × 8 u, trop étroit pour s'y battre à trois (brutes de 2,5 u) : c'est voulu, **les gardiens sortent** se battre dans l'arène B (34 × 20 u), la citerne est leur dortoir et le lieu des coffres.

Emplacements pour les deux autres cartes (mêmes règles, à régénérer par `gen_maps.py`) :
- **Forêt-brume** : le petit sanctuaire fermé à l'ouest du spawn, lignes 13-17 / colonnes 10-14 (intérieur 3 × 3 cellules, entrée actuelle au sud en (13,17) → devient `D` ; le coffre candidat (25;31) intérieur devient le dortoir des gardiens et est retiré de la liste `C`). Pierres levées en (15;23) (cellule (7,11), arène B) et (45;35) (cellule (22,17), arène C). Entrée à 1 cellule de large : les gardiens sortent l'un après l'autre (2 s d'écart), ce qui lisse le pic de danger.
- **Cité de rouille** : salle blindée à creuser dans la cour haute ouest, intérieur colonnes 7-11 × lignes 1-4 (10 × 8 u), murs nouveaux colonne 6 (lignes 1-4) et ligne 5 (colonnes 7-11), porte `DD` en (8,5)-(9,5) ; l'événement `E` (13;11) en (6,5) est conservé. Générateurs en (7;11) (cellule (3,5)) et (31;5) (cellule (15,2), cour haute est, de l'autre côté du mur central : 24 u par la brèche). À vérifier après régénération : le disque de 7 u du petit pilier (9;7) garde ≥ 70 % de sol praticable (estimation ≈ 78 %).

### 3.3 Flux pas à pas et timings (Terrasses, étage 1, Moyen)

| t | Étape | Ce que voit / entend le joueur |
|---|---|---|
| 0:00 | Étage armé (tirage 50 %). La grille porte un **glyphe émissif** cyan à **deux crans éteints** ; les deux dalles pulsent (0,5 Hz, liseré émissif). Minimap : porte (trait épais clair) + 2 icônes de dalle. Les gardiens sont visibles **à travers les barreaux**, immobiles, lanterne éteinte (murs de 1,25 u avec fondu : l'intérieur se lit en iso). | Pas de ligne OBJECTIFS (rien n'est engagé). |
| n'importe quand | Le joueur **marche sur la dalle `a`** (ou `b`, ordre libre) : elle s'enfonce (anim 6 images, 0,3 s), **reste enfoncée pour tout l'étage**, le joueur n'est ni arrêté ni ralenti. | « Clac » + filet d'eau ; **premier cran** du glyphe allumé ; OBJECTIFS : **« Dalles  1/2 »** (ligne optionnelle, sans compte à rebours). Minimap : l'icône de la dalle devient pleine. |
| plus tard (0 s ou 3 min après, peu importe) | Le joueur marche sur la **seconde dalle**. | « Clac », **grondement 1,0 s** (secousse légère, désactivable), la grille se lève (anim 0,8 s, 8 images), la cellule `DD` devient praticable (`map_cells_changed`). OBJECTIFS : **« Gardiens  0/2 »**. Les deux gardiens s'éveillent : **télégraphe 1,0 s** (cercle rouge 2,5 u sous chacun, lanterne qui s'allume), puis sortent par la porte à 2,2 u/s, Orme d'abord, Aulne 1,5 s après. Musique : couche de percussions des mini-boss. |
| Combat (≈ 15-30 s) | Brutes élites : auto = coup en cône 90°, 2,5 u, préparation 0,5 s ; passif Carapace (−40 % de face). Elles **poursuivent sans limite** (pas de laisse : à 2,2 u/s, le joueur garde l'initiative), **immunisées aux poussées, ralentissements ×0,5** (règle des boss). Le director ne s'arrête pas. | Barres de vie nommées (HUD boss, 2 barres empilées, comme deux petits piliers simultanés). Chaque mort : compteur 1/2 puis 2/2, son de pierre tombale. |
| Mort d'un gardien | Il lâche sur place un **reliquaire** (coffre gratuit 1 u, kind `&"gardien"`, chaîne rompue, lumière verte `#9CF0C8`) : « Ouvrir » → d100 sur la table gardien, 2 cartes, choix / relance normale (or ou pub, même plafonds). Les deux reliquaires sont indépendants. | Le reliquaire **ne disparaît jamais** (utile après `floor_cleared`, en farm). |
| Après | La citerne reste ouverte : refuge de 4 × 8 u (eau peu profonde, les monstres n'y apparaissent pas, 1 seule entrée) : une cachette pour la fin de charge du gros pilier (25;51) à 12 u. | OBJECTIFS : ligne retirée 3 s après « 2/2 ». |

**Si une seule dalle est enfoncée** : il ne se passe rien d'autre que le premier cran du glyphe et la ligne « Dalles 1/2 » ; elle **reste enfoncée** jusqu'à la fin de l'étage, sans limite de temps, sans pénalité. Repasser dessus ne fait rien. Le joueur peut donc enfoncer la première au passage vers un coffre et revenir sur la seconde quand il se sent prêt pour les gardiens : **le choix du moment du combat lui appartient**, et c'est la seule « énigme » : avoir vu qu'il y a deux dalles (indices : les deux crans du glyphe, les deux icônes de minimap). Sauvegarde : l'état `pressed` de chaque dalle. La seconde dalle enfoncée **pendant une zone de pilier active** ouvre quand même la porte (les gardiens s'ajoutent à la pression : c'est le risque du joueur, aucun garde-fou).

### 3.4 Chiffres des gardiens

| Grandeur | Valeur | Justification |
|---|---|---|
| Base | brute tier 3 : PV 300, dégâts 30, 2,2 u/s | Gabarit existant, `TIER_STATS[3]` |
| Élite | PV ×4, dégâts ×2 (`ELITE_HP`, `ELITE_DMG`), 1 affixe (2 à coeff ≥ 3, règle `elite_affix_count`) | Règles du jeu, pas d'exception |
| PV à 2:00 étage 1 (coeff 1,3, niveau 1) | ≈ 1 200 chacun, 2 400 au total | ≈ 1,5 mini-boss (1 300 à coeff 1) ; DPS joueur à 2:30 ≈ 150 → ≈ 8 s par gardien en contact, 20-30 s en réel |
| Coup le plus lourd | 60 × (1 + 0,2 × (niv − 1)), **plafond 25 % des PV max** (monstre, pas boss) | 2 coups = 50 % des PV : dangereux, jamais mortel d'un coup ; `is_in_group("bosses")` = non |
| Prime d'or | **valeur director surchargée 12** → or = 2 × coeff × 12 × 0,235 ≈ 5,6 × coeff (≈ 0,1 P) | Sans surcharge, une élite tier 3 vaut 34 × coeff or ≈ 0,6 P : la récompense serait doublée par accident |
| XP | moitié de l'or (règle des kills) | |
| Reliquaire | table **36 / 49 / 13 / 2** (= petit coffre avec 1 Chance : best of 2 d100) ; Chance du joueur s'ajoute ; pity **non** consommé ni incrémenté | 2,33 poids ≈ 1,5 P chacun |

**Valeur attendue** : 3 P d'objets + 0,2 P d'or pour T ≈ 10 s (détour des dalles) + 25 s (combat) + trajets ≈ **50-60 s**, soit ×4,5 la valeur du farm, **1 étage sur 2**. C'est le secret le plus généreux du catalogue, à dessein : il demande la lecture de la carte et un double combat d'élites à coeff bas (sans la course chronométrée, le coût est surtout le combat : d'où l'importance que les gardiens restent dangereux, 25 % des PV par coup). Levier de réglage si trop fort en télémétrie : table petit coffre sans Chance (2 × 1 P), ou fréquence 35 %.

---

## 4. Implémentation à prévoir (après la phase 0 iso)

### 4.1 Données : grilles et `tools/gen_maps.py`
- Nouveaux caractères de grille (seulement ce qui touche la **collision**) : `D` porte scellée (solide tant que fermée, rectangle de collision **séparé** nommé `Door<id>` pour pouvoir le désactiver), `:` sol scellé (praticable, **exclu** des candidats de capsules et des cellules d'apparition tant que la porte est fermée), `X` mur fissuré (solide, destructible), `w` eau profonde vidangeable (solide, devient `,`). Les marqueurs ponctuels vont dans une liste `secrets` du dict `MAPS` (comme `chests`), pas dans la grille : `[{id, kind: sealed_door|sluice|lanterns|winch|keybearer|timed_chest|cracked_wall|altar|challenge, cells/door_cells/room_rect/plates/guardians/…}]`.
- `gen_maps.py` : validation (porte adjacente à la salle, salle entièrement close hors porte, plaques sur `.`, ratio praticable des piliers recalculé **porte fermée**), génération des `Marker2D` groupe `secret_spawn` (métadonnées `secret_id`, `role`), export JSON `secrets` + `dynamic_cells`. `maps_test` étendu.
- Correction incluse : les cellules `.` injoignables (poche actuelle) ne doivent plus recevoir capsules ni apparitions.

### 4.2 Scènes et scripts Godot (nouveaux dossiers `scripts/secrets/`, `scenes/secrets/`)
- `interactable.gd` (**classe de base générique**, `Area2D` couche 7, masque 2, groupe `interactable`) : `can_interact()`, `interact_label()`, `interact()`, `set_armed(bool)`, portée, lumière `LightRig` d'état, sprite billboard iso (`Iso.UNSQUASH`, `SPRITE_K`). Coffre, pilier, téléporteur, capsule migrent dessus **plus tard** (hors lot).
- `pressure_plate.gd` (dalle/pierre/plaque : `Area2D` au sol déclenchée par l'entrée du joueur, états `armed` / `pressed` définitif, **pas un `interactable`**), `sealed_door.gd` (collision `Door<id>` on/off, anim, occluder, `map_cells_changed`), `secret_room.gd` (contrôleur : plaques → porte → gardiens → reliquaires, OBJECTIFS), `sluice.gd`, `lantern.gd` + `lantern_vigil.gd`, `winch.gd`, `timed_chest.gd` (variante de `chest.gd`, kind `&"horloge"`), `cracked_wall.gd` (`breakable`, PV, débris), `rain_altar.gd`, `challenge_stele.gd`, `locked_chest.gd` + `key_pickup`.
- `enemies/` : variante `guardian` (nommé, prime surchargée, immunité poussée, ralentissement ×0,5, pas de LOD/despawn), comportement `flee` pour le porte-clé, **cible destructible** pour le ciblage auto (priorité basse).
- `stage_map.gd` : `set_cell_kind(cell, kind)` → collision, tuile visuelle, `NavField.rebuild_local(rect)`, `OccluderBuilder.rebuild_local(rect)`, minimap (image en repère carte mise à jour).
- `director.gd` : `spawn_elite(kind, affix, pos, opts)`, `spawn_pack(kind, n, pos)` hors budget, `trigger_wave(opts)` paramétrée (count, leaders, side), `set_credit_mult(mult, duration)`, `set_gold_mult_zone(center, radius, mult, duration)`.
- `ui/objectives_panel.gd` : **ligne optionnelle** (`set_optional(text, value, color)` / `clear_optional()`), relue depuis `StageManager.secret_status()` ; `ui/minimap.gd` : marqueurs `secret` (porte, engrenage, lanterne, cadenas, horloge, ancre, fissure) ; `ui/hud.gd` : barres de vie nommées empilées (2 gardiens).

### 4.3 Signaux `Events` à ajouter (orchestrateur)
`secret_armed(id, kind)`, `secret_step(id, step, total, time_left)` (time_left = −1 sans minuteur), `secret_opened(id)`, `secret_failed(id)`, `plate_pressed(plate, pressed_count, total)`, `door_opened(door)`, `guardian_killed(enemy, index, total)`, `map_cells_changed(cells: Array[Vector2i], kind)`, `timed_chest_locked(chest)`, `key_collected()`, `challenge_started(center, duration)` / `challenge_ended(success)`. Réutilisés : `enemy_killed`, `chest_opened`, `pillar_state_changed`, `floor_cleared`.

### 4.4 Sauvegarde (`RunState` inchangé ; `StageManager.to_dict()` / `run_save.gd`)
- Nouveau bloc `"secrets": [{id, kind, state, time_left, plates: [bool], door_open, guardians_dead: [bool], relics: [{pos, opened}], cells_changed: [...]}]`. Gardiens vivants : déjà couverts par la sauvegarde des monstres (type, PV, affixes) + champ `name`/`secret_id`. Coffre-horloge : `remaining_s`. Bassin vidé / mur brisé : rejoués via `cells_changed` **avant** le NavField.
- Montée de `RunSave.VERSION` (déjà prévue par la migration iso : une seule montée, à grouper).
- Règle GDD §4 : si l'app est tuée pendant l'ouverture d'un reliquaire, les 2 mêmes items reviennent (même mécanisme que les coffres).

### 4.5 Tests (`game/tests/`)
`secrets_test.tscn` : plaques (ordre libre, déclenchement par le corps du joueur seulement, pas par un monstre, état définitif, repasser ne change rien, porte ouverte seulement quand les deux sont enfoncées), porte (solide fermée / praticable ouverte, NavField mis à jour, un monstre peut sortir), gardiens (prime surchargée, 2 reliquaires, compteur), sauvegarde/chargement avec une dalle enfoncée et avec un gardien vivant, coffre-horloge (verrouillage à 120 s actif, pas en pause), mur fissuré (PV, ciblage auto en priorité basse), écluse (cellules `w` → `,`, capsule au fond). `maps_test` : validation des 3 cartes (salle close, plaques sur `.`, ratios de piliers). `objectives_test` : ligne optionnelle. `economy_test` : +1 scénario avec un secret majeur (espérance d'or/objets par étage dans la fourchette §2.10).

### 4.6 Assets à demander à Codex (rig iso MAP sauf mention ; DA officielle sérieuse ; `_n`, `_e` si émissif, **ombres cuites + `<f>_shadow.png`**)
| Lot | Asset | Spec |
|---|---|---|
| S-A | Portes scellées ×3 (grille de citerne, rideau de racines, porte blindée) | emprise 2 cellules (512 × 256), hauteur 1,25 u, états fermée / ouverture (8 images) / ouverte ; glyphe émissif séparé `_e` ; ombre cuite |
| S-A | Plaques ×3 paires (dalle de vanne, pierre plate à rune, plaque rivetée) | décalque au sol 1 cellule (2 u, rig **TOP** pour le plat + relief léger rendu MAP), états armée (liseré émissif, boucle 8) / enfoncement (6 images) / enfoncée ; 1 variante par biome |
| S-B | Gardiens ×3 paires (Noyés, Veilleurs, Chaudronniers) | rig **CREA**, mêmes frames et directions que la brute tier 3 (192² à R = 90,51), lanterne/ramure émissive `_e` ; effort `medium` |
| S-B | Reliquaire | coffre 1 u, variante « chaîne rompue », lumière verte ; 3 états |
| S-C | Roue d'écluse, treuil + passerelle (relevée / descente 8 images / posée), caisse rivetée, coffre-horloge (cadran : aiguille animée **en code** sur une couche séparée), coffre verrouillé + clé (pickup, rig CREA), mur fissuré ×3 biomes (intact / brisé + 6 débris), autel à deux vasques, stèle de défi, lanterne de pierre allumée (réutiliser le prop existant + état allumé) | MAP, 1-2 u, ombres cuites |
| S-D | Décalques au sol (rig **TOP**) | anneau de défi 12 u, boue du bassin vidé (tuile 2 u), flaque de vase sous les gardiens, icônes minimap (kit UI, hors Blender) |

### 4.7 Découpage en lots (après P0 iso et L1 ; code Claude en parallèle, Codex un lot à la fois)
| Lot | Agent | Dossiers | Contenu | Dépend de |
|---|---|---|---|---|
| Z0 | orchestrateur | `scripts/core/events.gd`, `CONTRACTS.md` | signaux §4.3, contrats `Interactable`, `Director.*` nouveaux | L1 |
| Z1 | Opus | `tools/`, `data/maps`, `scripts/stage`, `scripts/director`, `scripts/save` | grilles + `gen_maps` (§4.1), cellules dynamiques, NavField local, director (§4.2), sauvegarde (§4.4) | Z0 |
| Z2 | Sonnet | `scripts/secrets`, `scenes/secrets`, `scripts/enemies` (variante gardien, flee, breakable) | **Porte scellée** complète sur Terrasses (placeholders), puis écluse, horloge, mur fissuré | Z0 (Z1 pour la porte réelle) |
| Z3 | Sonnet | `scripts/ui` | ligne OBJECTIFS optionnelle, marqueurs minimap, barres nommées empilées | Z0 |
| Z4 | Sonnet | `scripts/secrets` | lanternes, treuil, porte-clé, stèle, autel | Z2 |
| Z5 | Haiku → Sonnet | `tests/`, docs | tests §4.5, mise à jour `Design_Boss_Cartes.md` §4 (grilles) et `CONTRACTS.md` | Z1-Z4 |
| Codex | S-A → S-B → S-C → S-D | `art/` | après C1/C8 (terrain terrasses, coffres/piliers) pour partager les matières | C1, C8 |

Ordre conseillé : **Z0 → Z1 ‖ Z2 ‖ Z3 → Z4 → Z5**, la porte scellée des Terrasses d'abord (carte P0, poche existante : aucune modification de l'arène), les autres cartes à la livraison de C2/C3.

---

## 5. Questions ouvertes pour le joueur (avec recommandation)

**Tranché par le joueur (21/10/2026)** : plaques enfoncées au passage et définitives, sans fenêtre de temps ni pénalité ; gardiens = brutes élites rhabillées et nommées en v1 (un sort unique par paire possible en LiveOps si le secret plaît).

Restent ouvertes :
1. **Générosité de la porte scellée** : 2 reliquaires à table « gardien » (≈ 3 P, 1 étage sur 2) ou 2 petits coffres simples (2 P) ? **Reco : généreux au départ** (la découverte doit payer), fréquence 50 %, et on ajuste par télémétrie (taux d'ouverture, taux de mort pendant le combat). Sans course chronométrée, le combat est le seul coût : si la télémétrie montre > 80 % d'ouvertures sans mort, passer à 2 P.
2. **Stèle de défi vs Sanctuaire de risque** (§4.4 des cartes) : les deux font « vague contre or ». **Reco : fusionner** : garder la Stèle (25 s, deux élites, capsule lourde), supprimer le Sanctuaire de risque, et réserver le Sanctuaire de la montagne (boss d'étage doublé → 2 coffres de boss) à une version ultérieure.
3. **Budget par étage** : 1 majeur + 1 mineur maximum (reco), ou laisser le tirage libre (jusqu'à 3 secrets sur un étage) ? **Reco : 1 + 1**, en fusionnant ce tirage avec celui des 4 événements de carte existants (un seul tirage seedé « animations d'étage », 60 % → 85 % de chance qu'il se passe quelque chose), pour que chaque étage reste lisible en 4-5 min.
4. (Nouveau, lié à docs/Design_Etages.md) **Un secret majeur par variante de carte** : la porte scellée est placée dans la grille, donc chaque variante A/B d'un biome a son propre emplacement (et peut avoir un autre secret majeur : écluse en A, porte en B). **Reco : oui**, c'est ce qui différencie le plus les deux variantes à l'usage.
