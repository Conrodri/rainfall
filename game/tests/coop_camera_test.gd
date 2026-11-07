extends Node
## Caméra commune de la coop locale (étape 4, SharedCamera) dans le vrai Main, arène plate du mode test :
## - deux joueurs locaux : SharedCamera courante, caméras des joueurs coupées, Main.camera = SharedCamera ;
## - joueurs proches : vue solo (multiplicateur 1) ; écartés : dézoom, les deux dans la vue ; zoom borné à
##   1 / COOP_LOCAL_CAM_ZOOM_MAX ;
## - laisse : un joueur téléporté ou qui pousse au-delà de l'étendue maximale est retenu, l'autre n'est jamais tiré ;
## - spectateur exclu du cadre et de la laisse ;
## - secousse (Main.shake) toujours appliquée à la caméra commune ; Director : apparitions autour du cadre commun ;
## - solo : aucune SharedCamera (caméra du joueur 1 inchangée).
## godot --headless --path game res://tests/coop_camera_test.tscn  -> RESULT: OK


class FakeSource extends InputSource:
	var mv := Vector2.ZERO

	func _init(dev: int) -> void:
		kind = Kind.PAD
		device = dev

	func mode() -> int:
		return Platform.InputMode.GAMEPAD

	func move_vector() -> Vector2:
		return mv

	func aim_vector() -> Vector2:
		return Vector2.ZERO

	func is_pressed(_a: StringName) -> bool:
		return false

	func just_pressed(_a: StringName) -> bool:
		return false

	func just_released(_a: StringName) -> bool:
		return false

	func pointer_world(_c: CanvasItem) -> Variant:
		return null

	func owns_event(_e: InputEvent) -> bool:
		return false


var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _process_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _make_main(setup: Array[Dictionary]) -> Node:
	var m: Node = load("res://scenes/main.tscn").instantiate()
	m.set(&"save_path", "user://test_coop_camera.json")
	m.set(&"run_seed", 777)
	m.set(&"party_setup", setup)
	add_child(m)
	await m.game_ready
	var d: Node = m.get(&"director")
	d.set(&"spawning_enabled", false)
	d.set(&"waves_enabled", false)
	await _frames(2)
	return m


func _run() -> void:
	TestMode.begin() # arène plate (StageManager : carte test_arena, ni coffre ni pilier), profil en bac à sable
	print("Solo")
	var solo := await _make_main([])
	_check("solo : pas de caméra commune", SharedCamera.active == null and not (solo.get(&"camera") is SharedCamera))
	solo.queue_free()
	await _process_frames(3)

	print("Deux joueurs locaux")
	var src: Array[FakeSource] = [FakeSource.new(80), FakeSource.new(81)]
	var setup: Array[Dictionary] = [{"input": src[0], "character": &"ardent", "loadout": {}, "skin": ""},
		{"input": src[1], "character": &"ardent", "loadout": {}, "skin": ""}]
	var main := await _make_main(setup)
	var cam := main.get(&"camera") as SharedCamera
	var players: Array = main.get(&"players")
	var p0: Node2D = players[0]
	var p1: Node2D = players[1]
	for p in players:
		(p as Node2D).call(&"grant_invulnerability", 99999.0)
	_check("caméra commune courante", cam != null and SharedCamera.active == cam and cam.is_current())
	var c0 := p0.get_node_or_null(^"Camera2D") as Camera2D
	var c1 := p1.get_node_or_null(^"Camera2D") as Camera2D
	_check("caméras des joueurs coupées", (c0 == null or not c0.enabled) and (c1 == null or not c1.enabled))
	_check("Director ancré sur le cadre commun", (main.get(&"director") as Director)._view_anchor(Vector2(-99999, 0)) == cam.view_center())

	var base := p0.global_position
	p1.global_position = base + Vector2(64, 0)
	cam.snap()
	_check("joueurs proches : vue solo", is_equal_approx(cam.mult, 1.0), str(cam.mult))
	var w := cam.max_extent()
	_check("étendue max plus large que la vue solo", w.x > cam.view_extent(1.0).x - 2.0 * SharedCamera.margins().x)

	p1.global_position = base + Vector2(w.x * 0.8, 0)
	await _frames(2)
	cam.snap()
	_check("écartés : dézoom", cam.mult < 1.0 and cam.mult >= SharedCamera.min_mult() - 0.001, str(cam.mult))
	var vr := cam.view_rect()
	_check("les deux dans la vue", vr.has_point(p0.global_position) and vr.has_point(p1.global_position), str(vr))

	print("Laisse")
	p1.global_position = base + Vector2(w.x * 3.0, 0)
	await _frames(2)
	_check("téléporté : ramené à l'étendue max", absf(p1.global_position.x - p0.global_position.x) <= w.x + 1.0, "%f / %f" % [p1.global_position.x - p0.global_position.x, w.x])
	_check("l'autre n'est pas tiré", p0.global_position.distance_to(base) < 2.0, str(p0.global_position - base))
	cam.snap()
	_check("zoom borné au dézoom max", is_equal_approx(cam.mult, SharedCamera.min_mult()), str(cam.mult))
	vr = cam.view_rect()
	_check("étirés au max : toujours dans la vue", vr.grow(-8.0).has_point(p0.global_position) and vr.grow(-8.0).has_point(p1.global_position))
	src[1].mv = Vector2(1, 0)
	await _frames(40)
	_check("pousse contre le bord : retenu", absf(p1.global_position.x - p0.global_position.x) <= w.x + 1.0)
	src[1].mv = Vector2(1, 1).normalized()
	var y_before := p1.global_position.y
	await _frames(20)
	_check("mur doux : avance sur l'axe libre", p1.global_position.y > y_before + 20.0, "%f -> %f" % [y_before, p1.global_position.y])
	_check("retenu sur l'axe bloqué", absf(p1.global_position.x - p0.global_position.x) <= w.x + 1.0)
	_check("compteur de laisse", cam.leashed_count >= 1)
	src[1].mv = Vector2.ZERO
	await _frames(2)

	print("Spectateur")
	Players.set_spectating(1)
	p1.global_position = base + Vector2(w.x * 3.0, 0)
	await _frames(3)
	_check("spectateur non retenu", absf(p1.global_position.x - base.x) > w.x * 2.0)
	cam.snap()
	_check("spectateur hors cadre : vue solo autour du joueur 1", is_equal_approx(cam.mult, 1.0) and cam.frame_rect.has_point(p0.global_position) and not cam.frame_rect.has_point(p1.global_position))
	Players.resurrect_all()

	print("Secousse")
	main.call(&"shake", 12.0, 20.0, 0.4)
	await _process_frames(3)
	_check("secousse sur la caméra commune", cam.offset != Vector2.ZERO)

	main.queue_free()
	await _process_frames(3)
	_check("caméra commune libérée", SharedCamera.active == null)
	Players.clear()
	TestMode.end()
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)
