class_name OmenBadge
extends PanelContainer
## Rappel discret du présage actif dans le HUD (docs/Propositions_Boucle_Interactions.md §3.1) : icône + nom, sous la
## difficulté, avant le panneau d'objectifs. Le détail (contrainte + compensation) s'ouvre :
##  - souris (PC) : au survol ; infobulle système aussi ;
##  - tactile : au toucher (la zone ne capte les touches qu'en mode tactile, comme PassiveBadge) ;
##  - manette / clavier : ouvert automatiquement OPEN_ON_CHOICE_S après le choix, puis replié.
## Caché sans présage actif (aussi après « Ciel clair »). Le HUD le place (place()) et lui donne l'échelle (set_ui_scale()).

const OPEN_ON_CHOICE_S := 6.0
const OPEN_ON_TAP_S := 5.0
const BASE_WIDTH := 460.0
const MIN_WIDTH := 300.0

var ui_scale := 1.0
var omen_id: StringName = &""

var _icon: TextureRect
var _name: Label
var _detail: Label
var _style: StyleBoxFlat
var _open_left := 0.0
var _hover := false


func _init() -> void:
	name = &"OmenBadge"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_PASS
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.03, 0.05, 0.09, 0.62)
	_style.border_color = Color(1.0, 0.78, 0.35, 0.35)
	_style.set_border_width_all(1)
	_style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel", _style)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_icon)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_name = _label(col)
	_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_detail = _label(col)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_color_override("font_color", Color(0.93, 0.95, 1.0))
	_detail.visible = false
	mouse_entered.connect(func() -> void: _hover = true; _apply_open())
	mouse_exited.connect(func() -> void: _hover = false; _apply_open())
	set_ui_scale(1.0)


static func _label(parent: Control) -> Label:
	var l := Label.new()
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func set_ui_scale(s: float) -> void:
	ui_scale = s
	_style.content_margin_left = 12.0 * s
	_style.content_margin_right = 14.0 * s
	_style.content_margin_top = 6.0 * s
	_style.content_margin_bottom = 6.0 * s
	_icon.custom_minimum_size = Vector2(48, 48) * s
	_name.add_theme_font_size_override("font_size", int(26 * s))
	_detail.add_theme_font_size_override("font_size", int(24 * s))
	(_icon.get_parent() as HBoxContainer).add_theme_constant_override("separation", int(12 * s))


## Tactile : seul mode où le badge capte les touches (la souris reste libre de viser ailleurs).
func sync_input_mode() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if Platform.input_mode == Platform.InputMode.TOUCH else Control.MOUSE_FILTER_PASS


## Relit RunState.omen. `announce` : déplie le détail quelques secondes (choix qui vient d'être fait).
func refresh(announce := false) -> void:
	omen_id = RunState.omen
	var active := Omens.is_active()
	visible = active
	if not active:
		_open_left = 0.0
		return
	var e := Omens.get_omen(omen_id)
	_name.text = str(e.get("name", ""))
	_detail.text = str(e.get("text", ""))
	_icon.texture = Omens.icon_of(omen_id)
	_icon.visible = _icon.texture != null
	tooltip_text = Omens.tooltip(omen_id)
	_open_left = OPEN_ON_CHOICE_S if announce else 0.0
	_apply_open()


func is_open() -> bool:
	return _detail.visible


func detail_text() -> String:
	return _detail.text


func name_text() -> String:
	return _name.text


## Coin haut-droit en `top_right` (px du viewport), largeur bornée par `max_width`.
func place(top_right: Vector2, max_width: float) -> void:
	var w := clampf(BASE_WIDTH * ui_scale, minf(MIN_WIDTH * ui_scale, max_width), max_width)
	custom_minimum_size.x = 0.0
	_detail.custom_minimum_size.x = maxf(w - (80.0 * ui_scale), 120.0)
	size = Vector2(w, 0.0)
	custom_minimum_size.x = w
	position = Vector2(top_right.x - w, top_right.y)


func _apply_open() -> void:
	_detail.visible = visible and (_hover or _open_left > 0.0)
	reset_size()


func _process(delta: float) -> void:
	if _open_left > 0.0:
		_open_left -= delta
		if _open_left <= 0.0:
			_apply_open()


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	var press := false
	if event is InputEventScreenTouch:
		press = (event as InputEventScreenTouch).pressed
	elif event is InputEventMouseButton:
		press = (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and Platform.input_mode == Platform.InputMode.TOUCH
	if press:
		_open_left = 0.0 if _detail.visible and not _hover else OPEN_ON_TAP_S
		_apply_open()
		accept_event()
