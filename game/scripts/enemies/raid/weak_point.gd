class_name WeakPoint
extends Area2D
## Point faible d'un boss façon raid (docs/Design_Boss_Raid.md §1.7) : sous-cible hors du cône frontal (dos, flancs),
## Area2D couche 3 dans le groupe `enemies` (le ciblage automatique et les sorts la touchent), PV = hp_frac des PV
## du boss. Exposé seulement quand le joueur est dans l'arc `exposed_arc_deg` centré sur la direction du point :
## sinon « gardé » (hors du groupe `enemies`, couche coupée, pointillés). Dégâts reçus transférés au boss
## × RAID_WEAK_TRANSFER avec hit["weak"] = true. À 0 PV : `on_broken.call(self)`, éclat, libéré.
## Duck typing minimal d'Enemy (is_boss, is_elite, tier, hp, max_hp, active, radius_px, aim_priority,
## apply_status, push, stun…) pour les sorts et kits qui parcourent le groupe `enemies`.

const LAYER_ENEMIES := 1 << 2
const RADIUS_U := 0.8 ## anneau de 0,8 u (consigne du kit)
const LIFT_U := 1.2 ## hauteur du point sur le corps (billboard)

var boss: Node2D = null
var offset_u := Vector2(-1.6, 0.0) ## repère du boss : +x = devant (direction `facing`), -x = dos
var exposed_arc_deg := 120.0
## Orientation du boss (rad) imposée par son cerveau ; NAN = Enemy._facing.
var facing_angle := NAN
var on_broken: Callable = Callable()
var exposed := false
var broken := false

# --- duck typing Enemy
var is_boss := false
var is_elite := false
var tier := 1
var hp := 1.0
var max_hp := 1.0
var active := true
var radius_px := RADIUS_U * 64.0
var aim_priority := 2.0 ## visé en priorité par le ciblage automatique (contrat SpellCaster, §1.9)
var boss_kind: StringName = &""
var affixes: Array[StringName] = []

var _vis: Node2D = null
var _shape: CollisionShape2D = null


static func attach(p_boss: Node2D, p_offset_u: Vector2, hp_frac := 0.05, arc_deg := 120.0, p_on_broken := Callable()) -> WeakPoint:
	var w := WeakPoint.new()
	w.boss = p_boss
	w.offset_u = p_offset_u
	w.exposed_arc_deg = arc_deg
	w.on_broken = p_on_broken
	var bhp: float = float(p_boss.get(&"max_hp")) if p_boss.get(&"max_hp") != null else 100.0
	w.max_hp = maxf(bhp * hp_frac, 1.0)
	w.hp = w.max_hp
	w.monitoring = false
	w.monitorable = true
	w.collision_layer = 0
	w.collision_mask = 0
	w._shape = CollisionShape2D.new()
	var cs := CircleShape2D.new()
	cs.radius = w.radius_px
	w._shape.shape = cs
	w.add_child(w._shape)
	w._vis = RaidFx.visual(&"weak_point", RaidFx.Kind.WEAK, RaidFx.CYAN, w.radius_px)
	w._vis.position = Vector2(0.0, -Iso.lift_logical(LIFT_U))
	w.add_child(w._vis)
	RaidKit.world_of(p_boss).add_child(w)
	w.add_to_group(RaidFx.CUE_GROUP)
	w.step(0.0)
	return w


func _physics_process(delta: float) -> void:
	step(delta)


## Suit le boss et met à jour l'exposition (test d'angle, aucune allocation).
func step(_delta: float) -> void:
	if broken:
		return
	if boss == null or not is_instance_valid(boss) or not bool(boss.get(&"active")):
		release()
		return
	var a := facing_angle
	if is_nan(a):
		a = float(boss.get(&"_facing")) if boss.get(&"_facing") != null else 0.0
	var dir := offset_u.rotated(a)
	global_position = boss.global_position + dir * RaidKit.U
	var pl := RaidKit.player_of(self)
	var on := false
	if pl != null and dir.length_squared() > 0.0001:
		var to_p := pl.global_position - boss.global_position
		on = absf(dir.angle_to(to_p)) <= deg_to_rad(exposed_arc_deg) * 0.5
	if on != exposed:
		_set_exposed(on)


func _set_exposed(on: bool) -> void:
	exposed = on
	collision_layer = LAYER_ENEMIES if on else 0
	if on:
		add_to_group(&"enemies")
	elif is_in_group(&"enemies"):
		remove_from_group(&"enemies")
	RaidFx.set_state(_vis, 1 if on else 0)


func take_damage(amount: float, is_crit: bool = false, element: StringName = &"", hit: Dictionary = {}) -> void:
	if broken or not exposed or amount <= 0.0:
		return
	hp -= amount
	if boss != null and is_instance_valid(boss) and boss.has_method(&"take_damage"):
		var h := hit.duplicate()
		h["weak"] = true
		boss.take_damage(amount * Balance.RAID_WEAK_TRANSFER, is_crit, element, h)
	if hp <= 0.0:
		_break()


func _break() -> void:
	broken = true
	_set_exposed(false)
	RaidFx.sfx(&"enemy.raid_weak_break.heavy", global_position)
	if on_broken.is_valid():
		on_broken.call(self)
	queue_free()


func release() -> void:
	broken = true
	if is_in_group(&"enemies"):
		remove_from_group(&"enemies")
	queue_free()


# --- duck typing Enemy (sans effet : un point faible ne subit ni statut ni recul)
func apply_status(_status: StringName, _data: Dictionary) -> void:
	pass


func push(_offset_px: Vector2) -> void:
	pass


func stun(_seconds: float) -> void:
	pass


func is_stunned() -> bool:
	return false


func is_slowed() -> bool:
	return false


func is_burning() -> bool:
	return false


func is_poisoned() -> bool:
	return false


func status_mask() -> int:
	return 0


func status_list() -> Array:
	return []


func imprison(_seconds: float, _release_pct := 0.0, _release_s := 0.0) -> void:
	pass


func release_imprison(_release_pct := -1.0, _release_s := -1.0) -> void:
	pass


func hold_at(_p: Vector2) -> void:
	pass


func is_imprisoned() -> bool:
	return false


func add_damage_taken_mod(_id: Variant, _mult: float, _duration: float = -1.0) -> void:
	pass


func remove_damage_taken_mod(_id: Variant) -> void:
	pass
