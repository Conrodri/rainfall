extends Node
## Test du lot A (thème et composants UI).
## godot --headless --path game res://tests/ui_theme_test.tscn

var _fails := 0
var _got: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _on_chosen(d: bool) -> void:
	_got.append(d)


func _ready() -> void:
	await get_tree().process_frame
	var th := UiTheme.theme()
	_check(th != null and th.has_stylebox(&"normal", &"Button"), "theme: styles de bouton")
	_check(UiTheme.theme() == th, "theme: cache")
	_check(UiTheme.scale() > 0.5 and UiTheme.scale() <= 1.0, "scale dans [0,55 ; 1]")

	# Tailles tactiles >= 88 après apply
	var root := Control.new()
	add_child(root)
	var box := VBoxContainer.new()
	root.add_child(box)
	var b1 := Button.new()
	var b2 := MenuBtn.new()
	var sl := HSlider.new()
	var cb := CheckButton.new()
	for c in [b1, b2, sl, cb]:
		box.add_child(c)
	UiTheme.apply(root)
	for c in [b1, b2, sl, cb]:
		_check((c as Control).custom_minimum_size.y >= 88.0, "min height >= 88 : %s" % c.get_class())
	_check(b2.custom_minimum_size.x >= 620.0, "MenuBtn largeur 620")
	_check(root.theme == th, "apply pose le thème")

	# MenuBtn sous-titre + primary/destructive
	b2.subtitle = "Ardent · Étage 2"
	_check(b2._sub != null and b2._sub.visible and b2._sub.text == "Ardent · Étage 2", "sous-titre")
	UiTheme.primary(b2)
	_check(b2.get_theme_color(&"font_color") == UiTheme.COL_PRIMARY_TEXT, "primary: couleur de texte")
	UiTheme.destructive(b1)
	_check(b1.get_theme_stylebox(&"normal") is StyleBox, "destructive: style")
	b2.subtitle = ""
	_check(not b2._sub.visible, "sous-titre masqué")

	# hook_sounds
	UiTheme.hook_sounds(root)
	UiTheme.hook_sounds(root) # idempotent
	UiTheme.sound_log.clear()
	b1.pressed.emit()
	b1.focus_entered.emit()
	_check(Array(UiTheme.sound_log) == [&"ui.click", &"ui.hover"], "sons: click puis hover (%s)" % [UiTheme.sound_log])

	# OptionStepper
	var st := OptionStepper.new()
	st.items = PackedStringArray(["Auto", "Bas", "Moyen", "Haut"])
	root.add_child(st)
	var ev: Array = []
	st.changed.connect(func(i: int) -> void: ev.append(i))
	_check(st.custom_minimum_size.y >= 88.0, "stepper >= 88")
	st.index = 1
	_check(ev.is_empty() and st.current_text() == "Bas", "index par code sans signal")
	st._step(1)
	st._step(1)
	st._step(1) # borne : sans effet
	_check(st.index == 3 and ev == [2, 3], "stepper borné (%s)" % [ev])
	_check(st._label.text == "Haut", "stepper libellé")
	st.wrap = true
	st._step(1)
	_check(st.index == 0, "stepper wrap")

	# SafeArea
	var sa := SafeArea.new()
	root.add_child(sa)
	_check(sa.get_theme_constant(&"margin_left") >= 48 and sa.get_theme_constant(&"margin_top") >= 32, "SafeArea marges 48/32")

	# FadeLayer
	var fl := FadeLayer.new()
	add_child(fl)
	await fl.fade_out(0.05)
	_check(fl.alpha() > 0.99, "fade_out -> noir")
	await fl.fade_in(0.05)
	_check(fl.alpha() < 0.01, "fade_in -> transparent")

	# ConfirmDialog : Échap -> chosen(false)
	var d := ConfirmDialog.new()
	add_child(d)
	d.ask("Quitter ?", "Ligne", "Annuler", "Quitter").connect(_on_chosen)
	await get_tree().process_frame
	for c in d.find_children("*", "BaseButton", true, false):
		_check((c as Control).custom_minimum_size.y >= 88.0 and (c as Control).custom_minimum_size.x >= 400.0, "dialogue: bouton 400x104")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_got == [false], "ui_cancel -> chosen(false) (%s)" % [_got])
	# Destructif via bouton
	var d2 := ConfirmDialog.new()
	add_child(d2)
	d2.ask("T", "L", "N", "D").connect(_on_chosen)
	await get_tree().process_frame
	var btns := d2.find_children("*", "BaseButton", true, false)
	(btns[1] as BaseButton).pressed.emit()
	await get_tree().process_frame
	_check(_got == [false, true], "bouton destructif -> chosen(true)")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
