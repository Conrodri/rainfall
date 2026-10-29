extends Node
## Test headless des combos d'Averse (docs/Design_Combos.md §4) : AV-1 Vague -> Crue, AV-2 Flaque -> Vague de fond
## (Flaque non consommée), AV-3 Goutte sur trempé, AV-4 sillage de la Glissade, combo_ready.
## godot --headless --path game res://tests/averse_combos_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var is_boss := false
	var is_elite := false

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func last_slow() -> Dictionary:
		for i in range(statuses.size() - 1, -1, -1):
			if statuses[i][0] == &"slow":
				return statuses[i][1]
		return {}


const U := 64.0
const BASE := 12.0 ## dégât de base niveau 1

var _fails := 0
var _player: CharacterBody2D
var _kit: Node
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


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _reset(w: float = 50.0) -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.water = w
	_kit.dry_left = 0.0
	_kit._rain_mult = 0.0
	_kit._rain_t = 99.0
	_kit._soaked_until.clear()
	_kit._lock_left = 0.0
	_kit._kit_clock = 100.0
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
	RunState.counters.clear()


func _run() -> void:
	RunState.level = 1
	RunState.character = &"averse"
	RunState.loadout = {}
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit
	_check("kit Averse", _kit is AverseKit)

	print("Constantes (compensations)")
	_check("CRUE_COEF_FULL 8,6, WAVE_COEF 3,4, HIT_WATER 0,4, GOUTTE_COEF_MIN 0,7",
			_near(AverseKit.CRUE_COEF_FULL, 8.6) and _near(AverseKit.WAVE_COEF, 3.4) and _near(AverseKit.HIT_WATER, 0.4) and _near(AverseKit.GOUTTE_COEF_MIN, 0.7))

	print("AV-1 : Crue sur trempés")
	_reset(100.0)
	var wet := _fake(Vector2(2.0 * U, 0))
	var dry := _fake(Vector2(-2.0 * U, 0))
	_kit._soak(wet)
	_check("is_soaked / is_marked", _kit.is_soaked(wet) and _kit.is_marked(wet) and not _kit.is_soaked(dry))
	_check("Crue lancée", _player.spells.cast(4))
	_kit.flush_pending()
	_check("les deux touchés", wet.taken.size() == 1 and dry.taken.size() == 1, "%s %s" % [wet.taken, dry.taken])
	if wet.taken.size() == 1 and dry.taken.size() == 1:
		_check("trempé >= +20 %", wet.taken[0] >= dry.taken[0] * 1.19, "%s vs %s" % [wet.taken[0], dry.taken[0]])
		_check("combo_hit seulement sur trempé (slot 4)", _kit.combo_hit(_player.character.spells[3], wet) and not _kit.combo_hit(_player.character.spells[3], _fake(Vector2(900, 900))))
	_check("coef de la Crue pleine 8,6", _near(AverseKit.crue_coef(100.0), 8.6))

	print("AV-2 : Flaque -> Vague de fond")
	_reset(100.0)
	var pz: Node2D = _kit.spawn_puddle(_kit._puddle_spell(), Vector2(3.0 * U, 0))
	var t1 := _fake(Vector2(4.0 * U, 0))
	_player.spells.aim_override = Vector2(500, 0)
	_check("Vague lancée", _player.spells.cast(2))
	_kit.flush_pending()
	var deep: float = t1.total()
	var expect := (AverseKit.WAVE_COEF + AverseKit.WAVE_PUDDLE_ADD) * BASE
	_check("dégâts = (coef + 0,5) x base", _near(deep, expect, 0.2), "%s / %s" % [deep, expect])
	var sl := t1.last_slow()
	_check("trempe 8 s / 40 %", not sl.is_empty() and _near(float(sl["duration"]), 8.0) and _near(float(sl["pct"]), 0.4), str(sl))
	_check("Flaque non consommée", is_instance_valid(pz) and not pz.is_ending() and _kit.puddles.has(pz))
	# Vague hors Flaque : pas de bonus.
	_reset(100.0)
	var t2 := _fake(Vector2(4.0 * U, 0))
	_player.spells.aim_override = Vector2(500, 0)
	_player.spells.cast(2)
	_kit.flush_pending()
	_check("sans Flaque : coef de base, trempe 4 s / 30 %", _near(t2.total(), AverseKit.WAVE_COEF * BASE, 0.2) and _near(float(t2.last_slow().get("duration", 0)), 4.0))
	# Vague lancée depuis la Flaque (cône dans l'autre sens).
	_reset(100.0)
	_kit.spawn_puddle(_kit._puddle_spell(), Vector2.ZERO)
	var t3 := _fake(Vector2(-4.0 * U, 0))
	_player.spells.aim_override = Vector2(-500, 0)
	_player.spells.cast(2)
	_kit.flush_pending()
	_check("depuis la Flaque : +0,5 coef", _near(t3.total(), expect, 0.2), str(t3.total()))

	print("AV-3 : Goutte sur trempé")
	_reset(50.0)
	var g: SpellData = _player.character.spells[0]
	var gw := _fake(Vector2(500, 500))
	var gd := _fake(Vector2(500, 600))
	_kit._soak(gw)
	_check("coef additif +0,25 sur trempé, 0 sinon", _near(_kit.combo_coef_add(g, gw), 0.25) and _kit.combo_coef_add(g, gd) == 0.0)
	_kit.on_spell_hit(g, gd, 1.0)
	var w_dry: float = _kit.water - 50.0
	_kit.water = 50.0
	_kit.on_spell_hit(g, gw, 1.0)
	var w_wet: float = _kit.water - 50.0
	_check("eau : HIT_WATER 0,4 sec, +1,0 trempé", _near(w_dry, 0.4) and _near(w_wet, 1.4), "%s %s" % [w_dry, w_wet])
	_check("dégâts via SpellCaster : trempé > sec", _player.spells.compute_damage(g, gw, false) > _player.spells.compute_damage(g, gd, false))

	print("AV-4 : sillage de la Glissade")
	_reset(100.0)
	var ka := _fake(Vector2(2.0 * U, 10.0))
	var kb := _fake(Vector2(2.0 * U, 6.0 * U))
	_check("glisse commencée", _kit.slide_begin())
	for i in range(1, 8):
		_kit.slide_trail(Vector2.ZERO, Vector2(i * 0.5 * U, 0))
	_kit._wake_t = 0.0
	_kit.tick(0.3)
	var ws := ka.last_slow()
	_check("monstre sur la trace : trempe 2 s / 30 %", not ws.is_empty() and _near(float(ws["duration"]), 2.0) and _near(float(ws["pct"]), 0.3), str(ws))
	_check("monstre loin : sec", kb.statuses.is_empty())
	_check("aucun dégât", ka.taken.is_empty())
	_check("<= 80 points", _kit._wake_pts.size() <= AverseKit.SLIDE_WAKE_MAX_POINTS)
	_kit.slide_end(false)
	var kc := _fake(Vector2(1.0 * U, 5.0))
	_kit._wake_t = 0.0
	_kit.tick(0.3)
	_check("la trace trempe encore après l'arrêt (fondu 1 s)", not kc.statuses.is_empty())
	_kit.tick(1.0)
	var n := kc.statuses.size()
	_kit._wake_t = 0.0
	_kit.tick(0.3)
	_check("puis plus rien", kc.statuses.size() == n)

	print("combo_ready")
	_reset(100.0)
	_kit.invalidate_combo_cache()
	_check("faux sans trempé ni Flaque", not _kit.combo_ready(4) and not _kit.combo_ready(2))
	var r1 := _fake(Vector2(2.0 * U, 0))
	var r2 := _fake(Vector2(-2.0 * U, 0))
	var r3 := _fake(Vector2(0, 2.0 * U))
	_kit._soak(r1)
	_kit._soak(r2)
	_kit.invalidate_combo_cache()
	_check("2 trempés : Crue faux", not _kit.combo_ready(4))
	_kit._soak(r3)
	_kit.invalidate_combo_cache()
	_check("3 trempés : Crue vrai", _kit.combo_ready(4))
	_kit.spawn_puddle(_kit._puddle_spell(), Vector2(2.0 * U, 0))
	_kit.invalidate_combo_cache()
	_check("Flaque vivante : Vague vrai", _kit.combo_ready(2))
	_kit._kit_clock += 100.0 # trempes expirées
	_kit.invalidate_combo_cache()
	_check("trempes finies : Crue faux", not _kit.combo_ready(4))
	_check("slots 1 et 3 : faux", not _kit.combo_ready(1) and not _kit.combo_ready(3))

	_reset()
	for j in _junk:
		if is_instance_valid(j):
			j.queue_free()
	if _fails == 0:
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
