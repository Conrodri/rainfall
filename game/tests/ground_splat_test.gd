extends Node
## Sol v2 (GroundSplat + GroundDecals) sur toutes les cartes iso : un quad unique au lieu des losanges de
## 4 u, masque cuit fidèle à la grille (vide, eau, murs), matières chargées, variante du shader par palier,
## pas de masque du vide en cases, eau peu profonde sans losanges, coût de cuisson, décalques semés
## (atlas factice) hors murs / vide / repères et reproductibles.
## godot --headless --path game res://tests/ground_splat_test.tscn

const MAPS := ["terrasses_noyees", "terrasses_rizieres_hautes", "foret_brume", "foret_mangrove_lanternes",
	"cite_rouille", "cite_fonderie_canal", "cryptes_noyees", "cryptes_ossuaire_pluies", "la_source"]
const FAKE_ATLAS := "res://assets/sprites/terrain/shore/shore_foam_256x32.png" ## texture quelconque : on ne teste que le placement
var _fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL: ", msg)


func _ready() -> void:
	for id in MAPS:
		await _test_map(id)
	_test_decals()
	_test_fallback()
	print("RESULT: ", "OK" if _fails == 0 else "FAILED (%d)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _test_map(id: String) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
	var t0 := Time.get_ticks_usec()
	var map := (load(meta["scene"]) as PackedScene).instantiate() as StageMap
	add_child(map)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	await get_tree().process_frame
	var gs := map.ground_splat
	_check(gs != null and is_instance_valid(gs), "%s : GroundSplat présent" % id)
	if gs == null:
		map.queue_free()
		return
	var ground := map.get_node(^"Visual/Ground") as TileMapLayer
	_check(ground.get_used_cells().is_empty() and ground.tile_set == null, "%s : plus aucun losange de sol ni TileSet chargé (%d)" % [id, ground.get_used_cells().size()])
	_check(map.get_node_or_null(^"Visual/VoidMask") == null, "%s : pas de masque du vide en cases" % id)
	_check(gs.get_parent() == map.get_node(^"Visual") and gs.get_index() == ground.get_index() + 1, "%s : sous Visual, juste après Ground" % id)
	_check(gs.polygon.size() == 4, "%s : un seul quad" % id)
	var grid: Array = meta["grid"]
	var rows := grid.size()
	var cols := (grid[0] as String).length()
	var size := Vector2(meta["size_px"][0], meta["size_px"][1])
	var bb := Rect2(gs.polygon[0], gs.polygon[2] - gs.polygon[0])
	_check(bb.position.is_equal_approx(-size * 0.5) and bb.size.is_equal_approx(size), "%s : quad = emprise de la grille %s" % [id, bb])
	# masque : centre des cases
	var img := gs.mask_image
	_check(img.get_width() == cols * GroundSplat.MASK_K and img.get_height() == rows * GroundSplat.MASK_K, "%s : taille du masque" % id)
	var bad_land := 0
	var bad_void := 0
	var wet_ok := true
	var shallow_ok := true
	var seen_shallow := false
	for y in rows:
		var row: String = grid[y]
		for x in cols:
			var c := img.get_pixel(x * GroundSplat.MASK_K + GroundSplat.MASK_K / 2, y * GroundSplat.MASK_K + GroundSplat.MASK_K / 2)
			var ch := row[x]
			if ch == " ":
				# vide entouré de vide : aucune trace de sol
				if _all_void(grid, x, y) and c.r > 0.05:
					bad_void += 1
			elif c.r < 0.6:
				bad_land += 1
			if ch == "~" and c.g < 0.6:
				wet_ok = false
			if ch == ",":
				seen_shallow = true
				if c.a < 0.5:
					shallow_ok = false
	_check(bad_land == 0, "%s : sol plein sur toutes les cases hors vide (%d)" % [id, bad_land])
	_check(bad_void == 0, "%s : aucun sol au cœur du vide (%d)" % [id, bad_void])
	_check(wet_ok, "%s : humidité sur l'eau profonde" % id)
	_check(not seen_shallow or shallow_ok, "%s : film d'eau peu profonde" % id)
	# « , » n'a plus de losange d'eau ; « ~ » garde le sien (sous l'eau d'ambiance)
	var decor := map.get_node(^"Visual/Decor") as TileMapLayer
	var shallow_tiles := 0
	for y in rows:
		var row: String = grid[y]
		for x in cols:
			if row[x] == "," and decor.get_cell_source_id(Vector2i(x, y)) >= 0:
				shallow_tiles += 1
	_check(shallow_tiles == 0, "%s : plus de losanges d'eau peu profonde (%d)" % [id, shallow_tiles])
	# matières
	_check(gs.layer_paths.size() == 4, "%s : 4 matières" % id)
	for p in gs.layer_paths:
		_check(p != "" and ResourceLoader.exists(p), "%s : matière %s" % [id, p])
	var mat := gs.material as ShaderMaterial
	_check(mat != null and mat.shader != null and mat.get_shader_parameter(&"mask_tex") != null and mat.get_shader_parameter(&"noise_tex") != null, "%s : material complet" % id)
	# paliers : une variante de shader par palier, bascule à chaud
	var old := Quality.tier
	for t in [0, 1, 2]:
		Quality.tier = t
		gs._on_quality(t)
		_check(mat.shader.resource_path == GroundSplat.SHADERS[t], "%s : shader du palier %d (%s)" % [id, t, mat.shader.resource_path])
	Quality.tier = old
	gs._on_quality(old)
	_check(ms < 400.0, "%s : chargement de la carte %.0f ms" % [id, ms])
	print("  %-26s carte %4.0f ms  masque %dx%d  matières %s" % [id, ms, img.get_width(), img.get_height(), ", ".join(gs.layer_paths.map(func(p): return String(p).get_file()))])
	map.queue_free()
	await get_tree().process_frame


func _all_void(grid: Array, x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var yy := y + dy
			var xx := x + dx
			if yy < 0 or yy >= grid.size() or xx < 0 or xx >= (grid[yy] as String).length():
				continue
			if (grid[yy] as String)[xx] != " ":
				return false
	return true


func _test_decals() -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/cryptes_noyees.json"))
	var grid: Array = meta["grid"]
	var size := Vector2(meta["size_px"][0], meta["size_px"][1])
	var cfg := GroundSplat.config_for("cryptes")
	cfg = cfg.duplicate(true)
	cfg["decals"] = {"cols": 4, "rows": 4, "size_u": 2.0, "density": 0.3, "zones": ["wet", "wet", "wall", "wall", "open"]}
	var keep: Array[Vector2i] = [Vector2i(10, 10)]
	var a := GroundDecals.new()
	var n := a.setup(cfg, load(FAKE_ATLAS), grid, -size * 0.5, 128.0, "cryptes_noyees", keep)
	var b := GroundDecals.new()
	var n2 := b.setup(cfg, load(FAKE_ATLAS), grid, -size * 0.5, 128.0, "cryptes_noyees", keep)
	_check(n > 50 and n == n2, "décalques : semés et reproductibles (%d / %d)" % [n, n2])
	_check(a.multimesh.instance_count == n and a.multimesh.transform_format == MultiMesh.TRANSFORM_2D, "décalques : un MultiMesh 2D")
	var bad := 0
	var near_keep := 0
	for i in n:
		var p := a.multimesh.get_instance_transform_2d(i).origin
		var c := Vector2i(((p + size * 0.5) / 128.0).floor())
		var ch := (grid[c.y] as String)[c.x]
		if ch != "." and ch != ",":
			bad += 1
		if absi(c.x - 10) <= 1 and absi(c.y - 10) <= 1:
			near_keep += 1
		if i == 0:
			_check(a.multimesh.get_instance_transform_2d(i).is_equal_approx(b.multimesh.get_instance_transform_2d(i)), "décalques : même position à la même graine")
	_check(bad == 0, "décalques : jamais sur mur / vide / eau profonde (%d)" % bad)
	_check(near_keep == 0, "décalques : repères laissés libres (%d)" % near_keep)
	var c3 := GroundDecals.new()
	var n3 := c3.setup(cfg, load(FAKE_ATLAS), grid, -size * 0.5, 128.0, "autre_carte", keep)
	_check(n3 > 0, "décalques : autre graine")
	a.free()
	b.free()
	c3.free()


func _test_fallback() -> void:
	_check(not GroundSplat.available("biome_inconnu"), "biome sans configuration : ancien sol")
	var cfg := {"dir": "res://nulle_part/", "layers": [{"file": "base_0.png"}, {"file": "base_1.png", "fallback": FAKE_ATLAS}]}
	_check(GroundSplat.layer_path(cfg, 0) == "" and GroundSplat.layer_path(cfg, 1) == FAKE_ATLAS, "repli de matière")
