class_name SettingsPanel
extends VBoxContainer
## Panneau de réglages unique, réutilisé au titre (scenes/menu/settings.tscn) et dans la pause
## (docs/Design_Menus.md §3.4 et §5). Il ne stocke rien : il lit à l'ouverture (`sync`), écrit à
## chaque changement (Audio.set_volume, GameSettings.*) et se resynchronise sur
## Audio.volumes_changed / Quality.quality_changed. Rien n'est écrit en headless (GameSettings / Audio).
## Audit_Menus M11 : 4 onglets de 88 px (Audio · Affichage · Jeu · Accessibilité ; LB/RB à la manette),
## interrupteurs visuels 160×88 (toggle_on/off.png si livrés, sinon forme provisoire en code), plus de
## réglage « Style de rendu » (cel-shadé décidé).
## Ancien libellé "Afficher la hitbox" : renommé « Cercle de collision du héros » (M11, jargon).

signal back_requested
signal controls_requested

const ROW_H := 88.0
const TAB_H := 88.0
const ROW_GAP := 8
const TOGGLE_SIZE := Vector2(160, 88)
const TOGGLE_ON_TEX := "res://assets/sprites/ui/menu/toggle_on.png"
const TOGGLE_OFF_TEX := "res://assets/sprites/ui/menu/toggle_off.png"
const TABS := ["Audio", "Affichage", "Jeu", "Accessibilité"]
enum Tab { AUDIO, DISPLAY, GAME, ACCESS }
const VOLUME_ROWS := [["master", "Volume général"], ["music", "Musique"], ["sfx", "Effets"], ["ambience", "Ambiance"], ["ui", "Interface"]]
const QUALITY_ITEMS := ["Automatique", "Bas", "Moyen", "Haut"]
const FLASH_ITEMS := ["Aucun", "Réduits", "Complets"]
const DAMAGE_ITEMS := ["Petits", "Normaux", "Grands"]
const COLORBLIND_ITEMS := ["Aucun", "Deutéranopie", "Protanopie", "Tritanopie"]
const CHEST_REVEAL_ITEMS := ["Complète", "Courte", "Instantanée"] ## Balance.CHEST_REVEAL_MODES
const RETICLE_ITEMS := ["100 %", "150 %"] ## GameSettings.RETICLE_SCALES


## Interrupteur visuel (Audit_Menus M11) : piste + bouton glissant. Textures toggle_on/off.png (brief Codex
## _uxreglages) dès qu'elles existent ; sinon placeholder dessiné en code (provisoire, à remplacer).
class ToggleSwitch extends Button:
	var tex_on: Texture2D = null
	var tex_off: Texture2D = null

	func _init() -> void:
		toggle_mode = true
		flat = true # pas de fond de bouton : le focus reste dessiné par le thème
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = TOGGLE_SIZE
		if ResourceLoader.exists(TOGGLE_ON_TEX) and ResourceLoader.exists(TOGGLE_OFF_TEX):
			tex_on = load(TOGGLE_ON_TEX) as Texture2D
			tex_off = load(TOGGLE_OFF_TEX) as Texture2D
		toggled.connect(func(_on: bool) -> void: queue_redraw())

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var tex := tex_on if button_pressed else tex_off
		if tex != null:
			draw_texture_rect(tex, r, false)
			return
		# Placeholder : piste arrondie, bouton blanc à droite (activé, braise) ou à gauche (désactivé, gris).
		var th := size.y * 0.6
		var track := Rect2(Vector2(4.0, (size.y - th) * 0.5), Vector2(size.x - 8.0, th))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("#FFB347") if button_pressed else Color("#3A4250")
		sb.border_color = Color("#E8EEF8", 0.85)
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(int(th * 0.5))
		draw_style_box(sb, track)
		var kr := th * 0.5 - 6.0
		var kx := track.end.x - th * 0.5 if button_pressed else track.position.x + th * 0.5
		draw_circle(Vector2(kx, size.y * 0.5), kr, Color("#F4F6FA"))
		draw_arc(Vector2(kx, size.y * 0.5), kr, 0.0, TAU, 32, Color("#1A1E26"), 2.0)


var _syncing := false
var _title: Label
var _tab_bar: HBoxContainer
var _tab_buttons: Array[Button] = []
var _pages: Array[VBoxContainer] = []
var _page_rows: Array = [] ## par onglet : Array de [ligne, contrôle focalisable]
var _tab := Tab.AUDIO
var _scroll: ScrollContainer
var _box: VBoxContainer ## page en cours de construction
var _bottom: HBoxContainer
var _rows: Array[Control] = []
var _labels: Array[Label] = []
var _buttons: Array[Button] = []
var _toggles: Array[Button] = []
var _steppers: Array[OptionStepper] = []
var _sliders := {} ## clé de volume -> HSlider
var _pct := {} ## clé de volume -> Label
var _pct_labels: Array[Label] = [] ## pourcentages des curseurs hors volumes
var _quality: OptionStepper
var _flashes: OptionStepper
var _damage: OptionStepper
var _colorblind: OptionStepper
var _chest_reveal: OptionStepper ## « Animation des coffres » (GameSettings.chest_reveal)
var _reticle: OptionStepper ## « Taille du réticule » (PC)
var _fullscreen: Button
var _show_fps: Button
var _autocast: Button
var _haptics: Button
var _long_press: Button
var _key_hints: Button
var _overhead: Button ## barres au-dessus du personnage (GameSettings.overhead_bars)
var _show_hitbox: Button ## cercle de collision du héros (GameSettings.show_hitbox)
var _reduce_motion: Button ## « Réduire les mouvements » (GameSettings.reduce_motion)
var _hints: Button ## « Astuces de jeu » (GameSettings.hints, lot M-A)
var _strong_tel: Button ## « Télégraphes renforcés » (GameSettings.strong_telegraphs, lot A11y-L9)
var _mono: Button ## « Audio mono » (GameSettings.mono_audio)
var _shake: HSlider ## « Secousses de caméra » 0-100 % (GameSettings.shake_scale)
var _shake_pct: Label
var _haptic_strength: HSlider ## « Intensité des vibrations » 0-100 % (GameSettings.haptics_strength)
var _haptic_pct: Label
var _haptic_row: Control ## visible sur mobile ou quand une manette est branchée
var _haptics_row: Control
var _ui_scale: HSlider ## « Taille de l'interface » 80-150 % (GameSettings.ui_scale)
var _ui_scale_pct: Label
var _deadzone: HSlider ## « Zone morte des sticks » 10-35 % (GameSettings.stick_deadzone)
var _deadzone_pct: Label
var _deadzone_row: Control
var _joystick: HSlider ## « Taille du joystick » 80-150 % (GameSettings.joystick_scale)
var _joystick_pct: Label
var _joystick_row: Control
var _reticle_row: Control
var _run_log: Button ## « Journal de run » (RunLog.enabled, journal local des parties)
var _export_button: Button ## « Exporter les journaux » (RunLogExport)
var _export_label: Label
var _dialog: ConfirmDialog
var _reset_button: Button
var _controls_button: Button
var _back_button: Button


func _ready() -> void:
	add_theme_constant_override("separation", 20)
	_build()
	UiTheme.apply(self)
	UiTheme.hook_sounds(self)
	_apply_layout()
	sync()
	get_viewport().size_changed.connect(_apply_layout)
	visibility_changed.connect(_on_visibility_changed)
	if Audio.has_signal(&"volumes_changed"):
		Audio.volumes_changed.connect(_on_external_change)
	if Quality.has_signal(&"quality_changed"):
		Quality.quality_changed.connect(_on_external_change)


func _build() -> void:
	_title = Label.new()
	_title.text = "RÉGLAGES"
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_title)

	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.add_theme_constant_override("separation", 12)
	add_child(_tab_bar)
	var group := ButtonGroup.new()
	for i in TABS.size():
		var tb := Button.new()
		tb.text = TABS[i]
		tb.toggle_mode = true
		tb.button_group = group
		tb.custom_minimum_size = Vector2(0, TAB_H)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(show_tab.bind(i))
		_tab_bar.add_child(tb)
		_tab_buttons.append(tb)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(holder)
	for i in TABS.size():
		var page := VBoxContainer.new()
		page.name = "Page%d" % i
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", ROW_GAP)
		holder.add_child(page)
		_pages.append(page)
		_page_rows.append([])

	_page(Tab.AUDIO)
	for row in VOLUME_ROWS:
		_add_volume(row[0], row[1])
	_mono = _add_toggle("Audio mono", func(on: bool) -> void: GameSettings.set_mono_audio(on))

	_page(Tab.DISPLAY)
	_quality = _add_stepper("Qualité", QUALITY_ITEMS, func(i: int) -> void: GameSettings.set_quality(i - 1))
	if Platform.is_pc():
		_fullscreen = _add_toggle("Plein écran", func(on: bool) -> void: GameSettings.set_fullscreen(on))
	var us := _add_percent_slider("Taille de l'interface", func(v: float) -> void: GameSettings.set_ui_scale(v),
		GameSettings.UI_SCALE_MIN, GameSettings.UI_SCALE_MAX, 0.1)
	_ui_scale = us[0]
	_ui_scale_pct = us[1]
	_overhead = _add_toggle("Barres au-dessus du personnage", func(on: bool) -> void: GameSettings.set_overhead_bars(on))
	_key_hints = _add_toggle("Afficher les touches sous les sorts", func(on: bool) -> void: GameSettings.set_key_hints(on))
	_show_hitbox = _add_toggle("Cercle de collision du héros", func(on: bool) -> void: GameSettings.set_show_hitbox(get_tree(), on))
	_show_fps = _add_toggle("Afficher les FPS", func(on: bool) -> void: GameSettings.set_show_fps(on))

	_page(Tab.GAME)
	_autocast = _add_toggle("Sorts automatiques", func(on: bool) -> void: GameSettings.set_auto_cast(get_tree(), on))
	_chest_reveal = _add_stepper("Animation des coffres", CHEST_REVEAL_ITEMS,
		func(i: int) -> void: GameSettings.set_chest_reveal(String(Balance.CHEST_REVEAL_MODES[i])))
	_hints = _add_toggle("Astuces de jeu", func(on: bool) -> void: GameSettings.set_hints(on))
	_long_press = _add_toggle("Bouton pause : appui long", func(on: bool) -> void: GameSettings.set_pause_long_press(on))
	_haptics = _add_toggle("Vibrations", func(on: bool) -> void: GameSettings.set_haptics(on))
	_haptics_row = _rows[_rows.size() - 1]
	var hs := _add_percent_slider("Intensité des vibrations", func(v: float) -> void: GameSettings.set_haptics_strength(v))
	_haptic_strength = hs[0]
	_haptic_pct = hs[1]
	_haptic_row = hs[2]
	var dz := _add_percent_slider("Zone morte des sticks", func(v: float) -> void: GameSettings.set_stick_deadzone(v),
		GameSettings.DEADZONE_MIN, GameSettings.DEADZONE_MAX, 0.05)
	_deadzone = dz[0]
	_deadzone_pct = dz[1]
	_deadzone_row = dz[2]
	var js := _add_percent_slider("Taille du joystick", func(v: float) -> void: GameSettings.set_joystick_scale(v),
		GameSettings.JOYSTICK_SCALE_MIN, GameSettings.JOYSTICK_SCALE_MAX, 0.1)
	_joystick = js[0]
	_joystick_pct = js[1]
	_joystick_row = js[2]
	_reticle = _add_stepper("Taille du réticule", RETICLE_ITEMS,
		func(i: int) -> void: GameSettings.set_reticle_scale(float(GameSettings.RETICLE_SCALES[i])))
	_reticle_row = _rows[_rows.size() - 1]
	# Journal de run local (équilibrage par les données) : rien ne quitte l'appareil sans l'export volontaire.
	_run_log = _add_toggle("Journal de run", func(on: bool) -> void: RunLog.set_enabled(on))
	_export_button = MenuBtn.new()
	_export_button.text = "Exporter les journaux"
	_export_button.custom_minimum_size = Vector2(0, ROW_H)
	_export_button.pressed.connect(_export_logs)
	_add_row("Parties enregistrées", _export_button)
	_export_label = _labels[_labels.size() - 1]

	_page(Tab.ACCESS)
	_flashes = _add_stepper("Flashs", FLASH_ITEMS, func(i: int) -> void: GameSettings.set_flashes(i))
	var ss := _add_percent_slider("Secousses de caméra", func(v: float) -> void: GameSettings.set_shake(v))
	_shake = ss[0]
	_shake_pct = ss[1]
	_reduce_motion = _add_toggle("Réduire les mouvements", func(on: bool) -> void: GameSettings.set_reduce_motion(on))
	_strong_tel = _add_toggle("Télégraphes renforcés", func(on: bool) -> void:
		GameSettings.set_strong_telegraphs(on)
		EnemyTelegraph.refresh_strong()) # effet immédiat (sinon relu après STRONG_REFRESH_MS)
	_damage = _add_stepper("Taille des chiffres de dégâts", DAMAGE_ITEMS, func(i: int) -> void: GameSettings.set_damage_text_scale(float(GameSettings.DAMAGE_SCALES[i])))
	_colorblind = _add_stepper("Mode daltonien", COLORBLIND_ITEMS, func(i: int) -> void: GameSettings.set_colorblind(i))

	_bottom = HBoxContainer.new()
	_bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	_bottom.add_theme_constant_override("separation", 20)
	add_child(_bottom)
	_controls_button = _add_button("Commandes", func() -> void: controls_requested.emit())
	_reset_button = _add_button("Réinitialiser", _ask_reset)
	_back_button = _add_button("Retour", func() -> void: back_requested.emit())
	UiTheme.mark_back(_back_button)
	_controls_button.focus_neighbor_left = _back_button.get_path()
	_back_button.focus_neighbor_right = _controls_button.get_path()
	for i in _tab_buttons.size():
		var tb := _tab_buttons[i]
		tb.focus_neighbor_left = tb.get_path_to(_tab_buttons[(i - 1 + _tab_buttons.size()) % _tab_buttons.size()])
		tb.focus_neighbor_right = tb.get_path_to(_tab_buttons[(i + 1) % _tab_buttons.size()])
	show_tab(Tab.AUDIO, false)


func _page(t: int) -> void:
	_box = _pages[t]


func _add_row(text: String, control: Control, focus: Control = null, expand := true) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.add_theme_constant_override("separation", 20)
	var l := Label.new()
	l.text = text
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = 45.0
	row.add_child(l)
	if expand:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.size_flags_stretch_ratio = 55.0
	else:
		control.size_flags_horizontal = Control.SIZE_SHRINK_END
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	_box.add_child(row)
	_rows.append(row)
	_labels.append(l)
	(_page_rows[_pages.find(_box)] as Array).append([row, focus if focus != null else control])
	return row


func _add_volume(key: String, text: String) -> void:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 16)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.custom_minimum_size = Vector2(0, 64)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.value_changed.connect(func(v: float) -> void:
		_pct[key].text = "%d %%" % roundi(v * 100.0)
		if not _syncing:
			Audio.set_volume(key, v))
	if key == "ui":
		sl.drag_ended.connect(func(_changed: bool) -> void: Audio.play_ui(&"ui.click"))
	holder.add_child(sl)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(110, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(pct)
	_pct[key] = pct
	_sliders[key] = sl
	_add_row(text, holder, sl) # le focus va au curseur, pas au conteneur


## Ligne « curseur en % » (hors volumes), 0-100 % par pas de 10 par défaut. Retourne [HSlider, Label, ligne].
func _add_percent_slider(text: String, cb: Callable, lo := 0.0, hi := 1.0, step := 0.1) -> Array:
	var holder := HBoxContainer.new()
	holder.add_theme_constant_override("separation", 16)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.custom_minimum_size = Vector2(0, 64)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(sl)
	var pct := Label.new()
	pct.custom_minimum_size = Vector2(110, 0)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	holder.add_child(pct)
	sl.value_changed.connect(func(v: float) -> void:
		pct.text = "%d %%" % roundi(v * 100.0)
		if not _syncing:
			cb.call(v))
	var row := _add_row(text, holder, sl)
	_pct_labels.append(pct)
	return [sl, pct, row]


func _add_stepper(text: String, items: Array, cb: Callable) -> OptionStepper:
	var st := OptionStepper.new()
	st.custom_minimum_size = Vector2(0, ROW_H) # largeur libre : la ligne se partage 45/55
	st.wrap = true
	st.items = PackedStringArray(items)
	st.changed.connect(func(i: int) -> void:
		if not _syncing:
			cb.call(i))
	_add_row(text, st)
	_steppers.append(st)
	return st


func _add_toggle(text: String, cb: Callable) -> Button:
	var b := ToggleSwitch.new()
	b.tooltip_text = text
	b.toggled.connect(func(on: bool) -> void:
		if not _syncing:
			cb.call(on))
	_add_row(text, b, null, false)
	_toggles.append(b)
	return b


func _add_button(text: String, cb: Callable) -> Button:
	var b := MenuBtn.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 104)
	b.pressed.connect(cb)
	_bottom.add_child(b)
	_buttons.append(b)
	return b


# --- Onglets ---------------------------------------------------------------------------

## Affiche l'onglet `t` (Tab) ; `focus` : donne le focus au premier réglage (clavier / manette).
func show_tab(t: int, focus := true) -> void:
	_tab = clampi(t, 0, TABS.size() - 1) as Tab
	for i in _pages.size():
		_pages[i].visible = i == _tab
	_tab_buttons[_tab].set_pressed_no_signal(true)
	_style_tabs()
	_scroll.scroll_vertical = 0
	_update_conditional_rows()
	_link_focus()
	if focus and is_inside_tree() and Platform.input_mode != Platform.InputMode.TOUCH:
		var f := _first_focus()
		if f != null:
			f.grab_focus.call_deferred()


## Onglet courant en style primaire (sélection lisible), les autres au style par défaut du thème.
func _style_tabs() -> void:
	for i in _tab_buttons.size():
		var tb := _tab_buttons[i]
		if i == _tab:
			UiTheme.primary(tb)
		else:
			for k in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
				tb.remove_theme_stylebox_override(k)
			for c in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
				tb.remove_theme_color_override(c)


func current_tab() -> int:
	return _tab


func tab_buttons() -> Array[Button]:
	return _tab_buttons


## Contrôles focalisables visibles de l'onglet courant, dans l'ordre.
func _focusables() -> Array[Control]:
	var out: Array[Control] = []
	for e in _page_rows[_tab]:
		if (e[0] as Control).visible:
			out.append(e[1])
	return out


func _first_focus() -> Control:
	var f := _focusables()
	return f[0] if not f.is_empty() else _tab_buttons[_tab]


## Voisins de focus : onglet -> 1er réglage -> … -> dernier -> boutons du bas -> onglet.
func _link_focus() -> void:
	var f := _focusables()
	var tb := _tab_buttons[_tab]
	var first: Control = f[0] if not f.is_empty() else _controls_button
	var last: Control = f[f.size() - 1] if not f.is_empty() else tb
	for b in _tab_buttons:
		b.focus_neighbor_bottom = b.get_path_to(first)
		b.focus_neighbor_top = b.get_path_to(_controls_button)
	for i in f.size():
		f[i].focus_neighbor_top = f[i].get_path_to(f[i - 1] if i > 0 else tb)
		f[i].focus_neighbor_bottom = f[i].get_path_to(f[i + 1] if i < f.size() - 1 else _controls_button)
	for b in [_controls_button, _reset_button, _back_button]:
		b.focus_neighbor_top = b.get_path_to(last)
		b.focus_neighbor_bottom = b.get_path_to(tb)


## Lignes qui dépendent du matériel : vibrations (mobile ou manette), zone morte (manette ou PC),
## taille du joystick (écran tactile), réticule (PC).
func _update_conditional_rows() -> void:
	if _haptic_row == null:
		return
	var hv := haptics_row_visible()
	_haptic_row.visible = hv
	_haptics_row.visible = hv
	_deadzone_row.visible = Platform.is_pc() or not Input.get_connected_joypads().is_empty()
	_joystick_row.visible = Platform.has_touch()
	_reticle_row.visible = Platform.is_pc()


## Recopie l'état courant (Audio, Quality, joueur, GameSettings) dans les contrôles sans réécrire.
func sync() -> void:
	if _quality == null:
		return
	_syncing = true
	for key in _sliders:
		var v := Audio.get_volume(key)
		(_sliders[key] as HSlider).value = v
		(_pct[key] as Label).text = "%d %%" % roundi(v * 100.0)
	_quality.index = GameSettings.quality_choice() + 1
	_flashes.index = clampi(GameSettings.flashes_level(), 0, 2)
	_damage.index = GameSettings.damage_text_index()
	_colorblind.index = GameSettings.colorblind()
	_chest_reveal.index = maxi(Balance.CHEST_REVEAL_MODES.find(StringName(GameSettings.chest_reveal())), 0)
	_reticle.index = 1 if GameSettings.reticle_scale() > 1.25 else 0
	_set_toggle(_fullscreen, GameSettings.fullscreen())
	_set_toggle(_show_fps, GameSettings.show_fps())
	var p := get_tree().get_first_node_in_group(&"player") if is_inside_tree() else null
	_set_toggle(_autocast, bool(p.get(&"auto_cast_spells")) if p != null and "auto_cast_spells" in p else GameSettings.auto_cast())
	_set_toggle(_haptics, GameSettings.haptics())
	_set_toggle(_long_press, GameSettings.pause_long_press())
	_set_toggle(_key_hints, GameSettings.key_hints())
	_set_toggle(_overhead, GameSettings.overhead_bars())
	_set_toggle(_show_hitbox, GameSettings.show_hitbox())
	_set_toggle(_reduce_motion, GameSettings.reduce_motion())
	_set_toggle(_hints, GameSettings.hints())
	_set_toggle(_strong_tel, GameSettings.strong_telegraphs())
	_set_toggle(_mono, GameSettings.mono_audio())
	_set_toggle(_run_log, RunLog.enabled())
	_export_label.text = "Parties enregistrées : %d" % RunLog.list_logs().size()
	_set_slider(_shake, _shake_pct, GameSettings.shake_scale())
	_set_slider(_haptic_strength, _haptic_pct, GameSettings.haptics_strength())
	_set_slider(_ui_scale, _ui_scale_pct, GameSettings.ui_scale())
	_set_slider(_deadzone, _deadzone_pct, GameSettings.stick_deadzone())
	_set_slider(_joystick, _joystick_pct, GameSettings.joystick_scale())
	_update_conditional_rows()
	_link_focus()
	_syncing = false


func _set_slider(sl: HSlider, pct: Label, v: float) -> void:
	sl.value = v
	pct.text = "%d %%" % roundi(sl.value * 100.0)


## Intensité des vibrations : mobile, ou PC avec une manette branchée.
func haptics_row_visible() -> bool:
	return Platform.is_mobile() or not Input.get_connected_joypads().is_empty()


func shake_slider() -> HSlider:
	return _shake


func haptic_slider() -> HSlider:
	return _haptic_strength


func ui_scale_slider() -> HSlider:
	return _ui_scale


func deadzone_slider() -> HSlider:
	return _deadzone


func joystick_slider() -> HSlider:
	return _joystick


func reduce_motion_toggle() -> Button:
	return _reduce_motion


func flashes_stepper() -> OptionStepper:
	return _flashes


func chest_reveal_stepper() -> OptionStepper:
	return _chest_reveal


## Interrupteur par libellé (tests) ; null si absent.
func toggle(label: String) -> Button:
	for i in _rows.size():
		if _labels[i].text == label:
			for c in _rows[i].get_children():
				if c is ToggleSwitch:
					return c
	return null


## Libellés de toutes les lignes (tests).
func row_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for l in _labels:
		out.append(l.text)
	return out


func _set_toggle(b: Button, on: bool) -> void:
	if b != null:
		b.button_pressed = on
		b.queue_redraw()


func _on_external_change(_arg: Variant = null) -> void:
	if is_visible_in_tree():
		sync()


func _ask_reset() -> void:
	if _dialog != null and is_instance_valid(_dialog):
		return
	_dialog = ConfirmDialog.new()
	add_child(_dialog)
	var destructive: bool = await _dialog.ask("Réinitialiser", "Rétablir les réglages par défaut ?", "Annuler", "Rétablir")
	_dialog = null
	if destructive:
		_do_reset()
	elif Platform.input_mode != Platform.InputMode.TOUCH:
		_reset_button.grab_focus.call_deferred()


## Export volontaire des journaux de run (RunLogExport) : archive .zip, puis dossier ouvert (PC), feuille de
## partage (Android) ou app Fichiers (iOS) ; un dialogue dit où se trouve le fichier.
func _export_logs() -> void:
	if is_confirming():
		return
	var res := RunLogExport.export_and_show(RunLog.log_dir)
	var ok: bool = res["ok"]
	var title := "Journaux exportés" if ok else "Rien à exporter"
	var line: String = ("%d partie(s). " % int(res["count"]) if ok else "") + String(res.get("where", ""))
	var action := "OK"
	if ok:
		match OS.get_name():
			"Android":
				action = "Partager"
			"iOS":
				action = "Copier le chemin"
			_:
				action = "Ouvrir le dossier"
	_dialog = ConfirmDialog.new()
	add_child(_dialog)
	var again: bool = await _dialog.ask(title, line, "Fermer", action)
	_dialog = null
	if again and ok:
		match OS.get_name():
			"Android":
				RunLogExport._android_share(String(res["abs_path"]))
			"iOS":
				DisplayServer.clipboard_set(String(res["abs_path"]))
			_:
				OS.shell_show_in_file_manager(String(res["abs_path"]), true)
	if Platform.input_mode != Platform.InputMode.TOUCH and is_instance_valid(_export_button):
		_export_button.grab_focus.call_deferred()


func _do_reset() -> void:
	GameSettings.reset_all(get_tree())
	sync()


func is_confirming() -> bool:
	return _dialog != null and is_instance_valid(_dialog)


## Nombre de lignes de réglage (tests) : tous onglets confondus.
func rows() -> Array[Control]:
	return _rows


func slider(key: String) -> HSlider:
	return _sliders.get(key)


func quality_stepper() -> OptionStepper:
	return _quality


func focus_first() -> void:
	if Platform.input_mode != Platform.InputMode.TOUCH:
		var f := _first_focus()
		if f != null:
			f.grab_focus.call_deferred()


func _on_visibility_changed() -> void:
	if is_visible_in_tree():
		sync()
		_scroll.scroll_vertical = 0
		focus_first()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or is_confirming():
		return # le dialogue gère lui-même Échap / B
	if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
		var d := -1 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1
		Audio.play_ui(&"ui.click", -6.0, 1.0)
		show_tab((_tab + d + TABS.size()) % TABS.size())
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	Audio.play_ui(&"ui.click", -6.0, 0.85)
	back_requested.emit()
	get_viewport().set_input_as_handled()


## Échelle §2.1 : 1.0 sauf très petites fenêtres PC (min(vp) / 1080, plancher 0,55).
func _scale() -> float:
	var vp := get_viewport().get_visible_rect().size
	return clampf(minf(vp.x, vp.y) / 1080.0, 0.55, 1.0)


func _apply_layout() -> void:
	if _title == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var s := _scale()
	custom_minimum_size.x = minf(1200.0, vp.x - 96.0) * s
	add_theme_constant_override("separation", int(16 * s))
	_title.add_theme_font_size_override("font_size", int(64 * s))
	for tb in _tab_buttons:
		tb.add_theme_font_size_override("font_size", int(34 * s))
		tb.custom_minimum_size.y = TAB_H * s
	for l in _labels:
		l.add_theme_font_size_override("font_size", int(36 * s))
	for r in _rows:
		r.custom_minimum_size.y = ROW_H * s
	for key in _pct:
		(_pct[key] as Label).add_theme_font_size_override("font_size", int(30 * s))
	for pl in _pct_labels:
		pl.add_theme_font_size_override("font_size", int(30 * s))
	for b in _toggles:
		b.custom_minimum_size = TOGGLE_SIZE * s
	for st in _steppers:
		st.add_theme_font_size_override(&"font_size", int(34 * s))
	for b in _buttons:
		b.add_theme_font_size_override("font_size", int(40 * s))
		b.custom_minimum_size = Vector2(minf(380.0 * s, (custom_minimum_size.x - 40.0 * s) / 3.0), 104 * s)
	# hauteur de la liste : tient dans la zone sûre (Platform.safe_margins, comme le cadre qui l'accueille)
	# avec le titre, les onglets et les boutons du bas mesurés (l'ancienne estimation 0,95 × écran
	# débordait de ~40 px en 1280×720 et 800×600)
	var sm: Dictionary = Platform.safe_margins()
	var avail_h := vp.y - float(sm.get("top", 32.0)) - float(sm.get("bottom", 32.0)) - 8.0
	var others := _title.get_combined_minimum_size().y + _tab_bar.get_combined_minimum_size().y \
		+ _bottom.get_combined_minimum_size().y + 3.0 * int(16 * s)
	_scroll.custom_minimum_size.y = clampf(avail_h - others, 200.0, 760.0)
