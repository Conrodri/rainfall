class_name RictusPendulum
extends Node2D
## Lame-pendule (variante du sort 2 de Rictus, docs/Variantes_Sorts.md §2.2) : couteau lourd au bout d'un fil.
## Aller à `range_px` (ou mur), retour vers Rictus (position courante) ; chaque passage touche une fois tout monstre
## traversé (perce tout). Dégâts toujours via SpellCaster.deal_damage (items et procs). Placeholder dessiné en code
## tant que `pendulum_knife` (lot Codex RICV) n'est pas livré : couteau qui tourne + fil argent.

const HIT_RADIUS_U := 0.6 ## rayon de contact du couteau (+ rayon du monstre)
const CATCH_U := 0.5 ## le couteau est rattrapé à cette distance de Rictus
const WALL_MASK := 1
const SPIN_RAD_S := 14.0
const FRAMES := "res://assets/sprites/characters/rictus/variants/pendulum_knife/pendulum_knife.tres"

var caster: SpellCaster = null
var owner_player: CharacterBody2D = null
var spell: SpellData = null
var dir := Vector2.RIGHT
var speed_px := 0.0
var range_px := 0.0
var returning := false
var travelled := 0.0
var passes := 0 ## 0 aller, 1 retour
var hits_total := 0
var _hit: Dictionary = {} ## instance_id -> true, vidé à chaque passage
var _spin := 0.0
var _sprite: AnimatedSprite2D = null
var _thread_color := Color("#9FC8C0")


## Crée et lance un couteau-pendule depuis le joueur.
static func launch(c: SpellCaster, p: CharacterBody2D, s: SpellData, d: Vector2, spd_px: float, rng_px: float) -> RictusPendulum:
	var n := RictusPendulum.new()
	n.caster = c
	n.owner_player = p
	n.spell = s
	n.dir = d.normalized()
	n.speed_px = spd_px
	n.range_px = rng_px
	n.top_level = true
	c.effects_parent().add_child(n)
	n.global_position = p.global_position
	return n


func _ready() -> void:
	z_index = 1
	if ResourceLoader.exists(FRAMES):
		var sf := load(FRAMES) as SpriteFrames
		if sf != null and sf.has_animation(&"default"):
			_sprite = AnimatedSprite2D.new()
			_sprite.sprite_frames = sf
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(_sprite)
			_sprite.play(&"default")


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests : avance de `delta` s.
func step(delta: float) -> void:
	if caster == null or not is_instance_valid(caster) or owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	_spin += SPIN_RAD_S * delta
	var move := speed_px * delta
	if not returning:
		var wall := _wall_ahead(move)
		var step_px := minf(move, range_px - travelled)
		if wall >= 0.0:
			step_px = minf(step_px, wall)
		global_position += dir * step_px
		travelled += step_px
		_hit_scan()
		if travelled >= range_px - 0.01 or wall >= 0.0:
			_turn()
	else:
		var to := owner_player.global_position - global_position
		if to.length() <= CATCH_U * Balance.UNIT_PX or to.length() <= move:
			queue_free()
			return
		dir = to.normalized()
		global_position += dir * move
		_hit_scan()
	if _sprite != null:
		_sprite.rotation = _spin
	queue_redraw()


## Distance avant un mur sur le pas courant, ou -1.
func _wall_ahead(move: float) -> float:
	if not is_inside_tree():
		return -1.0
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + dir * (move + 6.0), WALL_MASK)
	var r := space.intersect_ray(q)
	if r.is_empty():
		return -1.0
	return maxf((r["position"] as Vector2).distance_to(global_position) - 6.0, 0.0)


func _turn() -> void:
	returning = true
	passes = 1
	_hit.clear()


func _hit_scan() -> void:
	var u := Balance.UNIT_PX
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e):
			continue
		var id := e.get_instance_id()
		if _hit.has(id):
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		if e.global_position.distance_to(global_position) <= HIT_RADIUS_U * u + er:
			_hit[id] = true
			hits_total += 1
			caster.deal_damage(e, spell, {"source_pos": global_position})


func _draw() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var to := owner_player.global_position - global_position
	draw_line(Vector2.ZERO, to, Color(_thread_color.r * 1.25, _thread_color.g * 1.25, _thread_color.b * 1.25, 0.35), 1.5)
	if _sprite != null:
		return
	var a := Vector2.from_angle(_spin)
	var pts := PackedVector2Array([a * 14.0, a.rotated(2.4) * 8.0, -a * 6.0, a.rotated(-2.4) * 8.0])
	draw_colored_polygon(pts, Color(0.75, 0.85, 0.85))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(_thread_color.r * 1.4, _thread_color.g * 1.4, _thread_color.b * 1.4), 1.5)
