class_name SpellTooltip
extends PanelContainer
## Infobulle d'un sort ou d'une variante (Nouvelle run, §3.2 MISE À JOUR).
## Variante verrouillée : « Quête de déblocage » + texte de quête ; débloquée : sa description.
## Ouverte au survol souris, au focus clavier/manette et à l'appui long tactile (character_sheet.gd).

const WIDTH := 520.0
const COL_LOCK := Color("#FFB347")

## Arbitre des bulles du HUD (audit H5) : une seule bulle visible à la fois.
## Priorité 1 = bulle demandée par le joueur (SpellHint : survol / appui long ; infobulle d'item d'ItemBar) ;
## priorité 2 = tutoriel (AvarePurseTip), qui se masque et fige son minuteur tant qu'une bulle P1 est ouverte.
## Chaque P1 déclare son état avec set_user_bubble(source, ouverte) ; les P1 entre elles : la première ouverte garde la main.
static var _user_sources := {} ## source (StringName) -> true

static func set_user_bubble(source: StringName, open: bool) -> void:
	if open:
		_user_sources[source] = true
	else:
		_user_sources.erase(source)


## Vrai si une bulle P1 est ouverte (le tutoriel doit s'effacer).
static func user_bubble_open() -> bool:
	return not _user_sources.is_empty()


## Vrai si une bulle P1 autre que `source` est déjà ouverte (cette source doit alors s'abstenir).
static func other_user_bubble_open(source: StringName) -> bool:
	for k in _user_sources:
		if k != source:
			return true
	return false


var anchor_control: Control
## Zone à ne jamais recouvrir (ex. aperçu animé des sorts) : la bulle se pose près du contrôle, décalée hors de cette zone.
var avoid: Control
var _width := WIDTH
var _title: Label
var _tag: Label
var _body: Label


func _init() -> void:
	top_level = true
	visible = false
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, 0)
	add_theme_stylebox_override("panel", CharacterCard.panel_box(Color("#1a1620"), Color("#FFB347"), 2, 1.0, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = CharacterCard.make_label("", 32)
	v.add_child(_title)
	_tag = CharacterCard.make_label("", 26, COL_LOCK)
	v.add_child(_tag)
	_body = CharacterCard.make_label("", 26, Color(0.92, 0.92, 0.95))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(WIDTH - 32, 0)
	v.add_child(_body)


## Affiche l'infobulle au-dessus (ou au-dessous) de `ctrl`, bornée à l'écran.
func show_for(ctrl: Control, title: String, tag: String, body: String, avoid_ctrl: Control = null) -> void:
	anchor_control = ctrl
	avoid = avoid_ctrl
	var w := _width
	if avoid != null and is_instance_valid(avoid) and avoid.is_inside_tree():
		var room := get_viewport().get_visible_rect().end.x - avoid.get_global_rect().end.x - 28.0
		w = clampf(room, minf(320.0, _width), _width)
	custom_minimum_size = Vector2(w, 0)
	_body.custom_minimum_size = Vector2(w - 32.0, 0)
	_title.text = title
	_tag.text = tag
	_tag.visible = tag != ""
	_body.text = body
	reset_size()
	visible = true
	_place.call_deferred()


func hide_tip(for_ctrl: Control = null) -> void:
	if for_ctrl != null and for_ctrl != anchor_control:
		return
	visible = false
	anchor_control = null
	avoid = null


## Tailles de texte et largeur (HUD tactile : plus grand). Défaut : 32 / 26 / 26, WIDTH.
func set_text_sizes(title_px: int, tag_px: int, body_px: int, width := WIDTH) -> void:
	_title.add_theme_font_size_override("font_size", title_px)
	_tag.add_theme_font_size_override("font_size", tag_px)
	_body.add_theme_font_size_override("font_size", body_px)
	_width = width
	custom_minimum_size = Vector2(width, 0)
	_body.custom_minimum_size = Vector2(width - 32, 0)


func text_content() -> String:
	return "%s\n%s\n%s" % [_title.text, _tag.text, _body.text]


func _place() -> void:
	if anchor_control == null or not is_instance_valid(anchor_control) or not is_inside_tree():
		return
	reset_size()
	var vis := get_viewport().get_visible_rect()
	var r := anchor_control.get_global_rect()
	var sz := get_combined_minimum_size()
	size = sz
	var pos := Vector2(r.get_center().x - sz.x * 0.5, r.position.y - sz.y - 12)
	if pos.y < vis.position.y + 16:
		pos.y = r.end.y + 12
	pos.x = clampf(pos.x, vis.position.x + 16, vis.end.x - sz.x - 16)
	pos.y = clampf(pos.y, vis.position.y + 16, vis.end.y - sz.y - 16)
	if avoid != null and is_instance_valid(avoid) and avoid.is_inside_tree():
		var ar := avoid.get_global_rect()
		if Rect2(pos, sz).intersects(ar):
			if ar.get_center().x <= vis.get_center().x:
				pos.x = ar.end.x + 12.0 # zone à gauche : la bulle passe à sa droite
			else:
				pos.x = ar.position.x - sz.x - 12.0
			pos.x = clampf(pos.x, vis.position.x + 16, vis.end.x - sz.x - 16)
			if Rect2(pos, sz).intersects(ar): # ultime recours : sous ou au-dessus de la zone
				pos.y = ar.end.y + 12.0 if ar.end.y + 12.0 + sz.y <= vis.end.y - 16 else ar.position.y - sz.y - 12.0
	global_position = pos
