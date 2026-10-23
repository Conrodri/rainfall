class_name RunScreens
extends CanvasLayer
## Écrans plein écran de la scène de jeu (process ALWAYS, au-dessus du HUD et du menu pause) :
## chargement, choix de fin d'étage 3 (Terminer / Continuer en sans fin), fin de run (rubis, Rejouer).
## Mise en page à ancrages, taille de police selon le petit côté du viewport (portrait et paysage).
## Placeholders d'interface : à habiller avec les éléments d'UI rendus dans Blender.

const LAYER_LOADING := 120
const LAYER_SCREENS := 110

var _root: Control
var _box: VBoxContainer
var _labels: Array[Label] = [] ## [titre, lignes…]
var _buttons: Array[Button] = []


static func loading(text: String = "Chargement…") -> RunScreens:
	var s := RunScreens.new()
	s.layer = LAYER_LOADING
	s.name = &"LoadingScreen"
	s._setup(text, [], [], Color(0.02, 0.03, 0.05, 1.0))
	return s


## buttons : Array de [texte: String, action: Callable].
static func dialog(title: String, lines: Array, buttons: Array, dim := 0.75) -> RunScreens:
	var s := RunScreens.new()
	s.layer = LAYER_SCREENS
	s._setup(title, lines, buttons, Color(0, 0, 0, dim))
	return s


func _setup(title: String, lines: Array, buttons: Array, bg: Color) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = bg
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	if buttons.is_empty():
		center.add_child(_box) # écran de chargement : texte seul
	else:
		var panel := PanelContainer.new() # dialogue : cadre du thème du jeu
		panel.theme_type_variation = &"SmallPanel"
		center.add_child(panel)
		panel.add_child(_box)
	_add_label(title)
	for l in lines:
		_add_label(str(l))
	for b in buttons:
		var btn := Button.new()
		btn.text = String(b[0])
		btn.pressed.connect(b[1])
		_box.add_child(btn)
		_buttons.append(btn)
	# Premier bouton = action principale (cadre orange), les suivants = secondaires (cadre du thème).
	if not _buttons.is_empty():
		UiTheme.primary(_buttons[0])
		for i in range(1, _buttons.size()):
			_buttons[i].focus_neighbor_top = _buttons[i].get_path_to(_buttons[i - 1])
			_buttons[i - 1].focus_neighbor_bottom = _buttons[i - 1].get_path_to(_buttons[i])
	UiTheme.apply(_root)
	UiTheme.hook_sounds(_root)


func _ready() -> void:
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	if not _buttons.is_empty() and Platform.input_mode != Platform.InputMode.TOUCH:
		_buttons[0].grab_focus.call_deferred()


func _add_label(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_outline_color", UiTheme.COL_OUTLINE)
	l.add_theme_color_override("font_color", UiTheme.COL_PRIMARY_TEXT if _labels.is_empty() else UiTheme.COL_TEXT)
	l.add_theme_constant_override("outline_size", 8)
	_box.add_child(l)
	_labels.append(l)


func _apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := clampf(minf(vp.x, vp.y) / 1080.0, 0.55, 1.0)
	_box.add_theme_constant_override("separation", int(26 * s))
	var w := minf(760.0 * s, vp.x * 0.8)
	for i in _labels.size():
		_labels[i].custom_minimum_size.x = w
		_labels[i].add_theme_font_size_override("font_size", int((72 if i == 0 else 40) * s))
	for i in _buttons.size():
		var b := _buttons[i]
		# principal 720×120, secondaire 620×100 (jamais sous la cible tactile de 88 px)
		var base := Vector2(720, 120) if i == 0 else Vector2(620, 100)
		b.custom_minimum_size = Vector2(minf(base.x * s, vp.x * 0.85), maxf(base.y * s, UiTheme.MIN_TOUCH))
		b.add_theme_font_size_override("font_size", int(UiTheme.FONT_BUTTON * s))


## Libellés et boutons (tests).
func texts() -> Array:
	var out: Array = []
	for l in _labels:
		out.append(l.text)
	return out


func press(index: int) -> void:
	if index >= 0 and index < _buttons.size():
		_buttons[index].pressed.emit()
