extends Node
## Banc de perf par carte, lanceur PC (scripts/testmode/map_perf_bench.gd) : mode test (bac à sable, rien au profil),
## vraie scène de jeu, cartes réelles chargées comme par l'onglet Cartes, Bas / Moyen / Haut, 0 / 80 / 250 monstres,
## événement d'ambiance à D 7,5. À lancer SANS --headless pour un rendu réel (fenêtre 1920 x 1080, vsync coupée) :
##   godot --path game res://tests/map_perf_bench.tscn -- --maps=cite_rouille,cite_fonderie_canal --tiers=0,1,2 --counts=0,80,250 --seconds=10 --out=C:/x.json
## Sans --maps : les 9 cartes. En --headless (contrôle de non-régression, chiffres de rendu sans valeur) : --seconds=0.3.
## --ui : bandeau et fenêtre de résultat comme sur le téléphone.
## --watchdog=<s> (défaut 60) : si aucune image n'avance pendant <s> secondes (boucle infinie, gel), un fil de garde
## écrit « WATCHDOG » avec la dernière configuration et termine le processus (aucun Godot figé laissé en fond) ;
## --watchdog-grace=<s> retarde la fin de <s> secondes (pour relever la pile avec un débogueur distant).
## Les images passées en pause ne comptent pas : un menu pause resté ouvert est signalé comme tel par le fil de garde.
## Perte de focus (menu pause ouvert par PauseMenu) : reprise automatique (MapPerfBench.resume_on_pause), sauf
## --keep-pause. --focus-out-at=<s> simule une perte de focus <s> secondes après le début du banc (reproduction
## du « gel » du 09/11/2026, docs/Mesures_Perf_Android.md §7, possible aussi en --headless).
## Sortie : lignes « BENCHROW | {json} » au fil des mesures, tableau texte, fichiers user://perf_bench/bench_<date>.json / .txt, puis « RESULT: OK ».

const PROFILE_PATH := "user://map_perf_bench_profile.json"

var _beat := 0 ## images écoulées hors pause (lu par le fil de garde)
var _paused := false ## jeu en pause à la dernière image (lu par le fil de garde)
var _focus_out_ms := -1 ## --focus-out-at : instant (ticks) de la perte de focus simulée
var _step := "démarrage" ## dernière étape annoncée par le banc (lue par le fil de garde)
var _wd: Thread
var _wd_stop := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _process(_delta: float) -> void:
	_paused = get_tree().paused
	if not _paused:
		_beat += 1
	if _focus_out_ms >= 0 and Time.get_ticks_msec() >= _focus_out_ms:
		_focus_out_ms = -1
		print("Perte de focus simulée (--focus-out-at)")
		get_tree().root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)


## Fil de garde : termine le processus si les images n'avancent plus pendant `limit_s` secondes.
func _watchdog(limit_s: float, grace_s: float) -> void:
	var last := -1
	var t_last := Time.get_ticks_msec()
	while not _wd_stop:
		OS.delay_msec(250)
		var b := _beat
		if b != last:
			last = b
			t_last = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - t_last > int(limit_s * 1000.0):
			var why := "jeu en pause (menu pause resté ouvert)" if _paused else "aucune image"
			printerr("WATCHDOG : %s depuis %.0f s ; dernière étape : %s" % [why, limit_s, _step])
			print("RESULT: FAIL (%s pendant « %s »)" % [why, _step])
			OS.delay_msec(int(grace_s * 1000.0)) # laisse un débogueur distant relever la pile GDScript
			OS.kill(OS.get_process_id())
			return


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var wd_s := float(args.get("watchdog", "60"))
	if wd_s > 0.0:
		_wd = Thread.new()
		_wd.start(_watchdog.bind(wd_s, float(args.get("watchdog-grace", "0"))))
	var old_path: String = Profile.path
	var old_write: bool = Profile.write_enabled
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	Profile.path = PROFILE_PATH
	Profile.write_enabled = true # le mode test ne doit rien écrire : vérifié à la fin
	Quality.persist = false
	Quality.dynamic_degrade = false
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1920, 1080)
	TestMode.begin()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 777)
	add_child(main)
	await main.game_ready
	for i in 10:
		await get_tree().process_frame
	var bench := MapPerfBench.new()
	bench.with_ui = args.has("ui")
	bench.resume_on_pause = not args.has("keep-pause")
	bench.restore_after = false
	if args.has("maps"):
		bench.maps.assign(Array(str(args["maps"]).split(",", false)))
	if args.has("tiers"):
		bench.tiers.assign(Array(str(args["tiers"]).split(",", false)).map(func(x): return int(x)))
	if args.has("counts"):
		bench.counts.assign(Array(str(args["counts"]).split(",", false)).map(func(x): return int(x)))
	bench.seconds = float(args.get("seconds", "10"))
	if args.has("warmup"):
		bench.warmup_s = float(args["warmup"])
	bench.progress.connect(func(t: String) -> void: _step = t)
	bench.row_done.connect(func(r: Dictionary) -> void: print("BENCHROW | ", JSON.stringify(r)))
	main.add_child(bench)
	if args.has("focus-out-at"):
		_focus_out_ms = Time.get_ticks_msec() + int(float(args["focus-out-at"]) * 1000.0)
	var res: Dictionary = await bench.run()
	var rows: Array = res.get("rows", [])
	var ok := not rows.is_empty()
	for r in rows:
		if int((r as Dictionary).get("frames", 0)) == 0:
			ok = false
	print(MapPerfBench.to_text(res))
	if args.has("out"):
		var f := FileAccess.open(str(args["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(res, " "))
			f.close()
	remove_child(main)
	main.queue_free()
	await get_tree().process_frame
	var sandbox_ok := not FileAccess.file_exists(PROFILE_PATH)
	Profile.path = old_path
	Profile.write_enabled = old_write
	if _wd != null:
		_wd_stop = true
		_wd.wait_to_finish()
	print("RESULT: %s" % ("OK" if ok and sandbox_ok else "FAIL (lignes vides ou profil écrit)"))
	get_tree().quit(0 if ok and sandbox_ok else 1)
