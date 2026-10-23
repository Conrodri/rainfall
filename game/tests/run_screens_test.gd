extends Node
## Lot M-E : dialogue de fin d'étage thémé (RunScreens.dialog) : principal / secondaire, taille tactile, focus.

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _ready() -> void:
	get_tree().paused = true
	var hits := [0, 0]
	var d := RunScreens.dialog("Étage 3 terminé", ["Vous pouvez continuer.", "Terminer = victoire, rubis +25."],
		[["Terminer la run", func() -> void: hits[0] += 1], ["Continuer (sans fin)", func() -> void: hits[1] += 1]])
	add_child(d)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(d.texts().size() == 3 and d.texts()[2].contains("victoire"), "titre + 2 lignes")
	var b0: Button = d._buttons[0]
	var b1: Button = d._buttons[1]
	_check(b0.theme_type_variation == &"" and b0.has_theme_stylebox_override("normal"), "principal : style orange du thème")
	_check(not b1.has_theme_stylebox_override("normal"), "secondaire : style par défaut du thème")
	_check(d._root.theme != null, "thème UiTheme posé")
	_check(b0.custom_minimum_size.x >= 600.0 and b0.custom_minimum_size.y >= 88.0, "principal >= 88 px de haut (%s)" % b0.custom_minimum_size)
	_check(b1.custom_minimum_size.y >= 88.0, "secondaire >= 88 px de haut")
	_check(b0.custom_minimum_size.x >= b1.custom_minimum_size.x, "principal au moins aussi large que secondaire")
	if Platform.input_mode != Platform.InputMode.TOUCH:
		_check(get_viewport().gui_get_focus_owner() == b0, "focus initial sur le bouton principal")
	_check(b0.get_node(b0.focus_neighbor_bottom) == b1 and b1.get_node(b1.focus_neighbor_top) == b0, "focus haut/bas entre les boutons")
	d.press(1)
	_check(hits[1] == 1 and hits[0] == 0, "press(1) -> second callback")
	d.queue_free()
	var l := RunScreens.loading()
	add_child(l)
	await get_tree().process_frame
	_check(l.texts().size() == 1 and l._buttons.is_empty(), "écran de chargement inchangé")
	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().paused = false
	get_tree().quit(0 if _fails == 0 else 1)
