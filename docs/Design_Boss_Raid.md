# Boss façon raid : boîte à outils, trois nouveaux boss d'étage, variété des boss existants (design v1)

> Statut : **proposition de game design** (26/10/2026) répondant à la demande du joueur : « rajouter de la variété dans les sorts des boss ; créer 3 nouveaux boss d'étage inspirés des boss de raid de World of Warcraft, avec des interactions : à chaque nouvelle phase le boss devient invulnérable et il y a toujours une manière de le rendre vulnérable (ramasser les 3 boules qu'il jette, lancer son ultime, attendre 5 s) ; interactions avec le décor : il pose des piquets/pylônes qui protègent le joueur puis lance des centaines de projectiles pendant X secondes, le joueur doit se cacher derrière. »
> Aucun fichier de `game/` n'est modifié par ce document. Cohérent avec `Design_Etages.md` (roster, biomes, DA par biome), `Design_Boss_Cartes.md` §3 (fiches des boss existants), `Comportements_Monstres.md` (BossPace), `Maths_Scaling.md` / `balance.gd` (PV et dégâts des boss, enrage), `art/briefs/STYLE_cel.md` (rendu), `art/tools/night/_boss_agent_common.md` (contrat des agents boss).
> Propriété intellectuelle (GDD §13) : on s'inspire des **mécaniques** des raids (boucliers conditionnels, abris, zones à absorber, adds prioritaires, zones sûres, fixation, enrage), jamais des noms, créatures ni designs de WoW, RoR ou Vampire Survivors.

---

## 0. Résumé et règles dures

| Élément | Décision proposée |
|---|---|
| Boîte à outils | 8 mécaniques génériques codées **une fois** (`game/scripts/enemies/raid/`), paramétrées par dictionnaire, utilisables par tout cerveau de boss (`*_brain.gd`) et par les mini-boss pilotés par données plus tard |
| Nouveaux boss | **L'Idole noyée** (`drowned_idol`, étage 1 : rupture par **3 cloches à ramasser**), **Le Canonnier de crue** (`flood_gunner`, étage 3 : rupture en **tuant les soutiers**, pylônes-abris contre la Mitraille), **Le Roi de sel** (`salt_king`, étage 4 : rupture par **un coup d'ultime**, nef sèche qui tourne) |
| Boss existants | les 13 reçoivent une transition de phase **invulnérable avec condition** dans leur thème + 1 sort ou mécanique de la boîte, en 3 vagues de priorité (§3) |
| Production | 5 lots parallélisables (§4) : boîte à outils (Opus), 3 boss (Sonnet, placeholders), ajouts aux existants (Sonnet), consignes Codex écrites (`art/tools/night/_raid_*.txt`, groupes 52-55 de `queue.txt`), sons (`art/tools/audio/_raid_sfx.txt`) |

Règles dures (toutes mécaniques, tous boss) :
1. **Lisibilité mobile en paysage** : tout télégraphe ≥ 0,8 s (`Balance.BOSS_PACE_WINDUP` spell : 1,1 / 0,95 / 0,85 s par phase) ; les barrages, chutes de pylônes et transitions ≥ 1,2 s ; aucune forme au sol < 1,2 u de rayon ; un seul code couleur : rouge = dégâts, cyan/accent du biome = objet utile au joueur (orbe, abri, zone sûre), blanc = neutre. Hors écran : flèches `OffscreenCues` (lot UX A11y-L9) étendues aux orbes, pylônes et zones à absorber.
2. **Jamais de mort instantanée.** Chaque coup de boss garde le plafond existant (40 % des PV max par coup) ; une pénalité d'échec = dégâts plafonnés, ralentissement, soin du boss (≤ 10 % de ses PV), adds supplémentaires ou perte d'une fenêtre de dégâts. Un échec n'est **jamais** une condition de défaite.
3. **Toujours une sortie** : chaque bouclier a sa condition principale **et** un garde-fou temporel (`backstop_s`, 20-25 s) après lequel le bouclier tombe seul, sans la fenêtre de vulnérabilité bonus. Le joueur n'est jamais bloqué, seulement puni par le temps (la pression du director continue).
4. **Trois plateformes** : sur mobile les sorts 2-4 visent automatiquement (`SpellCaster._nearest_enemy`) et l'ultime peut se lancer **à la main** (bouton 4) ou en auto-cast ; aucune condition ne demande de viser un point précis à la main. Les objets à atteindre sont au sol (on marche dessus), les cibles à frapper sont dans le groupe `enemies` (le ciblage automatique les trouve), les abris sont des obstacles physiques (on se place derrière).
5. **Temps de combat** : un boss d'étage vise toujours ≈ 75 s en Moyen. Le temps passé sous bouclier **gèle l'horloge d'enrage** (`Balance.BOSS_ENRAGE_AFTER_S` = 90 s compte le temps vulnérable) et les boss à deux boucliers ont des PV × 0,9 (`Balance.BOSS_HP_MULT`, nouveau, voir §1.9).
6. **Perf mobile** : un barrage ne dépasse jamais 160 projectiles vivants (`Director.PROJECTILE_POOL` = 220, le reste pour les tireurs) ; les abris sont ≤ 6 obstacles dynamiques `NavField` à la fois ; aucune mécanique n'ajoute de lumière dynamique au-delà des plafonds par palier (`Direction_Lumiere_Ambiance`).

---

## 1. Boîte à outils des mécaniques de raid

Chaque mécanique est un nœud ou un `RefCounted` sous `game/scripts/enemies/raid/`, créé par le cerveau du boss (sous le parent du boss, coordonnées logiques, comme `WeaverSnare` / `CraneYard` / `RecluseGloom`), détruit par `brain.clear()` ou conservé comme trace jusqu'à la fin de la charge (`keep_until_charge()`). Les formes provisoires passent par `RecluseFx` tant que Codex n'a pas livré les extras ; **tous les visuels finaux sont rendus dans Blender** (lot `_raid_kit.txt`, §4.d).

### 1.1 Bouclier de phase (`BossShield`) et conditions de rupture (`BreakCondition`)

**But** : à chaque seuil de phase (`Balance.BOSS_PHASE_THRESHOLDS`), le boss devient invulnérable, met en scène sa transition, puis le joueur doit remplir une condition pour le rendre vulnérable. La rupture ouvre une **fenêtre de vulnérabilité** bonus (le boss sonné, +30 % de dégâts reçus pendant 2-3 s) : la récompense de la mécanique réussie.

Déroulé commun (en s) :
| Étape | Durée | Détail |
|---|---|---|
| Transition | 0,9 (anim `trans_pN`, 8 frames à 12 fps + 0,25) | boss figé, coups annulés (`pace.cancel()`), `Events.boss_shield_changed(boss, true, kind)` |
| Mise en place | 1,0-1,5 | l'objet de la condition apparaît (orbes jetées, adds qui sortent, cristaux qui s'éteignent…), télégraphé ; le boss ne frappe pas |
| Bouclier actif | jusqu'à la rupture, `backstop_s` max (20-25) | `is_invulnerable()` vrai (barre : **INVULNÉRABLE** + étiquette de progression « CLOCHES 1/3 ») ; le boss garde **un seul sort lent** (cadence 4 s, jamais le plus lourd) ; le director continue (la pression vient de la foule) |
| Rupture | 0,5 | éclat, son `enemy.<boss>_shield_break.heavy`, `Events.boss_shield_changed(boss, false, kind)` |
| Fenêtre | 2,0-3,0 | état `exposed` (barre : liseré chaud qui pulse), `damage_taken_mult()` × 1,3 ; puis la phase suivante commence |
| Garde-fou | à `backstop_s` | le bouclier tombe **sans** fenêtre ; message HUD « Le bouclier cède » ; aucune autre pénalité |

Conditions (`BreakCondition.Kind`), chacune avec ses paramètres, son télégraphe et sa pénalité d'échec :

| Kind | Paramètres | Comment le joueur comprend | Échec / pénalité | Plateformes |
|---|---|---|---|---|
| `ORBS` (ramasser) | `count` 3-4, `throw_r_u` 5-8, `spread_deg` 120, `life_s` = backstop, `pickup_u` 0,8 | les orbes sont jetées avec un cercle de chute 1,5 u (1,0 s, coef 0,8 si dessous), roulent, puis brillent à l'accent du biome avec une flèche hors écran ; compteur sous la barre | orbe tombée dans l'eau peu profonde = ralentissement en allant la chercher ; backstop | marche au contact (`GroundPickup`, contact `pickup_u`), aucune visée |
| `ULTIMATE_HIT` (coup d'ultime) | `hits` 1 (ou 2 à la 2e transition), `backstop_s` 20 | la croûte porte des fissures « vides » ; étiquette « FRAPPEZ AVEC L'ULTIME » et l'icône du sort 4 pulse sur le HUD ; dès que l'ultime touche, fissure totale | ultime en recharge : attendre (20 s max) ; chaque coup lourd (≥ 20 % du meilleur coup du joueur) fissure visuellement sans compter | mobile : bouton 4 à la main ou auto-cast (`auto_cast_enabled`) ; PC/manette : touche ou clic molette |
| `TIMER` (attendre) | `s` 5-8 | une jauge circulaire vide sur le boss ; le boss **attaque pendant ce temps** (c'est la vraie épreuve : survivre) | aucun ; c'est la condition « attendre 5 s » demandée | toutes |
| `KILL_ADDS` (tuer des adds) | `count` 2-3, `add_hp_frac` 0,06-0,08 des PV du boss, `walk_u` 2,0, `heal_frac` 0,10 si un add atteint le boss | adds marqués (halo de l'accent + flèche hors écran, `aim_priority` 2) ; ils marchent lentement vers le boss | add arrivé = boss soigné de 10 % (une fois par add) ; quand tous les adds sont morts **ou** consommés, le bouclier tombe (consommés : sans fenêtre) | le ciblage automatique privilégie `aim_priority` (contrat §1.9) |
| `WEAK_POINT` (frapper un point faible) | `points` 1-2, `hp_frac` 0,05 chacun, `offset_u` (dos, flancs), `exposed_arc_deg` 120 | nœud `WeakPoint` dans le groupe `enemies` (ciblage auto), cristal/valve qui brille ; le point est **hors du cône frontal** du boss : contourner | aucun soin ; backstop | ciblage automatique du plus proche : le point faible est posé **plus près** du joueur que le centre du boss quand le joueur est dans l'arc exposé |
| `SOAK` (zones à absorber) | `zones` 1-4, `r_u` 2,5, `hold_s` 1,5, `order` libre | cercles cyan au sol qui se remplissent quand le joueur est dedans (jauge dans le cercle) | zone non remplie à `backstop_s` : aucune ; zone qui « déborde » (optionnel) : adds | marche |
| `INTERACT` (rallumer, actionner) | `props` 2-3, `hold_s` 0,6, action `interact` | props du décor allumés en cyan avec l'invite d'interaction (pilule `InteractButton`, lot Choix-L8) | backstop | bouton Interagir (tactile), touche E / A manette |

Combinaison : `[{kind, …}, {kind: TIMER, s: backstop}]` ; la première remplie gagne. Une condition peut être répétée **plus dure** à la 2e transition (4 orbes, 3 adds, 2 coups d'ultime).

**Retours** : son d'armement `enemy.<boss>_shield_up.heavy`, bourdon de bouclier en boucle (`enemy.shield_hum.loop`, −18 dB, coupé à la rupture), chaque progrès = `ui.raid_progress` (tintement montant, 3 hauteurs), rupture = `enemy.<boss>_shield_break.heavy` + flash `LightRig.flash` à l'accent du biome + haptique `BOSS_IMPACT`. La barre de boss (`BossHealthBar`) affiche l'étiquette `{text, color, kind: &"shield", progress}` (§1.9).

### 1.2 Abri et barrage (`ShelterPylon`, `BarrageEmitter`)

**But** : la demande du joueur. Le boss **plante des pylônes** qui protègent, puis **lance des centaines de projectiles pendant X secondes** ; le joueur se cache derrière.

`ShelterPylon` (obstacle-abri) :
- Pose : télégraphe de chute 0,9 s (cercle 1,2 u, coef 0,8 si le joueur est dessous : on ne se fait pas écraser par surprise), puis `StaticBody2D` couche 1 (monde) de rayon 0,5 u + `NavField.add_circle_obstacle` (les monstres le contournent) + **segment d'ombre** : derrière le pylône, un couloir de 1,0 u de large est protégé des projectiles ennemis (`EnemyProjectilePool.cull_segments` étendu à une liste de **disques** `cull_circles`, et pour un barrage orienté, à l'ombre projetée : segment de 1,0 u × 6 u dans l'axe boss → pylône).
- Placement : 3-4 pylônes à 4-6 u du joueur, répartis à ≥ 90° entre eux, jamais à < 2 u d'un mur (sinon ramenés `nav.resolve`).
- Vie : 12-16 s ; **PV** 4 % des PV du boss (un obus du boss ou 20 projectiles de barrage les abîment : 3 états visuels `pylon_ok / pylon_cracked / pylon_broken`) : un abri n'est pas éternel, le joueur doit changer de pylône.
- Lisibilité : lampe à l'accent du biome au sommet ; l'ombre protégée est **dessinée au sol** (bande cyan translucide 1,0 u de large, opacité 0,35) pendant tout le barrage : on voit où se mettre.
- Plafond : 6 pylônes vivants (les plus vieux cassent).

`BarrageEmitter` (le barrage) :
- Télégraphe **1,5 s** : cône rouge (angle du barrage) + sirène `enemy.<boss>_volley_warn.heavy` + le boss arme son anim de boucle ; les pylônes doivent être posés **≥ 2,5 s avant** (le cerveau refuse un barrage sans ≥ 2 pylônes vivants : il en plante d'abord).
- Émission : `rate` 24-30 projectiles/s, `duration_s` 5-6, `arc_deg` 120 (P1) ou 2 cônes de 60° qui tournent à 45°/s (P2+ : les abris comptent de tous les côtés), vitesse 9 u/s, portée 14 u, rayon 9 px (`EnemyProjectilePool.RADIUS_PX`), **plafond 160 vivants** (à 30/s et 4 s de vie : 120).
- Dégâts : **coef 0,2 par projectile**, immunité par source 0,35 s (`Player` : `hit_cooldown_per_source`) : exposé en continu = 0,57 coef/s, soit 3,4 coef sur 6 s = **43 % des PV d'un joueur de l'étage 1 sans aucun objet** ; abrité = 0. Pas de mort instantanée, forte incitation.
- Variante tournante (P3) : 2 cônes de 60° qui tournent à 20°/s en continu, « rechargement » de 2 s toutes les 8 s (le canon fume, aucune émission) = fenêtre pour changer d'abri.
- Perf : un seul passage `EnemyProjectilePool.update` par frame déjà centralisé ; les projectiles abrités sont tués au passage (`cull_segments` / `cull_circles`), jamais testés individuellement contre la physique.

### 1.3 Zones à absorber (`SoakZone`)

**But** : des cercles qu'il faut **occuper** (seul ou à tour de rôle) avant leur échéance, sinon pénalité. Inversion de la grammaire « cercle rouge = fuir ».
- Paramètres : `r_u` 2,5-3,0, `life_s` 4-6, `hold_s` 1,5 (jauge qui se remplit, se vide à moitié de vitesse quand on sort), `count` 1-4, `spacing_u` ≥ 5.
- Télégraphe : cercle **cyan** (jamais rouge), jauge circulaire intérieure, flèche hors écran ; libellé court au-dessus (« ABSORBER ») la première fois par run (onboarding).
- Échec (zone non remplie à `life_s`) : la zone **éclate** : anneau rouge 1 → 5 u télégraphé 1,0 s, coef 1,0, **ou** 4 monstres de tier 1 ; jamais les deux.
- Usage : condition de bouclier (§1.1 `SOAK`), appât d'un boss (Anguille), vidange d'une crue (Semeur).

### 1.4 Adds prioritaires (`PriorityAdds`)

**But** : des serviteurs à tuer **avant** un délai, sinon ils renforcent le boss. Le joueur doit détourner son DPS.
- Spawn par `Director.spawn_enemy(tier, pos)` avec surcharge de skin (`EnemyVisual.set_skin_frames(frames, prefix)`, contrat §1.9) ; PV `add_hp_frac` (6-8 % du boss), vitesse 2,0 u/s, pas de coup propre (ils marchent, c'est tout) ; `aim_priority` = 2 pour le ciblage automatique.
- Lisibilité : halo de l'accent + liseré clignotant 2 Hz + ligne pointillée au sol vers le boss (leur trajet) + compteur sous la barre.
- Échec : add au contact du boss → soin 10 % (une fois par add, plafond 20 % par transition) ou +10 % de vitesse d'attaque jusqu'à la fin de la phase (au choix du boss).
- Plafond : 3 adds à la fois.

### 1.5 Zone sûre qui tourne (`SafeSector`)

**But** : toute l'arène devient dangereuse **sauf un secteur** qui tourne ; le joueur suit la zone sûre.
- Paramètres : `radius_u` = zone de charge (9 u, `Pillar.BIG_ZONE_RADIUS`), `sector_deg` 90 (P1) → 60 (P2+), `turn_deg_s` 30 → 40, `duration_s` 6-8, `tick` 0,5 s, coef 0,4 par 0,5 s + ralentissement −30 % hors du secteur.
- Télégraphe : 1,2 s avant : le secteur sûr apparaît en **cyan** au sol (coin de camembert), le reste s'assombrit en rouge translucide ; une flèche sur le bord montre le sens de rotation. Jamais plus vite que la vitesse du joueur : à 9 u de rayon, 40°/s = 6,3 u/s au bord, le joueur (4 u/s) doit rester **à moins de 5,7 u du centre** pour suivre : lisible et voulu (on se rapproche du boss).
- Échec : dégâts plafonnés + ralentissement ; jamais plus.
- Répit : toutes les 8 s, 2 s sans rotation.

### 1.6 Fixation (`FixateMark`)

**But** : le boss **cible un endroit** (la position du joueur à l'armement, ou un point du décor) et y déclenche une action longue : le joueur a le temps de ne pas y être, ou doit au contraire y revenir.
- Paramètres : `lock_s` 1,0 (le point se fige, marqueur « X » qui tourne), `action` (roue, rayon, pluie), `duration_s` 2-3, `radius_u` 1,5-4.
- Lisibilité : marqueur blanc puis rouge au sol, ligne pointillée boss → point ; libellé « FIXE » sur la barre.
- Cas d'usage : l'Idole (Noria), la Pompe aveugle (déjà « dernière position connue »), l'Anguille (appât).

### 1.7 Point faible (`WeakPoint`)

**But** : une sous-cible hors du cône frontal (dos, flancs, couronne flottante) dont les dégâts sont **transférés ×2** au boss ou qui conditionne la rupture.
- Nœud `Area2D` couche 3 (`enemies`) dans le groupe `enemies` (ciblage auto et sorts le touchent), `hp_frac` 0,05, `offset_u` par rapport au boss et `exposed_arc_deg` : actif seulement quand le joueur est dans cet arc (sinon « gardé », sans halo).
- Lisibilité : cristal/valve qui brille (accent), anneau cyan de 0,8 u ; quand le joueur est dans l'arc, la silhouette du point passe en **plein**, sinon en pointillés.
- Transfert : `take_damage` du point → `boss.take_damage(amount × 2, …, {"weak": true})`.

### 1.8 Enrage doux (`SoftEnrage`)

L'enrage existant (`Balance.BOSS_ENRAGE_AFTER_S` 90 s, +1,5 %/s) reste. Ajouts :
- l'horloge **ne compte que le temps vulnérable** (gelée sous bouclier et en transition) ;
- **avertissement à 75 s** : la barre de boss se teinte, le boss grogne (`enemy.<boss>_enrage_warn.heavy`), pulsation de l'accent ; à 90 s : « ENRAGÉ » + liseré rouge ;
- l'enrage n'accélère **jamais** les télégraphes sous 0,85 s ni les récupérations (`BossPace`) : seule la cadence et les dégâts montent.

### 1.9 Contrat technique attendu (sans coder)

Fichiers (nouveaux, lot (a)) : `game/scripts/enemies/raid/boss_shield.gd` (`class_name BossShield`), `break_condition.gd`, `raid_orb.gd` (étend `GroundPickup`, kind `&"raid_orb"`), `shelter_pylon.gd`, `barrage_emitter.gd`, `soak_zone.gd`, `priority_adds.gd`, `safe_sector.gd`, `fixate_mark.gd`, `weak_point.gd`, `raid_fx.gd` (formes provisoires, même rôle que `RecluseFx`), test `game/tests/raid_kit_test.tscn`.

Duck typing attendu par `Enemy` (déjà en place) : `brain.is_invulnerable()` → `shield.active` ; `brain.damage_taken_mult()` → 0 sous bouclier, × 1,3 pendant la fenêtre ; `brain.boss_state_tag()` → `{text, color, kind, progress}` avec un **nouveau kind `&"shield"`** (barre : remplissage gris acier + jauge de progression `progress` 0-1 sous le texte ; `&"exposed"` existant pour la fenêtre).

Ajouts partagés (orchestrateur) :
- `Events` : `boss_shield_changed(boss: Node2D, active: bool, kind: StringName)`, `boss_shield_progress(boss: Node2D, done: int, total: int)`, `raid_mechanic_failed(boss: Node2D, kind: StringName)`, `raid_barrage(boss: Node2D, active: bool)` (musique : ducking et couche « tension » pendant un barrage).
- `Balance` : `BOSS_HP_MULT := {&"drowned_idol": 0.9, &"flood_gunner": 0.9, &"salt_king": 0.9}` (appliqué dans `boss_hp()` par `boss_id`), `BOSS_SHIELD_BACKSTOP_S := 25.0`, `BOSS_SHIELD_EXPOSED_MULT := 1.3`, `BOSS_SHIELD_EXPOSED_S := 2.5`, `RAID_BARRAGE_COEF := 0.2`, `RAID_BARRAGE_IFRAME_S := 0.35`, `RAID_SOAK_FAIL_COEF := 1.0`, `RAID_ADD_HEAL_FRAC := 0.10`, `RAID_SECTOR_TICK_COEF := 0.4`, `BOSS_ENRAGE_WARN_S := 75.0` ; `boss_enrage_mult(fight_time_s)` reçoit le temps **vulnérable** (le cerveau soustrait ses boucliers).
- `SpellCaster._nearest_enemy` : pondération `aim_priority` (propriété optionnelle de l'ennemi, défaut 1 ; distance divisée par la priorité) pour que les adds prioritaires et les points faibles soient visés en auto.
- `Enemy` : `aim_priority: float` ; `take_damage(…, hit)` : `hit["slot"]` et `hit["spell_id"]` renseignés par `SpellCaster` (ligne 543) pour la condition `ULTIMATE_HIT` (`slot == ArdentKit.ULTIMATE_SLOT`) ; `hit["weak"]`.
- `EnemyVisual.set_skin_frames(frames: SpriteFrames, prefix: StringName)` : un add utilise les extras `stoker_*` du `.tres` du boss (pas de nouveau dossier mini).
- `EnemyProjectilePool.cull_circles(centers, radii)` et `cull_shadows(origin, pylons, half_w)` (ombre des pylônes dans l'axe du boss) ; `Player.hit_cooldown_per_source(source, s)` pour l'immunité de 0,35 s par barrage.
- `BossHealthBar` : kind `&"shield"` + `progress` ; `OffscreenCues` : catégorie `raid` (orbes, pylônes, zones) ; `InteractButton` : props `INTERACT` (déjà le contrat du téléporteur et des plaques).
- `Audio` : ids listés par boss (§2) et génériques `enemy.shield_hum.loop`, `ui.raid_progress`, `enemy.raid_barrage_warn.heavy`, `enemy.raid_soak_fill.light`, `enemy.raid_soak_burst.heavy`.
- Sauvegarde : un boss sous bouclier n'est pas sauvegardé à mi-combat (la run se sauvegarde entre les étages, inchangé).

Tests : `raid_kit_test` (chaque mécanique en isolation : rupture par chaque condition, backstop, abri qui tue les projectiles, soak réussi/raté, secteur qui tourne sans dépasser 6,3 u/s au bord, fixation qui se fige, point faible gardé/exposé, enrage gelé sous bouclier), puis `<id>_boss_test` par boss (séquence des 3 phases, 2 boucliers, durée ≈ 75-90 s en Moyen avec le joueur de référence du simulateur), `floor1/3/4_boss_test`, `sprites_test`, `biome_fauna_test`, `integration_test`.

---

## 2. Trois nouveaux boss d'étage

### 2.0 Choix des étages : 1, 3 et 4

- **Étage 1 (Terrasses noyées)** : vu à chaque run ; c'est là qu'on **apprend** la grammaire des raids avec la condition la plus simple (ramasser). Ses 3 boss sont livrés (Éclusier, Bouvier, Porteuse) : un 4e tire la rotation à 25 % chacun, le joueur voit le nouveau boss dès ses premières runs.
- **Étage 3 (Cité de rouille)** : les pylônes de paratonnerre et la mitraille d'automate sont le biome industriel incarné ; le joueur a 20+ objets, un barrage de 6 s se lit comme un « check » de survie et de placement.
- **Étage 4 (Cryptes noyées)** : la condition « coup d'ultime » tombe quand les ultimes sont montés (niveau 12-16, variantes débloquées) ; le biome sans soleil rend la croûte de sel et la nef sèche très lisibles (seules lumières). L'étage 4 n'a que 2 boss avec sprites (`recluse`, `crystal_mother` ; l'Anguille en cours) : un 4e boss y pèse plus.
- **Étage 2 (Forêt-brume)** écarté : ses 3 boss sont les plus récents et complets (Cerf, Tisseuse, Cèdre), et sa variété vient déjà des pièges (fils, toile, racines) ; il reçoit ses mécaniques de raid par §3.

Fiche commune : boss d'étage (`kind` `etage`), PV `Balance.boss_hp(&"etage", D, stage) × 0,9`, Dég_base 28 (+20 %/niveau ambiant), seuils 70 / 35 % (`BOSS_PHASE_THRESHOLDS`), BossPace standard (auto / spell / heavy / charge), plafond 40 % par coup, trace après la mort jusqu'à la fin de la charge, cel-shade `STYLE_cel.md` profil `boss`, cellule 256 × 256, 4 directions `e, s, w, n`, frame d'impact à la moitié de l'anim, un seul accent émissif du biome.

### 2.1 L'Idole noyée (`drowned_idol`) : étage 1, Terrasses noyées

**Identité** : statue votive des rizières, à qui l'on offrait des cloches de bronze pour appeler la pluie. Les pluies sont venues. Elle continue de sonner.

**Silhouette pour Codex** (3,6 u, le socle compris) : idole de pierre grise moussue (`#4A5B5A` → `#8A9A92`, jamais plus sombre que L\* 60), **agenouillée sur un socle de lotus** de pierre qui glisse sur l'eau des rizières (pas de jambes visibles : le socle laisse un sillage) ; torse creux où tourne une **roue de prière de bronze** (bronze vert-de-gris `#8C7A4C` / `#5F8F80`) ; **3 cloches de bronze** pendues à des sangles de cuir (2 aux épaules, 1 à la nuque), bien visibles et asymétriques (tailles différentes) ; visage lisse sans traits, les deux orbites **pleurent une eau cyan** (`#5EC8FF`, seul accent émissif : deux coulées lumineuses + l'eau qui s'accumule dans les mains jointes) ; mains jointes devant la poitrine qui s'ouvrent pour frapper. Usure : mousse dans les plis, lichen, cordes pourries, une cloche fêlée. Phases visibles : **p1** mains jointes, roue lente ; **p2** sans ses cloches (sangles qui pendent, vides), roue rapide, eau des orbites plus abondante ; **p3** socle fendu et **ancrée** (racines de lotus de pierre qui plongent dans l'eau), torse ouvert, roue à nu qui projette de l'eau. 2,2 u/s.

**Phases et sorts** (coefs `Balance.BOSS_ATTACK_COEF[&"drowned_idol"]`) :

| Phase | Auto | Sort A | Sort B | Mécaniques |
|---|---|---|---|---|
| **P1 « Offrande »** (100-70 %) | **Paume** : cône 90° de 3 u, toutes les 1,8 s, coef 1,0 (`palm`) | **Carillon** : 3 anneaux concentriques (rayons 3 / 6 / 9 u, épaisseur 0,8 u) télégraphiés ensemble 1,0 s puis déclenchés à 0,5 s d'intervalle, coef 1,2 (`carillon`), recharge 10 s ; les couloirs **entre** les anneaux sont sûrs | **Chapelet** : 5 cercles de 2 u alignés du boss vers le joueur (le dernier sur lui), allumés l'un après l'autre (0,25 s), chacun 1,0 s, coef 1,3 (`chaplet`), recharge 9 s | — |
| **Transition 2 « Les trois cloches »** (70 %) | **Bouclier** `ORBS` count 3 : les mains se joignent, une bulle d'eau enveloppe l'idole ; les 3 cloches sont **jetées** à 5-8 u, à 120° l'une de l'autre (cercles de chute 1,5 u, 1,0 s, coef 0,8), roulent 1 s puis s'arrêtent, brillent cyan. Chaque cloche ramassée (contact 0,8 u) **revient sonner sur l'idole** (trait lumineux, `enemy.idol_bell_ring.medium`, compteur « CLOCHES 1/3 »). 3/3 → bulle crevée, idole **sonnée 2,5 s** (+30 %). Sous bouclier : seulement le Chapelet, toutes les 4 s. Backstop 25 s. Une cloche sur deux tombe **dans une rizière inondée** (`,`) : le joueur y est ralenti −20 % (lecture du terrain). |
| **P2 « Mousson »** (70-35 %) | Paume | **Carillon** à 4 anneaux (2,25 / 4,5 / 6,75 / 9 u) | **Digues** (interaction décor) : 2 murets de terre de 1 × 4 u jaillissent des rizières (télégraphe 1,0 s, coef 0,6 si dessus), obstacles 8 s qui **bloquent le joueur ET arrêtent les anneaux du Carillon** (ombre d'abri 1,0 u derrière, §1.2 `cull_shadows`) : se placer derrière une digue protège du Carillon | **Noria** (fixation, §1.6) : l'idole fixe la position du joueur (1,0 s, marqueur), une roue d'eau s'y plante et fait tourner une pale de 1,5 × 8 u sur 180° en 2 s (télégraphe continu), coef 0,5 par 0,5 s (`noria`), recharge 12 s |
| **Transition 3 « Les quatre cloches »** (35 %) | Bouclier `ORBS` count 4 (les 3 cloches + la cloche fêlée de la nuque, qui tombe **la plus loin**, 8 u) ; backstop 25 s ; fenêtre 2,5 s. |
| **P3 « Crue de prière »** (35-0 %) | Paume | **Carillon continu** : un anneau part de l'idole toutes les 2,5 s (3 → 9 u en 1,2 s, télégraphe 0,9 s), coef 1,0 ; Digues ×3 | **Ancrée** sur son socle fendu (immobile jusqu'à la mort, +20 % de dégâts reçus, `BOSS_PHASE_DAMAGE_TAKEN`), Noria ×2 (deux roues), Chapelet en spirale (6 cercles) |

Coefs : `palm` 1,0 ; `carillon` 1,2 ; `chaplet` 1,3 ; `bell_drop` 0,8 ; `dike` 0,6 ; `noria` 0,5 (par 0,5 s) ; `ring_p3` 1,0. Recharges P2 × 0,9, P3 × 0,8. Trace après la mort : digues et roues de noria restent jusqu'à la fin de la charge.
**Contre-jeu** : Carillon = rester dans un couloir ou derrière une digue ; cloches = aller les chercher dans l'ordre « terre d'abord, eau ensuite » ; Noria = ne pas rester où l'on était. **Met à l'épreuve** : mobilité et lecture du terrain (eau), mono-cible pendant les fenêtres sonnées. Durée visée : 85 s dont ≈ 18 s de boucliers.

**Animations** (format `fauna.json` `boss_sprites.drowned_idol`, dir `etage/drowned_idol`, floor true, dim 250,88, fh ≈ 330, cadre 256 ; `brain` `scripts/enemies/drowned_idol_brain.gd` ; `brief` `art/tools/night/_raid_drowned_idol.txt`) :
`anims` : `idle_p1_e/s/w/n`, `idle_p2_*`, `idle_p3_*`, `walk_p1_*`, `walk_p2_*`, `walk_p3_*` (glisse sur le socle, sillage), `auto_*` (6 fr, paume, impact 3), `spell_a_*` (8 fr, carillon : la roue s'emballe, impact 4), `spell_b_*` (8 fr, chapelet / digues / noria : mains ouvertes vers l'avant, impact 4), `shield_s` (8 fr boucle : mains jointes, bulle), `throw_s` (8 fr : jette les cloches, impact 4), `stun_s` (6 fr boucle : sonnée, roue arrêtée), `trans_p2_s`, `trans_p3_s`, `death_s` (10 fr : la roue s'arrête, les orbites se tarissent en dernier).
`extras` : `bell` (billboard 96 × 128, cloche de bronze posée, 8 fr boucle : lueur cyan qui pulse ; `_e`), `bell_roll` (sol 64 × 64, 6 fr), `bell_return` (billboard 128 × 256, trait d'eau lumineux montant, 6 fr), `carillon_ring` (sol 1152 × 1152, anneau de rayon extérieur 576 px, 8 fr boucle : la roue d'eau ; le code l'étire au rayon de chaque anneau), `chaplet_circle` (sol 256 × 256, cercle d'offrande de 2 u, 6 fr), `dike` (billboard 256 × 160, muret de terre 1 × 4 u, 2 états × 6 fr : intact, qui s'effrite), `dike_rise` (billboard 256 × 192, 6 fr), `noria_wheel` (sol 512 × 512, roue + pale de 8 u vers +x, 8 fr boucle), `noria_mark` (sol 128 × 128, marqueur de fixation, 6 fr), `water_bubble` (billboard 288 × 320, bulle d'eau qui enveloppe le boss, 8 fr boucle, `_e`), `bubble_burst` (billboard 320 × 320, 6 fr), `lotus_crack` (sol 256 × 256, socle fendu et racines, P3, 6 fr boucle).

**Sons** (Codex audio, ids `enemy.*`) : `enemy.idol_palm.medium`, `enemy.idol_carillon_warn.heavy` (la roue s'emballe), `enemy.idol_carillon.heavy` (anneau), `enemy.idol_chaplet.light` (×5, hauteur montante), `enemy.idol_bell_throw.medium`, `enemy.idol_bell_ring.medium` (cloche rendue, 3 hauteurs), `enemy.idol_shield_up.heavy` (bulle), `enemy.idol_shield_break.heavy`, `enemy.idol_stun.loop`, `enemy.idol_dike.medium`, `enemy.idol_noria.loop` (roue d'eau), `enemy.idol_anchor.heavy` (socle qui se fend), `enemy.idol_death.heavy`.

### 2.2 Le Canonnier de crue (`flood_gunner`) : étage 3, Cité de rouille

**Identité** : automate d'artillerie des digues de la Cité, qui tirait des rivets dans les fissures des barrages pour les colmater. Il colmate toujours : il tire sur tout ce qui bouge.

**Silhouette pour Codex** (3,7 u) : **tripode** de fer rouillé (`#6B3A22`, `#2B2A29`, laiton `#A8946E`), trois pattes-vérins griffues ; torse = **barillet** rotatif de rivets (cylindre riveté, lourd, qui tourne pendant la Mitraille), canon court sous une tête-lampe (**œil-lampe au sodium `#FF9A3C`**, seul accent émissif, avec le foyer de la chaudière à l'arrière) ; chaudière verticale dans le dos avec une **trappe** d'où sortent les soutiers ; sur les flancs, des **pylônes de paratonnerre** rangés en carquois (4 tiges, c'est lui qui les plante). Usure : coulures de rouille, plaques de blindage dépareillées, vapeur qui fuit des joints. Phases : **p1** blindage fermé, carquois plein ; **p2** blindage ouvert sur la chaudière rouge, carquois à moitié ; **p3** **ancré** sur ses trois pattes plantées (patins), canon dressé, barillet à nu, foyer blanc. 2,0 u/s.

**Phases et sorts** (coefs `Balance.BOSS_ATTACK_COEF[&"flood_gunner"]`) :

| Phase | Auto | Sort A | Sort B | Mécaniques |
|---|---|---|---|---|
| **P1 « Salve »** (100-70 %) | **Culasse** : un rivet lourd (projectile 0,8 u, 11 u/s, ligne 1 × 8 u télégraphiée 0,6 s), toutes les 2,0 s, coef 1,0 (`breech`) | **Pylônes** (§1.2 `ShelterPylon`) : plante 3 pylônes à 4-6 u du joueur (chute 0,9 s, coef 0,8 dessous, `pylon_drop`), vie 14 s, PV 4 % du boss | **Mitraille** (§1.2 `BarrageEmitter`) : télégraphe 1,5 s (cône rouge 120° + sirène), puis **5 s à 24 projectiles/s** en éventail de 120° qui balaie ±30°, 9 u/s, coef 0,2 chacun (`volley`), immunité 0,35 s par projectile ; **refusée s'il n'y a pas ≥ 2 pylônes vivants** (il les plante d'abord : la séquence Pylônes → 2,5 s → Mitraille est garantie), recharge 14 s | L'ombre protégée des pylônes est dessinée au sol pendant le barrage |
| **Transition 2 « Surchauffe »** (70 %) | **Bouclier** `KILL_ADDS` count 2 : les plaques de blindage se referment (invulnérable), la chaudière siffle, **2 soutiers** sortent de la trappe (automates de 2,0 u, pelle et seau de charbon, PV 7 % du boss, 2,0 u/s, aucun coup propre, `aim_priority` 2) et marchent vers 2 « bouches à charbon » posées à 6 u du boss (props télégraphiés) puis reviennent le nourrir : soutier au contact du boss = **+10 % PV** et le soutier disparaît. 2 soutiers tués → plaques qui sautent, le Canonnier **purge sa vapeur 3 s** (exposé, +30 %). Backstop 25 s (ou 2 soutiers consommés : bouclier tombé sans fenêtre). Sous bouclier : Culasse seulement, toutes les 3 s. |
| **P2 « Rafale »** (70-35 %) | Culasse | **Pylônes ×4** | **Mitraille tournante** : 2 cônes de 60° opposés qui tournent à 45°/s pendant 6 s (les abris comptent de tous les côtés : il faut tourner autour du pylône avec le cône) | **Obus** (interaction décor) : cercle de 3 u sur le joueur, télégraphe 1,2 s, coef 1,6 (`shell`), recharge 8 s ; un obus qui tombe sur un pylône le **casse** (état `pylon_broken`, plus d'abri) : l'Obus vise le pylône le plus proche du joueur une fois sur deux, pour forcer à changer d'abri |
| **Transition 3 « Chaudière crevée »** (35 %) | Bouclier `KILL_ADDS` count 3 (3 soutiers, 6 % du boss chacun, +8 % PV si consommés) ; backstop 25 s ; purge 3 s. |
| **P3 « Déluge de fer »** (35-0 %) | Culasse ×2 (deux rivets à ±15°) | **Pylônes ×3** toutes les 10 s | **Mitraille continue** : 2 cônes de 60° à 20°/s **en permanence** (télégraphe continu rouge), **rechargement de 2 s toutes les 8 s** (le canon fume : fenêtre pour changer d'abri, « RECHARGE » sur la barre) | **Ancré** (immobile, +20 % de dégâts reçus) ; Obus toutes les 5 s |

Coefs : `breech` 1,0 ; `pylon_drop` 0,8 ; `volley` 0,2 (par projectile) ; `shell` 1,6 ; `stoker_feed` 0 (soin). Trace après la mort : les pylônes restent (abris contre les tireurs du director) jusqu'à la fin de la charge.
**Contre-jeu** : compter ses pylônes, se mettre dans l'ombre dessinée, changer d'abri à chaque Obus et pendant les rechargements ; tuer les soutiers **loin** du boss (ils marchent lentement, un sort de zone suffit) ; profiter de la purge. **Met à l'épreuve** : placement, zone (soutiers), projectiles perforants (à travers un cône de rivets, les perforants du joueur passent ; les rivets, eux, meurent sur les pylônes). Durée visée : 85 s dont ≈ 16 s de boucliers.

**Animations** (`boss_sprites.flood_gunner`, dir `etage/flood_gunner`, dim 250,88, fh ≈ 340 ; `brain` `scripts/enemies/flood_gunner_brain.gd` ; `brief` `art/tools/night/_raid_flood_gunner.txt`) :
`anims` : `idle_p1_e/s/w/n`, `idle_p2_*`, `idle_p3_*`, `walk_p1_*`, `walk_p2_*` (tripode qui martèle), `walk_p3_*` (= idle_p3, ancré), `auto_*` (6 fr, culasse, impact 3), `spell_a_*` (8 fr, plante un pylône : tige tirée du carquois et enfoncée, impact 4), `spell_b_*` (8 fr, Mitraille : le barillet se lance, impact 4), `volley_loop_*` (6 fr boucle, 4 dirs : barillet qui tourne et canon qui recule, pendant le barrage), `shell_s` (8 fr, obus : canon dressé, impact 4), `shield_s` (8 fr boucle : blindage fermé, chaudière qui siffle), `vent_s` (8 fr boucle : purge de vapeur, exposé), `trans_p2_s`, `trans_p3_s` (pattes plantées, canon dressé), `death_s` (10 fr : les pattes cèdent, la chaudière crève).
`extras` : `pylon` (billboard 128 × 224, pylône de paratonnerre de 1 u, 3 états × 6 fr boucle : `pylon_ok`, `pylon_cracked`, `pylon_broken` ; lampe sodium au sommet, `_e`), `pylon_drop` (billboard 128 × 320, 6 fr : la tige tombe et se plante), `shelter_shadow` (sol 128 × 384, bande d'ombre protégée 1 × 6 u vers +x, 6 fr boucle, cyan translucide), `rivet` (sol 48 × 24, projectile vers +x, 4 fr boucle), `rivet_hit` (sol 64 × 64, 4 fr), `volley_cone` (sol 1024 × 1024, cône de 120° de télégraphe, 8 fr boucle : rivets qui pleuvent), `shell` (billboard 128 × 384, obus qui tombe, 6 fr), `shell_crater` (sol 384 × 384, cratère de 3 u, 6 fr), `coal_mouth` (billboard 160 × 160, bouche à charbon, 6 fr boucle, `_e`), `stoker_idle_s`, `stoker_walk_e/s/w/n` (billboard 128 × 160, soutier de 2,0 u, 8 fr boucle), `stoker_death_s` (8 fr), `steam_vent` (billboard 256 × 320, purge, 8 fr boucle), `reload_smoke` (billboard 192 × 256, 6 fr boucle).

**Sons** : `enemy.gunner_breech.medium`, `enemy.gunner_rivet_hit.light` (très court, poolé), `enemy.gunner_pylon_plant.medium`, `enemy.gunner_pylon_crack.medium`, `enemy.gunner_pylon_break.heavy`, `enemy.gunner_volley_warn.heavy` (sirène 1,5 s + barillet), `enemy.gunner_volley.loop` (mitraille en boucle, 3 couches selon la cadence), `enemy.gunner_reload.medium`, `enemy.gunner_shell_whistle.medium`, `enemy.gunner_shell.heavy`, `enemy.gunner_shield_up.heavy` (plaques), `enemy.gunner_vent.heavy` (purge), `enemy.gunner_stoker_walk.loop`, `enemy.gunner_stoker_feed.medium` (soin), `enemy.gunner_stoker_death.medium`, `enemy.gunner_anchor.heavy`, `enemy.gunner_death.heavy`.

### 2.3 Le Roi de sel (`salt_king`) : étage 4, Cryptes noyées

**Identité** : le dernier souverain de la Cité, descendu dans les cryptes avec sa cour quand les eaux ont tout pris. Le sel l'a gardé. Il tient toujours sa cour, dans le noir.

**Silhouette pour Codex** (3,8 u) : monarque voûté, **manteau de sel** en grandes plaques cristallisées qui traîne 1,5 u derrière lui (os et coquilles pris dedans), buste maigre, **masque funéraire d'os** sans yeux, **couronne de cristal** blanc-cyan (`#BFF4FF`, seul accent émissif, avec les fissures du manteau en P2+), sceptre = colonne vertébrale d'anguille ossifiée terminée par un crâne de poisson. Albédo ≥ 90/255 (sel gris perle `#98A2A6` → `#C9D3D6`), liseré froid. Phases : **p1** manteau fermé, couronne terne ; **p2** manteau fissuré (veines lumineuses), **couronne détachée** qui flotte 0,8 u au-dessus de lui (point faible, dessinée à part) ; **p3** assis sur un **trône de sel** monté du lac (ancré), manteau étalé en flaque cristalline, couronne en orbite. 2,0 u/s.

**Phases et sorts** (coefs `Balance.BOSS_ATTACK_COEF[&"salt_king"]`) :

| Phase | Auto | Sort A | Sort B | Mécaniques |
|---|---|---|---|---|
| **P1 « La cour »** (100-70 %) | **Sceptre** : ligne 1 × 4 u, toutes les 1,8 s, coef 1,0 (`scepter`) | **Procession** (§1.5 `SafeSector`) : le sceptre se lève 1,2 s, la **marée de sel** monte sur toute la zone de charge (9 u) sauf une **nef sèche** de 90° qui tourne à 30°/s pendant 6 s, coef 0,4 par 0,5 s + ralentissement −30 % hors de la nef (`procession`), recharge 16 s | **Stèles** (interaction décor) : 4 stèles de sel jaillissent en croix à 3 u du joueur (télégraphe 1,0 s, coef 1,2 `stele` si dessus), obstacles de 1 u pendant 10 s qui bloquent le joueur et **arrêtent la marée** (l'ombre derrière une stèle reste sèche : §1.2 `cull_shadows` appliqué au secteur) : un abri de secours quand la nef est trop loin | — |
| **Transition 2 « Cristallisation »** (70 %) | **Bouclier** `ULTIMATE_HIT` hits 1 : le roi s'agenouille, une **croûte de sel** le recouvre (invulnérable, fissures vides) ; étiquette « FRAPPEZ AVEC L'ULTIME », icône du sort 4 qui pulse. Tout coup lourd fissure visuellement (3 états `salt_crust`) sans compter ; **l'ultime** (n'importe lequel du roster : `hit["slot"] == ULTIMATE_SLOT`) fait **éclater** la croûte : roi « éclaté » 3 s (+35 %). Backstop **20 s** (plus court : certains ultimes ont 30 s de recharge, le garde-fou évite une attente injuste ; l'icône affiche la recharge restante). Sous bouclier : Stèles toutes les 5 s + **Larmes de sel** : 6 monstres de tier 1 (skin sel) toutes les 8 s. |
| **P2 « Marée noire »** (70-35 %) | Sceptre | **Procession** : nef de 60°, 40°/s, 7 s | **Stèles ×6** (deux croix décalées) | **Couronne** (§1.7 `WeakPoint`) : la couronne flotte à 2 u **derrière** le roi (arc exposé 120° dans son dos), PV 5 % du boss, dégâts ×2 transférés ; quand elle est brisée, le roi est **sonné 2 s** et la couronne se reforme après 10 s : une fenêtre de burst à aller chercher dans son dos |
| **Transition 3 « Cristallisation »** (35 %) | Bouclier `ULTIMATE_HIT` hits 1 (une croûte plus épaisse : l'ultime doit toucher le **roi**, la couronne ne compte pas) ; backstop 20 s ; éclaté 3 s. |
| **P3 « Noyade »** (35-0 %) | **Édit** : anneau 1 → 8 u depuis le trône toutes les 4 s (télégraphe 1,0 s), coef 1,4 (`edict`) | **Procession permanente** : la nef (60°) tourne à 40°/s **en continu**, répit de 2 s toutes les 8 s (la marée baisse : « REFLUX » sur la barre) | Stèles ×4 toutes les 6 s | **Ancré** sur le trône de sel monté du lac (immobile, +20 % de dégâts reçus) ; couronne en orbite 2,5 u (point faible actif en permanence, 60° exposés qui tournent avec elle) |

Coefs : `scepter` 1,0 ; `procession` 0,4 (par 0,5 s) ; `stele` 1,2 ; `edict` 1,4 ; `tears` (tier 1) 0 (monstres normaux) ; `crown_hit` 0 (point faible : transfert ×2). Trace après la mort : la marée se retire, les stèles restent ; la couronne tombe au sol (décor) jusqu'à la fin de la charge.
**Contre-jeu** : rester **près du roi** pendant la Procession (au bord, la nef file à 6,3 u/s ; à 4 u du centre, 2,8 u/s) ; garder son ultime pour la croûte (le HUD le rappelle) ; passer dans son dos pour la couronne ; les stèles sont l'abri de secours. **Met à l'épreuve** : gestion de l'ultime (le choix de variante compte : Tête-cloche de Tocsin, Crue d'Averse… tous valides), mobilité, survie en continu. Durée visée : 85 s dont ≈ 14 s de boucliers.

**Animations** (`boss_sprites.salt_king`, dir `etage/salt_king`, dim 250,88, fh ≈ 350 ; `brain` `scripts/enemies/salt_king_brain.gd` ; `brief` `art/tools/night/_raid_salt_king.txt`) :
`anims` : `idle_p1_e/s/w/n`, `idle_p2_*`, `idle_p3_*` (assis), `walk_p1_*`, `walk_p2_*` (le manteau racle), `walk_p3_*` (= idle_p3), `auto_*` (6 fr, sceptre, impact 3), `spell_a_*` (8 fr, Procession : sceptre levé, impact 4), `spell_b_*` (8 fr, Stèles : sceptre planté au sol, impact 4), `edict_s` (8 fr, P3 : anneau depuis le trône, impact 4), `shield_s` (8 fr boucle : agenouillé, croûte qui respire), `crack_s` (8 fr : la croûte éclate, impact 4), `stun_s` (6 fr boucle : sonné, couronne brisée), `trans_p2_s`, `trans_p3_s` (le trône monte), `death_s` (10 fr : le manteau s'effondre en sel, la couronne roule).
`extras` : `salt_crust` (billboard 288 × 352, croûte de sel sur le roi agenouillé, 3 états × 6 fr boucle : intacte, fissurée, prête à céder ; `_e` des fissures), `crust_burst` (billboard 384 × 384, 6 fr), `stele` (billboard 128 × 224, stèle de sel de 1 u, 2 états × 6 fr boucle : dressée, érodée ; `_e`), `stele_rise` (billboard 128 × 256, 6 fr), `tide_sheet` (sol 1152 × 1152, nappe de marée de sel, 8 fr boucle, rouge translucide : le code découpe la nef par masque), `dry_nave` (sol 1152 × 1152, secteur sec de 90° depuis le centre vers +x, 8 fr boucle : cyan, bord lumineux ; le code tourne et rétrécit l'angle par masque), `tide_front` (sol 256 × 128, écume de sel sur le bord de la nef, 6 fr boucle), `crown` (billboard 96 × 96, couronne de cristal flottante, 8 fr boucle, `_e`), `crown_guarded` (billboard 96 × 96, couronne en pointillés gris, 4 fr boucle), `crown_break` (billboard 160 × 160, 6 fr), `throne` (billboard 320 × 384, trône de sel de 3 u, 6 fr boucle, P3), `throne_rise` (billboard 320 × 448, 8 fr), `edict_ring` (sol 1024 × 1024, anneau de sel de rayon 512 px, 6 fr), `tear_drop` (billboard 96 × 128, larme de sel qui tombe et libère un monstre, 6 fr).

**Sons** : `enemy.salt_king_scepter.medium`, `enemy.salt_king_procession_warn.heavy` (chœur grave + sceptre levé, 1,2 s), `enemy.salt_king_tide.loop` (marée de sel qui crisse, boucle), `enemy.salt_king_reflux.medium`, `enemy.salt_king_stele.medium` (×4 décalés), `enemy.salt_king_crust.heavy` (cristallisation), `enemy.salt_king_crust_crack.light` (fissure sans effet), `enemy.salt_king_crust_burst.heavy` (ultime), `enemy.salt_king_crown_hit.light`, `enemy.salt_king_crown_break.medium`, `enemy.salt_king_edict.heavy`, `enemy.salt_king_throne.heavy`, `enemy.salt_king_tears.medium`, `enemy.salt_king_death.heavy`, `amb.salt_court` (murmures de cour, boucle, sous bouclier).

---

## 3. Variété pour les 13 boss existants

Chaque boss reçoit **au moins une transition de phase invulnérable avec condition** (dans son thème, condition souvent différente des trois nouveaux boss) et, quand c'est utile, un sort ou une mécanique de la boîte. Les transitions existantes (`trans_pN`, boss figé 0,9 s) deviennent le début du bouclier ; rien d'autre ne change dans leurs kits. Priorité : **P0** = boss de l'étage 1 et boss livrés (vus tôt, sprites en place), **P1** = boss à sprites des étages 2-4, **P2** = boss encore en placeholders (ajout au moment de leur passage en sprites).

| Boss (`id`) | Étage | Transition invulnérable + condition (seuil) | Mécanique ou sort ajouté | Pénalité d'échec | Prio |
|---|---|---|---|---|---|
| **L'Éclusier** (`eclusier`) | 1 | **70 % « Écluse fermée »** : la vanne se referme (invulnérable) et l'eau monte ; condition **`SOAK` 2 zones** : les 2 **bondes** de la zone (cercles cyan 2,5 u à 6 u du pilier, là où naîtront les geysers permanents) à occuper 1,5 s chacune pour vidanger ; rupture = vanne qui s'ouvre, Éclusier sonné 2,5 s | aucun sort nouveau : les bondes deviennent ses geysers permanents (déjà prévus en P2) | zone non vidangée à 25 s : geyser permanent **plus large** (2,5 u au lieu de 2) jusqu'à la fin | P0 |
| **Le Bouvier** (`ox_herder`) | 1 | **35 % « Ancres »** : il s'embourbe (déjà ancré) mais ses **2 cornes-ancres** sont plantées dans la boue à 3 u de part et d'autre (`WEAK_POINT` ×2, 5 % PV chacun, exposés quand le joueur est du côté de l'ancre) ; les 2 brisées → il s'arrache **sans** sa charge de sortie et reste sonné 2,5 s | aucun | backstop 25 s : il s'arrache avec sa charge (comportement actuel) | P0 |
| **La Porteuse de jarres** (`jar_bearer`) | 1 | **70 % « Scellée »** : elle se cache dans une **jarre-mère géante** (2 u, invulnérable) ; 3 jarres-mères ordinaires (`JarBearerJar`, cassables) sont posées autour ; condition = **casser les 3** (variante `KILL_ADDS` sur des props : elles n'explosent pas pendant le bouclier) → la grande jarre éclate, Porteuse sonnée 2,5 s | aucun | backstop 25 s : les 3 jarres explosent en anneau (télégraphe 1,2 s, coef 1,2) | P0 |
| **Le Cerf-Lanterne** (`cerf`) | 2 | **70 % « Lanternes mourantes »** : le Cerf s'efface dans la brume (invulnérable) et ses **6 follets** de transition (déjà lancés) deviennent prioritaires (`KILL_ADDS` 6, PV actuels des follets, ils ne marchent pas vers le Cerf mais **vers les lanternes de l'arène**) ; 6 tués → il réapparaît sonné 2 s | aucun (ses follets explosent déjà) | follet arrivé à une lanterne : la brume de P2 gagne +1 u de rayon (plafond +3 u) ; backstop 25 s | P0 |
| **Le Sonneur** (`sonneur`) | 3 | **70 % « Cloche fermée »** : la cloche se referme sur le paratonnerre (invulnérable), condition **`TIMER` 5 s** : la foudre doit tomber sur lui (le compte à rebours est l'éclair qui se charge) ; pendant les 5 s : Glas double **en continu** (toutes les 2,5 s) : survivre, c'est la condition ; l'éclair fend la cloche : sonné 2 s | `SoftEnrage` : avertissement 75 s | aucune (c'est la condition « attendre 5 s » demandée) | P0 |
| **La Grue** (`crane`) | 3 | **70 % « Levée »** : la Grue hisse sa cabine hors de portée (invulnérable) ; condition **`SOAK` 2 plaques de chargement** (cercles cyan 2,5 u sous la flèche, 1,5 s chacun) : la charge l'oblige à redescendre, sonnée 2 s | **P3 « Grenaille »** : la flèche dressée **mitraille** (`BarrageEmitter` 20/s, 4 s, cône 90° qui suit lentement le joueur à 20°/s) et ses **conteneurs** sont les abris (`CraneYard` reçoit l'ombre d'abri `cull_shadows`) : la demande du joueur, version Grue | plaque non chargée : un conteneur de plus tombe au hasard dans la zone | P1 |
| **Le Fondeur** (`smelter`) | 3 | **70 % « Croûte de laitier »** : le creuset se couvre d'une croûte (invulnérable) ; condition **`WEAK_POINT` ×2 : les évents** sur ses flancs (arc exposé 100° de chaque côté, 5 % PV chacun) ; percés → la croûte saute, Fondeur sonné 2,5 s | aucun | backstop 25 s : la croûte se fend seule dans un anneau de métal (télégraphe 1,2 s, coef 1,2) | P1 |
| **Le Reclus** (`recluse`) | 4 | **35 % « Silence absolu »** : il lévite (déjà immobile) sous un dôme de silence (invulnérable) ; condition **`INTERACT` 3 cristaux** de l'arène à **rallumer** (maintien 0,6 s, invite Interagir ; ils sont éteints depuis P2 : `RecluseGloom` fournit leurs positions) ; 3 rallumés → le dôme éclate, la lumière revient à 100 %, Reclus sonné 2,5 s | aucun (ses rayons tournent déjà) | backstop 25 s : l'obscurité tombe à 40 % jusqu'à la fin | P1 |
| **L'Anguille** (`deep_eel`) | 4 | **70 % « Crue »** : plongée (déjà ×0,3) devient **invulnérable** pendant la transition ; condition **`SOAK` 1 appât** (`FixateMark` + zone cyan 2,5 u sur la rive, 2 s) : le joueur « bat l'eau » (jauge), l'Anguille **surgit sur l'appât** (émergence télégraphée 1,2 s, le joueur doit sortir du cercle) et s'échoue 3 s (exposée) | aucun (échouage existant) | appât ignoré 25 s : elle émerge d'une flaque **sans** s'échouer | P1 |
| **Le Semeur de pluie** (`rain_sower`) | 5 | **70 % « La crue monte »** : `TIMER` 4 s (mise en scène actuelle, maintenant invulnérable, Averse ×3 pendant) ; **35 % « L'ancrage »** : le Semeur glisse au paratonnerre (invulnérable) ; condition **`SOAK` 4 flaques sacrées** dans les 4 chapelles de l'arène (cercles cyan 2,5 u, 1,5 s chacun, ordre libre) : chaque flaque vidée fait **refluer** l'eau d'1,5 u ; 4/4 → le bassin se vide, le Semeur s'ancre **sonné 3 s** (+35 %) | aucun (Rafale existante) | backstop 25 s : il s'ancre sans fenêtre et la crue **reste** à 6 u (l'arène reste petite) | P1 |
| **La Tisseuse** (`weaver`) | 2 | **70 % « La toile »** : elle reste dans la canopée (invulnérable) tant que la toile ne **vibre** pas ; condition **`INTERACT` par contact : toucher un fil de la toile** (c'est déjà son oreille) → elle tombe sur le point touché (télégraphe 1,2 s, se décaler) et reste **sonnée 2,5 s** au sol (exposée) | aucun | backstop 20 s : elle descend seule, sans être sonnée | P2 |
| **Le Cèdre-Ermite** (`hermit_cedar`) | 2 | **35 % « Déracinement »** : écorce fermée (invulnérable), `TIMER` 8 s **accéléré** : 4 racines-adds (1 coup chacune, `KILL_ADDS` 4, immobiles, à 4 u) : chaque racine coupée retire 2 s au minuteur ; fin → il se déracine sonné 2 s | aucun (charge et souches existantes) | aucune : au pire 8 s d'attente, ses spores continuent | P2 |
| **La Mère-Cristal** (`crystal_mother`) | 4 | **70 % « Géode fermée »** : elle se referme en géode (invulnérable) ; condition **briser 2 blocs-lampes** parmi ceux qu'elle a posés (props cassables, 5 % PV chacun, `KILL_ADDS` sur props) : chaque bloc brisé lui rend sa lumière (flash), 2/2 → la géode s'ouvre, Mère sonnée 2,5 s | aucun (Reflet existant) | backstop 25 s : les blocs restants deviennent **tous** des lampes (plus de monstres boostés) | P2 |

Deux règles de cohérence : un boss garde **une seule** transition invulnérable là où son autre transition est déjà une mise en scène forte (Sonneur P3 chaudière, Grue P3 paratonnerre, Reclus P2 extinction…) ; aucune condition ne demande plus que ce que le ciblage automatique mobile sait faire (adds, props et points faibles sont dans le groupe `enemies` ; zones, orbes et cristaux se marchent ou s'actionnent).

---

## 4. Plan de production (lots parallélisables)

Principes : CLAUDE.md « Orchestration » (Fable orchestre, Opus pour les systèmes partagés, Sonnet pour les boss, Codex pour les assets) ; un agent ne touche que ses dossiers ; `game/scripts/core/*`, `project.godot` réservés à l'orchestrateur ; style ultracave pour les messages des agents, prose normale dans les fichiers.

| Lot | Agent | Contenu | Dépend de | Vérification |
|---|---|---|---|---|
| **(a) RK1 Boîte à outils, cœur** | Opus | `game/scripts/enemies/raid/` : `boss_shield.gd`, `break_condition.gd` (7 kinds), `raid_orb.gd`, `weak_point.gd`, `priority_adds.gd`, `raid_fx.gd` ; contrats partagés listés §1.9 (`Events` ×4 signaux, `Balance` constantes, `Enemy.aim_priority`, `hit["slot"]` dans `SpellCaster`, `EnemyVisual.set_skin_frames`, `BossHealthBar` kind `shield`) ; test `raid_kit_test.tscn` | — | `raid_kit_test`, `sonneur_boss_test`, `integration_test` → RESULT: OK |
| **(a') RK2 Boîte à outils, terrain** | Opus (2e agent, périmètre disjoint) | `shelter_pylon.gd`, `barrage_emitter.gd`, `soak_zone.gd`, `safe_sector.gd`, `fixate_mark.gd` ; `EnemyProjectilePool.cull_circles / cull_shadows`, `Player.hit_cooldown_per_source` ; perf : 160 projectiles + 6 pylônes à 60 fps sur le profil Bas ; `OffscreenCues` catégorie `raid` | — | `raid_kit_test` (section terrain), `perf_test` ou mesure `--print-fps` |
| **(b) RB1 L'Idole noyée** | Sonnet | `drowned_idol_brain.gd` (+ `drowned_idol_fx.gd` placeholders), entrées `Balance.BOSS_ATTACK_COEF / BOSS_PHASE_THRESHOLDS / BOSS_PHASE_DAMAGE_TAKEN / BOSS_HP_MULT`, `fauna.json` `boss_sprites.drowned_idol` + `floors.json` `floor_bosses` étage 1 (en 4e : non tiré tant que le `.tres` manque), `boss_names`, test `drowned_idol_boss_test`, `floor1_boss_test` | RK1 (orbes, bouclier), RK2 (fixation, ombre des digues) | `drowned_idol_boss_test`, `floor1_boss_test`, `sprites_test`, `biome_fauna_test` |
| **(b) RB2 Le Canonnier de crue** | Sonnet | `flood_gunner_brain.gd` (+ fx), mêmes entrées, étage 3, test `flood_gunner_boss_test`, `floor3_boss_test` | RK1 (adds), RK2 (pylônes, barrage) | idem + mesure du nombre de projectiles vivants ≤ 160 |
| **(b) RB3 Le Roi de sel** | Sonnet | `salt_king_brain.gd` (+ fx), mêmes entrées, étage 4, test `salt_king_boss_test`, `floor4_boss_test` | RK1 (ultime, point faible), RK2 (secteur, stèles) | idem + test de la condition ultime avec 3 kits (Ardent, Tocsin, Averse) |
| **(c) RE1 Existants P0** | Sonnet | `eclusier`, `ox_herder`, `jar_bearer`, `cerf`, `sonneur` : transition invulnérable + condition (§3), `SoftEnrage` sur tous | RK1, RK2 | tests de chaque boss + `floor1_boss_test`, `floor2_boss_test`, `floor3_boss_test` |
| **(c) RE2 Existants P1** | Sonnet (2e agent) | `crane` (+ Grenaille), `smelter`, `recluse`, `deep_eel`, `rain_sower` | RK1, RK2 | tests de chaque boss + `floor3/4_boss_test`, `rain_sower_boss_test` |
| **(c) RE3 Existants P2** | Sonnet | `weaver`, `hermit_cedar`, `crystal_mother` | RK1 | tests de chaque boss, `floor2_boss_test`, `floor4_boss_test` |
| **(d) Consignes Codex** | écrites par ce document | `art/tools/night/_raid_kit.txt` (VFX génériques de la boîte : orbe, bulle de bouclier, jauge de zone, secteur, marqueur de fixation, point faible : `game/assets/sprites/vfx/raid/`), `_raid_drowned_idol.txt`, `_raid_flood_gunner.txt`, `_raid_salt_king.txt` ; ajoutés en fin de `art/tools/night/queue.txt` (groupes **52** kit `low`, **53** idole, **54** canonnier, **55** roi, `medium`) ; lancement par `night_queue.sh` ou `sh art/tools/run_codex.sh <consigne> <journal> medium` | (b) écrit d'abord les `boss_sprites` dans `fauna.json` (noms d'anims et d'extras = ceux de §2, qui font foi) | `sprites_test`, `texture_budget_test`, test du boss → RESULT: OK, planche `_raid_<id>_contact.png` |
| **(e) Sons** | Codex audio | `art/tools/audio/_raid_sfx.txt` : tous les ids §1.1, §1.9 et §2 (synthèse dans `art/tools/audio/gen_raid.py`, manifeste `raid_manifest.json`, sorties `game/assets/audio/impacts/` et `ambience/`) ; groupe **55** de `queue.txt`, `low` | ids figés par (b) | `verify_new.py` sur le lot, `audio_test` |

Ordre : RK1 et RK2 en parallèle (jour 1) → RB1, RB2, RB3, RE1 en parallèle (jour 2 ; RE2 et RE3 dès qu'un agent se libère) → Codex (d) et (e) en file de nuit (les boss tournent en placeholders dès (b)). Les trois nouveaux boss ne sont **tirés en run** qu'une fois leur `.tres` livré (règle de `floors.json`) : aucun risque pour les testeurs entre-temps.

Recalibrage : passer `docs/simulateur_scaling.py` et `art/tools/night/balance_sim.py` avec un boss à 2 boucliers (18 s invulnérables, PV × 0,9) pour vérifier la cible de 75-90 s en Moyen aux étages 1, 3 et 4 ; le skill `/balance-check boss <id>` sur chacun des trois.

---

## 5. Questions ouvertes pour le joueur (avec recommandation)

1. **Fréquence des boucliers** : 2 transitions invulnérables par boss (proposé) ou une seule (l'autre reste une mise en scène) ? **Reco : 2 pour les trois nouveaux, 1 pour les existants** (§3), pour que « boss raid » reste une saveur et pas la norme.
2. **Garde-fou** à 25 s (20 s pour l'ultime) : garder, ou plus court (15 s) sur mobile ? **Reco : 25 / 20 s**, avec le message « Le bouclier cède » ; l'échec coûte déjà la fenêtre bonus et 25 s de foule.
3. **Pénalité de la Mitraille** : coef 0,2 par rivet et immunité 0,35 s (43 % des PV sur 6 s sans abri à l'étage 1 sans objet, ≈ 25 % à l'étage 3 avec les objets attendus). Trop doux ? **Reco : garder** ; c'est la lisibilité (l'abri dessiné au sol) qui fait la peur, pas les chiffres.
4. **Ultime obligatoire** (Roi de sel) : un joueur qui a choisi une variante d'ultime à 30 s de recharge attend plus. **Reco : accepter** avec le backstop de 20 s, et afficher la recharge restante sur la croûte ; alternative : compter aussi 2 coups d'un sort 2-3 « lourd » (≥ 25 % du meilleur coup du run), à tester.
5. **Quatrième boss par étage** : les étages 1, 3 et 4 passent à 4 boss d'étage, l'étage 2 reste à 3. Ajouter un 4e à l'étage 2 plus tard (idée : « La Noyeuse », naïade de mangrove, condition `SAFE_SECTOR` + orbes de lucioles) ? **Reco : plus tard**, après le retour des testeurs sur les trois premiers.
