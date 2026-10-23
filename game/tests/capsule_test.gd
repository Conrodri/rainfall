extends Node
## Capsules d'argent : placement (cartes réelles), ouverture, pas de double ouverture, nettoyage.
## godot --headless --path game res://tests/capsule_test.tscn   (sortie « RESULT: OK »)

const UNIT := 64.0

class FakePlayer extends Node2D:
	var mult := 0.5 ## bonus d'or : gold_mult() = 1,5

	func gold_mult() -> float:
		return 1.0 + mult


var _fails := 0


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label)


func _grid_cell(id: String, pos: Vector2) -> String:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var origin := -Vector2(data["size_px"][0], data["size_px"][1]) * 0.5
	var cell := float(data["grid_cell_u"]) * UNIT
	var c := ((pos - origin) / cell).floor()
	var grid: Array = data["grid"]
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= (grid[int(c.y)] as String).length():
		return "?"
	return (grid[int(c.y)] as String)[int(c.x)]


func _run() -> void:
	var player := FakePlayer.new()
	player.add_to_group(&"player")
	add_child(player)
	var mgr := StageManager.new()
	add_child(mgr)

	# --- Équilibrage
	_check("CAPSULES_PER_STAGE = 10", Balance.CAPSULES_PER_STAGE == 10)
	for D in [1.0, 2.5, 6.0]:
		var ratio := Balance.capsule_gold(D) / Balance.chest_price(&"petit", D, 1)
		_check("capsule_gold ~ 0,4 x petit coffre (D=%s)" % D, absf(ratio - 0.4) < 0.001)
	_check("capsule_gold croît avec D", Balance.capsule_gold(3.0) > Balance.capsule_gold(1.5))

	# --- Placement sur les 3 cartes réelles, plusieurs seeds
	var ids := {}
	for s in 4:
		RunState.start_run(&"moyen", 100 + s)
		mgr.reset_run()
		for st in 3:
			RunState.stage = st + 1
			mgr.start_stage()
			ids[mgr.map_id] = true
			var caps := mgr.capsules
			_check("10 capsules (%s)" % mgr.map_id, caps.size() == 10)
			var start := mgr.map.get_player_start()
			var avoid: Array[Vector2] = [start]
			for c in mgr.chests:
				avoid.append(c.position)
			for p in mgr.pillars:
				avoid.append(p.position)
			avoid.append(mgr.pillars[2].position + StageManager.TELEPORTER_OFFSET)
			for i in caps.size():
				var c := caps[i]
				_check("case praticable « . » (%s)" % mgr.map_id, _grid_cell(mgr.map_id, mgr.map.to_map(c.position)) == ".")
				_check("groupes", c.is_in_group("interactable") and c.is_in_group("gold_capsules"))
				_check("couche 7", c.collision_layer == 64)
				for a in avoid:
					_check(">= 4 u des coffres/piliers/téléporteur/départ", c.position.distance_to(a) >= 4.0 * UNIT - 0.1)
				for j in range(i + 1, caps.size()):
					_check(">= 6 u entre capsules", c.position.distance_to(caps[j].position) >= 6.0 * UNIT - 0.1)
	_check("3 cartes testées", ids.size() == 3)

	# --- Déterminisme
	RunState.rng.seed = 7
	RunState.stage = 1
	mgr.start_stage()
	var a: Array = []
	for c in mgr.capsules:
		a.append(c.position)
	RunState.rng.seed = 7
	mgr.start_stage()
	var b: Array = []
	for c in mgr.capsules:
		b.append(c.position)
	_check("même seed = mêmes capsules", a == b)

	# --- Ouverture
	var cap: GoldCapsule = mgr.capsules[0]
	var other: GoldCapsule = mgr.capsules[1]
	_check("fermée : pas interactive hors portée", not cap.can_interact())
	cap._on_body_entered(player)
	_check("à portée : interactive", cap.can_interact())
	var expected := Balance.capsule_gold(RunState.difficulty(), RunState.stage) * 1.5
	_check("expected_gold = capsule_gold x gold_mult", absf(cap.expected_gold() - expected) < 0.01)
	_check("label « Ouvrir (+N or) »", cap.interact_label() == "Ouvrir (+%d or)" % int(round(expected)))
	RunState.gold = 10.0
	_check("open() réussit", cap.open())
	_check("or ajouté = attendu", absf(RunState.gold - (10.0 + expected)) < 0.01)
	_check("plus interactive", not cap.can_interact() and cap.is_opened())
	_check("état ouvert", cap._visual.animation == &"open")
	var em := cap._visual.get_node_or_null(NodePath(NormalMaps.EMISSION_NODE)) as CanvasItem
	_check("ouverte = éteinte (lueur masquée)", em == null or not em.visible)
	var gold_after := RunState.gold
	_check("pas de double ouverture", not cap.open())
	_check("interact() sur ouverte = refus", not cap.interact())
	_check("or inchangé après 2e tentative", RunState.gold == gold_after)

	# --- Ouverture via PickupManager : pièces déposées, or versé au ramassage
	var pm := (load("res://scenes/pickups/pickup_manager.tscn") as PackedScene).instantiate()
	add_child(pm)
	await get_tree().process_frame
	other._on_body_entered(player)
	var g0 := RunState.gold
	var n0: int = pm.active_count
	other.open()
	# Ramassage automatique (22/10/2026) : l'or est versé à l'ouverture (ors entiers, fraction < 1 reportée),
	# les pièces ne sont qu'un effet visuel qui vole vers le joueur.
	_check("pièces déposées (effet visuel)", pm.active_count > n0)
	_check("or versé tout de suite = attendu", absf(RunState.gold + pm.gold_carry - (g0 + expected)) < 0.01)
	for i in 120:
		pm._process(0.05)
	_check("pièces arrivées au joueur", pm.active_count == n0)
	pm.queue_free()

	# --- Nettoyage au changement d'étage
	var old: Array = mgr.capsules.duplicate()
	mgr.next_stage()
	await get_tree().process_frame
	await get_tree().process_frame
	var freed := true
	for c in old:
		if is_instance_valid(c):
			freed = false
	_check("capsules de l'ancien étage libérées", freed)
	_check("10 nouvelles capsules", mgr.capsules.size() == 10)

	# --- Sauvegarde : seules les capsules fermées reviennent
	mgr.capsules[0].open()
	var saved := mgr.to_dict()
	_check("sauvegarde : 9 capsules fermées", (saved["capsules"] as Array).size() == 9)
	var json: Dictionary = JSON.parse_string(JSON.stringify(saved))
	mgr.from_dict(json)
	_check("restauration : 9 capsules", mgr.capsules.size() == 9)
