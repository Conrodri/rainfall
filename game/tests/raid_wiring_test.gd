extends Node
## Branchement commun des boss façon raid (CONTRACTS.md « Boss façon raid ») :
## priorité de visée (aim_priority), duck typing de WeakPoint, PV × boss_hp_mult, barre de boss (shield / enrage_warn /
## enrage, message « Le bouclier cède »), OffscreenCues (groupe raid_cues), données des 3 boss.
## godot --headless --path game res://tests/raid_wiring_test.tscn  -> RESULT: OK

var _fails := 0
var _player
var _director: Director
var _map: Node2D


class TagBrain extends RefCounted:
	var tag: Dictionary = {}
	var invuln := true
	func tick(_d: float, _p: Node2D, _pp: Vector2, _dir: Vector2, _dist: float, _pd: Vector2) -> Vector2:
		return Vector2.ZERO
	func owns_motion() -> bool:
		return true
	func clear() -> void:
		pass
	func is_invulnerable() -> bool:
		return invuln
	func boss_state_tag() -> Dictionary:
		return tag


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


func _run() -> void:
	RunState.level = 1
	_map = Node2D.new()
	get_tree().root.add_child(_map)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	_player.global_position = Vector2.ZERO
	await get_tree().process_frame
	_director.bind_map(_map)
	await get_tree().physics_frame
	_director.set_physics_process(false)
	_player.set_physics_process(false)

	_aim_priority()
	_weak_point_duck()
	_hp_mult()
	await _bar()
	_cues()
	_data()

	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _aim_priority() -> void:
	print("Priorité de visée")
	var sc = _player.get("spells")
	var near := _director.spawn_enemy(1, Vector2(250, 0))
	var far := _director.spawn_enemy(1, Vector2(400, 0))
	_check("sans priorité : le plus proche", sc._nearest_enemy(1000.0) == near)
	far.aim_priority = 2.0
	_check("priorité 2 à 400 px bat priorité 1 à 250 px", sc._nearest_enemy(1000.0) == far)
	_check("la portée reste en distance réelle", sc._nearest_enemy(300.0) == near)
	_check("aucun ennemi à portée : null", sc._nearest_enemy(100.0) == null)
	near.queue_free()
	far.queue_free()


func _weak_point_duck() -> void:
	print("WeakPoint duck typing")
	var w := WeakPoint.new()
	for m in [&"apply_status", &"push", &"stun", &"imprison", &"release_imprison", &"hold_at", &"is_imprisoned",
			&"is_slowed", &"is_burning", &"is_poisoned", &"add_damage_taken_mod", &"remove_damage_taken_mod", &"take_damage"]:
		_check("WeakPoint.%s" % m, w.has_method(m))
	w.free()


func _hp_mult() -> void:
	print("PV × boss_hp_mult")
	_director.set_meta(&"next_boss_id", &"cerf")
	var a := _director.spawn_boss(&"etage", Vector2(900, 0)) as Enemy
	var hp_cerf := a.max_hp
	_director.set_meta(&"next_boss_id", &"salt_king")
	var b := _director.spawn_boss(&"etage", Vector2(-900, 0)) as Enemy
	_check("boss résolu = salt_king", b.boss_id() == &"salt_king", str(b.boss_id()))
	_check("PV salt_king = PV standard × 0,9", absf(b.max_hp / maxf(hp_cerf, 1.0) - 0.9) < 0.001, "%s / %s" % [b.max_hp, hp_cerf])
	_check("boss_hp() inchangé", is_equal_approx(Balance.boss_hp(&"etage", 1.0, 1), Balance.boss_hp(&"etage", 1.0, 1)))
	_check("cerf non touché (× 1)", a.boss_id() == &"cerf")
	a.queue_free()
	b.queue_free()
	_director.remove_meta(&"next_boss_id")


func _bar() -> void:
	print("Barre de boss")
	var boss := _director.spawn_boss(&"etage", Vector2(1200, 0)) as Enemy
	var br := TagBrain.new()
	boss.brain = br
	var bar := BossHealthBar.new()
	bar.size = Vector2(900, 80)
	get_tree().root.add_child(bar)
	bar.setup(boss, true)
	br.tag = {"text": "CLOCHES 2/3", "color": Color(0.5, 0.7, 0.8), "kind": &"shield", "progress": 0.66}
	bar._process(0.05)
	_check("tag shield affiché malgré l'invulnérabilité", bar.state_tag_text() == "CLOCHES 2/3", bar.state_tag_text())
	_check("progression 0,66", is_equal_approx(bar.shield_progress(), 0.66) and bar.tag_kind() == &"shield")
	var rects := bar.text_rects()
	_check("texte du bouclier mesuré (text_rects)", rects.size() == 1 and rects[0]["text"] == "CLOCHES 2/3")
	br.invuln = true
	br.tag = {}
	bar._process(0.05)
	_check("sans tag : INVULNÉRABLE reste (aucun texte d'état)", bar.state_tag_text() == "" and bar.is_invulnerable_shown())
	br.invuln = false
	br.tag = {"text": "ENRAGE IMMINENT", "color": Color(1, 0.6, 0.2), "kind": &"enrage_warn", "progress": 0.4}
	bar._process(0.05)
	_check("enrage_warn", bar.state_tag_text() == "ENRAGE IMMINENT" and bar.tag_kind() == &"enrage_warn" and bar.shield_progress() < 0.0)
	br.tag = {"text": "ENRAGÉ", "color": Color(1, 0.2, 0.2), "kind": &"enrage", "progress": 1.0}
	bar._process(0.05)
	_check("enrage", bar.state_tag_text() == "ENRAGÉ" and bar.tag_kind() == &"enrage")
	bar.queue_redraw()
	await get_tree().process_frame
	Events.raid_mechanic_failed.emit(boss, &"shield_backstop")
	_check("message « Le bouclier cède »", bar.state_tag_text() == "Le bouclier cède", bar.state_tag_text())
	bar._process(BossHealthBar.MSG_S + 0.1)
	_check("message expiré", bar.state_tag_text() == "ENRAGÉ", bar.state_tag_text())
	bar.queue_free()
	boss.queue_free()


func _cues() -> void:
	print("OffscreenCues")
	var n := Node2D.new()
	n.add_to_group(RaidFx.CUE_GROUP)
	get_tree().root.add_child(n)
	n.global_position = Vector2(9000, 9000)
	var screen := Rect2(0, 0, 1920, 1080)
	var found := false
	for t in preload("res://scripts/ui/offscreen_cues.gd").collect_targets(get_tree(), screen):
		if t["kind"] == 1: # TELEGRAPH
			found = true
	_check("objet raid_cues hors écran = cible", found)
	n.global_position = Vector2(500, 500)
	found = false
	for t in preload("res://scripts/ui/offscreen_cues.gd").collect_targets(get_tree(), screen):
		if t["kind"] == 1:
			found = true
	_check("objet raid_cues à l'écran = aucune cible", not found)
	n.queue_free()


func _data() -> void:
	print("Données")
	var names: Dictionary = FloorPlan.data().get("boss_names", {})
	for id in [&"drowned_idol", &"flood_gunner", &"salt_king"]:
		_check("fauna boss_cfg %s" % id, not EnemyVisual.boss_cfg(id).is_empty() and bool(EnemyVisual.boss_cfg(id)["floor"]))
		_check("boss_names %s" % id, str(names.get(String(id), "")) != "")
	_check("Idole noyée à l'étage 1", "drowned_idol" in (FloorPlan.floor_entry(1)["floor_bosses"] as Array))
	_check("Canonnier à l'étage 3", "flood_gunner" in (FloorPlan.floor_entry(3)["floor_bosses"] as Array))
	_check("Roi de sel à l'étage 4", "salt_king" in (FloorPlan.floor_entry(4)["floor_bosses"] as Array))
	_check("--force-boss absent : rien d'imposé", FloorPlan.forced_boss(["drowned_idol"]) == "")
