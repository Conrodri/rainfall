class_name TitleScreen
extends Node
## Écran titre (docs/Design_Menus.md §3.1). Racine = Node : le fond animé (MenuBackground, canvas racine,
## éclairé et étalonné) puis l'UI sur un CanvasLayer 10 (au-dessus de l'étalonnage de l'ambiance).
## Les confirmations (« Remplacer la run en cours ? », « Quitter Rainfall ? ») sont gérées ici :
## `new_run_requested` (si une sauvegarde existe) et `quit_requested` ne sont émis qu'après confirmation.
## Audit_Menus M9/M16 : plus d'icône Réglages (doublon du bouton), invites sans « — », version seule ;
## après la 1re run, « Jouer » porte « Ardent · Moyen » et un appui long (0,6 s) ou [Y] relance directement.
## Premier lancement : avertissement de photosensibilité (Audit_Entrees_Accessibilite §3.3), une seule fois.

signal resume_requested
signal new_run_requested
signal progress_requested
signal settings_requested
signal credits_requested
## Mode test (À RETIRER OU MASQUER AVANT LA SORTIE) : arène d'invocation, triches ; rien n'est écrit au profil.
signal test_mode_requested
signal quit_requested
signal quick_start_requested(config: Dictionary) ## {character, mode, spells} : relance du dernier personnage

const BG_SCENE := preload("res://scenes/menu/menu_background.tscn")
const LOGO_PATHS := ["res://assets/sprites/ui/menu/logo.png", "res://assets/sprites/ui/menu/logo_rainfall.png"]
const RUBY_PATHS := ["res://assets/sprites/ui/menu/ruby_large.png", "res://assets/sprites/ui/hud/icon_ruby.png"]
const UI_LAYER := 10
const COL_X := 96.0
const MAIN_SIZE := Vector2(720, 120)
const SUB_SIZE := Vector2(620, 96)
const GAP := 16.0
const DARK := Color("#050810")
const TEXT := Color("#E8EEF8")
const GOLD := Color("#FFE9A8")
const EMBER := Color("#FFB347")
const MODE_NAMES := {"facile": "Facile", "moyen": "Moyen", "difficile": "Difficile"}
const QUICK_HOLD_S := 0.6 ## appui long sur « Jouer » = relancer le dernier personnage (E-08 : 0,6 s)
const VERSION_FONT := 22
const VERSION_ALPHA := 0.6
const PHOTO_TITLE := "Avertissement de photosensibilité"
const PHOTO_TEXT := "Ce jeu contient des éclairs, des flashs lumineux et des secousses d'écran. Chez certaines personnes, ils peuvent provoquer des crises d'épilepsie. Vous pouvez les réduire maintenant, ou plus tard dans Réglages > Accessibilité."
const PHOTO_REDUCED_SHAKE := 0.3 ## secousses à 30 % si le joueur choisit de réduire (flashs « Réduits »)

## Tests : remplace RunSave (Callable -> Dictionary, vide = pas de sauvegarde).
var summary_provider := Callable()
## Tests : simule iOS (pas de bouton Quitter).
var ios_override := false
## Avertissement de photosensibilité au premier lancement. Désactivé en headless et en capture vidéo (les tests
## et captures des autres lots ne le voient pas) ; un test l'active avec un fichier de réglages injecté.
var photosensitivity_enabled := DisplayServer.get_name() != "headless" and Engine.get_write_movie_path() == ""
## Tests : remplace Profile pour le raccourci « relancer » (objet avec stats, last_character, last_mode).
var profile_override: Object = null

var background: MenuBackground
var ui: CanvasLayer
var root: Control
var has_save := false
var summary: Dictionary = {}
var main_button: MenuBtn
var new_run_button: Button
var progress_button: Button
var settings_button: Button
var credits_button: Button
var quit_button: Button
var ruby_label: Label
var toast_label: Label
var hints_label: Label
var dialog: ConfirmDialog

var _gradient: Gradient
var _column: Control
var _logo: Control
var _version: Label
var _ruby_box: HBoxContainer
var _buttons: Array[Button] = []
var _toast_tween: Tween
var _dialog_open := false
var quick_config: Dictionary = {} ## config de relance (vide : pas de raccourci)
var _hold_t := -1.0 ## durée d'appui sur le bouton principal (-1 : relâché)
var _hold_fired := false


func _ready() -> void:
	background = BG_SCENE.instantiate() as MenuBackground
	background.name = "Background"
	add_child(background)
	_build_ui()
	refresh()
	background.setup(_background_map_id())
	if Audio.current_map_id() != "menu":
		Audio.start_map("menu")
	Audio.play_ui(&"ui.hover", -4.0, 1.15)
	Platform.input_mode_changed.connect(_on_input_mode_changed)
	Platform.safe_area_changed.connect(_layout) # encoche passée de côté sans redimensionnement (A11y-L4)
	if Profile.has_signal(&"changed"):
		Profile.connect(&"changed", refresh)
	_apply_mode()
	if photosensitivity_enabled and not GameSettings.photosensitivity_seen():
		show_photosensitivity_warning.call_deferred()


func _background_map_id() -> String:
	var id := String(summary.get("map_id", ""))
	return id if id != "" else MenuBackground.daily_map_id()


# --- Construction -------------------------------------------------------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "UI"
	ui.layer = UI_LAYER
	add_child(ui)
	root = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	ui.add_child(root)
	UiTheme.apply(root)

	# Lisibilité : dégradé #050810 α0,78 -> α0,15 sur les 1100 premiers px.
	var shade := TextureRect.new()
	shade.name = "Shade"
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_gradient = Gradient.new()
	_gradient.colors = PackedColorArray([Color(DARK, 0.78), Color(DARK, 0.15)])
	var gt := GradientTexture2D.new()
	gt.gradient = _gradient
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	gt.width = 512
	gt.height = 4
	shade.texture = gt
	root.add_child(shade)

	_logo = _make_logo()
	root.add_child(_logo)
	_version = Label.new()
	_version.text = "Version %s" % str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
	_style_label(_version, VERSION_FONT, TEXT, 4)
	_version.modulate.a = VERSION_ALPHA
	root.add_child(_version)

	_column = Control.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_column)

	_build_top_right()

	hints_label = Label.new()
	hints_label.name = "Hints"
	hints_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hints_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(hints_label, 28, TEXT, 6)
	root.add_child(hints_label)

	toast_label = Label.new()
	toast_label.name = "Toast"
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.visible = false
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(toast_label, 32, GOLD, 7)
	var tp := StyleBoxFlat.new()
	tp.bg_color = Color("#2B3340", 0.9)
	tp.set_corner_radius_all(12)
	tp.content_margin_left = 28
	tp.content_margin_right = 28
	tp.content_margin_top = 10
	tp.content_margin_bottom = 12
	toast_label.add_theme_stylebox_override(&"normal", tp)
	root.add_child(toast_label)

	root.resized.connect(_layout)


func _make_logo() -> Control:
	for p in LOGO_PATHS:
		if ResourceLoader.exists(p):
			var tr := TextureRect.new()
			tr.name = "Logo"
			tr.texture = load(p) as Texture2D
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			return tr
	# Placeholder texte tant que le logo Blender n'existe pas.
	var l := Label.new()
	l.name = "Logo"
	l.text = "Rainfall"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_label(l, 168, Color("#DCE6F5"), 12)
	l.add_theme_color_override(&"font_shadow_color", Color(0.37, 0.45, 0.56, 0.55))
	l.add_theme_constant_override(&"shadow_offset_y", 6)
	return l


func _build_top_right() -> void:
	_ruby_box = HBoxContainer.new()
	_ruby_box.name = "Rubies"
	_ruby_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ruby_box.add_theme_constant_override(&"separation", 12)
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(64, 64)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p in RUBY_PATHS:
		if ResourceLoader.exists(p):
			icon.texture = load(p) as Texture2D
			break
	_ruby_box.add_child(icon)
	ruby_label = Label.new()
	ruby_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ruby_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_label(ruby_label, 40, GOLD, 7)
	_ruby_box.add_child(ruby_label)
	root.add_child(_ruby_box)


# --- Données -------------------------------------------------------------------

func _read_summary() -> Dictionary:
	if summary_provider.is_valid():
		var s: Variant = summary_provider.call()
		return s if typeof(s) == TYPE_DICTIONARY else {}
	if RunSave.exists():
		var s2: Variant = RunSave.summary()
		return s2 if typeof(s2) == TYPE_DICTIONARY else {}
	return {}


static func format_summary(s: Dictionary) -> String:
	if s.is_empty():
		return ""
	var secs := int(float(s.get("active_time_s", 0.0)))
	var mode := String(s.get("mode", "moyen"))
	return "%s · Étage %d · %s · %02d:%02d" % [String(s.get("character_name", "Ardent")), int(s.get("stage", 1)),
		MODE_NAMES.get(mode, mode.capitalize()), secs / 60, secs % 60]


## Relit RunSave.summary() et Profile.rubies, reconstruit la colonne de boutons.
func refresh() -> void:
	if root == null:
		return
	summary = _read_summary()
	has_save = not summary.is_empty()
	ruby_label.text = _format_int(int(Profile.rubies))
	quick_config = _quick_config()
	_rebuild_column()
	_layout()
	_apply_mode()


static func _format_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += " "
		out += s[i]
	return ("-" if n < 0 else "") + out


func _rebuild_column() -> void:
	for c in _column.get_children():
		_column.remove_child(c)
		c.queue_free()
	_buttons.clear()
	new_run_button = null
	quit_button = null

	main_button = _make_button("Reprendre" if has_save else "Jouer", true)
	main_button.name = "Main"
	main_button.pressed.connect(_on_main_pressed)
	if has_save:
		main_button.subtitle = format_summary(summary)
	elif not quick_config.is_empty():
		main_button.subtitle = String(quick_config.get("label", ""))
	main_button.button_down.connect(func() -> void:
		_hold_t = 0.0
		_hold_fired = false)
	main_button.button_up.connect(func() -> void: _hold_t = -1.0)
	_column.add_child(main_button)
	_buttons.append(main_button)

	if has_save:
		new_run_button = _add_sub("Nouvelle run", _on_new_run_pressed)
		new_run_button.name = "NewRun"
	progress_button = _add_sub("Progression", func(): progress_requested.emit())
	progress_button.name = "Progress"
	settings_button = _add_sub("Réglages", func(): settings_requested.emit())
	settings_button.name = "Settings"
	credits_button = _add_sub("Crédits", func(): credits_requested.emit())
	credits_button.name = "Credits"
	var test_button := _add_sub("Mode test", func(): test_mode_requested.emit()) # À RETIRER OU MASQUER AVANT LA SORTIE
	test_button.name = "TestMode"
	if Platform.can_quit() and not ios_override:
		quit_button = _add_sub("Quitter", _on_quit_pressed)
		quit_button.name = "Quit"

	# Navigation explicite en boucle dans la colonne (pas de saut vers un bouton masqué).
	for i in _buttons.size():
		var b := _buttons[i]
		var up: Control = _buttons[(i - 1 + _buttons.size()) % _buttons.size()]
		var down: Control = _buttons[(i + 1) % _buttons.size()]
		b.focus_neighbor_top = b.get_path_to(up)
		b.focus_neighbor_bottom = b.get_path_to(down)
		b.focus_neighbor_left = b.get_path_to(b)
		b.focus_neighbor_right = b.get_path_to(b)
	UiTheme.hook_sounds(root)


func _add_sub(txt: String, cb: Callable) -> MenuBtn:
	var b := _make_button(txt, false)
	b.pressed.connect(cb)
	_column.add_child(b)
	_buttons.append(b)
	return b


func _make_button(txt: String, primary: bool) -> MenuBtn:
	var b := MenuBtn.new()
	b.text = txt
	b.custom_minimum_size = MAIN_SIZE if primary else SUB_SIZE
	b.size = b.custom_minimum_size
	if primary:
		UiTheme.primary(b)
		UiTheme.mark_confirm(b)
	_hover_focus(b)
	return b


func _hover_focus(b: Button) -> void:
	b.mouse_entered.connect(func():
		if not Platform.is_touch_mode() and not _dialog_open and b.is_inside_tree() and not b.disabled:
			b.grab_focus())


static func _style_label(l: Label, size: int, color: Color, outline: int) -> void:
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", UiTheme.COL_OUTLINE)
	l.add_theme_constant_override(&"outline_size", outline)


# --- Disposition -----------------------------------------------------------------

func _layout() -> void:
	if root == null or _column == null or _buttons.is_empty():
		return
	var m: Dictionary = Platform.safe_margins()
	var left := float(m.get("left", 48.0))
	var right := float(m.get("right", 48.0))
	var top := float(m.get("top", 32.0))
	var bottom := float(m.get("bottom", 32.0))
	var w := root.size.x
	var h := root.size.y
	_gradient.offsets = PackedFloat32Array([0.0, clampf(1100.0 / maxf(w, 1.0), 0.05, 1.0)])
	var x := left + COL_X
	_logo.position = Vector2(x, 40.0 + top)
	_logo.size = Vector2(640, 220)
	_version.position = Vector2(x + 8.0, _logo.position.y + 224.0)
	_version.size = Vector2(640, 34)
	# Colonne alignée en bas (6 boutons ne tiennent pas dans 1080 aux pas du doc : 96 de haut, 16 d'écart).
	var total := GAP * (_buttons.size() - 1)
	for b in _buttons:
		total += b.custom_minimum_size.y
	var y := (h - bottom) - total
	_column.position = Vector2(x, 0)
	_column.size = Vector2(MAIN_SIZE.x, h)
	for b in _buttons:
		b.position = Vector2(0, y)
		b.size = b.custom_minimum_size
		y += b.size.y + GAP
	# Haut-droite : rubis (l'icône Réglages a été retirée, le bouton existe dans la colonne).
	_ruby_box.reset_size()
	_ruby_box.position = Vector2(w - right - _ruby_box.size.x, top + 16.0)
	# Bandeau d'invites : aligné à droite (la colonne de boutons occupe le bas-gauche).
	hints_label.size = Vector2(900, 40)
	hints_label.position = Vector2(w - right - 900.0, h - bottom - 48.0)
	toast_label.reset_size()
	toast_label.position = Vector2((w - toast_label.size.x) * 0.5, top + 24.0)


# --- Modes d'entrée ----------------------------------------------------------------

func _on_input_mode_changed(_mode: int) -> void:
	_apply_mode()


func _apply_mode() -> void:
	if root == null or main_button == null:
		return
	var touch := Platform.is_touch_mode()
	hints_label.visible = not touch
	hints_label.text = hints_text()
	for b in _buttons:
		if touch:
			b.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		elif b == main_button:
			UiTheme.primary(b)
		else:
			b.remove_theme_stylebox_override(&"focus")
	if touch:
		var f := root.get_viewport().gui_get_focus_owner()
		if f != null:
			f.release_focus()
	elif not _dialog_open:
		_focus_main.call_deferred()


## Invites du bas : seulement des actions qui ont un effet sur cet écran (M9).
func hints_text() -> String:
	var parts: Array[String] = []
	if Platform.is_gamepad_mode():
		parts.append("[A] Valider")
		if not has_save and not quick_config.is_empty():
			parts.append("[Y] Relancer %s" % String(quick_config.get("label", "")))
	else:
		parts.append("[Entrée] Valider")
		if Platform.is_pc():
			parts.append("[F11] Plein écran")
	return " · ".join(parts)


func _focus_main() -> void:
	if main_button != null and main_button.is_inside_tree() and not Platform.is_touch_mode() and not _dialog_open:
		main_button.grab_focus()


# --- Actions ---------------------------------------------------------------------------

func _on_main_pressed() -> void:
	if _hold_fired:
		_hold_fired = false
		return # l'appui long a déjà lancé la relance
	if has_save:
		Audio.play_ui(&"ui.item_pick")
		resume_requested.emit()
	else:
		new_run_requested.emit()


func _on_new_run_pressed() -> void:
	var line := "%s sera perdue (les rubis déjà gagnés sont conservés)." % _short_summary()
	if await _confirm("Remplacer la run en cours ?", line, "Annuler", "Remplacer"):
		new_run_requested.emit()


func _on_quit_pressed() -> void:
	if await _confirm("Quitter Rainfall ?", "", "Annuler", "Quitter"):
		quit_requested.emit()


# --- Relance rapide (M16) ------------------------------------------------------------------------

## Config du dernier personnage joué, si au moins une run est finie et qu'il est encore jouable.
func _quick_config() -> Dictionary:
	var pr: Object = profile_override if profile_override != null else Profile
	var st: Variant = pr.get("stats")
	if not (st is Dictionary) or int((st as Dictionary).get("runs", 0)) < 1:
		return {}
	var cid := StringName(str(pr.get("last_character")))
	var mode := StringName(str(pr.get("last_mode")))
	if pr.has_method(&"is_character_available") and not bool(pr.call(&"is_character_available", cid)):
		return {}
	if pr.has_method(&"is_mode_unlocked") and not bool(pr.call(&"is_mode_unlocked", mode)):
		return {}
	var cname := String(cid).capitalize()
	var spells := {}
	var found := false
	var f := FileAccess.open("res://data/characters.json", FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
	if parsed is Array:
		for c in parsed:
			if c is Dictionary and String(c.get("id", "")) == String(cid):
				found = bool(c.get("playable", true))
				cname = String(c.get("name", cname))
				spells = CharacterSheet.resolve_loadout(pr, c) # sorts mémorisés (variantes débloquées) sinon base
	if not found:
		return {}
	return {"character": cid, "mode": mode, "spells": spells,
		"label": "%s · %s" % [cname, MODE_NAMES.get(String(mode), String(mode).capitalize())]}


## Lance directement la run « dernier personnage · dernier mode » (sans sauvegarde en cours).
func quick_start() -> bool:
	if has_save or quick_config.is_empty() or _dialog_open:
		return false
	Audio.play_ui(&"ui.item_pick")
	var cfg := quick_config.duplicate(true)
	cfg.erase("label")
	quick_start_requested.emit(cfg)
	return true


func _process(delta: float) -> void:
	if _hold_t < 0.0 or _hold_fired:
		return
	_hold_t += delta
	if _hold_t >= QUICK_HOLD_S and not has_save and not quick_config.is_empty():
		_hold_fired = true
		quick_start()


# --- Avertissement de photosensibilité ------------------------------------------------------------

## Montré une fois (GameSettings [first_launch] photosensitivity_seen). « Réduire » : flashs réduits,
## secousses à 30 %. Retourne true si le joueur a choisi de réduire.
func show_photosensitivity_warning() -> bool:
	if _dialog_open:
		return false
	_dialog_open = true
	dialog = ConfirmDialog.new()
	dialog.layer = UI_LAYER + 10
	add_child(dialog)
	var sig: Signal = dialog.ask(PHOTO_TITLE, PHOTO_TEXT, "Continuer", "Réduire flashs et secousses")
	if dialog._destructive != null:
		UiTheme.primary(dialog._destructive) # choix sûr, pas destructif
	var reduce: bool = await sig
	dialog = null
	_dialog_open = false
	GameSettings.set_photosensitivity_seen()
	if reduce:
		GameSettings.set_flashes(1)
		GameSettings.set_shake(PHOTO_REDUCED_SHAKE)
	if is_inside_tree() and not Platform.is_touch_mode() and main_button != null:
		_focus_main.call_deferred()
	return reduce


func _short_summary() -> String:
	var secs := int(float(summary.get("active_time_s", 0.0)))
	return "%s · Étage %d · %02d:%02d" % [String(summary.get("character_name", "Ardent")), int(summary.get("stage", 1)), secs / 60, secs % 60]


func _input(event: InputEvent) -> void:
	if _dialog_open:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled() # rien : pas de « quitter » accidentel
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		get_viewport().set_input_as_handled()
		if main_button != null:
			main_button.pressed.emit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y:
		if quick_start():
			get_viewport().set_input_as_handled()


# --- Toast -------------------------------------------------------------------------------

func show_toast(text: String) -> void:
	if toast_label == null:
		return
	toast_label.text = text
	toast_label.visible = true
	toast_label.modulate.a = 1.0
	_layout()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(3.5)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func(): toast_label.visible = false)


# --- Confirmation ---------------------------------------------------------------------------

## Retourne true si l'action destructive est choisie. Échap / B = action neutre (focus initial).
func _confirm(title: String, line: String, neutral: String, destructive: String) -> bool:
	if _dialog_open:
		return false
	_dialog_open = true
	dialog = ConfirmDialog.new()
	dialog.layer = UI_LAYER + 10
	add_child(dialog)
	var chosen: bool = await dialog.ask(title, line, neutral, destructive)
	dialog = null
	_dialog_open = false
	if is_inside_tree() and not Platform.is_touch_mode() and main_button != null:
		_focus_main.call_deferred()
	return chosen
