extends Node
## Capture du panneau du mode test (SANS --headless) : un cliché par onglet.
## godot --path game res://tests/_test_mode_capture.tscn -- --out=<dossier> [--touch]

var _out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
	Platform.set_input_mode(Platform.InputMode.TOUCH if OS.get_cmdline_user_args().has("--touch") else Platform.InputMode.KBM)
	_run.call_deferred()


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	TestMode.begin()
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"run_seed", 5)
	add_child(m)
	await m.game_ready
	await _f(30)
	TestMode.set_difficulty(8.0)
	var o: TestOverlay = m.get_node("TestOverlay")
	TestTools.spawn(get_tree(), TestTools.monster_catalog()[0], 5, false)
	var pt := TestTools.spawn_poutch(get_tree(), &"normal", _player_pos(m) + Vector2(260, 40))
	TestTools.spawn_chest(get_tree(), &"large", _player_pos(m) + Vector2(-260, 60))
	await _f(10)
	for i in 6:
		pt.enemy.take_damage(900.0, i == 2, &"", {"source_pos": pt.enemy.position + Vector2(-40, 0)})
		await _f(6)
	if _out != "":
		CaptureUtil.save_viewport(get_viewport(), "%s/testmode_world.png" % _out)
	o.open()
	print("panel ", o.panel.visible, " ", o.panel.get_global_rect(), " layer ", o.panel.get_parent().layer, " vp ", get_viewport().get_visible_rect())
	for t in TestPanel.TABS:
		o.panel._select_tab(t[1])
		await _f(8)
		if _out != "":
			CaptureUtil.save_viewport(get_viewport(), "%s/testmode_%s.png" % [_out, t[1]])
		print("shot ", t[1])
		for sy in [650, 1500]:
			o.panel._scroll.scroll_vertical = sy
			await _f(4)
			if _out != "":
				CaptureUtil.save_viewport(get_viewport(), "%s/testmode_%s_%d.png" % [_out, t[1], sy])
	get_tree().paused = false
	get_tree().quit()


func _player_pos(m: Node) -> Vector2:
	return (m.get(&"player") as Node2D).global_position
