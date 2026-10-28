extends Node
## Captures de la passe accessibilité : HUD (barre de PV, infobulle d'objet, objectifs) et écran de coffre en trois variantes
## (normal, deutéranopie, texte 130 %). Fenêtre réelle requise (pas --headless).
## godot --path game --resolution 1600x900 res://tests/capture_a11y.tscn -- --phase=hud|chest --out=<dossier>
## Fichier de réglages injecté : la config du joueur n'est pas touchée.

const VARIANTS := [["normal", 0, 0], ["deuteranopie", 1, 0], ["texte130", 0, 2]] ## nom, mode daltonien, indice de taille de texte

var _phase := "hud"
var _out := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--phase="):
			_phase = a.substr(8)
		elif a.begins_with("--out="):
			_out = a.substr(6)
	GameSettings.cfg_path = "user://test_capture_a11y.cfg"
	DirAccess.make_dir_recursive_absolute(_out)
	if _phase == "chest":
		await _chest()
	else:
		await _hud()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _apply(v: Array) -> void:
	GameSettings.set_colorblind(int(v[1]))
	GameSettings.set_text_scale_index(int(v[2]))
	CvdPalette.clear_cache()
	Accessibility.notify_changed()


func _shot(name: String) -> void:
	await _frames(4)
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, name])
	print("saved ", name, " ", img.get_size())


func _chest() -> void:
	for v in VARIANTS:
		_apply(v)
		var ui: ChestUI = load("res://scenes/ui/chest/chest_ui.tscn").instantiate()
		add_child(ui)
		ui.open(&"large", 2, 0.0)
		while ui._busy:
			await get_tree().process_frame
		await _frames(30)
		await _shot("chest_" + String(v[0]))
		ui.queue_free()
		await _frames(5)


func _hud() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 2024)
	add_child(main)
	while not bool(main.get(&"is_ready")):
		await get_tree().process_frame
	var hud: Hud = main.hud
	main.player.grant_invulnerability(1.0e6)
	var ids := ItemDB.all_ids()
	for k in [1, 5, 12, 20, 33, 41, 47]:
		RunState.add_item(StringName(ids[k % ids.size()]))
	var d: Director = main.director
	var pp: Vector2 = main.player.global_position
	for i in 4:
		d.spawn_enemy(1 + i % 3, pp + Vector2.from_angle(i * TAU / 4.0) * 330.0, i == 2)
	for v in VARIANTS:
		_apply(v)
		main.player.hp = main.player.max_hp * 0.2 # PV bas : la barre passe à la couleur d'alerte
		main.player.hp_changed.emit(main.player.hp, main.player.max_hp)
		await _frames(30)
		hud.item_bar.show_tooltip(StringName(ids[5]))
		await _shot("hud_" + String(v[0]))
		hud.item_bar.hide_tooltip()
	RunState.items.clear()
