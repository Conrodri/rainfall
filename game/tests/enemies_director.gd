extends SceneTree
## Director : apparitions hors écran, plafond 250, report des crédits, zones, tiers débloqués, vagues.
## godot --headless --fixed-fps 60 --path game --script res://tests/enemies_director.gd

var _fails := 0
var _director: Node2D
var _player: Node2D
var _run_state: Node


func _initialize() -> void:
	_run_state = root.get_node("RunState")
	_player = load("res://tests/enemies_fake_player.gd").new()
	root.add_child(_player)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawn_ramp = false # débit brut du doc ; la mise en route est testée à la fin
	_director.waves_enabled = false # flux continu seul ; les vagues sont testées à la fin
	root.add_child(_director)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	# 1. Points d'apparition hors du rectangle visible
	var half: Vector2 = _director._spawn_half_extent()
	var inside := 0
	for k in 2000:
		var p: Vector2 = _director._spawn_point(Vector2(300, -200)) - Vector2(300, -200)
		if absf(p.x) < half.x and absf(p.y) < half.y:
			inside += 1
	_check("apparitions hors écran (%d dans l'écran sur 2000)" % inside, inside == 0)

	# 2. Tiers : D = 1 -> uniquement T1 ; D = 5 -> mix, coût moyen ≈ 1 + DIRECTOR_MEAN_COST_SLOPE × 4 (Alignement RoR2 : 2,6 ; remplace > 3,3)
	var only_t1 := true
	for k in 500:
		if _director._pick_tier(1.0) != 1:
			only_t1 = false
	_check("D=1 : uniquement tier 1", only_t1)
	var cost := 0.0
	var seen := {}
	for k in 4000:
		var t: int = _director._pick_tier(5.0)
		seen[t] = true
		cost += root.get_node("Balance").TIER_COST[t]
	cost /= 4000.0
	var want_cost: float = 1.0 + root.get_node("Balance").DIRECTOR_MEAN_COST_SLOPE * 4.0
	_check("D=5 : 3 tiers, coût moyen %.2f ≈ %.2f" % [cost, want_cost], seen.size() == 3 and absf(cost - want_cost) < 0.15 * want_cost)

	# 3. Spawn autonome à D ≈ 1 : premiers monstres en quelques secondes. Alignement RoR2 : 0,894 × 1,4 ≈ 1,25 crédit/s
	# (remplace 6,5/s) -> 1 à 6 monstres en 2 s (remplace 8 à 16).
	for k in 120:
		await physics_frame
	var n2s: int = _director.active_count()
	_check("apparitions à D=1 (%d en 2 s)" % n2s, n2s >= 1 and n2s <= 6)

	# 4. Plafond 250 et report des crédits (gros budget à D = 1, aucun kill)
	_director.credits = 1000.0
	_director._next_tier = 0
	for k in 60: # 6 apparitions max par frame
		await physics_frame
	_check("plafond 250 (%d)" % _director.active_count(), _director.active_count() == 250)
	var c0: float = _director.credits
	for k in 60:
		await physics_frame
	_check("crédits reportés au plafond (%.0f -> %.0f)" % [c0, _director.credits], _director.credits > c0)
	var e: Node2D = _director._active[0]
	e.take_damage(1e9)
	await physics_frame
	_check("place libérée re-remplie", _director.active_count() == 250)

	# 5. Zone : crédits ×1,5 quand le joueur est dedans
	_director.despawn_all()
	_check("despawn_all", _director.active_count() == 0 and _director.free_count() == 250)
	_run_state.active_time_s = 0.0
	_director.spawning_enabled = false
	_director.credits = 0.0
	_director.set_zone(1, _player.global_position, 300.0, true)
	_director._next_tier = 1
	_director._next_elite = false
	_director.spawning_enabled = true
	await physics_frame
	var expected: float = root.get_node("Balance").director_credits_per_s(1.0, &"mini") / 60.0
	_check("crédits zone ×1,5 (%.4f / %.4f)" % [_director.credits, expected], absf(_director.credits - expected) < 0.002)

	# 6. Mise en route : plafond de vivants réduit et crédits ×0,25 à 0 s
	var bal: Node = root.get_node("Balance")
	_director.set_zone(1, _player.global_position, 300.0, false)
	_director.despawn_all()
	_director.spawn_ramp = true
	_director.credits = 1000.0
	_run_state.active_time_s = 0.0
	for i in 30:
		await physics_frame
	_check("plafond de début (%d / %d)" % [_director.active_count(), bal.director_alive_cap(0.0)], _director.active_count() == bal.director_alive_cap(0.0))
	_check("rampe de crédits", is_equal_approx(bal.director_ramp(0.0), bal.RAMP_CREDITS_MIN) and is_equal_approx(bal.director_ramp(bal.RAMP_TIME_S), 1.0))

	# 7. Vagues : au moins une en 40 s, monstres d'un même côté hors écran, plafond de vivants respecté
	_director.despawn_all()
	_director.waves_enabled = true
	_director.spawn_ramp = true
	_run_state.active_time_s = 200.0
	var w0: int = _director.wave_count
	var over := 0
	var side := Vector2.ZERO
	var wave_pos := PackedVector2Array()
	var wave_ppos := Vector2.ZERO
	for k in 40 * 60:
		await physics_frame
		if _director.active_count() > bal.director_alive_cap(_run_state.active_time_s):
			over += 1
		if side == Vector2.ZERO and _director.wave_count > w0 and _director._wave_queue.is_empty():
			side = _director.last_wave_side
			wave_pos = _director.last_wave_positions.duplicate()
			wave_ppos = _player.global_position
		if k % 300 == 299: # le joueur nettoie l'écran toutes les 5 s
			for en in _director._active.duplicate():
				_director.release_enemy(en)
	_check("au moins une vague en 40 s (%d)" % (_director.wave_count - w0), _director.wave_count > w0)
	_check("plafond de vivants respecté (%d frames au-dessus)" % over, over == 0)
	var depth: float = absf(side.x) * half.x + absf(side.y) * half.y
	var same_side: bool = wave_pos.size() >= bal.WAVE_MIN_COUNT
	for p in wave_pos:
		if (p - wave_ppos).dot(side) < depth:
			same_side = false
	_check("vague du même côté hors écran (%d monstres, côté %s)" % [wave_pos.size(), side], same_side)

	# 8. Redistribution, pas d'augmentation : même ordre de monstres sur 120 s avec ou sans vagues
	var n_stream: int = await _simulate(false, 120.0)
	var n_waves: int = await _simulate(true, 120.0)
	var ratio := float(n_waves) / maxf(n_stream, 1.0)
	_check("total comparable avec vagues (%d vs %d sans, x%.2f)" % [n_waves, n_stream, ratio], ratio > 0.7 and ratio < 1.3)

	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


## Monstres apparus en `seconds` (le joueur nettoie l'écran toutes les 5 s), même graine.
func _simulate(waves: bool, seconds: float) -> int:
	_director._rng.seed = 4242
	_director.despawn_all()
	_director.waves_enabled = waves
	_director.spawn_ramp = true
	_run_state.active_time_s = 200.0
	var n0: int = _director.spawned_total
	for k in int(seconds * 60.0):
		await physics_frame
		if k % 300 == 299:
			for en in _director._active.duplicate():
				_director.release_enemy(en)
	return _director.spawned_total - n0


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])
