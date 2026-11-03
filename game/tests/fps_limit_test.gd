extends Node
## Limite d'images : godot --headless --path game res://tests/fps_limit_test.tscn
## Fichier de réglages injecté ; Engine.max_fps restauré à la fin.

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	var saved_fps := Engine.max_fps
	GameSettings.cfg_path = "user://test_fps_limit.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	Platform.set_input_mode(Platform.InputMode.KBM)

	# Défaut : aucune clé -> illimité, comportement historique.
	Engine.max_fps = 77
	GameSettings.apply_fps_limit()
	_check(Engine.max_fps == 0 and GameSettings.fps_limit() == 0 and not GameSettings.fps_limit_chosen(), "défaut : max_fps 0, rien enregistré")

	# Chaque valeur PC.
	var opts := GameSettings.fps_limit_options()
	_check(opts == [60, 144, 240, 360, 0], "options PC : %s" % str(opts))
	for v in opts:
		GameSettings.set_fps_limit(int(v))
		_check(Engine.max_fps == int(v) and GameSettings.fps_limit() == int(v), "set_fps_limit(%d) -> Engine.max_fps %d" % [v, Engine.max_fps])

	# Sauvegarde / rechargement.
	GameSettings.set_fps_limit(144)
	Engine.max_fps = 0
	GameSettings.apply_fps_limit()
	_check(Engine.max_fps == 144 and GameSettings.fps_limit_chosen(), "rechargement : 144 réappliqué depuis le fichier")
	var cf := ConfigFile.new()
	cf.load(GameSettings.cfg_path)
	_check(int(cf.get_value("graphics", "fps_limit", -1)) == 144, "clé [graphics] fps_limit écrite")

	# Valeur inconnue -> illimité.
	GameSettings.set_fps_limit(244)
	_check(Engine.max_fps == 0 and GameSettings.fps_limit() == 0, "valeur inconnue (244) -> 0")

	# Mobile : options <= 120, 0 en dernier.
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	if not Platform.is_pc():
		var mo := GameSettings.fps_limit_options()
		_check(mo.back() == 0 and mo.all(func(x: Variant) -> bool: return int(x) <= 120), "options mobile : %s" % str(mo))
	else:
		print("skip options mobile (Platform.is_pc() reste vrai hors appareil)")
	Platform.set_input_mode(Platform.InputMode.KBM)

	# Panneau : sélecteur présent, index = valeur, changement -> Engine.max_fps.
	GameSettings.set_fps_limit(240)
	var host := Control.new()
	add_child(host)
	var panel := SettingsPanel.new()
	host.add_child(panel)
	await get_tree().process_frame
	await get_tree().process_frame
	panel.sync()
	var st: OptionStepper = panel._fps_limit
	_check(st != null and st.items.size() == 5 and st.index == 2, "panneau : sélecteur sur 240")
	st.index = 3
	st.changed.emit(3)
	_check(Engine.max_fps == 360 and GameSettings.fps_limit() == 360, "panneau : 360 -> Engine.max_fps 360")

	# Réinitialiser -> défaut.
	GameSettings.reset_all(get_tree())
	_check(Engine.max_fps == 0 and not GameSettings.fps_limit_chosen(), "reset_all : retour à illimité, clé effacée")

	Engine.max_fps = saved_fps
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
