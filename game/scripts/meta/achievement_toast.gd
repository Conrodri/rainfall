class_name AchievementToast
extends CanvasLayer
## Notification discrète (succès débloqué, récompense du défi du jour) : petit bandeau en haut au centre, 3 s, file
## d'attente, ne capte aucune entrée. Hébergé par MetaTracker (App), donc visible en jeu comme dans les menus.
## Pas de flash ni de pulsation : un fondu simple.

const LAYER := 12 ## au-dessus du HUD (10) et des invites (11), sous la pause (100)
const SHOW_S := 3.2
const FADE_S := 0.3
const ICON_PX := 64.0
const WIDTH := 560.0

var panel: PanelContainer
var icon: TextureRect
var title_label: Label
var text_label: Label
var current := {} ## {title, text, icon} affiché ("" : aucun)

var _queue: Array = []
var _left := 0.0
var _root: Control


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS # visible aussi pendant la pause / le récap


func _ready() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(WIDTH, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.102, 0.086, 0.125, 0.92)
	sb.border_color = Color("#FFB347")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 16
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override(&"panel", sb)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override(&"separation", 14)
	panel.add_child(h)
	icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_PX, ICON_PX)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(icon)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 2)
	h.add_child(v)
	title_label = _label(26, Color("#FFB347"))
	v.add_child(title_label)
	text_label = _label(22, Color("#F2EEE6"))
	v.add_child(text_label)
	panel.visible = false
	panel.modulate.a = 0.0
	_root.add_child(panel)
	_root.resized.connect(_place)


func _label(size: int, col: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", col)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override(&"outline_size", 3)
	l.clip_text = true
	l.custom_minimum_size.x = 120.0
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## Met une notification en file. `tex` peut être null.
func push(title: String, text: String, tex: Texture2D = null) -> void:
	_queue.append({"title": title, "text": text, "icon": tex})


func pending() -> int:
	return _queue.size()


func _process(delta: float) -> void:
	if current.is_empty():
		if not _queue.is_empty() and panel != null:
			_show(_queue.pop_front())
		return
	_left -= delta
	panel.modulate.a = clampf(minf(_left, SHOW_S - _left) / FADE_S, 0.0, 1.0)
	if _left <= 0.0:
		current = {}
		panel.visible = false


func _show(n: Dictionary) -> void:
	current = n
	_left = SHOW_S
	title_label.text = str(n["title"])
	text_label.text = str(n["text"])
	text_label.visible = text_label.text != ""
	icon.texture = n["icon"] as Texture2D
	icon.visible = icon.texture != null
	panel.visible = true
	panel.modulate.a = 0.0
	panel.reset_size()
	_place()


## Haut au centre, sous la plaque du temps (la minimap occupe le haut à droite), dans la zone sûre.
func _place() -> void:
	if panel == null or _root == null:
		return
	var m: Dictionary = Platform.safe_margins()
	panel.size = panel.get_combined_minimum_size()
	panel.position = Vector2((_root.size.x - panel.size.x) * 0.5, float(m.get("top", 32.0)) + 120.0)
