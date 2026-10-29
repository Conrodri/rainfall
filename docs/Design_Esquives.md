# Esquives par personnage (design v2, implémenté)

> Statut : **document de référence** (Fable, game-designer, 29/10/2026), sur demande du joueur : chaque personnage a une esquive qui correspond à son chara design. Remplace `docs/Roulades_Personnages.md` (v1 du 23/10, non implémentée) sur trois points imposés par le joueur : **Averse glisse en consommant son eau** (son réservoir, pas une jauge à part), **Ardent se téléporte**, **Vigie a 3 petits dashs enchaînables**. Les autres mobilités de la v1 sont reprises, allégées, et sont **codées** (`game/scripts/player/dodge_move.gd` et les kits).
> Conventions : 1 u = 64 px ; i-frames = invulnérabilité (`Player.is_invulnerable()`) ; « budget » = la roulade de référence : 3 u, 0,25 s d'i-frames, recharge 3 s, soit ≈ 1 u/s de repositionnement et ≈ 8 % du temps invulnérable. Chaque esquive tient ce budget à ±15 % sauf justification écrite.

Sommaire : 1. Règles communes · 2. Tableau · 3. Fiches · 4. Entrées et HUD · 5. Contrat technique · 6. Tests et protocole joueur · 7. Leviers et risques.

---

## 1. Règles communes

1. **Même bouton partout** : action `dodge` (tactile : bouton « esquive » de la grappe ; clavier : Maj gauche ou Espace ; manette : LB). Un seul appui = une esquive ; **seule Averse lit le maintien** (le bouton tactile presse l'action au toucher et la relâche au lever du doigt : `DodgeButton`).
2. **Direction** (`Player.dodge_direction()`) : déplacement en cours (joystick, ZQSD, stick gauche), sinon le curseur (clavier-souris), sinon l'avant (`facing`). Deux personnages **inversent le sens par défaut sans entrée de déplacement** : Rainette et Vigie reculent depuis la visée en gardant la menace en face (`dodge_motion_dir`). Avec le joystick, tout le monde part où il pousse.
3. **Jamais à travers un mur, jamais dans le vide.** Toute esquive est un déplacement **balayé** (`move_and_collide` + glissement le long du mur, puis `Player.keep_walkable()` : bornes de la carte et cases de mur du NavField). Vaut pour les cartes à contours organiques (vide `VOID_CHAR " "` hors carte), les remparts de bord, l'eau profonde `~` (rectangle de collision), les blocs dynamiques des boss. Un blink dos au mur parcourt ce qu'il peut et **consomme quand même** sa recharge (lisibilité > clémence).
4. **Monstres** : aucune esquive n'est bloquée par un monstre (masque monde seulement). Rictus et Rainette passent **au-dessus** (hauteur + ombre), les autres **à travers** (fantômes, traînée).
5. **Lisibilité** : un marqueur de départ et un marqueur d'arrivée, visibles en moins de 0,5 s ; aucun téléport invisible (Ardent laisse sa silhouette de braises au départ et une gerbe à l'arrivée, à 3 u l'une de l'autre).
6. **Pas un sort offensif** : effets secondaires = contrôle léger (ralentissement), ressource (Tension, pièces) ou cosmétique ; seul l'Iaï de Taliant blesse (≈ 13 % de son DPS, décision du 22/10). Aucun effet d'esquive ne dépasse 5 % du DPS d'un kit.
7. **Plafond mobile** : un seul nœud persistant par esquive (traînée ou zone, ≤ 2 s), pas d'ombre dynamique nouvelle.
8. **Équilibrage** : `Balance.DODGE_*` reste la roulade par défaut ; toute valeur propre vit dans le kit (`<id>_kit.gd`, constantes) ou dans la classe d'esquive (`BlinkDodge`, `SlideDodge`). Jamais en dur dans `player.gd`. Aucune réduction de recharge par les items. **Mode test** : « Recharge 100 % » (`TestMode.cdr_full`) met la recharge à 0 et les charges au maximum ; « Ressource pleine » garde l'eau d'Averse au maximum.
9. **Téléporteur, coffres, secrets** : une esquive ne déclenche jamais « interagir » (le téléporteur ne part que sur l'action `interact`) ; les plaques de pression des zones secrètes se déclenchent au passage comme à la marche (Ardent qui blinke par-dessus une plaque sans la toucher ne l'enfonce pas : lisible, pas un exploit).

## 2. Tableau

| Perso | Esquive | Genre | Distance | Durée | i-frames | Recharge / charges | Coût | Effet signature |
|---|---|---|---|---|---|---|---|---|
| Ardent | **Éclat** | téléportation balayée | 3 u | 0,20 s (0,06 dispersion + 0,14 reformation) | 0,20 s | 3 s | — | silhouette de braises au départ, gerbe à l'arrivée ; course permise dès la reformation |
| Averse | **Glissade** | glisse au maintien | 9 u/s tant qu'on tient ; min 1,35 u | tenue (min 0,15 s) | 0,15 s au départ ; contact ignoré pendant | verrou 0,5 s après l'arrêt | **eau** : 10 au départ + 25/s (÷2 sur l'eau de la carte, Flaque, Gouttière) | trace d'eau au sol, eau versée sous ses pieds ; amphore ≥ 80 : freine mal 0,25 s |
| Rictus | **Levée** | saut aérien | 3 u | 0,25 s | 0,25 s | 3 s | — | au-dessus des monstres, fils tendus (existant) |
| Tocsin | **Vapeur** | dash | 3 u | 0,25 s | 0,25 s | 3 s | — | nuage 1,2 u pendant 0,6 s : `slow` 30 % 1 s, sans dégâts |
| Arpenteuse | **Trait** | dash | 3 u | 0,25 s | 0,25 s | 3 s | — | chaîne **tendue** 1,5 s : `slow` 50 % au lieu de 35 %, sans dégât de plus |
| Rainette | **Bond** | saut aérien à reculons | 3,5 u | 0,29 s (12 u/s) | 0,29 s | 3 s | — | au-dessus des monstres, anneau d'atterrissage (existant) |
| Avare | **Râfle** | dash lourd | 2,5 u | 0,25 s (10 u/s) | 0,25 s | 3 s | — | ses pièces à 1,2 u ramassées pendant + 0,3 s ; fantômes or |
| Bourbe | **Coulée** | dash lourd | 3 u | 0,30 s (10 u/s) | 0,30 s | 3 s | — | hitbox 0,35 u pendant ; traînée de vase 3 × 0,8 u, 2 s : `slow` 30 % |
| Vigie | **Repli** | 3 petits dashs enchaînables | 3 × 1 u | 3 × 0,083 s (12 u/s) | 3 × 0,083 s = 0,25 s | 1 charge / 1 s (3 s pour les 3) | — | recule depuis la visée par défaut ; +8 % de Tension par dash ; fantômes rouges |
| Taliant | **Iaï** | dash tranchant | 3 u | 0,25 s | 0,25 s | 3 s | 4 % d'aiguisage s'il touche | coef 1,5 à 0,9 u du trajet (existant) |

Budget : tous à 3 u / 0,25 s / 3 s sauf Ardent (0,20 s d'i-frames : −20 %, compensé par zéro exposition pendant le trajet et un repositionnement instantané), Averse (i-frames −40 % mais mobilité illimitée tant qu'elle a de l'eau : payée en sorts), Avare (2,5 u : −17 %, il est le plus blindé du roster), Bourbe (0,30 s : +20 %, elle est la plus lente et finit sa coulée à portée du paquet traversé), Rainette (3,5 u et 0,29 s : +17 %, inchangé ; mobilité engagée partout ailleurs).

---

## 3. Fiches

### 3.1 Ardent : « Éclat » (`BlinkDodge`)
- Appui → **dispersion 0,06 s** (sprite qui s'efface, immobile, invulnérable) → **saut balayé** de 3 u (`move_and_collide` + glissement + `keep_walkable`) → **reformation 0,14 s** (sprite qui revient, invulnérable, **déplacement et sorts permis** : il se reforme en courant). Total 0,20 s d'i-frames, recharge 3 s, distance fixe (le curseur ne la raccourcit pas).
- Murs, remparts, eau profonde, vide : le balayage s'arrête au dernier point libre (hitbox comprise) ; dos au mur, la recharge part quand même.
- Marques : silhouette de braises (fantôme du sprite, orange, 0,35 s) + gerbe `out` au départ ; gerbe `in` + éclat de lumière `ember` à l'arrivée. VFX `assets/sprites/vfx/dodge_blink/` (lot Codex `art/tools/vfx/_dodge_vfx.txt`, livré) ; repli `ember_shard_impact`. Sons : `spell.cendres.cast_light` (−4 dB, ×1,3) au départ, `spell.eclat_de_braise.hit_light` (−8 dB, ×0,9) à l'arrivée.
- Vaut pour Ardent et ses variantes (`CharacterData.dodge_kind = &"blink"` posé par `ArdentKit.variant_a()`).

### 3.2 Averse : « Glissade » (`SlideDodge`, demande du joueur)
- **Elle verse de l'eau sous ses pieds et glisse dessus tant qu'elle tient le bouton et qu'il lui reste de l'eau.** Son réservoir = l'**Eau** de son kit (pas de jauge à part) : glisser concurrence Vague / Flaque / Crue, c'est le choix du joueur. Départ : **−10 d'eau** (`SLIDE_START_COST`, la gerbe) ; puis **−25/s** (`SLIDE_DRAIN_PER_S`). Sur l'eau de la carte (`,`), dans sa Flaque ou sa Gouttière : **drain ÷2** (`SLIDE_WATER_DRAIN_MULT`), l'eau porte. Amphore pleine : 3,6 s de glisse, 32 u.
- Vitesse **9 u/s** (`SLIDE_SPEED_U`), indépendante du niveau d'eau. Direction continue au joystick / ZQSD (virage 200°/s), cap gardé sans entrée ; le curseur ne la dirige pas. Durée minimale 0,15 s (un tap = coup sec de 1,35 u). Relâcher = fin ; réservoir à 0 = fin ; mur de face (normale contre le cap, seuil −0,7) = elle bute et s'arrête ; eau profonde = mur.
- **i-frames : 0,15 s au départ seulement** ; pendant la glisse, les coups de **contact** des monstres à portée (rayon + marge 0,3 u, boss compris) sont ignorés (`ignores_hit`), **projectiles, zones et ondes touchent**. L'eau porte, elle ne protège pas. Verrou de relance 0,5 s après l'arrêt (pas de spam d'i-frames).
- Sous 10 d'eau ou « à sec » : bouton grisé (`can_dodge` faux). Amphore ≥ 80 à l'arrêt : elle **freine mal** 0,25 s (anim `stumble`, vitesse ×0,6). L'ancienne roulade de 1,5 u disparaît.
- Marques : eau versée au départ (anim `splash` de `dodge_slide`, repli : sa Flaque-miroir en petit), **trace d'eau** (Line2D texturée `slide_wake.png`, s'efface en 1 s), pas de fantômes. Sons : `spell.vague.cast_light` (−6 dB, ×1,25) au départ, `spell.flaque_miroir.cast_light` (−10 dB, ×1,3) à l'arrêt. Pas de chuintement continu en v2 (à produire si le ressenti le réclame : `art/tools/audio/`).
- HUD : le bouton montre le verrou (0,5 s) ; la jauge d'Eau existante est la vraie limite. Sauvegarde : l'eau l'est déjà.

### 3.3 Rictus : « Levée » (existante, `RollDodge`)
Le Montreur soulève le pantin : 3 u / 0,25 s au-dessus des monstres, fils tendus, interdite pendant le vertige. Rien de neuf : libellé « Levée ».

### 3.4 Tocsin : « Vapeur » (`RollDodge` + hook)
Dash 3 u / 0,25 s / 3 s (`DODGE_U`). Au départ, la chaudière lâche sa vapeur : anneau `TocsinSteamFx` de **1,2 u** pendant **0,6 s** ; les monstres à portée au départ sont ralentis **30 % pendant 1 s** (`STEAM_*`). Pas de dégâts. Son `spell.tocsin_bras_pilier.end` (−6 dB, ×1,2). Fantômes en calques conservés.

### 3.5 Arpenteuse : « Trait » (`RollDodge` + hook)
Dash standard qui déroule 3 u de chaîne d'un coup (existant). À l'arrivée, la chaîne reste **tendue 1,5 s** (`TAUT_S`) : son ralentissement passe de 35 % à **50 %** (`TAUT_SLOW_PCT`, Lestée déjà à 50 %), **sans dégât de plus**. Tip : après une Boucle, un Trait redonne de quoi boucler. Son `spell.arpenteuse_tendeur.cast_light` (−6 dB, ×1,2).

### 3.6 Rainette : « Bond » (existant, `RollDodge`)
Bond arrière 3,5 u, au-dessus des monstres, interdit pendant le Grand saut. Rien de neuf (la ressource Souffle n'existe plus depuis le 26/10) : libellé « Bond », son `spell.rainette_grand_saut.cast_light` (−8 dB, ×1,3).

### 3.7 Avare : « Râfle » (`RollDodge` + hook)
Dash **2,5 u à 10 u/s** (`RAKE_SPEED_U`, 0,25 s, i-frames égales). Pendant le dash et **0,3 s** après, ses **propres pièces** (ressources de joueur) à **1,2 u** sont ramassées (`RAKE_PICKUP_U`, `GroundPickup.collect()`) : la roulade est le geste pour aller rechercher sa bourse dans la foule. Aucun or créé. Fantômes or (#F2C14E). Son `spell.avare_coup_de_coffre.cast_light` (−6 dB, ×1,1).

### 3.8 Bourbe : « Coulée » (`RollDodge` + hook)
Elle se liquéfie : **3 u à 10 u/s** (0,30 s, i-frames 0,30 s, surplus assumé : lente, bruyante, finit à portée du paquet). Hitbox **0,35 u** pendant (rendue à l'arrivée par `_refresh_body`). **Traînée de vase** sur le trajet (`MudTrail`, 2 s, demi-largeur 0,4 u) : `slow` 30 % rafraîchi toutes les 0,25 s, **sans dégâts** ; visuel = 3 `mud_splash` (lot BO3) posés le long. Pas de fantômes. Interdite pendant le Bourbier. Son `spell.gifle_de_vase.cast_light` (−6 dB, ×0,8).

### 3.9 Vigie : « Repli » (`RollDodge` à 3 charges, demande du joueur)
- **3 charges** (`DODGE_CHARGES`) de **1 u** chacune (`DODGE_U`) à 12 u/s (0,083 s d'i-frames par dash) : même distance et mêmes i-frames totales que la roulade. Une charge se régénère à la fois en **1 s** (3 s pour les trois). Un appui pendant un dash **relance tout de suite** dans la nouvelle direction (zigzag).
- Sans entrée de déplacement : elle rompt **à l'opposé de la visée** (curseur / l'avant) en gardant la cible en face ; au joystick, elle part où il pousse.
- Chaque dash achevé bande l'arc : **+8 % de Tension** (`DODGE_TENSION_GAIN`, +24 % pour les trois ; ≈ +0,08 Tension/s au plus contre +0,45/s en marche : un appoint). Fantômes rouge fusée. Pastilles de charges sur le bouton.

### 3.10 Taliant : « Iaï » (existant, `RollDodge`)
Dash tranchant inchangé (coef 1,5 à 0,9 u, 4 % d'aiguisage s'il touche, doublé sous Lames jumelles). Libellé « Iaï ».

---

## 4. Entrées et HUD

- **Tactile** : bouton d'esquive de la grappe (120 px, à droite des sorts). Toucher = `Input.action_press(&"dodge")`, lever = `action_release` (différé de 2 images si le tap est trop bref pour `is_action_just_pressed`). Direction = joystick, sinon l'avant. Libellé par personnage (initiale si l'icône manque), anneau de recharge, pastilles de charges (Vigie), grisé si interdit (vertige de Rictus, Bourbier, Averse sans eau).
- **Clavier-souris** : Maj gauche / Espace ; direction = ZQSD, sinon le curseur. Averse : maintien = glisse ; ZQSD la dirige, le curseur non.
- **Manette** : LB ; direction = stick gauche, sinon l'avant. Maintien pour Averse.
- **Barre PC** : même indicateur à droite de la barre de sorts (`bar_dodge`), touche affichée (`KeyPrompt`).

## 5. Contrat technique (implémenté)

- `game/scripts/player/dodge_move.gd` (`DodgeMove`, RefCounted, stratégie) : `make(player, kit, character)` (kit `make_dodge()` > `CharacterData.dodge_kind` > `RollDodge`), `can_start()`, `start(dir)`, `step(delta)`, `release()`, `tick(delta)`, `is_invulnerable()`, `is_hold()`, `allows_move()`, `progress_left()`, `duration_s()`, `distance_u()`, `ui_state()` {remaining, total, active, charges, max_charges, hold, label, kind}, `reset()`, `abort()`.
- Implémentations : `roll_dodge.gd` (`RollDodge` : distance via `Player.dodge_distance_u()`, vitesse `kit.dodge_speed_u()`, charges `kit.dodge_charges()`, fantômes, hooks), `blink_dodge.gd` (`BlinkDodge`, Ardent), `slide_dodge.gd` (`SlideDodge`, Averse : hooks `slide_speed_u`, `slide_can_start`, `slide_begin`, `slide_drain(delta)`, `slide_end(by_wall)`, `slide_trail(from, to)`).
- Hooks de kit (tous facultatifs) : `can_dodge`, `dodge_distance_u`, `dodge_speed_u`, `dodge_charges`, `dodge_cooldown_s`, `dodge_motion_dir(dir)`, `dodge_ghosts`, `dodge_ghost_color`, `dodge_label`, `dodge_sound() -> [id, dB, pitch]`, `on_dodge_start(dir)`, **`on_dodge_end(from, to)`** (nouveau), `make_dodge()`.
- `Player` : `dodge(dir)`, `dodge_release()`, `dodge_step(delta)` (tests), `reset_dodge()`, `dodge_move()`, `is_dodging()`, `is_invulnerable()`, `get_dodge_cooldown()`, `dodge_progress_left()`, `dodge_duration_s()`, `dodge_distance_u()`, `spawn_dodge_ghost(color, fade)`, `set_visual_alpha(a)`, `keep_walkable()` (public). Les champs privés `_dodge_cd` / `_dodge_left` n'existent plus (tests migrés sur `reset_dodge()` / `dodge_step()`).
- `CharacterData.dodge_kind` (`&""`/`&"roll"`, `&"blink"`, `&"slide"`).
- `DodgeButton` : maintien tactile, libellé, pastilles de charges.

## 6. Tests et protocole joueur

- `tests/dodge_test.tscn` : par personnage genre, distance, i-frames, recharge ; Vigie 3 charges + Tension + enchaînement ; Ardent et Rictus arrêtés devant un mur ; Averse maintien, eau consommée et arrêt à vide, contact ignoré, projectile encaissé, mur de face ; mode test recharge 0 ; changement de personnage. `tests/averse_test` (bloc Glissade), `avare_test`, `arpenteuse_*`, `test_mode_test`, `run_flow_test`, `spell_auto_aim_test`.
- **Protocole en mode test** (titre → « Mode test », TAB = panneau) : voir le rapport d'intégration ; par personnage, touche Maj, attendu = la ligne du tableau §2.

## 7. Leviers et risques

- **Averse** : si elle traverse les mêlées sans jamais payer, monter le drain (25 → 32/s) ou le coût de départ (10 → 15) avant de toucher l'immunité de contact ; si les tireurs la tuent en glisse, 0,15 → 0,25 s d'i-frames. Sur une carte sans pluie (Cryptes), ses flaques et l'eau de carte (drain ÷2) sont sa mobilité.
- **Vigie** : si le zigzag à 3 charges domine (0,25 s d'i-frames « à la carte »), passer la régénération à 1,2 s par charge.
- **Ardent** : un blink sans trait de liaison peut dérouter 2-3 fois ; parade : les deux gerbes + tip.
- **Bourbe** à 0,30 s : revenir à 12 u/s (0,25 s) si elle devient la plus sûre des mêléistes.
- Sons continus (chuintement d'Averse), anims `blink_out` / `blink_in` 8 directions d'Ardent, `slide` d'Averse, `flow` de Bourbe, `dodge_back` de Vigie : non produits en v2 (replis : fondu du sprite, `run`, fantômes).
