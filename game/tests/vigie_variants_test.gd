extends Node
## Test headless des variantes de sorts de Vigie (docs/Variantes_Sorts.md §2.9, CONTRACTS.md « Variantes de sorts ») :
## substitution par CharacterData.for_id, Tir double (+ volée), Fanal, Chausse-trapes, Tir de signal, compteurs
## (vigie_exposed / vigie_netted / vigie_grele_kills) et règles de déblocage de characters.json.
## godot --headless --path game res://tests/vigie_variants_test.tscn  (scène : les autoloads doivent exister)

class FakeEnemy extends StaticBody2D:
	var taken: Array = []
	var statuses: Array = []
	var mods: Array = []
	var is_boss := false

	func _init() -> void:
		collision_layer = 4 # les flèches (masque 4) les touchent
		collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = 10.0
		cs.shape = sh
		add_child(cs)

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"", _hit: Dictionary = {}) -> void:
		taken.append(amount)

	func apply_status(status: StringName, data: Dictionary) -> void:
		statuses.append([status, data])

	func add_damage_taken_mod(id: Variant, mult: float, duration: float = -1.0) -> void:
		mods.append([id, mult, duration])

	func is_slowed() -> bool:
		return false

	func has_status(st: StringName) -> bool:
		for s in statuses:
			if s[0] == st:
				return true
		return false

	func status_data(st: StringName) -> Dictionary:
		for s in statuses:
			if s[0] == st:
				return s[1]
		return {}

	func exposed() -> bool:
		for m in mods:
			if m[0] == VigieKit.EXPOSE_ID:
				return true
		return false

	func total() -> float:
		var t := 0.0
		for a in taken:
			t += a
		return t


class FakeProfile extends RefCounted:
	var stats := {}
	var unlocked_spells: Array = []

	func stat(key: String) -> float:
		return float(stats.get(key, 0.0))


const VU := preload("res://scripts/save/variant_unlocks.gd")
const U := 64.0
const BASE := 12.0 ## Dégât_base niveau 1
const LOADOUT := {1: &"vigie_tir_double", 2: &"vigie_fanal", 3: &"vigie_chausse_trapes", 4: &"vigie_tir_de_signal"}

var _fails := 0
var _player: CharacterBody2D
var _kit: VigieKit
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


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Avance le joueur de `t` s (pas de 0,01 s), sort 1 suspendu sauf `auto`, immobile sauf `moving`.
func _advance(t: float, auto := false, moving := false) -> void:
	for i in roundi(t / 0.01):
		if not auto:
			_player.spells._remaining[1] = 99.0
		_player.is_moving = moving
		_player.tick(0.01)
		for arr in [_kit.hails, _kit.flares, _kit.caltrops]:
			for z in arr:
				if is_instance_valid(z):
					z.set_process(false)
					z.step(0.01)
	if not auto:
		_player.spells._remaining[1] = 0.0


func _wait_projectiles(max_frames := 90) -> void:
	for i in max_frames:
		if _player.spells.active_projectile_count() == 0:
			return
		await get_tree().physics_frame


func _flush() -> void:
	var t := 0.0
	while _kit.has_pending() and t < 1.2:
		_advance(0.01)
		t += 0.01


func _reset(tension: float = 0.0) -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.clear_transients()
	_kit.set_tension(tension)
	_kit.still_t = 0.0
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
	RunState.counters.clear()


func _run() -> void:
	# --- substitution (sans joueur) ---------------------------------------------------------------
	print("Substitution")
	var base_cd := CharacterData.for_id(&"vigie", {})
	_check("sans loadout : sorts de base", base_cd.spells.map(func(s): return String(s.id)) == ["vigie_trait", "vigie_fusee", "vigie_filet", "vigie_grele"])
	var var_cd := CharacterData.for_id(&"vigie", LOADOUT)
	_check("4 variantes substituées", var_cd.spells.map(func(s): return String(s.id)) == ["vigie_tir_double", "vigie_fanal", "vigie_chausse_trapes", "vigie_tir_de_signal"], str(var_cd.spells.map(func(s): return s.id)))
	_check("slots conservés", var_cd.spells.map(func(s): return s.slot) == [1, 2, 3, 4])
	_check("variant_of", var_cd.variant_of(1) == &"vigie_tir_double" and var_cd.variant_of(4) == &"vigie_tir_de_signal" and base_cd.variant_of(2) == &"")
	_check("slot 1 reste auto", var_cd.spells[0].is_auto)
	_check("variante inconnue : sort de base", CharacterData.for_id(&"vigie", {1: &"vigie_fantome"}).spells[0].id == &"vigie_trait")
	_check("variant() inconnue = null", VigieKit.variant(1, &"nope") == null and VigieKit.variant(2, &"vigie_tir_double") == null)

	# --- characters.json ---------------------------------------------------------------------------
	print("characters.json")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters.json"))
	var declared := {}
	for c in data:
		if c is Dictionary and str(c.get("id", "")) == "vigie":
			var spells_json: Array = c.get("spells", [])
			for i in spells_json.size():
				for v in spells_json[i].get("variants", []):
					declared[i + 1] = str(v.get("id", ""))
	_check("4 variantes déclarées, ids = ids codés", declared.size() == 4 and declared.get(1) == "vigie_tir_double" and declared.get(2) == "vigie_fanal"
			and declared.get(3) == "vigie_chausse_trapes" and declared.get(4) == "vigie_tir_de_signal", str(declared))
	var all_coded := true
	for slot in declared:
		all_coded = all_coded and VigieKit.variant(int(slot), StringName(declared[slot])) != null
	_check("chaque variante déclarée est codée", all_coded)

	# --- déblocage ---------------------------------------------------------------------------------
	print("Déblocage")
	var prof := FakeProfile.new()
	_check("Tir double : victoire avec Vigie", VU.evaluate(prof, data, {"victory": true, "character": "vigie", "mode": "moyen", "stage": 5}).has(&"spell:vigie_tir_double"))
	_check("Tir double : défaite = non", not VU.evaluate(prof, data, {"victory": false, "character": "vigie", "stage": 3}).has(&"spell:vigie_tir_double"))
	prof.stats["vigie_exposed"] = 999.0
	_check("Fanal : 999 = non", not VU.evaluate(prof, data, {"character": "vigie", "stage": 1}).has(&"spell:vigie_fanal"))
	prof.stats["vigie_exposed"] = 1000.0
	_check("Fanal : 1 000", VU.evaluate(prof, data, {"character": "vigie", "stage": 1}).has(&"spell:vigie_fanal"))
	prof.stats["vigie_netted"] = 500.0
	_check("Chausse-trapes : 500", VU.evaluate(prof, data, {"character": "vigie", "stage": 1}).has(&"spell:vigie_chausse_trapes"))
	prof.stats["vigie_grele_kills"] = 299.0
	_check("Tir de signal : 299 = non", not VU.evaluate(prof, data, {"character": "vigie", "stage": 1}).has(&"spell:vigie_tir_de_signal"))
	prof.stats["vigie_grele_kills"] = 300.0
	_check("Tir de signal : 300", VU.evaluate(prof, data, {"character": "vigie", "stage": 1}).has(&"spell:vigie_tir_de_signal"))

	# --- en jeu ------------------------------------------------------------------------------------
	RunState.level = 1
	RunState.character = &"vigie"
	RunState.loadout = LOADOUT.duplicate()
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as VigieKit
	print("Joueur avec variantes")
	_check("kit Vigie", _kit != null)
	_check("sorts du joueur = variantes", _player.get_spell_cooldowns().map(func(c): return String(c.id)) == ["vigie_tir_double", "vigie_fanal", "vigie_chausse_trapes", "vigie_tir_de_signal"])

	print("Sort 1 : Tir double")
	_reset(0.0)
	_check("sans ennemi : rien", not _player.spells.cast(1))
	var d1 := _fake(Vector2(3 * U, 0))
	var d2 := _fake(Vector2(5 * U, 1.5 * U))
	var d3 := _fake(Vector2(7 * U, 0))
	_check("tir lancé", _player.spells.cast(1))
	_flush()
	_check("2 flèches parties", _player.spells.active_projectile_count() == 2, str(_player.spells.active_projectile_count()))
	await _frames(40)
	_check("coef 0,42 sur les deux plus proches, pas la 3e", d1.taken.size() == 1 and d2.taken.size() == 1 and d3.taken.is_empty()
			and _near(d1.taken[0], VigieKit.DOUBLE_COEF * BASE, 0.05), "%s %s %s" % [d1.taken, d2.taken, d3.taken])
	_reset(0.0)
	var lone := _fake(Vector2(4 * U, 0))
	_player.spells.cast(1)
	_flush()
	await _frames(40)
	_check("un seul ennemi : les deux flèches sur lui", lone.taken.size() == 2, str(lone.taken))
	_reset(0.0)
	var out_of_range := _fake(Vector2(8.5 * U, 0))
	_check("portée 8 u (pas 9)", not _player.spells.cast(1))
	out_of_range.global_position = Vector2(7.5 * U, 0)
	_check("à 7,5 u : tire", _player.spells.cast(1))

	print("Volée d'allonge (Tension pleine)")
	_reset(1.0)
	var line: Array = []
	for i in 3:
		line.append(_fake(Vector2((3 + 3 * i) * U, 0)))
	var up := _fake(Vector2(6 * U, 6 * U * tan(deg_to_rad(10.0)))) # sur le trait haut de l'éventail (10 deg)
	_check("volée lancée", _player.spells.cast(1))
	_check("Tension vidée", _near(_kit.tension, 0.0))
	_flush()
	_check("3 traits", _player.spells.active_projectile_count() == 3, str(_player.spells.active_projectile_count()))
	await _frames(50)
	var all_hit := true
	for b in line:
		all_hit = all_hit and b.taken.size() == 1 and _near(b.taken[0], VigieKit.VOLLEY_COEF * BASE, 0.05)
	_check("trait central perce toute la ligne à 1,2", all_hit, str(line.map(func(b): return b.taken)))
	_check("trait en éventail touche la cible décalée de 10 deg", up.taken.size() >= 1, str(up.taken))

	print("Sort 2 : Fanal")
	_reset(0.0)
	var near_e := _fake(Vector2(2 * U, 0))
	var far_e := _fake(Vector2(5 * U, 0))
	_check("fanal lancé", _player.spells.cast(2))
	_check("recharge 8 s", _near(_player.get_spell_cooldowns()[1].total, 8.0, 0.01))
	_flush()
	_check("lumière attachée à Vigie", _kit.flares.size() == 1 and (_kit.flares[0] as Node2D).global_position.distance_to(_player.global_position) < 1.0)
	_player.global_position = Vector2(0, 2 * U)
	_advance(0.3)
	_check("la lumière suit Vigie", (_kit.flares[0] as Node2D).global_position.distance_to(_player.global_position) < 1.0)
	_check("monstre proche exposé, loin non", near_e.exposed() and not far_e.exposed())
	_check("aucun dégât propre", near_e.taken.is_empty())
	_check("compteur vigie_exposed incrémenté", int(RunState.counters.get("vigie_exposed", 0)) >= 1, str(RunState.counters))
	_kit.fanal_t = 0.0
	_player.is_moving = true
	_kit.still_t = 0.0
	var rate_off := _kit.tension_rate()
	_kit.fanal_t = 5.0
	var rate_on := _kit.tension_rate()
	_check("Fanal en marche : corde au rythme ancré (1 s)", rate_on > rate_off * 2.0, "%s %s" % [rate_on, rate_off])
	_kit.fanal_t = 0.0
	_player.is_moving = false

	print("Sort 3 : Chausse-trapes")
	_reset(0.0)
	_player.spells.aim_override = Vector2(5 * U, 0)
	var c1 := _fake(Vector2(5 * U, 1.5 * U))
	var cboss := _fake(Vector2(4 * U, -1 * U))
	cboss.is_boss = true
	var cfar := _fake(Vector2(5 * U, 4 * U))
	_check("chausse-trapes lancées", _player.spells.cast(3))
	_check("recharge 9 s", _near(_player.get_spell_cooldowns()[2].total, 9.0, 0.01))
	_flush()
	await _wait_projectiles()
	_check("champ posé", _kit.caltrops.size() == 1)
	_advance(0.3)
	_check("entrée : coup 0,6 une seule fois", c1.taken.size() == 1 and _near(c1.taken[0], VigieKit.CHAUSSE_ENTRY_COEF * BASE, 0.05), str(c1.taken))
	_advance(1.0)
	_check("toujours un seul coup tant qu'il reste", c1.taken.size() == 1)
	_check("ralenti 50 %, boss 25 %", _near(float(c1.status_data(&"slow").get("pct", 0)), 0.5) and _near(float(cboss.status_data(&"slow").get("pct", 0)), 0.25), str(c1.statuses))
	_check("hors champ : intact", cfar.taken.is_empty() and not cfar.has_status(&"slow"))
	_check("pas emprisonné (ce n'est pas un filet)", not c1.has_status(&"imprisoned"))
	_check("Tension +25 % par entrée (2 entrées)", _kit.tension >= 0.5 - 0.001, str(_kit.tension))
	_check("pas de compteur vigie_netted", not RunState.counters.has("vigie_netted"))
	_advance(6.5)
	_check("champ disparu après 6 s", _kit.caltrops.is_empty() or (_kit.caltrops[0] as VigieCaltrops).is_ending())

	print("Sort 4 : Tir de signal")
	_reset()
	_player.spells.aim_override = Vector2(6 * U, 0)
	var s1 := _fake(Vector2(6 * U, 2 * U))
	var sboss := _fake(Vector2(6 * U, -2 * U))
	sboss.is_boss = true
	var sfar := _fake(Vector2(6 * U, 6 * U))
	_check("tir de signal lancé", _player.spells.cast(4))
	_check("recharge 20 s", _near(_player.get_spell_cooldowns()[3].total, 20.0, 0.01))
	_flush()
	_advance(1.0)
	_check("rien avant la fin du télégraphe (1,2 s)", s1.taken.is_empty())
	_advance(0.35)
	_check("impact : coef 7,0 en un coup", s1.taken.size() == 1 and _near(s1.taken[0], VigieKit.SIGNAL_COEF * BASE, 0.05), str(s1.taken))
	_check("emprisonné 1 s ; boss ralenti 40 %", s1.has_status(&"imprisoned") and sboss.has_status(&"slow") and not sboss.has_status(&"imprisoned")
			and _near(float(sboss.status_data(&"slow").get("pct", 0)), 0.4))
	_check("hors rayon (3,5 u) : intact", sfar.taken.is_empty())
	_advance(0.3)
	_check("lumière 8 s plantée : exposés", s1.exposed() and _kit.flares.size() == 1)
	_advance(8.2)
	_check("lumière éteinte après 8 s", _kit.flares.is_empty() or (_kit.flares[0] as VigieFlare).is_ending())

	print("Compteurs")
	_reset()
	for i in 3:
		_fake(Vector2(5 * U, (i - 1) * U))
	_kit.open_net(Vector2(5 * U, 0))
	_check("vigie_netted = monstres immobilisés", int(RunState.counters.get("vigie_netted", 0)) == 3, str(RunState.counters))
	var victim := _fake(Vector2(9 * U, 0))
	var base_spells: Array = VigieKit.character().spells
	_kit.on_spell_hit(base_spells[3], victim, 5.0)
	Events.enemy_killed.emit(victim, victim.global_position, 1, false)
	_check("vigie_grele_kills : dernier coup de la Grêle", int(RunState.counters.get("vigie_grele_kills", 0)) == 1, str(RunState.counters))
	var other := _fake(Vector2(9 * U, 0))
	_kit.on_spell_hit(base_spells[3], other, 5.0)
	_kit.on_spell_hit(base_spells[0], other, 5.0)
	Events.enemy_killed.emit(other, other.global_position, 1, false)
	_check("achevé par un autre sort : pas compté", int(RunState.counters.get("vigie_grele_kills", 0)) == 1)

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
