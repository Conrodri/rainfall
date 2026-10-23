class_name PauseMenu
extends CanvasLayer
## Menu pause (process ALWAYS). Reprendre (compte a rebours 3 s si danger proche, 1 s sinon : Balance.RESUME_*), Reglages (SettingsPanel unifié,
## docs/Design_Menus.md §3.4), Objets (liste complète des items possédés avec leurs effets), Commandes
## (ControlsPanel), Sauvegarder et quitter (signal : main.gd sauvegarde puis revient au titre),
## Abandonner (confirmation), Quitter le jeu (hors iOS : sauvegarde puis ferme). Échap / B : retour au
## menu pause depuis un sous-panneau. Pause automatique sur perte de focus / mise en arriere-plan.

signal opened
signal resumed ## apres le compte a rebours (le joueur peut appliquer sa protection de 1,5 s)
signal abandon_requested
signal save_quit_requested ## « Sauvegarder et quitter » : la scene de jeu sauvegarde puis revient au titre
signal items_closed ## fin d'une consultation « Objets seuls » (open_items par-dessus un écran déjà en pause : coffre)

const ITEM_CELL_PX := 96.0 ## case d'objet de la grille (M14)
const ITEM_GAP_PX := 10.0
const ITEM_COLS_MAX := 8
const ITEM_COLS_MIN := 3
const DETAIL_H := 150.0 ## bandeau de détail sous la grille (nom, rareté, effet)
const QUALITY_ORDER: Array[StringName] = [&"legendaire", &"rare", &"peu_commun", &"commun"]
const QUALITY_WORDS := {&"commun": "Commun", &"peu_commun": "Peu commun", &"rare": "Rare", &"legendaire": "Légendaire"}
const PAD_LOST_TEXT := "Manette déconnectée"
const RELEASE_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "spell_2", "spell_3", "spell_4"]

var is_open := false
var items_only := false ## consultation des Objets sans le menu pause (écran de coffre) : Retour / Échap / B referme
var counting_down := false
var _count := 0.0
var _panel_main: VBoxContainer
var _panel_settings: SettingsPanel
var _panel_confirm: VBoxContainer
var _panel_controls: ControlsPanel
var _count_label: Label
var _root: Control
var _holder: Control
var _center: CenterContainer
var _wide_center: CenterContainer ## sous-panneaux larges : Réglages, Commandes
var _buttons: Array[Button] = []
var _titles: Array[Label] = []
var _quit_button: Button
var _bg: Panel ## fond opaque arrondi du panneau (menu principal et Objets)
var _info: Label ## chrono + étage de la run
var _grid: GridContainer ## boutons du menu principal (1 ou 2 colonnes selon la place)
var _pads: Array[VBoxContainer] = [] ## panneaux à marge interne
var _hint: Label
var _panel_items: VBoxContainer
var _items_scroll: ScrollContainer
var _items_box: GridContainer ## grille d'icônes (M14)
var _items_button: Button
var _items_back: Button
var _item_cells: Array[Button] = []
var _item_texts: Array = [] ## « nom ×N | effet » dans l'ordre de RunState.items (tests)
var _detail_name: Label
var _detail_effect: Label
var _resume_button: Button ## pleine largeur au-dessus de la grille
var _abandon_dialog: ConfirmDialog
var _current: Control ## panneau affiché (null pendant le compte à rebours)
var _controls_from: Control ## d'où l'on est venu vers Commandes (retour)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	add_to_group(&"pause_menu") # trouvé par l'écran de coffre (bouton Objets)
	InputSetup.pad_disconnected.connect(on_pad_disconnected) # E-11 (lot A11y-L6)
	_build()
	_root.visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	Platform.safe_area_changed.connect(_apply_layout) # encoche passée de côté sans redimensionnement (A11y-L4)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.82) # assombrit le jeu et le HUD derrière
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_center)
	var holder := Control.new()
	_holder = holder
	_center.add_child(holder)
	# Fond opaque arrondi du panneau (zone sûre respectée par _apply_layout)
	_bg = Panel.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var bgs: StyleBox = UiTheme.da_box("panel_9slice")
	_bg.add_theme_stylebox_override(&"panel", bgs if bgs != null else UiTheme._flat(Color("1a1620", 0.99), UiTheme.COL_BORDER, 3, 28))
	_bg.visible = false
	holder.add_child(_bg)
	_wide_center = CenterContainer.new()
	_wide_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_wide_center.visible = false
	_root.add_child(_wide_center)

	_panel_main = _make_panel(holder, "PAUSE")
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_color_override("font_color", UiTheme.COL_MUTED)
	_panel_main.add_child(_info)
	# Ordre (audit M4) : Reprendre pleine largeur, puis par paires en 2 colonnes
	# Objets · Réglages / Commandes · Sauvegarder et quitter / Abandonner · Quitter le jeu.
	# Abandonner (rouge) n'est jamais voisin d'un bouton fréquent ; Quitter le jeu absent sur iOS.
	_resume_button = _add_button(_panel_main, "Reprendre", _on_resume)
	_resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiTheme.primary(_resume_button)
	UiTheme.mark_confirm(_resume_button)
	_grid = GridContainer.new()
	_grid.columns = 1
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel_main.add_child(_grid)
	_items_button = _add_button(_grid, "Objets", func() -> void:
		_fill_items()
		_show_only(_panel_items))
	_add_button(_grid, "Réglages", func() -> void: _show_only(_panel_settings))
	_add_button(_grid, "Commandes", func() -> void:
		_controls_from = _panel_main
		_show_only(_panel_controls))
	_add_button(_grid, "Sauvegarder et quitter", _on_save_quit)
	var abandon := _add_button(_grid, "Abandonner", func() -> void: _show_only(_panel_confirm))
	_danger_style(abandon) # action destructive : rouge opaque (Design_Menus §3.7/§3.8)
	# Pas de bouton Quitter sur iOS (l'app ne se ferme pas elle-meme).
	if Platform.can_quit():
		_quit_button = _add_button(_grid, "Quitter le jeu", _on_quit_game)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_main.add_child(_hint)

	_panel_settings = SettingsPanel.new()
	_panel_settings.visible = false
	_wide_center.add_child(_panel_settings)
	_panel_settings.back_requested.connect(func() -> void: _show_only(_panel_main))
	_panel_settings.controls_requested.connect(func() -> void:
		_controls_from = _panel_settings
		_show_only(_panel_controls))

	_panel_controls = ControlsPanel.new()
	_panel_controls.visible = false
	_wide_center.add_child(_panel_controls)
	_panel_controls.back_requested.connect(func() -> void: _show_only(_controls_from if _controls_from != null else _panel_main))

	_panel_items = _make_panel(holder, "OBJETS")
	_items_scroll = ScrollContainer.new()
	_items_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_items_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_items.add_child(_items_scroll)
	_items_scroll.follow_focus = true # la manette fait défiler la grille
	_items_box = GridContainer.new()
	_items_box.columns = ITEM_COLS_MAX
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_scroll.add_child(_items_box)
	# Détail de l'objet sous focus / touché (divulgation progressive)
	_detail_name = Label.new()
	_detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_items.add_child(_detail_name)
	_detail_effect = Label.new()
	_detail_effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_items.add_child(_detail_effect)
	_items_back = _add_button(_panel_items, "Retour", func() -> void:
		if items_only:
			close_items()
		else:
			_show_only(_panel_main))
	UiTheme.mark_back(_items_back)

	# « Abandonner » : panneau vide dont l'affichage ouvre le ConfirmDialog (Design_Menus §3.7).
	_panel_confirm = VBoxContainer.new()
	_panel_confirm.visible = false
	holder.add_child(_panel_confirm)

	_count_label = Label.new()
	_count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 220)
	_count_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_count_label.add_theme_constant_override("outline_size", 16)
	_count_label.visible = false
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_count_label)
	UiTheme.apply(_root)
	UiTheme.hook_sounds(_root)


## Recopie l'état courant dans le panneau de réglages (compat. tests).
func _sync_settings() -> void:
	_panel_settings.sync()


## Écran « Commandes » : touches du mode d'entrée courant (ControlsPanel).
func _fill_controls() -> void:
	_panel_controls.refresh()


## Écran « Objets » (M14) : grille d'icônes 96 px triée par qualité (légendaire en tête) ; le nom, la rareté
## et l'effet de l'objet sous le focus / touché / survolé s'affichent dans le bandeau de détail.
func _fill_items() -> void:
	for c in _items_box.get_children():
		_items_box.remove_child(c)
		c.queue_free()
	_item_cells.clear()
	_item_texts.clear()
	var s := _scale()
	_items_box.columns = _item_cols(_layout())
	_items_box.add_theme_constant_override("h_separation", int(ITEM_GAP_PX * s))
	_items_box.add_theme_constant_override("v_separation", int(ITEM_GAP_PX * s))
	if RunState.items.is_empty():
		_item_texts.append("Aucun objet pour l'instant.")
		_items_box.columns = 1
		var l := Label.new()
		l.text = "Aucun objet pour l'instant."
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", int(32 * s))
		_items_box.add_child(l)
		_detail_name.text = ""
		_detail_effect.text = ""
	var ids: Array = RunState.items.keys()
	for id in ids:
		var it := ItemDB.get_item(id)
		var stacks := int(RunState.items[id])
		_item_texts.append("%s | %s" % [str(it.get("name", id)) + ("  ×%d" % stacks if stacks > 1 else ""), str(it.get("effect_text", ""))])
	var sorted: Array = ids.duplicate()
	sorted.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ra := _quality_rank(a)
		var rb := _quality_rank(b)
		if ra != rb:
			return ra < rb
		return ids.find(a) < ids.find(b))
	for id in sorted:
		var cell := _make_item_cell(id, int(RunState.items[id]), s)
		_items_box.add_child(cell)
		_item_cells.append(cell)
	_wire_item_focus()
	if not sorted.is_empty():
		_show_item_detail(sorted[0])
	_items_button.text = "Objets (%d)" % RunState.items.size()


func _quality_rank(id: Variant) -> int:
	var q := StringName(str(ItemDB.get_item(id).get("quality", "commun")))
	var r := QUALITY_ORDER.find(q)
	return r if r >= 0 else QUALITY_ORDER.size()


## Nombre de colonnes de la grille d'objets selon la largeur du panneau (3 à 8).
func _item_cols(L: Dictionary) -> int:
	var s: float = L.s
	var w: float = (L.size as Vector2).x - 2.0 * float(L.pad) - 20.0 * s # barre de défilement
	var cell := (ITEM_CELL_PX + ITEM_GAP_PX) * s
	return clampi(int((w + ITEM_GAP_PX * s) / cell), ITEM_COLS_MIN, ITEM_COLS_MAX)


## Case d'objet : icône dans son cadre de qualité, ×N en coin, cadre de focus visible (manette / clavier).
func _make_item_cell(id: Variant, stacks: int, s: float) -> Button:
	var it := ItemDB.get_item(id)
	var b := Button.new()
	b.custom_minimum_size = Vector2.ONE * ITEM_CELL_PX * s
	b.focus_mode = Control.FOCUS_ALL
	b.clip_text = true
	var empty := StyleBoxEmpty.new()
	for k in [&"normal", &"pressed", &"disabled"]:
		b.add_theme_stylebox_override(k, empty)
	b.add_theme_stylebox_override(&"hover", UiTheme._flat(Color(1, 1, 1, 0.08), Color(1, 1, 1, 0.0), 0, 10))
	b.add_theme_stylebox_override(&"focus", UiTheme._flat(Color(1, 0.7, 0.28, 0.18), UiTheme.COL_FOCUS, 5, 10))
	var icon_path: String = ItemBar.ITEM_ICON % String(id)
	var icon_tex: Texture2D = load(icon_path) as Texture2D if ResourceLoader.exists(icon_path) else null
	var frame_path: String = ItemBar.RARITY_FRAME % str(it.get("quality", "commun"))
	for tex in [icon_tex, load(frame_path) as Texture2D if ResourceLoader.exists(frame_path) else null]:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		t.texture = tex
		b.add_child(t)
	if icon_tex == null: # icône absente : initiales (provisoire)
		var f := Label.new()
		f.text = str(it.get("name", id)).left(2)
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		f.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		f.add_theme_font_size_override("font_size", int(32 * s))
		b.add_child(f)
	if stacks > 1:
		var n := Label.new()
		n.text = "×%d" % stacks
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		n.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		n.add_theme_font_size_override("font_size", int(26 * s))
		n.add_theme_color_override("font_outline_color", Color.BLACK)
		n.add_theme_constant_override("outline_size", 6)
		b.add_child(n)
	var on_sel := _show_item_detail.bind(id)
	b.focus_entered.connect(on_sel)
	b.mouse_entered.connect(on_sel)
	b.pressed.connect(on_sel) # tactile : un toucher affiche le détail
	return b


## Détail (nom coloré + ×N + mot de rareté, puis effet) de l'objet `id`.
func _show_item_detail(id: Variant) -> void:
	var it := ItemDB.get_item(id)
	var q := StringName(str(it.get("quality", "commun")))
	var stacks := int(RunState.items.get(id, 0))
	_detail_name.text = "%s%s  ·  %s" % [str(it.get("name", id)), "  ×%d" % stacks if stacks > 1 else "", QUALITY_WORDS.get(q, "Commun")]
	_detail_name.add_theme_color_override("font_color", ItemBar.QUALITY_COLORS.get(q, Color.WHITE))
	_detail_effect.text = str(it.get("effect_text", ""))


## Navigation manette / clavier explicite dans la grille ; bas de grille -> Retour.
func _wire_item_focus() -> void:
	var n := _item_cells.size()
	var cols := maxi(_items_box.columns, 1)
	for i in n:
		var b := _item_cells[i]
		var here := NodePath(".")
		b.focus_neighbor_left = b.get_path_to(_item_cells[i - 1]) if i % cols > 0 else here
		b.focus_neighbor_right = b.get_path_to(_item_cells[i + 1]) if i % cols < cols - 1 and i + 1 < n else here
		b.focus_neighbor_top = b.get_path_to(_item_cells[i - cols]) if i - cols >= 0 else here
		if i + cols < n:
			b.focus_neighbor_bottom = b.get_path_to(_item_cells[i + cols])
		elif i / cols < (n - 1) / cols:
			b.focus_neighbor_bottom = b.get_path_to(_item_cells[n - 1])
		else:
			b.focus_neighbor_bottom = b.get_path_to(_items_back)
	_items_back.focus_neighbor_left = NodePath(".")
	_items_back.focus_neighbor_right = NodePath(".")
	_items_back.focus_neighbor_bottom = NodePath(".")
	_items_back.focus_neighbor_top = _items_back.get_path_to(_item_cells[n - 1]) if n > 0 else NodePath(".")


## Texte des cases de l'écran « Objets » (tests) : « nom ×N | effet », dans l'ordre de RunState.items.
func items_texts() -> Array:
	return _item_texts.duplicate()


func _scale() -> float:
	return _layout().s


## Calcule la mise en page du panneau dans la zone sûre : colonnes (1 ou 2), échelle, tailles.
## Hauteur = titre + lignes d'info réelles (chrono, puis régénération si présente) + Reprendre (pleine largeur)
## + grille des autres boutons + aide clavier/manette (hors tactile) + écarts : audit M4 (« Quitter le jeu » débordait).
func _layout() -> Dictionary:
	var vp := get_viewport().get_visible_rect().size
	var sm: Dictionary = Platform.safe_margins()
	var avail := Vector2(vp.x - sm.left - sm.right, vp.y - sm.top - sm.bottom) - Vector2(32, 32)
	var n := 6 if Platform.can_quit() else 5 ## boutons de la grille (Reprendre est à part, pleine largeur)
	var s := clampf(minf(vp.x, vp.y) / 1080.0, 0.55, 1.0)
	var pad := 28.0
	var sep := 16.0
	var bh := 96.0
	var lines := 1 if _info == null else maxi(1, _info.text.count("\n") + 1)
	var head := 76.0 + 42.0 * lines ## titre + lignes d'info
	var hint := 40.0 if Platform.input_mode != Platform.InputMode.TOUCH else 0.0
	var kids := 4 + (1 if hint > 0.0 else 0) ## titre, info, Reprendre, grille, [aide]
	var cols := 1
	var need := 0.0
	# 1 colonne si elle tient à l'échelle réelle, sinon 2 colonnes, puis réduction (min 0,55)
	for c in [1, 2]:
		cols = c
		var rows := ceili(float(n) / c)
		need = 2.0 * pad + head + bh + rows * bh + (rows - 1) * sep + hint + (kids - 1) * sep + 8.0
		if need * s <= avail.y:
			break
	if need * s > avail.y:
		s = clampf(avail.y / need, 0.55, 1.0)
	var bw := minf((620.0 if cols == 1 else 520.0) * s, (avail.x - 2.0 * pad * s - (cols - 1) * sep * s) / cols)
	var gw := cols * bw + (cols - 1) * sep * s
	var pw := gw + 2.0 * pad * s
	return {"s": s, "cols": cols, "pad": pad * s, "sep": sep * s, "bh": bh * s, "bw": bw, "grid_w": gw,
		"size": Vector2(pw, need * s), "head": head * s, "sm": sm}


## Lignes affichées par l'écran « Commandes » (tests).
func controls_texts() -> Array:
	return _panel_controls.texts()


func _on_save_quit() -> void:
	_close()
	save_quit_requested.emit()


## « Quitter le jeu » : sauvegarde (même chemin que « Sauvegarder et quitter », traité de façon
## synchrone par main.gd) puis ferme l'application.
func _on_quit_game() -> void:
	_close()
	save_quit_requested.emit()
	Platform.quit_game()


func _make_panel(parent: Control, title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	_pads.append(v)
	var l := Label.new()
	l.text = title
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 64)
	_titles.append(l)
	v.add_child(l)
	parent.add_child(v)
	v.visible = false
	return v


func _add_button(parent: Control, text: String, cb: Callable) -> Button:
	var b := MenuBtn.new()
	b.text = text
	b.custom_minimum_size = Vector2(620, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 44)
	_opaque_style(b)
	b.pressed.connect(cb)
	_buttons.append(b)
	parent.add_child(b)
	return b


## Libellé à 44 px × s, réduit seulement s'il déborderait de la case (« Sauvegarder et quitter » en
## 2 colonnes à 520 px) : sinon le bouton s'élargit et la grille dépasse la largeur prévue.
func _fit_font(b: Button, fs: int, width: float) -> void:
	var font := b.get_theme_font(&"font")
	var sb := b.get_theme_stylebox(&"normal")
	var room := width - (sb.get_margin(SIDE_LEFT) + sb.get_margin(SIDE_RIGHT) if sb != null else 0.0)
	var floor_px := HudMetrics.floor_px()
	while font != null and fs > floor_px and font.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 1
	b.add_theme_font_size_override("font_size", fs)


## Style secondaire opaque (le thème par défaut est trop translucide sur le jeu en arrière-plan).
func _opaque_style(b: Button) -> void:
	UiTheme._override_button(b, UiTheme._btn_styles(false)) # boutons DA (opaques)


func _show_only(panel: Control) -> void:
	_current = panel
	if panel == _panel_confirm:
		_ask_abandon()
	elif _abandon_dialog != null:
		_abandon_dialog.queue_free()
		_abandon_dialog = null
	var wide := panel == _panel_settings or panel == _panel_controls
	for p in [_panel_main, _panel_settings, _panel_confirm, _panel_controls, _panel_items]:
		p.visible = (p == panel)
	_bg.visible = panel == _panel_main or panel == _panel_items
	_center.visible = not wide
	_wide_center.visible = wide
	_update_hint()
	# clavier / manette : focus sur le premier bouton pour naviguer sans souris
	# (Réglages / Commandes le font eux-mêmes à l'affichage)
	if panel == _panel_items and Platform.input_mode != Platform.InputMode.TOUCH:
		var first: Button = _item_cells[0] if not _item_cells.is_empty() else _items_back
		first.grab_focus.call_deferred()
	elif panel != null and not wide and Platform.input_mode != Platform.InputMode.TOUCH:
		for c in panel.get_children():
			if c is Button:
				(c as Button).grab_focus.call_deferred()
				break


func _update_hint() -> void:
	if _hint == null:
		return
	var key := "Echap" if Platform.input_mode != Platform.InputMode.GAMEPAD else "Start"
	_hint.text = "" if Platform.input_mode == Platform.InputMode.TOUCH else "%s : reprendre" % key
	_hint.visible = _hint.text != "" # masqué au tactile : ne prend plus de place (M4)


## Dimensions selon le ratio / la taille du viewport (portrait mobile, paysage PC, redimensionnement).
func _apply_layout() -> void:
	var L := _layout()
	var s: float = L.s
	var sm: Dictionary = L.sm
	var btn := Vector2(L.bw, L.bh)
	# la zone centrée est bornée par la zone sûre (encoche, barre de navigation)
	for c in [_center, _wide_center]:
		c.offset_left = sm.left
		c.offset_top = sm.top
		c.offset_right = -sm.right
		c.offset_bottom = -sm.bottom
	_grid.columns = L.cols
	_grid.add_theme_constant_override("h_separation", int(L.sep))
	_grid.add_theme_constant_override("v_separation", int(L.sep))
	for b in _buttons:
		b.custom_minimum_size = btn
		_fit_font(b, int(44 * s), btn.x)
	_resume_button.custom_minimum_size = Vector2(L.grid_w, L.bh) # Reprendre : toute la largeur de la grille
	for t in _titles:
		t.add_theme_font_size_override("font_size", int(56 * s))
	_info.add_theme_font_size_override("font_size", int(30 * s))
	_hint.add_theme_font_size_override("font_size", int(26 * s))
	for p in _pads:
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, int(L.pad))
		p.add_theme_constant_override("separation", int(L.sep))
	var sz: Vector2 = L.size
	# Objets : titre + grille (défilante) + détail (nom, effet) + Retour, 4 écarts
	var detail_h := DETAIL_H * s
	var scroll_h := maxf(sz.y - 2.0 * L.pad - 76.0 * s - detail_h - btn.y - 4.0 * L.sep, 120.0 * s)
	_items_scroll.custom_minimum_size = Vector2(sz.x - 2.0 * L.pad, scroll_h)
	_detail_name.add_theme_font_size_override("font_size", int(32 * s))
	_detail_effect.add_theme_font_size_override("font_size", int(26 * s))
	_detail_name.custom_minimum_size = Vector2(sz.x - 2.0 * L.pad, 44.0 * s)
	_detail_effect.custom_minimum_size = Vector2(sz.x - 2.0 * L.pad, detail_h - 44.0 * s)
	if _items_box.get_child_count() > 0 and not _item_cells.is_empty():
		_items_box.columns = _item_cols(L)
		_wire_item_focus()
	_count_label.add_theme_font_size_override("font_size", int(220 * s))
	_holder.custom_minimum_size = sz


func open() -> void:
	if is_open:
		return
	if get_tree().paused:
		return # deja en pause (coffre...) : ne pas empiler
	is_open = true
	counting_down = false
	for a in RELEASE_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)
	get_tree().paused = true
	_count_label.visible = false
	_root.visible = true
	_show_only(_panel_main)
	_items_button.text = "Objets (%d)" % RunState.items.size()
	var t := int(RunState.active_time_s)
	_info.text = "%02d:%02d  ·  Étage %d" % [t / 60, t % 60, RunState.stage]
	var regen := Hud.regen_summary(get_tree().get_first_node_in_group(&"player")) # taux PV / ressource (vague 3)
	if regen != "":
		_info.text += "\n" + regen
	_apply_layout()
	opened.emit()


## Ouvre directement l'écran « Objets » (pastille « +N » du HUD, bouton Objets de l'écran de coffre).
## En jeu : menu pause ouvert sur Objets (Retour -> menu pause). Arbre déjà en pause par un autre écran
## (coffre) : consultation seule, sans menu pause ; Retour / Échap / B referme (items_closed) sans toucher à la pause.
func open_items() -> void:
	if get_tree().paused and not is_open:
		items_only = true
		is_open = true
		counting_down = false
		_count_label.visible = false
		_root.visible = true
		_apply_layout()
		_fill_items()
		_show_only(_panel_items)
		return
	if not is_open:
		open()
	if not is_open or counting_down:
		return
	_fill_items()
	_show_only(_panel_items)


## Ferme la consultation « Objets seuls » ouverte par open_items() au-dessus d'un écran en pause.
func close_items() -> void:
	if not items_only:
		return
	items_only = false
	is_open = false
	_current = null
	_root.visible = false
	items_closed.emit()


func _on_resume() -> void:
	counting_down = true
	_count = resume_duration()
	_show_only(null)
	_count_label.visible = true
	_count_label.text = str(int(ceil(_count)))


## Durée du compte à rebours de reprise (M15) : 3 s si un danger est proche, 1 s sinon.
func resume_duration() -> float:
	return Balance.RESUME_COUNTDOWN_DANGER_S if danger_near() else Balance.RESUME_COUNTDOWN_CALM_S


## Danger proche du joueur : boss en vie, monstre à moins de RESUME_DANGER_MONSTER_U, ou projectile
## ennemi actif à moins de RESUME_DANGER_PROJECTILE_U. Pas de joueur (menu hors partie) : pas de danger.
func danger_near() -> bool:
	var tree := get_tree()
	var player := tree.get_first_node_in_group(&"player") as Node2D
	if player == null or not is_instance_valid(player):
		return false
	if not tree.get_nodes_in_group(&"bosses").is_empty():
		return true # le groupe ne contient que des boss vivants (retirés à la mort)
	var pp := player.global_position
	var mon_r2 := pow(Balance.RESUME_DANGER_MONSTER_U * Balance.UNIT_PX, 2.0)
	for e in tree.get_nodes_in_group(&"enemies"):
		var n := e as Node2D
		if n != null and n.is_inside_tree() and n.global_position.distance_squared_to(pp) < mon_r2:
			return true
	var scene := tree.current_scene
	var pool := scene.find_child("EnemyProjectiles", true, false) if scene != null else null
	if pool != null:
		var pr2 := pow(Balance.RESUME_DANGER_PROJECTILE_U * Balance.UNIT_PX, 2.0)
		for c in pool.get_children():
			var p := c as Node2D
			if p != null and p.get(&"active") == true and p.global_position.distance_squared_to(pp) < pr2:
				return true
	return false


func _ask_abandon() -> void:
	if _abandon_dialog != null:
		return
	var d := ConfirmDialog.new()
	_abandon_dialog = d
	add_child(d)
	var destructive: bool = await d.ask("Abandonner la run ?", "Les rubis déjà gagnés sont conservés.", "Annuler", "Abandonner")
	if _abandon_dialog != d:
		return # fermé entre-temps (autre panneau)
	_abandon_dialog = null
	if destructive:
		_on_abandon()
	else:
		_show_only(_panel_main)


func _on_abandon() -> void:
	_close()
	abandon_requested.emit()


func _close() -> void:
	is_open = false
	counting_down = false
	_root.visible = false
	_count_label.visible = false
	get_tree().paused = false


func _process(delta: float) -> void:
	if not counting_down:
		return
	_count -= delta
	if _count <= 0.0:
		_close()
		resumed.emit()
	else:
		_count_label.text = str(int(ceil(_count)))


func _unhandled_input(event: InputEvent) -> void:
	var back := event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")
	if not back or event.is_echo():
		return
	if _abandon_dialog != null:
		return # le dialogue gère Échap / B
	if items_only:
		close_items() # consultation par-dessus le coffre : on revient au coffre
		get_viewport().set_input_as_handled()
		return
	if is_open and not counting_down and _current != _panel_main and _current != null:
		# sous-panneau : Échap / B revient au menu pause (Commandes → d'où l'on vient)
		_show_only(_controls_from if _current == _panel_controls and _controls_from != null else _panel_main)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		if not is_open:
			open()
		elif not counting_down:
			_on_resume()
		get_viewport().set_input_as_handled()


## Manette débranchée en jouant au pad (audit E-11, lot A11y-L6) : pause (compte à rebours annulé) avec
## « Manette déconnectée » en tête du bandeau d'informations.
func on_pad_disconnected(_device: int) -> void:
	if not is_inside_tree() or not Platform.is_gamepad_mode():
		return
	if counting_down:
		counting_down = false
		_count_label.visible = false
		_show_only(_panel_main)
	elif not is_open:
		open()
	if is_open and not _info.text.begins_with(PAD_LOST_TEXT):
		_info.text = PAD_LOST_TEXT + "\n" + _info.text


func _exit_tree() -> void:
	if InputSetup.pad_disconnected.is_connected(on_pad_disconnected):
		InputSetup.pad_disconnected.disconnect(on_pad_disconnected)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if is_inside_tree():
			open()


## Style « danger » opaque (rouge #C23B12) pour Abandonner.
func _danger_style(b: Button) -> void:
	UiTheme._override_button(b, UiTheme._btn_styles(&"danger"))
	for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		b.add_theme_color_override(c, Color.WHITE)
