class_name RaidKit
extends RefCounted
## Aides communes de la boîte à outils des boss façon raid (docs/Design_Boss_Raid.md §1) : pénalité d'échec
## plafonnée et non létale (règle 2), placement sur sol accessible, accès au pool de projectiles du Director.

const U := 64.0


## Pénalité d'échec d'une mécanique (zone ratée, secteur…) : coef × dégâts courants du boss (enrage compris),
## plafonnée à RAID_PENALTY_MAX_FRAC des PV max du joueur et, si RAID_PENALTY_NONLETHAL, jamais sous 1 PV :
## un échec n'est jamais une condition de défaite. Émet Events.raid_mechanic_failed(boss, kind) si `kind` != &"".
## Retourne les dégâts demandés au joueur (avant ses défenses).
static func penalty_hit(boss: Node2D, player: Node2D, coef: float, kind: StringName = &"") -> float:
	if kind != &"":
		Events.raid_mechanic_failed.emit(boss, kind)
	if player == null or not is_instance_valid(player) or not player.has_method(&"take_damage") or coef <= 0.0:
		return 0.0
	var base := 0.0
	if boss is Enemy and is_instance_valid(boss):
		base = (boss as Enemy).current_damage()
	var dmg := base * coef
	var mhp: float = float(player.get(&"max_hp")) if player.get(&"max_hp") != null else 0.0
	if mhp > 0.0:
		dmg = minf(dmg, mhp * Balance.RAID_PENALTY_MAX_FRAC)
	if Balance.RAID_PENALTY_NONLETHAL and player.get(&"hp") != null:
		dmg = minf(dmg, float(player.get(&"hp")) - 1.0)
	if dmg <= 0.0:
		return 0.0
	player.take_damage(dmg, boss if is_instance_valid(boss) else null)
	return dmg


## Coup ordinaire d'une mécanique (chute d'orbe, de pylône) : coef × dégâts courants du boss, source = boss
## (plafond de 40 % des coups de boss côté Player).
static func boss_hit(boss: Node2D, player: Node2D, coef: float) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method(&"take_damage"):
		return
	if boss is Enemy and is_instance_valid(boss):
		player.take_damage((boss as Enemy).current_damage() * coef, boss)


## Point ramené sur le sol accessible (NavField du boss), inchangé sans champ.
static func place(boss: Node2D, p: Vector2) -> Vector2:
	var nav: NavField = boss.get(&"nav") if boss != null and is_instance_valid(boss) else null
	if nav != null and nav.has_reachability():
		return nav.nearest_reachable(p)
	return p


static func player_of(n: Node) -> Node2D:
	if n == null or not n.is_inside_tree():
		return null
	return n.get_tree().get_first_node_in_group(&"player") as Node2D


## Pool de projectiles ennemis du Director du boss (ou du premier Director de l'arbre).
static func pool_of(n: Node) -> EnemyProjectilePool:
	var d: Node = n.get(&"director") if n != null else null
	if d == null and n != null and n.is_inside_tree():
		d = n.get_tree().get_first_node_in_group(&"director")
	return d.get_node_or_null(^"EnemyProjectiles") as EnemyProjectilePool if d != null else null


static func director_of(n: Node) -> Director:
	var d: Node = n.get(&"director") if n != null else null
	if d == null and n != null and n.is_inside_tree():
		d = n.get_tree().get_first_node_in_group(&"director")
	return d as Director


## Parent des objets d'une mécanique : le parent du boss (coordonnées logiques du monde).
static func world_of(boss: Node2D) -> Node:
	return boss.get_parent() if boss != null and boss.get_parent() != null else boss
