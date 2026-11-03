class_name RictusPendulum
extends Node2D
## Couteau lourd de Rictus (sort 2 « Couteau ficelé » et retour de la Saccade, docs/Design_Rictus_v2.md §3) :
## le Montreur le tient par un fil et le ramène toujours. États :
## - FLYING : part vers la visée, se plante dans le premier monstre touché (coup d'impact, signal `planted_in`),
##   sinon tombe au sol en bout de course ou contre un mur (signal `dropped`).
## - PLANTED : suit le monstre ficelé ; le kit gère la scie, les tours et la durée. Si la cible meurt ou disparaît,
##   le couteau tombe là où elle était (`dropped`).
## - GROUND : planté au sol KNIFE_LIFE_S ; le marcher dessus le rattrape (`caught`), sinon il disparaît (`expired`).
## - RETURNING : revient en ligne droite vers Rictus (position courante), touche une fois tout monstre traversé
##   (`return_spell`), s'arrête contre un mur (tombe au sol), est rattrapé à CATCH_U (`caught`).
## Le même nœud sert de couteau léger de l'Éventail qui revient avec la Saccade (`recall_light`, sans fil).
## Dégâts toujours via SpellCaster.deal_damage (items et procs). Sprite `pendulum_knife` (lot RICV) ; le fil et les
## tours enroulés sont dessinés (Line de fil, anneaux), comme le fil des doublures.

signal planted_in(enemy: Node2D)
signal dropped(at: Vector2, lost_target: bool)
signal caught
signal expired

enum State { FLYING, PLANTED, GROUND, RETURNING }

const HIT_RADIUS_U := 0.6 ## rayon de contact du couteau (+ rayon du monstre)
const CATCH_U := 0.5 ## le couteau est rattrapé à cette distance de Rictus
const GROUND_CONTACT_U := 0.6 ## marcher sur le couteau au sol le rattrape
const GROUND_LIFE_S := 4.0
const WALL_MASK := 1
const SPIN_RAD_S := 14.0
const SUBSTEP_U := 0.25 ## pas maximal d'un déplacement (pas de tunnel à travers un monstre)
const PLANT_LIFT_U := 0.3 ## couteau dessiné au-dessus du monstre
const FRAMES := "res://assets/sprites/characters/rictus/variants/pendulum_knife/pendulum_knife.tres"
const THREAD_COLOR := Color("#9FC8C0")
const THREAD_ALPHA := 0.5
const THREAD_PX := 1.5
const THREAD_GLOW := 1.25
const THREAD_WAVE_HZ := 0.5
const THREAD_AMP_PX := 3.0

var caster: SpellCaster = null
var owner_player: CharacterBody2D = null
var spell: SpellData = null ## coup d'impact (aller)
var return_spell: SpellData = null ## coup du retour (0,6)
var state: State = State.FLYING
var dir := Vector2.RIGHT
var speed_px := 0.0
var range_px := 0.0
var travelled := 0.0
var target: Node2D = null ## monstre ficelé (PLANTED)
var tours := 0 ## tours de fil enroulés (anneaux dessinés)
var ground_left := GROUND_LIFE_S
var hits_total := 0
var thread := true ## fil dessiné jusqu'à la main du Montreur (faux pour les couteaux légers de l'Éventail)
var hand_fn: Callable = Callable() ## position monde de la main du Montreur (sinon au-dessus de Rictus)
var on_caught: Callable = Callable() ## couteau léger : appelé au rattrapage
var _hit: Dictionary = {} ## instance_id -> true, vidé à chaque retour
var _spin := 0.0
var _wave := 0.0
var _rest_angle := 0.0
var _last_target_pos := Vector2.ZERO
var _sprite: AnimatedSprite2D = null


## Crée et lance un couteau lourd depuis le joueur.
static func launch(c: SpellCaster, p: CharacterBody2D, s: SpellData, d: Vector2, spd_px: float, rng_px: float) -> RictusPendulum:
	var n := RictusPendulum.new()
	n.caster = c
	n.owner_player = p
	n.spell = s
	n.dir = d.normalized()
	n.speed_px = spd_px
	n.range_px = rng_px
	n._rest_angle = n.dir.angle()
	n.top_level = true
	c.effects_parent().add_child(n)
	n.global_position = p.global_position
	return n


## Couteau léger de l'Éventail qui revient en ligne vers Rictus (Saccade) : touche `s` une fois par monstre traversé.
static func recall_light(c: SpellCaster, p: CharacterBody2D, s: SpellData, at: Vector2, spd_px: float, frames_path: String) -> RictusPendulum:
	var n := RictusPendulum.new()
	n.caster = c
	n.owner_player = p
	n.spell = s
	n.return_spell = s
	n.speed_px = spd_px
	n.thread = false
	n.state = State.RETURNING
	n._frames_path = frames_path
	n.top_level = true
	c.effects_parent().add_child(n)
	n.global_position = at
	return n


var _frames_path := FRAMES


func _ready() -> void:
	z_index = 1
	if ResourceLoader.exists(_frames_path):
		var sf := load(_frames_path) as SpriteFrames
		if sf != null and sf.has_animation(&"default"):
			_sprite = AnimatedSprite2D.new()
			_sprite.sprite_frames = sf
			_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			add_child(_sprite)
			_sprite.play(&"default")
			if VfxSwap.enabled(): # mode test : VFX de test (scripts/testmode/vfx_swap.gd)
				VfxSwap.on_sprite(_sprite, sf)


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests : avance de `delta` s.
func step(delta: float) -> void:
	if caster == null or not is_instance_valid(caster) or owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	_spin += SPIN_RAD_S * delta
	_wave += delta
	match state:
		State.FLYING:
			_step_flying(delta)
		State.PLANTED:
			_step_planted()
		State.GROUND:
			_step_ground(delta)
		State.RETURNING:
			_step_returning(delta)
	if _sprite != null:
		var moving := state == State.FLYING or state == State.RETURNING
		_sprite.rotation = _spin if moving else _rest_angle
		_sprite.position = Vector2(0.0, Iso.lift_logical(PLANT_LIFT_U)) if state == State.PLANTED else Vector2.ZERO
	queue_redraw()


# --- Aller ---------------------------------------------------------------------------------------------

func _step_flying(delta: float) -> void:
	var left := speed_px * delta
	while left > 0.0001 and state == State.FLYING:
		var sub := minf(minf(left, SUBSTEP_U * Balance.UNIT_PX), range_px - travelled)
		if sub <= 0.0:
			drop_at(global_position)
			return
		var wall := _wall_ahead(sub)
		var adv := sub if wall < 0.0 else minf(sub, wall)
		global_position += dir * adv
		travelled += adv
		left -= sub
		var e := _enemy_at(true)
		if e != null:
			_impact(e)
			return
		if wall >= 0.0 or travelled >= range_px - 0.01:
			drop_at(global_position)
			return


## Coup d'impact puis couteau planté dans le monstre (ou au sol s'il est mort du coup).
func _impact(e: Node2D) -> void:
	hits_total += 1
	if spell != null:
		caster.deal_damage(e, spell, {"source_pos": owner_player.global_position})
	if not is_instance_valid(e) or e.get(&"active") == false or not e.is_inside_tree():
		drop_at(global_position, true)
		return
	plant_in(e)


## Planté dans `e` : suit le monstre.
func plant_in(e: Node2D) -> void:
	state = State.PLANTED
	target = e
	global_position = e.global_position
	_last_target_pos = global_position
	planted_in.emit(e)


func _step_planted() -> void:
	if target == null or not is_instance_valid(target) or not target.is_inside_tree() or target.get(&"active") == false:
		drop_at(_last_target_pos, true)
		return
	global_position = target.global_position
	_last_target_pos = global_position


## Tombe planté au sol à `at` (fil cassé, cible morte, bout de course, mur, expiration du ficelé).
func drop_at(at: Vector2, lost_target := false) -> void:
	state = State.GROUND
	target = null
	tours = 0
	global_position = at
	ground_left = GROUND_LIFE_S
	dropped.emit(at, lost_target)


func _step_ground(delta: float) -> void:
	ground_left -= delta
	if global_position.distance_to(owner_player.global_position) <= GROUND_CONTACT_U * Balance.UNIT_PX:
		_catch()
		return
	if ground_left <= 0.0:
		expired.emit()
		queue_free()


# --- Retour (Saccade) ----------------------------------------------------------------------------------

## Le Montreur tire le fil : le couteau revient en ligne vers Rictus. Le monstre où il était planté est déjà touché.
func recall(rs: SpellData) -> void:
	return_spell = rs
	_hit.clear()
	if target != null and is_instance_valid(target):
		_hit[target.get_instance_id()] = true
	target = null
	tours = 0
	state = State.RETURNING


func _step_returning(delta: float) -> void:
	var left := speed_px * delta
	while left > 0.0001 and state == State.RETURNING:
		var to := owner_player.global_position - global_position
		var dist := to.length()
		if dist <= CATCH_U * Balance.UNIT_PX:
			_catch()
			return
		var sub := minf(minf(left, SUBSTEP_U * Balance.UNIT_PX), dist)
		dir = to / dist
		_rest_angle = dir.angle()
		var wall := _wall_ahead(sub)
		var adv := sub if wall < 0.0 else minf(sub, wall)
		global_position += dir * adv
		left -= sub
		_hit_scan_return()
		if wall >= 0.0: # s'arrête contre le mur : retombe planté de ce côté
			if thread:
				drop_at(global_position)
			else:
				queue_free() # couteau léger : perdu (il n'était plus qu'un rappel)
			return
		if global_position.distance_to(owner_player.global_position) <= CATCH_U * Balance.UNIT_PX:
			_catch()
			return


func _hit_scan_return() -> void:
	var e := _enemy_at(false)
	while e != null:
		_hit[e.get_instance_id()] = true
		hits_total += 1
		if return_spell != null:
			caster.deal_damage(e, return_spell, {"source_pos": global_position})
		e = _enemy_at(false)


func _catch() -> void:
	if on_caught.is_valid():
		on_caught.call()
	caught.emit()
	queue_free()


# --- Géométrie -----------------------------------------------------------------------------------------

## Monstre actif au contact du couteau (le plus proche), pas encore touché ; `first_only` : aller (aucune mémoire).
func _enemy_at(_first_only: bool) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	var u := Balance.UNIT_PX
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or e.get(&"active") == false:
			continue
		if _hit.has(e.get_instance_id()):
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		var d: float = e.global_position.distance_to(global_position)
		if d <= HIT_RADIUS_U * u + er and d < best_d and StageMap.los(get_tree(), global_position, e.global_position):
			best_d = d
			best = e
	return best


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


# --- Rendu ---------------------------------------------------------------------------------------------

func _hand_pos() -> Vector2:
	if hand_fn.is_valid():
		return hand_fn.call()
	return owner_player.global_position + Vector2(0.0, Iso.lift_logical(1.4))


func _draw() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var lift := Vector2(0.0, Iso.lift_logical(PLANT_LIFT_U)) if state == State.PLANTED else Vector2.ZERO
	if thread:
		var to: Vector2 = _hand_pos() - global_position
		var col := Color(THREAD_COLOR.r * THREAD_GLOW, THREAD_COLOR.g * THREAD_GLOW, THREAD_COLOR.b * THREAD_GLOW, THREAD_ALPHA)
		var pts := PackedVector2Array()
		var n := 12
		var perp := to.orthogonal().normalized()
		for i in n + 1:
			var k := float(i) / n
			var wob := sin(_wave * TAU * THREAD_WAVE_HZ + k * 5.0) * THREAD_AMP_PX * sin(PI * k)
			pts.append(lift + (to - lift) * k + perp * wob)
		draw_polyline(pts, col, THREAD_PX / Iso.camera_zoom().x)
	# tours de fil : un anneau par tour autour du couteau
	for i in tours:
		draw_arc(lift, 7.0 + 3.5 * i, 0.0, TAU, 20, Color(THREAD_COLOR.r * 1.4, THREAD_COLOR.g * 1.4, THREAD_COLOR.b * 1.4, 0.8), 1.3)
	if _sprite != null:
		return
	var a := Vector2.from_angle(_spin if state == State.FLYING or state == State.RETURNING else _rest_angle)
	var pts2 := PackedVector2Array([a * 14.0 + lift, a.rotated(2.4) * 8.0 + lift, -a * 6.0 + lift, a.rotated(-2.4) * 8.0 + lift])
	draw_colored_polygon(pts2, Color(0.75, 0.85, 0.85))
	draw_polyline(PackedVector2Array([pts2[0], pts2[1], pts2[2], pts2[3], pts2[0]]), Color(THREAD_COLOR.r * 1.4, THREAD_COLOR.g * 1.4, THREAD_COLOR.b * 1.4), 1.5)
