extends Node
## Captures store des menus (SANS --headless) : sélection de personnage, fiche ouverte.
## godot --path game res://tests/capture_store_menu.tscn -- --out=<dossier> [--pick=<n° de carte>]
## Écrit <dossier>/select.png (grille) et <dossier>/sheet.png (fiche du personnage choisi).

class FakeProfile extends RefCounted:
	var rubies := 4820
	var unlocked_modes: Array = ["facile", "moyen", "difficile"]
	var unlocked_spells: Array = ["spell:meteor_rain"]
	var last_mode := "moyen"
	var last_character := "ardent"
	var stats := {"runs": 37, "victories": 5, "kills": 18423, "play_time_s": 43200.0, "best_time_s": {"facile": 812.0}}

	func is_unlocked(key: StringName) -> bool:
		return String(key) in unlocked_spells


var _out := "user://"
var _pick := 0
var _screen: Control


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--pick="):
			_pick = int(a.substr(7))
	Platform.set_input_mode(Platform.InputMode.KBM)
	get_window().size = Vector2i(1920, 1080)
	_run.call_deferred()


func _run() -> void:
	_screen = load("res://scenes/menu/new_run.tscn").instantiate()
	_screen.set("profile", FakeProfile.new())
	add_child(_screen)
	await get_tree().create_timer(2.0).timeout
	CaptureUtil.save_viewport(get_viewport(), "%s/select.png" % _out)
	var nr := _screen as NewRunScreen
	nr.cards[_pick].pressed.emit()
	await get_tree().create_timer(1.5).timeout
	CaptureUtil.save_viewport(get_viewport(), "%s/sheet.png" % _out)
	print("SAVED ", _out)
	get_tree().quit()
