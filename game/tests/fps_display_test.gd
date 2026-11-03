extends Node
## Compteur FPS : godot --headless --path game res://tests/fps_display_test.tscn
## Réglage on -> label visible au texte numérique ; off -> caché ; bascule à chaud.

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _ready() -> void:
	GameSettings.cfg_path = "user://test_fps_display.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	GameSettings.set_show_fps(false)
	var c: CanvasLayer = preload("res://scripts/ui/fps_counter.gd").new()
	add_child(c)
	await _frames(0.4)
	_check(c.label != null and not c.label.visible, "défaut/off : compteur caché")

	GameSettings.set_show_fps(true)
	await _frames(0.5)
	var digits: String = c.label.text.trim_suffix(" FPS")
	_check(c.label.visible and digits.is_valid_int(), "on : visible, texte numérique « %s »" % c.label.text)
	_check(c.layer > 10, "au-dessus de l'UI (layer %d)" % c.layer)

	c.label.text = "x"
	await _frames(0.5)
	_check(c.label.text.trim_suffix(" FPS").is_valid_int(), "texte mis à jour à chaud")

	GameSettings.set_show_fps(false)
	await _frames(0.5)
	_check(not c.label.visible, "bascule off : caché")
	GameSettings.set_show_fps(true)
	await _frames(0.5)
	_check(c.label.visible, "bascule on : revisible")

	GameSettings.set_show_fps(false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
