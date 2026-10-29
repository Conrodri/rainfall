extends Node
## Correctif du 24/10/2026 (bug joueur) : les sorts d'Arpenteuse doivent tous marcher quand la chaîne est attachée au
## poteau (Piquet planté). Avant : le Halage exigeait une traîne d'au moins 3 u et ne frappait que la traîne, donc
## refusé (ou sans effet) dès que le touret l'avait rembobinée, poteau posé. Chaque sort est lancé poteau posé et doit
## produire son effet, la chaîne restant attachée au poteau.
## godot --headless --path game res://tests/arpenteuse_peg_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []
	var pushes: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func push(v: Vector2) -> void:
		pushes.append(v)

	func is_slowed() -> bool:
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t

	func has_status(s: StringName) -> bool:
		for st in statuses:
			if st[0] == s:
				return true
		return false


const U := 64.0
const BASE := 12.0
const DT := 1.0 / 60.0

var _fails := 0
var _player: CharacterBody2D
var _kit: ArpenteuseKit
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


func _wait(seconds: float) -> void:
	for i in int(round(seconds / DT)):
		_player.tick(DT)


func _to_impact() -> void:
	var t := 0.0
	while _kit.has_pending() and t < 1.5:
		_player.tick(DT)
		t += DT


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_player.reset_dodge()
	_kit._last_head = Vector2.ZERO
	_kit._tick_t = 0.0
	_kit._idle_t = 0.0
	RunState.counters.clear()
	_player.tick(DT)


## Piquet planté à 5 u, puis le touret a rembobiné la traîne (le joueur est resté sur place).
func _plant_and_idle() -> void:
	_reset()
	_player.spells.aim_override = Vector2(5 * U, 0)
	_player.spells.cast(3)
	_to_impact()
	_wait(2.5)


func _attached() -> bool:
	if not _kit.peg_active():
		return false
	var pts: PackedVector2Array = _kit.peg_line.base.points
	return pts.size() == 2 and pts[0].distance_to(_kit.peg_pos) < 1.0 and pts[1].distance_to(_player.global_position) < 1.0


func _run() -> void:
	RunState.level = 1
	RunState.character = &"arpenteuse"
	RunState.loadout = {}
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as ArpenteuseKit

	print("Poteau posé, traîne rembobinée")
	_plant_and_idle()
	_check("poteau actif, traîne rembobinée", _kit.peg_active() and _kit.chain_length() < 0.5 * U, str(_kit.chain_length() / U))
	_check("chaîne attachée au poteau (ligne poteau -> elle)", _attached())

	print("Sort 2 : Halage poteau posé")
	var m := _fake(Vector2(3 * U, 0.6 * U)) # à 0,6 u de la ligne du poteau
	var far := _fake(Vector2(3 * U, 3 * U))
	_kit._peg_hits[m.get_instance_id()] = 1.0e9 # isole le Halage du balayage du poteau
	_player.spells._remaining[2] = 0.0
	_check("Halage lancé (la ligne du poteau compte comme chaîne)", _player.spells.cast(2))
	_to_impact()
	_check("Halage : coef 3,5 sur la ligne du poteau", _near(m.total(), 3.5 * BASE), str(m.taken))
	_check("Halage : attiré vers la ligne", m.pushes.size() == 1 and m.pushes[0].y < 0.0, str(m.pushes))
	_check("Halage : hors bande, rien", far.taken.is_empty())
	_check("Halage : chaîne toujours attachée", _attached())
	_check("auto-cast : un seul monstre sur la ligne -> non (attend 2)", not _kit.auto_cast_ok(2))
	var m2 := _fake(Vector2(4 * U, -0.5 * U))
	_kit._probe_t = -1.0
	_check("auto-cast : deux monstres sur la ligne -> ok", _kit.auto_cast_ok(2))

	print("Sort 3 : Piquet (balayage) poteau posé")
	var sw := _fake(Vector2(2 * U, 0.1 * U))
	_wait(0.05)
	_check("balayage de la ligne tendue : coef 1,0", sw.taken.size() >= 1 and _near(sw.taken[0], BASE), str(sw.taken))
	_check("Piquet : chaîne toujours attachée", _attached())

	print("Sort 1 : Chaîne (auto) poteau posé")
	_kit._peg_hits[sw.get_instance_id()] = 1.0e9
	_kit._peg_hits[m.get_instance_id()] = 1.0e9
	# le joueur avance de 3 u (reste à moins de 10 u du poteau) : la traîne se pose derrière lui
	var from := _player.global_position
	for i in 45:
		_player.global_position = from + Vector2(3 * U, 0) * float(i + 1) / 45.0
		_player.tick(DT)
	var on_trail := _fake(Vector2(1.5 * U, 0.1 * U))
	_kit._peg_hits[on_trail.get_instance_id()] = 1.0e9
	_wait(0.55)
	_check("Chaîne : tick sur la traîne (coef 1,0)", on_trail.taken.size() >= 1 and _near(on_trail.taken[0], BASE), str(on_trail.taken))
	_check("Chaîne : poteau toujours attaché", _attached())

	print("Sort 4 : Tendeur poteau posé")
	_plant_and_idle()
	var t := _fake(Vector2(2.5 * U, 0.8 * U))
	_kit._peg_hits[t.get_instance_id()] = 1.0e9
	_check("Tendeur lancé (poteau seul)", _player.spells.cast(4))
	_to_impact()
	_check("Tendeur : coef 10 sur la ligne du poteau", _near(t.total(), 10.0 * BASE), str(t.taken))
	_wait(ArpenteuseKit.SNAP_S + 0.05)
	_check("Tendeur : traîné jusqu'à elle, emprisonné", t.pushes.size() == 1 and t.has_status(&"imprisoned"), str(t.pushes))
	_check("Tendeur : chaîne toujours attachée", _attached())

	print("Combo : Piquet puis Halage puis Tendeur, enchaînés")
	_plant_and_idle()
	var e1 := _fake(Vector2(2 * U, 0.7 * U))
	var e2 := _fake(Vector2(4 * U, -0.7 * U))
	_kit._peg_hits[e1.get_instance_id()] = 1.0e9
	_kit._peg_hits[e2.get_instance_id()] = 1.0e9
	_check("Halage", _player.spells.cast(2))
	_to_impact()
	_check("Halage a frappé les deux", e1.taken.size() == 1 and e2.taken.size() == 1)
	_check("Tendeur", _player.spells.cast(4))
	_to_impact()
	_check("Tendeur a frappé les deux", e1.taken.size() == 2 and e2.taken.size() == 2)
	_check("chaîne attachée en fin de combo", _attached())

	_reset()
	_player.queue_free()
	director.queue_free()
	await get_tree().process_frame
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
