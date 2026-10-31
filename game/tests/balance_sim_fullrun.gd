extends Node
## Audit d'équilibrage : runs complètes simulées (tests/balance_sim/full_run_sim.gd), un personnage par processus.
## godot --headless --fixed-fps 60 --path game res://tests/balance_sim_fullrun.tscn -- --char=ardent --seeds=0,1,2 --out=<f.json>
## Rencontre ciblée rapide : --inject=<f.json> ({stage, t, level, items, boss?} : un seul combat de boss, sans mini-boss).
## Options : --stages=5 --t_boss=180 --mode=moyen ; essais de PV de boss : --boss_k=1.12 --final_mult=1.35 --mini_hp=0.8 --etage_hp=1. Sortie : JSON {runs: [...]} puis « RESULT: OK ».

const FullRun := preload("res://tests/balance_sim/full_run_sim.gd")
const Sim := preload("res://tests/balance_sim/balance_sim.gd")


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	# Filet : si l'autoload InputSetup n'a pas compilé (fichier voisin en cours d'édition), le bot a quand même ses actions.
	for a in [&"move_left", &"move_right", &"move_up", &"move_down", &"aim_left", &"aim_right", &"aim_up", &"aim_down",
			&"spell_2", &"spell_3", &"spell_4", &"interact", &"pause"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var cid := str(args.get("char", "ardent"))
	var out_path := str(args.get("out", "user://fullrun.json"))
	var loader: Node = Sim.new()
	add_child(loader)
	var runs: Array = []
	for s in str(args.get("seeds", "0")).split(",", false):
		var lc: Dictionary = loader.load_character(cid)
		if not lc["ok"]:
			print("RESULT: FAIL (kit %s : %s)" % [cid, lc["note"]])
			get_tree().quit(1)
			return
		var fr: Node = FullRun.new()
		fr.seed_value = 1234 + 1000 * int(s)
		fr.stages = int(args.get("stages", "5"))
		fr.t_boss = float(args.get("t_boss", "180"))
		fr.mode = StringName(args.get("mode", "moyen"))
		fr.try_stage_k = float(args.get("boss_k", "0"))
		fr.try_final_mult = float(args.get("final_mult", "0"))
		fr.try_mini_hp = float(args.get("mini_hp", "1"))
		fr.try_etage_hp = float(args.get("etage_hp", "1"))
		fr.charge_zone = StringName(args.get("charge_zone", "etage"))
		fr.boss_aim_priority = float(args.get("boss_aim", "1"))
		if args.has("inject"): # rencontre ciblée : JSON {stage, t, level, items, boss?}
			fr.inject = JSON.parse_string(FileAccess.get_file_as_string(str(args["inject"])))
		add_child(fr)
		var r: Dictionary = await fr.run(cid, lc["data"])
		r["errors"] = loader.errlog.take().size()
		runs.append(r)
		print("RUN %s seed %d : %.0fs morts %d niv %d" % [cid, fr.seed_value, r["run_s"], r["deaths"], r["level"]])
		fr.queue_free()
		await get_tree().process_frame
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"runs": runs}, " "))
	f.close()
	print("RESULT: OK")
	get_tree().quit(0)
