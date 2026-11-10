extends Node
## Boss contre obstacles centraux des cartes B (docs/Design_Variantes_B.md §8 « Boss ») : sur chaque carte B, le gros
## pilier candidat le plus proche de l'obstacle central (Rizières : noria ; Mangrove : cèdre ; Fonderie : creusets ;
## Ossuaire : margelle du puits) reçoit, un par un, les 3 boss d'étage et les 5 mini-boss du biome, à la place où
## Pillar.activate les fait apparaître (gros pilier + BOSS_OFFSET). Le joueur (invulnérable, sorts coupés) est posé
## DERRIÈRE l'obstacle par rapport au boss. Pendant SIM_S secondes de jeu, on suit la distance au joueur et le
## déplacement du boss.
## Verdict par boss : « atteint » s'il passe à moins de REACH_U du joueur (ou à moins de la moitié de sa distance de
## départ) ; « coincé » s'il n'a jamais approché ET a bougé de moins de STILL_U sur les STILL_WINDOW_S dernières secondes
## alors qu'il était loin ; « statique » (boss qui ne marche pas, déplacement total < STILL_U) signalé à part.
## Témoin : le même boss refait l'essai avec le joueur à la même distance mais À DÉCOUVERT (ligne de vue libre). Un boss
## qui garde ses distances (tireur, lanceur) s'arrête aussi loin dans les deux cas : seul un boss qui n'approche pas
## derrière l'obstacle alors qu'il approche à découvert (écart > 3 u) est « bloqué par l'obstacle ».
##   godot --headless --fixed-fps 60 --path game res://tests/boss_obstacle_test.tscn [-- --maps=cite_fonderie_canal --sim=20]
##   options : --bosses=sonneur,smelter (filtre), --trace (position et direction du champ toutes les 0,5 s), --lenient
## Colonnes : r u = rayon du corps, obst u = distance finale du boss au centre de l'obstacle (un boss coincé contre
## l'obstacle finit à peu près à « demi-largeur de l'obstacle + rayon »).
## Sortie : une ligne par boss, les ALERTES (boss bloqué par l'obstacle, boss fini dans une case bloquée ; un boss d'eau
## profonde dans une case `~` n'est pas « dans un mur »), puis « RESULT: OK » si tous les boss sont apparus et qu'il n'y a
## aucune alerte : depuis la navigation des gros corps (NavField.steer_body, champ sur grille dilatée du rayon), chaque
## alerte est un échec par défaut ; --lenient les signale sans échouer (ancien comportement, --strict accepté et ignoré).
## Tirages globaux réensemencés avant chaque essai (seed) : les deux essais d'un boss et deux passages se ressemblent.

const B_MAPS := ["terrasses_rizieres_hautes", "foret_mangrove_lanternes", "cite_fonderie_canal", "cryptes_ossuaire_pluies"]
## Obstacle central de chaque carte B : nom de prop fixe (`props_fixed`, collision) ou motif de texture (prop de biome).
const OBSTACLES := {
	"terrasses_rizieres_hautes": {"prop": "noria"},
	"foret_mangrove_lanternes": {"texture": "cedar", "cell": [23, 11]},
	"cite_fonderie_canal": {"prop": "crucible"},
	"cryptes_ossuaire_pluies": {"prop": "well_rim"},
}
const SIM_S := 20.0
const REACH_U := 4.0
const STILL_U := 1.0
const STILL_WINDOW_S := 5.0
const BEHIND_U := 3.0 ## distance du joueur derrière le bord de l'obstacle
const U := 64.0

var _fails := 0
var _alerts: Array[String] = [] ## boss bloqués / dans un mur : comptés en échec (sauf --lenient)
var _main: Node
var _rows: Array = []
var _trace := false ## --trace : position du boss et direction du champ toutes les 0,5 s


func _ready() -> void:
	_run.call_deferred()


func _check(label: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  ok   ", label, " ", detail)
	else:
		_fails += 1
		print("  FAIL ", label, " ", detail)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	var maps: Array = B_MAPS
	if args.has("maps"):
		maps = Array(str(args["maps"]).split(",", false))
	var sim_s := float(args.get("sim", str(SIM_S)))
	_trace = args.has("trace")
	var old_path: String = Profile.path
	var old_write: bool = Profile.write_enabled
	Profile.path = "user://boss_obstacle_profile.json"
	Profile.write_enabled = false
	TestMode.begin()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"run_seed", 77)
	add_child(_main)
	await _main.game_ready
	await _frames(3)
	TestMode.set_flag(&"god", true)
	TestMode.set_difficulty(2.5)
	var sm: StageManager = _main.get(&"stage")
	var director: Director = _main.get(&"director")
	var player: Node2D = _main.get(&"player")
	for id in maps:
		if not TestMaps.load_map(get_tree(), String(id)):
			_check("%s : carte chargée" % id, false)
			continue
		await _frames(5)
		director.spawning_enabled = false
		director.waves_enabled = false
		var e := TestMaps.entry(String(id))
		var obstacle := _obstacle_pos(sm, String(id))
		_check("%s : obstacle central trouvé" % id, obstacle != Vector2.INF)
		if obstacle == Vector2.INF:
			continue
		var big := _nearest_big(sm, obstacle)
		var spawn := big + Pillar.BOSS_OFFSET
		var away := (obstacle - spawn).normalized()
		var p_target := sm.map.to_global(sm.reachable_local(sm.map.to_local(obstacle + away * (2.0 + BEHIND_U) * U)))
		print("%s : obstacle %s, gros pilier %s (à %.1f u), joueur %s" % [id, obstacle.round(), big.round(), big.distance_to(obstacle) / U, p_target.round()])
		var bosses := _biome_bosses(int(e.floor))
		if args.has("bosses"): # filtre : --bosses=sonneur,smelter
			var keep := Array(str(args["bosses"]).split(",", false))
			bosses = bosses.filter(func(bk: Array) -> bool: return keep.has(String(bk[0])))
		var p_open := _open_target(sm, spawn, spawn.distance_to(p_target), away)
		print("   témoin à découvert : joueur %s (à %.1f u du boss, ligne de vue libre)" % [p_open.round(), spawn.distance_to(p_open) / U])
		for bk in bosses:
			var row := await _try_boss(sm, director, player, String(id), bk[0], bk[1], spawn, p_target, sim_s, obstacle)
			var ctl := await _try_boss(sm, director, player, String(id), bk[0], bk[1], spawn, p_open, sim_s, obstacle)
			row["open_min_u"] = ctl.min_u
			row["open_verdict"] = ctl.verdict
			# coincé à cause de l'obstacle : n'approche pas derrière l'obstacle alors qu'il approche à découvert
			row["blocked_by_obstacle"] = row.verdict == "coincé" and float(row.min_u) > float(ctl.min_u) + 3.0
			_rows.append(row)
	print("")
	print("%-26s %-20s %-5s | %5s | %6s %6s %6s %6s %6s | %-20s | %8s %-12s" % ["carte", "boss", "type", "r u", "dép u", "min u", "dépl u", "fin u", "obst u", "derrière l'obstacle", "témoin u", "témoin"])
	for r in _rows:
		print("%-26s %-20s %-5s | %5.2f | %6.1f %6.1f %6.1f %6.1f %6.1f | %-20s | %8.1f %-12s" % [r.map, r.boss, r.kind, r.radius_u, r.d0_u, r.min_u, r.moved_u, r.last_window_u, r.end_obstacle_u, r.verdict, r.open_min_u, r.open_verdict])
		_check("%s / %s : boss apparu" % [r.map, r.boss], r.verdict != "absent")
		if bool(r.blocked_by_obstacle):
			_alerts.append("%s / %s : bloqué par l'obstacle (min %.1f u derrière, %.1f u à découvert)" % [r.map, r.boss, r.min_u, r.open_min_u])
		if r.in_wall:
			_alerts.append("%s / %s : fini dans une case bloquée (case « %s », emprise d'un prop ou d'un mur)" % [r.map, r.boss, r.get("cell_char", "?")])
	print("")
	print("ALERTES (%d) :" % _alerts.size())
	for al in _alerts:
		print("  ALERTE ", al)
	if not args.has("lenient"):
		_fails += _alerts.size()
	if args.has("out"):
		var f := FileAccess.open(str(args["out"]), FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify({"rows": _rows}, " "))
			f.close()
	remove_child(_main)
	_main.queue_free()
	await _frames(2)
	Profile.path = old_path
	Profile.write_enabled = old_write
	print("RESULT: %s" % ("OK" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(0 if _fails == 0 else 1)


## [[boss_id, kind]] : boss d'étage puis mini-boss du biome (data/floors.json).
func _biome_bosses(floor_n: int) -> Array:
	var out: Array = []
	for f in FloorPlan.floors():
		var fe := f as Dictionary
		if int(fe.get("floor", 0)) != floor_n:
			continue
		for b in fe.get("floor_bosses", []):
			out.append([StringName(b), &"etage"])
		for m in fe.get("minis", []):
			out.append([StringName(m), &"mini"])
	return out


func _try_boss(sm: StageManager, director: Director, player: Node2D, map_id: String, boss_id: StringName, kind: StringName,
		spawn: Vector2, p_target: Vector2, sim_s: float, obstacle: Vector2) -> Dictionary:
	director.despawn_all()
	player.global_position = p_target
	var spells: Node = player.get(&"spells")
	if spells != null:
		spells.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	seed(hash(boss_id)) # tirages globaux (randf : pylônes, cibles…) identiques d'un passage et d'un essai à l'autre
	var b := TestTools.spawn_boss(get_tree(), boss_id, kind, spawn)
	var row := {"map": map_id, "boss": String(boss_id), "kind": String(kind), "d0_u": 0.0, "min_u": 0.0, "moved_u": 0.0,
		"last_window_u": 0.0, "in_wall": false, "verdict": "absent", "radius_u": 0.0, "end_obstacle_u": 0.0}
	if b == null:
		return row
	row.radius_u = snappedf(float(b.get(&"radius_px")) / U, 0.01) if b.get(&"radius_px") != null else 0.0
	var d0 := b.global_position.distance_to(player.global_position)
	var min_d := d0
	var start_pos := b.global_position
	var max_moved := 0.0
	var samples: Array[Vector2] = []
	var steps := int(sim_s * 60.0)
	for i in steps:
		await get_tree().physics_frame
		if not is_instance_valid(b) or not b.is_inside_tree():
			break
		player.global_position = p_target # le joueur ne bouge pas (recul, poussées)
		min_d = minf(min_d, b.global_position.distance_to(player.global_position))
		max_moved = maxf(max_moved, b.global_position.distance_to(start_pos))
		if i % 30 == 0:
			samples.append(b.global_position)
			if _trace:
				print("    t=%.1f %s pos=%s d=%.1f u steer_body=%s" % [i / 60.0, boss_id, b.global_position.round(),
					b.global_position.distance_to(player.global_position) / U,
					director.nav.steer_body(b.global_position, float(b.get(&"radius_px"))) if director.nav != null else Vector2.ZERO])
	var window := int(STILL_WINDOW_S * 2.0)
	var last_window := 0.0
	if samples.size() > window:
		var ref := samples[samples.size() - 1 - window]
		for k in range(samples.size() - window, samples.size()):
			last_window = maxf(last_window, samples[k].distance_to(ref))
	var nf := sm.reach_field()
	var in_wall := false
	if is_instance_valid(b) and nf != null:
		var c := nf.cell_of(b.global_position)
		in_wall = c >= 0 and nf.blocked[c] != 0 and b.global_position.distance_to(nf.nearest_reachable(b.global_position)) > U * 1.5
		row["cell_char"] = _grid_char(sm.map, b.global_position)
		if in_wall and _grid_char(sm.map, b.global_position) == "~":
			in_wall = false # boss d'eau profonde (anguille) : dans l'eau, pas dans un mur
			row["in_deep_water"] = true
	row.d0_u = snappedf(d0 / U, 0.1)
	row.min_u = snappedf(min_d / U, 0.1)
	row.moved_u = snappedf(max_moved / U, 0.1)
	row.last_window_u = snappedf(last_window / U, 0.1)
	row.in_wall = in_wall
	if is_instance_valid(b):
		row.end_obstacle_u = snappedf(b.global_position.distance_to(obstacle) / U, 0.1)
		row["end_pos"] = [roundi(b.global_position.x), roundi(b.global_position.y)]
	if min_d <= REACH_U * U or min_d <= d0 * 0.5:
		row.verdict = "atteint"
	elif max_moved < STILL_U * U:
		row.verdict = "statique"
	elif last_window < STILL_U * U:
		row.verdict = "coincé"
	else:
		row.verdict = "en route"
	if in_wall:
		row.verdict += " (dans un mur)"
	director.despawn_all()
	if spells != null:
		spells.process_mode = Node.PROCESS_MODE_INHERIT
	return row


## Obstacle central : parmi les instances du prop (props_fixed : centre de l'emprise ; prop de biome : sprite dont la
## texture contient le motif, repli sur la case du design), celle qui est la plus proche d'un gros pilier candidat.
func _obstacle_pos(sm: StageManager, map_id: String) -> Vector2:
	var spec: Dictionary = OBSTACLES.get(map_id, {})
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	var cell_u := float(data.get("grid_cell_u", 2))
	var found: Array[Vector2] = []
	if spec.has("prop"):
		for pf in data.get("props_fixed", []):
			if String(pf.get("name", "")) == String(spec["prop"]):
				var c := Vector2(float(pf.cell[0]), float(pf.cell[1]))
				var sz := Vector2(float(pf.size[0]), float(pf.size[1]))
				found.append(_u_to_global(sm.map, (c + sz * 0.5) * cell_u))
	elif spec.has("texture"):
		for n in sm.map.find_children("*", "Sprite2D", true, false):
			var spr := n as Sprite2D
			if spr.texture != null and String(spec["texture"]) in spr.texture.resource_path:
				found.append(spr.global_position)
		if found.is_empty():
			var c2 := Vector2(float(spec.cell[0]), float(spec.cell[1]))
			found.append(_u_to_global(sm.map, (c2 + Vector2(0.5, 0.5)) * cell_u))
	var best := Vector2.INF
	var best_d := INF
	for o in found:
		var d := _nearest_big(sm, o).distance_to(o)
		if d < best_d:
			best_d = d
			best = o
	return best


## Point à `dist` du boss, accessible, ligne de vue libre (aucune cellule bloquée sur le segment), le plus éloigné
## possible de la direction de l'obstacle : témoin « à découvert » pour séparer obstacle et portée préférée du boss.
func _open_target(sm: StageManager, spawn: Vector2, dist: float, away: Vector2) -> Vector2:
	var nf := sm.reach_field()
	var best := spawn + away.rotated(PI) * dist
	var best_score := -INF
	for k in 24:
		var dir := Vector2.from_angle(TAU * k / 24.0)
		var p := spawn + dir * dist
		if nf == null or not nf.is_reachable(p):
			continue
		var clear := true
		var steps := int(dist / 16.0)
		for i in steps + 1:
			var c := nf.cell_of(spawn.lerp(p, float(i) / maxf(steps, 1)))
			if c < 0 or nf.blocked[c] != 0:
				clear = false
				break
		if not clear:
			continue
		var score := -dir.dot(away)
		if score > best_score:
			best_score = score
			best = p
	return best


## Caractère de la grille ASCII de la carte sous une position globale ("" hors grille).
func _grid_char(map: StageMap, g: Vector2) -> String:
	var info := AmbianceWater.grid_of(map)
	if info.is_empty():
		return ""
	var mp := map.to_map(map.to_local(g)) - (info.origin as Vector2)
	var cx := int(floor(mp.x / float(info.cell_px)))
	var cy := int(floor(mp.y / float(info.cell_px)))
	var grid: PackedStringArray = info.grid
	if cy < 0 or cy >= grid.size() or cx < 0 or cx >= grid[cy].length():
		return ""
	return grid[cy][cx]


func _u_to_global(map: StageMap, u: Vector2) -> Vector2:
	var size_u: Vector2 = map.get_meta(&"size_u", Vector2.ZERO)
	return map.to_global(map.from_map((u - size_u * 0.5) * U))


## Gros pilier candidat (data/maps : candidates.big_pillars, en u) le plus proche de l'obstacle.
func _nearest_big(sm: StageManager, obstacle: Vector2) -> Vector2:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % sm.map_id))
	var best := Vector2.INF
	for c in data.get("candidates", {}).get("big_pillars", []):
		var g := _u_to_global(sm.map, Vector2(float(c[0]), float(c[1])))
		if best == Vector2.INF or g.distance_to(obstacle) < best.distance_to(obstacle):
			best = g
	return best
