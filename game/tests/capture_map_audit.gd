extends Node
## Audit visuel des 9 cartes réelles (SANS --headless) : pour chaque carte et chaque palier de qualité, une vue large
## et des vues à hauteur de jeu (départ, coffres, piliers, eau profonde). Sert à traquer les artefacts de rendu
## (« carrés bleus », lignes) signalés par le joueur le 12/11/2026. Mode test (bac à sable, rien au profil).
##   godot --path game res://tests/capture_map_audit.tscn -- --out=C:/x --maps=terrasses_noyees --tiers=2,0 --views=6
## Sans --maps : les 9 cartes. Sortie : <out>/<carte>_<palier>_<vue>.png puis « RESULT: OK ».

const PROFILE_PATH := "user://capture_map_audit_profile.json"

var _out := ""


func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_out = str(args.get("out", OS.get_user_data_dir() + "/map_audit"))
	DirAccess.make_dir_recursive_absolute(_out)
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	Profile.path = PROFILE_PATH
	Quality.persist = false
	Quality.dynamic_degrade = false
	get_window().size = Vector2i(1920, 1080)
	Platform.set_input_mode(Platform.InputMode.KBM)
	TestMode.begin()
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.set(&"run_seed", 777)
	add_child(main)
	await main.game_ready
	await _f(10)
	var tree := get_tree()
	var director: Director = tree.get_first_node_in_group(&"director") as Director
	TestMode.set_flag(&"god", true)
	TestMode.set_flag(&"spawns", false)
	var maps: Array = []
	if args.has("maps"):
		maps.assign(Array(str(args["maps"]).split(",", false)))
	else:
		for e in TestMaps.catalog():
			maps.append(String(e.id))
	var tiers: Array = [2, 0]
	if args.has("tiers"):
		tiers.assign(Array(str(args["tiers"]).split(",", false)).map(func(x): return int(x)))
	var n_views := int(args.get("views", "6"))
	for id in maps:
		if not TestMaps.load_map(tree, String(id)):
			push_warning("carte « %s » impossible à charger" % id)
			continue
		if director != null:
			director.spawning_enabled = false
			director.waves_enabled = false
		await _wait(3.0)
		var sm: StageManager = tree.get_first_node_in_group(&"stage_manager") as StageManager
		if args.has("dump"):
			_dump(tree.root)
		var pts := _points(sm, n_views)
		var pl := Players.all()[0] as Node2D
		var start := pl.global_position
		for t in tiers:
			Quality.set_tier(int(t), true)
			await _wait(1.5)
			var tn := Quality.tier_name(int(t))
			# vue large
			var cam := get_viewport().get_camera_2d()
			var z0 := cam.zoom
			pl.global_position = sm.map.to_global(Vector2.ZERO)
			cam.zoom = z0 * 0.3
			await _wait(0.6)
			_shot("%s_%s_0large" % [id, tn])
			cam.zoom = z0
			var i := 1
			for p in pts:
				pl.global_position = p
				await _wait(0.6)
				_shot("%s_%s_%d" % [id, tn, i])
				i += 1
			pl.global_position = start
		print("carte ", id, " : ", pts.size() + 1, " vues par palier")
	print("RESULT: OK")
	get_tree().quit()


func _wait(s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(s * 1000.0):
		if get_tree().paused: # perte de focus de la fenêtre : le menu pause s'ouvre, on le referme
			var pm := get_tree().get_first_node_in_group(&"pause_menu")
			if pm != null and bool(pm.get(&"is_open")) and pm.has_method(&"resume"):
				pm.call(&"resume")
			get_tree().paused = false
		await get_tree().process_frame


## Liste les nœuds visibles dessinés en formes (Line2D, Polygon2D, ColorRect hors UI) : chasse aux placeholders.
func _dump(n: Node) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Epreuve.EpreuveOverlay:
		var ep: Node = (n as Epreuve.EpreuveOverlay).epreuve
		print("DUMP Overlay ", n.get_path(), " epreuve=", ep.get_script().resource_path if ep != null else "")
	if n is Line2D or n is Polygon2D or (n is ColorRect and not n.get_parent() is Control):
		var ci := n as CanvasItem
		var col: Variant = ci.get(&"color") if not n is Line2D else (n as Line2D).default_color
		print("DUMP ", n.get_class(), " ", n.get_path(), " col=", col, " mod=", ci.modulate, " script=",
			n.get_script().resource_path if n.get_script() != null else "")
	for c in n.get_children():
		_dump(c)


func _shot(tag: String) -> void:
	CaptureUtil.save_viewport(get_viewport(), "%s/%s.png" % [_out, tag])


## Points de vue (global) : départ, eau profonde, coffres, piliers ; au plus `n`.
func _points(sm: StageManager, n: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var map := sm.map
	out.append(map.to_global(map.get_player_start()))
	var g := AmbianceWater.grid_of(map)
	if not g.is_empty():
		var grid: PackedStringArray = g["grid"]
		var cell: float = g["cell_px"]
		var origin: Vector2 = g["origin"]
		var water: Array[Vector2] = []
		for y in grid.size():
			for x in grid[y].length():
				if grid[y][x] == "~" or grid[y][x] == ",":
					water.append(map.to_global(map.from_map(origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell)))
		var step := maxi(1, water.size() / 3)
		var k := 0
		while k < water.size() and out.size() < 4:
			out.append(water[k])
			k += step
	for c in sm.chests:
		if out.size() >= n:
			break
		if is_instance_valid(c):
			out.append(c.global_position)
	for p in sm.pillars:
		if out.size() >= n:
			break
		if is_instance_valid(p):
			out.append(p.global_position)
	return out
