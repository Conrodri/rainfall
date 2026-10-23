extends Node
## Test de fumée du simulateur d'équilibrage (tests/balance_sim) : chaque personnage jouable de
## data/characters.json fait deux combats courts (essaim T1, mini-boss) en config Niv 6 / Moyen 6 min.
## OK si aucun kit présent ne produit d'erreur de script et si les mesures restent dans des bornes saines.
## Kit absent (personnage en cours de codage) : sauté avec une note, pas un échec.
## godot --headless --path game res://tests/balance_sim_test.tscn  -> RESULT: OK

const Sim := preload("res://tests/balance_sim/balance_sim.gd")
const SCENS := ["swarm", "miniboss"]
const CFG := "L6"
const CAP_SCALE := 0.15 ## essaim 9 s, mini-boss 18 s (temps de jeu)
const DPS_MAX := 2000.0 ## Ardent ≈ 190 en essaim à cette config
const MAX_DEATHS := 2

var _fails := 0


func _ready() -> void:
	var sim: Node = Sim.new()
	sim.speed_k = 12
	add_child(sim)
	var ran := 0
	for c in Sim.roster():
		var cid: String = c["id"]
		var r: Dictionary = await sim.run_character(cid, SCENS, [CFG], CAP_SCALE)
		if not r["ok"]:
			if r.get("skip", false):
				print("SKIP %s : %s" % [cid, r["note"]])
			else:
				_check("%s : kit chargé" % cid, false, "%s %s" % [r["note"], _errs_str(r.get("load_errors", []))])
			continue
		ran += 1
		if r["note"] != "":
			print("NOTE %s : %s" % [cid, r["note"]])
		var kit_path: String = CharacterData.KIT_PATH % cid
		for f in r["fights"]:
			var tag := "%s/%s" % [cid, f["scenario"]]
			var bad: Array = []
			for e in f["errors"]:
				if int(e["type"]) == Logger.ERROR_TYPE_SCRIPT or str(e["where"]).begins_with(kit_path) \
						or str(e["where"]).contains("tests/balance_sim"):
					bad.append(e)
				else:
					print("  avertissement %s : %s %s" % [tag, e["where"], e["msg"]])
			_check("%s : aucune erreur de script" % tag, bad.is_empty(), _errs_str(bad))
			var dps: float = f["dps"]
			_check("%s : dégâts infligés > 0" % tag, f["dealt"] > 0.0, "dealt=%.1f" % f["dealt"])
			_check("%s : DPS fini et borné" % tag, is_finite(dps) and dps >= 0.0 and dps < DPS_MAX, "dps=%.1f" % dps)
			_check("%s : dégâts subis finis" % tag, is_finite(f["taken"]) and f["taken"] >= 0.0, "taken=%s" % f["taken"])
			_check("%s : morts <= %d" % [tag, MAX_DEATHS], int(f["deaths"]) <= MAX_DEATHS, "deaths=%d" % f["deaths"])
			_check("%s : PV max sains" % tag, f["max_hp"] >= 30.0 and f["max_hp"] < 5000.0, "max_hp=%.0f" % f["max_hp"])
			if f["scenario"] == "swarm":
				_check("%s : au moins 5 kills" % tag, int(f["kills"]) >= 5, "kills=%d" % f["kills"])
	_check("au moins Ardent simulé", ran >= 1)
	sim.queue_free()
	await get_tree().process_frame
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _errs_str(errs: Array) -> String:
	var parts: Array = []
	for e in errs.slice(0, 3):
		parts.append("%s %s" % [e.get("where", "?"), e.get("msg", "")])
	return " | ".join(parts)


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		return
	_fails += 1
	print("FAIL %s %s" % [label, detail])
