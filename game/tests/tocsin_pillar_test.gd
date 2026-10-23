extends Node
## Refonte de Tocsin du 23/10/2026 : (1) un membre au sol se rattache DANS LA FRAME du contact (capacité, calque,
## charge du bouton, recharge du SpellCaster), (2) le Bras-pilier se plante et décharge 5 s puis reste ramassable,
## (3) aucune perte de vitesse ni blocage liés aux membres (les jambes ne sont plus lancées).
## godot --headless --path game res://tests/tocsin_pillar_test.tscn

class FakeEnemy extends Node2D:
	var taken: Array = []
	var statuses: Array = []

	func take_damage(amount: float, _is_crit: bool = false, _element: StringName = &"") -> void:
		taken.append(amount)

	func apply_status(status: StringName, _data: Dictionary) -> void:
		statuses.append(status)

	func is_slowed() -> bool:
		return false


const U := 64.0
const BASE := 12.0
const DT := 1.0 / 60.0

var _fails := 0
var _player: CharacterBody2D
var _kit: TocsinKit
var _junk: Array = []


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _near(a: float, b: float, tol: float = 0.01) -> bool:
	return absf(a - b) <= tol


func _fake(pos: Vector2) -> FakeEnemy:
	var e := FakeEnemy.new()
	e.add_to_group("enemies")
	get_tree().root.add_child(e)
	e.global_position = pos
	_junk.append(e)
	return e


func _sim(t: float) -> void:
	for i in int(ceil(t / DT)):
		_player.spells._remaining[1] = 99.0
		_player.tick(DT)
		for l in _kit.limbs.values():
			if is_instance_valid(l):
				l.set_physics_process(false)
				l.step(DT)


func _limb(key: StringName) -> TocsinLimb:
	var l: TocsinLimb = _kit.limbs.get(key)
	return l if l != null and is_instance_valid(l) else null


func _reset() -> void:
	for j in _junk:
		if is_instance_valid(j):
			j.remove_from_group("enemies")
			j.queue_free()
	_junk.clear()
	_kit.regen_all()
	_player.global_position = Vector2.ZERO
	_player.velocity = Vector2.ZERO
	_player.is_moving = false
	_player.facing = Vector2.RIGHT
	_player.apply_stats({"crit_chance": -0.05})
	_player.clear_statuses()
	_player.dead = false
	_player.hp = _player.max_hp
	_player.spells.aim_override = null
	for k in _player.spells._remaining:
		_player.spells._remaining[k] = 0.0
	_sim(0.5)


## Lance le bras du slot 2 vers (x u, 0) et avance jusqu'à ce que `key` soit au sol avec son pickup.
func _throw_and_land(key: StringName, x_u: float) -> TocsinLimb:
	_player.spells.aim_override = Vector2(x_u * U, 0)
	_player.spells.cast(2)
	var guard := 0.0
	while guard < 9.0:
		_sim(DT)
		guard += DT
		var l := _limb(key)
		if l != null and l.phase == TocsinLimb.Phase.GROUND and l.pickup != null:
			return l
	return null


func _run() -> void:
	RunState.level = 1
	RunState.character = &"tocsin"
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	director.spawning_enabled = false
	get_tree().root.add_child(director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_player.set_physics_process(false)
	_kit = _player.kit as TocsinKit

	print("Bras-pilier : lancer et décharge 5 s")
	_reset()
	var victim := _fake(Vector2(7.0 * U, 0.5 * U))
	var out := _fake(Vector2(7.0 * U, 3.5 * U))
	_player.spells.aim_override = Vector2(12.0 * U, 0) # au-delà de la portée : le pilier tombe à 7 u
	_check("bras lancé", _player.spells.cast(2))
	var pil: TocsinLimb = null
	var g := 0.0
	while pil == null and g < 2.0:
		_sim(DT)
		g += DT
		pil = _limb(&"arm_l")
	_check("limb créé", pil != null)
	_check("point visé borné à la portée (7 u)", pil != null and _near(pil.target.x, 7.0 * U, 1.0), str(pil.target if pil else null))
	_check("rayon de zone 2,2 u", pil != null and _near(pil.radius_px, TocsinKit.PILLAR_RADIUS_U * U, 0.5))
	var t_plant := 0.0
	while is_instance_valid(pil) and pil.phase == TocsinLimb.Phase.FLY and t_plant < 2.0:
		_sim(DT)
		t_plant += DT
	_check("planté après le lob (0,6 s)", pil.phase == TocsinLimb.Phase.PILLAR and t_plant < 0.8, "%s %s" % [pil.phase, t_plant])
	var planted_at := pil.global_position
	_check("premier tick à la pose", victim.taken.size() == 1 and _near(victim.taken[0], TocsinKit.PILLAR_COEF * BASE), str(victim.taken))
	_sim(4.3)
	_check("encore en décharge vers 4,5 s", pil.phase == TocsinLimb.Phase.PILLAR and pil.pickup == null)
	_check("hors zone : rien", out.taken.is_empty())
	_sim(0.8)
	_check("10 ticks en 5 s", victim.taken.size() == 10, str(victim.taken.size()))
	_check("puis au sol, ramassable", pil.phase == TocsinLimb.Phase.GROUND and pil.pickup != null and is_instance_valid(pil.pickup))
	_check("position inchangée (le pilier ne bouge pas)", pil.global_position.distance_to(planted_at) < 1.0)
	_sim(1.0)
	_check("plus aucun tick au sol", victim.taken.size() == 10)
	_check("durée de décharge = 5 s (constantes)", _near(TocsinKit.PILLAR_S, 5.0) and TocsinKit.PILLAR_TICKS == 10)

	print("Ramassage : rattaché dans la frame du contact")
	var pk := pil.pickup
	_check("aucun délai de pose", _near(pk.delay_s, 0.0) and _near(TocsinKit.PICKUP_DELAY_S, 0.0))
	_check("bras absent avant contact", not _kit.present[&"arm_l"] and _kit.is_queued(&"arm_l") and _kit.charges(2) == 1)
	_player.global_position = pil.global_position
	pk.step(DT) # UNE seule frame de physique du pickup
	_check("présent aussitôt", bool(_kit.present[&"arm_l"]))
	_check("sorti de la file de recharge", not _kit.is_queued(&"arm_l") and (_kit.queue[2] as Array).is_empty())
	_check("2 charges rendues (bouton)", _kit.charges(2) == 2 and _player.get_spell_cooldowns().filter(func(c): return c.slot == 2)[0]["charges"] == Vector2i(2, 2))
	_check("recharge du sort remise à 0 dans la frame", _near(_player.spells._remaining[2], 0.0), str(_player.spells._remaining[2]))
	_check("ressource : 3/3 membres", _kit.resource_state()["filled"] == 3)
	_check("capacité immédiatement relançable", _player.spells.cast(2))

	print("Ramassage avec l'autre bras encore en recharge")
	_reset()
	var p1 := _throw_and_land(&"arm_l", 3.0)
	_check("bras gauche au sol", p1 != null)
	if p1 != null:
		_player.spells.aim_override = Vector2(3.0 * U, 0)
		_player.spells.cast(2) # le bras droit part aussi
		_check("0 charge", _kit.charges(2) == 0)
		_player.global_position = p1.global_position
		p1.pickup.step(DT)
		_check("un bras de retour : 1 charge", _kit.charges(2) == 1 and bool(_kit.present[&"arm_l"]) and not bool(_kit.present[&"arm_r"]))
		_check("sort prêt (reste une charge)", _near(_player.spells._remaining[2], 0.0), str(_player.spells._remaining[2]))
		_check("le bras droit reste en recharge", _kit.is_queued(&"arm_r") and float(_kit.recharge_left[2]) > 0.0)

	print("Fin de recharge pendant la décharge : le pilier finit puis part en braises")
	_reset()
	_player.spells.aim_override = Vector2(3.0 * U, 0)
	_player.spells.cast(2)
	_sim(1.2) # planté
	var pp := _limb(&"arm_l")
	_check("pilier en décharge", pp != null and pp.phase == TocsinLimb.Phase.PILLAR)
	_kit.recharge_left[2] = 0.01
	_sim(0.1)
	_check("bras revenu sur le robot", bool(_kit.present[&"arm_l"]))
	_check("le pilier continue de décharger", pp.phase == TocsinLimb.Phase.PILLAR and pp.expired)
	pp.set_physics_process(false) # le pilier n'est plus suivi par le kit : le test le fait avancer
	for i in int(5.2 / DT):
		_sim(DT)
		if is_instance_valid(pp):
			pp.step(DT)
	_check("fin : pas de pickup (déjà rattaché)", not is_instance_valid(pp) or pp.is_queued_for_deletion() or pp.phase == TocsinLimb.Phase.DONE)

	print("Aucune perte de vitesse ni blocage")
	_reset()
	_player.spells.aim_override = Vector2(4.0 * U, 0)
	_player.spells.cast(2)
	_player.spells.cast(2)
	_player.spells.cast(4)
	_sim(0.4)
	_check("2 bras + tête lancés : vitesse 4,0 u/s", _near(_player.move_speed(), 4.0 * U) and _near(_kit.speed_mult(), 1.0), str(_player.move_speed()))
	_check("jambes présentes (jamais lancées)", _kit.legs() == 2 and bool(_kit.present[&"leg_l"]) and bool(_kit.present[&"leg_r"]))
	_check("locomotion marche, roulade 3 u", _kit.locomotion() == &"walk" and _near(_kit.dodge_distance_u(), 3.0))
	_check("aucun slot bloqué", not _player.spells.is_slot_blocked(2) and not _player.spells.is_slot_blocked(3) and not _player.spells.is_slot_blocked(4))
	_check("Coup de tocsin lançable sans bras", _player.spells.cast(3))
	_check("pas de sort de jambe", _player.character.spells.all(func(s): return not String(s.id).contains("botte") and not String(s.id).contains("jambe")))
	_check("hitbox constante 0,5 u", _near(((_player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D).radius, 24.0))

	_reset()
	director.queue_free()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
