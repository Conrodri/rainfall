extends Node
## Mise en scène du coffre (ChestUI) : défilement de rareté puis d'items, skip au clic / touche, reprise sans animation.
## - phases rareté -> items -> fini, durée totale ≈ 1,2-2 s, plus aucun dé ;
## - même graine : résultat et RunState.rng identiques avec ou sans skip (présentation seule) ;
## - le clic de skip (souris + toucher émulé) ne choisit jamais de carte, le clic suivant choisit ;
## - Entrée passe l'animation sans choisir ; relance à l'or = défilement des items seul, skippable ;
## - ChestUI.resume : résultat directement, sans animation.
## godot --headless --path game res://tests/chest_reveal_test.tscn   (RESULT: OK)

const UI := "res://scenes/ui/chest/chest_ui.tscn"
const SEED := 424242

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


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _new_ui() -> ChestUI:
	var ui: ChestUI = load(UI).instantiate()
	add_child(ui)
	return ui


func _close(ui: Variant) -> void:
	if is_instance_valid(ui):
		ui.queue_free()
	get_tree().paused = false
	await _frames(2)


func _card_center(ui: ChestUI, i: int) -> Vector2:
	return ui._cards[i].get_global_rect().get_center()


func _click(pos: Vector2, release := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	e.global_position = pos
	Input.parse_input_event(e)
	var t := InputEventScreenTouch.new() # toucher émulé depuis la souris (projet : emulate_touch_from_mouse)
	t.pressed = true
	t.position = pos
	Input.parse_input_event(t)
	if release:
		await _frames(1)
		var r := e.duplicate() as InputEventMouseButton
		r.pressed = false
		Input.parse_input_event(r)
		var tr := t.duplicate() as InputEventScreenTouch
		tr.pressed = false
		Input.parse_input_event(tr)
	await _frames(2)


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(1)
	var r := e.duplicate() as InputEventKey
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _names(ui: ChestUI) -> Array:
	return [(ui._card_front[0].get_child(1) as Label).text, (ui._card_front[1].get_child(1) as Label).text]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# réglages injectés : « Animation des coffres » = Complète quel que soit le réglage réel du joueur
	GameSettings.cfg_path = "user://test_chest_reveal_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	Platform.set_input_mode(Platform.InputMode.KBM)
	get_window().size = Vector2i(1920, 1080)
	RunState.start_run(&"moyen", SEED)
	RunState.gold = 100000.0
	ChestSession.reset_run_counters()
	await _frames(2)

	# --- 1. Sans skip : phases, durée, résultat affiché
	var st0 := RunState.rng.state
	var ui := _new_ui()
	ui.open(&"large", 2, 0.0)
	await _frames(1)
	_check(ui.is_animating() and ui._busy, "animation lancée, écran occupé")
	var phases: Array = []
	var t := 0.0
	var t_items := -1.0
	while ui.is_animating() and t < 5.0:
		var p := ui.reveal_phase()
		if phases.is_empty() or phases[-1] != p:
			phases.append(p)
		if p == &"items" and t_items < 0.0:
			t_items = t
			_check(ui._reel_tiles.size() > 0 and ui._reel_seq[int(ui._reel_to)] == ui.session.quality, "la bande de rareté s'arrête sur la rareté tirée (%s)" % ui.session.quality)
			_check(ui._quality.text == ChestUI.QUALITY_NAMES[ui.session.quality], "nom de rareté affiché à l'arrêt")
		await _frames(1)
		t += get_process_delta_time()
	_check(phases.has(&"rarity") and phases.has(&"items") and phases.find(&"rarity") < phases.find(&"items"), "phases rareté puis items %s" % [phases])
	_check(t >= 1.0 and t <= 2.3, "durée totale ≈ 1,2-2 s (%.2f s)" % t)
	_check(not ui._busy and not ui.skipped, "fin naturelle, écran prêt")
	var res_a := {"q": ui.session.quality, "die": ui.session.die, "offered": ui.session.offered.duplicate(), "rng": RunState.rng.state}
	var want_names: Array = []
	for id in res_a["offered"]:
		want_names.append(str(ItemDB.get_item(id).get("name", id)))
	_check(_names(ui) == want_names, "cartes posées sur les items tirés %s" % [want_names])
	_check(ui._card_front[0].visible and ui._card_front[1].visible, "faces avant visibles")
	var has_die := false
	for n in ui.find_children("*", "", true, false):
		if n is TextureRect and (n as TextureRect).texture != null and (n as TextureRect).texture.resource_path.contains("dice"):
			has_die = true
	_check(not has_die, "aucun dé affiché")
	await _close(ui)

	# --- 2. Même graine + skip au clic pendant la rareté : même résultat, aucun choix
	RunState.rng.state = st0
	var items0 := RunState.items.duplicate()
	ui = _new_ui()
	var chosen := [false]
	Events.item_chosen.connect(func(_i): chosen[0] = true)
	ui.open(&"large", 2, 0.0)
	await _frames(4)
	_check(ui.reveal_phase() == &"rarity", "skip testé pendant le défilement de rareté")
	await _click(_card_center(ui, 0), false) # appui maintenu sur la carte 0
	_check(not ui.is_animating() and ui.skipped and not ui._busy, "clic = animation terminée instantanément")
	_check(ui.session.quality == res_a["q"] and ui.session.die == res_a["die"] and ui.session.offered == res_a["offered"], "même tirage que sans skip")
	_check(RunState.rng.state == res_a["rng"], "RunState.rng identique (présentation sans RNG de jeu)")
	_check(_names(ui) == want_names and ui._quality.text == ChestUI.QUALITY_NAMES[res_a["q"]], "résultat final affiché")
	_check(is_instance_valid(ui) and not chosen[0] and RunState.items == items0, "le clic de skip ne choisit pas de carte")
	# relâcher, puis le clic suivant choisit normalement
	var r := InputEventMouseButton.new()
	r.button_index = MOUSE_BUTTON_LEFT
	r.position = _card_center(ui, 0)
	r.global_position = r.position
	Input.parse_input_event(r)
	var tr := InputEventScreenTouch.new()
	tr.position = r.position
	Input.parse_input_event(tr)
	await _frames(2)
	_check(is_instance_valid(ui) and not chosen[0], "le relâcher du skip ne choisit pas non plus")
	await _wait(0.3)
	var pick := str(res_a["offered"][0])
	await _click(_card_center(ui, 0))
	_check(chosen[0] and RunState.stacks(StringName(pick)) >= 1, "second clic : carte choisie (%s)" % pick)
	_check(not is_instance_valid(ui) or ui.is_queued_for_deletion(), "écran fermé après le choix")
	await _close(ui)

	# --- 3. Entrée pendant le défilement des items : skip sans choix ; relance à l'or = items seuls
	chosen[0] = false
	ui = _new_ui()
	ui.open(&"petit", 1, 0.0)
	var guard := 0.0
	while ui.reveal_phase() != &"items" and guard < 3.0:
		await _frames(1)
		guard += get_process_delta_time()
	_check(ui.reveal_phase() == &"items", "phase items atteinte")
	await _key(KEY_ENTER)
	_check(not ui.is_animating() and not chosen[0] and is_instance_valid(ui), "Entrée : skip sans choix")
	await _wait(0.3)
	var before: Array = ui.session.offered.duplicate()
	ui._on_gold_reroll()
	await _frames(2)
	_check(ui.is_animating() and ui.reveal_phase() == &"items", "relance : défilement des items seul")
	await _key(KEY_SPACE)
	_check(not ui.is_animating() and not chosen[0], "relance passée à l'Espace, sans choix")
	var nn: Array = []
	for id in ui.session.offered:
		nn.append(str(ItemDB.get_item(id).get("name", id)))
	_check(_names(ui) == nn and ui.session.offered != before or ItemDB.ids_of_quality(ui.session.quality).size() <= 2, "cartes de la relance affichées %s" % [nn])
	await _close(ui)

	# --- 3b. Coffre légendaire : la bande mélange les raretés, éclair borné au coffre et à la bande, son calé
	ui = _new_ui()
	ui.open(&"legendaire", 2, 0.0)
	await _frames(3)
	var kinds := {}
	for q in ui._reel_seq:
		kinds[q] = true
	_check(kinds.size() >= 3 and ui._reel_seq[int(ui._reel_to)] == &"legendaire", "bande légendaire : mélange de %d raretés, arrêt sur Légendaire" % kinds.size())
	var vp := get_viewport().get_visible_rect().size
	_check(ui._flash.get_parent() == ui._stage_box and ui._flash.size.x < vp.x * 0.6 and ui._flash.size.y < vp.y * 0.9, "éclair borné au coffre et à la bande (%s)" % ui._flash.size)
	var font := (ui._reel_tiles[0].get_child(2) as Label).get_theme_font(&"font")
	var fsz := (ui._reel_tiles[0].get_child(2) as Label).get_theme_font_size(&"font_size")
	_check(font.get_string_size("Légendaire", HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x <= ui._tile_px - 16.0, "« Légendaire » tient dans une case sans coupure (%d px)" % fsz)
	var gen0: int = Audio._chest_gen
	ui.skip()
	_check(Audio._chest_gen != gen0 and Audio._chest_gen == Audio._chest_gen_landed, "skip : frappe légendaire jouée maintenant, minuteurs annulés")
	await _close(ui)

	# --- 4. Reprise de sauvegarde : directement sur le résultat
	var s := ChestSession.new(&"large", 2, 120.0)
	s.quality = &"rare"
	s.die = 95
	var rares: Array = ItemDB.ids_of_quality(&"rare")
	s.offered = [str(rares[0]), str(rares[min(1, rares.size() - 1)])]
	s.shown = s.offered.duplicate()
	var opened := [false]
	Events.chest_opened.connect(func(_c, _q, _o): opened[0] = true)
	var rs := RunState.rng.state
	ui = _new_ui()
	ui.resume(s)
	await _frames(2)
	_check(not ui.is_animating() and not ui._busy and ui.reveal_phase() == &"done", "reprise : pas d'animation, écran prêt")
	_check(ui._card_front[0].visible and _names(ui)[0] == str(ItemDB.get_item(s.offered[0]).get("name", "")), "reprise : mêmes cartes")
	_check(ui._quality.text == "Rare" and ui._reel_seq[int(ui._reel_to)] == &"rare", "reprise : rareté posée")
	_check(not opened[0] and RunState.rng.state == rs, "reprise : ni chest_opened ni RNG consommé")
	await _close(ui)

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
