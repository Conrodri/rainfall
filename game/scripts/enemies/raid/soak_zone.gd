class_name SoakZone
extends Node2D
## Zone à absorber (docs/Design_Boss_Raid.md §1.3) : cercle CYAN (jamais rouge) que le joueur doit occuper
## `hold_s` cumulées avant `life_s` ; la jauge se remplit quand il est dedans et se vide à moitié de vitesse
## dehors. Remplie : `filled` (+ on_filled.call(self)). Ratée à `life_s` : `failed`, puis selon `fail_mode` :
##   &"burst" : anneau rouge 1 -> 5 u télégraphé `burst_tele_s` (1,0 s), RaidKit.penalty_hit (RAID_SOAK_FAIL_COEF,
##              plafonné, non létal) si le joueur est dans l'anneau ;
##   &"adds"  : `fail_adds` monstres de tier 1 (jamais les deux) ;
##   &"none"  : rien (condition de bouclier SOAK : le garde-fou du bouclier suffit).
## Contour au sol : ZoneOutline (grammaire des zones posées) + jauge RaidFx `soak_fill` / forme provisoire.

signal filled(zone: SoakZone)
signal failed(zone: SoakZone)

const BURST_R0_U := 1.0
const BURST_R1_U := 5.0

var boss: Node2D = null
var r_u := 2.5
var hold_s := 1.5
var life_s := 5.0
var fail_mode: StringName = &"burst"
var fail_adds := 4
var burst_tele_s := 1.0
var on_filled: Callable = Callable()
var fill := 0.0 ## 0..1
var t := 0.0
var done := false
var is_failed := false
var _burst_t := -1.0
var _outline: ZoneOutline = null
var _gauge: Node2D = null
var _tele: RecluseFx = null


static func spawn(p_boss: Node2D, at: Vector2, opts: Dictionary = {}, p_on_filled := Callable()) -> SoakZone:
	var z := SoakZone.new()
	z.name = &"SoakZone"
	z.boss = p_boss
	z.r_u = float(opts.get("r_u", 2.5))
	z.hold_s = maxf(float(opts.get("hold_s", 1.5)), 0.05)
	z.life_s = float(opts.get("life_s", 5.0))
	z.fail_mode = StringName(opts.get("fail", &"burst"))
	z.fail_adds = int(opts.get("fail_adds", 4))
	z.on_filled = p_on_filled
	RaidKit.world_of(p_boss).add_child(z)
	z.global_position = RaidKit.place(p_boss, at)
	z.add_to_group(RaidFx.CUE_GROUP)
	z._outline = ZoneOutline.attach(z, z.r_u * RaidKit.U, RaidFx.CYAN)
	if z._outline != null:
		z._outline.emphasize()
	z._gauge = RaidFx.attach_ground(z, RaidFx.visual(&"soak_fill", RaidFx.Kind.SOAK, RaidFx.CYAN, z.r_u * RaidKit.U))
	RaidFx.set_value(z._gauge, 0.0)
	return z


func _physics_process(delta: float) -> void:
	step(delta)


func player_inside() -> bool:
	var pl := RaidKit.player_of(self)
	return pl != null and pl.global_position.distance_to(global_position) <= r_u * RaidKit.U


func step(delta: float) -> void:
	if _burst_t >= 0.0:
		_step_burst(delta)
		return
	if done or is_failed:
		return
	t += delta
	if player_inside():
		fill = minf(fill + delta / hold_s, 1.0)
	else:
		fill = maxf(fill - delta * 0.5 / hold_s, 0.0)
	RaidFx.set_value(_gauge, fill)
	if fill >= 1.0:
		done = true
		RaidFx.sfx(&"enemy.raid_soak_fill.light", global_position)
		filled.emit(self)
		if on_filled.is_valid():
			on_filled.call(self)
		_fade_out()
	elif life_s > 0.0 and t >= life_s:
		_fail()


func _fail() -> void:
	is_failed = true
	failed.emit(self)
	match fail_mode:
		&"burst":
			_burst_t = 0.0
			_tele = RecluseFx.make(RecluseFx.Kind.RING_TELE, EnemyTelegraph.FILL)
			RecluseFx.add_to_tele_layer(_tele, self)
			_tele.set_param(BURST_R1_U * RaidKit.U, BURST_R0_U * RaidKit.U, 0.0)
			if _gauge != null:
				_gauge.visible = false
		&"adds":
			Events.raid_mechanic_failed.emit(boss, &"soak")
			var d := RaidKit.director_of(self)
			if d != null:
				for i in fail_adds:
					d.spawn_enemy(1, RaidKit.place(boss, global_position + Vector2.from_angle(TAU * i / fail_adds) * RaidKit.U))
			_fade_out()
		_:
			_fade_out()


func _step_burst(delta: float) -> void:
	_burst_t += delta
	if _tele != null:
		_tele.set_param(BURST_R1_U * RaidKit.U, BURST_R0_U * RaidKit.U, clampf(_burst_t / burst_tele_s, 0.0, 1.0))
	if _burst_t < burst_tele_s:
		return
	_burst_t = -1.0
	var pl := RaidKit.player_of(self)
	var hit := false
	if pl != null:
		var d := pl.global_position.distance_to(global_position)
		hit = d <= BURST_R1_U * RaidKit.U
	if hit:
		RaidKit.penalty_hit(boss, pl, Balance.RAID_SOAK_FAIL_COEF, &"soak")
	else:
		Events.raid_mechanic_failed.emit(boss, &"soak")
	RaidFx.sfx(&"enemy.raid_soak_burst.heavy", global_position)
	_fade_out()


func _fade_out() -> void:
	if _outline != null and is_instance_valid(_outline):
		_outline.release()
	queue_free()


func _exit_tree() -> void:
	if _tele != null and is_instance_valid(_tele):
		_tele.queue_free()
