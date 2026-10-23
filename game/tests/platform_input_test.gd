extends Node
## godot --headless --path game res://tests/platform_input_test.tscn
## Bascule du mode d'entrée (toucher / clavier+souris / manette), signal, liaisons d'actions.

var _fails := 0
var _changes: Array = []


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	Platform.input_mode_changed.connect(func(m: int) -> void: _changes.append(m))
	_check(Platform.is_pc() and not Platform.is_mobile(), "headless Windows = PC")
	_check(not Platform.is_ios(), "pas iOS")
	_check(not Platform.ads_available(), "pas de pubs sur PC")
	_check(Platform.can_quit(), "Quitter autorisé hors iOS")
	_check(Platform.input_mode == Platform.InputMode.KBM, "mode initial PC = kbm")
	_check(InputSetup.pointer_bound(), "liaisons souris actives en kbm")

	# toucher
	var t := InputEventScreenTouch.new()
	t.pressed = true
	Platform._input(t)
	_check(Platform.input_mode == Platform.InputMode.TOUCH, "toucher -> touch")
	_check(_changes == [Platform.InputMode.TOUCH], "signal émis une fois: %s" % str(_changes))
	_check(not InputSetup.pointer_bound(), "liaisons souris retirées en tactile")
	Platform._input(t)
	_check(_changes.size() == 1, "pas de signal si le mode ne change pas")

	# souris émulée par un toucher : ignorée
	var em := InputEventMouseButton.new()
	em.pressed = true
	em.device = InputEvent.DEVICE_ID_EMULATION
	Platform._input(em)
	_check(Platform.input_mode == Platform.InputMode.TOUCH, "souris émulée ignorée")

	# clavier
	var k := InputEventKey.new()
	k.physical_keycode = KEY_W
	k.pressed = true
	Platform._input(k)
	_check(Platform.input_mode == Platform.InputMode.KBM, "touche -> kbm")
	_check(InputSetup.pointer_bound(), "liaisons souris réactivées")

	# manette : stick au repos ignoré, stick poussé / bouton = gamepad
	var jm := InputEventJoypadMotion.new()
	jm.axis = JOY_AXIS_LEFT_X
	jm.axis_value = 0.1
	Platform._input(jm)
	_check(Platform.input_mode == Platform.InputMode.KBM, "stick au repos ignoré")
	jm.axis_value = 0.9
	Platform._input(jm)
	_check(Platform.input_mode == Platform.InputMode.GAMEPAD, "stick -> gamepad")
	Platform._input(k)
	_check(Platform.input_mode == Platform.InputMode.KBM, "retour clavier")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	Platform._input(jb)
	_check(Platform.input_mode == Platform.InputMode.GAMEPAD, "bouton -> gamepad")

	# souris : micro-mouvement ignoré, vrai mouvement = kbm
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(1, 0)
	Platform._input(mm)
	_check(Platform.input_mode == Platform.InputMode.GAMEPAD, "micro-mouvement de souris ignoré")
	mm.relative = Vector2(20, 0)
	Platform._input(mm)
	_check(Platform.input_mode == Platform.InputMode.KBM, "mouvement souris -> kbm")

	# chemin réel : événement poussé dans le viewport
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	var tt := InputEventScreenTouch.new()
	tt.pressed = true
	get_viewport().push_input(tt)
	_check(Platform.input_mode == Platform.InputMode.TOUCH, "push_input toucher -> touch")

	# invites
	Platform.set_input_mode(Platform.InputMode.KBM)
	var pk := Platform.interact_prompt("Partir")
	_check(pk.begins_with("[") and pk.ends_with("] Partir"), "invite clavier: " + pk)
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	_check(Platform.interact_prompt("Partir") == "[A] Partir", "invite manette: " + Platform.interact_prompt("Partir"))
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	_check(Platform.interact_prompt("Partir") == "Partir", "invite tactile = libellé seul")

	# AZERTY : touches uniquement physiques ; Z/Q/S/D d'un AZERTY = W/A/S/D physiques
	for a in ["move_left", "move_right", "move_up", "move_down", "spell_2", "spell_3", "spell_4", "interact", "dodge", "pause"]:
		for ev in InputMap.action_get_events(a):
			if ev is InputEventKey:
				_check((ev as InputEventKey).keycode == KEY_NONE and (ev as InputEventKey).physical_keycode != KEY_NONE, "%s: touche physique" % a)
	var wev := InputEventKey.new()
	wev.physical_keycode = KEY_W # touche « Z » d'un clavier AZERTY
	_check(InputMap.event_is_action(wev, "move_up"), "touche physique W/Z -> haut")
	var aev := InputEventKey.new()
	aev.physical_keycode = KEY_A # touche « Q » d'un clavier AZERTY
	_check(InputMap.event_is_action(aev, "move_left"), "touche physique A/Q -> gauche")
	var lstick := InputEventJoypadMotion.new()
	lstick.axis = JOY_AXIS_LEFT_X
	lstick.axis_value = -1.0
	_check(InputMap.event_is_action(lstick, "move_left"), "stick gauche -> move_left")
	var rstick := InputEventJoypadMotion.new()
	rstick.axis = JOY_AXIS_RIGHT_Y
	rstick.axis_value = 1.0
	_check(InputMap.event_is_action(rstick, "aim_down"), "stick droit -> aim_down")
	var rt := InputEventJoypadMotion.new()
	rt.axis = JOY_AXIS_TRIGGER_RIGHT
	rt.axis_value = 1.0
	_check(InputMap.event_is_action(rt, "spell_2"), "gâchette droite -> sort 2")
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 1.0
	_check(InputMap.event_is_action(lt, "spell_3"), "gâchette gauche -> sort 3")
	Platform.set_input_mode(Platform.InputMode.KBM)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	lmb.pressed = true
	_check(InputMap.event_is_action(lmb, "spell_2"), "clic gauche -> sort 2")
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	rmb.pressed = true
	_check(InputMap.event_is_action(rmb, "spell_3"), "clic droit -> sort 3")
	var mid := InputEventMouseButton.new()
	mid.button_index = MOUSE_BUTTON_MIDDLE
	mid.pressed = true
	_check(InputMap.event_is_action(mid, "spell_4"), "clic molette -> sort 4")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	_check(not InputMap.event_is_action(wheel, "spell_4"), "rotation de la molette non liée par défaut (E-02)")

	# stubs pubs / achats
	var got := [null]
	Platform.show_rewarded_ad(func(ok: bool) -> void: got[0] = ok)
	_check(got[0] == false, "pub récompensée sans backend = échec")

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
