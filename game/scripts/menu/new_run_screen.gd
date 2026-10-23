class_name NewRunScreen
extends Control
## Écran « Nouvelle run » : sélection du personnage, fiche avec sorts et variantes, mode, départ.
## docs/Design_Menus.md §3.2 (+ MISE À JOUR du joueur). Mise en page calculée (base 1080 de haut,
## largeur 1920 à ≈ 2400), rien au-delà de x = 1920 en dur.
## Le focus sélectionne (audit M2) : clavier / manette, la fiche suit le focus, comme au toucher ; une seule carte
## paraît donc choisie. Parcourir un perso verrouillé le sélectionne aussi : « Commencer » est alors désactivé.
## Mode choisi = fond braise + coche ; verrouillé = cadenas (audit M3). Tous les textes font au moins 18 px.

signal start_requested(config: Dictionary)
signal back_requested

const MODES: Array[StringName] = [&"facile", &"moyen", &"difficile"]
const MODE_NAMES := {&"facile": "Facile", &"moyen": "Moyen", &"difficile": "Difficile"}
const CARD_GAP := 16.0 ## entre cartes (la sélectionnée grossit de 8 %)
const MAIN_Y := 140.0 ## haut de la zone cartes / panneau (sous le bandeau de titre)
const BANNER_SIZE := Vector2(560, 84)
const PANEL_GAP := 40.0
const MAX_INSET := 160.0
const MODE_Y := 880.0
const MODE_SIZE := Vector2(290, 96)
const MODE_GAP := 16.0
const BACK_SIZE := Vector2(240, 96)
const START_SIZE := Vector2(600, 120)

## Profil (autoload `Profile` par défaut ; un objet factice peut être injecté avant _ready).
var profile: Object
var characters: Array = []
var cards: Array[CharacterCard] = []
var mode_buttons: Dictionary = {} ## StringName -> Button
var mode_labels: Dictionary = {}
var start_button: Button
var start_reason: Label
var back_button: Button
var sheet: CharacterSheet
var tooltip: SpellTooltip
var hint: Label
var title_label: Label
var side_panel: Panel ## plaque DA derrière le panneau du personnage (visible aussi tant que la fiche est fermée)
var grid_cols := 4
var _banner: PanelContainer
var selected_index := 0
var mode: StringName = &"moyen"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if profile == null:
		profile = CharacterCard.default_profile()
	if characters.is_empty(): # une liste peut être injectée avant _ready (tests)
		characters = CharacterCard.load_characters()
	_build()
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	resized.connect(_layout)
	_layout()
	var last := String(CharacterCard.pget(profile, "last_character", "ardent"))
	selected_index = 0
	for i in characters.size():
		if String(characters[i].get("id", "")) == last:
			selected_index = i
	_select_character(selected_index, true, false) # fiche du perso présélectionné visible tout de suite (PC, tactile, manette)
	var lm := StringName(String(CharacterCard.pget(profile, "last_mode", "moyen")))
	_set_mode(lm if (lm in MODES and CharacterCard.is_mode_unlocked(profile, lm)) else &"moyen", false)
	_wire_focus()
	var plat := get_node_or_null("/root/Platform")
	if plat != null and plat.has_signal("input_mode_changed"):
		plat.input_mode_changed.connect(func(_m: int) -> void: _apply_focus_for_mode())
	_apply_focus_for_mode()
	CharacterCard.play_ui(&"ui.hover", -4.0, 1.15)


func _apply_focus_for_mode() -> void:
	if _touch_mode():
		var f := get_viewport().gui_get_focus_owner()
		if f != null and is_ancestor_of(f):
			f.release_focus()
	elif get_viewport().gui_get_focus_owner() == null and not cards.is_empty():
		cards[selected_index].grab_focus.call_deferred()


func _touch_mode() -> bool:
	var plat := get_node_or_null("/root/Platform")
	return plat != null and bool(plat.call("is_touch_mode"))


# --- Construction ----------------------------------------------------------------

func _build() -> void:
	add_child(CharacterCard.make_backdrop())
	var bn := CharacterCard.make_banner("Nouvelle run")
	_banner = bn.banner
	title_label = bn.label
	add_child(_banner)
	for i in characters.size():
		var c: Dictionary = characters[i]
		var card := CharacterCard.new()
		card.setup(c, CharacterCard.is_character_locked(profile, c))
		card.pressed.connect(_on_card_pressed.bind(i))
		card.focus_entered.connect(_on_card_focused.bind(i))
		add_child(card)
		cards.append(card)
	side_panel = Panel.new()
	side_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sp := UiTheme.da_box("panel_9slice", 0.5)
	side_panel.add_theme_stylebox_override("panel", sp if sp != null else CharacterCard.panel_box(Color("#1a1620"), CharacterCard.COL_BORDER, 2, 0.9, false))
	add_child(side_panel)
	hint = CharacterCard.make_label("Choisissez un personnage pour afficher sa fiche et ses sorts.", 32, Color(0.8, 0.82, 0.86))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	tooltip = SpellTooltip.new()
	sheet = CharacterSheet.new()
	sheet.profile = profile
	sheet.tooltip = tooltip
	sheet.visible = false
	sheet.option_chosen.connect(func(_s: int, _id: StringName) -> void:
		_remember_loadout()
		_wire_focus())
	add_child(sheet)
	for m in MODES:
		var b := Button.new()
		b.name = "Mode_" + String(m)
		b.text = MODE_NAMES[m]
		b.custom_minimum_size = MODE_SIZE
		b.size = MODE_SIZE
		b.add_theme_font_size_override("font_size", 40)
		b.pressed.connect(_on_mode_pressed.bind(m))
		add_child(b)
		mode_buttons[m] = b
		var l := CharacterCard.make_label(_mode_sub(m), 20, Color(0.85, 0.86, 0.9), 5)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # légende longue : 2 lignes plutôt que de déborder
		l.size = Vector2(MODE_SIZE.x + MODE_GAP, 56)
		add_child(l)
		mode_labels[m] = l
	back_button = Button.new()
	back_button.name = "Back"
	back_button.text = "Retour"
	back_button.custom_minimum_size = BACK_SIZE
	back_button.size = BACK_SIZE
	back_button.add_theme_font_size_override("font_size", 40)
	back_button.pressed.connect(_on_back)
	UiTheme.mark_back(back_button)
	add_child(back_button)
	start_button = Button.new()
	start_button.name = "Start"
	start_button.text = "Commencer"
	start_button.custom_minimum_size = START_SIZE
	start_button.size = START_SIZE
	start_button.add_theme_font_size_override("font_size", 44)
	start_button.pressed.connect(_on_start)
	UiTheme.primary(start_button)
	UiTheme.mark_confirm(start_button)
	add_child(start_button)
	start_reason = CharacterCard.make_label("", 26, Color(0.85, 0.86, 0.9))
	start_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(start_reason)
	add_child(tooltip) # au-dessus de tout


## Légende en clair sous chaque mode (plus de « Scaling ×2 ») : ressenti + effet sur les rubis.
func _mode_sub(m: StringName) -> String:
	if not CharacterCard.is_mode_unlocked(profile, m):
		return "Terminez une run en Moyen"
	var pct := int(round((float(Balance.RUBY_MODE_MULT[m]) - 1.0) * 100.0))
	var feel := {&"facile": "Plus doux", &"moyen": "Normal", &"difficile": "Plus dur"}.get(m, "") as String
	if pct == 0:
		return feel
	return "%s · rubis %s%d %%" % [feel, "+" if pct > 0 else "−", absi(pct)]


func _layout() -> void:
	var vs := size if size.x > 0 else get_viewport_rect().size
	var m := _margins()
	_banner.position = Vector2(m.left, 24)
	_banner.size = BANNER_SIZE
	_banner.size = Vector2(BANNER_SIZE.x, maxf(_banner.size.y, 1.0))
	var bottom: float = vs.y - m.bottom
	var mode_y := minf(880.0, bottom - MODE_SIZE.y - 30.0)
	var main_y := maxf(MAIN_Y, _banner.position.y + _banner.size.y + 16.0)
	var main_h := mode_y - 16.0 - main_y
	var avail_w: float = vs.x - m.left - m.right
	# Gauche : grille de cartes verticales (ratio du cadre) ; droite : panneau du personnage sélectionné.
	var panel_w := clampf(avail_w * 0.40, 600.0, 920.0) # 40 % (audit M7) : cartes plus grandes
	var grid_w := avail_w - panel_w - PANEL_GAP
	var ratio := 384.0 / 560.0
	var best_h := 0.0
	var n := maxi(cards.size(), 1)
	for cols in range(2, n + 1):
		var rows := ceili(float(n) / cols)
		var inner_w := grid_w - 2.0 * 0.04 * grid_w / cols # marge pour la carte sélectionnée (+8 %)
		var h := minf((main_h - (rows - 1) * CARD_GAP - 16.0) / rows, (inner_w - (cols - 1) * CARD_GAP) / cols / ratio)
		if h > best_h + 0.5:
			best_h = h
			grid_cols = cols
	var ch := maxf(best_h, 120.0)
	var cw := ch * ratio
	var rows_n := ceili(float(n) / grid_cols)
	var used_w := grid_cols * cw + (grid_cols - 1) * CARD_GAP
	var gx: float = m.left + (grid_w - used_w) * 0.5
	var gy := main_y + 8.0 + maxf((main_h - 16.0 - (rows_n * ch + (rows_n - 1) * CARD_GAP)) * 0.5, 0.0)
	for i in cards.size():
		var r := i / grid_cols
		var c := i % grid_cols
		cards[i].set_card_size(Vector2(cw, ch))
		cards[i].position = Vector2(gx + c * (cw + CARD_GAP), gy + r * (ch + CARD_GAP))
	var px: float = vs.x - m.right - panel_w
	side_panel.position = Vector2(px, main_y)
	side_panel.size = Vector2(panel_w, main_h)
	sheet.position = Vector2(px, main_y)
	sheet.size = Vector2(panel_w, main_h)
	sheet.custom_minimum_size = Vector2(panel_w, 0)
	hint.position = Vector2(px + 48.0, main_y)
	hint.size = Vector2(panel_w - 96.0, main_h)
	back_button.position = Vector2(m.left, bottom - BACK_SIZE.y)
	# Barre du bas adaptative : Retour | 3 modes | Commencer, rétrécie si la zone sûre est étroite.
	var avail: float = vs.x - m.left - m.right - BACK_SIZE.x - 48.0
	var start_w := clampf(avail - 3 * MODE_SIZE.x - 2 * MODE_GAP, 420.0, START_SIZE.x)
	var mode_w := clampf((avail - start_w - 2 * MODE_GAP) / 3.0, 200.0, MODE_SIZE.x)
	var mx: float = m.left + BACK_SIZE.x + 24
	for i in MODES.size():
		var b: Button = mode_buttons[MODES[i]]
		b.custom_minimum_size = Vector2(mode_w, MODE_SIZE.y)
		b.size = b.custom_minimum_size
		b.position = Vector2(mx + i * (mode_w + MODE_GAP), mode_y)
		var l: Label = mode_labels[MODES[i]]
		l.size = Vector2(mode_w + MODE_GAP, 56)
		l.position = Vector2(b.position.x - MODE_GAP * 0.5, mode_y + MODE_SIZE.y + 4)
	start_button.custom_minimum_size = Vector2(start_w, START_SIZE.y)
	start_button.size = start_button.custom_minimum_size
	start_button.position = Vector2(vs.x - m.right - start_w, bottom - START_SIZE.y)
	start_reason.position = Vector2(start_button.position.x, start_button.position.y - 36)
	start_reason.size = Vector2(start_w, 32)


func _margins() -> Dictionary:
	var plat := get_node_or_null("/root/Platform")
	if plat != null and plat.has_method("safe_margins"):
		var d: Dictionary = plat.call("safe_margins")
		# Borné à MAX_INSET : l'aperçu mobile sur PC multi-écran peut renvoyer des insets aberrants.
		return {"left": clampf(d.get("left", 48), 48, MAX_INSET), "right": clampf(d.get("right", 48), 48, MAX_INSET),
			"top": clampf(d.get("top", 32), 32, MAX_INSET), "bottom": clampf(d.get("bottom", 32), 32, MAX_INSET)}
	return {"left": 48.0, "right": 48.0, "top": 32.0, "bottom": 32.0}


# --- Sélection ---------------------------------------------------------------

func _on_card_pressed(i: int) -> void:
	if cards[i].locked:
		CharacterCard.play_ui(&"ui.click", -8.0, 0.7)
	_select_character(i, true)


## Le focus (clavier, manette, ou clic qui prend le focus) sélectionne le personnage.
func _on_card_focused(i: int) -> void:
	_select_character(i, true)


func _select_character(i: int, open_sheet: bool, animate := true) -> void:
	# Fiche déjà ouverte pour ce perso : on ne la reconstruit pas (garde les variantes choisies, évite le double fondu).
	var same_sheet := sheet.visible and String(sheet.character.get("id", "")) == String(characters[i].get("id", ""))
	selected_index = i
	for j in cards.size():
		cards[j].selected = j == i
	var c: Dictionary = characters[i]
	var locked := cards[i].locked
	start_button.disabled = locked
	start_reason.text = "Personnage verrouillé" if locked else ""
	if open_sheet and not same_sheet:
		open_sheet_for(i, animate)


## Ouvre (ou rafraîchit) la fiche du personnage `i`.
func open_sheet_for(i: int, animate := true) -> void:
	hint.visible = false
	sheet.visible = true
	sheet.open(characters[i], cards[i].locked, animate)
	UiTheme.hook_sounds(sheet)
	_wire_focus()


func is_sheet_open() -> bool:
	return sheet.visible


func _on_mode_pressed(m: StringName) -> void:
	if not CharacterCard.is_mode_unlocked(profile, m):
		CharacterCard.play_ui(&"ui.click", -8.0, 0.7)
		tooltip.show_for(mode_buttons[m], MODE_NAMES[m], "Mode verrouillé", "Terminez une run en Moyen pour débloquer ce mode.")
		return
	_set_mode(m, true)
	tooltip.hide_tip()
	if not _touch_mode() and not start_button.disabled:
		start_button.grab_focus()


func _set_mode(m: StringName, user: bool) -> void:
	mode = m
	if user:
		_wire_focus()
	for k in MODES:
		var b: Button = mode_buttons[k]
		var unlocked := CharacterCard.is_mode_unlocked(profile, k)
		var sel := k == m
		# StyleBoxFlat franc (pas le 9-slice DA, qui écrasait la couleur) : choisi = fond braise opaque + liseré blanc
		# + coche + texte blanc ; verrouillé = fond éteint + cadenas + texte gris (jamais la seule opacité).
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#C23B12") if sel else (CharacterCard.COL_PANEL if unlocked else Color("#1c1f26"))
		sb.border_color = Color.WHITE if sel else (CharacterCard.COL_BORDER if unlocked else Color(0.38, 0.4, 0.45))
		sb.set_border_width_all(4 if sel else 2)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 60.0 if (sel or not unlocked) else 16.0 # place pour la coche / le cadenas
		sb.content_margin_right = 16.0
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_stylebox_override("focus", CharacterCard.focus_box())
		var tc := Color.WHITE if sel else (CharacterCard.COL_TEXT if unlocked else CharacterCard.COL_GREY)
		for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(cn, tc)
		b.text = MODE_NAMES[k]
		b.modulate = Color.WHITE
		var old := b.get_node_or_null("StateIcon")
		if old != null:
			b.remove_child(old)
			old.queue_free()
		if sel or not unlocked:
			var holder := Control.new()
			holder.name = "StateIcon"
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.anchor_top = 0.5
			holder.anchor_bottom = 0.5
			holder.offset_left = 14.0
			holder.offset_right = 54.0
			holder.offset_top = -20.0
			holder.offset_bottom = 20.0
			holder.add_child(CharacterCard.make_check_icon(40.0, Color.WHITE) if sel else CharacterCard.make_lock_icon(40.0, CharacterCard.COL_GREY))
			b.add_child(holder)


func _on_start() -> void:
	if start_button.disabled or cards[selected_index].locked:
		return
	var c: Dictionary = characters[selected_index]
	var cid := StringName(String(c.get("id", "")))
	var spells := {}
	if sheet.character.get("id", "") == c.get("id", "") and not sheet.chosen.is_empty():
		spells = sheet.chosen_spells()
	else:
		spells = CharacterSheet.resolve_loadout(profile, c) # choix mémorisé (variantes débloquées) sinon base
	if profile != null and profile.has_method(&"set_loadout"):
		profile.call(&"set_loadout", cid, spells)
	if profile != null:
		if "last_mode" in profile:
			profile.set("last_mode", mode)
		if "last_character" in profile:
			profile.set("last_character", cid)
	start_requested.emit({"character": cid, "mode": mode, "spells": spells})


func _on_back() -> void:
	back_requested.emit()


## Mémorise dans le profil les sorts choisis sur la fiche ouverte (par personnage, restaurés à l'ouverture).
func _remember_loadout() -> void:
	var cid := StringName(str(sheet.character.get("id", "")))
	if cid != &"" and not sheet.locked and profile != null and profile.has_method(&"set_loadout"):
		profile.call(&"set_loadout", cid, sheet.chosen_spells())


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if tooltip.visible:
			tooltip.hide_tip()
		else:
			CharacterCard.play_ui(&"ui.click", -6.0, 0.85)
			_on_back()
	elif event is InputEventScreenTouch and event.pressed and tooltip.visible:
		# Tactile : un appui ailleurs referme l'infobulle ouverte par appui long.
		var a := tooltip.anchor_control
		if a == null or not a.get_global_rect().has_point(event.position):
			tooltip.hide_tip()


# --- Focus (clavier / manette), §2.2 -------------------------------------------

func _np(from: Control, to: Control) -> NodePath:
	return from.get_path_to(to)


func _wire_focus() -> void:
	if cards.is_empty():
		return
	var rows: Array = sheet.focus_rows() if sheet.visible else []
	var top_row: Array = []
	var bottom_row: Array = []
	if rows.size() >= 1:
		top_row = rows.slice(0, mini(2, rows.size()))
		bottom_row = rows.slice(2) if rows.size() > 2 else top_row
	var first_opt: Control = rows[0][0] if rows.size() > 0 else null
	var last_opt: Control = bottom_row[0][0] if bottom_row.size() > 0 else first_opt
	var n := cards.size()
	for i in n:
		var c := cards[i]
		c.focus_neighbor_left = _np(c, cards[(i - 1 + n) % n])
		c.focus_neighbor_right = _np(c, cards[(i + 1) % n])
		# grille : haut / bas entre rangées, puis fiche (ou modes) depuis la dernière rangée
		c.focus_neighbor_top = _np(c, cards[i - grid_cols] if i >= grid_cols else c)
		var down: Control
		if i / grid_cols < (n - 1) / grid_cols:
			down = cards[mini(i + grid_cols, n - 1)]
		else:
			down = first_opt if first_opt != null else mode_buttons[MODES[clampi((i % grid_cols) * 3 / grid_cols, 0, 2)]]
		c.focus_neighbor_bottom = _np(c, down)
		c.focus_next = _np(c, cards[(i + 1) % n])
		c.focus_previous = _np(c, cards[(i - 1 + n) % n])
	# Fiche : grille 2×2 de blocs ; gauche/droite dans une rangée de blocs, haut/bas entre rangées.
	for r in rows.size():
		var btns: Array = rows[r]
		var col := r % 2
		var line := r / 2
		var left_block: Array = rows[r - 1] if col == 1 else []
		var right_block: Array = rows[r + 1] if col == 0 and r + 1 < rows.size() else []
		for k in btns.size():
			var b: Control = btns[k]
			var left: Control = btns[k - 1] if k > 0 else (left_block.back() if not left_block.is_empty() else b)
			var right: Control = btns[k + 1] if k + 1 < btns.size() else (right_block[0] if not right_block.is_empty() else b)
			b.focus_neighbor_left = _np(b, left)
			b.focus_neighbor_right = _np(b, right)
			var up: Control
			var down: Control
			if line == 0:
				up = cards[selected_index]
			else:
				var above: Array = rows[r - 2]
				up = above[mini(k, above.size() - 1)]
			if r + 2 < rows.size():
				var below: Array = rows[r + 2]
				down = below[mini(k, below.size() - 1)]
			else:
				down = mode_buttons[mode]
			b.focus_neighbor_top = _np(b, up)
			b.focus_neighbor_bottom = _np(b, down)
	# Modes, Retour, Commencer.
	for i in MODES.size():
		var b: Button = mode_buttons[MODES[i]]
		b.focus_neighbor_left = _np(b, mode_buttons[MODES[i - 1]] if i > 0 else back_button)
		b.focus_neighbor_right = _np(b, mode_buttons[MODES[i + 1]] if i < MODES.size() - 1 else start_button)
		var up_m: Control = last_opt if last_opt != null else cards[mini(n - 1, ((n - 1) / grid_cols) * grid_cols + i * grid_cols / 3)]
		b.focus_neighbor_top = _np(b, up_m)
		b.focus_neighbor_bottom = _np(b, start_button)
	back_button.focus_neighbor_right = _np(back_button, mode_buttons[&"facile"])
	back_button.focus_neighbor_top = _np(back_button, mode_buttons[&"facile"])
	back_button.focus_neighbor_left = _np(back_button, back_button)
	back_button.focus_neighbor_bottom = _np(back_button, back_button)
	start_button.focus_neighbor_left = _np(start_button, mode_buttons[&"difficile"])
	start_button.focus_neighbor_top = _np(start_button, mode_buttons[mode])
	start_button.focus_neighbor_right = _np(start_button, start_button)
	start_button.focus_neighbor_bottom = _np(start_button, start_button)
