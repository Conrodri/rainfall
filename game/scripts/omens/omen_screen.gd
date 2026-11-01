class_name OmenScreen
extends CanvasLayer
## Écran d'arrivée « Présage » (étages 2 à 5, docs/Propositions_Boucle_Interactions.md §3.1) : deux cartes (un présage de
## combat, un présage de butin, chacun avec sa contrainte et sa compensation) et, hors Difficile, une troisième « Ciel clair »
## (aucun présage). En Difficile le choix est obligatoire : pas de troisième carte. Posé par Main après le carton d'étage,
## jeu en pause (process ALWAYS). Un choix émet `chosen(id)`.
##
## Entrées : toucher et souris (cartes de grande taille, jamais sous MIN_TOUCH), clavier et manette (focus gauche / droite,
## valider = ui_accept). Mise en page par fractions du viewport : paysage adaptatif, aucune position codée en dur.
## Icônes : Omens.icon_of (lot Codex attendu, icônes d'objets proches en attendant).

signal chosen(id: StringName)

const LAYER := 135 ## au-dessus du HUD, sous le carton d'étage (140)
const INPUT_DELAY_S := 0.45 ## un toucher qui vient de fermer le carton d'étage ne choisit pas

var stage_n := 2
var offer: Array[Dictionary] = []
var mandatory := false

var _root: Control
var _title: Label
var _sub: Label
var _row: HBoxContainer
var _cards: Array[Button] = []
var _ids: Array[StringName] = []
var _texts: Array[Label] = []
var _names: Array[Label] = []
var _tags: Array[Label] = []
var _icons: Array[TextureRect] = []
var _t := 0.0
var _done := false


## Écran pour l'étage `n` ; `cards` : entrées Omens.offer() ; `must_pick` : Difficile (aucune carte neutre).
static func create(n: int, cards: Array[Dictionary], must_pick: bool) -> OmenScreen:
	var s := OmenScreen.new()
	s.stage_n = n
	s.offer = cards
	s.mandatory = must_pick
	return s


func _init() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	name = &"OmenScreen"


func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	_title = _label(box, "ÉTAGE %d · PRÉSAGE" % stage_n, UiTheme.COL_PRIMARY_TEXT)
	_title.add_theme_font_override("font", UiTheme.title_font())
	_sub = _label(box, "Choisissez une contrainte et sa compensation. Elles durent jusqu'au téléporteur." if not mandatory
		else "Choix obligatoire : une contrainte et sa compensation, jusqu'au téléporteur.", UiTheme.COL_MUTED)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_row)
	for e in offer:
		_add_card(e)
	for i in _cards.size():
		var b := _cards[i]
		b.focus_neighbor_left = b.get_path_to(_cards[(i - 1 + _cards.size()) % _cards.size()])
		b.focus_neighbor_right = b.get_path_to(_cards[(i + 1) % _cards.size()])
	UiTheme.apply(_root)
	UiTheme.hook_sounds(_root)
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	if not _cards.is_empty() and Platform.input_mode != Platform.InputMode.TOUCH:
		_cards[0].grab_focus.call_deferred()


func _label(parent: Control, text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", UiTheme.COL_OUTLINE)
	l.add_theme_constant_override("outline_size", 8)
	parent.add_child(l)
	return l


func _add_card(e: Dictionary) -> void:
	var id := StringName(str(e.get("id", "")))
	var group := StringName(str(e.get("group", "")))
	var clear := id == Balance.OMEN_CLEAR_ID
	var b := Button.new()
	b.name = "Card_%s" % id
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	b.add_child(margin)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	var tag := _label(v, "NEUTRE" if clear else String(Omens.GROUP_NAMES.get(group, "")),
		UiTheme.COL_MUTED if clear else (Color(1.0, 0.55, 0.4) if group == &"combat" else Color(1.0, 0.85, 0.35)))
	var icon := TextureRect.new()
	icon.texture = Omens.icon_of(id)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var nm := _label(v, str(e.get("name", "")), UiTheme.COL_PRIMARY_TEXT)
	var tx := _label(v, str(e.get("text", "")), UiTheme.COL_TEXT)
	b.pressed.connect(func() -> void: _pick(id))
	_row.add_child(b)
	_cards.append(b)
	_ids.append(id)
	_tags.append(tag)
	_icons.append(icon)
	_names.append(nm)
	_texts.append(tx)


func _apply_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := clampf(minf(vp.x, vp.y) / 1080.0, 0.55, 1.0)
	var n := maxi(_cards.size(), 1)
	var gap := 28.0 * s
	var card_w := minf(540.0 * s, (vp.x * 0.92 - gap * (n - 1)) / n)
	var k := clampf(card_w / (540.0 * s), 0.6, 1.0) * s # taille de police suit la largeur de carte
	var card_h := maxf(minf(620.0 * s, vp.y * 0.62), UiTheme.MIN_TOUCH * 2.0)
	_row.add_theme_constant_override("separation", int(gap))
	(_title.get_parent() as VBoxContainer).add_theme_constant_override("separation", int(24 * s))
	_title.add_theme_font_size_override("font_size", int(64 * s))
	_title.custom_minimum_size.x = vp.x * 0.9
	_sub.add_theme_font_size_override("font_size", int(30 * s))
	_sub.custom_minimum_size.x = minf(1100.0 * s, vp.x * 0.9)
	var icon_px := clampf(card_h * 0.2, 72.0, 160.0 * s)
	for i in _cards.size():
		_cards[i].custom_minimum_size = Vector2(card_w, card_h)
		_tags[i].add_theme_font_size_override("font_size", int(26 * k))
		_icons[i].custom_minimum_size = Vector2(icon_px, icon_px)
		_names[i].add_theme_font_size_override("font_size", int(46 * k))
		_texts[i].add_theme_font_size_override("font_size", int(32 * k))
		_names[i].custom_minimum_size.x = card_w - 36.0
		_texts[i].custom_minimum_size.x = card_w - 36.0


func _process(delta: float) -> void:
	_t += delta


func _input(ev: InputEvent) -> void:
	# la pause (Échap, Start) ne doit pas ouvrir le menu pause par-dessus ce choix
	if _done or not ev.is_action_pressed(&"pause"):
		return
	get_viewport().set_input_as_handled()


func _pick(id: StringName) -> void:
	if _done or _t < INPUT_DELAY_S:
		return
	_done = true
	chosen.emit(id)


# --- Accès pour les tests ----------------------------------------------------------------------

## Identifiants des cartes, dans l'ordre d'affichage.
func card_ids() -> Array[StringName]:
	return _ids


## Choisit la carte `index` sans attendre le délai d'entrée (tests, automatisation).
func choose(index: int) -> void:
	if index < 0 or index >= _ids.size() or _done:
		return
	_done = true
	chosen.emit(_ids[index])


func card_button(index: int) -> Button:
	return _cards[index] if index >= 0 and index < _cards.size() else null


func card_text(index: int) -> String:
	return "%s | %s | %s" % [_tags[index].text, _names[index].text, _texts[index].text] if index >= 0 and index < _cards.size() else ""
