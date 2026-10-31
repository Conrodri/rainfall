extends Node
## Roues de rareté multiples (objets « +1 Chance ») : 1 + luck jets, meilleur gardé, une roue par jet (plafond 3).
## godot --headless --path game res://tests/chest_luck_wheels_test.tscn   (RESULT: OK)

const UI := "res://scenes/ui/chest/chest_ui.tscn"
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameSettings.cfg_path = "user://test_chest_luck_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	Platform.set_input_mode(Platform.InputMode.KBM)
	get_window().size = Vector2i(1920, 1080)
	RunState.start_run(&"moyen", 777)
	ChestSession.reset_run_counters()
	await _frames(2)

	# --- sans Chance : 1 jet, 1 roue
	var s0 := ChestSession.new(&"large", 1, 100.0)
	s0.start()
	_check(s0.rolls.size() == 1 and s0.rolls[0] == s0.die, "sans Chance : 1 jet")
	var ui0: ChestUI = load(UI).instantiate()
	add_child(ui0)
	ui0.open(&"large", 1, 0.0)
	await _frames(2)
	_check(ui0.wheel_count() == 1, "sans Chance : 1 roue")
	await _end(ui0)

	# --- avec 1 exemplaire (+1 Chance) : 2 jets, meilleur gardé, 2 roues
	RunState.add_item(&"faveur_du_marchand")
	var bad := 0
	for i in 40:
		var s := ChestSession.new(&"large", 1, 100.0)
		s.start()
		if s.rolls.size() != 2 or s.die != maxi(int(s.rolls[0]), int(s.rolls[1])) or s.quality != LootRoller.quality_from_die(&"large", s.die):
			bad += 1
	_check(bad == 0, "avec Chance 1 : 2 jets, die = max, rareté = celle du meilleur")
	var ui: ChestUI
	ui = load(UI).instantiate()
	add_child(ui)
	ui.open(&"large", 1, 0.0)
	await _frames(3)
	_check(ui.session.rolls.size() == 2 and ui.wheel_count() == 2, "UI : 2 roues pour 2 jets")
	var t := 0.0
	while ui.is_animating() and t < 4.0:
		await _frames(1)
		t += get_process_delta_time()
	_check(t <= 2.0, "ouverture courte (%.2f s)" % t)
	var main_ok: bool = ui._reel_seq[int(ui._reel_to)] == ui.session.quality
	_check(main_ok, "roue principale posée sur la meilleure rareté")
	var x: Dictionary = ui._xr[0]
	var xq: StringName = x["seq"][int(x["to"])]
	var worst_rank := mini(LootRoller.quality_rank(LootRoller.quality_from_die(&"large", int(ui.session.rolls[0]))), LootRoller.quality_rank(LootRoller.quality_from_die(&"large", int(ui.session.rolls[1]))))
	_check(LootRoller.quality_rank(xq) == worst_rank and x["landed"], "roue secondaire posée sur l'autre jet")
	_check(ui.session.offered.size() == 2, "2 items proposés comme avant")
	await _end(ui)

	# --- skip : tout posé aussitôt
	var ui2: ChestUI = load(UI).instantiate()
	add_child(ui2)
	ui2.open(&"large", 1, 0.0)
	await _frames(2)
	ui2.skip()
	await _frames(1)
	_check(ui2._xr.all(func(w: Dictionary) -> bool: return w["landed"]), "skip : roues secondaires posées")
	await _end(ui2)

	# --- plafond à 3 roues avec 4 exemplaires (5 jets)
	for _i in 3:
		RunState.add_item(&"faveur_du_marchand")
	var s5 := ChestSession.new(&"large", 1, 100.0)
	s5.start()
	_check(s5.rolls.size() == 5, "4 exemplaires : 5 jets")
	var ui3: ChestUI = load(UI).instantiate()
	add_child(ui3)
	ui3.open(&"large", 1, 0.0)
	await _frames(2)
	_check(ui3.wheel_count() == 3, "plafond visuel : 3 roues")
	await _end(ui3)

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _end(ui: Node) -> void:
	if is_instance_valid(ui):
		ui.queue_free()
	get_tree().paused = false
	await _frames(2)
