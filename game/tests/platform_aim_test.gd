extends Node
## godot --headless --path game res://tests/platform_aim_test.tscn
## Visée des sorts 2-4 : souris (kbm), stick droit (manette), ciblage auto (tactile / sans visée).

class FakeEnemy extends Node2D:
	var taken: Array = []
	var tier := 1
	var is_elite := false
	func take_damage(amount: float, _crit: bool = false, _el: StringName = &"") -> void:
		taken.append(amount)
	func apply_status(_s: StringName, _d: Dictionary) -> void:
		pass
	func is_slowed() -> bool:
		return false

var _fails := 0
var _player: CharacterBody2D


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


func _enemy(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	return e


func _ready() -> void:
	_run.call_deferred()


func _fresh() -> void:
	_player.apply_stats({"crit_chance": -0.05})
	_player.spells._remaining[3] = 0.0
	_player.spells.aim_override = null


func _clear_zones() -> void:
	for z in _player.spells._container.get_children():
		if z.has_method("step"):
			z.free()


## Avance les zones persistantes (cendres) pour qu'elles appliquent un tick.
func _tick_zones() -> void:
	for z in _player.spells._container.get_children():
		if z.has_method("step"):
			z.step(0.6)


func _run() -> void:
	_player = load("res://scenes/player/player.tscn").instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.global_position = Vector2.ZERO
	var near := _enemy(Vector2(150, 0)) # le plus proche (auto)
	var far := _enemy(Vector2(-300, -250)) # dans la portée de Cendres (7 u = 448 px)
	var sp: SpellCaster = _player.spells

	# tactile : ciblage automatique -> zone sur l'ennemi le plus proche
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	_fresh()
	_check(sp.get_manual_aim_point(448.0) == null, "tactile : pas de visée manuelle")
	_check(sp.cast(3), "cendres lancées (auto)")
	sp.flush_pending() # Ardent : effet à la frame d'impact de l'anim
	_tick_zones()
	_check(near.taken.size() > 0 and far.taken.is_empty(), "auto : zone sur le plus proche")

	# souris : zone au point visé (aim_override = position du curseur dans le monde)
	Platform.set_input_mode(Platform.InputMode.KBM)
	_clear_zones()
	near.taken.clear()
	far.taken.clear()
	_fresh()
	sp.aim_override = far.global_position
	_check(sp.cast(3), "cendres lancées (souris)")
	sp.flush_pending() # Ardent : effet à la frame d'impact de l'anim
	_tick_zones()
	_check(far.taken.size() > 0 and near.taken.is_empty(), "souris : zone sur le curseur, pas sur le plus proche")

	# portée : curseur très loin -> zone limitée à la portée (7 u)
	_clear_zones()
	_fresh()
	sp.aim_override = Vector2(5000, 0)
	sp.cast(3)
	sp.flush_pending() # Ardent : effet à la frame d'impact de l'anim
	var zone: Node2D = null
	for z in sp._container.get_children():
		if z.has_method("step"):
			zone = z
	_check(zone != null and absf(zone.global_position.x - 448.0) < 1.0, "zone limitée à la portée: %s" % str(zone.global_position if zone else null))

	# le curseur réel est lu en kbm (get_global_mouse_position), sans override
	_fresh()
	var p: Variant = sp.get_manual_aim_point(448.0)
	_check(p is Vector2, "kbm : point de visée = curseur")

	# manette : stick droit au repos -> auto ; stick poussé -> direction du stick
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	_fresh()
	_check(sp.get_manual_aim_point(448.0) == null, "manette : stick au repos -> auto")
	Input.action_press("aim_left", 1.0)
	Input.action_press("aim_up", 1.0)
	var q: Variant = sp.get_manual_aim_point(448.0)
	_check(q is Vector2 and (q as Vector2).x < 0.0 and (q as Vector2).y < 0.0, "manette : stick haut-gauche -> point haut-gauche %s" % str(q))
	_clear_zones()
	near.taken.clear()
	far.taken.clear()
	_check(sp.cast(3), "cendres lancées (stick)")
	sp.flush_pending() # Ardent : effet à la frame d'impact de l'anim
	_tick_zones()
	_check(near.taken.is_empty(), "stick : la zone ne va pas sur l'ennemi proche")
	Input.action_release("aim_left")
	Input.action_release("aim_up")

	# sort 1 : toujours automatique (jamais de visée manuelle), même en kbm
	Platform.set_input_mode(Platform.InputMode.KBM)
	_fresh()
	sp.aim_override = Vector2(0, 3000)
	_check(_player.character.spells[0].is_auto, "sort 1 auto")
	sp._remaining[1] = 0.0
	_check(sp.cast(1), "sort 1 tiré vers l'ennemi, pas vers le curseur")
	sp.flush_pending() # Ardent : effet à la frame d'impact de l'anim
	var dir_ok := false
	for pr in sp._pool:
		if pr.active:
			dir_ok = pr.global_position.y < 100.0
	_check(dir_ok, "projectile du sort 1 vers la cible")
	sp.aim_override = null

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
