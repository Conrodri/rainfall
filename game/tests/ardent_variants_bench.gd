extends Node
## Mesure isolée du budget de puissance des variantes d'Ardent (docs/Variantes_Sorts.md §1.3 : side-grade ±15 %).
## Pour un slot, compare le sort de base et sa variante dans les combats du simulateur d'équilibrage, les TROIS AUTRES
## sorts étant mis à coef 0 (le DPS mesuré est celui du seul sort testé).
## godot --headless --path game res://tests/ardent_variants_bench.tscn -- --slot=1 [--seeds=2] [--scen=swarm,elite,mixed,miniboss] [--cfg=L1,L6,L12] [--coef=0.5] [--cap=0.4]
## --coef : remplace le coef de la variante (réglage). Sortie : une ligne par combat + moyennes ; « RESULT: OK ».

const Sim := preload("res://tests/balance_sim/balance_sim.gd")
const VARIANTS := {1: &"roaming_embers", 2: &"flame_pillar", 3: &"meteor_rain", 4: &"phoenix"}


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var slot := int(args.get("slot", "1"))
	var seeds := int(args.get("seeds", "2"))
	var scens: Array = Array(str(args.get("scen", "swarm,elite,mixed,miniboss")).split(",", false))
	var cfgs: Array = Array(str(args.get("cfg", "L1,L6,L12")).split(",", false))
	var coef := float(args.get("coef", "-1"))
	var cap := float(args.get("cap", "0.4")) # fraction de la durée max du scénario (fenêtre de mesure identique base / variante)
	var sim: Node = Sim.new()
	sim.speed_k = int(args.get("k", "12"))
	add_child(sim)
	var ratios: Array[float] = []
	var by_scen := {}
	for cfg in cfgs:
		for scen in scens:
			var dps := {"base": 0.0, "var": 0.0}
			for si in seeds:
				sim.seed_base = 1234 + 1000 * si
				for opt in ["base", "var"]:
					var cd := CharacterData.for_id(&"ardent", {slot: VARIANTS[slot]} if opt == "var" else {})
					for s in cd.spells:
						if s.slot != slot:
							s.coef = 0.0
						elif opt == "var" and coef > 0.0:
							s.coef = coef
					var f: Dictionary = await sim.run_fight("ardent", cd, scen, cfg, cap)
					dps[opt] += float(f["dealt"]) / maxf(float(f["duration"]), 0.1) / seeds
			var r: float = dps["var"] / maxf(dps["base"], 0.001)
			ratios.append(r)
			by_scen[scen] = by_scen.get(scen, []) + [r]
			print("BENCH slot=%d %s %s : base %.1f  variante %.1f  ratio %.2f" % [slot, cfg, scen, dps["base"], dps["var"], r])
	var mean := 0.0
	for r in ratios:
		mean += r / ratios.size()
	var parts := []
	for sc in by_scen:
		var m := 0.0
		for r in by_scen[sc]:
			m += r / by_scen[sc].size()
		parts.append("%s %.2f" % [sc, m])
	print("MOYENNE slot=%d ratio %.2f (%s)" % [slot, mean, ", ".join(parts)])
	print("RESULT: OK")
	get_tree().quit(0)
