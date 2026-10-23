class_name ConfirmDialog
extends CanvasLayer
## Dialogue de confirmation §3.7 : voile noir 70 %, cadre 900×420, deux boutons 400×104.
## Neutre à gauche (focus initial, aussi Échap/B), destructif à droite.
## Usage : var d := ConfirmDialog.new(); add_child(d); var destructive: bool = await d.ask(...)
## `ask` renvoie le signal `chosen(destructive: bool)` ; le dialogue se libère après le choix.

signal chosen(destructive: bool)

var _done := false
var _neutral: Button
var _destructive: Button


func _init() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS


func ask(title: String, line: String, neutral_text: String, destructive_text: String) -> Signal:
	_build(title, line, neutral_text, destructive_text)
	if is_inside_tree():
		_focus_neutral()
	else:
		tree_entered.connect(_focus_neutral, CONNECT_ONE_SHOT)
	return chosen


func _build(title: String, line: String, neutral_text: String, destructive_text: String) -> void:
	for c in get_children():
		c.queue_free()
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	UiTheme.apply(root)

	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.7)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(veil)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	# fenêtre PC très petite : le cadre et les boutons rétrécissent pour rester dans la vue
	var vw := root.get_viewport_rect().size.x if root.is_inside_tree() else 1920.0
	var pw := minf(900.0, vw - 96.0)
	var bw := minf(400.0, (pw - 40.0 - 48.0) * 0.5)
	panel.custom_minimum_size = Vector2(pw, 420)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 24)
	panel.add_child(box)

	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override(&"font_size", 48)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)

	var l := Label.new()
	l.text = line
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(l)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 40)
	box.add_child(row)

	_neutral = MenuBtn.new()
	_neutral.text = neutral_text
	_neutral.custom_minimum_size = Vector2(bw, 104)
	_neutral.pressed.connect(_finish.bind(false))
	row.add_child(_neutral)
	UiTheme.mark_back(_neutral)

	_destructive = MenuBtn.new()
	_destructive.text = destructive_text
	_destructive.custom_minimum_size = Vector2(bw, 104)
	_destructive.pressed.connect(_finish.bind(true))
	row.add_child(_destructive)
	UiTheme.destructive(_destructive)

	_neutral.focus_neighbor_right = _neutral.get_path_to(_destructive)
	_destructive.focus_neighbor_left = _destructive.get_path_to(_neutral)
	UiTheme.hook_sounds(root)


func _focus_neutral() -> void:
	if _neutral != null and not Platform.is_touch_mode():
		_neutral.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _done or _neutral == null:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish(false)


func _finish(destructive: bool) -> void:
	if _done:
		return
	_done = true
	chosen.emit(destructive)
	queue_free.call_deferred()
