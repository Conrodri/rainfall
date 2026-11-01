class_name CompassPanel
extends CanvasLayer
## Panneau de la Boussole de rouille : liste courte de tags (docs/Ateliers_Chiffres.md §7), un appui choisit. Met l'arbre
## en pause (process ALWAYS) et le restaure. Souris, tactile, manette (focus + ui_accept) et clavier ; Échap / Retour ferme
## sans rien choisir (la station reste utilisable).

signal chosen(tag: String)
signal finished

const INPUT_LOCK_S := 0.3

var tags: Array = []
var _was_paused := false
var _paused_by_me := true ## faux en coop : l'arbre n'a pas été mis en pause
var _lock := true
var _closed := false
var _buttons: Array[Button] = []


func _init() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_was_paused = get_tree().paused
	_paused_by_me = ChestSession.is_blocking() # coop : jamais de pause (l'écran reste modal pour son joueur seulement)
	if _paused_by_me:
		get_tree().paused = true
	else:
		OverlayMode.enter()
	get_tree().create_timer(INPUT_LOCK_S, true, false, true).timeout.connect(func() -> void: _lock = false)


## `p_tags` : tags proposés ; `current` : RunState.compass (tag et charges actuels, rappelés dans le sous-titre).
func open(p_tags: Array, current: Dictionary = {}) -> void:
	tags = p_tags.duplicate()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 22)
	center.add_child(col)
	col.add_child(_label("BOUSSOLE DE ROUILLE", 52, Color(1, 0.92, 0.7)))
	col.add_child(_label("Les %d prochains petits ou grands coffres : la carte A portera ce tag." % Balance.BOUSSOLE_CHARGES, 30, Color(0.85, 0.85, 0.9)))
	if int(current.get("charges", 0)) > 0:
		col.add_child(_label("Charges en cours : %s ×%d (remplacées par ce choix)." % [String(current.get("tag", "")), int(current["charges"])], 26, Color(1, 0.8, 0.5)))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 24)
	col.add_child(grid)
	for t in tags:
		var b := Button.new()
		b.text = str(t)
		b.custom_minimum_size = Vector2(360, 130)
		b.add_theme_font_size_override("font_size", 44)
		b.focus_mode = Control.FOCUS_ALL
		var ring := StyleBoxFlat.new()
		ring.draw_center = false
		ring.set_border_width_all(6)
		ring.border_color = Color.WHITE
		ring.set_corner_radius_all(20)
		b.add_theme_stylebox_override("focus", ring)
		b.name = "Tag_%s" % str(t)
		b.pressed.connect(pick.bind(str(t)))
		grid.add_child(b)
		_buttons.append(b)
	var close := Button.new()
	close.text = "Fermer"
	close.custom_minimum_size = Vector2(0, 100)
	close.add_theme_font_size_override("font_size", 34)
	close.focus_mode = Control.FOCUS_ALL
	close.pressed.connect(_close)
	col.add_child(close)
	_buttons.append(close)
	if not _buttons.is_empty():
		_buttons[0].grab_focus.call_deferred()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Choisit `tag` (ignoré dans la fenêtre de verrouillage d'ouverture ou si le tag n'est pas proposé).
func pick(tag: String) -> void:
	if _lock or _closed or not (tag in tags):
		return
	chosen.emit(tag)
	_close()


func _close() -> void:
	if _closed:
		return
	_closed = true
	if _paused_by_me:
		get_tree().paused = _was_paused
	else:
		OverlayMode.leave()
	finished.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if not _closed and not _lock and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()
