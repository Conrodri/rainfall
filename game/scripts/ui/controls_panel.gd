class_name ControlsPanel
extends VBoxContainer
## Sous-panneau « Commandes » (docs/Design_Menus.md §3.5, audit E-01 lot A11y-L5) : trois onglets
## Clavier · Manette · Tactile (Tactile seulement si Platform.has_touch()), onglet initial = mode d'entrée courant.
## Clavier et Manette : une ligne par action remappable (InputSetup.REMAP_ACTIONS) avec ses emplacements
## (InputSetup.SLOTS_KBM / SLOTS_PAD) et un bouton « Défaut » ; lignes d'information pour ce qui ne se remappe
## pas (sort 1, visée, pause, déplacement au stick). Un emplacement pressé écoute pendant LISTEN_S secondes :
## Échap / Start annule, Suppr efface l'emplacement (s'il en reste un autre) ; conflit dans le même groupe =
## échange (InputSetup.rebind). « Tout par défaut » remet toutes les liaisons. Tactile : lecture seule.

signal back_requested

const TABS := [["Clavier", 1], ["Manette", 2], ["Tactile", 0]] ## [libellé, Platform.InputMode]
const LISTEN_S := 5.0
const InputLabels := preload("res://scripts/ui/input_labels.gd")
const COL_KEY := Color(1.0, 0.85, 0.5)
const COL_HEAD := Color(0.66, 0.7, 0.75)

var tab_mode: int = 1 ## mode affiché
var _title: Label
var _tabs_row: HBoxContainer
var _tab_buttons := {} ## mode -> MenuBtn
var _scroll: ScrollContainer
var _list: VBoxContainer
var _status: Label
var _bottom: HBoxContainer
var _reset_all: MenuBtn
var _back: MenuBtn
var _slot_buttons := {} ## action -> [Button] (onglet courant)
var _reset_buttons := {} ## action -> Button
var _listen := {} ## {"action", "device", "slot", "t"} pendant l'écoute, {} sinon
var _note := "" ## dernier message (échange, effacement)


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	_title = Label.new()
	_title.text = "COMMANDES"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)
	_tabs_row = HBoxContainer.new()
	_tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs_row.add_theme_constant_override("separation", 16)
	add_child(_tabs_row)
	var group := ButtonGroup.new()
	for t in TABS:
		var mode: int = t[1]
		if mode == Platform.InputMode.TOUCH and not Platform.has_touch():
			continue
		var b := MenuBtn.new()
		b.text = t[0]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(300, 88)
		b.pressed.connect(func() -> void: show_mode(mode))
		_tabs_row.add_child(b)
		_tab_buttons[mode] = b
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", COL_KEY)
	add_child(_status)
	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_bottom)
	_reset_all = MenuBtn.new()
	_reset_all.text = "Tout par défaut"
	_reset_all.pressed.connect(func() -> void:
		_cancel_listen()
		InputSetup.reset(&"", _device())
		_note = "Liaisons %s remises par défaut." % ("de la manette" if _device() == "pad" else "du clavier et de la souris")
		_refresh_slots())
	_bottom.add_child(_reset_all)
	_back = MenuBtn.new()
	_back.text = "Retour"
	_back.pressed.connect(func() -> void:
		_cancel_listen()
		back_requested.emit())
	_bottom.add_child(_back)
	UiTheme.mark_back(_back)
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh()
		else:
			_cancel_listen())
	Platform.input_mode_changed.connect(_on_mode_changed)
	get_viewport().size_changed.connect(_apply_layout)
	refresh()


func _exit_tree() -> void:
	if Platform.input_mode_changed.is_connected(_on_mode_changed):
		Platform.input_mode_changed.disconnect(_on_mode_changed)


func _on_mode_changed(_m: int) -> void:
	if is_visible_in_tree() and _listen.is_empty():
		refresh()


## Réaffiche l'onglet du mode d'entrée courant (ouverture du panneau, changement de mode).
func refresh() -> void:
	var mode := Platform.input_mode
	if not _tab_buttons.has(mode):
		mode = Platform.InputMode.KBM
	show_mode(mode)
	if mode in _tab_buttons and Platform.input_mode != Platform.InputMode.TOUCH and is_visible_in_tree():
		(_tab_buttons[mode] as Button).grab_focus.call_deferred()


func _device() -> String:
	return "pad" if tab_mode == Platform.InputMode.GAMEPAD else "kbm"


func show_mode(mode: int) -> void:
	_cancel_listen()
	tab_mode = mode
	_note = ""
	for m in _tab_buttons:
		(_tab_buttons[m] as Button).set_pressed_no_signal(m == mode)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_slot_buttons.clear()
	_reset_buttons.clear()
	if mode == Platform.InputMode.TOUCH:
		for row in InputLabels.controls_help(Platform.InputMode.TOUCH):
			_add_info(row[0], row[1])
	elif mode == Platform.InputMode.GAMEPAD:
		_add_info("Déplacement", "Stick gauche / croix")
		_add_info("Visée des sorts 2-4", "Stick droit (sinon ennemi le plus proche)")
		_add_info("Sort 1", "Automatique")
		_add_info("Pause", "%s (fixe)" % InputLabels.pad_button_label(JOY_BUTTON_START))
		_add_head("Sorts et actions")
		for r in InputSetup.REMAP_ACTIONS:
			if r[2] == "jeu" and r[3]:
				_add_remap_row(r[0], "pad")
		_add_head("Coffre")
		for r in InputSetup.REMAP_ACTIONS:
			if r[2] == "coffre":
				_add_remap_row(r[0], "pad")
	else:
		_add_info("Sort 1", "Automatique")
		_add_info("Visée des sorts 2-4", "Souris (curseur)")
		_add_info("Pause", "Échap (fixe)")
		_add_head("Déplacement")
		for r in InputSetup.REMAP_ACTIONS:
			if String(r[0]).begins_with("move_"):
				_add_remap_row(r[0], "kbm")
		_add_head("Sorts et actions")
		for r in InputSetup.REMAP_ACTIONS:
			if r[2] == "jeu" and not String(r[0]).begins_with("move_"):
				_add_remap_row(r[0], "kbm")
		_add_head("Coffre")
		for r in InputSetup.REMAP_ACTIONS:
			if r[2] == "coffre":
				_add_remap_row(r[0], "kbm")
	_reset_all.visible = mode != Platform.InputMode.TOUCH
	UiTheme.hook_sounds(_list)
	_refresh_slots()
	_apply_layout()


func _add_info(key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	var k := _label(key, COL_KEY)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.size_flags_stretch_ratio = 0.9
	var v := _label(value, Color.WHITE)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_stretch_ratio = 1.6
	row.add_child(k)
	row.add_child(v)
	_list.add_child(row)


func _add_head(text: String) -> void:
	var l := _label(text, COL_HEAD)
	l.set_meta(&"head", true)
	_list.add_child(l)


func _label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col)
	return l


func _add_remap_row(action: StringName, device: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_l := _label(InputSetup.action_title(action), COL_KEY)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.set_meta(&"name", true)
	row.add_child(name_l)
	var btns: Array = []
	for i in InputSetup.slot_count(device):
		var b := Button.new()
		b.focus_mode = Control.FOCUS_ALL
		b.clip_text = true
		b.set_meta(&"slot", true)
		var slot := i
		b.pressed.connect(func() -> void: start_listen(action, device, slot))
		row.add_child(b)
		btns.append(b)
	var rst := Button.new()
	rst.text = "Défaut"
	rst.focus_mode = Control.FOCUS_ALL
	rst.set_meta(&"reset", true)
	rst.pressed.connect(func() -> void:
		_cancel_listen()
		InputSetup.reset(action, device)
		_note = "« %s » remis par défaut." % InputSetup.action_title(action)
		_refresh_slots())
	row.add_child(rst)
	_slot_buttons[action] = btns
	_reset_buttons[action] = rst
	_list.add_child(row)


## Textes des emplacements (liaisons courantes), état des boutons « Défaut », ligne d'état.
func _refresh_slots() -> void:
	var dev := _device()
	for action in _slot_buttons:
		var binds: Array = InputSetup.bindings(action, dev)
		var btns: Array = _slot_buttons[action]
		for i in btns.size():
			var b: Button = btns[i]
			if not _listen.is_empty() and _listen["action"] == action and _listen["slot"] == i:
				b.text = "… %d" % int(ceil(float(_listen["t"])))
			else:
				b.text = InputLabels.event_label(binds[i]) if i < binds.size() else "—"
			b.icon = _icon_for(binds[i]) if i < binds.size() else null
		(_reset_buttons[action] as Button).disabled = InputSetup.is_default(action, dev)
	_reset_all.disabled = _all_default(dev)
	if not _listen.is_empty():
		_status.text = "« %s » : appuyez sur %s (%s : annuler%s)." % [InputSetup.action_title(_listen["action"]),
			"un bouton ou une gâchette" if dev == "pad" else "une touche ou un bouton de souris",
			"Start" if dev == "pad" else "Échap", "" if dev == "pad" else ", Suppr : effacer"]
	elif tab_mode == Platform.InputMode.TOUCH:
		_status.text = ""
	else:
		_status.text = _note if _note != "" else "Choisissez un emplacement pour changer sa liaison."


## Icône d'invite de l'emplacement (manette : selon la famille, gâchettes comprises ; souris).
func _icon_for(ev: InputEvent) -> Texture2D:
	var file := ""
	if ev is InputEventMouseButton:
		file = KeyPrompt.MOUSE_ICONS.get((ev as InputEventMouseButton).button_index, "")
	elif ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		file = InputLabels.pad_icon(ev)
	return KeyPrompt._tex(file) if file != "" else null


func _all_default(dev: String) -> bool:
	for r in InputSetup.REMAP_ACTIONS:
		if not InputSetup.is_default(r[0], dev):
			return false
	return true


## Met un emplacement en écoute (LISTEN_S secondes).
func start_listen(action: StringName, device: String, slot: int) -> void:
	_listen = {"action": action, "device": device, "slot": slot, "t": LISTEN_S}
	_note = ""
	_refresh_slots()


func is_listening() -> bool:
	return not _listen.is_empty()


func _cancel_listen() -> void:
	if _listen.is_empty():
		return
	_listen = {}
	if _list != null:
		_refresh_slots()


func _process(delta: float) -> void:
	if _listen.is_empty():
		return
	_listen["t"] = float(_listen["t"]) - delta
	if float(_listen["t"]) <= 0.0:
		_note = "Délai écoulé : liaison inchangée."
		_cancel_listen()
	else:
		_refresh_slots()


func _input(event: InputEvent) -> void:
	if _listen.is_empty() or not is_visible_in_tree():
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		return
	if handle_listen_event(event):
		get_viewport().set_input_as_handled()


## Traite un événement pendant l'écoute (public pour les tests). Retourne true s'il est consommé.
func handle_listen_event(event: InputEvent) -> bool:
	if _listen.is_empty():
		return false
	var dev: String = _listen["device"]
	var pressed := false
	if event is InputEventKey:
		pressed = (event as InputEventKey).pressed and not event.is_echo()
	elif event is InputEventMouseButton or event is InputEventJoypadButton:
		pressed = event.is_pressed()
	elif event is InputEventJoypadMotion:
		var jm := event as InputEventJoypadMotion
		pressed = absf(jm.axis_value) > 0.6
		if not pressed or not InputSetup.is_bindable(event, "pad"):
			return dev == "pad" # stick / gâchette à peine enfoncée : ignorés
	if not pressed:
		return true
	var action: StringName = _listen["action"]
	var slot: int = _listen["slot"]
	# annulation : Échap (clavier) ou Start (manette), quel que soit l'onglet
	if (event is InputEventKey and _code(event) == KEY_ESCAPE) or \
			(event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_START):
		_note = "Liaison inchangée."
		_cancel_listen()
		return true
	if dev == "kbm" and event is InputEventKey and _code(event) == KEY_DELETE:
		_note = "Emplacement effacé." if InputSetup.clear_slot(action, dev, slot) else "Il faut garder au moins une liaison."
		_cancel_listen()
		return true
	if not InputSetup.is_bindable(event, dev):
		if dev == "pad" and event is InputEventMouseButton:
			_cancel_listen() # clic ailleurs pendant l'écoute de la manette : on abandonne
		elif InputSetup.device_of(event) == dev:
			_note = "Cette touche est réservée."
		return true
	var ev := event.duplicate() as InputEvent
	_listen = {}
	var other := InputSetup.rebind(action, dev, slot, ev)
	_note = "Échangé avec « %s »." % InputSetup.action_title(other) if other != &"" else ""
	_refresh_slots()
	return true


static func _code(event: InputEvent) -> Key:
	var k := event as InputEventKey
	return k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode


## Textes affichés, dans l'ordre (libellés, emplacements, en-têtes ; tests).
func texts() -> Array:
	var out: Array = []
	_collect(_list, out)
	return out


func _collect(n: Node, out: Array) -> void:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Label:
			out.append((c as Label).text)
		elif c is Button:
			out.append((c as Button).text)
		else:
			_collect(c, out)


## Texte de l'emplacement `slot` d'une action dans l'onglet courant (tests).
func slot_text(action: StringName, slot: int) -> String:
	if not _slot_buttons.has(action):
		return ""
	return (_slot_buttons[action][slot] as Button).text


func slot_button(action: StringName, slot: int) -> Button:
	return _slot_buttons[action][slot] if _slot_buttons.has(action) else null


func tab_modes() -> Array:
	return _tab_buttons.keys()


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and _listen.is_empty() and event.is_action_pressed("ui_cancel"):
		Audio.play_ui(&"ui.click", -6.0, 0.85)
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _apply_layout() -> void:
	if _title == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var s := clampf(minf(vp.x, vp.y) / 1080.0, 0.55, 1.0)
	var floor_px := 26 if Platform.is_mobile() else 18 # plancher de taille de texte (contrat UX)
	var fpx := func(px: float) -> int: return maxi(int(px * s), floor_px)
	custom_minimum_size.x = minf(1400.0, vp.x - 96.0) * s
	add_theme_constant_override("separation", int(16 * s))
	_title.add_theme_font_size_override("font_size", fpx.call(64))
	for m in _tab_buttons:
		var b: Button = _tab_buttons[m]
		b.custom_minimum_size = Vector2(minf(300.0 * s, (custom_minimum_size.x - 32.0 * s) / 3.0), 88 * s)
		b.add_theme_font_size_override("font_size", fpx.call(40))
	for b in [_back, _reset_all]:
		(b as Button).custom_minimum_size = Vector2(420 * s, 96 * s)
		(b as Button).add_theme_font_size_override("font_size", fpx.call(38))
	_bottom.add_theme_constant_override("separation", int(24 * s))
	_status.add_theme_font_size_override("font_size", fpx.call(28))
	_list.add_theme_constant_override("separation", int(4 * s))
	var w := custom_minimum_size.x - 24.0 * s
	var slot_w := w * (0.19 if tab_mode == Platform.InputMode.KBM else 0.25)
	var row_h := maxf(60.0 * s, 64.0 if Platform.is_mobile() else 56.0)
	for row in _list.get_children():
		if row is Label:
			(row as Label).add_theme_font_size_override("font_size", fpx.call(28))
			continue
		for c in row.get_children():
			if c is Label:
				(c as Label).add_theme_font_size_override("font_size", fpx.call(32))
				c.custom_minimum_size.y = row_h if c.has_meta(&"name") else 0.0
			elif c is Button:
				var b := c as Button
				b.add_theme_font_size_override("font_size", fpx.call(30))
				b.add_theme_constant_override("icon_max_width", int(row_h * 0.6))
				b.expand_icon = false
				b.custom_minimum_size = Vector2(slot_w if b.has_meta(&"slot") else 150.0 * s, row_h)
	_scroll.custom_minimum_size.y = clampf(vp.y * 0.9 - (64 + 88 + 96 + 40 + 90) * s, 200.0, 760.0)
