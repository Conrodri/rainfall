extends Node
## Lot UX L2 : écran de coffre au doigt et à la manette (ChestUI).
## - choix au relâcher (appui seul = rien, glisser hors de la carte = annulé, relâcher dedans = choix) ;
## - boutons de relance >= 128 px, côte à côte, aucun PrimaryButton, bouton d'or distinct ;
## - invites de touches : suivent le mode d'entrée (vides au tactile) et le remappage ;
## - contour de focus visible à la manette ; ligne d'empilement « ×N → ×N+1 » ; rareté écrite sur la carte ;
## - éclat de rareté soumis à GameSettings.flash_scale().
## godot --headless --path game res://tests/chest_l2_test.tscn   (RESULT: OK)

const UI := "res://scenes/ui/chest/chest_ui.tscn"
const CFG := "user://test_chest_l2_settings.cfg"

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


func _mouse(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	return e


func _open(kind := &"large") -> ChestUI:
	var ui: ChestUI = load(UI).instantiate()
	add_child(ui)
	ui.open(kind, 2, 0.0)
	await _frames(2)
	ui.skip()
	await _frames(2)
	await get_tree().create_timer(0.4, true, false, true).timeout
	ui._skip_wait_release = false
	return ui


func _close(ui: ChestUI) -> void:
	if is_instance_valid(ui):
		ui.queue_free()
	get_tree().paused = false
	await _frames(2)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var old_cfg := GameSettings.cfg_path
	GameSettings.cfg_path = CFG # réglages injectés : le réglage réel du joueur n'influence pas le test
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	Platform.set_input_mode(Platform.InputMode.KBM)
	get_window().size = Vector2i(1920, 1080)
	RunState.start_run(&"moyen", 77)
	RunState.gold = 100000.0
	ChestSession.reset_run_counters()
	await _frames(2)

	# --- 1. ligne d'empilement (pure)
	_check(ChestUI.stack_line("bague_de_vigueur", 0) == "", "item non possédé : pas de ligne")
	_check(ChestUI.stack_line("bague_de_vigueur", 1) == "×1 → ×2 : +50 PV max au total", "PV max : « %s »" % ChestUI.stack_line("bague_de_vigueur", 1))
	_check(ChestUI.stack_line("lentille_aiguisee", 2) == "×2 → ×3 : +30 % de chance de critique au total", "critique : « %s »" % ChestUI.stack_line("lentille_aiguisee", 2))
	_check(ChestUI.stack_line("sablier_fele", 1).begins_with("×1 → ×2 : "), "exponentiel : « %s »" % ChestUI.stack_line("sablier_fele", 1))
	_check(ChestUI.stack_line("etincelle", 1).begins_with("×1 → ×2 : "), "proc seul : « %s »" % ChestUI.stack_line("etincelle", 1))

	# --- 2. écran ouvert au clavier-souris
	var ui := await _open()
	_check(not ui._busy and ui._card_front[0].visible and ui._card_front[1].visible, "écran prêt")
	for b in [ui._ad_btn, ui._gold_btn]:
		_check(b.get_global_rect().size.y >= 128.0, "bouton de relance >= 128 px (%.0f)" % b.get_global_rect().size.y)
		_check(b.theme_type_variation != &"PrimaryButton", "bouton de relance en style secondaire")
	var ar := ui._ad_btn.get_global_rect()
	var gr := ui._gold_btn.get_global_rect()
	_check(absf(ar.position.y - gr.position.y) < 2.0 and gr.position.x >= ar.end.x + 40.0, "boutons côte à côte, écart >= 40 px")
	_check(ui._gold_btn.has_theme_stylebox_override("normal") and not ui._ad_btn.has_theme_stylebox_override("normal"), "bouton d'or au style distinct")
	for i in 2:
		var rl := ui._card_front[i].get_child(5) as Label
		var qn := String(ChestUI.QUALITY_NAMES[ui.session.quality]).to_upper()
		_check(rl.text == qn and rl.size.x > 20.0, "rareté écrite sur la carte %d (« %s »)" % [i, rl.text])
	_check(ui._pick_keys[0].text() != "" and ui._ad_key.text() != "" and ui._gold_key.text() != "", "invites présentes au clavier-souris (%s / %s)" % [ui._pick_keys[0].text(), ui._gold_key.text()])

	# --- 3. choix au relâcher
	var chosen := [false]
	var cb := func(_i): chosen[0] = true
	Events.item_chosen.connect(cb)
	var c0 := ui._cards[0]
	var mid := c0.size * 0.5
	ui._on_card_input(_mouse(mid, true), 0)
	await _frames(1)
	_check(not chosen[0] and ui._press_card == 0, "l'appui seul ne choisit pas")
	ui._on_card_input(_mouse(c0.size + Vector2(50, 50), false), 0)
	await _frames(1)
	_check(not chosen[0] and ui._press_card == -1 and is_instance_valid(ui) and not ui.is_queued_for_deletion(), "relâcher hors de la carte = annulé")
	ui._on_card_input(_mouse(mid, true), 0)
	var mv := InputEventMouseMotion.new()
	mv.position = c0.size + Vector2(30, 0)
	ui._on_card_input(mv, 0)
	_check(ui._press_card == -1, "glisser hors de la carte annule")
	ui._on_card_input(_mouse(mid, false), 0)
	_check(not chosen[0], "relâcher après annulation : rien")
	ui._on_card_input(_mouse(mid, true), 0)
	ui._on_card_input(_mouse(mid, false), 0)
	_check(chosen[0] and ui.is_queued_for_deletion(), "relâcher dans la carte = choix")
	Events.item_chosen.disconnect(cb)
	await _close(ui)

	# --- 4. invites : tactile vide, manette, remappage
	ui = await _open()
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	await _frames(1)
	_check(ui._pick_keys[0].text() == "" and ui._gold_key.text() == "", "tactile : invites vides")
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	await _frames(1)
	_check(ui._pick_keys[0].text() == "LB" and ui._pick_keys[1].text() == "RB", "manette : LB / RB (%s / %s)" % [ui._pick_keys[0].text(), ui._pick_keys[1].text()])
	# --- 5. contour de focus à la manette
	ui._cards[0].grab_focus()
	await _frames(2)
	_check(ui._focus_rings[0].visible and not ui._focus_rings[1].visible, "manette : contour de focus sur la carte focalisée")
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	await _frames(1)
	_check(not ui._focus_rings[0].visible, "tactile : pas de contour")
	Platform.set_input_mode(Platform.InputMode.KBM)
	await _frames(1)
	var old := InputMap.action_get_events(&"chest_pick_1")
	InputMap.action_erase_events(&"chest_pick_1")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F
	InputMap.action_add_event(&"chest_pick_1", ev)
	ui._refresh_prompts()
	_check(ui._pick_keys[0].text() == "F", "remappage respecté (« %s »)" % ui._pick_keys[0].text())
	InputMap.action_erase_events(&"chest_pick_1")
	for e in old:
		InputMap.action_add_event(&"chest_pick_1", e)
	await _close(ui)

	# --- 6. éclat de rareté soumis à flash_scale
	var prev: int = Quality.flashes_level
	for lvl in [0, 2]:
		Quality.flashes_level = lvl
		ui = load(UI).instantiate()
		add_child(ui)
		ui.open(&"legendaire", 2, 0.0)
		await _frames(2)
		var peak := 0.0
		var t := 0.0 # borne en temps (pas en images : le défilement légendaire dure 1,22 s, ~170 images en headless)
		while t < 4.0:
			await _frames(1)
			t += get_process_delta_time()
			peak = maxf(peak, ui._flash.color.a)
			if not ui.is_animating() and ui._rar_landed and t > 0.3:
				await _frames(3) # l'éclat (0,04 s de montée) suit l'arrêt de la rareté
				peak = maxf(peak, ui._flash.color.a)
				break
		if lvl == 0:
			_check(peak == 0.0, "flashes aucun : aucun éclat (pic %.2f)" % peak)
		else:
			_check(peak > 0.0, "flashes complets : éclat (pic %.2f)" % peak)
		await _close(ui)
	Quality.flashes_level = prev

	# --- 7. réglage « Animation des coffres » (GameSettings.chest_reveal_mult) appliqué aux durées
	var durs := {}
	for mode in ["complete", "short", "instant"]:
		GameSettings.set_chest_reveal(mode)
		var m: Array = GameSettings.chest_reveal_mult()
		ui = load(UI).instantiate()
		add_child(ui)
		ui.open(&"legendaire", 2, 0.0)
		await _frames(1)
		var want_rar: float = ChestUI.RARITY_DUR[ui._rank] * float(m[0])
		_check(is_equal_approx(ui._rar_dur, want_rar), "%s : défilement de rareté × %.2f (%.3f s)" % [mode, m[0], ui._rar_dur])
		_check(is_equal_approx(ui._item_dur[0], ChestUI.ITEM_DUR[0] * float(m[1])) and is_equal_approx(ui._item_dur[1], ChestUI.ITEM_DUR[1] * float(m[1])),
			"%s : défilement des items × %.2f (%.3f / %.3f s)" % [mode, m[1], ui._item_dur[0], ui._item_dur[1]])
		var t := 0.0
		while ui.is_animating() and t < 4.0:
			await _frames(1)
			t += get_process_delta_time()
		durs[mode] = t
		_check(not ui.is_animating() and not ui._busy and ui._rar_landed and ui._item_landed[0] and ui._item_landed[1], "%s : résultat posé, écran prêt" % mode)
		if mode == "instant":
			_check(t < 0.05, "instantanée : résultat affiché tout de suite (%.3f s)" % t)
			_check(not ui.skipped and not ui._skip_wait_release, "instantanée : pas un skip (aucun verrou de relâcher)")
			_check(ui._card_front[0].visible and ui._card_front[1].visible and ui._quality.text == ChestUI.QUALITY_NAMES[ui.session.quality], "instantanée : rareté et cartes affichées")
		await _close(ui)
	_check(durs["complete"] > durs["short"] and durs["short"] > durs["instant"], "complète > courte > instantanée (%.2f / %.2f / %.2f s)" % [durs["complete"], durs["short"], durs["instant"]])
	# instantanée : arrivée de rareté AVEC effets (_land_rarity(true) : son de rareté + éclat), pas l'arrivée muette du skip
	GameSettings.set_chest_reveal("instant")
	ui = load(UI).instantiate()
	add_child(ui)
	Quality.flashes_level = 2
	ui.open(&"legendaire", 2, 0.0)
	var pk := 0.0
	for f in 6:
		await _frames(1)
		pk = maxf(pk, ui._flash.color.a)
	_check(pk > 0.0, "instantanée : arrivée de rareté jouée avec effets (éclat %.2f)" % pk)
	await _close(ui)
	Quality.flashes_level = prev
	GameSettings.cfg_path = old_cfg

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails else 0)
