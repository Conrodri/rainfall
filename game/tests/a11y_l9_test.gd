extends Node
## Lot A11y-L9 : télégraphes renforcés, audio mono, taille du réticule, flèches de menace hors écran.
## godot --headless --path game res://tests/a11y_l9_test.tscn  -> RESULT: OK

const CUES := preload("res://scripts/ui/offscreen_cues.gd")
const CFG := "user://_test_a11y_l9_settings.cfg"

var _fails := 0


class FakeHud extends Node:
	var rects: Array[Rect2] = []

	func reserved_rects() -> Array[Rect2]:
		return rects


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, ok: bool, detail: String = "") -> void:
	if ok:
		print("  ok  " + label)
	else:
		_fails += 1
		print("  ÉCHEC  " + label + ("  (" + detail + ")" if detail != "" else ""))


func _run() -> void:
	var old_path := GameSettings.cfg_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = CFG
	await _telegraphs()
	_mono()
	await _mono_poll()
	_reticle()
	_deadzone()
	await _cues()
	EnemyTelegraph.strong_override = -1
	EnemyTelegraph.refresh_strong()
	Audio.apply_mono(false)
	GameSettings.cfg_path = old_path
	InputSetup.apply_stick_deadzone()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _telegraphs() -> void:
	print("Télégraphes renforcés")
	EnemyTelegraph.strong_override = -1
	EnemyTelegraph.refresh_strong()
	_check("défaut : normal", not EnemyTelegraph.strong())
	_check("normal : liseré 6/2, remplissage 0,28", EnemyTelegraph.outer_px() == EnemyTelegraph.EDGE_OUTER_PX
		and EnemyTelegraph.inner_px() == EnemyTelegraph.EDGE_INNER_PX and is_equal_approx(EnemyTelegraph.fill_color().a, 0.28))
	GameSettings.set_value("accessibility", "strong_telegraphs", true)
	_check("lu en cache (pas de relecture immédiate)", not EnemyTelegraph.strong())
	EnemyTelegraph.refresh_strong()
	_check("réglage lu : renforcé", EnemyTelegraph.strong())
	_check("renforcé : liseré plus épais", EnemyTelegraph.outer_px() > EnemyTelegraph.EDGE_OUTER_PX
		and EnemyTelegraph.inner_px() > EnemyTelegraph.EDGE_INNER_PX
		and EnemyTelegraph.outer_px() >= EnemyTelegraph.inner_px() + 4.0)
	_check("renforcé : remplissage plus opaque", EnemyTelegraph.fill_color().a > EnemyTelegraph.FILL.a
		and EnemyTelegraph.progress_color().a > EnemyTelegraph.PROGRESS.a)
	_check("même famille de couleur (rouge)", is_equal_approx(EnemyTelegraph.STRONG_FILL.r, EnemyTelegraph.FILL.r)
		and is_equal_approx(EnemyTelegraph.STRONG_FILL.g, EnemyTelegraph.FILL.g))
	var cg := EnemyTelegraph.contrast(EnemyTelegraph.GAUGE_COLOR, EnemyTelegraph.EDGE_OUTER)
	_check("minuterie / liseré sombre >= 3:1", cg >= 3.0, "%.2f" % cg)
	_check("minuterie plus épaisse que le liseré", EnemyTelegraph.GAUGE_INNER_PX > EnemyTelegraph.STRONG_INNER_PX)
	var t := EnemyTelegraph.new()
	add_child(t)
	await get_tree().process_frame
	_check("groupe enemy_telegraphs", t.is_in_group(&"enemy_telegraphs"))
	for kind in 3:
		match kind:
			0: t.show_circle(Vector2(300, 300), 120.0)
			1: t.show_cone(Vector2(300, 300), 0.3, 160.0, 0.5)
			2: t.show_line(Vector2(300, 300), 0.0, 300.0, 60.0)
		_check("forme %d : mode figé à l'affichage" % kind, t.is_strong())
		t.set_progress(0.0)
		_check("forme %d : minuterie visible dès 0" % kind, t._ring.visible and t._ring._gauge)
		t.set_progress(0.6)
		_check("forme %d : minuterie à 0,6" % kind, is_equal_approx(t._ring._k, floorf(0.6 * EnemyTelegraph.RING_STEPS) / EnemyTelegraph.RING_STEPS))
		await get_tree().process_frame
	t.hide_telegraph()
	_check("caché : is_showing faux", not t.is_showing())
	EnemyTelegraph.strong_override = 0
	t.show_circle(Vector2(300, 300), 120.0)
	t.set_progress(0.0)
	_check("normal : anneau caché à 0, sans minuterie", not t._ring.visible and not t._ring._gauge)
	t.queue_free()
	EnemyTelegraph.strong_override = -1


func _mono() -> void:
	print("Audio mono")
	Audio.apply_mono(true)
	var m := AudioServer.get_bus_index("Master")
	var idx := Audio.mono_effect_index()
	_check("effet mono sur Master", idx >= 0)
	if idx >= 0:
		var fx := AudioServer.get_bus_effect(m, idx) as AudioEffectStereoEnhance
		_check("pan_pullout 0 (canal latéral annulé)", fx != null and is_zero_approx(fx.pan_pullout))
		_check("effet actif", AudioServer.is_bus_effect_enabled(m, idx))
	var n := AudioServer.get_bus_effect_count(m)
	Audio.apply_mono(false)
	_check("désactivé sans retrait", AudioServer.get_bus_effect_count(m) == n
		and not AudioServer.is_bus_effect_enabled(m, Audio.mono_effect_index()))
	Audio.apply_mono(true)
	_check("pas de doublon", AudioServer.get_bus_effect_count(m) == n)
	Audio.apply_mono(false)


func _mono_poll() -> void:
	GameSettings.set_value("accessibility", "mono_audio", true)
	Audio._mono_poll = Audio.MONO_POLL_S
	await get_tree().process_frame
	await get_tree().process_frame
	_check("réglage mono_audio appliqué par la relecture", Audio.mono
		and AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index("Master"), Audio.mono_effect_index()))
	GameSettings.set_value("accessibility", "mono_audio", false)
	Audio._mono_poll = Audio.MONO_POLL_S
	await get_tree().process_frame
	await get_tree().process_frame
	_check("mono coupé par la relecture", not Audio.mono)


func _reticle() -> void:
	print("Réticule")
	var r := AimReticle.new()
	add_child(r)
	r.show_at(Vector2(100, 100), 1.0)
	_check("taille 100 % par défaut", is_equal_approx(r._scale, 1.0))
	GameSettings.set_value("accessibility", "reticle_scale", 1.5)
	r._size_ms = -1000000
	r.show_at(Vector2(100, 100), 1.0)
	_check("taille 150 %", is_equal_approx(r._scale, 1.5))
	GameSettings.set_value("accessibility", "reticle_scale", 9.0)
	r._size_ms = -1000000
	r.show_at(Vector2(100, 100), 2.0)
	_check("bornée à 150 %", is_equal_approx(r._scale, 3.0))
	r.queue_free()


func _deadzone() -> void:
	print("Zone morte des sticks / joystick tactile")
	InputSetup.apply_stick_deadzone()
	_check("défaut 0,20 sur move/aim", is_equal_approx(InputMap.action_get_deadzone(&"move_left"), 0.2)
		and is_equal_approx(InputMap.action_get_deadzone(&"aim_up"), 0.2))
	GameSettings.set_value("accessibility", "stick_deadzone", 0.3)
	InputSetup._dz_poll = InputSetup.DEADZONE_POLL_S
	InputSetup._process(0.0)
	_check("0,30 appliquée par la relecture", is_equal_approx(InputMap.action_get_deadzone(&"move_down"), 0.3)
		and is_equal_approx(InputMap.action_get_deadzone(&"aim_right"), 0.3))
	GameSettings.set_value("accessibility", "joystick_scale", 1.5)
	var j := FloatingJoystick.new()
	add_child(j)
	_check("joystick : zone morte et taille lues", is_equal_approx(j.deadzone, 0.3) and is_equal_approx(j.radius(), FloatingJoystick.MAX_RADIUS * 1.5))
	j.queue_free()


func _cues() -> void:
	print("Flèches hors écran")
	var screen := Rect2(0, 0, 1920, 1080)
	var p: Vector2 = CUES.place(screen, Vector2(5000, 540), 48.0, [])
	_check("cible à droite : flèche au bord droit", p.x > 1920 - 48 - CUES.MARGIN_PX - 1 and absf(p.y - 540) < 1.0, str(p))
	var blocked := Rect2(1800, 440, 120, 200)
	var p2: Vector2 = CUES.place(screen, Vector2(5000, 540), 48.0, [blocked])
	_check("évite la zone réservée", not blocked.intersects(Rect2(p2 - Vector2(24, 24), Vector2(48, 48))), str(p2))
	_check("reste au bord", p2.x > 1800, str(p2))
	var corner := Rect2(1500, 0, 420, 1080) # toute la bande droite réservée : rentrée vers le centre
	var p3: Vector2 = CUES.place(screen, Vector2(5000, 540), 48.0, [corner])
	_check("bande réservée : rentrée hors zone", not corner.intersects(Rect2(p3 - Vector2(24, 24), Vector2(48, 48))), str(p3))

	var world := Node2D.new()
	add_child(world)
	var teles: Array[EnemyTelegraph] = []
	for i in 8:
		var t := EnemyTelegraph.new()
		t.in_world = true
		world.add_child(t)
		teles.append(t)
	var inside := EnemyTelegraph.new()
	inside.in_world = true
	world.add_child(inside)
	await get_tree().process_frame
	for i in 8:
		teles[i].show_circle(Vector2(3000 + i * 200, -400 + i * 300), 100.0)
	inside.show_circle(Vector2(900, 500), 100.0)
	var vp := get_viewport().get_visible_rect()
	var targets: Array[Dictionary] = CUES.collect_targets(get_tree(), vp)
	_check("8 télégraphes hors écran détectés (pas celui à l'écran)", targets.size() == 8, str(targets.size()))
	var hud := FakeHud.new()
	hud.rects = [Rect2(vp.size.x - 400, 0, 400, 300)] as Array[Rect2]
	add_child(hud)
	var cues: Control = CUES.new()
	cues.call(&"bind", hud)
	cues.set(&"scale_override", 1.0)
	add_child(cues)
	cues.call(&"refresh")
	var list: Array = cues.get(&"cues")
	_check("au plus 6 flèches", list.size() == CUES.MAX_CUES, str(list.size()))
	var ok_rect := true
	var ok_overlap := true
	var boxes: Array[Rect2] = []
	for c: Dictionary in list:
		var b := Rect2(c["pos"] - Vector2(24, 24), Vector2(48, 48))
		if hud.rects[0].intersects(b):
			ok_rect = false
		for o in boxes:
			if o.intersects(b):
				ok_overlap = false
		boxes.append(b)
		if not vp.encloses(b):
			ok_rect = false
	_check("flèches dans l'écran, hors zones réservées", ok_rect)
	_check("flèches sans chevauchement", ok_overlap)
	for t in teles:
		t.hide_telegraph()
	cues.call(&"refresh")
	_check("télégraphes cachés : plus de flèche", (cues.get(&"cues") as Array).is_empty())
	cues.queue_free()
	hud.queue_free()
	world.queue_free()
