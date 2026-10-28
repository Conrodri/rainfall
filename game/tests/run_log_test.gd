extends Node
## Journal de run local (RunLog, scripts/telemetry/) :
## - une run simulée dans le vrai Main (étage 1 : monstres, mini-boss tué, or gagné / dépensé, dégâts reçus,
##   minute écoulée, abandon) écrit un journal JSON valide (schéma, étage, combat, minutes, fin) ;
## - fichier « en cours » + pointeur de reprise pendant la run, pointeur supprimé à la fin ;
## - rotation : 50 journaux gardés au plus ;
## - export : archive .zip avec un .json par run et LISEZMOI.txt ;
## - rien n'est journalisé en mode test ni quand l'option « Journal de run » est coupée.
## godot --headless --path game res://tests/run_log_test.tscn  -> RESULT: OK
## Écrit seulement dans user://test_run_logs* (jamais dans user://run_logs du joueur).

const DIR := "user://test_run_logs"
const EXPORT_DIR := "user://test_run_logs_export"
const CFG := "user://test_run_log_settings.cfg"

var _main: Node
var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # le récap de fin met l'arbre en pause
	_wipe(DIR)
	_wipe(EXPORT_DIR)
	RunLog.log_dir = DIR
	GameSettings.cfg_path = CFG
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	_check("journal activé par défaut (build de test)", RunLog.enabled() == RunLog.TEST_BUILD)

	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 4242)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	_check("run journalisée", RunLog.recording)
	var files := RunLog.list_logs()
	_check("fichier en cours créé", files.size() == 1, str(files))
	_check("pointeur de reprise", FileAccess.file_exists(DIR.path_join(RunLog.CURRENT_FILE)))

	var stage: StageManager = _main.get(&"stage")
	var player: Node2D = _main.get(&"player")
	var director: Director = _main.get(&"director")
	player.grant_invulnerability(99999.0)
	# monstres + attaque automatique du joueur (spell_hit) pendant une seconde
	director.credits = 150.0
	director.wave_credits = 150.0
	director.trigger_wave()
	await _frames(60)
	var e: Node = get_tree().get_first_node_in_group(&"enemies")
	_check("monstre présent", e != null)
	player.set(&"_invuln", 0.0)
	player.grant_invulnerability(0.0)
	if e != null:
		player.call(&"take_damage", 5.0, e) # dégâts reçus par source
	RunState.add_gold(120.0)
	RunState.spend_gold(30.0)
	RunState.active_time_s += 61.0 # minute suivante : la 1re minute est versée au journal
	await _frames(2)
	# mini-boss d'un petit pilier, tué par dégâts directs
	var small: Pillar = null
	for p: Pillar in stage.pillars:
		if p.kind == Pillar.Kind.SMALL:
			small = p
			break
	_check("petit pilier", small != null)
	if small != null:
		player.global_position = small.global_position + Vector2(24, 24)
		small._on_body_entered(player)
		small.activate()
		var boss: Enemy = small.get(&"_boss")
		_check("mini-boss apparu", boss != null and boss.active)
		var guard := 0
		while boss != null and boss.active and guard < 3000:
			player.set(&"hp", player.get(&"max_hp"))
			RunState.active_time_s += 0.5
			if boss.hp > 0.0:
				boss.take_damage(boss.max_hp * 0.1)
			await get_tree().physics_frame
			guard += 1
	await _frames(2)
	_main.end_run(false, &"abandon")
	await _frames(2)

	_check("run close", not RunLog.recording)
	_check("pointeur supprimé", not FileAccess.file_exists(DIR.path_join(RunLog.CURRENT_FILE)))
	files = RunLog.list_logs()
	_check("un journal", files.size() == 1, str(files))
	var log: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(files[0]))) if files.size() == 1 else null
	_check("JSON valide", log is Dictionary)
	if log is Dictionary:
		_check_log(log)
	var keep := OS.get_environment("RUN_LOG_TEST_COPY") # copie du journal produit (test de tools/analyse_runs.py)
	if keep != "" and files.size() == 1:
		DirAccess.copy_absolute(ProjectSettings.globalize_path(DIR.path_join(files[0])), keep)

	# --- rotation : 52 anciens journaux factices + le vrai -> 50 gardés, le plus récent (le vrai) conservé
	var real := files[0] if files.size() > 0 else ""
	for i in 52:
		var f := FileAccess.open(DIR.path_join("run_19990101-0000%02d_00000000.json" % i), FileAccess.WRITE)
		f.store_string("{}")
		f.close()
	RunLog.rotate()
	var after := RunLog.list_logs()
	_check("rotation : 50 journaux", after.size() == RunLog.MAX_LOGS, str(after.size()))
	_check("rotation : le plus récent gardé", real != "" and after.has(real))
	_check("rotation : les plus anciens supprimés", not after.has("run_19990101-000000_00000000.json"))

	# --- export
	var res := RunLogExport.build_archive(DIR, EXPORT_DIR)
	_check("export : archive créée", bool(res["ok"]) and FileAccess.file_exists(String(res["path"])), str(res))
	if res["ok"]:
		var zr := ZIPReader.new()
		_check("export : zip lisible", zr.open(String(res["path"])) == OK)
		var names := zr.get_files()
		_check("export : %d journaux + LISEZMOI" % RunLog.MAX_LOGS, names.size() == RunLog.MAX_LOGS + 1 and names.has("LISEZMOI.txt"), str(names.size()))
		_check("export : contenu intact", real != "" and zr.read_file(real) == FileAccess.get_file_as_bytes(DIR.path_join(real)))
		zr.close()
	_check("export vide : message", not bool(RunLogExport.build_archive(DIR + "_absent", EXPORT_DIR)["ok"]))

	# --- reprise d'une sauvegarde (relance du jeu) : le journal en cours de la même graine est repris
	RunState.run_seed = 98765
	Events.run_started.emit(false)
	var cur := String(RunLog.get(&"_file"))
	_check("reprise : journal en cours", RunLog.recording and FileAccess.file_exists(DIR.path_join(cur)))
	Events.run_started.emit(true) # relance : même graine, sauvegarde reprise
	_check("reprise : même fichier", String(RunLog.get(&"_file")) == cur)
	_check("reprise : compteur", int((RunLog.get(&"_log") as Dictionary).get("resumes", 0)) == 1)
	Events.run_finished.emit(false, &"abandon")
	var resumed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR.path_join(cur)))
	_check("reprise : journal terminé", resumed is Dictionary and resumed["end"] is Dictionary and int(resumed["resumes"]) == 1)
	_check("rotation après la reprise : 50", RunLog.list_logs().size() == RunLog.MAX_LOGS)

	# --- mode test : rien n'est journalisé
	TestMode.active = true
	Events.run_started.emit(false)
	_check("mode test : pas de journal", not RunLog.recording and RunLog.list_logs().size() == RunLog.MAX_LOGS)
	Events.run_finished.emit(false, &"abandon")
	TestMode.active = false
	# --- option coupée : rien n'est journalisé
	RunLog.set_enabled(false)
	_check("option coupée", not RunLog.enabled())
	Events.run_started.emit(false)
	_check("option coupée : pas de journal", not RunLog.recording)
	RunLog.set_enabled(true)
	_finish()


func _check_log(log: Dictionary) -> void:
	_check("schéma %d" % RunLog.SCHEMA, int(log.get("schema", 0)) == RunLog.SCHEMA)
	for k in ["id", "game_version", "platform", "character", "skin", "loadout", "mode", "seed", "plan", "floors", "fights", "minutes", "end"]:
		_check("clé " + k, log.has(k))
	_check("graine", int(log.get("seed", 0)) == 4242)
	_check("plan de run (5 étages)", (log.get("plan", []) as Array).size() >= 5, str((log.get("plan", []) as Array).size()))
	var floors: Array = log.get("floors", [])
	_check("étage 1 noté", floors.size() == 1 and int(floors[0]["stage"]) == 1)
	if floors.size() == 1:
		var fl: Dictionary = floors[0]
		_check("étage : or gagné ≥ 120", float(fl["gold_earned"]) >= 120.0, str(fl["gold_earned"]))
		_check("étage : or dépensé = 30", int(fl["gold_spent"]) == 30, str(fl["gold_spent"]))
		_check("étage : temps de sortie", float(fl["t_out"]) > float(fl["t_in"]))
		_check("étage : D d'entrée", float(fl["d_in"]) >= 1.0)
		_check("étage : pilier noté", not (fl["pillars"] as Array).is_empty())
		_check("étage : dégâts reçus", float(fl["dmg_taken"]) > 0.0, str(fl["dmg_taken"]))
	var fights: Array = log.get("fights", [])
	var kill: Dictionary = {}
	for f: Dictionary in fights:
		if f["outcome"] == "kill":
			kill = f
	_check("combat de mini-boss tué", not kill.is_empty(), str(fights))
	if not kill.is_empty():
		_check("combat : catégorie mini", kill["cat"] == "mini", str(kill["cat"]))
		_check("combat : id", String(kill["id"]) != "")
		_check("combat : PV max", float(kill["hp_max"]) > 0.0)
		_check("combat : TTK > 0", float(kill["ttk"]) > 0.0, str(kill["ttk"]))
		_check("combat : dégâts infligés ≈ PV max", float(kill["dmg_dealt"]) >= float(kill["hp_max"]) * 0.9, "%s / %s" % [kill["dmg_dealt"], kill["hp_max"]])
	var minutes: Array = log.get("minutes", [])
	_check("minutes notées", not minutes.is_empty())
	var dealt := 0.0
	var taken := 0.0
	var casts := 0
	for m: Dictionary in minutes:
		for k in m["dmg"]:
			dealt += float(m["dmg"][k])
		for k in m["taken"]:
			taken += float(m["taken"][k])
		for k in m["casts"]:
			casts += int(m["casts"][k])
	_check("minutes : dégâts infligés", dealt > 0.0)
	_check("minutes : lancers de sorts", casts > 0, str(casts))
	_check("minutes : dégâts reçus par source", taken > 0.0)
	var end: Variant = log.get("end")
	_check("fin : abandon", end is Dictionary and end["result"] == "abandon", str(end))
	_check("pas de champ de reprise", not log.has("partial_minute") and not log.has("_gold_earned"))


func _wipe(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.remove_absolute(dir)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok  ", label)
	else:
		_fails += 1
		print("  FAIL ", label, "  ", detail)


func _finish() -> void:
	get_tree().paused = false
	_wipe(DIR)
	_wipe(EXPORT_DIR)
	if FileAccess.file_exists(CFG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG))
	GameSettings.cfg_path = GameSettings.PATH
	RunLog.log_dir = RunLog.DIR
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)
