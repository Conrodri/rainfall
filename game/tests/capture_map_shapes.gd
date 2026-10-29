extends Node
## Captures (SANS --headless) d'une carte au contour organique dans une vraie run : vue large de la carte
## entière, puis gros plans sur les quatre bords (nord = remparts, sud = falaises, ouest, est) pour vérifier
## les raccords de tuiles de bord, le masque du vide, les rives et les lumières.
## godot --path game res://tests/capture_map_shapes.tscn -- --out=<dossier> --force-map=<id>
const EDGE_ZOOM_MULT := 0.55
var _out := ""


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _shot(tag: String) -> void:
	await _f(6)
	CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s.png" % [_out, _map_id(), tag])


func _map_id() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--force-map="):
			return a.substr(12)
	return "map"


func _run() -> void:
	get_window().size = Vector2i(1920, 1080)
	var id := _map_id()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var floor_n := int(data.get("floor", 1))
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
	m.set(&"save_path", "user://test_capture_map_shapes.json")
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
	var map := stage.map
	# 1. vue large : la carte entière dans la fenêtre (zoom iso 2:1 conservé)
	var b := map.get_bounds()
	var z := minf(1920.0 / b.size.x, 2160.0 / b.size.y) * 0.94
	cam.zoom = Iso.camera_zoom(z / (Iso.SCREEN_PX_PER_U / Balance.UNIT_PX))
	cam.global_position = map.to_global(b.get_center())
	await _shot("1_large")
	# 2-5. bords : première case praticable depuis chaque côté de la grille (repère carte)
	var grid: Array = data["grid"]
	var size_px := Vector2(data["size_px"][0], data["size_px"][1])
	var origin := -size_px * 0.5
	var edges := {"2_nord": _first_walkable(grid, Vector2i(0, 1)), "3_sud": _first_walkable(grid, Vector2i(0, -1)),
		"4_ouest": _first_walkable(grid, Vector2i(1, 0)), "5_est": _first_walkable(grid, Vector2i(-1, 0))}
	cam.zoom = Iso.camera_zoom(EDGE_ZOOM_MULT)
	for tag in edges:
		var c: Vector2i = edges[tag]
		cam.global_position = map.to_global(map.from_map(origin + (Vector2(c) + Vector2(0.5, 0.5)) * 128.0))
		await _shot(tag)
	if FileAccess.file_exists("user://test_capture_map_shapes.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_capture_map_shapes.json"))
	get_tree().quit()


## Case praticable la plus proche du bord de la grille en balayant dans la direction `dir` (ligne médiane).
func _first_walkable(grid: Array, dir: Vector2i) -> Vector2i:
	var h := grid.size()
	var w := (grid[0] as String).length()
	var c := Vector2i(w / 2, 0) if dir.y > 0 else (Vector2i(w / 2, h - 1) if dir.y < 0 else (Vector2i(0, h / 2) if dir.x > 0 else Vector2i(w - 1, h / 2)))
	while c.x >= 0 and c.y >= 0 and c.x < w and c.y < h:
		var ch: String = (grid[c.y] as String)[c.x]
		if ch == "." or ch == "," or ch in "CPGES":
			return c
		c += dir
	return Vector2i(w / 2, h / 2)
