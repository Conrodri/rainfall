# Structure des étages, biomes et roster de boss (design v1, planification)

> Statut : **proposition de game design** suite à la décision du joueur du 21/10/2026 (CLAUDE.md « Structure des étages façon RoR2 ») : *l'étage N a toujours le même biome (même DA), tiré parmi 2 variantes de carte ; étages 1-4 = 4 biomes ; étage 5 = étage de boss final, sans variante. Par étage : au moins 3 boss d'étage différents et 5 mini-boss. Tous dans la DA d'ash_lord (lot R8a, validée), déclinée par biome.*
> Aucun code ni asset modifié par ce document. Cohérent avec `Design_Boss_Cartes.md` (boss et cartes existants), `Direction_Lumiere_Ambiance.md` (heures et lumières), `Design_Isometrique.md` (lots d'assets iso), `Design_Zones_Secretes.md` (secrets placés dans les grilles), `Maths_Scaling.md` / `balance.gd` (coeff × 1,15 par étage, TIME_COMPRESSION « étage de 5 min »).
> Règle de propriété intellectuelle (GDD §13) : on s'inspire des **mécaniques** de RoR2, jamais des noms, assets ni designs.

---

## 0. Résumé

| Étage | Biome (DA fixe) | Variantes | Boss d'étage (tirage 1 parmi ≥ 3) | Mini-boss (2 petits piliers, tirés parmi ≥ 5) |
|---|---|---|---|---|
| 1 | **Terrasses noyées** (rizières, pierre moussue, bronze ; fin d'après-midi) | A `terrasses_noyees` (existante), B « Rizières hautes » | Éclusier (existant), Bouvier, Porteuse de jarres | Colosse de pierre, Ours de givre (existants), Héron de fer, Crapaud-cuve, Épouvantail faucheur |
| 2 | **Forêt-brume** (mangrove, cèdres, lanternes ; aube bleue) | A `foret_brume` (existante), B « Mangrove des lanternes » | Cerf-Lanterne (existant), Tisseuse, Cèdre-Ermite | Reine des ronces, Essaim-mère (R8b en cours), Loup de brume, Chouette-lanterne, Mante de mousse |
| 3 | **Cité de rouille** (canal industriel, cuves, vapeur ; crépuscule d'orage) | A `cite_rouille` (existante), B « Fonderie du canal » | Sonneur (existant), Grue, Fondeur | Seigneur des cendres (R8a fait), Archonte rouillé (existant), Molosse à vapeur, Rémouleur, Pompe aveugle |
| 4 | **Cryptes noyées** (nouveau : cavernes et ossuaires sous la cité, cristaux, eau noire ; sans soleil) | A « Cryptes noyées », B « Ossuaire des pluies » | Reclus, Mère-Cristal, Anguille des profondeurs | Porte-ossuaire, Nuée aveugle, Golem de sel, Lanternier aveugle, Crabe-sarcophage |
| 5 | **La Source** (arène unique, sanctuaire sous le puits de pluie) | aucune | **Le Semeur de pluie** (boss final, 3 phases ; nombre à trancher §4) | aucun (pas de petits piliers) |

Une run = 5 étages (≈ 22-25 min à 4-5 min l'étage : **à confirmer**, le GDD visait 10 min pour 3 étages, voir §8). Le mode sans fin reboucle sur les biomes 1-4 (étages 6-9) puis la Source (10), coeff ×1,15 par étage sans réinitialisation.

---

## 1. Référence : la structure d'une boucle dans Risk of Rain 2

Pages consultées (riskofrain2.wiki.gg, 21/10/2026) : [Environments](https://riskofrain2.wiki.gg/wiki/Environments), [Commencement](https://riskofrain2.wiki.gg/wiki/Commencement), [Teleporter](https://riskofrain2.wiki.gg/wiki/Teleporter), [Abandoned Aqueduct](https://riskofrain2.wiki.gg/wiki/Abandoned_Aqueduct) (plaques, autels de Newt).

| Fait RoR2 | Détail (wiki) | Transposition Rainfall |
|---|---|---|
| **Étages fixes par position** | Étage 1 : Distant Roost, Titanic Plains, Siphoned Forest (+ DLC) ; étage 2 : Abandoned Aqueduct, Wetland Aspect… ; étage 3 : Rallypoint Delta, Scorched Acres… ; étage 4 : Abyssal Depths, Siren's Call, Sundered Grove… ; étage 5 : Sky Meadow (+ Helminth Hatchery). Un environnement ne revient pas deux fois dans une boucle | Même principe, mais **un seul biome par étage** (décision du joueur) : la DA de l'étage 1 est toujours celle des Terrasses. Les « environnements » alternatifs de RoR2 deviennent nos **variantes A/B** du même biome |
| **Variantes de plan** | Chaque environnement a « trois variations de stage ou plus » (disposition des interactables, parfois des passages) ; certains ont des variantes réservées à la 2e boucle (Viscous Falls, Iron Auroras…) | 2 variantes par biome, **plan différent (grille), même DA** ; une variante « boucle » par biome est une idée LiveOps (§8) |
| **Étage final sans variante** | Commencement (lune) : 4 à 7 piliers de 4 types (Masse 60 s, Dessein 30 s + ondes, Âme 30 s + rayon qui rétrécit, Sang 10 s en perdant 10 % PV/s), en charger 4 → arène du boss ; boss final (Mithrix) ; fuite chronométrée de 3 min puis tenir une zone 1 min | **Étage 5 = La Source**, sans variante, sans petits piliers : une arène et un boss final à phases. Les « piliers à type » sont une bonne idée pour un **mode sans fin** ou une seconde boucle, pas pour la v1 |
| **Boss du téléporteur** | « un ou plusieurs boss selon la difficulté et le nombre de joueurs », tirés par le director de l'environnement (pas de liste par étage sur la page Teleporter) ; parfois une « Horde of Many » à la place | Boss d'étage **tiré parmi 3 propres au biome** ; variante « horde » (2 mini-boss à la place du boss d'étage) = idée LiveOps |
| **Boucle** | Après l'étage 5, la séquence reprend à l'étage 1 (succès « Deja Vu? ») ; la difficulté continue de monter | Mode sans fin = reboucler 1-4 puis 5, coeff ×1,15 par étage (déjà `K_STAGE`), autre variante privilégiée |
| **Secrets propres à un étage** | Plaques de l'Aqueduct (étage 2), coffre à minuteur de Rallypoint (3), œufs de Siren's Call (4) : chaque étage a **son** secret, ce qui crée la connaissance « à l'étage 2 je sais qu'il y a… » | Secrets placés **dans la grille** de chaque variante (Design_Zones_Secretes.md §5 q4) : la porte scellée des Terrasses est toujours dans la ruine centrale de la variante A |

---

## 2. Structure d'une run

### 2.1 Séquence
1. **Étage 1 → 4** : biome fixe, variante A ou B tirée **à 50/50**, seedée au **début de la run** (le plan complet de la run est tiré à `start_run`, comme une seed RoR2 : variante, boss d'étage et paire de mini-boss de chaque étage ; sauvegardé, donc jamais relancé en quittant/revenant).
2. **Étage 5** : La Source, arène unique, boss final. Pas de petits piliers : un seul **gros pilier** (le paratonnerre-mère) → boss final + zone de charge (90 s, ou la durée du combat si plus longue). Coffres : 6 petits + 2 grands + 1 légendaire garanti (c'est le dernier marché), tous posés autour de l'arène.
3. **Victoire** après le boss final : écran de victoire (rubis ×1,5 par rapport à une victoire à l'étage 3 d'aujourd'hui, à recalibrer §8) ou **sans fin** : étages 6-9 = biomes 1-4 (variante **opposée** à celle vue dans la boucle 1 si possible), étage 10 = La Source à nouveau, etc. Les règles de scaling de `balance.gd` s'appliquent sans changement (RoR2 n'a pas d'accélération « endless » ; la pente de temps suffit).

### 2.2 Tirages (seedés, `RunState.rng`, au début de la run)
| Tirage | Règle | Pourquoi |
|---|---|---|
| Variante de carte | 50 / 50 par étage ; en sans fin, l'autre variante si elle existe | Deux runs de suite ne se ressemblent pas, mais l'étage 1 est **toujours** reconnaissable |
| Boss d'étage | 1 parmi les 3 du biome, uniforme ; **mémoire de profil** : le boss vu à cet étage lors de la run précédente pèse ×0,5 | Variété d'une run à l'autre sans priver un joueur d'un boss qu'il n'a jamais vu |
| Mini-boss | 2 **distincts** parmi les 5 du biome, affectés aux 2 petits piliers (le joueur ne sait pas lequel est où : la silhouette apparaît à l'activation) | Jamais deux fois le même sur un étage ; sur 5 biomes × 2, un joueur voit ≈ 8 mini-boss différents par run |
| Défi du jour | Seed fixe : variantes, boss et minis identiques pour tout le monde | Classement comparable |

### 2.3 Ce qui est commun à toutes les variantes d'un biome
Tileset et props (lot iso C1-C3 + C4 nouveau), profil d'ambiance (`data/ambiance/<biome>.tres` : heure, `CanvasModulate`, directionnelle, pluie, brume), musique et nappe de pluie, roster de monstres T1-T3 et de boss, palette des télégraphes, **règles de tirage des coffres/piliers/capsules** (`draw_rules`), événements de carte (§4.4 des cartes) avec le **même habillage** par biome.

### 2.4 Ce qui distingue la variante A de la B
| Axe | Variante A (existante pour les biomes 1-3) | Variante B (à dessiner) |
|---|---|---|
| **Plan / grille** | Grilles actuelles (56 × 64, 64 × 56, 48 × 80 u) | Nouvelle grille, **même taille ±15 %**, autre topologie : si A est ouverte, B est en couloirs, et inversement (Terrasses A = la plus ouverte → B = rizières étroites en escalier ; Forêt A = moyeu et rayons → B = un long méandre ; Cité A = canal vertical et 3 ponts → B = cour de fonderie centrale et 2 anneaux de passerelles) |
| **Arènes de boss** | 3 arènes ≥ 20 × 14 u | 3 arènes aussi, mais de forme différente (l'une d'elles **avec un obstacle central** pour le Colosse / la Grue) |
| **Props** | 6 props du biome | Les mêmes 6 + **3 props propres à B** (ex. Rizières hautes : noria, escaliers de pierre, épouvantails ; Mangrove : pontons, cages à lucioles, autel effondré ; Fonderie : creuset, rails, wagonnets) : petit lot Codex |
| **Événements de carte** | Habillages §4.4 | Mêmes types, **habillage B** (ex. Marchand de l'ombre = barque en A, cabane de noria en B) |
| **Secret majeur** | Terrasses A : porte scellée dans la ruine centrale ; Forêt A : veillée des lanternes ; Cité A : treuil | Terrasses B : écluse ; Forêt B : porte scellée (sanctuaire) ; Cité B : porte blindée. Un joueur apprend « où » par variante |
| **Événement ambiant** | Existants (bassins qui débordent, lucioles, orage) | Variante : Rizières hautes = **noria qui se remet à tourner** à Hostile (bruit, éclaboussures) ; Mangrove = marée qui monte (`,` qui s'élargit) ; Fonderie = coulée de métal (lumière orange pulsante) |
| **Heure** | Celle du profil (17 h 40 / 5 h 10 / 19 h 30) | **±30 min** sur le même profil (ex. Rizières hautes à 18 h 10 : soleil plus bas, ombres 2,4 u au lieu de 2,0) : même DA, nuance perceptible |
| **Spawn et sortie** | Spawn au centre | Spawn **excentré** (bord ouest ou sud) : la lecture de la carte change |

---

## 3. Les quatre biomes (étages 1-4)

Base commune : DA d'ash_lord / STYLE_boss_da.md (matières PBR usées, palette sombre désaturée, **un seul accent émissif par biome**, silhouettes anguleuses), lumière STYLE.md (soleil chaud haut-gauche + fill froid), éclairage profond v2 (Direction_Lumiere_Ambiance §8). Les valeurs ci-dessous reprennent le tableau §2.4 de Direction_Lumiere_Ambiance pour les biomes 1-3 (inchangés) et proposent le biome 4.

| | 1 · Terrasses noyées | 2 · Forêt-brume | 3 · Cité de rouille | 4 · Cryptes noyées (nouveau) |
|---|---|---|---|---|
| **Thème** | Rizières en terrasses abandonnées, murets moussus, bassins, pins tordus, norias | Mangrove de cèdres géants, racines en arche, sanctuaires à lanternes, étangs noirs | Canal industriel, cuves, passerelles, cloche d'alerte, lampes à vapeur | Catacombes et cavernes **sous** la cité où l'eau s'accumule : voûtes, colonnes, ossuaires, cristaux de sel, lacs noirs, stalactites qui gouttent |
| **Place dans le récit** | Le porteur de braise descend des terrasses : la pluie fine, le premier paratonnerre | La forêt noyée, le feu follet | La ville qui a construit les paratonnerres, l'orage | Là où toute l'eau finit : plus de pluie, des **gouttes** et une **crue** lente ; le silence avant la Source |
| **Palette sol** | `#4A5B5A` → `#5C6E68`, murets `#2F3A3C`, eau `#1F3139` / `#54707A`, bronze `#8C7A4C` | `#3E4A3F` → `#55634E`, racines `#2A2420`, eau `#17262B` | `#3B3F46` → `#4E4A44`, cuves `#26292E`, eau `#141B22` | sol `#2E3238` (pierre humide) → `#3C3A33` (sel et ossements), parois `#1E2126` liseré `#8FA3B0`, eau noire `#0E1419` (L\* 15) avec reflets de cristal, os `#8C8778` |
| **Accent émissif** | bronze / cyan d'eau (`#5EC8FF` doux) sur vannes et lanternes de pierre | vert pâle lanterne `#9CF0C8` | orange lampe à vapeur `#FF9A3C` (petit) + cyan du Sonneur | **cristal blanc-cyan `#BFF4FF`** (veines dans la roche, stalactites), et l'eau qui luit par endroits |
| **Heure / lumière** | 17 h 40, soleil sous les nuages, `CanvasModulate #C9C1B0` (lum 0,53), directionnelle 310° `#FFD9A8` 0,55, ombres 2,0 u | 5 h 10, heure bleue, `#8FA3A8` (0,35) + ciel 0,45, 315° `#C2E6E0` 0,45, pas d'ombres (canopée) | 19 h 30, orage, `#9A9CA8` (0,34) + ciel 0,40, 320° `#B9BCD6` 0,40, ombres 0,6 u | **Sans soleil** : `CanvasModulate #8A96A4` (lum ≈ 0,33, ≥ 0,42 en relatif après le garde-fou §1.1), **pas de directionnelle** ; lumière = PointLight2D des cristaux (cyan froid, rayon 6-8 u, pulsation lente 0,1 Hz) + le joueur (seule chaleur, comme le pitch) ; ombres de contact seulement (0,4 u, Haut) ; **gouttes** (particules verticales, pas de calque de pluie), éclaboussures sur l'eau noire |
| **Saturation / contraste / vignette** | 1,05 / 1,08 / 0,22 | 0,92 / 0,96 / 0,30 | 0,88 / 1,12 / 0,34 | 0,85 / 1,15 / **0,38** (le plus sombre ; monstres rendus avec chroma +20 % dans Blender pour garder L\* ≥ 60) |
| **Brume** | 12 % (bruine qui scintille) | 17 % (brume basse, lucioles) | 15 % (vapeur, éclairs) | 10 % : **vapeur froide au ras de l'eau** seulement ; pas de brume sur le sol sec (la lisibilité des télégraphes dans le noir prime) |
| **Ambiance sonore** | nappe de bruine + grillons mouillés, norias ; musique légère à cordes | pluie lourde sur canopée, lucioles, hiboux ; nappes et flûte | pluie en rideaux, tonnerre, vapeur, cloche lointaine ; percussions métalliques | **gouttes réverbérées**, grondement de crue, cristal qui tinte ; musique quasi absente à Calme (drones graves), chœur à Furieux |
| **Jauge de difficulté** | Hostile : bassins débordent | Furieux : lucioles éteintes, brume 15 % | Furieux : orage ; Cataclysme : canal monte | Hostile : la **crue** monte (cellules `,` élargies, visuel) ; Furieux : cristaux qui **s'éteignent par vagues** (3 s d'obscurité partielle, jamais sous le garde-fou) ; Cataclysme : grondement continu, chutes de pierre (cercles de 1 u télégraphiés, décor) |
| **Cartes** | A `terrasses_noyees` (56 × 64 u, existante, P0) ; B « Rizières hautes » (≈ 48 × 72 u, en escalier nord-sud, murets avec escaliers, noria au centre) | A `foret_brume` (64 × 56 u, existante) ; B « Mangrove des lanternes » (≈ 72 × 48 u, méandre est-ouest, pontons, 2 îles) | A `cite_rouille` (48 × 80 u, existante) ; B « Fonderie du canal » (≈ 64 × 64 u, cour centrale ronde, 2 anneaux de passerelles, 4 creusets) | A « Cryptes noyées » (≈ 60 × 60 u, nef centrale + 4 chapelles, lac au sud) ; B « Ossuaire des pluies » (≈ 48 × 76 u, galeries parallèles reliées par des escaliers, puits de lumière au centre) |
| **Boss d'étage existant** | Éclusier | Cerf-Lanterne | Sonneur | aucun (3 nouveaux) |

Les trois cartes existantes restent donc **telles quelles comme variantes A** de leur biome (c'est déjà leur thème et leur boss) ; aucune ne change d'étage. Le 4e biome est souterrain pour fermer l'arc « descente » du pitch et offrir la seule carte **sans pluie ni soleil** (contraste fort avec les trois autres, et un vrai usage de l'éclairage 2D : le joueur-lanterne).

---

## 4. Étage 5 : La Source

- **Lieu** : au fond des cryptes, une **caverne ouverte sur le ciel** par un puits vertical : la pluie tombe en **une seule colonne** au centre (particules + lumière blanche froide), le reste est dans la pénombre des cristaux. Au centre, le **paratonnerre-mère**, inversé, planté dans un lac circulaire peu profond (`,`). C'est la source du déluge : le premier paratonnerre, qui s'est mis à l'appeler au lieu de le repousser.
- **Arène unique** (pas de variante) : disque de **44 u de diamètre** (bassin `,` central de 14 u, anneau de sol de pierre, 8 colonnes de 2 u en cercle à 16 u du centre = obstacles pour peigner la foule, 4 chapelles de 8 × 6 u en périphérie = refuges). Spawn au sud, coffres (6 petits, 2 grands, 1 légendaire) dans les chapelles et sur l'anneau. Taille totale 48 × 48 u : 1 écran et demi, le combat se lit en entier.
- **Déroulé** : arrivée → 60-90 s de libre (coffres, farm, montée de la difficulté comme ailleurs) → interaction sur le paratonnerre-mère (gros pilier unique, « Appeler la Source ») → **boss final** + zone de charge couvrant tout l'anneau (rayon 22 u) : la charge dure 90 s mais le pilier n'est terminé qu'à la **mort du boss** ; la pression (crédits ×2,33) continue jusqu'à la mort. Puis choix victoire / sans fin via le téléporteur, comme aujourd'hui.
- **Boss final proposé : « Le Semeur de pluie »** : silhouette **4,5 u**, figure encapuchonnée de bronze noirci à la place du paratonnerre, bras-chaînes, cœur = une goutte de cristal blanc ; PV base **2 × boss d'étage** (`BOSS_BASE_HP[&"final"] = 8 600`), dégâts base 32, plafond 40 % par coup. **3 phases** (70 % / 35 %, transitions 1,5 s), chacune reprenant le thème d'un biome traversé : (1) **Averse** : cercles en pluie (6 × 2 u, 1,0 s) + ligne de vague ; (2) **Crue** : l'eau du bassin monte, le disque central devient infranchissable (`~`) et un anneau de brume (Forêt) ralentit les bords : l'arène rétrécit ; (3) **Orage** : foudre toutes les 4 s (cercle 2 u, coef 2,5, Cité) + le boss **s'ancre** au paratonnerre et fait tourner 4 lignes en croix (Éclusier) : fenêtre de DPS. Durée visée 75-100 s en Moyen (enrage à 90 s déjà prévu). **Pas de phase de fuite** (RoR2) : une run de 20 min se termine sur le kill, pas sur une course.
- **Nombre de boss finaux** : voir §8 question 1. Reco : **un seul**, à 3 phases, pour la v1 ; un second (« L'Écho », variante sans fin) en LiveOps.
- **Assets** : tileset de la Source (dérivé des Cryptes + colonne de lumière), 4 props (colonne, chapelle, paratonnerre-mère 3 états, cristal géant), le boss (rig CREA, 448², effort `medium`), VFX de la colonne de pluie (rig TOP + CREA).

---

## 5. Roster par étage

Fiches communes : mini-boss = Design_Boss_Cartes §2 (PV 1 300 × coeff^1,6 [base actuelle `BOSS_BASE_HP`], Dég_base 20, 1 auto + 2 sorts + 1 passif + phase 2 à 50 %, silhouette ≤ 2,8 u) ; boss d'étage = §3 (PV `BOSS_BASE_HP[&"etage"]` 4 300, Dég_base 28, phases 70 / 35 %, trace après la mort). Chaque nouveau boss ci-dessous est un **concept court** à détailler sur le modèle des fiches existantes quand son lot arrive. Les noms de dossier (`id`) sont en anglais, les noms affichés en français.

### 5.1 Étage 1 : Terrasses noyées (eau, pierre, bronze ; accent cyan d'eau)
| Rôle | Nom (`id`) | Concept | Met à l'épreuve | Statut asset |
|---|---|---|---|---|
| Boss | **L'Éclusier** (`eclusier`) | Gardien de la vanne, vague et geysers, s'ancre en phase 3 (fiche §3.1) | Survie %, mobilité | existant, re-rendu iso 30° (lot C7) |
| Boss | **Le Bouvier** (`ox_herder`) | Buffle d'eau de pierre 3,4 u harnaché de bronze, cornes-ancres. Auto : cornes en cône. A : **charge en ligne** 2,5 × 16 u qui laisse un sillon d'eau (`,` temporaire, ralentit −20 %). B : **piétinement** en anneau 6 u. 70 % : double charge en V ; 35 % : **s'embourbe** (ancré) et appelle 2 vagues de boue (lignes tournantes). Trace : sillons qui persistent | mobilité, burst dans la fenêtre d'ancrage | nouveau |
| Boss | **La Porteuse de jarres** (`jar_bearer`) | Esprit de lanterne de pierre 3,0 u, 6 jarres sur le dos. Auto : jet de jarre (projectile 1 u qui éclate en cercle 1,5 u). A : **pluie de jarres** (5 cercles 2 u en séquence). B : **jarre-mère** posée au sol (obstacle 1 u, explose après 3 s en anneau 5 u télégraphié). 70 % : les jarres cassées laissent des **flaques de vase** (ralentissement). 35 % : la porteuse lévite, les jarres tournent autour d'elle (4 projectiles en orbite, télégraphe continu) | zone (casser les jarres-mères), antidote | nouveau |
| Mini | Colosse de pierre (`stone_colossus`) | fiche §2.1 | burst | existant, refonte DA (R8c) |
| Mini | Ours de givre (`frost_bear`) | fiche §2.4 | mobilité, givre | existant, refonte DA (R8c) |
| Mini | **Héron de fer** (`iron_heron`) | Échassier 2,6 u de haut, pattes de bronze, bec-harpon. Auto : coup de bec (ligne courte 3 u). A : **harpon** (ligne 1 × 12 u, 1,0 s, coef 1,6). B : **envol** : disparaît 1 s et retombe sur le joueur (cercle 3 u, 1,0 s, coef 1,3). Passif : **échasses** : traverse l'eau profonde (le joueur non). Phase 2 : double harpon en croix | mono-cible sur cible mobile, projectiles rapides | nouveau |
| Mini | **Crapaud-cuve** (`vat_toad`) | 2,4 u, ventre-cuve de bronze qui bout. Auto : langue (ligne 1 × 5 u, 0,8 s, coef 1,0, **tire le joueur de 1,5 u**, respecte les collisions). A : **bulles de boue** (4 cercles 1,5 u, ralentissement). B : **bond** (cercle 3 u, coef 1,4). Passif : **peau glissante** : immunisé aux poussées, prend +30 % de dégâts quand il est hors de l'eau. Phase 2 : crache une mare 4 u (poison 6 s) | positionnement (se battre loin de l'eau), antidote | nouveau |
| Mini | **Épouvantail faucheur** (`scarecrow_reaper`) | 2,3 u, bois noir et faux rouillée, corbeaux. Auto : faux en arc 180° 3 u. A : **moisson** (3 lignes parallèles 1 × 10 u, 1,0 s, coef 1,2). B : **envol de corbeaux** (8 projectiles lents en éventail, 0,5 u). Passif : **planté** : immobile 2 s après chaque Moisson (fenêtre), sinon 2,8 u/s. Phase 2 : la faux s'allonge (arc 4 u), corbeaux ×12 | esquive latérale, critique | nouveau |

### 5.2 Étage 2 : Forêt-brume (bois mort, mousse, brume ; accent vert pâle)
| Rôle | Nom (`id`) | Concept | Met à l'épreuve | Statut |
|---|---|---|---|---|
| Boss | **Le Cerf-Lanterne** (`cerf`) | fiche §3.2 | zone, mono-cible mobile | existant, re-rendu iso (C7) |
| Boss | **La Tisseuse** (`weaver`) | Araignée-sanctuaire 3,3 u, abdomen de lanterne fêlée, pattes de bois. Auto : morsure cône. A : **fils** (3 lignes 0,8 × 12 u depuis le boss, persistent 5 s, ralentissent −40 % au contact, bloquent les projectiles ennemis). B : **descente** : disparaît dans la canopée et retombe (cercle 3 u, 1,2 s, coef 1,6). 70 % : les fils forment une **toile** (anneau de 6 u à 2 brèches). 35 % : pond 6 cocons (obstacles 1 u, éclosent en tier 1 après 3 s). Trace : fils qui restent | mobilité, zone (cocons) | nouveau |
| Boss | **Le Cèdre-Ermite** (`hermit_cedar`) | Tréant 3,6 u, tronc fendu abritant une lanterne, bras-branches. Auto : branche en cône 90°. A : **racines** (4 lignes 1 × 8 u qui jaillissent du sol autour du joueur, 1,0 s, coef 1,3). B : **spores** (cercle 4 u sur le joueur, 1,0 s, poison 6 s). 70 % : **enraciné** (immobile, +50 % de vitesse d'attaque, racines ×6). 35 % : se déracine et **charge** lentement (ligne 3 × 12 u, 1,2 s, coef 1,8) en laissant des souches (obstacles 6 s). Trace : souches | antidote, DoT (il est lent), burst pendant l'enracinement | nouveau |
| Mini | Reine des ronces (`bramble_queen`) | fiche §2.2 | zone, antidote | existant, refonte R8b en cours |
| Mini | Essaim-mère (`brood_mother`) | fiche §2.5 | zone, soins par kill | existant, refonte R8b en cours |
| Mini | **Loup de brume** (`mist_wolf`) | Alpha 2,2 u, pelage gris-vert, yeux lanterne + **meute de 4** louveteaux (tier 1 à 60 % PV, Meute). Auto : morsure. A : **bond** sur le joueur (cercle 2 u, 0,9 s, coef 1,3). B : **s'évanouit** 1 s dans la brume et réapparaît derrière le joueur (cercle 2 u, 1,0 s) puis mord (coef 1,0). Passif : **meute** : +10 % de dégâts par louveteau vivant. Phase 2 : hurle, 4 louveteaux de plus, bonds en chaîne (2 cercles) | zone (louveteaux), lecture du cercle de réapparition | nouveau |
| Mini | **Chouette-lanterne** (`lantern_owl`) | 2,0 u, vole (ignore les obstacles, 3,2 u/s), yeux-lanternes. Auto : serres en piqué (ligne courte). A : **cri** (cône 60° × 8 u, 1,0 s, coef 1,2 + ralentissement). B : **sème 3 follets** (comme le Cerf, 30 % PV, explosent). Passif : **nocturne** : −30 % de dégâts reçus quand elle est hors des flaques de lumière (lanternes, joueur à > 4 u) → se battre sous les lanternes. Phase 2 : follets ×5, cri en balayage | mono-cible sur cible mobile, placement près des lumières | nouveau |
| Mini | **Mante de mousse** (`moss_mantis`) | 2,6 u, lames-bras de bois dur, camouflage de mousse. Auto : lame en arc. A : **ciseaux** (2 lignes en V 1 × 8 u, 1,0 s, coef 1,4). B : **embuscade** : s'immobilise 1,5 s (invisible à 60 % sauf les yeux) puis bondit (ligne 2 × 10 u, 1,0 s, coef 1,8). Passif : **carapace** de face −40 %. Phase 2 : +25 % vitesse, ciseaux en X | critique, projectiles perforants (dos), esquive | nouveau |

### 5.3 Étage 3 : Cité de rouille (fer, béton, vapeur ; accent orange de lampe)
| Rôle | Nom (`id`) | Concept | Met à l'épreuve | Statut |
|---|---|---|---|---|
| Boss | **Le Sonneur** (`sonneur`) | fiche §3.3 | survie %, mêlée contre distance | existant, re-rendu iso (C7) |
| Boss | **La Grue** (`crane`) | Automate-grue 3,8 u de haut, flèche articulée, crochet. Auto : crochet (ligne 1 × 6 u). A : **lâcher de conteneur** (cercle 3 u, 1,2 s, coef 1,8 ; le conteneur **reste** 8 s comme obstacle 2 u : des murs pour le Colosse… et pour couper les lignes). B : **balayage de flèche** (ligne 1,5 × 14 u qui **tourne** de 90° en 1,5 s, télégraphe continu). 70 % : 2 conteneurs à la fois. 35 % : la grue **se bloque** (ancrée) et lâche des conteneurs en spirale toutes les 2,5 s. Trace : conteneurs qui restent | mobilité, utilisation des obstacles | nouveau |
| Boss | **Le Fondeur** (`smelter`) | Automate-forge 3,5 u, creuset à la place du torse, bras-louches. Auto : louche (cône 3 u, brûlure). A : **coulée** (ligne 2 × 12 u qui **reste** 5 s comme flaque de métal : coef 0,5 par 0,5 s + brûlure). B : **étincelles** (6 projectiles en éventail 0,6 u). 70 % : le creuset déborde : anneau de métal à 5 u (2 brèches). 35 % : **surchauffe** : +25 % de dégâts reçus, coulées en croix, vapeur (lignes tournantes). Trace : flaques de métal | survie, antidote (brûlure), lecture des brèches | nouveau |
| Mini | Seigneur des cendres (`ash_lord`) | fiche §2.3 | mobilité, survie % | **fait** (R8a, référence de DA) |
| Mini | Archonte rouillé (`rust_archon`) | fiche §2.6 | critique, perforant | existant, refonte DA (R8d) |
| Mini | **Molosse à vapeur** (`steam_hound`) | Quadrupède mécanique 2,4 u, chaudière sur le dos. Auto : morsure. A : **charge** (ligne 2 × 12 u, 1,0 s, coef 1,6 ; s'écrase sur un mur : 3 s étourdi). B : **jets de vapeur** latéraux (2 lignes 1 × 6 u, 0,9 s, brûlure). Passif : **surpression** : +20 % vitesse tant qu'il a chargé il y a < 5 s. Phase 2 : charge double, vapeur en croix | burst dans l'étourdissement, utilisation des murs | nouveau |
| Mini | **Le Rémouleur** (`grinder`) | 2,3 u, automate à meule, disques de scie. Auto : meule (cône court, 3 coups rapides). A : **disques** (3 projectiles 0,8 u à 9 u/s qui **rebondissent** une fois sur les murs). B : **tour de meule** (anneau 1-4 u autour de lui, 0,9 s, coef 1,3). Passif : **affûtage** : +5 % de dégâts par coup reçu, remis à zéro quand il lance Tour de meule (max +50 %). Phase 2 : disques ×5, rebonds ×2 | distance, lecture des rebonds | nouveau |
| Mini | **Pompe aveugle** (`blind_pump`) | Cuve sur 4 pattes 2,6 u, pas de tête, tuyaux. Auto : jet d'huile (projectile lent, flaque ralentissante 2 s). A : **aspiration** (cercle 5 u autour d'elle, 1,0 s, tire le joueur de 2 u puis coef 1,2 au contact ; respecte les collisions). B : **geysers d'huile** (4 cercles 2 u, 1,0 s, brûlure si une flamme passe). Passif : **aveugle** : vise la **dernière position connue** du joueur (0,5 s de retard : se déplacer suffit). Phase 2 : aspiration en continu 3 s, geysers ×6 | mobilité continue (Danseur), antidote | nouveau |

### 5.4 Étage 4 : Cryptes noyées (os, sel, cristal, eau noire ; accent cristal blanc-cyan)
| Rôle | Nom (`id`) | Concept | Met à l'épreuve | Statut |
|---|---|---|---|---|
| Boss | **Le Reclus** (`recluse`) | Moine de pierre 3,6 u, capuche vide, cristal dans la poitrine, cloche de silence à la main. Auto : bâton en cône. A : **cloche** (anneau 1 → 8 u en 0,8 s, 1,0 s, coef 1,5, **coupe les sorts à recharge 2 s** si touché). B : **prières** (6 cercles 2 u en spirale, 1,0 s, coef 1,3). 70 % : les **cristaux de l'arène s'éteignent** (lumière à 50 %, télégraphes inchangés) et la cloche devient double. 35 % : **lévite** immobile et tourne 4 rayons (lignes 1 × 14 u à 20°/s, télégraphe continu). Trace : obscurité jusqu'à la fin de charge | recharge (pénalité de la cloche), survie | nouveau |
| Boss | **La Mère-Cristal** (`crystal_mother`) | Amas de cristal 3,4 u à silhouette féminine, 6 bras-stalactites. Auto : éclat (projectile 1 u). A : **stalactites** (6 cercles 1,5 u, 1,2 s, coef 1,3, chacun laisse un **bloc de cristal** 1 u 6 s qui **réfracte** : bloque les projectiles ennemis). B : **prisme** (ligne 1,5 × 16 u, 1,0 s, coef 2,0, **se divise en 2 lignes** à 30° sur un bloc). 70 % : les blocs deviennent des **lampes** (zones de lumière, les monstres y sont +15 % dégâts reçus). 35 % : s'**éclate** : 8 éclats en orbite, prisme en croix. Trace : blocs qui restent | mobilité, projectiles perforants, placement derrière les blocs | nouveau |
| Boss | **L'Anguille des profondeurs** (`deep_eel`) | 3,8 u de long, écailles de sel, nageoires-lames, lueur interne. **Vit dans l'eau** du lac et **surgit** : Auto : morsure au bord. A : **émergence** (ligne 2 × 14 u depuis l'eau, 1,2 s, coef 1,8). B : **décharge** (anneau 6 u autour de son point d'émergence, 1,0 s, coef 1,4 + ralentissement). 70 % : **crue** : le lac s'élargit de 2 u (cellules `,` → `~` visuelles, bord qui recule). 35 % : s'**échoue** sur l'anneau (ancrée, vulnérable, fouette : 2 lignes tournantes). Trace : crue qui reste | lecture des lignes depuis l'eau, DPS sur une cible qui disparaît | nouveau |
| Mini | **Porte-ossuaire** (`ossuary_bearer`) | Golem 2,5 u portant une niche d'os sur le dos. Auto : poing. A : **invoque 6 squelettes** (tier 1, 50 % PV, anneau 1,0 s). B : **effondrement** (cercle 4 u, 1,2 s, coef 1,4, laisse 3 tas d'os obstacles 5 s). Passif : **reliquaire** : −35 % de dégâts reçus tant que ≥ 3 squelettes vivent. Phase 2 : 8 squelettes, effondrement double | zone, soins par kill | nouveau |
| Mini | **Nuée aveugle** (`blind_swarm`) | Reine chauve-souris 2,2 u (vole) + nuée. Auto : griffes. A : **nuée** (cercle 2,5 u sur le joueur, 12 chauves-souris convergent, 1,0 s, coef 1,2). B : **cri** (cône 90° × 7 u, 1,0 s, coef 1,0, **brouille la minimap 3 s**). Passif : **écholocalisation** : +20 % vitesse quand le joueur bouge, −20 % quand il est immobile 1 s. Phase 2 : nuée ×2 (deux cercles décalés) | zone, gestion du mouvement (anti-Danseur) | nouveau |
| Mini | **Golem de sel** (`salt_golem`) | 2,6 u, bloc de sel cristallisé, lent (2,0 u/s). Auto : coup lourd cône. A : **onde de choc** (anneau 1 → 6 u, 0,9 s, coef 1,4). B : **éclats de sel** (4 lignes en croix 1 × 8 u, 1,0 s, coef 1,2, laissent une **croûte** qui ralentit 4 s). Passif : **se dissout** : −2 % PV max par seconde dans l'eau peu profonde (le joueur peut l'y attirer). Phase 2 : se fend en 2 (deux golems à 40 % PV chacun, onde seule) | kiting vers l'eau, zone (2 cibles) | nouveau |
| Mini | **Lanternier aveugle** (`blind_lamplighter`) | 2,4 u, humanoïde voûté, lanterne de cristal au bout d'une perche. Auto : perche (ligne courte 4 u). A : **cône de lumière** (cône 45° × 10 u, 1,0 s, canalisé 1,5 s en balayage 30°, coef 0,5 par 0,5 s + brûlure « blanche »). B : **pose une lanterne** (obstacle 1 u 8 s, zone de lumière 4 u : le joueur y voit mieux mais **les monstres y gagnent +15 % vitesse**). Passif : **dans le noir** : le lanternier est invisible à 70 % hors des zones de lumière (sa lanterne reste visible). Phase 2 : 2 lanternes, cône double | mobilité, choix lumière/obscurité | nouveau |
| Mini | **Crabe-sarcophage** (`sarcophagus_crab`) | 2,8 u, crabe portant un sarcophage de pierre, pince géante. Auto : pince (cône 120°, 3 u, coef 1,1). A : **claquement** (ligne 1,5 × 8 u, 0,9 s, coef 1,6, pousse 2 u). B : **se terre** 2 s (invulnérable **de face seulement** : garde 120°, dos exposé) puis **jaillit** (cercle 3 u, 1,0 s, coef 1,4). Passif : **marche de côté** : se déplace 2× plus vite latéralement. Phase 2 : le sarcophage s'ouvre : perd la garde, +30 % vitesse, claquements doubles | contournement, projectiles perforants, critique | nouveau |

### 5.5 Étage 5 : voir §4 (Le Semeur de pluie, boss unique).

### 5.6 Compte des assets créatures
| Catégorie | Existants gardés | À refaire (DA) | En cours | Nouveaux | Total lots Codex |
|---|---|---|---|---|---|
| Boss d'étage 1-4 | 3 (eclusier, cerf, sonneur : **re-rendu iso 30°**, lot C7, DA déjà bonne) | 0 | 0 | **8** | 3 re-rendus + 8 × 1 lot (`medium`) |
| Boss final | 0 | 0 | 0 | **1** | 1 lot (`medium`) + 1 lot VFX |
| Mini-boss 1-4 | 1 (ash_lord, R8a) | 3 (frost_bear, stone_colossus, rust_archon) | 2 (bramble_queen, brood_mother, R8b) | **14** | 2 lots de refonte (R8c ×2, R8d ×1) + 7 lots de 2 nouveaux (`low`) |
| **Total** | 4 | 3 | 2 | **23** | **≈ 25 lots créatures** (+ props des gardiens de secrets, Design_Zones_Secretes §4.6) |

Monstres T1-T3 : le roster générique (essaim, tireur, bondisseur, brute) est conservé **pour tous les biomes** ; un lot « variante de matière par biome » (même modèle, autre matériau : vase / mousse / rouille / sel, 4 rendus par type) est proposé en P2 pour que les foules suivent la DA de l'étage sans nouveau modèle.

**Palier jouable** (avant que tout soit produit) : chaque étage est jouable dès qu'il a **1 boss d'étage + 2 mini-boss + la variante A** : c'est déjà le cas des étages 1-3 (placeholders et sprites 35° en attendant), l'étage 4 et la Source sont les manques réels. Le minimum demandé (3 / 5) est l'objectif de lancement (GDD §12 mois 6).

---

## 6. Contrats de code (à faire après la phase 0 iso et le lot L1)

### 6.1 Données
- **`data/floors.json`** (nouveau, source de vérité du roster, remplace les constantes) :
  ```json
  [
   {"floor": 1, "biome": "terrasses", "name": "Terrasses noyées",
    "maps": ["terrasses_noyees", "rizieres_hautes"],
    "floor_bosses": ["eclusier", "ox_herder", "jar_bearer"],
    "minis": ["stone_colossus", "frost_bear", "iron_heron", "vat_toad", "scarecrow_reaper"],
    "ambiance": "terrasses", "music": "terrasses"},
   {"floor": 5, "biome": "source", "name": "La Source", "final": true,
    "maps": ["la_source"], "floor_bosses": ["rain_sower"], "minis": [],
    "draw_rules_override": {"small_chests": 6, "large_chests": 2, "legendary_chance": 1.0, "small_pillars": 0}}
  ]
  ```
- **`data/maps/<id>.json`** : + `floor`, `variant` (`"A"`/`"B"`), `biome`, `hour_shift_min` (B : ±30), `props_extra` ; `floor_boss` devient optionnel (le boss vient du plan de run). `tools/gen_maps.py` : une entrée `MAPS` par variante (10 grilles au total), validation « 2 variantes par étage 1-4, 1 à l'étage 5 ».
- **`data/bosses.json`** (déjà prévu Design_Boss_Cartes §6.5) : y ajouter la section `sprite` (`dir`, `floor`, `dim`, `bottom`, `fh`, `energy`, `render_px_per_u`) aujourd'hui dans `enemy_visual.gd` `BOSS_SPRITES` ; `MINIS_BY_FLOOR` **supprimé** (remplacé par `floors.json`).
- `data/ambiance/<biome>.tres` : un profil par biome (les 3 existants renommés par biome + `cryptes` + `source`), les variantes n'ont que `hour_shift_min` et `fog_add`.

### 6.2 Plan de run (`RunState`, orchestrateur)
- `RunState.floor_plan: Array[Dictionary]` = `[{floor, map_id, floor_boss, minis: [a, b], variant}]` pour les étages 1-5, tiré dans `start_run()` à partir de `floors.json` avec `RunState.rng` (**avant** tout autre tirage, pour que les coffres gardent leur seed) ; en sans fin, `plan_for_stage(n)` étend le plan à la demande (étage 6 → biome 1, variante opposée).
- `RunState.to_dict()` / `from_dict()` : `floor_plan` sauvegardé ; `summary()` de `run_save.gd` affiche « Étage 3 · Cité de rouille ».
- Mémoire de profil (`profile.gd`) : `last_floor_boss[floor]` pour le poids ×0,5.
- `Balance.FINAL_STAGE := 5` ; `Balance.BOSS_BASE_HP[&"final"]`, `BOSS_BASE_DMG[&"final"]`, `BOSS_VALUE[&"final"]`.

### 6.3 Étage et carte (`scripts/stage`, Opus)
- `StageManager._entry_for_stage(stage)` : lit `RunState.floor_plan[stage]` → charge la scène de `map_id` ; **`map_order` et `_shuffled_indices` disparaissent** (le catalogue reste pour les tests avec `map_scene`). `start_stage()` applique `draw_rules_override` de l'étage 5 (0 petit pilier : le gros est débloqué d'emblée).
- `Pillar.setup()` reçoit `boss_id` depuis le plan : petit pilier n° i → `minis[i]`, gros → `floor_boss`. `Director.spawn_boss(kind, position, boss_id)` (déjà `boss_id` sur le pilier pour le boss d'étage ; à généraliser aux minis).
- `_on_pillar_finished` : à l'étage `FINAL_STAGE`, le choix victoire/sans fin (aujourd'hui à l'étage 3 dans `main.gd` : `victory_choice_requested`) ; le gros pilier de la Source : terminé **à la mort du boss** (la charge continue d'alimenter les crédits mais n'est pas une condition).
- `AmbianceManager.bind_map(map)` et `Audio.start_map(id)` reçoivent le **biome** (`map.get_meta("biome")`) + les surcharges de variante.
- `enemy_visual.gd` : lit `bosses.json` ; `pick_mini(floor_id)` remplacé par le plan.

### 6.4 Sauvegarde
- `RunSave.VERSION` : montée (à grouper avec celle de l'iso et des secrets). Anciennes sauvegardes (plan absent, `map_order`) : converties en rubis selon la règle existante.
- `StageManager.to_dict()` : `map_id` suffit (plus de `map_order`) ; `pillars[i].boss_id` déjà sauvé.

### 6.5 Tests
`floors_test.tscn` (plan seedé reproductible, 5 étages, variante A/B seulement sur 1-4, étage 5 sans variante ni petits piliers, 2 minis distincts, boss parmi les 3 du biome, poids de profil), `maps_test` sur les **10 variantes** (candidats, arènes, ratios), `stage_test` (sans fin : étage 6 = biome 1 variante opposée, étage 10 = Source), `save` aller-retour avec `floor_plan`, `bosses_data_test` (tout `id` de `floors.json` existe dans `bosses.json`, sprite ou placeholder déclaré), `economy_test` sur 5 étages (coffres, or, objets : ≈ 45 objets par run, à recalibrer avec `simulateur_scaling.py` passé à 5 étages).

---

## 7. Plan de production

### 7.1 Principes (CLAUDE.md « Économie de tokens Codex »)
Lots **petits** (1 boss d'étage ou 2 mini-boss par lot), consignes courtes dans `art/tools/monsters/_r*.txt`, lancement via `run_codex.sh`, effort `low` pour un mini-boss, `medium` pour un boss d'étage / final ; **rig CREA iso 30°** (`art/tools/iso/iso_rig.py`, lot C0) ; DA = `STYLE_boss_da.md` + référence `ash_lord` (`_r8a_contact.png`, `ash_lord_build.py` pour les matières, l'AO et le rendu) ; par biome : **variante de thème et de colorimétrie** (palette du biome §3, un seul accent émissif du biome) ; planche de contact à chaque lot avec ash_lord et le boss d'étage du biome à la même échelle ; sorties aux noms/grilles/`.tres` conservés (`game/assets/sprites/bosses/<mini|etage>/<id>/`), ombres cuites, `_n`/`_e`.

### 7.2 Ordre conseillé (créatures)
| # | Lot | Contenu | Effort | Pourquoi dans cet ordre |
|---|---|---|---|---|
| 1 | R8b (en cours) | bramble_queen, brood_mother | low | DA validée, terminer |
| 2 | R8c | frost_bear + stone_colossus (étage 1) | low | **L'étage 1 est vu à chaque run** : il doit être complet et beau en premier |
| 3 | C7a | eclusier re-rendu iso 30° | medium | boss d'étage 1 |
| 4 | N1a | iron_heron + vat_toad | low | étage 1 → 4 minis |
| 5 | N1b | scarecrow_reaper (+ variante de matière « vase » des T1-T3 si le quota le permet) | low | étage 1 → 5 minis |
| 6 | N1c | ox_herder | medium | étage 1 → 2 boss |
| 7 | N1d | jar_bearer | medium | **étage 1 complet (3 / 5)** |
| 8 | R8d | rust_archon | low | étage 3 |
| 9 | C7b | cerf re-rendu | medium | étage 2 |
| 10 | N2a | mist_wolf (+ louveteau) + lantern_owl | low | |
| 11 | N2b | moss_mantis | low | étage 2 → 5 minis |
| 12 | N2c | weaver | medium | |
| 13 | N2d | hermit_cedar | medium | **étage 2 complet** |
| 14 | C7c | sonneur re-rendu | medium | étage 3 |
| 15 | N3a | steam_hound + grinder | low | |
| 16 | N3b | blind_pump | low | étage 3 → 5 minis |
| 17 | N3c | crane | medium | |
| 18 | N3d | smelter | medium | **étage 3 complet** |
| 19 | N4a | ossuary_bearer + blind_swarm | low | étage 4 (après le tileset C4, pour juger le raccord dans le noir) |
| 20 | N4b | salt_golem + blind_lamplighter | low | |
| 21 | N4c | sarcophagus_crab | low | |
| 22 | N4d | recluse | medium | **étage 4 jouable** (1 boss + 5 minis) |
| 23 | N4e | crystal_mother | medium | |
| 24 | N4f | deep_eel | medium | **étage 4 complet** |
| 25 | N5a | rain_sower (modèle + 3 phases) | medium | boss final |
| 26 | N5b | VFX de la Source (colonne de pluie, foudre, crue) | low | |

Les gardiens des secrets (Design_Zones_Secretes §4.6, lot S-B) s'intercalent après N1d (ceux des Terrasses d'abord).

### 7.3 Cartes et variantes (lots de la migration iso, Design_Isometrique §5)
| Lot | Contenu | Agent / Codex |
|---|---|---|
| L1 (Opus, code) | `floors.json`, plan de run, `gen_maps.py` à 10 grilles ; **grilles B dessinées en ASCII** (Rizières hautes, Mangrove, Fonderie) + grilles A/B des Cryptes + arène de la Source, jouables en G1 (tuiles tournées, prismes) **sans asset** | Claude (Fable pour les grilles, Opus pour le code) |
| C1 | tileset Terrasses (iso) : sert aux variantes A **et** B | Codex |
| C1b | 3 props de la variante B (noria, escaliers, épouvantail) | Codex, petit lot |
| C2 / C2b | tileset Forêt + props Mangrove (pontons, cages, autel) | Codex |
| C3 / C3b | tileset Cité + props Fonderie (creuset, rails, wagonnet) | Codex |
| **C4 / C4b** (nouveau) | tileset **Cryptes** (sol pierre/sel, parois, eau noire, cristaux émissifs `_e`, falaises = gouffres) + props (colonne, ossuaire, stalactite, cristal, lanterne de cristal) + variante B (escaliers, puits de lumière) | Codex |
| **C5** (nouveau) | arène de la Source : sol, bassin, 8 colonnes, 4 chapelles, paratonnerre-mère (3 états), colonne de pluie (rig TOP + CREA) | Codex |
| Ambiance | profils `cryptes.tres`, `source.tres` (code Claude) ; textures : gouttes, vapeur froide, scintillement de cristal (Codex, lot ambiance) | |
| Audio | nappes et musiques des 2 nouveaux biomes (Codex, lot audio) | |

Ordre : L1 d'abord (tout est jouable en G1), puis C1 → C1b → C4 (le biome qui n'existe pas du tout) → C5 → C2/C2b → C3/C3b, en alternance avec les lots créatures §7.2 pour ne jamais bloquer le jeu sur un seul type d'asset.

---

## 8. Questions ouvertes pour le joueur (avec recommandation)

> **Tranché par le joueur (21/10/2026)** : 1) un seul boss final à 3 phases ; 2) run d'environ 18-20 min (charge de 60 s aux étages 1-2, 90 s ensuite) ; 3) étage 4 = Cryptes noyées ; 4) étages 4-5 produits avant les variantes B ; 5) pas de mini-boss hors biome en v1 (recommandation retenue).

1. **Boss final** : un seul boss à 3 phases (« Le Semeur de pluie »), ou 2 boss à la suite (un gardien puis la Source), ou 3 tirés au sort comme aux autres étages ? **Reco : un seul, à 3 phases**, qui cite les 4 biomes traversés ; un second boss final (variante sans fin) en LiveOps. Un étage final tiré au sort perd la valeur de « moment attendu ».
2. **Durée de run** : 5 étages à 4-5 min = **20-25 min** par run, contre la cible de 10 min du GDD (3 étages). Garder 5 étages et accepter 20 min (le format RoR2), ou raccourcir les étages (3 min : piliers plus rapides, charge 60 s) ? **Reco : accepter ≈ 18-20 min** avec une charge de 60 s au gros pilier des étages 1-2 et 90 s ensuite, et une sauvegarde à chaque étage (déjà prévue) pour les sessions mobiles courtes. À recalibrer avec `simulateur_scaling.py` passé à 5 étages (objets par run ≈ 45, tables de coffres et prix à revoir).
3. **Étage 4 = Cryptes noyées (souterrain, sans pluie)** : ce biome rompt avec le motif « la pluie partout » pour créer le contraste avant la Source. Alternative : un 4e biome extérieur (« Digues brisées » : barrage de béton, déversoirs, nuit d'orage). **Reco : Cryptes**, pour l'éclairage 2D (le joueur-lanterne) et parce que la Cité fait déjà l'orage nocturne.
4. **Variante B de l'étage 1 avant les étages 4-5, ou l'inverse ?** Les variantes B n'apportent que de la variété ; les étages 4-5 apportent la fin du jeu. **Reco : étages 4-5 d'abord** (grilles G1 jouables en L1, créatures N4/N5 après l'étage 1 complet), variantes B ensuite, l'étage 1 B en premier.
5. **Mini-boss hors biome** : faut-il garder une petite chance (10 %) de tirer un mini-boss d'un autre biome (le Colosse dans la Cité…) pour la surprise ? **Reco : non en v1** (la lisibilité « cet étage = ces menaces » est le but de la décision), oui comme mutateur de défi hebdomadaire.
