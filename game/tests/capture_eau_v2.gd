extends Node
## Captures (SANS --headless) de l'eau profonde d'une carte (bords organiques, 31/10/2026) : vue de jeu et zoom 1,8 sur la case « ~ » la plus proche du centre.
## godot --path game res://tests/capture_eau_v2.tscn -- --out=<dossier> --force-map=<id> [--tag=avant --sol-v1]
var _out := ""
var _tag := "apres"


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--tag="):
			_tag = a.substr(6)
		elif a == "--sol-v1": # ancien sol en losanges (capture « avant »)
			StageMap.ground_v2_enabled = false
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _map_id() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--force-map="):
			return a.substr(12)
	return "map"


func _shot(name: String) -> void:
	await _f(8)
	CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s_%s.png" % [_out, _map_id(), _tag, name])


func _run() -> void:
	get_window().size = Vector2i(1920, 1080)
	var id := _map_id()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var floor_n := int(data.get("floor", 1))
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
	m.set(&"save_path", "user://test_capture_eau_v2.json")
	add_child(m)
	await m.game_ready
	var stage: StageManager = m.get(&"stage")
	var player := m.get(&"player") as Node2D
	while RunState.stage < floor_n:
		stage.floor_cleared = true
		stage.teleporter.set_active(true)
		stage.teleporter.used.emit()
		await _f(10)
	await _f(30)
	await get_tree().create_timer(2.0).timeout
	print("carte ", stage.map_id)
	var cam := m.get(&"camera") as Camera2D
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.position_smoothing_enabled = false
	player.grant_invulnerability(99999.0)
	var d: Director = get_tree().get_first_node_in_group(&"director") as Director
	d.spawning_enabled = false
	d.despawn_all()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	for n in get_tree().root.find_children("*", "", true, false):
		if n is FloorCard:
			n.queue_free()
	await _f(20)
	var map := stage.map
	# cadre sur l'eau profonde : case « ~ » la plus proche du centre de la carte, deux zooms
	var g := AmbianceWater.grid_of(map)
	var best := Vector2.ZERO
	var best_d := INF
	var grid: PackedStringArray = g["grid"]
	for y in grid.size():
		for x in grid[y].length():
			if grid[y][x] == "~":
				var p: Vector2 = g["origin"] + (Vector2(x, y) + Vector2(0.5, 0.5)) * float(g["cell_px"])
				if p.length() < best_d:
					best_d = p.length()
					best = p
	cam.global_position = map.to_global(map.from_map(best))
	cam.zoom = Iso.camera_zoom(1.0)
	await _shot("1_eau")
	cam.zoom = Iso.camera_zoom(1.8)
	await _shot("2_eau_zoom")
	if FileAccess.file_exists("user://test_capture_eau_v2.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_capture_eau_v2.json"))
	get_tree().quit()
