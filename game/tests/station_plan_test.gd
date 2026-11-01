extends Node
## Tirage des ateliers par étage (docs/Ateliers_Chiffres.md §2.2) : poids de data/stations.json (somme 100 par étage),
## fréquences réelles après la règle de répétition (±1,5 point sur 10 000 graines), Enclume toujours à l'étage 5,
## déterminisme par graine, jamais deux ateliers au même étage, boucle sans fin, atelier imposé.
## godot --headless --path game res://tests/station_plan_test.tscn  -> RESULT: OK

const SEEDS := 10000
const TOL := 1.5
## Fréquences attendues (%) par étage, §2.2 du doc (Monte-Carlo du systems-designer).
const EXPECTED := {
	1: {&"enclume": 50.0, &"boussole": 50.0},
	2: {&"fondoir_matrice": 55.0, &"matrice": 0.0, &"alambic": 28.0, &"enclume": 10.0, &"boussole": 7.0},
	3: {&"fondoir_matrice": 38.0, &"matrice": 4.0, &"alambic": 39.0, &"enclume": 13.0, &"boussole": 5.0},
	4: {&"fondoir_matrice": 28.0, &"matrice": 4.0, &"alambic": 29.0, &"enclume": 32.0, &"boussole": 8.0},
}

var _fails := 0


func _check(label: String, cond: bool, detail: String = "") -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label, ("  (" + detail + ")") if detail != "" else "")


func _ready() -> void:
	StationPlan.force_station = &""
	StationPlan.reset_cache()
	# poids : somme 100 par étage 1-4
	for f in 4:
		var t: Dictionary = StationPlan.weights().get(str(f + 1), {})
		var sum := 0.0
		for id in t:
			sum += float(t[id])
		_check("étage %d : poids = 100" % (f + 1), is_equal_approx(sum, 100.0), str(sum))
	var counts := {}
	var double := 0
	var finals := 0
	var per_run := {}
	for sd in range(1, SEEDS + 1):
		var plan := StationPlan.build(sd)
		_check("plan de %d étages" % FloorPlan.final_floor(), plan.size() == FloorPlan.final_floor())
		if plan[plan.size() - 1] == Balance.STATION_FINAL:
			finals += 1
		for f in 4:
			var id: StringName = plan[f]
			counts[[f + 1, id]] = int(counts.get([f + 1, id], 0)) + 1
			per_run[id] = int(per_run.get(id, 0)) + 1
		if sd <= 200:
			_check("graine %d : déterministe" % sd, StationPlan.build(sd) == plan)
			for f in 5:
				_check("for_stage = plan (graine %d, étage %d)" % [sd, f + 1], StationPlan.for_stage(sd, f + 1) == plan[f])
	_check("Enclume à l'étage 5 pour 100 %% des graines", finals == SEEDS, str(finals))
	for f in EXPECTED:
		var exp: Dictionary = EXPECTED[f]
		for id in exp:
			var got := 100.0 * float(counts.get([f, id], 0)) / float(SEEDS)
			_check("étage %d %s : %.1f %% (attendu %.0f ±%.1f)" % [f, id, got, float(exp[id]), TOL], absf(got - float(exp[id])) <= TOL)
		var total := 0
		for k in counts:
			if k[0] == f:
				total += int(counts[k])
		_check("étage %d : un seul atelier par graine" % f, total == SEEDS)
	# par run (étages 1-4) : Fondoir+Matrice 1,21 / Matrice seule 0,08 / Alambic 0,96 / Enclume 1,06 / Boussole 0,69
	for pair in [[&"fondoir_matrice", 1.21], [&"matrice", 0.08], [&"alambic", 0.96], [&"enclume", 1.06], [&"boussole", 0.69]]:
		var got := float(per_run.get(pair[0], 0)) / float(SEEDS)
		_check("par run : %s %.2f (attendu %.2f ±0,06)" % [pair[0], got, pair[1]], absf(got - float(pair[1])) <= 0.06)
	# sans fin : étages 6-10 déterministes, étage 10 = Source = Enclume, jamais vide aux étages 6-9
	for stage in range(6, 11):
		var a := StationPlan.for_stage(42, stage)
		_check("sans fin étage %d déterministe" % stage, a == StationPlan.for_stage(42, stage))
		_check("sans fin étage %d : un atelier" % stage, a != &"")
	_check("sans fin : étage 10 = Enclume", StationPlan.for_stage(42, 10) == Balance.STATION_FINAL)
	# atelier imposé
	StationPlan.force_station = &"alambic"
	_check("atelier imposé", StationPlan.for_stage(1, 3) == &"alambic" and StationPlan.for_stage(1, 5) == &"alambic")
	StationPlan.force_station = &"none"
	_check("« none » = aucun", StationPlan.for_stage(1, 3) == &"")
	StationPlan.force_station = &""
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)
