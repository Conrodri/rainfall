class_name StationSpawner
extends RefCounted
## Pose les ateliers d'un étage (appelé par StageManager.start_stage, après les capsules). Atelier tiré par
## StationPlan ; position sur une case `E` de la carte (marqueurs `event_spawn`, 3 par carte aux étages 1-4, 2 à
## la Source), sinon point libre de la carte à Balance.STATION_MIN_START_DIST_U du départ et des piliers.
## Générateur propre (graine de run + "station_pos" + étage) : ne consomme jamais RunState.rng.
## Le couple Fondoir + Matrice partage une case `E` (deux props à 3 u l'un de l'autre, bornés par 4 u).
## Sauvegarde : to_dict(stations) <-> spawn(sm, saved) (états des usages, objet de la Matrice, position).

const PAIR_OFFSET_PX := 96.0 ## demi-écart du couple (1,5 u) -> 3 u entre les deux props
const OTHER_IDS: Array[StringName] = [&"boussole"] ## tirés par StationPlan, posés par un autre lot (hook make_other)


## Atelier(s) de l'étage de run courant. `saved` : états sauvegardés ([] = tirage neuf ; Array vide + `has_saved` faux).
static func spawn(sm: StageManager, saved: Variant = null) -> Array[Station]:
	var out: Array[Station] = []
	if sm.map == null or sm.bare_arena:
		return out
	if saved is Array:
		for raw in saved:
			if not (raw is Dictionary):
				continue
			var d := raw as Dictionary
			var st := StationState.from_dict(d)
			out.append(_place(sm, st, Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))))
		return out
	var id := StationPlan.for_stage(RunState.run_seed, RunState.stage)
	if id == &"" or (sm.map_scene != null and StationPlan.forced() == &""):
		return out # carte imposée par un test : pas d'atelier, sauf atelier imposé
	var states: Array[StationState] = []
	match id:
		&"fondoir_matrice":
			states = [StationState.make(&"fondoir", RunState.stage), StationState.make(&"matrice", RunState.stage)]
		&"fondoir", &"matrice", &"alambic", &"enclume":
			states = [StationState.make(id, RunState.stage)]
		_:
			if id in OTHER_IDS:
				make_other(sm, id, anchor(sm, id))
			return out
	var a := anchor(sm, id)
	for i in states.size():
		var off := Vector2.ZERO
		if states.size() == 2:
			off = Vector2(PAIR_OFFSET_PX * (-1.0 if i == 0 else 1.0), 0.0)
		out.append(_place(sm, states[i], sm.reachable_local(a + off)))
	return out


## Hook d'un atelier posé par un autre lot (Boussole de rouille) : pose le nœud sous `sm.map` en `pos`.
## Retourne le nœud posé ou null. Par défaut : rien.
static func make_other(sm: StageManager, id: StringName, pos: Vector2) -> Node2D:
	if id == &"boussole":
		return sm.place_compass(pos) # scripts/stage/compass_station.gd (état sauvegardé sous `compass_station`)
	return null


static func _place(sm: StageManager, st: StationState, pos: Vector2) -> Station:
	var s := Station.new()
	s.setup(st)
	s.position = pos
	sm.map.add_child(s)
	return s


static func to_dict(stations: Array) -> Array:
	var out: Array = []
	for s in stations:
		if is_instance_valid(s) and s is Station and (s as Station).state != null:
			var d := ((s as Station).state as StationState).to_dict()
			d["x"] = (s as Station).position.x
			d["y"] = (s as Station).position.y
			out.append(d)
	return out


# --- Position -------------------------------------------------------------------------------------

## Case d'ancrage de l'atelier `id` (repère local de la carte, zone accessible).
static func anchor(sm: StageManager, id: StringName) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([RunState.run_seed, "station_pos", RunState.stage])
	var start := sm.map.get_player_start()
	var cells: Array[Vector2] = []
	for m in sm.map.get_event_markers():
		var p := sm.map.local_pos(m)
		if sm.is_reachable_local(p):
			cells.append(p)
	if not cells.is_empty():
		if sm.is_final_floor:
			cells.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(start) < b.distance_to(start))
			return cells[0] # l'Enclume de la Source sert AVANT le boss final : case la plus proche du départ
		return cells[rng.randi_range(0, cells.size() - 1)]
	return _free_point(sm, rng, start)


## Repli sans case `E` : point libre, à Balance.STATION_MIN_START_DIST_U du départ et des piliers, hors des coffres.
static func _free_point(sm: StageManager, rng: RandomNumberGenerator, start: Vector2) -> Vector2:
	var min_d := Balance.STATION_MIN_START_DIST_U * StageManager.UNIT
	var cands := sm._capsule_candidates(rng)
	var order := sm._shuffled_indices(cands.size(), rng)
	var best := start + Vector2(6.0 * StageManager.UNIT, 0.0)
	var best_d := -1.0
	for i in order:
		var p: Vector2 = cands[i]
		var d := p.distance_to(start)
		var ok := d >= min_d
		for pl in sm.pillars:
			if is_instance_valid(pl) and p.distance_to(pl.position) < min_d:
				ok = false
		for c in sm.chests:
			if is_instance_valid(c) and p.distance_to(c.position) < 4.0 * StageManager.UNIT:
				ok = false
		if ok:
			return p
		if d > best_d:
			best_d = d
			best = p
	return best
