class_name ScrapPips
extends HBoxContainer
## Pastilles de scories du HUD (docs/Propositions_Boucle_Interactions.md §2.1) : une par scorie portée, teinte de
## la qualité (blanc / vert / rouge), à côté de l'or. Discrètes : rien d'affiché sans scorie. Placeholder de
## style (disques plats) en attendant l'icône de scorie rendue par Codex (art/tools/props/_ateliers.txt).
## Le rang de la qualité est aussi écrit (forme et lettre) pour le mode daltonien : B / V / R.

const PIP_PX := 26.0
const LETTERS := {&"commun": "B", &"peu_commun": "V", &"rare": "R"}

var ui_scale := 1.0


func _init() -> void:
	name = "ScrapPips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 4)
	visible = false


func _ready() -> void:
	RunState.scrap_changed.connect(refresh)
	refresh()


func set_ui_scale(s: float) -> void:
	ui_scale = s
	refresh()


func refresh() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var px := PIP_PX * ui_scale
	for q in StationState.QUALITY_ORDER:
		for i in RunState.scrap_of(q):
			add_child(_pip(q, px))
	visible = get_child_count() > 0
	tooltip_text = ""
	reset_size()


func _pip(q: StringName, px: float) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = StationState.SCRAP_COLORS.get(q, Color.WHITE)
	sb.set_corner_radius_all(int(px * 0.5))
	sb.set_border_width_all(2)
	sb.border_color = Color(0.06, 0.05, 0.08, 0.9)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = String(LETTERS.get(q, ""))
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", int(px * 0.55))
	l.add_theme_color_override("font_color", Color(0.08, 0.07, 0.1))
	p.add_child(l)
	return p
