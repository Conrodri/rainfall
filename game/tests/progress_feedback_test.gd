extends Node
## Lot Choix-L4 (audit Choix P13 / P14) : retours de progression du HUD.
## godot --headless --path game res://tests/progress_feedback_test.tscn
## Réglages injectés (user://test_progress_feedback.cfg) : la config réelle du joueur n'est ni lue ni écrite.

const TEST_CFG := "user://test_progress_feedback.cfg"
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


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _level_up(hud: Hud) -> void:
	RunState.add_xp(Balance.xp_required(RunState.level) - RunState.xp + 0.01)


func _ready() -> void:
	GameSettings.cfg_path = TEST_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	GameSettings.reset_all(get_tree())
	Platform.set_input_mode(Platform.InputMode.KBM)
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 779)
	add_child(main)
	await main.game_ready
	await _frames(3)
	var hud: Hud = main.hud
	var badge := hud.level_badge()

	# --- affichage initial : aucun retour
	_check(hud.level_feedbacks == 0 and hud.gold_pulses == 0, "pas de retour à l'affichage initial")

	# --- montée de niveau, réglages par défaut
	var lvl0 := RunState.level
	_level_up(hud)
	_check(hud.level_feedbacks == 1, "montée de niveau signalée une fois")
	await _wait(0.1)
	_check(hud.level_badge_scale() > 1.2, "médaillon en impulsion (×%.2f à 100 ms)" % hud.level_badge_scale())
	var lt := hud.level_text()
	_check(lt != null and lt.text == "Niveau %d" % (lvl0 + 1), "libellé « Niveau %d » affiché" % (lvl0 + 1))
	if lt != null:
		_check(lt.get_theme_font_size("font_size") >= HudMetrics.floor_px(HudMetrics.is_mobile()), "libellé >= plancher de police")
		var pp := (hud.player as CanvasItem).get_global_transform_with_canvas().origin
		_check(lt.get_global_rect().end.y < pp.y and absf(lt.get_global_rect().get_center().x - pp.x) < 4.0, "libellé centré au-dessus du joueur")
	var fl := hud._xp_flash
	_check(fl != null and fl.visible and fl.color.a > 0.0 and fl.color.a < Hud.XP_FLASH_ALPHA, "éclat de la barre d'XP en cours")
	await _wait(0.35)
	_check(is_equal_approx(hud.level_badge_scale(), 1.0), "médaillon revenu à ×1 après 300 ms")
	_check(not fl.visible, "éclat de la barre d'XP fini après 200 ms")
	await _wait(0.8)
	_check(hud.level_text() == null, "libellé retiré après 1 s")

	# --- or : impulsion à l'arrivée des pièces, plafonnée
	var p0 := hud.gold_pulses
	RunState.add_gold(5.0)
	await _wait(0.1)
	_check(hud.gold_pulses == p0, "pas d'impulsion avant l'arrivée des pièces (crédit immédiat : %d)" % int(RunState.gold))
	await _wait(PickupManager.FLY_TIME)
	_check(hud.gold_pulses == p0 + 1, "impulsion à l'arrivée de la première pièce")
	for i in 20:
		RunState.add_gold(1.0)
	await _wait(PickupManager.FLY_TIME + 0.1)
	_check(hud.gold_pulses <= p0 + 2, "20 primes simultanées : impulsions plafonnées (%d)" % (hud.gold_pulses - p0))
	var p1 := hud.gold_pulses
	RunState.spend_gold(3.0)
	await _wait(PickupManager.FLY_TIME + 0.1)
	_check(hud.gold_pulses == p1, "dépense : pas d'impulsion")
	hud.pulse_gold()
	await _wait(0.04)
	_check(hud._gold_box.scale.x > 1.05, "compteur d'or en impulsion (×%.2f)" % hud._gold_box.scale.x)
	await _wait(0.15)
	_check(is_equal_approx(hud._gold_box.scale.x, 1.0), "compteur revenu à ×1 après 120 ms")

	# --- Réduire les mouvements : pas d'échelle, éclaircissement à la place
	GameSettings.set_reduce_motion(true)
	_level_up(hud)
	await _wait(0.05)
	_check(is_equal_approx(hud.level_badge_scale(), 1.0) and badge.modulate.r > 1.0, "mouvements réduits : médaillon éclairci, sans échelle")
	var lt2 := hud.level_text()
	var y0 := lt2.position.y if lt2 != null else 0.0
	await _wait(0.4)
	_check(lt2 != null and is_instance_valid(lt2) and absf(lt2.position.y - y0) < 2.0, "mouvements réduits : libellé immobile")
	hud.pulse_gold()
	await _wait(0.04)
	_check(is_equal_approx(hud._gold_box.scale.x, 1.0), "mouvements réduits : compteur d'or sans échelle")
	await _wait(1.0)

	# --- Flashs « aucun » : pas d'éclat
	GameSettings.set_flashes(0)
	_level_up(hud)
	await _frames(2)
	_check(not hud._xp_flash.visible, "flashs aucun : pas d'éclat de la barre d'XP")
	_check(is_equal_approx(badge.modulate.r, 1.0) and is_equal_approx(hud.level_badge_scale(), 1.0), "flashs aucun + mouvements réduits : médaillon inchangé")
	_check(hud.level_text() != null, "le libellé « Niveau N » reste (information, pas un flash)")
	GameSettings.set_flashes(1)
	_level_up(hud)
	await _frames(1)
	_check(hud._xp_flash.color.a <= Hud.XP_FLASH_ALPHA * 0.25 + 0.001, "flashs réduits : éclat ×0,25")
	GameSettings.reset_all(get_tree())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	print("RESULT: OK" if _fails == 0 else "RESULT: FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
