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
	o.open()
	print("panel ", o.panel.visible, " ", o.panel.get_global_rect(), " layer ", o.panel.get_parent().layer, " vp ", get_viewport().get_visible_rect())
	for t in TestPanel.TABS:
		o.panel._select_tab(t[1])
		await _f(8)
		if _out != "":
			CaptureUtil.save_viewport(get_viewport(), "%s/testmode_%s.png" % [_out, t[1]])
		print("shot ", t[1])
	get_tree().paused = false
	get_tree().quit()
