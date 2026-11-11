extends Node
## Audit UX E4/E7/E8 : « +1 rubis » sous la note parfaite (EpreuveHud), médaillons de note au récap (EndRunScreen),
## vibration de la note (parfait = 2 impulsions de 80 ms, autre note = 100 ms) et nouveaux Kind d'Haptics.
## godot --headless --path game res://tests/epreuve_end_run_test.tscn  -> RESULT: OK

var _fails := 0


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _medals(s: Node) -> Array[String]:
	var out: Array[String] = []
	var flow := s.find_child("EpreuveMedals", true, false)
	if flow == null:
		return out
	for c in flow.get_children():
		out.append(String(c.get_meta(&"grade", "")))
		if c is TextureRect and ((c as TextureRect).texture == null or int(c.get_meta(&"base_px", 0)) != 48):
			out.append("BAD")
	return out


func _ready() -> void:
	# --- Haptique
	GameSettings.cfg_path = "user://test_epreuve_end_run.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	GameSettings.set_haptics(true)
	var shots: Array = []
	Haptics.reset()
	Haptics.mode_override = 2
	Haptics.now_ms_override = 10000
	Haptics.joy_sink = func(_d: int, _w: float, _s: float, secs: float) -> void: shots.append(secs)
	_check(Haptics.pulse(Haptics.Kind.EPREUVE_NOTE) and shots.size() == 1 and is_equal_approx(shots[0], 0.1), "note : 1 impulsion de 100 ms")
	shots.clear()
	Haptics.now_ms_override = 20000
	_check(Haptics.pulse(Haptics.Kind.EPREUVE_PERFECT) and shots.size() == 2 and is_equal_approx(shots[0], 0.08), "parfait : 2 impulsions de 80 ms")
	shots.clear()
	Haptics.mode_override = 1 # clavier-souris
	Haptics.now_ms_override = 30000
	_check(not Haptics.pulse(Haptics.Kind.FORGE) and shots.is_empty(), "clavier-souris : rien")
	Haptics.mode_override = 2
	GameSettings.set_haptics(false)
	_check(not Haptics.pulse(Haptics.Kind.CORE) and shots.is_empty(), "réglage coupé : rien")
	_check(not Haptics.pulse(Haptics.Kind.PAD_RECONNECT, 3) and shots.is_empty(), "réglage coupé : reconnexion muette aussi")
	GameSettings.set_haptics(true)
	Haptics.mode_override = 1
	Haptics.now_ms_override = 40000
	_check(Haptics.pulse(Haptics.Kind.PAD_RECONNECT, 3) and shots.size() == 1 and is_equal_approx(shots[0], 0.2), "reconnexion : manette précise, 200 ms, même en clavier-souris")
	shots.clear()
	for k in [Haptics.Kind.FORGE, Haptics.Kind.CORE, Haptics.Kind.LOBBY_READY]:
		Haptics.mode_override = 2
		Haptics.now_ms_override += 1000
		_check(Haptics.pulse(k) and shots.size() == 1, "Kind %d vibre à la manette" % k)
		shots.clear()

	# --- HUD : « +1 rubis » et vibration de la note
	Haptics.mode_override = 2
	Haptics.now_ms_override = 90000
	var eh := EpreuveHud.new()
	add_child(eh)
	await _frames(1)
	Events.epreuve_finished.emit(&"tenue", &"bien", 50.0, 1.0)
	_check(eh.grade_text == "Bien" and eh.ruby_text == "", "note Bien : pas de rubis")
	Haptics.now_ms_override += 1000
	shots.clear()
	Events.epreuve_finished.emit(&"tenue", &"parfait", 30.0, 1.5)
	_check(eh.grade_text == "Parfait" and eh.ruby_text == "+1 rubis", "note Parfait : « +1 rubis » sous la note")
	_check(shots.size() == 2, "HUD : parfait = 2 impulsions")
	eh._process(5.0)
	_check(eh.grade_text == "" and eh.ruby_text == "", "libellé et rubis effacés après la durée")
	eh.queue_free()
	Haptics.reset()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	# --- Récap : médaillons
	var s := EndRunScreen.create({"victory": true, "mode": &"moyen", "rubies": 20, "epreuve_rubies": 2,
		"epreuve_grades": [&"parfait", &"parfait", &"bien", &"fait"]})
	add_child(s)
	await _frames(2)
	var m := _medals(s)
	_check(m == ["parfait", "parfait", "bien", "fait"], "médaillons : %s" % str(m))
	s.queue_free()
	var s2 := EndRunScreen.create({"victory": false, "reason": &"death", "mode": &"moyen"})
	add_child(s2)
	await _frames(2)
	_check(s2.find_child("EpreuveMedals", true, false) == null, "sans épreuve : aucune rangée de médaillons")
	s2.queue_free()
	await _frames(1)

	print("RESULT: %s (%d echec(s))" % ["OK" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
