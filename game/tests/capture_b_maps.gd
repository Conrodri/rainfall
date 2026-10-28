extends Node
## Captures (SANS --headless) d'une variante B dans une vraie run : vue large de la carte, porte scellée fermée,
## arène du gros pilier, puis porte ouverte et gardiens sortis.
## godot --path game res://tests/capture_b_maps.tscn -- --out=<dossier> --force-map=<id>
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
	# amène l'étage voulu (plan forcé par --force-map)
	while RunState.stage < floor_n:
		stage.floor_cleared = true
		stage.teleporter.set_active(true)
		stage.teleporter.used.emit()
		await _f(10)
	await _f(30)
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
	var map := stage.map
	var start := player.global_position
	# 1. vue large
	cam.zoom = Vector2(0.3, 0.3)
	cam.global_position = map.to_global(Vector2.ZERO)
	await _shot("1_large")
	# 2. porte scellée fermée
	var room := stage.secrets[0]
	cam.zoom = Vector2(0.9, 0.9)
	cam.global_position = map.to_global(room.door_pos)
	await _shot("2_porte_fermee")
	# 3. arène du gros pilier
	var big: Pillar = stage.pillars.back()
	cam.zoom = Vector2(0.7, 0.7)
	cam.global_position = big.global_position
	await _shot("3_arene_gros_pilier")
	# 4. départ
	cam.zoom = Vector2(0.8, 0.8)
	cam.global_position = start
	await _shot("4_depart")
	# 5. plaque
	cam.zoom = Vector2(1.2, 1.2)
	cam.global_position = room.plates[0].global_position
	await _shot("5_plaque")
	# 6. porte ouverte, gardiens sortis
	for p in room.plates:
		p.press()
	cam.zoom = Vector2(0.9, 0.9)
	cam.global_position = map.to_global(room.door_pos)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = map.to_global(room.door_pos)
	await _f(20)
	await _shot("6_porte_ouverte")
	await get_tree().create_timer(3.0).timeout
	player.process_mode = Node.PROCESS_MODE_DISABLED
	cam.global_position = map.to_global(room.door_pos)
	await _shot("7_gardiens")
	get_tree().quit()
