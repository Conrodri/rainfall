class_name GresilleLob
extends Node2D
## Bouteille de Leyde en vol (variante de l'Orage, docs/fiches/gresille.md §12.2) : part de Grésille, monte en cloche
## (`lift_px` au sommet, ombre au sol) et atterrit en `dur` s, puis appelle `on_land(position)` (l'éclat est fait par le
## kit). Rendu : sprite `vfx/gresille/jar_fly` (8 poses de rotation) ; repli si la ressource manque : bouteille dessinée en
## code. `ring()` : anneau d'éclat, repli de `jar_burst` (le kit ne l'appelle que si la planche manque).

const ACCENT := Color("#B9A6FF")
const FRAMES_PATH := "res://assets/sprites/vfx/gresille/jar_fly/jar_fly.tres"

var from := Vector2.ZERO
var to := Vector2.ZERO
var dur := 0.8
var lift_px := 120.0
var landed := false
var _t := 0.0
var _on_land := Callable()
var _body: Node2D = null
var _sprite: AnimatedSprite2D = null


func setup(start: Vector2, target: Vector2, duration: float, lift: float, on_land: Callable) -> void:
	from = start
	to = target
	dur = maxf(duration, 0.05)
	lift_px = lift
	_on_land = on_land
	global_position = start
	z_index = 31
	_body = Node2D.new()
	_body.scale = Iso.UNSQUASH
	add_child(_body)
	var frames := load(FRAMES_PATH) as SpriteFrames if ResourceLoader.exists(FRAMES_PATH) else null
	if frames != null:
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = frames
		_body.add_child(_sprite)
		_sprite.pause()
	else:
		_body.draw.connect(_draw_bottle)
	queue_redraw()


func progress() -> float:
	return clampf(_t / dur, 0.0, 1.0)


## Avance de `delta` (public : tests sans boucle de rendu).
func step(delta: float) -> void:
	if landed:
		return
	_t += delta
	var k := progress()
	global_position = from.lerp(to, k)
	_body.position = Vector2(0.0, -lift_px * 4.0 * k * (1.0 - k) * 0.5)
	if _sprite != null:
		var n := _sprite.sprite_frames.get_frame_count(&"default")
		_sprite.frame = int(k * 2.5 * float(n)) % n # 2,5 tours en vol
	else:
		_body.rotation = k * TAU * 2.5
	queue_redraw()
	if k >= 1.0:
		landed = true
		if _on_land.is_valid():
			_on_land.call(to)
		queue_free()


func _process(delta: float) -> void:
	step(delta)


func _draw() -> void: # ombre de contact
	draw_circle(Vector2.ZERO, 9.0, Color(0.0, 0.0, 0.0, 0.35))


func _draw_bottle() -> void:
	_body.draw_rect(Rect2(-6.0, -12.0, 12.0, 20.0), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85))
	_body.draw_rect(Rect2(-3.0, -18.0, 6.0, 7.0), Color("#CFC8DA"))


## Anneau d'éclat au sol (PLACEHOLDER de `jar_burst`) : grossit jusqu'à `radius_px` et s'efface en `life` s.
static func ring(parent: Node, at: Vector2, radius_px: float, color: Color, life: float) -> void:
	if parent == null:
		return
	var n := Node2D.new()
	n.top_level = true
	n.global_position = at
	n.z_index = 30
	n.draw.connect(func() -> void:
		n.draw_circle(Vector2.ZERO, radius_px, Color(color.r, color.g, color.b, 0.16))
		n.draw_arc(Vector2.ZERO, radius_px, 0.0, TAU, 64, Color(color.r, color.g, color.b, 0.8), 3.0))
	n.scale = Vector2(0.2, 0.2)
	parent.add_child(n)
	var tw := n.create_tween()
	tw.set_parallel(true)
	tw.tween_property(n, ^"scale", Vector2.ONE, life * 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, ^"modulate:a", 0.0, life)
	tw.chain().tween_callback(n.queue_free)
