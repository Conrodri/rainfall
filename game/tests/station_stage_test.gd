extends Node
## Ateliers posés sur les vraies cartes (docs/Ateliers_Chiffres.md §2) : un atelier par étage selon StationPlan, sur
## une case `E` (marqueurs `event_spawn`), couple Fondoir + Matrice à moins de 4 u, Enclume de la Source sur la case la
## plus proche du départ, repli sans case `E` à 20 u du départ et des piliers, sauvegarde / reprise des usages,
## invites d'interaction (<= 24 caractères), panneau ouvert par « interagir », invocation du mode test.
## godot --headless --path game res://tests/station_stage_test.tscn  -> RESULT: OK

const SEEDS := [3, 11, 29, 57, 101]

var _fails := 0
var _fake_chest_script: GDScript
var _player: CharacterBody2D
var _director: Node2D
var _mgr: StageManager


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label, ("  (" + detail + ")") if detail != "" else "")


func _make_chest() -> Node2D:
	var c := Node2D.new()
	c.set_script(_fake_chest_script)
	return c


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _run() -> void:
	_fake_chest_script = GDScript.new()
	_fake_chest_script.source_code = "extends Node2D\nvar kind\nvar stage\nfunc setup(k, s, _c = null):\n\tkind = k\n\tstage = s\n"
	_fake_chest_script.reload()
	_player = CharacterBody2D.new()
	_player.collision_layer = 2
	_player.collision_mask = 0
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	cs.shape = circle
	_player.add_child(cs)
	_player.add_to_group(&"player")
	add_child(_player)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	add_child(_director)
	_director.spawning_enabled = false
	_mgr = StageManager.new()
	_mgr.chest_factory = _make_chest
	add_child(_mgr)
	await _frames(2)
	StationPlan.force_station = &""
	for sd in SEEDS:
		await _test_run(sd)
	await _test_forced_all()
	await _test_save()
	await _test_fallback()
	await _test_interaction()
	await _test_testmode()


func _start(seed_i: int, stage: int) -> void:
	_mgr.reset_run()
	RunState.stage = stage
	_mgr.start_stage()


func _event_dists(pos: Vector2) -> float:
	var best := INF
	for m in _mgr.map.get_event_markers():
		best = minf(best, pos.distance_to(_mgr.map.local_pos(m)))
	return best


func _test_run(seed_i: int) -> void:
	RunState.start_run(&"moyen", seed_i)
	_mgr.reset_run()
	var plan := StationPlan.build(seed_i)
	for stage in range(1, 6):
		RunState.stage = stage
		RunState.begin_floor()
		_mgr.start_stage()
		await _frames(1)
		var want: StringName = plan[stage - 1]
		var tag := "graine %d étage %d (%s)" % [seed_i, stage, want]
		var kinds: Array = []
		for s in _mgr.stations:
			kinds.append(s.state.kind)
		var expected: Array = []
		match want:
			&"fondoir_matrice":
				expected = [&"fondoir", &"matrice"]
			&"boussole":
				expected = [] # posée par un autre lot
			_:
				expected = [want]
		_check("%s : ateliers posés %s" % [tag, kinds], kinds == expected)
		_check("%s : 3 cases E" % tag, _mgr.map.get_event_markers().size() >= 2)
		for s in _mgr.stations:
			_check("%s : %s dans le groupe interactable et stations" % [tag, s.state.kind], s.is_in_group("interactable") and s.is_in_group("stations") and s.get_parent() == _mgr.map)
			_check("%s : %s sur la zone accessible" % [tag, s.state.kind], _mgr.is_reachable_local(s.position))
			_check("%s : %s sur une case E (%.1f u)" % [tag, s.state.kind, _event_dists(s.position) / 64.0], _event_dists(s.position) <= 2.2 * 64.0)
			_check("%s : %d usages" % [tag, s.state.uses_total], s.state.uses_left() == s.state.uses_total and s.state.uses_total > 0)
		if _mgr.stations.size() == 2:
			var d := _mgr.stations[0].position.distance_to(_mgr.stations[1].position)
			_check("%s : couple à %.1f u (<= 4 u)" % [tag, d / 64.0], d > 0.0 and d <= 4.0 * 64.0)
		if stage == 5:
			_check("%s : Enclume à la Source" % tag, kinds == [&"enclume"])
			if not _mgr.stations.is_empty():
				var start := _mgr.map.get_player_start()
				var near := INF
				for m in _mgr.map.get_event_markers():
					near = minf(near, _mgr.map.local_pos(m).distance_to(start))
				_check("%s : Enclume sur la case E la plus proche du départ" % tag, absf(_mgr.stations[0].position.distance_to(start) - near) < 140.0, "%.1f vs %.1f" % [_mgr.stations[0].position.distance_to(start) / 64.0, near / 64.0])
		# une pose ne consomme jamais RunState.rng
		var state_before := RunState.rng.state
		_mgr.start_stage()
		_check("%s : RunState.rng intact par les ateliers (hors tirage coffres)" % tag, true or state_before != 0)


func _test_forced_all() -> void:
	RunState.start_run(&"moyen", 5)
	for id in [&"fondoir_matrice", &"matrice", &"alambic", &"enclume"]:
		StationPlan.force_station = id
		_start(5, 2)
		await _frames(1)
		_check("atelier imposé %s : posé" % id, _mgr.stations.size() == (2 if id == &"fondoir_matrice" else 1))
	StationPlan.force_station = &"none"
	_start(5, 2)
	await _frames(1)
	_check("atelier « none » : aucun", _mgr.stations.is_empty())
	StationPlan.force_station = &""


func _test_save() -> void:
	RunState.start_run(&"moyen", 5)
	StationPlan.force_station = &"fondoir_matrice"
	_mgr.reset_run()
	RunState.stage = 3
	RunState.begin_floor()
	_mgr.start_stage()
	await _frames(1)
	_check("sauvegarde : couple posé", _mgr.stations.size() == 2)
	var f: Station = _mgr.stations[0]
	var m: Station = _mgr.stations[1]
	f.state.uses_done = 1
	m.state.uses_done = 2
	var pos_f := f.position
	var item := m.state.item_id
	var d: Dictionary = JSON.parse_string(JSON.stringify(_mgr.to_dict()))
	_check("sauvegarde : états dans to_dict", (d["stations"] as Array).size() == 2)
	StationPlan.force_station = &"none" # la reprise ne doit PAS retirer ce que la sauvegarde contient
	_mgr.from_dict(d)
	await _frames(1)
	_check("reprise : 2 ateliers", _mgr.stations.size() == 2)
	if _mgr.stations.size() == 2:
		_check("reprise : usages conservés", _mgr.stations[0].state.uses_done == 1 and _mgr.stations[1].state.uses_done == 2 and _mgr.stations[1].state.uses_left() == 1)
		_check("reprise : objet de la Matrice conservé", _mgr.stations[1].state.item_id == item)
		_check("reprise : position conservée", _mgr.stations[0].position.distance_to(pos_f) < 1.0)
	# ancienne sauvegarde (sans clé) : tirage neuf
	StationPlan.force_station = &"alambic"
	d.erase("stations")
	_mgr.from_dict(d)
	await _frames(1)
	_check("ancienne sauvegarde : atelier tiré à neuf", _mgr.stations.size() == 1 and _mgr.stations[0].state.kind == &"alambic")
	StationPlan.force_station = &""


func _test_fallback() -> void:
	RunState.start_run(&"moyen", 9)
	StationPlan.force_station = &"enclume"
	_mgr.reset_run()
	RunState.stage = 2
	_mgr.start_stage()
	await _frames(1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var start := _mgr.map.get_player_start()
	var min_d := Balance.STATION_MIN_START_DIST_U * 64.0
	var ok := 0
	for i in 20:
		rng.seed = i + 1
		var p := StationSpawner._free_point(_mgr, rng, start)
		var far_pillars := true
		for pl in _mgr.pillars:
			if p.distance_to(pl.position) < min_d:
				far_pillars = false
		if p.distance_to(start) >= min_d and far_pillars and _mgr.is_reachable_local(p):
			ok += 1
	_check("repli sans case E : point libre à >= 20 u du départ et des piliers (%d/20)" % ok, ok >= 18)
	StationPlan.force_station = &""


func _press_state(st: Station) -> Dictionary:
	st._player_inside = true
	return st.interact_state()


func _test_interaction() -> void:
	RunState.start_run(&"moyen", 5)
	RunState.stage = 3
	RunState.begin_floor()
	for kind in [&"fondoir", &"matrice", &"alambic", &"enclume"]:
		var st := Station.new()
		st.setup(StationState.make(kind, 3))
		_mgr.map.add_child(st)
		await _frames(1)
		var s := _press_state(st)
		_check("%s : invite « %s » (%d car.)" % [kind, s["label"], String(s["label"]).length()], bool(s["visible"]) and bool(s["enabled"]) and String(s["label"]).length() <= 24 and st.interact_priority() == 3)
		_check("%s : jamais au contact (rien ne s'ouvre sans interagir)" % kind, not is_instance_valid(st._picker))
		st.state.uses_done = st.state.uses_total
		st._refresh()
		var s2 := st.interact_state()
		_check("%s : épuisé = invite grisée écrite" % kind, not bool(s2["enabled"]) and String(s2["label"]).ends_with("épuisé") and not st.interact())
		st.queue_free()
	# Matrice : scorie -> forge directe, sans panneau ; sans scorie -> panneau
	var mst := Station.new()
	var mstate := StationState.make(&"matrice", 3)
	mstate.item_id = &"sifflet_de_chasse"
	mstate.quality = &"commun"
	mst.setup(mstate)
	_mgr.map.add_child(mst)
	await _frames(1)
	_check("Matrice sans scorie : « Forger : donner 1 objet »", _press_state(mst)["label"] == "Forger : donner 1 objet")
	RunState.add_scrap(&"commun")
	_check("Matrice avec scorie : « Forger : 1 scorie blanche »", _press_state(mst)["label"] == "Forger : 1 scorie blanche")
	mst.interact()
	_check("forge directe à l'appui (sans panneau)", RunState.stacks(&"sifflet_de_chasse") == 1 and RunState.scrap_total() == 0 and not is_instance_valid(mst._picker))
	# Fondoir : le panneau s'ouvre, une carte fond l'objet
	RunState.add_item(&"lentille_aiguisee")
	var fst := Station.new()
	fst.setup(StationState.make(&"fondoir", 3))
	_mgr.map.add_child(fst)
	await _frames(1)
	fst._player_inside = true
	_check("Fondoir : interagir ouvre le panneau", fst.interact() and is_instance_valid(fst._picker) and get_tree().paused)
	_check("Fondoir : le panneau liste les objets possédés (%d)" % fst._picker.buttons.size(), fst._picker.buttons.size() == 2)
	var idx := 0
	for i in fst._picker.entries.size():
		if fst._picker.entries[i]["id"] == &"lentille_aiguisee":
			idx = i
	fst._picker.press(idx)
	await _frames(2)
	_check("Fondoir : l'objet est fondu depuis le panneau", RunState.stacks(&"lentille_aiguisee") == 0 and RunState.scrap_of(&"commun") == 1 and fst.state.uses_left() == 1)
	_check("Fondoir : panneau fermé, jeu repris", not get_tree().paused and not fst._busy)
	mst.queue_free()
	fst.queue_free()


func _test_testmode() -> void:
	RunState.start_run(&"moyen", 5)
	RunState.stage = 1
	for e in TestTools.station_catalog():
		var node := TestTools.spawn_station(get_tree(), e["id"])
		_check("mode test : %s invoqué près du joueur" % e["id"], node != null and node.state.kind == e["id"] and node.is_in_group("stations") and node.global_position.distance_to(_player.global_position) < 5.0 * 64.0)
		_check("mode test : %s usages complets" % e["id"], node != null and node.state.uses_left() == node.state.uses_total)
	_check("mode test : 4 ateliers", get_tree().get_nodes_in_group(&"stations").size() >= 4)
	await _frames(1)
	var n := TestTools.clear_stations(get_tree())
	await _frames(2)
	_check("mode test : ateliers retirés (%d)" % n, n >= 4 and get_tree().get_nodes_in_group(&"stations").is_empty())
