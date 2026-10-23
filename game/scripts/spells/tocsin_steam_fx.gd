class_name TocsinSteamFx
extends Node2D
## Effet bref des variantes de Tocsin (cône / anneau de vapeur, onde de traction ou d'atterrissage).
## PLACEHOLDER temporaire dessiné en code : à remplacer par les rendus Blender du lot TOCV
## (art/tools/night/_tocv.txt : steam_cone, steam_ring, stomp_ring). Un seul nœud, libéré à la fin.

enum Mode { CONE, RING, WAVE }

var mode := Mode.CONE
var radius_px := 192.0
var dir := Vector2.RIGHT
var life := 0.25
var half_angle := deg_to_rad(30.0)
var _t := 0.0


## Pose l'effet à `at` dans `parent` (rien si parent nul : tests sans monde).
static func spawn(parent: Node, at: Vector2, m: Mode, radius: float, d: Vector2, duration: float) -> TocsinSteamFx:
	if parent == null:
		return null
	var fx := TocsinSteamFx.new()
	fx.mode = m
	fx.radius_px = radius
	fx.dir = d
	fx.life = maxf(duration, 0.05)
	fx.z_index = 5
	parent.add_child(fx)
	fx.global_position = at
	return fx


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / life, 0.0, 1.0)
	var a := 1.0 - k
	var warm := Color(1.0, 0.72, 0.42)
	match mode:
		Mode.CONE:
			var pts := PackedVector2Array([Vector2.ZERO])
			var r := radius_px * (0.55 + 0.45 * k)
			var base := dir.angle()
			for i in 13:
				pts.append(Vector2.from_angle(base - half_angle + 2.0 * half_angle * float(i) / 12.0) * r)
			draw_colored_polygon(pts, Color(warm.r, warm.g, warm.b, 0.28 * a))
			draw_arc(Vector2.ZERO, r, base - half_angle, base + half_angle, 24, Color(1.0, 0.6, 0.25, 0.6 * a), 2.0)
		Mode.RING:
			var r2 := radius_px * (0.6 + 0.4 * k)
			draw_circle(Vector2.ZERO, r2, Color(warm.r, warm.g, warm.b, 0.18 * a))
			draw_arc(Vector2.ZERO, r2, 0.0, TAU, 48, Color(1.0, 0.6, 0.25, 0.6 * a), 2.0)
		Mode.WAVE:
			var r3 := radius_px * (0.25 + 0.75 * k)
			draw_arc(Vector2.ZERO, r3, 0.0, TAU, 56, Color(1.0, 0.55, 0.2, 0.8 * a), 3.0)
			draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 56, Color(1.0, 0.55, 0.2, 0.25 * a), 1.5)
