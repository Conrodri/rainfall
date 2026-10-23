extends Node
## Lots UX Choix L6 / L7 (docs/ux/Audit_Choix.md P10, P11, P12).
## - L7 : GroundPickup clignote pendant la dernière seconde (2,5 Hz, alpha 0,35..1) ; fondu sans clignotement
##   avec « Réduire les mouvements » ;
## - L6 : rareté écrite dans l'infobulle d'item (ItemBar) ; PauseMenu.open_items() (en jeu et par-dessus le
##   coffre, sans toucher à la pause) ; bouton « Objets (N) » + action chest_items dans l'écran de coffre.
## godot --headless --path game res://tests/choice_l6l7_test.tscn   (RESULT: OK)

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


func _action(a: StringName, pressed := true) -> void:
	var e := InputEventAction.new()
	e.action = a
	e.pressed = pressed
	get_viewport().push_input(e)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Platform.set_input_mode(Platform.InputMode.KBM)
	get_window().size = Vector2i(1920, 1080)
	RunState.start_run(&"moyen", 31)
	await _frames(2)

	# --- L7 : alpha d'expiration (pur)
	_check(is_equal_approx(GroundPickup.expire_alpha(3.0), 1.0), "hors avertissement : plein")
	_check(is_equal_approx(GroundPickup.expire_alpha(1.0), 1.0), "début de l'avertissement : plein")
	var half := 0.5 / Balance.PICKUP_EXPIRE_BLINK_HZ # demi-période : creux
	_check(is_equal_approx(GroundPickup.expire_alpha(1.0 - half), Balance.PICKUP_EXPIRE_ALPHA_MIN), "creux à %.2f s : %.2f" % [half, GroundPickup.expire_alpha(1.0 - half)])
	var lo := 1.0
	var hi := 0.0
	var dips := 0
	var was_low := false
	for i in 101:
		var a := GroundPickup.expire_alpha(1.0 - i * 0.01)
		lo = minf(lo, a)
		hi = maxf(hi, a)
		var low := a < 0.5
		if low and not was_low:
			dips += 1
		was_low = low
	_check(lo >= Balance.PICKUP_EXPIRE_ALPHA_MIN - 0.001 and hi <= 1.0, "alpha dans [0,35 ; 1] (%.2f..%.2f)" % [lo, hi])
	_check(dips >= 2 and dips <= 3, "clignotements sur 1 s : %d (< 3 flashs/s)" % dips)
	var prev := 2.0
	var mono := true
	for i in 101:
		var a := GroundPickup.expire_alpha(1.0 - i * 0.01, true)
		mono = mono and a <= prev + 0.0001
		prev = a
	_check(mono and is_equal_approx(GroundPickup.expire_alpha(0.0, true), Balance.PICKUP_EXPIRE_ALPHA_MIN), "Réduire les mouvements : fondu continu, sans clignotement")

	# --- L7 : appliqué au nœud (sprite / repli / halo enfant)
	var host := Node2D.new()
	add_child(host)
	var g := GroundPickup.spawn(host, Vector2(500, 500), null, Callable(), 2.0)
	g.step(0.5)
	_check(is_equal_approx(g.modulate.a, 1.0), "pickup à 1,5 s restantes : plein")
	g.step(0.5 + half) # temps écoulé = 1 + half : restant = 1 - half
	_check(absf(g.modulate.a - Balance.PICKUP_EXPIRE_ALPHA_MIN) < 0.01, "pickup au creux : alpha %.2f" % g.modulate.a)
	host.queue_free()

	# --- L6 : rareté écrite dans l'infobulle
	RunState.add_item(&"chronometre_brise")
	RunState.add_item(&"lentille_aiguisee")
	var bar := ItemBar.new()
	add_child(bar)
	await _frames(1)
	bar.show_tooltip(&"chronometre_brise")
	_check(bar.tooltip_rarity_text() == "RARE", "infobulle : « %s »" % bar.tooltip_rarity_text())
	_check(bar._tip_rarity.get_theme_font_size(&"font_size") >= HudMetrics.floor_px(), "rareté >= plancher de police")
	bar.hide_tooltip()
	bar.show_tooltip(&"lentille_aiguisee")
	_check(bar.tooltip_rarity_text() == "COMMUN", "infobulle commun : « %s »" % bar.tooltip_rarity_text())
	bar.hide_tooltip()
	_check(ItemBar.rarity_word(&"peu_commun") == "Peu commun", "mot de rareté partagé")
	bar.queue_free()

	# --- L6 : PauseMenu.open_items() en jeu
	var pm := PauseMenu.new()
	add_child(pm)
	await _frames(1)
	pm.open_items()
	await _frames(1)
	_check(pm.is_open and not pm.items_only and pm._current == pm._panel_items, "en jeu : menu pause ouvert sur Objets")
	_check(get_tree().paused, "en jeu : pause")
	_check(pm.items_texts().size() == 2, "Objets : 2 cases")
	pm._items_back.pressed.emit()
	_check(pm._current == pm._panel_main and pm.is_open, "Retour -> menu pause")
	pm._close()
	await _frames(1)

	# --- L6 : bouton Objets dans l'écran de coffre
	RunState.gold = 100000.0
	ChestSession.reset_run_counters()
	var ui: ChestUI = load(UI).instantiate()
	add_child(ui)
	ui.open(&"large", 2, 0.0)
	await _frames(2)
	ui.skip()
	await _frames(2)
	await get_tree().create_timer(0.4, true, false, true).timeout
	ui._skip_wait_release = false
	_check(InputMap.has_action(&"chest_items"), "action chest_items créée")
	_check(ui._items_btn.visible and ui._items_btn.text == "Objets (2)", "bouton « %s » visible" % ui._items_btn.text)
	_check(ui._items_btn.get_global_rect().size.y >= 96.0, "bouton Objets >= 96 px")
	_check(ui._items_key.text() != "", "invite de touche (KBM) : « %s »" % ui._items_key.text())
	_action(&"chest_items")
	await _frames(2)
	_action(&"chest_items", false)
	_check(ui.items_open() and pm.items_only and pm.is_open, "Tab : objets par-dessus le coffre")
	_check(get_tree().paused, "coffre : toujours en pause")
	var offered := ui.session.offered.duplicate()
	_action(&"chest_pick_1")
	await _frames(2)
	_action(&"chest_pick_1", false)
	_check(is_instance_valid(ui) and not ui.is_queued_for_deletion(), "choix bloqué pendant la consultation")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	get_viewport().push_input(esc)
	await _frames(2)
	_check(not ui.items_open() and not pm.is_open, "Échap / B : retour au coffre")
	_check(get_tree().paused and is_instance_valid(ui) and ui.session.offered == offered, "coffre intact et en pause")
	ui.open_items()
	await _frames(1)
	_check(ui.items_open(), "bouton : réouverture")
	_action(&"chest_items")
	await _frames(2)
	_action(&"chest_items", false)
	_check(not ui.items_open(), "Tab referme")
	ui._items_btn.pressed.emit()
	await _frames(1)
	pm._items_back.pressed.emit()
	await _frames(1)
	_check(not ui.items_open() and get_tree().paused, "Retour referme sans quitter la pause")
	ui._on_choose(0)
	await _frames(2)
	_check(not get_tree().paused, "choix : pause rendue")
	pm.queue_free()
	await _frames(2)

	# --- sans menu pause : bouton masqué
	var ui2: ChestUI = load(UI).instantiate()
	add_child(ui2)
	ui2.open(&"petit", 1, 0.0)
	await _frames(2)
	ui2.skip()
	await get_tree().create_timer(0.4, true, false, true).timeout
	_check(not ui2._items_btn.visible, "sans menu pause : bouton Objets masqué")
	ui2.queue_free()
	get_tree().paused = false
	await _frames(2)

	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)
