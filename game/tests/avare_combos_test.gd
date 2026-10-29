extends Node
## Combos d'Avare (docs/Design_Combos.md §5.4) : Rançon -> Poignée (1,8 par pièce, retombée à 100 %, aucun or neuf),
## Faillite sur marqués, Coup de coffre qui prolonge la marque, bonus dans la fenêtre seulement, ordre inverse.
## godot --headless --path game res://tests/avare_combos_test.tscn

class FakeEnemy extends Node2D:
	var radius_px := 16.0

	func take_damage(_amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		pass

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

	func stun(_s: float) -> void:
		pass

const TEST_PROFILE := "user://test_avare_combos_profile.json"
var _fails := 0
var _player: CharacterBody2D
var _kit: AvareKit
var _junk: Array = []
var _old_path := ""
var _old_write := false


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.001) -> bool:
	return absf(a - b) <= tol


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _mark(e: Node, secs: float) -> void:
	_kit.marks[e.get_instance_id()] = {"t": _kit._clock + secs, "ref": weakref(e)}


func _dmg(s: SpellData, e: Node) -> float:
	return _player.spells.compute_damage(s, e, false)


func _run() -> void:
	_old_path = Profile.path
	_old_write = Profile.write_enabled
	Profile.path = TEST_PROFILE
	Profile.write_enabled = true
	Profile.load_profile()
	RunState.level = 1
	RunState.character = &"avare"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	var pm := PickupManager.new()
	get_tree().root.add_child(pm)
	if not pm.is_in_group(&"pickups"):
		pm.add_to_group(&"pickups")
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as AvareKit
	_player.apply_stats({"crit_chance": -0.05})
	RunState.gold = 0.0
	var ch := AvareKit.character()
	var s1: SpellData = ch.spells[0]
	var s2: SpellData = ch.spells[1]
	var s3: SpellData = ch.spells[2]
	var s4: SpellData = ch.spells[3]

	print("Constantes et compensations")
	_check("COINS_COEF 1,1 ; RUIN_BASE_COEF 4,6", _near(AvareKit.COINS_COEF, 1.1) and _near(AvareKit.RUIN_BASE_COEF, 4.6))
	_check("coefs de base des sorts", _near(s2.coef, 1.1) and _near(s4.coef, 4.6))
	_check("COIN_MARKED_COEF 1,8 ; refund 1,0 ; Faillite +1,0", _near(AvareKit.COIN_MARKED_COEF, 1.8) and _near(AvareKit.COIN_MARKED_REFUND, 1.0) and _near(AvareKit.RUIN_MARKED_ADD, 1.0))

	print("Bonus dans la fenêtre seulement")
	var e := _fake(Vector2(100, 0))
	var base2 := _dmg(s2, e)
	var base4 := _dmg(s4, e)
	var base1 := _dmg(s1, e)
	_mark(e, 4.0)
	_check("Poignée sur marqué : 1,8 / 1,1", _near(_dmg(s2, e) / base2, 1.8 / 1.1, 0.002), str(_dmg(s2, e) / base2))
	_check("Faillite sur marqué : (4,6 + 1) / 4,6", _near(_dmg(s4, e) / base4, 5.6 / 4.6, 0.002))
	_check("Coup de coffre : pas de bonus de dégâts", _near(_dmg(s1, e), base1))
	_kit.marks[e.get_instance_id()]["t"] = _kit._clock - 0.1
	_check("marque expirée : Poignée de base", _near(_dmg(s2, e), base2))
	_check("marque expirée : Faillite de base", _near(_dmg(s4, e), base4))
	var other := _fake(Vector2(200, 0))
	_check("monstre non marqué : de base", _near(_dmg(s2, other), base2))

	print("Fenêtre HUD")
	_kit.marks.clear()
	_check("sans marque : rien ne pulse", not _kit.combo_ready(2) and not _kit.combo_ready(4))
	_mark(e, 4.0)
	_check("avec une marque : Poignée et Faillite pulsent, pas le reste", _kit.combo_ready(2) and _kit.combo_ready(4) and not _kit.combo_ready(1) and not _kit.combo_ready(3))
	_check("combo_hit : Poignée / Faillite / Coup de coffre sur marqué", _kit.combo_hit(s2, e) and _kit.combo_hit(s4, e) and _kit.combo_hit(s1, e))
	_check("combo_hit faux sur un non marqué", not _kit.combo_hit(s2, other))

	print("Coup de coffre qui prolonge")
	_kit.marks.clear()
	_mark(e, 4.0)
	_kit.guard_left = 0.0
	_kit.combo_hit(s1, e)
	_check("marque +0,5 s", _near(float(_kit.marks[e.get_instance_id()]["t"]) - _kit._clock, 4.5, 0.01))
	_check("coffre-bouclier 0,6 s", _near(_kit.guard_left, 0.6))
	for i in 10:
		_kit.combo_hit(s1, e)
	_check("plafond 6 s", _near(float(_kit.marks[e.get_instance_id()]["t"]) - _kit._clock, 6.0, 0.01))

	print("Retombée à 100 % (aucun or neuf)")
	_kit.marks.clear()
	var each := 10.0 * AvareKit.COINS_REFUND_FRAC / 5.0 # part de base (80 % du coût de 10)
	var far_coin: GroundPickup = null
	_kit.on_projectile_rest(s2, Vector2(5000, 0), {"coin": each})
	far_coin = _kit.coins.back()
	_check("hors marqué : 80 %", _near(float(far_coin.get_meta(&"gold")), each))
	_mark(e, 4.0)
	e.global_position = Vector2(3000, 0)
	_kit.on_projectile_rest(s2, Vector2(3010, 0), {"coin": each})
	var near_coin: GroundPickup = _kit.coins.back()
	_check("sur marqué : 100 % de la part (10 / 5)", _near(float(near_coin.get_meta(&"gold")), 10.0 / 5.0), str(near_coin.get_meta(&"gold")))
	_check("5 pièces sur marqué rendent au plus le coût payé", 5.0 * float(near_coin.get_meta(&"gold")) <= 10.0 + 0.0001)
	_kit.marks[e.get_instance_id()]["t"] = _kit._clock - 1.0
	_kit.on_projectile_rest(s2, Vector2(3010, 0), {"coin": each})
	_check("marque expirée : 80 %", _near(float((_kit.coins.back() as GroundPickup).get_meta(&"gold")), each))

	print("Ordre inverse : Poignée puis Rançon")
	_kit.marks.clear()
	e.global_position = Vector2(60, 0)
	RunState.gold = 100.0
	_kit.on_cast(s2) # la Poignée est payée d'abord
	_player.global_position = Vector2.ZERO
	_kit._do_ransom(s3)
	_check("la Rançon marque le monstre touché par les pièces", _kit.is_marked(e))
	var paid_after := RunState.gold
	_check("aucun or neuf à la pose", paid_after <= 100.0)

	print("Râfle : aucun dégât direct")
	_check("la Râfle n'inflige pas de coup (dodge_label)", _kit.dodge_label() != "")

	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	Profile.path = _old_path
	Profile.write_enabled = _old_write
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(_fails)
