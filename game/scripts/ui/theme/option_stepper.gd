class_name OptionStepper
extends HBoxContainer
## Sélecteur « ‹ valeur › » §3.4 : 88 px de haut, gauche/droite au clavier et à la manette,
## flèches cliquables en tactile/souris. Le stepper porte le focus (les flèches ne le prennent pas).

signal changed(index: int)

## Libellés des valeurs.
@export var items: PackedStringArray = PackedStringArray():
	set(v):
		items = v
		index = index # re-clamp
		_refresh()
## Passe de la dernière valeur à la première (et inversement).
@export var wrap := false
## Valeur courante ; l'affectation par code n'émet pas `changed` (seules les actions du joueur l'émettent).
@export var index := 0:
	set(v):
		index = clampi(v, 0, maxi(items.size() - 1, 0))
		_refresh()

var _left: Button
var _right: Button
var _label: Label


func _init() -> void:
	custom_minimum_size = Vector2(560, 88)
	focus_mode = Control.FOCUS_ALL
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 8)


func _ready() -> void:
	_left = _arrow("‹", -1)
	add_child(_left)
	_label = Label.new()
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_right = _arrow("›", 1)
	add_child(_right)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_refresh()


func _arrow(txt: String, dir: int) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(88, 88)
	b.pressed.connect(_step.bind(dir))
	return b


func current_text() -> String:
	return items[index] if index < items.size() else ""


func _refresh() -> void:
	if _label == null:
		return
	_label.text = current_text()
	var multi := items.size() > 1
	_left.disabled = not multi or (not wrap and index <= 0)
	_right.disabled = not multi or (not wrap and index >= items.size() - 1)


func _step(dir: int) -> void:
	if items.size() < 2:
		return
	var n := index + dir
	if wrap:
		n = posmod(n, items.size())
	else:
		n = clampi(n, 0, items.size() - 1)
	if n == index:
		return
	index = n
	UiTheme._play(&"ui.click")
	changed.emit(index)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		_step(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		_step(1)
		accept_event()


func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, size))
