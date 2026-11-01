class_name StationPlan
extends RefCounted
## Tirage des ateliers de la run (docs/Ateliers_Chiffres.md §2). Un atelier par étage 1-4 (poids de
## data/stations.json), l'Enclume (Balance.STATION_FINAL) à l'étage 5. Générateur PROPRE (graine de run +
## "station_run") : ne touche ni RunState.rng, ni les cartes, ni les boss ; déterministe (défi du jour, sauvegarde).
## Une famille déjà sortie dans la run voit son poids multiplié par Balance.STATION_REPEAT_WEIGHT.
## Ids tirés : &"fondoir_matrice" (couple), &"matrice", &"alambic", &"enclume", &"boussole" (posée par un autre lot).

const PATH := "res://data/stations.json"

static var _weights: Dictionary = {}
## Atelier imposé à tous les étages (tests, mode test) : &"" = tirage normal. Ligne de commande : `-- --force-station=<id>`
## (id d'atelier, ou `none` pour aucun).
static var force_station := &""


static func weights() -> Dictionary:
	if _weights.is_empty():
		if FileAccess.file_exists(PATH):
			var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if d is Dictionary and (d as Dictionary).get("weights") is Dictionary:
				_weights = (d as Dictionary)["weights"]
		if _weights.is_empty():
			push_warning("StationPlan : %s absent ou invalide" % PATH)
			_weights = {"1": {"enclume": 100}}
	return _weights


static func reset_cache() -> void:
	_weights = {}


static func forced() -> StringName:
	if force_station != &"":
		return force_station
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--force-station="):
			return StringName(arg.trim_prefix("--force-station="))
	return &""


## Atelier de chaque étage de la boucle 1..final (index = étage - 1), pour une graine de run.
static func build(run_seed: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "station_run"])
	var seen := {}
	for f in range(1, FloorPlan.final_floor() + 1):
		var id := _draw(f, rng, seen)
		out.append(id)
	return out


## Atelier de l'étage de run `stage` (&"" = aucun). Boucle 1 : celui du plan ; sans fin : tirage propre à l'étage.
static func for_stage(run_seed: int, stage: int) -> StringName:
	var fv := forced()
	if fv != &"":
		return &"" if fv == &"none" else fv
	if FloorPlan.loop_of_stage(stage) == 0:
		var plan := build(run_seed)
		return plan[stage - 1] if stage - 1 < plan.size() else &""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "station_run", stage])
	return _draw(FloorPlan.floor_of_stage(stage), rng, {})


static func _draw(floor_n: int, rng: RandomNumberGenerator, seen: Dictionary) -> StringName:
	if floor_n >= FloorPlan.final_floor():
		return Balance.STATION_FINAL
	var table: Dictionary = weights().get(str(floor_n), {})
	var ids: Array = table.keys()
	var ws: Array[float] = []
	var total := 0.0
	for id in ids:
		var w := float(table[id])
		if seen.has(Balance.STATION_FAMILY.get(StringName(id), StringName(id))):
			w *= Balance.STATION_REPEAT_WEIGHT
		ws.append(w)
		total += w
	if total <= 0.0:
		return &""
	var roll := rng.randf() * total
	var pick: StringName = StringName(ids[ids.size() - 1])
	for i in ids.size():
		roll -= ws[i]
		if roll < 0.0:
			pick = StringName(ids[i])
			break
	seen[Balance.STATION_FAMILY.get(pick, pick)] = true
	return pick
