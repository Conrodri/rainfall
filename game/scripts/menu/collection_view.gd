class_name CollectionView
extends Control
## Vue en grille défilante des onglets « Records », « Objets » et « Skins » de l'écran Historique (HistoryScreen),
## reprise de l'ancien écran Progression.
##  - records : un bouton par personnage (meilleur temps par mode) ; clic = signal `character_chosen` (le parent ouvre BestRunsPanel).
##  - items   : tous les objets (items.json), débloqués en couleur, verrouillés en silhouette avec condition et avancement.
##  - skins   : tous les skins de chaque personnage jouable (Skins.all_skins : trophées puis Panoplies de la boutique), une
##              cellule chacun, équipable (ou retirable) s'il est possédé (`Profile.set_selected_skin`).
## Le parent fixe `position` / `size` ; la vue règle ses colonnes selon sa largeur.

signal character_chosen(c: Dictionary)

enum Kind { RECORDS, ITEMS, SKINS }

const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const CELL_H := 176.0
const RECORD_H := 128.0
const SKIN_PORTRAIT := 128.0
const GAP := 16.0
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const COL_LOCKED := Color(0.5, 0.5, 0.55)
const ITEM_QUALITY_COLORS := {
	&"commun": Color(0.78, 0.78, 0.8), &"peu_commun": Color(0.35, 0.82, 0.4),
	&"rare": Color(0.33, 0.6, 1.0), &"legendaire": Color(1.0, 0.65, 0.12),
}
const ITEM_QUALITY_NAMES := {&"commun": "Commun", &"peu_commun": "Peu commun", &"rare": "Rare", &"legendaire": "Légendaire", &"forge": "Forgé"}
const MODES: Array[StringName] = [&"facile", &"moyen", &"difficile"]
const MODE_NAMES := {&"facile": "Facile", &"moyen": "Moyen", &"difficile": "Difficile"}

var kind: Kind = Kind.ITEMS
var profile: Object
var characters: Array = []
var cells: Array[Button] = []
var columns := 1
var count_text := "" ## « X/Y objets débloqués » (lu par le parent)

var _scroll: ScrollContainer
var _grid: GridContainer
var _focus_id := "" ## cellule à re-focaliser après un rafraîchissement (équiper / retirer)


static func create(k: Kind, p: Object, chars: Array) -> CollectionView:
	var v := CollectionView.new()
	v.kind = k
	v.profile = p
	v.characters = chars
	return v


func _ready() -> void:
	name = ["Records", "Items", "Skins"][kind]
	mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override(&"h_separation", int(GAP))
	_grid.add_theme_constant_override(&"v_separation", int(GAP))
	_scroll.add_child(_grid)
	resized.connect(_relayout)
	refresh()


func refresh() -> void:
	if _grid == null:
		return
	for ch in _grid.get_children():
		_grid.remove_child(ch)
		ch.queue_free()
	cells.clear()
	match kind:
		Kind.RECORDS:
			var n_wins := 0
			for c in characters:
				var cell := _record_cell(c)
				_grid.add_child(cell)
				cells.append(cell)
				if cell.get_meta(&"has_win", false):
					n_wins += 1
			count_text = "%d personnage%s avec une victoire" % [n_wins, "s" if n_wins > 1 else ""]
		Kind.ITEMS:
			var ids: Array = ItemDB.all_ids()
			var open := 0
			for id in ids:
				var ok := ItemUnlocks.is_unlocked(id, profile)
				open += 1 if ok else 0
				var cell := _item_cell(str(id), ok)
				_grid.add_child(cell)
				cells.append(cell)
			count_text = "%d/%d objets débloqués" % [open, ids.size()]
		Kind.SKINS:
			var entries := Skins.all_skins(characters)
			var open := 0
			for e in entries:
				var ok := Skins.is_unlocked(profile, e.id)
				open += 1 if ok else 0
				var cell := _skin_cell(e, ok)
				_grid.add_child(cell)
				cells.append(cell)
			count_text = "%d/%d skins débloqués" % [open, entries.size()]
	_relayout()
	if _focus_id != "":
		for c in cells:
			if c.name == _focus_id:
				c.grab_focus.call_deferred()
		_focus_id = ""


func _relayout() -> void:
	if _grid == null:
		return
	var w := maxf(size.x - 16.0, 200.0)
	var cols := 2 if w >= 760.0 else 1
	if cols != columns or _grid.columns != cols:
		columns = cols
		_grid.columns = cols
	var cell_w := floorf((w - GAP * (cols - 1)) / cols)
	for c in cells:
		c.custom_minimum_size = Vector2(cell_w, RECORD_H if kind == Kind.RECORDS else CELL_H)
	_grid.custom_minimum_size.x = w


# --- Cellules --------------------------------------------------------------------------------------------------------

func _cell_button(nm: String) -> Button:
	var b := Button.new()
	b.name = nm
	b.clip_contents = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.add_theme_stylebox_override(&"normal", CharacterCard.panel_box())
	return b


func _row(b: Button) -> HBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	b.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(h)
	return h


func _line(nm: String, txt: String, fs: int, col: Color, lines: int) -> Label:
	var l := CharacterCard.make_label(txt, fs, col, 3)
	l.name = nm
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.custom_minimum_size.x = 10.0
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _portrait(c: Dictionary, skin: String, px: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.name = "Portrait"
	tr.texture = CharacterCard.portrait_info(c, skin).tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(px, px)
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return tr


## Meilleur temps (victoire la plus courte) du personnage dans chaque mode ; clic = panneau BestRunsPanel.
func _record_cell(c: Dictionary) -> Button:
	var cid := str(c.get("id", ""))
	var b := _cell_button("Record_" + cid)
	var locked := CharacterCard.is_character_locked(profile, c)
	b.pressed.connect(func() -> void: character_chosen.emit(c))
	var h := _row(b)
	var pr := _portrait(c, "-", 96.0)
	if locked:
		pr.modulate = Color(0.06, 0.06, 0.08, 0.95)
	h.add_child(pr)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override(&"separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := CharacterCard.make_label("???" if locked and bool(c.get("hidden", false)) else str(c.get("name", cid)), 28,
		COL_LOCKED if locked else CharacterCard.COL_TEXT, 4)
	nm.name = "Name"
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	var parts: Array[String] = []
	var wins := false
	for m in MODES:
		var r: Dictionary = profile.call(&"best_run", StringName(cid), m) if profile != null and profile.has_method(&"best_run") else {}
		wins = wins or not r.is_empty()
		parts.append("%s %s" % [MODE_NAMES[m], BestRunsPanel.time_text(float(r.get("time_s", 0.0))) if not r.is_empty() else "—"])
	b.set_meta(&"has_win", wins)
	v.add_child(_line("Times", "  ·  ".join(parts), 21, COL_BODY if wins else COL_DIM, 2))
	return b


func _item_cell(id: String, unlocked: bool) -> Button:
	var it := ItemDB.get_item(id)
	var q := StringName(str(it.get("quality", "commun")))
	var qcol: Color = ITEM_QUALITY_COLORS.get(q, Color.WHITE)
	var b := _cell_button("Item_" + id)
	b.tooltip_text = "%s (%s)\n%s%s" % [str(it.get("name", id)), ITEM_QUALITY_NAMES.get(q, ""), str(it.get("effect_text", "")),
		"" if unlocked else "\nVerrouillé : " + ItemUnlocks.condition_text(id)]
	var h := _row(b)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(84, 84)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	ic.add_child(ItemBar.quality_backing(q, 6))
	var path: String = ITEM_ICON % id
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if not unlocked:
			tr.modulate = Color(0.06, 0.06, 0.08, 0.95) # silhouette
		ic.add_child(tr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := CharacterCard.make_label(str(it.get("name", id)), 26, qcol if unlocked else COL_LOCKED, 4)
	nm.name = "Name"
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	v.add_child(nm)
	v.add_child(_line("Effect", str(it.get("effect_text", "")), 19, COL_BODY if unlocked else COL_LOCKED, 3))
	if not unlocked:
		v.add_child(_line("Condition", "Verrouillé : " + ItemUnlocks.condition_text(id), 19, CharacterCard.COL_FOCUS, 2))
		var pr := ItemUnlocks.progress(id, profile)
		if not pr.is_empty():
			var bar := ProgressBar.new()
			bar.name = "Progress"
			bar.max_value = float(pr.target)
			bar.value = float(pr.value)
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 12)
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(bar)
			var pl := CharacterCard.make_label("%s / %s" % [BestRunsPanel.group_thousands(int(pr.value)), BestRunsPanel.group_thousands(int(pr.target))], 18, COL_DIM, 3)
			pl.name = "ProgressText"
			v.add_child(pl)
	return b


## Débloqué : portrait du skin (ou celui par défaut + « Rendu à venir »), état Équiper / Équipé ; verrouillé : silhouette et condition.
func _skin_cell(e: Dictionary, unlocked: bool) -> Button:
	var c: Dictionary = e.character
	var sk: Dictionary = e.skin
	var cid := str(c.get("id", ""))
	var sid := str(e.id)
	var equipped := Skins.equipped(cid, profile) == sid
	var has_art := Skins.has_assets(cid, sid)
	var b := _cell_button("Skin_" + sid)
	b.tooltip_text = "%s — %s\n%s" % [str(c.get("name", "")), str(sk.get("name", "")), str(sk.get("desc", ""))]
	b.set_meta(&"skin_id", sid)
	b.pressed.connect(_on_skin_pressed.bind(cid, sid))
	var h := _row(b)
	var pi: Dictionary = Skins.portrait_info(cid, sid)
	if not bool(pi.exists):
		pi = CharacterCard.portrait_info(c, "-") # pas encore rendu : portrait par défaut assombri
	var pr := TextureRect.new()
	pr.name = "Portrait"
	pr.texture = pi.tex
	pr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pr.custom_minimum_size = Vector2(SKIN_PORTRAIT, SKIN_PORTRAIT)
	pr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if not unlocked:
		pr.modulate = Color(0.06, 0.06, 0.08, 0.95)
	elif not has_art:
		pr.modulate = Color(0.45, 0.45, 0.5)
	h.add_child(pr)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var who := CharacterCard.make_label(str(c.get("name", "")), 20, COL_DIM, 3)
	who.name = "Character"
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.clip_text = true
	v.add_child(who)
	var nm := CharacterCard.make_label(str(sk.get("name", sid)), 26, CharacterCard.COL_TEXT if unlocked else COL_LOCKED, 4)
	nm.name = "Name"
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	v.add_child(nm)
	if unlocked:
		if not has_art:
			v.add_child(_line("Pending", "Rendu à venir", 19, COL_DIM, 1))
		v.add_child(_line("State", "Équipé · appuyer pour retirer" if equipped else "Équiper", 22,
			Color("#9BE29B") if equipped else CharacterCard.COL_FOCUS, 2))
	else:
		v.add_child(_line("Condition", "Verrouillé : " + Skins.quest_text(c, sk), 19, CharacterCard.COL_FOCUS, 3))
		if not has_art:
			v.add_child(_line("Pending", "Rendu à venir", 19, COL_LOCKED, 1))
	return b


## Équipe le skin (ou le retire s'il l'est déjà). Verrouillé : sans effet.
func _on_skin_pressed(cid: String, sid: String) -> void:
	if not Skins.is_unlocked(profile, sid) or profile == null or not profile.has_method(&"set_selected_skin"):
		return
	var now := Skins.equipped(cid, profile) == sid
	_focus_id = "Skin_" + sid
	CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
	profile.call(&"set_selected_skin", StringName(cid), "" if now else sid)
	if not profile.has_signal(&"changed"):
		refresh()
