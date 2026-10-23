class_name CreditsScreen
extends Node
## Crédits (docs/Design_Menus.md §3.6) : texte défilant sur le fond animé assombri à 60 %.
## 60 px/s, x4 en maintenant ui_accept / un doigt ; retour auto 2 s après la fin ; Échap / B / « Retour ».

signal back_requested

const BG_SCENE := preload("res://scenes/menu/menu_background.tscn")
const UI_LAYER := 10
const SPEED := 60.0
const FAST_MULT := 4.0
const END_DELAY := 2.0
const COLUMN_W := 900.0
const TEXT := Color("#E8EEF8")
const GOLD := Color("#FFE9A8")
const EMBER := Color("#FFB347")
## Studio : Peak development ; développeur : Garpzz.
const LINES: Array = [
	["Rainfall", "title"],
	["Peak development", "body"],
	["", "gap"],
	["Conception et code", "head"],
	["Garpzz", "body"],
	["", "gap"],
	["Assets Blender et audio", "head"],
	["Pipeline Codex", "body"],
	["", "gap"],
	["Moteur", "head"],
	["Godot Engine 4.7 (licence MIT)", "body"],
	["", "gap"],
	["", "gap"],
	["Merci d'avoir joué", "title2"],
]

var background: MenuBackground
var ui: CanvasLayer
var root: Control
var back_button: Button
var scroll_content: VBoxContainer
var elapsed := 0.0
var finished := false

var _scroll_y := 0.0
var _end_t := 0.0
var _holding := false
var _auto_back := true


func _ready() -> void:
	background = BG_SCENE.instantiate() as MenuBackground
	background.name = "Background"
	add_child(background)
	background.setup(MenuBackground.daily_map_id())
	_build_ui()
	if Audio.current_map_id() != "menu":
		Audio.start_map("menu")
	Audio.play_ui(&"ui.hover", -4.0, 1.15)
	Platform.input_mode_changed.connect(func(_m): _apply_mode())
	Platform.safe_area_changed.connect(_layout) # encoche passée de côté sans redimensionnement (A11y-L4)
	_apply_mode()


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
	root.gui_input.connect(_on_gui_input)
	UiTheme.apply(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color("#050810", 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var clip := Control.new()
	clip.name = "Clip"
	clip.clip_contents = true
	clip.set_anchors_preset(Control.PRESET_FULL_RECT)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(clip)
	scroll_content = VBoxContainer.new()
	scroll_content.name = "Content"
	scroll_content.custom_minimum_size = Vector2(COLUMN_W, 0)
	scroll_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_content.add_theme_constant_override(&"separation", 12)
	clip.add_child(scroll_content)
	for e in LINES:
		var kind := String(e[1])
		var l := Label.new()
		l.text = String(e[0])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.add_theme_color_override(&"font_outline_color", Color("#1a1620"))
		match kind:
			"title":
				_font(l, 160, Color("#DCE6F5"), 12)
			"title2":
				_font(l, 72, GOLD, 8)
			"head":
				_font(l, 44, GOLD, 7)
			"gap":
				l.custom_minimum_size.y = 60
			_:
				_font(l, 60, TEXT, 7)
		scroll_content.add_child(l)

	back_button = MenuBtn.new()
	back_button.name = "Back"
	back_button.text = "Retour"
	back_button.custom_minimum_size = Vector2(300, 96)
	UiTheme.mark_back(back_button)
	back_button.pressed.connect(_go_back)
	root.add_child(back_button)
	root.resized.connect(_layout)
	_layout.call_deferred()
	UiTheme.hook_sounds(root)


static func _font(l: Label, size: int, color: Color, outline: int) -> void:
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", outline)


func _layout() -> void:
	if root == null:
		return
	var m: Dictionary = Platform.safe_margins()
	var w := root.size.x
	var h := root.size.y
	scroll_content.size = Vector2(COLUMN_W, 0)
	scroll_content.reset_size()
	scroll_content.position.x = (w - COLUMN_W) * 0.5
	if elapsed == 0.0:
		_scroll_y = h # le texte entre par le bas
	scroll_content.position.y = _scroll_y
	back_button.position = Vector2(float(m.get("left", 48.0)) + 96.0, h - float(m.get("bottom", 32.0)) - 96.0)
	back_button.size = Vector2(300, 96)


func _apply_mode() -> void:
	if root == null:
		return
	if Platform.is_touch_mode():
		back_button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		var f := root.get_viewport().gui_get_focus_owner()
		if f != null:
			f.release_focus()
	else:
		back_button.remove_theme_stylebox_override(&"focus")
		back_button.grab_focus.call_deferred()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_holding = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_holding = event.pressed


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()


func _go_back() -> void:
	if _auto_back:
		_auto_back = false # un seul signal
		Audio.play_ui(&"ui.click", -6.0, 0.85)
		back_requested.emit()


func _process(delta: float) -> void:
	if root == null:
		return
	elapsed += delta
	var fast := _holding or Input.is_action_pressed(&"ui_accept")
	if not finished:
		_scroll_y -= SPEED * (FAST_MULT if fast else 1.0) * delta
		scroll_content.position.y = _scroll_y
		if _scroll_y + scroll_content.size.y < 0.0:
			finished = true
	else:
		_end_t += delta
		if _end_t >= END_DELAY:
			_go_back()
