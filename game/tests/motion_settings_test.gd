extends Node
## Lot L3 (A-07) : réglages Flashs / Secousses de caméra / Réduire les mouvements, une source unique (GameSettings).
## godot --headless --path game res://tests/motion_settings_test.tscn
## Fichier de réglages injecté : la config réelle du joueur n'est ni lue ni écrite.

const TEST_CFG := "user://test_motion_settings.cfg"
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
	Platform.set_input_mode(Platform.InputMode.KBM)
	GameSettings.cfg_path = TEST_CFG
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	GameSettings.reset_all(get_tree())

	# --- Valeurs par défaut
	_check(GameSettings.flashes_level() == 2 and is_equal_approx(GameSettings.flash_scale(), 1.0), "défaut : flashs complets (×1)")
	_check(is_equal_approx(GameSettings.shake_scale(), 1.0), "défaut : secousses 100 %")
	_check(not GameSettings.reduce_motion() and GameSettings.hitstop_enabled(), "défaut : mouvements normaux, arrêts sur image actifs")
	_check(is_equal_approx(GameSettings.haptics_strength(), 1.0), "défaut : intensité des vibrations 100 %")

	# --- Flashs : source unique, Quality suit
	GameSettings.set_flashes(1)
	_check(Quality.flashes_level == 1 and is_equal_approx(GameSettings.flash_scale(), 0.25), "flashs réduits -> Quality.flashes_level 1, ×0,25")
	GameSettings.set_flashes(0)
	_check(Quality.flashes_level == 0 and GameSettings.flash_scale() == 0.0 and GameSettings.flashes_level() == 0, "flashs aucun -> Quality 0, ×0")
	GameSettings.set_flashes(7)
	_check(GameSettings.flashes_level() == 2 and Quality.flashes_level == 2, "valeur hors bornes bornée à 2")

	# --- Secousses : pas de 10 %, indépendantes des flashs
	GameSettings.set_shake(0.43)
	_check(is_equal_approx(GameSettings.shake_scale(), 0.4), "secousses 43 % -> 40 % (pas de 10)")
	GameSettings.set_flashes(0)
	_check(is_equal_approx(GameSettings.shake_scale(), 0.4), "secousses indépendantes des flashs")
	GameSettings.set_flashes(2)
	GameSettings.set_shake(2.0)
	_check(is_equal_approx(GameSettings.shake_scale(), 1.0), "secousses bornées à 100 %")
	GameSettings.set_shake(0.0)
	_check(GameSettings.shake_scale() == 0.0, "secousses 0 %")
	var cf := ConfigFile.new()
	cf.load(TEST_CFG)
	_check(is_equal_approx(float(cf.get_value("gameplay", "shake", -1.0)), 0.0), "secousses écrites dans le fichier injecté")

	# --- Réduire les mouvements
	GameSettings.set_reduce_motion(true)
	_check(GameSettings.reduce_motion() and not GameSettings.hitstop_enabled(), "réduire les mouvements : plus d'arrêt sur image")
	_check(is_equal_approx(HpBarStyle.low_pulse(0.2, 0.0), HpBarStyle.low_pulse(0.2, 0.37)), "pulsation PV bas fixe (indépendante du temps)")
	GameSettings.set_reduce_motion(false)
	_check(not is_equal_approx(HpBarStyle.low_pulse(0.2, 0.0), HpBarStyle.low_pulse(0.2, 0.6)), "pulsation PV bas animée sinon")

	# --- LightRig.flash : point unique
	GameSettings.set_flashes(2)
	LightRig.clear_all()
	var h := LightRig.flash(Vector2.ZERO, &"default", 0.2, {"energy": 0.5})
	_check(is_equal_approx(h.energy_mult, 0.5), "flash complet : énergie inchangée")
	GameSettings.set_flashes(1)
	h = LightRig.flash(Vector2.ZERO, &"default", 0.2, {"energy": 0.5})
	_check(is_equal_approx(h.energy_mult, 0.125), "flash réduit : énergie ×0,25")
	GameSettings.set_flashes(0)
	h = LightRig.flash(Vector2.ZERO, &"default", 0.2)
	_check(h.energy_mult == 0.0, "flash aucun : énergie 0")
	GameSettings.set_flashes(2)
	LightRig.clear_all()
	var strong := 0
	for i in 6:
		var hh := LightRig.flash(Vector2.ZERO, &"default", 0.2, {"energy": 3.0})
		if hh.energy_mult > 0.0:
			strong += 1
	_check(strong == LightRig.FLASH_CAP_PER_S, "6 éclats forts d'affilée : %d passent (plafond %d/s)" % [strong, LightRig.FLASH_CAP_PER_S])
	var small := LightRig.flash(Vector2.ZERO, &"default", 0.2, {"energy": 0.3})
	_check(small.energy_mult > 0.0, "une petite lueur n'est pas plafonnée")
	LightRig.clear_all()

	# --- HurtFeedback
	var holder := Node.new()
	add_child(holder)
	var hf := HurtFeedback.ensure(holder)
	await _frames(1)
	GameSettings.set_flashes(2)
	hf.pulse(0.3)
	var full := hf.intensity()
	hf = HurtFeedback.new()
	add_child(hf)
	await _frames(1)
	GameSettings.set_flashes(1)
	hf.pulse(0.3)
	_check(hf.intensity() <= HurtFeedback.REDUCED_MAX_ALPHA + 0.001 and hf.intensity() < full, "vignette : plafonnée à 0,25 en flashs réduits (%.2f < %.2f)" % [hf.intensity(), full])
	var hf0 := HurtFeedback.new()
	add_child(hf0)
	await _frames(1)
	GameSettings.set_flashes(0)
	hf0.pulse(0.05)
	var a_small := hf0.intensity()
	hf0.pulse(0.5)
	_check(is_equal_approx(a_small, hf0.intensity()) and is_equal_approx(a_small, HurtFeedback.NONE_ALPHA), "vignette : cadre fixe sans flashs, même opacité quel que soit le coup")
	GameSettings.set_flashes(2)

	# --- Panneau
	GameSettings.reset_all(get_tree())
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var panel := SettingsPanel.new()
	host.add_child(panel)
	await _frames(3)
	_check(panel.shake_slider() != null and panel.reduce_motion_toggle() != null and panel.haptic_slider() != null and panel.flashes_stepper() != null, "panneau : 3 réglages + intensité des vibrations")
	panel.shake_slider().value = 0.3
	_check(is_equal_approx(GameSettings.shake_scale(), 0.3), "curseur Secousses -> GameSettings (0,3)")
	panel.reduce_motion_toggle().button_pressed = true
	_check(GameSettings.reduce_motion(), "bascule Réduire les mouvements -> GameSettings")
	panel.haptic_slider().value = 0.5
	_check(is_equal_approx(GameSettings.haptics_strength(), 0.5), "curseur Intensité des vibrations -> GameSettings")
	panel.flashes_stepper().index = 1
	panel.flashes_stepper().changed.emit(1)
	_check(Quality.flashes_level == 1, "stepper Flashs -> Quality synchronisé")
	panel.call(&"_do_reset")
	await _frames(1)
	_check(GameSettings.flashes_level() == 2 and Quality.flashes_level == 2 and is_equal_approx(GameSettings.shake_scale(), 1.0) \
		and not GameSettings.reduce_motion() and is_equal_approx(GameSettings.haptics_strength(), 1.0), "Réinitialiser : valeurs par défaut des 4 réglages")
	_check(is_equal_approx(panel.shake_slider().value, 1.0) and not panel.reduce_motion_toggle().button_pressed and is_equal_approx(panel.haptic_slider().value, 1.0), "Réinitialiser : contrôles resynchronisés")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	GameSettings.cfg_path = GameSettings.PATH
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
