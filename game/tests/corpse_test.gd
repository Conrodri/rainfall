extends Node
## Cadavres des monstres de base (CorpsePool) : anim death jouée puis dernière frame tenue, plafond par palier,
## le plus ancien réutilisé en premier, aucun nœud créé par une mort, fondu puis retrait, repli sans anim death.
## godot --headless --path game res://tests/corpse_test.tscn

const U := 64.0

var _fails := 0
var _director: Director


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _kill_swarm(pos: Vector2, angle: float) -> Enemy:
	var e := _director.spawn_enemy(1, pos, false, [] as Array[StringName], 0)
	e.visual.set_facing(angle)
	e.take_damage(1.0e9)
	return e


func _run() -> void:
	RunState.level = 1
	_director = load("res://scenes/enemies/director.tscn").instantiate()
	_director.spawning_enabled = false
	get_tree().root.add_child(_director)
	await get_tree().process_frame
	_director.process_mode = Node.PROCESS_MODE_DISABLED
	var pool: CorpsePool = _director.corpses
	pool.process_mode = Node.PROCESS_MODE_ALWAYS # le Director est désactivé (IA figée), pas le pool

	print("Constantes et pool")
	_check("plafonds par palier croissants 12 / 24 / 40", CorpsePool.cap_for_tier(0) == 12 and CorpsePool.cap_for_tier(1) == 24 and CorpsePool.cap_for_tier(2) == 40)
	_check("sous les pickups (z -2 < -1)", pool.z_index < -1)
	_check("plafond courant suit Quality (%d)" % pool.capacity(), pool.capacity() == CorpsePool.cap_for_tier(Quality.tier))
	pool.set_capacity(40)

	print("Mort d'un essaim : cadavre")
	var tex := load("res://assets/sprites/monsters/swarm_tier1/swarm_tier1.tres") as SpriteFrames
	_check("anims death_e/s/w/n livrées, non bouclées", tex != null and tex.has_animation(&"death_e") and tex.has_animation(&"death_n") and not tex.get_animation_loop(&"death_s"))
	var e := _kill_swarm(Vector2(5 * U, 5 * U), PI * 0.5) # sud
	_check("monstre rendu au pool, caché", not e.active and not e.visible)
	_check("un cadavre vivant", pool.live_count == 1, str(pool.live_count))
	var c := pool.sprite_at(0)
	_check("anim death_s (direction la plus proche)", c.visible and c.animation == &"death_s", str(c.animation))
	_check("position du monstre", c.position.is_equal_approx(Vector2(5 * U, 5 * U)))
	_check("échelle du sprite vivant reprise", c.scale.x > 0.0 and c.scale.y > 0.0)
	for k in 90:
		await get_tree().process_frame
	_check("dernière frame tenue (arrêté)", not c.is_playing() and c.frame == c.sprite_frames.get_frame_count(&"death_s") - 1, "frame %d playing %s" % [c.frame, str(c.is_playing())])
	var e2 := _kill_swarm(Vector2(-4 * U, 2 * U), PI) # ouest
	_check("direction ouest", pool.sprite_at(1).animation == &"death_w", str(pool.sprite_at(1).animation))
	var e3 := _kill_swarm(Vector2(0, -3 * U), -PI * 0.5) # nord
	_check("direction nord", pool.sprite_at(2).animation == &"death_n", str(pool.sprite_at(2).animation))
	var e4 := _kill_swarm(Vector2(0, 3 * U), 0.0)
	_check("direction est", pool.sprite_at(3).animation == &"death_e", str(pool.sprite_at(3).animation))
	pool.clear()
	_check("clear : plus aucun cadavre", pool.live_count == 0 and not pool.sprite_at(0).visible)

	print("Plafond, réutilisation, zéro allocation")
	pool.set_capacity(10)
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var objs0 := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	for i in 25:
		_kill_swarm(Vector2(i * 10.0, 0.0), 0.0)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	_check("25 morts, plafond 10 : %d cadavres" % pool.live_count, pool.live_count == 10)
	_check("aucun nœud créé (%d -> %d)" % [nodes0, nodes1], nodes0 == nodes1)
	_check("le plus ancien est réutilisé en premier (emplacement 0 = mort n°21 : x=200)", absf(pool.sprite_at(0).position.x - 200.0) < 0.1 or absf(pool.sprite_at(0).position.x - 240.0) < 0.1, str(pool.sprite_at(0).position.x))
	var oldest_x := INF
	var newest_x := -INF
	for i in 10:
		oldest_x = minf(oldest_x, pool.sprite_at(i).position.x)
		newest_x = maxf(newest_x, pool.sprite_at(i).position.x)
	_check("les 10 derniers survivent (x 150..240)", is_equal_approx(oldest_x, 150.0) and is_equal_approx(newest_x, 240.0), "%f %f" % [oldest_x, newest_x])
	_check("objets Godot stables (pas d'allocation)", absi(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objs0) < 40, str(int(Performance.get_monitor(Performance.OBJECT_COUNT)) - objs0))
	pool.set_capacity(4)
	_check("réduction du plafond : cadavres en trop retirés", pool.live_count <= 4, str(pool.live_count))
	pool.set_capacity(40)

	print("Fondu et retrait")
	pool.clear()
	_kill_swarm(Vector2.ZERO, 0.0)
	pool._process(Balance.CORPSE_HOLD_S - 0.1)
	_check("avant le fondu : opaque", is_equal_approx(pool.sprite_at(0).modulate.a, 1.0) and pool.fading_count() == 0)
	pool._process(0.1 + Balance.CORPSE_FADE_S * 0.5)
	_check("mi-fondu : alpha ~0,5", absf(pool.sprite_at(0).modulate.a - 0.5) < 0.05 and pool.fading_count() == 1, str(pool.sprite_at(0).modulate.a))
	pool._process(Balance.CORPSE_FADE_S * 0.6)
	_check("fondu fini : retiré, process éteint", pool.live_count == 0 and not pool.sprite_at(0).visible and not pool.is_processing())

	print("Coût")
	pool.clear()
	for i in 40:
		_kill_swarm(Vector2(i * 10.0, 0.0), 0.0)
	var t0 := Time.get_ticks_usec()
	for i in 200:
		pool._process(0.001)
	var per := float(Time.get_ticks_usec() - t0) / 200.0
	_check("40 cadavres : _process %.1f us/image < 150 us" % per, pool.live_count == 40 and per < 150.0)
	pool.clear()

	print("Repli sans anim death")
	var old := SpriteFrames.new()
	old.add_animation(&"run_s")
	var before := pool.live_count
	_check("frames sans death_ : pas de cadavre", not pool.try_spawn(Vector2.ZERO, old, 2, Vector2.ONE, Vector2.ZERO, Color.WHITE) and pool.live_count == before)
	_check("octant inconnu : pas de cadavre", not pool.try_spawn(Vector2.ZERO, tex, -1, Vector2.ONE, Vector2.ZERO, Color.WHITE))
	_check("floor_started vide le pool", _fill_and_floor(pool))

	_director.queue_free()
	await get_tree().process_frame
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _fill_and_floor(pool: CorpsePool) -> bool:
	_kill_swarm(Vector2.ZERO, 0.0)
	var had := pool.live_count
	Events.floor_started.emit(2)
	return had == 1 and pool.live_count == 0
