class_name FixateMark
extends Node2D
## Fixation (docs/Design_Boss_Raid.md §1.6) : le boss cible un point (position du joueur à l'armement ou point du
## décor) et y déclenche une action longue. Déroulé : verrouillage `lock_s` (>= 0,8 s : marqueur « X » blanc qui
## tourne, ligne pointillée boss -> point), puis le point est FIXÉ (marqueur rouge, signal `locked`) et l'action
## dure `duration_s` : toutes les `tick_s`, selon `mode` :
##   &"avoid"  : joueur à moins de `radius_u` du point -> coup du boss (coef `coef`, RaidKit.boss_hit) ;
##   &"return" : joueur hors du cercle -> pénalité plafonnée non létale (RaidKit.penalty_hit) ;
##   &"none"   : aucun dégât, le cerveau du boss joue son action (signal `fired` à chaque tick).
## Fin : `finished`, libéré. `point` reste lisible par le cerveau (roue, pluie, appât…).

signal locked(mark: FixateMark)
signal fired(mark: FixateMark)
signal finished(mark: FixateMark)

const MIN_LOCK_S := 0.8
const MIN_RADIUS_U := 1.2

var boss: Node2D = null
var point := Vector2.ZERO
var lock_s := 1.0
var duration_s := 2.5
var radius_u := 2.0
var tick_s := 0.5
var coef := 0.5
var mode: StringName = &"avoid"
var t := 0.0
var is_locked := false
var hits := 0
var _tick_t := 0.0
var _mark: Node2D = null
var _link: Node2D = null
var _zone: ZoneOutline = null
var _link_len := -1.0


static func spawn(p_boss: Node2D, at: Vector2, opts: Dictionary = {}) -> FixateMark:
	var m := FixateMark.new()
	m.name = &"FixateMark"
	m.boss = p_boss
	m.lock_s = maxf(float(opts.get("lock_s", 1.0)), MIN_LOCK_S)
	m.duration_s = float(opts.get("duration_s", 2.5))
	m.radius_u = maxf(float(opts.get("radius_u", 2.0)), MIN_RADIUS_U)
	m.tick_s = maxf(float(opts.get("tick_s", 0.5)), 0.1)
	m.coef = float(opts.get("coef", 0.5))
	m.mode = StringName(opts.get("mode", &"avoid"))
	RaidKit.world_of(p_boss).add_child(m)
	m.point = RaidKit.place(p_boss, at)
	m.global_position = m.point
	m.add_to_group(RaidFx.CUE_GROUP)
	m._link = RaidFx.attach_ground(m, RaidFx.visual(&"fixate_link", RaidFx.Kind.LINK, RaidFx.NEUTRAL, 64.0), -2)
	if m._link is RaidFx:
		(m._link as RaidFx).width = 3.0
	m._mark = RaidFx.attach_ground(m, RaidFx.visual(&"fixate_mark", RaidFx.Kind.FIXATE, RaidFx.NEUTRAL, 0.9 * RaidKit.U))
	m._sync_link()
	return m


func _physics_process(delta: float) -> void:
	step(delta)


func player_inside() -> bool:
	var pl := RaidKit.player_of(self)
	return pl != null and pl.global_position.distance_to(point) <= radius_u * RaidKit.U


func step(delta: float) -> void:
	t += delta
	_sync_link()
	if not is_locked:
		if _mark != null and _mark is RaidFx:
			_mark.rotation += TAU * 0.5 * delta
		if t >= lock_s:
			_lock()
		return
	_tick_t += delta
	if _tick_t >= tick_s:
		_tick_t -= tick_s
		fired.emit(self)
		var pl := RaidKit.player_of(self)
		if pl != null:
			var inside := player_inside()
			if mode == &"avoid" and inside:
				hits += 1
				RaidKit.boss_hit(boss, pl, coef)
			elif mode == &"return" and not inside:
				hits += 1
				RaidKit.penalty_hit(boss, pl, coef, &"fixate")
	if t >= lock_s + duration_s:
		finished.emit(self)
		if _zone != null and is_instance_valid(_zone):
			_zone.release()
		queue_free()


func _lock() -> void:
	is_locked = true
	if _mark != null:
		_mark.rotation = 0.0
		RaidFx.set_value(_mark, 1.0)
		RaidFx.set_state(_mark, 1)
	_zone = ZoneOutline.attach(self, radius_u * RaidKit.U, RaidFx.DANGER if mode != &"return" else RaidFx.CYAN)
	if _zone != null:
		_zone.emphasize()
	RaidFx.sfx(&"enemy.raid_fixate_lock.medium", point)
	locked.emit(self)


## Ligne pointillée boss -> point : redessinée seulement si la longueur bouge de plus de 8 px.
func _sync_link() -> void:
	if _link == null or boss == null or not is_instance_valid(boss):
		return
	var d := boss.global_position - point
	_link.rotation = d.angle()
	var l := d.length()
	if absf(l - _link_len) > 8.0:
		_link_len = l
		if _link is RaidFx:
			(_link as RaidFx).radius = l
			_link.queue_redraw()
		else:
			_link.scale.x = l / 512.0 # anim fixate_link : cellule de 512 px vers +x
