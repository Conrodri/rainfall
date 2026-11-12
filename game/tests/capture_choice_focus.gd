extends Node
## Captures de l'écran vitrine : souris sans survol, souris sur la carte 2, manette sur la carte 2, tactile.
## godot --path game --resolution 1600x900 --quit-after 400 res://tests/capture_choice_focus.tscn -- --out=<dossier>


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var out := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6) + "/"
	var ids: Array = ItemDB.all_ids().slice(0, 3)
	for step in ["souris_repos", "souris_survol2", "manette_carte2", "tactile"]:
		var mode := Platform.InputMode.KBM
		if step.begins_with("manette"):
			mode = Platform.InputMode.GAMEPAD
		elif step == "tactile":
			mode = Platform.InputMode.TOUCH
		Platform.set_input_mode(mode)
		var ui := ShowcaseUI.new()
		add_child(ui)
		ui.open_pick(1, 0.0, ids, &"commun")
		await get_tree().create_timer(ShowcaseUI.INPUT_LOCK_S + 0.4, true, false, true).timeout
		if step == "souris_survol2":
			ui._buttons[1].mouse_entered.emit()
		elif step == "manette_carte2":
			ui._buttons[1].grab_focus()
		await get_tree().create_timer(0.3, true, false, true).timeout
		get_viewport().get_texture().get_image().save_png(out + "vitrine_%s.png" % step)
		ui.queue_free()
		await get_tree().process_frame
	get_tree().quit()
