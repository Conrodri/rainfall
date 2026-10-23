class_name MorfilCleaveFx
extends Node2D
## PLACEHOLDER (VFX `cut_cleave` du lot TALV) : le trait du Fendoir de Taliant, un rectangle de sève tendu sur la
## ligne frappée, qui s'éteint en 0,25 s. Une seule couleur d'accent, aucun remplissage décoratif.

const LIFE_S := 0.25

var color := Color("#CDEB6E")
var dir := Vector2.RIGHT
var length_px := 320.0
var width_px := 64.0
var _age := 0.0


func _ready() -> void:
	z_index = 5


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE_S:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - _age / LIFE_S
	var side := Vector2(-dir.y, dir.x) * width_px * 0.5
	var a := Vector2.ZERO
	var b := dir * length_px
	var col := Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.55 * k)
	draw_colored_polygon(PackedVector2Array([a - side, b - side * 0.6, b + side * 0.6, a + side]), col)
	draw_line(a, b, Color(1.0, 1.0, 0.85, 0.9 * k), 3.0)
