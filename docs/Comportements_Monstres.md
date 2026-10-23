# Comportements des monstres : anticipation, coup, récupération

Retour du joueur (22/10/2026) : « les tireurs tirent en marchant », puis « les mêlées ne marquent pas le temps d'arrêt sur les coups, même les boss ». Ce guide résume la recherche et donne les valeurs de départ du jeu. Toutes les valeurs passent par `Balance` (section Monstres). Code : `scripts/enemies/enemy.gd`. Test : `tests/ranged_behavior_test.tscn`.

## Principes retenus

1. **Anticipation, action, récupération.** Chaque attaque a trois temps. L'**armement** (wind-up) annonce le coup. Il dure plus que le temps de réaction humain (0,2-0,3 s ; une attaque de moins de 0,33 s n'est pas réactable). Le **coup** part à la frame d'impact. La **récupération** est immobile et ouvre une fenêtre de punition [Stout ; VF ; RoR2].
2. **S'il bouge, il ne frappe pas.** En horde, la règle la plus lisible est qu'un monstre s'arrête pour armer et reste planté pendant la récupération. Le tireur Brotato (Spitter) et le Lemurian RoR2 en sont des exemples ; le Lemurian marque 0,6 s d'armement et 0,5 s de récupération [RoR2 ; Brotato].
3. **Plusieurs signaux en même temps** : une pose ou une anim, une teinte qui monte en intensité, un éclat juste avant le coup, un son de charge et une ligne de visée ou une zone au sol [Stout ; Wisp RoR2 ; Sniper Brotato].
4. **Plus l'armement est long, plus le coup est fort.** La récupération s'allonge avec lui : 0,5 s pour une boule de feu (Lemurian), 2 s pour un laser chargé 3 s (Golem) [RoR2].
5. **Jetons d'attaque (Doom 2016).** Un nombre limité de monstres attaquent en même temps. Le monstre prend un jeton avant d'armer et le rend après. Proposition de départ : 2-3 jetons de tir à distance, à moduler entre ×0,5 et ×1,5 avec la difficulté [80.lv ; StraySpark].
6. **Bandes de distance du tireur.** Il avance au-delà de sa distance préférée et recule en deçà d'un seuil, plus lentement que le joueur (Spitter Brotato : 0,44 × la vitesse du joueur). Il ne tire qu'en ligne de vue, à l'écran [RoR2 Wisp et Lemurian ; Brotato].
7. **Visée verrouillée avant le tir.** La visée suit le joueur pendant la plus grande part de l'armement, puis se fige. Un pas de côté pendant l'éclat final suffit pour esquiver, et c'est juste [Wisp, ligne de visée ; inférence].

## Valeurs du jeu (Balance)

| Archétype | Armement | Coup | Récupération | Autres |
|---|---|---|---|---|
| Tireur (tier 2), tir simple | `SHOOTER_WINDUP_S` 0,7 s, immobile ; visée suivie jusqu'à 75 % (`SHOOTER_AIM_LOCK`) puis verrouillée | 1 projectile à 6 u/s | `SHOOTER_RECOVERY_S` 0,5 s immobile | cadence `SHOOTER_INTERVAL_S` 2,5 s ±15 % |
| Tireur, salve (sort, 8 s) | `SHOOTER_SALVO_WINDUP_S` 1,0 s, cône au sol | 3 projectiles en éventail | `SHOOTER_SALVO_RECOVERY_S` 0,8 s | même jeton |
| Bondisseur (tier 2), tir d'appoint | `LEAPER_SHOT_WINDUP_S` 0,5 s | 1 projectile | `LEAPER_SHOT_RECOVERY_S` 0,3 s | même jeton |
| Bondisseur, charge | 0,8 s, ligne au sol (inchangé) | course de 6 u | `LEAPER_DASH_RECOVERY_S` 0,5 s immobile | |
| Brute (tier 3), cône | 0,6 s (inchangé) | cône 1,9 u | `BRUTE_RECOVERY_S` 0,4 s | |
| Brute, onde de choc | 1,0 s (inchangé) | cercle 3 u | 0,4 s | |
| Essaim (tier 1), contact | aucun : un contact passif reste immédiat (survivor-like) | morsure | `SWARM_BITE_PAUSE_S` 0,25 s sur place + petit recul `SWARM_BITE_RECOIL_U` 0,25 u | tick le moins cher : une comparaison |

- **Distances du tireur :** préférée `SHOOTER_KEEP_U` 5,5 u (avant : 4,5) ; repli sous `SHOOTER_RETREAT_U` 3,5 u à `SHOOTER_RETREAT_SPEED` 0,45 × sa vitesse ; tir jusqu'à `SHOOTER_RANGE_U` 8 u, en ligne de vue (1 u = le joueur).
- **Jetons :** `SHOOTER_MAX_CHARGING` = 3 tireurs (toutes espèces, élites comprises) peuvent armer en même temps. Sans jeton, le tireur continue de se placer et réessaie après `SHOOTER_TOKEN_RETRY_S` 0,2 s. Le jeton est rendu au tir ou à l'interruption (emprisonnement, mort) et expire seul en garde-fou.
- **Signaux pendant l'armement :**
  - Pose : anim `attack_<dir>` (rejouée depuis la frame 0) pour le tireur. Le bondisseur n'a pas de pose (brief Codex `art/tools/night/_mb1.txt`).
  - Lueur chaude sur le corps, plus vive à partir du verrouillage (éclat final). Elle est passée par l'alpha de modulation > 1 (`EnemyVisual.set_charge`, `sprite_flash.gdshader`) et avive aussi l'émission. Elle reste visible sur un corps sombre la nuit, alors qu'une teinte multiplicative ne se voyait pas (capture).
  - Brute : poses `attack_<dir>` (cône) et `cast_<dir>` (onde), avec la même lueur.
  - Ligne de visée rouge de 1,6 u qui se remplit, ou cône de 2,2 u pour la salve.
  - Son `telegraph.warn_light.light` atténué (aucun son de charge dédié pour l'instant).
- **Projectile :** 6 u/s, soit 1,5 × la vitesse du joueur (4 u/s). La recherche conseille 0,6-0,8 × le joueur pour un tir de base esquivable en marchant. C'est un point ouvert : à essayer après ce lot, car le changement touche l'équilibrage.

## Boss : armement / récupération (valeurs recommandées pour les cerveaux `*_brain.gd`, `miniboss_*.gd`)

Mêmes principes, avec des valeurs plus longues que pour les monstres de base (coups plus forts, RoR2 principe 4). Ce sont des recommandations ; les cerveaux sont réglés par leur propre agent.

| Coup | Armement | Pendant l'armement | Récupération immobile |
|---|---|---|---|
| Auto de boss d'étage (mêlée ou tir) | 0,5-0,6 s (plancher actuel 0,35 s : trop court) | arrêt complet, face au joueur, visée verrouillée à 75 % | 0,4-0,5 s |
| Auto de mini-boss | 0,45-0,5 s | arrêt complet | 0,35-0,45 s |
| Sort / zone (cercle, cône, ligne) | 0,8-1,2 s (règle des sorts >= 0,8 s) | arrêt ou freinage <= 20 % de sa vitesse ; télégraphe au sol | 0,7-1,0 s |
| Gros coup (slam, charge, laser) | 1,2-2,0 s | immobile, son grave qui monte | 1,0-1,5 s : vraie fenêtre de punition |
| Combo à plusieurs coups | 1er coup comme ci-dessus, puis >= 0,25 s entre les coups | immobile entre les coups | seulement après le dernier coup, >= 0,6 s |
| Charge ou ruée | 0,8 s minimum, avec une ligne au sol | | 0,6-0,8 s immobile en fin de course |

Règles communes aux boss :
- Le coup part à la frame d'impact de l'anim (`EnemyVisual.attack_impact_time` / `play_attack`).
- Pendant la récupération : anim tenue ou retour au repos, aucune marche.
- Enchaînement sort après auto : >= 0,3 s d'écart.
- La récupération ne raccourcit pas avec l'enrage. Seule la cadence monte, sinon la lisibilité se perd.

## Sources

- 80.lv, « Cyber Demons: The AI of DOOM » (jetons d'attaque) : https://80.lv/articles/cyber-demons-the-ai-of-doom
- StraySpark, « Attack Token System UE5: Group Combat That Feels Fair » (2 jetons distance, 1 mêlée, 1 lourd, ×0,5-1,5) : https://www.strayspark.studio/blog/attack-token-system-ue5-group-combat-that-feels-fair
- GDC 2018, « Embracing Push Forward Combat in DOOM » (Campbell, Loudy) : https://gdcvault.com/play/1024940/Embracing-Push-Forward-Combat-in
- Mike Stout, « Enemy Attacks and Telegraphing », Game Developer : https://gamedeveloper.com/design/enemy-attacks-and-telegraphing
- Risk of Rain 2 wiki : Lemurian https://riskofrain2.wiki.gg/wiki/Lemurian ; Lesser Wisp https://riskofrain2.wiki.gg/wiki/Lesser_Wisp ; Stone Golem https://riskofrain2.wiki.gg/wiki/Stone_Golem
- Brotato wiki, Enemies (vitesses, Spitter, Clam, Crab) : https://brotato.wiki.spellsandguns.com/Enemies
- Ludo guide, Brotato, types d'ennemis (Spitter lent, Sniper à laser de visée, marqueur d'artillerie) : https://www.ludo.guide/guide/brotato/walkthrough/enemy-types-behaviors
- Virtua Fighter, fil « reaction time » (startup <= 20 frames non réactable) : https://ns2.virtuafighter.com/threads/reaction-time.16419/page-2
- Game AI Pro (positionnement tactique, gestion des attaquants) : https://gameaipro.com/
