extends Node
## Déroule un étage complet avec Director et coffre factices.
## godot --headless --path game res://tests/stage_test.tscn

class FakeDirector extends Node:
	var spawned: Array = [] ## [{kind, pos, boss}]
	var zones: Array = [] ## [{id, active}]

	func spawn_boss(kind: StringName, position: Vector2) -> Node2D:
		var b := Node2D.new()
		b.position = position
		add_child(b)
		spawned.append({"kind": kind, "pos": position, "boss": b})
		return b

	func set_zone(id: int, _center: Vector2, _radius: float, active: bool, kind: StringName = &"mini") -> void:
		zones.append({"id": id, "active": active, "kind": kind})

	func last_zone(id: int) -> Variant:
		for i in range(zones.size() - 1, -1, -1):
			if zones[i]["id"] == id:
				return zones[i]["active"]
		return null


var _fails := 0
var _player_ref: Node2D
var _states: Array = []
var _floor_started: Array = []
var _floor_cleared: Array = []
var _fake_chest_script: GDScript


func _ready() -> void:
	_run()
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label)


func _make_fake_chest() -> Node2D:
	var c := Node2D.new()
	c.set_script(_fake_chest_script)
	return c


func _layout_of(mgr: StageManager) -> Array:
	var out: Array = []
	for c in mgr.chests:
		out.append([c.kind, c.position])
	for p in mgr.pillars:
		out.append([p.kind, p.position])
	return out


func _kill(director: FakeDirector, idx: int, floor_boss: bool) -> void:
	Events.boss_killed.emit(director.spawned[idx]["boss"], floor_boss)


func _run() -> void:
	_fake_chest_script = GDScript.new()
	_fake_chest_script.source_code = "extends Node2D\nvar kind\nvar stage\nfunc setup(k, s):\n\tkind = k\n\tstage = s\n"
	_fake_chest_script.reload()

	Events.pillar_state_changed.connect(func(_p: Node, s: StringName) -> void: _states.append(s))
	Events.floor_started.connect(func(s: int) -> void: _floor_started.append(s))
	Events.floor_cleared.connect(func(s: int) -> void: _floor_cleared.append(s))

	var director := FakeDirector.new()
	director.add_to_group(&"director")
	add_child(director)
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)

	_player_ref = player
	var mgr := StageManager.new()
	mgr.chest_factory = _make_fake_chest
	mgr.map_scene = load("res://scenes/stage/stage_map_test.tscn")
	add_child(mgr)

	# --- Placement
	RunState.stage = 1
	RunState.rng.seed = 4242
	mgr.start_stage()
	var layout_a := _layout_of(mgr)
	_check("floor_started(1)", _floor_started == [1])
	var n_petit := 0
	var n_large := 0
	var n_leg := 0
	for c in mgr.chests:
		match c.kind:
			&"petit": n_petit += 1
			&"large": n_large += 1
			&"legendaire": n_leg += 1
		_check("coffre setup stage", c.stage == 1)
	_check("8 petits coffres", n_petit == 8)
	_check("2 larges", n_large == 2)
	_check("légendaire 0 ou 1", n_leg <= 1)
	_check("3 piliers", mgr.pillars.size() == 3)
	_check("2 petits + 1 gros", mgr.pillars[0].kind == Pillar.Kind.SMALL and mgr.pillars[1].kind == Pillar.Kind.SMALL and mgr.pillars[2].kind == Pillar.Kind.BIG)
	var seen := {}
	for c in mgr.chests:
		seen[c.position] = true
	for p in mgr.pillars:
		seen[p.position] = true
	_check("positions distinctes", seen.size() == mgr.chests.size() + 3)
	_check("joueur au départ", player.global_position == mgr.map.get_player_start())

	# Déterminisme
	RunState.rng.seed = 4242
	mgr.start_stage()
	_check("même seed = même disposition", _layout_of(mgr) == layout_a)
	RunState.rng.seed = 999
	mgr.start_stage()
	_check("autre seed = autre disposition", _layout_of(mgr) != layout_a)
	var legendary_seen := false
	for s in 40:
		RunState.rng.seed = s
		mgr.start_stage()
		for c in mgr.chests:
			if c.kind == &"legendaire":
				legendary_seen = true
	_check("légendaire apparaît parfois", legendary_seen)
	RunState.stage = 1
	RunState.rng.seed = 4242
	_states.clear()
	director.spawned.clear()
	director.zones.clear()
	mgr.start_stage()
	_check("même disposition après relances", _layout_of(mgr) == layout_a)

	_test_interact(mgr)
	# --- Piliers
	var s1: Pillar = mgr.pillars[0]
	var s2: Pillar = mgr.pillars[1]
	var big: Pillar = mgr.pillars[2]
	_check("gros verrouillé", big.state == &"locked")
	_check("gros non activable", not big.activate())
	player.global_position = s1.global_position + Vector2(5000, 5000) # loin
	_check("petit 1 activé", s1.activate())
	_check("petit 2 activé", s2.activate())
	_check("activation unique", not s1.activate())
	_check("2 mini-boss", director.spawned.size() == 2 and director.spawned[0]["kind"] == &"mini" and director.spawned[1]["kind"] == &"mini")
	_check("zone inactive joueur dehors", director.last_zone(s1.zone_id) == false)
	player.global_position = s1.global_position
	s1.tick(0.1)
	_check("zone 1 active joueur dedans", director.last_zone(s1.zone_id) == true)
	player.global_position = s1.global_position + Vector2(5000, 0)
	s1.tick(0.1)
	_check("zone 1 coupée en sortant", director.last_zone(s1.zone_id) == false)
	_check("petit pilier sans charge", s1.charge == 0.0)
	_kill(director, 0, false)
	_check("petit 1 terminé", s1.state == &"done")
	_check("petit 2 encore actif", s2.state == &"active")
	_check("gros toujours verrouillé", big.state == &"locked")
	_kill(director, 1, false)
	_check("petit 2 terminé", s2.state == &"done")
	_check("gros débloqué", big.state == &"ready")

	# --- Gros pilier
	_check("gros activé", big.activate())
	_check("boss d'étage", director.spawned.size() == 3 and director.spawned[2]["kind"] == &"etage")
	for i in 100:
		big.tick(1.0) # joueur dehors
	_check("pas de charge dehors", big.charge == 0.0)
	player.global_position = big.global_position
	big.tick(1.0)
	_check("zone de charge active", director.last_zone(big.zone_id) == true)
	var charge_s := int(Balance.PILLAR_CHARGE_S) # 60 s depuis le 28/10/2026 (était 90)
	for i in charge_s - 2:
		big.tick(1.0)
	_check("charge %d s" % (charge_s - 1), absf(big.charge - (charge_s - 1)) < 0.001 and not big.is_charged())
	_kill(director, 2, true)
	_check("boss mort mais non chargé = actif", big.state == &"active" and big.boss_dead)
	_check("pas d'étage terminé", _floor_cleared.is_empty())
	big.tick(1.0)
	_check("terminé chargé + boss mort", big.state == &"done")
	_check("zone fermée", director.last_zone(big.zone_id) == false)
	_check("floor_cleared(1)", _floor_cleared == [1])
	_check("coffre boss", mgr.chests.back().kind == &"boss" and mgr.chests.back().position == big.position)
	_check("sortie active", mgr.teleporter.active)
	_check("transitions", _states.has(&"locked") and _states.has(&"ready") and _states.has(&"active") and _states.has(&"done"))

	# --- Sauvegarde
	var saved := mgr.to_dict()
	var json := JSON.parse_string(JSON.stringify(saved)) as Dictionary
	mgr.from_dict(json)
	_check("restauration : gros terminé", mgr.pillars[2].state == &"done" and mgr.floor_cleared and mgr.teleporter.active)
	var d := mgr.pillars[0].to_dict()
	var probe := Pillar.new()
	probe.from_dict(d)
	_check("pillar to/from_dict", probe.state == mgr.pillars[0].state and probe.kind == mgr.pillars[0].kind)
	probe.free()

	# --- Étages suivants
	var victory := [false]
	var asked := [0]
	mgr.run_won.connect(func() -> void: victory[0] = true)
	mgr.victory_choice_requested.connect(func(s: int) -> void: asked[0] = s)
	RunState.stage = 1
	mgr.start_stage()
	mgr.request_exit()
	_check("sortie refusée avant la fin", RunState.stage == 1)
	_clear_floor(mgr, director, player)
	mgr.teleporter.use()
	_check("étage 2", RunState.stage == 2 and _floor_started.back() == 2 and mgr.pillars.size() == 3 and mgr.pillars[0].state == &"ready")
	for st in range(3, StageManager.FINAL_STAGE + 1): # 5 étages (data/floors.json), la Source en dernier
		_clear_floor(mgr, director, player)
		mgr.teleporter.use()
		_check("étage %d" % st, RunState.stage == st)
	_clear_floor(mgr, director, player)
	mgr.teleporter.use()
	var fin := StageManager.FINAL_STAGE
	_check("choix à l'étage %d" % fin, asked[0] == fin and RunState.stage == fin and not victory[0])
	mgr.finish_run()
	_check("victoire", victory[0])
	mgr.continue_endless()
	_check("sans fin -> étage %d" % (fin + 1), RunState.stage == fin + 1 and mgr.endless)
	_clear_floor(mgr, director, player)
	asked[0] = 0
	mgr.teleporter.use()
	_check("sans fin : plus de choix", asked[0] == 0 and RunState.stage == fin + 2)

	_test_real_maps(director, player)
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)


## La Source : paratonnerre-mère seul (prêt d'emblée), boss final du plan, zone 22 u, coffres 6 + 2 + 1 légendaire.
func _check_final_floor(m: StageManager) -> void:
	_check("Source : 1 seul pilier (gros, prêt)", m.pillars.size() == 1 and m.pillars[0].kind == Pillar.Kind.BIG and m.pillars[0].state == &"ready")
	var rod: Pillar = m.pillars[0]
	_check("Source : boss final rain_sower", rod.final_boss and rod.boss_id == &"rain_sower" and m.floor_boss == &"rain_sower")
	_check("Source : zone de charge 22 u", is_equal_approx(rod.zone_radius(), 22.0 * 64.0))
	_check("Source : « Appeler la Source »", rod.interact_label() == "Appeler la Source")
	var kinds := {}
	for c in m.chests:
		kinds[c.kind] = int(kinds.get(c.kind, 0)) + 1
	_check("Source : coffres 6 + 2 + 1 légendaire " + str(kinds), kinds.get(&"petit", 0) == 6 and kinds.get(&"large", 0) == 2 and kinds.get(&"legendaire", 0) == 1)


## Termine tous les piliers de l'étage courant avec boss simulés.
func _clear_floor(mgr: StageManager, director: FakeDirector, player: Node2D) -> void:
	director.spawned.clear()
	for i in 2:
		mgr.pillars[i].activate()
	_kill(director, 0, false)
	_kill(director, 1, false)
	var big: Pillar = mgr.pillars[2]
	big.activate()
	player.global_position = big.global_position
	_kill(director, 2, true)
	for i in 91:
		big.tick(1.0)


func _test_interact(mgr: StageManager) -> void:
	var p: Pillar = mgr.pillars[0]
	_check("pilier dans groupe interactable", p.is_in_group(&"interactable") and mgr.teleporter.is_in_group(&"interactable"))
	_check("pas interactif hors portée", not p.can_interact())
	_check("gros : Verrouillé", mgr.pillars[2].interact_label() == "Verrouillé" and not mgr.pillars[2].can_interact())
	_check("label pilier", p.interact_label() == "Activer le pilier" and mgr.teleporter.interact_label() == "Partir")
	p._on_body_entered(_player_ref)
	_check("contact n'active pas", p.state == &"ready")
	_check("à portée = interactif", p.can_interact())


## Vraies cartes : rotation seedée, règles de tirage, bornes, boss d'étage.
func _test_real_maps(director: FakeDirector, player: Node2D) -> void:
	var m := StageManager.new()
	m.chest_factory = _make_fake_chest
	add_child(m)
	var bosses := {}
	var orders := {}
	var saved_seed := RunState.run_seed
	for s in 12:
		RunState.rng.seed = s
		RunState.run_seed = 1000 + s # plan de run (FloorPlan) : seed de run, jamais RunState.rng
		m.reset_run()
		RunState.stage = 1
		m.start_stage()
		var order_a := str(m.floor_plan)
		orders[str(m.floor_plan.map(func(e: Dictionary) -> String: return e["map_id"]))] = true
		var first_id := m.map_id
		_check("plan de 5 étages", m.floor_plan.size() == StageManager.FINAL_STAGE and FloorPlan.final_floor() == StageManager.FINAL_STAGE)
		var seen_ids := {}
		for st in StageManager.FINAL_STAGE:
			RunState.stage = st + 1
			m.start_stage()
			seen_ids[m.map_id] = true
			bosses[m.floor_boss] = st + 1 # boss tiré -> étage où il est apparu
			var meta = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % m.map_id))
			_check("étage %d : carte de l'étage (%s)" % [st + 1, m.map_id], int(meta["floor"]) == st + 1)
			if m.is_final_floor:
				_check_final_floor(m)
				continue
			var start: Vector2 = m.map.get_player_start()
			var big: Pillar = m.pillars[2]
			var all: Array = [m.pillars[0], m.pillars[1], big]
			_check("gros pilier >= 20 u du départ", big.position.distance_to(start) >= 20.0 * 64.0 - 0.1)
			_check("gros pilier : boss_id", big.boss_id == m.floor_boss)
			for i in 3:
				for j in range(i + 1, 3):
					_check("piliers >= 18 u", all[i].position.distance_to(all[j].position) >= 18.0 * 64.0 - 0.1)
			for p: Pillar in all:
				var r := 9.0 if p.kind == Pillar.Kind.BIG else 7.0
				_check("sol >= 70 %% (%s)" % m.map_id, m.map.get_walkable_ratio(p.position, r * 64.0) >= 0.7)
			for c in m.chests:
				if c.kind == &"legendaire":
					_check("légendaire >= 24 u", c.position.distance_to(start) >= 24.0 * 64.0 - 0.1)
			_check("bornes non vides", m.get_bounds().size.x > 1000.0 and m.get_bounds().has_point(start))
		_check("5 cartes différentes", seen_ids.size() == StageManager.FINAL_STAGE)
		# même seed = même plan
		RunState.rng.seed = s
		m.reset_run()
		RunState.stage = 1
		m.start_stage()
		_check("plan déterministe", str(m.floor_plan) == order_a and m.map_id == first_id)
		# sans fin : étage 6 = biome 1 (variante opposée si elle existe), étage 10 = la Source
		RunState.stage = 6
		m.start_stage()
		_check("sans fin : étage 6 = étage 1", FloorPlan.floor_of_stage(6) == 1 and FloorPlan.playable_maps(1).has(m.map_id) and not m.is_final_floor)
		RunState.stage = 10
		m.start_stage()
		_check("sans fin : étage 10 = la Source", m.map_id == "la_source" and m.is_final_floor and m.pillars.size() == 1)
	_check("une seule variante par étage aujourd'hui : un seul ordre de cartes", orders.size() == 1)
	RunState.stage = 1
	m.start_stage()
	_check("étage 1 = terrasses_noyees", m.map_id == "terrasses_noyees")
	# roster (docs/Design_Etages.md) : au moins 3 boss d'étage par étage 1-4, un boss final unique à l'étage 5 ;
	# chaque boss tiré appartient au roster de son étage (le nombre tiré dépend des sprites livrés)
	var roster_ok := true
	var roster_ids := {}
	for f in FloorPlan.final_floor():
		var fb: Array = FloorPlan.floor_entry(f + 1).get("floor_bosses", [])
		roster_ok = roster_ok and (fb.size() == 1 if f + 1 == FloorPlan.final_floor() else fb.size() >= 3)
		for b in fb:
			roster_ids[StringName(b)] = f + 1
	_check("roster : >= 3 boss d'étage par étage 1-4, boss final unique " + str(roster_ids), roster_ok and roster_ids.size() >= 3 * (FloorPlan.final_floor() - 1) + 1)
	var drawn_ok := bosses.size() >= FloorPlan.final_floor()
	for b in bosses:
		drawn_ok = drawn_ok and roster_ids.get(b, -1) == bosses[b]
	_check("boss d'étage tirés dans le roster de leur étage " + str(bosses), drawn_ok and bosses.has(&"rain_sower"))
	RunState.run_seed = saved_seed
	m.reset_run()
	# boss_id transmis au Director
	director.spawned.clear()
	RunState.stage = 1
	m.start_stage()
	m.pillars[0].activate()
	_kill(director, 0, false)
	m.pillars[1].activate()
	_kill(director, 1, false)
	m.pillars[2].activate()
	_check("méta boss_id sur le boss", director.spawned[2]["boss"].get_meta(&"boss_id") == m.floor_boss)
	# sol praticable : un disque vide vs plein
	var test_map: StageMap = load("res://scenes/stage/stage_map_test.tscn").instantiate()
	add_child(test_map)
	_check("sol praticable libre = 100 %", test_map.get_walkable_ratio(Vector2(-1300, -1300), 200.0) > 0.99)
	_check("sol praticable obstacle < 100 %", test_map.get_walkable_ratio(Vector2(-900, -700), 150.0) < 0.8)
	test_map.queue_free()
	m.queue_free()
