class_name PriorityAdds
extends Node2D
## Adds prioritaires (docs/Design_Boss_Raid.md §1.4) : serviteurs à tuer avant qu'ils n'atteignent le boss.
## Spawn par Director.spawn_enemy (tier `tier`, pool commun : aucune instanciation), PV = add_hp_frac des PV du boss,
## vitesse walk_u, aucun coup (dégâts 0), `aim_priority` 2 (ciblage automatique), `walk_target` = le boss
## (Enemy marche vers lui). Habillage : extras `<prefix>run_<dir>` du .tres du boss (EnemyVisual.set_skin_frames),
## sinon le monstre du biome ; halo clignotant 2 Hz (forme provisoire RaidFx RING tant que le kit n'est pas rendu).
## Échec : add au contact du boss -> boss soigné de heal_frac de ses PV max (plafond heal_cap_frac pour ce groupe),
## Events.raid_mechanic_failed(boss, &"add_reached"), add retiré sans prime. Plafond : MAX adds vivants.

signal add_killed(add: Enemy)
signal add_reached(add: Enemy)

const MAX := 3
const BLINK_HZ := 2.0
const SPAWN_RING_U := 6.0

var boss: Node2D = null
var heal_frac := Balance.RAID_ADD_HEAL_FRAC
var heal_cap_frac := Balance.RAID_ADD_HEAL_CAP_FRAC
var healed := 0.0 ## PV rendus au boss par ce groupe
var walk_u := 2.0
var adds: Array[Enemy] = []
var _halos: Array[Node2D] = []
var _t := 0.0


static func create(p_boss: Node2D) -> PriorityAdds:
	var p := PriorityAdds.new()
	p.name = &"PriorityAdds"
	p.boss = p_boss
	RaidKit.world_of(p_boss).add_child(p)
	return p


func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)


func alive() -> int:
	return adds.size()


## Fait sortir `count` adds autour du boss (côté `toward`, ex. le joueur ; sinon en anneau). opts : add_hp_frac
## (0,07), walk_u (2,0), tier (1), prefix (&"stoker_"), ring_u (SPAWN_RING_U). Retourne le nombre sorti (plafond MAX).
func spawn(count: int, opts: Dictionary = {}, toward := Vector2.INF) -> int:
	var d := RaidKit.director_of(boss)
	if d == null or boss == null or not is_instance_valid(boss):
		return 0
	walk_u = float(opts.get("walk_u", walk_u))
	var hp_frac := float(opts.get("add_hp_frac", 0.07))
	var tier := int(opts.get("tier", 1))
	var ring := float(opts.get("ring_u", SPAWN_RING_U)) * RaidKit.U
	var prefix := StringName(opts.get("prefix", &"stoker_"))
	var frames: SpriteFrames = null
	var bv := boss.get(&"visual") as EnemyVisual
	if bv != null and bv.body_sprite() != null:
		frames = bv.body_sprite().sprite_frames
	var base := 0.0
	if toward != Vector2.INF:
		base = (toward - boss.global_position).angle()
	var n := 0
	for i in count:
		if adds.size() >= MAX:
			break
		var a := base + (float(i) - (count - 1) * 0.5) * 0.9
		var pos := RaidKit.place(boss, boss.global_position + Vector2.from_angle(a) * ring)
		var e := d.spawn_enemy(tier, pos, false, [] as Array[StringName], Enemy.VARIANT_SHOOTER)
		if e == null:
			break
		var bhp: float = float(boss.get(&"max_hp"))
		e.max_hp = maxf(bhp * hp_frac, 1.0)
		e.hp = e.max_hp
		e.damage = 0.0
		e.speed_px = walk_u * RaidKit.U
		e.aim_priority = 2.0
		e.walk_target = boss
		if frames != null and e.visual is EnemyVisual:
			(e.visual as EnemyVisual).set_skin_frames(frames, prefix)
		var halo := RaidFx.visual(&"raid_add_halo", RaidFx.Kind.RING, RaidFx.CYAN, e.radius_px * 1.4)
		halo.z_index = -1
		e.add_child(halo)
		e.add_to_group(RaidFx.CUE_GROUP)
		adds.append(e)
		_halos.append(halo)
		n += 1
	return n


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_t += delta
	var blink := 0.55 + 0.45 * cos(TAU * BLINK_HZ * _t)
	var i := adds.size() - 1
	while i >= 0:
		var e := adds[i]
		if not is_instance_valid(e) or not e.active or e.walk_target != boss:
			_drop(i) # retiré hors mécanique (changement d'étage, pool)
		else:
			var h := _halos[i]
			if is_instance_valid(h):
				h.modulate.a = blink
			if boss != null and is_instance_valid(boss) \
					and e.global_position.distance_to(boss.global_position) <= e.radius_px + float(boss.get(&"radius_px")) + 8.0:
				_reach(i)
		i -= 1


func _reach(i: int) -> void:
	var e := adds[i]
	var bhp: float = float(boss.get(&"max_hp"))
	var heal := minf(bhp * heal_frac, maxf(bhp * heal_cap_frac - healed, 0.0))
	if heal > 0.0:
		healed += heal
		boss.set(&"hp", minf(float(boss.get(&"hp")) + heal, bhp))
	Events.raid_mechanic_failed.emit(boss, &"add_reached")
	RaidFx.sfx(&"enemy.raid_add_heal.heavy", boss.global_position)
	_drop(i)
	add_reached.emit(e)
	var d := RaidKit.director_of(boss)
	if d != null and e.active:
		d.release_enemy(e) # sans prime ni Events.enemy_killed


func _on_enemy_killed(enemy: Node2D, _pos: Vector2, _tier: int, _elite: bool) -> void:
	var i := adds.find(enemy)
	if i < 0:
		return
	var e := adds[i]
	_drop(i)
	add_killed.emit(e)


func _drop(i: int) -> void:
	var e := adds[i]
	var h := _halos[i]
	if is_instance_valid(h):
		h.queue_free()
	if is_instance_valid(e):
		if e.walk_target == boss:
			e.walk_target = null
			e.aim_priority = 1.0
		if e.is_in_group(RaidFx.CUE_GROUP):
			e.remove_from_group(RaidFx.CUE_GROUP)
	adds.remove_at(i)
	_halos.remove_at(i)


## Retire les adds restants (sans prime) et libère le gestionnaire.
func release() -> void:
	var d := RaidKit.director_of(boss)
	while not adds.is_empty():
		var e := adds[adds.size() - 1]
		_drop(adds.size() - 1)
		if d != null and is_instance_valid(e) and e.active:
			d.release_enemy(e)
	queue_free()
