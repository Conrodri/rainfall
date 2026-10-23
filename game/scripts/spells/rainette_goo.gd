class_name RainetteGoo
extends Node2D
## Flaque de Gluant (Rainette, sort 3) : ralentit les monstres dedans et les attire vers son centre (le paquet
## se colle et avance lentement) ; les bonds de Rainette qui en partent sont plus longs (RainetteKit).
## Visuel : SpellData.vfx_frames (goo.tres, lot RA2 : rig TOP, `default` en boucle, `end` facultative), posé au
## sol comme un ZoneEffect ; absent = placeholder dessiné (disque vase sombre + contour jade fin).

static var live: Array[RainetteGoo] = []

const SLOW_REFRESH_S := 0.25 ## ralentissement rafraîchi tant que le monstre reste dedans
const FADE_IN_S := 0.15
const FADE_OUT_S := 0.5
const VFX_Z := -1
const FILL := Color(0.16, 0.2, 0.15, 0.42) ## vase (repli)

var radius := 160.0
var duration := 5.0
var slow_pct := 0.4
var pull_px_s := 57.6
var spell: SpellData = null
var vfx: AnimatedSprite2D = null
var _t := 0.0
var _ending := false
var _light: LightRig.Handle = null


func setup(_at: Vector2, radius_px: float, life_s: float, p_slow: float, p_pull_px_s: float, s: SpellData) -> void:
	radius = radius_px
	duration = life_s
	slow_pct = p_slow
	pull_px_s = p_pull_px_s
	spell = s


func _ready() -> void:
	z_index = VFX_Z
	live.append(self)
	_setup_vfx()
	if spell != null and spell.light_preset != &"" and LightRig.has_preset(spell.light_preset):
		var base_r := float(LightRig.get_preset(spell.light_preset).get("radius_u", 2.0)) * Balance.UNIT_PX
		_light = LightRig.attach(self, spell.light_preset, {"radius": radius / maxf(base_r, 1.0), "energy": 0.5})


func _exit_tree() -> void:
	live.erase(self)


func _setup_vfx() -> void:
	if spell == null or spell.vfx_frames == "" or not ResourceLoader.exists(spell.vfx_frames):
		return
	var frames := load(spell.vfx_frames) as SpriteFrames
	if frames == null or not frames.has_animation(&"default") or frames.get_frame_count(&"default") == 0:
		return
	vfx = AnimatedSprite2D.new()
	vfx.name = "Vfx"
	add_child(vfx)
	EmissiveOverlay.apply(vfx, frames)
	var k := radius / maxf(spell.vfx_radius_px, 1.0) if spell.vfx_radius_px > 0.0 else 1.0
	vfx.scale = Vector2(k, k / clampf(spell.vfx_floor_aspect, 0.1, 1.0))
	vfx.sprite_frames.set_animation_loop(&"default", true)
	vfx.play(&"default")
	vfx.modulate.a = 0.0


static func contains(pos: Vector2) -> bool:
	for g in live:
		if is_instance_valid(g) and not g._ending and g.global_position.distance_to(pos) <= g.radius:
			return true
	return false


static func clear_all() -> void:
	for g in live.duplicate():
		if is_instance_valid(g):
			g.queue_free()
	live.clear()


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests sans boucle physique.
func step(delta: float) -> void:
	_t += delta
	if _ending:
		if vfx == null or not vfx.is_playing() or _t >= duration + 2.0:
			queue_free()
		elif not vfx.sprite_frames.has_animation(&"end"):
			vfx.modulate.a = clampf(1.0 - (_t - duration) / FADE_OUT_S, 0.0, 1.0)
			if vfx.modulate.a <= 0.0:
				queue_free()
		return
	_affect(delta)
	if vfx != null:
		vfx.modulate.a = minf(clampf(_t / FADE_IN_S, 0.0, 1.0), 1.0)
	else:
		queue_redraw()
	if _t >= duration:
		_ending = true
		if _light != null:
			_light.set_fade(FADE_OUT_S)
		if vfx != null and vfx.sprite_frames.has_animation(&"end"):
			vfx.sprite_frames.set_animation_loop(&"end", false)
			vfx.play(&"end")
		elif vfx == null:
			queue_free()


func _affect(delta: float) -> void:
	var c := global_position
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var p: Vector2 = (e as Node2D).global_position
		var d := c - p
		if d.length() > radius:
			continue
		if e.has_method(&"apply_status"):
			e.apply_status(&"slow", {"pct": slow_pct, "duration": SLOW_REFRESH_S})
		if e.has_method(&"push") and d.length_squared() > 4.0:
			e.push(d.normalized() * minf(pull_px_s * delta, d.length()))


## Placeholder sans goo.tres : vase sombre + contour jade fin (à remplacer par le rendu Blender RA2).
func _draw() -> void:
	if vfx != null or spell == null:
		return
	var a := clampf(_t / FADE_IN_S, 0.0, 1.0) * clampf((duration - _t) / FADE_OUT_S, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(FILL.r, FILL.g, FILL.b, FILL.a * a))
	var c := spell.color
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(c.r, c.g, c.b, 0.55 * a), 2.0)
	draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 48, Color(c.r, c.g, c.b, 0.18 * a), 1.0)
