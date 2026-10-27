class_name TestOverlay
extends Node
## Mode test : ouverture du panneau (F1, bouton Select / Back de la manette, bouton « TEST » à l'écran en tactile),
## pause facultative pendant qu'il est ouvert, journal des dégâts reçus, invocation par clic dans l'arène.
## Attaché à Main par Main._build quand TestMode.active. À RETIRER OU MASQUER AVANT LA SORTIE avec le mode test.

const PANEL_LAYER := 90 ## sous le menu pause (100), au-dessus du HUD (10)
const LAUNCHER_LAYER := 20
const HINT_S := 7.0
const HIT_LOG_MAX := 8
const PAD_BUTTON := JOY_BUTTON_BACK ## Select / Back / Vue

var main: Node
var panel: TestPanel
var launcher: Button
var hint: Label

## Journal des coups reçus (lu par le panneau, onglet Difficulté) : [{amount, source, t}] du plus récent au plus ancien.
var hits: Array[Dictionary] = []
var hit_max := 0.0
var hit_total := 0.0
var hit_count := 0

var _paused_by_us := false
var _launcher_layer: CanvasLayer
var _panel_layer: CanvasLayer


static func attach(main_node: Node) -> TestOverlay:
	var o := TestOverlay.new()
	o.name = "TestOverlay"
	o.main = main_node
	main_node.add_child(o) # dernier enfant de Main : reçoit les entrées avant le HUD et le menu pause
	return o


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = PANEL_LAYER
	_panel_layer.name = "PanelLayer"
	add_child(_panel_layer)
	panel = TestPanel.new()
	panel.overlay = self
	panel.visible = false
	_panel_layer.add_child(panel)
	_launcher_layer = CanvasLayer.new()
	_launcher_layer.layer = LAUNCHER_LAYER
	_launcher_layer.name = "LauncherLayer"
	add_child(_launcher_layer)
	_build_launcher()
	TestMode.panel_requested.connect(toggle)
	Events.player_damaged.connect(_on_player_damaged)
	Platform.input_mode_changed.connect(func(_m: int) -> void: _update_launcher())
	Platform.safe_area_changed.connect(_place_launcher)
	get_viewport().size_changed.connect(_place_launcher)
	_update_launcher()
	get_tree().create_timer(HINT_S, true).timeout.connect(func() -> void:
		if is_instance_valid(hint):
			hint.queue_free())


func _exit_tree() -> void:
	if _paused_by_us:
		get_tree().paused = false
	if TestMode.panel_requested.is_connected(toggle):
		TestMode.panel_requested.disconnect(toggle)
	if Events.player_damaged.is_connected(_on_player_damaged):
		Events.player_damaged.disconnect(_on_player_damaged)


func _build_launcher() -> void:
	launcher = Button.new()
	launcher.name = "TestLauncher"
	launcher.text = "TEST"
	launcher.focus_mode = Control.FOCUS_NONE
	launcher.custom_minimum_size = Vector2(150, UiTheme.MIN_TOUCH)
	launcher.add_theme_font_size_override(&"font_size", 30)
	launcher.pressed.connect(toggle)
	launcher.theme = UiTheme.theme()
	_launcher_layer.add_child(launcher)
	hint = Label.new()
	hint.name = "TestHint"
	hint.text = "Mode test : F1 ou Select ouvre le panneau"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.theme = UiTheme.theme()
	hint.add_theme_font_size_override(&"font_size", 28)
	hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	hint.add_theme_constant_override(&"outline_size", 8)
	hint.position = Vector2(48, 150)
	_launcher_layer.add_child(hint)
	_place_launcher()


## Bouton à gauche, à mi-hauteur : hors des zones du HUD (plaque et objets en haut, sorts en bas, boss au centre haut).
func _place_launcher() -> void:
	if launcher == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var safe := Platform.safe_margins()
	launcher.size = launcher.get_combined_minimum_size()
	launcher.position = Vector2(float(safe.get("left", 0.0)) + 24.0, vp.y * 0.5 - launcher.size.y * 0.5)
	if hint != null:
		hint.position = Vector2(float(safe.get("left", 0.0)) + 24.0, vp.y * 0.5 + launcher.size.y)


func _update_launcher() -> void:
	if launcher != null:
		launcher.visible = Platform.input_mode == Platform.InputMode.TOUCH


# --- Ouverture / fermeture --------------------------------------------------------

func is_open() -> bool:
	return panel != null and panel.visible


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if panel == null or panel.visible:
		return
	panel.open()
	if TestMode.pause_on_open and not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	if is_instance_valid(hint):
		hint.queue_free()


func close() -> void:
	if panel == null or not panel.visible:
		return
	panel.close()
	if _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false


## Le réglage « Pause à l'ouverture » change pendant que le panneau est ouvert : la pause suit tout de suite.
func sync_pause() -> void:
	if not is_open():
		return
	if TestMode.pause_on_open and not get_tree().paused:
		get_tree().paused = true
		_paused_by_us = true
	elif not TestMode.pause_on_open and _paused_by_us:
		get_tree().paused = false
		_paused_by_us = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F1:
		toggle()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == PAD_BUTTON:
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open() and (event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel")):
		close() # Échap / Start / B ferment le panneau avant le menu pause
		get_viewport().set_input_as_handled()


## Invocation par clic dans l'arène (option « au curseur » du panneau) : seulement hors du cadre du panneau.
func _unhandled_input(event: InputEvent) -> void:
	if not is_open() or panel.armed_entry.is_empty():
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var player := get_tree().get_first_node_in_group(&"player") as Node2D
		if player == null:
			return
		panel.spawn_entry(panel.armed_entry, player.get_global_mouse_position())
		get_viewport().set_input_as_handled()


# --- Journal des coups reçus -------------------------------------------------------

func _on_player_damaged(amount: float, source: Node) -> void:
	var name_s := "—"
	if is_instance_valid(source):
		name_s = String(source.call(&"boss_id")) if source.has_method(&"boss_id") and String(source.call(&"boss_id")) != "" else source.name
		if source is Enemy and not (source as Enemy).is_boss:
			name_s = "%s%s" % [TestTools.TIER_NAMES.get((source as Enemy).tier, "Monstre"), " élite" if (source as Enemy).is_elite else ""]
	hits.push_front({"amount": amount, "source": name_s, "t": Time.get_ticks_msec()})
	if hits.size() > HIT_LOG_MAX:
		hits.pop_back()
	hit_max = maxf(hit_max, amount)
	hit_total += amount
	hit_count += 1


func reset_hits() -> void:
	hits.clear()
	hit_max = 0.0
	hit_total = 0.0
	hit_count = 0
