extends Node
## Simulateur d'équilibrage complet (rapport) : lancé par art/tools/night/balance_sim.py, un personnage par
## processus (un kit en panne ne bloque pas les autres). Arguments après `--` :
##   --chars=ardent,rictus  --scen=swarm,mixed,elite,miniboss  --cfg=L1,L6,L12  --out=<fichier.json>  --k=12
## godot --headless --path game res://tests/balance_sim_run.tscn -- --chars=ardent --out=C:/.../sim_ardent.json
## Sortie : JSON {characters: [{char, ok, skip, note, fights: [...]}]} puis « RESULT: OK ».

const Sim := preload("res://tests/balance_sim/balance_sim.gd")


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var chars: Array = []
	if args.has("chars"):
		chars = Array(str(args["chars"]).split(",", false))
	else:
		for c in Sim.roster():
			chars.append(c["id"])
	var scens: Array = Array(str(args.get("scen", "swarm,mixed,elite,miniboss")).split(",", false))
	var cfgs: Array = Array(str(args.get("cfg", "L1,L6,L12")).split(",", false))
	var out_path := str(args.get("out", "user://balance_sim.json"))
	var sim: Node = Sim.new()
	sim.speed_k = int(args.get("k", "12"))
	for kv in str(args.get("loadout", "")).split(",", false): # --loadout=1:id,2:id
		var lp := kv.split(":")
		if lp.size() == 2:
			sim.loadout[int(lp[0])] = StringName(lp[1])
	for sl in str(args.get("noslot", "")).split(",", false): # --noslot=4 : ablation d'un sort
		sim.disabled_slots.append(int(sl))
	add_child(sim)
	var res: Array = []
	for cid in chars:
		var r: Dictionary = await sim.run_character(cid, scens, cfgs, float(args.get("cap", "1.0")), int(args.get("seeds", "1")))
		res.append(r)
		print("CHAR %s ok=%s note=%s" % [cid, r["ok"], r["note"]])
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		print("RESULT: FAIL (écriture impossible : %s)" % out_path)
		get_tree().quit(1)
		return
	f.store_string(JSON.stringify({"characters": res}, "  "))
	f.close()
	sim.queue_free()
	await get_tree().process_frame
	print("RESULT: OK")
	get_tree().quit(0)
