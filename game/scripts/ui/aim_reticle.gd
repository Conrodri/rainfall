class_name AimReticle
extends Control
## Réticule discret de visée (PC : curseur, manette : point visé au stick droit).
## Le HUD fournit la position écran (coordonnées du viewport logique) via show_at()/hide_reticle().

## Taille du réticule (A11y-L9, audit A-14) : GameSettings.reticle_scale() = 1.0 | 1.5 (défaut 1,0),
## relu au plus une fois par seconde.
const SIZE_MIN := 1.0
const SIZE_MAX := 1.5
const SIZE_REFRESH_MS := 1000

var _pos := Vector2.ZERO
var _scale := 1.0
var size_mult := 1.0
var _size_ms := -1000000


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func show_at(screen_pos: Vector2, ui_scale: float = 1.0) -> void:
	_pos = screen_pos
	var now := Time.get_ticks_msec()
	if now - _size_ms >= SIZE_REFRESH_MS:
		_size_ms = now
		size_mult = clampf(GameSettings.reticle_scale(), SIZE_MIN, SIZE_MAX)
	_scale = ui_scale * size_mult
	visible = true
	queue_redraw()


func hide_reticle() -> void:
	visible = false


func current_position() -> Vector2:
	return _pos


func _draw() -> void:
	var r := 20.0 * _scale
	var col := Color(1.0, 0.95, 0.8, 0.55)
	draw_arc(_pos, r, 0.0, TAU, 32, col, 2.0 * _scale)
	draw_circle(_pos, 2.5 * _scale, Color(1.0, 0.95, 0.8, 0.8))
	for i in 4:
		var d := Vector2.from_angle(i * PI * 0.5)
		draw_line(_pos + d * (r + 3.0 * _scale), _pos + d * (r + 11.0 * _scale), col, 2.0 * _scale)
