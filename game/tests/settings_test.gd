extends Node
## Lot E : panneau de réglages unifié, commandes, pause, appui long du bouton pause.
## godot --headless --path game res://tests/settings_test.tscn
## En headless, GameSettings / Audio n'écrivent aucun fichier.

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
	GameSettings.cfg_path = "user://test_settings_test.cfg" # fichier injecté : le réglage réel du joueur n est ni lu ni écrit
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	var existed_before := FileAccess.file_exists(GameSettings.PATH)
	var mtime_before := FileAccess.get_modified_time(GameSettings.PATH) if existed_before else 0

	# --- SettingsPanel seul
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(host)
	var panel := SettingsPanel.new()
	host.add_child(panel)
	await _frames(3)
	var rows := panel.rows()
	var small := 0
	for r in rows:
		if r.custom_minimum_size.y < 88.0:
			small += 1
	_check(rows.size() >= 12 and small == 0, "%d lignes de réglage, toutes >= 88 px" % rows.size())

	var sl := panel.slider("music")
	sl.value = 0.35
	_check(absf(Audio.get_volume("music") - 0.35) < 0.001, "curseur Musique -> Audio.set_volume (%.2f)" % Audio.get_volume("music"))
	Audio.set_volume("sfx", 0.5)
	panel.sync()
	_check(absf(panel.slider("sfx").value - 0.5) < 0.001, "sync() relit les volumes")

	var st := panel.quality_stepper()
	st.index = 3 # -> Haut
	st.changed.emit(3)
	_check(st.index == 3 and GameSettings.quality_choice() == 2, "stepper Qualité Haut -> quality_choice() == 2 (%d)" % GameSettings.quality_choice())
	_check(panel.quality_stepper().items.size() == 4, "4 paliers de qualité")

	GameSettings.set_flashes(0)
	GameSettings.reset_all(get_tree())
	panel.sync()
	_check(GameSettings.quality_choice() == -1 and GameSettings.flashes_level() == 2, "reset_all : qualité auto, flashs complets")
	_check(absf(Audio.get_volume("music") - 0.8) < 0.001 and absf(Audio.get_volume("sfx") - 1.0) < 0.001, "reset_all : volumes par défaut")
	_check(not GameSettings.show_fps() and GameSettings.haptics() and GameSettings.damage_text_index() == 1 and GameSettings.colorblind() == 0, "valeurs par défaut des nouvelles clés")
	_check(GameSettings.pause_long_press() == Platform.is_mobile(), "appui long : défaut = mobile")

	# confirmation de la réinitialisation
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	panel.call(&"_ask_reset")
	await _frames(2)
	_check(panel.is_confirming(), "confirmation de réinitialisation (ConfirmDialog)")
	panel._dialog._finish(false)
	await _frames(2)
	_check(not panel.is_confirming(), "annuler ferme la confirmation")
	var backs := [0]
	panel.back_requested.connect(func() -> void: backs[0] += 1)
	panel._unhandled_input(esc)
	_check(backs[0] == 1, "ui_cancel -> back_requested")

	# --- Vague 2 (agent « Réglages ») : onglets, interrupteurs, nouvelles clés
	var labels := panel.row_labels()
	_check(panel.tab_buttons().size() == 4 and panel.tab_buttons()[3].text == "Accessibilité", "M11 : 4 onglets")
	for tb in panel.tab_buttons():
		_check(tb.custom_minimum_size.y >= 88.0, "onglet « %s » >= 88 px" % tb.text)
	_check(not labels.has("Style de rendu") and not labels.has("Afficher la hitbox") and labels.has("Cercle de collision du héros"), "M11 : « Style de rendu » retiré, hitbox renommée")
	panel.show_tab(SettingsPanel.Tab.ACCESS, false)
	_check(panel.current_tab() == SettingsPanel.Tab.ACCESS and panel._pages[3].visible and not panel._pages[0].visible, "show_tab : une seule page visible")
	var rb := InputEventJoypadButton.new()
	rb.button_index = JOY_BUTTON_RIGHT_SHOULDER
	rb.pressed = true
	panel._unhandled_input(rb)
	_check(panel.current_tab() == SettingsPanel.Tab.AUDIO, "RB : onglet suivant (boucle)")
	var tg := panel.toggle("Astuces de jeu")
	_check(tg != null and tg.custom_minimum_size.x >= 160.0 and tg.custom_minimum_size.y >= 88.0, "interrupteur visuel 160×88")
	_check(GameSettings.hints() and tg.button_pressed, "Astuces de jeu : défaut activé")
	tg.button_pressed = false
	_check(not GameSettings.hints() and bool(GameSettings.get_value("gameplay", "hints", true)) == false, "Astuces de jeu -> gameplay/hints")
	var stg := panel.toggle("Télégraphes renforcés")
	_check(not GameSettings.strong_telegraphs() and not stg.button_pressed, "Télégraphes renforcés : défaut désactivé")
	stg.button_pressed = true
	_check(bool(GameSettings.get_value("accessibility", "strong_telegraphs", false)), "Télégraphes renforcés -> accessibility/strong_telegraphs")
	panel.toggle("Audio mono").button_pressed = true
	_check(GameSettings.mono_audio(), "Audio mono -> accessibility/mono_audio")
	var cr := panel.chest_reveal_stepper()
	_check(GameSettings.chest_reveal() == "complete" and cr.index == 0 and cr.items.size() == 3, "Animation des coffres : défaut Complète")
	cr.index = 1
	cr.changed.emit(1)
	_check(GameSettings.chest_reveal() == "short" and GameSettings.chest_reveal_mult() == [0.5, 0.6], "Courte -> chest_reveal short, durées ×0,5 / ×0,6")
	cr.index = 2
	cr.changed.emit(2)
	_check(GameSettings.chest_reveal() == "instant" and GameSettings.chest_reveal_mult() == [0.0, 0.0], "Instantanée")
	GameSettings.set_value("gameplay", "chest_reveal", "n'importe quoi")
	_check(GameSettings.chest_reveal() == "complete", "valeur inconnue -> Complète")
	# Taille de l'interface : 80-150 %, défaut selon la plateforme, recalcul du HUD
	var k := HudMetrics.MOBILE_K if Platform.is_mobile() else 1.0
	_check(is_equal_approx(GameSettings.ui_scale(), k) and is_equal_approx(HudMetrics.user_scale(), 1.0), "Taille de l'interface : défaut %d %% (user_scale 1)" % roundi(k * 100.0))
	var us := panel.ui_scale_slider()
	_check(is_equal_approx(us.min_value, 0.8) and is_equal_approx(us.max_value, 1.5) and is_equal_approx(us.step, 0.1), "curseur 80-150 %, pas de 10 %")
	var relayouts := [0]
	var on_size := func() -> void: relayouts[0] += 1
	get_tree().root.size_changed.connect(on_size)
	us.value = 1.2
	_check(is_equal_approx(float(GameSettings.get_value("gameplay", "ui_scale", 0.0)), 1.2) and relayouts[0] >= 1, "curseur -> gameplay/ui_scale 1,2 + size_changed (%d)" % relayouts[0])
	_check(is_equal_approx(HudMetrics.user_scale(), 1.2 / k), "HudMetrics.user_scale = ui_scale / facteur plateforme")
	get_tree().root.size_changed.disconnect(on_size)
	GameSettings.set_ui_scale(3.0)
	_check(is_equal_approx(GameSettings.ui_scale(), 1.5), "ui_scale borné à 150 %")
	# Confort (A11y-L9) : zone morte, joystick, réticule
	var dz := panel.deadzone_slider()
	_check(is_equal_approx(GameSettings.stick_deadzone(), 0.2) and is_equal_approx(dz.min_value, 0.1) and is_equal_approx(dz.max_value, 0.35), "Zone morte : 10-35 %, défaut 20 %")
	dz.value = 0.3
	_check(is_equal_approx(GameSettings.stick_deadzone(), 0.3), "Zone morte -> accessibility/stick_deadzone")
	panel.joystick_slider().value = 1.3
	_check(is_equal_approx(GameSettings.joystick_scale(), 1.3), "Taille du joystick -> accessibility/joystick_scale")
	GameSettings.set_reticle_scale(1.5)
	panel.sync()
	_check(is_equal_approx(GameSettings.reticle_scale(), 1.5) and panel._reticle.index == 1, "Taille du réticule 150 %")
	_check(panel._joystick_row.visible == Platform.has_touch() and panel._reticle_row.visible == Platform.is_pc(), "lignes selon le matériel")
	_check(panel.toggle("Vibrations") != null, "Vibrations (mobile ou manette)")
	# Réinitialiser : tout revient
	GameSettings.reset_all(get_tree())
	panel.sync()
	_check(GameSettings.hints() and not GameSettings.strong_telegraphs() and not GameSettings.mono_audio() and GameSettings.chest_reveal() == "complete" \
		and is_equal_approx(GameSettings.ui_scale(), k) and is_equal_approx(GameSettings.stick_deadzone(), 0.2) and is_equal_approx(GameSettings.joystick_scale(), 1.0), "reset_all : nouvelles clés par défaut")
	_check(panel.toggle("Astuces de jeu").button_pressed and not panel.toggle("Télégraphes renforcés").button_pressed, "reset_all : interrupteurs resynchronisés")
	host.queue_free()

	# --- Commandes
	var cp := ControlsPanel.new()
	add_child(cp)
	await _frames(2)
	_check(cp.tab_mode == Platform.input_mode, "onglet initial = mode courant")
	var kb: Array = cp.texts()
	_check(kb.has("Déplacement") and kb.has("Pause"), "onglet Clavier : lignes de commandes")
	cp.show_mode(Platform.InputMode.GAMEPAD)
	_check(cp.texts().has("Stick gauche / croix") and Platform.input_mode == Platform.InputMode.KBM, "onglet Manette sans changer le mode réel")
	_check(cp.tab_modes().has(Platform.InputMode.TOUCH) == Platform.has_touch(), "onglet Tactile seulement si écran tactile")
	cp.queue_free()

	# --- Pause
	RunState.items.clear()
	var pm := PauseMenu.new()
	add_child(pm)
	await _frames(2)
	pm.open()
	await _frames(2)
	_check(get_tree().paused and pm._panel_main.visible, "pause ouverte sur le menu principal")
	_check(pm._items_button.text.begins_with("Objets ("), "bouton « Objets (N) » conservé")
	pm._show_only(pm._panel_settings)
	await _frames(2)
	_check(pm._panel_settings.is_visible_in_tree() and not pm._panel_main.visible, "pause : panneau de réglages ouvert")
	pm._panel_settings.controls_requested.emit()
	await _frames(2)
	_check(pm._panel_controls.is_visible_in_tree() and pm.controls_texts().has("Déplacement"), "pause : Commandes depuis Réglages")
	pm._unhandled_input(esc)
	_check(pm._panel_settings.is_visible_in_tree(), "ui_cancel : Commandes -> Réglages")
	pm._unhandled_input(esc)
	_check(pm._panel_main.visible and not pm._panel_settings.visible, "ui_cancel : Réglages -> menu pause")
	pm._show_only(pm._panel_confirm)
	await _frames(2)
	_check(pm._abandon_dialog != null, "Abandonner : ConfirmDialog ouvert")
	var ab := [0]
	pm.abandon_requested.connect(func() -> void: ab[0] += 1)
	pm._abandon_dialog._finish(false)
	await _frames(2)
	_check(pm._panel_main.visible and ab[0] == 0, "Annuler : retour au menu pause")
	pm._show_only(pm._panel_confirm)
	await _frames(2)
	pm._abandon_dialog._finish(true)
	await _frames(2)
	_check(ab[0] == 1, "Abandonner : abandon_requested")
	pm.open()
	await _frames(2)
	var sq := [0]
	pm.save_quit_requested.connect(func() -> void: sq[0] += 1)
	pm._on_save_quit()
	_check(sq[0] == 1 and not get_tree().paused, "Sauvegarder et quitter émet save_quit_requested")
	pm.queue_free()

	# --- Bouton pause : appui simple sur PC, long sinon
	var pb := PauseButton.new()
	add_child(pb)
	var fired := [0]
	pb.long_pressed.connect(func() -> void: fired[0] += 1)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	pb._gui_input(ev)
	if not GameSettings.pause_long_press():
		_check(fired[0] == 1, "bouton pause : appui simple (PC)")
	else:
		_check(fired[0] == 0, "bouton pause : appui long requis (mobile)")
	pb.queue_free()

	_check(FileAccess.file_exists(GameSettings.PATH) == existed_before and (not existed_before or FileAccess.get_modified_time(GameSettings.PATH) == mtime_before), "headless : settings.cfg inchangé")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
