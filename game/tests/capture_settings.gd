extends Node
## Capture du lot E : réglages au titre (1,5 s), Commandes (3 s), pause + réglages (4,5 s), pause principale (6 s).
## PC     : godot --path game --write-movie <dossier>/pc.png --fixed-fps 30 res://tests/capture_settings.tscn
## Mobile : idem avec `-- --mobile`.

var _t := 0.0
var _step := 0
var _screen: SettingsScreen
var _pause: PauseMenu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color("1d2a3a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var cl := CanvasLayer.new()
	add_child(cl)
	_screen = SettingsScreen.new()
	cl.add_child(_screen)
	if Platform.is_mobile():
		Platform.set_input_mode(Platform.InputMode.TOUCH)


func _process(delta: float) -> void:
	_t += delta
	if Platform.is_mobile() and Platform.input_mode != Platform.InputMode.TOUCH:
		Platform.set_input_mode(Platform.InputMode.TOUCH)
	if _step == 0 and _t > 2.0:
		_step = 1
		_screen.panel.visible = false
		_screen.controls.visible = true
	if _step == 1 and _t > 3.5:
		_step = 2
		_screen.hide()
		_pause = PauseMenu.new()
		add_child(_pause)
		await get_tree().process_frame
		_pause.open()
		_pause._show_only(_pause._panel_settings)
	if _step == 2 and _t > 5.0:
		_step = 3
		_pause._show_only(_pause._panel_main)
	if _step == 3 and _t > 6.2:
		get_tree().quit()
