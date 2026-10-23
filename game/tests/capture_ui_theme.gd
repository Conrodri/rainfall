extends Node
## Galerie des composants du lot A.
## PC     : godot --path game --write-movie <dossier>/pc.png --fixed-fps 30 --quit-after 40 res://tests/capture_ui_theme.tscn
## Mobile : idem avec `-- --mobile`.
## Images 0-19 : galerie ; dès l'image 20 : dialogue de confirmation par-dessus.

var _frame := 0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1b2a38")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var ui := Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ui)
	UiTheme.apply(ui)
	var sa := SafeArea.new()
	sa.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(sa)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 20)
	sa.add_child(col)

	var title := Label.new()
	title.text = "Composants UI"
	title.add_theme_font_size_override(&"font_size", UiTheme.FONT_TITLE)
	col.add_child(title)

	var row1 := HBoxContainer.new()
	col.add_child(row1)
	var b1 := MenuBtn.new()
	b1.text = "Normal"
	row1.add_child(b1)
	var b2 := MenuBtn.new()
	b2.text = "Reprendre"
	b2.subtitle = "Ardent · Étage 2 · Moyen · 04:12"
	b2.custom_minimum_size = Vector2(720, 120)
	row1.add_child(b2)
	UiTheme.primary(b2)

	var row2 := HBoxContainer.new()
	col.add_child(row2)
	var b3 := MenuBtn.new()
	b3.text = "Désactivé"
	b3.subtitle = "Aucune run sauvegardée"
	b3.disabled = true
	row2.add_child(b3)
	var b4 := MenuBtn.new()
	b4.text = "Focus clavier"
	row2.add_child(b4)
	var b5 := MenuBtn.new()
	b5.text = "Abandonner"
	b5.custom_minimum_size = Vector2(400, 104)
	row2.add_child(b5)
	UiTheme.destructive(b5)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override(&"separation", 40)
	col.add_child(row3)
	var st := OptionStepper.new()
	st.items = PackedStringArray(["Automatique", "Bas", "Moyen", "Haut"])
	st.index = 2
	row3.add_child(st)
	var sl := HSlider.new()
	sl.custom_minimum_size = Vector2(520, 88)
	sl.value = 70
	row3.add_child(sl)
	var tg := CheckButton.new()
	tg.text = "Plein écran"
	tg.button_pressed = true
	row3.add_child(tg)

	var cap := Label.new()
	cap.text = "Légende 26 px · le texte reste lisible sur fond animé"
	cap.add_theme_font_size_override(&"font_size", UiTheme.FONT_CAPTION)
	col.add_child(cap)

	UiTheme.apply(ui)
	UiTheme.hook_sounds(ui)
	if not Platform.is_touch_mode():
		b4.grab_focus.call_deferred()


func _process(_d: float) -> void:
	_frame += 1
	if _frame == 20:
		var d := ConfirmDialog.new()
		add_child(d)
		d.ask("Remplacer la run en cours ?", "Ardent · Étage 2 · 04:12 sera perdue (les rubis déjà gagnés sont conservés).", "Annuler", "Remplacer")
