extends Node
## Coop locale PC, étape 4 : jonction, retrait et deux manettes simulées.
## 1. CoopLobbyScreen (événements simulés) : A / Start rejoint, une manette = un joueur, le clavier-souris passe en
##    tête, B retire, personnage et skin par joueur, « Prêt » de tous -> compte -> config `party` ; manette débranchée
##    = place libérée ; 4 places au plus.
## 2. App.party_setup_from : sources par appareil (clavier-souris, manette N).
## 3. Vrai Main à 2 manettes : plaques du HUD (fiche solo masquée), caméra commune, Start d'une manette quelconque =
##    pause, Select = inventaire de CE joueur (et bascule), manette débranchée = joueur absent (muet, protégé, pause),
##    reprise par une manette libre ; mode test : ajout d'un joueur en cours de run (add_local_player, jonction armée).
## godot --headless --path game res://tests/coop_local_join_test.tscn  -> RESULT: OK


var _fails := 0


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


## Rapport de contraste WCAG entre deux couleurs opaques.
func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _lum(c: Color) -> float:
	var f := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


static func _pad(device: int, button: int, pressed := true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = button
	e.pressed = pressed
	return e


## Appui court (enfoncé puis relâché) : en mode test, Select ouvre l'inventaire au relâchement.
func _tap(device: int, button: int) -> void:
	Input.parse_input_event(_pad(device, button, true))
	await _frames(1)
	Input.parse_input_event(_pad(device, button, false))
	await _frames(2)


static func _keyev(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e


func _run() -> void:
	await _lobby()
	TestMode.begin() # arène plate (StageManager : carte test_arena, ni coffre ni pilier), profil en bac à sable
	await _in_game()
	Players.clear()
	TestMode.end()
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _lobby() -> void:
	print("Écran de jonction")
	var lob := CoopLobbyScreen.new()
	lob.characters = [{"id": "ardent", "name": "Ardent"}, {"id": "averse", "name": "Averse"}]
	add_child(lob)
	await _frames(1)
	var emitted: Array = []
	lob.start_requested.connect(func(c: Dictionary) -> void: emitted.append(c))
	lob.handle_event(_pad(3, JOY_BUTTON_A))
	_check("A rejoint (manette 3 = joueur 1)", lob.slots.size() == 1 and int(lob.slots[0]["device"]) == 3)
	lob.handle_event(_pad(3, JOY_BUTTON_START))
	_check("même manette : pas de 2e joueur (Start = prêt)", lob.slots.size() == 1 and bool(lob.slots[0]["ready"]))
	lob.handle_event(_pad(3, JOY_BUTTON_B))
	_check("B annule le prêt", lob.slots.size() == 1 and not bool(lob.slots[0]["ready"]))
	lob.handle_event(_keyev(KEY_ENTER))
	_check("clavier-souris en tête", lob.slots.size() == 2 and str(lob.slots[0]["kind"]) == "kbm" and int(lob.slots[1]["device"]) == 3)
	lob.handle_event(_pad(5, JOY_BUTTON_START))
	_check("Start rejoint (manette 5 = joueur 3)", lob.slots.size() == 3 and int(lob.slots[2]["device"]) == 5)
	lob.handle_event(_pad(5, JOY_BUTTON_B))
	_check("B retire un joueur non prêt", lob.slots.size() == 2 and lob.slot_of_key(CoopLobbyScreen.pad_key(5)) < 0)
	lob.slots[0]["char"] = 0 # indépendant du dernier personnage joué au profil
	lob.slots[1]["char"] = 0
	lob.handle_event(_pad(3, JOY_BUTTON_DPAD_RIGHT))
	_check("personnage par joueur (manette 3 -> Averse)", lob.character_id(1) == &"averse" and lob.character_id(0) == &"ardent")
	var stick := InputEventJoypadMotion.new()
	stick.device = 3
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = -0.9
	lob.handle_event(stick)
	lob.handle_event(stick) # maintenu : un seul cran
	_check("stick gauche : un cran", lob.character_id(1) == &"ardent")
	_check("doublon : skin distinct si possible, sinon le même", str(lob.slots[1]["skin"]) != "")
	lob.handle_event(_pad(9, JOY_BUTTON_A))
	lob.handle_event(_pad(10, JOY_BUTTON_A))
	lob.handle_event(_pad(11, JOY_BUTTON_A))
	_check("4 places au plus", lob.slots.size() == 4 and lob.slot_of_key(CoopLobbyScreen.pad_key(11)) < 0)
	lob._on_joy_connection_changed(10, false)
	_check("manette débranchée : place libérée", lob.slots.size() == 3 and lob.slot_of_key(CoopLobbyScreen.pad_key(10)) < 0)
	lob.handle_event(_pad(9, JOY_BUTTON_B))
	_check("retrait par B", lob.slots.size() == 2)
	lob.mode = &"moyen"
	lob.handle_event(_keyev(KEY_TAB))
	_check("Tab : mode suivant", lob.mode != &"moyen")
	lob.mode = &"moyen"
	lob.handle_event(_keyev(KEY_ENTER))
	_check("pas encore tous prêts : pas de compte", lob.countdown < 0.0)
	lob.handle_event(_pad(3, JOY_BUTTON_A))
	_check("tous prêts : compte lancé", lob.countdown > 0.0)
	lob.handle_event(_pad(3, JOY_BUTTON_B))
	_check("un prêt annulé : compte annulé", lob.countdown < 0.0)
	lob.handle_event(_pad(3, JOY_BUTTON_A))
	lob._process(CoopLobbyScreen.LAUNCH_S + 0.1)
	_check("lancement : config émise", emitted.size() == 1 and lob.launched)
	var cfg: Dictionary = emitted[0] if not emitted.is_empty() else {}
	var party: Array = cfg.get("party", [])
	_check("config : 2 joueurs, clavier puis manette 3", party.size() == 2 and str(party[0]["kind"]) == "kbm" and str(party[1]["kind"]) == "pad" and int(party[1]["device"]) == 3)
	_check("config : mode et personnage du joueur 1", cfg.get("mode") == &"moyen" and cfg.get("character") == &"ardent")
	var setup := App.party_setup_from(party)
	_check("party_setup_from : sources par appareil", setup.size() == 2 and setup[0]["input"] is InputSourceKbm and setup[1]["input"] is InputSourcePad and (setup[1]["input"] as InputSource).device == 3)
	_check("lobby : largeur de carte clamp((W-192)/4, 280, 420)", is_equal_approx(CoopLobbyScreen.card_width(1920.0), 420.0) and is_equal_approx(CoopLobbyScreen.card_width(1440.0), 312.0) and is_equal_approx(CoopLobbyScreen.card_width(800.0), 280.0))
	_check("lobby : 2 x 2 seulement quand 4 cartes de 280 px ne tiennent pas", not CoopLobbyScreen.uses_two_by_two(1920.0) and not CoopLobbyScreen.uses_two_by_two(1440.0) and CoopLobbyScreen.uses_two_by_two(1200.0))
	_check("lobby : 4 colonnes en 16:9", lob.grid_columns() == 4)
	var chk := (lob._card_labels[0]["check"] as TextureRect)
	_check("lobby : état prêt = coche + cadre épais ; non prêt = ni l'un ni l'autre", chk.visible == bool(lob.slots[0]["ready"]) and lob._card_styles[0].border_width_left == (6 if bool(lob.slots[0]["ready"]) else 3))
	var back := [0]
	var lob2 := CoopLobbyScreen.new()
	lob2.characters = lob.characters
	add_child(lob2)
	lob2.back_requested.connect(func() -> void: back[0] += 1)
	lob2.handle_event(_keyev(KEY_ESCAPE))
	_check("Échap sans joueur : retour", back[0] == 1)
	lob.queue_free()
	lob2.queue_free()
	await _frames(2)


func _in_game() -> void:
	print("Partie à deux manettes")
	var pads: Array[InputSource] = [InputSource.pad_source(7), InputSource.pad_source(8)]
	var setup: Array[Dictionary] = [{"input": pads[0], "character": &"ardent", "loadout": {}, "skin": ""},
		{"input": pads[1], "character": &"averse", "loadout": {}, "skin": "default"}]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"save_path", "user://test_coop_join.json")
	main.set(&"run_seed", 99)
	main.set(&"party_setup", setup)
	add_child(main)
	await main.game_ready
	var d: Node = main.get(&"director")
	d.set(&"spawning_enabled", false)
	d.set(&"waves_enabled", false)
	await _frames(3)
	var hud: Node = main.get(&"hud")
	var plates := hud.get(&"coop_plates") as CoopPlates
	_check("coop locale détectée", bool(main.call(&"is_local_coop")) and Hud.is_local_coop())
	_check("caméra commune", main.get(&"camera") is SharedCamera)
	_check("plaques visibles, fiche solo masquée", plates.visible and bool(hud.call(&"coop_hud_active")) and not (hud.get(&"_player_plate") as Control).visible)
	plates.queue_redraw()
	await _frames(2)
	_check("une plaque par joueur", plates.plates.size() == 2, str(plates.plates.size()))
	var r := CoopPlates.layout(4, Vector2(1920, 1080), 1.0)
	_check("4 plaques : coins bas, centre libre, sans chevauchement", r.size() == 4 and r[0].position.x < 100.0 and r[3].end.x > 1820.0 and r[1].end.x < r[2].position.x - 200.0 and r[0].end.y <= 1080.0)
	var rn := CoopPlates.layout(4, Vector2(1440, 1080), 1.0)
	_check("écran étroit : 2 x 2 dans les coins", rn[0].position.x == rn[1].position.x and rn[0].end.y <= rn[1].position.y)
	var main_player: Node2D = main.get(&"player")
	_check("joueur 2 : skin de base imposé", str((main.get(&"players") as Array)[1].get(&"skin_id")) == "default" and str(main_player.get(&"skin_id")) == "")

	var pm := hud.get(&"pause_menu") as PauseMenu
	Input.parse_input_event(_pad(8, JOY_BUTTON_START))
	await _frames(2)
	_check("Start de la manette 8 (joueur 2) : pause", pm.is_open and get_tree().paused)
	pm.call(&"_close")
	await _frames(1)
	await _tap(8, JOY_BUTTON_BACK)
	_check("Select manette 8 : inventaire du joueur 2", pm.inventory_mode and pm.viewer_slot == 1 and pm.viewer_state() == RunState.player_state(1))
	_check("inventaire coop : jeu non figé", not get_tree().paused)
	await _tap(7, JOY_BUTTON_BACK)
	_check("Select manette 7 : bascule sur le joueur 1", pm.inventory_mode and pm.viewer_slot == 0)
	await _tap(7, JOY_BUTTON_BACK)
	_check("Select de nouveau : fermé", not pm.inventory_mode and pm.viewer_slot == -1)

	print("Déconnexion / reconnexion")
	var cl := main.get(&"coop_local") as CoopLocal
	_check("CoopLocal présent", cl != null)
	cl._on_joy_connection_changed(8, false)
	await _frames(2)
	_check("manette 8 perdue : joueur 2 absent (source muette)", CoopLocal.is_absent(1) and Players.input_of(1) is InputSourceIdle)
	_check("absent protégé", bool((main.get(&"players") as Array)[1].call(&"is_invulnerable")))
	_check("pause avec bandeau dédié (pas dans le chrono)", pm.is_open and get_tree().paused and pm.alert_text().begins_with("Manette du joueur 2 déconnectée") and not pm._info.text.contains("Manette"))
	_check("bandeau : consigne de reprise lisible, contraste texte/fond >= 4,5:1", pm.alert_text().contains("Rebranchez la manette de J2") and _contrast(PauseMenu.ALERT_TEXT, PauseMenu.ALERT_TINT) >= 4.5, str(_contrast(PauseMenu.ALERT_TEXT, PauseMenu.ALERT_TINT)))
	plates.queue_redraw()
	await _frames(1)
	var absent_shown := false
	for pl in plates.plates:
		if int(pl["slot"]) == 1 and bool(pl["absent"]):
			absent_shown = true
	_check("plaque « Manette déconnectée »", absent_shown)
	var worst_bg := Color(CoopPlates.COL_BG.r * CoopPlates.COL_BG.a + (1.0 - CoopPlates.COL_BG.a), CoopPlates.COL_BG.g * CoopPlates.COL_BG.a + (1.0 - CoopPlates.COL_BG.a), CoopPlates.COL_BG.b * CoopPlates.COL_BG.a + (1.0 - CoopPlates.COL_BG.a))
	_check("plaques : texte spectateur / déconnecté à pleine opacité, contraste >= 4,5:1 même sur un sol blanc", _contrast(CoopPlates.COL_TEXT, worst_bg) >= 4.5, str(_contrast(CoopPlates.COL_TEXT, worst_bg)))
	var p2: Node2D = (main.get(&"players") as Array)[0]
	var mx := float(p2.get(&"max_hp"))
	p2.set(&"hp", mx * 0.2)
	plates.queue_redraw()
	await _frames(1)
	var low_flag := false
	for pl in plates.plates:
		if int(pl["slot"]) == 0 and bool(pl["low_hp"]):
			low_flag = true
	_check("plaque : PV <= 25 % signalés autrement que par la couleur (cadre épais qui pulse, « ! »)", low_flag)
	p2.set(&"hp", mx)
	_check("manette 7 occupée : ne reprend pas", not cl.handle_free_pad_press(7))
	_check("manette libre 12 : reprend le joueur 2", cl.handle_free_pad_press(12) and Players.input_of(1) is InputSourcePad and Players.input_of(1).device == 12)
	cl._on_joy_connection_changed(12, false)
	cl._on_joy_connection_changed(8, true)
	_check("manette rebranchée : rendue à l'absent", Players.input_of(1) is InputSourcePad and Players.input_of(1).device == 8)
	_check("pad_restored : bandeau « reconnectée » (le jeu reste en pause)", pm.alert_text().begins_with("Manette du joueur 2 reconnectée") and get_tree().paused, pm.alert_text())
	pm.call(&"_close")
	await _frames(1)

	print("Mode test : ajout en cours de run")
	var id := int(main.call(&"add_local_player", InputSource.pad_source(14)))
	await _frames(2)
	_check("joueur 3 ajouté", id == 2 and Players.count() == 3 and Players.by_id(2) != null)
	_check("même niveau que le joueur 1", RunState.player_state(2).level == RunState.local().level)
	cl.arm_join()
	_check("jonction armée : manette libre 15 rejoint", cl.handle_free_pad_press(15) and Players.count() == 4 and not cl.join_armed)
	plates.queue_redraw()
	await _frames(2)
	_check("4 plaques", plates.plates.size() == 4)
	_check("partie pleine : refus", int(main.call(&"add_local_player", InputSource.pad_source(16))) == -1)

	main.queue_free()
	await _frames(3)
	get_tree().paused = false
