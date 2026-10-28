extends Node
## Capture (SANS --headless) des 4 monstres v2 des terrasses à côté du joueur : repos, course, frame d'impact.
## godot --path game res://tests/capture_monsters_v2.tscn -- --out=<dossier>

var _out := ""
var _biome := &"terrasses"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		if a.begins_with("--biome="):
			_biome = StringName(a.substr(8))
	Platform.set_input_mode(Platform.InputMode.KBM)
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	TestMode.begin()
	EnemyVisual.biome_override = _biome
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
	add_child(m)
	await m.game_ready
	await _f(30)
	var player := m.get(&"player") as Node2D
	var d: Director = get_tree().get_first_node_in_group(&"director") as Director
	var base := player.global_position
	var spots := [Vector2(-3.0, 2.0), Vector2(-1.8, 2.0), Vector2(1.0, 2.0), Vector2(2.6, 2.0), Vector2(5.0, 2.0)]
	var list: Array[Enemy] = []
	var defs := [[1, 0], [2, 0], [2, 1], [3, 0]]
	for i in 4:
		var e := d.spawn_enemy(defs[i][0], base + spots[i] * 64.0, false, [] as Array[StringName], defs[i][1])
		list.append(e)
	d.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED # plus de tirs : les monstres ne sont pas tués pendant la prise de vue
	for n in get_tree().get_nodes_in_group(&"player_projectiles"):
		n.queue_free()
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		cam.zoom *= 1.0
		cam.global_position = base + Vector2(0.5, 1.5) * 64.0
	await _f(8)
	for dir_name in [["s", PI / 2.0], ["e", 0.0]]:
		for e in list:
			e.visual.set_facing(dir_name[1])
			e.visual.set_action(&"idle")
		await _f(6)
		_shot("idle_%s" % dir_name[0])
		for e in list:
			e.visual.set_action(&"run")
		await _f(7)
		_shot("run_%s" % dir_name[0])
		# frame d'impact : anim calée sur 0,5 s, on attend ~0,5 s
		for e in list:
			e.visual.set_action_timed(&"attack", 0.5)
		await get_tree().create_timer(0.52).timeout
		_shot("impact_%s" % dir_name[0])
		for e in list:
			e.visual.set_action_timed(&"cast" if e.tier == 3 else &"attack", 0.5)
	get_tree().quit()


func _shot(n: String) -> void:
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/monv2_%s_%s.png" % [_out, _biome, n])
	print("shot ", n)
