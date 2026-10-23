extends Node
## godot --headless --path game res://tests/input_remap_test.tscn
## Lots A11y-L5 / L6 : remappage (surcharges [input] dans un settings.cfg injecté), échange en cas de conflit,
## remise par défaut, clic molette seul (E-02), libellés de la rangée des chiffres (E-10), aide générée à partir
## des liaisons, écran Commandes interactif, familles de manette et gâchettes (E-09), débranchement -> pause (E-11).

const InputLabels := preload("res://scripts/ui/input_labels.gd")
const CFG := "user://test_input_remap.cfg"

var _fails := 0


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_fails += 1
		printerr("FAIL: ", msg)


func _ready() -> void:
	_run.call_deferred()


func _key(code: Key, pressed := true) -> InputEventKey:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.pressed = pressed
	return k


func _jb(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = true
	return e


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	GameSettings.cfg_path = CFG # jamais le vrai user://settings.cfg
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	InputSetup.load_overrides()
	Platform.set_input_mode(Platform.InputMode.KBM)

	# --- défauts
	_check(InputMap.event_is_action(_key(KEY_1), "spell_2"), "1 -> sort 2")
	var mid := InputEventMouseButton.new()
	mid.button_index = MOUSE_BUTTON_MIDDLE
	mid.pressed = true
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	_check(InputMap.event_is_action(mid, "spell_4") and not InputMap.event_is_action(wheel, "spell_4"), "E-02 : clic molette seul")
	for a in [&"chest_pick_1", &"chest_pick_2", &"chest_reroll_ad", &"chest_reroll_gold", &"chest_items"]:
		_check(InputMap.has_action(a) and InputSetup.is_remappable(a), "action de coffre remappable : %s" % a)
	_check(InputMap.event_is_action(_key(KEY_1), "chest_pick_1"), "1 -> coffre objet 1 (groupe distinct du sort 2)")
	_check(not InputSetup.is_bindable(_key(KEY_ESCAPE), "kbm") and not InputSetup.is_bindable(_jb(JOY_BUTTON_START), "pad"), "Échap / Start réservés")

	# --- E-10 : chiffres et aide générée
	_check(Platform.action_label(&"spell_2") == "1", "chiffre affiché tel quel : %s" % Platform.action_label(&"spell_2"))
	_check(InputLabels.key_label(_key(KEY_SHIFT)) == "Shift" and InputLabels.key_label(_key(KEY_SPACE)) == "Espace", "noms français des touches")
	var help: Array = Platform.controls_help()
	_check(str(help[0][1]).ends_with("/ flèches"), "déplacement généré : %s" % help[0][1])
	_check(str(help[3][1]).contains("Clic G / 1"), "sorts générés : %s" % help[3][1])
	_check(str(help[4][1]).begins_with("Shift gauche / Espace"), "roulade générée : %s" % help[4][1])

	# --- remappage + sauvegarde
	var other := InputSetup.rebind(&"interact", "kbm", 0, _key(KEY_F))
	_check(other == &"", "F libre")
	_check(InputMap.event_is_action(_key(KEY_F), "interact") and not InputMap.event_is_action(_key(KEY_E), "interact"), "interagir = F")
	_check(Platform.interact_prompt("Partir") == "[F] Partir", "invite suit le remappage : " + Platform.interact_prompt("Partir"))
	var saved: Variant = GameSettings.get_value("input", "interact.kbm", "")
	_check(saved is Array and (saved as Array) == ["k:%d" % KEY_F], "surcharge enregistrée : %s" % str(saved))
	# conflit : 1 sur interagir -> échange avec le sort 2
	other = InputSetup.rebind(&"interact", "kbm", 0, _key(KEY_1))
	_check(other == &"spell_2", "conflit -> échange avec le sort 2 (%s)" % other)
	_check(InputMap.event_is_action(_key(KEY_F), "spell_2") and InputMap.event_is_action(_key(KEY_1), "interact"), "le sort 2 récupère F")
	_check(not InputMap.event_is_action(_key(KEY_1), "spell_2"), "1 n'est plus au sort 2")
	_check(InputMap.event_is_action(_key(KEY_1), "chest_pick_1"), "groupe coffre non touché")
	InputSetup.reset()
	_check(GameSettings.get_value("input", "interact.kbm", "") is String, "reset -> surcharges effacées")
	_check(InputSetup.is_default(&"spell_2") and InputMap.event_is_action(_key(KEY_E), "interact"), "reset -> défauts")
	# relecture depuis le fichier
	GameSettings.set_value("input", "dodge.pad", ["jb:%d" % JOY_BUTTON_B])
	InputSetup.load_overrides()
	_check(InputMap.event_is_action(_jb(JOY_BUTTON_B), "dodge") and not InputMap.event_is_action(_jb(JOY_BUTTON_LEFT_SHOULDER), "dodge"), "surcharge relue au chargement")
	InputSetup.reset(&"dodge")
	_check(InputMap.event_is_action(_jb(JOY_BUTTON_LEFT_SHOULDER), "dodge"), "reset d'une ligne")
	# gâchette assignable au pad
	var lt := InputEventJoypadMotion.new()
	lt.axis = JOY_AXIS_TRIGGER_LEFT
	lt.axis_value = 0.9
	other = InputSetup.rebind(&"dodge", "pad", 0, lt)
	_check(other == &"spell_3", "LT pris au sort 3 -> échange (%s)" % other)
	_check(InputMap.event_is_action(_jb(JOY_BUTTON_LEFT_SHOULDER), "spell_3"), "le sort 3 récupère LB")
	InputSetup.reset()

	# --- E-09 : familles de manette, icônes positionnelles, LT/RT
	_check(InputLabels.family_of_name("Xbox Series Controller") == "xbox", "famille xbox")
	_check(InputLabels.family_of_name("PS5 Controller") == "ps" and InputLabels.family_of_name("Sony DualSense") == "ps", "famille ps")
	_check(InputLabels.family_of_name("Nintendo Switch Pro Controller") == "nintendo", "famille nintendo")
	_check(InputLabels.family_of_name("8BitDo Generic") == "generic" and InputLabels.family_of_name("") == "xbox", "générique / aucune")
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	_check(Platform.interact_prompt("Partir") == "[A] Partir", "xbox par défaut : " + Platform.interact_prompt("Partir"))
	InputSetup.pad_family_override = "ps"
	_check(Platform.action_label(&"interact") == "Croix", "ps : Croix")
	var parts := Platform.action_prompt_parts(&"interact")
	_check(parts.size() == 1 and parts[0]["icon"] == "pad_btn_bottom" and parts[0]["caption"] == "", "ps : icône positionnelle sans légende")
	InputSetup.pad_family_override = "nintendo"
	_check(Platform.action_label(&"interact") == "B" and Platform.action_label(&"spell_3") == "A", "nintendo : bas = B, droite = A")
	InputSetup.pad_family_override = ""
	parts = Platform.action_prompt_parts(&"interact")
	_check(parts[0]["icon"] == "pad_a" and parts[0]["caption"] == "A", "xbox : pad_a + A")
	InputSetup.rebind(&"spell_2", "pad", 0, InputSetup.deserialize_event("ja:%d:+" % JOY_AXIS_TRIGGER_RIGHT))
	parts = Platform.action_prompt_parts(&"spell_2")
	_check(parts.size() == 1 and parts[0]["icon"] == "pad_rt" and parts[0]["text"] == "RT", "gâchette RT dans les invites (%s)" % str(parts))
	var kp := KeyPrompt.new()
	add_child(kp)
	kp.set_action(&"spell_2")
	_check(kp.get_child_count() >= 1 and kp.get_child(0) is TextureRect, "KeyPrompt : icône de gâchette")
	kp.queue_free()
	InputSetup.reset()

	# --- écran Commandes interactif
	Platform.set_input_mode(Platform.InputMode.KBM)
	var cp := ControlsPanel.new()
	add_child(cp)
	await _frames(2)
	_check(cp.texts().has("Déplacement") and cp.texts().has("Coffre : objet 1"), "onglet Clavier : lignes remappables")
	_check(cp.slot_text(&"spell_4", 0) == "Molette" and cp.slot_text(&"spell_4", 1) == "3", "emplacements du sort 4 : %s / %s" % [cp.slot_text(&"spell_4", 0), cp.slot_text(&"spell_4", 1)])
	cp.slot_button(&"dodge", 1).pressed.emit()
	_check(cp.is_listening() and cp.slot_text(&"dodge", 1).begins_with("…"), "écoute après appui")
	cp.handle_listen_event(_key(KEY_ESCAPE))
	_check(not cp.is_listening() and InputSetup.is_default(&"dodge"), "Échap annule l'écoute")
	cp.start_listen(&"dodge", "kbm", 1)
	cp.handle_listen_event(_key(KEY_C))
	_check(not cp.is_listening() and InputMap.event_is_action(_key(KEY_C), "dodge"), "C assigné à la roulade")
	_check(cp.slot_text(&"dodge", 1) == "C", "emplacement mis à jour : %s" % cp.slot_text(&"dodge", 1))
	_check(not (cp._reset_buttons[&"dodge"] as Button).disabled, "bouton Défaut actif après changement")
	cp.start_listen(&"dodge", "kbm", 1)
	cp._listen["t"] = 0.01
	await _frames(3)
	_check(not cp.is_listening(), "écoute expirée")
	(cp._reset_buttons[&"dodge"] as Button).pressed.emit()
	_check(InputSetup.is_default(&"dodge") and cp.slot_text(&"dodge", 1) == "Espace", "Défaut par ligne (%s)" % cp.slot_text(&"dodge", 1))
	cp.show_mode(Platform.InputMode.GAMEPAD)
	_check(cp.texts().has("Stick gauche / croix") and cp.slot_text(&"interact", 0) == "A", "onglet Manette")
	cp.start_listen(&"interact", "pad", 1)
	cp.handle_listen_event(_key(KEY_Q)) # clavier ignoré
	_check(cp.is_listening(), "touche ignorée en écoute manette")
	cp.handle_listen_event(_jb(JOY_BUTTON_RIGHT_STICK))
	_check(InputMap.event_is_action(_jb(JOY_BUTTON_RIGHT_STICK), "interact") and cp.slot_text(&"interact", 1) == "R3", "R3 en secondaire")
	cp._reset_all.pressed.emit()
	_check(InputSetup.is_default(&"interact", "pad"), "Tout par défaut")
	cp.queue_free()

	# --- E-11 : débranchement -> pause
	var pm := PauseMenu.new()
	add_child(pm)
	await _frames(2)
	Platform.set_input_mode(Platform.InputMode.KBM)
	InputSetup.pad_disconnected.emit(0)
	_check(not pm.is_open, "pas de pause si l'on joue au clavier")
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	InputSetup.pad_disconnected.emit(0)
	_check(pm.is_open and get_tree().paused and pm._info.text.begins_with("Manette déconnectée"), "pause + message")
	pm._close()
	pm.queue_free()
	Platform.set_input_mode(Platform.InputMode.KBM)

	InputSetup.reset()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = GameSettings.PATH
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
