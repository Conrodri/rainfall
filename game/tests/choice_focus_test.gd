extends Node
## Écrans de choix (vitrine, coffre, présage, boussole) : aucune carte ne garde un focus d'office hors manette ;
## souris = le focus suit le survol, tactile = aucun focus, manette = focus sur la 1re carte (FocusFollow).
## godot --headless --path game res://tests/choice_focus_test.tscn   (sortie « RESULT: OK »)

var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label)


func _focused(ui: ShowcaseUI) -> int:
	return ui._buttons.find(get_viewport().gui_get_focus_owner())


func _run() -> void:
	var ids: Array = ItemDB.all_ids().slice(0, 3)
	for mode in [Platform.InputMode.KBM, Platform.InputMode.TOUCH, Platform.InputMode.GAMEPAD]:
		Platform.set_input_mode(mode)
		var ui := ShowcaseUI.new()
		add_child(ui)
		ui.open_pick(1, 0.0, ids, &"commun")
		for i in 3:
			await get_tree().process_frame
		await get_tree().create_timer(ShowcaseUI.INPUT_LOCK_S + 0.2, true, false, true).timeout
		var f := _focused(ui)
		if mode == Platform.InputMode.GAMEPAD:
			_check("manette : focus sur la carte 1", f == 0)
			ui._buttons[2].grab_focus()
			_check("manette : focus déplaçable sur la carte 3", _focused(ui) == 2)
		else:
			_check("mode %d : aucune carte focalisée d'office" % mode, f == -1)
		if mode == Platform.InputMode.KBM:
			ui._buttons[1].mouse_entered.emit()
			_check("souris : survol carte 2 = focus carte 2", _focused(ui) == 1)
			ui._buttons[2].mouse_entered.emit()
			_check("souris : survol carte 3 = focus carte 3 (un seul contour)", _focused(ui) == 2)
			ui._buttons[2].mouse_exited.emit()
			_check("souris : sortie = plus de contour", _focused(ui) == -1)
			var ev := InputEventAction.new()
			ev.action = &"ui_right"
			ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			await get_tree().process_frame
			_check("clavier : navigation sans focus = carte 1", _focused(ui) == 0)
		if mode == Platform.InputMode.TOUCH:
			ui._buttons[1].mouse_entered.emit()
			_check("tactile : survol sans effet", _focused(ui) == -1)
		ui.queue_free()
		await get_tree().process_frame
	Platform.set_input_mode(Platform.InputMode.KBM)
