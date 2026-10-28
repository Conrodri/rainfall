extends Node
## Défi du jour : graine de la date, personnage imposé, plan identique, essai compté une fois, série, rubis, mode test.
## godot --headless --path game res://tests/daily_test.tscn
## Profil = autoload en mémoire (jamais écrit en headless), remis à zéro au début et à la fin.

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


func _day(y: int, m: int, d: int) -> void:
	DailyChallenge.date_override = {"year": y, "month": m, "day": d}


func _res(victory: bool, stage: int, kills: int, t: float, reason := "death") -> Dictionary:
	return {"victory": victory, "stage": stage, "kills": kills, "time_s": t, "level": 5, "character": "ardent", "reason": reason}


func _ready() -> void:
	Profile.write_enabled = false
	Profile.reset()
	RunState.running = false
	TestMode.active = false
	FloorPlan.ignore_memory = false

	# --- clé et graine ---
	_day(2026, 10, 28)
	var k := DailyChallenge.today_key()
	_check(k == 20261028, "clé du jour AAAAMMJJ = 20261028 (%d)" % k)
	_check(DailyChallenge.seed_for(k) == DailyChallenge.seed_for(20261028) and DailyChallenge.seed_for(k) != DailyChallenge.seed_for(20261029)
		and DailyChallenge.seed_for(k) > 0, "graine stable, différente d'un jour à l'autre, jamais 0")
	_check(DailyChallenge.previous_key(20261101) == 20261031 and DailyChallenge.previous_key(20260301) == 20260228
		and DailyChallenge.previous_key(20270101) == 20261231 and DailyChallenge.previous_key(20240301) == 20240229, "jour précédent (fins de mois, année, bissextile)")
	_check(DailyChallenge.key_of_seed(DailyChallenge.seed_for(k)) == k and DailyChallenge.key_of_seed(DailyChallenge.seed_for(20261027)) == 20261027
		and DailyChallenge.key_of_seed(DailyChallenge.seed_for(20261020)) == 0 and DailyChallenge.key_of_seed(12345) == 0 and DailyChallenge.key_of_seed(0) == 0,
		"graine de run reconnue (aujourd'hui, hier) sinon 0")

	# --- personnage et config ---
	var roster := DailyChallenge.roster()
	var hidden_in := false
	for c in roster:
		if bool(c.get("hidden", false)) or not bool(c.get("playable", true)):
			hidden_in = true
	_check(not roster.is_empty() and not hidden_in, "roster du défi : jouables, non cachés (%d)" % roster.size())
	var cfg1 := DailyChallenge.config_for(k)
	var cfg2 := DailyChallenge.config_for(k)
	_check(cfg1 == cfg2 and cfg1["mode"] == &"moyen" and int(cfg1["seed"]) == DailyChallenge.seed_for(k) and cfg1["spells"] == {}, "même date => même config (Moyen, sorts de base)")
	var seen := {}
	for i in 14:
		var kk := 20261001 + i
		seen[str(DailyChallenge.config_for(kk)["character"])] = true
	_check(seen.size() >= 3, "sur 14 jours, plusieurs personnages (%d)" % seen.size())

	# --- plan de run identique, mémoire des boss ignorée ---
	var seed_ := DailyChallenge.seed_for(k)
	Profile.last_floor_boss = {"1": "eclusier", "2": "cerf", "3": "sonneur", "4": "recluse"}
	FloorPlan.ignore_memory = true
	var p1 := FloorPlan.build(seed_)
	Profile.last_floor_boss = {"1": "ox_herder", "2": "weaver", "3": "crane", "4": "salt_king"}
	var p2 := FloorPlan.build(seed_)
	var p3 := FloorPlan.build(seed_, {})
	FloorPlan.ignore_memory = false
	_check(p1 == p2 and p1 == p3 and p1.size() == FloorPlan.final_floor(), "plan du jour identique quelle que soit la mémoire des boss du profil")
	Profile.last_floor_boss = {}
	_check(FloorPlan.build(seed_) == p1, "sans mémoire, le tirage normal donne le même plan (tirage normal intact)")
	FloorPlan.ignore_memory = false

	# --- essai compté, rubis, série ---
	var r0 := Profile.rubies
	var a := DailyChallenge.record(Profile, k, _res(false, 3, 200, 400.0))
	_check(a["counted"] and a["streak"] == 1 and a["rubies"] == Balance.daily_rubies(1, false) and Profile.rubies == r0 + int(a["rubies"]), "1er essai : compté, série 1, rubis versés")
	_check(DailyChallenge.tries(Profile, k) == 1 and DailyChallenge.is_counted(Profile, k), "1 essai, compté")
	var b := DailyChallenge.record(Profile, k, _res(false, 4, 100, 500.0))
	_check(not b["counted"] and b["rubies"] == 0 and Profile.rubies == r0 + int(a["rubies"]) and DailyChallenge.tries(Profile, k) == 2, "2e essai : rejoué sans compter, pas de rubis")
	_check(int(DailyChallenge.best_of_day(Profile, k)["stage"]) == 4 and bool(b["new_best"]), "meilleur du jour = étage 4")
	var c := DailyChallenge.record(Profile, k, _res(false, 2, 900, 100.0))
	_check(not c["new_best"] and int(DailyChallenge.best_of_day(Profile, k)["stage"]) == 4, "un moins bon essai ne remplace pas le meilleur")
	var w := DailyChallenge.record(Profile, k, _res(true, 5, 50, 1200.0))
	_check(w["new_best"] and bool(DailyChallenge.best_of_day(Profile, k)["victory"]), "une victoire bat toute défaite")
	var w2 := DailyChallenge.record(Profile, k, _res(true, 5, 50, 1100.0))
	_check(w2["new_best"] and is_equal_approx(float(DailyChallenge.best_of_day(Profile, k)["time_s"]), 1100.0), "entre victoires, le temps le plus court")
	_check(int(Profile.daily["completed"]) == 1 and int(Profile.daily["wins"]) == 0, "jours comptés = 1 ; victoire du 1er essai seulement comptée dans wins (0)")
	# série
	_day(2026, 10, 29)
	var k2 := DailyChallenge.today_key()
	_check(DailyChallenge.current_streak(Profile, k2) == 1, "lendemain : la série tient encore")
	var d2 := DailyChallenge.record(Profile, k2, _res(true, 5, 10, 900.0))
	_check(d2["counted"] and d2["streak"] == 2 and d2["rubies"] == Balance.daily_rubies(2, true), "jour suivant : série 2, bonus victoire")
	_day(2026, 10, 31)
	var k4 := DailyChallenge.today_key()
	_check(DailyChallenge.current_streak(Profile, k4) == 0, "jour sauté : série affichée 0")
	var e4 := DailyChallenge.record(Profile, k4, _res(false, 1, 5, 80.0))
	_check(e4["counted"] and e4["streak"] == 1 and DailyChallenge.best_streak(Profile) == 2, "série remise à 1, record 2 conservé")
	# abandon trop court
	_day(2026, 11, 1)
	var k5 := DailyChallenge.today_key()
	var rb := Profile.rubies
	var ab := DailyChallenge.record(Profile, k5, _res(false, 1, 0, 20.0, "abandon"))
	_check(ab["ignored"] and not ab["counted"] and DailyChallenge.tries(Profile, k5) == 0 and Profile.rubies == rb, "abandon avant 60 s : ignoré")
	var ab2 := DailyChallenge.record(Profile, k5, _res(false, 1, 30, 90.0, "abandon"))
	_check(ab2["counted"], "abandon après 60 s : compté")
	# rubis modestes
	_check(Balance.daily_rubies(1, false) < 20 and Balance.daily_rubies(99, true) <= Balance.DAILY_RUBIES_BASE + Balance.DAILY_RUBIES_STREAK_STEP * 6 + Balance.DAILY_RUBIES_WIN, "récompense modeste et plafonnée")

	# --- écouteur : run du jour reconnue, plan sans mémoire, fin de run ---
	Profile.reset()
	_day(2026, 10, 28)
	k = DailyChallenge.today_key()
	_tracker = MetaTracker.new()
	add_child(_tracker)
	await _frames(2)
	RunState.run_seed = DailyChallenge.seed_for(k)
	Events.run_started.emit(false)
	_check(_tracker.daily_key == k and FloorPlan.ignore_memory, "run du jour reconnue à son démarrage")
	RunState.mode = &"moyen"
	RunState.stage = 3
	RunState.kills = 77
	RunState.active_time_s = 500.0
	RunState.character = &"ardent"
	Events.run_finished.emit(false, &"death")
	_check(not FloorPlan.ignore_memory, "mémoire des boss rendue à la fin de la run")
	await _frames(2)
	_check(DailyChallenge.tries(Profile, k) == 1 and Profile.rubies > 0 and Profile.is_achievement_unlocked("daily_first"), "fin de run du jour : essai, rubis, succès « Défi relevé »")
	Events.run_started.emit(false)
	RunState.run_seed = 987654
	Events.run_started.emit(false)
	_check(_tracker.daily_key == 0 and not FloorPlan.ignore_memory, "run normale : pas du jour")
	var tries_before := DailyChallenge.tries(Profile, k)
	Events.run_finished.emit(false, &"death")
	await _frames(2)
	_check(DailyChallenge.tries(Profile, k) == tries_before, "run normale : le défi du jour n'est pas touché")
	# succès de série
	for i in 7:
		_day(2026, 11, 1 + i)
		DailyChallenge.record(Profile, DailyChallenge.today_key(), _res(false, 1, 1, 100.0))
	Achievements.evaluate(Profile, {})
	_check(Profile.is_achievement_unlocked("daily_streak_7"), "7 jours de suite -> Semaine de pluie")

	# --- mode test : rien n'est écrit ---
	Profile.reset()
	_day(2026, 10, 28)
	RunState.run_seed = DailyChallenge.seed_for(DailyChallenge.today_key())
	TestMode.active = true
	Events.run_started.emit(false)
	_check(_tracker.daily_key == 0 and not FloorPlan.ignore_memory, "mode test : jamais une run du jour")
	Events.run_finished.emit(true, &"victory")
	await _frames(2)
	_check(Profile.daily.is_empty() and Profile.rubies == 0 and Profile.achievements.is_empty(), "mode test : profil intact")
	TestMode.active = false

	# --- migration : ancien profil sans défi du jour ---
	Profile._apply_dict({"version": 2, "rubies": 7})
	_check(Profile.daily.is_empty() and DailyChallenge.tries(Profile, 20261028) == 0 and DailyChallenge.current_streak(Profile, 20261028) == 0,
		"profil v2 : défi du jour vierge")

	DailyChallenge.date_override = {}
	_tracker.queue_free()
	Profile.reset()
	RunState.running = false
	RunState.kills = 0
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
