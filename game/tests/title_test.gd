extends Node
## Écran titre, fond animé et crédits (lot C, docs/Design_Menus.md §3.1, §3.6, §4).
## godot --headless --path game res://tests/title_test.tscn

const TITLE := preload("res://scenes/menu/title.tscn")
const CREDITS := preload("res://scenes/menu/credits.tscn")
var _fails := 0
var _got: Array = []


## Profil factice : jamais le vrai profil du joueur (raccourci « relancer » du lot M-G).
class FakeProfile extends RefCounted:
	var stats := {"runs": 0}
	var last_character: StringName = &"ardent"
	var last_mode: StringName = &"moyen"


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)
	else:
		print("ok:   ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _btn(n: Node, txt: String) -> Button:
	if n is Button and (n as Button).text == txt:
		return n as Button
	for c in n.get_children():
		var r := _btn(c, txt)
		if r != null:
			return r
	return null


func _fake_save() -> Dictionary:
	return {"character": "ardent", "character_name": "Ardent", "mode": "moyen", "stage": 2, "active_time_s": 252.0,
		"map_id": "foret_brume", "saved_at": 0}


func _no_save() -> Dictionary:
	return {}


func _spawn(save: bool, ios := false) -> TitleScreen:
	var t := TITLE.instantiate() as TitleScreen
	# Jamais la vraie sauvegarde du joueur : provider vide quand il n'y a pas de sauvegarde.
	t.summary_provider = _fake_save if save else _no_save
	t.ios_override = ios
	t.profile_override = FakeProfile.new()
	t.photosensitivity_enabled = false
	add_child(t)
	return t


func _ready() -> void:
	Platform.set_input_mode(Platform.InputMode.KBM)
	await _frames(2)

	# --- Sans sauvegarde
	var t := _spawn(false)
	await _frames(5)
	_check(t.main_button.text == "Jouer", "sans sauvegarde : bouton principal « Jouer »")
	_check(t.new_run_button == null, "sans sauvegarde : pas de « Nouvelle run »")
	_check(t.main_button.subtitle == "", "sans sauvegarde : pas de sous-titre")
	_check(t.get_viewport().gui_get_focus_owner() == t.main_button, "KBM : focus initial sur le bouton principal")
	_check(Audio.current_map_id() == "menu", "Audio.current_map_id() == menu")
	var bg := t.background
	_check(bg.ambiance != null and bg.ambiance.map_light_count() > 0, "fond : AmbianceManager.map_light_count() > 0 (%d)" % (bg.ambiance.map_light_count() if bg.ambiance != null else -1))
	_check(bg.map != null and bg.map is StageMap, "fond : vraie carte StageMap (%s)" % bg.map_id)
	_check(bg.camera != null and bg.camera.is_current(), "fond : caméra courante")
	_check(bg.get_tree().get_first_node_in_group(&"director") == null, "fond : aucun Director")
	var p0 := bg.camera.position
	await _frames(30)
	_check(bg.camera.position != p0 or bg.camera.offset != Vector2.ZERO, "fond : la caméra bouge")
	_check(not "settings_icon_button" in t and t.root.find_child("SettingsIcon", true, false) == null, "M9 : icône Réglages retirée")
	_check(not t._version.text.contains("Godot") and t._version.get_theme_font_size(&"font_size") == 22 and is_equal_approx(t._version.modulate.a, 0.6), "M9 : version seule, 22 px, 60 %")
	_check(not t.hints_label.text.contains("—") and t.hints_label.text.contains("[Entrée] Valider"), "M9 : invites sans « — » (%s)" % t.hints_label.text)
	for b in [t.main_button, t.progress_button, t.settings_button, t.credits_button]:
		_check(b.custom_minimum_size.x >= 88 and b.custom_minimum_size.y >= 88, "%s >= 88 px" % b.name)
	_check(t.quit_button != null, "PC : bouton Quitter présent")

	# --- Signaux
	_got.clear()
	for sig in [&"new_run_requested", &"progress_requested", &"settings_requested", &"credits_requested"]:
		t.connect(sig, func(): _got.append(sig))
	t.main_button.pressed.emit()
	t.progress_button.pressed.emit()
	t.settings_button.pressed.emit()
	t.credits_button.pressed.emit()
	_check(_got == [&"new_run_requested", &"progress_requested", &"settings_requested", &"credits_requested"], "signaux des boutons : %s" % str(_got))

	# --- Quitter : confirmation
	_got.clear()
	t.quit_requested.connect(func(): _got.append(&"quit"))
	t.quit_button.pressed.emit()
	await _frames(3)
	_check(t._dialog_open, "Quitter : dialogue ouvert")
	var neutral := _btn(t.dialog, "Annuler")
	_check(neutral != null and t.get_viewport().gui_get_focus_owner() == neutral, "dialogue : focus sur l'action neutre")
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(3)
	_check(not t._dialog_open and _got.is_empty(), "Échap = Annuler (pas de quit_requested)")
	t.quit_button.pressed.emit()
	await _frames(3)
	_btn(t.dialog, "Quitter").pressed.emit()
	await _frames(3)
	_check(_got == [&"quit"], "Quitter confirmé -> quit_requested")

	# --- Toast
	t.show_toast("Sauvegarde incompatible : +12 rubis")
	_check(t.toast_label.visible and t.toast_label.text.begins_with("Sauvegarde"), "toast affiché")
	t.queue_free()
	await _frames(3)

	# --- Avec sauvegarde
	t = _spawn(true)
	await _frames(5)
	_check(t.main_button.text == "Reprendre", "avec sauvegarde : « Reprendre »")
	_check(t.main_button.subtitle == "Ardent · Étage 2 · Moyen · 04:12", "sous-titre : « %s »" % t.main_button.subtitle)
	_check(t.new_run_button != null, "avec sauvegarde : « Nouvelle run »")
	_check(t.background.map_id == "foret_brume", "fond : carte de la run sauvegardée")
	_got.clear()
	t.resume_requested.connect(func(): _got.append(&"resume"))
	t.new_run_requested.connect(func(): _got.append(&"new"))
	t.main_button.pressed.emit()
	_check(_got == [&"resume"], "Reprendre -> resume_requested")
	t.new_run_button.pressed.emit()
	await _frames(3)
	_check(t._dialog_open and _got == [&"resume"], "Nouvelle run : confirmation d'écrasement")
	_btn(t.dialog, "Annuler").pressed.emit()
	await _frames(3)
	_check(_got == [&"resume"], "Annuler : pas de new_run_requested")
	t.new_run_button.pressed.emit()
	await _frames(3)
	_btn(t.dialog, "Remplacer").pressed.emit()
	await _frames(3)
	_check(_got == [&"resume", &"new"], "Remplacer -> new_run_requested")
	# refresh() relit les données
	t.summary_provider = _no_save
	t.refresh()
	_check(not t.has_save and t.main_button.text == "Jouer", "refresh() sans sauvegarde -> « Jouer »")
	t.summary_provider = _fake_save
	t.refresh()
	_check(t.has_save and t.main_button.text == "Reprendre", "refresh() avec sauvegarde -> « Reprendre »")
	t.queue_free()
	await _frames(3)

	# --- iOS : pas de Quitter
	t = _spawn(false, true)
	await _frames(5)
	_check(t.quit_button == null, "iOS : pas de bouton Quitter")
	t.queue_free()
	await _frames(3)

	# --- Tactile : aucun focus
	Platform.set_input_mode(Platform.InputMode.TOUCH)
	t = _spawn(false)
	await _frames(5)
	_check(t.get_viewport().gui_get_focus_owner() == null, "tactile : aucun focus")
	_check(not t.hints_label.visible, "tactile : bandeau d'invites masqué")
	Platform.set_input_mode(Platform.InputMode.KBM)
	await _frames(3)
	_check(t.get_viewport().gui_get_focus_owner() == t.main_button and t.hints_label.visible, "retour KBM : focus + invites")
	# Pause visuelle du fond
	t.background.set_paused_visuals(true)
	var cp := t.background.camera.position
	await _frames(10)
	_check(t.background.camera.position == cp, "set_paused_visuals(true) fige la caméra")
	t.background.set_paused_visuals(false)
	t.queue_free()
	await _frames(3)

	# --- M16 : relance rapide après la 1re run (profil factice)
	var fp := FakeProfile.new()
	fp.stats = {"runs": 3}
	fp.last_character = &"ardent"
	fp.last_mode = &"difficile"
	t = TITLE.instantiate() as TitleScreen
	t.summary_provider = _no_save
	t.profile_override = fp
	t.photosensitivity_enabled = false
	add_child(t)
	await _frames(5)
	_check(t.main_button.text == "Jouer" and t.main_button.subtitle == "Ardent · Difficile", "M16 : sous-titre « %s »" % t.main_button.subtitle)
	var quick: Array = []
	t.quick_start_requested.connect(func(cfg: Dictionary) -> void: quick.append(cfg))
	_got.clear()
	t.new_run_requested.connect(func(): _got.append(&"new"))
	t.main_button.button_down.emit()
	await get_tree().create_timer(TitleScreen.QUICK_HOLD_S + 0.2).timeout
	t.main_button.button_up.emit()
	t.main_button.pressed.emit() # relâcher après l'appui long : pas d'écran Nouvelle run
	_check(quick.size() == 1 and quick[0].get("character") == &"ardent" and quick[0].get("mode") == &"difficile" and not quick[0].has("label"), "M16 : appui long -> quick_start_requested %s" % str(quick))
	_check(_got.is_empty(), "M16 : l'appui long n'ouvre pas Nouvelle run")
	t.main_button.button_down.emit()
	t.main_button.button_up.emit()
	t.main_button.pressed.emit()
	_check(_got == [&"new"] and quick.size() == 1, "M16 : appui court -> Nouvelle run")
	Platform.set_input_mode(Platform.InputMode.GAMEPAD)
	await _frames(2)
	_check(t.hints_label.text.contains("[Y] Relancer Ardent · Difficile"), "M16 : invite manette [Y] (%s)" % t.hints_label.text)
	var y := InputEventJoypadButton.new()
	y.button_index = JOY_BUTTON_Y
	y.pressed = true
	t._input(y)
	_check(quick.size() == 2, "M16 : [Y] -> relance")
	Platform.set_input_mode(Platform.InputMode.KBM)
	t.queue_free()
	await _frames(3)

	# --- Avertissement de photosensibilité (fichier de réglages injecté)
	var real_cfg := GameSettings.cfg_path
	GameSettings.cfg_path = "user://test_title_photo.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	t = TITLE.instantiate() as TitleScreen
	t.summary_provider = _no_save
	t.profile_override = FakeProfile.new()
	t.photosensitivity_enabled = true
	add_child(t)
	await _frames(5)
	_check(t._dialog_open and t.dialog != null and _btn(t.dialog, "Réduire flashs et secousses") != null, "1er lancement : avertissement de photosensibilité")
	_btn(t.dialog, "Réduire flashs et secousses").pressed.emit()
	await _frames(3)
	_check(not t._dialog_open and GameSettings.photosensitivity_seen(), "avertissement : vu, enregistré")
	_check(GameSettings.flashes_level() == 1 and is_equal_approx(GameSettings.shake_scale(), TitleScreen.PHOTO_REDUCED_SHAKE), "Réduire : flashs réduits, secousses 30 %")
	t.queue_free()
	await _frames(3)
	t = TITLE.instantiate() as TitleScreen
	t.summary_provider = _no_save
	t.profile_override = FakeProfile.new()
	t.photosensitivity_enabled = true
	add_child(t)
	await _frames(5)
	_check(not t._dialog_open, "2e lancement : plus d'avertissement")
	t.queue_free()
	await _frames(3)
	GameSettings.reset_all(get_tree())
	_check(GameSettings.photosensitivity_seen(), "Réinitialiser ne fait pas revenir l'avertissement")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.cfg_path))
	GameSettings.cfg_path = real_cfg
	GameSettings.apply_graphics()

	# --- Crédits
	var c := CREDITS.instantiate() as CreditsScreen
	add_child(c)
	await _frames(5)
	_got.clear()
	c.back_requested.connect(func(): _got.append(&"back"))
	var y0 := c.scroll_content.position.y
	await _frames(20)
	_check(c.scroll_content.position.y < y0, "crédits : le texte défile")
	c.back_button.pressed.emit()
	c.back_button.pressed.emit()
	_check(_got == [&"back"], "crédits : Retour émet back_requested une fois")
	c.queue_free()
	await _frames(3)

	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
