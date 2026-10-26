extends Node
## Bus de signaux global. Les systèmes émettent ici au lieu de se référencer directement.

signal enemy_killed(enemy: Node2D, position: Vector2, tier: int, is_elite: bool)
signal enemy_damaged(enemy: Node2D, amount: float, is_crit: bool, element: StringName)
signal player_damaged(amount: float, source: Node)
signal player_died
signal pickup_collected(kind: StringName, amount: float)
signal chest_opened(chest: Node, quality: StringName, offered_items: Array)
signal item_chosen(item_id: StringName)
signal run_saved
signal boss_spawned(boss: Node2D, is_floor_boss: bool)
signal boss_killed(boss: Node2D, is_floor_boss: bool)
signal pillar_state_changed(pillar: Node, state: StringName)
signal floor_started(stage: int)
signal floor_cleared(stage: int)
## Changement d'étage : l'or restant (bourse + sol) a été converti en XP (RunState.convert_gold_to_xp).
signal gold_converted(gold: float, xp: float)
## Foudre (décor ou gameplay) : intensité 0..1 et position monde (Vector2.INF = hors écran / ciel).
signal lightning_struck(intensity: float, pos: Vector2)
## Changement de palier de la jauge de difficulté (Calme, Tendu, Hostile, Furieux, Cataclysme).
signal difficulty_tier_changed(tier_name: StringName, D: float)
## Progression de charge d'un gros pilier (0..1), émise pendant que la charge avance.
signal pillar_charge_progress(pillar: Node, ratio: float)
## --- Boss façon raid (docs/Design_Boss_Raid.md §1.9, scripts/enemies/raid/) ---
## Bouclier de phase armé (active = true, dès la transition) ou tombé (active = false, rupture ou garde-fou).
## kind : condition principale (&"orbs", &"ultimate_hit", &"timer", &"kill_adds", &"weak_point", &"soak", &"interact").
signal boss_shield_changed(boss: Node2D, active: bool, kind: StringName)
## Progrès de la condition de rupture du bouclier (orbes ramassées, adds tués…).
signal boss_shield_progress(boss: Node2D, done: int, total: int)
## Mécanique de raid ratée (pénalité appliquée) : &"soak", &"sector", &"add_reached", &"shield_backstop"…
signal raid_mechanic_failed(boss: Node2D, kind: StringName)
## Barrage de projectiles (BarrageEmitter) : true au début du télégraphe, false à la fin de l'émission.
signal raid_barrage(boss: Node2D, active: bool)
