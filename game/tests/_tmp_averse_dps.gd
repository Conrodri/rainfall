extends Node
## TEMPORAIRE : DPS par sort d'Averse vs Ardent (balance_sim). -- --out=<json> --modes=std,water,full --seeds=2

const Sim := preload("res://tests/_tmp_sim.gd")
const Kit := preload("res://tests/_tmp_averse_dps_kit.gd")
const MODES := {"std": [0.0, false], "water": [0.3, false], "full": [0.3, true]}


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var scens := Array(str(args.get("scen", "swarm,mixed,elite,miniboss")).split(",", false))
	var cfgs := Array(str(args.get("cfg", "L1,L6,L12")).split(",", false))
	var modes := Array(str(args.get("modes", "std,water,full")).split(",", false))
	var seeds := int(args.get("seeds", "2"))
	var with_ardent := str(args.get("ardent", "1")) == "1"
	var sim: Node = Sim.new()
	sim.speed_k = int(args.get("k", "12"))
	sim.boss_hp_mult = float(args.get("bhp", "1.0"))
	add_child(sim)
	var rows: Array = []
	var runs: Array = []
	if with_ardent:
		runs.append(["ardent", "ref"])
	for m in modes:
		runs.append(["averse", m])
	for r in runs:
		var cid: String = r[0]
		var mode: String = r[1]
		if cid == "averse":
			Kit.map_duty = MODES[mode][0]
			Kit.full_only = MODES[mode][1]
		for cfg_id in cfgs:
			for scen_id in scens:
				for si in seeds:
					sim.seed_base = 1234 + 1000 * si
					var lc: Dictionary = sim.load_character(cid)
					var cd: CharacterData = lc["data"]
					if cid == "averse":
						cd.kit_script = Kit
					Kit.reset_stats()
					var f: Dictionary = await sim.run_fight(cid, cd, scen_id, cfg_id, 1.0)
					var row := {"char": cid, "mode": mode, "cfg": cfg_id, "scen": scen_id, "seed": si,
						"dur": f["duration"], "dps": f["dps"], "cleared": f["cleared"], "deaths": f["deaths"],
						"taken": f["taken"], "max_hp": f["max_hp"], "casts": f["casts"]}
					if cid == "averse":
						var d := {}
						for k in Kit.dmg:
							d[str(k)] = float(Kit.dmg[k]) / f["duration"]
						row["slot_dps"] = d
						row["crues"] = Kit.crues
						row["crue_water"] = (Kit.crue_water / Kit.crues) if Kit.crues > 0 else 0.0
					rows.append(row)
					print("ROW %s %s %s %s s%d dps=%.1f dur=%.1f" % [cid, mode, cfg_id, scen_id, si, f["dps"], f["duration"]])
	var fa := FileAccess.open(str(args.get("out", "user://averse_dps.json")), FileAccess.WRITE)
	fa.store_string(JSON.stringify(rows, " "))
	fa.close()
	print("RESULT: OK")
	get_tree().quit(0)
