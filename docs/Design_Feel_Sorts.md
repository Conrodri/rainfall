# Feel des sorts : lancements visibles, impacts qui pèsent (design v1)

> Statut : **document de design** (Fable, game-designer, 29/10/2026), sur demande du joueur : « des lancements de sorts très visibles et satisfaisants : mouvements grands et imposants ; le coup part vite (startup court), la récupération est un peu plus longue, sauf si elle est annulée par un autre sort : le cancel est la clé des combos ». Rien n'est implémenté ; aucun fichier de `game/` n'est modifié. Compagnon de `docs/Design_Combos.md` (les combos y sont définis ; ici, le **rythme** qui les rend jouables) et de `docs/Design_Esquives.md` (esquives implémentées).
> Conventions : **1 f = 1 image à 60 Hz = 16,7 ms** ; 1 u = 64 px ; les planches de personnages sont rendues par Codex dans Blender (règle absolue : aucun aplat géométrique, aucun asset dessiné en code) ; les **durées par frame** vivent dans les `.tres` (`SpriteFrames`, champ `duration` par frame, déjà lu par `Player.play_action` pour placer l'impact) ; les constantes de ressenti vivent dans `Balance` ou dans le kit.

Sommaire : 1. Vocabulaire et état du code · 2. Règles par catégorie (frames) · 3. Cancel et buffer · 4. Poids du coup (hitstop, recul, secousse, flash, accessibilité) · 5. Corps et traînées (squash, smear, pose tenue) · 6. Son calé · 7. Mobile · 8. Codex vs code · 9. Application : Arpenteuse, Ardent, Averse · 10. Checklist de revue · 11. Références.

---

## 1. Vocabulaire et état du code

### 1.1 Les quatre temps d'un coup

| Temps | Définition | Ce que le joueur ressent |
|---|---|---|
| **Anticipation** (startup) | de l'appui à la frame d'impact : le corps se charge | « le coup part vite » si ≤ 10 f pour un sort, ≤ 20 f pour un ultime |
| **Actif** (impact) | la ou les frames où l'effet existe : dégâts, zone, projectile parti | le moment : pose tenue, flash, son, hitstop |
| **Récupération** (recovery) | de l'impact au retour en `run` / `idle` | le poids : plus elle est longue, plus le coup pèse… et plus le cancel vaut cher |
| **Cancel** | une autre action coupe la récupération | la clé des combos : préparer et encaisser **sans temps mort** |

Esthétique visée (MDA) : **Sensation** (le coup qui claque) d'abord, puis **Défi** (choisir quoi annuler par quoi). Dynamique : « j'appuie, ça part ; j'enchaîne, ça coupe ». Référence de rythme : Hades (dash qui annule tout, attaques qui partent en 5-8 f), pas Dark Souls (engagement total : on ne l'adopte que pour l'ultime).

### 1.2 Ce que le code fait déjà (`scripts/player/player.gd`, `scripts/spells/spell_caster.gd`, `scripts/enemies/enemy.gd`)

- **Anim d'action par sort** : `Player.play_action(base, dir)` joue `attack` (sort 1), `cast` (2-3), `cast_ult` (4) ou une base propre au kit (`kit.action_for`), orientée en 8 directions, **tient l'orientation** pendant l'anim (`action_locks_facing`) ; frame d'impact déclarée par kit (`ACTION_IMPACT_FRAMES`, ex. Averse `attack` 3, `wave` 3, `cast` 2, `crue` 5 ; Arpenteuse `plant` 2, `loop` 2, `whip` 2, `attack` 3, `cast` 2, `cast_ult` 3 ; Ardent sans kit : 40 % de l'anim, soit `attack` 2 / `cast` 3 / `cast_ult` 4 à 12 fps → 0,17 / 0,25 / 0,36 s). Les **effets du sort attendent la frame d'impact** (`SpellCaster._pending`, `Player.action_impact`) : tir, zone, son, lumière partent **au bon moment**. Repli procédural si l'anim manque (écrasé / recul / étiré / flash d'accent, `ACTION_SQUASH` 0,13, `ACTION_RECOIL_PX` 9).
- **Cancel actuel : total et sans règle.** `play_action` vide l'impact en attente (l'effet part tout de suite, jamais perdu) puis relance : **n'importe quel sort coupe n'importe quelle anim à n'importe quelle frame**, l'auto compris. Résultat : le sort 1 (toutes les 0,6 s) hache les anims des sorts 2-4, la récupération n'existe pas, donc le poids non plus. Aucun buffer d'entrée sauf Rainette (`INPUT_BUFFER_S` 0,15).
- **Poids du coup côté monstre** (`Balance` §« Poids des coups », `Enemy._direct_hit`, `HitFx`) : force f = √(dégât / (dégât de base × 10)) + 0,25 si critique, bornée [0, 1] ; **hitstop du monstre** 1 à 5 f (`HITSTOP_MIN_S` 0,016, `HITSTOP_MAX_S` 0,080, réarmement 0,10 s), **recul** 0,1 à 0,6 u × masse (`KB_MASS` 1 / 0,7 / 0,4, élite ×0,6, boss ×0,08 / ×0,04), **flash** 0,06-0,08 s, étincelles plafonnées (`IMPACTS_PER_FRAME` 24). Les boss ne gèlent pas.
- **Secousse** : `Main.shake(px, hz, s)` × `GameSettings.shake_scale()` (0-100 %) ; utilisée par les boss (`BOSS_PACE_SHAKE_PX` 2,5 / 7 / 5), les dégâts subis (2,5 / 9 px), et quatre kits (Tocsin 18 Hz 0,3 s ; Avare, Rainette, Vigie 22 Hz 0,2 s).
- **Accessibilité** (`GameSettings`) : `reduce_motion()` (coupe tout hitstop : `hitstop_enabled()`), `shake_scale()` (0-1), `flashes_level()` 2 / 1 (×0,25) / 0 (aucun : les flashs de monstre sont coupés, `Quality.flashes_level > 0`), `damage_text_scale()`, `haptics()`. Toute proposition ci-dessous passe par ces quatre points, jamais à côté.
- **Son** : `Audio.play_cast(spell_id, pos, power)` choisit `cast_light / medium / heavy` selon la puissance (seuils `hit_power` : 1,4 / 3,2), hauteur 1,08 → 0,90 et volume −3 → +2 dB avec la puissance ; coups classés `light / medium / heavy` + « crack » de critique ; ultime : `play_ultimate` + ducking.
- **Esquives** (`Design_Esquives.md` §2) : i-frames 0,20-0,30 s (12-18 f), Ardent 0,06 s de dispersion + 0,14 s de reformation (course et sorts permis dès la reformation), Averse glisse au maintien.

**Diagnostic** : le jeu a déjà la frame d'impact, le poids côté monstre et l'accessibilité. Il lui manque **la récupération** (donc le poids côté joueur), **des règles de cancel** (donc des combos qui s'enchaînent sans hachage) et **un buffer** commun.

---

## 2. Règles par catégorie (frames à 60 Hz)

Budget : un sort doit **se lire en deux images** : la pose d'anticipation (grande, hors silhouette) et la pose d'impact (tenue). Tout le reste est du liant.

| Catégorie | Anticipation (appui → impact) | Actif | Récupération | Total | Pose d'anticipation | Pose d'impact tenue |
|---|---|---|---|---|---|---|
| **Sort 1 (auto)** | **4-8 f** | 2-4 f | **6-10 f** | 12-22 f (0,2-0,37 s ; cadence 0,6 s) | petite (bras, pas le corps) | 2 f |
| **Sorts 2-3** | **8-12 f** | 2-6 f | **16-22 f** | 26-40 f (0,43-0,67 s) | **grande** : le corps entier sort de la silhouette d'`idle` | **4-6 f** |
| **Ultime** | **14-20 f** | 6-10 f | **24-32 f** | 44-62 f (0,73-1,03 s) | **très grande** + lumière de charge dès f 0 | **8-10 f** |
| **Esquive** | **0-2 f** | 12-18 f (i-frames) | **4-6 f** | 16-26 f | aucune (elle part) | marqueur d'arrivée 3 f |

Règles :

1. **Le coup part vite** : l'impact d'un sort 2-3 tombe à ≤ 12 f (0,2 s) ; aujourd'hui Averse `wave` 15 f, Ardent `cast` 15 f, `crue` 25 f : les sorts 2-3 **remontent à 10-12 f**, les ultimes restent à 20-25 f (l'anticipation de l'ultime est sa signature : c'est le seul sort « Souls »).
2. **La récupération est plus longue que l'anticipation** (×1,5 à ×2) : c'est elle qui donne le poids, et c'est elle qu'on annule.
3. **La pose d'impact est tenue** par la durée de frame du `.tres` (`duration` 2,0-3,0 sur la frame d'impact), pas par le code : Codex rend 6 frames, l'assemblage (`art/tools/<perso>/`) écrit les durées. Le code continue de lire `get_frame_duration` : aucun changement de logique.
4. **Une seule chose bouge pendant l'impact tenu** : le VFX (anneau, cône, chaîne) ; le corps est figé en pose, le sol reçoit la lumière (`LightRig.flash`). Le mouvement du joueur pendant l'impact tenu : interdit pour les sorts 2-4 (le corps ne glisse pas sur une pose), permis pour le sort 1 (Ardent, Averse, Vigie tirent en courant : `attack` ne bloque pas le déplacement, règle existante).
5. **Hors écran de la silhouette** : la pose d'anticipation d'un sort 2-4 dépasse l'`idle` d'au moins **20 % en hauteur ou en largeur** (bras levés, cape, chaîne, amphore basculée) ; l'ultime de 35 %. Mesurable sur la planche (`cel.check_sheet`).

---

## 3. Cancel et buffer

### 3.1 Qui annule quoi

Principe : **un geste plus engagé coupe un geste moins engagé ; l'esquive coupe tout ; l'auto ne coupe rien.** Le cancel n'est permis qu'**après l'impact** (jamais avant : un sort lancé part toujours, son effet n'est jamais perdu, règle déjà codée) et seulement **dans la récupération**.

| Geste en cours ↓ / nouveau → | Sort 1 (auto) | Sort 2-3 | Ultime | Esquive |
|---|---|---|---|---|
| **Sort 1** (récupération 6-10 f) | attend la fin (cadence) | **coupe dès impact + 1 f** | coupe dès impact + 1 f | coupe à toute frame (même avant impact : l'auto est gratuite, son effet est perdu si pas encore parti) |
| **Sort 2-3** (récupération 16-22 f) | **ne coupe pas** : l'auto est **mise en attente** et part à la fin de la récupération (jamais perdue, cadence conservée) | **coupe dès impact + 4 f** (fenêtre de cancel ≈ 12-18 f) | coupe dès impact + 2 f | **coupe dès impact + 2 f** |
| **Ultime** (récupération 24-32 f) | ne coupe pas (attente) | coupe dès **impact + 12 f** (la moitié de la récupération est engagée : le poids) | — | coupe dès **impact + 6 f** (l'esquive sauve, mais on paie 6 f : Hades-like, pas Smash-like) |
| **Esquive** (récupération 4-6 f) | ne coupe pas (l'auto repart à la fin) | **coupe dès la fin des i-frames** (le « dash-cancel » : Trait → Halage, Iaï → Fauche-lune, Repli → Allonge) | coupe dès la fin des i-frames | Vigie seulement (3 charges, à toute frame) |

- **Cancel = la récompense des combos** : avec cette table, `Design_Combos.md` AR-3 (Trait → Halage) se joue en **15 f + 0 f** : l'Halage part à la frame où les i-frames finissent ; TA1 (Iaï → Fauche-lune) idem ; AV-1 (Vague → Crue) : la Crue coupe la Vague à impact + 2 f, soit 12 + 2 = **14 f après l'appui de Vague** au plus tôt ; A-1 (Cendres → Nova) : la Nova auto-déclenchée coupe la récupération des Cendres à impact + 4 f.
- **Ce qui ne se cancel pas** : la frame d'impact et les 1-12 f qui la suivent (selon la catégorie) ; c'est la **seule** part « engagée » du jeu : assez pour sentir le poids, trop courte pour frustrer (Souls : 30-60 f d'engagement ; nous : 2-12 f).
- **Implémentation** (orchestrateur, `player.gd` / `spell_caster.gd`) : `Player.can_cancel_into(kind) -> bool` lu par `SpellCaster` avant `cast` et par `DodgeMove.can_start()` ; état = `_action` (catégorie) + `_action_left` vs `_action_total` + `_action_impact_pending`. Constantes dans `Balance` : `CANCEL_AFTER_IMPACT_F := {&"auto": 1, &"spell": 4, &"ult_by_spell": 12, &"ult_by_dodge": 6, &"spell_by_dodge": 2}` (en frames, convertis par `/ 60.0`). Le sort 1 **n'appelle plus** `play_action` si un sort 2-4 est en récupération : il est **différé** (file d'un élément, `_auto_deferred`), pas annulé.

### 3.2 Buffer d'entrée

- **8 f (0,133 s)** pour tout appui de sort 2-4 et d'esquive pendant une fenêtre non annulable : l'action part à la **première frame permise** (Celeste, Smash : 8-10 f). Constante `Balance.INPUT_BUFFER_S` 0,133 ; Rainette garde ses 0,15 s (déjà codés).
- **Tactile** : le buffer compense la latence du doigt (un tap de 50 ms pendant la récupération part quand même). **Manette / clavier** : idem. Jamais de double déclenchement : un appui buffé est consommé une fois.
- **Esquive buffée pendant un ultime** : elle part à impact + 6 f, pas avant : le joueur sent qu'il a « payé » l'ultime.

---

## 4. Poids du coup

### 4.1 Hitstop (arrêt sur image) selon la puissance

Existant côté monstre : 1-5 f selon f (`Balance.hitstop_time`). Proposition : **ajouter le côté joueur** et un **gel global** court pour l'ultime, tous coupés par `GameSettings.hitstop_enabled()` (mouvement réduit = aucun gel, règle existante).

| Puissance (f = force relative, `Balance.hit_force`) | Monstre (existant) | **Joueur** (anim figée sur la pose d'impact, nouveau) | **Gel global** (`Engine.time_scale` 0 → 1, nouveau) |
|---|---|---|---|
| Léger (f < 0,35 : auto, ticks) | 1-2 f | 0 | 0 |
| Moyen (0,35-0,6 : sorts 2-3) | 2-3 f | **2 f** | 0 |
| Lourd (0,6-0,85 : Fauche-lune, Tendeur, Crue partielle) | 3-4 f | **3 f** | 0 |
| Ultime / f ≥ 0,85 ou ≥ 8 monstres touchés d'un coup | 5 f | **4 f** | **3 f** (`ULT_GLOBAL_FREEZE_S` 0,05) |
| Critique | +0,25 à f | +1 f | 0 |

- Monster Hunter et Hades : le hitstop grandit avec l'arme / le coup, jamais au-delà de 5-6 f pour ne pas casser le rythme. **Plafond absolu 5 f** (`HITSTOP_MAX_S` 0,080 inchangé).
- Le gel global de 3 f sur l'ultime est le seul qui touche le temps du jeu : avec 250 monstres il coûte 0 (rien ne se calcule) ; il est **réarmé** à 1 par seconde (`ULT_GLOBAL_FREEZE_REARM_S` 1,0) pour qu'une Mousson ou un Chant de crue (ticks) ne figent pas l'écran en boucle. Les boss ne gèlent toujours pas (règle existante) : leur « hitstop » est la pose tenue du joueur.
- Le gel joueur s'applique sur `_visual` (AnimatedSprite2D en pause 2-4 f), **pas** sur `_action_left` : le cancel reste calculé en temps réel, le gel ne décale pas les fenêtres.

### 4.2 Recul et poussée

- **Monstres** (existant, `Balance.knockback_px`) : 0,1-0,6 u × masse. Garder. Ce qui manque : un recul **signé par catégorie** pour que le joueur lise la puissance au déplacement de la foule : auto 0,1-0,2 u ; sorts 2-3 0,3-0,5 u ; ultime 0,6 u (plafond) **plus** la poussée propre du sort (`push()`, ex. Crue 3 u → 4,5 u trempés, Coup de tocsin 2,5 u). Un ultime qui ne déplace pas la foule ne pèse pas (Vampire Survivors : tout le feel vient du recul et des chiffres, le personnage ne bouge pas ; nous avons le personnage **et** la foule).
- **Joueur** (nouveau pour les vraies anims ; existe en repli) : **kick** opposé à la visée à la frame d'impact : auto 0 ; sorts 2-3 **4-6 px** (0,1 u, 3 f aller + 6 f retour, `CAST_KICK_PX` 5) ; ultime **8-10 px** (`ULT_KICK_PX` 9). Appliqué sur l'offset du sprite (`_visual.offset`), **pas** sur la position physique : jamais un recul dans un mur ni un déplacement de hitbox.
- **Le monstre recule du côté opposé au point d'origine** (`hit["source_pos"]`, existant) : les kits qui posent une zone au sol donnent `source_pos` = centre de la zone (Nova, Crue), ceux qui frappent en ligne donnent le point le plus proche de la ligne (chaîne, piquet : déjà fait). À vérifier sort par sort (checklist §10).

### 4.3 Secousse de caméra

Vlambeer (« The Art of Screenshake ») : la secousse vend la puissance ; trop, elle vend la nausée. Toutes × `GameSettings.shake_scale()`.

| Catégorie | Amplitude | Fréquence | Durée | Condition |
|---|---|---|---|---|
| Auto | 0 | — | — | jamais |
| Sorts 2-3 | **0-2 px** | 22 Hz | 0,15 s | seulement si ≥ 3 monstres touchés d'un coup, ou un boss |
| Lourd (Tendeur, Fauche-lune, Crue ≥ 70 d'eau) | **3-4 px** | 20 Hz | 0,2 s | toujours |
| Ultime | **5-7 px** | 18 Hz | 0,25 s | toujours (Brasier 6, Tête-cloche 7 = `BOSS_PACE_SHAKE_PX.heavy`) |
| Esquive | 0 | — | — | jamais (Rainette, Bourbe : l'atterrissage n'est pas un coup) |

Constantes : `Balance.CAST_SHAKE_PX := {&"spell": 2.0, &"heavy": 3.5, &"ult": 6.0}`, `CAST_SHAKE_HZ := {&"spell": 22.0, &"heavy": 20.0, &"ult": 18.0}`, `CAST_SHAKE_S := {&"spell": 0.15, &"heavy": 0.2, &"ult": 0.25}` ; les quatre kits qui appellent `n.shake(px, 22.0, 0.2)` en dur passent par ces tables.

### 4.4 Flash et lumière

- **Flash du monstre** (existant, 0,06-0,08 s, coupé si `flashes_level` 0) : garder.
- **Flash du joueur à l'impact** : l'accent HDR ×2,2 existe en repli (`ACTION_FLASH_HDR`) ; pour les vraies anims, c'est le **masque `_e`** de la pose d'impact (Codex : émission ×2 sur la frame d'impact, rendue dans la planche `_e`) + `LightRig.flash` (existant par sort, `light_preset`). **Aucun flash plein écran, jamais** (épilepsie, mobile) : la lumière vient du sol et du corps, pas de l'écran. Les éclairs d'ambiance suivent déjà `Quality.flashes_level`.
- **Vignette d'ultime** : l'étalonnage se réchauffe déjà à l'ultime (ducking visuel, `ULTIMATE_SLOT`) ; garder ≤ 0,4 s et × `flash_scale()`.

### 4.5 Accessibilité (résumé des points d'entrée)

| Réglage | Ce qu'il coupe ou réduit | Ce qu'il garde |
|---|---|---|
| Mouvement réduit (`reduce_motion`) | hitstop monstre, joueur et global ; kick du joueur ; squash de code | poses tenues, VFX, son, chiffres |
| Secousses (`shake_scale` 0-1) | toutes les secousses, proportionnellement | tout le reste |
| Flashs (`flashes_level` 2 / 1 / 0) | flash des monstres, `LightRig.flash` ×1 / ×0,25 / ×0 (déjà le cas pour les éclairs : à étendre aux flashs de sorts), vignette d'ultime | masques `_e` des poses (lumière stable, pas un flash) |
| Taille des chiffres (`damage_text_scale`) | — | chiffres de combo en accent (`Design_Combos.md` §6) |
| Vibrations (`haptics`) | mobile : une impulsion courte à l'impact des sorts lourds et de l'ultime (`haptics_strength`), jamais sur l'auto | — |

---

## 5. Corps et traînées

### 5.1 Squash & stretch

- **Dans la planche (Codex)** : anticipation **écrasée 10-15 %** (le corps se tasse, les pieds s'écartent), impact **étiré 15-20 %** sur le membre qui frappe (bras, chaîne, amphore), retour à 100 % sur les 2 dernières frames. Les proportions de la silhouette restent reconnaissables (DA sérieuse : exagération **par la pose**, pas par la déformation cartoon : un Ardent qui s'écrase de 40 % n'est plus Ardent).
- **Dans le code** : rien pour les sorts 2-3 quand l'anim existe (le repli procédural `ACTION_SQUASH` 0,13 reste pour les anims absentes) ; pour l'**ultime**, un **tassement d'impact de 8 % pendant 4 f** sur `_visual.scale` (sol qui encaisse ; coupé par `reduce_motion`), parce qu'il se lit même sur une pose tenue.

### 5.2 Smear frames (frames de filé)

- **1 à 2 frames de filé par sort 2-4**, rendues par Codex **dans la planche** : le membre ou l'arme est étiré sur la trajectoire (motion blur modélisé : géométrie allongée + alpha 60 %), placées **juste avant l'impact**. Jamais sur l'auto (trop fréquent, bruit) ni sur l'esquive (les fantômes de code font le travail : `spawn_dodge_ghost`, existant).
- Durée d'une smear : **1 f** (`duration` 0,5 à 12 fps ≈ 2,5 f à 60 Hz : trop long ; le `.tres` accepte des durées fractionnaires, mettre 0,4).

### 5.3 Traînées de code (autorisées : ce sont des systèmes, leurs textures viennent de Blender)

- `Line2D` texturées existantes : chaîne d'Arpenteuse, `iai_trail`, `arrow_charged`, `slide_wake`. Règle : une traînée dure **≤ 0,3 s** après l'impact d'un sort 2-3, **≤ 0,6 s** pour un ultime ; fondu linéaire ; jamais plus d'une traînée par sort.
- Fantômes (sprites en calques, existants pour les esquives) : 3-4 copies à alpha décroissant, 0,25 s. Peuvent servir à l'**anticipation d'ultime** (le corps « charge » : 2 fantômes qui convergent vers la pose, Codex ne rend rien de plus).

### 5.4 Pose tenue à l'impact

C'est la règle la plus rentable du document : **une pose d'impact tenue 4-10 f, grande, éclairée par son `_e`, pendant que le VFX se déploie**. Smash et Hades construisent tout le feel dessus. Elle coûte 0 en code (durée dans le `.tres`), 0 en perf, et se lit sur mobile parce qu'elle **ne bouge pas**.

---

## 6. Son calé sur l'impact

- **Deux sons par sort 2-4** : un **départ** (whoosh / charge, court, à f 0, −6 dB) et un **impact** (à la frame d'impact, variante `light / medium / heavy` selon la puissance, existant via `play_cast(power)` : à déplacer de l'appui vers la frame d'impact, ce que `_pending` fait déjà pour le tir). Aujourd'hui `_cast_fx` est appelé dans `fire` (donc à l'impact) : vérifier sort par sort que le son d'**impact** n'est pas joué à l'appui.
- **Ultime** : départ à f 0 avec ducking (existant `duck_event(&"ultimate")`), **creux de 2 f** juste avant l'impact (volume −12 dB sur 2 f : l'oreille attend), impact `heavy` + crack si ≥ 8 touchés. Pas de silence plus long : sur mobile, le joueur perd le fil.
- **Hauteur** : déjà modulée par la puissance (1,08 → 0,90). Ajouter **+2 demi-tons sur un coup de combo** (`Design_Combos.md` §6, `hit["combo"]`).
- **Sol et taille** : les pas et impacts suivent déjà la taille et le sol ; un ultime sur l'eau de carte prend la variante « éclaboussure » si elle existe (sinon rien de nouveau).
- **Cadence** : jamais deux sons d'impact du même sort en < 50 ms (pool de voix existant, `HIT_CELL_PX`) ; un ultime à 30 touchés = **un** son lourd + étincelles, pas 30.

---

## 7. Mobile (lisibilité à petite taille)

- **Taille minimale** : sur un écran de 6,1" en paysage, 1 u ≈ 4,7 mm. Tout impact de sort 2-4 fait **≥ 1 u** à l'écran (anneau, cône, flaque) ; l'auto ≥ 0,5 u. Les poses d'anticipation « hors silhouette » (règle 5 du §2) sont ce qui rend le lancement visible à cette échelle : un bras levé de 20 % = 1 mm, lisible ; un flash de 2 f ne l'est pas.
- **Contraste** : la DA est sombre et désaturée avec un accent émissif par personnage ; le lancement se lit par **l'accent qui monte** (masque `_e` ×2 sur l'anticipation et l'impact) : c'est le signal mobile numéro un, avant la secousse et avant le hitstop.
- **Chiffres** : `damage_text_scale` existant ; un coup de combo en accent ; jamais plus de 6 chiffres par image (plafond à ajouter dans l'affichage des dégâts : `DAMAGE_TEXT_PER_FRAME` 6, les suivants fusionnent en « ×N »).
- **Qualité Bas / Moyen / Haut** (`Quality`) : Bas = pas de fantômes d'esquive, étincelles ÷2 (`IMPACTS_PER_FRAME` 24 → 12), traînées sans texture ; **jamais** de suppression de la pose tenue ni du son.
- **Doigt sur le bouton** : la pulsation du bouton de combo (`combo_ready`) et l'anneau de recharge existent ; pendant la récupération non annulable, le bouton **ne grise pas** (le buffer prend l'appui) : griser dirait « refusé » alors que c'est « bientôt ».

---

## 8. Codex (Blender) vs code (Godot)

| Codex rend dans la planche | Le code ajoute |
|---|---|
| Poses clés **exagérées** : anticipation hors silhouette (+20 % sorts, +35 % ultime), impact tenue (grande, membre étiré 15-20 %), retour | durées par frame dans le `.tres` (assemblage `art/tools/<perso>/`, pas Codex en direct) : impact ×2-3, smear ×0,4 |
| **1-2 smear frames** avant l'impact (géométrie allongée, alpha 60 %) | fantômes d'esquive et de charge d'ultime (sprites en calques) |
| **Masque `_e`** avec accent ×2 sur anticipation et impact (lumière stable, pas un flash) | `LightRig.flash` au sol, vignette d'ultime, tout × `flashes_level` |
| VFX de sort (anneaux, cônes, flaques : 12-20 frames, 18-24 fps, `art/briefs/vfx.md`) et **textures** des traînées (`slide_wake`, `chain_tile`…) | `Line2D` texturées, fondu, durée ≤ 0,3 / 0,6 s |
| 8 directions, pivots et tailles **inchangés** (`STYLE_cel.md` : mêmes grilles, mêmes noms) | kick de sprite (offset), tassement d'ultime (scale 8 %, 4 f), hitstop joueur / global, secousse, buffer, cancel |
| Sons : départ + impact par sort, variantes `light / medium / heavy`, « creux » non rendu (c'est du volume) | choix de variante selon la puissance, hauteur, ducking, +2 demi-tons de combo, plafond de voix |

Brief type pour Codex (une anim) : « `wave` d'Averse, 6 frames + 1 smear, 8 directions, 192 px : f0 anticipation (amphore basculée en arrière, corps tassé 12 %, hauteur +20 % par les bras), f1 smear (bras et cône filés 1,2 u, alpha 60 %), f2 **impact** (bras tendus, amphore vide vers l'avant, étirée 18 %, `_e` ×2 sur l'eau), f3-f5 retour. Pivot, grille, noms : inchangés. » Le reste (durées, son, lumière) est au code et à l'assemblage.

---

## 9. Application aux trois prioritaires

Frames à 60 Hz ; « actuel » = planche existante (frames @ fps, impact déclaré) ; « proposé » = cadrage à donner à Codex pour la reprise (mêmes noms, mêmes grilles ; le nombre de frames **peut** changer si la planche reste ≤ 4096 px) et aux durées du `.tres`.

### 9.1 Arpenteuse (`arpenteuse_kit.gd`, planche `arpenteuse.tres`)

| Sort | Anim | Actuel (impact) | Proposé : anticipation / impact tenu / récupération | Cancel | Poids |
|---|---|---|---|---|---|
| Chaîne (auto) | aucune (elle court) | — | — : la chaîne **est** le sort ; feel = `HEAT_FLASH_ENERGY` 4,5 à chaque tick qui mord, `CROSS_FLASH_ENERGY` 6,0 sur un croisé (`Design_Combos.md` §2.1) | — | tick : hitstop monstre 1 f, recul 0 (`CHAIN_FORCE` 0,1 : elle mord, ne repousse pas) |
| Halage (2) | `loop` 4 @ 12, impact 2 (10 f) | 10 f : bon | **8 f / 5 f / 18 f** (6 frames : f0 anticipation bras ouverts, f1 smear de la chaîne qui se tend, f2 impact tenue ×3, f3-f5 retour) | coupé par Piquet / Tendeur dès impact + 4 f, par le Trait dès impact + 2 f | f ≈ 0,6 (3,5 coef) : hitstop monstre 3 f, joueur 2 f, recul 0,4 u + attraction 1,5 u ; secousse 2 px si ≥ 3 touchés |
| Piquet (3) | `plant` 4 @ 10, impact 2 (12 f) | 12 f : limite | **10 f / 4 f / 16 f** (le piquet part de la main à l'impact ; la pose d'impact = bras tendu vers le point visé, hors silhouette +25 %) | idem | f ≈ 0,3 : hitstop monstre 2 f (par tick de ligne), pas de secousse |
| Tendeur (4) | `whip` 6 @ 14, impact 2 (8,6 f) | **trop rapide pour un ultime** (il part avant d'être vu) | **16 f / 8 f / 26 f** (8 frames : f0-f2 anticipation : elle saisit la chaîne à deux mains, corps tassé, chaîne qui monte du sol avec 2 fantômes convergents ; f3 smear ; f4 **impact tenue ×3** : bras au-dessus de la tête, chaîne tendue +35 % de hauteur, `_e` ×2 ; f5-f7 retour) ; `SNAP_S` 0,25 (claquement puis traction) reste synchronisé sur l'impact | Trait dès impact + 6 f, Halage / Piquet dès impact + 12 f | f = 1 : hitstop monstre 5 f, joueur 4 f, **gel global 3 f**, recul plafond puis traction (`TENDEUR_KEEP_U`), secousse 6 px 18 Hz 0,25 s, tassement 8 % 4 f, son `heavy` + creux de 2 f |
| Trait (esquive) | `RollDodge` 15 f | i-frames 15 f | **0 f / 15 f / 4 f** ; la chaîne se tend à l'arrivée (`TAUT_S`) : marqueur d'arrivée = flash cuivre sur le segment tendu 3 f | **Halage / Piquet / Tendeur dès f 15** (dash-cancel : AR-3) | aucun |

Séquence du joueur (`Design_Combos.md` AR-1) en frames : Trait 0-15 → Piquet à f 15 (impact f 25) → Tendeur à f 25 + 4 = f 29 (impact f 45, gel f 45-48) : **moins d'une seconde** de l'esquive au claquement, deux lignes sur le boss, un gel, une secousse : c'est le combo que le joueur décrit.

### 9.2 Ardent (`ardent_kit.gd`, planche `ardent.tres`, 12 fps, impacts par défaut 40 %)

| Sort | Anim | Actuel (impact) | Proposé | Cancel | Poids |
|---|---|---|---|---|---|
| Éclat de braise (auto) | `attack` @ 12, impact 2 (10 f) | 10 f : bon pour un auto à 0,6 s (plage 4-8 f : passer à **8 f**, frame 2 à `duration` 0,8) | **8 f / 2 f / 8 f**, tire en courant (existant) | coupé par Nova / Cendres / Brasier dès impact + 1 f, par l'Éclat (esquive) à toute frame | f ≈ 0,28 : hitstop monstre 1-2 f, recul 0,15 u, pas de secousse |
| Nova ardente (2) | `cast` @ 12, impact 3 (15 f) | **15 f : trop lent** pour un sort de contact auto-déclenché à 3 u | **10 f / 6 f / 18 f** (frame 2 d'impact à 12 fps, tenue ×3 : bras écartés, manteau soulevé +25 %, `_e` ×2) ; déclarer `action_impact_frames` dans un `ArdentBaseKit` (contrat `Design_Combos.md` §6) au lieu des 40 % | Cendres / Brasier dès impact + 4 f, Éclat dès impact + 2 f (la sortie du combo A-1 / A-3) | f ≈ 0,5 : hitstop monstre 3 f, joueur 2 f, recul 0,4 u depuis le centre (`source_pos` = Ardent), secousse 2 px si ≥ 3 touchés |
| Cendres (3) | `cast` @ 12, impact 3 (15 f) | 15 f | **10 f / 4 f / 16 f** (même anim que la Nova : la frame d'impact est la pose « main vers le sol » ; si Codex rend une `cast_zone` propre, la pose vise le point à 7 u, hors silhouette +20 %) | Nova dès impact + 4 f (A-1 : la Nova auto coupe les Cendres), Éclat dès impact + 2 f | f ≈ 0,3 par tick : hitstop 1-2 f, pas de secousse ; la zone qui s'allume est le feel (VFX `ardent_ashes`, 12-16 frames) |
| Brasier (4) | `cast_ult` @ 11, impact 4 (22 f) | 22 f : bon | **20 f / 10 f / 28 f** (8 frames : f0-f3 anticipation avec 2 fantômes qui convergent et le sol qui rougit dès f 0 (`LightRig` preset `brasier` en montée 0,33 s) ; f4 **impact tenue ×3** : bras levés +35 %, `_e` ×2,5 ; f5-f7 retour) | Éclat dès impact + 6 f, Nova / Cendres dès impact + 12 f (A-2 : Brasier puis Cendres) | f = 1 : hitstop monstre 5 f, joueur 4 f, gel global 3 f, recul 0,6 u depuis le centre, secousse 6 px, tassement 8 %, son `heavy` + creux 2 f ; l'anneau de flammes (VFX 16-20 frames) se déploie **pendant** la pose tenue |
| Éclat (esquive) | `BlinkDodge` 12 f (4 + 8) | — | **0 f / 12 f / 2 f** (course et sorts permis dès la reformation : existant) ; marqueurs : silhouette `out` + gerbe `in` (VFX `dodge_blink`, livrés) | **tout sort dès f 4** (la reformation accepte les sorts : c'est déjà la règle) | aucun (règle 6 des esquives) |

### 9.3 Averse (`averse_kit.gd`, planche `averse.tres`, 12 fps)

| Sort | Anim | Actuel (impact) | Proposé | Cancel | Poids |
|---|---|---|---|---|---|
| Goutte-lame (auto) | `attack` 6 @ 12, impact 3 (15 f) | **15 f : trop lent pour un auto** (elle tire en courant ; la lame doit partir au geste) | **8 f / 2 f / 10 f** (impact frame 2, `duration` 0,8 ; f0 anticipation = main qui puise à l'amphore, f1 smear de la lame, f2 impact) | coupé par Vague / Flaque / Crue dès impact + 1 f, Glissade à toute frame | f ≈ 0,3 : hitstop monstre 1-2 f, recul 0,15 u, éclaboussure `mud_splash` teintée cyan (Codex : `splash_small`, facultatif) |
| Vague (2) | `wave` 6 @ 12, impact 3 (15 f) | **15 f → 12 f** | **12 f / 5 f / 18 f** (f0-f1 anticipation : amphore basculée en arrière, corps tassé 12 %, +20 % de largeur par les bras ; f2 smear du cône ; f3 **impact tenue ×3** : bras tendus, amphore vidée vers l'avant, `_e` ×2 sur l'eau ; f4-f5 retour) ; `WAVE_VFX` (6 frames CREA) démarre à l'impact | Crue dès impact + 2 f (AV-1 : Vague → Crue en 14 f), Flaque dès impact + 4 f, Glissade dès impact + 2 f | f ≈ 0,6 : hitstop monstre 3 f, joueur 2 f, recul 0,4 u + `WAVE_KNOCK_U` 1,5 u × masse (existant), secousse 2 px si ≥ 3 touchés, son `medium`, kick 5 px vers l'arrière |
| Flaque-miroir (3) | `cast` 4 @ 12, impact 2 (10 f) | 10 f : bon | **10 f / 4 f / 14 f** (pose d'impact = amphore inclinée vers le point visé, l'eau « tombe » : VFX `puddle_mirror` qui s'ouvre) | Vague / Crue dès impact + 4 f (AV-2 : Flaque → Vague en 14 f), Glissade dès impact + 2 f | f ≈ 0,25 par tick : rien de plus ; la flaque qui pulse (AV-2) est le feel |
| Crue (4) | `crue` 8 @ 12, impact 5 (25 f) ; `CAST_LOCK_S` 0,2 | 25 f : bon (ultime) | **22 f / 10 f / 28 f** (f0-f3 anticipation : elle soulève l'amphore au-dessus de la tête, 2 fantômes, lumière `averse_crue` en montée ; f4 smear de l'eau ; f5 **impact tenue ×3** : amphore renversée, +35 %, `_e` ×2,5 ; f6-f7 retour, elle « redevient rapide » : la dernière frame est déjà une pose de course) | Glissade dès impact + 6 f (AV-4 inverse : la Flaque laissée porte la glisse), Vague / Flaque dès impact + 12 f | f = (eau/100)^1,2 × 0,9 : à 100 d'eau f ≈ 0,95 → hitstop monstre 5 f, joueur 4 f, gel global 3 f, recul plafond + `CRUE_KNOCK_U` 3 u (4,5 sur trempés), secousse **5 + 2 × eau/100 px** (5 à 40, 7 à 100 : la Crue pleine secoue plus, lisible), tassement 8 %, son `heavy` + creux 2 f ; à 40 d'eau f ≈ 0,3 : hitstop 2 f, secousse 3 px, son `medium` : **une petite Crue se sent petite**, c'est voulu (elle est faite pour fuir) |
| Glissade (esquive) | `SlideDodge` : 9 f d'i-frames, maintien | — | **0 f / 9 f + maintien / 0 f** (le verrou de 0,5 s après l'arrêt n'est pas une récupération : les sorts sont permis pendant) ; `stumble` 3 @ 10 (amphore ≥ 80 : freine mal 0,25 s) est la seule « récupération », assumée | **tout sort pendant la glisse** (elle lance en glissant : Vague ou Crue depuis le sillage, AV-4) | aucun ; la trace (`slide_wake`) est le marqueur |

Séquence du joueur (AV-1) en frames : Vague appui f 0, impact f 12 → Crue acceptée dès f 14 (buffer : un appui à f 5 part à f 14), impact f 36, gel f 36-39, secousse 7 px : **0,6 s** de l'appui de Vague au gel de la Crue, les trempés emportés à 4,5 u.

---

## 10. Checklist de revue (par sort, 2 minutes, `capture_hit_feel` ou mode test à vitesse ×0,25)

1. **Impact à ≤ 12 f** (sort 2-3), ≤ 25 f (ultime), ≤ 8 f (auto) ? (`play_action` → `action_impact` : chronométré dans le test.)
2. **Pose d'anticipation hors silhouette** (+20 % / +35 %) et **pose d'impact tenue** (4-6 f / 8-10 f, `duration` du `.tres`) ?
3. **Récupération ≥ 1,5 × anticipation**, et **annulable** par la bonne catégorie à la bonne frame (table §3.1) ? L'auto est différée, pas perdue ?
4. **Buffer** : un appui 5 f avant la fenêtre part à la première frame permise, une seule fois ?
5. **Hitstop** monstre / joueur / global selon f ; **aucun** si mouvement réduit ?
6. **Recul** dans le bon sens (`source_pos`), amplitude par catégorie, ultime qui déplace la foule ?
7. **Secousse** par catégorie, × réglage, jamais sur l'auto ni l'esquive ?
8. **Flash** : accent `_e` sur anticipation et impact ; `LightRig` au sol ; rien plein écran ; × `flashes_level` ?
9. **Smear** 1-2 f avant l'impact, jamais sur l'auto ?
10. **Son** : départ à f 0, impact à la frame d'impact, variante selon la puissance, creux de 2 f sur l'ultime, un seul son lourd par ultime ?
11. **Mobile** : impact ≥ 1 u, accent qui monte, chiffres ≤ 6 par image, bouton non grisé pendant la récupération ?
12. **Esquive** : coupe tout, est coupée par les sorts 2-4 dès la fin des i-frames, aucun dégât ?

---

## 11. Références

- Jonasson & Purho, « Juice it or lose it » (2012) : empiler des retours petits et cohérents (squash, secousse, son, particules) plutôt qu'un seul gros : https://www.youtube.com/watch?v=Fy0aCDmgnxg
- Nijman (Vlambeer), « The Art of Screenshake » (2013) : hitstop, secousse, recul, cadence ; la règle « moins de 6 f de gel » : https://www.youtube.com/watch?v=AJdEqssNZ-U
- Hades (Supergiant) : dash qui annule les attaques, attaques qui partent en quelques frames, hitstop proportionnel ; la critique de PC Gamer sur le « moment-to-moment » : https://www.pcgamer.com/hades-review ; les retours de joueurs sur l'absence de cancel dans Hades II montrent le coût d'un engagement trop long : https://steamcommunity.com/app/1145350/discussions/0/4357872738332097988
- Risk of Rain 2 (wiki) : compétences de survivants à armement court, sprint annulé par les compétences, poids porté par le recul et la cadence : https://riskofrain2.wiki.gg/
- Vampire Survivors : aucune anim de lancer ; tout le feel vient du recul de la foule, des chiffres et du son : la preuve que recul + chiffres suffisent à vendre un coup, et la raison pour laquelle notre personnage doit faire **mieux** (il a un corps).
- Dark Souls : engagement total de la récupération = poids ; retenu seulement pour l'ultime (12 f engagées), refusé pour le reste.
- Monster Hunter : hitstop qui grandit avec l'arme ; plafond pour garder le rythme.
- Super Smash Bros., Celeste : vocabulaire startup / active / endlag, buffer de 8-10 f, dash-cancel.
- Projet : `docs/Design_Combos.md`, `docs/Design_Esquives.md`, `art/briefs/STYLE_cel.md`, `art/briefs/vfx.md`, `game/scripts/core/balance.gd` (§« Poids des coups », `BOSS_PACE_*`), `game/scripts/player/player.gd` (`play_action`, repli procédural), `game/scripts/ui/game_settings.gd` (accessibilité), `game/scripts/audio/audio_manager.gd` (`play_cast`, `power_level`).
