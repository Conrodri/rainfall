class_name TestPanel
extends Control
## Panneau du mode test (TestOverlay) : cinq onglets Monstres / Objets / Personnage / Triches / Difficulté, posé sur le
## bord droit (la moitié gauche de l'écran reste visible). Souris, clavier, manette (focus) et tactile : tous les boutons
## ont la taille tactile minimale (UiTheme.MIN_TOUCH) et la liste défile. Les actions passent par TestTools / TestMode.
## À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const TABS: Array = [["Monstres", &"monsters"], ["Objets", &"items"], ["Personnage", &"character"], ["Triches", &"cheats"], ["Difficulté", &"difficulty"]]
const QUANTITIES: Array[int] = [1, 2, 3, 5, 10, 15, 25, 50, 100]
const FS_BODY := 28
const FS_SMALL := 23
const FS_HEAD := 34
const FS_TAB := 25
const BTN_H := 76.0
const WIDTH_FRAC := 0.5
const WIDTH_MIN := 740.0
const WIDTH_MAX := 1120.0
const REFRESH_S := 0.25
const COL_ON := Color("FFB347")
const COL_MUTED := Color("A9B2BF")
const COL_BAD := Color("FF7A5C")
## Icônes réutilisées des assets existants (aucune n'est dessinée ici). Plusieurs sont des emprunts à des icônes d'objets.
const ICON_GOD := "res://assets/sprites/icons/items/bague_de_vigueur.png"
const ICON_CDR := "res://assets/sprites/icons/items/sablier_fele.png"
const ICON_RANGE := "res://assets/sprites/icons/items/rune_de_portee.png"
const ICON_GOLD := "res://assets/sprites/ui/da/icon_gold.png"
const ICON_TIMER := "res://assets/sprites/icons/items/chronometre_brise.png"
const ICON_PAUSE := "res://assets/sprites/ui/da/icon_pause.png"
const ICON_HEAL := "res://assets/sprites/icons/items/tonique_vital.png"
const DIFF_ICONS := {"Calme": "diff_1_calme", "Tension": "diff_2_tension", "Alerte": "diff_3_alerte", "Fournaise": "diff_4_fournaise", "Cataclysme": "diff_5_cataclysme"}

var overlay: TestOverlay
## Entrée du catalogue armée pour l'invocation par clic dans l'arène ({} = aucune).
var armed_entry: Dictionary = {}
var tab: StringName = &"monsters"

var _frame: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _status: Label
var _tab_buttons := {}
var _quantity_idx := 3
var _poutch_type: StringName = &"normal"
var _tip: SpellTooltip ## infobulle des sorts et variantes (même composant que la fiche Nouvelle run)
var _press_token := 0
var _elite := false
var _at_cursor := false
var _loadouts := {} ## id de personnage (texte) -> {slot: id de variante}
var _item_counts := {} ## id d'objet -> Label du compteur
var _cheat_checks := {}
var _diff_labels := {}
var _level_label: Label
var _hits_label: Label
var _d_slider: HSlider
var _d_label: Label
var _d_icon: TextureRect
var _acc := 0.0
var _catalog: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.theme()
	_build_frame()
	_tip = SpellTooltip.new()
	_tip.name = "SpellTip"
	add_child(_tip)
	_catalog = TestTools.monster_catalog()
	get_viewport().size_changed.connect(_layout)
	Platform.safe_area_changed.connect(_layout)
	_layout()
	_select_tab(tab)


func open() -> void:
	visible = true
	_layout()
	_select_tab(tab)
	var b: Button = _tab_buttons.get(tab)
	if b != null:
		b.grab_focus()


func close() -> void:
	visible = false
	if _tip != null:
		_tip.hide_tip()
	armed_entry = {}
	var f := get_viewport().gui_get_focus_owner()
	if f != null and is_ancestor_of(f):
		f.release_focus()


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc < REFRESH_S:
		return
	_acc = 0.0
	if tab == &"difficulty":
		_refresh_difficulty()
	elif tab == &"character":
		_refresh_level()


# --- Cadre ------------------------------------------------------------------------

func _build_frame() -> void:
	_frame = PanelContainer.new()
	_frame.name = "Frame"
	_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.11, 1.0)
	sb.border_color = UiTheme.COL_BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 20
	sb.content_margin_right = 12
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_frame.add_theme_stylebox_override(&"panel", sb)
	add_child(_frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	_frame.add_child(col)
	# en-tête : titre, état, fermer
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	col.add_child(head)
	var title := _label("MODE TEST", FS_HEAD, UiTheme.COL_PRIMARY_TEXT)
	head.add_child(title)
	_status = _label("", FS_SMALL, COL_MUTED)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.clip_text = true
	_status.custom_minimum_size = Vector2(0, 60)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(_status)
	var close_btn := _btn("Fermer", func() -> void: overlay.close(), 170.0)
	close_btn.name = "Close"
	head.add_child(close_btn)
	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	col.add_child(tabs)
	var group := ButtonGroup.new()
	for t in TABS:
		var tb := Button.new()
		tb.text = t[0]
		tb.name = "Tab_%s" % t[1]
		tb.toggle_mode = true
		tb.button_group = group
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.custom_minimum_size = Vector2(0, BTN_H)
		tb.add_theme_font_size_override(&"font_size", FS_TAB)
		tb.clip_text = true
		_style_active_tab(tb)
		var tid: StringName = t[1]
		tb.pressed.connect(func() -> void: _select_tab(tid))
		tabs.add_child(tb)
		_tab_buttons[tid] = tb
	# corps défilant
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.scroll_deadzone = 12
	col.add_child(_scroll)
	_scroll.get_v_scroll_bar().custom_minimum_size.x = 34.0 if Platform.has_touch() else 18.0
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override(&"separation", 10)
	_scroll.add_child(_body)


func _layout() -> void:
	if _frame == null:
		return
	var vp := get_viewport_rect().size
	var safe := Platform.safe_margins()
	var w := clampf(vp.x * WIDTH_FRAC, WIDTH_MIN, WIDTH_MAX)
	w = minf(w, vp.x - 40.0)
	_frame.anchor_left = 1.0
	_frame.anchor_right = 1.0
	_frame.anchor_top = 0.0
	_frame.anchor_bottom = 1.0
	_frame.offset_right = -(float(safe.get("right", 0.0)) + 14.0)
	_frame.offset_left = _frame.offset_right - w
	_frame.offset_top = float(safe.get("top", 0.0)) + 14.0
	_frame.offset_bottom = -(float(safe.get("bottom", 0.0)) + 14.0)


# --- Fabrique de contrôles ----------------------------------------------------------

func _label(text: String, size: int = FS_BODY, color: Color = UiTheme.COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _btn(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, BTN_H)
	b.add_theme_font_size_override(&"font_size", FS_BODY)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(cb)
	return b


func _check(text: String, value: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.custom_minimum_size = Vector2(0, BTN_H)
	c.add_theme_font_size_override(&"font_size", FS_BODY)
	c.toggled.connect(cb)
	return c


func _heading(text: String) -> Label:
	var l := _label(text, FS_BODY + 2, COL_ON)
	l.add_theme_constant_override(&"line_spacing", 0)
	return l


func _note(text: String) -> Label:
	var l := _label(text, FS_SMALL, COL_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	return l


func _grid(columns: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override(&"h_separation", 8)
	g.add_theme_constant_override(&"v_separation", 8)
	return g


func _expand(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


## Largeur utile du corps défilant (px), pour adapter le nombre de colonnes des cartes.
func _body_width() -> float:
	var vp := get_viewport_rect().size
	var w := clampf(vp.x * WIDTH_FRAC, WIDTH_MIN, WIDTH_MAX)
	return minf(w, vp.x - 40.0) - 90.0


## Colonnes d'une grille de cartes : autant que la largeur le permet (cartes de `min_w` px au moins), au moins 2.
func _cols(min_w: float) -> int:
	return maxi(2, int(_body_width() / min_w))


## TextureRect d'une icône (ratio gardé) ; la texture peut être null (zone vide, jamais de forme dessinée).
func _icon(t: Texture2D, px: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	r.custom_minimum_size = Vector2(px, px)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Carte cliquable : vignette + nom (+ mention). Verticale (vignette au-dessus) ou horizontale (vignette à gauche).
func _card(t: Texture2D, title: String, sub: String, thumb_px: float, horizontal: bool, cb: Callable, gray: bool = false) -> Button:
	var b := Button.new()
	b.toggle_mode = false
	b.clip_contents = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		m.add_theme_constant_override(side, 8)
	b.add_child(m)
	var box: BoxContainer = HBoxContainer.new() if horizontal else VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 10 if horizontal else 2)
	m.add_child(box)
	var img := _icon(t, thumb_px)
	if gray:
		img.material = CharacterCard.grayscale_material(0.5) # icône absente : celle du sort de base, désaturée
	if not horizontal:
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(img)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(col)
	var nm := _label(title, FS_SMALL + 1)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if horizontal else HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(nm)
	if sub != "":
		var sl := _label(sub, FS_SMALL - 4, COL_MUTED)
		sl.horizontal_alignment = nm.horizontal_alignment
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(sl)
	return b


func say(msg: String) -> void:
	if _status != null:
		_status.text = msg


# --- Onglets --------------------------------------------------------------------------

## Onglet actif : fond plein et texte d'accent, indépendants du focus (le cadre de focus reste à part).
func _style_active_tab(tb: Button) -> void:
	for st in [&"pressed", &"hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.42, 0.24, 0.08, 1.0)
		sb.border_color = UiTheme.COL_PRIMARY_TEXT
		sb.set_border_width_all(3)
		sb.border_width_bottom = 8
		sb.set_corner_radius_all(10)
		tb.add_theme_stylebox_override(st, sb)
	for c in [&"font_pressed_color", &"font_hover_pressed_color"]:
		tb.add_theme_color_override(c, UiTheme.COL_PRIMARY_TEXT)


func _select_tab(t: StringName) -> void:
	tab = t
	if _tip != null:
		_tip.hide_tip()
	armed_entry = {}
	for k in _tab_buttons:
		(_tab_buttons[k] as Button).set_pressed_no_signal(k == t)
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_item_counts.clear()
	_cheat_checks.clear()
	_diff_labels.clear()
	_level_label = null
	_hits_label = null
	_d_slider = null
	_d_label = null
	_d_icon = null
	match t:
		&"monsters": _build_monsters()
		&"items": _build_items()
		&"character": _build_character()
		&"cheats": _build_cheats()
		&"difficulty": _build_difficulty()
	_scroll.scroll_vertical = 0
	UiTheme.hook_sounds(_body)


# --- Onglet Monstres ---------------------------------------------------------------------

func quantity() -> int:
	return QUANTITIES[_quantity_idx]


func _build_monsters() -> void:
	var tools := _grid(2)
	_body.add_child(tools)
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override(&"separation", 8)
	var qlabel := _label("Quantité : %d" % quantity(), FS_BODY)
	qlabel.name = "QuantityLabel"
	qlabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(_btn("−", func() -> void:
		_quantity_idx = maxi(_quantity_idx - 1, 0)
		qlabel.text = "Quantité : %d" % quantity(), 84.0))
	qrow.add_child(qlabel)
	qrow.add_child(_btn("+", func() -> void:
		_quantity_idx = mini(_quantity_idx + 1, QUANTITIES.size() - 1)
		qlabel.text = "Quantité : %d" % quantity(), 84.0))
	qrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools.add_child(qrow)
	var elite := _check("Élite", _elite, func(on: bool) -> void: _elite = on)
	elite.name = "EliteCheck"
	tools.add_child(_expand(elite))
	if Platform.input_mode != Platform.InputMode.GAMEPAD:
		var cur := _check("Clic dans l'arène", _at_cursor, func(on: bool) -> void:
			_at_cursor = on
			armed_entry = {}
			say("Choisissez un monstre, puis cliquez dans l'arène." if on else "Apparition près du joueur."))
		cur.name = "CursorCheck"
		tools.add_child(_expand(cur))
	var ai := _check("IA figée", TestMode.freeze_ai, func(on: bool) -> void:
		TestMode.set_flag(&"freeze_ai", on))
	ai.name = "FreezeCheck"
	tools.add_child(_expand(ai))
	var spawns := _check("Apparitions du director", TestMode.spawns, func(on: bool) -> void: _set_spawns(on))
	spawns.name = "SpawnsCheck"
	tools.add_child(_expand(spawns))
	_body.add_child(_note("La quantité et « Élite » valent pour les monstres ; un mini-boss ou un boss apparaît une seule fois par clic."))
	var acts := _grid(2)
	_body.add_child(acts)
	var kill := _btn("Tuer tout", func() -> void: say("%d monstre(s) tués." % TestTools.kill_all(get_tree())))
	kill.name = "KillAll"
	acts.add_child(_expand(kill))
	var clean := _btn("Nettoyer", func() -> void: say("%d monstre(s) retirés." % TestTools.clean(get_tree())))
	clean.name = "Clean"
	acts.add_child(_expand(clean))
	_build_poutch()
	var last_group := ""
	var grid: GridContainer = null
	var cols := _cols(190.0)
	for e in _catalog:
		var gk := "%s|%s" % [e.group, e.sub]
		if gk != last_group:
			last_group = gk
			_body.add_child(_heading(String(e.group) if String(e.sub) == "" else "%s · %s" % [e.group, e.sub]))
			grid = _grid(cols)
			_body.add_child(grid)
		var entry: Dictionary = e
		var th := TestThumbs.monster(entry)
		var sub := "provisoire (sprite non livré)" if bool(th.provisional) else ""
		var b := _card(th.tex, String(entry.label), sub, 120.0, false, func() -> void: _on_monster_pressed(entry))
		b.custom_minimum_size = Vector2(0, 196)
		b.name = "Spawn_%s" % String(entry.key).replace(":", "_")
		grid.add_child(b)
	if Platform.input_mode == Platform.InputMode.GAMEPAD:
		_body.add_child(_note("Les monstres apparaissent à 5-8 u autour du joueur."))


func _build_poutch() -> void:
	_body.add_child(_heading("Poutch (mannequin d'entraînement)"))
	var row := _grid(_cols(190.0))
	_body.add_child(row)
	var th := TestThumbs.monster({"key": "tier:3:-1", "kind": &"tier", "tier": 3, "variant": -1})
	var card := _card(th.tex, "Poutch", "immobile, invincible", 120.0, false, func() -> void: _on_arm_pressed({"kind": &"poutch", "label": "Poutch"}))
	card.name = "Poutch"
	card.custom_minimum_size = Vector2(0, 196)
	row.add_child(card)
	var types := _grid(3)
	_body.add_child(types)
	var group := ButtonGroup.new()
	for t in [[&"normal", "Normal"], [&"elite", "Élite"], [&"boss", "Boss"]]:
		var tid: StringName = t[0]
		var b := _btn(t[1], func() -> void: _poutch_type = tid)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = tid == _poutch_type
		b.name = "PoutchType_%s" % tid
		_style_active_tab(b)
		types.add_child(_expand(b))
	var acts := _grid(2)
	_body.add_child(acts)
	var rm := _btn("Retirer les Poutchs", func() -> void: say("%d Poutch(s) retirés." % TestTools.clear_poutchs(get_tree())))
	rm.name = "ClearPoutchs"
	acts.add_child(_expand(rm))
	var rz := _btn("Compteur à zéro (Retour arr.)", func() -> void:
		TestTools.reset_poutchs(get_tree())
		say("Compteurs remis à zéro."))
	rz.name = "ResetPoutchs"
	acts.add_child(_expand(rz))
	_body.add_child(_note("Le Poutch reçoit tout (dégâts, critiques, statuts, ciblage) mais ne meurt jamais ; son DPS (5 s) et son total s'affichent au-dessus de lui. Le type sert aux effets qui dépendent d'élite ou de boss."))


func _on_monster_pressed(entry: Dictionary) -> void:
	if _at_cursor and Platform.input_mode != Platform.InputMode.GAMEPAD:
		armed_entry = entry
		say("%s : cliquez dans l'arène (Échap pour annuler)." % entry.label)
		return
	spawn_entry(entry, null)


func _on_arm_pressed(entry: Dictionary) -> void:
	if _at_cursor and Platform.input_mode != Platform.InputMode.GAMEPAD:
		armed_entry = entry
		say("%s : cliquez dans l'arène (Échap pour annuler)." % entry.label)
		return
	spawn_entry(entry, null)


## Invoque `entry` (quantité et élite du panneau) près du joueur, ou autour de `center`.
func spawn_entry(entry: Dictionary, center: Variant) -> Array[Node2D]:
	if entry.get("kind", &"") == &"poutch":
		var pt := TestTools.spawn_poutch(get_tree(), _poutch_type, center)
		say("Poutch (%s) posé." % TestPoutch.TYPE_NAMES.get(_poutch_type, "") if pt != null else "Poutch impossible ici.")
		return [pt.enemy] if pt != null else ([] as Array[Node2D])
	if entry.get("kind", &"") == &"chest":
		var ch := TestTools.spawn_chest(get_tree(), StringName(entry.chest_kind), center)
		say("%s posé." % entry.label if ch != null else "Coffre impossible ici.")
		return [ch] if ch != null else ([] as Array[Node2D])
	var made := TestTools.spawn(get_tree(), entry, quantity(), _elite and entry.kind == &"tier", center)
	say("%d × %s%s" % [made.size(), entry.label, " (élite)" if _elite and entry.kind == &"tier" else ""])
	return made


func _set_spawns(on: bool) -> void:
	TestMode.set_flag(&"spawns", on)
	var d := get_tree().get_first_node_in_group(&"director")
	if d != null:
		d.set(&"spawning_enabled", on)
		d.set(&"waves_enabled", on)
	say("Apparitions du director : %s." % ("activées" if on else "coupées"))


# --- Onglet Objets ------------------------------------------------------------------------

func _build_chests() -> void:
	_body.add_child(_heading("Coffres"))
	var grid := _grid(_cols(190.0))
	_body.add_child(grid)
	for e in TestTools.chest_catalog():
		var entry: Dictionary = e
		var b := _card(TestThumbs.chest(entry), String(entry.label), "gratuit" if bool(entry.free) else "prix du D courant", 96.0, false, func() -> void: _on_arm_pressed(entry))
		b.name = "Chest_%s" % entry.chest_kind
		b.custom_minimum_size = Vector2(0, 170)
		grid.add_child(b)
	var rm := _btn("Retirer les coffres", func() -> void: say("%d coffre(s) retirés." % TestTools.clear_chests(get_tree())))
	rm.name = "ClearChests"
	_body.add_child(rm)
	_body.add_child(_note("Le coffre apparaît près du joueur (ou au clic si « Clic dans l'arène » est coché, onglet Monstres). Ouverture : interagir, comme en jeu. Pour l'ouvrir sans payer : triche « Or infini »."))


func _build_items() -> void:
	_build_chests()
	_body.add_child(_heading("Objets"))
	var top := HBoxContainer.new()
	top.add_theme_constant_override(&"separation", 8)
	_body.add_child(top)
	var total := _label("", FS_BODY)
	total.name = "ItemTotal"
	total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(total)
	var clear := _btn("Tout retirer", func() -> void:
		TestTools.clear_items(get_tree())
		_refresh_items()
		say("Tous les objets retirés."), 260.0)
	clear.name = "ClearItems"
	top.add_child(clear)
	_item_counts[&"__total"] = total
	var last_q := &""
	for it in TestTools.item_catalog():
		if it.quality != last_q:
			last_q = it.quality
			var h := _heading(String(TestTools.QUALITY_NAMES[it.quality]))
			h.add_theme_color_override(&"font_color", TestTools.QUALITY_COLORS[it.quality])
			_body.add_child(h)
		_body.add_child(_item_row(it))
	_refresh_items()


func _item_row(it: Dictionary) -> Control:
	var id: StringName = it.id
	var row := HBoxContainer.new()
	row.name = "Item_%s" % id
	row.add_theme_constant_override(&"separation", 8)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(76, 76)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(ItemBar.quality_backing(it.quality))
	var ir := _icon(TestThumbs.item_icon(id), 76.0)
	ir.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ic.add_child(ir)
	row.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override(&"separation", 0)
	var nm := _label(String(it.name), FS_BODY, TestTools.QUALITY_COLORS[it.quality])
	nm.clip_text = true
	info.add_child(nm)
	var fx := _label(String(it.effect), FS_SMALL - 2, COL_MUTED)
	fx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fx.custom_minimum_size = Vector2(200, 0)
	info.add_child(fx)
	row.add_child(info)
	var count := _label("0", FS_BODY + 2, Color.WHITE)
	count.custom_minimum_size = Vector2(64, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_item_counts[id] = count
	var minus := _btn("−", func() -> void:
		TestTools.remove_item(get_tree(), id)
		_refresh_items(), 84.0)
	minus.name = "Minus"
	var plus := _btn("+", func() -> void:
		TestTools.add_item(get_tree(), id)
		_refresh_items(), 84.0)
	plus.name = "Plus"
	row.add_child(minus)
	row.add_child(count)
	row.add_child(plus)
	return row


func _refresh_items() -> void:
	var total := 0
	for id in _item_counts:
		if id == &"__total":
			continue
		var n := RunState.stacks(id)
		total += n
		var l: Label = _item_counts[id]
		if is_instance_valid(l):
			l.text = str(n)
			l.add_theme_color_override(&"font_color", Color.WHITE if n > 0 else COL_MUTED)
	var tl: Label = _item_counts.get(&"__total")
	if is_instance_valid(tl):
		tl.text = "%d objet(s) possédés" % total


# --- Onglet Personnage --------------------------------------------------------------------

func _build_character() -> void:
	var cur := String(RunState.character)
	_body.add_child(_heading("Personnage (1 clic, sur place)"))
	var grid := _grid(_cols(420.0))
	_body.add_child(grid)
	var cdata: Dictionary = {}
	for c in TestTools.characters():
		var cid := str(c.get("id", ""))
		var cc: Dictionary = c
		var b := _card(TestThumbs.character(cc), str(c.get("name", cid)), str(c.get("title", "")), 104.0, true, func() -> void: _on_character_pressed(StringName(cid)))
		b.name = "Char_%s" % cid
		b.custom_minimum_size = Vector2(0, 124)
		if cid == cur:
			b.add_theme_stylebox_override(&"normal", _current_style())
			b.add_theme_stylebox_override(&"hover", _current_style())
			cdata = c
		grid.add_child(b)
	if cdata.is_empty():
		return
	_build_skins(cdata)
	_build_spell_variants(cdata)
	_body.add_child(_heading("Niveau"))
	_level_label = _label("", FS_BODY)
	_level_label.name = "LevelLabel"
	_body.add_child(_level_label)
	var lv := _grid(3)
	_body.add_child(lv)
	for step in [[-10, "−10"], [-1, "−1"], [1, "+1"], [10, "+10"]]:
		var s: int = step[0]
		lv.add_child(_expand(_btn(step[1], func() -> void:
			TestTools.set_level(RunState.level + s)
			_refresh_level())))
	var mx := _btn("Niveau max (%d)" % TestTools.MAX_LEVEL, func() -> void:
		TestTools.set_level(TestTools.MAX_LEVEL)
		_refresh_level())
	mx.name = "LevelMax"
	lv.add_child(_expand(mx))
	var one := _btn("Niveau 1", func() -> void:
		TestTools.set_level(1)
		_refresh_level())
	lv.add_child(_expand(one))
	_refresh_level()


## Fond de la carte du personnage en jeu (même style que l'onglet actif).
func _current_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.42, 0.24, 0.08, 1.0)
	sb.border_color = UiTheme.COL_PRIMARY_TEXT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	return sb


func _on_character_pressed(cid: StringName) -> void:
	if cid == RunState.character:
		return
	var ok := TestTools.switch_character(get_tree(), cid, _loadouts.get(String(cid), {}))
	say("%s en jeu." % cid if ok else "Changement impossible.")
	_reselect_keep_scroll()


func _reselect_keep_scroll() -> void:
	var sv := _scroll.scroll_vertical
	_select_tab(tab)
	await get_tree().process_frame
	_scroll.scroll_vertical = sv


func _build_skins(c: Dictionary) -> void:
	var cid := StringName(str(c.get("id", "")))
	var skins: Array = c.get("skins", []) if c.get("skins") is Array else []
	_body.add_child(_heading("Apparence"))
	var grid := _grid(_cols(190.0))
	_body.add_child(grid)
	var forced := str(TestMode.skin_override.get(String(cid), "<profil>"))
	var entries: Array = [{"id": "", "name": "Défaut"}]
	for s in skins:
		if s is Dictionary and str(s.get("id", "")) != "":
			entries.append(s)
	for s in entries:
		var sid := str(s.get("id", ""))
		var delivered := sid == "" or Skins.has_assets(cid, sid)
		var b := _card(TestThumbs.character(c, sid), str(s.get("name", sid)), "" if delivered else "non livré", 110.0, false, func() -> void:
			TestTools.set_skin(get_tree(), cid, sid, _loadouts.get(String(cid), {}))
			say("Apparence : %s." % (str(s.get("name", sid)) if sid != "" else "défaut"))
			_reselect_keep_scroll())
		b.name = "Skin_%s" % (sid if sid != "" else "default")
		b.disabled = not delivered
		b.custom_minimum_size = Vector2(0, 180)
		if (forced == sid) or (forced == "<profil>" and sid == ""):
			b.add_theme_stylebox_override(&"normal", _current_style())
			b.add_theme_stylebox_override(&"hover", _current_style())
			b.add_theme_stylebox_override(&"disabled", _current_style())
		grid.add_child(b)


func _build_spell_variants(c: Dictionary) -> void:
	var cid := StringName(str(c.get("id", "")))
	var spells: Array = c.get("spells", []) if c.get("spells") is Array else []
	if spells.is_empty():
		return
	_body.add_child(_heading("Sorts et variantes"))
	var lo: Dictionary = _loadouts.get(String(cid), {})
	var cdata := CharacterData.for_id(cid)
	for i in spells.size():
		var sp: Dictionary = spells[i]
		var slot := i + 1
		var variants: Array = sp.get("variants", []) if sp.get("variants") is Array else []
		_body.add_child(_label("%d · %s" % [slot, sp.get("name", sp.get("id", ""))], FS_SMALL + 2, UiTheme.COL_TEXT))
		var base_id := StringName(str(sp.get("id", "")))
		var base_icon := ArdentKit.spell_icon(base_id)
		var row := _grid(_cols(260.0))
		_body.add_child(row)
		var chosen := str(lo.get(slot, sp.get("id", "")))
		var opts: Array = [{"id": String(base_id), "name": str(sp.get("name", "")) + " (base)", "coded": true, "icon": base_icon, "gray": false,
			"desc": str(sp.get("desc", "")), "sd": cdata.spells[i] if cdata != null and i < cdata.spells.size() else null, "locked": false}]
		for v in variants:
			if v is Dictionary:
				var vid := StringName(str(v.get("id", "")))
				var vicon := ArdentKit.spell_icon(vid)
				opts.append({"id": String(vid), "name": str(v.get("name", vid)),
					"coded": CharacterData.variant_spell(cid, slot, vid, true) != null,
					"icon": vicon if vicon != null else base_icon, "gray": vicon == null, "desc": str(v.get("desc", "")),
					"sd": CharacterData.variant_spell(cid, slot, vid, true), "locked": not CharacterCard.is_variant_unlocked(Profile, v)})
		for o in opts:
			var oid := str(o.id)
			var is_base: bool = oid == String(base_id)
			var b := _card(o.icon, str(o.name), "" if bool(o.coded) else "non codée", 84.0, true, func() -> void: _choose_variant(cid, slot, oid, is_base), bool(o.gray))
			b.name = "Variant_%d_%s" % [slot, oid]
			_hook_spell_tip(b, slot, sp, o, is_base)
			b.disabled = not bool(o.coded)
			b.custom_minimum_size = Vector2(0, 108)
			if chosen == oid:
				b.add_theme_stylebox_override(&"normal", _current_style())
				b.add_theme_stylebox_override(&"hover", _current_style())
				b.add_theme_stylebox_override(&"disabled", _current_style())
			row.add_child(b)


## Infobulle d'une carte de sort : survol souris, focus clavier / manette (pas le focus pris au clic), appui long tactile.
## Elle part à la sortie de la souris ou du focus, jamais au clic.
func _hook_spell_tip(b: Button, slot: int, sp: Dictionary, o: Dictionary, is_base: bool) -> void:
	b.mouse_entered.connect(func() -> void: _show_spell_tip(b, slot, sp, o, is_base))
	b.mouse_exited.connect(func() -> void:
		if not Platform.has_touch():
			_tip.hide_tip(b))
	b.focus_entered.connect(func() -> void:
		if not b.is_hovered():
			_show_spell_tip(b, slot, sp, o, is_base))
	b.focus_exited.connect(func() -> void:
		if not b.is_hovered() and not Platform.has_touch():
			_tip.hide_tip(b))
	b.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			_press_token += 1
			if ev.pressed:
				var tok := _press_token
				get_tree().create_timer(0.45, true).timeout.connect(func() -> void:
					if tok == _press_token and is_instance_valid(b):
						_show_spell_tip(b, slot, sp, o, is_base)))


func _show_spell_tip(b: Button, slot: int, sp: Dictionary, o: Dictionary, is_base: bool) -> void:
	if _tip == null or not is_instance_valid(b) or not b.is_inside_tree():
		return
	var role := String(sp.get("role", CharacterSheet.ROLE_TEXT.get(String(sp.get("slot", "")), "")))
	var tag := "Sort %d · %s" % [slot, role] if role != "" else "Sort %d" % slot
	if not is_base:
		tag = "Variante · %s" % ("verrouillée au profil (appliquée quand même)" if bool(o.locked) else "débloquée")
	var body := str(o.get("desc", ""))
	var sd: SpellData = o.get("sd")
	if sd != null:
		var stats := CharacterSheet.spell_stats_text(sd)
		var dmg := CharacterSheet.scaling_text(sd, false)
		if stats != "":
			body += "
" + stats
		if dmg != "":
			body += "
" + dmg
	_tip.show_for(b, str(sp.get("name", "")) if is_base else str(o.get("name", "")), tag, body)


func _choose_variant(cid: StringName, slot: int, variant_id: String, is_base: bool) -> void:
	var lo: Dictionary = (_loadouts.get(String(cid), {}) as Dictionary).duplicate()
	if is_base:
		lo.erase(slot)
	else:
		lo[slot] = StringName(variant_id)
	_loadouts[String(cid)] = lo
	if RunState.character == cid:
		TestTools.switch_character(get_tree(), cid, lo)
	say("Sort %d : %s." % [slot, variant_id])
	_reselect_keep_scroll()


func _refresh_level() -> void:
	if _level_label == null:
		return
	var p := get_tree().get_first_node_in_group(&"player")
	var hp := ""
	if p != null:
		hp = " · PV max %d · dégâts de base %.1f" % [int(p.get(&"max_hp")), Balance.player_base_damage(RunState.level)]
	_level_label.text = "Niveau %d%s" % [RunState.level, hp]


# --- Onglet Triches ------------------------------------------------------------------------

func _build_cheats() -> void:
	_body.add_child(_heading("Triches (chacune indépendante)"))
	_cheat("PV illimités", &"god", "Les coups sont encaissés (chiffres, flash) mais ne retirent rien.", ICON_GOD)
	_cheat("Recharge 100 % (CDR)", &"cdr_full", "Les sorts se relancent sans attendre. Les ressources propres aux kits restent limitées.", ICON_CDR)
	_cheat("Portée infinie", &"inf_range", "Portée des sorts et ciblage automatique sans limite (8 000 px).", ICON_RANGE)
	_cheat("Or infini", &"inf_gold", "Les achats ne coûtent rien.", ICON_GOLD)
	_body.add_child(_heading("Partie"))
	_cheat("Minuterie arrêtée", &"freeze_time", "La difficulté vient de l'onglet Difficulté ; la minuterie de la partie ne tourne pas.", ICON_TIMER)
	var pz := _check("Pause à l'ouverture", TestMode.pause_on_open, func(on: bool) -> void:
		TestMode.set_flag(&"pause_on_open", on)
		overlay.sync_pause())
	_set_check_icon(pz, ICON_PAUSE)
	pz.name = "Check_pause_on_open"
	_body.add_child(pz)
	_body.add_child(_note("Sans pause, le jeu continue derrière le panneau (le déplacement reste actif)."))
	var acts := _grid(2)
	_body.add_child(acts)
	var heal := _btn("Soigner + recharges", func() -> void:
		TestTools.restore_player(get_tree())
		say("PV et recharges rendus."))
	_set_btn_icon(heal, ICON_HEAL)
	heal.name = "Restore"
	acts.add_child(_expand(heal))
	var gold := _btn("Or +1000", func() -> void:
		RunState.add_gold(1000.0)
		say("Or : %d." % int(RunState.gold)))
	_set_btn_icon(gold, ICON_GOLD)
	gold.name = "GoldPlus"
	acts.add_child(_expand(gold))


## Icône à gauche du texte d'un bouton (assets existants, 52 px) ; chemin absent : bouton sans icône.
func _set_btn_icon(b: Button, path: String) -> void:
	var t := TestThumbs.tex(path)
	if t == null:
		return
	b.icon = t
	b.expand_icon = true
	b.add_theme_constant_override(&"icon_max_width", 52)


func _set_check_icon(c: CheckButton, path: String) -> void:
	_set_btn_icon(c, path)


func _cheat(text: String, flag: StringName, note: String, icon_path: String = "") -> void:
	var c := _check(text, bool(TestMode.get(flag)), func(on: bool) -> void:
		TestMode.set_flag(flag, on)
		say("%s : %s." % [text, "oui" if on else "non"]))
	_set_check_icon(c, icon_path)
	c.name = "Check_%s" % flag
	_cheat_checks[flag] = c
	_body.add_child(c)
	_body.add_child(_note(note))


# --- Onglet Difficulté ---------------------------------------------------------------------

func _build_difficulty() -> void:
	_body.add_child(_heading("Difficulté D (PV et dégâts des monstres)"))
	_d_label = _label("", FS_BODY + 2, Color.WHITE)
	_d_label.name = "DLabel"
	var dhead := HBoxContainer.new()
	dhead.add_theme_constant_override(&"separation", 12)
	_d_icon = _icon(null, 72.0)
	dhead.add_child(_d_icon)
	_d_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_d_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dhead.add_child(_d_label)
	_body.add_child(dhead)
	_d_slider = HSlider.new()
	_d_slider.name = "DSlider"
	_d_slider.min_value = TestMode.D_MIN
	_d_slider.max_value = TestMode.D_MAX
	_d_slider.step = 0.05
	_d_slider.value = TestMode.d_value
	_d_slider.custom_minimum_size = Vector2(0, UiTheme.MIN_TOUCH)
	_d_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_d_slider.value_changed.connect(func(v: float) -> void:
		if not is_equal_approx(v, TestMode.d_value):
			TestMode.set_difficulty(v)
			_refresh_difficulty())
	_body.add_child(_d_slider)
	var steps := _grid(4)
	_body.add_child(steps)
	for st in [[-1.0, "−1"], [-0.25, "−0,25"], [0.25, "+0,25"], [1.0, "+1"]]:
		var s: float = st[0]
		steps.add_child(_expand(_btn(st[1], func() -> void:
			TestMode.set_difficulty(TestMode.d_value + s)
			_refresh_difficulty())))
	var presets := _grid(3)
	_body.add_child(presets)
	for pr in [[1.0, "D 1 (début)"], [3.0, "D 3 (étage 5 Moyen)"], [8.0, "D 8"]]:
		var v: float = pr[0]
		presets.add_child(_expand(_btn(pr[1], func() -> void:
			TestMode.set_difficulty(v)
			_refresh_difficulty())))
	_body.add_child(_note("Les monstres déjà présents gardent leurs PV : « Nettoyer » puis invoquez-les à nouveau."))
	_body.add_child(_heading("Valeurs de base à ce D (avant armure, plafond de coup)"))
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override(&"h_separation", 14)
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(table)
	table.add_child(_label("", FS_SMALL, COL_MUTED))
	table.add_child(_label("", FS_SMALL, COL_MUTED))
	table.add_child(_label("PV", FS_SMALL, COL_MUTED))
	table.add_child(_label("Dégâts / coup", FS_SMALL, COL_MUTED))
	var rows: Array = [["Nuée", 1, false], ["Tireur", 2, false], ["Brute", 3, false], ["Brute élite", 3, true]]
	for r in rows:
		_table_row(table, str(r[0]), str(r[0]))
	_table_row(table, "Mini-boss", "mini")
	_table_row(table, "Boss d'étage", "boss")
	_table_row(table, "Boss final", "final")
	_body.add_child(_note("Boss : étage de la partie (%d) ; le multiplicateur propre au boss n'est pas inclus." % RunState.stage))
	_body.add_child(_heading("Dégâts reçus par le joueur"))
	_body.add_child(_note("Les chiffres rouges s'affichent au-dessus du joueur, même avec PV illimités. Le coup est borné à %d %% des PV max (boss %d %%)." % [int(Balance.MAX_HIT_FRACTION * 100.0), int(Balance.MAX_HIT_FRACTION_BOSS * 100.0)]))
	_hits_label = _label("", FS_SMALL + 2)
	_hits_label.name = "HitsLabel"
	_hits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hits_label.custom_minimum_size = Vector2(300, 0)
	_body.add_child(_hits_label)
	var rst := _btn("Effacer le journal", func() -> void:
		overlay.reset_hits()
		_refresh_difficulty())
	rst.name = "ResetHits"
	_body.add_child(rst)
	_refresh_difficulty()


func _table_row(table: GridContainer, title: String, key: String) -> void:
	var th := TestThumbs.monster(_catalog_sample(key))
	table.add_child(_icon(th.tex, 52.0))
	table.add_child(_label(title, FS_SMALL + 2))
	var hp := _label("", FS_SMALL + 2, Color.WHITE)
	var dm := _label("", FS_SMALL + 2, Color.WHITE)
	table.add_child(hp)
	table.add_child(dm)
	_diff_labels[key] = [hp, dm]


func _refresh_difficulty() -> void:
	if _d_label == null:
		return
	var d := TestMode.d_value
	var tier_name := Balance.difficulty_tier_name(d)
	if _d_icon != null:
		var dn: String = DIFF_ICONS.get(tier_name, "")
		_d_icon.texture = TestThumbs.tex("res://assets/sprites/ui/difficulty/%s.png" % dn) if dn != "" else null
	_d_label.text = "D = %.2f · niveau des monstres %d · %s" % [d, Balance.monster_level(d), Balance.difficulty_tier_name(d)]
	if _d_slider != null and not is_equal_approx(_d_slider.value, d):
		_d_slider.set_value_no_signal(d)
	for key in _diff_labels:
		var st := _stats_for(String(key), d)
		var pair: Array = _diff_labels[key]
		(pair[0] as Label).text = _fmt(float(st.hp))
		(pair[1] as Label).text = _fmt(float(st.damage))
	if _hits_label != null and overlay != null:
		var lines: Array[String] = []
		lines.append("%d coup(s) · max %s · total %s" % [overlay.hit_count, _fmt(overlay.hit_max), _fmt(overlay.hit_total)])
		for h in overlay.hits:
			lines.append("−%s  %s" % [_fmt(float(h.amount)), h.source])
		_hits_label.text = "\n".join(lines)


## Entrée du catalogue qui illustre une ligne du tableau (premier du genre).
func _catalog_sample(key: String) -> Dictionary:
	var kind: StringName = &"tier"
	var tier := 1
	match key:
		"Nuée": tier = 1
		"Tireur": tier = 2
		"Brute", "Brute élite": tier = 3
		"mini": kind = &"mini"
		"boss": kind = &"boss"
		"final": kind = &"final"
	for e in _catalog:
		if e.kind == kind and (kind != &"tier" or (int(e.tier) == tier and int(e.variant) != Enemy.VARIANT_LEAPER)):
			return e
	return {}


func _stats_for(key: String, d: float) -> Dictionary:
	match key:
		"Nuée": return TestTools.base_stats({"kind": &"tier", "tier": 1}, d)
		"Tireur": return TestTools.base_stats({"kind": &"tier", "tier": 2}, d)
		"Brute": return TestTools.base_stats({"kind": &"tier", "tier": 3}, d)
		"Brute élite": return TestTools.base_stats({"kind": &"tier", "tier": 3}, d, true)
		"mini": return TestTools.base_stats({"kind": &"mini", "boss_id": &""}, d)
		"boss": return TestTools.base_stats({"kind": &"boss", "boss_id": &""}, d)
		"final": return TestTools.base_stats({"kind": &"final", "boss_id": &""}, d)
	return {"hp": 0.0, "damage": 0.0}


static func _fmt(v: float) -> String:
	if v >= 1.0e6:
		return "%.1f M" % (v / 1.0e6)
	if v >= 10000.0:
		return "%d k" % int(v / 1000.0)
	if v >= 100.0:
		return str(int(round(v)))
	return "%.1f" % v
