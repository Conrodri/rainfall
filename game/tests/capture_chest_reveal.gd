extends Node
## Capture de la mise en scène du coffre (défilement de rareté puis des items), grand coffre puis coffre légendaire.
## godot --path game --write-movie <dossier>/f.png --fixed-fps 30 --resolution 1920x1080 --quit-after 180 res://tests/capture_chest_reveal.tscn
## (idem en 2400x1080 et 1280x720). Images ~ 10-30 : rareté ; 35-50 : items ; 60 : résultat ; 95-150 : légendaire.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.cfg_path = "user://test_capture_chest_settings.cfg"
	RunState.start_run(&"moyen", 777)
	for kind in [&"large", &"legendaire"]:
		var ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
		add_child(ui)
		ui.open(kind, 2, 0.0)
		await get_tree().process_frame
		while ui.is_animating():
			await get_tree().process_frame
		for i in 30:
			await get_tree().process_frame
		ui.queue_free()
		get_tree().paused = false
		await get_tree().process_frame
