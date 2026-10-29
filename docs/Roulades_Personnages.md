# Roulades par personnage (design v1, REMPLACÉ)

> **Remplacé le 29/10/2026 par `docs/Design_Esquives.md`** (v2 implémentée : Averse glisse en consommant son eau, Ardent se téléporte, Vigie a 3 petits dashs). Gardé pour l'historique des choix.

> Statut : **document de design** (Fable, game-designer, 23/10/2026) sur demande du joueur : « une roulade différente par personnage ». Le joueur a imposé Ardent (téléportation) et Averse (glisse sur l'eau, sans recharge, jauge d'endurance) ; les huit autres mobilités sont **décidées ici** par délégation. Rien n'est implémenté ; les chiffres sont des points de départ à valider en playtest (le simulateur `art/tools/night/balance_sim.py` ne modélise pas la roulade : tout ce qui touche à la survie est **non vérifié**).
> Conventions : 1 u = 64 px ; « coef » = multiplicateur de Dégât_base(L) ; `slow` = clé de ralentissement existante (Givre, Vague) ; i-frames = invulnérabilité (`Player.is_invulnerable()`).

Sommaire : 0. Constat · 1. Principes communs · 2. Tableau de synthèse · 3. Fiche par personnage (3.1 Ardent, 3.2 Averse en détail, 3.3 Rictus, 3.4 Tocsin, 3.5 Arpenteuse, 3.6 Rainette, 3.7 Avare, 3.8 Bourbe, 3.9 Vigie, 3.10 Taliant) · 4. HUD et entrées · 5. Contrat technique et ordre d'implémentation · 6. Risques et points à trancher.

---

## 0. Constat (ce qui existe)

- **Roulade de base** (`game/scripts/player/player.gd` §Roulade, `Balance.DODGE_DISTANCE_U` 3,0 / `DODGE_DURATION_S` 0,25 / `DODGE_COOLDOWN_S` 3,0) : dash à vitesse constante 12 u/s, **invulnérable toute la durée** (`take_damage` et `apply_status` ignorés), `move_and_collide` (les murs bloquent, glissement le long), aucune collision monstre (masque 1), fantômes du sprite toutes les 0,04 s (fondu 0,3 s), son `spell.cendres.cast_light` à −4 dB / pitch 1,3. **Pas de réduction de recharge** par les items. Direction : déplacement en cours, sinon curseur (clavier-souris), sinon `facing`. Entrée `dodge` : Maj gauche / Espace, LB, bouton tactile « Roulade » (`DodgeButton`, anneau de recharge, grisé si `blocked`).
- **Hooks de kit déjà en place** (`game/CONTRACTS.md` « Kits de personnage ») : `can_dodge()`, `dodge_distance_u()` (Tocsin par état, Averse ≥ 80 d'eau), `dodge_motion_dir(dir)` (Rainette), `dodge_ghosts()`, `on_dodge_start(dir)` ; `CharacterData.dodge_distance_u` (Avare, Bourbe 2,5 u).
- **Déjà différencié en jeu** : Rictus (levée au-dessus des monstres, `collision_mask = WALL_MASK`, fils tendus), Rainette (bond arrière 3,5 u, `BACK_HOP_U`), Taliant (Iaï : coef 1,5 à 0,9 u du trajet, 4 % d'aiguisage s'il touche), Tocsin (3 / 1,5 / 3 / 1,5 / 2 u selon les membres), Averse (trébuchement 1,5 u à ≥ 80), Avare et Bourbe (2,5 u). Ardent, Arpenteuse, Vigie : roulade standard.
- **Budget de survie de la référence** : 3 u de repositionnement et 0,25 s d'invulnérabilité toutes les 3 s, soit **≈ 1 u/s** de déplacement d'esquive et **≈ 8 % du temps** invulnérable. Toute mobilité ci-dessous rend en moyenne ce budget-là, en échangeant éventuellement une part d'invulnérabilité contre du déplacement (Averse) ou de l'instantané (Ardent).
- **Esthétique MDA visée** : la roulade est le geste de la micro-boucle de 30 s (« bouger, esquiver, faucher ») ; la différencier par personnage sert le **Fantasme** (le geste dit qui l'on joue) et la **Sensation** (poids, rythme), jamais le Défi : aucune mobilité ne doit être la bonne réponse à un télégraphe que la roulade de base ne saurait pas gérer.

## 1. Principes communs (non négociables)

1. **Même bouton partout.** Action `dodge` inchangée (Maj / Espace, LB, bouton tactile). Direction = `Player.dodge_direction()` : joystick ou touches de déplacement, sinon curseur (clavier-souris), sinon l'avant. Deux personnages inversent le sens par défaut **sans entrée de déplacement** (Rainette, Vigie : elles reculent depuis la visée) ; avec le joystick, tout le monde part où il pousse. **Maintien** : seule Averse lit le maintien du bouton (glisse tant qu'on tient) ; pour les autres, maintenir = un seul déclenchement.
2. **Même budget.** Repositionnement moyen ≈ 1 u/s, invulnérabilité ≈ 8 % du temps (tableau §2). Une mobilité qui donne plus de distance donne moins d'i-frames (Averse) ; une mobilité instantanée (Ardent) donne un peu moins d'i-frames que la roulade mais zéro exposition pendant le trajet. Aucune réduction de recharge par les items (règle existante), aucune charge multiple en v1.
3. **Lisibilité.** Début et fin visibles en moins de 0,5 s : un **marqueur de départ** (fantôme, gerbe, nuage) et un **marqueur d'arrivée** (anneau au sol, éclaboussure, lumière). **Aucun téléport invisible** : l'Éclat d'Ardent laisse une silhouette de braises au départ et un anneau à l'arrivée ; le joueur voit d'où il vient et où il est. Les mobilités aériennes (Rictus, Rainette) gardent une **ombre de contact au sol** (`Iso.lift_px`).
4. **Murs, eau profonde, remparts.** Toute mobilité est un déplacement **balayé** (`Player.move_swept` ou `move_and_collide` + glissement) : jamais à travers un mur, même fin, même en une image. La destination est ensuite tenue dans la zone praticable (`NavField.is_reachable`, sinon `nearest_reachable` **du côté du départ**, jamais de l'autre côté d'un mur) : un blink ne finit jamais dans un mur, dans l'eau profonde `~` (cellule bloquée du NavField), hors des bornes (`clamp_to_bounds`), ni derrière les **remparts de bord** (blocs 1,25 u, `StaticBody2D` couche 1) ; une poche fermée (`is_enclosed`) est refusée. Les obstacles dynamiques (blocs de la Mère-Cristal) comptent via `is_reachable`. L'eau peu profonde `,` est praticable pour tous (bonus pour Averse).
5. **Monstres.** Comme la roulade de base, aucune mobilité n'est bloquée par un monstre (masque monde seulement) ; Rictus et Rainette passent **au-dessus** (lisible par la hauteur et l'ombre), les autres **à travers** (lisible par les fantômes ou la traînée).
6. **Pas un sort offensif.** Les effets secondaires sont du **contrôle léger** (ralentissement, vapeur), de la **ressource** (Tension, Souffle, or ramassé) ou cosmétiques ; le seul qui blesse reste l'Iaï de Taliant (déjà en jeu, 1,5 × 1 fois par 3 s ≈ 0,5 coef/s, ≈ 13 % de son DPS) et la braise d'Ardent (0,4 par 3 s ≈ 4 %). Un effet de roulade ne dépasse jamais **5 % du DPS** du kit.
7. **Plafond mobile.** Un seul VFX persistant par roulade (traînée ou zone), durée ≤ 2 s, pas d'effet par monstre traversé au-delà d'un statut ; un `ZoneEffect` au plus. Ombres dynamiques : aucune nouvelle.
8. **Équilibrage** : toute valeur ci-dessous vit dans le kit (`<id>_kit.gd`, constantes) ou dans `data/characters.json` (bloc `dodge`, §5) ; `Balance.DODGE_*` reste la roulade par défaut. Jamais en dur dans `player.gd`.

## 2. Tableau de synthèse

| Perso | Mobilité (nom FR) | Type | Distance | Durée | i-frames | Limite | u/s moyen | i-frames moyen | Effet secondaire |
|---|---|---|---|---|---|---|---|---|---|
| Ardent | **Éclat de braise** | blink balayé | 3 u instantané | 0,20 s (0,05 fondu + 0,15 reformation) | 0,20 s | recharge 3 s | 1,0 | 6,7 % (+ trajet nul) | braises au départ : coef 0,4 + brûlure légère à 1 u |
| Averse | **Glissade** | glisse tenue | jusqu'à 7,2 u (9 u/s × 0,8 s) ; 14 u sur l'eau | tenue | 0,15 s au départ seulement ; contact ignoré pendant | jauge Élan 100, départ 20, −100/s | ≈ 1,85 | ≈ 8 % | film d'eau au sol (cosmétique) |
| Rictus | **Levée** (existante) | saut aérien | 3 u | 0,25 s | 0,25 s | recharge 3 s | 1,0 | 8,3 % | fils tendus, au-dessus des monstres |
| Tocsin | **Coup de vapeur** | dash (× état) | 3 / 1,5 / 3 / 1,5 / 2 u | 0,25 s × distance/3 | = durée | recharge 3 s | 0,5-1,0 | 4-8 % | nuage de vapeur au départ : `slow` 30 % 1 s |
| Arpenteuse | **Trait tendu** | dash | 3 u | 0,25 s | 0,25 s | recharge 3 s | 1,0 | 8,3 % | les 3 u de chaîne posés d'un coup : `slow` 50 % 1,5 s sur ce segment |
| Rainette | **Bond arrière** (existant) | saut aérien | 3,5 u | 0,25 s | 0,25 s | recharge 3 s | 1,17 | 8,3 % | +1 Souffle à l'atterrissage |
| Avare | **Râfle du coffre** | dash lourd | 2,5 u | 0,25 s (10 u/s) | 0,25 s | recharge 3 s | 0,83 | 8,3 % | ramasse ses pièces à 1,2 u pendant + 0,3 s |
| Bourbe | **Coulée** | dash lourd | 3 u | 0,30 s (10 u/s) | 0,30 s | recharge 3 s | 1,0 | 10 % (compensé : lente, bruyante) | traînée de vase 3 × 0,8 u, 2 s : `slow` 30 % |
| Vigie | **Repli** | dash (recul par défaut) | 3 u | 0,25 s | 0,25 s | recharge 3 s | 1,0 | 8,3 % | +25 % de Tension à l'arrivée |
| Taliant | **Iaï** (existant) | dash tranchant | 3 u | 0,25 s | 0,25 s | recharge 3 s | 1,0 | 8,3 % | coef 1,5 à 0,9 u, −4 % d'aiguisage s'il touche |

Lecture : Ardent et Averse sont les deux vraies ruptures (instantané ; glisse sans recharge). Rictus, Rainette et Taliant existent déjà et sont **formalisés sans changement de chiffres** (une seule retouche : +1 Souffle pour Rainette). Tocsin, Arpenteuse, Avare, Bourbe, Vigie gardent un dash mais reçoivent un **effet signature léger** et un habillage propre.

---

## 3. Fiches

### 3.1 Ardent : « Éclat de braise » (imposé par le joueur : blink)

**Fiction.** Ardent est le porteur de braise : il **s'éparpille en braises** et se **rallume** 3 u plus loin. Pas de « téléport » magique : une bourrasque de braises part du point de départ et se rassemble à l'arrivée.

**Mécanique.**
- Appui → **fondu 0,05 s** (le sprite se désagrège en braises, invulnérable, entrées de déplacement ignorées) → **déplacement balayé instantané** de 3 u dans la direction (`move_swept(dir × 3 u)`, puis `nearest_reachable` côté départ si la case d'arrivée n'est pas praticable) → **reformation 0,15 s** (alpha 0 → 1, émission ×2 → ×1, invulnérable, **déplacement et sorts permis dès l'arrivée** : il « se reforme en courant »).
- i-frames totales **0,20 s** (`BLINK_PRE_S` 0,05 + `BLINK_POST_S` 0,15) ; recharge **3 s** (`Balance.DODGE_COOLDOWN_S`) ; distance **3 u fixe** sur toutes les plateformes (`BLINK_DISTANCE_U`), le curseur ne raccourcit pas le blink (voir §6 pour l'option).
- **Mur / eau profonde / rempart** : le balayage s'arrête au dernier point libre (hitbox 0,5 u comprise). Un blink de 0,4 u dos au mur **consomme quand même** la recharge (comme la roulade) : la lisibilité prime sur la clémence, et la braise de départ se produit toujours.
- **Braise de départ** (effet signature, léger) : à l'emplacement quitté, gerbe de braises de **1 u** de rayon : **coef 0,4**, proc 0,3, applique la brûlure d'Ardent (statut `burn` existant, 1 tick). ≈ 0,13 coef/s, soit ≈ 4 % de son DPS : un « adieu » lisible, pas un sort. Clés : `BLINK_EMBER_COEF` 0,4, `BLINK_EMBER_RADIUS_U` 1,0, `BLINK_EMBER_PROC` 0,3.

**Pourquoi 0,20 s et pas 0,25 s.** Le blink supprime l'exposition pendant le trajet (une roulade peut être « rattrapée » par un télégraphe qui finit à mi-course) et replace Ardent **instantanément** en position de tir : à i-frames égales il dominerait la roulade (Sirlin : option strictement meilleure). On rend 0,05 s ; il reste le personnage le plus sûr du roster, ce qui est son rôle (débutant 1/5).

**Lisibilité (marques).**
- Départ : **silhouette de braises** (fantôme du sprite courant, modulation `#FF8C33` additive, reste 0,3 s puis s'effondre en 6 particules) + gerbe `ember_burst` (TOP 6 frames, 1,2 u) + flash de lumière `ardent_blink` 0,25 s (preset à ajouter aux lumières du kit, accent braise).
- Arrivée : **anneau de braises** au sol (`blink_ring`, TOP 6 frames, rayon 1 u → 1,6 u en 0,25 s), sprite qui se reforme (alpha + émission `_e` ×2), petites braises montantes 0,4 s.
- Trait de liaison : **non** (un trait relierait visuellement les deux points mais encourage à croire qu'il traverse les murs). Les deux marques suffisent : elles sont à 3 u l'une de l'autre, à l'écran les deux sont visibles.
- Son : « souffle de braise » grave (0,1 s) au départ, « crépitement » clair à l'arrivée (0,15 s), hauteur fixe. À produire par Codex (`art/tools/audio/`), remplace `spell.cendres.cast_light` pour lui.

**Synergie kit.** La braise de départ porte les items de brûlure (`burn_damage_add`) et les procs à 0,3 : cohérent avec Cendres (0,3/tick) ; **Danseur** : le blink compte comme mouvement (0,2 s). Aucune interaction avec Nova / Brasier : pas de remise à zéro, pas de bonus.

**HUD.** Bouton de roulade standard (anneau de recharge 3 s), icône « éclat » ; libellé « Éclat ».

**Codex.** Anim `blink_out` 3 frames × 8 dir (il s'effrite, bras ouverts) et `blink_in` 4 frames × 8 dir (il se reforme) ; repli : fondu alpha du sprite `idle`. VFX `ember_burst` (TOP 6), `blink_ring` (TOP 6). Lot **A3** (low).

### 3.2 Averse : « Glissade » (imposé par le joueur : glisse sur l'eau, sans recharge, jauge d'endurance)

**Fiction.** La porteuse de pluie **verse un filet d'eau sous ses pieds et glisse dessus**, amphore ou pas : glisser, c'est **s'affranchir du poids** qui la ralentit à pied (3,4 u/s pleine). Sur l'eau de la carte, elle glisse presque sans effort.

**Jauge « Élan »** (endurance de glisse, **distincte de l'Eau** : glisser ne vide jamais l'amphore, sinon la Glissade concurrencerait la Crue et la joueuse ne glisserait jamais).
- Capacité **100** (`SLIDE_GAUGE_MAX`). Départ : **−20** immédiat (`SLIDE_START_COST`, la gerbe de lancement) ; puis **−100/s** en glisse (`SLIDE_DRAIN_PER_S`). Depuis une jauge pleine : **0,8 s** de glisse continue, soit **7,2 u** à 9 u/s. Un appui bref (0,15 s mini) coûte 35 : **deux coups secs** par jauge.
- Recharge : **+40/s** (`SLIDE_REGEN_PER_S`, pleine en 2,5 s) après un **délai de 0,6 s** sans glisser (`SLIDE_REGEN_DELAY_S`) ; **jamais pendant la glisse**. Aucune recharge en secondes affichée : la jauge **est** la limite.
- Seuil de départ : il faut **≥ 20** (le coût de lancement) ; en dessous, bouton grisé « Élan » (pas « À SEC », réservé à l'eau).
- **Sur l'eau** (cases `,` de la carte, **sa Flaque-miroir** comprise ; lecture par `AverseKit.is_map_water` + test des flaques du kit) : **drain −50/s, recharge +80/s et sans délai** ; `SLIDE_WATER_DRAIN_MULT` 0,5, `SLIDE_WATER_REGEN_MULT` 2,0. Depuis la pleine jauge : 1,6 s = **14 u** d'un bord à l'autre d'un bassin. L'**eau profonde `~` reste infranchissable** (cellule bloquée : la glisse bute sur la rive et s'arrête) : l'eau porte sur le gué, pas sur le lac. C'est son **bonus de carte** : Cryptes noyées, son étage sans pluie, lui rend de la mobilité par ses flaques.

**Glisse.**
- Vitesse **9 u/s** (`SLIDE_SPEED_U`), **indépendante du niveau d'eau** (c'est le point : pleine, elle est lente à pied mais glisse à la même vitesse). Plus lente que la roulade (12 u/s) mais tenue ; plus de deux fois sa course.
- Direction : celle de l'appui ; **le joystick / les touches dirigent en continu** avec une inertie de glisse (rotation **200°/s** max, `SLIDE_TURN_DEG_S`) ; sans entrée, elle garde le cap. Relâcher = **arrêt 0,1 s** (anim `slide_stop`). Durée minimale **0,15 s** (un tap donne un coup sec de 1,4 u).
- **i-frames : 0,15 s au départ seulement** (`SLIDE_IFRAME_S`, le temps de la gerbe de lancement) ; **pendant la glisse, les coups de contact des monstres traversés sont ignorés** (règle de Rainette en l'air : `ignores_hit(source)` si la source est à portée de contact ; les **boss, les projectiles et les zones télégraphiées touchent**). Justification : une glisse de 0,8 s totalement invulnérable sans recharge donnerait ≈ 20 % du temps d'invulnérabilité (vs 8 %) : dégénéré ; à l'inverse, zéro protection rendrait la traversée d'un paquet suicidaire, or traverser est tout l'intérêt d'une glisse. Le compromis « l'eau porte, elle ne protège pas » : elle **passe à travers** la mêlée sans dommage, mais une Grêle de T2, une onde de boss ou une vague d'écluse la touchent **comme si elle marchait**. Budget : 0,30 s d'i-frames par ≈ 3,7 s de cycle ≈ 8 %, et ≈ 1,85 u/s de déplacement (presque le double de la roulade), payés par une défense nulle contre le distant : cohérent avec une kiteuse de 90 PV.
- **Jauge vide en pleine glisse** : arrêt immédiat avec `slide_stop` (0,1 s, vitesse ×0,8), petit « plouf » sec, jauge éteinte 0,6 s puis recharge. Pas de pénalité supplémentaire (pas de trébuchement forcé) : la joueuse a déjà perdu sa mobilité.
- **Amphore ≥ 80** (ex-trébuchement) : le départ coûte **30** au lieu de 20 et l'arrêt dure **0,25 s à vitesse ×0,6** (`STUMBLE_*` existants réaffectés) : pleine, elle freine mal. L'ancienne roulade de 1,5 u disparaît.
- **Sorts pendant la glisse** : la Goutte-lame (auto) continue ; appuyer sur **Vague / Flaque / Crue arrête la glisse** (frein 0,1 s) **puis lance le sort** : pas d'anim de lancer en glisse à produire, et la réponse reste immédiate. Déposer une Flaque devant soi pour glisser dessus est un petit combo lisible (18 d'eau pour une piste).
- **Murs** : `move_and_collide` + glissement le long ; un mur frontal (normale > 0,7 contre le cap) **arrête** la glisse (elle bute, `slide_stop`). Chaque image, test `nav.is_blocked_at` au point d'avance : l'eau profonde arrête comme un mur.

**Lisibilité.** Départ : **gerbe d'eau** `splash_start` (TOP 6, 1 u) + ses pieds sur un **film d'eau** ; pendant : **sillage** `slide_wake` (ruban TOP 4 frames répété, 0,6 u de large, s'efface en 1 s) et empreintes mouillées, **pas de fantômes de sprite** (`dodge_ghosts()` faux) ; arrivée : petite éclaboussure. L'amphore brille (`_e` ×1,5) tant qu'elle glisse. Son : « plouf » de lancement puis **chuintement continu** filtré dont la hauteur suit la vitesse (et monte d'un ton sur l'eau), « plop » à l'arrêt ; à produire par Codex.

**Synergie kit.** La Flaque-miroir devient une **piste** (drain ÷2, recharge ×2) ; la Crue vide l'amphore et laisse une Flaque : « je déferle, puis je glisse dessus » ; l'eau de la carte lui rend déjà +12 d'eau/s : glisser dans un gué remplit l'amphore ET l'Élan. Aucun bonus de dégâts.

**HUD.** Le bouton de roulade passe en **mode jauge** : l'anneau se remplit en cyan (#5FD4E8) avec l'Élan, plein = prêt ; **se vide en glissant**, grisé sous 20 avec le libellé « Élan » ; pulse brièvement quand elle est sur l'eau (bonus actif). Sur PC, même anneau à droite de la barre de sorts. La jauge d'Eau (`ResourceGauge`) ne change pas.

**Codex.** Anim `slide` 4 frames × 8 dir (jambes fléchies, amphore tenue d'une main), `slide_stop` 2 frames × 8 dir ; repli : `run` figée frame 3. VFX `splash_start` (TOP 6), `slide_wake` (TOP 4, tuile répétable), icône « glissade ». Lot **AV5** (low).

### 3.3 Rictus : « Levée » (existante, formalisée)

- Le Montreur **soulève** le pantin : saut de **3 u en 0,25 s** à `lift_px(0,8)`, **au-dessus des monstres**, les murs arrêtent (`collision_mask = WALL_MASK`), **invulnérable** toute la durée, recharge 3 s. Interdit pendant le vertige ; permis pendant la Toupie (retour joueur).
- Marques : pas de fantômes ; **ombre de contact au sol** pendant le vol (lisible : il n'y a que lui et Rainette en l'air), fils tendus (`strings.tension = 1,0`), Montreur en `pull`, **claquement de talons de bois** à l'atterrissage (son à produire).
- Effet secondaire : aucun (le kit a déjà la garde du Montreur et les fils tendus). Décision : **ne rien ajouter** ; la levée est déjà la roulade la plus caractérisée du roster.
- Codex : `lift` 3 frames existe (lot M2) ; rien de neuf.

### 3.4 Tocsin : « Coup de vapeur »

**Fiction.** La chaudière **lâche sa vapeur** par la grille pectorale et propulse l'automate.

- Dash standard **3 u / 0,25 s / i-frames / 3 s**, **distance par état de membres** inchangée (§1.4 de Design_Personnages : 3 / 1,5 (cloche-pied) / 3 (roue sur les mains) / 1,5 (rampe) / 2 (tonneau)) via `dodge_distance_u()`.
- **Effet signature** : au départ, **nuage de vapeur** de **1,2 u** pendant **0,6 s** : les monstres dedans sont **ralentis 30 % pendant 1 s** (clé `slow`, rafraîchie tant qu'ils y sont). Pas de dégâts. Clés `STEAM_RADIUS_U` 1,2, `STEAM_DURATION_S` 0,6, `STEAM_SLOW` 0,3, `STEAM_SLOW_S` 1,0. Synergie : ralentis = `is_slowed()` vrai pour Cœur de glace, et un paquet ralenti est plus facile à attraper au bras.
- **Sans jambes** (tonneau, rampe) : la vapeur sort quand même (c'est la chaudière), la distance suit l'état.
- Marques : jet de vapeur `steam_burst` (CREA 6 frames, 1 direction, posé sur la grille) + nuage au sol `steam_cloud` (TOP 6) ; fantômes en **calques** conservés (ils reprennent les membres affichés) ; émission du foyer ×1,5 pendant 0,3 s. Son : « pschhh » de soupape (0,2 s) + cliquetis de bielles.
- HUD : standard. Codex : lot **T6** (low) : `steam_burst`, `steam_cloud`.

### 3.5 Arpenteuse : « Trait tendu »

**Fiction.** La géomètre **file droit** : le touret se dévide d'un coup et la chaîne reste **tendue** derrière elle.

- Dash standard **3 u / 0,25 s / i-frames / 3 s**. Comme aujourd'hui, les 3 u de chaîne sont **posés d'un coup** (polyligne de 14 u : la queue avance d'autant).
- **Effet signature** : le segment posé pendant le dash est **« tendu » 1,5 s** (`TAUT_S`) : les monstres qui le touchent subissent **`slow` 50 %** au lieu de 35 % (`TAUT_SLOW` 0,5), **sans dégâts supplémentaires** (le tick de la Chaîne, coef 1,0 / 0,5 s, reste le même). Rendu : ce tronçon brille plus (émission 4,5, comme « quand elle mord ») et ne balance pas.
- **Synergie** déjà présente, à enseigner : la Boucle exige 3 u de chaîne ; après une Boucle (chaîne consommée), **un dash réarme une Boucle d'un coup**, au lieu de 0,7 s de course. Tip : « Un Trait tendu redonne de quoi boucler ».
- Marques : pas de fantômes de sprite (`dodge_ghosts()` faux) : la **chaîne qui claque** suffit ; étincelles de cuivre le long du segment (`chain_sparks`, TOP 4), petit flash au touret. Son : fouet de chaîne (0,15 s) + cliquet du touret.
- Pas d'interaction avec le Piquet (la ligne piquet → elle suit déjà sa position). HUD : standard. Codex : lot **AR3** (low) : `chain_sparks`, icône.

### 3.6 Rainette : « Bond arrière » (existant, + 1 retouche)

- **3,5 u / 0,25 s / i-frames / 3 s** (`BACK_HOP_U`), arc 0,8 u, **au-dessus des monstres** (contact ignoré), murs arrêtent. Sens par défaut : **à reculons depuis la visée** sans entrée de déplacement (elle garde la menace en face) ; avec le joystick, elle saute là où il pousse, tournée vers l'arrière (`dodge_motion_dir`). Interdit pendant le Grand saut.
- **Retouche** : **+1 Souffle à l'atterrissage** (`BACK_HOP_BREATH` 1) : le bond arrière est une **respiration** ; il ne la sort pas de l'essoufflement (1 s sur place inchangée) mais lui évite d'y tomber. ≈ +0,33 Souffle/s au plus, contre +2,5/s au sol : un appoint, pas une source.
- Marques : pas de fantômes ; ombre de contact, anneau d'atterrissage `land_ring` (TOP 4, existant). Son : « croâ » bref + impact mouillé.
- HUD : standard. Codex : `dodge` existe (lot RN2) ; rien de neuf.

### 3.7 Avare : « Râfle du coffre »

**Fiction.** L'usurier **lance son coffre en avant** et se laisse traîner par la chaîne ; le coffre **râfle** les pièces au passage.

- Dash **2,5 u / 0,25 s** (10 u/s : lourd, la constante de vitesse de Balance est remplacée pour lui par `RAKE_SPEED_U` 10), **i-frames 0,25 s**, recharge 3 s. Distance courte **conservée** (armure 30, coffre-bouclier : il est déjà le plus solide).
- **Effet signature** : pendant le dash et **0,3 s après**, le rayon de ramassage de **ses propres pièces** (ressources de joueur `PLAYER_RESOURCE`, jamais l'or des monstres ni les capsules) passe à **1,2 u** (`RAKE_PICKUP_U`, contre 0,6-0,75 u au contact). Réponse directe au retour « je ne comprends pas comment remplir la bourse » : **la roulade est le geste pour aller rechercher ses pièces dans la foule**. Aucun or créé (équité de l'or inchangée).
- Marques : fantômes du sprite teintés or (#F2C14E, alpha 0,4) ; le coffre laisse une **traînée d'étincelles** `chest_drag` (TOP 4) ; pièces aspirées en arc vers le coffre (déplacement des pickups existants). Son : chaîne qui claque + coffre qui racle (0,3 s), tintements des pièces ramassées (existant).
- HUD : standard. Codex : lot **AV-R** (low) : `chest_drag`, icône.

### 3.8 Bourbe : « Coulée »

**Fiction.** La mère-vase **se liquéfie** et coule 3 u sous la mêlée avant de se redresser.

- Dash **3 u / 0,30 s** (10 u/s : `FLOW_SPEED_U`), **i-frames 0,30 s**, recharge 3 s. Léger surplus d'invulnérabilité (10 % vs 8,3 %) **assumé** : elle est lente (3,6 u/s), bruyante, et sa coulée finit 0,05 s plus tard que les autres, à portée du paquet qu'elle vient de traverser. Remplace l'ancienne roulade de 2,5 u (`CharacterData.dodge_distance_u`).
- **Effet signature** : **traînée de vase** de **3 u × 0,8 u** pendant **2 s** (`FLOW_TRAIL_S`) : `slow` **30 %** rafraîchi (`FLOW_TRAIL_SLOW` 0,3), **sans dégâts** (le Bourbier garde le DoT). Un seul `ZoneEffect` rectangulaire orienté (ou 3 disques de 0,5 u : moins cher à tester, à trancher par l'implémentation).
- Hitbox pendant la coulée : **0,35 u** (elle est à plat) ; sans effet sur les dégâts (invulnérable) mais lisible.
- Les mottes ne sont **pas** recollées par la coulée (le Rappel garde ce rôle). Pendant le Bourbier : roulade bloquée (inchangé).
- Marques : pas de fantômes ; anim `flow` (elle s'aplatit, 4 frames) + traînée `mud_trail` (TOP 4, tuile répétable) ; feu follet qui file au ras du sol (lumière `bourbe_follet`). Son : gargouillis de vase (0,3 s) + succion au redressement.
- HUD : standard. Codex : lot **B4** (low) : `flow` 4 × 8 dir, `mud_trail`, icône.

### 3.9 Vigie : « Repli »

**Fiction.** L'archère **rompt d'un pas** et **bande son arc** en reculant.

- Dash **3 u / 0,25 s / i-frames / 3 s**. Sens par défaut **sans entrée de déplacement : à l'opposé de la visée** (curseur / stick droit / ennemi le plus proche), `facing` **gardé vers la cible** (anim `dodge_back`, elle recule face à l'ennemi) ; avec le joystick, elle part où il pousse (même règle que Rainette, `dodge_motion_dir`).
- **Effet signature** : **+25 % de Tension à l'arrivée** (`DODGE_TENSION_GAIN` 0,25). Ordre de grandeur : +0,083 Tension/s au plus, contre +0,45/s en marche et +1/s ancrée : ≈ +18 % de Traits d'allonge pour qui esquive régulièrement, loin derrière le Filet (Tension pleine). Le rythme devient « je recule, je m'arrête une seconde, la flèche lourde part ».
- Marques : fantômes teintés rouge de fusée (#FF3A4F, alpha 0,35) ; **corde qui s'allume** (`_e`) à l'arrivée ; petit éclat de magnésium au carquois. Son : pas de bottes glissées + **corde tendue** (0,2 s) à l'arrivée.
- HUD : standard. Codex : `dodge_back` 4 frames × 8 dir (lot **VG3**, low) ; repli : `run` jouée à l'envers.

### 3.10 Taliant : « Iaï » (existant, formalisé)

- Dash **3 u / 0,25 s / i-frames / 3 s** qui **tranche chaque monstre traversé** à 0,9 u du trajet, une fois chacun : coef **1,5** (× aiguisage/100), recul 0,4 u, proc 0,8 ; coûte **4 %** d'aiguisage s'il touche au moins un monstre ; **doublé** sous Lames jumelles (0,12 s plus tard). Murs arrêtent. Seule roulade qui blesse (≈ 0,5 coef/s, ≈ 13 % de son DPS : accepté, c'est son « sort 2 » de bretteur, décision du 22/10).
- Marques : `iai_trail` (fil de sève tendu sur le trajet, 0,3 s) ; **pas de fantômes braise** ; ajout : **clic de fourreau** 0,2 s après l'arrivée (son à produire) et éclat `morfil_edge` proportionnel à l'aiguisage sur chaque monstre tranché (existant).
- Garde : l'Iaï **ne laisse pas de garde** en v1 (levier noté dans la fiche si les dégâts subis au niveau 12 le demandent : « Iaï qui laisse 0,5 s de garde »).
- HUD : standard. Codex : `dodge` 5 frames et `iai_trail` prévus au lot SA1 ; rien de neuf.

---

## 4. HUD et entrées (pour l'ux-designer)

- **Bouton de roulade** (`DodgeButton`, tactile 120 px et barre PC 90 px) : deux modes rendus par le même nœud.
  - **Recharge** (9 personnages) : anneau qui se vide puis se remplit sur 3 s, grisé avec icône de cause quand `blocked` (Toupie-vertige de Rictus, Grand saut de Rainette, Bourbier de Bourbe). Icône et libellé **par personnage** (« Éclat », « Levée », « Vapeur », « Trait », « Bond », « Râfle », « Coulée », « Repli », « Iaï »).
  - **Jauge** (Averse) : anneau **cyan** rempli à Élan/100, qui **se vide en glissant** ; sous 20 : grisé, libellé « Élan » ; léger pulse quand le bonus « sur l'eau » est actif. Pas de chiffre.
- **Tactile** : tap = déclenchement ; **maintien** lu seulement pour Averse (le bouton doit émettre pressé / relâché : `Input.action_press(&"dodge")` au toucher, `action_release` au relâcher, au lieu d'une simple simulation d'appui). La direction = joystick, sinon la visée automatique (ennemi le plus proche), sinon l'avant. Pour Rainette et Vigie sans joystick : recul depuis l'ennemi le plus proche.
- **Manette** : LB ; maintien pour Averse ; direction = stick gauche, sinon stick droit (visée), sinon l'avant.
- **Clavier-souris** : Maj gauche / Espace ; direction = ZQSD, sinon le curseur. Pour Averse, la glisse suit ZQSD en continu ; sans touche, elle garde le cap pris au départ (le curseur ne la dirige pas : une glisse qui suit la souris serait incontrôlable).
- **Tips** (tips.json, orchestrateur) : un par mobilité (ex. Ardent « Tes braises restent où tu étais : un monstre qui s'y jette brûle » ; Averse « Maintiens la roulade pour glisser ; l'eau de la carte te porte » ; Avare « La Râfle ramasse tes pièces au passage » ; Vigie « Reculer bande ton arc »).

## 5. Contrat technique suggéré et ordre d'implémentation (pour l'orchestrateur ; aucune valeur en dur)

**Principe** : la roulade de base reste le **défaut** ; un kit **fournit un objet de mobilité** au lieu de patcher la roulade par hooks dispersés.

- **`DodgeMove`** (`game/scripts/player/dodge/dodge_move.gd`, RefCounted, stratégie) :
  - `start(player, dir) -> bool`, `step(delta) -> bool` (faux = terminé), `stop()` (relâcher / interruption), `is_invulnerable() -> bool`, `ignores_contact() -> bool` (Averse, Rainette), `blocks_spells() -> bool`, `blocks_move_input() -> bool`, `wants_ghosts() -> bool`, `lift_px() -> float`, `collision_mask() -> int`.
  - `ui_state() -> Dictionary` : `{mode: "cooldown" | "gauge", remaining, total, gauge (0-1), active, blocked, label, icon}` : remplace `Player.get_dodge_cooldown()` (qui le relaie, compatibilité `DodgeButton`).
  - `is_hold() -> bool` : la mobilité lit le maintien (`Input.is_action_pressed(&"dodge")`) ; le joueur transmet le relâcher par `stop()`.
- **Implémentations** : `RollMove` (défaut : Balance.DODGE_*, distance via `CharacterData.dodge_distance_u` ou `kit.dodge_distance_u()`, sens via `kit.dodge_motion_dir`, fantômes), `BlinkMove` (Ardent : `move_swept` + `nearest_reachable`), `SlideMove` (Averse : jauge, drain, direction continue, `is_blocked_at` par image), `LiftMove` (Rictus : RollMove + `lift_px` + `WALL_MASK`), `HopMove` (Rainette : RollMove + arc + sens inversé). Taliant, Tocsin, Arpenteuse, Avare, Bourbe, Vigie = `RollMove` + callbacks du kit `on_dodge_start(dir)` / **`on_dodge_end(pos)`** (nouveau hook : braise, vapeur, Tension, Souffle, traînée, râfle).
- **Kit** : `make_dodge() -> DodgeMove` (défaut `RollMove`) ; les hooks existants (`can_dodge`, `dodge_distance_u`, `dodge_motion_dir`, `dodge_ghosts`, `on_dodge_start`) sont **conservés** et lus par `RollMove` : aucun kit existant ne casse.
- **Données** : `data/characters.json`, bloc `dodge` par personnage : `{"kind": "roll|blink|slide|lift|hop", "distance_u", "duration_s", "cooldown_s", "label", "icon"}` + pour `slide` : `{"gauge_max", "start_cost", "drain_per_s", "regen_per_s", "regen_delay_s", "speed_u", "iframe_s", "water_drain_mult", "water_regen_mult"}` ; `CharacterData.dodge_distance_u` devient `dodge.distance_u`. Les effets signatures (coefs, rayons, ralentissements) restent en **constantes du kit** (logique propre). `Balance.DODGE_*` inchangé = valeurs du `kind: roll` par défaut.
- **Sauvegarde** : `SlideMove` expose `save_state()` (jauge Élan) via `kit.save_state()` d'Averse ; les autres n'ont rien à sauver (recharge non sauvegardée : règle générale).
- **Partagés (orchestrateur)** : `player.gd` (délégation à `DodgeMove`, `_dodge_step` déplacé dans `RollMove`), `dodge_button.gd` (mode jauge, pressé / relâché), `CONTRACTS.md`. Les kits et les lumières (`*_kit.gd`) sont du ressort des agents dev par personnage.
- **Tests** : `tests/dodge_test.tscn` : pour chaque `kind`, (a) un dash / blink vers un mur à 0,5 u finit **devant** le mur ; (b) vers une case `~` finit sur la rive ; (c) vers le bord de carte reste dans `clamp_to_bounds` ; (d) un blink vers une poche `is_enclosed` est rabattu côté départ ; (e) Averse : jauge 100 → 0 en 0,8 s hors eau, 1,6 s dans l'eau, recharge 2,5 s après 0,6 s, aucun gain pendant la glisse ; (f) i-frames : durée mesurée = valeur du JSON ; (g) Rictus / Rainette : `collision_mask` restauré à l'atterrissage.

**Ordre d'implémentation.**
1. **Socle** `DodgeMove` + `RollMove` (refactor sans changement de comportement) + `dodge_test` (a-d, f-g) ; `DodgeButton` lit `ui_state()`. Rictus (`LiftMove`), Rainette (`HopMove`), Taliant (callbacks) migrés **sans changer un chiffre**.
2. **Ardent : `BlinkMove`** (imposé) : balayage, marques, braise de départ, lumière `ardent_blink`, lot Codex A3.
3. **Averse : `SlideMove`** (imposé) : jauge, maintien tactile / manette, bonus eau, i-frames de départ, arrêt-puis-sort, mode jauge du bouton, lot AV5. Retirer l'ancienne roulade de 1,5 u.
4. **Effets signatures légers** (un agent par kit, en parallèle) : Avare (râfle), Vigie (Tension, recul par défaut, `dodge_back`), Rainette (+1 Souffle), Tocsin (vapeur), Arpenteuse (segment tendu), Bourbe (coulée 3 u / 0,3 s, traînée).
5. **Tips, icônes et libellés** par personnage ; sons Codex (`art/tools/audio/`) : départ / arrivée par mobilité, chuintement d'Averse.
6. **Playtest** : mesurer dégâts subis par personnage avant / après (`balance_sim_run` ne modélise pas la roulade : prévoir une mesure en jeu, `capture_hit_feel` ou journal `Events.player_damaged` sur 5 min par perso).

## 6. Risques et points à trancher par le joueur

- **Averse, contact ignoré en glisse** : si les playtests montrent qu'elle traverse les mêlées sans jamais payer, resserrer d'abord le drain (100 → 125/s) ou le coût de départ (20 → 30), **pas** l'immunité de contact (c'est l'identité du geste). Inversement, si les tireurs T2 la tuent en glisse, envisager 0,25 s d'i-frames au départ au lieu de 0,15.
- **Averse sur l'eau** : 14 u d'une traite dans un gué peut court-circuiter une zone de charge bordée d'eau (level-designer à consulter : cartes avec `,` près des piliers). Levier : `SLIDE_WATER_DRAIN_MULT` 0,5 → 0,7.
- **Ardent, distance fixe vs curseur** (à trancher) : option « le blink s'arrête au curseur s'il est entre 1 et 3 u » = précision PC supplémentaire, mais divergence PC / mobile et risque de blink trop court par erreur. Recommandation : **fixe** en v1, option plus tard si les joueurs PC le demandent.
- **Ardent, lisibilité pour un nouveau joueur** : un blink sans trait de liaison peut dérouter 2-3 fois ; parade : les deux marques à 3 u l'une de l'autre + tip. À vérifier sur `capture_hit_feel`.
- **Bourbe à 10 % d'i-frames** : surplus assumé ; si elle devient la plus sûre des mêléistes, revenir à 0,25 s (3 u à 12 u/s) plutôt que de toucher la traînée.
- **Taliant** : l'Iaï reste le seul dash offensif ; s'il devient une boucle dominante (Iaï à chaque recharge pour le coef gratuit), le coût de 4 % suffit en théorie ; sinon, porter la recharge à 3,5 s pour lui seul.
- **Perf** : traînées (Averse, Bourbe, Avare) = 1 nœud chacune, durée ≤ 2 s ; vapeur et traînée de vase = 1 `ZoneEffect` par 3 s : négligeable à 250 monstres. Le test `is_blocked_at` par image d'Averse est O(1).
- **Mobile, maintien** : le `DodgeButton` doit cesser de simuler un appui unique ; vérifier qu'un doigt qui glisse hors du bouton relâche bien (sinon Averse vide sa jauge toute seule).
- **Dépendances** : `Player.move_swept` et `NavField.is_reachable / nearest_reachable / is_enclosed / is_blocked_at` existent (CONTRACTS.md 22/10) : aucun nouveau contrat partagé hors `DodgeMove`, `dodge_button.gd` et le bloc `dodge` de `characters.json`.
