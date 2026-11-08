class_name TocsinSteamFx
extends Node2D
## Effet bref des variantes de Tocsin (cône / anneau de vapeur, onde de traction ou d'atterrissage).
## Joue les rendus Blender de `assets/sprites/vfx/tocsin/` (steam_cone, steam_ring, toll_wave) ; repli dessiné en
## code seulement si ces ressources manquent. Un seul nœud, libéré à la fin.

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
	fx._start_sprite()
	return fx


## Rendus Blender (lot feel Tocsin) : cône, anneau et onde TOP, empreinte de 240 px dans la cellule 512.
## Sans le .tres, le placeholder dessiné en code ci-dessous sert de repli.
const _FRAMES := {Mode.CONE: "steam_cone", Mode.RING: "steam_ring", Mode.WAVE: "toll_wave"}
const _FRAMES_DIR := "res://assets/sprites/vfx/tocsin/"
const _FOOTPRINT_PX := 240.0

var _vfx: AnimatedSprite2D = null


func _start_sprite() -> void:
	var n: String = _FRAMES[mode]
	var path := "%s%s/%s.tres" % [_FRAMES_DIR, n, n]
	if not ResourceLoader.exists(path):
		return
	var sf := load(path) as SpriteFrames
	if sf == null or not sf.has_animation(&"default"):
		return
	_vfx = AnimatedSprite2D.new()
	_vfx.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_vfx)
	EmissiveOverlay.apply(_vfx, sf)
	var k := radius_px / _FOOTPRINT_PX
	_vfx.scale = Vector2(k, k)
	if mode == Mode.CONE:
		_vfx.rotation = dir.angle() # axe du rendu vers +X
	sf.set_animation_loop(&"default", false)
	_vfx.play(&"default")
	_vfx.animation_finished.connect(queue_free)
	life = 5.0 # filet : l'anim libère le nœud à sa fin


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	if _vfx == null:
		queue_redraw()


func _draw() -> void:
	if _vfx != null:
		return
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
