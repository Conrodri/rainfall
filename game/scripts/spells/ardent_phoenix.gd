class_name ArdentPhoenix
extends Node2D
## Phénix d'Ardent (variante de l'ultime) : familier volant, invulnérable (il est en feu), 12 s. Il suit Ardent
## (laisse 8 u), pique toutes les 1,5 s sur le paquet le plus dense à 8 u (ligne 3 u × 1 u, brûlure 2 s), puis
## explose en se consumant (zone rayon 3 u). Un seul à la fois (ArdentVariantKit).
## Ce n'est PAS un Decoy : il ne provoque personne (volant, intouchable) ; groupe `allies` seulement.
## Dégâts toujours via SpellCaster (deal_damage / spawn_zone) : items et procs du joueur s'appliquent.
## Visuel : assets/sprites/vfx/phoenix/phoenix.tres (rendu 55°, à re-rendre iso : brief _ardv.txt), sinon disque dessiné.

const LIFE_S := 12.0
const SPEED_U := 6.0
const DIVE_SPEED_U := 24.0
const DIVE_EVERY_S := 1.5
const DIVE_RANGE_U := 8.0
const LINE_LEN_U := 3.0
const LINE_HALF_W_U := 0.5 ## ligne de 1 u de large
const HOVER_U := 1.2 ## altitude visuelle
const FOLLOW_U := 1.4 ## distance de suivi derrière Ardent
const BURN_S := 2.0
const BURN_COEF := 0.8 ## total de la brûlure, en Dégât_base (0,2 par 0,5 s pendant 2 s)
const FRAMES := "res://assets/sprites/vfx/phoenix/phoenix.tres"
const SPRITE_SCALE := 0.37 ## frame 256 px -> ~1,5 u d'envergure

var caster: SpellCaster = null
var player: Node2D = null
var dive_spell: SpellData = null
var burst_spell: SpellData = null
var life_left := LIFE_S
var exploded := false
var diving := false
var dives := 0 ## piqués portés (tests)
var strikes_hit := 0 ## monstres touchés par les piqués (tests)
var _dive_cd := 0.5
var _dir := Vector2.RIGHT
var _impact := Vector2.ZERO
var _goal := Vector2.ZERO
var _struck := false
var _sprite: AnimatedSprite2D = null


func setup(new_caster: SpellCaster, new_player: Node2D, dive: SpellData, burst: SpellData) -> void:
	caster = new_caster
	player = new_player
	dive_spell = dive
	burst_spell = burst
	name = "Phoenix"
	add_to_group(&"allies")
	global_position = player.global_position + Vector2(-FOLLOW_U * Balance.UNIT_PX, 0.0)
	_build_visual()


func _build_visual() -> void:
	if ResourceLoader.exists(FRAMES):
		var sf := load(FRAMES) as SpriteFrames
		if sf != null and sf.has_animation(&"default"):
			_sprite = AnimatedSprite2D.new()
			_sprite.sprite_frames = sf
			_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE) * Iso.UNSQUASH
			_sprite.position = Vector2(0.0, Iso.lift_logical(HOVER_U))
			add_child(_sprite)
			_sprite.play(&"default")
	LightRig.attach(self, &"phoenix")


func _physics_process(delta: float) -> void:
	step(delta)


## Public pour les tests : avance de `delta` s.
func step(delta: float) -> void:
	if exploded:
		return
	life_left -= delta
	if life_left <= 0.0:
		explode()
		return
	_dive_cd -= delta
	if diving:
		_step_dive(delta)
	else:
		_step_follow(delta)
	if _dive_cd <= 0.0 and not diving:
		_try_dive()
	if _sprite != null and absf(_dir.x) > 0.05:
		_sprite.flip_h = _dir.x < 0.0


func _step_follow(delta: float) -> void:
	var u := Balance.UNIT_PX
	var want: Vector2 = player.global_position + Vector2(-FOLLOW_U * u, 0.0)
	global_position = global_position.move_toward(want, SPEED_U * u * delta)
	var off: Vector2 = global_position - player.global_position
	if off.length() > DIVE_RANGE_U * u: # laisse
		global_position = player.global_position + off.normalized() * DIVE_RANGE_U * u


func _try_dive() -> void:
	var rng_px: float = DIVE_RANGE_U * Balance.UNIT_PX * (1.0 + player.stat(&"range_add"))
	var pt: Variant = caster.densest_point(rng_px)
	if pt == null:
		_dive_cd = 0.3
		return
	_impact = pt
	_dir = _impact - global_position
	_dir = _dir.normalized() if _dir.length_squared() > 1.0 else Vector2.RIGHT
	_goal = _impact + _dir * (LINE_LEN_U * 0.5 * Balance.UNIT_PX)
	diving = true
	_struck = false
	_dive_cd = DIVE_EVERY_S
	dives += 1
	Audio.play_cast(&"phoenix", global_position, dive_spell.coef)


func _step_dive(delta: float) -> void:
	var u := Balance.UNIT_PX
	global_position = global_position.move_toward(_goal, DIVE_SPEED_U * u * delta)
	if not _struck and global_position.distance_to(_impact) <= 0.4 * u:
		_struck = true
		_strike()
	if global_position.distance_to(_goal) <= 1.0:
		if not _struck:
			_struck = true
			_strike()
		diving = false


## Ligne de LINE_LEN_U × 1 u centrée sur le point d'impact, orientée par la direction du piqué.
func _strike() -> void:
	var u := Balance.UNIT_PX
	var a := _impact - _dir * (LINE_LEN_U * 0.5 * u)
	var b := _impact + _dir * (LINE_LEN_U * 0.5 * u)
	var burn_total: float = BURN_COEF * Balance.player_base_damage(RunState.level) * (1.0 + player.stat(&"burn_damage_add"))
	LightRig.flash(_impact, &"flame_pillar", 0.25)
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if not (e is Node2D) or not is_instance_valid(e) or not e.has_method(&"take_damage") or e.get(&"active") == false:
			continue
		var er: float = float(e.get(&"radius_px")) if &"radius_px" in e else 0.0
		var closest := Geometry2D.get_closest_point_to_segment(e.global_position, a, b)
		if closest.distance_to(e.global_position) > LINE_HALF_W_U * u + er:
			continue
		strikes_hit += 1
		caster.deal_damage(e, dive_spell, {"source_pos": global_position})
		if e.has_method(&"apply_status"):
			e.apply_status(&"burn", {"duration": BURN_S, "total": burn_total})


## Se consume : explosion (zone du sort `burst_spell`), puis disparition.
func explode() -> void:
	if exploded:
		return
	exploded = true
	if caster != null and is_instance_valid(caster) and burst_spell != null:
		caster.spawn_zone(burst_spell, global_position)
		LightRig.flash(global_position, &"nova", 0.35)
		Audio.play_cast(burst_spell.id, global_position, burst_spell.coef)
	queue_free()


## Disparaît sans exploser (changement d'étage).
func dismiss() -> void:
	exploded = true
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10.0, Color(0.0, 0.0, 0.0, 0.28)) # ombre de contact
	if _sprite == null:
		draw_set_transform(Vector2(0.0, Iso.lift_logical(HOVER_U)), 0.0, Iso.UNSQUASH)
		draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.5, 0.15, 0.35))
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.75, 0.3, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
