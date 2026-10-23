extends Node
## Test headless des cycles anticipation -> coup -> récupération (docs/Comportements_Monstres.md).
## Tireur : immobile pendant l'armement et la récupération, projectile seulement après l'armement (durée
## respectée), visée suivie puis verrouillée, salve, pose d'attaque et teinte ; jetons : au plus
## SHOOTER_MAX_CHARGING tireurs arment en même temps. Mêlée : brute immobile pendant armement + récupération,
## bondisseur immobile après sa course, essaim sur place et petit recul après une morsure.
## godot --headless --path game res://tests/ranged_behavior_test.tscn

const U := 64.0
const DT := 1.0 / 60.0

var _fails := 0
var _director: Director
var _pool: EnemyProjectilePool
var _player: FakePlayer
var _pp := Vector2.ZERO ## position du joueur en coordonnées logiques (repère des monstres, conteneur du Director)


class FakePlayer extends Node2D:
	var hits := 0

	func take_damage(_amount: float, _source: Node = null) -> void:
		hits += 1


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


## Un tick à DT d'un monstre (Director arrêté : aucun autre mouvement), après une image physique.
func _step(e: Enemy) -> void:
	await get_tree().physics_frame
	e.tick(DT, _player, _pp, Vector2.ZERO)


func _spawn(tier: int, variant: int, offset_u: Vector2) -> Enemy:
	var e := _director.spawn_enemy(tier, Vector2(-80 * U, -80 * U), false, [] as Array[StringName], variant)
	e.position = _pp + offset_u * U
	e._attack_cd = 99.0
	e._spell_cd = 99.0
	return e


func _park(e: Enemy) -> void:
	_director.release_enemy(e)


func _run() -> void:
	RunState.level = 1
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	await get_tree().process_frame
	_director.process_mode = Node.PROCESS_MODE_DISABLED # les monstres ne bougent que par nos ticks
	_pool = _director.get_node(^"EnemyProjectiles") as EnemyProjectilePool
	_player = FakePlayer.new()
	get_tree().root.add_child(_player)
	_pp = Vector2.ZERO
	Enemy.reset_shot_tokens()

	await _test_shot()
	await _test_aim_lock()
	await _test_salvo()
	await _test_tokens()
	await _test_brute()
	await _test_leaper()
	await _test_swarm()

	_player.queue_free()
	_director.queue_free()
	await get_tree().process_frame
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _test_shot() -> void:
	print("Tireur : tir simple")
	var e := _spawn(2, Enemy.VARIANT_SHOOTER, Vector2(7.0, 0.0)) # au-delà de la distance préférée : avancerait
	e._attack_cd = 0.0
	var p0 := e.position
	await _step(e)
	_check("armement lancé (SHOT)", e._windup == Enemy.Windup.SHOT, str(e._windup))
	_check("pose d'attaque jouée", String(e.visual.current_anim()).begins_with("attack_") or e.visual.current_anim() == &"", String(e.visual.current_anim()))
	_check("teinte d'armement", e.visual._charge_mod != Color.WHITE)
	_check("ligne de visée affichée", e.telegraph.visible)
	var frames := 1
	var moved := false
	while _pool.active_count() == 0 and frames < 200:
		await _step(e)
		frames += 1
		moved = moved or e.position.distance_to(p0) > 0.01
	var t := frames * DT
	_check("immobile pendant l'armement", not moved, str(e.position - p0))
	_check("projectile parti après l'armement (%.2f s)" % t, absf(t - Balance.SHOOTER_WINDUP_S) <= 2.5 * DT, "attendu %.2f" % Balance.SHOOTER_WINDUP_S)
	_check("un seul projectile", _pool.active_count() == 1, str(_pool.active_count()))
	_check("jeton rendu au tir", Enemy.charging_shooters() == 0, str(Enemy.charging_shooters()))
	_check("récupération (RECOVER)", e._windup == Enemy.Windup.RECOVER, str(e._windup))
	var rec := 0
	moved = false
	while e._windup == Enemy.Windup.RECOVER and rec < 200:
		await _step(e)
		rec += 1
		moved = moved or e.position.distance_to(p0) > 0.01
	_check("immobile pendant la récupération (%.2f s)" % (rec * DT), not moved and absf(rec * DT - Balance.SHOOTER_RECOVERY_S) <= 2.5 * DT)
	_check("course rendue après la récupération", not String(e.visual.current_anim()).begins_with("attack_"), String(e.visual.current_anim()))
	await _step(e)
	_check("reprend sa marche", e.position.distance_to(p0) > 0.5, str(e.position - p0))
	_check("pas de nouveau tir avant l'intervalle", _pool.active_count() == 1)
	_pool.clear_all()
	_park(e)


func _test_aim_lock() -> void:
	print("Tireur : visée suivie puis verrouillée")
	var e := _spawn(2, Enemy.VARIANT_SHOOTER, Vector2(6.0, 0.0))
	e._attack_cd = 0.0
	await _step(e)
	# avant le verrouillage, le joueur passe au sud du tireur : la visée suit
	_pp = e.position + Vector2(0.0, 6.0 * U)
	await _step(e)
	var follow := absf(angle_difference(e._facing, PI * 0.5)) < 0.05
	_check("visée suit le joueur avant le verrouillage", follow, str(e._facing))
	while not e._aim_locked and e._windup == Enemy.Windup.SHOT:
		await _step(e)
	_check("éclat au verrouillage (teinte niveau 2)", e.visual._charge_mod == EnemyVisual.CHARGE_MODS[2])
	# après le verrouillage, le joueur repart à l'ouest : le tir garde l'axe verrouillé (sud)
	_pp = e.position + Vector2(-6.0 * U, 0.0)
	while _pool.active_count() == 0 and e.active:
		await _step(e)
	var v: Vector2 = _pool._active[0].velocity if _pool.active_count() > 0 else Vector2.ZERO
	_check("tir sur l'axe verrouillé (pas sur la nouvelle position)", v != Vector2.ZERO and absf(angle_difference(v.angle(), PI * 0.5)) < 0.05, str(v))
	_pp = Vector2.ZERO
	_pool.clear_all()
	_park(e)


func _test_salvo() -> void:
	print("Tireur : salve")
	var e := _spawn(2, Enemy.VARIANT_SHOOTER, Vector2(5.0, 0.0))
	e._spell_cd = 0.0
	var p0 := e.position
	await _step(e)
	_check("armement de salve (SALVO)", e._windup == Enemy.Windup.SALVO, str(e._windup))
	var frames := 1
	while _pool.active_count() == 0 and frames < 200:
		await _step(e)
		frames += 1
	_check("salve après %.2f s (>= 0,8 s)" % (frames * DT), absf(frames * DT - Balance.SHOOTER_SALVO_WINDUP_S) <= 2.5 * DT and frames * DT >= 0.8)
	_check("3 projectiles", _pool.active_count() == 3, str(_pool.active_count()))
	_check("immobile", e.position.distance_to(p0) < 0.01)
	_pool.clear_all()
	_park(e)


func _test_tokens() -> void:
	print("Jetons : tireurs qui arment en même temps")
	Enemy.reset_shot_tokens()
	var cap: int = Balance.SHOOTER_MAX_CHARGING
	var list: Array[Enemy] = []
	for i in cap + 3:
		var e := _spawn(2, Enemy.VARIANT_SHOOTER if i % 2 == 0 else Enemy.VARIANT_LEAPER, Vector2.from_angle(TAU * i / (cap + 3)) * 6.0)
		e._attack_cd = 0.0
		list.append(e)
	var max_seen := 0
	var all_fired := false
	var fired := {}
	for f in 240:
		await get_tree().physics_frame
		for e in list:
			e.tick(DT, _player, _pp, Vector2.ZERO)
			if e._windup == Enemy.Windup.RECOVER:
				fired[e] = true
		var n := 0
		for e in list:
			if e._windup == Enemy.Windup.SHOT or e._windup == Enemy.Windup.SALVO:
				n += 1
		max_seen = maxi(max_seen, n)
		if f == 0:
			_check("%d tireurs prêts, %d arment" % [list.size(), n], n == cap, str(n))
			_check("charging_shooters() = %d" % cap, Enemy.charging_shooters() == cap, str(Enemy.charging_shooters()))
		if fired.size() == list.size():
			all_fired = true
			break
	_check("plafond jamais dépassé (max %d)" % max_seen, max_seen <= cap)
	_check("tous finissent par tirer (jetons rendus)", all_fired, "%d/%d" % [fired.size(), list.size()])
	for e in list:
		_park(e)
	_pool.clear_all()
	_check("jetons libres après le retour au pool", Enemy.charging_shooters() == 0, str(Enemy.charging_shooters()))


func _test_brute() -> void:
	print("Brute : cône")
	var e := _spawn(3, 0, Vector2(1.5, 0.0))
	e._attack_cd = 0.0
	var p0 := e.position
	var h0 := _player.hits
	await _step(e)
	_check("armement du cône", e._windup == Enemy.Windup.CONE, str(e._windup))
	_check("pose d'attaque de la brute", String(e.visual.current_anim()).begins_with("attack_") or e.visual.current_anim() == &"", String(e.visual.current_anim()))
	var frames := 1
	while e._windup == Enemy.Windup.CONE and frames < 200:
		await _step(e)
		frames += 1
	_check("coup à la fin de l'armement (%.2f s)" % (frames * DT), _player.hits == h0 + 1 and absf(frames * DT - Enemy.CONE_WINDUP) <= 2.5 * DT)
	var rec := 0
	while e._windup == Enemy.Windup.RECOVER and rec < 200:
		await _step(e)
		rec += 1
	_check("récupération immobile %.2f s" % (rec * DT), absf(rec * DT - Balance.BRUTE_RECOVERY_S) <= 2.5 * DT and e.position.distance_to(p0) < 0.01)
	_park(e)


func _test_leaper() -> void:
	print("Bondisseur : récupération après la course")
	var e := _spawn(2, Enemy.VARIANT_LEAPER, Vector2(4.0, 0.0))
	e._spell_cd = 0.0
	await _step(e)
	_check("armement de charge", e._windup == Enemy.Windup.LEAP, str(e._windup))
	var guard := 0
	while e._windup != Enemy.Windup.RECOVER and guard < 300:
		await _step(e)
		guard += 1
	var p0 := e.position
	var rec := 0
	while e._windup == Enemy.Windup.RECOVER and rec < 200:
		await _step(e)
		rec += 1
	_check("immobile %.2f s après la course" % (rec * DT), absf(rec * DT - Balance.LEAPER_DASH_RECOVERY_S) <= 2.5 * DT and e.position.distance_to(p0) < 0.01)
	_park(e)
	_pool.clear_all()


func _test_swarm() -> void:
	print("Essaim : morsure")
	var e := _spawn(1, 0, Vector2(0.5, 0.0))
	e._attack_cd = 0.0
	var h0 := _player.hits
	await _step(e)
	_check("morsure", _player.hits == h0 + 1)
	_check("petit recul", e.knockback_left().x > 0.0, str(e.knockback_left()))
	var d_bite := e.position.length()
	var closer := false
	var frames := 0
	while e._attack_cd > Enemy.BITE_PAUSE_GATE and frames < 100:
		await _step(e)
		frames += 1
		closer = closer or e.position.length() < d_bite - 0.5
	_check("sur place %.2f s après la morsure (aucune avance)" % (frames * DT), not closer and absf(frames * DT - Balance.SWARM_BITE_PAUSE_S) <= 2.5 * DT)
	var d1 := e.position.length()
	for i in 10:
		await _step(e)
	_check("repart vers le joueur", e.position.length() < d1, "%.1f -> %.1f" % [d1, e.position.length()])
	_park(e)
