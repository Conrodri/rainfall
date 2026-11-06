extends Node
## Captures (SANS --headless) de l'emplacement de la salle scellée, avec ou sans secret tiré dans la run :
## godot --path game res://tests/capture_secret_zone.tscn -- --out=<dossier> --force-map=<id> --force-secret=<étage ou 0>
## Une vue large + un gros plan sur la salle (centre des cases de salle du JSON).
var _out := ""


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""


func _ready() -> void:
	_out = _arg("--out=")
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _run() -> void:
	get_window().size = Vector2i(1920, 1080)
	var id := _arg("--force-map=")
	var floor_n := 1
	for k in ["terrasses", "foret", "cite", "cryptes"]:
		if id.begins_with(k):
			floor_n = ["terrasses", "foret", "cite", "cryptes"].find(k) + 1
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
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
	await get_tree().create_timer(3.0).timeout
	for n in get_tree().root.find_children("*", "OmenScreen", true, false): # présage d'étage : refusé (ciel clair)
		(n as OmenScreen).choose((n as OmenScreen).card_ids().size() - 1)
	await get_tree().create_timer(1.5).timeout
	var tag := "secret" if not stage.secrets.is_empty() else "sans"
	var cam := m.get(&"camera") as Camera2D
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.position_smoothing_enabled = false
	player.grant_invulnerability(99999.0)
	var d: Director = get_tree().get_first_node_in_group(&"director") as Director
	d.spawning_enabled = false
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var map := stage.map
	var size_px := Vector2(meta["size_px"][0], meta["size_px"][1])
	var c: Array = meta["secrets"][0]["room_cells"][4]
	var pt := map.from_map(Vector2((float(c[0]) + 0.5) * 128.0, (float(c[1]) + 0.5) * 128.0) - size_px * 0.5)
	cam.zoom = Vector2(0.3, 0.3)
	cam.global_position = map.to_global(Vector2.ZERO)
	await _f(8)
	CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s_large.png" % [_out, id, tag])
	cam.zoom = Vector2(0.75, 0.75)
	cam.global_position = map.to_global(pt)
	await _f(8)
	CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s_salle.png" % [_out, id, tag])
	print("capture ok")
	OS.kill(OS.get_process_id())
