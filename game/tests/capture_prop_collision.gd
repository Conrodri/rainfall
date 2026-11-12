extends Node
## Captures (SANS --headless) des props d'une carte avec les formes de collision visibles : une vue par prop distinct.
## godot --path game --debug-collisions res://tests/capture_prop_collision.tscn -- --out=<dossier> --force-map=<id> [--names=noria,stone_stairs]
## Sans --names : tous les props distincts posés sur la carte ; sans --debug-collisions : même vues, sans les formes.
var _out := ""
var _names: PackedStringArray = []
var _zoom := 1.6


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--names="):
			_names = a.substr(8).split(",")
		elif a.begins_with("--zoom="):
			_zoom = float(a.substr(7))
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _map_id() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--force-map="):
			return a.substr(12)
	return "map"


func _run() -> void:
	get_window().size = Vector2i(1920, 1080)
	var floor_n := 1
	var id := _map_id()
	for k in ["terrasses", "foret", "cite", "cryptes"]:
		if id.begins_with(k):
			floor_n = ["terrasses", "foret", "cite", "cryptes"].find(k) + 1
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
	for i in 300: # présage d'étage (écran modal qui met le jeu en pause) : choix « Ciel clair »
		var om: Variant = m.get(&"omen_screen")
		if om != null and is_instance_valid(om):
			om.call(&"choose", 2)
		if not get_tree().paused:
			break
		await _f(1)
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
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	for e in get_tree().get_nodes_in_group(&"enemies"):
		(e as Node).queue_free()
	var map := stage.map
	var seen := {}
	var blocks := map.get_node("Blocks")
	var todo: Array = []
	for c in blocks.get_children():
		if not c is Sprite2D or not c.has_meta(&"prop"):
			continue
		var tex := (c as Sprite2D).texture.resource_path.get_file().get_basename()
		(c as Sprite2D).modulate.a = 0.5 # transparent : les formes de collision (dessinées sous les sprites) restent lisibles
		if seen.has(tex) or (not _names.is_empty() and not _names.has(tex)):
			continue
		seen[tex] = true
		todo.append([tex, c])
	print("props : ", seen.keys())
	for t in todo:
		cam.zoom = Iso.camera_zoom(_zoom)
		cam.global_position = (t[1] as Node2D).global_position + Vector2(0.0, -40.0)
		await _f(8)
		CaptureUtil.save_viewport(get_viewport(), "%s/%s_%s.png" % [_out, id, t[0]])
	get_tree().quit()
