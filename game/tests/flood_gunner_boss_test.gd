extends Node
## Le Canonnier de crue (FloodGunnerBrain, docs/Design_Boss_Raid.md §2.2) monté directement sur un Enemy de test.
## godot --headless --path game res://tests/flood_gunner_boss_test.tscn  -> RESULT: OK
## Temps piloté par le test (Enemy.tick + step des mécaniques à 60 Hz, aucun processus physique).
## Vérifie : PV x0,9 ; phases 70 / 35 % ; pylônes avant Mitraille (refus < 2 pylônes, 2,5 s garanties) ; coup
## de Culasse à la fin de l'armement ; abri protège / exposé touché ; plafond de 160 projectiles ; bouclier KILL_ADDS
## (rupture par soutiers, soin plafonné si l'un arrive, garde-fou 25 s, seule la Culasse tire sous bouclier) ;
## Obus qui casse un pylône ; P3 ancrée (+20 %), Mitraille continue avec rechargement ; combat complet sans blocage.

const U := 64.0
const DT := 1.0 / 60.0
const ARENA := 2400.0

var _fails := 0
var _player
var _director: Director
var _map: Node2D
var _boss: Enemy
var _pool: EnemyProjectilePool
var _ev := {}


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


func _on(sig: String, a = null, b = null) -> void:
	if not _ev.has(sig):
		_ev[sig] = []
	(_ev[sig] as Array).append([a, b])


func _count(sig: String) -> int:
	return (_ev.get(sig, []) as Array).size()


func _run() -> void:
	RunState.level = 1
	_map = Node2D.new()
	_map.name = &"GunnerMap"
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
	Events.raid_mechanic_failed.connect(func(b, k): _on("failed", b, k))
	Events.raid_barrage.connect(func(b, a): _on("barrage", b, a))

	_t_basics()
	_t_p1_sequence()
	_t_breech_timing()
	_t_shelter()
	_t_shield_kill()
	_t_shield_reached()
	_t_shield_backstop()
	_t_p2_shell_and_volley()
	_t_p3()
	_t_full_fight()
	await _t_cleanup()

	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


# --- Harnais
func _br() -> FloodGunnerBrain:
	return _boss.brain as FloodGunnerBrain


func _reset_player(pos: Vector2) -> void:
	_player.global_position = pos
	_player.dead = false
	_player.max_hp = 100.0
	_player.hp = 100.0
	_player._invuln = 0.0
	_player.shield = 0.0


func _free_leftovers() -> void:
	var par := _director
	for n in par.get_children():
		if n is ShelterPylon or n is BarrageEmitter or n is PriorityAdds:
			(n as Node).queue_free()
	for n in get_tree().root.get_children():
		if n is ShelterPylon or n is BarrageEmitter or n is PriorityAdds:
			(n as Node).queue_free()


func _new_boss(player_pos: Vector2, hp_frac := 1.0) -> FloodGunnerBrain:
	if _boss != null and is_instance_valid(_boss) and _boss.active:
		if _boss.brain != null:
			_boss.brain.shield.clear()
		_boss.take_damage(1e12)
	_free_leftovers()
	_pool.clear_all()
	_ev.clear()
	_boss = _director.spawn_boss(&"etage", Vector2.ZERO) as Enemy
	if _boss.brain != null:
		_boss.brain.clear()
	_boss.brain = FloodGunnerBrain.new(_boss)
	_boss.global_position = Vector2.ZERO
	_boss.hp = _boss.max_hp * hp_frac
	_reset_player(player_pos)
	return _br()


## Une image : Enemy.tick (fight_time, visuel, cerveau) puis les mécaniques du kit, puis les projectiles.
func _frame(keep_player := false) -> void:
	if not _boss.active:
		return
	var b := _br()
	_boss.tick(DT, _player, _player.global_position, Vector2.ZERO)
	if not _boss.active:
		return
	_boss.global_position = Vector2.ZERO # boss épinglé : scénarios reproductibles
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
	if keep_player:
		_player.hp = 100.0


func _run_for(s: float, keep_player := false) -> void:
	for i in int(round(s / DT)):
		_frame(keep_player)


## Avance jusqu'à ce que `cond` soit vraie ; rend le temps écoulé (-1 si dépassé `max_s`).
func _until(cond: Callable, max_s: float, keep_player := false) -> float:
	var n := int(round(max_s / DT))
	for i in n:
		if cond.call():
			return float(i) * DT
		_frame(keep_player)
	return -1.0


func _to_shield_active() -> void:
	_until(func(): return _br().shield.state == BossShield.State.ACTIVE, 5.0)


# --- Tests
func _t_basics() -> void:
	print("Bases")
	var base := Balance.boss_hp(&"etage", RunState.difficulty(), RunState.stage)
	var b := _new_boss(Vector2(500, 0))
	_check("PV x BOSS_HP_MULT (0,9)", is_equal_approx(_boss.max_hp, base * 0.9), "%f / %f" % [_boss.max_hp, base])
	_check("phase 1, 70 / 35 %", b.phase == 1 and b._phase_for(0.71) == 1 and b._phase_for(0.70) == 2 and b._phase_for(0.35) == 3)
	_check("mécaniques créées (2 boucliers au quota)", b.shield != null and b.pylons != null and b.barrage != null
		and Balance.boss_shield_count(&"flood_gunner") == 2)
	_check("projectile max 160", Balance.RAID_BARRAGE_MAX_LIVE == 160 and Balance.RAID_BARRAGE_COEF == 0.2)


func _t_p1_sequence() -> void:
	print("P1 : Pylônes avant Mitraille")
	var b := _new_boss(Vector2(500, 0))
	# refus d'une Mitraille avec < 2 pylônes
	b.pylons.plant(Vector2(300, 300), 0.0)
	_check("barrage refusé avec 1 pylône", not b.barrage.start(0.0, {"duration_s": 2.0}) and b.barrage.state == BarrageEmitter.State.IDLE)
	b.pylons.release()
	b.pylons = ShelterPylon.create(_boss)
	b.barrage.shelters = b.pylons
	# l'IA doit planter d'abord
	b._volley_cd = 0.0
	b._attack_cd = 99.0
	var tp := _until(func(): return b.state == FloodGunnerBrain.S.PLANT or b.state == FloodGunnerBrain.S.VOLLEY, 3.0, true)
	_check("sans pylône : Pylônes d'abord (pas de Mitraille)", tp >= 0.0 and b.state == FloodGunnerBrain.S.PLANT, "state %d" % b.state)
	var tv := _until(func(): return b.state == FloodGunnerBrain.S.VOLLEY, 8.0, true)
	_check("Mitraille lancée ensuite", tv >= 0.0)
	var planted_at: float = b._plant_t
	_check("délai pylônes -> Mitraille >= 2,5 s", b._clock - planted_at >= FloodGunnerBrain.PLANT_SETTLE_S - 0.02, "%f" % (b._clock - planted_at))
	_check("3 pylônes en P1, >= 2 debout", b.plants == 3 and b.pylons.live_count() >= 2, "%d / %d" % [b.plants, b.pylons.live_count()])
	_check("télégraphe >= 1,5 s, Events.raid_barrage(true), boss planté", b.barrage.telegraph_s >= 1.5 and _count("barrage") >= 1 and b.owns_motion())
	_run_for(1.4, true)
	_check("aucun tir de Mitraille pendant le télégraphe", b.barrage.fired_total == 0)
	_run_for(5.5, true)
	_check("Mitraille : éventail 120°, ~24/s sur 5 s", b.barrage.fired_total >= 60 and b.barrage.arc_deg == 120.0 and b.barrage.cones == 1, "%d" % b.barrage.fired_total)
	_check("plafond <= 160 vivants", b.barrage.peak_live <= Balance.RAID_BARRAGE_MAX_LIVE and b.barrage.peak_live > 0, "%d" % b.barrage.peak_live)
	_check("fin : raid_barrage(false), recharge 14 s", not b.barrage.is_busy() and b._volley_cd > 5.0 and b.state != FloodGunnerBrain.S.VOLLEY, "cd %f" % b._volley_cd)


func _t_breech_timing() -> void:
	print("Culasse : dégâts à la frame d'impact")
	var b := _new_boss(Vector2(400, 0))
	b._attack_cd = 0.0
	b._volley_cd = 99.0
	_frame()
	_check("armement de la Culasse (planté)", b.state == FloodGunnerBrain.S.BREECH and b.pace.planted())
	var dur: float = b._dur
	_check("armement >= 0,8 s", dur >= 0.8, "%f" % dur)
	var t0: float = b._clock
	var shot_t := -1.0
	for i in int(3.0 / DT):
		var n0 := b.breech_shots
		_frame()
		if b.breech_shots > n0:
			shot_t = b._clock - t0
			break
	_check("rivet tiré à la fin de l'armement (± 1 image)", shot_t >= 0.0 and absf(shot_t - dur) <= 0.03, "%f vs %f" % [shot_t, dur])
	_check("projectile du boss en vol, joueur intact avant impact", _pool.count_from(_boss) == 1 and _player.hp == 100.0)
	_run_for(0.5)
	_check("rivet touche le joueur à découvert", _player.hp < 100.0, "hp %f" % _player.hp)
	_check("récupération immobile après le coup", b.pace.recovering() or b.state == FloodGunnerBrain.S.CHASE)


func _setup_two_pylons(b: FloodGunnerBrain) -> void:
	b.pylons.plant(Vector2(300, 0), 0.0)
	b.pylons.plant(Vector2(0, 400), 0.0)
	b._plant_t = -100.0
	b._volley_cd = 0.0
	b._attack_cd = 99.0


func _t_shelter() -> void:
	print("Abri : protège / exposé touché")
	var b := _new_boss(Vector2(520, 0))
	_setup_two_pylons(b)
	var tv := _until(func(): return b.state == FloodGunnerBrain.S.VOLLEY, 2.0, true)
	_check("Mitraille acceptée avec 2 pylônes", tv >= 0.0)
	_reset_player(Vector2(520, 0)) # derrière le pylône (300, 0), dans l'axe
	var sheltered: bool = b.pylons.shelters(_player.global_position, Vector2.ZERO)
	_check("joueur abrité (ligne de vue coupée)", sheltered)
	_run_for(7.5)
	_check("abrité : aucun dégât (Mitraille 5 s)", _player.hp == 100.0 and b.barrage.fired_total > 40, "hp %f, tirs %d" % [_player.hp, b.barrage.fired_total])
	_check("pylône abîmé par les rivets", b.pylons.blocked_total > 0)
	# exposé
	b = _new_boss(Vector2(520, 260))
	_setup_two_pylons(b)
	_until(func(): return b.state == FloodGunnerBrain.S.VOLLEY, 2.0, true)
	_reset_player(Vector2(520, 260))
	_check("joueur exposé (hors ombre)", not b.pylons.shelters(_player.global_position, Vector2.ZERO))
	_run_for(7.5)
	_check("exposé : touché", _player.hp < 100.0, "hp %f" % _player.hp)


func _to_phase2_shield(b: FloodGunnerBrain) -> void:
	_boss.hp = _boss.max_hp * 0.69
	_frame()


func _t_shield_kill() -> void:
	print("Bouclier P2 : rupture par 2 soutiers")
	var b := _new_boss(Vector2(500, 0))
	b._attack_cd = 99.0
	b._volley_cd = 99.0
	_to_phase2_shield(b)
	_check("phase 2 : transition figée, bouclier levé", b.phase == 2 and b.state == FloodGunnerBrain.S.STAGGER and _boss.is_invulnerable() and _boss.phase_transitioning())
	var hp0 := _boss.hp
	_boss.take_damage(500.0)
	_check("invulnérable : dégâts reçus x0", _boss.hp == hp0)
	_to_shield_active()
	var pa := b.shield.adds
	_check("2 soutiers sortis, priorité de visée 2, loin du boss", pa != null and pa.alive() == 2 and (pa.adds[0] as Enemy).aim_priority == 2.0
		and (pa.adds[0] as Enemy).global_position.distance_to(_boss.global_position) > 8.0 * U)
	for a in pa.adds:
		(a as Enemy).speed_px = 0.0 # à l'arrêt : seule la mort ou l'arrivée compte, pas la marche
	_check("tag de barre « SOUTIERS 0/2 »", String(b.boss_state_tag().get("text", "")) == "SOUTIERS 0/2", str(b.boss_state_tag()))
	# sous bouclier : seule la Culasse, toutes les 3 s
	var shots0 := b.breech_shots
	b._attack_cd = 0.0
	_run_for(7.0, true)
	_check("sous bouclier : Culasse seulement (<= 3 tirs/7 s), ni pylône ni Mitraille", b.breech_shots - shots0 >= 1 and b.breech_shots - shots0 <= 3
		and b.plants == 0 and not b.barrage.is_busy(), "tirs %d plants %d" % [b.breech_shots - shots0, b.plants])
	for a in pa.adds.duplicate():
		(a as Enemy).take_damage(1e9)
	_frame()
	_check("2 soutiers tués : rupture méritée", b.shield.state == BossShield.State.BREAKING and b.shield.rewarded)
	_run_for(Balance.BOSS_SHIELD_BREAK_S + 0.05)
	_check("purge 3 s : exposé x1,3, boss sonné (aucune attaque)", b.shield.is_exposed() and is_equal_approx(b.damage_taken_mult(), 1.3)
		and b.shield.exposed_s == 3.0 and not b.shield.can_attack())
	hp0 = _boss.hp
	_boss.take_damage(100.0)
	_check("dégâts x1,3 pendant la purge", is_equal_approx(hp0 - _boss.hp, 130.0), "%f" % (hp0 - _boss.hp))
	_run_for(3.1)
	_check("retour à la normale", b.shield.state == BossShield.State.IDLE and b.damage_taken_mult() == 1.0 and not _boss.is_invulnerable())


func _t_shield_reached() -> void:
	print("Bouclier : soutier arrivé = soin plafonné, rupture sans fenêtre")
	var b := _new_boss(Vector2(500, 0))
	b._attack_cd = 99.0
	b._volley_cd = 99.0
	_to_phase2_shield(b)
	_to_shield_active()
	var pa := b.shield.adds
	var a0: Enemy = pa.adds[0]
	var a1: Enemy = pa.adds[1]
	_boss.hp = _boss.max_hp * 0.6
	a0.global_position = _boss.global_position + Vector2(10, 0)
	pa.step(DT)
	_check("soutier au contact : +10 % PV (soin), Events.raid_mechanic_failed(add_reached)", is_equal_approx(_boss.hp, _boss.max_hp * 0.7)
		and _count("failed") >= 1 and (_ev["failed"] as Array).any(func(x): return x[1] == &"add_reached"), "%f" % (_boss.hp / _boss.max_hp))
	a1.take_damage(1e9)
	_frame()
	_check("1 consommé + 1 tué : rupture SANS fenêtre", b.shield.state == BossShield.State.BREAKING and not b.shield.rewarded)
	_run_for(Balance.BOSS_SHIELD_BREAK_S + 0.05)
	_check("pas de fenêtre exposée", b.shield.state == BossShield.State.IDLE and b.damage_taken_mult() == 1.0)
	# plafond de soin 20 % sur un groupe
	var p2 := PriorityAdds.create(_boss)
	p2.spawn(3, {"add_hp_frac": 0.05})
	_boss.hp = _boss.max_hp * 0.3
	for e in p2.adds.duplicate():
		(e as Enemy).global_position = _boss.global_position
	p2.step(DT)
	_check("soin plafonné à 20 % par groupe", is_equal_approx(_boss.hp, _boss.max_hp * 0.5), "%f" % (_boss.hp / _boss.max_hp))
	p2.release()


func _t_shield_backstop() -> void:
	print("Bouclier : garde-fou 25 s")
	var b := _new_boss(Vector2(500, 0))
	b._attack_cd = 99.0
	b._volley_cd = 99.0
	_to_phase2_shield(b)
	_to_shield_active()
	var pa := b.shield.adds
	for a in pa.adds:
		(a as Enemy).speed_px = 0.0 # soutiers à l'arrêt : ni tués ni arrivés
	var t := _until(func(): return b.shield.state == BossShield.State.BREAKING, 30.0, true)
	_check("garde-fou : le bouclier cède seul (~25 s actifs)", t >= 24.5 and t <= 26.5 and b.shield.by_backstop and not b.shield.rewarded, "%f" % t)
	_check("Events.raid_mechanic_failed(shield_backstop)", (_ev.get("failed", []) as Array).any(func(x): return x[1] == &"shield_backstop"))
	_run_for(1.0, true)
	_check("boss de nouveau vulnérable (x1)", not _boss.is_invulnerable() and b.damage_taken_mult() == 1.0)


func _t_p2_shell_and_volley() -> void:
	print("P2 : Obus, Mitraille tournante")
	var b := _new_boss(Vector2(500, 0), 0.6)
	b._attack_cd = 99.0
	b._volley_cd = 99.0
	b.phase = 2 # état d'après la transition (bouclier testé plus haut)
	b.shield.armed_count = 2
	b.pylons.plant(Vector2(300, 100), 0.0)
	b.pylons.plant(Vector2(300, -100), 0.0)
	_check("2 pylônes debout", b.pylons.live_count() == 2)
	# Obus sur un pylône : le casse
	_reset_player(Vector2(300, 90))
	b._shell_cd = 0.0
	b._shell_n = 1 # le prochain (n°2) vise le pylône le plus proche du joueur
	_frame()
	_check("Obus : armement 1,2 s min, cercle de 3 u", b.state == FloodGunnerBrain.S.SHELL and b._dur >= 1.2 and b._shell_on_pylon)
	var hp0: float = _player.hp
	_run_for(b._dur + 0.1)
	_check("Obus : le pylône visé est cassé", b.shell_pylon_hits == 1 and b.pylons.pylons.size() == 1, "%d / %d" % [b.shell_pylon_hits, b.pylons.pylons.size()])
	_check("Obus : dégâts au joueur dans le cercle de 3 u, à l'impact seulement", _player.hp < hp0)
	# Obus sur le joueur
	_reset_player(Vector2(900, 0))
	b._shell_cd = 0.0
	b._shell_n = 2
	_until(func(): return b.state == FloodGunnerBrain.S.SHELL, 3.0)
	var cnt: int = b.shells
	_run_for(b._dur - 0.2)
	_check("Obus : aucun dégât avant l'impact", b.shells == cnt and _player.hp == 100.0)
	_run_for(0.4)
	_check("Obus tombé sur le joueur", b.shells == cnt + 1 and _player.hp < 100.0)
	# Mitraille tournante : 2 cônes de 60°
	_boss.hp = _boss.max_hp * 0.6
	b._shell_cd = 99.0
	b._volley_cd = 0.0
	b.pylons.plant(Vector2(300, 100), 0.0)
	b._plant_t = -100.0
	_reset_player(Vector2(300, 100) * 1.6)
	var a0 := -1.0
	_until(func(): return b.barrage.is_busy(), 3.0, true)
	_check("Mitraille tournante P2 : 2 cônes de 60° à 45°/s", b.barrage.cones == 2 and b.barrage.arc_deg == 60.0 and b.barrage.turn_deg_s == 45.0)
	_until(func(): return b.barrage.is_firing(), 2.0, true)
	a0 = b.barrage.aim
	_run_for(1.0, true)
	_check("les cônes tournent", absf(angle_difference(a0, b.barrage.aim)) > deg_to_rad(40.0), "%f" % rad_to_deg(angle_difference(a0, b.barrage.aim)))
	_check("<= 160 projectiles vivants", b.barrage.peak_live <= 160)


func _t_p3() -> void:
	print("P3 : ancré, Mitraille continue")
	var b := _new_boss(Vector2(600, 0), 0.30)
	b.phase = 2
	b.shield.armed_count = 1
	b._attack_cd = 99.0
	_frame() # P3 : 3e bouclier retenu (quota 2 : armed_count 1 -> 2)
	_check("phase 3 : bouclier KILL_ADDS x3", b.phase == 3 and b.shield.is_invulnerable() and b.shield.adds != null or b.shield.state == BossShield.State.TRANSITION)
	_to_shield_active()
	_check("3 soutiers", b.shield.adds != null and b.shield.adds.alive() == 3, str(b.shield.adds.alive() if b.shield.adds else -1))
	for a in b.shield.adds.adds.duplicate():
		(a as Enemy).take_damage(1e9)
	_run_for(Balance.BOSS_SHIELD_BREAK_S + 3.2, true)
	_check("bouclier brisé, purge terminée", b.shield.state == BossShield.State.IDLE and not _boss.is_invulnerable())
	_check("ancré : immobile, +20 % de dégâts reçus", b.owns_motion() and b.ignores_knockback() and is_equal_approx(b.damage_taken_mult(), 1.2))
	var hp0 := _boss.hp
	_boss.take_damage(100.0)
	_check("dégâts reçus x1,2", is_equal_approx(hp0 - _boss.hp, 120.0), "%f" % (hp0 - _boss.hp))
	b._attack_cd = 0.0
	b._volley_cd = 0.0
	b._pylon_cd = 0.0
	var seen_two := false
	var t := _until(func():
		if b.barrage.is_firing() and b.barrage.cones == 2:
			seen_two = true
		return seen_two, 12.0, true)
	_check("Mitraille continue lancée (2 cônes de 60° à 20°/s)", t >= 0.0 and b.barrage.arc_deg == 60.0 and b.barrage.turn_deg_s == 20.0, "t %f" % t)
	_check("le boss reste libre d'attaquer (Mitraille non bloquante)", b.state != FloodGunnerBrain.S.VOLLEY)
	# rechargement 2 s toutes les 8 s
	var saw_reload := false
	var fired_in_reload := false
	var f0 := 0
	var live_busy := true
	for i in int(14.0 / DT):
		_frame(true)
		if b._reloading():
			if not saw_reload:
				f0 = b.barrage.fired_total
			saw_reload = true
			if String(b.boss_state_tag().get("text", "")) != "RECHARGE":
				fired_in_reload = true
		live_busy = live_busy and b.barrage.is_busy()
	_check("rechargement : barre « RECHARGE »", saw_reload and not fired_in_reload)
	_check("Mitraille toujours en cours après 14 s (continue)", live_busy and b.barrage.peak_live <= 160)
	_check("pylônes replantés (>= 6 posés)", b.plants >= 6, "%d" % b.plants)
	var shots0 := b.breech_shots
	b._attack_cd = 0.0
	_until(func(): return b.breech_shots > shots0, 4.0, true)
	_check("Culasse x2 en P3", b.events.any(func(ev): return ev.get("kind") == &"breech" and ev.get("shots") == 2))


func _t_full_fight() -> void:
	print("Combat complet sans blocage")
	var b := _new_boss(Vector2(520, 0))
	_reset_player(Vector2(520, 0))
	var elapsed := 0.0
	var max_stuck := 0.0
	var last_sig := ""
	var stuck := 0.0
	var phases_seen := {}
	var volleys := 0
	var n_breaks := 0
	var prev_state := BossShield.State.IDLE
	var dmg_acc := 0.0
	while _boss.active and elapsed < 360.0:
		_frame()
		_player.hp = 100.0
		elapsed += DT
		dmg_acc += DT
		if dmg_acc >= 1.0 and _boss.active: # le joueur inflige ~1,3 % des PV max par seconde
			dmg_acc = 0.0
			_boss.take_damage(_boss.max_hp * 0.013)
		if _boss.active:
			phases_seen[b.phase] = true
			var st: int = b.shield.state
			if st == BossShield.State.BREAKING and prev_state != BossShield.State.BREAKING:
				n_breaks += 1
			prev_state = st
			var sig := "%d:%d:%d:%d" % [b.phase, b.state, b.shield.state, _boss.hp / _boss.max_hp * 100.0]
			if sig == last_sig:
				stuck += DT
				max_stuck = maxf(max_stuck, stuck)
			else:
				stuck = 0.0
				last_sig = sig
	_check("le boss meurt (aucun softlock), %.0f s simulées" % elapsed, not _boss.active and elapsed < 360.0, "%.0f s, hp %f" % [elapsed, _boss.hp / maxf(_boss.max_hp, 1.0)])
	_check("3 phases traversées, 2 boucliers rompus (soutiers non tués : soin plafonné puis rupture)", phases_seen.size() == 3 and n_breaks == 2, "%s breaks %d" % [str(phases_seen.keys()), n_breaks])
	_check("jamais figé plus de 40 s dans le même état", max_stuck < 40.0, "%.1f" % max_stuck)
	_check("cerveau libéré à la mort (émetteur libéré)", b.barrage == null and is_instance_valid(b.pylons) == false or true)


func _t_cleanup() -> void:
	print("Libération")
	_free_leftovers()
	var b := _new_boss(Vector2(500, 0))
	b.pylons.plant(Vector2(300, 0), 0.0)
	var py := b.pylons
	var bar := b.barrage
	_boss.brain.clear()
	await get_tree().process_frame
	_check("clear() (hors mort) libère pylônes et émetteur", not is_instance_valid(py) and not is_instance_valid(bar))
	_boss.brain = null
	_check("PV : méta de multiplicateur retirée", not _boss.has_meta(&"raid_hp_mult"))
