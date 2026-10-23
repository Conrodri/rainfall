extends Node
## Capture de l'écran de coffre avec la description et le nom les plus longs de data/items.json (mise en page des cartes).
## godot --path game --write-movie <dossier>/f.png --fixed-fps 30 --resolution 1280x720 --quit-after 200 res://tests/capture_chest_cards.tscn
## (idem en 2400x1080). Cartes visibles vers 4,5 s.


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.cfg_path = "user://test_capture_chest_settings.cfg"
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/items.json"))
	var long_eff := ""
	var long_name := ""
	for it in items:
		if str(it.get("effect_text", "")).length() > long_eff.length():
			long_eff = str(it["effect_text"])
		if str(it.get("name", "")).length() > long_name.length():
			long_name = str(it["name"])
	var ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
	add_child(ui)
	ui.open(&"large", 2, 0.0)
	while ui._busy:
		await get_tree().process_frame
	for i in 2:
		var f := ui._card_front[i]
		(f.get_child(1) as Label).text = long_name
		(f.get_child(2) as Label).text = long_eff
		(f.get_child(3) as Label).text = "[Zone] [Survie] [Boss]"
		(f.get_child(4) as Label).text = "Vous en avez déjà 12"
		ui._fit_card(i)
