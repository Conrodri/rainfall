class_name ItemPicker
extends CanvasLayer
## Panneau commun « Choisir un objet possédé » des ateliers (docs/Propositions_Boucle_Interactions.md §2.0) :
## plein écran, met le jeu en pause comme l'écran de coffre (process ALWAYS, état de pause restauré), grille de
## cartes d'objet sur 2 rangées avec défilement horizontal. Tactile (un appui), clavier-souris (clic, Entrée) et
## manette (navigation par focus, A = valider, B = retour). Le thème est celui des menus (UiTheme).
##
## Usage : var p := ItemPicker.open(host, {"title": "Fondre un objet", "entries": [...]}); p.picked.connect(...)
## cfg :
##   title, subtitle : textes d'en-tête (le sous-titre peut être vide) ;
##   entries : [{key: Variant, id: StringName, line: String, enabled: bool, reason: String, count: int}] ; `line` est
##     l'effet écrit sur la carte (« Fondre : +31 or, +1 scorie »), `reason` le refus écrit quand `enabled` est faux ;
##   multi : 0 = un appui choisit (et ferme) ; N > 0 = sélection de N cartes puis bouton de confirmation ;
##   confirm_label : texte du bouton de confirmation (multi) ;
##   validate : Callable(selected_entries: Array) -> String, raison de refus de la sélection ("" = valide) ; sert à
##     griser le bouton de confirmation en écrivant pourquoi (multi).
## Signaux : picked(entries) (les dictionnaires choisis), cancelled, closed.

signal picked(entries: Array)
signal cancelled
signal closed

const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const MARGIN := 32
const HEADER_H := 150.0 ## hauteur réservée au titre et au sous-titre
const FOOTER_H := 130.0 ## pied : état, compteur, boutons
const CARD_H_MIN := 190.0
const CARD_H_MAX := 330.0
const COL_ENABLED := Color(0.55, 0.95, 0.6)
const COL_REFUSED := Color(1.0, 0.55, 0.5)

var cfg: Dictionary = {}
var entries: Array = []
var multi := 0
var buttons: Array[Button] = [] ## une par entrée, dans l'ordre (tests)
var selected: Array[int] = []
var confirm_button: Button = null
var status_label: Label = null
var count_label: Label = null

var _was_paused := false
var _closed := false
var _title: Label
var _subtitle: Label
var _scroll: ScrollContainer
var _cols: HBoxContainer
var _card_size := Vector2(300, 240)


static func open(host: Node, p_cfg: Dictionary) -> ItemPicker:
	var p := ItemPicker.new()
	p.cfg = p_cfg
	host.add_child(p)
	p.setup()
	return p


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60


func setup() -> void:
	entries = cfg.get("entries", [])
	multi = int(cfg.get("multi", 0))
	_was_paused = get_tree().paused
	get_tree().paused = true
	_build()
	get_viewport().size_changed.connect(_relayout)
	_relayout()
	_refresh_state()
	if not buttons.is_empty():
		buttons[0].call_deferred(&"grab_focus")
	elif confirm_button != null:
		confirm_button.call_deferred(&"grab_focus")


func _exit_tree() -> void:
	if not _closed:
		get_tree().paused = _was_paused
	if get_viewport() != null and get_viewport().size_changed.is_connected(_relayout):
		get_viewport().size_changed.disconnect(_relayout)


# --- Construction --------------------------------------------------------------------------------

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var margin := MarginContainer.new()
	margin.theme = UiTheme.theme()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, MARGIN)
	add_child(margin)

	var big := PanelContainer.new()
	margin.add_child(big)
	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 20)
	big.add_child(inner)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	inner.add_child(col)

	_title = Label.new()
	_title.text = str(cfg.get("title", "Choisir un objet"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.add_theme_font_size_override("font_size", UiTheme.fsz(46))
	_title.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	col.add_child(_title)

	_subtitle = Label.new()
	_subtitle.text = str(cfg.get("subtitle", ""))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", UiTheme.fsz(UiTheme.FONT_CAPTION))
	_subtitle.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	_subtitle.visible = _subtitle.text != ""
	col.add_child(_subtitle)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_scroll)
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 14)
	_cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cols)

	if entries.is_empty():
		var empty := Label.new()
		empty.text = str(cfg.get("empty_text", "Aucun objet possédé"))
		empty.add_theme_font_size_override("font_size", UiTheme.fsz(UiTheme.FONT_BODY))
		_cols.add_child(empty)
	var column: VBoxContainer = null
	for i in entries.size():
		if i % 2 == 0:
			column = VBoxContainer.new()
			column.add_theme_constant_override("separation", 14)
			_cols.add_child(column)
		var b := _make_card(i, entries[i])
		buttons.append(b)
		column.add_child(b)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 16)
	col.add_child(foot)
	status_label = Label.new()
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", UiTheme.fsz(UiTheme.FONT_CAPTION))
	foot.add_child(status_label)
	if multi > 0:
		count_label = Label.new()
		count_label.add_theme_font_size_override("font_size", UiTheme.fsz(UiTheme.FONT_BODY))
		foot.add_child(count_label)
		confirm_button = Button.new()
		confirm_button.text = str(cfg.get("confirm_label", "Valider"))
		confirm_button.custom_minimum_size = Vector2(260, UiTheme.MIN_TOUCH)
		confirm_button.pressed.connect(confirm)
		UiTheme.primary(confirm_button)
		foot.add_child(confirm_button)
	var back := Button.new()
	back.text = "Retour"
	back.custom_minimum_size = Vector2(200, UiTheme.MIN_TOUCH)
	back.pressed.connect(cancel)
	UiTheme.mark_back(back)
	foot.add_child(back)


func _make_card(i: int, e: Dictionary) -> Button:
	var id := StringName(str(e.get("id", "")))
	var it := ItemDB.get_item(id)
	var q := StringName(str(it.get("quality", "commun")))
	var b := Button.new()
	b.name = "Card%d" % i
	b.focus_mode = Control.FOCUS_ALL
	b.clip_contents = true
	b.custom_minimum_size = _card_size
	b.pressed.connect(_on_card_pressed.bind(i))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10
	vb.offset_right = -10
	vb.offset_top = 8
	vb.offset_bottom = -8
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(0, 84)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := ITEM_ICON % id
	if ResourceLoader.exists(path):
		icon.texture = load(path) as Texture2D
	vb.add_child(icon)

	var name_l := _card_label(UiTheme.fsz(26), Palette.rarity(q) as Color)
	name_l.name = "Name"
	name_l.text = str(it.get("name", id))
	vb.add_child(name_l)
	var tag_l := _card_label(UiTheme.fsz(20), Color(0.6, 0.8, 1.0))
	tag_l.name = "Tags"
	tag_l.text = StationState.tag_line(id) + Palette.rank_suffix(q)
	vb.add_child(tag_l)
	var own := int(e.get("count", RunState.stacks(id)))
	var count_l := _card_label(UiTheme.fsz(22), Color(1, 0.85, 0.4))
	count_l.name = "Count"
	count_l.text = "×%d" % own if own > 0 else ""
	vb.add_child(count_l)
	var line_l := _card_label(UiTheme.fsz(24), COL_ENABLED)
	line_l.name = "Line"
	line_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(line_l)
	b.set_meta(&"quality", q)
	b.set_meta(&"line", line_l)
	_style_card(b, q, false, true)
	return b


func _card_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", UiTheme.COL_OUTLINE)
	l.add_theme_constant_override("outline_size", 4)
	return l


func _style_card(b: Button, q: StringName, is_selected: bool, enabled: bool) -> void:
	var rc: Color = Palette.rarity(q)
	var bg := Color(0.11, 0.10, 0.14, 0.96) if enabled else Color(0.09, 0.09, 0.1, 0.9)
	var width := 7 if is_selected else 3
	var border := rc.lerp(Color.WHITE, 0.35) if is_selected else (rc if enabled else rc.darkened(0.5))
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.lightened(0.08) if (st == "hover" or st == "pressed") else bg
		sb.set_corner_radius_all(14)
		sb.set_border_width_all(width)
		sb.border_color = border
		if st == "focus":
			sb.bg_color = bg.lightened(0.05)
			sb.border_color = UiTheme.COL_FOCUS
			sb.set_border_width_all(7)
		b.add_theme_stylebox_override(st, sb)
	b.modulate = Color.WHITE if enabled else Color(1, 1, 1, 0.62)


func _relayout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var avail_h := vp.y - 2.0 * MARGIN - 40.0 - HEADER_H - FOOTER_H
	var h := clampf(avail_h * 0.5 - 7.0, CARD_H_MIN, CARD_H_MAX)
	_card_size = Vector2(clampf(h * 1.15, 230.0, 380.0), h)
	for b in buttons:
		b.custom_minimum_size = _card_size
	if _scroll != null:
		_scroll.custom_minimum_size = Vector2(0, minf(h * 2.0 + 14.0, maxf(avail_h, CARD_H_MIN)))


# --- État ----------------------------------------------------------------------------------------

func _selected_entries() -> Array:
	var out: Array = []
	for i in selected:
		out.append(entries[i])
	return out


func _refresh_state() -> void:
	for i in buttons.size():
		var e: Dictionary = entries[i]
		var ok := bool(e.get("enabled", true))
		var line_l := buttons[i].get_meta(&"line") as Label
		line_l.text = str(e.get("line", "")) if ok else str(e.get("reason", ""))
		line_l.add_theme_color_override("font_color", COL_ENABLED if ok else COL_REFUSED)
		_style_card(buttons[i], buttons[i].get_meta(&"quality"), selected.has(i), ok)
	if multi > 0:
		count_label.text = "%d/%d" % [selected.size(), multi]
		var why := _confirm_reason()
		confirm_button.disabled = why != ""
		status_label.text = why if why != "" else str(cfg.get("ready_text", ""))
		status_label.add_theme_color_override("font_color", COL_REFUSED if why != "" else COL_ENABLED)


func _confirm_reason() -> String:
	if selected.size() != multi:
		return "Choisissez %d objets (%d/%d)" % [multi, selected.size(), multi]
	var v: Variant = cfg.get("validate")
	if v is Callable and (v as Callable).is_valid():
		return str((v as Callable).call(_selected_entries()))
	return ""


func say(msg: String, ok := false) -> void:
	if status_label != null:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", COL_ENABLED if ok else COL_REFUSED)


# --- Actions -------------------------------------------------------------------------------------

func _on_card_pressed(i: int) -> void:
	press(i)


## Appui sur la carte `i` (clic, toucher, Entrée / A). Carte refusée : la raison est écrite, rien ne se passe.
func press(i: int) -> void:
	if _closed or i < 0 or i >= entries.size():
		return
	var e: Dictionary = entries[i]
	if not bool(e.get("enabled", true)):
		say(str(e.get("reason", "Refusé")))
		return
	if multi <= 0:
		_finish([e])
		return
	if selected.has(i):
		selected.erase(i)
	elif selected.size() < multi:
		selected.append(i)
	else:
		say("Déjà %d objets choisis" % multi)
		return
	_refresh_state()


## Confirme la sélection (multi). Refusée si la sélection n'est pas valide.
func confirm() -> void:
	if _closed or multi <= 0:
		return
	var why := _confirm_reason()
	if why != "":
		say(why)
		return
	_finish(_selected_entries())


func cancel() -> void:
	if _closed:
		return
	cancelled.emit()
	_close()


func _finish(chosen: Array) -> void:
	picked.emit(chosen)
	_close()


func _close() -> void:
	if _closed:
		return
	_closed = true
	get_tree().paused = _was_paused
	closed.emit()
	queue_free()


func _input(event: InputEvent) -> void:
	if _closed:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		cancel()
