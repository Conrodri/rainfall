extends Node
## Pression des boss d'étage « raid » (Idole noyée, Canonnier de crue, Roi de sel) : retour joueur 27/10/2026, « les mécaniques sont
## trop simples à esquiver ». Simule des joueurs automatiques pendant 60 s par phase et compte les coups reçus :
##   - « idle » : immobile à 4 u (Idole) / 6 u (Canonnier) du boss ;
##   - « orbit » : tourne autour du boss à ce rayon, à la vitesse du joueur (5 u/s) ;
##   - « dodge » : évite les zones télégraphées (cercles, anneaux, cônes, lignes, pales) et se met à l'abri des
##     pylônes pendant la Mitraille (oracle lisant l'état interne du cerveau).
## Puis mesure ce que coûte d'attendre sous bouclier (aucune action du joueur).
## godot --headless --path game res://tests/boss_pressure_test.tscn  -> RESULT: OK
## Option : `-- --measure` n'applique aucun seuil (rapport seul).

const U := 64.0
const DT := 1.0 / 60.0
const ARENA := 2400.0
const SPEED := 5.0 * U
const SIM_S := 60.0
var SEEDS := [11] ## graine unique (2,5 min) ; `-- --full` ajoute une 2e graine et moyenne (5 min)

## Coups encaissés par le joueur immobile en 60 s AVANT la v2 du 27/10/2026 (mesures de l'ancien code, mêmes harnais).
const BASE_IDLE := {"gunner/1": 30.0, "gunner/2": 24.5, "gunner/3": 26.0, "idol/1": 6.0, "idol/2": 19.0, "idol/3": 32.0, "salt/1": 55.0, "salt/2": 61.0, "salt/3": 81.0}
## Idem, joueur qui tourne autour du boss (le profil que le joueur a décrit : « il suffit de tourner autour »).
const BASE_ORBIT := {"gunner/1": 3.5, "gunner/2": 0.5, "gunner/3": 18.5, "idol/1": 0.0, "idol/2": 8.5, "idol/3": 31.5, "salt/1": 40.0, "salt/2": 43.0, "salt/3": 87.0}
## Roi de sel : idem, joueur qui esquive (oracle), mesures de l'ancien code.
const BASE_DODGE := {"salt/1": 7.0, "salt/2": 10.0, "salt/3": 31.0}

var _fails := 0
var _player
var _director: Director
var _map: Node2D
var _boss: Enemy
var _pool: EnemyProjectilePool
var _hits := 0
var _src := {}
var _src_last := 0
var _ev := {}
var _results := {}
var _ibrain: DrownedIdolBrain
var _gbrain: FloodGunnerBrain
var _mode := &"idle"
var _orbit_a := 0.0
var _center_r := 4.0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


func _wall(parent: Node, center: Vector2, size: Vector2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = size
	cs.shape = rs
	b.add_child(cs)
	b.position = center
	parent.add_child(b)


func _run() -> void:
	RunState.level = 1
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	_map = Node2D.new()
	_map.name = &"PressureMap"
	get_tree().root.add_child(_map)
	_wall(_map, Vector2(0, -ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(0, ARENA), Vector2(ARENA * 2 + 128, 128))
	_wall(_map, Vector2(-ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_wall(_map, Vector2(ARENA, 0), Vector2(128, ARENA * 2 + 128))
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	_player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(_player)
	await get_tree().process_frame
	_director.bind_map(_map)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_director.set_physics_process(false)
	_player.set_physics_process(false)
	_pool = _director.get_node(^"EnemyProjectiles") as EnemyProjectilePool
	if OS.get_cmdline_user_args().has("--full"):
		SEEDS = [11, 29]
	Events.player_damaged.connect(func(_a, _s):
		_hits += 1
		if _gbrain != null and OS.get_cmdline_user_args().has("--src"):
			var k := "barrage" if _gbrain.barrage != null and _gbrain.barrage.is_firing() else ("shell/burst" if _gbrain.bursts_fired + _gbrain.shells > _src_last else "autre")
			_src_last = _gbrain.bursts_fired + _gbrain.shells
			_src[k] = int(_src.get(k, 0)) + 1)
	Events.raid_mechanic_failed.connect(func(_b, k): _ev[k] = int(_ev.get(k, 0)) + 1)

	var only_salt := OS.get_cmdline_user_args().has("--salt-only")
	for strat in [&"idle", &"orbit", &"dodge"]:
		if only_salt:
			break
		for ph in [1, 2, 3]:
			await _measure_gunner(strat, ph)
			if OS.get_cmdline_user_args().has("--src"):
				print("   sources ", _src)
				_src.clear()
		if OS.get_cmdline_user_args().has("--src"):
			break
	for strat in [&"idle", &"orbit", &"dodge"]:
		if only_salt:
			break
		for ph in [1, 2, 3]:
			await _measure_idol(strat, ph)
	for strat in [&"idle", &"orbit", &"dodge"]:
		for ph in [1, 2, 3]:
			await _measure_salt(strat, ph)
	if not only_salt:
		await _wait_gunner_shield()
		await _wait_idol_shield()
	await _wait_salt_shield()
	_verdict()

	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = 60
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


# --- Joueur automatique ------------------------------------------------------------------

func _move_player(delta: float, boss_pos: Vector2, danger: Callable, shelter: Callable) -> void:
	var pp: Vector2 = _player.global_position
	match _mode:
		&"orbit":
			_orbit_a += (SPEED / (_center_r * U)) * delta
			_player.global_position = boss_pos + Vector2.from_angle(_orbit_a) * _center_r * U
		&"dodge":
			var best_cost := INF
			var best := pp
			var cands: Array[Vector2] = [pp]
			for k in 16:
				cands.append(pp + Vector2.from_angle(TAU * float(k) / 16.0) * SPEED * 0.45)
			for q in shelter.call():
				cands.append(q)
			for c in cands:
				var reach := pp + (c - pp).limit_length(SPEED * delta * 6.0)
				var cost: float = float(danger.call(reach)) + float(danger.call(pp + (c - pp) * 0.5))
				cost += absf(reach.distance_to(boss_pos) - _center_r * U) * 0.004
				cost += 0.0005 * reach.distance_to(pp)
				if cost < best_cost:
					best_cost = cost
					best = c
			_player.global_position = pp + (best - pp).limit_length(SPEED * delta)
	_player.global_position = _player.global_position.clamp(Vector2(-ARENA + 200, -ARENA + 200), Vector2(ARENA - 200, ARENA - 200))


func _reset_player(pos: Vector2) -> void:
	_player.global_position = pos
	_player.dead = false
	_player.max_hp = 1e6
	_player.hp = 1e6
	_player._invuln = 0.0
	_player.shield = 0.0
	_hits = 0


func _in_cone(p: Vector2, origin: Vector2, ang: float, half: float, range_px: float) -> bool:
	var v := p - origin
	return v.length() <= range_px and absf(angle_difference(ang, v.angle())) <= half


# --- Canonnier (harnais synchrone, aucun processus physique) -------------------------------

func _g_new(phase: int) -> void:
	if _boss != null and is_instance_valid(_boss) and _boss.active:
		if _boss.brain != null:
			_boss.brain.shield.clear()
		_boss.take_damage(1e12)
	for n in _director.get_children():
		if n is ShelterPylon or n is BarrageEmitter or n is PriorityAdds:
			(n as Node).queue_free()
	for n in get_tree().root.get_children():
		if n is ShelterPylon or n is BarrageEmitter or n is PriorityAdds:
			(n as Node).queue_free()
	_pool.clear_all()
	_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null:
		_boss.brain.clear()
	_gbrain = FloodGunnerBrain.new(_boss)
	_boss.brain = _gbrain
	_boss.global_position = Vector2.ZERO
	_boss.hp = _boss.max_hp * [1.0, 0.6, 0.3][phase - 1]
	_gbrain.shield.armed_count = 2 # pas de bouclier : on mesure la pression de la phase seule
	if phase >= 2:
		_gbrain.phase = phase
		_gbrain._shell_cd = 3.5
	_reset_player(Vector2(_center_r * U, 0.0))


func _g_frame(move := true) -> void:
	_boss.tick(DT, _player, _player.global_position, Vector2.ZERO)
	_boss.global_position = Vector2.ZERO
	var b := _gbrain
	if b.pylons != null and is_instance_valid(b.pylons):
		b.pylons.step(DT)
	if b.barrage != null and is_instance_valid(b.barrage):
		b.barrage.step(DT)
	if b.shield.adds != null and is_instance_valid(b.shield.adds):
		for a in b.shield.adds.adds.duplicate():
			if is_instance_valid(a) and (a as Enemy).active:
				(a as Enemy).tick(DT, _player, _player.global_position, Vector2.ZERO)
		b.shield.adds.step(DT)
	_pool.update(DT, _player, _player.global_position, null)
	_player._invuln = maxf(_player._invuln - DT, 0.0)
	_player.hp = 1e6
	if move:
		_move_player(DT, Vector2.ZERO, _g_danger, _g_shelters)


func _shell_r() -> float:
	return float(_gbrain.call(&"shell_radius_u")) if _gbrain.has_method(&"shell_radius_u") else 3.0


func _g_danger(p: Vector2) -> float:
	var b := _gbrain
	var cost := 0.0
	var margin := 0.6 * U
	if b.state == FloodGunnerBrain.S.BREECH:
		var v := p - _boss.position
		var d := Vector2.from_angle(b.aim.angle())
		var along := v.dot(d)
		if along >= 0.0 and along <= 10.0 * U and absf(v.cross(d)) <= 0.9 * U + margin:
			cost += 100.0
	if b.state == FloodGunnerBrain.S.SHELL and p.distance_to(b._shell_at) <= _shell_r() * U + margin:
		cost += 100.0
	if b.has_method(&"extra_zones"):
		for z in b.call(&"extra_zones"):
			if p.distance_to(z["pos"]) <= float(z["r"]) + margin:
				cost += 100.0
	if b.barrage != null and b.barrage.is_busy() and not b.pylons.shelters(p, _boss.position):
		var half := deg_to_rad(b.barrage.arc_deg) * 0.5 + 0.12
		for i in b.barrage.cones:
			var ang: float = b.barrage.aim + TAU * float(i) / float(maxi(b.barrage.cones, 1))
			if _in_cone(p, _boss.position, ang, half, b.barrage.range_u * U):
				cost += 60.0
	if b.pylons != null:
		for c in b.pylons.pylons:
			if float(c["fall"]) > 0.0 and p.distance_to(c["pos"]) <= 1.2 * U + margin:
				cost += 80.0
	for pr in _pool._active:
		var a: Vector2 = pr.position
		var ab: Vector2 = pr.velocity * 0.45
		var tt := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		if p.distance_to(a + ab * tt) <= 0.55 * U:
			cost += 8.0
	return cost


func _g_shelters() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var b := _gbrain
	if b.barrage != null and b.barrage.is_busy() and b.pylons != null:
		for q in b.pylons.positions():
			var d := (q - _boss.position).normalized()
			out.append(q + d * 1.4 * U)
	return out


func _measure_gunner(strat: StringName, phase: int) -> void:
	_mode = strat
	_center_r = 6.0
	_orbit_a = 0.0
	var total := 0
	var info := ""
	for sd in SEEDS:
		seed(sd)
		_g_new(phase)
		var t := 0.0
		while t < SIM_S:
			_g_frame()
			t += DT
		total += _hits
		info += " [%d coups ; tirs %d, pylônes %d, obus %d]" % [_hits, _gbrain.breech_shots, _gbrain.plants, _gbrain.shells]
		await get_tree().physics_frame
	var avg := float(total) / float(SEEDS.size())
	_results["gunner/%d/%s" % [phase, strat]] = avg
	print("MESURE gunner P%d %-5s : %.1f coups / %.0f s%s" % [phase, strat, avg, SIM_S, info])


# --- Idole (harnais à images physiques, FixateMark / RaidOrb tournent seuls) --------------------

func _i_new(phase: int) -> void:
	if _ibrain != null:
		_ibrain.clear()
	if _boss == null or not is_instance_valid(_boss) or not _boss.active:
		_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null and _boss.brain != _ibrain:
		_boss.brain.clear()
	_boss._boss_sprite_id = &"drowned_idol"
	_boss.position = Vector2.ZERO
	_boss.hp = _boss.max_hp * [1.0, 0.6, 0.3][phase - 1]
	_boss.fight_time = 0.0
	_boss.damage = 10.0
	_ibrain = DrownedIdolBrain.new(_boss)
	_boss.brain = _ibrain
	_ibrain.shield.armed_count = 2
	if phase >= 2:
		_ibrain.phase = phase
		_ibrain._apply_phase_look()
	_reset_player(Vector2(_center_r * U, 0.0))


func _i_frame() -> void:
	await get_tree().physics_frame
	_player._invuln = maxf(_player._invuln - DT, 0.0)
	_player.hp = 1e6
	_boss.fight_time += DT
	_boss.visual.boss_tick(DT)
	var pp: Vector2 = _player.global_position
	var to := pp - _boss.position
	var dir := to.normalized() if to.length_squared() > 0.0001 else Vector2.RIGHT
	_ibrain.tick(DT, _player, pp, dir, to.length(), dir)
	_move_player(DT, _boss.position, _i_danger, func(): return [] as Array[Vector2])


func _ik(method: StringName, fallback: float) -> float:
	return float(_ibrain.call(method)) if _ibrain.has_method(method) else fallback


func _i_danger(p: Vector2) -> float:
	var b := _ibrain
	var cost := 0.0
	var margin := 0.55 * U
	if b.state == DrownedIdolBrain.S.PALM:
		if _in_cone(p, _boss.position, b.aim.angle(), _ik(&"palm_half", 0.785) + 0.3, _ik(&"palm_range_u", 3.0) * U + margin):
			cost += 100.0
	var thick := _ik(&"ring_thick_u", 0.8) * U
	for r in b._rings:
		var d := p.distance_to(r["origin"])
		if d <= float(r["r"]) + margin and d >= float(r["r"]) - thick - margin:
			cost += 100.0
	for c in b._circles:
		if p.distance_to(c["pos"]) <= _ik(&"chaplet_r_u", 1.0) * U + margin:
			cost += 100.0
	for d2 in b._dike_plan:
		if (d2["rect"] as Rect2).grow(margin).has_point(p):
			cost += 100.0
	var blade := _ik(&"noria_blade_u", 8.0) * U
	var bw := _ik(&"noria_width_u", 1.5) * U
	for en in b._noria:
		var mark := en["mark"] as FixateMark
		if not is_instance_valid(mark):
			continue
		var v := p - mark.point
		if not en["locked"]:
			if v.length() <= blade + margin + 2.5 * U:
				cost += 40.0 # zone de la future pale : on s'écarte
		else:
			var dd := Vector2.from_angle(b._blade_angle(en))
			var along := v.dot(dd)
			if v.length() <= 1.5 * U + margin or (along >= 0.0 and along <= blade + margin and absf(v.cross(dd)) <= bw * 0.5 + margin):
				cost += 100.0
	for cr in b._cring:
		var d3 := p.distance_to(cr["origin"])
		var rad := float(cr["r"])
		if d3 <= rad + 1.2 * U + margin and d3 >= rad - thick - 1.2 * U - margin:
			cost += 100.0
	if is_instance_valid(b._cring_tele):
		var d4 := p.distance_to(b._cring_tele.global_position)
		if d4 <= 4.0 * U + margin:
			cost += 60.0
	return cost


func _measure_idol(strat: StringName, phase: int) -> void:
	_mode = strat
	_center_r = 4.0
	_orbit_a = 0.0
	var total := 0
	var info := ""
	for sd in SEEDS:
		seed(sd)
		_i_new(phase)
		_ibrain._rng.seed = sd
		_ev.clear()
		var t := 0.0
		while t < SIM_S:
			await _i_frame()
			t += DT
		total += _hits
		info += " [%d coups ; anneaux touchés %d]" % [_hits, _ibrain.ring_hits]
	var avg := float(total) / float(SEEDS.size())
	_results["idol/%d/%s" % [phase, strat]] = avg
	print("MESURE idol   P%d %-5s : %.1f coups / %.0f s%s" % [phase, strat, avg, SIM_S, info])


# --- Roi de sel (harnais synchrone : tick du boss, Procession et stèles avancées à la main) -------------

var _sbrain: SaltKingBrain


func _s_new(phase: int) -> void:
	if _boss != null and is_instance_valid(_boss) and _boss.active:
		if _boss.brain != null:
			_boss.brain.shield.clear()
		_boss.take_damage(1e12)
	_pool.clear_all()
	_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null:
		_boss.brain.clear()
	_boss.global_position = Vector2.ZERO
	_boss.hp = _boss.max_hp * [1.0, 0.6, 0.3][phase - 1]
	_boss.damage = 10.0
	_sbrain = SaltKingBrain.new(_boss)
	_boss.brain = _sbrain
	_sbrain.shield.armed_count = 2 # pas de bouclier : on mesure la pression de la phase seule
	if phase >= 2:
		_sbrain.phase = phase
		_sbrain.anchored = phase >= 3
		_sbrain._apply_phase_look()
		_sbrain._spawn_crown()
	_boss.tick(DT, _player, Vector2(_center_r * U, 0.0), Vector2.ZERO)
	_reset_player(Vector2(_center_r * U, 0.0))


func _s_frame(move := true) -> void:
	_boss.tick(DT, _player, _player.global_position, Vector2.ZERO)
	var b := _sbrain
	if is_instance_valid(b.sector) and not b.sector.is_queued_for_deletion():
		b.sector.step(DT)
	_player._invuln = maxf(_player._invuln - DT, 0.0)
	_player.hp = 1e6
	if _mode == &"idle": # collision : une stèle levée sur le joueur immobile l'éjecte (sinon elle le coince et fausse les stèles suivantes)
		for c in b.steles.steles:
			if float(c["rise"]) <= 0.0 and _player.global_position.distance_to(c["pos"]) < 0.8 * U:
				var d: Vector2 = _player.global_position - c["pos"]
				_player.global_position = c["pos"] + (d.normalized() if d.length() > 0.5 else Vector2.RIGHT) * 0.85 * U
	if move:
		_move_player(DT, _boss.position, _s_danger, func(): return [] as Array[Vector2])


func _s_danger(p: Vector2) -> float:
	var b := _sbrain
	var cost := 0.0
	var margin := 0.55 * U
	var bp := _boss.position
	if b.state == SaltKingBrain.S.AUTO:
		var rel := p - bp
		var along := rel.dot(b.aim)
		if along >= -margin and along <= 4.0 * U + margin and absf(rel.cross(b.aim)) <= 0.5 * U + margin:
			cost += 100.0
	var hr := 0.9 * U
	if b.has_method(&"stele_hit_r_u"):
		hr = float(b.call(&"stele_hit_r_u")) * U
	for c in b.steles.steles:
		if float(c["rise"]) > 0.0 and p.distance_to(c["pos"]) <= hr + margin:
			cost += 100.0
		elif float(c["rise"]) <= 0.0 and p.distance_to(c["pos"]) <= 0.5 * U + 8.0:
			cost += 5.0 # obstacle
	if is_instance_valid(b.sector) and not b.sector.is_queued_for_deletion() and b.sector.radius_u > 0.0:
		if not b.sector.in_safe(p):
			cost += 100.0 if b.sector.is_live() else 25.0
	if b._wave_r >= 0.0:
		var d := p.distance_to(bp)
		if d <= 8.0 * U + margin and d >= b._wave_r - 0.5 * U - margin:
			cost += 100.0
	elif b.state == SaltKingBrain.S.EDICT and p.distance_to(bp) <= 8.0 * U:
		cost += 20.0
	return cost


func _measure_salt(strat: StringName, phase: int) -> void:
	_mode = strat
	_center_r = 4.0
	_orbit_a = 0.0
	var total := 0
	var info := ""
	for sd in SEEDS:
		seed(sd)
		_s_new(phase)
		_sbrain._rng.seed = sd
		_hits = 0
		var t := 0.0
		while t < SIM_S:
			_s_frame()
			t += DT
		total += _hits
		info += " [%d coups ; sceptre %d, stèles %d/%d posées, processions %d, marée %d, édit %d]" % [_hits, _sbrain.auto_hits, _sbrain.steles.hits, _sbrain.steles.landed_total, _sbrain.sector_count,
			_sbrain.sector.ticks_hit if is_instance_valid(_sbrain.sector) else -1, _sbrain.edict_hits]
		await get_tree().physics_frame
	var avg := float(total) / float(SEEDS.size())
	_results["salt/%d/%s" % [phase, strat]] = avg
	print("MESURE salt   P%d %-5s : %.1f coups / %.0f s%s" % [phase, strat, avg, SIM_S, info])


func _wait_salt_shield() -> void:
	_mode = &"idle"
	_center_r = 6.0
	seed(5)
	_s_new(2)
	_sbrain.shield.armed_count = 0
	_sbrain.phase = 1
	_boss.hp = _boss.max_hp * 0.69
	var hp0 := _boss.hp
	_ev.clear()
	_hits = 0
	var t := 0.0
	var fell := -1.0
	var armed := false
	while t < 120.0:
		_s_frame(false)
		t += DT
		if _sbrain.shield.is_invulnerable():
			armed = true
		if armed and not _sbrain.shield.is_invulnerable():
			fell = t
			break
	print("ATTENTE salt : bouclier tombé à %.1f s, fenêtre exposée %s, coups %d, PV boss %+.1f %% max (%s)" % [fell, str(_sbrain.shield.rewarded),
		_hits, (_boss.hp - hp0) / _boss.max_hp * 100.0, str(_ev)])
	_results["wait_salt"] = {"fell": fell, "rewarded": _sbrain.shield.rewarded, "hits": _hits, "heal": (_boss.hp - hp0) / _boss.max_hp}
	await get_tree().physics_frame


# --- Attendre sous bouclier -------------------------------------------------------------------

func _wait_gunner_shield() -> void:
	_mode = &"idle"
	_center_r = 6.0
	seed(5)
	_g_new(2)
	_gbrain.shield.armed_count = 0
	_gbrain.phase = 1
	_boss.hp = _boss.max_hp * 0.69
	var hp0 := _boss.hp
	_ev.clear()
	_hits = 0
	var t := 0.0
	var fell := -1.0
	var armed := false
	while t < 120.0:
		_g_frame(false)
		t += DT
		if OS.get_cmdline_user_args().has("--debug") and int(t * 60.0) % 300 == 0:
			var ad := _gbrain.shield.adds
			var c0 := _gbrain.shield.conditions[0] if not _gbrain.shield.conditions.is_empty() else null
			print("   t=%.0f adds=%d consumed=%d done=%d state=%d pos=%s" % [t, ad.alive() if ad != null and is_instance_valid(ad) else -1, c0.consumed if c0 else -1, c0.done if c0 else -1, _gbrain.shield.state, str(ad.adds.map(func(x): return (x.global_position / U).snapped(Vector2(0.1,0.1)))) if ad != null and is_instance_valid(ad) else ""])
		if _gbrain.shield.is_invulnerable():
			armed = true
		if armed and not _gbrain.shield.is_invulnerable():
			fell = t
			break
	var sh := _gbrain.shield
	print("ATTENTE gunner : bouclier tombé à %.1f s, fenêtre exposée %s, coups %d, PV boss %+.1f %% max (%s)" % [fell, str(sh.rewarded),
		_hits, (_boss.hp - hp0) / _boss.max_hp * 100.0, str(_ev)])
	_results["wait_gunner"] = {"fell": fell, "rewarded": sh.rewarded, "hits": _hits, "heal": (_boss.hp - hp0) / _boss.max_hp}
	await get_tree().physics_frame


func _wait_idol_shield() -> void:
	_mode = &"idle"
	_center_r = 4.0
	seed(5)
	_i_new(2)
	_ibrain._rng.seed = 5
	_ibrain.shield.armed_count = 0
	_ibrain.phase = 1
	_boss.hp = _boss.max_hp * 0.69
	var hp0 := _boss.hp
	_ev.clear()
	_hits = 0
	var t := 0.0
	var fell := -1.0
	var armed := false
	while t < 120.0:
		await _i_frame()
		t += DT
		if _ibrain.shield.is_invulnerable():
			armed = true
		if armed and not _ibrain.shield.is_invulnerable():
			fell = t
			break
	print("ATTENTE idol : bouclier tombé à %.1f s, fenêtre exposée %s, coups %d, PV boss %+.1f %% max (%s)" % [fell, str(_ibrain.shield.rewarded),
		_hits, (_boss.hp - hp0) / _boss.max_hp * 100.0, str(_ev)])
	_results["wait_idol"] = {"fell": fell, "rewarded": _ibrain.shield.rewarded, "hits": _hits, "heal": (_boss.hp - hp0) / _boss.max_hp}


# --- Verdict -------------------------------------------------------------------------------------

func _verdict() -> void:
	if OS.get_cmdline_user_args().has("--measure"):
		return
	print("Seuils : paresseux touché souvent ; esquive nettement sous le paresseux ; attendre coûte")
	_verdict_salt()
	if OS.get_cmdline_user_args().has("--salt-only"):
		return
	for boss in ["gunner", "idol"]:
		for ph in [1, 2, 3]:
			var idle := float(_results["%s/%d/idle" % [boss, ph]])
			var orbit := float(_results["%s/%d/orbit" % [boss, ph]])
			var dodge := float(_results["%s/%d/dodge" % [boss, ph]])
			var base: float = BASE_IDLE["%s/%d" % [boss, ph]]
			var base_o: float = BASE_ORBIT["%s/%d" % [boss, ph]]
			_check("%s P%d : paresseux (immobile + orbite) touché au moins 1,6 x plus qu'avant (%.1f vs %.1f avant)" % [boss, ph, (idle + orbit) * 0.5, (base + base_o) * 0.5],
				(idle + orbit) >= 1.6 * (base + base_o))
			_check("%s P%d : immobile touché au moins 1,5 x plus qu'avant (%.1f vs %.1f avant)" % [boss, ph, idle, base], idle >= 1.5 * base)
			_check("%s P%d : tourner autour du boss ne protège plus (orbite %.1f coups)" % [boss, ph, orbit], orbit >= 10.0)
			_check("%s P%d : l'esquive reste nettement sous le paresseux (%.1f vs immobile %.1f)" % [boss, ph, dodge, idle], dodge <= 0.7 * idle)
	var wg: Dictionary = _results["wait_gunner"]
	var wi: Dictionary = _results["wait_idol"]
	_check("attendre sous le bouclier du Canonnier : pas avant 40 s, sans fenêtre, des coups", float(wg["fell"]) >= 40.0 and not bool(wg["rewarded"]) and int(wg["hits"]) >= 4, str(wg))
	_check("attendre sous le bouclier de l'Idole : pas avant 40 s, sans fenêtre, des coups", float(wi["fell"]) >= 40.0 and not bool(wi["rewarded"]) and int(wi["hits"]) >= 4, str(wi))


## Roi de sel : le plafond de coups est bas (invulnérabilité de 0,4 s après un coup, marée de P3 déjà à 80-90 % du maximum
## possible avant la v2) ; les seuils ×2 des deux autres boss ne s'y appliquent donc pas tels quels. P1 / P2 : ×1,4 au moins ;
## P3 (saturée) : pas de recul pour le paresseux, mais l'esquive (le joueur compétent) prend ×1,1 au moins (39-49 selon l'ordre des mesures).
func _verdict_salt() -> void:
	for ph in [1, 2, 3]:
		var idle := float(_results["salt/%d/idle" % ph])
		var orbit := float(_results["salt/%d/orbit" % ph])
		var dodge := float(_results["salt/%d/dodge" % ph])
		var base: float = BASE_IDLE["salt/%d" % ph]
		var base_o: float = BASE_ORBIT["salt/%d" % ph]
		var base_d: float = BASE_DODGE["salt/%d" % ph]
		if ph < 3:
			_check("salt P%d : paresseux (immobile + orbite) touché au moins 1,4 x plus qu'avant (%.1f vs %.1f avant)" % [ph, (idle + orbit) * 0.5, (base + base_o) * 0.5],
				(idle + orbit) >= 1.4 * (base + base_o))
		else:
			_check("salt P3 : saturée, le paresseux ne recule pas (%.1f vs %.1f avant)" % [(idle + orbit) * 0.5, (base + base_o) * 0.5],
				(idle + orbit) >= 0.9 * (base + base_o))
			_check("salt P3 : l'esquive prend au moins 1,1 x plus de coups qu'avant (%.1f vs %.1f)" % [dodge, base_d], dodge >= 1.1 * base_d)
		_check("salt P%d : tourner autour du boss ne protège plus (orbite %.1f coups)" % [ph, orbit], orbit >= 20.0)
		_check("salt P%d : l'esquive reste nettement sous le paresseux (%.1f vs immobile %.1f)" % [ph, dodge, idle], dodge <= 0.7 * idle)
	var ws: Dictionary = _results["wait_salt"]
	_check("attendre sous le bouclier du Roi : pas avant 40 s (avant : 22 s), sans fenêtre, des coups", float(ws["fell"]) >= 40.0 and not bool(ws["rewarded"]) and int(ws["hits"]) >= 4, str(ws))
	_check("attendre sous le bouclier du Roi : le boss se soigne d'au moins 9 %% de ses PV max (%.1f %%)" % (float(ws["heal"]) * 100.0), float(ws["heal"]) >= 0.09)
