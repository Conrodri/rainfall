extends Node
## Captures (SANS --headless) de l'événement ambiant d'une carte dans une vraie run : avant / pendant, caméra sur la
## cible de l'effet (prop fixe : margelle, creusets, noria ; sinon première case d'eau peu profonde, sinon centre).
## godot --path game res://tests/capture_ambient_events.tscn -- --out=<dossier> --force-map=<id>
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
	var floor_n := 1
	for k in ["terrasses", "foret", "cite", "cryptes", "la_source"]:
		if id.begins_with(k):
			floor_n = ["terrasses", "foret", "cite", "cryptes", "la_source"].find(k) + 1
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
	print("pause après présage ", get_tree().paused)
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
	var mgr := AmbianceManager.find(get_tree())
	var map := stage.map
	var target := map.to_global(Vector2.ZERO)
	var ev := AmbientEvents.read_event(id)
	for e in ev.get("effects", []):
		var pn := String((e as Dictionary).get("prop", ""))
		var blocks := map.get_node_or_null(^"Blocks")
		if pn != "" and blocks != null:
			for c in blocks.get_children():
				if String(c.name).begins_with("FP_%s_" % pn):
					target = (c as Node2D).global_position
					break
			break
	cam.zoom = Vector2(0.8, 0.8)
	cam.global_position = target
	AmbientEvents.forced_d = -1.0
	await _shot("1_avant")
	AmbientEvents.forced_d = 7.5
	await get_tree().create_timer(16.0).timeout
	await _shot("2_pendant")
	print("effets ", mgr.events.active_count() if mgr != null else -1, " / ", mgr.events.effects.size() if mgr != null else -1, " pause ", get_tree().paused, " manquants ", mgr.events.missing_assets() if mgr != null else [])
	cam.zoom = Vector2(0.35, 0.35)
	cam.global_position = map.to_global(Vector2.ZERO)
	await _shot("3_large")
	get_tree().quit()
