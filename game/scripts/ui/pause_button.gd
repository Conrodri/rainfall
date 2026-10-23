class_name PauseButton
extends Control
## Bouton pause en haut a droite : appui long de HOLD_S requis (evite les faux appuis) ; option
## GameSettings.pause_long_press() = false : appui simple (defaut sur PC).

signal long_pressed

const HOLD_S := 0.3
const VISUAL_PX := 110.0 ## visuel (base 1080)
const HIT_PX := 140.0 ## zone de frappe invisible (audit E-06 : 110 px ≈ 6,6 mm, trop petit au doigt)

var _held := 0.0
var _down := false
var _touch := -1
var long_press := true ## relu depuis GameSettings a chaque appui


func _ready() -> void:
	custom_minimum_size = Vector2(110, 110)
	size = Vector2(110, 110)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Echelle de l'UI (1.0 = base 1080 px de large).
func apply_scale(s: float) -> void:
	custom_minimum_size = Vector2(VISUAL_PX, VISUAL_PX) * s
	size = custom_minimum_size
	queue_redraw()


## Marge de frappe autour du visuel (px logiques, à l'échelle du bouton).
func hit_pad() -> float:
	return (HIT_PX - VISUAL_PX) * 0.5 * size.x / VISUAL_PX


func _has_point(point: Vector2) -> bool:
	var p := hit_pad()
	return Rect2(-Vector2(p, p), size + Vector2(p, p) * 2.0).has_point(point)


func _begin_press() -> void:
	long_press = GameSettings.pause_long_press()
	_down = true
	_held = 0.0
	if not long_press:
		_down = false
		long_pressed.emit() # appui simple


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		# PC : clic souris (la souris n'émule plus de toucher), même appui long que le tactile
		if (event as InputEventMouseButton).pressed and _touch == -1:
			_touch = -2
			_begin_press()
			accept_event()
		elif not (event as InputEventMouseButton).pressed and _touch == -2:
			_touch = -1
			_down = false
			_held = 0.0
			queue_redraw()
			accept_event()
	elif event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _touch == -1:
			_touch = t.index
			_begin_press()
			accept_event()
		elif not t.pressed and t.index == _touch:
			_touch = -1
			_down = false
			_held = 0.0
			queue_redraw()
			accept_event()


func _process(delta: float) -> void:
	if _down:
		_held += delta
		queue_redraw()
		if _held >= HOLD_S:
			_down = false
			_held = 0.0
			long_pressed.emit()


func _draw() -> void:
	var itex := Minimap.ui_texture("icon_pause.png")
	if itex != null:
		draw_texture_rect(itex, Rect2(Vector2.ZERO, size), false)
		if _down:
			var c0 := size * 0.5
			var r0 := minf(size.x, size.y) * 0.5 - 4.0
			draw_arc(c0, r0, -PI * 0.5, -PI * 0.5 + TAU * clampf(_held / HOLD_S, 0.0, 1.0), 32, Color(1.0, 0.85, 0.3), 6.0)
		return
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(c, r, Color(0.1, 0.1, 0.15, 0.6))
	draw_rect(Rect2(c + Vector2(-16, -22), Vector2(10, 44)), Color.WHITE)
	draw_rect(Rect2(c + Vector2(6, -22), Vector2(10, 44)), Color.WHITE)
	draw_arc(c, r, 0.0, TAU, 32, Color(1, 1, 1, 0.3), 3.0)
	if _down:
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(_held / HOLD_S, 0.0, 1.0), 32, Color(1.0, 0.85, 0.3), 6.0)
