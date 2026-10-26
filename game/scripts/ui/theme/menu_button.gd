class_name MenuBtn
extends Button
## Bouton de menu §2.1 : 620×104 par défaut, libellé 44 px, sous-titre optionnel (26 px) sous le libellé.
## UiTheme.primary(btn) donne le style principal (prévoir alors custom_minimum_size 720×120).

@export var subtitle: String = "":
	set(v):
		subtitle = v
		if is_node_ready():
			refresh_subtitle()

const SUB_GAP := 4.0 ## écart entre libellé et sous-titre (px)
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
		add_child(_sub)
	_sub.text = subtitle
	_sub.visible = subtitle != ""
	_update_sub_alpha()
	# Remonte le libellé pour faire de la place au sous-titre : tout est dérivé des métriques réelles de la police
	# (trait du cadre + marge d'encre de chaque côté, deux lignes, petit écart entre elles).
	var fnt := get_theme_font(&"font")
	var sub_fs := UiTheme.FONT_CAPTION
	var sub_h := UiTheme.line_height(fnt, sub_fs)
	var sb0 := get_theme_stylebox(&"normal")
	var edge_pad := UiTheme.v_margin(sb0, sub_fs)
	_sub.offset_bottom = -edge_pad
	_sub.offset_top = 0.0
	for k in [&"normal", &"hover", &"pressed", &"disabled"]:
		var sb := get_theme_stylebox(k)
		if sb == null:
			continue
		var d := sb.duplicate() as StyleBox
		d.content_margin_bottom = (edge_pad + sub_h + SUB_GAP) if subtitle != "" else maxf(d.content_margin_bottom, UiTheme.v_margin(d, get_theme_font_size(&"font_size")))
		add_theme_stylebox_override(k, d)
	if subtitle != "":
		var main_h := UiTheme.line_height(fnt, get_theme_font_size(&"font_size"))
		var top := UiTheme.v_margin(sb0, get_theme_font_size(&"font_size"))
		custom_minimum_size.y = maxf(custom_minimum_size.y, ceilf(top + main_h + SUB_GAP + sub_h + edge_pad))


func _update_sub_alpha() -> void:
	if _sub != null:
		_sub.modulate = Color(1, 1, 1, 0.45 if disabled else 0.85)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED or what == NOTIFICATION_ENABLED:
		_update_sub_alpha()
