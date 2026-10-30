extends Node
## Visée des sorts lancés par l'auto-cast (option « Sorts automatiques ») : le monstre le plus proche, jamais le curseur,
## le stick droit, aim_override ni le « paquet le plus dense ». La visée manuelle des sorts lancés à la main ne change pas.
## godot --headless --path game res://tests/spell_auto_aim_test.tscn  -> RESULT: OK

class FakeEnemy extends Node2D:
	var aim_priority := 1.0

	func take_damage(_amount: float, _is_crit: bool = false, _element: StringName = &"", _hit: Dictionary = {}) -> void:
		pass

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false


const U := 64.0

var _fails := 0
var _player: CharacterBody2D
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _clear() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	for c in _player.spells.effects_parent().get_children():
		if c is Node2D and c.get_script() != null and String(c.get_script().resource_path).ends_with("zone_effect.gd"):
			c.queue_free()
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.spells.aim_override = null


func _zones() -> Array:
	var out: Array = []
	for c in _player.spells.effects_parent().get_children():
		if c is Node2D and c.get_script() != null and String(c.get_script().resource_path).ends_with("zone_effect.gd") and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _run() -> void:
	RunState.character = &"ardent"
	RunState.loadout = {}
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	add_child(_player)
	await get_tree().physics_frame
	_player.global_position = Vector2.ZERO
	var sp: SpellCaster = _player.spells
	var far_aim := Vector2(0.0, -900.0) # curseur / stick : à l'opposé du monstre proche

	# --- API : visée manuelle intacte à la main, ignorée en lancer auto
	var near := _fake(Vector2(3.0 * U, 0.0))
	var f1 := _fake(Vector2(0.0, -6.0 * U))
	var f2 := _fake(Vector2(10.0, -6.0 * U))
	var f3 := _fake(Vector2(-10.0, -6.0 * U + 10.0)) # paquet de 3 à 6 u au nord, un seul monstre proche à 3 u à l'est
	sp.aim_override = far_aim
	_check("à la main : get_manual_aim_point = aim_override", sp.get_manual_aim_point(7.0 * U) == far_aim)
	var dense: Variant = sp.densest_point(8.0 * U)
	_check("à la main : densest_point = paquet", dense is Vector2 and (dense as Vector2).y < -5.0 * U, str(dense))
	sp._auto_ctx = true
	_check("lancer auto : get_manual_aim_point = null malgré aim_override", sp.get_manual_aim_point(7.0 * U) == null)
	var dn: Variant = sp.densest_point(8.0 * U)
	_check("lancer auto : densest_point = monstre le plus proche", dn is Vector2 and (dn as Vector2).is_equal_approx(near.global_position), str(dn))
	_check("lancer auto : aucun monstre à portée -> null", sp.densest_point(1.0 * U) == null)
	sp._auto_ctx = false
	_check("contexte auto retombé", not sp._auto_ctx)

	# --- bout en bout : sort 3 (Cendres, zone au sol) lancé à la main puis par l'auto-cast
	_clear()
	near = _fake(Vector2(3.0 * U, 0.0))
	_fake(Vector2(0.0, -6.0 * U))
	sp.aim_override = far_aim
	_check("à la main : cast(3) réussi", sp.cast(3))
	sp.flush_pending()
	var z := _zones()
	_check("à la main : la zone tombe au point visé", z.size() == 1 and (z[0] as Node2D).global_position.distance_to(Vector2(0.0, -7.0 * U)) < 2.0 * U, str(z.map(func(n): return n.global_position)))
	_clear()
	near = _fake(Vector2(3.0 * U, 0.0))
	_fake(Vector2(0.0, -6.0 * U))
	sp.aim_override = far_aim
	_check("auto : cast(3, true) réussi", sp.cast(3, true))
	sp.flush_pending()
	z = _zones()
	_check("auto : la zone tombe sur le monstre le plus proche, pas sur aim_override", z.size() == 1 and (z[0] as Node2D).global_position.distance_to(near.global_position) < 8.0, str(z.map(func(n): return n.global_position)))

	# --- par tick(), option activée : le même chemin
	_clear()
	near = _fake(Vector2(3.0 * U, 0.0))
	_fake(Vector2(0.0, -5.0 * U))
	sp.aim_override = far_aim
	sp.auto_cast_enabled = true
	sp.manual_aim_enabled = true
	_player.hp = _player.max_hp
	for s in sp.character.spells:
		if s.slot != 3:
			sp._remaining[s.slot] = 99.0 # un seul sort tire
	sp._remaining[1] = 99.0
	_player._action_left = 0.0 # le lancer précédent (cast direct) ne doit pas retenir l auto-cast : cancel/buffer du 29/10
	sp.tick(0.016)
	sp.flush_pending()
	z = _zones()
	_check("tick auto : une zone posée sur le monstre proche", z.size() == 1 and (z[0] as Node2D).global_position.distance_to(near.global_position) < 8.0, str(z.map(func(n): return n.global_position)))

	# --- priorité de visée (boss de raid) : conservée en auto
	_clear()
	var close := _fake(Vector2(2.0 * U, 0.0))
	var weak := _fake(Vector2(0.0, 5.0 * U))
	weak.aim_priority = 4.0 # point faible : 5 u / 4 < 2 u
	sp._auto_ctx = true
	var dp: Variant = sp.densest_point(8.0 * U)
	_check("auto : aim_priority gardée (point faible préféré)", dp is Vector2 and (dp as Vector2).is_equal_approx(weak.global_position), str(dp))
	sp._auto_ctx = false
	close.aim_priority = 1.0

	# --- le rejeu (Couronne d'écho) d'un lancer auto reste auto
	_clear()
	near = _fake(Vector2(3.0 * U, 0.0))
	_fake(Vector2(0.0, -6.0 * U))
	sp.aim_override = far_aim
	var echoed := [false]
	sp.spell_cast.connect(func(_s: SpellData) -> void:
		if not echoed[0]:
			echoed[0] = true
			_check("rejeu pendant un lancer auto : contexte auto hérité", sp._auto_ctx))
	sp.cast(3, true)
	_check("contexte auto retombé après le lancer", not sp._auto_ctx)

	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
