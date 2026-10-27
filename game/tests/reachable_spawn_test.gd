extends Node
## Zone accessible (NavField.compute_reachable) : rien n'apparaît dans une poche fermée (murs en cercle de la
## carte 1, îlot d'eau profonde…). Sur chaque carte de data/maps (étages 1-5, plusieurs seeds) :
## - repères placés à la main (chest_spawn, pillar_spawn, candidats du JSON dont les événements) accessibles ;
## - coffres, piliers, capsules, téléporteur posés : accessibles ;
## - N tirages de points d'apparition du Director (flux, vagues, repli), d'invocations et de boss : accessibles ;
## - aucune case praticable enclose sur aucune carte (la poche de terrasses_noyees est devenue un bassin « ~ »,
##   cases 17-18 × 20-23, rive praticable entre 4 bornes d'angle).
## godot --headless --path game res://tests/reachable_spawn_test.tscn   (sortie « RESULT: OK »)

const UNIT := 64.0
const SEEDS := [11, 2024, 77]
const MONSTER_DRAWS := 200

var _fails := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	await _run()
	print("RESULT: ", "OK" if _fails == 0 else "FAIL (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_fails += 1
		print("FAIL: ", label)


func _run() -> void:
	_rng.seed = 4242
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child(player)
	var director: Node2D = load("res://scenes/enemies/director.tscn").instantiate()
	add_child(director)
	director.spawning_enabled = false
	var mgr := StageManager.new()
	add_child(mgr)
	mgr.chest_factory = func() -> Node2D: return Node2D.new()
	await get_tree().process_frame

	_unit_api()

	var seen := {}
	for s in SEEDS:
		RunState.start_run(&"moyen", s)
		mgr.reset_run()
		for st in StageManager.FINAL_STAGE:
			RunState.stage = st + 1
			mgr.start_stage()
			await get_tree().process_frame
			_check_stage(mgr, director, player, not seen.has(mgr.map_id))
			seen[mgr.map_id] = true
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.ends_with(".json") and f.get_basename() != "test_arena": # arène du mode test : hors run
			_check("carte %s parcourue" % f.get_basename(), seen.has(f.get_basename()))


## API sur une grille synthétique : anneau de murs fermé autour d'une poche.
func _unit_api() -> void:
	var root := Node2D.new()
	add_child(root)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	root.add_child(body)
	# carte 20 × 20 u (bords), anneau 6 × 6 u centré en (0, 0) (épaisseur 1 u), poche 4 × 4 u dedans
	var rects := [Rect2(-640, -640, 1280, 64), Rect2(-640, 576, 1280, 64), Rect2(-640, -640, 64, 1280), Rect2(576, -640, 64, 1280),
		Rect2(-192, -192, 384, 64), Rect2(-192, 128, 384, 64), Rect2(-192, -192, 64, 384), Rect2(128, -192, 64, 384)]
	for r: Rect2 in rects:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.get_center()
		body.add_child(cs)
	var nf := NavField.new()
	nf.build_from_map(root)
	_check("api : pas de calcul sans StageMap", not nf.has_reachability())
	_check("api : sans calcul, poche libre = accessible", nf.is_reachable(Vector2(0, 0)))
	var n := nf.compute_reachable(Vector2(400, 400))
	_check("api : cellules accessibles", n > 0 and nf.has_reachability())
	_check("api : poche fermée inaccessible", not nf.is_reachable(Vector2(0, 0)) and nf.is_enclosed(Vector2(0, 0)))
	_check("api : mur ni accessible ni « poche »", not nf.is_reachable(Vector2(-160, 0)) and not nf.is_enclosed(Vector2(-160, 0)))
	_check("api : dehors accessible", nf.is_reachable(Vector2(400, 400)) and nf.is_reachable(Vector2(-400, -300)))
	_check("api : is_spawnable refuse la poche", not nf.is_spawnable(Vector2(0, 0), 8.0))
	var q := nf.nearest_reachable(Vector2(10, 0))
	_check("api : nearest_reachable hors de l'anneau, au plus près (%s)" % q, nf.is_reachable(q) and q.x > 190.0 and q.x < 260.0)
	_check("api : nearest_reachable inchangé si accessible", nf.nearest_reachable(Vector2(400, 410)) == Vector2(400, 410))
	var r := RandomNumberGenerator.new()
	for i in 200:
		var p := nf.random_reachable_point(r)
		if not nf.is_reachable(p):
			_check("api : random_reachable_point accessible", false)
			break
	# obstacle dynamique posé après le calcul : ses cellules refusées, pas de recalcul
	nf.add_circle_obstacle(&"t", Vector2(400, 400), 40.0)
	_check("api : obstacle dynamique refusé", not nf.is_reachable(Vector2(400, 400)))
	nf.remove_obstacle(&"t")
	_check("api : obstacle retiré -> accessible", nf.is_reachable(Vector2(400, 400)))
	root.queue_free()


func _check_stage(mgr: StageManager, director: Node2D, player: Node2D, verbose: bool) -> void:
	var id := mgr.map_id
	var map := mgr.map
	var nav: NavField = director.nav
	_check("%s : grille liée au Director" % id, nav != null and director.get_map() == map)
	if nav == null:
		return
	_check("%s : zone accessible calculée" % id, nav.has_reachability() and nav.reach_cells.size() > 50)
	var g := func(p: Vector2) -> Vector2: return map.to_global(p)
	_check("%s : départ joueur accessible" % id, nav.is_reachable(g.call(map.get_player_start())))
	# poches fermées et eau profonde (bilan)
	var data0: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var size_u := Vector2(data0["size_u"][0], data0["size_u"][1])
	var pocket := 0 ## cellules de poche fermée DANS la grille du JSON (hors bande extérieure aux remparts)
	var outside := 0
	for c in nav.free_cells:
		var cp := nav.cell_center(c)
		if nav.is_enclosed(cp):
			var u := map.to_map(map.to_local(cp)) / UNIT + size_u * 0.5
			if u.x > 0.0 and u.y > 0.0 and u.x < size_u.x and u.y < size_u.y:
				pocket += 1
			else:
				outside += 1
	var data := data0
	var deep_ok := true
	var deep_n := 0
	var grid: Array = data["grid"]
	var origin := -Vector2(data["size_px"][0], data["size_px"][1]) * 0.5
	var cell := float(data.get("grid_cell_u", 2)) * UNIT
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			if row[x] == "~":
				deep_n += 1
				var p: Vector2 = g.call(map.from_map(origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell))
				if nav.is_reachable(p):
					deep_ok = false
	if verbose:
		print("%s : %d cellules accessibles, %d cellules de poche fermée (1 u) dans la carte, %d hors remparts, %d cases « ~ »" % [id, nav.reach_cells.size(), pocket, outside, deep_n])
	_check("%s : eau profonde « ~ » jamais accessible" % id, deep_ok)
	# plus aucune poche fermée sur aucune carte (22/10/2026 : la poche de la carte 1 est devenue un bassin « ~ »)
	_check("%s : aucune case praticable enclose dans la carte (%d cellules)" % [id, pocket], pocket == 0)
	if id == "terrasses_noyees":
		# ancien rectangle creux de murs, cases (17-18, 20-23) de la grille de 2 u : bassin d'eau profonde
		var deep := 0
		for y in range(20, 24):
			for x in range(17, 19):
				if (grid[y] as String)[x] == "~":
					deep += 1
		_check("terrasses : bassin de 8 cases « ~ » dans le JSON (%d)" % deep, deep == 8)
		var inside: Vector2 = g.call(map.from_map(origin + Vector2(18.0, 22.0) * cell))
		_check("terrasses : centre du bassin bloqué (ni accessible ni poche)", not nav.is_reachable(inside) and not nav.is_enclosed(inside))
		var dr: Node2D = director
		var b: Node2D = dr.spawn_boss(&"mini", inside)
		_check("terrasses : boss posé dans le bassin rabattu sur la rive", b != null and nav.is_reachable(b.position))
		dr.despawn_all()
		# rive praticable autour du bassin (côtés « . » entre les bornes d'angle « # »)
		for xy in [Vector2(16.5, 21.5), Vector2(19.5, 21.5), Vector2(17.5, 19.5), Vector2(18.5, 24.5)]:
			_check("terrasses : rive du bassin %s accessible" % xy, nav.is_reachable(g.call(map.from_map(origin + xy * cell))))
		var shut := 0
		for p: Vector2 in mgr._capsule_candidates(RandomNumberGenerator.new()):
			if not nav.is_reachable(g.call(p)):
				shut += 1
		_check("terrasses : aucun candidat de capsule hors zone accessible (%d)" % shut, shut == 0)
	# repères faits main (scène) et candidats du JSON (dont les événements / sanctuaires futurs)
	for m in map.get_chest_markers() + map.get_pillar_markers():
		_check("%s : repère %s accessible" % [id, m.name], nav.is_reachable(m.global_position))
	var cands: Dictionary = data.get("candidates", {})
	for k in cands:
		for xy in cands[k]:
			var p: Vector2 = g.call(map.from_map(origin + Vector2(float(xy[0]), float(xy[1])) * UNIT))
			_check("%s : candidat %s %s accessible" % [id, k, xy], nav.is_reachable(p))
	# objets posés
	for c in mgr.chests:
		_check("%s : coffre accessible" % id, nav.is_reachable(c.global_position))
	for p in mgr.pillars:
		_check("%s : pilier accessible" % id, nav.is_reachable(p.global_position))
		_check("%s : point d'apparition du boss du pilier accessible après rabat" % id,
			nav.is_reachable(nav.nearest_reachable(p.global_position + Pillar.BOSS_OFFSET)))
	for c in mgr.capsules:
		_check("%s : capsule accessible %s" % [id, c.position], nav.is_reachable(c.global_position))
	var big := mgr.pillars[mgr.pillars.size() - 1]
	_check("%s : téléporteur accessible" % id, nav.is_reachable(g.call(mgr.teleporter_local(big.position))))
	# Director : flux, vagues, repli, depuis des positions de joueur accessibles
	var bad := 0
	var drawn := 0
	for i in MONSTER_DRAWS:
		var pp := nav.random_reachable_point(_rng)
		player.global_position = pp
		var pts: Array[Vector2] = [director._spawn_point(pp), director._side_point(pp, Director.WAVE_SIDES[i % 4], _rng.randf_range(-0.7, 0.7)),
			director._nav_fallback_point(pp, director._spawn_box())]
		for sp in pts:
			if sp == Vector2.INF:
				continue
			drawn += 1
			if not nav.is_reachable(sp) or nav.is_enclosed(sp):
				bad += 1
	_check("%s : %d points d'apparition de monstres tous accessibles (%d hors zone)" % [id, drawn, bad], bad == 0 and drawn > MONSTER_DRAWS)
	player.global_position = g.call(map.get_player_start())
