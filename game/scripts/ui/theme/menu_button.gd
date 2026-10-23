class_name MenuBtn
extends Button
## Bouton de menu §2.1 : 620×104 par défaut, libellé 44 px, sous-titre optionnel (26 px) sous le libellé.
## UiTheme.primary(btn) donne le style principal (prévoir alors custom_minimum_size 720×120).

@export var subtitle: String = "":
	set(v):
		subtitle = v
		if is_node_ready():
			refresh_subtitle()

var _sub: Label = null


func _init() -> void:
	custom_minimum_size = Vector2(620, 104)
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	refresh_subtitle()


func refresh_subtitle() -> void:
	if not is_node_ready():
		return
	if _sub == null:
		_sub = Label.new()
		_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_sub.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_sub.add_theme_font_size_override(&"font_size", UiTheme.FONT_CAPTION)
		_sub.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_sub.offset_bottom = -10
		add_child(_sub)
	_sub.text = subtitle
	_sub.visible = subtitle != ""
	_update_sub_alpha()
	# Remonte le libellé pour faire de la place au sous-titre.
	for k in [&"normal", &"hover", &"pressed", &"disabled"]:
		var sb := get_theme_stylebox(k)
		if sb == null:
			continue
		var d := sb.duplicate() as StyleBox
		d.content_margin_bottom = 40.0 if subtitle != "" else 12.0
		add_theme_stylebox_override(k, d)


func _update_sub_alpha() -> void:
	if _sub != null:
		_sub.modulate = Color(1, 1, 1, 0.45 if disabled else 0.85)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED or what == NOTIFICATION_ENABLED:
		_update_sub_alpha()
