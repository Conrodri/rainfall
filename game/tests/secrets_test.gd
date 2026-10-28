extends Node
## Porte scellée des 4 cartes B (docs/Design_Zones_Secretes.md §3, docs/Design_Variantes_B.md) :
## - une SecretRoom par carte B, 2 plaques / 2 gardiens nommés / 1 porte ; porte fermée = salle inaccessible (NavField) ;
## - une plaque ne réagit qu'au joueur (un monstre dessus ne fait rien), reste enfoncée, ordre libre ;
## - 2e plaque : collision de porte coupée, bloc de mur retiré, salle accessible (NavField refait), télégraphe puis
##   2 gardiens élites tier 3 nommés (affixes du biome) ; mort -> 2 reliquaires ; secret terminé ;
## - sauvegarde / reprise : plaque enfoncée, porte ouverte, gardien mort conservés ;
## - cartes A : aucun secret.
## godot --headless --path game res://tests/secrets_test.tscn  -> RESULT: OK

const B_MAPS := ["terrasses_rizieres_hautes", "foret_mangrove_lanternes", "cite_fonderie_canal", "cryptes_ossuaire_pluies"]
const A_MAPS := ["terrasses_noyees", "foret_brume", "cite_rouille", "cryptes_noyees"]

var _fails := 0
var _fake_chest_script: GDScript
var _player: CharacterBody2D
var _director: Node2D
var _mgr: StageManager


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


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


func _run() -> void:
	_fake_chest_script = GDScript.new()
	_fake_chest_script.source_code = "extends Node2D\nvar kind\nvar stage\nfunc setup(k, s):\n\tkind = k\n\tstage = s\n"
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
	for id in A_MAPS:
		await _load_map(id)
		_check("%s : aucun secret sur une carte A" % id, _mgr.secrets.is_empty())
	for id in B_MAPS:
		await _test_b(id)
	await _test_save(B_MAPS[0])


func _load_map(id: String) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	RunState.start_run(&"moyen", 31)
	_mgr.reset_run()
	var fl := int(meta["floor"])
	(_mgr.floor_plan[fl - 1] as Dictionary)["map_id"] = id
	RunState.stage = fl
	_mgr.start_stage()
	await _frames(2)
	_check("%s : carte chargée" % id, _mgr.map_id == id)


## Centre de la première case de la salle (repère local de la carte).
func _room_point(meta: Dictionary) -> Vector2:
	var c: Array = meta["secrets"][0]["room_cells"][0]
	var size_px := Vector2(meta["size_px"][0], meta["size_px"][1])
	return _mgr.map.from_map(Vector2((float(c[0]) + 0.5) * 128.0, (float(c[1]) + 0.5) * 128.0) - size_px * 0.5)


func _test_b(id: String) -> void:
	await _load_map(id)
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var map := _mgr.map
	_check("%s : une SecretRoom" % id, _mgr.secrets.size() == 1)
	if _mgr.secrets.size() != 1:
		return
	var room := _mgr.secrets[0]
	var sc: Dictionary = meta["secrets"][0]
	_check("%s : 2 plaques, 2 gardiens nommés" % id, room.plates.size() == 2 and room.guardian_defs.size() == 2)
	_check("%s : noms des gardiens" % id, room.guardian_defs[0]["name"] == sc["guardian_names"][0] and room.guardian_defs[1]["name"] == sc["guardian_names"][1])
	var nav: NavField = _director.nav
	var inside := map.to_global(_room_point(meta))
	_check("%s : salle scellée inaccessible porte fermée" % id, nav != null and not nav.is_reachable(inside))
	var door := map.get_node("Obstacles/Walls/Door_%s" % String(room.secret_id)) as CollisionShape2D
	_check("%s : collision de porte active" % id, door != null and not door.disabled)
	var dcell := Vector2i(int(sc["door_cells"][0][0]), int(sc["door_cells"][0][1]))
	_check("%s : bloc de porte dessiné" % id, map._blocks.has(dcell) or map.iso_dir_used == "")
	# plaque : un monstre dessus ne la déclenche pas
	var foe := CharacterBody2D.new()
	foe.collision_layer = 1 << 2
	foe.collision_mask = 0
	var fcs := CollisionShape2D.new()
	fcs.shape = CircleShape2D.new()
	foe.add_child(fcs)
	map.add_child(foe)
	foe.global_position = room.plates[0].global_position
	await _frames(3)
	_check("%s : un monstre n'enfonce pas la plaque" % id, not room.plates[0].pressed)
	foe.queue_free()
	# ligne OBJECTIFS et minimap : rien avant la 1re dalle (pas de spoiler), porte = mur tant que fermée
	var panel := ObjectivesPanel.new()
	panel.stage_manager = _mgr
	add_child(panel)
	panel.refresh()
	_check("%s : pas de ligne secrète avant la 1re dalle" % id, not panel.is_secret_shown())
	var mm := Minimap.new()
	add_child(mm)
	mm._bind_map(map)
	var dc: Vector2i = mm._secret_cells.keys()[0]
	_check("%s : minimap porte fermée = mur" % id, mm._vis_cell(dc.x, dc.y) == "#")
	var seen := {"plate": 0, "open": 0, "spawned": 0, "killed": 0, "done": 0}
	room.plate_pressed.connect(func(_i, _n, _t) -> void: seen["plate"] += 1)
	room.opened.connect(func(_i) -> void: seen["open"] += 1)
	room.guardian_spawned.connect(func(_i, _n, _e) -> void: seen["spawned"] += 1)
	room.guardian_killed.connect(func(_i, _n, _d, _t) -> void: seen["killed"] += 1)
	room.completed.connect(func(_i) -> void: seen["done"] += 1)
	# plaque 1, puis ailleurs, puis plaque 0 (ordre libre, état définitif)
	_player.global_position = room.plates[1].global_position
	await _frames(3)
	_check("%s : plaque 1 enfoncée" % id, room.plates[1].pressed and room.pressed_count() == 1 and not room.is_open)
	_check("%s : objectif Dalles 1/2" % id, room.objective_text() == "Dalles  1/2")
	panel.refresh()
	_check("%s : ligne secrète Dalles 1/2" % id, panel.is_secret_shown() and panel.secret_text() == "Dalles 1/2", panel.secret_text())
	_player.global_position = map.to_global(map.get_player_start())
	await _frames(3)
	_check("%s : la plaque reste enfoncée" % id, room.plates[1].pressed)
	_player.global_position = room.plates[0].global_position
	await _frames(4)
	_check("%s : 2 plaques -> porte ouverte" % id, room.is_open and seen["open"] == 1 and seen["plate"] == 2)
	_check("%s : compteur secret_zones = 1 (une fois par zone)" % id, int(RunState.counters.get("secret_zones", 0.0)) == 1, str(RunState.counters.get("secret_zones")))
	_check("%s : collision de porte coupée" % id, door.disabled)
	_check("%s : bloc de porte retiré" % id, not map._blocks.has(dcell))
	nav = _director.nav
	_check("%s : salle accessible porte ouverte (NavField refait)" % id, nav != null and nav.is_reachable(inside))
	_check("%s : objectif Gardiens 0/2" % id, room.objective_text() == "Gardiens  0/2")
	panel.refresh()
	_check("%s : ligne secrète Gardiens 0/2" % id, panel.secret_text() == "Gardiens 0/2", panel.secret_text())
	var floor_cells := 0
	for c: Vector2i in mm._secret_cells:
		if mm._vis_cell(c.x, c.y) == ".":
			floor_cells += 1
	_check("%s : minimap porte ouverte = sol (%d cases)" % [id, floor_cells], floor_cells == mm._secret_cells.size() and floor_cells > 1)
	var gold0 := RunState.gold
	# télégraphe 1 s + 2 gardiens espacés de 1,5 s
	await get_tree().create_timer(SecretRoom.TELEGRAPH_S + SecretRoom.GUARDIAN_GAP_S + 0.6).timeout
	_check("%s : 2 gardiens apparus" % id, seen["spawned"] == 2, str(seen))
	for i in 2:
		var g: Variant = room.guardians[i]
		_check("%s : gardien %d élite tier 3 nommé" % [id, i], g != null and g.is_elite and g.tier == 3 and g.get_meta(&"guardian_name", "") == sc["guardian_names"][i])
		if g != null:
			_check("%s : gardien %d accessible (hors mur)" % [id, i], nav.is_reachable(g.global_position))
			_check("%s : gardien %d affixes de biome" % [id, i], not g.affixes.is_empty() and g.affixes.size() <= 2)
	var chests0 := _mgr.chests.size()
	for i in 2:
		var g: Variant = room.guardians[i]
		if g != null:
			g.take_damage(1.0e9, false, &"test")
	await _frames(3)
	_check("%s : 2 gardiens tués" % id, room.dead_count() == 2 and seen["killed"] == 2 and seen["done"] == 1)
	_check("%s : prime d'or des gardiens" % id, RunState.gold > gold0, "%s -> %s" % [gold0, RunState.gold])
	panel.refresh()
	_check("%s : ligne secrète terminée" % id, panel.secret_text().begins_with("Salle secrète"), panel.secret_text())
	panel.queue_free()
	mm.queue_free()
	_check("%s : 2 reliquaires (coffres kind boss)" % id, _mgr.chests.size() == chests0 + 2 and _mgr.chests.back().kind == &"boss")
	_check("%s : secret terminé" % id, room.is_complete() and room.objective_text() == "" and _mgr.secret_status()[0]["complete"])


## Sauvegarde / reprise : plaque 0 enfoncée, puis porte ouverte + un gardien mort + reliquaire.
func _test_save(id: String) -> void:
	await _load_map(id)
	var room := _mgr.secrets[0]
	_player.global_position = room.plates[0].global_position
	await _frames(3)
	var d := _mgr.to_dict()
	_check("sauvegarde : bloc secrets", (d["secrets"] as Array).size() == 1 and d["secrets"][0]["plates"] == [true, false] and not d["secrets"][0]["open"])
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d))) # aller-retour JSON comme user://run_save.json
	await _frames(3)
	room = _mgr.secrets[0]
	_check("reprise : plaque 0 enfoncée, 1 non", room.plates[0].pressed and not room.plates[1].pressed and not room.is_open)
	_player.global_position = room.plates[1].global_position
	await _frames(4)
	_check("reprise : 2e plaque -> porte ouverte", room.is_open)
	await get_tree().create_timer(SecretRoom.TELEGRAPH_S + 0.4).timeout
	var g: Variant = room.guardians[0]
	_check("reprise : gardien 0 apparu", g != null)
	if g != null:
		g.take_damage(1.0e9, false, &"test")
	await _frames(3)
	var d2 := _mgr.to_dict()
	_check("sauvegarde : porte ouverte, gardien 0 mort, 1 reliquaire", d2["secrets"][0]["open"] and d2["secrets"][0]["dead"] == [true, false] and (d2["secrets"][0]["relics"] as Array).size() == 1)
	_mgr.from_dict(JSON.parse_string(JSON.stringify(d2)))
	await _frames(4)
	room = _mgr.secrets[0]
	var door := _mgr.map.get_node("Obstacles/Walls/Door_%s" % String(room.secret_id)) as CollisionShape2D
	_check("reprise : porte ouverte", room.is_open and door.disabled and room.plates[0].pressed and room.plates[1].pressed)
	_check("reprise : gardien 0 mort, reliquaire rendu", room.dead[0] and not room.dead[1] and room.relics.size() == 1)
	await get_tree().create_timer(3.8).timeout
	_check("reprise : le gardien vivant revient", room.guardians[1] != null)
