class_name BestRunsPanel
extends Control
## Panneau modal « Meilleures runs » d'un personnage (écran Progression, clic / toucher / A sur sa carte) :
## trois colonnes Facile / Moyen / Difficile = la victoire la plus courte (temps pour abattre le boss final), avec
## date, niveau atteint, monstres tués, objets (icônes + exemplaires) et variantes de sorts utilisées.
## « Aucune victoire » sinon. Données : `Profile.best_run(perso, mode)` (ou `best_runs` d'un profil injecté).
## Fermeture : bouton « Fermer », Échap / B (ui_cancel), clic hors de la feuille. Aucune position codée en dur.

signal closed

const MODES: Array[StringName] = [&"facile", &"moyen", &"difficile"]
const MODE_NAMES := {&"facile": "Facile", &"moyen": "Moyen", &"difficile": "Difficile"}
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_TIME := Color("#FFE9A8")
const ICON := 56.0

var character: Dictionary = {}
var profile: Object = null
var close_button: Button
var columns: Array[Control] = [] ## une par mode, dans l'ordre MODES

var _sheet: PanelContainer


static func create(c: Dictionary, p: Object) -> BestRunsPanel:
	var bp := BestRunsPanel.new()
	bp.character = c
	bp.profile = p
	return bp


func _ready() -> void:
	name = "BestRunsPanel"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(_on_dim_input)
	add_child(dim)
	_sheet = PanelContainer.new()
	_sheet.name = "Sheet"
	_sheet.add_theme_stylebox_override("panel", CharacterCard.panel_box())
	add_child(_sheet)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	_sheet.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	margin.add_child(v)
	v.add_child(_header())
	var sub := CharacterCard.make_label("Victoire la plus courte dans chaque mode (temps pour abattre le boss final).", 24, COL_DIM, 4)
	sub.name = "Subtitle"
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.max_lines_visible = 2
	sub.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(sub)
	var row := HBoxContainer.new()
	row.name = "Columns"
	row.add_theme_constant_override("separation", 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	for m in MODES:
		var col := _mode_column(m)
		columns.append(col)
		row.add_child(col)
	close_button = Button.new()
	close_button.name = "Close"
	close_button.text = "Fermer"
	close_button.custom_minimum_size = Vector2(300, 80)
	close_button.add_theme_font_size_override("font_size", 38)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	UiTheme.mark_back(close_button)
	close_button.focus_neighbor_left = NodePath(".")
	close_button.focus_neighbor_right = NodePath(".")
	close_button.focus_neighbor_top = NodePath(".")
	close_button.focus_neighbor_bottom = NodePath(".")
	v.add_child(close_button)
	UiTheme.apply(self)
	resized.connect(_layout)
	_layout()
	var plat := get_node_or_null("/root/Platform")
	if plat == null or not bool(plat.call("is_touch_mode")):
		close_button.grab_focus.call_deferred()


func _layout() -> void:
	var vs := size if size.x > 0 else get_viewport_rect().size
	var w := minf(vs.x - 96.0, 1760.0)
	var h := minf(vs.y - 64.0, 920.0)
	_sheet.custom_minimum_size = Vector2(w, h)
	_sheet.size = Vector2(w, h)
	_sheet.position = ((vs - _sheet.size) * 0.5).floor()


func _header() -> Control:
	var h := HBoxContainer.new()
	h.name = "Header"
	h.add_theme_constant_override("separation", 18)
	var pi := CharacterCard.portrait_info(character, "-")
	if pi.tex != null:
		var tr := TextureRect.new()
		tr.name = "Portrait"
		tr.texture = pi.tex
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(96, 96)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(tr)
	var t := CharacterCard.make_label("Meilleures runs — %s" % str(character.get("name", "?")), 46)
	t.name = "Title"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.clip_text = true
	h.add_child(t)
	return h


## Record du personnage dans ce mode ({} = aucune victoire).
func record(m: StringName) -> Dictionary:
	var cid := StringName(str(character.get("id", "")))
	if profile != null and profile.has_method(&"best_run"):
		return profile.call(&"best_run", cid, m)
	var br: Variant = CharacterCard.pget(profile, "best_runs", {})
	if br is Dictionary:
		var per: Variant = (br as Dictionary).get(String(cid), {})
		if per is Dictionary and (per as Dictionary).get(String(m)) is Dictionary:
			return (per as Dictionary)[String(m)]
	return {}


func _mode_column(m: StringName) -> Control:
	var p := PanelContainer.new()
	p.name = "Mode_" + String(m)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(120, 0)
	p.add_theme_stylebox_override("panel", CharacterCard.panel_box(CharacterCard.COL_PANEL, CharacterCard.COL_BORDER, 2, 0.7, false))
	var mg := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mg.add_theme_constant_override("margin_" + side, 14)
	p.add_child(mg)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	mg.add_child(v)
	var head := CharacterCard.make_label(MODE_NAMES[m], 38, CharacterCard.COL_TEXT, 5)
	head.name = "ModeName"
	v.add_child(head)
	var r := record(m)
	if r.is_empty():
		var none := CharacterCard.make_label("Aucune victoire", 30, COL_DIM, 4)
		none.name = "None"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.max_lines_visible = 2
		none.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(none)
		return p
	var tl := CharacterCard.make_label(ProgressScreen.time_text(float(r.get("time_s", 0.0))), 56, COL_TIME, 7)
	tl.name = "Time"
	v.add_child(tl)
	var dt := date_text(str(r.get("date", "")))
	var dl := _wrap("Date", dt if dt != "" else "Date inconnue", 24, COL_DIM, 1)
	v.add_child(dl)
	var st := _wrap("Stats", "Niveau %d · %s monstres tués" % [int(r.get("level", 0)), ProgressScreen.group_thousands(int(r.get("kills", 0)))], 26, COL_BODY, 2)
	v.add_child(st)
	v.add_child(_wrap("ItemsTitle", "Objets", 26, CharacterCard.COL_FOCUS, 1))
	v.add_child(_items_block(r.get("items", {})))
	v.add_child(_wrap("VariantsTitle", "Variantes de sorts", 26, CharacterCard.COL_FOCUS, 1))
	var names := variant_names(r.get("variants", {}))
	if names.is_empty():
		v.add_child(_wrap("Variants", "Aucune (sorts de base)", 24, COL_DIM, 2))
	else:
		v.add_child(_wrap("Variants", "\n".join(names), 24, COL_BODY, maxi(names.size(), 1) + 1))
	return p


func _wrap(nm: String, txt: String, fs: int, col: Color, lines: int) -> Label:
	var l := CharacterCard.make_label(txt, fs, col, 4)
	l.name = nm
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _items_block(items: Variant) -> Control:
	var sc := ScrollContainer.new()
	sc.name = "Items"
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, ICON + 8.0)
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(flow)
	if not (items is Dictionary) or (items as Dictionary).is_empty():
		flow.add_child(CharacterCard.make_label("Aucun", 24, COL_DIM, 4))
		return sc
	for id in items:
		flow.add_child(_item_cell(str(id), int(items[id])))
	return sc


func _item_cell(id: String, stacks: int) -> Control:
	var it := ItemDB.get_item(id)
	var cell := Control.new()
	cell.name = "Item_" + id
	cell.custom_minimum_size = Vector2(ICON, ICON)
	cell.tooltip_text = "%s%s" % [str(it.get("name", id)), (" ×%d" % stacks) if stacks > 1 else ""]
	cell.mouse_filter = Control.MOUSE_FILTER_PASS
	cell.add_child(ItemBar.quality_backing(it.get("quality", "commun"), 6))
	var path: String = ItemBar.ITEM_ICON % id
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(tr)
	else:
		var f := CharacterCard.make_label(str(it.get("name", id)).left(2), 22, COL_BODY, 4)
		f.set_anchors_preset(Control.PRESET_FULL_RECT)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(f)
	if stacks > 1:
		var n := CharacterCard.make_label("×%d" % stacks, 20, COL_TIME, 5)
		n.name = "Stacks"
		n.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		n.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		n.grow_vertical = Control.GROW_DIRECTION_BEGIN
		cell.add_child(n)
	return cell


## « Sort 2 : Pilier de flamme » pour chaque variante enregistrée ({slot: id}), dans l'ordre des emplacements.
func variant_names(variants: Variant) -> Array[String]:
	var out: Array[String] = []
	if not (variants is Dictionary):
		return out
	var slots: Array = (variants as Dictionary).keys()
	slots.sort_custom(func(a, b): return int(str(a)) < int(str(b)))
	var spells: Array = character.get("spells", []) if character.get("spells") is Array else []
	for k in slots:
		var slot := int(str(k))
		var vid := str(variants[k])
		var nm := ""
		if slot >= 1 and slot <= spells.size() and spells[slot - 1] is Dictionary:
			for v in spells[slot - 1].get("variants", []):
				if v is Dictionary and (str(v.get("id", "")) == vid or str(v.get("unlock_key", "")) == "spell:" + vid):
					nm = str(v.get("name", ""))
		if nm == "":
			nm = vid.replace("_", " ").capitalize()
		out.append("Sort %d : %s" % [slot, nm])
	return out


## « 2026-10-26T22:57:23 » -> « 26/10/2026 » ("" si illisible).
static func date_text(iso: String) -> String:
	if iso.length() < 10 or iso[4] != "-" or iso[7] != "-":
		return ""
	return "%s/%s/%s" % [iso.substr(8, 2), iso.substr(5, 2), iso.substr(0, 4)]


func close() -> void:
	CharacterCard.play_ui(&"ui.click", -6.0, 0.85)
	closed.emit()
	queue_free()


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close()
	elif event is InputEventScreenTouch and event.pressed:
		close()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
