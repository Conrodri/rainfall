extends Node
## Test headless des combos de Grésille (docs/fiches/gresille.md §6, docs/Design_Combos.md) : GR-1 Arc -> Décharge
## (la Décharge sur une cible chargée est un coup de combo : chiffre couleur combo via DamageNumbers.combo_tint, son
## combo), combo_ready (bouton 2 à >= 4 cumuls, bouton 4 à 5 cumuls), pas de combo sans charge ni sur les arcs voisins.
## godot --headless --path game res://tests/gresille_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var tints: Array = [] ## DamageNumbers.combo_tint relevé au moment de chaque coup
	var statuses: Array = []
	var wet := false
	var is_boss := false
	var is_elite := false
	var active := true
	var radius_px := 20.0

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)
		tints.append(DamageNumbers.combo_tint)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func is_wet() -> bool:
		return wet

	func mark_wet(_seconds: float) -> void:
		wet = true

	func stun(_seconds: float) -> void:
		pass

	func add_damage_taken_mod(_id: Variant, _mult: float, _duration: float = -1.0) -> void:
		pass

	func combo_tinted() -> bool:
		return not tints.is_empty() and tints[0].a > 0.0


const U := 64.0

var _fails := 0
var _player: CharacterBody2D
var _kit: GresilleKit
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


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.storm_left = 0.0
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_player._invuln = 0.0
	StageMap.water_override = {}


func _cast(slot: int) -> bool:
	var ok: bool = _player.spells.cast(slot)
	_kit.flush_pending()
	return ok


func _run() -> void:
	RunState.level = 1
	RunState.character = &"gresille"
	RunState.loadout = {}
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as GresilleKit
	_check("kit Grésille", _kit != null)

	print("GR-1 Arc -> Décharge")
	_reset()
	var hot := _fake(Vector2(4 * U, 0))
	for i in GresilleKit.COMBO_READY_STACKS:
		_kit.apply_static(hot, false)
	_kit._probe_ready()
	_check("combo_ready(2) : cible à >= 4 cumuls à portée", _kit.combo_ready(2))
	_check("combo_ready(4) faux (pas 5 cumuls)", not _kit.combo_ready(4))
	_check("Décharge lancée", _cast(2))
	_check("coup de Décharge sur cible chargée : un seul coup", hot.taken.size() == 1, str(hot.taken))
	_check("le coup est un coup de combo (couleur combo)", hot.combo_tinted(), str(hot.tints))
	_check("combo_hit retombe à faux après le coup", not _kit.combo_hit(_kit._spell_of(2), hot))

	print("Pas de combo")
	_reset()
	var cold := _fake(Vector2(4 * U, 0))
	_kit.apply_static(cold, false)
	_kit._probe_ready()
	_check("combo_ready(2) faux à 1 cumul", not _kit.combo_ready(2))
	_check("Décharge lancée sur une cible à 1 cumul", _cast(2))
	_check("coup sans combo : pas de teinte", cold.taken.size() == 1 and not cold.combo_tinted(), str(cold.tints))

	_reset()
	var core := _fake(Vector2(4 * U, 0))
	var nb := _fake(Vector2(6 * U, 0))
	for i in GresilleKit.COMBO_READY_STACKS:
		_kit.apply_static(core, false)
	_cast(2)
	_check("l'arc voisin n'est pas un coup de combo", nb.taken.size() >= 1 and not nb.combo_tinted(), str(nb.tints))

	print("GR-2 combo_ready(4)")
	_reset()
	var five := _fake(Vector2(5 * U, 0))
	for i in 5:
		_kit.apply_static(five, false)
	_kit._probe_ready()
	_check("combo_ready(4) : cible à 5 cumuls à portée de l'Orage", _kit.combo_ready(4))
	_reset()
	_kit._probe_ready()
	_check("combo_ready faux sans cible", not _kit.combo_ready(2) and not _kit.combo_ready(4))

	_reset()
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
