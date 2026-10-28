extends Node
## Succès locaux : données, conditions, progression, écouteurs (MetaTracker), mode test, bac à sable, migration du profil.
## godot --headless --path game res://tests/achievements_test.tscn
## Le profil est l'autoload en mémoire (jamais écrit en headless), remis à zéro au début et à la fin.

var _fails := 0
var _tracker: MetaTracker


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("ok   ", msg)
	else:
		_fails += 1
		print("FAIL ", msg)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


class FakeBoss extends Node2D:
	var bid := ""
	func boss_id() -> String:
		return bid


func _boss(id: String) -> FakeBoss:
	var b := FakeBoss.new()
	b.bid = id
	add_child(b)
	return b


func _ready() -> void:
	Profile.write_enabled = false
	Profile.reset()
	RunState.running = false
	TestMode.active = false

	# --- données ---
	Achievements.reset_cache()
	var defs := Achievements.all()
	_check(defs.size() >= 20 and defs.size() <= 30, "20 à 30 succès (%d)" % defs.size())
	var ids := {}
	var types := ["stat", "floor_cleared", "run_victory", "run_time", "boss_count", "boss_floor_set", "boss_all", "win_characters",
		"chest_quality", "run_items", "run_stacks", "run_level", "daily_completed", "daily_streak"]
	var all_ok := true
	var icons_ok := true
	for a in defs:
		var id := str(a["id"])
		if ids.has(id) or str(a.get("name", "")) == "" or str(a.get("desc", "")) == "" or not types.has(str((a["cond"] as Dictionary).get("type", ""))):
			all_ok = false
			print("  mauvaise définition : ", id)
		ids[id] = true
		if Achievements.icon_of(a) == null:
			icons_ok = false
			print("  icône introuvable : ", id)
	_check(all_ok, "ids uniques, textes présents, types connus")
	_check(icons_ok, "chaque succès a une icône existante (objets, portraits, UI)")

	# --- conditions pures ---
	_check(Achievements.evaluate(Profile, {}).is_empty(), "profil vierge : rien de débloqué")
	Profile.stats["kills"] = 1
	var got := Achievements.evaluate(Profile, {})
	_check(got.size() == 1 and str(got[0]["id"]) == "first_blood", "1 kill -> Première goutte")
	_check(Profile.is_achievement_unlocked("first_blood") and not Profile.unlock_achievement("first_blood"), "déblocage unique")
	var pr := Achievements.progress(Profile, Achievements.def_of("kills_1000"))
	_check(int(pr["cur"]) == 1 and int(pr["max"]) == 1000, "progression kills 1/1000")
	Achievements.evaluate(Profile, {"stage": 1})
	_check(Profile.is_achievement_unlocked("floor_1") and not Profile.is_achievement_unlocked("floor_2"), "étage 1 nettoyé seulement")
	var f1 := Achievements.floor_bosses(1)
	_check(f1.size() >= 1, "boss de l'étage 1 lus dans floors.json (%d)" % f1.size())
	for b in f1:
		Profile.add_boss_kill(str(b))
	Achievements.evaluate(Profile, {})
	_check(Profile.is_achievement_unlocked("boss_first") and Profile.is_achievement_unlocked("boss_floor_1") and not Profile.is_achievement_unlocked("boss_floor_2"),
		"tous les boss de l'étage 1 -> Maître des terrasses")
	_check(not Profile.is_achievement_unlocked("boss_all"), "boss_all pas encore")
	for n in range(1, 8):
		for b in Achievements.floor_bosses(n):
			Profile.add_boss_kill(str(b))
	Achievements.evaluate(Profile, {})
	_check(Profile.is_achievement_unlocked("boss_all"), "tous les boss d'étage -> Tueur de légendes")
	# victoires
	Achievements.evaluate(Profile, {"run_end": true, "victory": false, "mode": "difficile", "time_s": 100.0})
	_check(not Profile.is_achievement_unlocked("win_run"), "défaite : pas de victoire")
	Achievements.evaluate(Profile, {"run_end": true, "victory": true, "mode": "moyen", "time_s": 1500.0})
	_check(Profile.is_achievement_unlocked("win_run") and not Profile.is_achievement_unlocked("win_hard") and not Profile.is_achievement_unlocked("win_fast"),
		"victoire Moyen lente : seulement win_run")
	Achievements.evaluate(Profile, {"run_end": true, "victory": true, "mode": "difficile", "time_s": 1000.0})
	_check(Profile.is_achievement_unlocked("win_hard") and Profile.is_achievement_unlocked("win_fast"), "victoire Difficile en 1000 s : win_hard + win_fast")
	Achievements.evaluate(Profile, {"run_end": true, "time_s": 901.0})
	_check(Profile.is_achievement_unlocked("survive_15"), "15 minutes tenues")
	Achievements.evaluate(Profile, {"quality": "legendaire"})
	_check(Profile.is_achievement_unlocked("chest_legendary"), "coffre légendaire")
	# personnages gagnants (best_runs)
	var cast := Achievements.win_roster()
	_check(cast.size() >= 3, "roster à gagner (%d, sans les cachés)" % cast.size())
	Profile.best_runs = {str(cast[0]): {"moyen": {"time_s": 1.0}}, str(cast[1]): {"moyen": {"time_s": 1.0}}}
	Achievements.evaluate(Profile, {})
	_check(not Profile.is_achievement_unlocked("win_chars_3"), "2 personnages gagnés : pas encore 3")
	Profile.best_runs[str(cast[2])] = {"moyen": {"time_s": 1.0}}
	Achievements.evaluate(Profile, {})
	_check(Profile.is_achievement_unlocked("win_chars_3") and not Profile.is_achievement_unlocked("win_chars_all"), "3 personnages gagnés")
	for c in cast:
		Profile.best_runs[str(c)] = {"moyen": {"time_s": 1.0}}
	Achievements.evaluate(Profile, {})
	_check(Profile.is_achievement_unlocked("win_chars_all"), "chaque personnage gagné")
	# run en cours
	RunState.running = true
	RunState.items = {&"a": 3, &"b": 5, &"c": 12}
	RunState.level = 15
	Achievements.evaluate(Profile, {})
	_check(Profile.is_achievement_unlocked("items_run_20") and Profile.is_achievement_unlocked("stack_5") and Profile.is_achievement_unlocked("level_15"),
		"objets (20), exemplaires (5), niveau (15)")
	RunState.items = {}
	RunState.level = 1
	RunState.running = false
	# kills en direct = profil + run en cours
	Profile.stats["kills"] = 990
	RunState.running = true
	RunState.kills = 10
	_check(Achievements.stat_value(Profile, "kills") == 1000.0, "kills = profil + run en cours")
	RunState.running = false
	RunState.kills = 0

	# --- écouteurs ---
	Profile.reset()
	_tracker = MetaTracker.new()
	add_child(_tracker)
	await _frames(2)
	Events.floor_cleared.emit(1)
	_check(Profile.is_achievement_unlocked("floor_1"), "floor_cleared(1) -> succès")
	_check(_tracker.toast.pending() >= 1 or not _tracker.toast.current.is_empty(), "notification en file")
	Events.chest_opened.emit(null, &"legendaire", [])
	_check(Profile.is_achievement_unlocked("chest_legendary") and Profile.stat("chests_opened") == 1.0, "coffre légendaire écouté + compteur de coffres")
	var fb := _boss("eclusier")
	Events.boss_killed.emit(fb, true)
	_check(int(Profile.boss_kills.get("eclusier", 0)) == 1 and Profile.is_achievement_unlocked("boss_first"), "boss d'étage compté")
	var mb := _boss("frost_bear")
	Events.boss_killed.emit(mb, false)
	_check(Profile.stat("minis_killed") == 1.0 and not Profile.boss_kills.has("frost_bear"), "mini-boss compté à part")
	Events.pillar_state_changed.emit(null, &"done")
	_check(Profile.stat("pillars_done") == 1.0, "pilier terminé compté")
	Events.item_chosen.emit(&"x")
	_check(Profile.stat("items_picked") == 1.0, "objet choisi compté")
	# kills en direct par seuil
	Profile.stats["kills"] = 998
	RunState.running = true
	RunState.kills = 0
	_tracker._refresh_kill_goal()
	Events.enemy_killed.emit(null, Vector2.ZERO, 1, false) # RunState compte 1 : 999 au total
	_check(not Profile.is_achievement_unlocked("kills_1000"), "999 kills : pas encore")
	Events.enemy_killed.emit(null, Vector2.ZERO, 1, false)
	_check(Profile.is_achievement_unlocked("kills_1000"), "1000e kill en direct -> Averse de lames")
	RunState.running = false
	RunState.kills = 0
	# fin de run
	RunState.mode = &"difficile"
	RunState.active_time_s = 600.0
	RunState.stage = 5
	Events.run_finished.emit(true, &"victory")
	_check(not Profile.is_achievement_unlocked("win_run"), "évalué après la fin synchrone (différé)")
	await _frames(2)
	_check(Profile.is_achievement_unlocked("win_run") and Profile.is_achievement_unlocked("win_hard") and Profile.is_achievement_unlocked("win_fast"),
		"fin de run victorieuse : win_run, win_hard, win_fast")
	# interface de services de plateforme : vide, sans effet
	_check(not PlatformServices.current.is_available(), "services de plateforme : interface vide")

	# --- mode test : rien n'est écrit ---
	Profile.reset()
	TestMode.active = true
	Events.floor_cleared.emit(1)
	Events.chest_opened.emit(null, &"legendaire", [])
	Events.boss_killed.emit(fb, true)
	Events.run_finished.emit(true, &"victory")
	await _frames(2)
	_check(Profile.achievements.is_empty() and Profile.boss_kills.is_empty() and Profile.stat("chests_opened") == 0.0, "mode test : aucun succès ni compteur")
	TestMode.active = false

	# --- bac à sable du profil ---
	Profile.begin_sandbox()
	Profile.unlock_achievement("floor_1")
	Profile.add_boss_kill("eclusier")
	Profile.end_sandbox()
	_check(not Profile.is_achievement_unlocked("floor_1") and Profile.boss_kills.is_empty(), "bac à sable : succès et boss rendus comme avant")

	# --- migration de profil ---
	Profile.reset()
	Profile._apply_dict({"version": 1, "rubies": 42, "unlocked_modes": ["facile", "moyen"], "stats": {"runs": 3, "victories": 1, "kills": 90, "play_time_s": 100.0, "best_time_s": {}}})
	_check(Profile.rubies == 42 and Profile.stats["runs"] == 3 and Profile.achievements.is_empty() and Profile.daily.is_empty()
		and Profile.boss_kills.is_empty() and not Profile.tutorial_replay, "profil v1 : champs de la méta par défaut, le reste intact")
	Profile.unlock_achievement("first_blood")
	Profile.add_boss_kill("cerf")
	Profile.set_daily({"streak": 2, "best_streak": 3, "last_key": 20261028, "completed": 4, "wins": 1,
		"days": {"20261028": {"tries": 2, "counted": true, "best": {"victory": true, "stage": 5, "kills": 10, "time_s": 99.0, "level": 4, "character": "ardent"}}}})
	var snap: Dictionary = JSON.parse_string(JSON.stringify(Profile.to_dict()))
	Profile.reset()
	Profile._apply_dict(snap)
	_check(Profile.is_achievement_unlocked("first_blood") and int(Profile.boss_kills["cerf"]) == 1 and int(Profile.daily["streak"]) == 2
		and bool(Profile.daily["days"]["20261028"]["best"]["victory"]) and int(snap["version"]) == 3, "aller-retour JSON v3")

	# --- écrans ---
	Profile.reset()
	Profile.unlock_achievement("first_blood")
	var scr := load("res://scenes/menu/achievements.tscn").instantiate() as AchievementsScreen
	add_child(scr)
	await _frames(3)
	_check(scr.cards.size() == Achievements.all().size() and scr.count_label.text == "1 / %d débloqués" % Achievements.all().size(), "écran des succès : une carte par succès, compteur")
	_check(str(scr.cards[0].get_meta(&"achievement")) == "first_blood", "débloqués en tête de grille")
	var wide := true
	for c in scr.cards:
		if c.size.x < 300.0:
			wide = false
	_check(wide, "cartes assez larges (%d colonnes)" % scr._grid.columns)
	scr.queue_free()
	var got_cfg := {}
	var dsc := load("res://scenes/menu/daily.tscn").instantiate() as DailyScreen
	add_child(dsc)
	dsc.start_requested.connect(func(cfg: Dictionary) -> void: got_cfg.merge(cfg))
	await _frames(3)
	dsc.start_button.pressed.emit()
	_check(int(got_cfg.get("seed", 0)) == DailyChallenge.seed_for(DailyChallenge.today_key()) and got_cfg.get("mode") == &"moyen" and int(got_cfg.get("daily", 0)) == DailyChallenge.today_key(),
		"écran du défi : « Lancer » émet la config du jour (graine, Moyen)")
	_check(dsc.status_label.text.contains("à faire") and dsc.start_button.text == "Lancer le défi", "défi non joué : « à faire »")
	dsc.queue_free()

	_tracker.queue_free()
	Profile.reset()
	RunState.running = false
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
