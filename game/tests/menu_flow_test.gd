extends Node
## Parcours complet des menus sur la vraie app.tscn (lot F, docs/Design_Menus.md §8) :
## titre → Jouer → Nouvelle run → Commencer → jeu → pause → Sauvegarder et quitter → titre « Reprendre »
## → Reprendre (même étage) → Abandonner → récap → Continuer → titre sans sauvegarde.
## Aucune écriture dans la vraie sauvegarde : chemin de test user://test_menu_flow.json.
## Profil isolé : chemin de test, écriture coupée, profil par défaut (dernier personnage = Ardent) ; le vrai
## profil du joueur n'est ni lu pendant le test ni écrit (comme save_test).
## godot --headless --path game res://tests/menu_flow_test.tscn  → « RESULT: OK »

const APP_SCENE := preload("res://scenes/app.tscn")
const TEST_SAVE := "user://test_menu_flow.json"
const TEST_PROFILE := "user://test_menu_flow_profile.json"

var _fails: Array[String] = []
var app: App


func _check(cond: bool, what: String) -> void:
	if not cond:
		_fails.append(what)
		printerr("FAIL: ", what)


func _until(cond: Callable, what: String, timeout_s := 40.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if (Time.get_ticks_msec() - t0) / 1000.0 > timeout_s:
			_check(false, "délai dépassé : " + what)
			return false
		await get_tree().process_frame
	return true


func _on_title() -> bool:
	return app.current is TitleScreen and not app.busy and app.fade.alpha() < 0.05


func _btn_text(t: TitleScreen) -> String:
	return t.main_button.text if t.main_button != null else ""


func _ready() -> void:
	RunSave.delete(TEST_SAVE)
	Profile.path = TEST_PROFILE
	Profile.write_enabled = false
	Profile.reset()
	app = APP_SCENE.instantiate() as App
	app.save_path = TEST_SAVE
	app.saves_in_headless = true
	add_child(app)

	# 1. Titre, sans sauvegarde, aucun Director.
	await _until(_on_title, "titre affiché")
	var title := app.current as TitleScreen
	_check(title != null and not title.has_save, "titre sans sauvegarde")
	_check(title != null and _btn_text(title) == "Jouer", "bouton principal « Jouer » (lu : %s)" % _btn_text(title))
	_check(get_tree().get_nodes_in_group("director").size() == 0, "aucun Director au titre")
	_check(Audio.current_map_id() == "menu", "musique de menu au titre")

	# 2. Jouer → Nouvelle run.
	title.main_button.pressed.emit()
	await _until(func() -> bool: return app.current is NewRunScreen and not app.busy, "écran Nouvelle run")
	var nr := app.current as NewRunScreen
	_check(nr != null and nr.start_button != null and not nr.start_button.disabled, "Commencer actif (Ardent)")

	# 2b. Retour arrière puis Progression, Réglages, Crédits : chacun revient au titre.
	nr.back_requested.emit()
	await _until(_on_title, "retour titre depuis Nouvelle run")
	for pair in [[&"progress", ProgressScreen], [&"settings", SettingsScreen], [&"credits", CreditsScreen]]:
		await app.show(pair[0])
		await _until(func() -> bool: return is_instance_of(app.current, pair[1]) and not app.busy, "écran " + String(pair[0]))
		_check(is_instance_of(app.current, pair[1]), "show(%s)" % pair[0])
		app.current.back_requested.emit()
		await _until(_on_title, "retour titre depuis " + String(pair[0]))
	_check(get_tree().get_nodes_in_group("director").size() == 0, "aucun Director après la navigation")

	# 3. Nouvelle run → jeu.
	title = app.current as TitleScreen
	title.main_button.pressed.emit()
	await _until(func() -> bool: return app.current is NewRunScreen and not app.busy, "Nouvelle run (2)")
	nr = app.current as NewRunScreen
	nr.start_button.pressed.emit()
	await _until(func() -> bool: return app.main != null and bool(app.main.get(&"is_ready")), "game_ready")
	_check(app.main != null, "scène de jeu instanciée")
	_check(StringName(str(app.main.get(&"run_mode"))) == RunState.mode, "run_mode transmis")
	_check(int(app.main.get(&"run_seed")) == 0, "run_seed = 0 (aléatoire)")
	_check(RunState.character == &"ardent", "RunState.character = ardent")
	_check(Audio.current_map_id() != "menu" and Audio.current_map_id() != "", "musique de carte en jeu (%s)" % Audio.current_map_id())
	_check(get_tree().get_nodes_in_group("director").size() == 1, "un Director en jeu")
	await get_tree().create_timer(0.5).timeout
	var stage_before := RunState.stage

	# 4. Pause → Sauvegarder et quitter → titre « Reprendre ».
	var pm: PauseMenu = app.main.get(&"hud").get(&"pause_menu")
	pm.open()
	_check(pm.is_open and get_tree().paused, "pause ouverte")
	pm.save_quit_requested.emit()
	await _until(_on_title, "retour au titre après Sauvegarder et quitter")
	title = app.current as TitleScreen
	_check(RunSave.exists(TEST_SAVE), "sauvegarde écrite")
	_check(title != null and title.has_save and _btn_text(title) == "Reprendre", "bouton « Reprendre » (lu : %s)" % _btn_text(title))
	_check(title != null and title.new_run_button != null, "bouton « Nouvelle run » présent")
	_check(app.main == null and get_tree().get_nodes_in_group("director").size() == 0, "plus de Director au titre")
	_check(not get_tree().paused, "arbre dépausé au titre")

	# 5. Reprendre → même étage.
	title.main_button.pressed.emit()
	await _until(func() -> bool: return app.main != null and bool(app.main.get(&"is_ready")), "reprise : game_ready")
	_check(RunState.stage == stage_before, "même étage après reprise (%d / %d)" % [RunState.stage, stage_before])
	_check(RunState.character == &"ardent", "personnage conservé à la reprise")

	# 6. Abandonner → récap → Continuer → titre sans sauvegarde.
	pm = app.main.get(&"hud").get(&"pause_menu")
	pm.abandon_requested.emit()
	await _until(func() -> bool: return app.main != null and app.main.get(&"end_screen") != null, "récap de fin de run")
	var es: EndRunScreen = app.main.get(&"end_screen")
	_check(es != null, "récap affiché")
	es.continue_pressed.emit()
	await _until(_on_title, "retour au titre après le récap")
	title = app.current as TitleScreen
	_check(not RunSave.exists(TEST_SAVE), "sauvegarde supprimée en fin de run")
	_check(title != null and not title.has_save and _btn_text(title) == "Jouer", "titre sans sauvegarde (lu : %s)" % _btn_text(title))
	_check(get_tree().get_nodes_in_group("director").size() == 0, "aucun Director à la fin")

	# 7. Rejouer : même config, nouvelle run.
	app.start_run({"character": &"ardent", "mode": &"facile", "spells": {}})
	await _until(func() -> bool: return app.main != null and bool(app.main.get(&"is_ready")), "run (rejouer)")
	app.main.call(&"end_run", false, &"abandon")
	await _until(func() -> bool: return app.main.get(&"end_screen") != null, "récap (2)")
	(app.main.get(&"end_screen") as EndRunScreen).replay_pressed.emit()
	await get_tree().create_timer(0.3).timeout
	await _until(func() -> bool: return app.main != null and bool(app.main.get(&"is_ready")) and not app.busy, "rejouer : nouvelle run")
	_check(RunState.mode == &"facile", "Rejouer garde le mode (%s)" % RunState.mode)
	_check(get_tree().get_nodes_in_group("director").size() == 1, "un seul Director après Rejouer")

	RunSave.delete(TEST_SAVE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PROFILE))
	Profile.path = Profile.PATH
	Profile.load_profile() # relecture seule du vrai profil (write_enabled reste faux)
	if _fails.is_empty():
		print("RESULT: OK")
	else:
		print("RESULT: FAIL (%d)" % _fails.size())
	get_tree().quit(0 if _fails.is_empty() else 1)
