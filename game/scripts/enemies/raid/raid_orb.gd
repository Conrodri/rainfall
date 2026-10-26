class_name RaidOrb
extends GroundPickup
## Orbe de rupture de bouclier (condition ORBS, docs/Design_Boss_Raid.md §1.1) : jetée par le boss avec un cercle
## de chute rouge de 1,5 u télégraphé `fall_s` (1,0 s, coef RAID_ORB_FALL_COEF si le joueur est dessous), puis
## posée au sol, ramassée au contact (`pickup_u`, aucune visée : marche sur les trois plateformes). Groupe
## RaidFx.CUE_GROUP (flèche hors écran). Visuel : anim `raid_orb` du kit, sinon forme provisoire.

const KIND := &"raid_orb"
const FALL_R_U := 1.5
const ARC_LIFT := 96.0 ## hauteur du vol (px logiques)

var kind := KIND
var boss: Node2D = null
var fall_s := 1.0
var landed := false
var _from_local := Vector2.ZERO
var _fall_t := 0.0
var _vis: Node2D = null
var _tele: EnemyTelegraph = null


## Jette une orbe de `from` vers `to` (coordonnées globales logiques). `life_s` : durée au sol après la chute.
static func throw(parent: Node, p_boss: Node2D, from: Vector2, to: Vector2, p_player: Node2D, p_on_collect: Callable,
		p_life_s := 25.0, p_pickup_u := 0.8, p_fall_s := 1.0) -> RaidOrb:
	var o := RaidOrb.new()
	o.boss = p_boss
	o.player = p_player
	o.on_collect = p_on_collect
	o.fall_s = maxf(p_fall_s, 0.0)
	o.delay_s = o.fall_s
	o.life_s = o.fall_s + p_life_s
	o.contact_u = p_pickup_u
	o.show_placeholder = false
	o.color = RaidFx.CYAN
	parent.add_child(o)
	o.global_position = to
	o._from_local = from - to
	o._vis = RaidFx.visual(&"raid_orb", RaidFx.Kind.ORB, RaidFx.CYAN, 20.0)
	o.add_child(o._vis)
	o.add_to_group(RaidFx.CUE_GROUP)
	if o.fall_s > 0.0:
		o._tele = EnemyTelegraph.new()
		parent.add_child(o._tele)
		o._tele.show_circle(to, FALL_R_U * RaidKit.U)
		o._vis.position = o._from_local
	else:
		o._land()
	return o


func step(delta: float) -> void:
	if not landed:
		_fall_t += delta
		var k := clampf(_fall_t / maxf(fall_s, 0.001), 0.0, 1.0)
		if _vis != null:
			_vis.position = _from_local * (1.0 - k) + Vector2(0.0, -ARC_LIFT * 4.0 * k * (1.0 - k))
		if _tele != null and is_instance_valid(_tele):
			_tele.set_progress(k)
		if _fall_t >= fall_s:
			_land()
	super.step(delta)


func _land() -> void:
	landed = true
	if _vis != null:
		_vis.position = Vector2.ZERO
	if _tele != null and is_instance_valid(_tele):
		_tele.queue_free()
	_tele = null
	if fall_s > 0.0 and player != null and is_instance_valid(player) \
			and player.global_position.distance_to(global_position) <= FALL_R_U * RaidKit.U:
		RaidKit.boss_hit(boss, player, Balance.RAID_ORB_FALL_COEF)
	GroundMarker.attach(self, 0.5, true)


func _exit_tree() -> void:
	if _tele != null and is_instance_valid(_tele):
		_tele.queue_free()
