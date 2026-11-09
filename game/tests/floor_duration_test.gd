extends Node
## Durée d'étage A contre B (docs/Design_Variantes_B.md §8 « Durée ») : pour chaque carte réelle et 4 graines, l'étage
## est posé par le vrai StageManager (mode test, onglet Cartes : coffres, piliers, Épreuves, téléporteur tirés comme en
## run), puis le trajet d'un joueur est mesuré sur la grille de déplacement de la carte (AStarGrid2D sur les cellules
## de NavField, diagonales sans couper les coins) :
##   départ -> petits piliers / Épreuves (plus proche d'abord) -> gros pilier -> téléporteur ;
##   variante « avec coffres » : COFFRES_VISITES coffres insérés au moindre détour.
## Temps estimé = marche / (vitesse de base x RENDEMENT_MARCHE) + temps fixes d'objectif (Épreuve : EPREUVE_TARGET_S du
## verbe ; mini-boss : T_MINI_S ; charge du gros pilier : PILLAR_CHARGE_S ; boss d'étage : T_BOSS_S ; coffre : T_COFFRE_S).
## Les temps de combat ne dépendent pas de la carte (mêmes boss, même biome) : l'écart A / B vient du trajet.
##   godot --headless --path game res://tests/floor_duration_test.tscn [-- --seeds=1,2,3,4 --maps=a,b --out=C:/x.json]
## Sortie : tableau par carte, tableau A / B par étage, « RESULT: OK » (toutes les cartes posées, tous les objectifs
## atteignables, écart B - A sous ECART_MAX_S).

const SEEDS := [1, 2, 3, 4]
const COFFRES_VISITES := 5
const RENDEMENT_MARCHE := 0.8 ## détours de combat, kite : 80 % de la vitesse de base en moyenne
const T_MINI_S := 35.0 ## mini-boss d'un petit pilier classique (sans Épreuve)
const T_BOSS_S := 45.0 ## boss d'étage après la charge (référence balance_sim_fullrun, joueur moyen)
const T_COFFRE_S := 3.0 ## ouverture + choix
const ECART_MAX_S := 45.0 ## alerte si une B dure plus de 45 s de plus que la A du même étage (moyenne des graines)

var _fails := 0
var _main: Node


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var seeds: Array = SEEDS
	if args.has("seeds"):
		seeds = Array(str(args["seeds"]).split(",", false)).map(func(x): return int(x))
	var old_path: String = Profile.path
	var old_write: bool = Profile.write_enabled
	Profile.path = "user://floor_duration_profile.json"
	Profile.write_enabled = false
	TestMode.begin()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 77)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	var sm: StageManager = _main.get(&"stage")
	var cat := TestMaps.catalog()
	var only: Array = Array(str(args.get("maps", "")).split(",", false))
	var rows: Array = []
	for e in cat:
		if not only.is_empty() and not (String(e.id) in only):
			continue
		for s in seeds:
			RunState.run_seed = 4000 + int(s) * 97
			RunState.rng.seed = RunState.run_seed
			var ok := TestMaps.load_map(get_tree(), String(e.id))
			await _frames(3)
			_check("%s graine %d : carte posée" % [e.id, s], ok and sm.map != null and sm.map_id == String(e.id))
			if not ok or sm.map == null:
				continue
			var r := _measure(sm, e)
			r["seed"] = s
			rows.append(r)
			_check("%s graine %d : objectifs atteignables" % [e.id, s], bool(r.reachable), str(r.get("note", "")))
	# tableau par carte (moyenne des graines)
	var by_map := {}
	for r in rows:
		var k := String(r.map)
		if not by_map.has(k):
			by_map[k] = {"map": k, "floor": r.floor, "variant": r.variant, "n": 0, "walk_obj_u": 0.0, "walk_all_u": 0.0,
				"t_obj_s": 0.0, "t_all_s": 0.0, "fixed_s": 0.0, "verbs": {}}
		var m: Dictionary = by_map[k]
		m.n += 1
		m.walk_obj_u += float(r.walk_obj_u)
		m.walk_all_u += float(r.walk_all_u)
		m.t_obj_s += float(r.t_obj_s)
		m.t_all_s += float(r.t_all_s)
		m.fixed_s += float(r.fixed_s)
		for v in r.verbs:
			m.verbs[v] = int(m.verbs.get(v, 0)) + 1
	print("")
	print("%-26s %3s %2s | %9s %9s | %8s %8s | %7s | %s" % ["carte", "ét", "v", "marche u", "+coffres", "t obj s", "t+cof s", "fixe s", "objectifs (graines)"])
	for k in by_map:
		var m: Dictionary = by_map[k]
		for f in ["walk_obj_u", "walk_all_u", "t_obj_s", "t_all_s", "fixed_s"]:
			m[f] = snappedf(float(m[f]) / m.n, 0.1)
		print("%-26s %3d %2s | %9.1f %9.1f | %8.1f %8.1f | %7.1f | %s" % [k, m.floor, m.variant, m.walk_obj_u, m.walk_all_u, m.t_obj_s, m.t_all_s, m.fixed_s, str(m.verbs)])
	print("")
	print("A CONTRE B (moyenne de %d graines) :" % seeds.size())
	var ab: Array = []
	for k in by_map:
		var b: Dictionary = by_map[k]
		if String(b.variant) != "B":
			continue
		for k2 in by_map:
			var a: Dictionary = by_map[k2]
			if int(a.floor) == int(b.floor) and String(a.variant) == "A":
				var d_obj := float(b.t_obj_s) - float(a.t_obj_s)
				var d_all := float(b.t_all_s) - float(a.t_all_s)
				ab.append({"floor": b.floor, "a": a.map, "b": b.map, "t_a_s": a.t_all_s, "t_b_s": b.t_all_s, "delta_obj_s": snappedf(d_obj, 0.1), "delta_all_s": snappedf(d_all, 0.1),
					"walk_a_u": a.walk_all_u, "walk_b_u": b.walk_all_u})
				print("  étage %d : %s %.0f s  contre  %s %.0f s  -> B - A = %+.1f s (objectifs seuls %+.1f s), marche %.0f contre %.0f u" % [
					b.floor, a.map, a.t_all_s, b.map, b.t_all_s, d_all, d_obj, a.walk_all_u, b.walk_all_u])
				_check("étage %d : écart B - A sous %.0f s" % [b.floor, ECART_MAX_S], d_all <= ECART_MAX_S, "%+.1f" % d_all)
	if args.has("out"):
		var f := FileAccess.open(str(args["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"rows": rows, "maps": by_map.values(), "b_vs_a": ab,
				"model": {"speed_u_s": Balance.PLAYER_SPEED_U, "efficiency": RENDEMENT_MARCHE, "t_mini_s": T_MINI_S, "t_boss_s": T_BOSS_S,
				"charge_s": Balance.PILLAR_CHARGE_S, "t_chest_s": T_COFFRE_S, "chests": COFFRES_VISITES}}, " "))
			f.close()
	remove_child(_main)
	_main.queue_free()
	await _frames(2)
	Profile.path = old_path
	Profile.write_enabled = old_write
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Trajet et temps d'un étage posé.
func _measure(sm: StageManager, e: Dictionary) -> Dictionary:
	_cache.clear()
	var nf := sm.reach_field()
	var out := {"map": String(e.id), "floor": int(e.floor), "variant": String(e.variant), "reachable": true, "verbs": []}
	if nf == null or not nf.is_valid():
		out["reachable"] = false
		out["note"] = "pas de grille"
		return out
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, nf.w, nf.h)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	for c in nf.w * nf.h:
		if nf.blocked[c] != 0:
			astar.set_point_solid(Vector2i(c % nf.w, c / nf.w), true)
	var start := sm.map.to_global(sm.map.get_player_start())
	var smalls: Array[Vector2] = []
	var big := Vector2.INF
	var fixed := 0.0
	for p in sm.pillars:
		if not is_instance_valid(p):
			continue
		if p.kind == Pillar.Kind.BIG:
			big = p.global_position
			fixed += Balance.PILLAR_CHARGE_S + T_BOSS_S
		else:
			smalls.append(p.global_position)
			if p is Epreuve:
				var verb := StringName((p as Epreuve).verb)
				out.verbs.append(String(verb))
				fixed += float(Balance.EPREUVE_TARGET_S.get(verb, 40.0))
			else:
				out.verbs.append("mini")
				fixed += T_MINI_S
	if big == Vector2.INF:
		out["reachable"] = false
		out["note"] = "pas de gros pilier"
		return out
	var tele := sm.teleporter.global_position if sm.teleporter != null else big
	# ordre : petits objectifs du plus proche au plus proche, puis gros pilier, puis téléporteur
	var route: Array[Vector2] = [start]
	var left := smalls.duplicate()
	var cur := start
	while not left.is_empty():
		var bi := 0
		var bd := INF
		for i in left.size():
			var d := _path_u(astar, nf, cur, left[i])
			if d < bd:
				bd = d
				bi = i
		cur = left[bi]
		route.append(cur)
		left.remove_at(bi)
	route.append(big)
	route.append(tele)
	var walk_obj := 0.0
	for i in route.size() - 1:
		var d := _path_u(astar, nf, route[i], route[i + 1])
		if d == INF:
			out["reachable"] = false
			out["note"] = "segment %d inaccessible" % i
			return out
		walk_obj += d
	# coffres : insertion au moindre détour (avant le gros pilier)
	var chests: Array[Vector2] = []
	for c in sm.chests:
		if is_instance_valid(c):
			chests.append((c as Node2D).global_position)
	var walk_all := walk_obj
	var full := route.duplicate()
	var added := 0
	while added < COFFRES_VISITES and not chests.is_empty():
		var best_ci := -1
		var best_pos := -1
		var best_cost := INF
		for ci in chests.size():
			for k in range(1, full.size() - 1): # insertion avant full[k], jamais après le gros pilier
				var a: Vector2 = full[k - 1]
				var b: Vector2 = full[k]
				var cost := _path_u(astar, nf, a, chests[ci]) + _path_u(astar, nf, chests[ci], b) - _path_u(astar, nf, a, b)
				if cost < best_cost:
					best_cost = cost
					best_ci = ci
					best_pos = k
		if best_ci < 0 or best_cost == INF:
			break
		full.insert(best_pos, chests[best_ci])
		chests.remove_at(best_ci)
		walk_all += best_cost
		added += 1
	var speed := Balance.PLAYER_SPEED_U * RENDEMENT_MARCHE
	out["walk_obj_u"] = snappedf(walk_obj, 0.1)
	out["walk_all_u"] = snappedf(walk_all, 0.1)
	out["fixed_s"] = snappedf(fixed, 0.1)
	out["chests_visited"] = added
	out["t_obj_s"] = snappedf(walk_obj / speed + fixed, 0.1)
	out["t_all_s"] = snappedf(walk_all / speed + fixed + added * T_COFFRE_S, 0.1)
	return out


var _cache := {}


## Longueur (u) du plus court chemin à pied entre deux positions globales (INF si aucun chemin).
func _path_u(astar: AStarGrid2D, nf: NavField, a: Vector2, b: Vector2) -> float:
	var ca := _cell(nf, a)
	var cb := _cell(nf, b)
	if ca < 0 or cb < 0:
		return INF
	if ca == cb:
		return 0.0
	var key := Vector3i(ca, cb, nf.w)
	if _cache.has(key):
		return _cache[key]
	var path := astar.get_point_path(Vector2i(ca % nf.w, ca / nf.w), Vector2i(cb % nf.w, cb / nf.w))
	var d := INF
	if path.size() >= 2:
		d = 0.0
		for i in path.size() - 1:
			d += path[i].distance_to(path[i + 1])
	_cache[key] = d
	_cache[Vector3i(cb, ca, nf.w)] = d
	return d


## Cellule libre la plus proche (repère posé contre un mur ou sur un prop : rabattu dans la zone accessible).
func _cell(nf: NavField, p: Vector2) -> int:
	var c := nf.cell_of(p)
	if c >= 0 and nf.blocked[c] == 0 and nf.is_reachable(p):
		return c
	var q := nf.nearest_reachable(p)
	c = nf.cell_of(q)
	return c if c >= 0 and nf.blocked[c] == 0 else -1
