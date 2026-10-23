extends Node
## Haptique (lot L7) : plafond de fréquence, respect du réglage, rien en clavier-souris, table d'intensités.
## godot --headless --path game res://tests/haptics_test.tscn  -> RESULT: OK
## Sinks et horloge injectés (Input.vibrate_handheld / start_joy_vibration jamais appelés) ; config injectée.

const PATH := "user://test_haptics_test.cfg"
var _fails := 0
var _hand: Array = []
var _joy: Array = []


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  ok  ", msg)
	else:
		_fails += 1
		print("  ÉCHEC  ", msg)


func _on_hand(ms: int, amp: float) -> void:
	_hand.append([ms, amp])


func _on_joy(dev: int, w: float, s: float, d: float) -> void:
	_joy.append([dev, w, s, d])


func _setup(mode: int, mobile: bool) -> void:
	Haptics.reset()
	Haptics.mode_override = mode
	Haptics.mobile_override = 1 if mobile else 0
	Haptics.now_ms_override = 10000
	Haptics.handheld_sink = _on_hand
	Haptics.joy_sink = _on_joy
	_hand.clear()
	_joy.clear()


func _ready() -> void:
	GameSettings.cfg_path = PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	GameSettings.set_value("gameplay", "haptics", true)
	var TOUCH := 0
	var KBM := 1
	var PAD := 2

	# clavier-souris : rien
	_setup(KBM, false)
	_check(not Haptics.pulse(Haptics.Kind.DEATH) and _hand.is_empty() and _joy.is_empty(), "clavier-souris : aucune vibration")
	_setup(KBM, true)
	_check(not Haptics.pulse(Haptics.Kind.HURT) and _hand.is_empty() and _joy.is_empty(), "clavier-souris même mobile : rien")
	# tactile sur PC (écran tactile) : pas de moteur
	_setup(TOUCH, false)
	_check(not Haptics.pulse(Haptics.Kind.HURT) and _hand.is_empty(), "tactile sur PC : rien")

	# téléphone
	_setup(TOUCH, true)
	_check(Haptics.pulse(Haptics.Kind.HURT) and _hand.size() == 1 and _hand[0][0] == 30 and is_equal_approx(_hand[0][1], 0.5), "téléphone : dégât 30 ms / 0,5")
	_check(_joy.is_empty(), "téléphone : pas de vibration manette")
	# manette
	_setup(PAD, false)
	_check(Haptics.pulse(Haptics.Kind.HURT_BIG) and _joy.size() == 1 and is_equal_approx(_joy[0][2], 0.7) and _hand.is_empty(), "manette : gros dégât fort 0,7")
	_setup(PAD, false)
	Haptics.hurt(10.0, 100.0)
	Haptics.now_ms_override += 200
	Haptics.hurt(15.0, 100.0)
	_check(_joy.size() == 2 and is_equal_approx(_joy[0][1], 0.3) and is_equal_approx(_joy[1][1], 0.5), "hurt() : seuil 15 % des PV")

	# plafond : 80 ms
	_setup(PAD, false)
	var ok := 0
	for i in 5:
		Haptics.now_ms_override = 10000 + i * 20
		if Haptics.pulse(Haptics.Kind.HURT):
			ok += 1
	_check(ok == 2, "plafond 80 ms : 2 impulsions sur 5 appels en 80 ms (%d)" % ok)
	# plafond glissant par seconde
	_setup(PAD, false)
	ok = 0
	for i in 40:
		Haptics.now_ms_override = 10000 + i * 85 # 85 ms d'écart : seul le plafond/seconde limite
		if Haptics.pulse(Haptics.Kind.HURT):
			ok += 1
	_check(ok <= Haptics.MAX_PER_S * 4, "horde : <= %d par seconde (%d en 3,4 s)" % [Haptics.MAX_PER_S, ok])
	_setup(PAD, false)
	ok = 0
	for i in 12:
		Haptics.now_ms_override = 10000 + i * 85
		if Haptics.pulse(Haptics.Kind.HURT):
			ok += 1
	_check(ok == Haptics.MAX_PER_S, "1 s de horde : exactement %d (%d)" % [Haptics.MAX_PER_S, ok])
	# la mort passe toujours
	_check(Haptics.pulse(Haptics.Kind.DEATH), "la mort passe malgré le plafond")
	# reprise après la pause
	Haptics.now_ms_override += 2000
	_check(Haptics.pulse(Haptics.Kind.HURT), "reprise après 2 s")

	# double impulsion (niveau)
	_setup(TOUCH, true)
	Haptics.pulse(Haptics.Kind.LEVEL_UP)
	_check(_hand.size() == 2 and _hand[0][0] == 40, "montée de niveau : 2 impulsions de 40 ms")

	# coffre légendaire via Events (seule la qualité légendaire vibre)
	_setup(TOUCH, true)
	Haptics._on_chest_opened(null, &"rare", [])
	_check(_hand.is_empty(), "coffre rare : rien")
	Haptics._on_chest_opened(null, &"legendaire", [])
	_check(_hand.size() == 2, "coffre légendaire : double impulsion")
	Haptics.connect_events()
	Haptics.connect_events() # idempotent
	_check(Events.chest_opened.is_connected(Haptics._on_chest_opened), "connect_events branche chest_opened")

	# réglage coupé
	GameSettings.set_value("gameplay", "haptics", false)
	_setup(PAD, true)
	_check(not Haptics.pulse(Haptics.Kind.DEATH) and _joy.is_empty(), "réglage Vibrations coupé : rien (même la mort)")
	GameSettings.set_value("gameplay", "haptics", true)
	# curseur d'intensité
	GameSettings.set_value("gameplay", "haptics_strength", 0.5)
	_setup(TOUCH, true)
	Haptics.pulse(Haptics.Kind.HURT)
	_check(_hand.size() == 1 and is_equal_approx(_hand[0][1], 0.25), "curseur 50 % : amplitude 0,25")
	GameSettings.set_value("gameplay", "haptics_strength", 0.0)
	_setup(TOUCH, true)
	_check(not Haptics.pulse(Haptics.Kind.HURT) and _hand.is_empty(), "curseur 0 % : rien")

	Haptics.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
