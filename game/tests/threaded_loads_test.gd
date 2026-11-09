extends Node
## Travail en fil sans attente bloquante du fil principal (gel fenêtré du banc PC, docs/Mesures_Perf_Android.md §7) :
##   A. BakedShadows : l'annulation d'une re-cuisson de fond ne l'attend pas (tâche orpheline libérée une fois
##      finie), le résultat arrive par _process, un nœud libéré pendant la tâche ne fait rien planter ;
##   B. EnemyVisual._warm_bosses : un seul chargement en fil à la fois, chaque demande récupérée
##      (load_threaded_get) et rangée dans le cache, jamais redemandée ; boss_frames récupère un préchargement
##      en cours ; changement d'étage = cache des autres étages vidé.
## godot --headless --path game res://tests/threaded_loads_test.tscn

var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	await _test_baked_shadows()
	await _test_warm_bosses()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _params(len_u: float) -> Dictionary:
	return {&"sun_shadow_length_u": len_u, &"sun_rotation_deg": 315.0, &"sun_shadow_smooth": 1.0,
		&"sun_shadow_color": Color(0.1, 0.1, 0.12, 0.5)}


func _frames_until(cond: Callable, max_s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_s * 1000.0):
			return false
		await get_tree().process_frame
	return true


func _test_baked_shadows() -> void:
	var map: Node2D = load("res://scenes/stage/maps/cite_rouille.tscn").instantiate()
	add_child(map)
	var bs := BakedShadows.new()
	add_child(bs)
	bs.bake(map, _params(2.0))
	_check(bs.sprite.texture != null and is_equal_approx(bs.baked_length_u, 2.0), "cuisson synchrone (%s)" % bs.describe())

	# re-cuisson de fond puis annulation immédiate : aucune attente sur le fil principal
	bs.update_params(_params(3.0), 1.0)
	_check(bs.is_baking(), "re-cuisson de fond lancée")
	var t0 := Time.get_ticks_usec()
	bs._cancel_task()
	var cancel_ms := (Time.get_ticks_usec() - t0) / 1000.0
	_check(not bs.is_baking(), "tâche abandonnée")
	_check(cancel_ms < 5.0, "annulation sans attente (%.2f ms)" % cancel_ms)
	_check(await _frames_until(func() -> bool: return BakedShadows.orphan_count() == 0, 3.0), "tâche orpheline libérée une fois finie")
	_check(is_equal_approx(bs.baked_length_u, 2.0), "résultat annulé ignoré (L=%.2f)" % bs.baked_length_u)

	# re-cuisson menée à terme : résultat appliqué par _process
	bs.update_params(_params(4.0), 1.0)
	_check(await _frames_until(func() -> bool: return not bs.is_baking(), 3.0), "re-cuisson de fond terminée")
	_check(is_equal_approx(bs.baked_length_u, 4.0) and bs.sprite.texture != null, "résultat de fond appliqué (%s)" % bs.describe())

	# nœud libéré pendant une tâche : la tâche n'écrit que dans son dictionnaire (callable statique)
	bs.update_params(_params(5.0), 1.0)
	_check(bs.is_baking(), "re-cuisson lancée avant libération")
	bs.queue_free()
	await get_tree().process_frame
	var bs2 := BakedShadows.new()
	add_child(bs2)
	_check(await _frames_until(func() -> bool: return BakedShadows.orphan_count() == 0, 3.0), "orpheline d'un nœud libéré récupérée par une autre instance")
	bs2.queue_free()
	map.queue_free()
	await get_tree().process_frame


func _test_warm_bosses() -> void:
	var a := &"cerf"
	var b := &"smelter"
	_check(not EnemyVisual.boss_cfg(a).is_empty() and not EnemyVisual.boss_cfg(b).is_empty(), "boss de test connus (%s, %s)" % [a, b])
	var s := GDScript.new()
	s.source_code = "extends Node\nvar floor_boss: StringName = &\"\"\n"
	s.reload()
	var sm := Node.new()
	sm.set_script(s)
	sm.set(&"floor_boss", a)
	sm.add_to_group(&"stage_manager")
	add_child(sm)

	EnemyVisual._warm_bosses(get_tree())
	var st := EnemyVisual.warm_state()
	_check(st["floor"] == a and st["loading"] != &"", "un chargement en fil lancé (%s)" % st)
	var ok := await _frames_until(func() -> bool:
		var w := EnemyVisual.warm_state()
		return int(w["pending"]) == 0 and w["loading"] == &"", 30.0)
	_check(ok, "file de préchargement vidée (%s)" % EnemyVisual.warm_state())
	var ids: Array[StringName] = [a]
	for m in EnemyVisual.mini_pool(a):
		ids.append(StringName(m))
	for id in ids:
		var path := RenderStyle.resolve(EnemyVisual.boss_path(id))
		if path == "" or not ResourceLoader.exists(path):
			continue
		_check(EnemyVisual._boss_cache.has(id), "%s rangé dans le cache" % id)
		_check(ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "demande de %s récupérée (aucune en suspens)" % id)
	_check(EnemyVisual._boss_cache.get(a) is SpriteFrames, "sprite du boss d'étage préchargé")
	var cerf_frames: SpriteFrames = EnemyVisual._boss_cache.get(a)
	_check(EnemyVisual.boss_frames(a) == cerf_frames, "boss_frames sert le préchargement")
	EnemyVisual._warm_bosses(get_tree())
	_check(EnemyVisual.warm_state()["loading"] == &"", "aucune nouvelle demande pour un étage déjà préchargé")

	# changement d'étage : cache des autres boss vidé, boss_frames récupère le chargement en cours
	sm.set(&"floor_boss", b)
	EnemyVisual._warm_bosses(get_tree())
	_check(not EnemyVisual._boss_cache.has(a), "cache de l'étage précédent vidé")
	var cur: StringName = EnemyVisual.warm_state()["loading"]
	_check(cur != &"", "préchargement du nouvel étage lancé")
	if cur != &"":
		var cur_path := RenderStyle.resolve(EnemyVisual.boss_path(cur))
		var f := EnemyVisual.boss_frames(cur)
		_check(f != null, "boss_frames(%s) pendant son préchargement" % cur)
		_check(EnemyVisual.warm_state()["loading"] == &"", "chargement en cours récupéré par boss_frames")
		_check(ResourceLoader.load_threaded_get_status(cur_path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, "aucune demande laissée en suspens")
	ok = await _frames_until(func() -> bool:
		var w := EnemyVisual.warm_state()
		return int(w["pending"]) == 0 and w["loading"] == &"", 30.0)
	_check(ok, "file du nouvel étage vidée (%s)" % EnemyVisual.warm_state())
	_check(EnemyVisual._boss_cache.get(b) is SpriteFrames, "sprite du nouveau boss d'étage préchargé")
	sm.queue_free()
	await get_tree().process_frame
