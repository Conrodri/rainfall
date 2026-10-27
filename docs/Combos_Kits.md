# Combos et interactions internes des kits (design v1)

> Statut : **document de design** (Fable, game-designer, 27/10/2026) sur demande du joueur : « voir comment modifier les kits de nos personnages pour faire un maximum d'interactions ou de combos, comme Arpenteuse et Taliant qui sont très interactifs entre leurs propres sorts ». Rien n'est implémenté ; aucun fichier de `game/` n'a été modifié. Les chiffres sont des points de départ à passer au simulateur (`balance_sim_run.tscn --chars=<id>`, avant/après) : **systems-designer** valide les coefs avant tout code.
> Conventions : 1 u = 64 px ; « coef » = multiple de Dégât_base(L), commun à tous les personnages ; les valeurs de base citées sont celles des kits (`game/scripts/spells/<id>_kit.gd`) au 27/10/2026, qui prévalent sur les fiches. Cibles d'équilibrage (`docs/Equilibrage_Personnages.md`) : mono-cible dans [0,85 ; 1,20] × Ardent, chaque variante à ±15 % du sort qu'elle remplace, Arpenteuse élite 1,30. Règles de lisibilité : télégraphe ≥ 0,8 s pour tout effet différé, aucune mort instantanée, un retour visuel et sonore par combo.
> Plateformes : sort 1 automatique partout ; PC : sorts 2-4 visés au curseur ; manette : stick droit sinon le plus proche ; **mobile : ciblage automatique** (S5 : paquet le plus dense). Chaque combo ci-dessous est noté sur ce critère : il doit **se produire naturellement** avec la visée automatique, ou recevoir une aide d'auto-visée explicite.

Sommaire : 1. Analyse : ce qui rend Arpenteuse et Taliant interactifs (cinq patrons réutilisables, boîte à outils du code) · 2. Les dix personnages (carte des interactions, note /5, combos proposés) · 3. Priorisation et lots · 4. Questions ouvertes · Annexe A : récapitulatif.

---

## 1. Analyse : pourquoi Arpenteuse et Taliant sont interactifs

### 1.1 Arpenteuse (`arpenteuse_kit.gd`) : le kit entier parle à un seul objet, la chaîne

- **Un état posé au sol que les autres sorts lisent.** La Chaîne (auto) n'est pas un projectile : c'est une polyligne de 14 u (`CHAIN_MAX_U`, points tous les `CHAIN_STEP_U` 0,25 u) qui **est** la ressource (`resource_frac()` = longueur / 14). Le Halage frappe une bande de `BOUCLE_BAND_U` 1,2 u le long de **toute** la chaîne posée ; le Tendeur claque à `TENDEUR_REACH_U` 1 u de la chaîne **et** de la ligne du piquet ; les deux exigent une longueur minimale (`BOUCLE_MIN_U` 3 u, `TENDEUR_MIN_U` 2 u). Trois sorts sur quatre sont donc **conditionnés par le déplacement** du joueur : où il a couru décide où ses sorts frappent.
- **Un second objet qui prolonge le premier.** Le Piquet plante un point fixe et tend une ligne piquet → joueuse 5 s (`PEG_LIFE_S`) ; cette ligne est lue par le Halage et par le Tendeur comme si elle faisait partie de la chaîne. Un objet du kit **agrandit l'état** que les autres consomment.
- **L'ordre change l'effet.** Tendeur avant Halage : les monstres sont traînés à 1 u d'elle et emprisonnés 1,5 s (`TENDEUR_STUN_S`), donc le Halage suivant touche un paquet immobile. Halage avant Tendeur : l'attraction de 1,5 u (`BOUCLE_PULL_U`) rapproche les monstres de la chaîne, donc le Tendeur en attrape davantage. Les deux ordres sont valides et donnent deux résultats différents : c'est ce qui fait le « jeu ».
- **Un positionnement relatif à l'objet.** Le piquet est arraché au-delà de `PEG_SNAP_U` 10 u ; la chaîne se rembobine à l'arrêt (`CHAIN_IDLE_S` 0,6 s puis `CHAIN_REEL_U_S` 4 u/s). Le joueur gère en permanence sa distance à ses propres objets.

### 1.2 Taliant (`morfil_kit.gd`) : une ressource que chaque geste dépense et qu'un sort rend

- **Ressource construite par un sort, dépensée par tous les autres.** L'aiguisage (0-100 %) multiplie **tous** les dégâts de lame (`× aiguisage / 100`, plancher `SHARP_MIN` 10 %). Chaque geste coûte : auto `COST_CIRCLE` / `COST_THRUST` 3 %, Fauche-lune `COST_CRESCENT` 15 %, Iaï `COST_IAI` 4 % s'il touche. L'Aiguisage (sort 3) remet à 100 %. Le joueur **choisit quand** dépenser gros (Fauche-lune à 100 % = 4,0 ; à 50 % = 2,0) et quand remettre à neuf.
- **Un ultime à seuil qui lit la ressource.** Lames jumelles exige ≥ `SHARP_ULT_MIN` 90 % : l'ordre « Aiguisage puis ultime » est imposé par la règle, pas par un tip.
- **Des gestes qui se parlent par un état court.** Chaque geste ouvre une garde (`GUARD_TAKEN_MULT` 0,55 pendant `GUARD_S` 0,6 s) : enchaîner les gestes maintient la garde ; s'arrêter l'ouvre. La roulade (Iaï) est un geste de lame : elle paie, elle est doublée sous Lames jumelles (`TWIN_DELAY_S` 0,12 s), elle garde.
- **Les variantes s'insèrent dans la même économie** : Sur-aiguisage (6 gestes ×1,5 dans 8 s, `EDGE_STRIKES` / `EDGE_MULT` / `EDGE_S`), Trempe (usure 0 pendant 15 s). Elles ne créent pas une seconde ressource : elles changent la façon de dépenser la première.

### 1.3 Les cinq patrons réutilisables

| # | Patron | Définition | Référence dans le code | Où il manque |
|---|---|---|---|---|
| P1 | **État posé au sol consommé par un autre sort** | Un sort laisse un objet (zone, polyligne, piquet, flaque, pilier, motte, doublure, couteau) ; un autre sort lit cet objet (distance, contenu) et change son effet. | Chaîne / piquet (Arpenteuse) ; Gluant → bonds +50 % (`GOO_HOP_BONUS`, Rainette) ; couteaux plantés → recharge de l'Éventail (`KNIFE_REFUND_S`, Rictus) | Ardent (Cendres ignorées par Nova et Brasier), Tocsin (Bras-pilier ignoré par la Tête et le Coup), Averse (Flaque ignorée par la Vague) |
| P2 | **Ressource construite par un sort, dépensée par un autre** | Une jauge que l'auto ou un sort remplit et que les sorts 2-4 vident, avec un seuil d'ultime. | Aiguisage (Taliant) ; Eau (Averse) ; Bourse (Avare) ; Tension (Vigie : le Filet la remplit, l'Allonge la vide) ; masse (Bourbe) ; Surchauffe (Tocsin : membres absents → cadence de l'auto) | Ardent, Rictus, Rainette (plus de souffle depuis le 26/10) |
| P3 | **Marque ou statut appliqué puis « détoné »** | Un sort pose un statut lisible (`imprisoned`, `slow` trempe, `vigie_expose`, marque de Rançon, étourdissement) ; un second sort inflige plus ou autre chose aux porteurs. | Tête-fumigène +50 % sur les étourdis par son entrée (`FUMI_PRISONER_BONUS`) ; Tête-cloche +30 % sur les boss (`HEAD_BOSS_ADD`) ; Fusée → exposés +10 % (toutes sources) | Averse (trempe = ralentissement seul), Avare (la marque ne change que l'or), Rainette (étourdissement du Grand saut non exploité), Vigie (l'exposition est faible et sans détonation) |
| P4 | **Ordre de lancer qui change l'effet** | A puis B ≠ B puis A, les deux ordres étant utiles. | Tendeur / Halage ; Aiguisage / Lames jumelles ; Doublures / Toupie (l'étoile, Rictus) ; Filet / Allonge (Vigie) | Ardent, Averse (Crue après Vague = même chose qu'avant), Bourbe (Rappel / Bourbier indépendants) |
| P5 | **Positionnement relatif à un objet du kit** | Le joueur gagne à se tenir près ou loin de son objet (piquet, flaque, pilier, doublures, mottes). | Piquet arraché à 10 u ; Averse +2,5 d'eau/s dans sa Flaque (`PUDDLE_GAIN_PER_S`) ; Main du Montreur garde seulement à ≤ 1,5 u (`MAIN_GUARD_U`) | Tocsin (rien ne récompense de combattre près du pilier), Bourbe (les mottes sont des alliés, pas une position), Rictus (la Levée ignore les doublures) |

**Règle de conception retenue** : chaque combo proposé ci-dessous **réutilise un objet ou un statut qui existe déjà** dans le kit (nommé par sa classe, sa constante ou sa variable), ajoute **au plus un nouvel état** par personnage, et se lit en un retour visuel et un retour sonore. Pas de nouveau bouton, pas de nouvelle jauge (sauf là où une jauge existe déjà), jamais un combo qui exige une visée fine sur mobile.

### 1.4 Boîte à outils déjà dans le code (à réutiliser, pas à réinventer)

| Outil | Fichier | Usage pour les combos |
|---|---|---|
| `Enemy.apply_status(&"imprisoned", {duration, release_pct, release_s})`, `Enemy.is_imprisoned()`, `Enemy.hold_at(p)` | `scripts/enemies/enemy.gd` | Statut tenu au sol : Tendeur, Filet, Geyser, Bulle, Nœud, Tête-fumigène |
| `Enemy.apply_status(&"slow", {pct, duration})`, `Enemy.is_slowed()` | idem | Trempe d'Averse (`SOAK_PCT` 0,30, `SOAK_S` 4 s), ralentissement du Bras-pilier (`PILLAR_SLOW_PCT`), Gluant, Chaîne |
| `Enemy.add_damage_taken_mod(id, mult, duration)`, `has_damage_taken_mod(id)` | idem | Exposition de Vigie (`EXPOSE_ID` &"vigie_expose", ×1,1, 0,35 s rafraîchie). **Un id avec mult 1,0 sert d'étiquette lisible par tout le monde** (pas de nouveau champ sur Enemy) |
| `Enemy.stun(seconds)`, `Enemy.push(offset_px)` | idem | Étourdissement du Grand saut, de la Rançon ; poussées de Tocsin / Averse |
| `SpellCaster.deal_damage(enemy, s, hit)`, signal `spell_hit(spell, enemy, amount)`, hook `kit.on_spell_hit(spell, enemy, amount)` | `scripts/spells/spell_caster.gd` | Point d'entrée unique pour appliquer un bonus de combo (le kit construit un `SpellData` « combo » à coef additionnel et `proc_coef` 0, comme `smoke_bonus_spell` de Tocsin) et pour poser les marques |
| `SpellCaster.spawn_zone(s, pos)`, `ZoneEffect` (`radius`, `duration`, `step`), `SpellCaster.densest_point(range_px)` | idem, `zone_effect.gd` | Zones persistantes (Cendres, Flaque, Grêle, Bourbier) ; ciblage auto S5 |
| Dictionnaire de marques du kit : `marks {instance_id: {t, ref}}`, `is_marked(e)` | `avare_kit.gd` (Rançon) | Modèle à copier pour toute marque courte portée par le kit (pas par Enemy) ; déjà protégé contre le recyclage du pool |
| `_soaked_until {instance_id: fin}` | `averse_kit.gd` | Déjà une marque « trempé » par monstre : à exposer par `is_soaked(e)` |
| `ArdentTracker` | `ardent_tracker.gd` | Suit déjà « qui est dans une Cendres » (compteurs de déblocage) : base d'une marque braise |
| `TocsinLimb.Phase.PILLAR`, `TocsinKit.limbs {clé: TocsinLimb}` | `tocsin_limb.gd`, `tocsin_kit.gd` | Position et rayon (`PILLAR_RADIUS_U` 2,2) des piliers actifs |
| `Decoy.hit_by(pos, r_px)`, `Decoy.nearest_to`, `Decoy.on_explode`, `explode_spell` | `decoy.gd` | Doublures de Rictus, mottes de Bourbe (`BourbeMotte extends Decoy`) |
| `RictusKit.knives: Array` (GroundPickup) | `rictus_kit.gd` | Couteaux plantés (`KNIFE_LIFE_S` 4 s) |
| `RainetteGoo` (flaque, rayon `GOO_RADIUS_U` 2,5) | `rainette_goo.gd` | Test « dans le Gluant » déjà fait pour les bonds (l. 576) |
| `VigieKit.tension`, `set_tension(v)` ; `_expose_tick()` | `vigie_kit.gd` | Ressource et marque de Vigie |
| `MorfilKit.sharpness`, `guard_left`, `edge_strikes`, `_iai_paid` | `morfil_kit.gd` | Ressource, garde, Iaï |
| `kit.auto_cast_ok(slot)` | contrat `game/CONTRACTS.md` | **Aide mobile** : chaque combo déclare sa règle d'auto-cast (ex. « la Tête attend un pilier avec ≥ 4 monstres ») |

**Retour générique de combo (à ajouter une fois, orchestrateur)** : `deal_damage(…, hit = {"combo": true})` → le chiffre de dégâts est affiché dans la couleur d'accent du personnage (`CharacterData` / `ACCENT` du kit) au lieu du blanc, et le son du sort prend la variante « lourde » existante avec +2 demi-tons (règle audio « le son suit la puissance du coup », déjà codée). Un seul son générique supplémentaire par personnage (`spell.<perso>.combo`, Codex `art/tools/audio/`) suffit en v1 ; les VFX cités ci-dessous sont **existants** sauf mention « Codex ».

---

## 2. Les dix personnages

Format de chaque bloc : carte actuelle des interactions (sorts 1-4, passif, roulade) · note d'interactivité /5 (critères : nombre de paires de sorts qui se lisent, ressource commune, ordre signifiant, objet au sol exploité, découvrabilité sans tip) · combos proposés. Pour chaque combo : **Déclencheur** · **Effet** (chiffré) · **Lisibilité** · **Mobile** · **Équilibrage** (gain estimé et compensation) · **Variantes**.

### 2.1 Ardent, mage de feu (`ardent_kit.gd`, `ardent_variant_kit.gd`, `ardent_tracker.gd`)

**Carte actuelle.** Éclat de braise (auto, 0,8 / 0,6 s, perce 1) · Nova ardente (`NOVA_COEF` 2,5 / 6 s, r 3,5) · Cendres (0,5 par 0,5 s pendant 5 s / 8 s, r 2,5, proc 0,3) · Brasier (`BRASIER_COEF` 8 / 20 s, r 6). Aucune lecture croisée : la Nova ne sait pas qu'une Cendres brûle, le Brasier non plus. Pas de passif. Roulade standard (blink « Éclat de braise » prévu, `docs/Roulades_Personnages.md` §3.1 : braise de départ coef 0,4 à 1 u). Les variantes (Braises errantes, Pilier, Pluie de météores, Phénix) sont elles aussi indépendantes. C'est voulu (personnage débutant 1/5), mais le roster n'a pas besoin que le débutant soit **sans** combo : il a besoin qu'il soit sans **gestion**.
**Note : 1/5.**

**Nouvel état unique : la marque « braise »** (dictionnaire `marks` dans un nœud kit d'Ardent, modèle `AvareKit.marks` ; durée 1,5 s, rafraîchie). Posée par : chaque tick de Cendres sur un monstre (déjà suivi par `ArdentTracker`), chaque impact de Pluie de météores, chaque piqué du Phénix, la braise de départ du blink. Visuel : braises qui montent du monstre (VFX `ardent_ashes` existant à l'échelle 0,4 u, 1 particule), aucun rendu nouveau.

- **A1 « Nova qui attise »** (P3, P1)
  - Déclencheur : Nova ardente (ou Pilier de flamme) qui frappe un monstre marqué braise.
  - Effet : **+40 %** sur les marqués (coef 2,5 → 3,5 sur eux) ; la Cendres qui a posé la marque **gagne 1 s** de durée (une fois par Cendres). La marque est consommée.
  - Lisibilité : la zone Cendres pulse (modulate HDR ×1,6 pendant 0,3 s, `ZoneEffect.vfx`), chiffres en couleur d'accent, son Nova « lourd ».
  - Mobile : la Nova est à déclenchement automatique à 3 u (`trigger_range_u` 3) et les Cendres se posent sur le paquet le plus dense à 7 u ; le combo se produit quand Ardent recule vers sa Cendres ou que le paquet en sort vers lui. Aide : `auto_cast_ok(2)` retarde la Nova de 0,5 s au plus si ≥ 2 monstres marqués sont à 3,5 u et pas encore dans son rayon.
  - Équilibrage : taux de Nova sur marqués estimé 50 % en zone, 30 % sur boss ; compensation `NOVA_COEF` 2,5 → **2,2** (moyenne zone 2,2 × (1 + 0,4 × 0,5) = 2,64 ≈ +6 % ; boss 2,2 × 1,12 = 2,46 ≈ −2 %).
  - Variantes : Pilier de flamme (remplace la Nova) : ses ticks (0,25) font **+40 %** sur les marqués et consomment la marque au premier tick ; Pluie de météores (remplace Cendres) : chaque impact pose la marque (pas de +1 s, rien ne dure) ; Braises errantes : les orbes ne posent pas de marque (elles ne sont pas une zone), mais la détonent comme la Nova : non (une seule source de détonation par slot) : les orbes **prolongent** la marque de 0,5 s à chaque touche.
- **A2 « Brasier sur braises »** (P3)
  - Déclencheur : Brasier (ou explosion finale du Phénix, `phoenix_burst_spell`) qui touche des marqués.
  - Effet : **+1,0 coef par monstre marqué** (8 → 9 sur lui), marque consommée ; toute Cendres active dans le rayon de 6 u s'éteint en une **flambée** instantanée coef 2,0 dans son rayon 2,5 u (proc 1,0).
  - Lisibilité : la Cendres se contracte puis éclate (anim `end` de `ardent_ashes` jouée ×2 de vitesse + `ardent_nova` à l'échelle 2,5 u), son Brasier « lourd ».
  - Mobile : Brasier auto autour de lui, Cendres sur le paquet dense : combo naturel quand il se bat sur sa Cendres (ce que le patron A1 encourage déjà).
  - Équilibrage : +1,0 sur 60 % des cibles et +2,0 sur une Cendres en zone (≈ +2 par lancer en zone 5) ; compensation `BRASIER_COEF` 8 → **7,2** (boss : 7,2 + 1,0 × 0,5 = 7,7 ≈ −4 % ; zone 5 : 36 + 3 + 10 = 49 vs 40 ≈ +22 %, acceptable : l'ultime d'Ardent est aujourd'hui le plus faible en zone, et le gain exige une Cendres bien placée).
  - Variantes : Phénix : son explosion finale détone ; Pluie de météores : pas de flambée (rien au sol), le +1,0 par marqué reste.
- **A3 « Éclat qui ravive »** (P3, léger)
  - Déclencheur : Éclat de braise (auto) qui touche un marqué.
  - Effet : la marque est **prolongée de 0,6 s** (plafond 3 s) et l'éclat **perce +1** (il traverse le brûlant). Pas de dégâts en plus.
  - Lisibilité : le projectile prend une traînée plus longue (modulate), rien d'autre.
  - Mobile : automatique.
  - Équilibrage : aucun (contrôle du tempo de la marque) ; permet d'enchaîner Cendres → marque tenue → Nova sans être collé à la zone.
  - Variantes : Braises errantes : idem par touche d'orbe (déjà dit en A1).

Contrat à signaler : **Ardent de base n'a pas de nœud kit** (`ArdentVariantKit` n'existe qu'avec une variante). Le lot Ardent crée `ArdentBaseKit` (ou promeut `ArdentTracker` en kit) : décision orchestrateur, voir §3.

### 2.2 Rictus, pantin de la barge noyée (`rictus_kit.gd`, `decoy.gd`, `rictus_pendulum.gd`)

**Carte actuelle.** Dagues en demi-lune (auto `ARC_COEF` 0,8, r 2,5, garde `GUARD_TAKEN_MULT` 0,7 pendant `GUARD_S` 0,3 s) · Éventail (`FAN_COEF` 1,35 × 5, couteaux plantés `KNIFE_LIFE_S` 4 s, ramassés = `KNIFE_REFUND_S` 1 s de recharge, plafond 5 s) · Toupie (`TOUPIE_COEF` 0,42 / 0,25 s pendant 2,5 s + pointe `TOUPIE_FOCUS_COEF` 0,15 sur le plus proche, expédie les doublures) · Les Doublures (6 × `DECOY_COEF` 2,4, r `DECOY_BURST_U` 2,4, vol `FLIGHT_COEF` 1,2). Interactions existantes : **l'étoile** (Doublures puis Toupie, P4, le meilleur combo du roster après Arpenteuse), couteaux → recharge (P1, boucle sur un seul sort), Éventail lançable pendant la Toupie, fils tendus +2 % PV. La Levée (roulade) et les couteaux ignorent les doublures ; la Toupie ignore les couteaux.
**Note : 3/5.**

- **R1 « Doublures armées »** (P1, P4)
  - Déclencheur : un couteau de l'Éventail (ou la Lame-pendule) **traverse une doublure** vivante (`Decoy.hit_by` sur la trajectoire, une charge par doublure, le couteau continue).
  - Effet : la doublure est **chargée** : son explosion passe de 2,4 à **3,1** (+0,7), et si elle est expédiée par la Toupie son vol fait 1,2 → **1,6**. Les doublures sont sur un anneau de 1,2 u et le cône de l'Éventail fait 60° : 2-3 doublures chargées par salve.
  - Lisibilité : fissures `_e` de la doublure allumées en argent spectral (le shader désaturé des doublures a déjà un `_e` inversé ; paramètre `charged` 0-1), grelot à la charge, explosion avec le son « lourd ».
  - Mobile : les Doublures se posent autour de Rictus, l'Éventail auto vise le paquet le plus dense : les couteaux partent du centre de l'anneau et traversent **toujours** 1-2 doublures. Naturel.
  - Équilibrage : +0,7 × 2,5 doublures ≈ +1,75 par ultime (14,4 → 16,2, +12 %) quand l'Éventail est prêt ; compensation `DECOY_COEF` 2,4 → **2,2** (sans combo : 13,2, −8 % ; avec : 14,9, +4 %). Les doublures tuées (60 %) gardent la charge.
  - Variantes : Rideau (ligne à 2 u devant, perpendiculaire à la visée) : les couteaux visent devant, ils traversent le rideau : fonctionne ; Lame-pendule : charge à l'aller **et** au retour, une charge par doublure au plus ; Pirouette : expédie les chargées comme la Toupie.
- **R2 « Toupie qui ramasse »** (P1, P5)
  - Déclencheur : la Toupie dérive sur un couteau planté (`knives`, contact `KNIFE_CONTACT_U` 0,6 u → déjà ramassé par le contact).
  - Effet : en plus du remboursement de 1 s, chaque couteau ramassé **pendant** la Toupie la **prolonge de 0,25 s** (un tick, plafond +1,25 s) et le couteau **repart** en projectile coef 1,35 vers le monstre le plus proche (perce 1, pas de nouveau plantage).
  - Lisibilité : le couteau planté se relève et file (sprite `knife` existant), un tick de `spin_blur` plus clair.
  - Mobile : la Toupie se dirige au joystick ; les couteaux sont plantés à 7 u (fin de course) ou contre un mur ; le joueur choisit d'y dériver. Pas d'aide nécessaire : c'est un choix de déplacement, pas de visée.
  - Équilibrage : +1,35 et +1 tick (0,42 + 0,15) par couteau, 1-3 couteaux par Toupie ≈ +2-5 par 8 s (+0,25-0,6/s, soit +8-20 % du DPS zone) ; compensation `TOUPIE_COEF` 0,42 → **0,38** (−0,16/s) et `FAN_COEF` 1,35 → **1,25**.
  - Variantes : Pirouette (0,6 s, immobile) : ramasse les couteaux à 2,2 u à l'impact (relance, pas de prolongation) ; Lame-pendule : aucun couteau planté, R2 sans objet (la Pirouette / Toupie gardent R1 et R3).
- **R3 « Levée sur les doublures »** (P5, P4)
  - Déclencheur : la Levée (roulade) **atterrit** à ≤ 2,4 u d'une ou plusieurs doublures en attente (pas encore expédiées).
  - Effet : elles explosent **immédiatement** (coef inchangé, charges R1 comprises) : le joueur choisit le moment au lieu d'attendre les 3 s ; l'invulnérabilité de la Levée couvre l'explosion.
  - Lisibilité : les fils vibrent (`StringRig`, `STRING_VIBRATE_S` 0,2), claquement de talons, six explosions synchrones.
  - Mobile : bouton Roulade + joystick ; les doublures sont autour de lui : la Levée atterrit toujours à ≤ 3 u d'elles si le joueur ne fuit pas. Naturel.
  - Équilibrage : aucun gain de dégâts (anticipation) ; perte de 0-3 s de provocation. Pas de compensation.
  - Variantes : Rideau : idem (le rideau explose à la Levée).

### 2.3 Tocsin, automate de crue (`tocsin_kit.gd`, `tocsin_limb.gd`)

**Carte actuelle (kit du 23/10).** Rivets rougis (auto 0,8 / 0,6 s, perce 1, **Surchauffe** +12 % de cadence par membre absent, `OVERHEAT_PER_LIMB`) · Bras-pilier (2 charges / 8 s, lob 7 u, zone `PILLAR_RADIUS_U` 2,2 u, `PILLAR_COEF` 0,75 × 10 ticks de 0,5 s, ralentissement `PILLAR_SLOW_PCT` 0,25, puis bras au sol : contact = charge rendue tout de suite) · Coup de tocsin (`TOLL_COEF` 2,5, r 3 autour de lui, poussée 2,5 u × masse) · Tête-cloche (`HEAD_COEF` 10, r 4, +30 % sur les boss). Interactions : Surchauffe (P2, bonne), ramassage (P5, trop fort selon l'audit P7). **Depuis le retrait du Bras-grappin, plus rien ne lit l'état `imprisoned`** : le +50 % de la Tête sur les prisonniers n'a plus de source dans le kit de base. Le Bras-pilier est un objet au sol parfait (P1) que ni la Tête ni le Coup ne regardent.
**Note : 2/5.**

**Nouvel état : la marque « électrisé »** : chaque tick de pilier pose `add_damage_taken_mod(&"tocsin_charge", 1.0, 0.6)` (étiquette sans effet propre, rafraîchie 0,6 s ; lisible par `has_damage_taken_mod`). Visuel : l'arc du pilier (`pillar_arc.png`, déjà livré) est déjà sur eux.

- **T1 « La cloche sur le pilier »** (P1, P3, P5)
  - Déclencheur : Tête-cloche qui explose à ≤ 4 u (son rayon) du centre d'un Bras-pilier en décharge (`TocsinLimb.Phase.PILLAR`).
  - Effet : **+50 %** sur les électrisés (10 → 15, se cumule additivement avec +30 % boss : 18 sur un boss électrisé) ; le pilier **sonne** : ses ticks restants partent en une seule décharge (0,75 × ticks restants, plafond 5,0, proc 0,25) et le bras tombe au sol, ramassable. Reprend la constante `FUMI_PRISONER_BONUS` et la mécanique `smoke_bonus_spell` déjà codée pour la Tête-fumigène.
  - Lisibilité : `pillar_arc` flashe blanc 0,2 s puis s'éteint, lumière `tocsin_blast` ×1,5, tintement + crépitement (son de la décharge existant, variante lourde).
  - Mobile : les deux sorts visent le paquet le plus dense (S5) : la Tête tombe sur le pilier dès que le paquet y est. Aide : `auto_cast_ok(4)` : la Tête part si ≥ 4 points de monstres sont dans le rayon **ou** si un pilier avec ≥ 2 monstres est à portée.
  - Équilibrage : +5 sur les cibles électrisées (≈ 60 % en zone, 70 % sur un boss immobile) et jusqu'à +5 de décharge ; compensation `HEAD_COEF` 10 → **8,5** (boss sans pilier : 8,5 × 1,3 = 11 ; avec : 8,5 × 1,8 = 15,3 + décharge ; moyenne pondérée ≈ 13 vs 13 aujourd'hui). Le ramassage immédiat du bras rendu par T1 est bridé par la règle P7 de l'audit (recharge restante ×0,5 au ramassage) : à implémenter dans le même lot.
  - Variantes : Tête-fumigène : la fumée posée sur un pilier applique `FUMI_PRISONER_BONUS` aussi aux électrisés (déjà le même +50 %) et le pilier n'est pas vidé (la fumée dure 5 s, le pilier aussi) ; Vapeur : sans effet (slot 1).
- **T2 « Le Coup qui fait sonner le pilier »** (P5, P1)
  - Déclencheur : Coup de tocsin (onde 3 u) dont le rayon atteint un pilier en décharge **ou** un bras au sol.
  - Effet : chaque pilier touché émet **une décharge supplémentaire immédiate coef 1,5** dans ses 2,2 u (proc 0,25) et **gagne 2 ticks** (+1 s) ; un bras au sol (pas en décharge) se **redresse en pilier** pour 4 ticks (2 s) sans recharge supplémentaire.
  - Lisibilité : onde de choc qui « rebondit » sur le pilier (second anneau depuis le pilier, `ZoneEffect` repli), cloche grave.
  - Mobile : Tocsin lance le bras à 7 u puis avance ; le Coup est autour de lui : il faut être à ≤ 3 u du pilier. Aide : `auto_cast_ok(3)` préfère le moment où un pilier est dans l'onde (sinon règle actuelle).
  - Équilibrage : +1,5 (+ 2 ticks = +1,5) par Coup sur pilier ≈ +3 par 7 s en zone (+0,43/s) ; compensation `TOLL_COEF` 2,5 → **2,2** (−0,04/s en mono, −0,2/s en zone 5) et `PILLAR_COEF` 0,75 → **0,7**.
  - Variantes : aucune ne remplace les slots 2-3 (Bras-harpon et Jambes-ressorts retirés) : T2 vaut pour toutes.
- **T3 « Surchauffe qui décharge »** (P2)
  - Déclencheur : Rivets tirés avec **3 membres absents** (2 bras + tête, Surchauffe +36 %).
  - Effet : un rivet sur un électrisé **saute** vers l'électrisé le plus proche à 2 u (chaîne de 1 saut, coef 0,8, proc 0,5) : la décharge voyage par les rivets.
  - Lisibilité : petit arc entre les deux monstres (texture de `pillar_arc` étirée en `Line2D` 0,1 s), clac aigu.
  - Mobile : automatique.
  - Équilibrage : +0,8 × 0,5 (proba d'un second électrisé) ≈ +0,4 par rivet pendant les fenêtres « tout lancé » (≈ 25 % du temps en zone) ≈ +0,15/s ; compensation : aucune au-delà de T1/T2 (le gain récompense le mode « tout lancé » qui coûte 3 membres).
  - Variantes : Vapeur (cône 3 u) : la vapeur sur un électrisé le ralentit 0,2 → 0,4 (pas de saut) : équivalent de contrôle.

### 2.4 Averse, porteuse de pluie (`averse_kit.gd`, `averse_rivulet.gd`, `averse_geyser_fx.gd`)

**Carte actuelle.** Eau 0-100 (P2 : Goutte +0,5 par touche `HIT_WATER`, +1,0 sur élite / boss `BIG_HIT_WATER`, kill +0,9, pluie 2,5/s × carte, Flaque +2,5/s `PUDDLE_GAIN_PER_S`, eau de carte +7/s) · Vague (`WAVE_COST` 20, cône 6 u / 70°, 3,5, trempe) · Flaque-miroir (18, `PUDDLE_CD` 5 s, r 3, 0,45 / 0,5 s pendant 6 s, trempe) · Crue (toute l'eau ≥ 40, `CRUE_CD` 12 s, `CRUE_COEF_FULL` 9 × (eau/100)^1,2, r 5 + 0,02/eau, laisse une Flaque). La ressource est excellente (P2), la Crue laisse une Flaque (P1 faible : rien ne lit la Flaque sauf Averse elle-même), la **trempe** (`_soak`, clé `slow` 30 % 4 s, dictionnaire `_soaked_until`) est posée par trois sorts et **lue par aucun** (P3 absent). Rien ne récompense un ordre (P4).
**Note : 3/5** (toute la note vient de l'eau).

**État réutilisé : « trempé »** = `_soaked_until[id] > _kit_clock`, exposé par `AverseKit.is_soaked(e)`.

- **AV1 « Goutte sur corps mouillé »** (P3, P2)
  - Déclencheur : Goutte-lame (auto) qui touche un trempé.
  - Effet : **+1,0 d'eau** en plus (0,5 → 1,5 par touche ; élite / boss trempé : 1,0 → 2,0) et **coef +0,25** sur le trempé (la lame glisse dans l'eau).
  - Lisibilité : « +N » cyan existant (plus gros), impact avec éclaboussure (`mud_splash` teinté cyan en repli ; Codex : `splash_small` TOP 4).
  - Mobile : automatique après n'importe quelle Vague / Flaque / Crue.
  - Équilibrage : l'eau sur boss remonte (l'audit l'avait baissée de 2 à 1) : compensation `HIT_WATER` 0,5 → **0,4**, `GOUTTE_COEF_MIN` 0,75 → **0,7**. Sur un boss trempé en permanence (Crue toutes les 12 s + Vagues) : eau par Goutte 2,0 comme avant l'audit, mais seulement si Averse paie 20 d'eau toutes les 4 s pour le garder trempé : le cycle est neutre (−20 / 4 s, +1,5 × 1,67/s × 4 s = +10 ; la Vague reste un investissement).
  - Variantes : Bruine : +0,33 d'eau par goutte sur trempé, plafond de salve `BRUINE_VOLLEY_WATER_CAP` 1,0 → 2,0 ; Geyser / Gouttière / Mousson trempent toutes : compatibles.
- **AV2 « Crue qui emporte »** (P3, P4)
  - Déclencheur : Crue (ou Mousson) sur des trempés.
  - Effet : **+20 %** sur les trempés et recul 3 → **4,5 u × masse** (ils sont emportés ; boss : +20 % seulement). L'ordre Vague → Crue devient le bon ordre ; Crue → Vague reste valable pour la trempe suivante (AV1).
  - Lisibilité : anneau de Crue plus brillant sur son passage (`CRUE_VFX_TINT` ×1,2), chiffres en accent, grondement lourd.
  - Mobile : la Vague auto vise le paquet dense, la Crue est autour d'elle : naturel dès que le paquet approche. Aide : `auto_cast_ok(4)` attend 0,5 s au plus si une Vague vient d'être lancée (ses trempés arrivent).
  - Équilibrage : trempés estimés 70 % en zone, 90 % sur boss (AV1 incite à tremper) ; compensation `CRUE_COEF_FULL` 9 → **8,2** (boss : 8,2 × 1,2 × 0,9 + 8,2 × 0,1 = 9,7, +8 % ; zone : +5 %). Retour joueur « la Crue tape énormément » : rester sous +8 % sur boss ; levier 8,0 si le simulateur dépasse.
  - Variantes : Mousson (zone attachée 6 s) : ses ticks font +20 % sur les trempés ; le premier tick trempe, les suivants profitent : la Mousson lance donc AV2 d'elle-même après 0,5 s, c'est acceptable (ses dégâts totaux sont étalés) ; Geyser (remplace la Vague) : la projection 0,8 s + trempe prépare la Crue de la même façon.
- **AV3 « Vague de fond »** (P1, P5)
  - Déclencheur : le cône de la Vague **traverse une Flaque-miroir** (centre de la flaque dans le cône) ou Averse lance la Vague **depuis** sa Flaque.
  - Effet : les monstres touchés sont trempés **8 s / −40 %** (au lieu de 4 s / −30 %) et prennent **+0,5 coef** ; la Flaque **n'est pas consommée** (elle pulse).
  - Lisibilité : `puddle_mirror` grossit 15 % pendant 0,3 s, vague au son plus grave.
  - Mobile : la Flaque est posée sur le paquet dense, la Vague vise le paquet dense : le cône traverse la flaque dans la majorité des cas. Naturel.
  - Équilibrage : +0,5 sur ≈ 50 % des Vagues ; compensation `WAVE_COEF` 3,5 → **3,3**.
  - Variantes : Gouttière (ligne 6 u depuis Averse) : Vague lancée dans l'axe de la Gouttière (angle ≤ 35°) : même bonus ; Geyser sur Flaque : projection 0,8 → 1,2 s et trempe 8 s.

### 2.5 Arpenteuse, géomètre de la Cité (`arpenteuse_kit.gd`)

**Carte actuelle.** Voir §1.1. Chaîne → Halage (bande le long de toute la chaîne) → Piquet (ligne lue par Halage et Tendeur) → Tendeur (traîne et emprisonne, chaîne et piquet conservés). +25 % élites / boss sur les sorts 2-4 (`BIG_TARGET_ADD`). Variantes cohérentes (Nœud consomme 4 u, Jalons = ligne A-B lue par le Tendeur, Cerceau rend la chaîne pleine). Roulade : Trait tendu prévu (3 u de chaîne d'un coup, ralentissement 50 % 1,5 s sur le segment, `docs/Roulades_Personnages.md` §3.5).
**Note : 5/5.** Référence. Aucun combo nouveau nécessaire ; un seul ajout facultatif, déjà cohérent avec le Trait tendu :

- **AR1 « Halage sur emprisonnés »** (P3, facultatif, lot bas)
  - Déclencheur : Halage dont la bande touche des monstres encore emprisonnés par le Tendeur (`is_imprisoned()`, fenêtre 1,5 s).
  - Effet : attraction 1,5 u → **0** (ils sont tenus) mais **+0,5 coef** (3,5 → 4,0 sur eux) : l'ordre Tendeur → Halage, déjà le plus fort, devient lisible par un chiffre.
  - Lisibilité : chiffres en accent, chaîne qui mord (`HEAT_FLASH_ENERGY` 4,5 déjà existant).
  - Mobile : les deux sorts sont sans visée (la chaîne est sous elle). Naturel.
  - Équilibrage : +0,5 une fois par 20 s sur ≤ 6 monstres : négligeable (< 2 %) ; pas de compensation. Ne touche pas la cible élite 1,30 (le +25 % reste additif : 4,0 + 0,25 × 3,5).
  - Variantes : Nœud (`NOEUD_PRISON_S` 1 s) : le Nœud sur des emprisonnés du Tendeur prolonge la prison de 0,5 s ; Cerceau : sans objet (pas de Tendeur).

### 2.6 Rainette, chevalière des roseaux (`rainette_kit.gd`, `rainette_goo.gd`, `rainette_bubble.gd`)

**Carte actuelle (refonte du 26/10, plus de souffle).** Langue (auto `TONGUE_COEF` 1,15 sur la cible principale, `TONGUE_LINE_COEF` 0,9 sur la ligne, traction 0,25 u, T1 tué avalé +1 % PV) · Grand saut (`LEAP_COEF` 3,8 / 7 s, r 3, `LEAP_STUN_S` 0,5, invulnérable 0,35 s) · Gluant (`GOO_SPLASH_COEF` 1,4, flaque 2,5 u / 5 s, −40 %, attraction 0,9 u/s, bonds +50 % depuis la flaque `GOO_HOP_BONUS`) · Chant de crue (4 s, bonds ×2, atterrissages `ULT_LAND_COEF` 2,8 dans 3 u). Interactions : Gluant → bonds (P1, bonne mais elle ne concerne que la locomotion) ; Grand saut pendant le Chant = deux impacts (audit P5 : à ramener à un seul) ; l'étourdissement du Grand saut n'est lu par rien ; la flaque n'est lue par aucun impact.
**Note : 2/5.**

**État réutilisé : « collé »** = monstre dans une `RainetteGoo` (test déjà fait pour les bonds, l. 576) ; **« étourdi »** = `Enemy.is_stunned()` (à ajouter : `_stop_left > 0`, contrat orchestrateur).

- **RN1 « Écrasement »** (P1, P3, P4)
  - Déclencheur : atterrissage d'un Grand saut (ou d'un Ricochet, ou d'un atterrissage de Chant) **dans** une flaque de Gluant.
  - Effet : **+30 %** sur les collés (3,8 → 4,9), étourdissement 0,5 → **1,0 s** ; la flaque **éclate** (consommée) : éclaboussure coef 1,4 (`GOO_SPLASH_COEF`) dans 2,5 u. L'ordre Gluant → Grand saut (burst) et Grand saut → Gluant (paquet étourdi qui se colle) sont tous deux utiles.
  - Lisibilité : `goo` joue son `end` ×2 de vitesse + `land_ring` à 1,2 d'échelle, « splotch » lourd (Codex : `goo_burst` TOP 6 si l'on veut mieux que l'`end`).
  - Mobile : Gluant et Grand saut visent tous deux le paquet le plus dense à 6 u : **le combo est le cas par défaut** sur mobile. Aide : `auto_cast_ok(2)` attend que le Gluant soit posé si sa recharge est < 1 s.
  - Équilibrage : combo réalisé ≈ 60 % des Grands sauts ; compensation `LEAP_COEF` 3,8 → **3,4** et `GOO_SPLASH_COEF` 1,4 → **1,2** (moyenne : 3,4 × (1 + 0,3 × 0,6) + 1,2 × 0,6 = 4,0 + 0,7 = 4,7 par 7 s contre 3,8 + 1,2 = 5,0 aujourd'hui sur 7-8 s : neutre ; le gain est dans le burst et le contrôle, pas dans le DPS). Audit P5 (Grand saut pendant le Chant = un seul impact) appliqué dans le même lot.
  - Variantes : Bulle (remplace le Gluant, soulève 1,5 s) : un atterrissage sur des monstres en l'air les **fait tomber** : éclatement anticipé + 30 % ; Ricochet : seul le second bond écrase (le premier prépare) ; Chœur (mini-flaques 1,5 u) : +15 % et la mini-flaque n'est pas consommée (10 flaques, trop de VFX sinon).
- **RN2 « Langue sur étourdi »** (P3)
  - Déclencheur : Langue dont la cible principale est **étourdie** (Grand saut, Rançon-like) ou **collée**.
  - Effet : coef principal 1,15 → **1,6** (coup de grâce), traction 0,25 → **0,75 u** (elle ramène le paquet collé vers elle ; attraction du Gluant conservée).
  - Lisibilité : langue plus épaisse (`tongue` échelle Y ×1,3), son claquant.
  - Mobile : automatique.
  - Équilibrage : 1 Langue par Grand saut (fenêtre 0,5-1,0 s) et 2-3 par Gluant : +0,45 × 3 par 8 s ≈ +0,17/s (+7 % mono) ; compensation `TONGUE_COEF` 1,15 → **1,1**.
  - Variantes : Croassement (anneau 2,5 u) : +0,3 sur les étourdis / collés dans l'anneau (même esprit, zone) ; Bulle : les monstres en l'air comptent comme étourdis.
- **RN3 « Chant dans la vase »** (P1, P2)
  - Déclencheur : pendant le Chant de crue, atterrissage dans une flaque de Gluant **non consommée** (le Chant ne consomme pas : règle RN1 limitée au Grand saut et au Ricochet).
  - Effet : **+1 s de Chant** par flaque touchée (plafond +2 s, soit 6 s) et bonds ×2 → ×2,5 depuis la flaque (le ×1,5 du Gluant remplacé par ce +0,5).
  - Lisibilité : sac vocal `_e` qui pulse plus vite, `land_ring` jade.
  - Mobile : automatique (elle bondit au joystick).
  - Équilibrage : +1 atterrissage par seconde gagnée (2,8 × 2 au plus = +5,6 par ultime, +17 %, seulement si deux flaques sont posées sous un Chant) ; compensation `ULT_LAND_COEF` 2,8 → **2,6**.
  - Variantes : Chœur (8 s, mini-flaques) : sans objet (il pose ses propres flaques) ; Bulle : +1 s si un atterrissage de Chant fait tomber une Bulle.

### 2.7 Avare, usurier des Terrasses (`avare_kit.gd`, `avare_bounce_coin.gd`)

**Carte actuelle.** Bourse (P2 : `GOLD_POWER_PER_P` 0,15 / P, plafond `GOLD_POWER_CAP` 0,30) · Coup de coffre (auto `SWING_COEF` 0,8, arc 150° r 2,6, coffre-bouclier `GUARD_TAKEN_MULT` 0,55 pendant 0,4 s) · Poignée de pièces (5 × 1,2, coûte max(2 % or, 0,1 P), pièces au sol 80 %) · Rançon (`RANSOM_COEF` 1,8, r 3, étourdit 0,5 s, **marque** `RANSOM_MARK_S` 4 s : +50 % d'or à la mort) · Faillite (`RUIN_BASE_COEF` 5 + 3,5 × min(1, dépensé / 4 P), 50 % de l'or, 50 % retombe). Interactions : la bourse nourrit tout (P2), les pièces retombent (P1 vers la roulade Râfle prévue), la marque de Rançon n'est lue **que par l'or** (P3 absent côté dégâts). Rien ne lit l'étourdissement de la Rançon ; rien ne relie Poignée et Rançon.
**Note : 3/5.**

**État réutilisé : « marqué »** = `AvareKit.is_marked(e)` (dictionnaire `marks`, déjà protégé contre le recyclage du pool).

- **AVR1 « Pièce qui encaisse »** (P3, P4)
  - Déclencheur : une pièce de la Poignée (ou la Pièce truquée) touche un marqué.
  - Effet : coef 1,2 → **1,8** sur lui, et la pièce retombe à **100 %** de sa part du coût au lieu de 80 % (le marqué « rembourse »). L'ordre Rançon → Poignée paie ; Poignée → Rançon reste utile (étourdir le paquet qui a ramassé les pièces... c'est-à-dire le paquet où elles sont tombées).
  - Lisibilité : pièce qui tinte en accent or, « ting » montant (son de rebond existant de la Pièce truquée).
  - Mobile : Rançon autour de lui (3 u), Poignée vers le paquet dense à 6 u : naturel au contact. Aide : `auto_cast_ok(2)` lance la Poignée en priorité dans les 4 s qui suivent une Rançon.
  - Équilibrage : +0,6 × 2,5 pièces sur marqués ≈ +1,5 par 5 s après chaque Rançon (9 s) ≈ +0,17/s (+6 % mono) ; compensation `COINS_COEF` 1,2 → **1,1**. Économie : le 100 % ne crée pas d'or (les pièces rendent la valeur exacte, règle d'équité conservée).
  - Variantes : Pièce truquée : ses rebonds **préfèrent** les marqués non touchés (ordre de choix : marqué à ≤ 3 u, sinon le plus proche) et chacun fait 1,5 → 2,1 ; Saisie (remplace la Rançon) : marque aussi : compatible.
- **AVR2 « Faillite des marqués »** (P3)
  - Déclencheur : Faillite (ou Trésor enterré) qui touche des marqués.
  - Effet : **+1,0 coef** sur chaque marqué (5 → 6 sur lui) ; **pas d'or neuf supplémentaire** (la prime +50 % de la marque reste la seule source d'or neuf, `economy_test` inchangé).
  - Lisibilité : `coin_burst` ×1,2 sur les marqués, chiffres en accent.
  - Mobile : Rançon (autour, étourdit 0,5 s) puis Faillite (autour) : naturel, l'étourdissement tient le paquet.
  - Équilibrage : +1,0 sur ≈ 70 % des cibles d'une Faillite lancée dans les 4 s d'une Rançon ; compensation `RUIN_BASE_COEF` 5 → **4,6** (zone 5 : 23 + 3,5 = 26,5 vs 25 ; boss marqué : 4,6 + 1,0 = 5,6 vs 5, +12 % mais ≈ 1 fois par 25 s : +0,02/s).
  - Variantes : Trésor enterré : la détonation applique le +1,0 ; la marque est rafraîchie de 2 s si le marqué survit (il doit encore payer).
- **AVR3 « Coffre qui prolonge »** (P3, léger)
  - Déclencheur : Coup de coffre (auto) sur un marqué.
  - Effet : marque **+0,5 s** par coup (plafond 6 s) ; coffre-bouclier 0,4 → **0,6 s** après un coup sur marqué.
  - Lisibilité : sceau de Rançon (`ransom_ring`) qui re-pulse sous le marqué.
  - Mobile : automatique.
  - Équilibrage : défense +50 % de couverture au contact d'un marqué (l'audit avait réduit `GUARD_S` 0,6 → 0,4 : ici 0,6 seulement sur marqués, c'est-à-dire ≈ 30 % du temps) ; pas de compensation.
  - Variantes : Coffre-bélier (ligne 3,5 u, `RAM_GUARD_S` 0,8) : marque +0,5 s, bouclier inchangé (déjà long).

### 2.8 Bourbe, mère-vase de la Mangrove (`bourbe_kit.gd`, `bourbe_motte.gd`)

**Carte actuelle (modèle « masse » du 23/10).** Gifle de vase (auto `SLAP_COEF` 1,0, arc 210° r 2,6, vase compacte −30 % subis sans motte) · Détacher (4 charges / 3 s, `MASS_PER_MOTTE` 15 % des PV max tant que la motte est dehors, motte `MOTTE_CONTACT_COEF` 0,40 / 0,8 s, plouf `MOTTE_LAND_COEF` 1,4 dans 2 u, provoque 4 u sauf boss) · Rappel (`RECALL_COEF` 1,5 par monstre traversé) · Bourbier (`BOG_COEF` 1,2 / 0,5 s pendant 4 s, r 5, −50 %, mottes fusionnées, `RISE_FREE_MOTTES` 2 à la sortie). Interactions : masse (P2, forte), Rappel consomme les mottes (P4 : Rappel après Détacher), Bourbier fusionne (P4). Les mottes sont des alliés que **la Gifle ignore** (P5 absent) ; le Bourbier ignore où sont les mottes ; le Rappel ignore le ralentissement du Bourbier.
**Note : 3/5.**

- **B1 « Gifle transmise »** (P5, P1)
  - Déclencheur : la Gifle de vase **passe sur une motte alliée** (`BourbeMotte` dans l'arc, une fois par motte toutes les 2 s).
  - Effet : la motte regagne **10 % de ses PV** et son prochain coup de contact fait **×3** (0,40 → 1,2, proc 0,5 → 1,0) : « la mère pousse la motte ». Combattre **au milieu** de ses mottes devient le bon placement.
  - Lisibilité : follet de la motte qui flambe (`_e` ×2, 0,4 s), `mud_slap` qui déborde sur la motte, « splotch » doublé.
  - Mobile : la Gifle vise le plus proche, les mottes chassent à 6 u et reviennent à 1,3 u : la Gifle les traverse souvent. Naturel.
  - Équilibrage : +0,8 par motte par 2 s = +0,4/s par motte, 2 mottes en moyenne dans l'arc ≈ +0,8/s (sur ≈ 4,2/s à 4 mottes : +19 %) ; compensation `SLAP_COEF` 1,0 → **0,85** (−0,19/s) et `MOTTE_CONTACT_COEF` 0,40 → **0,35** (−0,06/s par motte, −0,25/s à 4) : net ≈ +0,35/s (+8 %), à rogner par `SLAP_COEF` 0,8 si le simulateur sort de [0,85 ; 1,20].
  - Variantes : Crachat de vase (projectile à 6 u) : un crachat qui **traverse** une motte (ligne de tir) la nourrit de la même façon ; Bouture (grosses mottes, contact 0,45 / 0,4 s) : ×2 au lieu de ×3 (elle frappe deux fois plus souvent).
- **B2 « La vase revient en déchirant »** (P4, P1)
  - Déclencheur : Bourbier lancé avec des mottes dehors (elles fusionnent au lancer).
  - Effet : chaque motte **éclate sur place** avant de fusionner : coef **1,0** dans 1,5 u (proc 1,0, ralentissement 30 % 1 s ; reprend `ECLAT_*` de la variante Éclatement à moitié) ; la masse revient comme aujourd'hui.
  - Lisibilité : `mud_splash` par motte (existant), 4 « plof » décalés de 0,05 s (règle déjà écrite pour l'Éclatement).
  - Mobile : automatique (Bourbier sans visée).
  - Équilibrage : +1,0 × mottes (≤ 4) par 22 s dans de petites zones là où les mottes se battent ≈ +0,1-0,2/s en zone ; compensation `BOG_COEF` 1,2 → **1,1** (−0,8 par Bourbier sur une cible qui reste 4 s ; mono neutre).
  - Variantes : Marée de vase (absorbe les mottes) : même éclatement à l'absorption ; Éclatement (remplace le Rappel) : indépendant (il n'y a plus de motte à faire éclater au Bourbier si l'Éclatement vient d'être lancé : pas de cumul possible).
- **B3 « Plouf de garde »** (P5, défensif)
  - Déclencheur : Rappel lancé alors qu'une motte est **déjà à ≤ 1 u** de Bourbe (elle ne traverse rien).
  - Effet : au lieu d'une traversée vide, la motte fait un **plouf** 1,4 dans 2 u (`MOTTE_LAND_COEF`) autour de Bourbe à son recollage : le Rappel « au contact » devient une défense.
  - Lisibilité : `mud_splash` autour de Bourbe.
  - Mobile : automatique.
  - Équilibrage : remplace une traversée (1,5 sur 2-4 monstres) par un plouf (1,4 sur 2 u) : neutre ; pas de compensation.
  - Variantes : Éclatement : sans objet (il fait déjà exploser sur place).

À faire dans le même lot (audit P4) : les mottes ne provoquent plus les boss (déjà noté dans le kit au 23/10 : vérifier `Decoy.lures_bosses` à faux pour `BourbeMotte`).

### 2.9 Vigie, guetteuse de la digue (`vigie_kit.gd`, `vigie_flare.gd`, `vigie_caltrops.gd`)

**Carte actuelle.** Tension (P2 : `TENSION_MOVING_S` 2,2 s, `TENSION_STILL_S` 1 s ; pleine → Trait d'allonge `ALLONGE_COEF` 2,0 perce tout) · Fusée de détresse (`FUSEE_COEF` 1,2, lumière 3 u / 5 s : exposés `EXPOSE_MULT` ×1,1 toutes sources) · Filet lesté (0,5 + `NET_COEF` 1,2, `imprisoned` `NET_HOLD_S` 1,5 s, **Tension pleine**) · Grêle (`GRELE_COEF` 0,7 / 0,25 s pendant 2,5 s, r 4,5, −25 %, expose). Interactions : Filet → Allonge (P4, le meilleur ordre du kit, imposé par la règle), exposition (P3 faible : +10 % passif, rien ne la détone), Grêle expose aussi. Le Filet et la Fusée s'ignorent ; la Grêle ignore le Filet.
**Note : 3/5.**

**États réutilisés : « exposé »** = `has_damage_taken_mod(&"vigie_expose")` ; **« cloué »** = `is_imprisoned()`.

- **V1 « Allonge sur exposé »** (P3, P2)
  - Déclencheur : Trait d'allonge (ou Volée d'allonge) qui traverse un exposé.
  - Effet : coef 2,0 → **2,6** sur lui (en plus du ×1,1 de l'exposition) ; la flèche **ravive** la fusée la plus proche à 3 u : +1 s de lumière (plafond 7 s).
  - Lisibilité : traînée rouge de `arrow_charged` plus longue, éclat de magnésium sur la fusée (`flare` ×1,3, 0,2 s), son « lourd ».
  - Mobile : Fusée auto sur le paquet dense, Allonge auto vers le plus proche : le paquet dense est généralement le plus proche. Naturel.
  - Équilibrage : exposés ≈ 50 % des Allonges ; compensation `ALLONGE_COEF` 2,0 → **1,8** (1,8 × (1 + 0,33 × 0,5) = 2,1 ≈ +5 % mono ; sur boss exposé en permanence par la Fusée + Grêle : 2,4 × 1,1 vs 2,0 × 1,1 aujourd'hui = +20 % sur l'Allonge seule, ≈ +7 % du kit : limite haute, levier 1,7).
  - Variantes : Tir double (3 traits × 1,2) : 1,2 → 1,5 sur exposés ; Fanal (expose autour d'elle) : fonctionne, et comme Vigie est au contact l'Allonge traverse tout le paquet exposé : c'est le style « au corps à corps » voulu.
- **V2 « Fusée dans le filet »** (P4, P3)
  - Déclencheur : Fusée qui s'arrête (`rests_on_hit`) sur un **cloué** par le Filet.
  - Effet : la fusée s'allume **dans** le filet : exposition ×1,1 → **×1,25** pour les cloués tant que le filet tient, et le filet tient **+0,5 s** (1,5 → 2,0 s ; boss : ralentissement 0,4 prolongé de 0,5 s). L'ordre Filet → Fusée → Allonge est la séquence complète du personnage.
  - Lisibilité : filet (`net_burst`) teinté rouge pendant la tenue, crachotement plus fort.
  - Mobile : Filet et Fusée visent le paquet dense : la Fusée s'arrête au premier monstre du paquet cloué. Naturel. Aide : `auto_cast_ok(2)` lance la Fusée en priorité pendant une tenue de Filet.
  - Équilibrage : +15 % de dégâts subis sur ≤ 6 monstres pendant 2 s, une fois par 9 s : ≈ +3 % ; compensation `FUSEE_COEF` 1,2 → **1,0** (la flèche-fusée n'est pas là pour les dégâts).
  - Variantes : Chausse-trapes (remplace le Filet) : Fusée posée dans le champ : chaque entrée donne `CHAUSSE_TENSION` 0,25 → **0,4** ; Fanal (remplace la Fusée) : Filet lancé sous Fanal : cloués exposés ×1,25 (même chiffre, autre source).
- **V3 « Grêle sur cloués »** (P3)
  - Déclencheur : volées de Grêle (ou impact du Tir de signal) sur des cloués.
  - Effet : **+40 %** par volée sur les cloués (0,7 → 0,98), même règle que `FUMI_PRISONER_BONUS` de Tocsin.
  - Lisibilité : impacts plus gros sur le filet, chiffres en accent.
  - Mobile : Filet puis Grêle sur le paquet dense : naturel. Aide : `auto_cast_ok(4)` préfère une tenue de Filet en cours (sinon règle actuelle).
  - Équilibrage : 6-8 volées sur 11 pendant la tenue de 2 s (V2) : +0,28 × 7 ≈ +2 par ultime sur ≤ 6 cibles ; compensation `GRELE_COEF` 0,7 → **0,64**.
  - Variantes : Tir de signal (7,0 instantané) : +40 % sur les cloués = 9,8 : trop ; **+20 %** pour cette variante (8,4) ; Chausse-trapes : les ralentis du champ ne sont pas cloués : pas de bonus (équivalent : la Grêle sur le champ rend +0,1 Tension par volée).

### 2.10 Taliant, rōnin d'écorce (`morfil_kit.gd`, `morfil_twin_blade.gd`)

**Carte actuelle.** Voir §1.2. Aiguisage (ressource), garde, Iaï, Lames jumelles à seuil, Sur-aiguisage et Trempe cohérents.
**Note : 4/5.** Il manque un lien entre l'Iaï (roulade) et la Fauche-lune, et un usage de la garde :

- **TA1 « Iaï d'ouverture »** (P4, P2)
  - Déclencheur : Fauche-lune (ou Fendoir) lancée **dans les 1,5 s** après un Iaï qui a touché (`_iai_paid`).
  - Effet : coût 15 % → **8 %** d'aiguisage (la lame est déjà dégainée) et recul 1,0 → 1,4 u.
  - Lisibilité : `iai_trail` qui reste 0,3 s de plus et s'embrase à la Fauche ; clic de fourreau supprimé (la lame ne rentre pas).
  - Mobile : roulade (bouton) puis sort 2 (bouton) : deux appuis, aucune visée (la Fauche vise le paquet dense ; Taliant vient de le traverser). Naturel.
  - Équilibrage : −7 % d'usure une fois par 6 s au mieux ≈ +3 % d'aiguisage moyen (0,58 → 0,60) ≈ +3 % de DPS ; pas de compensation (l'audit P6 le trouve faible en début de run).
  - Variantes : Fendoir : idem ; Trempe (usure 0) : sans objet ; Sur-aiguisage : un Iaï compte déjà comme un geste du sur-fil.
- **TA2 « Garde qui rend »** (P2, défensif)
  - Déclencheur : un coup **encaissé sous garde** (`guard_left > 0`, `damage_taken_mult` 0,55 appliqué).
  - Effet : **+2 % d'aiguisage** (la lame qui pare s'affine), plafond 100 %, une fois par 0,3 s.
  - Lisibilité : fil de sève `_e` qui scintille à la parade, son de parade bois (Codex : `morfil_parry`, 1 son).
  - Mobile : automatique.
  - Équilibrage : ≈ 1 coup paré / 2 s en mêlée dense = +1 %/s d'aiguisage contre 8-9 %/s d'usure : +10 % d'aiguisage moyen au plus en essaim, rien sur un boss lent ; pas de compensation (c'est la faiblesse « début de run » visée).
  - Variantes : Taille lente (garde −35 %) : +1,5 % ; Lames jumelles (garde permanente) : plafonné à +2 % par seconde.

---

## 3. Priorisation et lots

### 3.1 Ordre (les huit personnages les moins interactifs d'abord)

| Rang | Perso | Note actuelle → visée | Combos | Pourquoi à cette place |
|---|---|---|---|---|
| 1 | **Ardent** | 1 → 3,5 | A1, A2, A3 | Le seul kit sans aucune lecture croisée ; personnage de référence du simulateur : valider la marque et le retour générique dessus. Demande un nœud kit de base (contrat). |
| 2 | **Tocsin** | 2 → 4 | T1, T2, T3 | Le Bras-pilier est l'objet au sol le plus riche du roster et personne ne le lit ; T1 remet du sens au +50 % orphelin de la Tête. |
| 3 | **Rainette** | 2 → 4 | RN1, RN2, RN3 | Le Gluant n'est lu que par les bonds ; RN1 est le combo le plus « mobile » du lot (deux sorts sur le paquet dense). Intègre l'audit P5. |
| 4 | **Averse** | 3 → 4 | AV1, AV2, AV3 | La trempe existe, est suivie par monstre et n'est lue par rien. Attention à la Crue (retour joueur) : AV2 avec `CRUE_COEF_FULL` 8,2, levier 8,0. |
| 5 | **Vigie** | 3 → 4 | V1, V2, V3 | Exposition et Filet existent ; trois détonations simples. Kit propre (toutes valeurs en constantes). |
| 6 | **Avare** | 3 → 4 | AVR1, AVR2, AVR3 | La marque existe ; relier Poignée, Faillite et Coup à la Rançon. Relancer `economy_test` (le 100 % de retombée ne crée pas d'or). |
| 7 | **Rictus** | 3 → 4 | R1, R2, R3 | Déjà l'étoile ; R1 touche `decoy.gd` (partagé avec Bourbe : orchestrateur). |
| 8 | **Bourbe** | 3 → 4 | B1, B2, B3 | Mottes = position ; B1 change le placement de la joueuse. Touche `bourbe_motte.gd` (champ `pushed_coef` ou équivalent). |
| 9 | Taliant | 4 → 4,5 | TA1, TA2 | Léger. |
| 10 | Arpenteuse | 5 → 5 | AR1 (facultatif) | Référence ; ne pas toucher à la cible élite 1,30. |

### 3.2 Lot 0 transverse (orchestrateur, avant les lots par personnage)

- `SpellCaster.deal_damage(enemy, s, hit)` : clé `hit["combo"]` → chiffre de dégâts en couleur d'accent + variante sonore « lourde » +2 demi-tons (`scripts/spells/spell_caster.gd`, affichage des chiffres).
- `Enemy.is_stunned() -> bool` (`_stop_left > 0`) dans `scripts/enemies/enemy.gd` (Rainette RN2, Avare AVR2 pour lecture).
- `Enemy.has_damage_taken_mod(id)` existe ; **convention** : un id avec mult 1,0 est une étiquette (Tocsin `&"tocsin_charge"`). À écrire dans `CONTRACTS.md`.
- Nœud kit de base pour Ardent : `ArdentBaseKit` (ou `ArdentTracker` promu) chargé par `CharacterData.for_id` même sans variante ; `ArdentVariantKit` en hérite.
- `Decoy` : champ `charged := 0.0` et prise en compte dans `explode_spell` / `flight_spell` (coef × (1 + charged)) : `decoy.gd` est partagé Rictus / Bourbe.
- `auto_cast_ok(slot)` : documenter dans `CONTRACTS.md` que les règles de priorité de combo passent par ce hook (jamais en manuel).
- Option S5 (mobile) : `SpellCaster.densest_point(range_px)` pondère ×1,5 les monstres **marqués par le kit** (`kit.is_marked(e)` si défini) : une seule aide de visée pour tous les combos à marque (Ardent, Avare, Tocsin, Vigie). À trancher (§4, Q5).

### 3.3 Lots par personnage (parallélisables, un agent par lot, périmètres disjoints)

| Lot | Fichiers touchés (tous sous `game/`) | Constantes modifiées | Test à ajouter |
|---|---|---|---|
| **C-ARD** | `scripts/spells/ardent_kit.gd` (+ nouveau `ardent_base_kit.gd`), `ardent_variant_kit.gd`, `ardent_tracker.gd`, `ardent_phoenix.gd` | `NOVA_COEF` 2,2, `BRASIER_COEF` 7,2, nouvelles `EMBER_MARK_S` 1,5, `NOVA_MARK_ADD` 0,4, `BRASIER_MARK_ADD` 1,0, `ASH_FLARE_COEF` 2,0 | `tests/ardent_combos_test.tscn` : Cendres sur 3 mannequins → marque posée ; Nova = 2,2 × 1,4 sur marqués, 2,2 sur un non marqué ; Brasier sur Cendres active = flambée 2,0 + extinction ; Pilier et Météores idem. |
| **C-TOC** | `scripts/spells/tocsin_kit.gd`, `tocsin_limb.gd` | `HEAD_COEF` 8,5, `TOLL_COEF` 2,2, `PILLAR_COEF` 0,7, nouvelles `CHARGE_TAG` &"tocsin_charge", `HEAD_CHARGE_ADD` 0,5, `PILLAR_RING_COEF` 1,5, `PILLAR_RING_TICKS` 2, `RIVET_JUMP_COEF` 0,8, `PICKUP_CD_REFUND` 0,5 (audit P7) | `tests/tocsin_combos_test.tscn` : pilier posé, Tête à 2 u → +50 % sur électrisés, pilier vidé, bras au sol ; Coup à 2 u du pilier → décharge 1,5 + 2 ticks ; ramassage → recharge ×0,5. |
| **C-RAI** | `scripts/spells/rainette_kit.gd`, `rainette_goo.gd`, `rainette_bubble.gd` | `LEAP_COEF` 3,4, `GOO_SPLASH_COEF` 1,2, `TONGUE_COEF` 1,1, `ULT_LAND_COEF` 2,6, nouvelles `CRUSH_ADD` 0,3, `CRUSH_STUN_S` 1,0, `TONGUE_STUN_COEF` 1,6, `TONGUE_STUN_PULL_U` 0,75, `ULT_GOO_EXTEND_S` 1,0 (max 2) | `tests/rainette_combos_test.tscn` : Gluant puis Grand saut dans la flaque → +30 %, flaque consommée, étourdis 1 s ; Grand saut pendant le Chant → un seul impact (P5) ; Langue sur étourdi → 1,6. |
| **C-AVE** | `scripts/spells/averse_kit.gd` | `HIT_WATER` 0,4, `GOUTTE_COEF_MIN` 0,7, `CRUE_COEF_FULL` 8,2, `WAVE_COEF` 3,3, nouvelles `SOAK_HIT_WATER` 1,0, `SOAK_GOUTTE_ADD` 0,25, `CRUE_SOAK_MULT` 1,2, `CRUE_SOAK_KNOCK_U` 4,5, `WAVE_PUDDLE_ADD` 0,5, `WAVE_PUDDLE_SOAK_S` 8, `is_soaked(e)` | `tests/averse_combos_test.tscn` : Vague → trempés ; Goutte sur trempé → +1,5 d'eau, coef +0,25 ; Crue sur trempés → ×1,2, recul 4,5 u ; Vague à travers la Flaque → trempe 8 s / 40 %. Relancer `_tmp_averse_dps` et le scénario « Crue à 100 » de l'audit (part de l'ultime ≤ 35 %). |
| **C-VIG** | `scripts/spells/vigie_kit.gd`, `vigie_flare.gd`, `vigie_caltrops.gd` | `ALLONGE_COEF` 1,8, `FUSEE_COEF` 1,0, `GRELE_COEF` 0,64, nouvelles `ALLONGE_EXPOSED_COEF` 2,6 (variante 1,5), `FLARE_REVIVE_S` 1,0, `NET_FLARE_EXPOSE` 1,25, `NET_FLARE_EXTEND_S` 0,5, `HAIL_NETTED_MULT` 1,4, `SIGNAL_NETTED_MULT` 1,2 | `tests/vigie_combos_test.tscn` : Fusée → exposé ; Allonge sur exposé = 2,6 × 1,1 ; Filet puis Fusée → ×1,25 et tenue 2 s ; Grêle sur cloués ×1,4. |
| **C-AVA** | `scripts/spells/avare_kit.gd`, `avare_bounce_coin.gd` | `COINS_COEF` 1,1, `RUIN_BASE_COEF` 4,6, nouvelles `COIN_MARKED_COEF` 1,8 (truquée 2,1), `COIN_MARKED_REFUND` 1,0, `RUIN_MARKED_ADD` 1,0, `SWING_MARK_EXTEND_S` 0,5, `MARK_MAX_S` 6, `SWING_MARKED_GUARD_S` 0,6 | `tests/avare_combos_test.tscn` : Rançon puis Poignée → 1,8 sur marqués, pièces à 100 % ; Faillite → +1,0 sur marqués, or neuf inchangé ; relancer `economy_test`. |
| **C-RIC** | `scripts/spells/rictus_kit.gd`, `rictus_pendulum.gd` (+ `decoy.gd` via lot 0) | `DECOY_COEF` 2,2, `TOUPIE_COEF` 0,38, `FAN_COEF` 1,25, nouvelles `DECOY_CHARGE_ADD` 0,7, `FLIGHT_CHARGED_COEF` 1,6, `SPIN_KNIFE_EXTEND_S` 0,25 (max 1,25), `LIFT_DETONATE_U` 2,4 | `tests/rictus_combos_test.tscn` : Doublures puis Éventail → 2-3 doublures chargées, explosion 2,9 ; Toupie sur couteau → +0,25 s et couteau relancé ; Levée près des doublures → explosion immédiate. |
| **C-BOU** | `scripts/spells/bourbe_kit.gd`, `bourbe_motte.gd` | `SLAP_COEF` 0,85, `MOTTE_CONTACT_COEF` 0,35, `BOG_COEF` 1,1, nouvelles `SLAP_FEED_HEAL` 0,1, `SLAP_FEED_MULT` 3,0 (Bouture 2,0), `SLAP_FEED_CD_S` 2,0, `BOG_MOTTE_BURST_COEF` 1,0, `BOG_MOTTE_BURST_U` 1,5, `RECALL_HOME_U` 1,0 | `tests/bourbe_combos_test.tscn` : Gifle sur motte → soin 10 %, coup suivant ×3 ; Bourbier avec 3 mottes → 3 éclatements 1,0 ; Rappel motte à 0,5 u → plouf 1,4. Vérifier `lures_bosses` faux (P4). |
| **C-TAL** | `scripts/spells/morfil_kit.gd` | nouvelles `IAI_OPEN_S` 1,5, `COST_CRESCENT_AFTER_IAI` 8, `IAI_OPEN_KNOCK_U` 1,4, `PARRY_SHARP` 2,0, `PARRY_CD_S` 0,3 | `tests/morfil_combos_test.tscn` : Iaï qui touche puis Fauche-lune à 1 s → coût 8 % ; coup encaissé sous garde → +2 %. |
| **C-ARP** (facultatif) | `scripts/spells/arpenteuse_kit.gd` | nouvelle `HALAGE_HELD_ADD` 0,5 | `tests/arpenteuse_combos_test.tscn` : Tendeur puis Halage → 4,0 sur emprisonnés, attraction 0. |

Chaque lot : code (Sonnet), puis `balance_sim_run.tscn --chars=<id>` avant / après (systems-designer : mono dans [0,85 ; 1,20], mini-boss [0,8 ; 1,25], Arpenteuse élite 1,30 ; chaque variante encore à ±15 % de son sort de base avec le combo), puis mise à jour des descriptions de sorts dans `data/characters.json` (**fichier partagé** : chaque agent livre ses textes dans son rapport, l'orchestrateur les fusionne) et un tip par combo (`tips.json`). Codex : un son `spell.<perso>.combo` par personnage (`art/tools/audio/`), aucun VFX nouveau obligatoire (ceux cités « Codex » sont des améliorations).

### 3.4 Ce que le simulateur ne verra pas

Le pilote auto-cast lance les sorts par règles simples ; les combos à ordre (P4) ne se produiront que si `auto_cast_ok` les encode (c'est pourquoi chaque combo ci-dessus déclare sa règle). Mesurer **avec et sans** la règle : « sans » doit rester dans la cible (un joueur qui ignore le combo ne doit pas être sous 0,85), « avec » ne doit pas dépasser 1,20. Les combos de placement (P5 : Tocsin T2, Bourbe B1, Rictus R2) dépendent du déplacement : non mesurables au simulateur, à vérifier en jeu (`capture_hit_feel`, 5 min par personnage).

---

## 4. Questions ouvertes pour le joueur (avec recommandation)

1. **Tocsin, T1 : la Tête-cloche vide-t-elle le pilier ?** Option A : le pilier sonne et tombe (bras ramassable tout de suite, burst) ; option B : le pilier continue sa décharge (+50 % seulement). **Recommandation : A** (un seul moment fort lisible ; la règle P7 sur le ramassage borne la relance).
2. **Averse, AV3 : la Vague consomme-t-elle la Flaque ?** Option A : non, elle la fait pulser (eau conservée) ; option B : oui, en échange d'un gros bonus. **Recommandation : A** (la Flaque est sa source d'eau ; la consommer punirait le combo).
3. **Avare, AVR2 : de l'or neuf sur les marqués tués par la Faillite ?** Option A : +1,0 coef seulement (proposé) ; option B : +100 % d'or au lieu de +50 %. **Recommandation : A** (l'économie est déjà au bord : `economy_test`, bourse plafonnée à 0,30 après audit).
4. **Compensations : baisser les sorts de base ou plafonner les combos ?** Option A : baisses de base proposées (le combo rend ≈ 100-110 %) ; option B : base inchangée, combos à moitié des chiffres. **Recommandation : A** (un combo doit se sentir ; Sirlin : la version « sans combo » devient un peu plus faible, c'est le prix d'une courbe d'apprentissage).
5. **Mobile : aide de visée commune ?** `densest_point` pondéré ×1,5 sur les monstres marqués par le kit (une seule règle pour Ardent, Avare, Tocsin, Vigie) ou aucune aide (les combos à marque se font sur le paquet dense de toute façon). **Recommandation : l'aide**, derrière l'option d'accessibilité « visée automatique » (déjà existante), à mesurer sur `capture_hit_feel`.

---

## Annexe A : récapitulatif

| Perso | Note | Combo phare | Autres | État / objet réutilisé | Compensation principale |
|---|---|---|---|---|---|
| Ardent | 1 → 3,5 | A1 Nova +40 % sur les marqués braise (Cendres +1 s) | A2 Brasier +1,0 / marqué + flambée des Cendres ; A3 Éclat prolonge la marque | marque braise (nouvelle, modèle `AvareKit.marks`, `ArdentTracker`) | `NOVA_COEF` 2,2, `BRASIER_COEF` 7,2 |
| Rictus | 3 → 4 | R1 couteaux qui chargent les doublures (+0,7, vol 1,6) | R2 Toupie qui ramasse et relance (+0,25 s) ; R3 Levée détone les doublures | `Decoy`, `knives`, `StringRig` | `DECOY_COEF` 2,2, `TOUPIE_COEF` 0,38, `FAN_COEF` 1,25 |
| Tocsin | 2 → 4 | T1 Tête-cloche sur pilier : +50 % sur électrisés, pilier vidé | T2 Coup qui fait sonner le pilier (1,5 + 2 ticks) ; T3 rivets qui sautent à 3 membres absents | `TocsinLimb.Phase.PILLAR`, étiquette `&"tocsin_charge"`, `smoke_bonus_spell` | `HEAD_COEF` 8,5, `TOLL_COEF` 2,2, ramassage ×0,5 (P7) |
| Averse | 3 → 4 | AV2 Crue +20 % et recul 4,5 u sur les trempés | AV1 Goutte sur trempé +1 d'eau, +0,25 ; AV3 Vague à travers la Flaque : trempe 8 s / 40 %, +0,5 | `_soaked_until` → `is_soaked`, `PUDDLE` | `CRUE_COEF_FULL` 8,2, `WAVE_COEF` 3,3, `HIT_WATER` 0,4 |
| Arpenteuse | 5 | (référence) AR1 facultatif : Halage +0,5 sur emprisonnés | — | `is_imprisoned` | aucune |
| Rainette | 2 → 4 | RN1 Grand saut dans le Gluant : +30 %, étourdit 1 s, flaque éclate (1,2) | RN2 Langue 1,6 sur étourdi / collé ; RN3 Chant +1 s par flaque | `RainetteGoo`, `Enemy.stun` (+ `is_stunned`) | `LEAP_COEF` 3,4, `GOO_SPLASH_COEF` 1,2, `TONGUE_COEF` 1,1, `ULT_LAND_COEF` 2,6 |
| Avare | 3 → 4 | AVR1 Poignée 1,8 sur marqués, pièces à 100 % | AVR2 Faillite +1,0 sur marqués ; AVR3 Coup prolonge la marque, bouclier 0,6 s | `marks` / `is_marked` | `COINS_COEF` 1,1, `RUIN_BASE_COEF` 4,6 |
| Bourbe | 3 → 4 | B1 Gifle sur motte : soin 10 %, coup suivant ×3 | B2 mottes qui éclatent au Bourbier (1,0) ; B3 Rappel au contact = plouf | `BourbeMotte`, `MOTTE_LAND_COEF` | `SLAP_COEF` 0,85, `MOTTE_CONTACT_COEF` 0,35, `BOG_COEF` 1,1 |
| Vigie | 3 → 4 | V1 Allonge 2,6 sur exposé, fusée ravivée +1 s | V2 Fusée dans le Filet : ×1,25, +0,5 s ; V3 Grêle +40 % sur cloués | `&"vigie_expose"`, `is_imprisoned` | `ALLONGE_COEF` 1,8, `FUSEE_COEF` 1,0, `GRELE_COEF` 0,64 |
| Taliant | 4 → 4,5 | TA1 Fauche-lune à 8 % après un Iaï qui touche | TA2 parade sous garde +2 % d'aiguisage | `_iai_paid`, `guard_left` | aucune |
