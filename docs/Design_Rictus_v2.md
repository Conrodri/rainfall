# Rictus v2 : refonte des sorts 2, 3 et 4

> Game design, 31/10/2026. Réponse au retour du joueur : « il faut repenser le kit de Rictus, changer les 3 sorts ; un combo qui fait seulement 8 % de dégâts en plus c'est nul ; le monocible du perso est nul ; 2 attaques au CAC, 1 distante pour du multi-cible : très difficile de tuer des boss efficacement sans se mettre fort en danger. » Précisions du joueur (même jour) : garder la DA, le couteau, si possible les fils ; un combo intéressant à jouer ; un sort 3 moins fort, à recharge plus courte que les sorts 3 des autres personnages, qui combote avec le sort 1 et le sort 2.
>
> Sources : `game/scripts/spells/rictus_kit.gd`, `docs/Design_Personnages.md` §2.6-2.7, `docs/Design_Combos.md` §1.3 et §5.1, `docs/Combos_Kits.md` §2.2, `docs/Equilibrage_Personnages.md`, `docs/Audit_Runs_Completes_2026-10-31.md`, `docs/Maths_Scaling.md` §6, §9, §14, `game/tests/balance_sim/`. Ce document ne modifie aucun code ; il remplace §2.6.3 à §2.6.9 de `Design_Personnages.md` et §5.1 de `Design_Combos.md` une fois l'option tranchée.

## 0. En bref

- **Diagnostic** : à 4-5 u d'un boss, Rictus actuel vaut **0,22 à 0,25 fois le DPS d'Ardent** (seuls 2-3 couteaux de l'Éventail touchent) ; au contact il vaut 1,41 (théorique), 0,93-1,02 (mesuré au simulateur, bot). Tout son monocible est au contact ; le combo « L'étoile armée » rapporte +4 % avec les trois charges et coûte −8 % sans. Le joueur a raison sur les trois points.
- **Socle commun aux deux options** : le pantin, le Montreur, les fils et les doublures restent ; le **couteau** devient l'arme centrale et le **fil** devient un état lisible : un monstre « ficelé » porte le couteau lourd de Rictus, relié à la main du Montreur.
- **Option 1 « Le fil et la lame » (recommandée)** : sort 2 Couteau ficelé (couteau lourd au bout d'un fil, monocible à 8 u, scie la cible), sort 3 **Saccade** (recharge **3 s**, la plus courte du jeu : le Montreur tire le fil, le couteau s'arrache, revient en main, le sort 2 est de nouveau prêt ; les coups de demi-lune sur le ficelé chargent la Saccade), sort 4 Les Doublures lancées autour de la cible (et détonées par la Saccade, +30 % si ficelées). Monocible à distance : **0,84 Ardent** ; au contact 1,15 (après facteur de réalisation) ; gain du combo sur sa fenêtre **+28 à +46 %**.
- **Option 2 « Le théâtre des doublures »** : conserve plus de l'ancien kit (Pirouette légère 4 s à la place de la Toupie, doublures en hexagone, étoile biaisée vers le ficelé). Monocible à distance 0,66-0,75 Ardent, combo +11 % au contact : contraste utile, mais elle répond moins bien au retour.
- **Assets Codex neufs** : option 1 = **une icône** (Saccade) et, facultatif, une anim `catch` (4 frames × 8 dir) ; option 2 = aucun (icônes des variantes réutilisées). Tout le reste existe.

---

## 1. Diagnostic chiffré de l'actuel

### 1.1 Ce que mesure le simulateur (31/10/2026, `balance_sim_run.tscn --chars=ardent,rictus,vigie --scen=miniboss,mixed,elite --cfg=L6,L12m --k=12`, bot)

| Combat | Ardent | Rictus | Rictus / Ardent | Vigie / Ardent |
|---|---|---|---|---|
| Mini-boss L6 (B/s) | 99 | 92 | 0,93 | 1,16 |
| Élite T3 L6 | 74 | 62 | 0,83 | 1,31 |
| Mixte + tireurs L6 | 106 | 81 | 0,77 | 0,88 |
| Mini-boss L12m | 389 | 397 | 1,02 | 0,89 |
| Élite T3 L12m | 340 | 299 | 0,88 | 1,13 |
| Mixte L12m | 367 | 363 | 0,99 | 1,00 |

Le bot de Rictus se tient à 2,2 u (`pref_u`) : il joue **au contact** en permanence. Ses chiffres de mini-boss tiennent aux six explosions superposées des Doublures (10,8 à 13,2 coef sur la cible collée) ; sur l'élite (combat long, 35-42 s) il est à 0,83-0,88.

### 1.2 Ce que vaut le kit à distance (modèle, §5)

| Position | Rictus actuel (coef/s) | Ardent | Ratio |
|---|---|---|---|
| Boss à 4-5 u | 0,62 (2-3 couteaux d'Éventail) | 2,84 | **0,22** |
| Boss au contact | 4,17 | 2,97 | 1,41 (théorique) |

Un joueur humain qui ne veut pas rester collé à un boss (coups de 28 × (1 + 0,2 (niv − 1)), 95 PV + 28 par niveau, armure 10) n'a **aucun** outil : la Toupie et la demi-lune sont au contact, les Doublures explosent autour de lui, l'Éventail touche un boss avec 2-3 couteaux sur 5 passé 3 u.

### 1.3 Le combo « L'étoile armée »

Doublures → Éventail (charge 2-3 doublures) → Toupie : +0,7 à l'explosion et 1,2 → 1,6 en vol par doublure chargée, compensé par `DECOY_COEF` 2,4 → 2,2. Résultat : sans combo −8 %, avec +4 % (`docs/Design_Combos.md` §5.1). Trois sorts, 3 s de fenêtre, au contact, pour +4 % : le joueur ne peut pas le sentir. Le budget de §1.3 (gain net +5 à +10 %) était respecté, mais il produit des combos invisibles ; ce document vise **+25 à +40 % sur la fenêtre** et compense sur les valeurs hors combo (§5.4).

---

## 2. Socle commun aux deux options

### 2.1 Ce qui ne change pas
- DA, sprites, Montreur, cinq fils du pantin (`StringRig`), Levée (roulade aérienne 3 u, invulnérable), stats de base (95 PV + 28/niv, armure 10, régén 0,6 + 0,12/niv, vitesse 4,2 u/s, hitbox 0,45 u), garde du Montreur (−30 % de dégâts subis 0,3 s après chaque demi-lune).
- **Sort 1 Dagues en demi-lune** : automatique, 0,6 s, coef 0,8, demi-cercle de 3 u (180°) vers l'ennemi le plus proche, proc 0,8, recul 0,2 u. Retouche proposée (les deux options) : `is_zone = false` sur le sort 1 (audit P3 : il cumule aujourd'hui `auto_damage_add` et `zone_damage_add`, contrairement aux autos d'Ardent et de Tocsin). Aucune autre modification.

### 2.2 L'état « ficelé » (nouveau, les deux options)
- Un monstre est **ficelé** quand le **couteau lourd** de Rictus (sort 2) est planté en lui : un fil d'argent spectral relie la main du Montreur au couteau. **Un seul ficelé à la fois** (le Montreur n'a qu'une main libre) : relancer le sort 2 déplace le fil. Durée **5 s** (fenêtre du combo), ou jusqu'au retour du couteau.
- Tant qu'il est ficelé, à **9 u** au plus de Rictus, le couteau **scie** : un tick toutes les 0,5 s (coef voir chaque option, proc 0,3). Au-delà de 9 u (ou derrière un mur : rayon `WALL_MASK`), le fil casse : le couteau tombe planté au sol à l'endroit du monstre (`knife_planted`, 4 s) et le Montreur en refait un au bout de 6 s si personne ne le ramasse.
- Si le ficelé meurt, le couteau tombe planté au sol au même endroit (4 s).
- Un boss ou un mini-boss se ficelle comme les autres ; il n'est jamais tiré ni déplacé.
- Lisibilité : fil `Line2D` de la main du Montreur au couteau, texture `string_tile`, couleur `#9FC8C0`, alpha 0,5 et 1,5 px (plus visible que les cinq fils du pantin à 0,2 / 1 px), ondulation sinus 0,5 Hz ; couteau planté dessiné enfant du monstre (sprite `knife`, orienté dans le sens du lancer, décalé de 0,3 u vers le haut) ; chaque tick de scie = flash `LightRig.flash(pos, &"spell_steel", 0,1)` sur le couteau + grelot (`pickup.coin` à −12 dB, hauteur 2,0, même son que la charge des doublures aujourd'hui). Une petite jauge en arc autour de l'icône du sort 3 montre les 5 s restantes (HUD : `combo_ready(3)` existe déjà, sondé toutes les 0,1 s).

### 2.3 Ciblage par plateforme (règle commune)
| Plateforme | Sort 2 (couteau lourd) | Sort 3 | Sort 4 |
|---|---|---|---|
| PC clavier-souris | vers le curseur ; premier monstre sur la ligne (rayon de contact 0,6 u + rayon du monstre) | sans visée | option 1 : autour du curseur ; option 2 : autour de Rictus |
| Manette | stick droit ; au repos : ciblage automatique | sans visée | stick droit / automatique |
| Mobile et « sorts automatiques » | **priorité au boss ou mini-boss à portée** (`aim_priority` = `Balance.BOSS_AIM_PRIORITY` 2,0 : distance divisée par 2 dans `SpellCaster.nearest_enemy`, déjà en place), sinon l'élite ou le T3 le plus proche, sinon le plus proche | automatique (règles §3.5 / §4.4) | option 1 : autour du ficelé s'il existe, sinon paquet le plus dense à 6 u, sinon autour de Rictus |

Le monocible du kit tombe donc **de lui-même** sur le boss en tactile : c'est la condition pour que le combo soit « réalisable sur mobile en ciblage automatique comme sur PC à la souris ».

---

## 3. Option 1 « Le fil et la lame » (recommandée)

### 3.1 Principe
Rictus n'a **qu'un couteau lourd**. Il est dans sa main, en l'air, planté dans un monstre, ou au sol. Le Montreur le tient par un fil et le **ramène toujours**. Le jeu de Rictus est une boucle à trois temps, lisible et rythmée : **lancer** (sort 2) → **laisser scier** (le fil tendu, la demi-lune vrille la lame si on est près) → **Saccade** (sort 3, 3 s : le fil claque, le couteau s'arrache, revient en main, blesse tout ce qu'il traverse, et le sort 2 est prêt). Les Doublures (sort 4) se **lancent** là où est le couteau : six pantins autour de la victime ; la Saccade tire aussi leurs fils.

C'est le pantin qui joue au marionnettiste : il ficelle, il tire, il rappelle.

### 3.2 Les sorts

| Slot | Sort | Recharge | Coef | Portée / rayon | proc | Note |
|---|---|---|---|---|---|---|
| 1 auto | Dagues en demi-lune | 0,6 s | 0,8 | 3 u, 180° | 0,8 | inchangé ; sur un ficelé, chaque coup ajoute un **tour** (max 3) |
| 2 | **Couteau ficelé** | 1,0 s, **nécessite le couteau en main** (repli 6 s si le couteau est perdu) | 2,0 à l'impact, puis **scie 0,4 / 0,5 s** (jusqu'à 10 ticks = 4,0 si on le laisse 5 s) | 8 u, 14 u/s | 0,8 impact, 0,3 scie | plante dans le premier monstre touché : ficelé 5 s ; rien touché : planté au sol en bout de course |
| 3 | **Saccade** | **3 s** | **1,4 + 0,25 par tour** (max 2,15) sur le ficelé ; **0,6** à tout monstre traversé par le couteau qui revient (perce tout) | 9 u (longueur du fil) | 0,8 | le couteau revient en main : **sort 2 prêt** ; ficelé non-boss **tiré de 1,5 u** vers Rictus ; doublures posées : **détonées** |
| 4 ultime | **Les Doublures** | 20 s | **1,8** par explosion (×6), **2,35 si ficelées** (+30 %) ; vol 1,2 | anneau de 1,2 u **autour du point visé** (ficelé en priorité), explosion 2,4 u | 1,0 | 3 s de vie, 20 % PV max, provocation 4 u ; mort = explosion à 60 % |

##### Sort 2 : Couteau ficelé
- Le couteau lourd (sprite `pendulum_knife`, 4 frames, déjà livré pour la Lame-pendule) part vers la visée à 14 u/s sur 8 u, coef 2,0, recul 0,3 u. Il **se plante dans le premier monstre touché** (ficelé, §2.2) ; sinon au sol en bout de course ou contre un mur (`knife_planted`, 4 s).
- Le sort n'a pas de vraie recharge : son bouton est **grisé tant que le couteau n'est pas en main** (icône « couteau absent » : le même dessin, vidé, avec le fil). Le couteau revient par la Saccade, ou en marchant sur lui au sol (0,6 u de contact, pickup existant `GroundPickup`), ou automatiquement s'il est perdu : 6 s après la perte, le Montreur « en refait un » (repli `KNIFE_REMAKE_S`).
- **Scie** : tick 0,4 toutes les 0,5 s, le premier 0,5 s après l'impact, tant que le ficelé est à ≤ 9 u. 10 ticks au plus (5 s). Les items à proc ne voient que 0,3 par tick (comme les Cendres).
- Anim : `throw` (existante, impact à la frame 2) ; orientation vers la visée.

##### Sort 3 : Saccade
- **Entrée** : bouton 3 / clic droit ; aucune visée. **Disponible seulement si le couteau est hors de la main** (planté dans un monstre ou au sol) : sinon grisé. Recharge 3 s, plancher 1,05 s avec les hâtes (`COOLDOWN_FLOOR` 0,35).
- **Sur un ficelé** : le Montreur tire d'un coup sec. La lame s'arrache : coef **1,4 + 0,25 par tour** (tours : §3.3, max 3 → 2,15), recul 0,5 u ; un non-boss est **tiré de 1,5 u vers Rictus** (`push` existant, direction inversée), un boss ne bouge pas. Le couteau **revient en ligne droite** vers la position courante de Rictus (comme le retour de `RictusPendulum`, 14 u/s), coef 0,6 à tout monstre traversé (perce tout, une touche par monstre), puis il est **rattrapé** : sort 2 prêt dans la même frame.
- **Sur un couteau au sol** (lancer raté, ficelé mort, fil cassé) : même retour en ligne (0,6 par monstre traversé), rattrapé, sort 2 prêt. Pas de dégât d'arrachement.
- **Doublures posées** (quelle que soit la cause) : la Saccade **tire tous leurs fils** : elles explosent toutes dans la même frame (coef 1,8 ; **2,35 si une cible est ficelée au moment de la Saccade** : « ficelées »). La Levée garde son effet (atterrir à 2,4 u les détone aussi, sans bonus).
- Vertige : aucun. Rictus reste libre de bouger pendant toute la boucle.
- Anim : `throw` jouée **à l'envers** (frames 3 → 0 : le bras se referme sur la lame) ; repli `idle`. Si Codex livre `catch` (4 frames × 8 dir), elle la remplace. Fils du pantin tendus 0,2 s (`StringRig.vibrate`), claquement sec (son `rictus_saccade`, synthèse Codex, variante du grelot : claquement de fil + lame qui siffle).

##### Sort 4 : Les Doublures (lancées)
- Rictus lance ses six doublures (anim `throw_ult`, bras projetés, existante) : elles atterrissent en **hexagone de 1,2 u autour du point visé** : PC = curseur (plafond 7 u), sinon le **ficelé**, sinon le paquet le plus dense à 6 u, sinon autour de Rictus (comportement actuel). Chaque doublure fait face vers l'extérieur de son anneau. Position dans un mur : sautée (règle actuelle).
- Immobiles, 3 s, 20 % des PV max de Rictus, provocation 4 u (jamais les boss), tuée = explosion à 60 %, timer = explosion rayon 2,4 u coef **1,8** (`double_burst`), recul 1 u × masse, +2 % PV max à la première explosion (règle « fils tendus » conservée).
- **Saccade** : voir ci-dessus (détonation immédiate, +30 % si une cible est ficelée). Sur un boss ficelé au centre de l'hexagone : **6 × 2,35 = 14,1** d'un coup, à 5-7 u de Rictus, sans se déplacer. Comparaison : Brasier d'Ardent 7,4 sur chaque monstre à 6 u ; Doublures actuelles 13,2 sur un boss **collé** à Rictus.
- Le vol des doublures (`push`, coef 1,2) n'est plus déclenché par le kit de base (plus de Toupie) : il reste câblé pour la variante Toupie (§6).

### 3.3 Le combo « Fil, lame, saccade »

**Séquence** : sort 2 (ficelle) → sort 1 (chaque demi-lune qui touche le ficelé ajoute un **tour de fil**, 3 au plus, le fil s'enroule visiblement : un anneau par tour autour du couteau) → sort 4 facultatif (doublures autour du ficelé) → **sort 3 Saccade** (arrachement 1,4 + 0,25/tour, retour qui traverse, doublures +30 %, sort 2 prêt) → sort 2 immédiatement. Fenêtre : 5 s (durée du ficelé), relançable sans fin tant que le couteau revient.

Ce qui est intéressant à jouer, au-delà des chiffres :
- **Le rythme** : lancer, attendre que la scie travaille (0,4 toutes les 0,5 s) ou tirer tout de suite ; la Saccade tôt relance plus vite (boucle de 1,3 s avec hâte), la Saccade tard engrange plus de ticks. Le joueur choisit son tempo.
- **La position** : la Saccade **tire la cible vers soi** (non-boss) : on ficelle un tireur T2 à 7 u, on le ramène dans la demi-lune. Au contact d'un boss, les tours (demi-lune) font monter la Saccade ; à distance, on renonce aux tours et on garde la peau. Près = plus fort, loin = sûr : c'est le marché que le joueur demandait.
- **La ligne de retour** : le couteau revient **vers Rictus** : se placer pour que la ligne traverse le paquet (0,6 à chacun, perce tout) est un petit jeu de visée à l'envers, lisible par le fil.
- **Les doublures** : les poser autour du ficelé puis tirer le fil = burst synchronisé à distance ; les poser autour de soi = provocation et protection comme aujourd'hui, mais c'est désormais un choix.
- **Ordre inverse** (sort 3 avant le sort 2) : rien (grisé) : le couteau est en main. Sort 4 avant sort 2 : valide, les doublures tombent sur le paquet dense ; la Saccade suivante les détone sans le +30 %.

**Gain sur la fenêtre** (modèle §5, boss, L6 / L12m) : à distance **+46 % / +28 %** ; au contact **+34 % / +24 %** ; sur un paquet de 5 **+23 % / +21 %**. Référence « sans combo » : même kit joué sans Saccade (couteau laissé 5 s, retour seul, doublures au timer). Le gain baisse à L12m parce que la hâte (0,6) raccourcit la boucle sous la durée utile de la scie : le levier est `SAW_COEF` (0,4 → 0,45) si le joueur veut un combo plus marqué en fin de run.

### 3.4 Table d'états

| État | Déplacement | Sort 1 | Sort 2 | Sort 3 | Sort 4 | Levée |
|---|---|---|---|---|---|---|
| couteau en main | marche 4,2 | oui | **oui** | grisé | oui | oui |
| couteau en vol (0,6 s) | marche | oui | grisé | grisé | oui | oui |
| couteau planté (ficelé ou sol) | marche | oui (tours sur le ficelé) | grisé | **oui** (3 s) | oui | oui |
| couteau en retour (≤ 0,65 s) | marche | oui | grisé | grisé | oui | oui |
| couteau perdu (fil cassé, 6 s) | marche | oui | grisé | grisé | oui | oui |
| levée (0,25 s) | vol 3 u | suspendu | non | non | non | — |

Plus de vertige, plus d'état « toupie », plus d'inertie : `speed_mult`, `inertia_s`, `slow_immune`, `can_dodge` rendent les valeurs neutres. Le kit perd son invulnérabilité de 2,5 s toutes les 8 s (31 % du temps, jugée « presque gratuite » par l'audit) ; il gagne la distance.

### 3.5 Lancer automatique (mobile, « Sorts automatiques »)
- Sort 2 : dès que le couteau est en main et qu'un ennemi est à ≤ 8 u, cible §2.3 (boss en priorité).
- Sort 3 : dès que disponible **et** l'une des conditions : (a) le couteau est planté depuis ≥ 2,0 s ; (b) le ficelé sort de 8,5 u (le fil va casser) ; (c) le ficelé est mort ou le couteau est au sol ; (d) des doublures sont posées depuis ≥ 1,5 s et une cible est ficelée ; (e) 3 tours sont enroulés. Sinon il attend (au plus 2,5 s). Hook `auto_cast_ok(slot)` (contrat existant, modèle d'Ardent `AUTO_HOLD_MAX_S`).
- Sort 4 : règle actuelle (`trigger_range_u` 3 u, ou ficelé présent et ≥ 3 monstres autour de lui à 2,4 u, ou boss ficelé).

### 3.6 Cas limites
- Fil cassé par un mur : le couteau tombe planté là où était le monstre (visible), pas derrière le mur. Un retour de Saccade qui rencontre un mur **s'arrête** contre lui et le couteau retombe planté de ce côté (pas de contournement) ; Rictus va le chercher (contact 0,6 u) ou attend les 6 s du repli.
- Ficelé qui se téléporte (boss) ou devient intangible (Anguille immergée, `EEL_SUBMERGED_DAMAGE_TAKEN` 0,3) : la scie continue à 9 u, dégâts réduits par la règle du boss ; la Saccade reste possible.
- Changement d'étage, mort : couteau rendu en main, ficelé effacé, doublures effacées (règle générale).
- Deux Saccades sur une seule pose : impossible (la première ramène le couteau).
- Sort 2 pendant le retour : grisé ; la relance se fait 0,65 s au plus après la Saccade (vol de retour à 14 u/s sur ≤ 9 u).
- Le ficelé entre dans la demi-lune pendant un retour : le retour frappe à 0,6 puis la demi-lune normalement.
- Hâte extrême (Saccade 1,05 s) : la boucle est bornée par le vol aller-retour (≈ 1,3 s) : pas de boucle infinie plus rapide que 1,3 s ; DPS plafonné naturellement.

### 3.7 Items
- `Horloge arcanique`, `Sablier fêlé` : accélèrent la Saccade donc **toute** la boucle (le sort 2 n'a pas de recharge propre) : c'est l'item à surveiller (plafond naturel 1,3 s par boucle). `Chronomètre brisé` sur les kills du retour de couteau : bon.
- `Rune de portée` : explosions 2,4 → 2,9 u et +15 % sur les doublures ; la scie et la Saccade ne sont pas des zones : impact modéré, voulu (le kit n'est plus « tout zone »).
- `Lame jumelle`, `Sifflet` : demi-lune ; le Sifflet accélère aussi les tours (max 3 par pose).
- `Éclair en bouteille`, `Étincelle`, `Fiole` : couteau lourd (0,8), retour (0,8) : procs réguliers ; la scie à 0,3 reste sage.
- `Pointe perforante` : sort 1 seulement, sans effet (à signaler dans l'aide, comme aujourd'hui).
- Items synergiques affichés : Horloge arcanique, Rune de portée, Éclair en bouteille.

### 3.8 Entrées par plateforme
| Plateforme | Couteau ficelé | Saccade | Doublures |
|---|---|---|---|
| PC | clic gauche (2) : curseur | clic droit (3) : sans visée | clic molette (4) : autour du curseur (≤ 7 u) |
| Manette | spell_2 : stick droit / auto | spell_3 | spell_4 : stick droit / auto |
| Mobile | bouton 2 : boss en priorité ; bouton grisé « couteau absent » | bouton 3 : grisé tant que le couteau est en main ; **pulse** quand des tours ou des doublures attendent | bouton 4 : autour du ficelé / paquet dense |

### 3.9 Constantes proposées (`rictus_kit.gd`, à créer / remplacer)

```
KNIFE_COEF := 2.0            ## impact du couteau lourd
KNIFE_RANGE_U := 8.0
KNIFE_SPEED_U := 14.0
KNIFE_KNOCK_U := 0.3
KNIFE_RECAST_S := 1.0        ## anti-spam, le vrai verrou est « couteau en main »
KNIFE_REMAKE_S := 6.0        ## couteau perdu : le Montreur en refait un
FICELE_S := 5.0              ## fenêtre du combo
FICELE_RANGE_U := 9.0        ## longueur du fil
SAW_COEF := 0.4
SAW_TICK_S := 0.5
SAW_PROC := 0.3
TOUR_MAX := 3
SACCADE_CD := 3.0
SACCADE_COEF := 1.4
SACCADE_TOUR_ADD := 0.25
SACCADE_PULL_U := 1.5
SACCADE_LINE_COEF := 0.6     ## retour du couteau, perce tout
DECOY_COEF := 1.8            ## 2,2 -> 1,8
DECOY_FICELE_MULT := 1.3     ## détonées par la Saccade avec une cible ficelée
DECOY_THROW_RANGE_U := 7.0
DECOY_AUTO_RANGE_U := 6.0
```
Leviers d'ajustement après simulation : `SACCADE_COEF` 1,2-1,6 ; `DECOY_COEF` 1,6-2,0 ; `SAW_COEF` 0,35-0,45 ; `SACCADE_CD` 2,5-3,5.

### 3.10 Recharge du sort 3 comparée aux autres personnages

| Personnage | Sort 3 | Recharge |
|---|---|---|
| **Rictus v2** | **Saccade** | **3 s** |
| Averse | Flaque-miroir | 5 s |
| Bourbe | Rappel | 6 s |
| Tocsin | Coup de tocsin | 7 s |
| Ardent | Cendres | 8 s |
| Arpenteuse | Piquet | 8 s |
| Rainette | Gluant | 8 s |
| Rictus actuel | Toupie | 8 s |
| Avare | Rançon | 9 s |
| Vigie | Filet lesté | 9 s |
| Taliant | Aiguisage | 10 s |

La Saccade est 40 % plus courte que le sort 3 le plus court du jeu et vaut 1,4-2,15 (la Toupie valait 5,7 par lancement). Le nom « Rappel » est pris par Bourbe (`&"rappel"`) : d'où **Saccade** (le coup sec du marionnettiste sur le fil ; id `rictus_saccade`).

---

## 4. Option 2 « Le théâtre des doublures »

### 4.1 Principe
Conserver l'hexagone de doublures autour de Rictus et le tour sur soi-même, mais alléger le sort 3 et donner au couteau lourd le rôle monocible. Le combo est l'**étoile biaisée** : les doublures percutées par la Pirouette volent vers le ficelé.

### 4.2 Les sorts

| Slot | Sort | Recharge | Coef | Portée / rayon | Note |
|---|---|---|---|---|---|
| 1 auto | Dagues en demi-lune | 0,6 s | 0,8 | 3 u, 180° | **360°** (cercle complet) pendant 0,5 s après une Pirouette |
| 2 | Couteau ficelé | 6 s | 1,8 impact ; scie 0,4 / 0,5 s (10 ticks) ; retour seul à 5 s : 1,0 sur la ligne | 8 u | revient seul : pas de rappel ; une seule cible ficelée |
| 3 | **Pirouette** | **4 s** | 1,0 dans 2,2 u (impact à 0,3 s) | 0,6 s invulnérable, immobile | **percute les doublures** ; sur un ficelé : **enroule 1 u** de fil (non-boss tiré de 1 u, 2 ticks de scie immédiats = 0,8) |
| 4 ultime | Les Doublures | 20 s | 1,5 par explosion (×6), vol 1,2 | hexagone 1,2 u autour de Rictus | si une cible est ficelée, la première doublure lui fait face et **3 des 6** partent vers elle à la Pirouette (étoile biaisée) |

- Pirouette = la variante actuelle (`PIROUETTE_S` 0,6, `pirouette_burst`), recharge 8 → 4 s et coef 3,7 → 1,0 : un sort léger, défensif (0,6 s d'invulnérabilité toutes les 4 s = 15 % du temps, contre 31 % pour la Toupie), qui combote avec le sort 1 (cercle complet) et le sort 2 (enroulement).
- La Toupie devient la variante du slot 3 (§6).

### 4.3 Le combo « L'étoile biaisée »
Sort 2 (ficelle un boss à 5 u) → sort 4 (hexagone autour de soi, première doublure face au ficelé) → sort 3 Pirouette (étoile : 3 doublures volent sur le ficelé : 3 × (1,5 + 1,2) = 8,1 sur lui à distance, les 3 autres nettoient autour) → demi-lune à 360° pendant 0,5 s. Fenêtre : 3 s (vie des doublures). Gain sur la fenêtre (modèle) : à distance +35 %, mais **au contact et sur un paquet +10-11 %** seulement : le combo est positionnel (la Pirouette se fait au milieu des doublures, donc près de l'action) et la Pirouette porte peu.

### 4.4 Lancer automatique
Sort 2 comme en option 1. Pirouette : dès que disponible et ≥ 2 monstres à 2,2 u, ou des doublures posées depuis ≥ 1 s, ou un ficelé à ≤ 4 u. Doublures : règle actuelle.

### 4.5 Ce qu'elle garde et ce qu'elle coûte
- Garde : la provocation autour de Rictus (meilleure protection pour un personnage à 95 PV), les anims `spin` / `spin_blur` (Pirouette), `summon` / `throw_ult`, l'étoile.
- Coûte : le monocible à distance reste moyen (0,66-0,75 Ardent), le combo au contact reste faible (+11 %), le joueur doit toujours rester au milieu de ses doublures pour l'étoile. Elle répond au « sort 3 léger à recharge courte », mais moins au « monocible à distance sans danger » et au « combo qui vaut le coup ».

### 4.6 Constantes proposées
```
KNIFE_COEF := 1.8 ; KNIFE_CD := 6.0 ; SAW_COEF := 0.4 ; RETURN_LINE_COEF := 1.0
PIROUETTE_CD := 4.0 ; PIROUETTE_COEF := 1.0 ; PIROUETTE_S := 0.6 ; PIROUETTE_REEL_U := 1.0 ; PIROUETTE_SAW_TICKS := 2
ARC_FULL_AFTER_PIROUETTE_S := 0.5
DECOY_COEF := 1.5 ; FLIGHT_COEF := 1.2 ; STAR_FICELE_COUNT := 3
```

---

## 5. Équilibrage

### 5.1 Méthode
- **Baseline mesurée** : `balance_sim_run.tscn` (bot, vitesse ×12), 31/10/2026, résultats §1.1.
- **Modèle accéléré** (pas image par image) : recharges effectives, intervalles d'attaque, hâte, crit et bonus d'items des configs `L6` (6 min Moyen, D 1,91, niveau 6, 6 objets : Pierre, Sifflet, Bague, Amulette, Sablier, Lentille) et `L12m` (14,5 min Moyen étage 4, D 4,87, niveau 12, ≈ 30 objets : Pierre ×5, Sifflet ×3, Sablier ×3, Lentille ×4, Rune ×2, Horloge ×2, …) de `balance_sim.gd` ; Dégât_base 24 / 38,4 ; PV d'un boss d'étage `Balance.boss_hp` avec le facteur de focus 0,5, calculés à la D de chaque config (`BOSS_STAGE_K` = 1,0 : l'étage ne joue pas) : 3 649 (D 1,91) et 15 657 (D 4,87). Taux de touche : demi-lune 0,9 sur un boss, Nova d'Ardent 0,7 à distance, Cendres 0,8, explosions de doublures 0,9. Trois positions : boss à 4-5 u (« distance », sort 1 hors portée), boss au contact, paquet de 5 T1 au contact.
- **Facteur de réalisation** (modèle → mesure du bot) : Ardent 99 mesuré / 87 modèle = 1,14 (procs non modélisés) ; Rictus actuel au contact 92 / 122 = 0,75. Les ratios de mêlée du modèle sont donc à multiplier par ≈ 0,85 pour retrouver une mesure ; les ratios à distance restent ≈ 1,0 (les sorts à distance touchent comme ceux d'Ardent).

### 5.2 Résultats (B/s, modèle ; ratio = / Ardent dans la même position)

| Config | Position | Ardent | Rictus actuel | Option 1 | Option 1 sans combo | Option 2 | Option 2 sans combo |
|---|---|---|---|---|---|---|---|
| L6 | distance | 83 | 18 (0,22) | **70 (0,84)** | 48 (0,58) | 55 (0,66) | 40 (0,49) |
| L6 | contact | 87 | 122 (1,41) | 118 (1,36) | 88 (1,02) | 121 (1,40) | 109 (1,25) |
| L6 | paquet de 5 | 300 | 385 (1,28) | 336 (1,12) | 273 (0,91) | 377 (1,26) | 341 (1,14) |
| L12m | distance | 332 | 83 (0,25) | **280 (0,84)** | 219 (0,66) | 250 (0,75) | 185 (0,56) |
| L12m | contact | 349 | 515 (1,48) | 446 (1,28) | 360 (1,03) | 505 (1,45) | 454 (1,30) |
| L12m | paquet de 5 | 1 274 | 1 542 (1,21) | 1 266 (0,99) | 1 032 (0,81) | 1 474 (1,16) | 1 338 (1,05) |

Après facteur de réalisation (×0,85 au contact), option 1 : distance **0,84**, contact **1,09-1,16**, paquet 0,84-0,95 : dans la plage [0,85 ; 1,20] du budget de `Design_Combos.md` §1.3 sauf la distance à 0,84 (voulu : un personnage de mêlée qui kite ne doit pas égaler Ardent à distance ; levier `SACCADE_COEF` 1,6 pour monter à 0,9).

### 5.3 Temps pour tuer un boss d'étage (modèle, PV avec focus 0,5)

| Config | Ardent | Rictus actuel, contact | Rictus actuel, distance | Option 1, distance | Option 1, contact | Option 2, distance |
|---|---|---|---|---|---|---|
| L6 (3 649 PV) | 42-44 s | 30 s | 201 s | **52 s** | 31 s | 64 s |
| L12m (15 657 PV) | 45-47 s | 30 s | 189 s | **56 s** | 35 s | 60 s |

Cible du §14 de `Maths_Scaling.md` : 65-75 s (médiane des six personnages en run complète, où seuls 36-50 % des dégâts touchent le boss) : les TTK « boss seul » du modèle sont en dessous pour tout le monde, le classement est ce qui compte. Option 1 à distance : **≈ 1,2 fois le temps d'Ardent**, contre 4,5 fois aujourd'hui. Le joueur peut tuer un boss à 5-7 u, en gérant ses télégraphes avec la Levée, sans jamais entrer au contact ; entrer au contact reste la façon la plus rapide (×0,7) et la plus risquée.

### 5.4 Combo : gain sur la fenêtre et compensation
- Gain (option 1, §3.3) : +46 / +28 % à distance, +34 / +24 % au contact, +23 / +21 % sur un paquet. Cible +25-40 % atteinte à L6 ; à L12m la hâte réduit l'écart (le sort 2 seul devient très bon : levier `SAW_COEF`).
- Compensation hors combo : `DECOY_COEF` 2,2 → 1,8 (−18 %) ; plus de Toupie (−0,71/s mono au contact, −2,6/s sur un paquet) ; plus d'Éventail (−0,6 à −1,8/s). Le kit sans combo vaut 0,58-0,66 Ardent à distance et 1,02 au contact : « ≤ 0 sans combo » respecté.
- Le combo n'est pas « un bonus de chiffre » : il est la boucle elle-même (le sort 2 ne revient que par la Saccade), ce qui le rend visible à chaque cycle de 3 s.

### 5.5 Dégâts subis
- Option 1 : le kit perd 2,5 s d'invulnérabilité toutes les 8 s (31 % du temps) ; il garde la garde de la demi-lune (−30 %, 0,3 s après chaque coup : 50 % du temps au contact) et la Levée. À distance, les dégâts subis viennent des tireurs et des télégraphes de boss : comparable à Vigie (`taken` 36-74 par combat au simulateur contre 13-81 pour Rictus actuel). À vérifier au simulateur : `taken` de l'option 1 à `pref_u` 5 u ≤ 1,5 × Ardent.
- Option 2 : 15 % d'invulnérabilité (Pirouette) + provocation autour de soi.

### 5.6 Ce que le simulateur doit vérifier (après codage)
`balance_sim_run.tscn --chars=ardent,rictus --scen=miniboss,elite,mixed,swarm --cfg=L6,L12m --seeds=3`, avec `BotPilot.preferred_range_u` de Rictus réglé à 5 u (sort 2 : `range_u` 8 × 0,6 = 4,8 : la règle existante donnera ≈ 4,8 u d'elle-même) puis forcé à 2,2 u (contact) :
- mono (élite + mini-boss) dans [0,85 ; 1,20] × Ardent au contact, ≥ 0,75 à 5 u ;
- zone (mixte, essaim) dans [0,85 ; 1,20] ;
- ablation `--noslot=3` : perte ≥ 25 % à distance (le combo pèse) ;
- `taken` à 5 u ≤ 1,5 × Ardent ;
- aucune boucle plus courte que 1,3 s (compteur de casts du slot 2 ≤ durée / 1,3).

---

## 6. Devenir des quatre variantes

| Variante (id) | Option 1 | Option 2 |
|---|---|---|
| **Main du Montreur** (`rictus_main_du_montreur`, slot 1) | **Conservée telle quelle** (claquement 1,4 u sur le paquet dense à 4 u, garde si ≤ 1,5 u). Sur un ficelé dans le disque : ajoute un tour (comme la demi-lune). Asset `montreur_hand_slam` inchangé. | Idem. |
| **Lame-pendule** (`rictus_lame_pendule`, slot 2) | **Remplacée par « Éventail »** (l'ancien sort de base devient la variante, id `rictus_eventail`) : 5 couteaux légers 1,35, 60°, 7 u, perce 1, plantés au sol 4 s. Avec la Saccade : les 5 couteaux plantés **reviennent en ligne** (0,6 chacun, perce tout) et rendent 1 s de recharge chacun (plafond 5 s) ; aucun ficelé : la Saccade ne fait que rappeler. Style : « le multi-cible au lieu du monocible ». Icône : `eventail.png` existante (renommée). L'asset `pendulum_knife` et le code `RictusPendulum` passent au sort de base. Déblocage inchangé : 150 couteaux ramassés (le compteur `rictus.knives_picked` compte aussi les couteaux rappelés par la Saccade). | **Lame-pendule conservée** (aller-retour 7 u, 2,5 / 2,5, sans fil) comme variante multi-ligne du Couteau ficelé. |
| **Pirouette** (`rictus_pirouette`, slot 3) | **Remplacée par « Toupie »** (l'ancien sort de base devient la variante, id `rictus_toupie`) : 2,5 s invulnérable, 0,42 par tick, 2,2 u, glisse, vertige, pousse les doublures en étoile (code et assets existants : `spin`, `spin_blur`). Avec le fil : chaque tick de Toupie fait aussi un tick de scie sur le ficelé (le fil s'enroule autour de la toupie). Recharge 8 s : le joueur qui veut l'ancienne mêlée invulnérable la retrouve, au prix de la Saccade. Icône `toupie.png` existante. Déblocage : « Tuer 100 monstres à moins de 2 u » (compteur `Player.close_kills` existant, celui du déblocage caché de Rictus à 200). L'asset `pirouette_burst` est réutilisé comme flash d'arrachement de la Saccade. | **Toupie** devient la variante de la Pirouette (même contenu que ci-contre). |
| **Rideau** (`rictus_rideau`, slot 4) | **Conservée** : 6 doublures en ligne perpendiculaire à la visée à 2 u devant Rictus, 6 s, 30 % PV. La Saccade les détone (+30 % si une cible est ficelée) ; elles ne sont pas lancées à distance (c'est le style « mur devant soi » de la variante). Coef 1,7 → 1,5 (même rapport que la base 2,2 → 1,8). | Conservée, idem. |

Compteurs : `rictus.doubles_launched` (déblocage de la Pirouette) n'a plus de sort de base qui l'alimente en option 1 : il est remplacé par `close_kills`. Les textes `data/characters.json` (`desc`, `unlock_text`) et `docs/Variantes_Sorts.md` §2.2 sont à réécrire par l'implémenteur à partir de ce tableau.

---

## 7. Assets Codex

### 7.1 Réutilisés (aucun rendu)
| Asset | Chemin | Usage v2 |
|---|---|---|
| pantin `idle`, `run`, `slash`, `throw`, `throw_ult`, `summon`, `lift`, `stagger`, `death` | `assets/sprites/characters/rictus/` | inchangé ; `throw` à l'envers = rattrapage (option 1) ; `stagger` sans usage en option 1 (gardé pour la variante Toupie) |
| `spin`, `spin_blur` | idem | variante Toupie ; Pirouette (option 2) |
| Montreur `hover`, `pull`, `string_tile` | `assets/sprites/characters/montreur/` | `pull` pendant le vol du couteau, la Saccade et le lancer des doublures ; `string_tile` = texture du fil du ficelé |
| `pendulum_knife` (4 frames) | `characters/rictus/variants/pendulum_knife/` | **couteau lourd** du sort 2 (vol aller et retour) |
| `knife`, `knife_planted` | `characters/rictus/knife*/` | couteau dans le monstre (`knife`, enfant du monstre) ; couteau au sol (`knife_planted`) ; variante Éventail |
| `dagger_arc` | | demi-lune (inchangé) |
| `double_burst` (TOP + CREA) | | explosions des doublures (inchangé) |
| `pirouette_burst` | `variants/pirouette_burst/` | flash d'arrachement de la Saccade (option 1) ; Pirouette (option 2) |
| `montreur_hand_slam` | | variante Main du Montreur |
| icônes `rictus_lame_pendule.png` (→ Couteau ficelé), `eventail.png` (→ variante Éventail), `toupie.png` (→ variante Toupie), `rictus_pirouette.png` (option 2 : Pirouette de base), `doublures.png`, `rictus_rideau.png`, `rictus_main_du_montreur.png`, `dagues_demi_lune.png` | `assets/sprites/icons/spells/` | renommages de fichiers seulement |

### 7.2 Neufs
| Option | Asset | Spécification | Lot |
|---|---|---|---|
| 1 | icône `rictus_saccade.png` | 128 px, même gabarit que les icônes de sorts de Rictus (fond sombre, accent argent spectral) : une main de brume qui tire un fil tendu, couteau au bout | RICV2 (effort low) |
| 1 (facultatif) | anim `catch` | 4 frames × 8 dir, même rig que `throw` : le bras se referme sur la lame qui arrive ; repli = `throw` à l'envers | RICV2 |
| 1 | son `rictus_saccade` | synthèse (scripts `art/tools/audio/`) : claquement de fil sec + sifflement court de lame, 0,25 s, trois variantes léger / moyen / lourd (0 / 1-2 / 3 tours) | audio |
| 1 | son `rictus_knife_plant` | impact mat du couteau lourd dans la chair + grelot, 0,2 s | audio |
| 2 | aucun visuel ; sons : `rictus_knife_plant` et un « fouet » de Pirouette (peut réutiliser le son de la Toupie) | | audio |

Pas de VFX nouveau : les ticks de scie sont un flash de `LightRig`, les tours sont des anneaux dessinés sur le fil (`Line2D` + 1 à 3 petits cercles, code), les fils des doublures ficelées sont des `Line2D` avec `string_tile`.

---

## 8. Implémentation (pour les développeurs)

- **Périmètre** : `game/scripts/spells/rictus_kit.gd` (réécriture : les états toupie / pirouette / éventail passent dans les branches de variantes), `rictus_pendulum.gd` (devient le couteau lourd : états FLYING, PLANTED_IN(enemy), PLANTED_GROUND, RETURNING ; `launch`, `plant_in(e)`, `drop_at(pos)`, `recall(to_player)`), `decoy.gd` (ajout : `explode_mult` lu à la détonation, `strung` pour le fil visuel ; orchestrateur, fichier partagé avec Bourbe), `data/characters.json` (sorts, textes, variantes), icônes renommées, `docs/Design_Personnages.md` §2.6 et `docs/Variantes_Sorts.md` §2.2.
- **Hooks existants suffisants** : `cast_spell`, `on_cast`, `blocks_slot` (sort 2 grisé sans couteau, sort 3 grisé avec couteau en main : `blocks_slot(2)` = `not knife_in_hand`, `blocks_slot(3)` = `knife_in_hand`), `combo_ready(slot)` (3 : ficelé ou doublures ; 2 : jamais), `auto_cast_ok(slot)` (§3.5), `damage_taken_mult` (garde), `on_dodge_end` (détonation), `action_for` (`throw` pour 2, `throw` inversé ou `catch` pour 3, `throw_ult` pour 4), `visual_anim`, `passive_info`. **Aucun contrat nouveau** si `SpellCaster.set_cooldown(slot, 0, total)` sert à rendre le sort 2 prêt au rattrapage (il existe).
- **Ficelé** : dictionnaire du kit `{instance_id: {"ref": WeakRef, "t_end": s, "tours": int, "knife": RictusPendulum}}`, modèle `AvareKit.marks` ; sondage de la distance (9 u) toutes les 0,25 s, pas par image. Tick de scie : `SpellCaster.spawn_zone` d'un `SpellData` NOVA de rayon 0, `is_zone = false`, proc 0,3, coef `SAW_COEF`, ou un coup direct via `deal_damage` si l'API le permet sans zone.
- **Tours** : `on_spell_hit(spell, enemy)` du sort 1 sur l'ennemi ficelé → `tours = min(tours + 1, 3)`.
- **Saccade** : coup direct `SACCADE_COEF + SACCADE_TOUR_ADD × tours` (hit_force recul 0,5 u) ; `enemy.push(dir_vers_rictus × 1,5 u)` si non-boss ; `knife.recall()` ; `Decoy.live` : pour chaque doublure vivante non expédiée : `explode(spell × (1,3 si ficelé))` ; `set_cooldown(2, 0, …)` au rattrapage (signal `caught` du couteau).
- **Doublures lancées** : `_spawn_decoys(s, aim)` prend un centre : `aim` (PC) borné à 7 u, sinon position du ficelé, sinon `densest_point(6 u)`, sinon Rictus ; le reste du code (hexagone, murs, poussée des monstres, `appear`) est inchangé.
- **Bot** (`bot_pilot.gd`) : `preferred_range_u` donnera 4,8 u pour le sort 2 (`range_u` 8 × 0,6) : ajouter la règle « sort 3 grisé tant que le couteau est en main » dans le choix des casts (il lit `blocks_slot`).
- **Tests** : `tests/rictus_kit_test` (à créer, modèle des tests de kits existants) : (1) lancer → ficelé → 10 ticks de scie en 5 s → couteau au sol à 5 s ; (2) Saccade avec 3 tours = 2,15 et sort 2 prêt dans la frame ; (3) retour qui traverse 3 monstres = 3 × 0,6 ; (4) ficelé à 9,5 u → fil cassé, couteau au sol ; (5) doublures + ficelé + Saccade = 6 × 2,35 ; (6) auto-cast : Saccade part à 2,0 s de pose ; (7) hâte 0,6 : pas plus d'une boucle par 1,3 s. `tests/spell_auto_aim_test` : le sort 2 vise le mini-boss avant les T1 à égale distance.

## 9. Protocole de vérification en mode test (joueur)

1. Mode test, Rictus, PV illimités désactivés, « Sorts automatiques » désactivés. Invoquer un mini-boss. Se placer à 5-6 u : **sort 2** : le couteau se plante, le fil apparaît, un grelot toutes les 0,5 s. Attendre 5 s : le couteau tombe au sol, le fil disparaît. **Sort 3** : le couteau revient, le sort 2 est de nouveau allumé.
2. Même scène : sort 2, puis **sort 3 après 2 s** : la cible prend le coup d'arrachement, le couteau revient ; relancer sort 2 tout de suite. Vérifier qu'on peut tenir la boucle sans s'approcher et que la barre du mini-boss descend à un rythme comparable à Ardent à distance (chrono : objectif ≈ 1,2 × le temps d'Ardent).
3. Se coller au mini-boss : sort 2 puis 3 demi-lunes (3 anneaux sur le fil), sort 3 : le chiffre de l'arrachement doit être ≈ 1,5 × celui de l'étape 2.
4. Invoquer 8 essaims à 6 u, sort 2 sur l'un d'eux, sort 3 : il est tiré de 1,5 u vers Rictus et le couteau qui revient blesse ceux qu'il traverse.
5. Boss ficelé à 6 u, **sort 4** : les six doublures tombent autour du boss (pas autour de Rictus) ; **sort 3** : six explosions d'un coup, chiffres ≈ 30 % plus gros que si on laisse le timer.
6. Mobile ou « Sorts automatiques » : invoquer un mini-boss et 10 essaims : le sort 2 doit partir sur le mini-boss, le sort 3 à ≈ 2 s de pose ; vérifier que la boucle tient seule.
7. Variantes : équiper Éventail (slot 2) et Toupie (slot 3) : l'ancien kit doit se rejouer (étoile comprise).

## 10. Points à trancher par le joueur

1. **Option 1 ou option 2** (recommandation : 1).
2. Plafond des tours : 3 (proposé) ou 5 (contact plus récompensé, Saccade jusqu'à 2,65).
3. Le sort 4 lancé autour du curseur sur PC (proposé) ou toujours autour du ficelé / de Rictus (plus simple, moins de contrôle).
4. Anim `catch` : la demander à Codex (RICV2) ou garder `throw` à l'envers.
5. Déblocage de la variante Toupie : « 100 monstres tués à moins de 2 u » (proposé) ou « gagner une run avec Rictus » (déjà pris par Main du Montreur).
