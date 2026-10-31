extends Node
## Captures (SANS --headless) du sol d'une carte dans une vraie run (refonte du sol v2, GroundSplat) :
## vue de jeu au départ du joueur (zoom normal), vue reculée (0,55) et vue large de la carte.
## godot --path game res://tests/capture_sol_v2.tscn -- --out=<dossier> --force-map=<id> [--tag=avant --sol-v1]
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
	m.set(&"save_path", "user://test_capture_sol_v2.json")
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
	var start := map.to_global(map.get_player_start())
	cam.zoom = Iso.camera_zoom(1.0)
	cam.global_position = start
	await _shot("1_jeu")
	cam.zoom = Iso.camera_zoom(0.55)
	await _shot("2_recul")
	var b := map.get_bounds()
	var z := minf(1920.0 / b.size.x, 2160.0 / b.size.y) * 0.94
	cam.zoom = Iso.camera_zoom(z / (Iso.SCREEN_PX_PER_U / Balance.UNIT_PX))
	cam.global_position = map.to_global(b.get_center())
	await _shot("3_large")
	if FileAccess.file_exists("user://test_capture_sol_v2.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_capture_sol_v2.json"))
	get_tree().quit()
