class_name ProgressScreen
extends Control
## Écran « Progression » (docs/Design_Menus.md §3.3) : rubis, modes, personnages, statistiques.
## Lecture seule ; seul « Retour » est focusable. Données : `Profile` (§6.2), lues avec repli
## tant que le lot B n'expose pas toutes les propriétés.

signal back_requested

const RUBY_ICON := "res://assets/sprites/ui/menu/ruby_large.png"
const RUBY_ICON_FALLBACK := "res://assets/sprites/ui/hud/icon_ruby.png"
const MODES: Array[StringName] = [&"facile", &"moyen", &"difficile"]
const MODE_NAMES := {&"facile": "Facile", &"moyen": "Moyen", &"difficile": "Difficile"}
const CARD_RATIO := 384.0 / 560.0 ## ratio du cadre DA des cartes (card_front.png)
const GAP := 24.0
const COL_DIM := Color(0.62, 0.64, 0.68)
const COL_BODY := Color(0.9, 0.9, 0.93)
const ITEM_ICON := "res://assets/sprites/icons/items/%s.png"
const ITEM_FRAME := "res://assets/sprites/icons/frame_%s.png"
const ITEM_CELL_H := 176.0
const ITEM_QUALITY_COLORS := {
	&"commun": Color(0.78, 0.78, 0.8), &"peu_commun": Color(0.35, 0.82, 0.4),
	&"rare": Color(0.33, 0.6, 1.0), &"legendaire": Color(1.0, 0.65, 0.12),
}
const ITEM_QUALITY_NAMES := {&"commun": "Commun", &"peu_commun": "Peu commun", &"rare": "Rare", &"legendaire": "Légendaire"}

var profile: Object
var characters: Array = []
var back_button: Button
var rubies_label: Label
var stats_label: Label
var next_label: Label ## « Prochain déblocage : … » (1 ligne sous le titre)
var char_cards: Array[Control] = []
var _card_size := CharacterCard.CARD_SIZE

var _title: Label
var _banner: PanelContainer
var _ruby_box: HBoxContainer
var _modes_box: VBoxContainer
var _chars_header: Label
var _chars_grid: GridContainer
var _chars_scroll: ScrollContainer ## la grille défile s'il y a trop de cartes pour la hauteur disponible
var tab_chars: Button ## onglets « Personnages » / « Objets » (zone droite)
var tab_items: Button
var items_count_label: Label ## « X/Y objets débloqués »
var items_scroll: ScrollContainer
var item_cells: Array[Button] = []
var _items_grid: GridContainer
var tab_skins: Button ## 3e onglet « Skins » : un skin par personnage (Skins), équipable s'il est débloqué
var skins_count_label: Label ## « X/Y skins débloqués »
var skins_scroll: ScrollContainer
var skin_cells: Array[Button] = []
var best_panel: BestRunsPanel = null ## panneau « Meilleures runs » ouvert (clic sur une carte de personnage)
var _skins_grid: GridContainer
var _tab := 0 ## 0 personnages, 1 objets, 2 skins
var _skin_focus := "" ## skin à re-focaliser après un rafraîchissement (équiper / retirer)
const TAB_CHARS := 0
const TAB_ITEMS := 1
const TAB_SKINS := 2
const SKIN_CELL_H := 176.0
const SKIN_PORTRAIT := 128.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = CharacterCard.default_profile()
	if characters.is_empty(): # une liste peut être injectée avant _ready (tests)
		characters = CharacterCard.sorted_by_difficulty(CharacterCard.load_characters())
	_build()
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	resized.connect(_layout)
	_layout()
	if profile != null and profile.has_signal("changed"):
		profile.connect("changed", refresh)
	var plat := get_node_or_null("/root/Platform")
	if plat == null or not bool(plat.call("is_touch_mode")):
		back_button.grab_focus.call_deferred()
	CharacterCard.play_ui(&"ui.hover", -4.0, 1.15)


func _build() -> void:
	add_child(CharacterCard.make_backdrop())
	var bn := CharacterCard.make_banner("Progression")
	_banner = bn.banner
	_title = bn.label
	add_child(_banner)
	_ruby_box = HBoxContainer.new()
	_ruby_box.add_theme_constant_override("separation", 12)
	_ruby_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ruby_box)
	var icon_path := RUBY_ICON if ResourceLoader.exists(RUBY_ICON) else RUBY_ICON_FALLBACK
	if ResourceLoader.exists(icon_path):
		var ic := TextureRect.new()
		ic.texture = load(icon_path)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(96, 96)
		_ruby_box.add_child(ic)
	rubies_label = CharacterCard.make_label("0", 64, UiTheme.COL_PRIMARY_TEXT, 8) # or, comme au titre et au récap
	_ruby_box.add_child(rubies_label)
	next_label = CharacterCard.make_label("", 28, CharacterCard.COL_FOCUS, 5)
	next_label.name = "NextUnlock"
	next_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(next_label)

	_modes_box = VBoxContainer.new()
	_modes_box.add_theme_constant_override("separation", 16)
	add_child(_modes_box)

	_chars_header = CharacterCard.make_label("Personnages", 40)
	_chars_header.visible = false # remplacé par les onglets
	add_child(_chars_header)
	tab_chars = _make_tab("TabChars", "Personnages")
	tab_items = _make_tab("TabItems", "Objets")
	tab_skins = _make_tab("TabSkins", "Skins")
	tab_chars.pressed.connect(_show_tab.bind(TAB_CHARS))
	tab_items.pressed.connect(_show_tab.bind(TAB_ITEMS))
	tab_skins.pressed.connect(_show_tab.bind(TAB_SKINS))
	tab_chars.focus_neighbor_right = tab_chars.get_path_to(tab_items)
	tab_items.focus_neighbor_left = tab_items.get_path_to(tab_chars)
	tab_items.focus_neighbor_right = tab_items.get_path_to(tab_skins)
	tab_skins.focus_neighbor_left = tab_skins.get_path_to(tab_items)
	tab_chars.focus_neighbor_left = NodePath(".")
	tab_skins.focus_neighbor_right = NodePath(".")
	items_count_label = CharacterCard.make_label("", 28, COL_BODY, 5)
	items_count_label.name = "ItemsCount"
	add_child(items_count_label)
	items_scroll = ScrollContainer.new()
	items_scroll.name = "ItemsScroll"
	items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	items_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	items_scroll.visible = false
	add_child(items_scroll)
	_items_grid = GridContainer.new()
	_items_grid.columns = 2
	_items_grid.add_theme_constant_override("h_separation", 16)
	_items_grid.add_theme_constant_override("v_separation", 16)
	items_scroll.add_child(_items_grid)
	skins_count_label = CharacterCard.make_label("", 28, COL_BODY, 5)
	skins_count_label.name = "SkinsCount"
	add_child(skins_count_label)
	skins_scroll = ScrollContainer.new()
	skins_scroll.name = "SkinsScroll"
	skins_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	skins_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	skins_scroll.visible = false
	add_child(skins_scroll)
	_skins_grid = GridContainer.new()
	_skins_grid.columns = 2
	_skins_grid.add_theme_constant_override("h_separation", 16)
	_skins_grid.add_theme_constant_override("v_separation", 16)
	skins_scroll.add_child(_skins_grid)
	_chars_grid = GridContainer.new()
	_chars_grid.columns = 3
	_chars_grid.add_theme_constant_override("h_separation", int(GAP))
	_chars_grid.add_theme_constant_override("v_separation", int(GAP))
	_chars_scroll = ScrollContainer.new()
	_chars_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chars_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_chars_scroll)
	_chars_scroll.add_child(_chars_grid)

	stats_label = CharacterCard.make_label("", 26, COL_BODY)
	add_child(stats_label)
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(300, 96)
	back_button.size = back_button.custom_minimum_size
	back_button.add_theme_font_size_override("font_size", 40)
	back_button.pressed.connect(_on_back)
	UiTheme.mark_back(back_button)
	back_button.focus_neighbor_left = NodePath(".")
	back_button.focus_neighbor_right = NodePath(".")
	back_button.focus_neighbor_top = back_button.get_path_to(tab_chars)
	back_button.focus_neighbor_bottom = NodePath(".")
	add_child(back_button)
	refresh()


## Relit le profil et reconstruit les blocs.
func refresh() -> void:
	rubies_label.text = group_thousands(int(CharacterCard.pget(profile, "rubies", 0)))
	var stats: Dictionary = _stats()
	var nxt := EndRunScreen.next_objective(profile, characters)
	next_label.visible = not nxt.is_empty()
	if not nxt.is_empty():
		var line := "Prochain déblocage : %s" % str(nxt.get("title", ""))
		if str(nxt.get("text", "")) != "":
			line += " — %s" % str(nxt["text"])
		if float(nxt.get("progress", -1.0)) > 0.0:
			line += " (%d %%)" % int(round(float(nxt["progress"]) * 100.0))
		next_label.text = line
	for ch in _modes_box.get_children():
		ch.queue_free()
	_modes_box.add_child(CharacterCard.make_label("Modes", 40))
	var best: Dictionary = stats.get("best_time_s", {}) if stats.get("best_time_s", {}) is Dictionary else {}
	var wins: Dictionary = stats.get("victories_by_mode", {}) if stats.get("victories_by_mode", {}) is Dictionary else {}
	for m in MODES:
		_modes_box.add_child(_mode_row(m, best, wins))
	for ch in _chars_grid.get_children():
		ch.queue_free()
	char_cards.clear()
	for c in characters:
		var card := _char_card(c)
		_chars_grid.add_child(card)
		char_cards.append(card)
	_rebuild_items()
	_rebuild_skins()
	_apply_tab()
	if is_inside_tree():
		_layout()
	var parts: Array[String] = [
		"Runs : %s" % group_thousands(int(stats.get("runs", 0))),
		"Victoires : %s" % group_thousands(int(stats.get("victories", 0))),
		"Monstres tués : %s" % group_thousands(int(stats.get("kills", 0))),
		"Temps de jeu : %s" % play_time_text(float(stats.get("play_time_s", 0.0))),
	]
	stats_label.text = " · ".join(parts)


func _make_tab(nm: String, txt: String) -> Button:
	var b := Button.new()
	b.name = nm
	b.text = txt
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(210, 56)
	b.size = b.custom_minimum_size
	b.add_theme_font_size_override("font_size", 28)
	add_child(b)
	return b


func _show_tab(t: int) -> void:
	_tab = t
	_apply_tab()
	if is_inside_tree():
		_layout()


func _apply_tab() -> void:
	tab_chars.set_pressed_no_signal(_tab == TAB_CHARS)
	tab_items.set_pressed_no_signal(_tab == TAB_ITEMS)
	tab_skins.set_pressed_no_signal(_tab == TAB_SKINS)
	_chars_scroll.visible = _tab == TAB_CHARS
	items_scroll.visible = _tab == TAB_ITEMS
	items_count_label.visible = _tab == TAB_ITEMS
	skins_scroll.visible = _tab == TAB_SKINS
	skins_count_label.visible = _tab == TAB_SKINS
	var down: Control = back_button
	match _tab:
		TAB_ITEMS:
			if not item_cells.is_empty():
				down = item_cells[0]
		TAB_SKINS:
			if not skin_cells.is_empty():
				down = skin_cells[0]
		_:
			if not char_cards.is_empty():
				down = char_cards[0]
	for tb in [tab_chars, tab_items, tab_skins]:
		(tb as Button).focus_neighbor_bottom = (tb as Button).get_path_to(down)
	back_button.focus_neighbor_top = back_button.get_path_to([tab_chars, tab_items, tab_skins][_tab])


## Grille de tous les objets (items.json) : débloqués en couleur, verrouillés en silhouette avec condition et avancement.
func _rebuild_items() -> void:
	for ch in _items_grid.get_children():
		_items_grid.remove_child(ch)
		ch.queue_free()
	item_cells.clear()
	var ids: Array = ItemDB.all_ids()
	var open := 0
	for id in ids:
		var ok := ItemUnlocks.is_unlocked(id, profile)
		if ok:
			open += 1
		var cell := _item_cell(str(id), ok)
		_items_grid.add_child(cell)
		item_cells.append(cell)
	items_count_label.set_meta(&"counts", Vector2i(open, ids.size()))
	items_count_label.text = "%d/%d objets débloqués" % [open, ids.size()]
	for i in item_cells.size():
		var c := item_cells[i]
		var cols := maxi(_items_grid.columns, 1)
		c.focus_neighbor_left = NodePath(".") if i % cols == 0 else c.get_path_to(item_cells[i - 1])
		c.focus_neighbor_right = NodePath(".") if i % cols == cols - 1 or i == item_cells.size() - 1 else c.get_path_to(item_cells[i + 1])
		c.focus_neighbor_top = c.get_path_to(tab_items) if i < cols else c.get_path_to(item_cells[i - cols])
		c.focus_neighbor_bottom = c.get_path_to(back_button) if i + cols >= item_cells.size() else c.get_path_to(item_cells[i + cols])


func _item_cell(id: String, unlocked: bool) -> Button:
	var it := ItemDB.get_item(id)
	var q := StringName(str(it.get("quality", "commun")))
	var qcol: Color = ITEM_QUALITY_COLORS.get(q, Color.WHITE)
	var b := Button.new()
	b.name = "Item_" + id
	b.custom_minimum_size = Vector2(300, ITEM_CELL_H)
	b.clip_contents = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", CharacterCard.panel_box())
	b.tooltip_text = "%s (%s)\n%s%s" % [str(it.get("name", id)), ITEM_QUALITY_NAMES.get(q, ""), str(it.get("effect_text", "")),
		"" if unlocked else "\nVerrouillé : " + ItemUnlocks.condition_text(id)]
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	b.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(h)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(84, 84)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	ic.add_child(ItemBar.quality_backing(q, 6))
	for path in [ITEM_ICON % id]:
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
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var dim := Color(0.5, 0.5, 0.55)
	var nm := CharacterCard.make_label(str(it.get("name", id)), 26, qcol if unlocked else dim, 4)
	nm.name = "Name"
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	v.add_child(nm)
	var ef := CharacterCard.make_label(str(it.get("effect_text", "")), 19, COL_BODY if unlocked else dim, 3)
	ef.name = "Effect"
	ef.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ef.max_lines_visible = 3
	ef.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	ef.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(ef)
	if not unlocked:
		var cond := CharacterCard.make_label("Verrouillé : " + ItemUnlocks.condition_text(id), 19, CharacterCard.COL_FOCUS, 3)
		cond.name = "Condition"
		cond.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cond.max_lines_visible = 2
		cond.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cond.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_child(cond)
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
			var pl := CharacterCard.make_label("%s / %s" % [group_thousands(int(pr.value)), group_thousands(int(pr.target))], 18, COL_DIM, 3)
			pl.name = "ProgressText"
			v.add_child(pl)
	return b


## Grille « Skins » : un skin par personnage jouable. Débloqué : portrait du skin (ou celui par défaut + « Rendu à venir »),
## état Équiper / Équipé ; verrouillé : silhouette sombre et condition de déblocage.
func _rebuild_skins() -> void:
	for ch in _skins_grid.get_children():
		_skins_grid.remove_child(ch)
		ch.queue_free()
	skin_cells.clear()
	var entries := Skins.all_skins(characters)
	var open := 0
	for e in entries:
		var ok := Skins.is_unlocked(profile, e.id)
		if ok:
			open += 1
		var cell := _skin_cell(e, ok)
		_skins_grid.add_child(cell)
		skin_cells.append(cell)
	skins_count_label.set_meta(&"counts", Vector2i(open, entries.size()))
	skins_count_label.text = "%d/%d skins débloqués" % [open, entries.size()]
	var cols := maxi(_skins_grid.columns, 1)
	for i in skin_cells.size():
		var c := skin_cells[i]
		c.focus_neighbor_left = NodePath(".") if i % cols == 0 else c.get_path_to(skin_cells[i - 1])
		c.focus_neighbor_right = NodePath(".") if i % cols == cols - 1 or i == skin_cells.size() - 1 else c.get_path_to(skin_cells[i + 1])
		c.focus_neighbor_top = c.get_path_to(tab_skins) if i < cols else c.get_path_to(skin_cells[i - cols])
		c.focus_neighbor_bottom = c.get_path_to(back_button) if i + cols >= skin_cells.size() else c.get_path_to(skin_cells[i + cols])
	if _skin_focus != "":
		for c in skin_cells:
			if c.name == "Skin_" + _skin_focus:
				c.grab_focus.call_deferred()
		_skin_focus = ""


func _skin_cell(e: Dictionary, unlocked: bool) -> Button:
	var c: Dictionary = e.character
	var sk: Dictionary = e.skin
	var cid := str(c.get("id", ""))
	var sid := str(e.id)
	var equipped := Skins.equipped(cid, profile) == sid
	var has_art := Skins.has_assets(cid, sid)
	var b := Button.new()
	b.name = "Skin_" + sid
	b.custom_minimum_size = Vector2(300, SKIN_CELL_H)
	b.clip_contents = true
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", CharacterCard.panel_box())
	b.tooltip_text = "%s — %s\n%s" % [str(c.get("name", "")), str(sk.get("name", "")), str(sk.get("desc", ""))]
	b.set_meta(&"skin_id", sid)
	b.pressed.connect(_on_skin_pressed.bind(cid, sid))
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	b.add_child(margin)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(h)
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
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var dim := Color(0.5, 0.5, 0.55)
	var who := CharacterCard.make_label(str(c.get("name", "")), 20, COL_DIM, 3)
	who.name = "Character"
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.clip_text = true
	v.add_child(who)
	var nm := CharacterCard.make_label(str(sk.get("name", sid)), 26, CharacterCard.COL_TEXT if unlocked else dim, 4)
	nm.name = "Name"
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	v.add_child(nm)
	if unlocked:
		if not has_art:
			v.add_child(_skin_line("Pending", "Rendu à venir", 19, COL_DIM, 1))
		var st := _skin_line("State", "Équipé · appuyer pour retirer" if equipped else "Équiper", 22,
			Color("#9BE29B") if equipped else CharacterCard.COL_FOCUS, 2)
		v.add_child(st)
	else:
		v.add_child(_skin_line("Condition", "Verrouillé : " + Skins.quest_text(c, sk), 19, CharacterCard.COL_FOCUS, 3))
		if not has_art:
			v.add_child(_skin_line("Pending", "Rendu à venir", 19, dim, 1))
	return b


func _skin_line(nm: String, txt: String, fs: int, col: Color, lines: int) -> Label:
	var l := CharacterCard.make_label(txt, fs, col, 3)
	l.name = nm
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = lines
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Équipe le skin (ou le retire s'il l'est déjà). Verrouillé : sans effet.
func _on_skin_pressed(cid: String, sid: String) -> void:
	if not Skins.is_unlocked(profile, sid) or profile == null or not profile.has_method(&"set_selected_skin"):
		return
	var now := Skins.equipped(cid, profile) == sid
	_skin_focus = sid
	CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
	profile.call(&"set_selected_skin", StringName(cid), "" if now else sid)
	if not profile.has_signal("changed"):
		refresh()


func _stats() -> Dictionary:
	var s: Variant = CharacterCard.pget(profile, "stats", {})
	return s if s is Dictionary else {}


func _mode_row(m: StringName, best: Dictionary, wins: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(0, 88)
	p.add_theme_stylebox_override("panel", CharacterCard.panel_box())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 24)
	p.add_child(h)
	var unlocked := CharacterCard.is_mode_unlocked(profile, m)
	var nm := CharacterCard.make_label(MODE_NAMES[m], 36, CharacterCard.COL_TEXT if unlocked else COL_DIM)
	nm.custom_minimum_size = Vector2(180, 0)
	h.add_child(nm)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(CharacterCard.make_label("Débloqué" if unlocked else "Terminez Moyen", 26, Color("#9BE29B") if unlocked else CharacterCard.COL_FOCUS, 4))
	var bt: Variant = best.get(String(m), best.get(m, null))
	var info := "Meilleur temps : %s" % (time_text(float(bt)) if bt != null else "—")
	var w: Variant = wins.get(String(m), wins.get(m, null))
	if w != null:
		info += " · Victoires : %d" % int(w)
	v.add_child(CharacterCard.make_label(info, 24, COL_BODY, 4))
	return p


## Carte de personnage : même carte DA que l'écran Nouvelle run (portrait, accent, titre), inerte ;
## verrouillé à objectif visible : texte de l'objectif + barre de progression à l'accent du personnage.
func _char_card(c: Dictionary) -> Control:
	var card := CharacterCard.new()
	var locked := CharacterCard.is_character_locked(profile, c)
	card.setup(c, locked)
	card.make_display_only()
	card.make_inspectable() # clic / toucher / A : meilleures runs
	card.pressed.connect(open_best_runs.bind(c))
	if locked and not bool(c.get("hidden", false)) and not bool(c.get("unlocked", false)):
		card.set_objective_progress(_objective(String(c.get("id", ""))))
	card.set_card_size(_card_size)
	return card


## Ouvre le panneau « Meilleures runs » du personnage (modal ; Échap / B / Fermer le referme).
func open_best_runs(c: Dictionary) -> void:
	if best_panel != null and is_instance_valid(best_panel):
		return
	CharacterCard.play_ui(&"ui.click", -6.0, 1.0)
	best_panel = BestRunsPanel.create(c, profile)
	var from_id := str(c.get("id", ""))
	best_panel.closed.connect(_on_best_closed.bind(from_id))
	add_child(best_panel)


func _on_best_closed(from_id: String) -> void:
	best_panel = null
	for card in char_cards:
		if str(card.data.get("id", "")) == from_id and is_inside_tree():
			card.grab_focus.call_deferred()


func _objective(id: String) -> float:
	if profile != null and profile.has_method("objective_progress"):
		return clampf(float(profile.call("objective_progress", StringName(id))), 0.0, 1.0)
	return 0.0


func _layout() -> void:
	var vs := size if size.x > 0 else get_viewport_rect().size
	var m := {"left": 48.0, "right": 48.0, "top": 32.0, "bottom": 32.0}
	var plat := get_node_or_null("/root/Platform")
	if plat != null and plat.has_method("safe_margins"):
		var d: Dictionary = plat.call("safe_margins")
		for k in m:
			m[k] = clampf(float(d.get(k, m[k])), m[k], 160.0) # borné (aperçu mobile multi-écran)
	_banner.position = Vector2(m.left, 24)
	_banner.size = Vector2(520, 92)
	_ruby_box.reset_size()
	var nx: float = m.left + 48
	next_label.position = Vector2(nx, 124)
	next_label.custom_minimum_size.x = vs.x - m.right - nx - 24.0
	next_label.size.x = next_label.custom_minimum_size.x
	_ruby_box.position = Vector2(vs.x - m.right - _ruby_box.get_combined_minimum_size().x, 24)
	var mx: float = m.left + 48
	# Modes : 600 px, réduits (≥ 480) si la zone sûre est étroite pour que la grille tienne.
	var modes_w := clampf(vs.x - m.right - mx - 48 - (3 * 340.0 + 2 * GAP), 480.0, 600.0)
	var gx: float = mx + modes_w + 48
	var grid_w: float = vs.x - m.right - gx
	_chars_header.position = Vector2(gx, 170)
	_chars_scroll.position = Vector2(gx, 230)
	items_scroll.position = _chars_scroll.position
	back_button.position = Vector2(m.left, vs.y - m.bottom - back_button.size.y)
	stats_label.position = Vector2(m.left + 48, back_button.position.y - stats_label.get_combined_minimum_size().y - 16.0)
	var scroll_h := maxf(stats_label.position.y - 16.0 - _chars_scroll.position.y, 160.0)
	# Grille : nombre de colonnes qui donne les plus grandes cartes tenant sans défilement
	# (16 px réservés à la barre) ; au-delà (roster très grand), hauteur plancher et défilement.
	var n := maxi(char_cards.size(), 1)
	var inner_w := grid_w - 16.0
	var best_h := 0.0
	var cols := 1
	for k in range(1, n + 1):
		var rows := ceili(float(n) / k)
		var h := minf((scroll_h - (rows - 1) * GAP) / rows, (inner_w - (k - 1) * GAP) / k / CARD_RATIO)
		if h > best_h + 0.5:
			best_h = h
			cols = k
	var ch := clampf(best_h, 200.0, 420.0)
	_chars_grid.columns = cols
	_card_size = Vector2(floorf(ch * CARD_RATIO), floorf(ch) - 1.0)
	for c in char_cards:
		(c as CharacterCard).set_card_size(_card_size)
	# Grille centrée dans sa colonne (16 px gardés pour la barre de défilement si elle sert).
	var used_w := cols * _card_size.x + (cols - 1) * GAP
	gx += maxf((inner_w - used_w) * 0.5, 0.0)
	grid_w = minf(grid_w, used_w + 16.0)
	_chars_scroll.position.x = gx
	_chars_header.position.x = gx
	# Onglets au-dessus de la zone ; grille d'objets sur la même zone que celle des personnages.
	tab_chars.position = Vector2(mx + modes_w + 48, 166)
	tab_items.position = Vector2(mx + modes_w + 48 + tab_chars.size.x + 16.0, 166)
	tab_skins.position = Vector2(tab_items.position.x + tab_items.size.x + 16.0, 166)
	skins_count_label.position = Vector2(tab_skins.position.x + tab_skins.size.x + 24.0, 172)
	skins_count_label.custom_minimum_size.x = maxf(vs.x - m.right - skins_count_label.position.x, 120.0)
	skins_count_label.size.x = skins_count_label.custom_minimum_size.x
	skins_count_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	items_count_label.position = Vector2(tab_skins.position.x + tab_skins.size.x + 24.0, 172)
	items_count_label.custom_minimum_size.x = maxf(vs.x - m.right - items_count_label.position.x, 120.0)
	items_count_label.size.x = items_count_label.custom_minimum_size.x
	items_count_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_fit_count(items_count_label, "objets débloqués")
	_fit_count(skins_count_label, "skins débloqués")
	var items_x: float = mx + modes_w + 48
	var items_w: float = vs.x - m.right - items_x
	var icols := 2 if items_w >= 760.0 else 1
	if _items_grid.columns != icols:
		_items_grid.columns = icols
		_rebuild_items()
		_apply_tab()
	if _skins_grid.columns != icols:
		_skins_grid.columns = icols
		_rebuild_skins()
		_apply_tab()
	var cell_w := floorf((items_w - 16.0 - 16.0 * (icols - 1)) / icols)
	for c in skin_cells:
		c.custom_minimum_size = Vector2(cell_w, SKIN_CELL_H)
	_skins_grid.custom_minimum_size.x = items_w - 16.0
	skins_scroll.position = Vector2(items_x, _chars_scroll.position.y)
	skins_scroll.size = Vector2(items_w, scroll_h)
	for c in item_cells:
		c.custom_minimum_size = Vector2(cell_w, ITEM_CELL_H)
	_items_grid.custom_minimum_size.x = items_w - 16.0
	items_scroll.position.x = items_x
	_modes_box.position = Vector2(mx, 170)
	_modes_box.custom_minimum_size = Vector2(modes_w, 0)
	_modes_box.size = Vector2(modes_w, 0)
	# ligne de stats juste au-dessus du bouton Retour ; la grille des personnages s'arrête au-dessus d'elle
	_chars_scroll.size = Vector2(grid_w, scroll_h)
	items_scroll.size = Vector2(items_w, scroll_h)
	_chars_grid.custom_minimum_size.x = grid_w - 16.0


## Compteur « X/Y <nom> » ; réduit à « X/Y » quand la place manque à côté des onglets.
func _fit_count(l: Label, noun: String) -> void:
	var cnt: Vector2i = l.get_meta(&"counts", Vector2i.ZERO)
	var long_txt := "%d/%d %s" % [cnt.x, cnt.y, noun]
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var w := f.get_string_size(long_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x if f != null else 0.0
	l.text = long_txt if w + 8.0 <= l.custom_minimum_size.x else "%d/%d" % [cnt.x, cnt.y]


func _on_back() -> void:
	back_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if best_panel != null and is_instance_valid(best_panel):
			return # le panneau se referme seul
		CharacterCard.play_ui(&"ui.click", -6.0, 0.85)
		_on_back()


static func group_thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


static func time_text(sec: float) -> String:
	var t := int(sec)
	return "%02d:%02d" % [t / 60, t % 60]


static func play_time_text(sec: float) -> String:
	var mins := int(sec) / 60
	return "%d h %02d" % [mins / 60, mins % 60] if mins >= 60 else "%d min" % mins
