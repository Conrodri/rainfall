extends Node
## Combos de Taliant (docs/Design_Combos.md §5.7) : Iaï -> Fauche-lune (coût 15 -> 8 %, recul 1,4 u, fenêtre 1,5 s),
## Garde qui rend (+2 % d'aiguisage, une parade par 0,3 s). Bonus dans la fenêtre seulement.
## godot --headless --path game res://tests/morfil_combos_test.tscn

class FakeEnemy extends Node2D:
	var radius_px := 16.0

	func take_damage(_amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		pass

	func apply_status(_status: StringName, _data: Dictionary) -> void:
		pass

	func is_slowed() -> bool:
		return false

var _fails := 0
var _player: CharacterBody2D
var _kit: MorfilKit
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _advance(t: float) -> void:
	for i in int(ceil(t * 60.0)):
		_player.spells._remaining[1] = 99.0
		if _player.is_dodging():
			_player.dodge_step(1.0 / 60.0)
		_player.tick(1.0 / 60.0)
	_player.spells._remaining[1] = 0.0


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.sharpness = MorfilKit.SHARP_MAX
	_kit.twin_left = 0.0
	_kit.guard_left = 0.0
	_kit._parry_cd = 0.0
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.dead = false
	_player._invuln = 0.0
	_player.reset_dodge()
	_player.apply_stats({"crit_chance": -0.05})


func _run() -> void:
	RunState.level = 1
	RunState.character = &"morfil"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as MorfilKit
	_reset()

	print("Constantes")
	_check("IAI_OPEN_S 1,5 ; coût 8 ; recul 1,4 ; parade 2 / 0,3 s", _near(MorfilKit.IAI_OPEN_S, 1.5) and _near(MorfilKit.COST_CRESCENT_AFTER_IAI, 8.0)
		and _near(MorfilKit.IAI_OPEN_KNOCK_U, 1.4) and _near(MorfilKit.PARRY_SHARP, 2.0) and _near(MorfilKit.PARRY_CD_S, 0.3))
	_check("Fauche-lune de base inchangée (15 %, 4,0)", _near(MorfilKit.COST_CRESCENT, 15.0) and _near(MorfilKit.CRESCENT_COEF, 4.0))

	print("Fauche-lune sans Iaï")
	_check("fenêtre fermée : pas de pulsation", not _kit.combo_ready(2))
	_kit.sharpness = 100.0
	_kit._crescent(Vector2.RIGHT)
	_check("coût 15 %", _near(_kit.sharpness, 85.0), str(_kit.sharpness))
	_check("pas de coup de combo", not _kit.combo_hit(_kit._strike_spell(&"fauche_lune", 4.0, 1.0, 1.0, 3.5), null))

	print("Iaï -> Fauche-lune")
	_reset()
	_check("rien d'ouvert avant l'Iaï", _kit._iai_open_left == 0.0)
	_kit.on_dodge_start(Vector2.RIGHT)
	_check("fenêtre ouverte dès l'Iaï, bouton 2 pulse", _kit.combo_ready(2) and not _kit.combo_ready(1))
	_kit._iai_active = false
	_kit._iai_open_left = MorfilKit.IAI_OPEN_S
	_advance(1.4)
	_check("encore ouverte à 1,4 s", _kit.combo_ready(2))
	_advance(0.2)
	_check("refermée après 1,5 s", not _kit.combo_ready(2))
	_kit._iai_open_left = MorfilKit.IAI_OPEN_S
	_check("info de coût : 8 %", str(_kit.slot_cost_info(2)["cost"]).begins_with("8"))
	_kit._crescent(Vector2.RIGHT)
	_check("coût 8 % dans la fenêtre", _near(_kit.sharpness, 92.0), str(_kit.sharpness))
	_check("la fenêtre est consommée", not _kit.combo_ready(2))
	_check("coups de combo pendant la résolution", _kit.combo_hit(_kit._strike_spell(&"fauche_lune", 4.0, 1.0, 1.0, 3.5), null))
	_advance(0.6)
	_check("combo_hit s'éteint", not _kit.combo_hit(_kit._strike_spell(&"fauche_lune", 4.0, 1.0, 1.4, 3.5), null))
	_kit._crescent(Vector2.RIGHT)
	_check("seconde Fauche : retour à 15 %", _near(_kit.sharpness, 92.0 - 15.0), str(_kit.sharpness))
	_check("coef inchangé par la fenêtre (aucun bonus de dégâts)", _near(MorfilKit.CRESCENT_COEF, 4.0))

	print("Recul 1,4 u dans la fenêtre")
	_reset()
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	_junk.append(e)
	_kit._iai_open_left = 1.0
	var spy := _kit._strike_spell(&"fauche_lune", 4.0, 1.0, MorfilKit.IAI_OPEN_KNOCK_U, 3.5)
	var base := _kit._strike_spell(&"fauche_lune", 4.0, 1.0, MorfilKit.CRESCENT_KNOCK_U, 3.5)
	_check("hit_force plus grande", spy.hit_force > base.hit_force, "%s %s" % [spy.hit_force, base.hit_force])

	print("Garde qui rend")
	_reset()
	_kit.sharpness = 50.0
	_kit.guard_left = 0.5
	Events.player_damaged.emit(5.0, null)
	_check("coup sous garde : +2 %", _near(_kit.sharpness, 52.0), str(_kit.sharpness))
	Events.player_damaged.emit(5.0, null)
	_check("une parade par 0,3 s", _near(_kit.sharpness, 52.0))
	_advance(0.35)
	_kit.guard_left = 0.5
	Events.player_damaged.emit(5.0, null)
	_check("après 0,3 s : +2 % de nouveau", _near(_kit.sharpness, 54.0), str(_kit.sharpness))
	_kit.guard_left = 0.0
	_advance(0.35)
	Events.player_damaged.emit(5.0, null)
	_check("hors garde : rien", _near(_kit.sharpness, 54.0))
	_kit.sharpness = 99.0
	_kit.guard_left = 0.5
	_kit._parry_cd = 0.0
	Events.player_damaged.emit(5.0, null)
	_check("plafonné à 100 %", _near(_kit.sharpness, 100.0))

	print("Esquive : aucun dégât direct hors Iaï")
	_check("combo_ready faux hors slot 2", not _kit.combo_ready(4) and not _kit.combo_ready(3))

	for j in _junk:
		if is_instance_valid(j):
			j.queue_free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(_fails)
