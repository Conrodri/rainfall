extends SceneTree
## Mort -> Events.enemy_killed -> retour au pool ; statuts ; affixes d'élite ; boss.
## godot --headless --fixed-fps 60 --path game --script res://tests/enemies_kill.gd

var _fails := 0
var _director: Node2D
var _player: Node2D
var _events: Node
var _kills: Array = []
var _boss_events: Array = []
var _damaged := 0


func _initialize() -> void:
	_events = root.get_node("Events")
	_events.enemy_killed.connect(func(e, pos, tier, elite): _kills.append([e, pos, tier, elite]))
	_events.enemy_damaged.connect(func(_e, _a, _c, _el): _damaged += 1)
	_events.boss_spawned.connect(func(b, floor_boss): _boss_events.append([&"spawned", b, floor_boss]))
	_events.boss_killed.connect(func(b, floor_boss): _boss_events.append([&"killed", b, floor_boss]))
	_player = load("res://tests/enemies_fake_player.gd").new()
	_player.position = Vector2(5000, 5000) # loin : aucun contact
	root.add_child(_player)
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	root.add_child(_director)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var pool_size: int = _director.free_count()
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	# 1. Mort -> signal -> pool
	var e: Node2D = _director.spawn_enemy(1, Vector2(100, 50))
	_check("spawn actif", e != null and e.active and e.is_in_group(&"enemies"))
	_check("pool -1", _director.free_count() == pool_size - 1 and _director.active_count() == 1)
	await physics_frame
	await physics_frame
	_check("couche 3 active", e.collision_layer == 1 << 2)
	e.take_damage(5.0, true, &"")
	_check("enemy_damaged émis", _damaged == 1)
	_check("PV réduits", is_equal_approx(e.hp, e.max_hp - 5.0))
	var death_pos: Vector2 = e.position
	e.take_damage(1e6)
	_check("enemy_killed émis une fois", _kills.size() == 1)
	if _kills.size() == 1:
		_check("args signal", _kills[0][0] == e and _kills[0][1] == death_pos and _kills[0][2] == 1 and _kills[0][3] == false)
	_check("inactif + hors groupe", not e.active and not e.is_in_group(&"enemies") and not e.visible)
	_check("retour au pool", _director.free_count() == pool_size and _director.active_count() == 0)
	e.take_damage(1e6)
	_check("pas de double mort", _kills.size() == 1)
	await physics_frame
	await physics_frame
	_check("couche retirée", e.collision_layer == 0)

	# 2. Réutilisation sans instanciation
	var e2: Node2D = _director.spawn_enemy(3, Vector2(-80, 0), true, [&"burn", &"poison"] as Array[StringName])
	_check("instance réutilisée", e2 == e)
	_check("élite PV ×ELITE_HP (4, Alignement RoR2)", is_equal_approx(e2.max_hp, root.get_node("Balance").monster_hp(300.0, 1.0) * root.get_node("Balance").ELITE_HP))

	# 3. Statuts subis : brûlure cumulable (total sur 3 s), poison (cumuls plafonnés à DOT_MAX_STACKS), ralentissement
	e2.apply_status(&"burn", {"total": 18.0, "duration": 3.0})
	e2.apply_status(&"burn", {"total": 12.0, "duration": 3.0})
	for k in 12:
		e2.apply_status(&"poison", {"total": 4.0, "duration": 4.0})
	e2.apply_status(&"slow", {})
	_check("statuts actifs", e2.is_burning() and e2.is_poisoned() and e2.is_slowed())
	_check("brûlure cumulée (2)", e2._burn_stack_left.size() == 2)
	_check("poison plafonné à %d" % e2.DOT_MAX_STACKS, e2._poison_left.size() == e2.DOT_MAX_STACKS)
	var hp0: float = e2.hp
	for k in 280: # 4,7 s : brûlure (3 s) et poison (4 s) terminés
		await physics_frame
	var lost: float = hp0 - e2.hp
	# brûlure 18 + 12 + poison 10 cumuls × 4 = 40 -> 70 attendus (± un tick)
	_check("dégâts DoT ≈ 70 (%.1f)" % lost, absf(lost - 70.0) <= 3.0)
	_check("brûlure finie, ralentissement fini", not e2.is_burning() and not e2.is_slowed())

	# 4. Affixes d'élite appliqués au joueur au contact
	_player.position = e2.position + Vector2(40, 0)
	for k in 90:
		await physics_frame
	_check("joueur touché par la brute (%d)" % _player.hits, _player.hits >= 1)
	_check("affixes burn+poison reçus", _player.statuses.has(&"burn") and _player.statuses.has(&"poison"))
	e2.take_damage(1e9)
	_check("2e mort émise (élite)", _kills.size() == 2 and _kills[1][3] == true)

	# 5. Boss : groupes, signaux, pas d'enemy_killed
	var boss: Node2D = _director.spawn_boss(&"mini", Vector2(300, 0))
	_check("boss groupes", boss.is_in_group(&"bosses") and boss.is_in_group(&"enemies") and boss.tier == 4)
	_check("boss_spawned", _boss_events.size() == 1 and _boss_events[0][2] == false)
	_check("PV boss", is_equal_approx(boss.max_hp, root.get_node("Balance").boss_hp(&"mini", 1.0)))
	boss.take_damage(1e9)
	_check("boss_killed", _boss_events.size() == 2 and _boss_events[1][0] == &"killed")
	_check("boss hors groupes", not boss.is_in_group(&"bosses") and _director.boss_count() == 0)
	_check("pas d'enemy_killed pour un boss", _kills.size() == 2)

	await _test_hit_weight()

	# 6. Aucun nœud créé pendant le test
	await physics_frame
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check("aucune instanciation (%d -> %d)" % [nodes0, nodes1], nodes0 == nodes1)

	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	quit(1 if _fails else 0)


## 5b. Poids des coups : coup direct = hitstop + recul (+ particules) ; DoT = ni l'un ni l'autre ;
## plus fort = gel et recul plus grands, toujours sous les plafonds de Balance.
func _test_hit_weight() -> void:
	var bal: Node = root.get_node("Balance")
	var U: float = bal.UNIT_PX
	var fx_script: GDScript = load("res://scripts/fx/hit_fx.gd") # chargé à l'exécution : --script compile avant les autoloads
	var hitfx = fx_script.instance()
	_check("HitFx présent (pool créé avec le Director)", hitfx != null)
	var imp0: int = fx_script.stat_impacts
	var dot0: int = fx_script.stat_dots
	_player.position = Vector2(0, 800) # proche : ni LOD ni recyclage hors écran pendant la mesure
	# coup direct venant de la gauche -> recul vers +x, gel
	var a: Node2D = _director.spawn_enemy(3, Vector2(0, 600))
	await physics_frame
	var pa: Vector2 = a.position
	a.take_damage(2.0, false, &"fire", {"source_pos": pa + Vector2(-100, 0)})
	var stop_a: float = a.hitstop_left()
	var kb_a: Vector2 = a.knockback_left()
	_check("coup direct : hitstop %.3f s > 0" % stop_a, stop_a > 0.0)
	_check("coup direct : recul vers +x (%.1f px)" % kb_a.x, kb_a.x > 0.0 and absf(kb_a.y) < 0.01)
	_check("coup direct : particules d'impact", fx_script.stat_impacts > imp0)
	await physics_frame
	_check("figé pendant le hitstop", a.position == pa)
	for k in 20:
		await physics_frame
	_check("hitstop fini, recul consommé", a.hitstop_left() <= 0.0 and a.knockback_left() == Vector2.ZERO)
	# DoT : ni gel ni recul, une particule
	var d: Node2D = _director.spawn_enemy(3, Vector2(300, 600))
	await physics_frame
	d.take_damage(2.0, false, &"burn")
	d.take_damage(2.0, false, &"fire", {"is_dot": true, "source_pos": d.position + Vector2(-100, 0)})
	_check("DoT : pas de hitstop", d.hitstop_left() == 0.0)
	_check("DoT : pas de recul", d.knockback_left() == Vector2.ZERO)
	_check("DoT : particules discrètes", fx_script.stat_dots >= dot0 + 2)
	# échelle continue : coup plus fort = gel et recul plus grands, plafonnés
	var w: Node2D = _director.spawn_enemy(3, Vector2(-300, 600))
	var s: Node2D = _director.spawn_enemy(3, Vector2(-300, 800))
	var o: Node2D = _director.spawn_enemy(3, Vector2(-300, 1000))
	await physics_frame
	w.take_damage(2.0, false, &"fire", {"source_pos": w.position + Vector2(-50, 0)})
	s.take_damage(100.0, false, &"fire", {"source_pos": s.position + Vector2(-50, 0)})
	o.take_damage(1.0, false, &"fire", {"source_pos": o.position + Vector2(-50, 0), "force": 5.0})
	var mass: float = bal.knockback_mass(3, false)
	_check("plus fort -> hitstop plus long (%.3f < %.3f)" % [w.hitstop_left(), s.hitstop_left()], w.hitstop_left() < s.hitstop_left())
	_check("plus fort -> recul plus grand (%.1f < %.1f px)" % [w.knockback_left().length(), s.knockback_left().length()],
		w.knockback_left().length() < s.knockback_left().length())
	_check("hitstop ≤ max (%.3f ≤ %.3f)" % [o.hitstop_left(), bal.HITSTOP_MAX_S], o.hitstop_left() <= bal.HITSTOP_MAX_S + 1e-6 and s.hitstop_left() <= bal.HITSTOP_MAX_S)
	_check("recul ≤ max (%.1f ≤ %.1f px)" % [o.knockback_left().length(), bal.KB_MAX_U * mass * U],
		o.knockback_left().length() <= bal.KB_MAX_U * mass * U + 0.01)
	_check("critique > normal", bal.hit_force(2.0, 12.0, true) > bal.hit_force(2.0, 12.0, false))
	# coups répétés : recul cumulé plafonné, pas de nouveau gel avant le réarmement
	for k in 5:
		o.take_damage(1.0, false, &"fire", {"source_pos": o.position + Vector2(-50, 0), "force": 1.0})
	_check("recul cumulé plafonné", o.knockback_left().length() <= bal.KB_MAX_U * mass * U + 0.01)
	# essaim reculé plus loin qu'une brute à force égale
	var t1: Node2D = _director.spawn_enemy(1, Vector2(300, 1000))
	await physics_frame
	t1.take_damage(1.0, false, &"fire", {"source_pos": t1.position + Vector2(-50, 0), "force": 0.5})
	_check("essaim > brute (recul %.1f > %.1f px)" % [t1.knockback_left().length(), bal.knockback_px(0.5, mass)],
		t1.knockback_left().length() > bal.knockback_px(0.5, mass))
	# boss : pas de gel, recul quasi nul
	var boss: Node2D = _director.spawn_boss(&"mini", Vector2(600, 600))
	boss.take_damage(1.0, false, &"fire", {"source_pos": boss.position + Vector2(-50, 0), "force": 1.0})
	_check("boss : pas de hitstop", boss.hitstop_left() == 0.0)
	_check("boss : recul ≤ 0,05 u (%.2f px)" % boss.knockback_left().length(), boss.knockback_left().length() <= 0.05 * U)
	for e in [a, d, w, s, o, t1, boss]:
		e.take_damage(1e9)
	await physics_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_fails += 1
	print("%s %s" % ["ok  " if ok else "FAIL", label])
