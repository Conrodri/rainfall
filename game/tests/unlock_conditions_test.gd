extends Node
## Conditions de déblocage des personnages de test (06/11/2026, docs/Design_Personnages.md) :
## Tocsin dès le départ ; Averse 60 s dans l'eau ; Arpenteuse 300 tués par zone persistante (cumul) ; Rainette un étage sans
## contact ; Avare plus de 4 P d'or ; Bourbe 3 élites tuées par des familiers (cumul) ; Vigie 100 tués à plus de 8 u ;
## Taliant (morfil) un boss d'étage avec au plus 3 coups subis. Chaque règle : juste atteinte / ratée de justesse, puis
## l'UnlockTracker alimenté par les signaux d'Events, et le mode test qui ne mesure rien.
## godot --headless --path game res://tests/unlock_conditions_test.tscn  → « RESULT: OK »

class FakeKit extends RefCounted:
	var in_map_water := false
	var in_puddle := false


class FakePlayer extends Node2D:
	var kit: FakeKit = FakeKit.new()
	var player_id := 0


class FakeEnemy extends Node2D:
	var last_hit_via: StringName = &""


class FakeMob extends Node2D:
	pass

var _fails: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		printerr("FAIL: ", what)


## Profil neuf, configuration de sortie (aucun perso ouvert par characters.json), rien écrit.
func _profile() -> Node:
	var p: Node = load("res://scripts/save/profile.gd").new()
	p.write_enabled = false
	p.path = "user://unlock_conditions_profile.json"
	p.open_characters = []
	p.characters_override = []
	return p


func _run(p: Node, r: Dictionary) -> Array:
	var base := {"mode": &"moyen"}
	base.merge(r)
	return p.add_run_result(base)


func _ready() -> void:
	_test_defaults()
	_test_run_rules()
	_test_cumulative_rules()
	_test_avare()
	_test_tracker()
	_test_sandbox()
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)


func _test_defaults() -> void:
	var p := _profile()
	_check(p.is_character_unlocked(&"ardent") and p.is_character_unlocked(&"tocsin"), "Tocsin disponible dès le départ")
	for cid in [&"averse", &"arpenteuse", &"rainette", &"avare", &"bourbe", &"vigie", &"morfil", &"gresille"]:
		_check(not p.is_character_unlocked(cid), "%s fermé au départ" % cid)
	p.free()


func _test_run_rules() -> void:
	# [mesure, juste sous le seuil, au seuil, personnage]
	var rules := [
		["water_s", 59.0, 60.0, &"averse"],
		["far_kills", 99.0, 100.0, &"vigie"],
		["clean_floors", 0.0, 1.0, &"rainette"],
		["light_boss_kills", 0.0, 1.0, &"morfil"],
	]
	for r in rules:
		var p := _profile()
		var miss: Array = _run(p, {r[0]: r[1]})
		_check(not p.is_character_unlocked(r[3]) and miss.is_empty(), "%s : %s sous le seuil, pas débloqué" % [r[3], r[0]])
		_run(p, {r[0]: r[1]})
		_check(not p.is_character_unlocked(r[3]), "%s : pas de cumul entre deux runs (« en une run »)" % r[3])
		var hit: Array = _run(p, {r[0]: r[2]})
		_check(p.is_character_unlocked(r[3]) and hit.has(StringName("character:%s" % r[3])), "%s : seuil atteint, débloqué et annoncé (%s)" % [r[3], str(hit)])
		var twice: Array = _run(p, {r[0]: r[2]})
		_check(not twice.has(StringName("character:%s" % r[3])), "%s : pas annoncé deux fois" % r[3])
		p.free()


func _test_cumulative_rules() -> void:
	var rules := [["zone_kills", 299, 1, &"arpenteuse"], ["familiar_elite_kills", 2, 1, &"bourbe"], ["lightning_kills", 99, 1, &"gresille"]]
	for r in rules:
		var p := _profile()
		_run(p, {r[0]: r[1]})
		_check(not p.is_character_unlocked(r[3]), "%s : %d, pas encore" % [r[3], r[1]])
		var u: Array = _run(p, {r[0]: r[2]})
		_check(p.is_character_unlocked(r[3]) and u.has(StringName("character:%s" % r[3])), "%s : cumul sur deux runs atteint" % r[3])
		p.free()
	# avancée mémorisée pour « Prochain objectif »
	var q := _profile()
	_run(q, {"zone_kills": 150})
	_check(absf(q.objective_progress(&"arpenteuse") - 0.5) < 0.001, "avancée Arpenteuse 50 %% (%s)" % str(q.objective_progress(&"arpenteuse")))
	q.free()


func _test_avare() -> void:
	var unit := maxf(Balance.chest_price(&"petit", 2.0, 2), 1.0)
	var p := _profile()
	_run(p, {"gold": int(4.0 * unit), "difficulty": 2.0, "stage": 2, "victory": true})
	_check(not p.is_character_unlocked(&"avare"), "Avare : exactement 4 P, pas plus")
	_run(p, {"gold": int(4.0 * unit) + 5, "difficulty": 2.0, "stage": 2, "reason": "abandon"})
	_check(not p.is_character_unlocked(&"avare"), "Avare : abandon ne compte pas")
	var u: Array = _run(p, {"gold": int(4.0 * unit) + 5, "difficulty": 2.0, "stage": 2, "victory": true})
	_check(p.is_character_unlocked(&"avare") and u.has(&"character:avare"), "Avare : plus de 4 P en fin de run (%s)" % str(u))
	p.free()


func _kill(player_id: int, pos: Vector2, via: StringName, elite: bool) -> void:
	var e := FakeEnemy.new()
	e.last_hit_via = via
	add_child(e)
	Events.enemy_killed_by.emit(player_id, e, pos, 0, elite)
	e.queue_free()


func _test_tracker() -> void:
	var saved_running: bool = RunState.running
	RunState.running = true
	var pl := FakePlayer.new()
	pl.add_to_group(&"player")
	add_child(pl)
	var t := UnlockTracker.new()
	add_child(t)
	Events.run_started.emit(false)
	var far := Balance.UNIT_PX * UnlockTracker.FAR_KILL_U
	# Averse : eau 30 s, hors eau 10 s, flaque 29 s -> 59 s ; +1 s -> 60 s
	pl.kit.in_map_water = true
	t._process(30.0)
	pl.kit.in_map_water = false
	t._process(10.0)
	pl.kit.in_puddle = true
	t._process(29.0)
	_check(is_equal_approx(t.water_s, 59.0), "eau : 59 s cumulées (%s)" % str(t.water_s))
	t._process(1.0)
	_check(t.metrics()["water_s"] >= 60.0, "eau : 60 s atteintes (flaque comprise)")
	# Arpenteuse / Bourbe / Vigie
	_kill(0, Vector2.ZERO, &"zone", false)
	_kill(0, Vector2.ZERO, &"", false)
	_check(t.zone_kills == 1, "tué par zone persistante compté, tué normal non")
	_kill(0, Vector2.ZERO, &"familiar", false)
	_check(t.familiar_elite_kills == 0, "familier sur monstre normal : pas compté")
	_kill(0, Vector2.ZERO, &"familiar", true)
	_check(t.familiar_elite_kills == 1, "élite tuée par un familier comptée")
	_kill(0, Vector2(far - 1.0, 0.0), &"", false)
	_check(t.far_kills == 0, "tué à 8 u - 1 px : pas lointain")
	_kill(0, Vector2(far + 1.0, 0.0), &"", false)
	_check(t.far_kills == 1, "tué au-delà de 8 u compté")
	# Rainette : un étage touché par un contact, puis un étage propre
	var mob := FakeMob.new()
	mob.add_to_group(&"enemies")
	add_child(mob)
	Events.floor_started.emit(1)
	Events.player_damaged_by.emit(0, 10.0, mob)
	Events.floor_cleared.emit(1)
	_check(t.clean_floors == 0, "étage touché par contact : pas propre")
	Events.floor_started.emit(2)
	Events.player_damaged_by.emit(0, 10.0, null) # projectile / zone : pas un contact
	Events.floor_cleared.emit(2)
	_check(t.clean_floors == 1, "étage sans contact (projectile seulement) : propre")
	# Taliant : 4 coups = raté, 3 coups = réussi
	var boss := Node2D.new()
	add_child(boss)
	Events.boss_spawned.emit(boss, true)
	for i in 4:
		Events.player_damaged_by.emit(0, 10.0, null)
	Events.boss_killed.emit(boss, true)
	_check(t.light_boss_kills == 0, "boss vaincu après 4 coups subis : raté")
	Events.boss_spawned.emit(boss, true)
	for i in 3:
		Events.player_damaged_by.emit(0, 10.0, null)
	Events.boss_killed.emit(boss, true)
	_check(t.light_boss_kills == 1, "boss vaincu après 3 coups subis : réussi")
	Events.boss_spawned.emit(boss, false)
	Events.boss_killed.emit(boss, false)
	_check(t.light_boss_kills == 1, "mini-boss ignoré")
	# Mesures relues par le profil
	var p := _profile()
	p.tracker = t
	var u: Array = _run(p, {})
	_check(p.is_character_unlocked(&"averse") and p.is_character_unlocked(&"rainette") and p.is_character_unlocked(&"morfil"),
		"le profil lit les mesures du tracker (%s)" % str(u))
	_check(not p.is_character_unlocked(&"vigie") and not p.is_character_unlocked(&"arpenteuse"), "Vigie et Arpenteuse pas atteints")
	p.tracker = null
	p.free()
	# Nouvelle run : remise à zéro
	Events.run_started.emit(false)
	_check(t.water_s == 0.0 and t.zone_kills == 0 and t.clean_floors == 0 and t.light_boss_kills == 0, "run_started remet les mesures à zéro")
	t.queue_free()
	pl.queue_free()
	mob.queue_free()
	boss.queue_free()
	RunState.running = saved_running


func _test_sandbox() -> void:
	var saved_running: bool = RunState.running
	RunState.running = true
	var t := UnlockTracker.new()
	add_child(t)
	TestMode.active = true
	_kill(0, Vector2.ZERO, &"zone", false)
	TestMode.active = false
	_check(t.zone_kills == 0, "mode test : rien mesuré")
	Profile.begin_sandbox()
	_kill(0, Vector2.ZERO, &"zone", false)
	Profile.end_sandbox()
	_check(t.zone_kills == 0, "bac à sable du profil : rien mesuré")
	t.queue_free()
	RunState.running = saved_running
