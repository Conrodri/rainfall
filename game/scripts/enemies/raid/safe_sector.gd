class_name SafeSector
extends Node2D
## Zone sûre qui tourne (docs/Design_Boss_Raid.md §1.5) : tout le disque (`radius_u`, zone de charge 9 u) devient
## dangereux sauf un secteur de `sector_deg` qui tourne à `turn_deg_s`. Télégraphe `tele_s` (1,2 s) : secteur cyan
## + reste rouge translucide, aucun dégât. Puis, `duration_s` durant, toutes les `tick_s` (0,5 s) : joueur dans le
## disque mais hors du secteur -> RaidKit.penalty_hit (RAID_SECTOR_TICK_COEF, plafonné, non létal) + ralentissement
## RAID_SECTOR_SLOW_PCT. Répit : toutes les `respite_every_s` (8 s), `respite_s` (2 s) sans rotation.
## Vitesse au bord bornée : turn_deg_s est ramené pour que le bord ne dépasse jamais `max_edge_speed_u` (6,3 u/s).

signal finished(sector: SafeSector)

const MAX_EDGE_SPEED_U := 6.3

var boss: Node2D = null
var radius_u := 9.0
var sector_deg := 90.0
var turn_deg_s := 30.0
var duration_s := 7.0
var tele_s := 1.2
var tick_s := 0.5
var respite_every_s := 8.0
var respite_s := 2.0
var angle := 0.0 ## direction (rad) du milieu du secteur sûr
var t := 0.0
var ticks_hit := 0
var _tick_t := 0.0
var _vis: Node2D = null
var _arrow: Node2D = null
var _done := false


static func spawn(p_boss: Node2D, center: Vector2, opts: Dictionary = {}) -> SafeSector:
	var s := SafeSector.new()
	s.name = &"SafeSector"
	s.boss = p_boss
	s.radius_u = float(opts.get("radius_u", 9.0))
	s.sector_deg = float(opts.get("sector_deg", 90.0))
	s.turn_deg_s = float(opts.get("turn_deg_s", 30.0))
	s.duration_s = float(opts.get("duration_s", 7.0))
	s.tele_s = maxf(float(opts.get("tele_s", 1.2)), 1.2)
	s.tick_s = float(opts.get("tick_s", 0.5))
	s.angle = float(opts.get("angle", 0.0))
	var max_turn := rad_to_deg(MAX_EDGE_SPEED_U / maxf(s.radius_u, 0.1))
	s.turn_deg_s = clampf(s.turn_deg_s, -max_turn, max_turn)
	RaidKit.world_of(p_boss).add_child(s)
	s.global_position = center
	s._vis = RaidFx.attach_ground(s, RaidFx.visual(&"safe_sector", RaidFx.Kind.SECTOR, RaidFx.CYAN, s.radius_u * RaidKit.U))
	RaidFx.set_value(s._vis, deg_to_rad(s.sector_deg) * 0.5)
	s._vis.rotation = s.angle
	return s


## Vitesse du bord du secteur (u/s) : tests et réglage.
func edge_speed_u() -> float:
	return deg_to_rad(absf(turn_deg_s)) * radius_u


func in_safe(p: Vector2) -> bool:
	var d := p - global_position
	if d.length() > radius_u * RaidKit.U:
		return true # hors du disque : rien
	return absf(angle_difference(angle, d.angle())) <= deg_to_rad(sector_deg) * 0.5


func is_live() -> bool:
	return t >= tele_s and not _done


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _done:
		return
	t += delta
	if t < tele_s:
		modulate.a = 0.5 + 0.5 * (t / tele_s)
		return
	var live_t := t - tele_s
	var in_respite := respite_every_s > 0.0 and fmod(live_t, respite_every_s + respite_s) >= respite_every_s
	if not in_respite:
		angle = wrapf(angle + deg_to_rad(turn_deg_s) * delta, -PI, PI)
		if _vis != null:
			_vis.rotation = angle
	_tick_t += delta
	if _tick_t >= tick_s:
		_tick_t -= tick_s
		var pl := RaidKit.player_of(self)
		if pl != null and not in_safe(pl.global_position):
			ticks_hit += 1
			RaidKit.penalty_hit(boss, pl, Balance.RAID_SECTOR_TICK_COEF, &"sector")
			if pl.has_method(&"apply_slow"):
				pl.apply_slow(1.0 - Balance.RAID_SECTOR_SLOW_PCT, tick_s + 0.1, &"raid_sector")
	if live_t >= duration_s:
		_done = true
		finished.emit(self)
		queue_free()
